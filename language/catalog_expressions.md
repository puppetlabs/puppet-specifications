Catalog Expressions
===
Catalog Expressions are those that directly relate to the content of the catalog produced
by the evaluation of a Puppet Program.

* **Node Definition** - associates the logic producing a particular catalog with the node making 
  a request for a catalog.
* **Class Definition** - creates a grouping of resources
* **Resource Type Definition** - creates a new (User Defined) Resource Type
* **Resource Expression** - creates resources
* **Resource Default Expression** - sets default values for resources per resource type
* **Resource Override Expression** - overrides attributes set in resources
* **Relationship Operators** - defines the application order or resources in the catalog
* **Collection** / **Query** - realizes virtual resources and optionally overrides their parameters, and imports external resources based on a query.

This section focuses on the syntactic aspects of these expressions. There are additional semantic rules, rules specific per type (an extensible set), evaluation order semantics, as well as semantics for catalog application that are covered in a separate chapter.

The general loading and evaluation of Puppet logic is described in the section [Modus Operandi][1]. For the semantics for each type (e.g. `File`, `User`), please refer to the documentation available per resource type.


### Parameter List

The parameter list is common to several of the catalog expressions:

    ParameterList
      : ParameterDeclaration (',' ParameterDeclaration)* ','?
      ;
      
    ParameterDeclaration
      : type = Expression<Type>? name = VariableExpression ('=' defaultValue = Expression<R>)?
      ;
    
    VariableExpression : VARIABLE ;

* The `VARIABLE` must contain a simple name
* A *captures rest* (as allowed for functions) is not allowed in parameter lists for a
  catalog related expression.
* The default value expression must evaluate to an instance of the specified type.
* The default value expression may evaluate to undef if the parameter type allows it.
* If a parameter type is not specified, the default is `Any`.
* The default value expression may not assign to/create a new variable.

See [Parameter Scope][2] for more information about default value expressions.


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

* Use of `inherits` raises an error as node-inheritance support is discontinued.
  * An implementation may treat this as a syntax error, or parse and validate it as an error
* The `HostMatch` consisting of a sequence of period separated `NAME` or `NUMBER` lexical tokens
* Note that `WHITESPACE` between period separated `NAME`/`NUMBER` tokens is not included in the
  result.
* All host matches (except regular expression and literal `default`) must result in a string
  that consist of a sequence of characters `a-z A-Z 0-9 _ - .`. An error is raised if the
  resulting host match string does not comply with this rule.
* Node definitions may not be made in a module.
* Node definitions are lazily evaluated after having been selected, see [Modus Operandi][1].

<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to evaluate NodeDefinitions, the above defined
  rules are enforced by the grammar / validation.
</td></tr>
</table>

### Class Definition

Syntax:

    ClassDefinition
      : 'class' ('(' ParameterList? ')')? ('inherits' QualifiedName)? 
          '{' Statements? '}'
      ;
      
* A class definition may only appear at the top level in a file, or inside a class definition
* A class may inherit another class
* A class may have parameters
* A parameter declaration may have a default value expression
* Parameter declarations with default value expression may appear anywhere in the list
* Parameter default value expressions:
  * should not reference other parameters in the list - the evaluation order is undefined when
    using an implementation that does not guarantee the correct order.
  * may reference variables defined by the inherited class (it is initialized before the
    inheriting class).
* A class defines a named scope and makes all of its parameters and variables visible.
* A class defined inside another class automatically becomes prefixed with the containing class'
  name as its name space.
* Circular inheritance is not allowed.
* Class definitions are lazily evaluated, see [Modus Operandi][1].


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
       : 'define' QualifiedName ('(' ParameterList? ')')?
           '{' Statements? '}'
       ;

* A Resource Type named the same as a type provided in a plugin will never be selected
* The default parameter value expressions may not reference variables in the calling scope, and
  should not reference any of the other parameters in the list when using a runtime where the
  order is not guaranteed. It may reference metaparameters and global variables.
* A define may occur at top level, or inside a class
* A resource type defined inside a class automatically becomes prefixed with the containing class'
  name as its name space.
* A resource type defined in a class only becomes visible if the class is loaded.
* A resource type is evaluated lazily when an instance of the type is
  created, see [Modus Operandi][1]. Each created instance evaluates the defined type's body
  once.


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

     # This syntax is common to the different kinds of resource expressions
     # See the semantic rules for details.
     
     # A tree data structure to describe the allowed title expression types.
     # This data structure does not exist in the Puppet Types
     #
     Tree[T] = Variant[T, Array[Tree[T]]]

     ResourceExpression
       : (virtual = '@' exported = '@'?)?
         type_name = (ResourceTypeReference | 'class')
         '{' ResourceBody (';' ResourceBody)* ';'? '}'
       ;
       
     ResourceTypeReference<CatalogEntry>
       :  QualifiedName
       |  QualifiedReference
       |  QualifiedReference '[' type_name = Expression ']'
       ;
       
     ResourceBody
       : titles = TitleExpression ':' ResourceAttributes? 
       ;
       
     ResourceAttributes
       : AttributeOperation (',' AttributeOperation)* ','?
       ;

     AttributeOperation
       : AttributeSet
       | AttributeAppend
       | AttributeFromHash
       ;

     AttributeSet
       : name = AttributeName '=>' value = Expression
       ;

     AttributeAppend  
       : name = AttributeName '+>' value = Expression
       ;

     AttributesFromHash
       : '*' '=>' Expression<Hash[String[1], Any]>
       ;

     AttributeName
       : KEYWORD
       | NAME
       ;
       
     TitleExpression
       : Expression<Tree[Variant[String[1], Default]]>
       ;

** Return Value **

A `ResourceExpression` returns an `Array[Type[CatalogEntry]]` type, where each entry is a reference to a just created resource
(a `Resource` or a `Class` type). Note that the resource expression itself has very low precedence, and it is not possible to directly assign the value of this expression to a variable - but when this expression is the last in a block it can be obtained.

```puppet
$created = ['message1', 'message2'].map | $m | { notify { $m: } }
```
would create two notify resources and output:
```puppet
[[Notify['message1']], [Notify['message2']]]
```

** Semantic Constraints **

* A `type_name` is restricted to the keyword `'class'`, `QualifiedName`, `QualifiedReference`, and 
  `AccessExpression`  with a left expression being a `QualifiedReference`.
  At runtime, the expression must evaluate to a `CatalogEntry` without a title.
  (Since it would conflict with the titles that are in the `ResourceBody`).

* The `type_name` of `'class'` and an `Expression` that evaluates to the `CatalogEntry` of `Class` 
  are interpreted equivalently. A `type_name` must be a reference to an existing plugin, provided
  custom resource type, or defined resource type. When the type name is `class` or evaluates to the   
  `CatalogEntry` of `Class` the titles are the names of classes, and they must 
  conform to class naming rules.

* The list of all titles (the `String[1]` or `Default` values of the `Tree`) from all
  `TitleExpression`s in a single `ResourceExpression` must not contain the same title more
  than once.

* The name of an attribute may be any keyword (except `true` or `false`), a simple name (a name
  not containing `::`). Names may not start with a digit. (Note that a future version of this 
  specification may specify use of '::' to address attributes that are specific to a provider on
  the format `providertype::attribute` - PUP-3146).

* The `names` given for the `ResourceAttributes` of a single `ResourceBody` must be unique.

* The `AttributeAppend` may not be used in a Resource Expression.

* When attributes are set using the `* =>` syntax, the given value must be a `Hash` with
  keys representing valid attribute names for the resource mapped to a value of a valid data
  type for that attribute. The values set this way are subject to the same rules as if
  the `key => value` entries in the hash had been made directly in the resource body (i.e. they
  must be unique).

* A `* =>` may appear anywhere in the list of attribute operations, but may only be used once per
  resource body.

* A body with a title of `Default` type defines a *local default*, other bodies in the same resource
  expression will use the attribute operations for this body as default values.
  
* It is allowed to give a mix of `String` titles with the `default` title. The default title has
  no effect on the created resources from the same title (it cannot, since the key/values are 
  exactly the same), but defines the defaults for any additional bodies in the same resource 
  expression.
  
* The effect of a *local default* does not extend beyond one resource expression.


** Realized, Virtual, and Exported Resources **

All resources created by a resource expression are created with a status of either *realized*, *virtual*, or *exported*. A "realized" resource is created and placed in the catalog. A "virtual" resource is created, but is not placed in the catalog. An "exported" resource is created, not placed in the catalog, and made available to catalog processors. All resources created by the same resource expression have the same status.

** Order of Evaluation **

1. The `type_name` is evaluated.
1. Each `ResourceBody` is evaluated in the order they appear (top to bottom) in the source text.
   1. The `TitleExpression` is evaluated.
   1. Each `AttributeOperation` value expression is evaluated and mapped to the attribute `name`.
   1. The `AttributesFromHash` expression is evaluated. Each key of the resulting `Hash` is used as 
      the name of an attribute and the value for that key is the attribute's value.
1. A resource is created for each title, except a resource with a title type of `Default`.
   * The attributes of the resource are the evaluated default attributes overridden by
     the attributes from the title's `ResourceBody`. Note: an attribute with a value of `undef` is 
     not handled specially as is done when deciding whether to use the default expression
     of a parameter.
   * The set of attributes given is checked against the set of declared parameters for the 
     `type_name` (or the `title` in the case of a `class` type). It is an error if there is no 
     available type or if one of the evaluated attributes does not exist on the type.
   * An attribute that evaluates to `undef` acts as if that attribute was not set and will
     trigger the parameter's default expression (or automatic parameter lookup (if the resource
     is a class)). Also see "Undef Parameters" below.
   * Virtual and exported resources are remembered for reference, and for future operations.
   * Regular resources are *realized* (placed in the catalog).
1. The resource instance is lazily evaluated by placing it in a queue, as
   described in [Modus Operandi][1].

** Undef Parameter Values **
As noted in "Order of Evaluation", an attribute operation that results in an undef value for a 
parameter that has a default value expression is equivalent to not including an attribute operation for that name as a given undef triggers the default value expression for the parameter. If the resource is a class, it will also trigger the data binding service to supply the value. If the parameter does not have a default value expression (or value to lookup), a given `undef`, results in an `undef` parameter value, and a missing attribute operation results in an error (no value given, not even undef).

This is illustrated in the table below. A `-` indicates missing as opposed to a given
undef. These rules apply for classes since data binding lookup is not available for other
resources.

| default expression | lookup | given  | result
| ---                | ---    | ---    | ---
| 10                 | -      | -      | 10
| 10                 | -      | 20     | 20
| 10                 | -      | undef  | 10
| 10                 | 30     | -      | 30
| 10                 | 30     | 20     | 20
| 10                 | 30     | undef  | 30
| undef              | -      | -      | undef
| undef              | -      | 20     | 20
| undef              | -      | undef  | undef
| undef              | 30     | -      | 30
| undef              | 30     | 20     | 20
| undef              | 30     | undef  | 30
| -                  | -      | -      | **error**
| -                  | -      | 20     | 20
| -                  | -      | undef  | undef
| -                  | 30     | -      | 30
| -                  | 30     | 20     | 20
| -                  | 30     | undef  | 30

This means:

* It is not possible to set an explicit `undef` if a value is bound via data binding.
* A given explicit `undef` does not count as a missing value (if there is no default or value
  to lookup).
* Use a parameter type that does not accept `Undef` to ensure that value is never `undef`.
* Use a default value of `undef` to equate missing value (and lookup) with a given `undef`.


### Resource Default Expression

A Resource Default Expression sets the default values to use for resources created in a scope where the expression is visible.

The scooping of Resource Defaults follow the 3x rules for *dynamic scoping*. Dynamic scoping means
that a search is made for the closest defined entity, starting in the current scope, then inherited scopes, then the scopes (transitively) where the resource was defined, then node and global scope. The search when looking up in a scope also includes everything that is visible to that scope. Thus, the *dynamic scoping* casts a very wide net that makes it difficult to reason about which
entity that will be picked.

<table><tr><th>Note</th></tr>
<tr><td>
  <p>
  All other usage of dynamic scoping except for defaults have been removed. In this version
  of the specification the Resource Default Expression still follows the old rules since
  it would have a very negative impact on compatibility to remove it. Removing dynamic scoping
  (only following lexical scoping) would remove all powers from this expression without providing
  a replacement. A future version of the specification will address the much requested
  feature of multiple definitions (merging them and handling conflicts) - the issues relating
  to setting defaults will then also be addressed.
  </p>
  <p>
  Until then, because of the difficulties of predicting the effect of the defaults expressions,
  they should simply be avoided.
  </p>
</td></tr>
</table>

    ResourceDefaultExpression
      : type = QualifiedReference '{' ResourceAttributes? '}'
      ;
     

* The type must be a reference to an existing resource type (plugin or user defined). Only a 
  `QualifiedReference` is accepted (as in 3x), or an AccessExpression with a left expression
  being a `QualifiedReference`.
* Setting defaults for classes e.g. `Class { a => foo }` is not allowed.
* A regular attribute operation using `=>` to assign the value sets the default value of the
  given attribute.
* An append attribute operation using `+>` assigns a value by appending the result of the
  value expression to the current default value of the given attribute. If no such default value
  exists, the operation yields the same result as if `=>` had been used.
* It is not allowed to redefine the default value for an attribute within the same scope.
* It is allowed to have multiple default expressions in the same scope provided they define
  different attributes.
* All visible defaults are merged.
* The use of `*` `=>` sets attributes from key/values in the RHS hash as if they had been 
  individually given with `key => value`.

Also see [Parameter Scope][2] for more information about default value expressions.

### Resource Override Expression

A Resource Override Expression sets new values in un-assigned attributes in a
referenced resource. It can also modify assigned attributes in a resource that
is declared in an inherited class when the override is evaluated in the scope of
the derived class.

     ResourceOverrideExpression
       : ResourceReferences '{' ResourceAttributes '}'
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
      * The behavior if it does not accept an array is resource implementation specific.
    * If no value was previously been assigned, the given value is assigned as if
      the `=>` operator had been used.
    * If a value has been assigned, and it is not an array, the value is wrapped in an array
      before the new value is appended
    * If the resulting value is an array, it is also flattened (nested arrays are flattened out).
  * The `*` `=>` sets attributes from key/values in the RHS hash as if they had been individually 
      given with `key => value`
* **Otherwise:**
  * The `=>` operators sets the value of the given attribute in all referenced resource instances
    provided that the attribute does not already have a value.
    * An error is raised if attribute already has a value
  * The `+>` operator raises and error (if there was a value it would append it and thus change
    the value; which is not allowed, and if there is no value, it is the same as `=>`, and
    this should have been used instead).
  * The `*` `=>` sets attributes from key/values in the RHS hash as if they had been individually 
    given with `key => value`
  
    
** ResourceReferences **

* Resource References must be resource instance specific (it is not possible to refer to
  all instances of a resource type).

Examples:

    File['foo'] { mode => '0666' } 
    File['foo', 'fee', 'bar'] { mode => '0666' }
    File[]                                        # syntax error
    File { mode => 0666 }                         # a Resource Default Expression, not override
    
    Resource['File', 'foo', 'bar'] { mode => '0666'}
    $type = File
    $type['foo', 'bar'] { mode => '0666' }
    
    $resources = File['foo', 'bar']
    $resources { mode => '0666' }

<table><tr><th>Note</th></tr>
<tr><td>
  The 4x implementation uses the 3x logic to apply overrides, and to calculate the result
  of appending to an outer scope default. This means that the specified append logic may vary
  between resource types.
</td></tr>
</table>

### Relationships

Relationship Expressions are used to ensure that resources are applied (on an agent) in a
specific order. There are two kind of operators `->` (that specifies the order), and
`~>` (that specifies notification of change (which implies order)).
Both kinds can be used in the reverse i.e. `<-` and `<~`

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

** Relationship Expressions have low precedence **

* The relationship operators have very low precedence, only un-parenthesized function calls
  have lower precedence
* Because of the low precedence it is not possible to directly assign the result to a variable. If a relationship is formed as the last expression in a block the produced value is the unique set of references in the rightmost resource set. Such a value can be assigned.

Examples:

     $a = File[a] -> File[b]
     
is interpreted as:

     ($a = File[a]) -> File[b]

and the -value of File[b] was not assigned, here however, the variable is set to set of 
references

     $a = if true { File[a] -> File[b] }
     
Since the only lower precedented expression is un-parenthesized function call - this is
possible:

     notify {a: message => 'a'}
     notify {b: message => 'b'}
     notice Notify[b]-> Notify[a]

Which will order the two resource, and print out the rhs result of `Notify[a]`

Whereas the example below results in syntax-error, because of the low precedence of the relationship expression.

     notify {a: message => 'a'}
     notify {b: message => 'b'}
     notice (Notify[b]-> Notify[a])  # syntax error on ->

<table><tr><th>Note</th></tr>
<tr><td>
  These restrictions and the precedence of the relationship operators may be changed in a future
  specification as the solution in the current implementation is undesirable.
</td></tr>
</table>

Collector Expressions
---

Collector Expressions are used to query for *any* available resources (`<| |>`), or
exported and virtual (`<<| |>>`) resources, modify parameters, and realizes any matched
unrealized resources into the catalog.

**NOTE** The `<| |>` operator collects all kinds of resources, regular and virtual
as well as exported that are created during the catalog production. The `<<| |>>` only
matches exported resources, both those created during the current catalog production and those
that are exported from other nodes.

Collector Expressions does not produce a directly assignable value. However Collector
Expressions can take part in Relationship Expressions, where all resources that
the collection matches have the Relationship Expression applied. If the query
does not produce any matching resources and used in a relationship, then the
relationship expression is a no-op.

Overrides apply to all resources that match the Query. Overrides are only applied to
any given resource once by a given query. Multiple queries that match the
same resource modify it once per query (and depends on the implementation's
evaluation order).

    CollectorExpression
       : QualifiedRefererence QueryPart ('{' AttributeOperations '}')?
       ;
       
     QueryPart
       : '<|' Query? '|>'
       | '<<|' Query? '|>>'
       ;

     Query
       : Query 'and' Query
       | Query 'or' Query
       | attr_name = AtributeName ('==' | '!=') query_value = QueryValue
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
* It is allowed to use `* => hash` as an attribute operation

The semantics of the Query is implementation dependent. However any implementation must accommodate:

* The evaluator may re-run the query against the configured backend many times.
* The collector when executing realizes all resources it finds and keeps track
  of what it has found so far (the specified operation; relationships, or
  resource attribute overrides) are only applied once for any given resource.

[1]: modus-operandi.md
[2]: parameter_scope.md
