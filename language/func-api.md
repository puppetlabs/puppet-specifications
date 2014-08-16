Puppet 4x Function API
===
In Puppet 4x there is a new API for writing Ruby functions that extend the functionality
of the Puppet language. This API is *experimental* in 4x in that functions written against
this API may need to be changed in minor releases. Functions that comply with the API will be
fully functional - it is not the use of the functions that is experimental.

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
* Specification of arity (number of arguments) is a blunt tool (can not express a variable
  number of arguments that is capped).
* Documentation can not be retrieved without running the ruby code that defines the function.

The 3x API
---

A Function is created by calling `Puppet::Parser::Functions.newfunction`. This method
takes the following arguments:

* name - a symbol
* type - if function is :rvalue or :statement
* arity - number of arguments (or variable min args if negative)
* doc - a doc string

The body of the function is implemented with a block given to `newfunction`. If an attempt is
made to define additional methods inside the new function body, they share the namespace with `Scope` and all other functions.

The API is both fragile, and does not help with the most common task - checking the arguments.
It is not uncommon that 80% of the logic in  function consists of argument type checking. Worse
is when there is no checking at all (because it is a chore to write) leading to mysterious
and sometimes spectacular failures.

The 4x API
---
In the 4x API, as you probably have already guessed, there is support for type checking, and the
logic for one function cannot step on the turf or other functions (and certainly not on `Scope`).

A `Function` is now simply a callable object. It is instantiated once (when loaded) and its
closure is the global scope (i.e. what is visible to it from outer scopes).

In general functions should not modify scope of the catalog - they are simply called with
arguments and produce a result that they return. Functions that really do need access to
other parts of the system has the opportunity to ask for helper object to be injected for
these purposes. This makes general purpose functions free of agent/master concerns and
it is easy to determine if a function will work in a particular context or not based on
its declared needs in terms of access to other parts of the system/services.

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

The `dispatch` method is used to define the dispatching of one *type signature* to one method. It
takes a block in which a call to `param` is made with type and name of each wanted parameter
(in order from left to right). Here is a `min` function that returns the smallest of two numbers, and
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

### Dispatch with variable argument count

If dispatch is used, the expected argument count is derived from the number of specified
parameters. If something else is wanted, if some parameters are optional (have defaults), or
if the last parameter is a varargs, then this is specified with a call to `arg_count`, which takes
min and max count of arguments. The max argument may be `:default` to indicate an infinite count.

Care must be taken to specify a min/max that is compatible with the method being called, but
they do not have to be exactly the same - this is legal

    dispatch :special do
      param 'Numeric', 'a'
      param 'Numeric', 'b'
      param 'Any', 'rest'
      arg_count 1, :default
    end
    
    def special(*args)
    end
  
Here, for implementation reasons it is wanted that all arguments are passed in one array
to the special method but in the eyes of the user we want it to have one required `Numeric`,
one optional `Numeric`, and then an optional amount of `Any`.

### Defining Type in the Dispatch call

Types are specified in string form with the syntax of the types as they are used in the
Puppet Programming Language. Only literal values may be used for the type parameter
expressions (e.g. '`Integer[$min_allowed + 1, $max_allowed]`' cannot be used as a type).

### Lambda Support

The signature supports a special block parameter that can accept a block of code / lambda given
to a function as an extra trailing argument. If this block parameter is not defined, the function
will not accept a call where a trailing lambda is given.

It is also possible to have explicit lambdas as parameters (albeit that there is currently no
way to pass multiple lambdas to a function from the Puppet Language in this version of
the specification). The language itself passes
a lambda as the last argument. Since a method may want to specify optional and variable number
of arguments before the lambda, there is the need to specify it separately using one
of the methods `block_param`, or `optional_block_param` where (as the name suggests), the former makes the signature require that a lambda is given, and the latter accepts a given lambda, but also that no lambda was given.

    dispatch :something do
      param 'Scalar', :a'
      block_param
    end

The `block_param` and `optional_block_param` can be called without arguments which means that
a lambda with any signature is accepted, and that the name of the parameter is `:block`. If something else is wanted, it is specified with a Callable type, and the name of the block. The type may also be a `Variant` type if all of the variants are variations of `Callable` (including other `Variant` types).

Example, accept a callable that takes two arguments, the first an `Integer`, and the second a
`String`:

    block_param 'Callable[Integer, String]', :block    

The declaration of the `Callable` type should be read as: "The given lambda must be callable
with arguments given of these types.", or simply "These are the types I will call the lambda with".


### Reserved method names

The Function class reserves the following method names:

* `closure_scope`
* `loader`
* `call_function`

**NOTE** The API for this is still being designed.

#### closure_scope

Returns the scope where the function was defined.

#### loader

Returns the loader that loaded the function. Further loading will be done from the perspective
of this loader.

#### call_function(function_name, *args)

Calls the function named `function_name` (the name is given without any prefix (3x prefixes
names with `function_`, 4x does not), and a variable number of arguments.

### Function Documentation

Documentation is written as yardoc comments before the call to `Functions.create_function` and
in comments before each call to `dispatch`.


### Rules for Non Internal Functions

* The function may only use things that are given to it.
* The function may not mutate the arguments given to it.
* The function should not mutate the state of the system directly, it may call other system
  functions that does this, but it should not mutate the system state itself.
* The function may not implement any of the reserved methods.
* The function may not contain nested classes or modules

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


* The anonymous Function class defines all methods on the class, an instance of the function
  represents a particular call
* use one extra argument in every method that the evaluator dispatches to (e.g. max(scope, a, b)) -
  which is bad because polymorphic dispatch works best on first arg, and becomes cumbersome
  when using varargs (compare `max(a,b,scope)`, `vararg(a,b, scope, *var)`)
  
The choice of instantiating the function for each call is better, but will create garbage
instances (slower). We could perhaps indicate if a function requires calling scope and
only instantiate it then.

### Manual Handling

The intention is that typical functions should only require the features that Function
supports. Internal / system functions may require support for additional features, and
for that purpose there is an `InternalFunction` base class which is intended to have all
features required. As the API is being defined, there may be the need to create a custom
base class to experiment with features. If this is needed, there are two main
extension points, the initialization, and the call method.

**NOTE** The API for this is still being designed.

#### call_method(scope, *args)

A Function can implement `call(scope, *args)`, perform additional checks etc, and either relay
to the super version, or rewrite the array with given arguments and call:

    self.class.dispatcher.dispatch(self, scope, args)

It is not intended that the `Function` directly implements its function-logic in the
`call` method.

#### initialize method

The `initialize` method takes two arguments, the `closure_scope`, and the `loader`, and if 
initialization is required of the function being created, the super version must be called.

The `closure_scope` is the outer scope of the function, typically this is the top/global scope.
The loader is the loader that loads the function - it is needed since the function may need access
to other loaded/loadable entities that are visible to it.





Experimental / Internal Features
---
### Calling Scope Support

If the function needs access to the calling scope, this can be injected into the dispatching
by calling `scope_param`, here is an example from the function `inline_epp`:

    Puppet::Functions.create_function(:inline_epp, Puppet::Functions::InternalFunction) do

      dispatch :inline_epp do
        scope_param()
        param 'String', 'template'
        param 'Hash[Pattern[/^\w+$/], Any]', 'parameters'
        arg_count(1, 2)
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
      syntax_checkers_type = hash_of(type_of(::Puppetx::SYNTAX_CHECKERS_TYPE))
      syntax_checkers_extension = ::Puppetx::SYNTAX_CHECKERS
     
      attr_injected syntax_checkers_type, :syntax_checkers, syntax_checkers_extension
     
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
is useful when the methods being called needs access to context or service and these a)
do not (and cannot) come from the puppet logic, and b) it may be different depending on environment
and/or calling context. 

This is specified via the methods injected_param, and injected_provider_param with the
same arguments as for the class attributes, but where the first name is the name of the
Parameter instead of the attribute.

Using the same example as earlier, but now instead using argument injection.

    Puppet::Functions.create_function('assert_syntax') do
      syntax_checkers_type = hash_of(type_of(::Puppetx::SYNTAX_CHECKERS_TYPE))
      syntax_checkers_extension = ::Puppetx::SYNTAX_CHECKERS
     
     dispatch :check do
       param String, 'text'
       param String, 'syntax'
       injected_param syntax_checkers_type, 'checkers', syntax_checkers_extension
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

