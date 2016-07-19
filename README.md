# Schemalet - a JSON-Schema based Design-By-Contract system.

Schemalet leverages [JSON-Schema](http://json-schema.org) as a Design-By-Contract system.

## Install

    npm install schemalet

## Usage

The first thing is to `require` it in your code.

    var Schema = require('schemalet');

Once required, you can create schema objects as follows:

    var intSchema = Schema.makeSchema({
      type: 'integer'
    });
    // validate an integer. checking *is-a* relationship.
    var result = intSchema.isa(1); // true
    var result = intSchema.isa(1.5); // false
    var result = intSchema.isa(false); // false
    var result = intSchema.isa('not a number'); // false

You can also "convert" other values into the type you are expecting.

    var result = intSchema.convert('10'); // => 10
    var result = intSchema.convert('not a number'); // error not an integer.

`.convert` can be extended - this though is yet to be implemented.

All the basic types of JSON-Schemas - `integer`, `number`, `boolean`, `string`, `null`, `array`, and `objects` are available.

    var numSchema = Schema.makeSchema({
      type: 'number'
    });

    var booleanSchema = Schema.makeSchema({
      type: 'boolean'
    });

    var nullSchema = Schema.makeSchema({
      type: 'null'
    });

    var stringSchema = Schema.makeSchema({
      type: 'string'
    });

    var arrayOfStringSchema = Schema.makeSchema({
      type: 'array',
      items: {
        type: 'string'
      }
    });

    var objSchema = Schema.makeSchema({
      type: 'object', // this is also the default if unspecified.
      properties: {
        foo: {
          type: 'integer'
        },
	bar: {
	  type: 'string'
        }
      }
    });

Instead of explicitly write out the schema spec, with Schemalet you can reuse the previous definition by just refering to the object (i.e. no `$ref` needed).

    var arrayOfStringSchema = Schema.makeSchema({
      type: 'array',
      items: stringSchema // previously defined.
    });
    arrayOfStringSchema.isa(['hello','how','are','you']); // ==> true
    arrayOfStringSchema.isa([1,2,3,4]); // ==> false
    arrayOfStringSchema.convert([1,2,3,4]); // ==> [ '1', '2', '3', '4' ]

    var objSchema = Schema.makeSchema({
      type: 'object',
      properties: {
        foo: intSchema, // previously defined.
        bar: stringSchema // previously defined.
      }
    });
    objSchema.isa({ foo: 1, bar: 'hello' }); // ==> true.

    objSchema.convert({ foo: '1', bar: 'hello' }); // ==> { foo: 1, bar: 'hello' }

### Validation vs. Conversion

Validation (via `.isa`) and conversion (via `.convert`) differ in the following:

1. Validation assumes that the passed in value is of the same type structure as the expected type. Conversion - as long as the passed in type has a defined conversion routine, can be converted into the target type.

2. `.isa` returns a `true` or `false` result and hence doesn't do anything to modify the passed-in value. `.convert` on the other hand, returns the converted result or throws an error. It would also fill in the fields that have default values specified. It would not modify the original argument either.

### Function/Procedure Contracts

Given that JSON-schema is meant for validation, Schemalet extends JSON-Schema to provide the validation for function parameters and return values.

A basic function contract looks like the following:

    {
      type: 'function',
      params: [
        <JSON schema for param>, ...
      ],
      restParam: <JSON schema for the "rest" parameters>, // can be unspecified.
      returns: <JSON schema for returned value>, // can be unspecified.
      async: 'promise' || true || false, // can be unspecified, default to false
    }

The `type` property for a function contract can either be `'function'` or `'procedure'`.

The `params` property is an array of JSON schemas, with each schema mapping to a parameter.

The `restParam` property denotes a JSON schema for the "rest" parameter, i.e. a function with variable number of parameters at the end.

The `returns` property is another JSON schema object that denotes the type of the returned value. When it's not specified, it defaults to no validation, which can be used for either the "void" type, or bypassing validation.

The `async` property denotes whether this function is considered an "async" function. If it's `'promise'`, it's expected that you write a function that returns a promise. If it's `true`, it's expected that you write a function that takes a callback procedure at the end. If it's `false`, it's not an async function.

Note that whether the function is async, the callback procedure or the promise doesn't need to be specified as part of the parametesr.

This is a simple example of a sync function that takes two numbers and add them together.

    var add = Schemalet.makeFunction({
      type: 'procedure',
      params: [
        {
	  type: 'number'
	},
	{
	  type: 'number'
	}
      ],
      returns: {
      	type: 'number'
      }
    }, function (a, b) { return a + b });

    // add(1, 2); // ==> 3
    // add(1, 2.5); // ==> 3.5
    // add(1, 'not a number'); // error param #2 not a number.

As usual, since we are now writing code rather than specifying JSON, we can reuse the schema by defining a variable to hold it.

    var num2Num2Num = Schema.makeSchema({ // num -> num -> num
      type: 'procedure',
      params: [
      	numSchema, // see above for numSchema
	numSchema
      ],
      returns: numSchema
    });

    var add2 = Schema.makeFunction(num2Num2Num, function (a, b) { return a + b; });
    var minus2 = Schema.makeFunction(num2Num2Num, function (a, b) { return a - b; });
    var mult2 = Schema.makeFunction(num2Num2Num, function (a, b) { return a * b; });

This is a simple callback-based async function that wraps around `fs.readFile`. Note that there are two parameters (instead of 3), and the second parameter has a `default` property, which marks it optional.

    var readFile = Schema.makeFunction({
      type: 'function',
      params: [
        {
          type: 'string',
	},
        {
	  type: 'string',
	  default: 'utf8'
	}
      ],
      async: true, // which means the function would takes in a callback.
      returns: { type: 'string' } // we'll deal with return of Buffer later.
    }, function (filePath, option, cb) {
      return fs.readFile(filePath, option, cb);
    });

Below is the same wrapper for `fs.readFile` but returns a promise instead of expecting a callback. Both are supported for people who likes to write different type of code.

    var readFile = Schema.makeFunction({
      type: 'function',
      params: [
        {
          type: 'string',
	},
        {
	  type: 'string',
	  default: 'utf8'
	}
      ],
      async: 'promise', // which means the function would takes in a callback.
      returns: { type: 'string' } // we'll deal with return of Buffer later.
    }, function (filePath, option) {
      return new Promise(function (resolve, reject) {
        fs.readFile(filePath, option, function (err, data) {
          if (err) {
            return reject(err);
          } else {
            return resolve(data);
          }
	});
      });
    });
 
In both cases, the created function can be used with either style:

    // callback style.
    readFile(<filePath>, <option>, function (err, data) {
      if (err) { ... }
      else { ... }
    });

    // promise style.
    readFile(<filePath>, <option>)
      .then(function (data) { ... })
      .catch(function (e) { ... });

And given that the schema for the second parameter has the property of `default: 'utf8'`, it becomes an optional parameter.

    // callback style.
    readFile(<filePath>, function (err, data) {
      if (err) { ... }
      else { ... }
    });

    // promise style.
    readFile(<filePath>)
      .then(function (data) { ... })
      .catch(function (e) { ... });

If we end up adding an additional parameter, it will error out with max arity exceeded error.

    readFile(<filePath>, <option>, <junk param>, function (err, data) {
      if (err) // this will be triggered since a junk param is specified.
    });
    
    readFile(<filePath>, <option>, <junk param>)
      .then(function (data) { ... }) // this will be skipped.
      .catch(function (e) { /* this will be triggered with the arity error */ });

Here's an example with `restParam` specified - in the example we will add the first two number, and then add any additional numbers that are passed in.

    var addAtLeast2 = Schema.makeFunction({
      type: 'function',
      params: [
        { type: 'number' },
	{ type: 'number' }
      ],
      restParam: { type: 'number' },
      returns: { type: 'number' }
    }, function (a, b, rest) { // notice rest is now sliced out as an array, rather than kept in the arguments as multiple parameters.
      return rest.reduce(function (acc, n) {
        return acc + n;
      }, a + b);
    });
    addAtLeast2(1, 2, 3, 4, 5, 6, 7) // ==> 28


### Rule of Parameter Matching

Note that given the dynamic nature of Javascript, there are some interaction issues between the optional params, rest param, and the callback. When they are used together, it can be difficult to see how the parameters get matched.

1. The minimum arity is determined by the number of the required parameters. If the number of passed-in parameters are fewer than the minimum arity, error out.
2. The maximum arity is determined by the number of the required parameters + the optional parameters + the rest parameters. When rest parameters are allowed, it is capped at a maximum of 32766.
3. If the procedure is async, and the total number of parameters exceeds at least the minimum arity, and the last parameter is a function, it would be treated as a callback (i.e. callback is matched before optional parameters and rest parameters).
4. Once the callback is extracted from the parameters, the remaining parameters are matched from left to right against the parameter list. Depending on how many "holes" (the difference between the number of passed-in parameters against the maximum parameters) - the holes will be filled in via the default values of the parameter from left to right, so the required parameters will get the correct value.

I.e. given the following parameters:

```
[ { type: 'integer' },
  { type: 'integer', default: 2 },
  { type: 'integer' },
  { type: 'integer', default 4 },
  { type: 'integer' }
]
```

The following are the outcomes:

```
(1) ==> error - less than minimum arity, which is 3.
(1, 3) ==> error - less than minimum arity, which is 3.
(1, 3, 5) ==> normalized to (1, 2, 3, 4, 5) by filling in with the default of 2 and 4 into the 2nd and the 4th positions.
(1, 3, 5, 7) ==> normalized to (1, 3, 5, 4, 7) by filling in with the default of 4 at the 4th position.
```

## Object-Oriented Programming with Schemalet

Given that Schemalet can wrap around the definition of functions, and that functions are the building block of OOP in JavaScript, Schemalet can also be used as
class constructors. When we think of each schema definition as a class, it becomes apparent on how it can be constructed.

```
var Foo = Schema.makeClass({
  properties: {
    foo: { type: 'integer' },
    bar: { type: 'array', items: { type: 'string' } }
  }
  $init: function (options) { // NOTE The $init expression. This defines the inner initialization function.
    this.foo = options.foo; // guaranteed to be type of integer
    this.bar = options.bar; // guaranteed to be type of array of integer.
  }
});

var foo = new Foo({ foo: 1, bar: ['hello', 'world' ] });

var schema = Foo.getSchema(); // returns the defined schema object.

```

Unlike `Schema.makeSchema`, which returns a `Schema` object, `Schema.makeClass` returns a constructor function that you can use for constructing an object of the type. The embedded schema can be accessed via `<ConstructorFunction>.getSchema()` (it's attached as `_$schema` property, but do not rely on that as it's an internal detail).

The `$init` param defines the initializer routine of the class. When it's not defined, `Schema.makeClass` supplies its own. The arguments of the `$init` function would have already been validated by the time `$init` is called. I.e. if the arguments do not pass the schema validation, the initializer is never called.

Though you can use any schema type for this purpose, given that JavaScript doesn't handle primitive object inheritance well besides `Object`, currently there are no support to help make inheritance from `number`, `string`, `boolean`, and `array` work.

You can also create a multi-parameter class with function signature, like this:

```
var Point = Schema.makeClass({
  type: 'function',
  params: [
    { type: 'number' },
    { type: 'number' }
  ],
  // return is unecessary.
  // async is not supported in this case.
  $init: function (x, y) {
    this.x = x;
    this.y = y;
  }
});
```


### Differences From JSON Schema

There are differences from JSON Schema spec since JSON schema isn't designed with OOP in mind, while the goal of this contract system is to work within the traditionally understood OOP.

The following are not supported:

### not

The `not` property isn't supported, since the type of `not` would be every other type but the `not` type, which makes it difficult to write as code.

### oneOf

`oneOf` is a more strict version of `anyOf`, in that only a single value can be matched. From code perspective `anyOf` would do the job.

### $ref

Given that the idea of the contract system is to write embedded JSON schema, `$ref` is a redundant implementation since the direct object can be referenced in code.

### allOf

`allOf` is only used when deserializing the JSON schema, and not allowed as a construction param. Use `$parent` instead.

### $base (not part of JSON Schema)

`$base` (the base class) is provided instead of `allOf` to map closer to regular OOP programming.

### $class (not part of JSON Schema)

`$class` is implicitly defined via `Schema.makeClass`. It can also be explicitly defined if the class is created outside of the `Schema.makeClass` process.

### $prototype (not part of JSON Schema)

`$prototype` can be provided to define the prototype of the class.


