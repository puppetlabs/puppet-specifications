Modus Operandi
===
This chapter is about "method of operation" (modus operandi), a specification how code gets loaded, in which order, and the order of execution of a Puppet Program.

Point of Entry / Boot Phase
---
There are several points of entry

* An agent request a catalog
* A puppet apply
  * with code given on the command line as a string
  * with a reference to a file
  * running the code as per the configuration of puppet
* The puppet configuration contains several settings that affect the entry point
  * the use of an External Node Classifier
  * the path to where environments are found
  * the code setting which may contain a string to execute
  * the staring set of manifests (one or several in one directory in an environment)
  * plugins that are evaluated early and that contribute to the configuration / resolution
    or have a direct impact on the produced catalog.
* Utility commands that will evaluate a Puppet Program for the purpose of answering questions
  about it.

### Environment

Almost all puppet applications require an Environment. An environment defines where the
initial manifests are, and where modules are located. From Puppet 4.0 environments are
always directory based, an environment is represented by a directory having the name of
that environment and with a defined structure. The setting `environmentpath` defines where these directories are.

An Environment may have its own `environment.conf` file in its root directory with
overrides of default settings that apply only to this environment.

*TODO: Creation of the injector should be done (or at least be able to lazily get the injector)
as it depends on the boot, the environment and its module path. There may be injector specific 
settings for the environment. 3.7's injector is not directory environment ready.*

*TODO: Loaders are configured at this point. They determine the visibility of modules from the module path, and the visibility each module has into other modules that they depend on.*

### 'code' Setting

The `code` setting may contain a Puppet Program source string that is evaluated.

*TODO: Is this pre-pended to the environment's set of manifests, or does this overshadow
the use of environments, or is this the code for the "default environment" that does not
have a directory with its content*

### Environment Manifests

The manifests in the environment are placed in its `manifests` subdirectory. For the Environment
these are processed in alphabetical sequence. This is logically equivalent to concatenating
all of the files in alphabetical order into one single file.

*TODO: Does this happen before or after the ENC and plugins have given a chance to affect
the result*

### At the end of the Boot Phase

At the end of this phase, all infrastructure is configured for the evaluation of the Puppet Program that is defined by the settings, injected logic, initial manifests, and the modules on the module path.

Catalog Building Phase
---
The Catalog Building Phase commences after the Boot Phase. It performs an Evaluation of the initial
Manifest(s) which in turn may trigger Loading and Evaluation of additional Manifests. When this initial step is finished, the Catalog Building matches the Node making the request with the
set of known node definitions. The node definition that matches the current Node is then Evaluated (which in turn triggers the Loading and Evaluation of the remainder of the Puppet Program). The resulting catalog is then completed.

The sub phases of the Catalog Building Phase are:

* Initial Evaluation
* Selection of a node definition
* Evaluation of a node definition
* Catalog Completion

### Initial Evaluation

This is the execution of one Evaluation Phase for the purpose of establishing global values,
and optionally a set of node definitions. See the Evaluation Phase for how Manifests are
loaded and evaluated.

*TODO: This phase defines the availability of trusted information from the node. This
because logic loaded by the initial manifests may need this to establish what it
wants.*

### Selection of node definition

When the initial evaluation is completed, a set of global variables have been bound in top scope.
Optionally there are now also a set of (unevaluated) node definition known to the Catalog Builder.

A node expression has a match expression that is evaluated against information about the current node.

The rules are:

* *TODO: describe the node matching rules*
* default node
* nodes with regular expressions

A node definition is always selected. This definition may be empty in which case, the initially
evaluated logic and what it loads and evaluates is what defines the result.

### Evaluation of Node Definition

The selected node definition is evaluated after the initial evaluation. This is the execution
of one Evaluation Phase.


Evaluation Phase
---
The Evaluation Phase is a sub phase of the Catalog Building Phase. It is the general Load and Evaluate Loop. It behaves the same way at all times.

Loading is either explicit; a path to logic to load, or symbolic; load the entity of a given
type and name, which results in a search for the Manifest that should contain the wanted named
entity. Both ways of loading result in the same behavior once the Manifest file to load
is known.

The Manifest is Lexed and Parsed into an Abstract Syntax Tree (a Puppet Program Model). The system
may fail with an error if it was not able to complete this. Such a failure aborts the current transaction. Once a Puppet Program Model has been produced, this model is validated against
semantic rules. This may results in a set of warnings and errors. If there are errors, these
are reported and the transaction is aborted. Warnings are only reported.

The next step is to add all named definitions to the set of known definitions. Named definitions
are ClassDefinition, ResourceTypeDefinition, FunctionDefinition, and NodeDefinition. Their respective
definitions are not evaluated at this point, the result is a set of associations between their type/name and their definition.

If asked to load something where there is already a type/name => definition association, the already
known definition is used.

It is an error if a new load produces a type/name that already has an association with a definition
(redefinition error).

The body of the Manifest itself is then evaluated. As this body is the container of NamedDefinition, the evaluation of those result in a no-op (silent step over).

When evaluation requires a name/type element this triggers loading of that name/type and the
Evaluation Phase recurses.

A name/type is required when:

* A function is called (function/name => definition is needed in order to evaluate the function)
* A call to `include`, `require`, `contain`, is made (class/name => definition
  is needed in order to evaluate the class). If the definition has already been evaluated, this
  is a no-op.
* A queued expression is evaluated, and it requires a type/name => definition association.

The evaluation of the following expressions are queued:

* Resource Instantiation

The evaluation of the following expressions are placed in a queue that is evaluated during
the Catalog Completion Phase.

* Relationship Expressions
* Queries 

The evaluation of a Manifest continues until all expressions have been evaluated (top-down). Evaluation then continues to evaluate all queued expression. This may trigger new recursive loading,
type/name => definition association, and queuing of more expressions.
This evaluation continues until the evaluation queue is empty.

Catalog Completion Phase
---
The Catalog Completion Phase evaluates all Queries, and then all Relationship Expressions.
This may in turn trigger new Evaluation Phases if anything is placed in the evaluation queue.

Once there is nothing more to evaluate, and there are no unevaluated queries or relationship
expressions, the catalog is finished, validated and transformed to the requested catalog format.
Typically, this catalog is sent to an agent for application (synchronization of actual state with
the desired state described in the produced catalog), but catalogs may be produced for
other reasons (testing, documentation, etc.).
  
*TODO - the list of things to describe:*

* manifest ordering
* what the queries result in
* what the relationships result in

Application Phase
---
The Application Phase is the phase that occurs when a completed catalog is acted upon
by an agent for the purpose of synchronizing its managed resources with the desired state
described in the given catalog.

*TODO - the list of things to describe:*

* generated resources


Auto Loading
---
Referenced elements of the language are automatically loaded based on their name. This applies
to:

* classes
* resource types (plugins in Ruby and user defined resources)
* functions (both 3x and 4x APIs)

Auto loading has the following rules:

* A "definition" must be stored in a file that corresponds to its name in order for it
  to be automatically loaded.
* Nested constructs are only visible if parent has been loaded, there is no search for elements
  inside of files with a name different than the file.
* Auto Loading is performed from the perspective of the code that triggers the loading.

The semantics of the 3x loader is that everything is visible to everything else. These semantics apply to all types of elements except functions defined using the 4x function API.

The 4x function API uses the 4x loaders which restrict the visibility by using the following rules.

* Elements defined by Puppet runtime (e.g. logging functions) is visible to everything else
* Everything in the Puppet runtime (the core) is available to everything else
* Everything defined at the environment level is visible to all modules in that environment
* A module without declared dependencies sees what is generally available, and all other modules
* A module with declared dependencies has visibility into what is generally available and the modules
  on which it depends.
