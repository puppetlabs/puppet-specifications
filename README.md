Puppet Specifications
===

This repository contains specifications for [the project Puppet][1], and related technologies.

Puppet Language Specification
---
The Puppet Programming Language Specification is a specification of the Puppet Programming
Language. The first published release of this specification specifies the language version 4.

The version 4.0.0 is the first version of the specification (this to make it harmonize
with the 4.0.0 release of Puppet). From that point, the intention is to keep the
same specification version even if the minor version of the implementation changes (i.e.
for other reasons that the specification has changed). When a specification change is made,
it *may* skip several numbers to again harmonize with the Puppet implementation version number.

Until Puppet 4.0 was released, there was just the "current" and "future" implementations
of the language. As time goes on it will be impossible to use only those words as their meaning
is relative to a particular release of puppet (the future in 3.6 is not the same as the future in 3.7, and again not the same as current in 4.0) - hence the need for a separate version of the
specification.

The [Puppet Project][1] is the reference implementation of the specification. 

Semantic Versioning
---
The specifications follows semantic versioning with the following semantics:

* The micro version contains corrections, clarifications of the specification. All implementation
  of the specification that are compliant with the same minor version are also compliant with
  all micro versions of the same minor version.
* The minor versions contains changes that are non breaking. But an implementation that
  is compliant with a previous minor versions is not automatically compliant with all future
  minor versions for the same major version.
* The major versions contains changes that are breaking. An implementation that is compliant
  with an earlier major version can not be compliant with a major specification change. (It may
  offser compliance with multiple versions of the specification via the use of feature flags).

Index
---

* [Introduction][2] - terminology and EBNF grammar
* [Modus Operandi][3] - overview of the runtime (loading, start-point, order of execution)
* [Types, Values and Variables][4] specification of types, values and variables
* [Naming and Scoping][5] - specification of names, scopes, and references
* [Lexical Structure][6] - specification of the textual aspects of the Puppet Language
* [Expressions][7] - specification of all non catalog expressions in the language
* [Catalog Expressions][8] - specification of all expressions related to catalog production
* [Expression Precedence][9] - specification of the precedence of expressions / operators
* [Puppet Functions][14] - functions in the puppet language
* [Deprecation][10] - specification of deprecated constructs
* PROPOSALS
* API
  * [Function Ruby API][11] - the API for writing functions in Ruby
  * [Plugin Ruby API][12] - the API for plugins in Ruby
  * [Resource Type Ruby API][16] - the API for resource types in Ruby
* Models
  * [Puppet Extended S-Expression Notation (PN)][17] - specification of the PN format 
* Plan Extensions
  * [Apply Expression][18] - an expression to capture a manifest block and apply it on remote nodes
* General
  * [Settings and Options][13] - specification of settings and options 
  * [Puppet Installation Layout][15] - specification of Puppet related files on disk

[2]:language/intro.md
[3]:language/modus-operandi.md
[4]:language/types_values_variables.md
[5]:language/names.md
[6]:language/lexical_structure.md
[7]:language/expressions.md
[8]:language/catalog_expressions.md
[9]:language/expression_precedence.md
[10]:language/deprecations.md

[11]:language/func-api.md
[12]:language/plugin-api.md
[13]:language/settings.md
[14]:language/puppet-functions.md
[15]:file_paths.md
[16]:language/resource_types.md
[17]:models/pn.md
[18]:language/apply.md

[1]:http://www.github.com/puppetlabs/puppet
