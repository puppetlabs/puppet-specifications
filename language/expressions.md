Expressions
===
L- and R-Value Expressions
---
A Puppet Program consists of a sequence of Expressions. There are two kinds of expressions:

* R-value expressions that produce a result (of some type)
* L-value expressions that provide an assignable "slot"

The letters `L`, `R` are used as type parameters e.g. `Expression<R>`in this specification
only (there are no such types in the type system).

### L-value Expressions

The L-value expressions are Variable Expressions when on the LHS in an Assignment Expression.
  
<table><tr><th>Note</th></tr>
<tr><td>
  Versions of the Puppet Programming Language before 4x allowed assignment to unassigned slots
  in <code>Array</code> and <code>Hash</code> values - i.e. an Access Expression
  (e.g. <code>$a[1]</code>) was also an L-value. This is no longer supported - all variables
  and values are strictly immutable in the Puppet Programming Language.
</td></tr>
</table>
     
### R-Value Expressions

All other expressions produce a value.

Precedence
---
Operators and expressions in the Puppet Programming Language have a defined precedence.
This is shown in the table [Expression / Operator Precedence].

[Expression / Operator Precedence]: expression_precedence.md

Literal Value Expressions
---
### Literal Numbers

    # Integers
    10   # decimal
    0777 # octal
    0xFF # hexadecimal
    
    # Floating Point
    0.1
    31.415e-1
    0.31415e1
     
Numbers are tokens produced by the Lexing of the source text. See [Numbers] in [Lexical Structure]. Literal Numbers evaluate to the value of the token interpreted in the appropriate base.

[Numbers]: ./lexical_structure.md#numbers
[Lexical Structure]: ./lexical_structure.md

Numbers evaluate to themselves.

### Literal Strings

    # Single quoted strings
    'hello'
    'I take a bit
    more room'
    'He said "hello", but it sounded like \'yello\''
    
    # Double quoted strings
    "You can quote me on that"
    "I keep \t of things around here"
    "I can not drink more than $max_beers beers"
    
    # Heredoc
    @(END)
    Text until the given end marker
    is in the resulting string.
    END
    
A single quoted string is a single token produced by the Lexing of the source text [Strings] in [Lexical Structure]. Lexical processing also produces [Heredoc][lexical-heredoc] is also the result of lexical processing

[Strings]: ./lexical_structure.md#strings
[lexical-heredoc]: lexical_structure.md#Heredoc

A Single Quoted string evaluates to a runtime String type.

A Double Quoted String is a sequence of text string parts, and expression parts. When evaluated
the text parts evaluate to runtime String type, and the expression parts are first evaluated and the result is converted into a runtime String type. The produced value is the concatenation of
all the produced runtime Strings into a single String.

The text parts of a double quoted string are produced by Lexing of the source text. See [Double Quoted String Expression Interpolation]] in [Lexical Structure] for details.

[Double Quoted String Expression Interpolation]: ./lexing_structure.md#double-quoted-string-expression-interpolation

Both types of strings (single and double quoted) can span multiple lines.
When they do, the \r\n or \n line endings are included in the result. There is no unification of line endings.

#### String Interpolation

String interpolation can be performed two different ways:

* `"$varname"` - interpolates the result of referencing the variable named 'varname'
* `"${expression}"` - interpolates the result of evaluating the embedded expression.

The expression part has the following rules:

* `class`, `define`, or `node` expressions; or statement-like function calls
  (only function name without parentheses) are not allowed.
* Automatic conversion to a variable is performed if the expression has one of the forms:
  * `${<KEYWORD>}` - e.g. `${node}`, `${class}` becomes `${$node}`, `${$class}`
  * `${<QualifiedName>}` - e.g. `${var}` becomes `${$var}`
  * `${<DECIMAL>}` - e.g. `${0}` becomes `${$0}`
* Automatic conversion is also performed in the following cases but variables having the same name as 
  a keyword must be written with a preceding `$`:  
  * `${<AccessExpression>}` - e.g. `${var[key]}`, `${var[key][key]}` becomes `${$var[key]}`,
    `${$var[key][key]}`
  * `${<MethodCall>}` - e.g. `${var.each ...}` becomes `${$var.each}`, which also works for the 
    leftmost name in a sequence of method calls e.g. `${var.fee.foo}` becomes `${$var.fee.foo}`  
* **In all other cases a name or number that should be interpreted as a variable must be
  preceded with a `$`**
  * `${if + 1}` - **error**, i.e. not `$if + 1`
  * `${2 + 2}` - **is 4**, not `$2 + 2`
  * `${x + 3}` - **error**, is `'x' + 3`, not `$x + 3` (which yields an error
     because `+` does not operate on `String`)
  * `${if[2]}` - **error**, since `if` is a keyword and the expression is not just the if-name 
    (causes syntax error since an if expression is allowed, but must have correct syntax e.g.
     `${if true { 'always' } else { 'never' }}`

<table><tr><th>Note</th></tr>
<tr><td>
  These rules are different from the rules in Puppet 3x where many constructs did
  not work because of failure to recognize what should <b>not</b> be interpreted 
  as a variable reference. Anything but the simplest forms of expression interpolation
  could have surprising effect.
</td></tr>
</table>

The result of the expression is converted to a `String` as specified in the following section.

#### Expression Result to String Conversion

* `undef` is converted to an empty string ''
* `QualifiedName` is converted to the reference in string form
* `QualifiedReference` is converted to string
* `Boolean` is converted to 'true' or 'false' respectively
* A `String` is copied verbatim
* A `Numeric` is converted to string using decimal radix (base 10), and uses platform specific
  defaults for conversion of floating points numbers (the result may vary from platform to
  platform). (Precise control over numeric formatting is provided by the `sprintf` function).
* Regular Expressions are converted to a regular expression pattern string in transitive form (can
  be converted back to a regular expression again)
* A `Type` is converted to its program source text form
* An `Array` is converted to string by enclosing the contents in `'['` `']'` and then applying the
  conversion rules recursively to each element using `', '` to separate the elements. 
* A `Hash` is converted to string by enclosing the contents in `'{'` `'}'` and then applying the
  conversion rules to each element's key and value, producing `<key> '=>' <value>` for each element
  separated by `', '`.
* For `Array` and `Hash`, no trailing comma is produced after the last element.

### Heredoc

Heredoc is covered in a separate section. See [Heredoc].

[Heredoc]: heredoc.md

### Qualified Name

A qualified name evaluates to a string unless it occurs in a context where the name
has specific meaning.

     $a = apache::port # equal to $a = 'apache::port'

### Qualified Reference

A qualified reference evaluates to a Type.

     $a = Integer # a is a reference to the Integer type
     
### Regular Expression

A regular expression pattern evaluates to a runtime regular expression.

     $a = /.*/  # a is a reference to the regular expression
     
Array and Hash Expressions
---
### Array Expression

A "literal" Array has the following syntax:

     LiteralArray
       : '[' ((Expression<R> (',' Expression<R>)*)? ','?) ']'
       ;
     
The expressions are evaluated from left to right, and a runtime array is produced with
the result. The expressions must result in an R-value.

The Puppet Programming Language `'['` token is used in grammatical constructs in a way that
creates an ambiguity. This is resolved by the following rules:

* `[]` as an access operator (accessing an 'identified detail' from the LHS) has higher precedence
  than `[]` as a Literal Array.
* When `[]` appears first in a file, or after a `WHITESPACE`, the intermediate whitespace sequence
  changes the lexical meaning of the initial `'['` to mean start of literal array.
* The precedence can be modified by using an expression separator `';'` between the LHS and `'['`.
* A `[]` that appears without a LHS is always interpreted as a literal array.

Examples:

     $a = [1, 2, 3] # $a becomes Literal Array of 3 numbers
     $x = $a[1]     # $x becomes 2 (Accessing element at index 1 in the value referenced by $a)
     $x = $a; [1]   # $x becomes the literal array, a literal array containing '1' is produced
     $x = abc[1]    # $x becomes 'b' (character at index 1 in string 'abc')
     abc [1]        # calls the function abc with the literal array containing '1' as an argument
     foo()[1]       # calls function foo and gets index 1 in returned enumerable
     foo() [1]      # calls function foo, then produces an array with the Integer 1
     
### Hash Expression

A "Literal" Hash has the following syntax.

     LiteralHash
       : '{' ((key = HashEntry (',' value = HashEntry)*)? ','?)) '}'
       ;

     HashEntry
       : Expression<R> '=>' Expression<R>
       ;
     
The hash entries are evaluated from left to right, key before value and a runtime hash
object is produced with all of the entries.

Operators
---
### + operator

     PlusExpression : Expression<R> '+' Expression<R> ;

* Performs a concatenate/merge if the LHS is an Array or Hash
* Adds LHS and RHS numerically otherwise
  * Operation fails if LHS or RHS are not numeric
* Is not commutative for non numeric/string operands ( `[1,2,3] + 3` is not the same as `3 + [1,2,3]`,
  and `[1,2,3] + [4,5,6]` is not the same as `[4,5,6] + [1,2,3]` )
  
#### Addition

Addition of integer values produces an integer result. If one of the operands is a `Float` the
result is also a `Float`. An implementation may raise an error if integral values overflow, but
may never silently produce an incorrect value.

    1 + 1      # produces 2
    1.0 + 1.0  # produces 2.0

##### Timestamps and Timespans

Timestamps and Timespans can participate in most arithmetic operations. 

*<small>T = Timestamp, D = Timespan (Duration), I = Integer (seconds), and F = Float (seconds with fraction)</small>*

    T + T is illegal
    T + D = T
    T + I = T
    T + F = T
    D + T = T
    D + D = D
    D + I = D
    D + F = D
    I + T = T
    F + T = T
    I + D = D
    F + D = D

Illegal operations:

    T + T

#### Concatenation / Merge

* When LHS is an `Array`
  * Concatenates an array or a non array value converted to a single entry array 
    to the end of a new copy of the LHS array.
  * If the RHS is a Hash, it is converted to an `Array` before concatenation (to instead
    concatenate a `Hash`, use the `<<` operator).
* When LHS is a `Hash`
  * Merges a Hash by copying the LHS and adding or overwriting keys with the RHS hash
  * If the RHS of a merge is an `Array`, it is converted to a `Hash` (the array should be
    on the form `[key, value, key, value, ...]`, or `[[key, value], [key, value], ...]`
    * if the array does not have one of the expected forms and error is raised.
  * The merged result retains the insertion order of the LHS's keys irrespective of if
    the value has been modified or not. Additional merged keys from the RHS are inserted into
    the result in their RHS order.

Examples

    # LHS must evaluate to an Array or a Hash (or it is a form of arithmetic expression)
    [1,2,3] + [4,5,6]               # => [1,2,3,4,5,6]
    [1,2,3] + 4                     # => [1,2,3,4]
    [1,2,3] + {a => 10, b => 20}    # => [1,2,3, [a, 10], [b, 20]]

    {a => 10, b => 20} + {b => 30}  # => {a => 10, b => 30}
    {a => 10, b => 20} + {c => 30}  # => {a => 10, b => 30, c => 30}
    {a => 10, b => 20} + 30         # => error
    {a => 10, b => 20} + [30]       # => error
    {a => 10, b => 20} + [c, 30]    # => {a => 10, b => 20, c => 30}

### - operator

     MinusExpression : Expression<R> '-' Expression<R> ;

* Performs a delete if the LHS is an `Array` or `Hash`
* Subtracts RHS from LHS otherwise
  * LHS and RHS are converted to `Numeric` (see [the section on Numeric Conversions][1] in Conversions and Promotions)
  * Operation fails if LHS or RHS are not numeric or conversion failed
* Is (by definition) not commutative
  
#### Subtraction

Subtraction of integer values produces an integer result. If one of the operands is a `Float` the
result is also a `Float`. An implementation may raise an error if integral values underflow, but
may never silently produce an incorrect value.

    10 - 1     # produces 9
    10.0 - 0.1 # produces 9.9
    
The following applies when a Timestamp or Timespan is involved:

*<small>T = Timestamp, D = Timespan (Duration), I = Integer (seconds), and F = Float (seconds with fraction)</small>*

    T - T = D
    T - D = T
    T - I = T
    T - F = T
    D - D = D
    D - I = D
    D - F = D
    I - D = D
    F - D = D

Illegal operations:

    D - T
    I - T
    F - T

#### Delete

Deletion produces the LHS \ RHS (set difference).

* Deletes matching entries from the LHS as given by the RHS. A copy of the LHS is first created,
  the original LHS is unchanged. The copy (after deletions) is produced as the result.
* When LHS is an `Array`, RHS, if not already an array, is transformed to an array and all matching 
  elements are removed (matching is done by equality `==` comparison of each array element).
* When LHS is a `Hash`;
  * and the RHS is an `Array`, the entries with keys matching the elements in the array are deleted
  * and the RHS is a `Hash`, the entries with matching keys are deleted

Examples:
   
    # LHS must evaluate to an Array or a Hash (or it is a form of arithmetic expression)
    [1,2,3,4,5,6] - [4,5,6]         # => [1,2,3]
    [1,2,3] - 3                     # => [1,2]
    [1,2,b] - {a => 1, b => 20}     # => [2]

    {a => 10, b => 20} - {b => 30}  # => {a => 10}
    {a => 10, b => 20} - a          # => {b => 20}
    {a => 10, b => 20} - [a,c]      # => {b => 20}

### unary - operator

     UnaryMinusExpression : '-' Expression<R> ;

* Changes the sign of the operand
  * RHS is converted to `Numeric` (see [the section on Numeric Conversions][1] in Conversions and Promotions)
  * Operation fails if RHS is not numeric or if conversion failed

### * operator

     MultiplicationExpression : Expression<R> '*' Expression<R> ;

* Multiplies LHS and RHS
  * LHS and RHS are converted to `Numeric` (see [the section on Numeric Conversions][1] in Conversions and Promotions)
  * Operation fails if LHS or RHS are not numeric or if conversion failed

Multiplication of integer values produces an integer result. If one of the operands is a Float the
result is also a Float. An implementation may raise an error if integral values overflow, but
may never silently produce an incorrect value.

The following applies when a Timestamp or Timespan is involved:

*<small>T = Timestamp, D = Timespan (Duration), I = Integer, and F = Float</small>*

    D * I = D
    D * F = D
    I * D = D
    F * D = D

Illegal operations:

    T * <any>
    <any> * T
    D * D

### unary * operator (splat)

    UnarySplatExpression : '*' Expression<R> ;
    
* Transforms the RHS Expression to an `Array` if not already an `Array`
  * If the RHS evaluates to `undef` the result is an empty array in general and interpreted as
  *nothing* when unfolded where a comma separated list of values is accepted.
  * If the RHS is a `Iterator` it is unrolled into the produced `Array`.
  * If the RHS is a `Hash` it is transformed to an `Array` of key-value arrays.
  * Any other value is wrapped in an `Array`.
* Unfolds the content of the RHS array (or just converted value) when applied in a context where a 
  comma separated list of values is accepted:
  * arguments to a call
  * options in a Case Expression Proposition
  * options in a Select Expression Proposition

Example:

    $args = [1,2,3]
    foo(*$args)
    
    # same result as
    foo(1,2,3)

Note that unfold of `*undef` in a case or select does not match anything, not even undef.

### / operator

     DivisionExpression : Expression<R> '/' Expression<R> ;

* Divides LHS by RHS
  * LHS and RHS are converted to `Numeric` (see [the section on Numeric Conversions][1] in Conversions and Promotions)
  * Operation fails if LHS or RHS are not numeric or conversion failed
  * Division by 0 is an error

Division of integer values produces an integer result (without rounding).
If one of the operands is a `Float` the result is also a `Float`.

The following applies when a Timestamp or Timespan is involved:

*<small>T = Timestamp, D = Timespan (Duration), I = Integer, and F = Float</small>*

    D / D = F
    D / I = F
    D / F = F

Illegal operations:

    T / <any>
    <any> / T
    I / D
    F / D

### % (modulo) operator

     ModuloExpression : Expression<R> '%' Expression<R> ;

* Produces the remainder (modulo) of dividing LHS by RHS
  * LHS and RHS are converted to `Numeric` (see [the section on Numeric Conversions][1] in Conversions and Promotions)
  * Operation fails if LHS or RHS are not `Integer` or if conversion failed
  * Modulo by 0 is an error
  
Note that `%` is not supported for `Float` (an error is raised) as this creates very confusing results.

The following applies when a Timestamp or Timespan is involved:

*<small>T = Timestamp, D = Timespan (Duration), I = Integer, and F = Float</small>*

    D % I = I (seconds)
    I % D = F (seconds and fractions of second)

Illegal operations:

    T % <any>
    <any> % T
    D % D
    F % D
    D % F

### << operator

     LeftShiftExpression : Expression<R> '<<' Expression<R> ;

* Performs an *append* if the LHS is an `Array`
* Performs *binary left shift* of the LHS by the RHS count of shift steps otherwise
  * LHS and RHS are converted to `Numeric` (see [the section on Numeric Conversions][1] in Conversions and Promotions)
  * Operation fails if LHS or RHS are not `Integer` or if conversion failed
  * A left shift of a negative count reverses the shift direction

#### Left Shift

Left shift is performed on `Integer` numbers. The LHS is shifted the given amount of bits to the
left. The shift does not overflow.

     1 << 1  # 2
     2 << 2  # 8
     8 << -1 # 4

#### Append

When the LHS is an `Array`, the RHS is appended to the end of a copy of the LHS, and the result
is produced. The RHS is not converted.

Examples:

     [1,2,3] << 4       # [1,2,3,4]
     [1,2,3] << [4]     # [1,2,3,[4]]
     [1,2,3] << {a=>10} # [1,2,3,{a=>10}]

### >> operator

     RightShiftExpression : Expression<R> '>>' Expression<R> ;

* Performs right shift of the LHS by the RHS count of shift steps otherwise
  * LHS and RHS are converted to `Numeric` (see [the section on Numeric Conversions][1] in Conversions and Promotions)
  * Operation fails if LHS or RHS are not `Integer` or if conversion failed
  * A right shift of a negative count reverses the shift direction

Right shift is performed on `Integer` numbers. The LHS is shifted the given amount of bits to the
right. The shift does not underflow. A value smaller than 0 is never produced.

     1 >> 1   # 0
     8 >> 2   # 2
     2 >> -1  # 4
     
### and, or, !, logical operators

     AndExpression
       : Expression<R> 'and' Expression<R>
       ;
     
     OrExpression
       : Expression<R> 'or' Expression<R>
       ;
       
     NotExpression
       : '!' Expression<R>
       ;

The logical connectives `and`, `or` evaluates their LHS and RHS until the truth or falsehood of
the expression is known. Remaining evaluation is skipped.

* The `and` operator produces `true` if both LHS and RHS are "truthy", and `false` otherwise
* The `or` operator produces `true` if either LHS or RHS are "truthy", and `false` otherwise
* The `and` operator has higher precedence than `or`.
* The unary `!` (not) operator reverses its operand, `false` if the operand is "truthy", and `true` 
  otherwise.
* The `!` operator has higher precedence than both `and` and `or`.

Examples:

     true and false  # false
     true or false   # true
     true and 1      # true
     true and ''     # true
     true and undef  # false
     true and !undef # true
     true and !false # true

See [Boolean Conversion] for more information about "truthy".

[Boolean Conversion]: types_values_variables.md#boolean-conversion


Equality and Comparison Operators
---
### Equality

#### == operator

     EqualityExpression
       : Expression<R> '==' Expression<R>
       ;


Tests if LHS is equal to RHS and produces a Boolean.

* If the base type of LHS and RHS is different the result is `false`
* String comparison is done case independently.
  * **Case independence is only done for the /[a-zA-Z]/ character range** as the rest of
    the characters' status depends on Locale. [PUP-1800]
* Arrays are equal if they have the same size and each element is equal (with the semantics of
  the `==` operator)
* Hashes are equal if they have the same size and each element is equal (with the semantics of
  the `==` operator applied to the keys and values).
* Types are equal if they represent the same type
* Regular Expressions are equal if they have identical pattern strings.
* Booleans are equal if they represent the same value - a boolean is not equal to a "truthy" value
* All other objects are equal if the underlying runtime representation reports them as equal (safety 
  net)

[PUP-1800]: https://tickets.puppetlabs.com/browse/PUP-1800

Examples

     true   == true    # true
     true   == ''      # false
     false  == ''      # false
     true   == undef   # false
     false  == undef   # false
     
     false == !''      # true
     false == !!''     # false

#### != operator

     InequalityExpression
       : Expression<R> '!=' Expression<R>
       ;

Tests if the LHS is not equal to RHS and produces a `Boolean`.

The logical reverse of the `==` operator. The same as evaluating `!(LHS == RHS)`.

### Pattern Match

Pattern matching supports matching a value against a regular expression or against a type.

#### =~ match operator

     MatchExpression
       : Expression<R> '=~' pattern = Expression<R>
       ;

Tests if the LHS matches the RHS pattern expression and returns a `Boolean` result. As a
side effect when the RHS is a Regular Expression or a `String`, the variables `$0`-`$n` are set with the produced captured group matches (or `undef` if there is no match or non matching groups).

When the RHS is a `Type`:

* the match is true if the LHS is an instance of the type
  * No match variables are set in this case.

When the RHS is a `SemVerRange`

* the match is true if the LHS is a `SemVer`, and the version is within the range
* the match is true if the LHS is a `String` representing a SemVer, and the version is within the range
* If the LHS is neither a `String` with a valid `SemVer` representation, nor a `SemVer` an error is raised.
* otherwise the result is `false` (not in range).

When the RHS is not a `Type`:

* If the RHS evaluates to a `String` a new Regular Expression is created with the string value
  as its pattern.
* If the RHS is not a `Regexp` (after string conversion) an error is raised.
* If the LHS is not a `String` an error is raised. (Note, `Numeric` values are **not** converted to
  `String` automatically because of unknown radix).

The numeric variables `$0`-`$n` are set as follows when RHS is not a type:

* `$0` represents the entire matched (sub-) string
* `$1` represents the first (leftmost) capture group
* `$2`-`$n` represents the subsequent capturing groups enumerated from left to right
* Unmatched sections evaluate to `undef`
* Numeric variables `$0`-`$n` are not visible from outer scopes
* If a match is performed in an inner scope, it will obscure all numerical variables in outer scopes.

The numeric match variables are in scope until the end of the block if the match is performed
without introducing a conditional block, and until the end of the conditional constructs if
such a block is introduced.

Example:

    if abc =~ /(a)b(c)/ {
      # $0 == 'abc', $1 == 'a', $2 == 'c'
    }
    elsif {
      # same as above
    }
    else {
      # same as above
    }
    # $0-$n return to the values they had before the if
    
Example:

    $x = abc =~ /(a)b(c)/
    # $0 == 'abc', $1 == 'a', $2 == 'c' (until end of block, or next match)
    
Example using Type:

    [1,2,3] =~ Array[Integer]          # => true
    [1,999,5] =~ Array[Integer[1,10]]  # => false (one value > 10)

The setting of match variables is also covered per expression that introduces conditional
blocks (`if`, `elsif`, `case` and `? { }` (selector)).

<table><tr><th>3x Compatibility</th></tr>
<tr><td>
  The match expression works differently than in the 3x version of Puppet where the LHS
  is transformed (arrays are flattened, and numeric values are turned into
  decimal strings, etc.) before applying the regular expression. When similar behavior is wanted,
  in 4x. the <tt>in</tt> operator should be used. If flattening or other transformations are
  wanted, they should be done explicitly.
</td></tr>
</table>

#### !~ match operator

     NotMatchExpression
       : Expression<R> '!~' pattern = Expression<R>
       ;

Tests if the LHS does not match the RHS and returns a `Boolean` result. This is the same as evaluating `! (LHS =~ RHS)`. The numerical match variables are set as a side effect if the RHS
is not a `Type`.

See `=~` operator for details.

### <, >, <=, >=, comparison operators

     ComparisonExpression
       : Expression<R> ('<' | '>' | '<=' | '>=') Expression<R>
       ;

Comparisons are done by ordering the LHS and RHS as being less than, equal, or greater than.
A comparison operator converts the result to a `Boolean`.

* `<`, true if LHS is less than RHS
* `>`, true if LHS is greater than RHS
* `<=`, true if LHS is less than or equal to RHS
* `>=`, true if LHS is greater than or equal to RHS
* If `<=` is true so is `<` and `==`
* If `>=` is true so is `>` and `==`

#### Comparison Semantics per Type

* Comparisons of strings is case independent
  * **Case independence is only done for the /[a-zA-Z]/ character range** as the rest of
    the characters' status depends on Locale. [PUP-1800]
* It is possible to compare:
  * `String` with `String`
  * `Numeric` with `Numeric`, `Timespan`, or `Timestamp`
  * `Timespan` with `Timespan` or `Numeric`
  * `Timestamp` with `Timestamp` or `Numeric`
  * `Type` with `Type`
    * Here the smaller type is the more specific. See [The Type System], and example below.
* `SemVer` instances can be compared.
* It is not possible to compare other types (except for equality)

[The Type System]: types_values_variables.md#the-type-system

Comparison involving type:

* A type T is considered greater than (`>`) another type Q, if T is a wider (more general)
  type. e.g. `Any > Integer` is true.
* A type T is equal to another type Q if they describe the exact same type

### IN operator

The `in` operator tests if the LHS operand can be found in the RHS operand. Both LHS and RHS
are evaluated before conducting the test. The result produces a `Boolean` indicating if the LHS
was considered to be in the RHS.

When a search using the `in` operator is performed with a regular expression,
the match variables `$0`-`$n` will contain the values from the first successful
match. When matching against an `Array`, this will be the element of the
`Array` with the lowest index, whose value matches the regular expression. When
matching against a `Hash` the keys are searched in the order the keys were inserted.

Syntax:

    InExpression
      : Expression<R> 'in' Expression<R>
      ;

<table>
<tr><th>Note</th></tr>
<tr><td>
  The <code>in</code> operator in Puppet 3x is a mysterious beast, it does not use the Puppet
  rules for equality and results in paradoxes. It is also not very versatile (it allows searching
  for a fixed substring in a string, but not a patterns, a not a substring in a collection
  of strings/keys.
</td></tr>
</table>


#### Result per Type

The following table shows the result of searching for a LHS of a particular type in a RHS of a particular type.


| LHS         | RHS       | Description |
|------       |------     |------       |
| `String`    | `String`    | searches for the LHS string as a substring in RHS (LHS and RHS downcased), `true` if a substring is found. Also see [PUP-1800] regarding case. |
| `String`    | `SemVerRange` | `true` if the SemVer version represented by the LHS String is in the range
| `Regexp`    | `String`    | true if the string matches the Regexp (`=~`) |
| `Type`      | `String`    | `false` |
| *any other* | `String`    | `false` |
| `Type`      | `Array`     | `true` if there is an element that is an instance of the given type |
| `Regexp`    | `Array`     | `true` if there is an array element that matches the Regexp (`=~`). Non string elements are skipped.   |
| `SemVer`    | `SemVerRange` | `true` if the version is in the range
| *any other* | `Array`     | `true` if there is an array element equal (`==`) to the LHS |
| *any*       | `Hash`      | `true` if the LHS `in` the array of hash keys is `true` |
| *any*       | *any other* | `false` |

Assignment Operator
---

The assignment operator assigns the result of the RHS to one or more L-values produced by the LHS expression.
An L-value is a name referring to a named "slot" in the current scope (that is, typically a variable).

* A `$` variable produces an L-value name
* Only a Simple Name is accepted, it is not allowed to assign to something in another namespace
* Numerical L-values are not allowed (numerical variables are read-only and set by side effect
  of matching with a regular expression).
* Assignment is an R-value
* The value of an assignment is the value of the RHS
* An array of L-values forms a multi-assignment where several variables can be assigned at once from the given RHS source
* In a multi-assignment the result depends on the type of the RHS:
  * *Array* - each variable is assigned from the RHS array's index 0-n. It is an error if there are too few values.
  * *Hash* - each variable is assigned the value from the corresponding key in the RHS hash. It is in an error if the key is not present.
  * *Type[Class]* - each variable is assigned the value of the corresponding variable/parameter in the referenced class. The
    class must have been added to the catalog, and the referenced variable must exist, but may have an `undef` value assigned.

Assignment also takes place in parameter declarations of user defined resource types and
classes. An alternate form of assignment also takes place when resource attributes are set.
These are covered in [Catalog Expressions].

[Catalog Expressions]: catalog_expressions.md

    AssignmentExpression
      : Expression<L> '=' Expression<R>
      ;

Assigns the evaluated RHS value to the given L-value name. The RHS value is produced as the
result. Chained assignments are permitted.

Examples:

~~~puppet

    $a = 10
    $x = $y = 0

    # from array
    [$a, $b] = [1, 2]  # assigns 1 to $a, and 2 to $b

    # from hash
    [$a, $b] = { a => 10, b => 20, c => 30 }  # assigns 10 to $a, and 20 to $b

    # from class
    class mymodule::someclass::example($x = 100) {
      $a = 10
    }
    include example
    [$a, $x] = Class['mymodule::someclass::example']  # assigns 10 to $a, and 100 to $x

~~~

[ ] Access Operator
---

The AccessExpression operator `[]` is one of the most versatile in the Puppet Programming
Language. It has different meaning depending on the type of the LHS operand.

The grammar is:

    AccessExpression
     : Expression<R> '[' keys += Expression<R> (',' keys += Expression<R>)* ']'
     ;

The arity of the list of expressions varies (number of keys) with the evaluated type of the LHS.
The arity is never less than 1 (it is a syntax error).

The `[ ]` operator supports access to:

* one, or a range of elements from an `Array`
* one, or selection of keys from a `Hash`
* a single character from a `String`
* a range of characters (substring) from a `String`

The `[ ]` operator supports creation of parameterized types:

* a specialized (parameterized) type when applied to a more generic type
* a collection of types (for certain types)

The `[ ]` operator supports access to Resource instance attributes:

* the set attribute value of a resource parameter can be accessed

The various forms are detailed in the following sub-sections.

### Array Value [ ]

Accepts two signatures:

    ArrayAccess
      : SingleElementAccess | ElementRangeAccess
      ;
      
    SingleElementAccess
      : '[' index = Index ']'
      ;
      
    ElementRangeAccess
      : '[' index = Index ',' count = Index ']'
      ;

    Index <Integer>: Expression<R> ;
    
* `index` is an index starting at 0 (the first element), 1 is the element after the first etc.
* A negative index enumerate from the end, where -1 is the last element
  * A negative index that is abs(from) > length(array) is a position before the first element
* `SingleElementAccess` produces the element at the given `index`
  If the index is outside of the range of the array, the value `undef` is produced
* `ElementRangeAccess` produces an `Array` including the given range of elements, starting at
  index, and containing a (max) count of elements.
  * if count is negative it enumerates a position from the end and the count of elements
    to include is computed as the elements from the computed (start) index to the computed end index.
    * if this results in a range extending to the left of the index, an empty array is produced
  * If the computed range is partially outside of the array, the overlapping
    range is produced.
  * An empty overlapping range produces an empty `Array` (i.e. resulting count of elements in array 
    is 0)
  * (the value `undef` is never produced when a length is specified)
* Fewer than one key is a syntax error, and more than two keys generates a runtime error.

Examples:

    [1,2,3][2]       # => 3
    [1,2,3][2,1]     # => [3]
    [1,2,3][2,0]     # => []
    [1,2,3,4][1,2]   # => [2,3]
    [1,2,3][100]     # => undef
    [1,2,3][100,1]   # => []
    [1,2,3,4][-1]    # => 4
    [1,2,3,4][2,-1]  # => [3,4]
    [1,2,3,4][-5,-3] # => [1,2]
    [1,2,3,4][2,-3]  # => []

### Hash Value [ ]

Signature:

    HashElementAccess
      : '[' keys += Expression<R> (',' keys += Expression<R>)* ']'
      ;

* If keys contain a single key the result is the lookup of that key
  * If the key does not exist, `undef` is produced.
  * If the value entry is `undef`, `undef` is produced.
* for multiple given keys, the result is an array with the result of looking up each key from
  left to right.
  * Non existing keys does not produce entries in the result.
  * Value entries that are `undef` does not produce entries in the result.
  * If none of the keys were found, and empty array is produced.

Examples:

    {'a'=>1, 'b'=>2, 'c'=>3}['b']         # => 2
    {'a'=>1, 'b'=>2, 'c'=>3}['b', 'c']    # => [2, 3]
    {'a'=>1, 'b'=>2, 'c'=>3}['x']         # => undef
    {'a'=>1, 'b'=>2, 'c'=>3}['x', 'y']    # => []
    {'a'=>1, 'b'=>2, 'c'=>3}['x', 'b']    # => [2]
    
Note that the result of using multiple keys results in a compacted array where all missing and explicit `undef` entries have been removed.

### String Value [ ]

Access to characters in a string (a substring) has the following signature:

    StringAccess
      : Expression<String> '[' k1 = Expression<Integer> (',' k2 = Expression<Integer>) ']'
      ;

And with the following semantics:

* k1 denotes the **start index** where the first character in the string has index 0, the second
  character index 1, etc.
* A negative k1 is a start index resulting from (`string.length + k1`)
  * e.g. k1 == -1 means the index of the last character in the string, k1 == -2 the next to
    last etc.
  * if `string.length + k1` is negative, the index is negative and represents a position to
    the left of the string.  
* A positive k2 denotes the number of characters to (max) include in the result (**count**)
  * the available characters are included if there are fewer characters available than the count
* A negative k2 represents a computed count measured from the computed **start index** to the
  index computed the same way as the index for a negative k1
  * if the range extends to the left of the start index an empty string is produced
* If optional k2 is not given it defaults to 1
* If the given **start index** + **count** is outside of the range of the string, an empty
  string is produced.
* Fewer than one key is a syntax error, and more than two keys generates a runtime error.

Examples:

    "Hello World"[6]       # => "W"
    "Hello World"[1,3]     # => "ell"
    "Hello World"[6,-1]    # => "World"
    "Hello World"[-5,-1]   # => "World"
    "Hello World"[6,-2]    # => "Worl"
    "Hello World"[-11,-2]  # => "Hello Worl"
    "Hello World"[-12,-2]  # => "Hello Worl"
    "Hello World"[-666,-2] # => "Hello Worl"
    "Hello World"[-11, 2]  # => "He"
    "Hello World"[-12, 2]  # => "H"
    "Hello World"[-13, 2]  # => ""
    "abcd"[2,-3]           # => ""

### Operation on Types

#### Regexp Type [ ]

Creates a regular expression type from the given pattern. For more information about the type see [Regexp Type].

[Regexp Type]: types_values_variables.md#regexppattern

Signature:

    RegexpTypeAccess
      : Expression<Type<Regexp>> ('[' pattern = PatternExpression ']')?
      ;
    
    PatternExpression
      : Expression<String>
      | Expression<Regexp> 
      ;    

* The pattern must evaluate to a `String` or a `Regexp`
* If the pattern is a `String`
  * it must be a valid regular expression
  * The pattern string should not include the leading and trailing `/` used in a literal regular 
    expression (if they are included they become part of the pattern).
* A `Regexp` that represents all regular expressions is obtained by leaving out the `[]` part.
* A `Type[Regexp]` is not a substitute for a `Regexp` in match expressions, the `Pattern` type should
  be used if instance-of semantics is wanted.

Examples:

    $r = Regexp['(f)(o)(o)']         # => Regexp[/(f)(o)(o)/]
    'foo' =~ $pattern                # => true
    'bar' =~ $pattern                # => false
    notice $1                        # => 'o'
    'x' =~ Regexp[/x/]               # => false 'x' is a String, not a Regexp

#### Pattern Type [ ]

Creates a parameterized Pattern Type given one or more patterns. For more information see
[Pattern Type]. (A Pattern type is a pattern based enumeration of acceptable string values).

[Pattern Type]: types_values_variables.md#patternpatterns

Signature:

    PatternTypeAccess
      : Expression<Type<Pattern>> 
        ('[' patterns += (PatternExpr ',' patterns += PatternExpr) ','? ']')?
      ;

     PatternExpr
      : Expression<String>
      | LiteralRegexp
      | Expression<RegexpType>
      | Expression<PatternType>
      ;

* When a pattern is a `String`
  * it must be a valid regular expression
  * it should not include the leading and trailing `/` used in a literal regular expression
    (if they are used, they become part of the pattern).
* When the pattern is a `Type[Pattern]`, all of its patterns are included
* When the pattern is a `Type[Regexp]` , its pattern is included
* Does not set the numeric match variables when used in a match.
* An unparameterized `Pattern` represents nothing, and matches nothing

Examples:

    $pattern = Pattern[red, blue, green]  # => a pattern type
    'red' =~ $pattern                     # => true
    'blue' =~ $pattern                    # => true
    'yellow' =~ $pattern                  # => false

#### Enum Type [ ]

Specializes an `Enum` type by producing a new `Enum` with the given strings as possible values.
For more information see [Enum Type]

    EnumTypeAccess
      : Expression<Type<Enum>> ('['
         values += Expression<String> (',' values += Expression<String>)*
        ']')
      ;

Examples:

    Enum[blue, red, green]

[Enum Type]: types_values_variables.md#enumstrings
    
#### Hash Type [ ]

Specializes a Hash Type by producing a new type with parameterized types for key and value.

Signature:

    HashTypeAccess
      : Expression<Type<Hash>> ('[' 
            key_t = Expression<Type> ','  value_t = Expression<Type>
            (',' size_t = SizeConstraint)?
        ']')?
      ;
      
    SizeConstraint<Type<Integer>>
      : from = Expression<Integer> (',' to = (Expression<Integer> | 'default'))?
      ;

* The `value_t` and `key_t` must evaluate to types
* Fewer than two or more than four parameters raises an error
* When two types are given, the key type is the first, and the value type the second
* The size of the hash may be constrained by giving a min (from) and a max (to) integer value,
  and a literal `default` may be used to denote +Infinity.
* A min/from value < 0 raises an error
* Note that an unparameterized `Hash` defaults to `Hash[Scalar, Data, 0, default]`

Examples:

    Hash[String, Integer]            # => Hash[String, Integer] (type)
    $h = Hash[Scalar, String]        # => Hash[Scalar, String] (type)
    $h[]                             # => syntax error
    $h[Scalar, Integer]              # => Hash[Scalar, Integer] (type)
    
    Hash[Scalar, String, 1, 10]      # => Hash type with min 1, max 10, Scalar => String entries

#### Array Type [ ]

Specializes an Array Type by producing a new type with specific element type.

Signature:

    ArrayTypeAccess
      : Expression<Type<Array>> ('[' 
          value_t = Expression<Type> (',' size_t = SizeConstraint)?
        ']')?
      ;

    # SizeConstraint is the same as for Hash

* The key must evaluate to a `Type`
* One to three parameters may be given
  * Fewer or more parameters raises an error
* The size of the array may constrained by giving a min (from) and a max (to) integer value,
  and a literal `default` may be used to denote +Infinity.
* A min/from value < 0 raises an error
* Note that an unparameterized `Array` defaults to `Array[Data, 0, default]`.

Examples:

    Array                            # => Array[Data]
    Array[String]                    # => Array[String] (type)
    $a = Array[String]               # => Array[String] (type)
    $a[]                             # => syntax error
    $a[Integer]                      # => Array[Integer] (type)
    
    Array[Data, 1]                   # => Array[Data] (type) that is non empty
    Array[Data, 2,4]                 # => Array[Data] (type) with min 2, and max 4 entries

#### Tuple Type [ ]

Specializes a `Tuple` type by producing a new type that matches the specified sequence of
types. For more details about the type se [Tuple Type]

    TupleTypeAccess
      : Expression<Type<Tuple>> ('['
         types += Expression<Type> (',' types += Expression<Type> )*
         (',' size_t = SizeConstraint)?
        ']')?
      ;

* All parameters (except the final 1-2 size constraint parameters) must evaluate to `Type`
* An optional size constraint specifies the minim and maximum number of entries in a matching array.
* The `SizeConstraint` is the same as for `Hash`.
* An empty set of parameters raises an error

[Tuple Type]: types_values_variables.md#tuple-type

#### Struct Type [ ]

Specializes a `Struct` type by producing a new type that matches the specified mix of
name => type entries in a `Hash`. For more information about the type see [Struct Type].

    StructTypeAccess
      : Expression<Type<Struct>> ('['
         entries_t = Expression<Hash<String<1>, Type>>>
        ']')?
      ;

* The keys and types of entries are specified with a Hash
  * keys must be non empty strings
  * values must be instances of Type
* Size of the struct is determined by the number of specified entries
* Optional entries are supported by giving their type as `Optional[T]`

[Struct Type]: types_values_variables.md#struct-type

#### Collection Type [ ]

Specializes a `Collection` type by producing a new type for all collections within the specified
size range. For more information about the type see [Collection Type].

    CollectionTypeAccess
      : Expression<Type<Collection>> ('['
         size_t = SizeConstraint
        ']')?
      ;

* The `SizeConstraint` is the same as for `Hash`.
* It is an error to have an empty list of parameters

[Collection Type]: types_values_variables.md#collectionto-from

#### Class Type [ ]

Specializes a Class Type by producing a new type that refers to a particular class. For more information see [Class Type]

[Class Type]: types_values_variables.md#classclass_name


A Class type has two forms:

* *open* - Any Class
* *reference* - Specific class reference

Signature:

    ClassTypeAccess
      : Expression<Type<Class>
         ('['  names += Expression<String> (',' names += Expression<String>)* ']')?
      ;

The rules are:

* If the `[]` part is omitted, the created type represents all classes (an *open* `Class` type).
* When `[]` is applied to an **open** class:
  * The names must evaluate to `String`
  * One or more names may be given
    * no names raises a syntax error
  * If more than one name is given, the result is an `Array` of class types in **reference** form;
    evaluated from left to right.
* When `[]` is applied to a **reference** class type:
  * The names are references to the parameters or metaparameters of the referenced class and must
    evaluate to `String`.
  * Produces a single value when there is a single key, and an array of values otherwise

Examples:

    Class                            # => any class
    Class[apache]                    # => Class[apache] (reference to the class 'apache')
    Class[apache, nginx]             # => [Class[apache], Class[nginx]] (array of classes)
    $c = Class[apache]               # => Class[apache]
    $c[]                             # => syntax error
    
If the `[]` operator is applied to a class in *reference* form the result is the lookup of a
class parameter.

Examples:

    class myclass($x = 10, $y=20) { }
    include myclass
    Class[myclass][x]                # => 10
    $someclass = Class[myclass]
    $someclass[x]                    # => 10
    $someclass[y]                    # => 20
    $someclass[x, y]                 # => [10, 20]
    

Note that only parameters of a parameterized class can be obtained, it is not possible to
obtain the class variables using this syntax.

* Note that lookup of a parameter that has no value will result in lookup of its current default 
  value. **PUP-??? Open Issue**
* Evaluation of parameter lookup is evaluation order dependent and that resource instantiation is
  lazily evaluated.
* Note that metaparameters only include values for what has explicitly been assigned as they
  defaults are evaluated late, and may depend on other values.
* Note that metaparameters is an open ended concept where each metaparameter defines its own
  behavior.

#### Resource Type [ ]

Specializes a `Resource` type by producing a new type that refers to a particular subtype
of `Resource`, or a fully qualified instance of `Resource`, and when applied to a fully qualified 
`Resource` the value of a parameter is produced.

Note that, since all capitalized names are types, names that are taken to be specializations
of `Resource` e.g. `Resource['File'] == File`. For more information see [Resource Type]

[Resource Type]: types_values_variables.md#resourcetype_name-title

A Resource type has three forms:

* *open* - Any Resource
* *typed* - Specific resource type
* *reference* - Specific resource instance reference

Signature:

    ResourceTypeAccess
      : OpenResource | TypedResource | ResourceReference | ResourceTypeExpression
      ;

    # Any expression that evaluates to a Resource Type in some form
    ResourceTypeExpression<Type<Resource>>
      : Expression<Type<Resource>>
      ;
    
    OpenResource<Type<Resource>>
      : 'Resource'
      ;

    TypedResource<Type<Resource>>
      : 'Resource' '[' type_name = TypeNameExpression ']'
      ;
      
    ResourceReference<Type<Resource>>
      : 'Resource' 
          '[' type_name = TypeNameExpression 
              titles += Expression<String> (',' titles += Expression<String>)*
           ']'

    TypeNameExpression
      : Expression<String>
      | ResourceType
      ;


These rules apply:

* If expressed as just `Resource` (no `[]` part), a Resource type in **open** form is created.
* Accepts one or multiple keys
  * When the form is **open**:
    * The first key must evaluate to a `Resource` type (type key), or a `String` resource type name
      * Case is ignored if a string is given.
    * Subsequent (optional) reference keys must evaluate to `String`
    * Produces a single **typed** `Resource` type when there are fewer than 2 reference keys, and
      an array of **reference** `Resource` types otherwise
  * When the form is **typed**:
    * The keys are all reference keys and must evaluate to `String`
    * Produces a single **reference** `Resource` type when there are fewer than 2 reference keys,
      and an array of **reference** `Resource` types otherwise
  * When the form is **reference**:
    * The keys are references to the parameters of the referenced resource and must
      evaluate to `String`.
    * Produces a single value when there is a single key, and an array of values otherwise

* In all forms, a syntax error is raised if there are no keys.

Examples:

    Resource                           # => any resource type
    Resource[File]                     # => File
    Resource['File']                   # => File
    Resource['file']                   # => File
    Resource[file]                     # => File
    Resource[File, '/tmp/x']           # => File['/tmp/x']
    Resource[File]['/tmp/x']           # => File['/tmp/x']
    Resource[File, '/tmp/x', '/tmp/y]  # => [File['/tmp/x'], File['/tmp/y']]
    File                               # => File
    file                               # => "file" (a string, not a Resource type)
    File['/tmp/x']                     # => File['/tmp/x']
    File['/tmp/x', '/tmp/y']           # => [File['/tmp/x'], File['/tmp/y']]
    
    File['/tmp/x'][mode]               # => the value of the file /tmp/x's mode parameter
    
This shows that the left hand type can be specialized; an **open** `Resource` to a specific **typed** `Resource`, and a typed resource to a specific (titled) **Reference** resource (instance), and then further specialized to refer to a parameter of a referenced resource.

If a parameter is not explicitly set, a default value is returned if a user defined type's parameter has a default value expression, or if there is an already evaluated Resource Defaults expression that defines a default value for that type/parameter. In all other cases the result is `undef` for a parameter that is not explicitly set.

* It is an error to attempt to get a value for a name that is not an attribute of the type
* It is an error to attempt to get a value from a resource that is not instantiated (it may be 
  virtual or exported and unrealized)
* Note that Evaluation of parameter lookup is evaluation order dependent and that resource 
  instantiation is lazily evaluated. (This means that a resource instantiation followed immediately
  by a parameter access will not be able to get default values due to the lazy/
  queuing behavior of resource evaluation. See [Modus Operandi].
* Note that accessing a default value set via a Resource Defaults expression depends on evaluation 
  order as the Resource Defaults expression must have been evaluated for it to have any effect. See 
  [Modus Operandi].
* Note that a collector expression with an override clause may modify attribute values of resources
  and that overrides are evaluated late.
  
Due to the dependency on evaluation order and that late evaluating overrides and Resource Override expressions accessed resource parameter values may be different than what the value eventually ends up being in the produced catalog.

[Modus Operandi]: modus-operandi.md

#### Integer Type [ ]

Produces a new `Integer` type with a range. An `Integer` type has the default range -Infinity to +Infinity.
An `Integer` range where one or both ends is Infinity is said to be an *open range*, else it is a
*closed range*. The set of values in a range is inclusive of the given values.

It is possible to iterate over the values in a closed
range. The range can be described as an ascending or descending range (the values in the set are
the same, but the order is different).

Signature:

    IntegerType
      : Expression<Type<Integer>> '[' exact = IntegerRangeValue ']'
      | Expression<Type<Integer>> '[' from = IntegerRangeValue ',' to = IntegerRangeValue ']'
      ;
      
    IntegerRangeValue
      : Expression<Integer>
      | 'default'
      ;  

* Accepts one or two integer range values
* A range value must evaluate to `Integer`, or to literal `default`
* A value of default means -Infinity if given as the value of `from`, and +Infinity if given
  as `to`. If only an exact value of `default` is given this is the same as
  `Integer[default, default]`,
  which again is the same as just `Integer` (i.e. all integers +/- Infinity).
* The `from` value may be greater than the `to` value
* Values may be negative
* If the `to` key is smaller than the first key the direction of the range is in descending order,
  while the range of values is the same as if they were specified in ascending order. (This
  only matters if the type is enumerated).

Examples:

    Integer[2]        # the exact value 2
    Integer[1,3]      # values 1 to 3 inclusive
    Integer[3,1]      # values 3 to 1 inclusive
    
    Integer[1,3].each {|x| . . . }   # iterate over 1,2,3
    
<table><tr><th>Note</th></tr>
<tr><td>
  It is the type that represents a range and values are created on demand when iterating
  (no array should be generated).
</td></tr>
</table>

#### Float Type [ ]

Produces a new `Float` type with a range. A `Float` type has the default range -Infinity to +Infinity.
A `Float` range where one or both ends is Infinity is said to be an *open range*, else it is a
*closed range*. The set of values in the range is inclusive of the given values.

It is not possible to iterate over the values (in contrast to
an `Integer` range). The range can be described as an ascending or descending range (the values in the set are the same).

Signature:

    FloatTypeAccess
      : Expression<Type<Float>> '[' exact = FloatRangeValue ']'
      | Expression<Type<Float>> '[' from = FloatRangeValue ',' to = FloatRangeValue ']'
      ;
      
    FloatRangeValue
      : Expression<Numeric>
      | 'default'
      ;  

* Accepts one or two keys
* Keys must evaluate to a `Float`, or an `Integer`, or to literal `default`
* A value of default means -Infinity if given as the value of `from`, and +Infinity if given
  as `to`. If only an exact value of `default` is given this is the same as
  `Float[default, default]`,
  which again is the same as just `Float` (i.e. all floating point values in the range +/- Infinity).
* The `from` value may be greater than the `to` value.
* The range values may be negative.

Examples:

    Float[2]          # the exact value 2.0
    Float[2.0]        # the exact value 2.0
    Float[1, 3.2]     # values 1.0 to 3.2 inclusive
    Float[3.2,1.5]    # values 3.2 to 1.5 inclusive
    Float[-1.0,1.0]   # values -1.0 to 1.0 inclusive
    

<table><tr><th>Note</th></tr>
<tr><td>
  It is not possible to enumerate a `Float` range.
</td></tr>
</table>

#### Timespan Type [ ]

Produces a new `Timespan` type with a range. A `Timespan` type has the default range -Infinity to +Infinity.
A `Timespan` range where one or both ends is Infinity is said to be an *open range*, else it is a
*closed range*. The set of values in the range is inclusive of the given values.

Signature:

    TimespanTypeAccess
      : Expression<Type<Timespan>> '[' exact = TimespanRangeValue ']'
      | Expression<Type<Timespan>> '[' from = TimespanRangeValue ',' to = TimespanRangeValue ']'
      ;
      
    TimespanRangeValue
      : Expression<Timespan>
      | Expression<Initializer[Timespan]>
      | Expression<String>
      | Expression<Integer>
      | Expression<Float>
      | 'default'
      ;  

* Accepts one or two keys
* Keys must evaluate to a `Timespan`, an `Initializer[Timespan]`, a `String`, a `Float`, an `Integer`, or to literal `default`
* A key that evaluates to `Initializer[Timespan]`, a `String`, a `Float`, or an `Integer`, will be coerced into a `Timespan` instance
* A value of default means -Infinity if given as the value of `from`, and +Infinity if given
  as `to`. If only an exact value of `default` is given this is the same as
  `Timespan[default, default]`,
  which again is the same as just `Timespan` (i.e. all floating point values in the range +/- Infinity).
* The `from` value may be greater than the `to` value.
* The range values may be negative.

Examples:

    Timespan[2]                        # a timespan of 2 seconds
    Timespan[77.3]                     # a timespan of 1 minute, 17 seconds, and 300 milliseconds
    Timespan[{hour => 1}, {hour => 2}] # a timespan between 1 and two hours
    Timespan['1-00:00:00', '2-00:00:00'] # a timespan between 1 and 2 days
    Timespan[Timespan('11', '%H'), Timespan('12', '%H')]              # a timespan between 11 and 12 hours
    Timespan['1-00:00:00', Timespan({days => 2, nanoseconds => -1})] # a timespan between 1 and up to (but not including) 2 days

<table><tr><th>Note</th></tr>
<tr><td>
  It is not possible to enumerate a `Timespan` range.
</td></tr>
</table>

#### Timestamp Type [ ]

Produces a new `Timestamp` type with a range. A `Timestamp` type has the default range -Infinity to +Infinity.
A `Timestamp` range where one or both ends is Infinity is said to be an *open range*, else it is a
*closed range*. The set of values in the range is inclusive of the given values.

Signature:

    TimestampTypeAccess
      : Expression<Type<Timestamp>> '[' exact = TimestampRangeValue ']'
      | Expression<Type<Timestamp>> '[' from = TimestampRangeValue ',' to = TimestampRangeValue ']'
      ;
      
    TimestampRangeValue
      : Expression<Timestamp>
      | Expression<Initializer[Timestamp]>
      | Expression<String>
      | Expression<Integer>
      | Expression<Float>
      | 'default'
      ;  

* Accepts one or two keys
* Keys must evaluate to a `Timestamp`, an `Initializer[Timestamp]`, a `String`, a `Float`, an `Integer`, or to literal `default`
* A key that evaluates to `Initializer[Timestamp]`, a `String`, a `Float`, or an `Integer`, will be coerced into a `Timestamp` instance
* A value of default means -Infinity if given as the value of `from`, and +Infinity if given
  as `to`. If only an exact value of `default` is given this is the same as
  `Timestamp[default, default]`,
  which again is the same as just `Timestamp` (i.e. all floating point values in the range +/- Infinity).
* The `from` value may be greater than the `to` value.
* The range values may be negative.

Examples:

    Timestamp['2000-01-01T00:00:00.000', default] # a timestamp in the 21st century or later
    Timestamp['2012-10-10']                       # The exact Timestamp 2012-10-10T00:00:00.0 UTC
    Timestamp[default, 1433116800]                # A Timestamp <= 2015-06-01T00:00:00 UTC (here expressed as seconds since epoch
    Timestamp['2010-01-01', '2015-12-31T23:59:59.999999999'] # A timestamp greater >= year 2010 and < 2016. 

<table><tr><th>Note</th></tr>
<tr><td>
  It is not possible to enumerate a `Timestamp` range.
</td></tr>
</table>

#### Optional Type [ ]

Produces a new `Optional` type for a given single type. For more information about the type
see [Optional Type].

    OptionalTypeAccess
      : Expression<Type<Optional>> ('['
          type = Expression<Type>
        ']')
      ;

* A single type can be given as parameter
* It is an error if the list of parameters is empty

[Optional Type]: types_values_variables.md#optionalt

#### Variant Type [ ]

Produces a new `Variant` type for the given set of types. For more information about the
type see [Variant Type].

    VariantTypeAccess
      : Expression<Type<Variant>> ('['
          types += Expression<Type> (',' types += Expression<Type>)*
        ']')
      ;

* One or more types can be given as parameters
* It is an error if the list of parameters is empty

[Variant Type]: types_values_variables.md#varianttypes

#### Type Type [ ]

Produces a new `Type` type for a given single type. For more information about the type
see [Type].

    TypeTypeAccess
      : Expression<Type<Type>> ('['
          type = Expression<Type>
        ']')
      ;

* A single type can be given as parameter
* It is an error if the list of parameters is empty

[Type]: types_values_variables.md#typet

#### Type SemVer [ ]

Produces a new `SemVer` type that matches one or a (possibly disjunct) set of version ranges.
For more information about the type see [SemVer].

A SemVer type is constructed from one or more:

* Strings - each in Semantic Version string form, which can represent a single versio or a range
* An instance of SemVer
* An instance of SemVerRange

[SemVer]: types_values_variables.md#semverversion-ranges

Function Calls
---
The Puppet Programming Language supports calling functions.
 
Function calls come in three forms:

* *statement* - arguments to the function does not require parentheses, may not appear in
  expressions, have syntactical restrictions on their arguments. Only a handful of explicitly
  listed functions can be called this way. Users can not add new statement type functions as
  their names are determined by the Puppet Parser.
* *prefix*
  * function name is first, arguments are always given in parentheses.
  * Type expression is first, arguments are always given in parentheses.
* *infix* - uses '.' to apply a function to the first argument to the function. Additional
  arguments are placed in parentheses after the function name (for example, `$x.notice`, `$x.notice($y)`).

Syntax:

    StatementStyleCall
      : QualifiedName Expression (',' Expression)* 
      ;

    PrefixStyleCall
      : (QualifiedName | Expression<Type>) arguments = ArgumentList LambdaExpression?
      ;

    InfixStyleCall
       : Expression '.' QualifiedName ('(' Expression (',' Expression)* ','? ')')? LambdaExpression?
       ;

    ArgumentList
      :  '(' args += Expression (',' args += Expression)* ','? ')'
      ;

    LambdaExpression
      : '|' ParameterList? '|' ReturnType? '{' Statements? '}'
      ;

    ParameterList
      : ParameterDeclaration (',' ParameterDeclaration)* ','?
      ;

    ParameterDeclaration
      : type= Expression<Type>?
        varag ?= '*'?
        name = VariableExpression ('=' default_value = Expression)?
      ;

    VariableExpression : VARIABLE ;  # e.g. $x, $my_param

    ReturnType
      : '>>' Expression<Type>
      ;

**General**:

* In 4x the Qualified Name function name is not restricted to a *simple name* (in 3x all functions 
  are in the same namespace, and in 4.x they can be namespaced).
* A function may be called using any of the three styles (statement style is restricted to a given 
  list of functions, see below) - there is no difference in
  evaluation between them - only syntactical differences, and the varying support for
  calls without arguments, and passing an optional lambda.
* Functions that are declared (in their 3x plugin logic) to be `:rvalue` functions produce a value,
  those  that that are declared to be `:statement` produce `undef` as their result.
* The 4x function API (for plugin Ruby functions) do not make a distinction between
  r-value and statement type, they all produce a value, and a function should produce
  Ruby nil (mapped to undef) if no other valid return value is suitable.
* A function call is never an L-value (a function can not produce something that is assignable).
* A call to a Type is the same as calling the function `new` with that type as the first argument.

**Parameters**

* Parameters may be optionally typed by preceding them with a type expression
* An untyped parameter defaults to `Any`
* The last parameter may optionally be marked as *captures rest* when prefixed with a *splat* `*`
* A parameter with a default value expression may not appear to the left of one without
 
**Statement Style**:

* `StatementStyleCall` may only appear at top level in a file, or in a block (i.e. the body
  of a Case Proposition, the conditional blocks for `if`, `unless`, `else`, `elsif`, the blocks
  constituting the body of `class` and `define` expressions.
* As shown in the grammar above, a `StatementStyleCall` requires an argument; a call without
  arguments requires use of one of the other two styles.
* A function implementation may invoke the lambda that is given to it, but it may not use it after 
  the function has returned (and it may not return the lambda).
* This style cannot be used when the argument is a literal `Hash` because the expression is
  indistinguishable from a resource expression without title. **(PUP-979)**
* A statement type call always produces `undef`.

Example:

    require 'myclass'

Functions that allow being called using statement style:

    # catalog manipuation
    require
    realize
    include
    contain
    tag

    # logging
    debug
    info
    notice
    warning
    err

    # stop execution
    fail

    # raises an error as it is discontinued
    import

**Prefix Style**:

* Requires parentheses around the 0-n arguments
* Accepts an optional lambda
* May appear anywhere where an Expression can appear

Example:

    require('myclass')
    $pi = sprintf("%.4f", 3.1415123)     # => '3.1415'
    map([1,2,3]) |$x| { $x * 10 }        # => [10, 20, 30]

**Postfix Style**

* Accepts leaving out the parentheses around an empty argument list
* The RHS of the `.` operator is given to the function as the first argument (argument 0)
* Any additional arguments (given within parentheses) are given to the function as argument 1-n)
* Parentheses are required around additional arguments
* Accepts an optional lambda after the (optional) argument list

Examples:

    [1,2,3].map |$x| { $x * 10 }                                    # => [10, 20, 30]
    [1,2,3].reduce(10) |$memo, $x| { $memo + $x }                   # => 16
    'myclass'.require                                               # => undef
    [1,2,3].map |$x| { $x * 10 }.reduce |$memo, $x| { $memo + $x }  # => 60

**Lambda**:

* A Lambda is an unnamed function, it has an optional `ParameterList` that declares the name
  and an optional default value expression (if too few arguments are given when it is invoked).
* Parameter declarations with default value expressions must come after parameter declarations 
  without default value expressions.
* The parameter list is syntactically the same as the parameter list for a Resource Type definitions,
  and a Class definitions.
* Evaluation of default value expressions take place in the scope where the lambda is declared.
* Since 4.7.0 it is possible to specify the expected return type of a lambda. An automatic type assertion will be made
  when the lambda has a specified return type.

**Calling Types - new-operation**
Since 4.5.0.

Calling a type - for example:

    Integer("0xFF")

creates a new instance of the type and an assertion is made that the value is compliant with the type.
An error is raised if the result is not compliant.

    Integer[0,10]("0xFF")

Would fail, since the result is not within the given range 0-10.

The parameters are specific to each type - see the documentation per type.

A call to a type is equivalent to calling the function `new` with the type as the first argument.

**Function Call Semantics**

* Given arguments are assigned to parameters left to right
* The type of the given argument must be compatible with the specified type
* If a value is not given for a parameter that has no default argument an error is raised
* If more values are specified than there are parameters and the last parameter is not a *captures 
  rest*, and error is raised.
* If the last parameter is a *captures rest* and there is no given argument for it, its value
  is an empty array (unless it has a default expression that will be used in this case).
* If the last parameter is a *captures rest* and there is one or more given arguments for it,
  the value is an Array with the captured arguments as values.
* Each argument captured by a *captures rest* parameter must comply with the parameters specified
  type such as `T $param` produces a value compatible with an `Array[T, 0, default]`.
* A given undef value counts as given and does not trigger substitution with the value of the
  default expression.
* Function call supports unfolding arrays into individual arguments.

<table><tr><th>Future</th></tr>
<tr><td>
  A future version may make named function definition available in the Puppet Programming Language.
  A future version may introduce real closures, allowing lambdas to be invoked after
  a function has returned.
</td></tr>
</table>

### Argument Unfold / Splat Support

Function calls (all styles) support unfolding arrays into individual arguments. The expression
is an unary * (referred to as 'splat') followed by the array. When splat is applied to a non
array, is is a no-op.

Technically, the Unfold Expression is not evaluated when used in an argument - it is simply
(as the name implies) unfolded.

    # These two calls are equivalent
    foo( *[1,2,3])
    foo(1,2,3)

Splat is an unary and non-associative operator.

Conditional Expressions
---
The conditional expressions are R-Value Expressions.

The conditional expressions are:

* `if` (`else` `elsif`)
* `unless` (`else`)
* `case`
* selector - i.e `x ? y => z` 

### if (elsif, else) expression

Syntax:

    IfExpression
      : 'if' IfPart
      ;
      
    IfPart
      : TestExpression '{' Statements? '}' ElsePart? 
      ;
      
    ElsePart
      : 'elsif' IfPart
      | 'else' '{' Statements? '}'
      ;
      
    TestExpression : Expression ;  

The `TestExpression` is evaluated, and if "thruty" the `IfPart` statements are evaluated,
else the `ElsePart`. If the `ElsePart` is an `IfPart` the evaluation recurses until either an
`IfPart` is evaluated, an unconditional `ElsePart` is evaluated (if one exists), or until
there are no more parts.

* The last evaluated expression in the selected expression block is produced as a result
* If all conditionals evaluated to false, and there was no `ElsePart`, the produced result is `undef`.

### unless (else) expression

Unless is the equivalent of `if !(TestExpression)`, but does not have an `'elsif'` or (fictitous) `elsunless` part.

Syntax:

    UnlessExpression
      : 'unless' TestExpression '{' Statements? '}' ('else' '{' Statements? '}')?
      ;
      
    TestExpression : Expression ;  


### case expression

A case expression tests a  value Expression against a series of propositions. The first matching
proposition triggers the evaluation of an associated set of statements. If no matching proposition
exists, a default proposition is selected if one exists.

Syntax:

    CaseExpression
      : 'case' case_expression = Expression<R> '{' Propositions? '}'
      ;
      
    Propositions
      : Option (',' Option)* ':' '{' Statements? '}'
      ;
      
    Option
      : Expression<R>
      | LambdaExpression
      | 'default'
      ;

* the case_expression is evaluated first
* options are evaluated in the order they are given; top-down, with option propositions evaluated 
  left to right until one proposition matches.
  * each proposition is evaluated before a match is performed using the produced value
* A match is computed as:
  * if the option is a literal `default`, the option is skipped (this rule does not apply
    recursively). **(PUP4520)**
  * if the option is a `Regexp` the value must be a string for the match to trigger
  * if the option is a `Type` and the value is not, the option matches if the value is an
    instance of the type.
  * if the option is a `SemVerRange` the value matches using operator `=~` semantics (version in range)
  * the option matches if the option and value both are of `Array` type, have the same
    length, and all entries in the option match the corresponding entry in the value (using
    the case matching rules recursively).
  * the option matches if the option and the value are both of `Hash` type, and the
    option key-value pairs match entries in the value hash by having identical keys
    and matching value (using the case matching rules recursively).
  * a literal `default` nested inside an Array or Hash always matches the corresponding entry.
    Such a `default` is not considered to be the case expression's default entry.
  * the option matches if it is a lambda expression and the call of this lambda expression with
    result of the evaluated case_expression unfolded as arguments results in a value that
    is neither `false` nor `undef`. **(PUP-4193)**
  * in all other cases, the option matches if the value is equal (using operator `==` semantics)
    to the option value.
* If one of the options match, the proposition's associated `Statements` are evaluated
  * remaining options in the same proposition are not evaluated
  * if the case_expression evaluated to literal `default` it will match the default option
    without first testing the remaining options.
* The result of evaluating the last expression in the `Statements` is produced as result
* If no matching options was found, and one option is the literal `default`, the `Statements`   
  associated with the Proposition with a `default` option is selected.
* If no matching Statements were evaluated, the result is `undef`
* The `default` may appear anywhere in the list of propositions, but may only appear once in
  one proposition.
* When a match is made with a regular expressions, the numerical match variables are set as a side 
  effect. When the case expression has been evaluated, the previously set match variables are 
  restored. (**TODO: same comment for if etc**)
* It is an error to have more than one option with a literal `default` value in the same case 
  expression. **(PUP-978)**
* An option producing a literal default does not count as the default entry. It will only be  
  triggered if the `case_expression` itself is a literal `default`. 
* An option that is an Unfold Expression (splat) transforms the given expression to individual
  options. A splatted `default` does not count as the default entry.
* If no option matched in any proposition, the proposition that had a skipped default option
  is selected **(PUP4520)**. If there is no such default entry, no option is selected and the
  value of the case expression is `undef`.

  
Examples:

    # example 1
    case $observed {
    
      'cat', 'sylvester': { 
        notice 'I taw a puddy cat'
      }
      
      'seed': {
        notice 'Feed me!'
      }
      
      'toe': {
        notice 'This widdle piddy went to market' 
      }
    }

    # example 2 - using cases an expression
    notice case $name {
    
      'paul', 'ringo', 'george', 'john': { 
        'One of The Beatles'
       }
       
      'mick', 'keith', 'charlie', 'ronnie': {
        'One of The Rolling Stones'
      }
      default: { 'In Some other band' }
    }

    # example 3 - using type
    notice case [1,2,50] {
    
      Array[Integer[1,49]]: {
        'in range'
      }
      default : {
        'out of range'
      }
    }
    
    # example 4 - using matching array
    $x = [green, 2, $whatever]
    case $x {
      [/ee/, Integer[0,10], default] : {
        notice 'this will be noticed'
      }
      default: {
        notice 'this will not be noticed'
      }
    }


**Option Support for Unfold/Splat**

If an option is an unary Unfold Expression, it is unfolded into individual options
for the same Proposition before matching takes place.

    case $x {
      *[paul, ringo, george, john] : {
        'One of The Beatles'
      }
    }

    case $x {
      you, *[paul, ringo, george, john], me : {
        'One of The Beatles, you, or me ;-)'
      }
    }
 
### ? (selector) expression

Matches a LHS expression against a sequence of propositions. The value expression associated
with the matching option expression is evaluated and produced as the result.

The semantics are the same as for the case expression with the exception that
an error is raised if no match is found.

Syntax:

    SelectorExpression
      : selector_expression = Expression '?' Proposition | '{' Propositions '}'
      ;
      
    Proposition
      : Option '=>' Value
      ;
      
    Propositions
      : Proposition (',' Proposition)* ','?
      ;
      
    Option: Expression<R> ;
    Value: Expression<R> ;

* The `selector_expression` is evaluated first
* the `Proposition` expressions are processed from top to bottom
  * the `Option` expression is evaluated
  * The proposition matches if the `Option`
    matches using the same match semantics as for case expression propositions
  * The result of the `SelectorExpression` is the result of the `Value` expression if the Proposition
    was matched.
  * If a proposition is the literal `default` it is set aside and its value expression
    is used if no other proposition matched.
* If no match was found (and there was no default proposition), an error is raised. 
* An option that is a `Regexp` sets the match variables `$0`-`$n`, and makes them available in the
  Value expression. The match variables are restored when the value expression has been evaluated.
* It is an error to have more than one option with `default` value. **(PUP-978)**

Example:

    # Ex 1.
    $x = $y ? sad => blue
    # the same as
    $x = if $y == sad { blue }
    
    # Ex 2.
    $x = $y ? {
      hot     => red,
      sad     => blue,
      seasick => green,
      default => normal,
    }
    # The same as
    $x = case $y {
      hot: { red }
      sad: { blue }
      seasick: { green }
      default: { normal }
    }

**Option Support for Unfold/Splat**

The Selector Expression supports unfold/splat the same way as in Case Expression.

Definition Expressions
---
The Puppet Language has several definition expressions:

* Function definition
* User defined resource definition
* Host Class definition
* Type Alias definition

The user defined resource definition and host class definition expressions are specified
in [Catalog Expressions][2], and function definition in [Puppet Functions][3], and [Function API][4].

### Type Alias Expression

The Type Alias Expression makes it possible to assign a type definition to a type
name, and use the new type name as a 100% equivalence to the assigned type.

In this version of the specification, only the case of the initial letter in each name segment
is significant; MyType is equivalent to MYTYPE, MytYPe, etc. This may change in a later release.

The grammar is:

```
TypeAliasExpression
  : 'type' QualifiedReference '=' Expression<Type>
  ;
```

Example use:

~~~
type PositiveInts = Array[Integer[0, default]]
$a = [1,2,3] ~= PositiveInts
$b = Array[Integer[0, default]] == PositiveInts
~~~

Would set both `$a` and `$b` to `true`.

Type references are autoloaded from the environment and modules. The autoloading rules are:

* The name of the file must be in lower case.
* No underscore `_` should be used to separate words in a camel cased name; the file for
  `MyType` should be `mytype.pp`, not `my_type.pp`.
* Each namespace segment maps to a directory path with the same name.
* For a module, the `<module_root>/types` corresponds to the module's namespace.
* For an environment, the `<env_root>/types` corresponds to the global namespace.
* For an environment, it is recommended to always use the `Environment::` namespace under `<env_root>/types/environment`.
* An autoloaded type alias `.pp` file may only contain a single type alias.
  No other expressions are allowed (comments are).
* The autoloaded type alias must use the full namespace on the left hand side, e.g.
  `MyModule::MyType`, or `MyModule::Nested::MyType` for a nested namespace.


Type references may be created in any manifest, but this should be avoided as they
cannot be autoloaded and is affected by the order in which manifests are loaded and evaluated.
This is mainly supported to enable writing small examples and experimentation.

In general:
* Type aliases are processed before the rest of the logic in the file.
* All types are allowed on the RHS, even the alias being defined (this creates
  a *self recursive type*).
* Recursive types are supported in general, i.e. not only by direct recursion created by
  using the alias being defined on the RHS.

Example: Type Aliases are defined before evaluation takes place

```
function foo(MyType $x) {
  notice $x
}
notice foo(42)

type MyType = Integer[42,42]
```

Examples of recursive types:

```
type IntegerTree = Array[Variant[Integer, IntegerTree]]
type Mix = Variant[Integer, String, MixedTree]
type MixedTree = Array[Variant[Mix, MixedTree]]

function integer_tree(IntegerTree $x) {
  notice $x
}
integer_tree( [1, 2, [42, 4], [[[ 5 ]]] ] )

function mixed(MixedTree $x) {
  notice $x
}
mixed( [1, 2, [hello, 4], [[[ 5, deep ]]] ] )

```

Since 4.4.0

[1]: types_values_variables.md#string-tofrom-numeric-conversions
[2]: catalog-expressions.md
[3]: puppet-functions.md
[4]: func-api.md

