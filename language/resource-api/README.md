# Puppet Resource API

This libarary provides a simple way to write new native resources for [puppet](https://puppet.com).

A *resource* is the basic thing that is managed by puppet. Each resource has a set of attributes describing its current state. Some of the attributes can be changed throughout the life-time of the resource, some attributes are only reported back, but cannot be changed (see `read_only`) others can only be set once during initial creation (see `init_only`). To gather information about those resources, and to enact changes in the real world, puppet requires a *provider* to implement this interaction. The provider can have parameters that influence its mode of operation (see `parameter`). To describe all these parts to the infrastructure, and the consumers, the resource *type* defines the all the metadata, including the list of the attributes. The *provider* contains the code to *get* and *set* the system state.

# Resource Definition ("Type")

To make the resource known to the puppet ecosystem, its definition ("type") needs to be registered with puppet:

```ruby
Puppet::ResourceApi.register_type(
  name: 'apt_key',
  desc: <<-EOS,
    This type provides Puppet with the capabilities to manage GPG keys needed
    by apt to perform package validation. Apt has it's own GPG keyring that can
    be manipulated through the `apt-key` command.

    apt_key { '6F6B15509CF8E59E6E469F327F438280EF8D349F':
      source => 'http://apt.puppetlabs.com/pubkey.gpg'
    }

    **Autorequires**:
    If Puppet is given the location of a key file which looks like an absolute
    path this type will autorequire that file.
  EOS
  attributes:   {
    ensure:      {
      type: 'Enum[present, absent]',
      desc: 'Whether this apt key should be present or absent on the target system.'
    },
    id:          {
      type:      'Variant[Pattern[/\A(0x)?[0-9a-fA-F]{8}\Z/], Pattern[/\A(0x)?[0-9a-fA-F]{16}\Z/], Pattern[/\A(0x)?[0-9a-fA-F]{40}\Z/]]',
      behaviour: :namevar,
      desc:      'The ID of the key you want to manage.',
    },
    # ...
    created:     {
      type:      'String',
      behaviour: :read_only,
      desc:      'Date the key was created, in ISO format.',
    },
  },
  autorequires: {
    file:    '$source', # will evaluate to the value of the `source` attribute
    package: 'apt',
  },
)
```

The `Puppet::ResourceApi.register_type(options)` function takes the following keyword arguments:

* `name`: the name of the resource type.
* `desc`: a doc string that describes the overall working of the resource type, gives examples, and explains pre-requisites as well as known issues.
* `attributes`: an hash mapping attribute names to their details. Each attribute is described by a hash containing the puppet 4 data `type`, a `desc` string, a `default` value, and the `behaviour` of the attribute: `namevar`, `read_only`, `init_only`, or a `parameter`.
  * `type`: the puppet 4 data type allowed in this attribute.
  * `desc`: a string describing this attribute. This is used in creating the automated API docs with [puppet-strings](https://github.com/puppetlabs/puppet-strings).
  * `default`: a default value that will be used by the runtime environment, whenever the caller doesn't specify a value for this attribute.
  * `behaviour`/`behavior`: how the attribute behaves. Currently available values:
    * `namevar`: marks an attribute as part of the "primary key", or "identity" of the resource. A given set of namevar values needs to distinctively identify a instance.
    * `init_only`: this attribute can only be set during creation of the resource. Its value will be reported going forward, but trying to change it later will lead to an error. For example, the base image for a VM, or the UID of a user.
    * `read_only`: values for this attribute will be returned by `get()`, but `set()` is not able to change them. Values for this should never be specified in a manifest. For example the checksum of a file, or the MAC address of a network interface.
    * `parameter`: these attributes influence how the provider behaves, and cannot be read from the target system. For example, the target file on inifile, or credentials to access an API.
* `autorequires`, `autobefore`, `autosubscribe`, and `autonotify`: a Hash mapping resource types to titles. Currently the titles must either be constants, or, if the value starts with a dollar sign, a reference to the value of an attribute. If the specified resources exist in the catalog, puppet will automatically create the relationsships requested here.
* `features`: a list of API feature names, specifying which optional parts of this spec the provider supports. Currently defined: features: `canonicalize`, `simple_get_filter`, and `noop_handler`. See below for details.

For autoloading to work, this code needs to go into `lib/puppet/type/<name>.rb` in your module.

# Resource Implementation ("Provider")

To effect changes on the real world, a resource also requires an implementation that makes the universe's state available to puppet, and causes the changes to bring reality to whatever state is requested in the catalog. The two fundamental operations to manage resources are reading and writing system state. These operations are implemented as `get` and `set`. The implementation itself is a basic Ruby class in the `Puppet::Provider` namespace, named after the Type using CamelCase.

At runtime the current and intended system states for a specific resource are always represented as ruby Hashes of the resource's attributes, and applicable operational parameters.

```ruby
class Puppet::Provider::AptKey
  def get(context)
    [
      {
        name: 'name',
        ensure: 'present',
        created: '2017-01-01',
        # ...
      },
      # ...
    ]
  end

  def set(context, changes)
    changes.each do |name, change|
      is = change.has_key? :is ? change[:is] : get_single(name)
      should = change[:should]
      # ...
    end
  end
end
```

The `get` method reports the current state of the managed resources. It returns an Enumerable of all existing resources. Each resource is a Hash with attribute names as keys, and their respective values as values. It is an error to return values not matching the type specified in the resource type. If a requested resource is not listed in the result, it is considered to not exist on the system. If the `get` method raises an exception, the provider is marked as unavailable during the current run, and all resources of this type will fail in the current transaction. The exception's message will be reported to the user.

The `set` method updates resources to a new state. The `changes` parameter gets passed an a hash of change requests, keyed by the resource's name. Each value is another hash with the optional `:is` and `:should` keys. At least one of the two has to be specified. The values will be of the same shape as those returned by `get`. After the `set`, all resources should be in the state defined by the `:should` values. As a special case, a missing `:should` entry indicates that a resource should be removed from the system. Even a type implementing the `ensure => [present, absent]` attribute pattern for its human consumers, still has to react correctly on a missing `:should` entry. For convenience, and performance, `:is` may contain the last available system state from a prior `get` call. If the `:is` value is `nil`, the resources was not found by `get`. If there is no `:is` key, the runtime did not have a cached state available.  The `set` method should always return `nil`. Any progress signaling should be done through the logging utilities described below. Should the `set` method throw an exception, all resources that should change in this call, and haven't already been marked with a definite state, will be marked as failed. The runtime will only call the `set` method if there are changes to be made. Especially in the case of resources marked with `noop => true` (either locally, or through a global flag), the runtime will not pass them to `set`. See `noop_handler` below for changing this behaviour if required.

Both methods take a `context` parameter which provides utilties from the Runtime Environment, and is decribed in more detail there.

## Provider Features

There are some common cases where an implementation might want to provide a better experience in specific usecases than the default runtime environment can provide. To avoid burdening the simplest providers with that additional complexity, these cases are hidden behind feature flags. To enable the special handling, the Resource Definition has a `feature` key to list all features implemented by the provider.

## Provider Feature: canonicalize

Allows the provider to accept a wide range of formats for values without confusing the user.

```ruby
Puppet::ResourceApi.register_type(
  name: 'apt_key',
  features: [ 'canonicalize' ],
)

class Puppet::Provider::AptKey
  def canonicalize(context, resources)
    resources.each do |r|
      r[:name] = if r[:name].start_with?('0x')
                   r[:name][2..-1].upcase
                 else
                   r[:name].upcase
                 end
    end
  end
```

The runtime environment needs to compare user input from the manifest (the desired state) with values returned from `get` (the actual state) to determine whether or not changes need to be effected. In simple cases, a provider will only accept values from the manifest in the same format as `get` would return. Then no extra work is required, as a trivial value comparison will suffice. In many cases this places a high burden on the user to provide values in an unnaturally constrained format. In the example, the `apt_key` name is a hexadecimal number that can be written with, and without, the `'0x'` prefix, and the casing of the digits is irrelevant. A trivial value comparison on the strings would cause false positives, when the user input format does not match, and there is no Hexadecimal type in the Puppet language. In this case the provider can specify the `canonicalize` feature and implement the `canonicalize` method.

The `canonicalize` method transforms its `resources` argument into the standard format required by the rest of the provider. The `resources` argument to `canonicalize` is an Enumerable of resource hashes matching the structure returned by `get`. It returns all passed values in the same structure, with the required transformations applied. It is free to re-use, or recreate the data structures passed in as arguments. The runtime environment must use `canonicalize` before comparing user input values with values returned from `get`. The runtime environment must always pass canonicalized values into `set`. If the runtime environment must requires the original values for later processing, it must protect itself from modifications to the objects passed into `canonicalize`, for example through creating a deep copy of the objects.

The `context` parameter is the same as passed to `get` and `set` which provides utilties from the Runtime Environment, and is decribed in more detail there.

> Note: When the provider implements canonicalisation, it should strive for always logging canonicalized values. By virtue of `get`, and `set` always producing and consuming canonically formatted values, this is not expected to pose extra overhead.

> Note: A interesting side-effect of these rules is the fact that the canonicalization of `get`'s return value must not change the processed values. Runtime environments may have strict or development modes that check this property.

## Provider Feature: simple_get_filter

Allows for more efficient querying of the system state when only specific bits are required.

```ruby
Puppet::ResourceApi.register_type(
  name: 'apt_key',
  features: [ 'simple_get_filter' ],
)

class Puppet::Provider::AptKey
  def get(context, names = nil)
    [
      {
        name: 'name',
        # ...
      },
    ]
  end
```

Some resources are very expensive to enumerate. In this case the provider can implement `simple_get_filter` to signal extended capabilities of the `get` method to address this. The provider's `get` method will be called with an Array of resource names, or `nil`. The `get` method must at least return the resources mentioned in the `names` Array, but may return more than those. As a special case, if the `names` parameter is `nil`, all existing resources should be returned. The `names` parameter should default to `nil` to allow simple runtimes to ignore this feature.

The runtime environment should call `get` with a minimal set of names it is interested in, and should keep track of additional instances returned, to avoid double querying. To reap the most benefits from batching implementations, the runtime should minimize the number of calls into `get`.

## Provider Feature: noop_handler

```ruby
Puppet::ResourceApi.register_type(
  name: 'apt_key',
  features: [ 'noop_handler' ],
)

class Puppet::Provider::AptKey
  def set(context, changes, noop: false)
    changes.each do |name, change|
      is = change.has_key? :is ? change[:is] : get_single(name)
      should = change[:should]
      # ...
      do_something unless noop
    end
  end
end
```

When a resource is marked with `noop => true`, either locally, or through a global flag, the standard runtime will emit the default change report with a `noop` flag set. In some cases an implementation can provide additional information (e.g. commands that would get executed), or requires additional evaluation before determining the effective changes (e.g. `exec`'s `onlyif` attribute). In those cases, the resource type can specify the `noop_handler` feature to have `set` called for all resources, even those flagged with `noop`. When the `noop` parameter is set to true, the provider must not change the system state, but only report what it would change. The `noop` parameter should default to `false` to allow simple runtimes to ignore this feature.

# Runtime Environment

The primary runtime environment for the provider is the puppet agent, a long-running daemon process. The provider can also be used in the puppet apply command, a one-shot version of the agent, or the puppet resource command, a short-lived CLI process for listing or managing a single resource type. Other callers who want to access the provider will have to emulate those environments. The primary lifecycle of resource managment in each of those tools is the *transaction*, a single set of changes (e.g. a catalog, or a CLI invocation) to work on. In any case the registered block will be surfaced in a clean class which will be instantiated once for each transaction. The provider can define any number of helper methods to support itself. To allow for a transaction to set up the prerequisites for an provider, and use it immediately, the provider is instantiated as late as possible. A transaction will usually call `get` once, and may call `set` any number of times to effect change. The object instance hosting the `get` and `set` methods can be used to cache ephemeral state during execution. The provider should not try to cache state beyond the transaction, to avoid interfering with the agent daemon. In many other cases caching beyond the transaction won't help anyways, as the hosting process will only manage a single transaction.

## Utilities

The runtime environment provides some utilities to make the providers's life easier, and provide a uniform experience for its users.

### Commands

To use CLI commands in a safe and comfortable manner, the Resource API provides a thin wrapper around the excellent [childprocess gem](https://rubygems.org/gems/childprocess) to address the most common use-cases. Through using the library commands and their arguments are never passed through the shell leading to a safer execution environment (no funny parsing), and faster execution times (no extra processes).

#### Creating a Command

To create a re-usable command, create a new instance of `Puppet::ResourceApi::Command` passing in the command. You can either specify a full path, or a bare command name. In the latter case the Command will use the system's `PATH` setting to search for the command. 

```ruby
class Puppet::Provider::AptKey
  def initialize
    @apt_key_cmd = Puppet::ResourceApi::Command.new('/usr/bin/apt-key')
    @gpg_cmd = Puppet::ResourceApi::Command.new('gpg')
  end
```

It is recommended to create the command in the `initialize` function of the provider, and store them in a member named after the command, with the `_cmd` suffix. This makes it easy to re-use common settings throughout the provider.

You can set default environment variables on the `@cmd.environment` Hash, and a default working directory using `@cmd.cwd=`.

#### Running simple commands

The `run(*args)` method takes any number of arguments, and executes the command using them. For example to call `apt-key` to delete a specific key by id:

```ruby
class Puppet::Provider::AptKey
  def set(context, changes, noop: false)
    # ...
    @apt_key_cmd.run(context, 'del', key_id)
```

If the command is not available, a `Puppet::ResourceApi::CommandNotFoundError` will be raised. This can be easily used to fail the resources for a specific run, if the requirements for the provider are not yet met.

The call will only return after the command has finished executing. If the command exits with a exitstatus indicating an error condition (that is non-zero), a `Puppet::ResourceApi::CommandExecutionError` is raised, containing the details of the command, and exit status.

Through the context, the commands are aware of whether noop is in effect or not, and will signal success while skipping the real execution if necessary. Using these methods also causes the provider's actions to be logged at the appropriate levels.

To pass additional environment variables through to the command, pass a hash of them as `environment:`:

```ruby
@apt_key_cmd.run('del', key_id, environment: { 'LC_ALL': 'C' })
```

By default the `stdout` of the command is logged to debug, while the `stderr` is logged to warning.

#### Processing commands

For more involved scenarios, variants of `@cmd.start` take the same arguments as `run`, but will start the command in the background, and return a handle to that process. The different variants have different defaults in how the process is set up. The handle provides functionality to interact with the command, and query its state.

To use a command to read information from the system, `start_read` does not allow input to the process, and its `stderr` is logged at the warning level. The handle's `stdout` attribute can be used to access the normal output of the command through an [`IO`](https://ruby-doc.org/core/IO.html) object. For example, to process the list of all apt keys:

```ruby
class Puppet::Provider::AptKey
  def get(context)
    @apt_key_cmd.start_read(context, 'adv', '--list-keys', '--with-colons', '--fingerprint', '--fixed-list-mode') do |handle|
      handle.stdout.each_line.collect do |line|
        # process each line here, and compute a Hash
      end
    end
  end
```

To use a command to write to, `start_write` allows input into the process, but will only log its output like `run` does. For example, to provide a key on stdin to the apt-key tool:

```ruby
class Puppet::Provider::AptKey
  def set(context, changes)
    # ...
    @apt_key_cmd.start_write(context, 'add', '-') do |handle|
      handle.stdin.puts the_key
    end
  end
```

Like the `run` method, the block forms of `start` will wait after the block has finished processing, to make sure that the command has exited cleanly, and will raise an error if the command returns a non-zero exit code.

#### Advanced scenarios

For advanced scenarios, the plain `start` method returns a handle with the `stdin`, `stdout`, and `stderr` pipes open, and unhandled.

This can be particularily useful together with providing your own `IO` objects, by using the `stdin:`, `stdout:`, and `stderr:` keyword arguments. For example redirecting the output of a command to a temporary file:

```ruby
error_out = Tempfile.new('err')
@apt_key_cmd.start('add', '-', stdin: File.open('/tmp/key_in.gpg'), stdout: nil, stderr: error_out)
```

> Note that due to buffering on the OS level (or lack thereof), bidirectional communication with that command can randomly hang your process, unless you take extra care only using the non-blocking methods on `IO`. Depending on your needs, you can also go straight to the childprocess gem.

The handle also can be used to query whether the process is still running with `alive?`, and `exited?`, access the `exit_code` of the command, `wait` for it to finish, or poll for it to exit using `poll_for_exit(seconds)`, and `stop` the process. All those methods correspond to their respective counterparts on [`ChildProcess::AbstractProcess`](http://www.rubydoc.info/gems/childprocess/ChildProcess/AbstractProcess).

> Note: If you don't provide a block to the `start` methods, you will have to take care of exit code handling yourself.

### Logging and Reporting

The provider needs to signal changes, successes and failures to the runtime environment. The `context` is the primary way to do so. It provides a single interface for both the detailed technical information for later automatic processing, as well as human readable progress and status messages for operators.

#### General messages

To provide feedback about the overall operation of the provider, the `context` has the usual set of [loglevel](https://docs.puppet.com/puppet/latest/metaparameter.html#loglevel) methods that take a string, and pass that up to runtime environment's logging infrastructure:

```ruby
context.warning("Unexpected state detected, continuing in degraded mode.")
```

will result in the following message:

```text
Warning: apt_key: Unexpected state detected, continuing in degraded mode.
```

* debug: detailed messages to understand everything that is happening at runtime; only shown on request
* info: regular progress and status messages; especially useful before long-running operations, or before operations that can fail, to provide context to interactive users
* notice: indicates state changes and other events of notice from the regular operations of the provider
* warning: signals error conditions that do not (yet) prohibit execution of the main part of the provider; for example deprecation warnings, temporary errors
* err: signal error conditions that have caused normal operations to fail
* critical/alert/emerg: should not be used by resource providers

See [wikipedia](https://en.wikipedia.org/wiki/Syslog#Severity_level) and [RFC424](https://tools.ietf.org/html/rfc5424) for more details.

#### Signalling resource status

In many simple cases, a provider can pass off the real work to a external tool, detailed logging happens there, and reporting back to puppet only requires acknowledging those changes. In these situations, signalling can be as easy as this:

```ruby
@apt_key_cmd.run(context, action, key_id)
context.processed(key_id, is, should)
```

This will report all changes from `is` to `should`, using default messages.

Providers that want to have more control over the logging throughout the processing can use the more specific `created(title)`, `updated(title)`, `deleted(title)`, `unchanged(title)` methods for that. To report the change of an attribute, the `context` provides a `attribute_changed(title, attribute, old_value, new_value, message)` method.

#### Logging contexts

Most of those messages are expected to be relative to a specific resource instance, and a specific operation on that instance. To enable detailed logging without repeating key arguments, and provide consistent error logging, the context provides *logging context* methods that capture the current action and resource instance.

```ruby
context.updating(title) do
  if key_not_found
    context.warning('Original key not found')
  end

  # Update the key by calling CLI tool
  apt_key(...)

  context.attribute_changed('content', nil, content_hash,
    message: "Replaced with content hash #{content_hash}")
end
```

will result in the following messages:

```text
Debug: Apt_key[F1D2D2F9]: Started updating
Warning: Apt_key[F1D2D2F9]: Updating: Original key not found
Debug: Apt_key[F1D2D2F9]: Executing 'apt-key ...'
Debug: Apt_key[F1D2D2F9]: Successfully executed 'apt-key ...'
Notice: Apt_key[F1D2D2F9]: Updating content: Replaced with content hash E242ED3B
Notice: Apt_key[F1D2D2F9]: Successfully updated
# TODO: update messages to match current log message formats for resource messages
```

In the case of an exception escaping the block, the error is logged appropriately:

```text
Debug: Apt_keyF1D2D2F9]: Started updating
Warning: Apt_key[F1D2D2F9]: Updating: Original key not found
Error: Apt_key[F1D2D2F9]: Updating failed: Something went wrong
# TODO: update messages to match current log message formats for resource messages
```

Logging contexts process all exceptions. [`StandardError`s](https://ruby-doc.org/core/StandardError.html) are assumed to be regular failures in handling a resources, and they are swallowed after logging. Everything else is assumed to be a fatal application-level issue, and is passed up the stack, ending execution. See the [ruby documentation](https://ruby-doc.org/core/Exception.html) for details on which exceptions are not `StandardError`s.

The equivalent long-hand form with manual error handling:

```ruby
context.updating(title)
begin
  if key_not_found
    context.warning(title, message: 'Original key not found')
  end

  # Update the key by calling CLI tool
  try_apt_key(...)

  if $?.exitstatus != 0
    context.error(title, "Failed executing apt-key #{...}")
  else
    context.attribute_changed(title, 'content', nil, content_hash,
      message: "Replaced with content hash #{content_hash}")
  end
  context.changed(title)
rescue Exception => e
  context.error(title, e, message: 'Updating failed')
  raise unless e.is_a? StandardError
end
```

This example is only for demonstration purposes. In the normal course of operations, providers should always use the utility functions.

#### Logging reference

The following action/context methods are available:

* Context functions
** `creating(titles, message: 'Creating', &block)`
** `updating(titles, message: 'Updating', &block)`
** `deleting(titles, message: 'Deleting', &block)`
** `processing(titles, is, should, message: 'Processing', &block)`
** `failing(titles, message: 'Failing', &block)`: unlikely to be used often, but provided for completeness
** `attribute_changed(attribute, is, should, message: nil)`: default to the title from the context

* Action functions
** `created(titles, message: 'Created')`
** `updated(titles, message: 'Updated')`
** `deleted(titles, message: 'Deleted')`
** `unchanged(titles, message: 'Unchanged')`: the resource did not require a change - emit no logging
** `processed(titles, is, should)`: the resource has been processed - emit default logging for the resource and each attribute
** `failed(titles, message:)`: the resource has not been updated successfully
** `attribute_changed(titles, attribute, is, should, message: nil)`: use outside of a context, or in a context with multiple resources

* `fail(message)`: abort the current context with an error

* Plain messages
** `debug(message)`
** `debug(titles, message:)`
** `info(message)`
** `info(titles, message:)`
** `notice(message)`
** `notice(titles, message:)`
** `warning(message)`
** `warning(titles, message:)`
** `err(message)`
** `err(titles, message:)`

`titles` can be a single identifier for a resource, or an Array of values, if the following block batch-processes multiple resources in one pass. If that processing is not atomic, providers should instead use the non-block forms of logging, and provide accurate status reporting on the individual parts of update operations.

A single `set()` execution may only log messages for instances it has been passed as part of the `changes` to process. Logging for foreign instances will cause an exception, as the runtime environment is not prepared for other resources to change.

The provider is free to call different logging methods for different resources in any order it needs to. The only ordering restriction is for all calls specifying the same `title`. The `attribute_changed` logging needs to be done before that resource's action logging, and if a context is opened, it needs to be opened before any other logging for this resource.

# Known Limitations

This API is not a full replacement for the power of 3.x style types and providers. Here is a (incomplete) list of missing pieces and thoughts on how to go about solving these. In the end, the goal of the new Resource API is not to be a complete replacement of prior art, but a cleaner way to get good results for the majority of simple cases.

## Multiple providers for the same type

The original Puppet Type and Provider API allows multiple providers for the same resource type. This allows the creation of abstract resource types, such as package, which can span multiple operating systems. Automatic selection of an os-appropriate provider means less work for the user, as they don't have to address in their code whether the package needs to be managed using apt, or managed using yum.

Allowing multiple providers doesn't come for free though and in the previous implementation it incurs a number of complexity costs to be shouldered by the type or provider developer.

    attribute sprawl
    disparate feature sets between the different providers for the same abstract type
    complexity in implementation of both the type and provider pieces stemming from the two issues above

The Resource API will not implement support for multiple providers at this time.

Today, should support for multiple providers be highly desirable for a given type, the two options are: 1) use the older, more complex API. 2) implement multiple similar types using the Resource API, and select the platform-appropriate type in Puppet code. For example:

```puppet
define package (
  Ensure $ensure,
  Enum[apt, rpm] $provider, # have a hiera 5 dynamic binding to a function choosing a sensible default for the current system
  Optional[String] $source  = undef,
  Optional[String] $version = undef,
  Optional[Hash] $options   = { },
) {
  case $provider {
    apt: {
      package_apt { $title:
        ensure          => $ensure,
        source          => $source,
        version         => $version,
        *               => $options,
      }
    }
    rpm: {
      package_rpm { $title:
        ensure => $ensure,
        source => $source,
        *      => $options,
      }
      if defined($version) { fail("RPM doesn't support \$version") }
      # ...
    }
  }
}
```

Neither of these options is ideal, thus it is documented as a limitation today. Ideas for the future include forward-porting the status quo through enabling multiple Implementations to register for the same Definition, or allowing Definitions to declare (partial) equivalence to other Definitions (ala "apt::package is a package").

## Composite namevars

The current API does not provide a way to specify composite namevars. [`title_patterns`](https://github.com/puppetlabs/puppet-specifications/blob/master/language/resource_types.md#title-patterns) are already very data driven, and will be easy to add at a later point.

## Puppet 4 data types

Currently anywhere "puppet 4 data types" are mentioned, only the built-in types are usable. This is because the type information is required on the agent, but puppet doesn't make it available yet. This work is tracked in [PUP-7197](https://tickets.puppetlabs.com/browse/PUP-7197). Even once that is implemented, modules will have to wait until the functionality is widely available, before being able to rely on that.

## Catalog access

There is no way to access the catalog from the provider. Several existing types rely on this to implement advanced functionality. Some of those use-cases would be better suited to be implemented as "external" catalog transformations, instead of munging the catalog from within the compilation process.

## Logging for unmanaged instances

The provider could provide log messages for resource instances that were not passed into the `set` call. In the current implementation those will cause an error. How this is handeled in the future might change drastically.

## Sharing code between providers

Providers in the old API share code through inheritance, using the `:parent` key in the `provide()` call. To reduce entanglement between the business end of code, and the required interactions with the Resource API, it is recommended to put shared code in separate classes, that are used directly, instead of inheriting their contents. This can either happen through normal instantiation and usage, or for small chunks of code through a `Module`, and `include`.
