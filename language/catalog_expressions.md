Catalog Expressions
===
Catalog Expressions are those that  directly relate to the content of the catalog produced
by the compilation of a Puppet Program.

* **Node Definition** - associates the logic producing a particular catalog with the node making 
  a request for a catalog.
* **Class Definition** - creates a grouping of resources
* **Resource Type Definition** - creates a new (User) Resource Type
* **Resource Expression** - creates resources
* **Resource Default Expression** - sets default values for resources
* **Resource Override Expression** - overrides attributes set in resources
* **Relationship Operators** - orders the resources in the catalog
* **Collection** / **Query** - realizes virtual resources and optionally overrides them, and
  imports external resources based on a query.

This chapter focuses on the syntactic aspects of these expressions. There are additional semantic rules, rules specific per type (extensible set), evaluation order semantics, as well as semantics for
catalog application that are covered in a separate chapter. (*TODO: REF TO THIS FUTURE CHAPTER*).

*TODO: Is the description in Modus Operandi enough*

Auto Loading
---
* Name of definitions must be stored in a file that corresponds to its name in order for it
  to be automatically loaded.
* Nested constructs are only visible if parent has been loaded, there is no search for elements
  inside of files with a name different than the file.
* Auto Loading is performed from the perspective of the code that triggers the loading.
* *(TODO: 4x function API has new rules, old has rule everything is visible to everything else)*

### Parameter List

The parameter list is common to several of the catalog expressions:

    ParameterList
      : ParameterDeclaration (',' ParameterDeclaration)* ','?
      ;
      
    ParameterDeclaration
      : private ?= 'private'? type ?= Expression<Type>? VariableExpression ('=' Expression<R>)?
      ;
    
    VariableExpression : VARIABLE ;

* The `VARIABLE` must contain a simple name
* A *captures rest* (as allowed for functions) is not allowed in parameter lists for a
  catalog entry.

### Node Definition

Syntax:

     NodeDefinition
       : 'node' HostMatches ('inherits' HostMatch)? '{' Statements? '}'
       ;
       
     HostMatches
       : HostMatch (',' HostMatch)* ','?
       ;
       
     HostMatch
       : (NAME | NUMBER) ('.' (NAME | NUMBER))*
       | SingleQuotedStringExpression
       | DoubleQuotedStringExpression
       | LiteralDefault
       | RegularExpression
       ;
       
     LiteralDefault: 'default' ;

* Use of `inherits` raises an error as node-inheritance is discontinued.
  * An implementation may treat this as a syntax error, or parse and validate it as an error
* The `HostMatch` consisting of a sequence of period separated `NAME` or `NUMBER` lexical tokens
* Note that `WHITESPACE` between period separated `NAME`/`NUMBER` tokens is not included in the
  result.
* All host matches (except regular expression and literal `default`) must result in a string
  that consist of a sequence of characters `a-z A-Z 0-9 _ - .`. An error is raised if the
  resulting host match string does not comply with this rule.
* node definitions may not be made in a module

<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to evaluate NodeDefinitions, the above defined
  rules are enforced by the grammar / validation.
</td></tr>
</table>

### Class Definition

Syntax:

    ClassDefinition
      : private ?= 'private'? 'class' ('(' ParameterList? ')')? ('inherits' QualifiedName)? 
          '{' Statements? '}'
      ;
      
* A class definition may only appear at the top level in a file, or inside a class definition
* A class may inherit another class
* A class may have parameters
* A class may be private to the module it is defined in **(PUP-523)**
* A class defined in the environment that is marked private is not visible to modules
* A parameter declaration may have a default value expression
* Parameter declarations with default value expression may appear anywhere in the list
* Parameter default value expressions:
  * should not reference other parameters in the list - the evaluation order is undefined when
    using an implementation that does not guarantee the correct order.
  * may reference variables defined by the inherited class (it is initialized before the
    inheriting class).
* A class defines a named scope and makes all of its non private) parameters and variables visible
* A parameter that is private can only be set from the same module (it is not part of the API)
* A class defined inside another class automatically becomes prefixed with the containing class'
  name as its name space
* Circular inheritance is not allowed.


<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to evaluate ClassDefinition. There are many
  additional (some unclear) rules that needs to be specified (and/or fixed). (finding classes,
  how they are merged in top scope, etc).
</td></tr>
<tr><th>Future</th></tr>
<tr><td>
  The 3x implementation does not restrict that parameter default values may not
  reference other parameters in the same parameter list, but does not always produce
  the correct result. A future version of the specification should specify that
  it is allowed to access parameters that are defined to the left of where the parameter
  is used.
</td></tr>
</table>

### Resource Type Definition

Syntax:

     ResourceTypeDefinition
       : private ?= 'private' 'define' QualifiedName ('(' ParameterList? ')')?
           '{' Statements? '}'
       ;

* A Resource Type named the same as a type provided in a plugin will never be selected
* The default parameter value expressions may not reference variables in the calling scope, and
  should not reference any of the other parameters in the list when using a runtime where the
  order is not guaranteed. It may reference meta parameters.
* A define may occur at top level, or inside a class
* A resource type defined inside a class automatically becomes prefixed with the containing class'
  name as its name space.
* A resource type defined in a class only becomes visible if the class is loaded.
* A resource type that is private may only be instantiated from with the same module

<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to evaluate Resource Type Definition. There are many
  additional (some unclear) rules that needs to be specified (and/or fixed).
</td></tr>
</table>

### Resource Expression

A resource expression instantiates a resource and realizes it, or optionally does not
realize it (*virtual*), and optionally exports (*exported*) it to a central store for inclusion
elsewhere via *exported resource collection*.

     ResourceExpression
       : (virtual = '@' exported = '@'?)?
         type_name = QualifiedName | 'class'
         '{' ResourceBody (';' ResourceBody)* ';'? '}'
       ;
       
     ResourceBody
       : titles = TitleExpression ':' AttributeOperations?
       ;
       
     AttributeOperations
       : AssignAttributeOperation (',' AssignAttributeOperation)* ','?
       ;

     AssignAttributeOperation
       : name = SimpleName '=>' value = Expression
       ;
       
     TitleExpression
       : Expression<Variant<String<1>, Numeric, Array<Variant<String<1>, Numeric>>>>
       ;

** General **

* exported resources are also virtual
* a virtual resource is created but is not realized (not included in the catalog)
* a resource type_name must be a reference to an existing plugin provided resource type
  TODO: REFERENCE, or a user defined resource type (TODO: REFERENCE).
* The type and virtual/exported status applies to all resource bodies

** Titles **

* titles can be a single expression evaluating to `String[1]` or `Numeric`, or an Array of
  the same types.
* one resource instance is created per given title (minimum 1)
  * All created resources get the same set of attributes assigned (except those that represent
    the resource's title and identity).
* The semantics of the title string is resource type specific.
* When the type name is `class`
  * a title is the name of the class, and it must conform to class naming rules.
  * this is similar to using include class, but with different order of evaluation
    see [Modus Operandi] **TODO: Ensure that there is content about this there**
    
[Modus Operandi]: modus-operandi.md

** Order of Evaluation **

* The `type_name` is evaluated first
* `Bodies` are evaluated from top to bottom
* For each body, the `titles` expression is evaluated
* each attribute value expression is evaluated and mapped to the attribute name
* each body is added to the compiler which (in 3x) performs the multiplication based on the
  given title(s)
  * virtual and exported resources are remembered for reference, and for future operations
  * regular resources are *realized* (placed in the catalog)

### Resource Default Expression

A Resource Default Expression sets the default values to use for resources created in the same scope.
TODO: SCOPING RULES.

    ResourceDefaultExpression
      : type = QualifiedReference '{' AttributeOperations? '}'
      ;

    # AttributeOperation(s) are the same as for Resource Expression


* the type must be a reference to an existing resource type (plugin or user defined)
* TODO: Can defaults be set for classes ? i.e. `Class { a => foo }`
* A regular attribute operation using `=>` to assign the value sets the default value of the
  given attribute.
* An append attribute operation using `+>` assigns a value by appending the result of the
  value expression to the current default value of the given attribute. If no such default value
  exists, the operation yields the same result as if `=>` had been used.


### Resource Override Expression

A Resource Override Expression sets new values in un-assigned attributes in a
referenced resource. It can also modify assigned attributes in a resource that
is declared in an inherited class when the override is evaluated in the scope of
the derived class.

     ResourceOverrideExpression
       : ResourceReferences '{' OverrideAttributeOperations '}'
       ;

    OverrideAttributeOperations
       : OverrideAttributeOperation (',' OverrideAttributeOperation)* ','?
       ;
       
    OverrideAttributeOperation 
       : name = SimpleName '=>' value = Expression
       | name = SimpleName '+>' value = Expression
       ;
     
     ResourceReferences
       : Expression<ResourceType>
       | Expression<Array<ResourceType>>
       ;

** Attribute Operations **

* **When the referenced resource is instantiated in a class inherited by the current class:**
  * The `=>` operator sets the value of the given attribute in all referenced resource instances.
    * An existing value for an attribute is overwritten
  * The `+>` operator appends the given value to the value in each referenced resource instance.
    * The attribute must accept an Array (this is resource type specific)
      * The behavior if it does accept an array is resource specific. ???
        TODO_ WHAT HAPPENS IF IT DOES NOT ??
    * If no value has been assigned, the given value is assigned as if the `=>` operator had
      been used.
    * If a value has been assigned, and it is not an array, the value is wrapped in an array
      before the new value is appended
    * If the resulting value is an array, it is also flattened (nested arrays are flattened out).
* **Otherwise:**
  * The `=>` operators sets the value of the given attribute in all referenced resource instances
    provided that the attribute does not already have a value.
    * An error is raised if attribute already has a value
  * The `+>` operator raises and error (if there was a value it would append it and thus change
    the value; which is not allowed, and if there is no value, it is the same as `=>`, and
    this should have been used instead).
    
** ResourceReferences **

* Resource References must be resource instance specific (it is not possible to refer to
  all instances of a resource type).

Examples:

    File['foo'] { mode => 0666 } 
    File['foo', 'fee', 'bar'] { mode => 0666 }
    File[]                                        # syntax error
    File { mode => 0666 }                         # a Resource Default Expression, not override
    
    Resource['File', 'foo', 'bar'] { mode => 0666}
    $type = File
    $type['foo', 'bar'] { mode => 0666 }
    
    $resources = File['foo', 'bar']
    $resources { mode => 0666 }

<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to apply overrides, and to calculate the result
  of appending to an outer scope default. This means that the specified append logic may vary
  between resource types ???.<br/>
  TODO: Look at what actually happens in:
  <code>scope.compiler.add_override(resource)</code>
</td></tr>
</table>

### Relationships

Relationship Expressions are used to ensure that resources are processed in a
specific order. There are two kind of operators `->` (that specifies the order), and
`~>` (that specifies notification). Both kinds can be used in the reverse i.e. `<-` and `<~`

    RelationshipExpression
      : lhs = RelationshipOperand ('->' | '~>' | '<-' | '<~') rhs = RelationshipOperand
      ;

    RelationshipOperand
      : CollectorExpression
      | References
      ;
      
    References
      : Expression<Resource>
      | Expression<String>
      | '[' References (',' References)* ','? ']'
      ;

* The result of evaluating the lhs and rhs expressions are turned into sets with unique content
* Relationships of the type and direction given by the operator are formed for the
  the cartesian product of the two sets; lhs × rhs
* When the Relationship Operand is a Collector, the actual relationships may be formed lazily
  * A collector can not be combined with other types of references in the same operand (i.e.
    a collector can not be placed inside of an array)
* The references in an operand can be of different type:
  * Resource Reference - e.g. Resource[File, 'foo'], File[a]
  * An array of references - e.g. [File[a], File[b]]
  * A String, is shorthand for Class[string] 
  * An array with a mix of references (array can not contain a Collector Expression)
* An empty operand means that the result is a no-op (Debatable **PUP-996**)
* Operations can be chained

Note, that a Collector Expression has side effects; it will also perform a query and realize
unrealized resources. Queries are lazily evaluated before Relationships are lazily evaluated.

** Order of Evaluation **

* The lhs is evaluated before the rhs
* The operator is applied to the cartesian product
* The rhs is returned as a Q-value
* The relationship operands are left associative and have the same precedence which means that
  they can be chained to form several cartesian product such as a -> b -> c is processed as
  a × b, b × c

** Relationship Expressions are Q-Value producing **

* The relationship operators have very low precedence, only un-parenthesized function calls
  have lower precedence
* Because of the low precedence it is not possible to assign the result to a variable, but a Q-value
  is produced.
* The Q-value is always the evaluated unique set of references in the rhs.

Examples:

     $a = File[a] -> File[b]
     
is interpreted as:

     ($a = File[a]) -> File[b]

and the -value of File[b] was not assigned, here however, the variable is set to the Q-Value

     $a = if true { File[a] -> File[b] }
     
Since the only lower precedented expression is un-parenthesized function call - this is
possible:

     notify {a: message => 'a'}
     notify {b: message => 'b'}
     notice Notify[b]-> Notify[a]

Which will order the two resource, and print out the rhs result of `Notify[a]`

Whereas the example below results in syntax-error, because the relationship expression is of Q-value type.

     notify {a: message => 'a'}
     notify {b: message => 'b'}
     notice (Notify[b]-> Notify[a])  # syntax error on ->


Collector Expressions
---

Collector Expressions are used to query for *any* available resource with (`<| |>`), or
exported and virtual (`<<| |>>`) resources, modify parameters, and realizes any matched
unrealized resources into the catalog.

**NOTE** The `<| |>` operator collects all kinds of resources, regular and virtual
as well as exported that are created during the compilation. The `<<| |>>` only
matches exported resources, both those created during the compilation and those
that are exported from other nodes.

Collector Expressions are Q-value producing expressions. However Collector
Expressions can take part in Relationship Expressions, where all resources that
the collection matches have the Relationship Expression applied. If the query
does not produce any matching resources and used in a relationship, then the
relationship expression is a no-op.

Overrides apply to all resources that match the Query. Overrides are only applied to
any given resource once by a given query, multiple queries that match the
same resource modifies it once per query (and depends on the implementation's
evaluation order).

    CollectorExpression
       : QualifiedRefererence QueryPart ('{' OverrideAttributeOperations '}')?
       ;
       
     QueryPart
       : '<|' Query? '|>'
       | '<<|' Query? '|>>'
       ;

     Query
       : Query 'and' Query
       | Query 'or' Query
       | attr_name = SimpleName ('==' | '!=') query_value = QueryValue
       | '(' Query ')'
       ;
     
     QueryValue
       : VariableExpression
       | LiteralString
       | LiteralBoolean
       | LiteralNumber
       | QualifiedName
       ;

It is worth noting that:

* It is not possible to include general purpose expressions as values (as shown
  in the EBNF above).
* It is not possible to use arrays and hashes as query values.

The semantics of the Query is implementation dependent. However any implementation must accommodate:

* The evaluator may re-run the query against the configured backend many times.
* The collector when executing realizes all resources it finds and keeps track
  of what it has found so far (the specified operation; relationships, or
  resource attribute overrides) are only applied once for any given resource.
