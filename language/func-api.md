Puppet 4x Function API
===
In Puppet 4x there is a new API for writing Ruby functions that extend the functionality
of the Puppet language. This API is *experimental* in 4x in that functions written against
this API may need to be changed in minor releases. Functions that comply with the API will be
fully functional - it is not the use of the functions that is experimental.

We are doing this because the 3x API for functions has several issues:

* The function runs as a method on `Scope` (and has access to too much non-api)
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
logic for one function cannot step on the turf or other functions (and certainly not on Scope).

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
creates a class derived from Function with a name derived after the function. The Ruby logic
can not find this class on its own - it is not bound to a constant anywhere (and it is forbidden
for anyone to do so or reloading will not work).

The simplest declaration uses introspection to configure the class - a simple function
can look like this:

    Puppet::Functions.create_function('max') do
      def max(x,y)
        x >= y ? x : y
      end
    end

This works, because we have named the created function and the method it contains the same
way. (If there is no method with the same name an error is raised). It is legal to have
additional helper methods but it is not possible to define classes nested inside of the function.

The function definition in the example above does obviously not define the types of the
arguments (since this cannot be done in Ruby). Instead, the introspection
treats every defined parameter as being of `Any` type.

The default introspection supports arguments with default values (optional arguments), and
that the last argument accepts spillover arguments (varargs). It is not allowed to follow
optional arguments with a required argument (and by definition a vararg is always optional.

Thus, this is allowed:

    Puppet::Functions.create_function('myfunc') do
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

The act of directing a call of the function to the correct method is called dispatching. In the
simple case, a default dispatcher was defined (all parameters are of Any type). While this is
convenient we most often want automatic checking of the arguments type. We may also want
to direct the call to different methods depending on the given argument types as this makes
it a lot easier to implement a function cleanly (we may want a function to operate quite differently
based on if it gets an Array or a String etc.)

The `dispatch` method is used to define the dispatching of one type signature to a method. It
takes a block in which one call to param is made with type and name for each parameter (in order
from left to right). Here is a min function that returns the smallest of two numbers, and
the lexicographically earlier of two strings (downcased to get case independence).

    Puppet::Functions.create_function('min') do
      dispatch :min do
        param 'Numeric', 'a'
        param 'Numeric', 'b'
      end

      dispatch :min_s do
        param 'String', 's1'
        param 'String', 's2'
      end

      def min(x,y)
        x <= y ? x : y
      end

      def min_s(x,y)
        cmp = (x.downcase <=> y.downcase)
        cmp <= 0 ? x : y
      end
    end

Now we can call the function min with either two numbers, or two strings, and we get
automatic dispatching and type checking. Should we pass something that is not supported
with get an error message that shows the alternatives - say we try to call it this way:

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
if the last parameter is a varargs, then this is specified with a call to arg_count, which takes
min and max count of arguments. The max argument may be :default to indicate an infinite count.

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

Types are specified in String form with the syntax of the types as they are used in the
Puppet Programming Language:

### Lambda Support

The signature supports passing a block of code / lambda to a function as an extra trailing argument.
It is always possible to have explicit lambdas as parameters. The language itself passes
a lambda as the last argument. Since a method may want to specify optional and variable number
of arguments before the lambda (and not repeat it), there is the need to specify it differently.

Maybe like this?

    dispatch :something do
      param 'Scalar', 'a'
      block_param Callable[...]
    end

**TODO** This changed - review implementation

The type is always a lambda type, and it is always last (except if user passes a closure,
but that is a different issue). There must be a way to define if the block is optional or
not, suggest `required_block_param`, `block_param` as methods.


### Manual Handling

A Function can implement `call(scope, *args)`, perform additional checks etc, and either relay
to the super version, or rewrite arguments and call:

    self.class.dispatcher.dispatch(self, scope, args)

It is not intended that the Function directly implements its function-logic in the
call method.

### Reserved method names

The Function class reserves the following method names:

* calling_scope
* closure_scope
* loader

**NOTE** The API for this is still being designed.

#### Overriding the initializer

The `initialize` method takes two arguments, the calling_scope, and the loader, and if initialization
is required of the function being created, the super version must be called.

**NOTE** The API for this is still being designed.

### Strict access

A Function is defined in a top level scope (or system scope), and does not by default have access to the scope in which it is called.

**The function may use things that is either given to it, or that it injects.**
    
Note that the scope given in the call to inject is the scope where the function
is defined - i.e. the function's closure (works the same as a lambda, only that all
functions are defined in a global system scope tied to the module where it is defined.

Accessing the calling scope is a very smelly thing and it is questionable if it should
be supported at all. If access is needed to any other part of the system, such accessors
should be injected (i.e. access is not via scope).

The only reason to get the calling scope is to read or write variables - i.e. bad behavior!
A function should only communicate via its given arguments and returned value(s) and
side effects only performed on objects that are injected (e.g. compiler, loader, etc).

However... when a call is made, the calling scope is passed and we can provide
access to it if needed, but we must then do one of the following:

* The anonymous Function class defines all methods on the class, an instance of the function
  represents a particular call
* use one extra argument in every method that the evaluator dispatches to (e.g. max(scope, a, b)) -
  which is bad because polymorphic dispatch works best on first arg, and becomes cumbersome
  when using varargs (compare `max(a,b,scope)`, `vararg(a,b, scope, *var)`)
  
The choice of instantiating the function for each call is better, but will create garbage
instances (slower). We could perhaps indicate if a function requires calling scope and
only instantiate it then.

The exploratory implementation does not have a mechanism yet for passing calling scope
on to the methods. It seems best to do this via injection, or by special methods that
behave like the injected_param method, e.g. injected_scope, injected_loader. This is much
faster than having to construct a new injection override for each call and do real injection.


### Function Documentation

Currently, documentation is a parameter to new function. Seems like this could be written
with ruby yardoc instead, thus avoiding that the string has to be parsed and created and
kept in memory at runtime. 

A scanner would process the documentation for the class, as well as the documentation for
the individual methods that have been wired (i.e. the various overloads).



Experimental / Internal Features
---
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

