Puppet Functions
===

Puppet Functions is simply the ability to write functions in Puppet.

Grammar
---

    FunctionDefinition
      : 'private'? 'function' parameters = ParameterList? '{' statements += statements '}'
      ;
      
    ParameterList
      : '(' parameters += Parameter ')'
      ;
      
    Parameter
     : type=Expression<Type>? captures_rest='*'? name=QualifiedName ('=' value = Expression)?
     ;
     
The `Parameter` definition is the same as for Lambda (after PUP-514 is merged).

* Only `FunctionDefinition` and `Lambda` can use `captures_rest` since they use arguments passed
  'by position'.
* A `captures_rest` parameter (if used), must be placed last in the list
* A parameter with a default value can not be placed after one that that does not have one.
* A default expression may refer to parameters defined in a parameter that is to the left of it. 
* The default expressions are evaluated in the **function's closure scope** (i.e. global scope), with
  the exception of parameters defined in the function list, such that:
  * it is an error to refer to a (non '::' anchored) variable name that appears as a parameter
    to the right, even if it could be resolved to a globally available value.
* A `captures_rest` parameter will always receive an Array.
* A `captures_rest` parameter's default can be given as a single value, or an `Array`.
  If a single value  is given, it is automatically wrapped in an `Array`.
* The type of the `captures_rest` parameter is either a non-Array type which becomes the element type
  of each captured element, or an Array Type that may cap the number or entries as well as specifying
  the element type. As a consequence, to capture a sequence of `Array[T]`, this must be specified as
  `Array[Array[T]]`.
  
Discussion:

The above rules for `captures_rest` are motivated by the thought that the most common use is
not to pass multiple arrays, and it is more convenient to write `foo(String *$rest)` then to have to write `foo(Array[String] *$rest)`, since the `*` already implies `Array`. The consequence is when using that shorthand notation is that an array of arrays must be written `Array[Array[T]]` - which is expected to be far more uncommon, than either capping the list
(e.g. `foo(Array[String,1,10] *$rest)`, or passing a variable number of arrays.

Which option is best?

a) Require always specifying `Array[T]` ?
b) Allow `T (T ∉ Array)` to be shorthand for `Array[T]` ?

Lambda Support
---
The language handles a Lambda given in a call as an extra argument that is always delivered last - 
even after a captures-rest. The lambda is either present or not.

A function can declare that it accepts a lambda, by typing the last parameter as a `Callable`.
If the last parameter is a captures-rest (irrespective of if it is `Callable` or not), this is treated as the function not supporting a lambda, and it is an error to call it with one.

If last parameter after (optional) captures-rest parameter is a callable variant, a lambda
may be given in the call to the function - as shown in the table below

| given last (non captures-rest) type     | meaning
| ---                                     | ---
| `Callable`                              | required lambda (any signature)
| `Optional[Callable]`                    | optional lambda (any signature)
| `Variant[<callable variants>]`          | requires one of the lambda signatures
| `Optional[Variant[<callable variant>]`  | optionally one of the lambda signatures

When a lambda is optional and not lambda is given in a call, the parameter will be bound to
`undef`.

Calling a Lambda
---
Calling a lambda (any callable) may be done by applying the `()` operator.

    function(Array $arr, Callable $block) {
      $arr.each |$x| { $block($x) }
    }

The above is the same (albeit slower) as calling each directly with the block. 

Since the function API treats a last parameter being a Callable special, it can be passed
to functions that accepts a block directly - like this:
  
    function(Array $arr, Callable $block) {  
      $arr.each($block)
    }

To call a lambda, the variable holding the block is simply called.

Call Rules:

* A name can be called (i.e. like it is now done)
* An expression that evaluates to Callable can be called
* Any other result raises an error

**NOTE** We may have to wait with supporting calling callables until we have fixed scope
since it is not safe to return a lambda and use it later due to the scope implementation in 3x.
There is no (non expensive) way of asserting that a function does not leak a Callable.

Type of Given Block
---
Since the function can use a Variant type, it is not known which of the allowed
Callable signatures that was given. The (not yet implemented) type_of(instance) function
will return the Callable (or a subtype of it) that can be used in a switch. This is useful if
a function wants to take alternative paths depending on the number of parameters in the Callable.


Function Definition - Scope & Autoloading
---
Puppet Functions are autoloaded from modules. They are located under <module-root>/functions.
The filename must match the simple (non namespaced name part) of the function. Thus, a function 'min' in module 'testmodule' is placed like this:

    testmodule
      |- functions
         | min.pp
         
The functions defined this way in modules must be name-spaced. Thus the contents of this `min.pp` is:

    function testmodule::min($a, $b) {
      # ...
    }

It is allowed to defined Puppet Functions in the environment's logic (i.e. `site.pp`, or in the manifests loaded from the manifests directory). It is also allowed to defined functions directly
on the command line when running puppet apply.

Rules:

* autoloaded functions in modules must have qualified names
* functions that are defined in modules, but that are not autoloaded (loaded as part of something   
  else) should also be defined in the module's namespace (it should be an error if an attempt is 
  made to name it differently).
* functions defined in the environment may have any name (global or namespaced)
* A function loaded in the environment shadows functions from modules, but not system functions


Related Functionality
---
### Function Reference

Other ways to obtain a callable (than to give a lambda to a function) are to:

* add a `lambda` function that simply returns the lambda given to it
* add an unary function reference operator (`&`) that turns a reference to a function into a `Callable`.

Here is the `lambda` function written in Puppet:

     function lambda(Callable $block) { $block }

Here, the `&` operator is used to reference a function.

     function min($a, $b) { if $a < $b { $a } else { $b } }
     
     [1,295,26,9,2,5,7,0].reduce(&min)
     
     # the last expression is equivalent to
     [1,295,26,9,2,5,7,0].reduce() |$memo, $x| { min($memo, $x) }

Rules:

* A `&NAME` must resolve to an existing function or an error is raised
* It produces a `Callable` with the signature of the found function
* It is illegal to apply the & operator to anything except a NAME

### Unfold (PUP-2240, merged)

The splat/unfold operator is related to 'captures-rest', but is really a general purpose operator. It
unfolds the RHS if it is an Array, and it can be used to unfold into literal lists, function arguments, and case options. If given something that is not an array, it is first turned into one.
If used where Unfold has no special meaning, the result is an array (a hash is turned into an array,
and all other values are wrapped in an array).

Grammar

    UnfoldExpression
      : '*' Expression
      ;
      
The UnfoldExpression has no effect unless it is used in one of the positions where it has special
meaning.

    $a = [1,2,3]
    foo(*$a) # same as foo(1, 2, 3)
    
    case $something {
      *$a: { # matches 1 or 2 or 3
      }
    }

    $b = [10, *$a, 20] # creates [10, 1, 2, 3, 20]
    
This operator is important as it removes the need for functions to have complex signatures
that either accepts individual values or arrays - it is instead up to the caller.    