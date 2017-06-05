Parameters
===

The Parameters supported in different kinds of definitions share a common
grammar for parameter definitions - the `ParameterList` rule:

```      
ParameterList
  : '(' parameters += Parameter (',' parameters += Parameter)* ','? ')'
  ;
  
Parameter
  : type = Expression<Type>? captures_rest='*'? name = QualifiedName
      ('=' default_expression = Expression)?
  ;
```

Some features may not be semantically valid for a particular kind of definition.
Classes and Defines does not currently support "captures_rest". This may change
in the future.

Parameter Value Binding
===

When arguments are given during evaluation (i.e a function call, declaration of a class or resource) the argument values are assigned to variables as specified by the definition's parameters.

If a parameter is not given a value:

* An automatic data binding lookup is performed.
* If that did not produce a value, a specified `default_value` expression is evaluated
  and its result is used as the value of the corresponding variable.

In all cases:

* If the parameter's type does not accept the value (a given argument, value from data lookup,
  or value from default expression evaluation), an error is raised.
  
The Default Expression Evaluation
---

When a default value expression is evaluated, the runtime uses a special parameter scope.
This is an intermediate scope that is used only while assigning argument values, performing lookups and evaluating default value expressions. Once all parameter variables have been given their value, this context ceases to exist, and the resulting variables are set in the scope that is used to evaluate the body of the definition (e.g. the body of a function).

The parameter variables are give values from left to right. The parameter's value is bound to a variable that is available in the Parameter Scope. This means that default value expressions can access variables that are to the left (comes before) the parameter being processed.

The Parameter Scope, in addition to the parameter variables, also provides access to the top level scope.

<table><tr><th>Access to Parameter Variables, and Variables in 'scope':</th></tr>
<tr><th>Since Puppet 4.4.0</th></tr>
<tr><td>
  Are defined by this specification. A strict, "variable to the left may be referenced" rule
  applies. The rules for how to access variables in other scopes are also specified.
</td></tr>
<tr><th>Before Puppet 4.4.0</th></tr>
<tr><td>
  The behavior was undefined. In some cases variable values to the left could be accessed,
  in other cases it did not work. Default value expressions could in some cases
  reference variables in the calling scope! It could also introduce variables
  in the calling scope as a result of the undefined and untested behavior.
  <br/>
  For versions before Puppet 4.4.0, default value expressions should only use literal values
  or make references to fully qualified variables that a user knows are already evaluated.
</td></tr>
</table>


###  A default expression may reference a parameter to its left 
 
| Function |
| -------- |
| `function example($a = 10, $b = $a) {` <br/> `}`


| When called like this... | the parameters are set like this: |
| ---- | ---- |
| `example(0)` | `$a = 10`<br/>`$b = 10`
| `example(2)` | `$a = 2`<br/>`$b = 2`
| `example(2, 5)` | `$a = 2`<br/>`$b = 5`



### It is an error to reference a variable to the right of the default expression

| Function |
| -------- |
| `function example($a = 10, $b = $c, $c = 20) {` <br/> `}`

| When called like this... | the parameters are set like this:
| --- | ---
| `example(1,2,3)` | `$a = 1`<br/>`$b = 2`<br/>`$c = 3`
| `example(1,2)`   | `$a = 1`<br/>`$b = 2`<br/>`$c = 20`
| `example(1)`     | error, default expression for $b tries to illegally access not yet evaluated $c


### The evaluation of each parameter has separate match scope

Numerical variables refer to the result of the last performed regular expression
match. When evaluating parameters, these are reset before evaluation
of each parameters' default expression. numerical variables are undef when there is no
preceding match, or where such a match did not produce a matching capture for the numeral.

### Numerical variables are undef when there is no match scope

| Function |
| -------- |
| `function example($a = $0, $b = $1) {` <br/> `}`

| When called like this... | the parameters are set like this:
| --- | ---
| `example()`      | `$a = undef`<br/>`$b = undef`


### A match scope for a parameter does not affect match scopes to its right

| Function |
| -------- |
| `function example($a = ['hello' =~ /(h)(.*)/, $1, $2], $b = $1) {` <br/> `}`

| When called like this... | the parameters are set like this:
| --- | ---
| `example()`      | `$a = [true, 'h', 'ello']`<br/>`$b = undef`

| Function |
| -------- |
| `function example($a=['hello' =~ /(h)(.*)/, $1, $2], $b=['hi' =~ /(h)(.*)/, $1, $2], $c=$1) {` <br/> `}`

| When called like this... | the parameters are set like this:
| --- | ---
| `example()`      | `$a = [true, 'h', 'ello']`<br/>`$b = [true, 'h', 'i']`<br/>`$c = undef`


### Match scopes nest per parameter

| Function |
| -------- |
| `function example($a = ['hi' =~ /(h)(.*)/, $1, if 'foo' =~ /f(oo)/ { $1 }, $1, $2], $b = $0) {` <br/> `}`

| When called like this... | the parameters are set like this:
| --- | ---
| `example()`      | `$a = [true, 'h', 'oo', 'h', 'i']`<br/>`$b = undef`


Note that the top level match scope is restored at index 3, and empty again for the next parameter (`$b`).

### A Match scope from other scopes is not available:

| Function |
| -------- |
| `'foo' =~ /(f)(o)(o)/`<br/>`function example($a = $0 {` <br/> `}`

| When called like this... | the parameters are set like this:
| --- | ---
| `function caller() {`<br/>&nbsp;&nbsp;`'foo' =~ /(f)(o)(o)/`<br/>&nbsp;&nbsp;`example()`<br/>`}`<br/>`caller()` | `$a = undef`
| `function caller() {`<br/>&nbsp;&nbsp;`example()`<br/>`}`<br/>`'foo' =~ /(f)(o)(o)/`<br/>`caller()` | `$a = undef`


### Assignments are not allowed except in a nested scope:

| These Function Definitions                       | All result in error
| --------                                         | :-----:
| `function example($a = $x = $10) { }`            | Assignment not allowed here
| `function example($a = [$x = 10]) { }`           | - " - 
| `function example($a = $a) { }`                  | - " - 
| `function example($a = ($b = 3), $b = 5) { }`    | - " - 
| `function example($a = 10, $b = ($a = 10)) { }`  | - " - 


## Assignments are allowed inside lambdas that are nested in the default expressions

```
 function example(
   $a = [1,2,3],
   $b = 0,
   $c = $a.map |$x| { $b = $x; $b * $a.reduce |$x, $y| {$x + $y}}
 ) { }

 example()
```

 results in:

```
   $a => [1,2,3]
   $b => 0
   $c = [6, 12, 18]
```

### Nested lambdas have access to enclosing match scope

```
function example($a = case "hello" {
  /(h)(.*)/ : {  
    [1,2,3].map |$x| { "$x-$2" }
  }
})
example()
```

results in:

```
$a = ["1-ello", "2-ello", "3-ello”]
```

### Nested lambdas have access to parameter scope

```
function example($a = "hello",
  $b = [1,2,3].map |$x| { "$x-$a" })
}
example()
```

results in:

```
$a = ["1-hello", "2-hello", "3-hello”]
```

### Parameter scope is not available in function block

```
function example($a = "hello" =~ /.*/) {
  notify { test: message "Y$0es" }
}
example()
```

results in: A notify “test” with message “Yes”

### Accessing earlier match results can be done using the match function:

```
function example(
  $a = "hello".match(/(h)(.*)/),
  $b = $a[0],
  $c = $a[1]
) { }
example()
```

results in:

```
$a == ['hello', 'h', 'ello']
$b == 'hello'
$c == 'h'

```

### Duplicate keys in arguments by name calls are errors:

```
define example($a) { }
example { 'test':
  a => 10,
  a => 20,
}
```

result:

```
error, duplicate specification of parameter $a
```

### Defines and Classes allows access from the right in all cases:

```
define example($a, $b=$a) { }
example { test: a=>10 }
```

```
define example($a=5, $b=$a) { }
example { test: a=>10 }
```

```
define example($a=10, $b=$a) { }
example { test: }
```

In all the examples, the result would be:

```
$a = 10
$b = 10
```

This works the same way for `class`, with the additional rules when there is a value bound to `$a` in data binding:

1. the bound value is used when an argument was not given
2. a default expression is then not evaluated


### Access to parameters in an outer scope

There are issues when referencing variables that do not exist in the parameter list, but exist in an outer scope.

### Functions

Functions can only access global scope and fully qualified variables referencing class parameters for evaluated classes. Such references are subject to evaluation order and should be avoided.

Functions cannot access variables in node scope.

```
class foo {
  $bar = '$bar in foo'
}
include foo

$surprise = '$surprise in top scope'

node default {
  $surprise = '$surprise in node scope'
}

function example($a = $surprise, $b = $foo::bar) {
  notice $a
  notice $b
}
example()
```

Would notice:

```
$surprise in top scope
$bar in foo
```

### Metaparameters are available in Parameter Scope

```
define example($a = $title) { }
example { 'hello' : }
```

results in:

```
$a == 'hello'
```
