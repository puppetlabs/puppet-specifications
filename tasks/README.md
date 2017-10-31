# Puppet Task Spec (Version 1)

The Puppet Task ecosystem allows users to execute actions on target systems. A **Task** is the smallest component of this system capturing a single action that can be taken on a target and is - in its simplest form - an executable file. It is packaged and distributed as Puppet modules which are made available to the task runner.

## Design goals

- The barrier to entry for writing simple tasks should be as low as possible. Drop a script in a folder and it's runnable.
- Start with a small functional core and add features as needed.

## Terminology

**Task**: A task is a file and an optional metadata file that will be executed on a target.

**task runner**: The application which executes tasks on target systems. This is the interface for controlling and running tasks, and is assumed to provide some sort of programatic interface (API). In initial releases this is Orchestrator (executing via PXP) and [Bolt] (via ssh/winrm). In the future new task runners may be added. For example the puppet agent may run tasks from resources.

**UI**: User interface, such as CLI tools ([Bolt], `puppet task`) or the Puppet Enterprise Console.

## Puppet Task Spec Versioning

Orchestrator shipped in PE 2017.3 supports version 1. [Bolt] is planned to support version 1 by 1.0.

Changes to the task spec that do not bump the version must not break existing tasks. We may add properties to the metadata defined in version 1 without bumping the version.

Older versions of the task runner may not support tasks that rely on newer features of the task spec. The task spec version is not intended to capture this now. Authors should use the `puppet_task_version` field in the module's metadata to document such incompatibilities for users.

## Task packaging and file

Tasks are packaged and distributed in the `/tasks` directory of a Puppet module. Any file in the top level of that directory with a valid name is considered a task. In addition to tasks, task authors may create a metadata file for the task with the same name and a `.json` extension.

### Task name and filename

- Task names have the same restriction as puppet type names and must match the regular expression `\A[a-z][a-z0-9\_]*\z`.
- Filenames not matching the task name regular expression will be ignored.
- Tasks are referred to as `module_name::task_name`.
- Tasks must exist at the top level of the tasks directory to be found.
- Task metadata is stored in `task_name.json` and is optional.
- The executable for the task must be stored in `task_name` or `task_name.<extension>`(where extension != `json`, `md` or `conf`).
- The presence or absence of an execute bit should be ignored by the task runner when finding task files and metadata.
- The name `init` and `init.<extension>` are treated specially and the init task may be referred to by the shorthand `module_name`.

A task with multiple executable files will be considered invalid.

Tools for validating this metadata and making local task execution easier when testing will eventually be added to the PDK.

### Task metadata

Task metadata is stored in `/tasks` dir in the module in `task_name.json` with `UTF-8` encoding.

All fields should have reasonable defaults so that writing metadata is optional. Metadata defaults should err towards security.

The preferred style of the keys should be `snake_case`.

#### Options

**description**: A description of what the task does.

**puppet_task_version**: The version of this spec used.

**supports_noop**: Default `false`. This task respects the `_noop` metaparam. If this is not set the task runner will refuse to run the task in noop.

**input_method**: What input method to use to pass parameters to the task. Default varies, see [Input Methods](#input-methods).

**parameters**:  The parameters or input the task accepts listed with a [Puppet data type](../language/types_values_variables.md) string and optional description. Top level params names have the same restrictions as Puppet class param names and must match `\A[a-z][a-z0-9_]*\z`.

#### Example

```json
{
  "description": "Description of what the task does",
  "parameters": {
    "param1" : {
      "description": "Description of what param1 does with option1 or option2",
      "type": "Enum[option1, option2]"
    },
    "param2": {
      "description": "Description of what param2 does with an array of non-empty strings",
      "type": "Array[String[0]]"
    },
    "param3": {
      "description": "Description of optional param3",
      "type": "Optional[Integer]"
    }
  }
}
```

A JSON schema of metadata accepted by task runners is included in [task.json](task.json). The Puppet Forge also hosts https://forgeapi.puppet.com/schemas/task.json describing requirements for metadata in published modules; the schema for publishing may be more restrictive to ensure published modules are easy to use without reading their implementation.

## Task parameters

The parameters property is used to validate the parameters to a task and generate UIs.

If the parameters property is missing or `null` any parameter values with be accepted. Authors should not write tasks without specifying parameters.

If the parameters property is empty no parameters will be accepted.

Any parameter that does not specify a type will accept any value (default type is [Any](../language/types_values_variables.md#any) or [Data](../language/types_values_variables.md#data)).

If a parameter type accepts `null` the task runner will accept either a `null` value or the absence of the property. Task authors must accept missing properties for nullable parameters. Task authors must not differentiate between absent properties and properties with `null` values.

## Task execution

The task file is copied to the target and then executed on the target by the task runner.

No arguments are passed to the task when it is executed.

The task file in the module does not need execute permissions set.

The location of the task file varies based on the transport used by the task runner. Task authors have no control over this path.

The operating environment the task is executed in (such as environment variables set and user privilege) is also controlled by the task runner. Task authors should document any requirements they have.

Task runners will handle execution on Microsoft Windows specially based on the following mapping for file extensions:

- **.ps1**: powershell
- **.rb**: puppet agent ruby if available
- **.pp**: puppet apply

Future releases of the task runner may expand this or add configuration options to the task runner around interpreter choice.

## Input Methods

There are a three input methods available to tasks: [stdin](#stdin), [environment](#environment-variables), and [powershell](#powershell). By default tasks without a `.ps1` extension are passed parameters with both the `stdin` and `environment` input methods. Tasks with a `.ps1` extension are passed parameters with the `powershell` input method by default.

In the future we may support other formats and methods for passing params to the task.

### Stdin

The parameters are passed to the task in a JSON object on `stdin`.

In addition to the tasks parameters, the task runner may inject metaparameters prefixed by '_', for example `_noop`.

### Environment Variables

Params are set as environment variables before the task is executed.

Param names will be prefixed with `PT_` to create the environment variables in the form `PT_<param_name>` (i.e. the value of the `foobar` param is set as `PT_foobar`).

String parameters will not be quoted. Numerical parameters and structured objects will use their JSON representations.

#### Example

##### JSON
```json
{
  "a": 1,
  "b": "a string",
  "c": [1, 2, "3"],
  "d": {"x": {"y": [0]}}
}
```

##### Environment Variables
```bash
PT_a=1
PT_b=a string
PT_c=[1, 2, "3"]
PT_d={"x": {"y": [0]}}
```

### Powershell

The `powershell` input method will pass each param as a named argument to the powershell script. This is the default input method for task files ending with a `.ps1` extension.

## Output handling

### Stdout

Task output is consumed on stdout and made available through the task runner API.

If the output cannot be parsed as a JSON object (i.e. `{...}`), one is created by the task runner with the captured stdout stored in the  `_output` key: i.e. `{"_output": "the string of output"}`. Otherwise the parsed JSON object is used.

All '_' prefixed keys are reserved and should only be used as described below:
- **_output**: A text summary of the job result. If the job does not return a JSON object the contents of stdout will be put in this key.
- **_error**: Tasks can set this when they fail and the UI can more gracefully display messages from it.

### Stderr

Stderr may be captured by the task runner.

In the initial release it may be temporarily stored on the target but not exposed through the task runner API. This behavior may change in future iterations of the task runner.

### Exitcode

The exitcode of the task is captured and exposed by the task runner.

An exitcode of 0 is considered success by the task runner. Any non-zero exit code is considered a failure.

If a task returns a non-zero exit code it may return a response on stdout with the `_error` object of the following form:
```json
{
  "kind": "mytask/myerror",
  "msg": "task failed because",
  "details": { "key": "value" }
}
```

otherwise a default `_error` will be generated by the task runner:
```json
{
  "kind": "puppetlabs.tasks/task-error",
  "msg": "The task errored with a code 12",
  "details": { "exitcode": 12 }
}
```

## Errors

Errors should be generated in the task_runner when the task could not be successfully executed or the results of the task could not be captured. 

Some examples:
- **task_file_error**: The task could not be copied onto the target.
- **unexecutable_task**: The task execution failed.
- **unparsable_output**: The task output could not be parsed with any of the specified formatters.
- **output_encoding_error**: The task output was not utf-8.

The JSON schema for errors is included in [error.json](error.json).

[Bolt]: https://github.com/puppetlabs/bolt