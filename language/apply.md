Apply Expression
===

An `ApplyExpression` describes a manifest block which will be compiled to a catalog and applied on remote nodes.

Grammar
---

    ApplyExpression
      : 'apply' arguments = ArgumentList '{' statements? '}'
      ;

    statements
       # All statements in the Puppet Programming Language (not shown) except NodeDefinition,
       # ClassDefinition, ResourceTypeDefinition, FunctionDefinition, and exported resource collectors
       : ...
       | primary_expression

    primary_expression
      : ... # all expressions that are primary expression in the Puppet Language (not shown)
      | epp_render_expression

See [Function Calls](expressions.md#function-calls) for `ArgumentList` grammar definitions.

An `ApplyExpression` takes an argument list of zero or more arguments. The intention is that the 1st
argument is required, and represents a set of remote nodes to operate on, while the second argument is a hash of
options. However defining the behavior of an ApplyExpression is out of the scope of this standard.

The statements of an ApplyExpression comprise those statements expected within a manifest or the body of a class,
excepting statements that themselves define named objects. The scope of statements is considered to be top-scope.

An ApplyExpression may return a value.

ApplyExpression is allowed within a PlanDefinition (to be defined later).
