Function API
===
In Puppet 4x there is a new API for writing Ruby functions that extend the functionality
of the Puppet language. This API is *experimental* in 3x (with future parser) in that functions written against this API may need to be changed in minor releases. Functions that comply with the API will be fully functional - it is not the use of the functions that is experimental.

We are doing this because the 3x API for functions has several issues:

* The function runs as a method on `Scope` (and has access to too much non-API)
* Undefined arguments are given to the function as empty strings
* There is no automatic type checking
* Functions share a flat namespace
* Functions cannot be private to a module
* Functions are defined in the `Puppet::Parser::Functions` namespace. Future use of functions
  is to also use them where no parser is available. The concept of "parser function" is just odd.
* Methods defined in a Function pollute Scope
* There are problems with reloading complex functions
* There is a distinction between function of expression and statement kind and this distinction
  is no longer meaningful.
* Documentation can not be retrieved without running the ruby code that defines the function.

The 3x API
---

A Function is created by calling `Puppet::Parser::Functions.newfunction`. This method
takes the following arguments:

* `name` - a symbol (required)
* `type` - if function is `:rvalue` or `:statement`
* `arity` - number of arguments (or variable min args if negative)
* `doc` - a doc string

The body of the function is implemented with a block given to `newfunction`. If an attempt is
made to define additional methods inside the new function body, they share the namespace with `Scope` and all other functions.

The API is both fragile and does not help with the most common task - checking the argument types.
It is not uncommon that 80% of the logic in  function consists of argument type checking. Worse
is when there is no checking at all (because it is a chore to write) leading to mysterious
and sometimes spectacular failures.

For autoloading information see [Autoloading][1].


The 4x API
---
In the 4x API there is support for type checking, and the
logic for one function cannot step on the turf or other functions (and certainly not on `Scope`).

A `Function` is now simply a callable object. It is instantiated once (when loaded) and its
closure is the global scope (i.e. what is visible to it from outer scopes).

In general functions should not modify scope of the catalog - they are simply called with
arguments and produce a result that they return. Functions that really do need access to
other parts of the system has the opportunity to ask for helper object to be injected for
these purposes. This makes general purpose functions free of agent/master concerns and
it is easy to determine if a function will work in a particular context or not based on
its declared needs in terms of access to other parts of the system/services.

For autoloading information see [Autoloading][1].

### Creating a Function

A function is created with a call to `Puppet::Function.create_function`. Behind the scenes this
creates a subclass of `Function` named after the function. The Ruby logic
can not find this class on its own - it is not bound to a constant anywhere (and it is forbidden
for anyone to bind it in a fashion that prevents reloading).

The simplest declaration uses introspection to configure the class - a simple function
can look like this:

    Puppet::Functions.create_function(:max) do
      def max(x,y)
        x >= y ? x : y
      end
    end

This works, because we have named the created function and the method it contains the same
way. (If there is no method with the same name an error is raised). It is legal to have
additional helper methods but it is not possible to define classes nested inside of the function.
Functions can now be namespaced for inclusion in a module, in which case the method would
be named with the last segment of the function name:

    Puppet::Functions.create_function(:"mymodule::min") do
      def min(x,y)
        x <= y ? x : y
      end
    end

The function definition in the example above does obviously not define the required types of the
arguments (since this cannot be done in Ruby). Instead, the introspection
treats every defined parameter as being of `Any` type.

The default introspection supports arguments with default values (optional arguments), and
that the last argument accepts spillover arguments (varargs). It is not allowed to follow
optional arguments with a required argument (and by definition a vararg is always optional).

Thus, this is allowed:

    Puppet::Functions.create_function(:myfunc) do
      def myfunc(a, b, c=10, *d)
        x >= y ? x : y
      end
    end

The introspection will derive the correct type signature for the function from the parameter
declaration. It will (when used with Ruby >= 1.9.3 also pick up the parameter names. If this
function is called with the wrong number of arguments (or wrong type - see below), say like this:

    myfunc(1)

an error message is shown like this:

    function 'myfunc' called with mis-matched arguments
      expected:
        myfunc(Any a, Any b, Any c?, Any d{0,}) - arg count {2,}
      actual:
        myfunc(Integer) - arg count {1}

What this is telling us is that `myfunc` has 4 parameters (`a`, `b`, `c`, `d`), but can be called
with a minimum of two parameters.
This is shown at the end as a short hand (`{2,}` means 2 or more). The optionality
is also shown for each parameter (a `?` denotes this), and at the end, the parameter `d` accepts
0 or more values as denoted by {0,}.

If we want to assert other types than `Any`, a little more work is required.

### Defining a Typed Dispatch

The act of directing a call of the function to the correct method is known as *dispatching*. In the
simple case, a default dispatcher was defined (all parameters are of `Any` type). While this is
convenient we most often want automatic checking of the arguments type. We may also want
to direct the call to different methods depending on the given argument types as this makes
it a lot easier to implement a function cleanly (we may want a function to operate quite differently
based on if it gets an `Array` or a `String` etc.)

Each wanted parameter is defined with a call to one of the **param methods** (in order from
left to right as seen when calling the function).

Here is a `min` function that returns the smallest of two numbers, and
the lexicographically earlier of two strings (downcased to get case independence).

    Puppet::Functions.create_function(:min) do
      dispatch :min do
        param 'Numeric', :a
        param 'Numeric', :b
      end

      dispatch :min_s do
        param 'String', :s1
        param 'String', :s2
      end

      def min(x,y)
        x <= y ? x : y
      end

      def min_s(x,y)
        cmp = (x.downcase <=> y.downcase)
        cmp <= 0 ? x : y
      end
    end

Now we can call the function `min` with either two numbers, or two strings, and we get
automatic dispatching and type checking. Should we pass something that is not supported
we get an error message that shows the alternatives - say we try to call it this way:

    min(1,2,3)

then we get:

    function 'min' called with mis-matched arguments
    expected one of:
      min(Numeric a, Numeric b) - arg count {2}
      min(String s1, String s2) - arg count {2}
    actual:
      min(Integer, Integer, Integer) - arg count {3}


When a call is made, the signatures are tested in the order they appear in the definition
of the function, thus, if a very generic entry is placed first it will always win.

#### Required, Optional, and Repeated Parameters

The `dispatch` method is used to define the dispatching of one *type signature* to one method. It
takes a block in which a series of calls are made to define the parameters using one of the methods:

* `param` - same as `required_param`
* `required_param` - a parameter that must be given as an argument
* `optional_param` - a parameter that may be omitted as an argument (may not be
  followed by a required parameter.
* `repeated_param`- a parameter that accepts none or many given argument values (must be placed
  last, or just before a block parameter). Can also be stated with `optional_repeated_param`. Can 
  not be combined with `required_repeated_param`.
* `required_repeated_param` - a parameter that accepts one or many given argument values (must be 
  placed last, or just before a block parameter). Cannot be combined with `repeated_param` or 
  `optional_repeated_param`.

These take type (in string form) and name (a symbol) as arguments.

#### Block Parameters

Block (lambda) parameters can be defined with:

* `block_param` - same as `required_block_param`
* `required_block_param` - specifies that a block must be given
* `optional_block_param` - specifies that a block may be given

If neither of the block parameter methods are called, then it is an error to call the
function with a block.


#### Dispatch with variable number of arguments

The methods optional_param, and repeated_param makes the function accept a variable number
of arguments. When using variable number of arguments
care must be taken to specify parameters that are compatible with the method being *called* by
the dispatch, but they do not have to be exactly the same - this is legal:

    dispatch :special do
      param 'Numeric', :a
      optional_param 'Numeric', :b
      repeated_param 'Any', :additional
    end
    
    def special(*args)
    end
  
Here, for implementation reasons it is wanted that all arguments are passed in one array
to the `special` method but in the eyes of the user we want it to have one required `Numeric`,
one optional `Numeric`, and then an optional amount of `Any`.

#### Defining Type in the Dispatch call

Types are specified in string form with the syntax of the types as they are used in the
Puppet Programming Language. Only literal values may be used for the type parameter
expressions (e.g. '`Integer[$min_allowed + 1, $max_allowed]`' cannot be used as a type).

#### Returned Type

Since Puppet 4.7.0 it is possible to specify the expected return type. This is done in the dispatcher by calling `return_type` with the type as a puppet type system string.

    Puppet::Functions.create_function(:min) do
      dispatch :min do
        param 'Numeric', :a
        param 'Numeric', :b
        return_type 'Numeric'
      end
    # ...
    end
    
* The return type is asserted when the function returns a value.
* If a return type is not specified it defaults to `Any`.

### Block/Lambda Support

#### Defining the Block Parameter

The signature supports a special block parameter that can accept a block of code / lambda given
to a function. If this block parameter is not defined, the function
will not accept a call where a lambda is given. To make it possible to pass a block to the method
this must be declared in the dispatcher with either `block_param` (same as `required_block_param`), or `optional_block_param`.

As the names of the methods suggests, the former makes the signature require that a lambda is given, and the latter accepts a given lambda, but also that no lambda was given.

    dispatch :something do
      param 'Scalar', :a'
      block_param
    end

The `block_param` and `optional_block_param` can be called without arguments which means that
a lambda with any signature is accepted, and that the name of the parameter is `:block`. If something else is wanted, it is specified with a `Callable` type, and the name of the block. The type may also be a `Variant` type if all of the variants are variations of `Callable` (including other `Variant` types).

Example, accept a callable that takes two arguments, the first an `Integer`, and the second a
`String`:

    block_param 'Callable[Integer, String]', :block    

The declaration of the `Callable` type should be read as: "The given lambda must be callable
with arguments given of these types.", or simply "These are the types I will call the lambda with".

#### Calling the Given Block

When a lambda is given in the Puppet Language it is given as a Ruby block to the method
the call is dispatched to - just as if the method is called directly from ruby with a trailing
do block. It is possible to check if a block is given with `block_given?`, and the block can be called with `yield`, or an explicit `block.call`.

The recommended way is to not declare a `&block` parameter, and instead call it with `yield` (after having checked if an optional block was given or not).

Here is an example where the min function accepts an optional block that is called with the result - e.g. it can be called as `min(1,100) |$x| { "min is $x" }` - which would return the string "min is 1". The definition of the function looks like this:

    Puppet::Functions.create_function(:min) do
      dispatch :min do
        param 'Numeric', :a
        param 'Numeric', :b
        optional_block_param Callable['Integer'], :block
      end

      def min(x,y)
        result = x <= y ? x : y
        # call (i.e. yield) to the block if it was given, else the result
        block_given? ? yield(result) : result
      end

    end

#### Introspecting the Given Block

The given block is a specialized Ruby `Proc` object from which it is possible to get arity, and
information about the parameters (names, if they have default value, etc.). The special `Proc` used by the Puppet runtime also supports getting the Puppet Closure which holds additional information
about the types of the parameters.

It is recommended to use the Ruby Proc API since this enables more convenient testing (just pass
a regular Ruby Proc). Also note that when using Ruby 1.8.7 the Proc API is limited in the information it can return. **In Ruby 1.8.7 it is also not possible to obtain the Puppet Closure**.

Use the `closure` method on the proc to get the Puppet closure (an instance of `Puppet::Pops::Evaluator::Closure`).

### Local Type Aliases

Since Puppet 4.5.0 it is possible to define local type aliases that can be used to type
the parameters of the function. This is done in a call to `local types`, which must be
placed before all dispatchers.

```
local_types do
  type  'AliasName = SomeDefinedType'
  type ...
end
```

Each call to `type` in the block given to `local_types` defines a type alias. The syntax for the string given
to the `type` function is exactly the same as what may follow the keyword `type` in the Puppet Language when
defining a type alias.

The locally defined type aliases may be used in the dispatchers when describing parameters. These aliases are only
available inside the function.

Example of usage:

```
local_types do
  type 'PartColor = Enum[blue, red, green, mauve, teal, white, pine]'
  type 'Part = Enum[cubicle_wall, chair, wall, desk, carpet]'
  type 'PartToColorMap = Hash[Part, PartColor]'
end

dispatch :define_colors do
  param 'PartToColorMap', :part_color_map
end

def define_colors(part_color_map)
  # etc
end
```

### Reserved method names

The Function class reserves the following method names:

* `closure_scope`
* `loader`
* `call_function`

#### closure_scope

Returns the scope where the function was defined. This is the scope a function should
use if it needs to lookup top-scope variables like `$facts`. This scope does not provide
access to the local scope the call originates from.

#### loader

Returns the loader that loaded the function. Further loading will be done from the perspective
of this loader.

#### call_function(function_name, args, &block)

Calls the function named `function_name` (the name is given without any prefix (3x prefixes
names with `function_`, 4x does not), and an array containing the arguments.

If you want to pass a block, you can either give a regular Ruby block, or pass on the `Proc` that
was given to the function.

    def my_function1(a, b, &block)
      # passing given Proc
      call_function('my_other_function', [a, b], &block)
    end

    def my_function2(a, &block)
      # using a Ruby block
      call_function('my_other_function', [a, b]) { |x| ... }
    end

### Function Documentation

Documentation is written as yardoc comments before the call to `Functions.create_function` and
in comments before each call to `dispatch`.


### Rules for Non Internal Functions

There are two implementations that build up a function; regular and internal. The builder
of internal functions have more access to the runtime and has an API that is considered private
(it may change in minor releases). For regular, not internal functions the rules are:

* The function may only use things that are given to it.
* The function may not mutate the arguments given to it.
* The function should not mutate the state of the system directly, it may call other system
  functions that does this, but it should not mutate the system state itself.
* The function may not implement any of the reserved methods.
* The function may not contain nested classes or modules
* The function may not define Ruby constants

Specifically, this means that a (non internal) function does not have access to the calling scope.
If there is a need to access the calling scope, or other internal runtime services, the
function is an internal / system function and it can be implemented using the more advanced
`InternalFunction` base class.

Normal functions should not access scope. It is very bad practice to read (or even worse,
write) variables in the scope. A Function should operate on its given arguments and
return a result. Functions that need to mutate the state of the catalog are considered
to be system functions, and it is far better to call these functions than to implement a new
system function (e.g. use `call_function(:include, 'name_of_class')` instead of trying
to manipulate the catalog being produced).

* The anonymous Function class defines all methods on the class, an instance of this function class
  represents the functions closure.

### Access to Stacktrace

Some functions need access to the call stack in order to be able to issue a specific error message, or to associate file and line information with produced data (as is the case with the `create_resources` function).

This is done by using the PuppetStack object available since Puppet 4.6.0.

The PuppetStack contains an array of all file/line locations in a nested call structure, where the
innermost nested call appears first. Thus the immediate caller location of a function is found at index 0.

The PuppetStack only contains location in .pp source. The corresponding information is also available in the Ruby stacktrace and shows up in logged exceptions. This is of value when a function calls another using `call_function` and the called function is implemented in Ruby.

To get the immediate caller:

````
stacktrace = Puppet::Pops::PuppetStack.stacktrace()
file, line = stacktrace[0]
````

### Manual Handling

The intention is that typical functions should only require the features that `Function`
supports. Internal / system functions may require support for additional features, and
for that purpose there is an `InternalFunction` base class. 

As the API for internal functions is being defined, there may be the need to create a custom
base class to experiment with features. If this is needed, there are two main
extension points, the *initialization*, and the *call method*.

**NOTE** The API for this is still being designed.

#### call_method(scope, *args, &block)

A Function can implement `call(scope, args, &block)`, perform additional checks etc, and either relay to the super version, or rewrite the array with given arguments and call:

    self.class.dispatcher.dispatch(self, scope, args, &block)

It is not intended that a `Function` directly implements its function-logic in the
`call` method.

#### initialize method

The `initialize` method takes two arguments, the `closure_scope`, and the `loader`, and if 
initialization is required of the function being created, the super version must be called.

The `closure_scope` is the outer scope of the function, typically this is the top/global scope.
The loader is the loader that loads the function - it is needed since the function may need access
to other loaded/loadable entities that are visible to it and the loader given to it provides
this interface.

Experimental / Internal Features
---
### Calling Scope Support

If the function needs access to the calling scope, this can be injected into the dispatching
by calling `scope_param`, here is an example from the function `inline_epp`:

    Puppet::Functions.create_function(:inline_epp, Puppet::Functions::InternalFunction) do

      dispatch :inline_epp do
        scope_param()
        param          'String',                      :template
        optional_param 'Hash[Pattern[/^\w+$/], Any]', :parameters
      end
      # ...
    end

### Injection

It is possible to inject objects - both at the time the function is instantiated and
when the function is called. 

#### Injection of Function Class attributes

Injections at function instantiation time is useful
when a function needs support from other services that do not depend on the calling context.

These injections are activated and values are looked up on first use. The grammar for this is:

    SharedInjection
      : 'attr_injected' AttributedInjection
      | 'attr_injected_producer' AttributedInjection
      ;
            
    AttributedInjection
      : type = TypeReference ',' attribute_name = SYMBOL (',' injection_key = STRING)?
      ;

As an example, a function that performs syntax checking gets syntax checker extensions
via the binder.

    Puppet::Functions.create_function('assert_syntax') do
      # define constants
      syntax_checkers_type = hash_of(type_of(::Puppetx::SYNTAX_CHECKERS_TYPE))
      syntax_checkers_extension = ::Puppetx::SYNTAX_CHECKERS
     
      # and in the dispatcher
      injected_param syntax_checkers_type, :syntax_checkers, syntax_checkers_extension
     
This creates a method called `assert_syntax()` that the method implementing the function's
logic can call to obtain the hash of syntax checkers registered with the injector as in the following
simple use of the registered syntax checkers (error checking, reporting, etc. is missing from the
example).

     def assert_syntax(text, syntax)
       syntax_checkers()[syntax].check(...)
       # raise error if not ok, else return the text
       text
     end

#### Injecting Arguments

The second use case for injections is to inject arguments when dispatching the calls. This
is useful when the methods being called needs access to context or service and these a) do not (and cannot) come from the puppet logic, and b) it may be different depending on environment
and/or calling context. 

This is specified via the methods `injected_param`, and `injected_provider_param` with the
same arguments as for the class attributes, but where the first name is the name of the
`Parameter` instead of the attribute.

Using the same example as earlier, but now instead using argument injection.

    Puppet::Functions.create_function('assert_syntax') do
      syntax_checkers_type = hash_of(type_of(::PuppetX::SYNTAX_CHECKERS_TYPE))
      syntax_checkers_extension = ::PuppetX::SYNTAX_CHECKERS
     
     dispatch :check do
       param 'String', :text
       param 'String', :syntax
       injected_param syntax_checkers_type, :checkers, syntax_checkers_extension
     end
     
     def check(text, syntax, checkers)
       checkers()[syntax].check(...)
       # raise error if not ok, else return the text
       text
     end

An injected param is not part of the signature that is used to dispatch the call, only the
params given by the user are. When the call is made, the injected parameter values
are woven into the given arguments at the places specified by the order in the dispatch
body. 

Alternatively, the same can be achieved by using a ruby default in the function and
directly calling lookup.

    def check(text, syntax, checkers = { 'json' => JsonChecker.new() })
     # ...
    end

(The example above uses a fictitious `JsonChecker` class as illustration).
    
The ruby parameter default can be used even if there is a dispatch - that means that if the method is
called directly from Ruby, then the default applies, if called from the puppet language, then
the injected value is used. This may be ideal for unit testing the function since it
can be tested without using injection and with default for available checkers.

Autoloading
---
Functions are autoloaded from files as shown in the table below. The reference `<root>` in the
shown paths is either the root of the environment (the environment's directory), or the root of a module. The notation `<module name>` means the name of the module without the author part, and `<function_name>` means the leaf name of the function (without name spaces).

| API        | in       | namespace support     | allows top-scope | path |
| ---        | ---      | ------------------    | ---------------- | --- |
| 3.x Ruby   | module   | Not supported         | Yes (always top scope) | `<root>/lib/puppet/parser/functions/<function_name>.rb` |
|            | env      | Not supported         | -   | - 
| 4.x Ruby   | module   | Yes `<module name>::` | Yes | `<root>/lib/puppet/functions/<module name>/<function_name>.rb` |
|            | env      | Yes `environment::`   | Yes | `<root>/lib/puppet/functions/environment/<function_name>.rb` `<root>/lib/puppet/functions/<function_name>.rb` |
| 4.x Puppet | module   | Yes `<module name>::` | No  | `<root>/functions/<function_name>.pp` |
|            | env      | Yes `environment::`   | No  | `<root>/functions/<function_name>.pp` |
|            | manifest | Yes (any namspace)    | Yes | in any manifest |

For 3.x note that only top scope, non namespaced functions can be defined. (The 3.x function API should not be used).

The 4.x namespaces allows namespaced functions to be created. When creating 4.x functions in Ruby it is possible to create both namespaced and top scope functions. Creating top scoped functions should be avoided as much as possible and considered to be reserved for functions included in the Puppet runtime.

Since the 4.x Ruby API allows functions to define top scope functions (both in the environment's file tree, and in module's file trees), the path to a namespaced function must always include the name of the module (or the fixed name `environment` for the (any) environment's namesapce) as the top directory `<root>/lib/puppet/functions` is for top scoped functions.

For the 4.x Puppet API it is not possible to autoload top scoped functions. It is however
possible to create top scoped functions by defining them in a manifest that is guaranteed to be loaded first (typically site.pp). This mechanism can be used to override/patch and delegate function calls as a version migration aid. 

Manifest loaded functions can define functions in any namespace. This should only be used for special cases (migration / patching).

Nested namespaces are suppoted in the 4.x API for both Ruby and Puppet. The paths to the `.rb` or `.pp` files containing such functions should have each additional namespace in a nested directory. As an example the function `environment::testing::env_func()` should be placed in `<root>/lib/puppet/functions/environment/testing/env_func.rb` (Ruby API), or `<root>/functions/testing/env_func.pp` (Puppet API) - note the difference that the Ruby API path includes the `environment` directory since the Ruby API allows top scope functions while the Puppet API does not.


[1]: #autoloading