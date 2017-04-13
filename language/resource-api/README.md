# Resource API

A *resource* is the basic thing that is managed by puppet. Each resource has a set of attributes describing its current state. Some of the attributes can be changed throughout the life-time of the resource, some attributes are only reported back, but cannot be changed (see `read_only`) others can only be set once during initial creation (see `init_only`). To gather information about those resources, and to enact changes in the real world, puppet requires a *provider* to implement this interaction. The provider can have parameters that influence its mode of operation (see `parameter`). To describe all these parts to the infrastructure, and the consumers, the resource *type* defines the all the metadata, including the list of the attributes. The *provider* contains the code to *get* and *set* the system state.

# Resource Definition

```ruby
Puppet::ResourceType.register(
    name: 'apt_key',
    docs: <<-EOS,
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
            docs: 'Whether this apt key should be present or absent on the target system.'
        },
        id:          {
            type: 'Variant[Pattern[/\A(0x)?[0-9a-fA-F]{8}\Z/], Pattern[/\A(0x)?[0-9a-fA-F]{16}\Z/], Pattern[/\A(0x)?[0-9a-fA-F]{40}\Z/]]',
            kind: :namevar,
            docs: 'The ID of the key you want to manage.',
        },
        # ...
        created:     {
            type: 'String',
            kind: :read_only,
            docs: 'Date the key was created, in ISO format.',
        },
    },
    autorequires: {
        file:    '$source', # will evaluate to the value of the `source` attribute
        package: 'apt',
    },
)
```

The `Puppet::ResourceType.register(options)` function takes a Hash with the following top-level keys:

* `name`: the name of the resource type. For autoloading to work, the function call needs to go into `lib/puppet/type/<name>.rb`.
* `docs`: a doc string that describes the overall working of the resource type, gives examples, and explains pre-requisites as well as known issues.
* `attributes`: an hash mapping attribute names to their details. Each attribute is described by a hash containing the puppet 4 data `type`, a `docs` string, and the `kind` of the attribute: `namevar`, `read_only`, `init_only`, or a `parameter`.
  * `namevar`: marks an attribute as part of the "primary key", or "identity" of the resource. A given set of namevar values needs to distinctively identify a instance.
  * `init_only`: this attribute can only be set during creation of the resource. Its value will be reported going forward, but trying to change it later will lead to an error. For example, the base image for a VM, or the UID of a user.
  * `read_only`: values for this attribute will be returned by `get()`, but `set()` is not able to change them. Values for this should never be specified in a manifest. For example the checksum of a file, or the MAC address of a network interface.
  * `parameter`: these attributes influence how the provider behaves, and cannot be read from the target system. For example, the target file on inifile, or credentials to access an API.
* `autorequires`, `autobefore`, `autosubscribe`, and `autonotify`: a Hash mapping resource types to titles. Currently the titles must either be constants, or, if the value starts with a dollar sign, a reference to the value of an attribute. If the specified resources exist in the catalog, puppet will automatically create the relationsships requested here.
* `features`: a list of API feature names, specifying which optional parts of this spec the provider supports. Currently defined: features: `canonicalize`, `simple_get_filter`, and `noop_handler`. See below for details.

# Resource Provider

At runtime the current and intended system states for a specific resource are always represented as ruby Hashes of the resource's attributes, and applicable operational parameters.

The two fundamental operations to manage resources are reading and writing system state. These operations are implemented in the `ResourceProvider` as `get` and `set`:

```ruby
Puppet::ResourceProvider.register('apt_key') do
  def get()
    [
      {
        name: 'name',
        # ...
      },
    ]
  end

  def set(changes)
    changes.each do |name, change|
      is = change.has_key? :is ? change[:is] : get_single(name)
      should = change[:should]
      # ...
    end
  end
end
```

The `get` method reports the current state of the managed resources. It is expected to return an Array of resources. Each resource is a Hash with attribute names as keys, and their respective values as values. It is an error to return values not matching the type specified in the resource type. If a requested resource is not listed in the result, it is considered to not exist on the system. If the `get` method raises an exception, the provider is marked as unavailable during the current run, and all resources of this type will fail in the current transaction. The error message will be reported to the user.

The `set` method updates resources to a new state. The `changes` parameter gets passed an a hash of change requests, keyed by the resource's name. Each value is another hash with a `:should` key, and an optional `:is` key. Those values will be of the same shape as those returned by `get`. After the `set`, all resources should be in the state defined by the `:should` values. For convenience, `:is` may contain the last available system state from a prior `get` call. If the `:is` value is `nil`, the resources was not found by `get`. If there is no `:is` key, the runtime did not have a cached state available. The `set` method should always return `nil`. Any progress signaling should be done through the logging utilities described below. Should the `set` method throw an exception, all resources that should change in this call, and haven't already been marked with a definite state, will be marked as failed. The runtime will only call the `set` method if there are changes to be made. Especially in the case of resources marked with `noop => true` (either locally, or through a global flag), the runtime will not pass them to `set`. See `noop_handler` below for changing this behaviour if required.

## Provider Feature: canonicalize

```ruby
Puppet::ResourceType.register(
  name: 'apt_key',
  features: [ 'canonicalize' ],
)

Puppet::ResourceProvider.register('apt_key') do
  def canonicalize(resources)
    resources.collect do |r|
      r[:name] = if r[:name].start_with?('0x')
                   r[:name][2..-1].upcase
                 else
                   r[:name].upcase
                 end
      r
    end
  end
```

The runtime environment requires a provider to always use the same format for values to be able to correctly detect changes, and not produce false positives. In the example, the `apt_key` name is a hexadecimal number that can be written with, and without, the `'0x'` prefix, and the casing of the digits is irrelevant. The implementation has chosen to always use all upper case, and no prefix. To avoid inflicting a unneccessarily strict form on users, the `canonicalize` function transforms all allowed formats into the standard format. The only argument to `canonicalize` is a list of resource hashes matching the structure returned by `get`. The function should transform all values in those hashes into the canonical format returned by get. The runtime environment must use `canonicalize` before comparing user input values with values returned from get. The runtime environment must protect itself from modifications to the object passed in as `resources`, if it requires the original values later in its processing.

> Note: When the provider implements canonicalisation, it should strive for always logging canonicalized values. By virtue of `get`, and `set` always producing and consuming canonically formatted values, this is not expected to pose extra overhead.

> Note: A interesting side-effect of these rules is the fact that the canonicalization of `get`'s return value must not change the processed values. Runtime environments may have strict or development modes that check this property.

## Provider Feature: simple_get_filter

```ruby
Puppet::ResourceType.register(
  name: 'apt_key',
  features: [ 'simple_get_filter' ],
)

Puppet::ResourceProvider.register('apt_key') do
  def get(names = [])
    [
      {
        name: 'name',
        # ...
      },
    ]
  end
```

Some resources are very expensive to enumerate. In this case the provider can implement `simple_get_filter` to signal extended capabilities of the `get` method to address this. The provider's `get` method will be called with an array of resource names, or `nil`. The `get` method must at least return the resources mentioned in the `names` array, but may return more than those. As a special case, if the `names` parameter is `nil`, all existing resources should be returned. To support simple runtimes, the `names` parameter should default to `[]`, to avoid unnecessary work if the runtime does not specify a filter at all.

The runtime environment should call `get` with a minimal set of names it is interested in, and should keep track of additional instances returned, to avoid double querying.

## Provider Feature: noop_handler

```ruby
Puppet::ResourceType.register(
  name: 'apt_key',
  features: [ 'noop_handler' ],
)

Puppet::ResourceProvider.register('apt_key') do
  def set(changes, noop: false)
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

To use CLI commands in a safe and comfortable manner, the provider can use the `commands` method to access shell commands. You can either specify a full path, or a bare command name. In the latter case puppet will use the system's `PATH` setting to search for the command. If the commands are not available, an error will be raised and the resources will fail in this run. The commands are aware of whether noop is in effect or not, and will signal success while skipping the real execution if necessary. Using these methods also causes the provider's actions to be logged at the appropriate levels.

```ruby
Puppet::ResourceImplementation.register('apt_key') do
  commands apt_key: '/usr/bin/apt-key'
  commands gpg: 'gpg'
```

This will create methods called `apt_get`, and `gpg`, which will take CLI arguments in an array, and execute the command directly without any shell processing in a safe environment (clean working directory, clean environment). For example to call `apt-key` to delete a specific key by id:

```ruby
apt_key 'del', key_id
```

To pass additional environment variables through to the command, pass a hash of them as `env:`:

```ruby
apt_key 'del', key_id, env: { 'LC_ALL': 'C' }
```

By default the `stdout` of the command is logged to debug, while the `stderr` is logged to warning. To access the `stdout` in the provider, use the command name with `_lines` appended, and process it through the returned [Enumerable](http://ruby-doc.org/core/Enumerable.html) line-by-line. For example, to process the list of all apt keys:

```ruby
apt_key_lines(%w{adv --list-keys --with-colons --fingerprint --fixed-list-mode}).collect do |line|
  # process each line here, and return a result
end
```

> Note: the output of the command is streamed through the Enumerable. If the implementation requires the exit value of the command before processing, or wants to cache the output, use `to_a` to read the complete stream in one go.

If the command returns a non-zero exit code, an error is signalled to puppet. If this happens during `get`, all managed resources of this type will fail. If this happens during a `set`, all resources that have been scheduled for processing in this call, but not yet have been marked as a success will be marked as failed. To avoid this behaviour, call the `try_` prefix variant. In this (hypothetical) example, `apt-key` signals already deleted keys with an exit code of `1`, which is still OK when the provider is trying to delete the key:

```ruby
try_apt_key 'del', key_id

if [0, 1].contains $?.exitstatus
  # success, or already deleted
else
  # fail
end
```

The exit code is signalled through the ruby standard variable `$?` as a [`Process::Status` object](https://ruby-doc.org/core/Process/Status.html)

<!-- TODO:
  * add a set `run_command` or `execute` methods that provide the same functionality without hardcoding the binary path
  * provide access to all streams of a command - currently skipped due to complexities around nonblocking IO reqs
-->

### Logging and Reporting

The provider needs to signal changes, successes and failures to the runtime environment. The `logger` is the primary way to do so. It provides a single interface for both the detailed technical information ofr later automatic processing, as well as human readable progress and status messages for operators.

#### General messages

To provide feedback about the overall operation of the provider, the logger has the usual set of [loglevel](https://docs.puppet.com/puppet/latest/metaparameter.html#loglevel) methods that take a string, and pass that up to runtime environment's logging infrastructure:

```ruby
logger.warning("Unexpected state detected, continuing in degraded mode.")
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

```
apt_key action, key_id
logger.processed(key_id, is, should)
```

This will report all changes from `is` to `should`, using default messages.

Providers that want to have more control over the logging throughout the processing can use the more specific `created(title)`, `updated(title)`, `deleted(title)`, `unchanged(title)` methods for that. To report the change of an attribute, the `logger` provides a `attribute_changed(title, attribute, old_value, new_value, message)` method.

#### Logging contexts

Most of those messages are expected to be relative to a specific resource instance, and a specific operation on that instance. To enable detailed logging without repeating key arguments, and provide consistent error logging, the logger provides *logging context* methods that capture the current action and resource instance.

```ruby
logger.updating(title) do
  if key_not_found
    logger.warning('Original key not found')
  end

  # Update the key by calling CLI tool
  apt_key(...)

  logger.attribute_changed('content', nil, content_hash,
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
logger.updating(title)
begin
  if key_not_found
    logger.warning(title, message: 'Original key not found')
  end

  # Update the key by calling CLI tool
  try_apt_key(...)

  if $?.exitstatus != 0
    logger.error(title, "Failed executing apt-key #{...}")
  else
    logger.attribute_changed(title, 'content', nil, content_hash,
      message: "Replaced with content hash #{content_hash}")
  end
  logger.changed(title)
rescue Exception => e
  logger.error(title, e, message: 'Updating failed')
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

`titles` can be a single identifier for a resource, or an array of values, if the following block batch-processes multiple resources in one pass. If that processing is not atomic, providers should instead use the non-block forms of logging, and provide accurate status reporting on the individual parts of update operations.

A single `set()` execution may only log messages for instances it has been passed as part of the `changes` to process. Logging for foreign instances will cause an exception, as the runtime environment is not prepared for other resources to change.

The provider is free to call different logging methods for different resources in any order it needs to. The only ordering restriction is for all calls specifying the same `title`. The `attribute_changed` logging needs to be done before that resource's action logging, and if a context is opened, it needs to be opened before any other logging for this resource.

# Known Limitations

This API is not a full replacement for the power of 3.x style types and providers. Here is a (incomplete) list of missing pieces and thoughts on how to go about solving these. In the end, the goal of the new Resource API is not to be a complete replacement of prior art, but a cleaner way to get good results for the majority of simple cases.

## Multiple providers for the same type

The previous version of this API allowed multiple providers for the same resource type. This leads to the following problems:

* attribute sprawl
* missing features
* convoluted implementations

puppet DSL already can address this:

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

## Composite namevars

The current API does not provide a way to specify composite namevars. [`title_patterns`](https://github.com/puppetlabs/puppet-specifications/blob/master/language/resource_types.md#title-patterns) are already very data driven, and will be easy to add at a later point.

## Puppet 4 data types

Currently anywhere "puppet 4 data types" are mentioned, only the built-in types are usable. This is because the type information is required on the agent, but puppet doesn't make it available yet. This work is tracked in [PUP-7197](https://tickets.puppetlabs.com/browse/PUP-7197), but even once that is implemented, modules will have to wait until the functionality is widely available, before being able to rely on that.

## Resources that can't be enumerated

Some resources, like files, cannot (or should not) be completely enumerated each time puppet runs. In some cases, the runtime environment knows that it doesn't require all resource instances. The current API does not provide a way to support those use-cases. An easy way forward would be to add a `find(title)` method that would return data for a single resource instance. A more involved solution my leverage PQL, but would require a much more sophisticated provider implementation. This also interacts with composite namevars.

## Catalog access

There is no way to access the catalog from the provider. Several existing types rely on this to implement advanced functionality. Some of those use-cases would be better suited to be implemented as "external" catalog transformations, instead of munging the catalog from within the compilation process.

## Logging for unmanaged instances

The provider could provide log messages for resource instances that were not passed into the `set` call. In the current implementation those will cause an error. How this is handeled in the future might change drastically.
