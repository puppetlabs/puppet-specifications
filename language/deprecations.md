New Deprecations
===
This contains a list of deprecations that should be added to a release prior to Puppet 4.
For each issue there is a brief discussion / motivation and implementation suggestion

"class" is not a valid name for a class
---
The keyword "class" is specifically allowed in the grammar and then becomes a string just
like any other name. The deprecation can most cleanly be done in the grammar itself and
this is also the point of origin for this feature.


Upper case variable names
---
Variables that start with an upper case letter are problematic when they are interpolated.
The current 4x implementation validates them as invalid for sake of consistent naming (all initial
UC segments is a reference to type and lower case to an instance). With an uc variables something like $a::B is an error since another rules says that each segment must start with the same case. 

It is thus impossible to refer to this variable from the outside. (That may be a feature in its
own right :-) but a very odd way of providing this.

Again, the easiest deprecation is probably in the grammar.

(Note that there is a difference between a lexicographical variable name and a valid name).

Variables with initial underscore
---
Local variables may have an initial underscore, but a qualified variable may not have an underscore
in the first position of a name segment.

legal:

    $_x
    $_x_
    $x_::y
    $x::y_
    
illegal:

    $::_x
    $x::_y

Access to non existing variables
---
There is a strict mode that can be turned on for variables. It performs a throw if the flag is turned on. It could be changed to always throw, then catch it, issue warning if flag is off and return undef.

To turn on strict mode:

    --strict_variables


Access to classes using uc class name/title
---
3.x allows a reference such as Class[Foo] to mean the class named 'foo'. This is
inconsistent since just a Foo is a reference to a resource type. The use of uc name
as class 'title' should be deprecated. (It is found in several tests).

+= and -= have been discontinued
---
The operators `+=` (append) and `-=` (delete) have been discontinued. They used to have
their own (quirky) semantics. They are trivially replaced as follows:

    $a += expression
    # replace with
    $a = $a + expression
    
    $a -= expression
    # replace with
    $a = $a - expression
    
This works because the reference to a variable on the right hand side is evaluated before the
new variable is created. It also works because `+` and `-` operations for add and delete works
on numbers and Collections (`Array` and `Hash`).

Older Deprecations Removed in 4x.
===
Here is a list of old behavior / deprecations that will be removed.

hyphens in names
---
The ability to accept have been removed.

Ruby DSL
---
Support for Ruby DSL will be removed.
