Calls
===

The Puppet Programming Language supports a variety of expressions / constructs that constitute a **call**. A call 
transfers values from the caller (argument) and matches them against the called entity's parameters, after which it 
either evaluates the called entity directly or enqueues it for evaluation at a later point in time.

These constructs constitute a call:

* **Function Call**, The [Function Calls][1] section describes the details of how functions can be 
  called, this section includes calling/using lambda expressions.
* **Template Call**, The functions `epp`, and `inline_epp` can pass arguments to template parameters; 
  thus performing a call to the template to produce text.
* **Resource Instantiation**, creation of resources, resource defaults, resource overrides, and collection.
* **Instantiation**, creation of values (new objects), conversion of data types etc (Since 4.5.0).

[1]: expressions.md#function-calls

### Arguments

Arguments are literal values and the results of evaluating expressions. In this call to
the function `with` (which relays its received arguments on to a lambda), two arguments are given
to the function (`1`, and the result of `2+2`). The lambda parameter `$x` is assigned the value `1`,
and the lambda parameter `$y` is assigned the value `4`.

    # XXX i understand this is a contrived example but it'd be
    # better to have something you'd actually see in a module -e0
    with(1, 2+2) |$x, $y | { $x + $y }

### Parameters

Parameters are named and optionally typed variables. A parameter may optionally also have a default value expression, 
and may declare that it captures any excess arguments. (Different rules apply depending on the type of call; 
by-position, or by-name).

Parameters are always specified in a Parameter List as shown in the following grammar.

### Parameter List Grammar


    ParameterList
      : ParameterDeclaration (',' ParameterDeclaration)* ','?
      ;

    ParameterDeclaration
      : type = Expression<Type>? 
        vararg ?= '*'?
        name = VariableExpression ('=' default_value = Expression<R>)?
      ;

    VariableExpression : VARIABLE ;

* Parameters follow the naming rule for variables.
* The type is an optional `Type` that a given argument must have to be acceptable. If no type
  is specified, the type defaults to `Any`.
* The vararg (captures-rest) `'*'` indicates that the parameter accepts excess arguments.
  When the argument 
  passing form (see pass-by-position, and pass-by-name) allows 'captures-rest', it must be placed
  last, and only one captures-rest parameter may be used.
* The default value expression allows specification of a value to be used in case there is no 
  argument given for that parameter (missing argument).
* A default value expression must be compliant with the parameter's type (or an error is raised).
* A default value expression may not introduce new variables.

Argument Passing
---
Argument passing is performed with either **Pass-By-Position**, or **Pass-By-Name**. Function calls and calls to lambdas 
are always done with Pass-By-Position. Resource creation and EPP uses Pass-By-Name. Resource defaults and resource 
overrides use a variant of Pass-By-Name that allows amending values with `+>` instead of just setting them with `=>`.

### Pass By Position

Pass-By-Position transfers given arguments to parameters based on their position: the first (leftmost) 
given argument is given to the first (leftmost) defined parameter. The caller must know the
order in which to present the arguments; it is not possible to direct a particular argument to
a particular parameter based on the name of the parameter.

In pass-by-position:

* All given values (including `undef`) count as arguments with a value and these values
  are assigned to the parameter in the same order they are called.
* Only arguments not given at all result in a parameter having a missing argument, which leads to an 
  error (missing argument) unless the parameter has a default value expression (in which case the 
  result of evaluating that expression is used as the parameter's value).
* A Parameter List for a Pass-By-Position entity may not have a parameter with a default value
  expression to the left of one that requires a value. XXX could this be restated as: "all parameters with defaults must 
  come after required parameters"? -e0
* A default value expression is evaluated in the called entity's closure (which for functions 
  is the global scope/module they are defined in, for lambdas the scope where they are defined/
  module).
* **A default value expression does not have access to the parameters in the parameter list**, the
  parameters have not yet received their values when the default value expressions are evaluated.

<table>
<tr><th>Note</th></tr>
<td>
  In a future version of the specification, it will be allowed to access the values
  of parameters to the left of a parameter's default value expression. PUP-1985.
</td>
</table>

### Pass By Name

Pass-By-Name transfers given arguments to parameters based on their name; both arguments and
parameters are named in this style. In resource creation, resource defaults, and resource
overrides, language syntax associates argument names with values - e.g. in a resource expression:

    notify { 'mynotify': message => 'hello world' }

the argument `message` is associated with the value 'hello world'. When calling EPP, the arguments
to the template are specified in a hash.

    epp('the_template', { x => 10, y => 20 })

In pass-by-name:

* Only given values that are not `undef` counts as arguments with a value and these values
  are assigned to the corresponding parameters.
* Arguments not given at all, or set to `undef` results in a parameter having a missing
  argument, which leads to a "missing argument" error unless the parameter
  has a default value expression, in which case the result of evaluating that expression is used as the parameter's 
  value.
* For some types of callable entities, there may be automatic lookup/injection of missing values that
  can supply a default value - see the respective entities (resource, class, etc.).
* A captures-rest parameter is not allowed.
* **A default value expression does not have access to the parameters in the parameter list**, the
  order in which the parameters receive their values when the default value expression is evaluated 
  is undefined.

<table>
<tr><th>Note</th></tr>
<tr><td>
  The 3x runtime which deals with resource expression, resource defaults, 
  resource overrides, and collections, has unspecified behavior with respect to
  default value expression evaluation scope - they
  may be able to access other parameters, but this is only by coincidence as the order of
  evaluation is unspecified and varies with Ruby runtime version.
</td></tr>
<tr><td>
  In a future version of the specification, it will be allowed to access the values
  of parameters to the left of a parameter's default value expression. PUP-1985.
</td></tr>
</table>
