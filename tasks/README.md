# Puppet Task Spec (version 1, revision 4)

The Puppet Task ecosystem allows users to execute actions on target systems. A **Task** is the smallest component of this system capturing a single action that can be taken on a target and is - in its simplest form - an executable file. It is packaged and distributed as Puppet modules which are made available to the task runner.

## Design goals

- The barrier to entry for writing simple tasks should be as low as possible. Drop a script in a folder and it's runnable.
- Start with a small functional core and add features as needed.

## Terminology

**Task**: A task is a file and an optional metadata file that will be executed on a target.

**task runner**: The application which executes tasks on target systems. This is the interface for controlling and running tasks, and is assumed to provide some sort of programmatic interface (API). In initial releases this is Orchestrator (executing via PXP) and [Bolt] (via ssh/winrm). In the future new task runners may be added. For example the puppet agent may run tasks from resources.

**UI**: User interface, such as CLI tools ([Bolt], `puppet task`) or the Puppet Enterprise Console.

## Puppet Task Spec Versioning

The task spec has a version and a revision. Changes that break existing tasks increment the version of the task spec. Revisions function as a minor version and are incremented for new features. This spec indicates in parentheticals the revision number for new features, for example "Running remote tasks (rev 4)." 

Older versions of the task runner may not support tasks that rely on newer features of the task spec. The task spec version is not intended to capture this now. Authors should use the `puppet_task_version` field in the module's metadata to document such incompatibilities for users.

Task Runners should document which version and revision of the task spec they support.

### Revision history

These are the revisions to this version of the task spec. 

**Note**: Bolt always uses the latest version and revision of the task spec. Puppet Enterprise versions use a specific version and revision of the task spec, indicated below. 

| Revision | Changes                  | PE version                |
|----------|--------------------------|---------------------------|
| 1        |                          | 2017.3.z 2018.1.z         |
| 2        | Cross-platform tasks.    | 2019.0.0                  |
| 3        | Multiple files per task. | 2019.0.1                  |
| 4        | Hide private tasks.      |                           |

## Task packaging and file

Tasks are packaged and distributed in the `/tasks` directory of a Puppet module. Any file in the top level of that directory with a valid name is considered a task. In addition to tasks, task authors may create a metadata file for the task with the same name and a `.json` extension.

### Task name and filename

A task consists of an optional metadata file and one or more implementation files. Files with the `.json` extensions are metadata files, and any other file extension (including files with no extension) is an implementation file. Implementation files do not need the executable bit set.

An implementation file `<task>.<ext>` without a corresponding metadata file `<task>.json` is a task.

A metadata file `<task>.json` also identifies a task. If the metadata specifies an `implementations` array, then the files listed in that array are the implementations for the task. Otherwise, there must be one corresponding implementation file `<task>.<ext>`.

Task names have the same restriction as puppet type names and must match the regular expression `\A[a-z][a-z0-9\_]*\z`. The extensions `.md` and `.conf` are forbidden. Only files at the top level of the `tasks` directory matching the task name regular expression are used; all other files are ignored.

The canonical name of a task is `<module_name>::<task>`. The `init` task is treated specially, and may be referred to by the shorthand `<module_name>`.

### Task metadata

Task metadata is stored in `/tasks` dir in the module in `<task>.json` with `UTF-8` encoding.

All fields should have reasonable defaults so that writing metadata is optional. Metadata defaults should err towards security.

The preferred style of the keys should be `snake_case`.

#### Options

**description**: A description of what the task does.(rev 1)

**puppet_task_version**: The version of this spec used.(rev 1)

**supports_noop**: Default `false`. This task respects the `_noop` metaparam. If this is not set the task runner will refuse to run the task in noop.(rev 1)

**input_method**: What input method to use to pass parameters to the task. Default varies, see [Input Methods](#input-methods).(rev 1)

**parameters**:  The parameters or input the task accepts listed with a [Puppet data type](../language/types_values_variables.md) string and optional description. Top level params names have the same restrictions as Puppet class param names and must match `\A[a-z][a-z0-9_]*\z`. Parameters may be `sensitive` in which case the task runner should hide their values in UI where possible.(rev 1)

**files**: A list of file resources to be made available to the task executable on the target specified as file paths. Files must be saved in module directories that Puppet makes available via mount points: `files`, `lib`, `tasks`. File specifications ending with `/` will require the entire directory. File separator must be `/`. (rev 3)

**implementations**: A list of implementation objects. An implementation object describes resources and feature requirements that must be available on a target for specified resources to be utilized. The available features are defined by the task runner; task runners should define at least the `shell`, `powershell` and `puppet-agent` features.(rev 2)

**private**: A boolean to specify whether a task should be hidden by default in the UI. This is useful if a task has a machine oriented interface or is intended to be used only in the context of one plan. Default is false.(rev 3)

**extensions**: A hash of extensions to the task spec used by a Specific Task Runner. Each key at the top level should be the name of the Task Runner the extension is used by. Task Runners should not read extensions outside of their own namespace.(rev 3)

**remote**: Default `false`. All implementation of this task operate on a remote target using the `_target` metaparam.(rev 4)


#### Example Task Metadata

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
      "type": "Array[String[0]]",
      "sensitive": true
    },
    "param3": {
      "description": "Description of optional param3",
      "type": "Optional[Integer]"
    }
  },
  "implementations" : [
    {"name": "foo_sh.sh", "requirements": ["shell"], "input_method": "environment"},
    {"name": "foo_ps1.ps1", "requirements": ["powershell"], "files": ["my_util/files/util/win_tools.ps1"]}
  ],
  "files": ["my_module/lib/puppet_x/helpful_code.rb", "kitchensink/files/task_helpers/"]
}
```

A JSON schema of metadata accepted by task runners is included in [task.json](task.json). The Puppet Forge also hosts https://forgeapi.puppet.com/schemas/task.json describing requirements for metadata in published modules; the schema for publishing may be more restrictive to ensure published modules are easy to use without reading their implementation.

## Task parameters

The parameters property is used to validate the parameters to a task and generate UIs. The property names in this object are the parameter names and map to a parameters options object.

If the parameters property is missing or `null` any parameter values with be accepted. Authors should not write tasks without specifying parameters.

If the parameters property is empty no parameters will be accepted.

Any parameter that does not specify a type will accept any value (default type is [Any](../language/types_values_variables.md#any) or [Data](../language/types_values_variables.md#data)).

If a parameter type accepts `null` the task runner will accept either a `null` value or the absence of the property. Task authors must accept missing properties for nullable parameters. Task authors must not differentiate between absent properties and properties with `null` values.

### Options

**type**: A Puppet Type string describing the type of value the parameter accepts. Default is `Any`.(rev 1)

**description**: A string description of the parameter.(rev 1)

**sensitive**: A Boolean value to identify data as sensitive. Values are masked when they appear in logs and API responses.(rev 1)

## Task implementations

The implementations property is used to describe different implementations for differet targets. The value is an array of implementation options objects. For each target the task is run on the Task Runner must compare the required features of the target to it's list of available features on that target and execute the first implementation where all requirements are statisfied.

### Options

**name**: The file name of the task file that contains the implementation of the task. This must be at the top level of the tasks directory of the module. In order to remain compatible with runners implementing revision 1, task names should be unique. For example, consider the task `foo` with implementations in bash and powershell. Instead of naming the executables `foo.sh` and `foo.ps1` build unique names by including extension information in the base filename: `foo_sh.sh` `foo_ps1.ps1`.(rev 2)

**requirements**: A list of features the target is required to support for the implementation to be used. `shell`, `powershell` and `puppet-agent` features are added by the ssh, winrm, and pcp transports respectively.(rev 2)

**input_method**: The input method to use for this implementation of the task. Default empty `[]` which will make this implementation suitable for all targets.(rev 3)

**files**: files required by this implementation. These will be concatenated with the files array from the top level of the tasks, metadata.(rev 3)

**remote**: This implementation is remote. Set remote on specific implementations if the task supports both normal and remote execution.(rev 4)

### Metaparameters

In addition to the tasks parameters, the task runner may inject metaparameters prefixed by `_`.

**_noop**: Used to implement logic in tasks to support cases where task should not perform certain actions.(rev 1)

**_task**: Allow multiple task implementations to access the same executable file. The `_task` metaparameter provides the executable the task name to allow task specific logic to be implemented.(rev 2)

**_installdir**: Tasks with `files` specified in the metadata will be passed the `_installdir` metaparameter to provide the file path to the expected resources.(rev 3)

**_target**: Connection information for connecting to the real target when the task is running on a proxy.

#### Metaparameter Examples

When the task runner runs a task with `files` metadata it copies the specified files into a temporary directory on the target. The directory structure of the specified file resources will be preserved such that paths specified with the `files` metadata option will be available to tasks prefixed with `_installdir`.

The task executable itself will be located within the `_installdir` at its normal module location, such as `_installdir/mymodule/tasks/init`. This allows writing tasks that can be tested locally from source by requiring dependencies by relative path.

##### Python Example
###### Metadata
```json
{
  "files": ["multi_task/files/py_helper.py"]
}
```
###### File Resource
`multi_task/files/py_helper.py`
```python
def useful_python():
  return dict(helper="python")
```
###### Task
```python
#!/usr/bin/env python
import sys
import os
import json

params = json.load(sys.stdin)
sys.path.append(os.path.join(params['_installdir'], 'multi_task', 'files'))
# Alternatively use relative path
# sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'multi_task', 'files'))
import py_helper

print(json.dumps(py_helper.useful_python()))
```
###### Output
```
Started on localhost...
Finished on localhost:
  {
    "helper": "python"
  }
Successful on 1 node: localhost
Ran on 1 node in 0.12 seconds
```
##### Ruby Example
###### Metadata
```json
{
  "files": ["multi_task/files/rb_helper.rb"]
}
```
###### File Resource
`multi_task/files/rb_helper.rb`
```ruby
def useful_ruby
  { helper: "ruby" }
end
```
###### Task
```ruby
#!/usr/bin/env ruby
require 'json'

params = JSON.parse(STDIN.read)
require_relative File.join(params['_installdir'], 'multi_task', 'files', 'rb_helper.rb')
# Alternatively use relative path
# require_relative File.join(__dir__, '..', '..', 'multi_task', 'files', 'rb_helper.rb')

puts useful_ruby.to_json
```
###### Output
```
Started on localhost...
Finished on localhost:
  {
    "helper": "ruby"
  }
Successful on 1 node: localhost
Ran on 1 node in 0.12 seconds
```
## Task execution

If the task has multiple implementation files, the `implementations` field of the metadata is used to determine which implementation is suitable for the target. Each implementation can specify `requirements`, which is an array of the required "features" to use that implementation.

If the task has a single implementation file and doesn't use the `implementations` field, that implementation will be used on every target.

The task implementation is copied to the target and then executed on the target by the task runner.

If `files` metadata has been provided those executable resources will be copied to the target and made available to the task via the `_installdir` metaparameter.

No arguments are passed to the task when it is executed.

The task file in the module does not need execute permissions set.

The location of the task file on the target varies based on the transport used by the task runner. Task authors have no control over this path.

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
- **_output**: A text summary of the job result. If the job does not return a JSON object the contents of stdout will be put in this key.(rev 1)
- **_error**: Tasks can set this when they fail and the UI can more gracefully display messages from it.(rev 1)

### Stderr

Stderr may be captured by the task runner.

In the initial release it may be temporarily stored on the target but not exposed through the task runner API. This behavior may change in future iterations of the task runner.

### Exitcode

The exitcode of the task is captured and exposed by the task runner.

An exitcode of 0 is considered success by the task runner unless the task result contains an `_error` key. Any non-zero exit code or a result containing an `_error` is considered a failure.

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

## Executing Remote Tasks(rev 4)

Tasks may be written to execute on a proxy target and interact remotely with
the specified target. This is useful when the target has a limited shell
environment or only exposes an API.

- The task runner must accept a hash of connection information for remote
  targets.
- The task runner must add the `_target` metaparam containing a hash of
  connection information before executing the task on the proxy target.
- The task runner should refuse to execute task implementations that do not have
  `remote` set on remote targets.
- The task runner should refuse to execute task implementations that do have
  `remote` set on normal targets.
- The task runner may have a default proxy target for remote targets.
