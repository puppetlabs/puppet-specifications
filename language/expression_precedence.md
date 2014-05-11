Expression / Operator Precedence
===

From highest to lowest precedence. Default association is "left" (the others are right and
non-associate). Left means the LHS is fed into the RHS, right the reverse, and non associative
means that the operator can not be repeated.

The L/R/Q column denotes if the Expression is L (left; can be assigned to), R (right; produces
a value), or is Q (quasi expression; that produces a value but is not a general purpose expression),
or - (not L / R / Q; typically punctuation). This is further explained in [L, R, Q, and Non Value Expression].


[L, R, Q, and Non Value Expression]: expressions.md#l-r-q-and-non-value_expression

| Operator / Expression | L/R/Q | Association | Explanation
| ---                   | ---   |  ---         | ---
| `;`                   | -  |    | expression separator, resource body separator
| <code>&#124;</code>   | -  |    | separator around lambda parameters
| `(`                   | R  |    | expression grouping () alter precedence of contained expression
| `)`                   | -  |    | - " -
| `.`                   | -  |    | inline call operand / function separator
| `CALL`                | R  |    | prefixed and inline style calls
| `[`                   | R  |    | array start, access operator
| `]`                   | -  |    | - " -
| `?`                   | R  |    | select
| <code><&#124;</code> <code><<&#124;</code> | Q | | collect (virtual, exported)
| <code>&#124;></code> <code>&#124;>></code> | - | | end of collect (virtual, exported)
| `!`                   | R  | right | not
| `-` *unary*           | R  | nonassoc | unary minus
| `*` *unary*           | R  | nonassoc | unary 'splat' for unfolding array
| `in`                  | R |       | 
| `=~` `!~`             | R |       | matches, not-matches
| `*` `/` `%`           | R |       | multiplication, division, modulo
| `+` `-`               | R |       | addition / concat / merge, subtraction / delete
| `<<` `>>`             | R |       | left-shift / append, right-shift
| `==` `!=`             | R |       | equal, not-equal
| `>` `>=` `<` `<=`     | R |       | greater, greater-or-equal, less, less-or-equal
| `and`                 | R |       | boolean and
| `or`                  | R |       | boolean or
| `+=` `-=` `=`         | R | right | append-to, delete-from, assign
| `{`                   | R |       | block / hash start
| `{` after `?`         | - |       | block start after `?`
| `}`                   | - |       | block / hash / selector end
| `:` (in title)        | - |       | title terminator
| `:` (case colon)      | - |       | case proposition-list terminator
| `=>` `+>`             | - |       | name-value association
| `,`                   | - |       | comma, separator in lists (parameters, arrays, hashes)
| L/R-value expression  | L/R |     | Any complete L or R value expression (see expressions)
| `@` `@@`              | - |       | virtual, exported (starts a resource expression)
| resource expression   | Q |       | resource, resource override, resource default expressions
| `->` `~>` `<-` `<~`   | Q |       | relationship
| un-parenthesized call | Q |       | statement like calls

The precedence governs the parsing, not all combinations of *expression operator expression* are
sensical, and those that are not are validated as being in error.

It is of importance to understand the precedence of operators to be able to
understand why a particular expression does not give the expected result, or why it produces
a particular error message.

Note that peculiarities around the Q-Value expressions at the low end of the precedence. This
may change in the future - the main problem here is the difficulty of differentiating
between the various forms of expressions starting with '{', and the un-parenthesized function
calls.
