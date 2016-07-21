{ assert } = require 'chai'
Schema = require '../src/schema'
uuid = require 'uuid'

describe 'schema test', ->
  
  describe 'integer schema test', ->

    it 'can convert integer', ->
      schema = Schema.makeSchema { type: 'integer' }
      assert.equal 1, schema.convert(1)
      assert.equal 1, schema.convert '1'

    it 'can validate integer', ->
      schema = Schema.makeSchema { type: 'integer' }
      assert.ok schema.isa 1
      assert.notOk schema.isa '1'
      assert.notOk schema.isa 1.2

    it 'can handle integer enum', ->
      schema = Schema.makeSchema
        type: 'integer'
        enum: [
          10,
          22,
          '33'
        ]
      assert.ok schema.isa 10
      assert.ok schema.isa 33
      assert.notOk schema.isa 12

    it 'can handle integer multipleOf', ->
      schema = Schema.makeSchema
        type: 'integer'
        multipleOf: 10
      assert.ok schema.isa 10
      assert.ok schema.isa 40
      assert.notOk schema.isa 12
      assert.deepEqual schema.toJSON(),
        type: 'integer'
        multipleOf: 10

    it 'can handle integer minimum', ->
      schema = Schema.makeSchema
        type: 'integer'
        minimum: 10
      assert.ok schema.isa 10
      assert.ok schema.isa 40
      assert.notOk schema.isa 9
      assert.deepEqual schema.toJSON(),
        type: 'integer'
        minimum: 10

    it 'can handle integer minimum exclusive', ->
      schema = Schema.makeSchema
        type: 'integer'
        minimum: 10
        exclusiveMinimum: true
      assert.ok schema.isa 11
      assert.ok schema.isa 40
      assert.notOk schema.isa 10
      assert.deepEqual schema.toJSON(),
        type: 'integer'
        minimum: 10
        exclusiveMinimum: true

    it 'can handle integer maximum', ->
      schema = Schema.makeSchema
        type: 'integer'
        maximum: 50
      assert.ok schema.isa 11
      assert.ok schema.isa 40
      assert.notOk schema.isa 51
      assert.deepEqual schema.toJSON(),
        type: 'integer'
        maximum: 50

    it 'can handle integer maximum exclusive', ->
      schema = Schema.makeSchema
        type: 'integer'
        maximum: 50
        exclusiveMaximum: true
      assert.ok schema.isa 11
      assert.ok schema.isa 49
      assert.notOk schema.isa 50
      assert.deepEqual schema.toJSON(),
        type: 'integer'
        maximum: 50
        exclusiveMaximum: true

    it 'can handle integer base schema', ->
      base = Schema.makeSchema
        type: 'integer'
        maximum: 20
      derived = Schema.makeSchema
        $base: base
        type: 'integer'
        minimum: 15
      assert.ok derived.isa 15
      assert.ok derived.isa 20
      assert.notOk derived.isa 14
      assert.notOk derived.isa 21
      assert.deepEqual derived.toJSON(),
        allOf: [
          {
            type: 'integer'
            maximum: 20
          }
          {
            type: 'integer'
            minimum: 15
          }
        ]

    it 'can handle schema equality', ->
      foo = Schema.makeSchema
        type: 'integer'
      bar = Schema.makeSchema
        type: 'integer'
      assert.ok foo.equal bar
      assert.ok foo.equal foo
      
      baz = Schema.makeSchema
        type: 'integer'
        multipleOf: 2

      baw = Schema.makeSchema
        type: 'integer'
        multipleOf: 2

      assert.ok baz.equal baw
      assert.notOk baz.equal foo

      enum1 = Schema.makeSchema
        type: 'integer'
        enum: [1, 2, 3, 5]

      enum2 = Schema.makeSchema
        type: 'integer'
        enum: [1, 2, 3, 5]

      assert.ok enum1.equal enum2


  describe 'number schema test', ->

    it 'can convert number', ->
      schema = Schema.makeSchema { type: 'number' }
      assert.equal 1, schema.convert 1
      assert.equal 1, schema.convert '1'

    it 'can validate number', ->
      schema = Schema.makeSchema { type: 'number' }
      assert.ok schema.isa 1
      assert.notOk schema.isa '1'
      assert.ok schema.isa 1.2

    it 'can handle number enum', ->
      schema = Schema.makeSchema
        type: 'number'
        enum: [
          10,
          22.5,
          '33'
        ]
      assert.ok schema.isa 10
      assert.ok schema.isa 22.5
      assert.ok schema.isa 33
      assert.notOk schema.isa 12

    it 'can handle number multipleOf', ->
      schema = Schema.makeSchema
        type: 'number'
        multipleOf: 10
      assert.ok schema.isa 10
      assert.ok schema.isa 40
      assert.notOk schema.isa 12

    it 'can handle number minimum', ->
      schema = Schema.makeSchema
        type: 'number'
        minimum: 10
      assert.ok schema.isa 11
      assert.ok schema.isa 40
      assert.notOk schema.isa 9

    it 'can handle number maximum', ->
      schema = Schema.makeSchema
        type: 'number'
        maximum: 50
      assert.ok schema.isa 11
      assert.ok schema.isa 40
      assert.notOk schema.isa 51

    it 'can handle number base schema', ->
      base = Schema.makeSchema
        type: 'number'
        minimum: 10
      derived = Schema.makeSchema
        $base: base
        type: 'number'
        maximum: 20
      assert.ok derived.isa 10
      assert.ok derived.isa 19.99
      assert.notOk derived.isa 9.9
      assert.notOk derived.isa 20.1

  describe 'boolean schema test', ->
    it 'can convert boolean', ->
      schema = Schema.makeSchema { type: 'boolean' }
      assert.equal true, schema.convert true
      assert.equal false, schema.convert 'false'

    it 'can validate boolean', ->
      schema = Schema.makeSchema { type: 'boolean' }
      assert.ok schema.isa true
      assert.notOk schema.isa 'true'
      assert.ok schema.isa false

    it 'can handle boolean enum', ->
      schema = Schema.makeSchema
        type: 'boolean'
        enum: [ true ]
      assert.ok schema.isa true
      assert.notOk schema.isa false

    it 'cannot derive boolean schema', ->
      base = Schema.makeSchema
        type: 'boolean'
      assert.throws ->
        derived = Schema.makeSchema
          $base: base
          type: 'boolean'

  describe 'string schema test', ->
    it 'can convert boolean', ->
      schema = Schema.makeSchema { type: 'string' }
      assert.equal 'hello', schema.convert 'hello'
      assert.equal 'false', schema.convert false

    it 'can validate string', ->
      schema = Schema.makeSchema { type: 'string' }
      assert.ok schema.isa 'hello'
      assert.notOk schema.isa true
      assert.ok schema.isa '1'

    it 'can handle string enum', ->
      schema = Schema.makeSchema
        type: 'string'
        enum: [ 'red', 'blue', 'yellow', 'white' ]
      assert.ok schema.isa 'red'
      assert.ok schema.isa 'yellow'
      assert.notOk schema.isa 'hello'

    it 'can handle string min length', ->
      schema = Schema.makeSchema
        type: 'string'
        minLength: 3
      assert.ok schema.isa 'abc'
      assert.notOk schema.isa 'ab'
      assert.ok schema.isa 'abcd'

    it 'can handle string max length', ->
      schema = Schema.makeSchema
        type: 'string'
        maxLength: 3
      assert.ok schema.isa 'abc'
      assert.ok schema.isa 'ab'
      assert.notOk schema.isa 'abcd'

    it 'can handle string pattern', ->
      schema = Schema.makeSchema
        type: 'string'
        pattern: /^\d\d\d-?\d\d-?\d\d\d\d$/
      assert.ok schema.isa '123456789'
      assert.ok schema.isa '123-45-6789'
      assert.notOk schema.isa '1234567890'

    it 'can handle string with format constraint (date)', ->
      schema = Schema.makeSchema
        type: 'string'
        format: 'date-time'
      assert.ok schema.isa '2016-08-01T00:00:00Z'
      assert.ok schema.isa (new Date()).toISOString()

    it 'can handle string with format constraint (uuid)', ->
      schema = Schema.makeSchema
        type: 'string'
        format: 'uuid'
      id1 = uuid.v4()
      console.log 'string format id1', id1
      assert.ok schema.isa id1
 
    it 'can handle custom format constraint', ->
      Schema.setFormat 'ssn', /^\d{3}-?\d{2}-?\d{4}$/
      schema = Schema.makeSchema
        type: 'string'
        format: 'ssn'
      assert.ok schema.isa '123456789'
      assert.ok schema.isa '123-45-6789'
      assert.notOk schema.isa '12345678'

  describe 'null schema test', ->
    it 'can convert null', ->
      schema = Schema.makeSchema { type: 'null' }
      assert.equal null, schema.convert null
      assert.equal null, schema.convert 'null'

    it 'can validate null', ->
      schema = Schema.makeSchema { type: 'null' }
      assert.ok schema.isa null
      assert.notOk schema.isa 'null'

    it 'cannot derive null schema', ->
      base = Schema.makeSchema
        type: 'null'
      assert.throws ->
        derived = Schema.makeSchema
          $base: base
          type: 'null'

  describe 'array schema test', ->
    it 'can convert array', ->
      intSchema = Schema.makeSchema { type: 'integer' }
      schema = Schema.makeSchema { type: 'array', items: intSchema, delim: ',' }
      assert.deepEqual [ 1 , 2 , 3 ], schema.convert ['1', '2', '3']
      assert.deepEqual [ 4 , 5 , 6 ], schema.convert '4,5,6'
      assert.deepEqual schema.toJSON(),
        type: 'array'
        items: { type: 'integer' }
        delim: ','

    it 'can validate array', ->
      schema = Schema.makeSchema { type: 'null' }
      assert.ok schema.isa null
      assert.notOk schema.isa 'null'

    it 'can validate min items', ->
      schema = Schema.makeSchema
        type: 'array'
        items:
          type: 'integer'
        minItems: 2
      assert.ok schema.isa [1, 2]
      assert.notOk schema.isa [1]
      assert.deepEqual schema.toJSON(),
        type: 'array'
        items:
          type: 'integer'
        minItems: 2

    it 'can validate max items', ->
      schema = Schema.makeSchema
        type: 'array'
        items:
          type: 'integer'
        maxItems: 3
      assert.ok schema.isa [1, 2, 3]
      assert.notOk schema.isa [1, 2, 3, 4]

    it 'can validate unique items', ->
      schema = Schema.makeSchema
        type: 'array'
        items:
          type: 'integer'
        uniqueItems: true
      assert.ok schema.isa [1, 2, 3]
      assert.ok schema.isa [1, 2, 3, 4]
      assert.notOk schema.isa [1, 2, 3, 4, 3]
      
    it 'cannot derive array schema', ->
      base = Schema.makeSchema
        type: 'array'
        items:
          type: 'number'
      assert.throws ->
        derived = Schema.makeSchema
          $base: base
          type: 'array'
          items:
            type: 'integer'

  describe 'tuple schema test', ->
    schema = Schema.makeSchema { type: 'array', items: [ { type: 'integer' }, { type: 'number' } ] }
    
    it 'can convert tuple', ->
      assert.deepEqual [ 1 , 2 ], schema.convert ['1', '2' ]
      assert.throws ->
        schema.convert ['hello','world']

    it 'can validate tuple', ->
      assert.ok schema.isa [ 1, 2.2 ]
      assert.notOk schema.isa [ 1, false ]

    it 'can handle derived tuple', ->
      derived = Schema.makeSchema
        $base: schema
        type: 'array'
        items: [
          { type: 'boolean' }
          { type: 'string' }
        ]
      assert.ok derived.isa [ 1 , 2 , true, 'hello' ]
      assert.notOk derived.isa [ true, 'hello' ]
      assert.ok derived.isa [ 1 , 2 , true, 'hello' , false ] # this is a weird rule - the same as derived objects.

  describe 'object schema test', ->
    schema = Schema.makeSchema
      type: 'object'
      properties:
        foo:
          type: 'integer'
        bar:
          type: 'array'
          items:
            type: 'boolean'
    it 'can convert object', ->
      assert.deepEqual { foo: 1, bar: [ true, false ] }, schema.convert { foo: '1', bar: [ 'true', false ] }

    it 'can validate tuple', ->
      assert.ok schema.isa { foo: 1, bar: [ true, false ] }

    it 'can handle derived object schema', ->
      derived = Schema.makeSchema
        $base: schema
        type: 'object'
        properties:
          baz:
            type: 'boolean'
          baw:
            type: 'string'
      assert.ok derived.isa { foo: 1, bar: [ true, false ], baz: true, baw: 'hello' }
      assert.notOk derived.isa { foo: 1, bar: [ true, false ], baz: 12, baw: 'hello' }
      assert.notOk derived.isa { foo: 1, bar: [ true, false ] }
      assert.ok derived.isa { foo: 1, bar: [ true, false ], baz: true, baw: 'hello', xyz: 'more prop than defined is okay' }

  describe 'map schema test', ->
    schema = Schema.makeSchema
      type: 'object'
      additionalProperties:
        type: 'string'

    it 'can convert map', ->
      assert.deepEqual { foo: '1', bar: '2', baz: 'hello' }, schema.convert { foo: '1', bar: '2', baz: 'hello' }

    it 'can validate map', ->
      assert.ok schema.isa { foo: '1', bar: '2', baz: 'hello' }

    it 'cannot derive map schema', ->
      base = Schema.makeSchema
        type: 'object'
        additionalProperties:
          type: 'number'
      assert.throws ->
        derived = Schema.makeSchema
          $base: base
          type: 'object'
          additionalProperties:
            type: 'integer'

  describe 'one of schema test', ->
    schema = Schema.makeSchema
      type: ['object', 'null']
      properties:
        foo:
          type: 'integer'
        bar:
          type: 'array'
          items:
            type: 'boolean'
    it 'can convert oneof', ->
      assert.deepEqual { foo: 1, bar: [ true, false ] }, schema.convert { foo: '1', bar: [ 'true', false ] }
      assert.deepEqual null, schema.convert 'null'

    it 'can validate oneof', ->    
      assert.ok schema.isa { foo: 1, bar: [ true, false ] }
      assert.ok schema.isa null

    it 'cannot derive one of schema', ->
      base = Schema.makeSchema
        type: ['object', 'null']
        additionalProperties:
          type: 'number'
      assert.throws ->
        derived = Schema.makeSchema
          $base: base
          type: ['integer']

  describe 'schema make class test', ->
    it 'can manually create object with $class property', ->
      schema = Schema.makeSchema
        type: 'string'
        format: 'date-time'
        $class: Date
      assert.ok schema.convert('2016-08-01T00:00:00Z') instanceof Date
      assert.ok schema.isa new Date()

    it 'can make class', ->
      Foo = Schema.makeClass {
        properties:
          foo:
            type: 'integer'
          bar:
            type: 'number'
      },
      (options) ->
        @foo = options.foo
        @bar = options.bar
      foo = Foo { foo: 1 , bar: 2 }
      assert.equal foo.foo, 1
      assert.equal foo.bar, 2

      assert.throws ->
        Foo { foo: 1 }

      assert.throws ->
        Foo { bar: 2 }

      assert.throws ->
        Foo { foo: 'hello' }
  
    it 'can make use of $init', ->
      Foo = Schema.makeClass {
        properties:
          foo:
            type: 'integer'
          bar:
            type: 'number'
      },
      (options) ->
        @result = options.foo + options.bar

      foo = Foo { foo: 1, bar: 2 }
      assert.equal foo.result, 3

    it 'can make use of $prototype', ->
      Foo = Schema.makeClass {
          properties:
            foo:
              type: 'integer'
            bar:
              type: 'number'
        },
        (options) -> @result = options.foo + options.bar,
        {
          sayHello: () ->
            say: 'hello'
            object: @
        }
      foo = new Foo { foo: 1, bar: 2 }
      assert.deepEqual foo.sayHello(), { say: 'hello', object: foo }

    it 'can make use of $base', ->
      Foo = Schema.makeClass
        properties:
          foo:
            type: 'integer'
          bar:
            type: 'number'
      Bar = Schema.makeClass
        $base: Foo # this is a Schema-validated class, but not a schema object itself.
        properties:
          baz:
            type: 'boolean'

      foo = Foo { foo: 1, bar: 2 }
      bar = Bar { foo: 1, bar: 2, baz: true }

    it 'can make use of $base (schema object)', ->
      Foo = Schema.makeSchema
        properties:
          foo:
            type: 'integer'
          bar:
            type: 'number'
      Bar = Schema.makeClass
        $base: Foo # this is a schema object.
        properties:
          baz:
            type: 'boolean'

      foo = Foo.$class { foo: 1, bar: 2 }
      bar = Bar { foo: 1, bar: 2, baz: true }

  describe 'procedure function schema test', ->

    it 'can create schema procedure/function', ->
      test = Schema.makeFunction {
          params:
            [
              {
                type: 'integer'
              }
              {
                type: 'integer'
              }
            ]
          returns:
            type: 'integer'
        },
        (a, b) -> a + b
      assert.equal test(1, 2), 3
      assert.throws ->
        test(1)
      assert.throws ->
        test(1, 2, 3)
      assert.throws ->
        test('hello')
      assert.throws ->
        test true, false

    it 'can handle returns failures', ->
      test = Schema.makeFunction {
          params:
            [
              {
                type: 'integer'
              }
              {
                type: 'integer'
              }
            ]
          returns:
            type: 'integer'
        },
        (a, b) -> 'a string is not an int'
      assert.throws ->
        test 1, 2

    it 'can deal with optional parameters', ->
      test = Schema.makeFunction {
          params:
            [
              {
                type: 'integer'
              }
              {
                type: 'boolean'
                default: true
              }
              {
                type: 'integer'
              }
              {
                type: 'boolean'
                default: false
              }
              {
                type: 'integer'
              }
            ]
          returns:
            type: 'integer'
        },
        (a, b, c, d, e) ->
          a + c + e
      assert.equal test(1, 2, 3), 6
      assert.throws ->
        test(1)
      assert.throws ->
        test('hello')
      assert.throws ->
        test true, false

    it 'can handle rest parameters', ->
      test = Schema.makeFunction {
          params:
            [
              {
                type: 'integer'
              }
              {
                type: 'integer'
              }
            ]
          restParams:
            type: 'string'
          returns:
            type: 'integer'
        },
        (a, b, strs...) ->
          res = a + b + strs.join('').length
          console.log 'call.inner', a, b, strs, res
          res
      console.log 'rest param schema created'
      assert.equal test(1, 2, 'hello','world'), 13
      assert.throws ->
        test(1)
      assert.throws ->
        test('hello')
      assert.throws ->
        test true, false

    it 'can create async function', (done) ->
      test = Schema.makeFunction {
          params:
            [
              {
                type: 'integer'
              }
              {
                type: 'integer'
              }
            ]
          async: true
          returns:
            type: 'integer'
        },
        (a, b, cb) ->
          cb null, a + b
      test(1, 2)
        .then (res) ->
          assert.equal res, 3
        .then ->
          test 3, 4, (err, res) ->
            try
              assert.equal res, 7
              done null
            catch e
              done e
        .catch done

    it 'can create async promise function', (done) ->
      test = Schema.makeFunction {
          params:
            [
              {
                type: 'integer'
              }
              {
                type: 'integer'
              }
            ]
          async: 'promise'
          returns:
            type: 'integer'
        },
        (a, b) ->
          new Promise (resolve) ->
            resolve a + b
      test(1, 2)
        .then (res) ->
          assert.equal res, 3
        .then ->
          test 3, 4, (err, res) ->
            try
              assert.equal res, 7
              done null
            catch e
              done e
        .catch done

    it 'can create async function with optional param', (done) ->
      test = Schema.makeFunction {
          params:
            [
              {
                type: 'integer'
              }
              {
                type: 'boolean'
                default: true
              }
              {
                type: 'integer'
              }
            ]
          async: true
          returns:
            type: 'integer'
        },
        (a, b, c, cb) ->
          cb null, a + c
      test(1, 2)
        .then (res) ->
          assert.equal res, 3
        .then ->
          test 3, 4, (err, res) ->
            try
              assert.equal res, 7
              done null
            catch e
              done e
        .catch done

    it 'can create async function with optional param and rest params', (done) ->
      test = Schema.makeFunction {
          params:
            [
              {
                type: 'integer'
              }
              {
                type: 'boolean'
                default: true
              }
              {
                type: 'integer'
              }
            ]
          restParams:
            type: 'string'
          async: true
          returns:
            type: 'integer'
        },
        (a, b, c, strs..., cb) ->
          cb null, a + c + strs.join('').length
      test(1, 2)
        .then (res) ->
          assert.equal res, 3
        .then ->
          # optional and rest parameters do not interact well... especially when we
          # separate out the way they are written.
          test 3, undefined, 4, 'hello', 'world', (err, res) ->
            try
              assert.equal res, 17
              done null
            catch e
              done e
        .catch done

  ###
  describe 'interface test', ->
    Animal = null
    it 'can create interface', ->
      Animal = Schema.makeSchema
        type: 'interface'
        properties:
          type:
            type: 'string'
        $init:
          type: 'function'
          params: [
            { type: [ 'string', 'null' ], default: null }
          ]
        $prototype:
          talk:
            type: 'function'
            params: []
            returns:
              type: 'string'

    it 'can implement interface', ->
      Cat = Animal.implement
        $init: (@name) ->
          @type = 'cat'
        $prototype:
          talk: () ->
            if @name
              'meow, my name is ' + @name
            else
              'meow'

      garfield = new Cat('Garfield')
      assert.equal 'meow, my name is Garfield', garfield.meow()
  ###

