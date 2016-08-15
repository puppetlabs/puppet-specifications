Puppet Functions
===

Puppet Functions is simply the ability to write functions in Puppet.

Grammar
---

    FunctionDefinition
      : 'function' name = NAME parameters = ParameterList? return_type = ReturnType? '{' statements += statements '}'
      ;
      
    ParameterList
      : '(' parameters += Parameter ')'
      ;
      
    Parameter
      : type=Expression<Type>? captures_rest='*'? name=QualifiedName ('=' value = Expression)?
      ;
    
    ReturnType
      : '>>' Expression<Type>
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
* Since 4.7.0 it is possible to specify the expected return type of the function. When it is specified an
  automatic type assertion will be made against the value produced by the function.


Discussion:

The above rules for `captures_rest` are motivated by the thought that the most common use is
not to pass multiple arrays, and it is more convenient to write `foo(String *$rest)` then to have to write `foo(Array[String] *$rest)`, since the `*` already implies `Array`. The consequence is when using that shorthand notation is that an array of arrays must be written `Array[Array[T]]` - which is expected to be far more uncommon, than either capping the list
(e.g. `foo(Array[String,1,10] *$rest)`, or passing a variable number of arrays.

See [Parameter Scope][1] for more information about scoping rules an variable access in a default value expression.

Lambda Support
---
Functions written in the Puppet Language does not support lambdas / code blocks. While it is
possible to call a puppet function with a lambda, and possibly also type a parameter as accepting a `Callable` parameter, this can not be put to any practical use since there is no support for calling the given block. It expected that this will be supported in a later version of this specification. Until then, the behavior of calling a puppet function with a code block is undefined.


Function Definition - Scope & Autoloading
---

### Autoloading

Namespaced Puppet Functions are auto loaded from modules and the environment when located under <module-root>/functions or <environment-root>/functions respectively. 

Auto loaded puppet functions are always namespaced; in a module using the module name, and in an environment by using the special name `environment` (i.e. not the *name* of the environment since that typically changes as code is being developed, tested, put into production and then maintained, etc.).

The name of the .pp file must match the simple (non namespaced name part) of the function. Thus, a function **'testmodule::min'** in module 'testmodule' is located like this:

    testmodule
      |- functions
         | min.pp

With the following contents in `min.pp` (note use of full namespace):

    function testmodule::min($a, $b) {
      # ...
    }

And a function **'environment::min'** in a 'production' environment like this:

    production
      |- functions
         | min.pp
         
With the following contents in `min.pp` (note use of namespace 'environment'):

    function environment::min($a, $b) {
      # ...
    }

Nested name spaces are allowed in both modules and the environment - e.g. a function **'testmodule::math::min'** would be located like this:

    testmodule
      |- functions
         |- math
            | min.pp

With the following contents in `min.pp` (note use of full namespace):

    function testmodule::math::min($a, $b) {
      # ...
    }

Rules:

* Loading is performed by mapping the fully qualified function name to a 4.x Ruby function path, and a puppet function path, then:
  * if the ruby path exist this 4.x Ruby function is loaded (and search stops)
  * if the puppet path exists this Puppet function is loaded (and search stops)
  * last, an attempt is made to load a 3.x Ruby function
* Files containing an auto loaded function may only contain a single function (or an error is raised and evaluation stops).

> Note:
> 
> Function loading only searches a set of distinct paths based on the fully qualified name of
> the function.
> Contrast this with other kinds of automatic loading of classes and user defined resource types
> where a search is made using a widening of the namespace, and finally reaching
> a modules `manifests/init.pp`.
> 
> **Specifically**: Autoloading a function from a module does not trigger loading of the module's 
> `manifests/init.pp` (nor is such initialization required to call a function from a module).
> If an author of a module provides functions that require that the module's `manifests/init.pp`
> is loaded, the function should include the module's class, or require that the caller first
> includes the module's class).
>
> **Specifically**: a file `init.pp` under the `functions` directory of a module or the environment
> does not have any special rules associated with it.
> If that file exists it is supposed to contain a function named `<module>::init`.
> Contrast this with `manifests/init.pp` which represents the module it is in. There is no such 
> concept for functions. 

### Defining functions in Manifests

It is possible to define a Puppet Function in any manifest. Such functions will come into existence when the manifest in question is loaded for some reason other than calling the function (e.g. from 'manifests/site.pp' or when including a class).

The following restrictions/rules/conventions apply on naming non-auto-loaded functions:

* A function defined in a module **must** be qualified with the module's namespace
* A function defined in an environment's main manifest **should** begin with the special namespace 'environment'
  * *except* when patching of a function is required - then the name may shadow other functions defined in the same environment, or the modules in this environment. Functions provided by the puppet runtime cannot be shadowed. A shadowed function cannot be called.

Note that the term "environment's main manifest" means logic loaded from the command line (`apply -e`), the Puppet setting `code`, the code loaded from the setting `manifest` (e.g. the `manifests/site.pp` file, or a directory of manifests).

The use cases for using functions defined in manifests are:

* Defining several helper functions that are used locally in a class/user defined type. (Although not yet provided in the language, these functions would typically be made `private` to the module).
* For patching:
  * To define a single word (non name-spaced) function (not recommended in general, useful for integrating code that needs such a function and where the original function's implementation is flawed/unwanted)
  * To override/shadow functions in modules that are flawed/unwanted.
  * To experiment during development
 
> Note: In the current implementation of Puppet 4.3.x the naming restrictions on non-auto-loaded
> functions are not enforced. They are expected to be enforced in some future release.

[1]: parameter_scope.md
