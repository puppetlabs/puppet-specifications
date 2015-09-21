Puppet Functions
===

Puppet Functions is simply the ability to write functions in Puppet.

Grammar
---

    FunctionDefinition
      : 'function' parameters = ParameterList? '{' statements += statements '}'
      ;
      
    ParameterList
      : '(' parameters += Parameter ')'
      ;
      
    Parameter
     : type=Expression<Type>? captures_rest='*'? name=QualifiedName ('=' value = Expression)?
     ;
     
The `Parameter` definition is the same as for Lambda.

* Only `FunctionDefinition` and `Lambda` can use `captures_rest` in their `ParameterList` since they use arguments passed 'by position'.
* A `captures_rest` parameter (if used), must be placed last in the list
* A parameter with a default value can not be placed after one that that does not have one.
* A default expression may refer to parameters defined in a parameter that is to the left of it. (once PUP-1985 is implemented - undefined otherwise)
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


Lambda Support
---
Functions written in the Puppet Language does not support lambdas / code blocks. While it is
possible to call a puppet function with a lambda, and possibly also type a parameter as accepting a `Callable` parameter, this can not be put to any practical use since there is no support for calling the given block. It expected that this will be supported in a later version of this specification. Until then, the behavior of calling a puppet function with a code block is undefined.


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


