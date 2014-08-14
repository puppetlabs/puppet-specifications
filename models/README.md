The LanguageSpec Model
===

The intention of the language specification model is to be an implementation independent specification of the expectancies / requirements on a Puppet Program.

Initially the model captures parser and validation expectancies. The intention is to also add Evaluation and Catalog related expectancies.

The rationale for this model is that an implementation neutral assertable specification is required to ensure specification compliance.

The model can be used in various ways:

* Rspec or JUnit runners can translate and execute the model dynamically
* Code can be generated in an implementation language - an implementation that runs the tests

S-Expressions
---
The AST model assertions are based on transformation of puppet AST to S-Expressions ([1]). Reference implementations of the AST model to S-expressions are / will be available in Java and Ruby.

This ensures that the tree representations can be expressed without implementation concern (an implementation may not be based on the actual Puppet AST ecore model), and an implementor of a
different model can then transform an implementation specific model into S-expressions in order
to validate the result.

[1]: http://en.wikipedia.org/wiki/S-expression

Current Version of the Model
---
The initial (and current) version of the model only covers expectancies of parse results
and validation of parsed results. The intention is to also add assertions/expectancies for evaluation results and resulting catalog results.

As an example. The model now is rich enough to expression that a statement like:

    $a = 1 + 1
    
Should result in the S-expression:

    (= $a (+ 1 1))
    
(NOTE: Presently the Model to S-Expression has been a debugging tool, and this mapping needs
to be formalized and reviewed. As an example, `$a` should probably be expressed as `(var a)`).

The model can also describe expectations on SyntaxError and Diagnostics (validation results).

Expectations can be combined (default is AND) with NOT, OR, and XOR (exclusive or).

Semantics
---
The execution of tests are driven by the expectancies. If a parse result is expected, then naturally
the given source string must be parsed. If no diagnostics expectancies are given, then it is expected
to be free from diagnostics. If diagnostics expectancies are present, the given diagnostics expectancies defines the full set of assertions applied to the produced diagnostics.

When evaluation expectancies are added, the semantics are similar - if a catalog result is expected,
naturally there is the need to build a catalog from the given source. A simpler evaluation expectancy (say 1 + 1 == 2) may only require a partial evaluation.

(NOTE: It is the intention to add evaluation expectancies in a later revision).
