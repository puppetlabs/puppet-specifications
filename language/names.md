Names
===
*Qualified Names* and *Qualified References* are used to refer to entities declared in a Puppet Program or to entities declared via plugins to the Puppet Runtime System.

A **Qualified Reference** is a reference to a type; one of:

* Built in types
* User defined resource type
* Resource type runtime plugin 
* A Puppet Class

A **Qualified Name** is a reference to a value (of some type), the type and scope depends on which operators are being used.

     $x                  # name is a reference to the variable named 'x'
     sprintf("%x4", 256) # name is a reference to the function named 'sprintf'
     
Names and References are either *simple* consisting of a single identifier, or *qualified*, consisting
of a sequence of identifiers separated by `::` tokens. A qualified name/reference may start with `::` which makes the reference *absolute*.

In determining the meaning of a name or reference, the context of the occurrence is used to disambiguate among the various kinds of named elements.

Access control can be specified for a named element making this element only visible to a restricted set of contexts. Access control is different from scope. Access specifies the part of the program
text within which the declared entity can be referenced by a qualified name/reference.

Declarations
---
A declaration introduces an entity into a program and introduces an identifier that can be used to refer to this entity. The ability to address an entity depends on where the declaration and
reference occurs - this is specified by Access Control and Scope.

A declared entity is one of the following:

* built in type
* plugin defined Resource type
* plugin defined Function
* (host) Class
* Class Parameter
* plugin defined Resource type parameter
* Variable
* Node
* Resource Instance

Scope of Declaration
---
The scope of a declaration is the region of the program within which the entity declared by the declaration can be referred to using a simple name, provided it is visible.

TODO: List of declarations and their scopes (W.I.P)

* All functions are always in scope
* All types are always in scope
* 
* The scope of a variable declaration in a Class is
* The scope of a Class


Shadowing, Obscuring, and Overloading
---
A local variable can only be referred using a simple name (never a qualified name).

It is not allowed to redeclare variables or parameters in the same scope.
A local scope may redeclare variables declared in outer scopes. These shadow the outer scope
declaration(s).

It is never allowed to declare a variable in a scope other than the current scope (i.e. it is
not possible to assign a value to a variable in another scope by using a qualified name).

Technically a Shadow is a new declaration of an existing entity, and Obscuring is the declaration of
a name in a context in such a way that it obscures a named entity in another scope (i.e. it is not
a shadow, but its existence blocks a name to resolve to what it obscures). 

The Puppet Programming Language does not have any obscuring constructs as there is a distinction between variable references $var, names (initial lower cased Qualified Name), and references
(initial upper case Qualified Reference).

Overloading is the term used to resolve the binding of declaration to definition in the
presence of multiple definitions of the same name. In the Puppet Programming Language overloading
takes place when loading a named entity from a search path, the first entity found
on the path wins. If a named entity has already been introduced, this will block access to
an entity with the same name that would otherwise have been loaded.

Future versions of this specification may impose stricter rules on where a named
entity may be defined; this to reduce the risk of accidental overloading.


Scopes
---
These constructs introduce a new scope:

* The Program's top scope
* A (host) Class
* A user defined Resource type
* A lambda
* A Node

### Top Scope

Top scope is created automatically when the execution of the program begins. Top scope
is the program region(s) outside of classes, user defined resource types, nodes and lambdas.

There is no difference between the top scope region in different source code files. There is
only one top scope.

### Class Scope

All Classes are singletons - there is never more than one instance of a given class. A parameterized
class may only be instantiated once - there can never be two instances of the same class with
different parameters in the same compilation.

Parameters and Variables in a Class C is in scope for C, and in all classes inheriting C.

All Parameters and Variables are by default public and are visible to all other scopes.
Parameters and Variables declared private are visible only to C.

### User Defined Resource Scope

A user defined resource type (just like plugin defined resource types) may be instantiated multiple
times provided instances are given unique identifiers.

Variables (other than those referring to the resource parameters) in a user defined resource type are always private - they are not visible to any region outside of the resource type body.

A resource's parameters can not be externally referenced via variables, but can be obtained
via an access expression:

    Resource[Type, title][param_name]
    
The result of such an operation is evaluation order dependent; the resource must have been created, evaluated, and the parameter must have been given a value.


Determining the meaning of a name
---
### In General

A Qualified Name in general is a Bare Word that evaluates to a String.

    hello     ==  'hello'
    abc::xyz  ==  'abc::xyz'
    ::xyz     ==  '::xyz'

### Function Name

A Qualified Name is a reference to a function when:

* it appears where an expression is accepted and:
  * it is followed by arguments in parentheses e.g. `abc()`
  * it is the RHS in a dot binary expression e.g. `$a.abc`
* it appears in the top level body of a Program, conditional construct, define, or class, and:
  * the name is one of the built in statement type functions, and
  * is followed by one or a comma separated list of argument expressions (this is known as
    an un-parenthesized function call).

**TODO:** Reference to where the list of statement like functions are

### Resource Type Reference

A Qualified Name is a reference to a Resource Type (plugin or definition expression) when it appears
as the type name in a Resource Expression. e.g. the name `file` in this example:

    file { title: }

### Attribute Reference

A Qualified Name is a reference to an Attribute of a Resource win it appears as the LHS in
an Attribute Operation (operators `=>` and `+>`)

### Name of Entity

A Qualified Name is a name in Class-, and Define-expressions. It is not a name in a Node expression, there the name parts can be composed with interleaved dots, and with numbers to form a string.

A Qualified Name is a reference to the parent class when used after `inherits` in a class definition.
 
Access Control
---
**NOTE: Access Control is not fully specified and has not yet been implemented.**

Access control in the Puppet Programming Language consists of the keyword `private` applied to:

* class
* user defined resource type
* parameter
* variable

This is explained in the following sections.

### Class

A private class may only be directly used from the module where it is declared. The term
*directly-used* means:

* including the class
* requiring the class
* instantiating the class as a resource
* inheriting from the class
* forming a relationship with the private class

The class itself is visible in the catalog, and it is possible to reference it and its parameters.
Since its existence in the catalog is public so is referencing it, and its parameters. Access to a private class and its parameters will issue a warning as the intention is that it is an implementation concern of the particular module.

**TODO: The rules for access to resource instances and parameters for private resources/params
requires more thought - warning / error / simply not visible...**

### User Defined Resource Type

A private user defined resource type may only be directly used from the module where it is declared.
The term *directy-used* means:

* instantiating an instance of the resource type
* forming a relationship

The type itself is visible, and so are the instances that are created. Access to instances of a private resource type and its parameters will issue a warning as the intention is that it is an implementation concern of the particular module.

### Parameters

A private parameter may only be directly used from the module where it was declared. The term
*directly-used* here means:

* referencing the parameter using variable syntax
* referencing the parameter via catalog lookup of type/id and then accessing its parameter

Since the result is still visible in the catalog, there is nothing preventing it from being accessed using catalog/type/id lookup, but a warning will be issued in these cases.

### Variable

A private variable is only available in the scope where it is declared (and inner local scopes). It is only meaningful to declare private variables in top, node and class scope (all other variables are already private/local to their respective scopes).

A private variable is simply not visible to other scopes.



