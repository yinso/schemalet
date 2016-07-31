AppError = require 'errorlet'
Promise = require 'bluebird'

_extend = (target, sources...) ->
  for src in sources
    for key, val of src
      target[key] = val
  target

_isFunction = (v) ->
  typeof(v) == 'function' or (v instanceof Function)

# this is somewhat similar to ObjectSchema (which forms an env).
class SchemaEnv
  constructor: () ->

class SchemaPath
  constructor: (path = '', prev = null) ->
    if not (@ instanceof SchemaPath)
      return new SchemaPath path, prev
    @path = path
    @prev = prev
  push: (path) ->
    new SchemaPath path, @
  toString: () ->
    res = []
    current = @
    while current
      res.unshift current.path
      current = current.prev
    res.join '/'
  toJSON: () ->
    @toString()

class Constraint
  check: (v) -> false
  validate: (v) ->
    new AppError
      error: 'constraintError'
      type: @type
      value: v
  equal: (other) ->
    if @ == other
      return true
    if not (other instanceof @constructor)
      return false
    return @_equal other

class EnumConstraint extends Constraint
  constructor: (@type) ->
    @enum =
      for item in @type.schema.enum
        @type.convert item
  check: (v) ->
    for item in @enum
      if @type.valueEqual item, v
        return true
    false
  equal: (other) ->
    if @enum.length != other.enum.length
      return false
    for item, i in @enum
      if not @type.valueEqual item, other.enum[i]
        return false
    true
  toJSON: () ->
    enum: 
      for item in @enum
        item

class AndConstraint extends Constraint
  constructor: (@type, @constraints) ->
  check: (v) ->
    for cons in @constraints
      if not cons.check v
        return false
    true
  _equal: (other) ->
    if @constraints.length != other.constraints.length
      return false
    for cons, i in @constraints
      if not cons.equal other.constraints[i]
        return false
    true
  toJSON: () ->
    res = {}
    for cons in @constraints
      inner = cons.toJSON()
      _extend res, inner
    res

class MultipleOfConstraint extends Constraint
  constructor: (@type) ->
    @multiple = @type.convert @type.schema.multipleOf
  check: (v) ->
    (v % @multiple) == 0
  _equal: (other) ->
    if not @type.valueEqual @multiple, other.multiple
      return false
    true
  toJSON: () ->
    multipleOf: @multiple

class MinimumConstraint extends Constraint
  constructor: (@type) ->
    @minimum = @type.convert @type.schema.minimum
    @exclusive = @type.schema.exclusiveMinimum
  check: (v) ->
    if @exclusive
      v > @minimum
    else
      v >= @minimum
  equal: (other) ->
    if other instanceof MinimumConstraint
      if not @type.equal other.type
        return false
      if not @type.valueEqual @minimum, other.minimum
        return false
      @exclusive == other.exclusive
    else
      false
  toJSON: () ->
    res =
      minimum: @minimum
    if @exclusive
      res.exclusiveMinimum = true
    res

class MaximumConstraint extends Constraint
  constructor: (@type) ->
    @maximum = @type.convert @type.schema.maximum
    @exclusive = @type.schema.exclusiveMaximum
  check: (v) ->
    if @exclusive
      v < @maximum
    else
      v <= @maximum
  equal: (other) ->
    if other instanceof MaximumConstraint
      if not @type.equal other.type
        return false
      if not @type.valueEqual @maximum, other.maximum
        return false
      @exclusive == other.exclusive
    else
      false
  toJSON: () ->
    res = 
      maximum: @maximum
    if @exclusive
      res.exclusiveMaximum = true
    res

class MinLengthConstraint extends Constraint
  constructor: (@type) ->
    @minimum = @type.convert @type.schema.minLength
  check: (v) ->
    v.length >= @minimum
  equal: (other) ->
    if other instanceof MinLengthConstraint
      if not @type.equal other.type
        return false
      return @type.valueEqual @minimum, other.minimum
    else
      false
  toJSON: () ->
    minimum: @minimum

class MaxLengthConstraint extends Constraint
  constructor: (@type) ->
    @maximum = @type.convert @type.schema.maxLength
  check: (v) ->
    v.length <= @maximum
  equal: (other) ->
    if other instanceof MaxLengthConstraint
      if not @type.equal other.type
        return false
      return @type.valueEqual @maximum, other.maximum
    else
      false
  toJSON: () ->
    maximum: @maximum

class PatternConstraint extends Constraint
  constructor: (@type) ->
    @pattern = @type.schema.pattern
  check: (v) ->
    v.match @pattern
  equal: (other) ->
    if other instanceof PatternConstraint
      if not @type.equal other.type
        return false
      return @pattern == other.pattern
    else
      false
  toJSON: () ->
    pattern: @pattern.toJSON()

formatConstraintMap =
  'date-time': (v) ->
    v.match /^\d{4}-?\d{2}-?\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/
  uuid: (v) ->
    v.match /^[a-zA-Z0-9]{8}-?[a-zA-Z0-9]{4}-?[a-zA-Z0-9]{4}-?[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}$/

class FormatConstraint extends Constraint
  constructor: (@type) ->
    @format = @type.schema.format
    if not formatConstraintMap.hasOwnProperty @format
      throw new AppError
        error: 'UnknownFormat'
        format: @format
        method: 'FormatConstraint.ctor'
  check: (v) ->
    formatConstraintMap[@format] v
  equal: (other) ->
    (other instanceof FormatConstraint) and @format == other.format

class Schema
  @SchemaPath: SchemaPath
  @SchemaEnv: SchemaEnv
  constructor: (@schema, @prev) ->
    if @isOptional()
      @validate @getDefaultValue()
    if @schema.hasOwnProperty('$base')
      if @schema.$base instanceof Schema
        @$base = @verifyBase @schema.$base
      else if @schema.$base.hasOwnProperty('_schema')
        @$base = @verifyBase @schema.$base._schema
      else
        throw new AppError
          type: 'invalidBase'
          schema: @schema
    if @schema.hasOwnProperty '$class'
      if _isFunction(@schema.$class)
        @$class = @schema.$class
      else
        throw new AppError
          type: 'invalidClass'
          schema: @schema
    @initConstraints()
  convert: (v, schemaPath = new SchemaPath()) ->
    if (v == null or v == undefined) and @isOptional()
      @getDefaultValue()
    else if @isa v
      if @$class
        if v instanceof @$class
          v
        else
          new @$class v
      else
        v
    else
      @valueConvert v, schemaPath
  isRequired: () ->
    not @isOptional()
  isOptional: () ->
    @schema.hasOwnProperty('default') or @schema.hasOwnProperty('defaultProc')
  getDefaultValue: () ->
    if @schema.hasOwnProperty('defaultProc')
      @schema.defaultProc.apply @, arguments
    else if @schema.hasOwnProperty('default')
      @schema.default
  equal: (other) ->
    if not (other instanceof @constructor)
      return false
    if @$base
      if not other.$base
        return false
      if not @$base.equal other.$base
        return false
    if @constraint
      if not other.constraint
        return false
      if not @constraint.equal other.constraint
        return false
    @_equal other
  _equal: (other) ->
    true
  # determine if the two value object valueEqual each other.
  valueEqual: (a, b) ->
    a == b # identity is the default valueEqual.
  isa: (v) ->
    if @hasOwnProperty('$base')
      if not @$base.isa(v)
        return false
    if @hasOwnProperty('$class')
      if (v instanceof @$class)
        return true
    if not @isType v
      return false
    if not @checkConstraints v
      return false
    true
  validate: (v) ->
    if not @isa v
      @invalidType v
    v
  @constraintMap:
    enum: EnumConstraint
  initConstraints: () ->
    cons = []
    for key, ctor of @constructor.constraintMap
      if @schema.hasOwnProperty(key)
        cons.push new ctor @
    if cons.length > 0
      @constraint = new AndConstraint @, cons
  checkConstraints: (v) ->
    if @constraint instanceof Constraint
      @constraint.check v
    else
      true
  invalidType: (v, schemaPath) ->
    err =
      error: 'invalidType'
      schema: @schema
      path: schemaPath
      value: v
    throw new AppError err, @invalidType
  absPath: () ->
    currentPath =
      if @schema.hasOwnProperty('id')
        @schema.id
      else
        '.'
    prevPath =
      if @prev instanceof Schema
        @prev.absPath()
      else
        '$'
    [ prevPath , currentPath ].join('/')
  getRoot: () ->
    if @prev
      @prev.getRoot()
    else
      @
  getPrev: () ->
    if @prev
      @prev
    else
      throw new AppError
        error: 'alreadyAtRoot'
        schema: @schema
  normalizePath: (refPath) ->
    segs = refPath.split '/'
    res = []
    for seg, i in segs
      if i > 0 and seg == ''
        continue
      else if i > 0 and seg == '.'
        continue
      else
        res.push seg
    res
  resolve: (refPath) ->
    segs = @normalizePath refPath
    current = @
    for seg, i in segs
      if seg == ''
        if i == 0
          current = current.getRoot()
        continue
      else if seg == '.'
        continue
      else if seg == '..'
        current = current.getPrev()
      else # seg is a property name.
        current = current.resolveName seg
    current
  resolveName: (name) ->
    @unknownProperty name
  unknownProperty: (name, schemaPath) ->
    err =
      error: 'unknownProperty'
      schema: @schema
      path: schemaPath
      name: name
    throw new AppError err, @unknownProperty
  verifyBase: (baseSchema) ->
    if (baseSchema instanceof @constructor)
      return baseSchema
    else
      @invalidBaseType()
  invalidBaseType: () ->
    err =
      error: 'invalidBaseType'
      #base: @schema.$base
      type: @schema.type
    throw new AppError err, @invalidBaseType
  finalTypeNonDerivable: () ->
    err =
      error: 'finalTypeNotDerivable'
      type: @schema.type
    throw new AppError err, @finalTypeNonDerivable
  specialize: (schema) ->
    # when there aren't any additional specialiation just pass it along
    @
  toJSON: () ->
    # when there is a $base we define things a bit differently.
    if @hasOwnProperty '$base'
      allOf = @$base.toJSON()
      {
        allOf: (if allOf.hasOwnProperty('allOf') then allOf.allOf else [ allOf ]).concat [ @toJSONInner() ]
      }
    else
      res = @toJSONInner()
      for key, val of @schema
        if key.match(/^\$/) and not (val instanceof Object)
          res[key] = val
        else if key in ['id', 'name', 'description', 'title']
          res[key] = val
      res
  toJSONInner: () ->
    res =
      type: @schema.type
    if @hasOwnProperty 'constraint'
      _extend res, @constraint.toJSON()
    _extend res, @_toJSON()
  _toJSON: () ->
    {}

  @makeFunction: (schema, proc) ->
    schemaObj =
      if schema instanceof ProcedureSchema
        schema
      else
        schema.type = 'function'
        @makeSchema schema
    schemaObj.makeFunction proc

  @makeClass: (schema, $init, $prototype, $base, $static) ->
    #console.log 'Schema::makeClass', $prototype
    name =
      if schema.hasOwnProperty('id')
        schema.id
      else
        'SchemaClass'
    schemaObj =
      if schema instanceof Schema
        schema
      else
        @makeSchema schema
    $init = $init or schema.$init or (options) -> _extend @, options
    $prototype = $prototype or schema.$prototype or {}
    $base = $prototype.$base or schema.$base
    if not _isFunction $init
      throw new AppError
        error: 'RequiredParameter'
        name: '$init'
        message: '$init must be a function'
        method: 'Schema::makeClass'
    getSchema = () -> schemaObj
    Ctor = (arg) ->
      if not (@ instanceof Ctor)
        return new Ctor arg
      res = schemaObj.valueConvert arg
      $init.call @, arg
      return
    Ctor._schema = schemaObj
    if $base
      if _isFunction $base
        require('util').inherits Ctor, schema.$base
      else if $base instanceof Schema
        Parent = @makeClass schema.$base
        require('util').inherits Ctor, Parent
      else if $base instanceof Object
          Ctor.prototype = schema.base
      else
        throw new AppError
          error: 'MakeClass.invalidBase'
          method: 'Schema.makeClass'
          schema: schema
    for key, val of $prototype
      Ctor.prototype[key] = val
    schema.$class = Ctor
    Ctor

  @makeSchema: (schema, prev = null) ->
    if not (schema instanceof Object)
      throw new AppError
        error: 'not_an_object'
        method: 'SimpleSchema.ctor'
    if schema instanceof Schema
      return schema
    if _isFunction schema
      return @makeOneSchema
        type: 'object'
        $init: schema
    if schema.type instanceof Array
      new OneOfSchema schema, prev
    else
      @makeOneSchema schema, prev

  @makeOneSchema: (schema, prev) ->
    if schema.$ref
      return @resolveSchema schema, prev
    switch schema.type
      when 'integer'
        new IntegerSchema schema, prev
      when 'number'
        new NumberSchema schema, prev
      when 'boolean'
        new BooleanSchema schema, prev
      when 'string'
        new StringSchema schema, prev
      when 'null'
        new NullSchema schema, prev
      when 'array'
        if schema.items instanceof Array
          new TupleSchema schema, prev
        else
          new ArraySchema schema, prev
      when 'function', 'procedure'
        new ProcedureSchema schema, prev
      when 'interface'
        new InterfaceSchema schema, prev
      else # default treat it as 'object'
        if schema.hasOwnProperty('additionalProperties')
          return new MapSchema schema, prev
        else
          new ObjectSchema schema, prev
  @resolveSchema: (schema, prev) ->
    current = 
      if schema.$ref instanceof Schema
        schema.$ref
      else
        prev.resolve schema.$ref
    current.specialize schema

  @setFormat: (fmt, checker) ->
    checkProc =
      if checker instanceof RegExp
        (v) ->
          v.match checker
      else if _isFunction checker
        checker
      else
        throw new AppError
          error: 'UnknownType'
          message: 'checker_must_be_function_or_regexp'
          method: 'Schema.setFormat'
          checker: checker
    formatConstraintMap[fmt] = checkProc

class NumberSchema extends Schema
  type: 'number'
  isType: (v) ->
    typeof(v) == 'number'
  valueConvert: (v, schemaPath) ->
    if typeof(v) == 'string'
      val = parseFloat v
      if val.toString() == v
        val
      else
        @invalidType v, schemaPath
    else
      @invalidType v, schemaPath
  @constraintMap:
    enum: EnumConstraint
    multipleOf: MultipleOfConstraint
    minimum: MinimumConstraint
    maximum: MaximumConstraint
  verifyBase: (baseSchema) ->
    if (baseSchema instanceof NumberSchema) and not (baseSchema instanceof IntegerSchema)
      return baseSchema
    else
      @invalidBaseType()
  specialize: (schema) ->
    keys = [
      'multipleOf',
      'minimum',
      'maximum',
      'exclusiveMaximum',
      'exclusiveMinimum'
    ]
    for key in keys
      if schema.hasOwnProperty key
        return new @constructor schema
    return @

class IntegerSchema extends NumberSchema
  type: 'integer'
  isType: (v) ->
    super(v) and Math.floor(v) == v
  valueConvert: (v, schemaPath) ->
    if typeof(v) == 'string'
      val = parseInt v
      if val.toString() == v
        val
      else
        @invalidType v, schemaPath
    else
        @invalidType v, schemaPath
  verifyBase: (baseSchema) ->
    Schema.prototype.verifyBase.call @, baseSchema

class BooleanSchema extends Schema
  type: 'boolean'
  isType: (v) ->
    typeof(v) == 'boolean'
  valueConvert: (v, schemaPath) ->
    if typeof(v) == 'string'
      if v == 'true'
        true
      else if v == 'false'
        false
      else
        @invalidType v, schemaPath
    else
      @invalidType v, schemaPath
  verifyBase: (baseSchema) ->
    @finalTypeNonDerivable()

class StringSchema extends Schema
  type: 'string'
  @constraintMap:
    enum: EnumConstraint
    minLength: MinLengthConstraint
    maxLength: MaxLengthConstraint
    pattern: PatternConstraint
    format: FormatConstraint
  isType: (v) ->
    typeof(v) == 'string' or v instanceof String
  valueConvert: (v) ->
    v.toString()

class NullSchema extends Schema
  type: 'null'
  isType: (v) ->
    v == null
  valueConvert: (v, schemaPath) ->
    if v == 'null'
      null
    else
      @invalidType v, schemaPath
  verifyBase: (baseSchema) ->
    @finalTypeNonDerivable()
  _toJSON: () ->
    constraint =
      if @hasOwnProperty('constraint')
        @constraint.toJSON()
      else
        {}
    schema =
      type: 'null'
    _extend schema, constraint

class MinItemsConstraint extends Constraint
  constructor: (@type) ->
    @minimum = @type.schema.minItems
  check: (v) ->
    v.length >= @minimum
  toJSON: () ->
    minItems: @minimum

class MaxItemsConstraint extends Constraint
  constructor: (@type) ->
    @maximum = @type.schema.maxItems
  check: (v) ->
    v.length <= @maximum
  toJSON: () ->
    maxItems: @maximum

class UniqueItemsConstraint extends Constraint
  constructor: (@type) ->
    @unique = @type.schema.uniqueItems
  _equal: (other) ->
    if not @type.equal other.type
      return false
    @unique == other.unique
  check: (v) ->
    if @unique
      for x, i in v
        for y, j in v 
          if i != j
            if @type.valueEqual x, y
              return false
      true
    else
      true
  toJSON: () ->
    unique: true

class ArraySchema extends Schema
  type: 'array'
  @constraintMap:
    enum: EnumConstraint
    minItems: MinItemsConstraint
    maxItems: MaxItemsConstraint
    uniqueItems: UniqueItemsConstraint
  constructor: (schema, prev) ->
    super schema, prev
    @item = Schema.makeSchema schema.items, @
  _equal: (other) ->
    @item.equal other.item
  isType: (v) ->
    if v instanceof Array
      for item in v
        if not @item.isa item
          return false
      true
    else
      false
  isOptional: () ->
    res = super()
    if res
      return true
    # if it has a min item == 0
    if not @constraint
      return true
    return false
  getDefaultValue: () ->
    if @schema.hasOwnProperty('defaultProc') or @schema.hasOwnProperty('default')
      super()
    else
      []
  valueConvert: (v, schemaPath) ->
    if typeof(v) == 'string' and @schema.hasOwnProperty('delim')
      values = v.split(@schema.delim)
      @valueConvert values, schemaPath
    else if v instanceof Array
      for item, i in v
        @item.convert item, schemaPath.push("$#{i}")
    else
      @invalidType v, schemaPath
  resolveName: (name) ->
    if name == '$'
      @item
    else
      @unknownProperty name
  verifyBase: (baseSchema) ->
    @finalTypeNonDerivable()
  _toJSON: () ->
    res = { items: @item.toJSON() }
    if @schema.hasOwnProperty 'delim'
      res.delim = @schema.delim
    res

class TupleSchema extends Schema
  type: 'tuple'
  constructor: (schema, prev) ->
    @items =
      for item in schema.items
        Schema.makeSchema item, @
    if schema.hasOwnProperty 'additionalItems'
      throw new AppError
        error: 'unsupportedSchemaProperty'
        property: 'additionalItems'
        schema: schema
    super schema, prev
  equal: (other) ->
    if @items.length != other.items.length
      return false
    for item, i in @items.length
      if not item.equal other.items[i]
        return false
    true
  baseLength: () ->
    if @hasOwnProperty '$base'
      @$base.items.length
    else
      0
  isType: (v) ->
    if v instanceof Array
      if @isRightLength v
        for item, i in @items
          if not item.isa v[i + @baseLength()]
            return false
        true
      else
        false
    else
      false
  isOptional: () ->
    res = super()
    if res
      return true
    for item in @items
      if not item.isOptional()
        return false
    true
  getDefaultValue: () ->
    if @schema.hasOwnProperty('defaultProc') or @schema.hasOwnProperty('default')
      super()
    else
      for item in @items
        item.getDefaultValue()
  isRightLength: (ary) ->
    ary.length >= @items.length + @baseLength()
  valueConvert: (v, schemaPath) ->
    if v instanceof Array
      @ensureLength v, schemaPath
      res = []
      for item, i in @items
        j = i + @baseLength()
        res.push item.convert v[j], schemaPath.push("${j}")
      return res
    else
      @invalidType v, schemaPath
  ensureLength: (ary, schemaPath) ->
    res = @isRightLength ary
    if not res
      throw new AppError
        error: 'invalidLength'
        schema: @schema
        path: schemaPath
        length: ary.length
  _toJSON: () ->
    res = super()
    res.items =
      for item in @items
        item.toJSON()
    res
  #resolveName: (name) ->

class ObjectSchema extends Schema
  type: 'object'
  constructor: (schema, prev) ->
    @properties =
      if schema.hasOwnProperty('properties')
        for key, val of schema.properties
          [ key , Schema.makeSchema val, @ ]
      else
        []
    super schema, prev
    if _isFunction schema.$init
      @$init = schema.$init
  equal: (other) ->
    if @properties.length != other.properties.length
      return false
    for [ key, val ], i in @properties
      [ otherKey, otherVal ] = other.properties[i]
      if key != otherKey
        return false
      if not val.equal otherVal
        return false
    true
  isType: (v) ->
    if @$init
      return v instanceof @$init
    if v instanceof Object
      for [ key , schema ] in @properties
        if not schema.isa v[key]
          return false
      true
    else
      false
  isOptional: () ->
    res = super()
    if res
      true
    for [ key, prop ] in @properties
      if not prop.isOptional()
        return false
    true
  getDefaultValue: () ->
    if @schema.hasOwnProperty('defaultProc') or @schema.hasOwnProperty('default')
      super()
    else
      res = {}
      for [ key, prop ] in @properties
        res[key] = prop.getDefaultValue()
      res
  valueConvert: (v, schemaPath = new SchemaPath()) ->
    if v instanceof Object
      res = {}
      for [ key, schema ] in @properties
        res[key] = schema.convert v[key], schemaPath.push(key)
      res
    else
      @invalidType v, schemaPath
  resolveName: (name) ->
    for [ key, val ] in @properties
      if key == name
        return val
    @unknownProperty name
  _toJSON: () ->
    res = super()
    res.properties = {}
    for [ key, item ] in @properties
      res.properties[key] = item.toJSON()
    res

class MapSchema extends Schema
  type: 'map'
  constructor: (schema, prev) ->
    super schema, prev
    @property = Schema.makeSchema schema.additionalProperties, @
  _equal: (other) ->
    @property.equal other.property
  isType: (v) ->
    for key, val of v
      if v.hasOwnProperty(key)
        if not @property.isa val
          return false
    true
  isOptional: () ->
    res = super()
    if res
      return true
    if not @constraint
      return true
    false
  getDefaultValue: () ->
    if @schema.hasOwnProperty('defaultProc') or @schema.hasOwnProperty('default')
      super()
    else
      {}
  valueConvert: (v, schemaPath) ->
    res = {}
    for key, val of v
      if v.hasOwnProperty(key)
        res[key] = @property.convert val, schemaPath.push(key)
    res
  resolveName: (name) ->
    name
  verifyBase: (baseSchema) ->
    @finalTypeNonDerivable()
  _toJSON: () ->
    res = super()
    res.additionalProperties = @property.toJSON()
    res

class OneOfSchema extends Schema
  type: 'oneOf'
  constructor: (schema, prev) -> # has multiple types.
    @items =
      for type in schema.type
        Schema.makeSchema _extend({}, schema, { type: type }), @
    super schema, prev
  _equal: (other) ->
    if @items.length != other.items.length
      return false
    for item, i in @items
      if not item.equal other.items[i]
        return false
    true
  isType: (v) ->
    for schema in @items
      if schema.isa v
        return true
    false
  isOptional: () ->
    res = super()
    if res
      return true
    for item in @items
      if item.isOptional()
        return true
    false
  getDefaultValue: () ->
    if @schema.hasOwnProperty('defaultProc') or @schema.hasOwnProperty('default')
      super()
    else
      for item in @items
        try
          return item.getDefaultValue()
        catch e
          continue
  valueConvert: (v, schemaPath) ->
    for schema, i in @items
      try
        return schema.convert v, schemaPath.push("${i}")
      catch e
        continue
    @invalidType v, schemaPath
  resolveName: (name) ->
    matched = name.match /^\$(\d+)$/
    if matched
      index = parseInt(matched[1])
      if 0 <= index and index < @items.length
        @items[index]
      else
        @unknownProperty(name)
    else
      @unknownProperty(name)
  verifyBase: (baseSchema) ->
    @finalTypeNonDerivable()
  _toJSON: () ->
    result = {}
    for item, i in @items
      json = item.toJSON()
      if i > 0
        result.type = [ json.type ]
      else
        result.type.push json.type
      delete json.type
      _extend result, json
    result

# all of is 
class AllOfSchema extends Schema
  type: 'allOf'
  constructor: (schema, prev) ->
    @items =
      for item in schema.allOf
        Schema.makeSchema inner, @
    super schema, prev
  _equal: (other) ->
    if @items.length != other.items.length
      return false
    for item, i in @items
      if not item.equal item.items[i]
        return false
    true
  isType: (v) ->
    for schema in @items
      if not schema.isa v
        return false
    true
  valueConvert: (v, schemaPath) -> # all of is weird when we are dealing with conversion, as it must convert everything.
    val = v
    for schema, i in @items
      val = schema.convert val, schemaPath.push("${i}")
    val
  _toJSON: () ->
    @schema


# this is used to only for annontated procedure, rather than arbitrary procedure validation.
# it doesn't handle *convert* procedures, nor does it handle 
# isa since javascript procedures are dynamic and therefore
# can only be annontated.

# { type: 'procedure|function'
#   name: 'thisIsTheNameOfProcedure'
#   params: [
#     { type: 'integer' } ... ],
#   restParams:
#     { type: 'number' } # cannot be type procedure.
#   returns: { type: 'boolean' }
#   async: true|false # if true, this function returns 
# }

class ProcedureSchema extends Schema
  type: 'procedure'
  constructor: (schema, prev) ->
    super schema, prev
    @params =
      for item in schema.params || []
        Schema.makeSchema item, @
    @restParams =
      if schema.restParams
        Schema.makeSchema schema.restParams, @
      else
        null
    if @restParams instanceof ProcedureSchema
      throw new AppError
        error: 'RestParamCannotBeProcedure'
        schema: schema
    @returns =
      if schema.returns
        Schema.makeSchema schema.returns, @
      else
        null
    @async = schema.async || false
    @arity = @getArity()
  _equal: (other) ->
    if @params.length != other.params.length
      return false
    for param, i in @params
      if not param.equal other.params[i]
        return false
    if @restParams
      if not @restParams.equal other.restParams
        return false
    if not @returns.equal other.returns
      return false
    if @async != other.async
      return false
    true
  isType: (v) ->
    if _isFunction v
      if v.hasOwnProperty('_schema')
        @equal v._schema
    else
      false
  equal: (schema) ->
    if schema instanceof ProcedureSchema
    else
      false
  convert: (v) ->
    throw new AppError
      error: 'notSupported'
      methd: 'ProcedureSchema.convert'
      schema: @schema
      value: v
  getArity: () ->
    min = 0
    for param in @params
      if param.isRequired()
        min++
    max = @params.length
    if @restParams
      # http://stackoverflow.com/questions/22747068/is-there-a-max-number-of-arguments-javascript-functions-can-accept
      max = 32767 - 1 # -1 is for the async parameter.
    { min: min, max: max }
  extractCallback: (args) ->
    if @arity.min == @arity.max # no optional + no rest params.
      if args.length == @arity.min
        [ args , undefined ]
      else if args.length > @arity.min and _isFunction args[args.length - 1 ]
        cb = args[args.length - 1]
        [ args.slice(0, args.length - 1), cb ]
      else
        [ args , undefined ]
    else if args.length <= @arity.min # if we only have the minimum of 
      [ args, undefined ]
    else if not _isFunction args[args.length - 1]
      [ args , undefined ]
    else
      cb = args[args.length - 1]
      [ args.slice(0, args.length - 1), cb ]
  validateArity: (args) ->
    if args.length < @arity.min
      throw new AppError
        error: 'arityErrorLessThanMin'
        arity: @arity
        args: args
        schema: @schema
    if args.length > @arity.max
      throw new AppError
        error: 'arityErrorGreaterThanMax'
        arity: @arity
        args: args
        schema: @schema
  fillHoles: (args) ->
    if @arity.min == @arity.max
      return args
    # the holes might exist in the middle...
    # the idea is that we'll ensure that they are only shifted
    # we want to fill all of the required fields.
    # then we'll leave the rest filled from left to right.
    # min is the number of required fields.
    # as long as it's greater than min, we could fill them accordingly.
    # what it means is that we should track of the list of the required fields
    # and ensure that we start to skip them once 
    #
    # a, b = 1, c, d = 2, e
    # => { min: 3, max: 5 }
    # [2, 3, 5] => [2, undefined, 3, undefined, 5]
    # to fill so, we need to keep track of how many remaining 
    remainRequired = @arity.min
    remainOptional = args.length - remainRequired
    counter = 0
    normalized = []
    for param, i in @params
      if param.isRequired()
        if remainRequired == 0 # should never happen
          throw new AppError
            error: 'requiredParamUnderflow'
            param: param
            args: args
            schema: @schema
        remainRequired--
        normalized.push args[counter++]
      else if remainOptional > 0
        normalized.push args[counter++]
        remainOptional--
      else
        normalized.push undefined
    if counter < args.length - 1
      if not @restParams
        throw new AppError
          error: 'ParameterOverflow'
          arity: arity
          args: args
          schema: @schema
      for j in [counter...args.length]
        normalized.push args[j]
    normalized
  validateArguments: (args) ->
    @validateArity args
    args = @fillHoles args
    path = new SchemaPath()
    normalized =
      for arg, i in args
        param = @params[i]
        if i < @params.length
          normed =
            if not param.isRequired() and arg == undefined
              param.getDefaultValue()
            else
              arg
          param.validate normed, path.push(i)
        else if @restParams
          @restParams.validate arg, path.push(i)
    normalized
  makeFunction: (proc) ->
    schemaObj = @
    if schemaObj.async == 'promise'
      Func = (args...) ->
        [ extracted , _callback ] = schemaObj.extractCallback args
        self = @
        if _isFunction _callback
          try
            normalized = schemaObj.validateArguments extracted
            proc.apply(self, normalized)
              .then (res) ->
                if schemaObj.returns
                  schemaObj.returns.validate res
                res
              .then (res) ->
                _callback null, res
              .catch (e) ->
                _callback e
          catch e
            _callback e
        else
          Promise.try ->
              schemaObj.validateArguments extracted
            .then (normalized) ->
              proc.apply(self, normalized)
            .then (res) ->
              if schemaObj.returns
                schemaObj.returns.validate res
              res
    else if schemaObj.async
      Func = (args...) ->
        [ extracted , _callback ] = schemaObj.extractCallback args
        self = @
        if _isFunction _callback
          try
            normalized = schemaObj.validateArguments extracted
            proc.call self, normalized..., (err, res) ->
              if err
                _callback err
              else
                try
                  if schemaObj.returns
                    schemaObj.returns.validate res
                  _callback null, res
                catch e
                  _callback e
          catch e
            _callback e
        else
          Promise.try ->
            schemaObj.validateArguments extracted
          .then (normalized) ->
            new Promise (resolve, reject) ->
              proc.call self, normalized..., (err, res) ->
                if err
                  reject err
                else
                  try
                    if schemaObj.returns
                      schemaObj.returns.validate res
                    resolve res
                  catch e
                    reject e

    else
      Func = (args...) ->
        normalized = schemaObj.validateArguments args
        #console.log 'Func.normalized', normalized
        res = proc.apply @, normalized
        if schemaObj.returns
          schemaObj.returns.validate res
        res
    Func._schema = schemaObj
    Func

class InterfaceSchema extends ObjectSchema
  type: 'interface'
  constructor: (schema, prev) ->
    super schema, prev
    if not schema.hasOwnProperty('$init')
      throw new AppError
        error: 'RequiredParameter'
        name: '$init'
        method: 'InterfaceSchema.ctor'
    @$init = Schema.makeSchema schema.$init, @
    if not schema.hasOwnProperty('$init')
      throw new AppError
        error: 'RequiredParameter'
        name: '$prototype'
        method: 'InterfaceSchema.ctor'
    @$prototype =
      for key, val of schema.$prototype or {}
        [ key, Schema.makeSchema val, @ ]
  implement: (obj) -> ## TO be implemented...
    if not obj.hasOwnProperty('$init')
      throw new AppError
        error: 'RequiredParameter'
        name: '$prototype'
        method: 'InterfaceSchema.implement'
    # we need to create a new schema.
    # 1 - gather the propertie schema.

module.exports = Schema

