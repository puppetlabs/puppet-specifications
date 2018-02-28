# Puppet Resource API

This library provides a simple way to write new native resources for [Puppet](https://puppet.com).

A *resource* is the basic unit that is managed by Puppet. Each resource has a set of attributes describing its current state. Some attributes can be changed throughout the lifetime of the resource, whereas others are only reported back but cannot be changed (see `read_only`), and some can only be set once during initial creation (see `init_only`). To gather information about those resources and to enact changes, Puppet requires a *provider* to implement this interaction. The provider can have parameters that influence its mode of operation (see `parameter`). To describe all these parts to the infrastructure and the consumers, the resource *type* defines all the metadata, including the list of the attributes. The *provider* contains the code to *get* and *set* the system state.

## Resource definition ("type")

To make the resource known to the Puppet ecosystem, its definition ("type") needs to be registered with Puppet:

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
  autorequire: {
    file:    '$source', # will evaluate to the value of the `source` attribute
    package: 'apt',
  },
)
```

The `Puppet::ResourceApi.register_type(options)` function takes the following keyword arguments:

* `name`: the name of the resource type.
* `desc`: a doc string that describes the overall working of the resource type, provides examples, and explains prerequisites and known issues.
* `attributes`: a hash mapping attribute names to their details. Each attribute is described by a hash containing the Puppet 4 data `type`, a `desc` string, a `default` value, and the `behaviour` of the attribute: `namevar`, `read_only`, `init_only`, or a `parameter`.
  * `type`: the Puppet 4 data type allowed in this attribute.
  * `desc`: a string describing this attribute. This is used in creating the automated API docs with [puppet-strings](https://github.com/puppetlabs/puppet-strings).
  * `default`: a default value that will be used by the runtime environment when the caller does not specify a value for this attribute.
  * `behaviour`/`behavior`: how the attribute behaves. Currently available values:
    * `namevar`: marks an attribute as part of the "primary key" or "identity" of the resource. A given set of `namevar` values needs to distinctively identify an instance.
    * `init_only`: this attribute can only be set during the creation of the resource. Its value will be reported going forward, but trying to change it later will lead to an error. For example, the base image for a VM or the UID of a user.
    * `read_only`: values for this attribute will be returned by `get()`, but `set()` is not able to change them. Values for this should never be specified in a manifest. For example, the checksum of a file or the MAC address of a network interface.
    * `parameter`: these attributes influence how the provider behaves and cannot be read from the target system. For example, the target file on inifile or credentials to access an API.
* `autorequire`, `autobefore`, `autosubscribe`, and `autonotify`: a hash mapping resource types to titles. The titles must either be constants, or, if the value starts with a dollar sign, a reference to the value of an attribute. If the specified resources exist in the catalog, Puppet will create the relationsships requested here.
* `features`: a list of API feature names, specifying which optional parts of this spec the provider supports. Currently defined features: `canonicalize`, `simple_get_filter`, and `supports_noop`. See below for details.

For autoloading work, this code needs to go into `lib/puppet/type/<name>.rb` in your module.

## Resource implementation ("provider")

To affect changes, a resource requires an implementation that makes the universe's state available to Puppet, and causes the changes to bring reality to whatever state is requested in the catalog. The two fundamental operations to manage resources are reading and writing system state. These operations are implemented as `get` and `set`. The implementation itself is a basic Ruby class in the `Puppet::Provider` namespace, named after the type using CamelCase.

> Note: Due to the way Puppet autoload works, this has to be in a file called `puppet/provider/<type_name>/<type_name>.rb`. The class will also have the CamelCased type name twice.

At runtime, the current and intended system states for a specific resource. These are always represented as Ruby hashes of the resource's attributes and applicable operational parameters.

```ruby
class Puppet::Provider::AptKey::AptKey
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

The `get` method reports the current state of the managed resources. It returns an enumerable of all existing resources. Each resource is a hash with attribute names as keys, and their respective values as values. It is an error to return values not matching the type specified in the resource type. If a requested resource is not listed in the result, it is considered to not exist on the system. If the `get` method raises an exception, the provider is marked as unavailable during the current run, and all resources of this type will fail in the current transaction. The exception message will be reported to the user.

The `set` method updates resources to a new state. The `changes` parameter gets passed a hash of change requests, keyed by the resource's name. Each value is another hash with the optional `:is` and `:should` keys. At least one of the two has to be specified. The values will be of the same shape as those returned by `get`. After the `set`, all resources should be in the state defined by the `:should` values.

A missing `:should` entry indicates that a resource should be removed from the system. Even a type implementing the `ensure => [present, absent]` attribute pattern still has to react correctly on a missing `:should` entry. `:is` may contain the last available system state from a prior `get` call. If the `:is` value is `nil`, the resources were not found by `get`. If there is no `:is` key, the runtime did not have a cached state available.

The `set` method should always return `nil`. Any progress signaling should be done through the logging utilities described below. If the `set` method throws an exception, all resources that should change in this call and haven't already been marked with a definite state, will be marked as failed. The runtime will only call the `set` method if there are changes to be made, especially in the case of resources marked with `noop => true` (either locally or through a global flag). The runtime will not pass them to `set`. See `supports_noop` below for changing this behaviour if required.

Both methods take a `context` parameter which provides utilties from the runtime environment, and is decribed in more detail there.

## Provider features

There are some use cases where an implementation provides a better experience than the default runtime environment provides. To avoid burdening the simplest providers with that additional complexity, these cases are hidden behind feature flags. To enable the special handling, the resource definition has a `feature` key to list all features implemented by the provider.

### Provider feature: `canonicalize`

Allows the provider to accept a wide range of formats for values without confusing the user.

```ruby
Puppet::ResourceApi.register_type(
  name: 'apt_key',
  features: [ 'canonicalize' ],
)

class Puppet::Provider::AptKey::AptKey
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

The runtime environment needs to compare user input from the manifest (the desired state) with values returned from `get` (the actual state) to determine whether or not changes need to be affected. In simple cases, a provider will only accept values from the manifest in the same format as `get` returns. No extra work is required, as a value comparison will suffice. This places a high burden on the user to provide values in an unnaturally constrained format. In the example, the `apt_key` name is a hexadecimal number that can be written with, and without, the `'0x'` prefix, and the casing of the digits is irrelevant. A value comparison on the strings would cause false positives if the user input format that does not match. There is no hexadecimal type in the Puppet language. To address this, the provider can specify the `canonicalize` feature and implement the `canonicalize` method.

The `canonicalize` method transforms its `resources` argument into the standard format required by the rest of the provider. The `resources` argument to `canonicalize` is an enumerable of resource hashes matching the structure returned by `get`. It returns all passed values in the same structure with the required transformations applied. It is free to reuse or recreate the data structures passed in as arguments. The runtime environment must use `canonicalize` before comparing user input values with values returned from `get`. The runtime environment always passes canonicalized values into `set`. If the runtime environment requires the original values for later processing, it protects itself from modifications to the objects passed into `canonicalize`, for example through creating a deep copy of the objects.

The `context` parameter is the same passed to `get` and `set`, which provides utilties from the runtime environment, and is decribed in more detail there.

> Note: When the provider implements canonicalization, it aims to always log the canonicalized values. As a result of `get` and `set` producing and consuming canonically formatted values, this is not expected to present extra cost.

> Note: A side effect of these rules is that the canonicalization of `get`'s return value must not change the processed values. Runtime environments may have strict or development modes that check this property.

### Provider feature: `simple_get_filter`

Allows for more efficient querying of the system state when only specific parts are required.

```ruby
Puppet::ResourceApi.register_type(
  name: 'apt_key',
  features: [ 'simple_get_filter' ],
)

class Puppet::Provider::AptKey::AptKey
  def get(context, names = nil)
    [
      {
        name: 'name',
        # ...
      },
    ]
  end
```

Some resources are very expensive to enumerate. The provider can implement `simple_get_filter` to signal extended capabilities of the `get` method to address this. The provider's `get` method will be called with an array of resource names, or `nil`. The `get` method must at least return the resources mentioned in the `names` array, but may return more than those. If the `names` parameter is `nil`, all existing resources should be returned. The `names` parameter defaults to `nil` to allow simple runtimes to ignore this feature.

The runtime environment calls `get` with a minimal set of names, and keeps track of additional instances returned to avoid double querying. To gain the most benefits from batching implementations, the runtime minimizes the number of calls into `get`.

### Provider feature: `supports_noop`

```ruby
Puppet::ResourceApi.register_type(
  name: 'apt_key',
  features: [ 'supports_noop' ],
)

class Puppet::Provider::AptKey::AptKey
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

When a resource is marked with `noop => true`, either locally or through a global flag, the standard runtime will produce the default change report with a `noop` flag set. In some cases, an implementation provides additional information, for example commands that would get executed, or requires additional evaluation before determining the effective changes, for example the `exec`'s `onlyif` attribute. The resource type specifies the `supports_noop` feature to have `set` called for all resources, even those flagged with `noop`. When the `noop` parameter is set to true, the provider must not change the system state, but only report what it would change. The `noop` parameter should default to `false` to allow simple runtimes to ignore this feature.

### Provider feature: `remote_resource`

```ruby
Puppet::ResourceApi.register_type(
  name: 'nx9k_vlan',
  features: [ 'remote_resource' ],
)

require 'puppet/util/network_device/simple/device'
module Puppet::Util::NetworkDevice::Nexus
  class Device < Puppet::Util::NetworkDevice::Simple::Device
    def facts
      # access the device and return facts hash
    end
  end
end

class Puppet::Provider::Nx9k_vlan::Nx9k_vlan
  def set(context, changes, noop: false)
    changes.each do |name, change|
      is = change.has_key? :is ? change[:is] : get_single(name)
      should = change[:should]
      # ...
      context.device.do_something unless noop
    end
  end
end
```

Declaring this feature restricts the resource from being run "locally". It is expected to execute all external interactions through the `context.device` instance. The way that instance is set up is runtime specific. In Puppet, it is configured through the [`device.conf`](https://puppet.com/docs/puppet/5.3/config_file_device.html) file, and only available when running under [`puppet device`](https://puppet.com/docs/puppet/5.3/man/device.html). It is recommended to use `Puppet::Util::NetworkDevice::Simple::Device` as the base class for all devices, which automatically loads a configuration from the local filesystem of the proxy node where it is running on.

## Runtime environment

The primary runtime environment for the provider is the Puppet agent, a long-running daemon process. The provider can also be used in the Puppet apply command, a one-shot version of the agent, or the Puppet resource command, a short-lived command line interface (CLI) process for listing or managing a single resource type. Other callers who want to access the provider will have to imitate these environments.

The primary lifecycle of resource managment in each of these tools is the transaction, a single set of changes, for example a catalog or a CLI invocation. The provider's class will be instantiated once for each transaction. Within that class the provider defines any number of helper methods to support itself. To allow for a transaction to set up the prerequisites for a provider and be used immediately, the provider is instantiated as late as possible. A transaction will usually call `get` once, and may call `set` any number of times to affect change. The object instance hosting the `get` and `set` methods can be used to cache ephemeral state during execution. The provider should not try to cache state outside of its instances. In many cases, such caching won't help as the hosting process will only manage a single transaction. In long-running runtime environments (like the agent) the benefit of the caching needs to be balanced by the cost of the cache at rest, and the lifetime of cache entries, which are only useful when they are longer than the regular `runinterval`.

### Utilities

The runtime environment has some utilities to provide a uniform experience for its users.

#### Logging and reporting

The provider needs to signal changes, successes, and failures to the runtime environment. The `context` is the primary way to do this. It provides a structured logging interface for all provider actions. Using this information the runtime environments can do automatic processing, emit human readable progress information, and provide status messages for operators.

##### General messages

To provide feedback about the overall operation of the provider, the `context` has the usual set of [loglevel](https://docs.puppet.com/puppet/latest/metaparameter.html#loglevel) methods that take a string, and pass that up to the runtime environments logging infrastructure.

```ruby
context.warning("Unexpected state detected, continuing in degraded mode.")
```

results in the following message:

```text
Warning: apt_key: Unexpected state detected, continuing in degraded mode.
```

* debug: detailed messages to understand everything that is happening at runtime; shown on request.
* info: regular progress and status messages; especially useful before long-running operations, or before operations that can fail, to provide context to interactive users.
* notice: indicates state changes and other events of notice from the regular operations of the provider.
* warning: signals error conditions that do not (yet) prohibit execution of the main part of the provider; for example, deprecation warnings, temporary errors.
* err: signal error conditions that have caused normal operations to fail.
* critical/alert/emerg: should not be used by resource providers.

See [RFC424](https://tools.ietf.org/html/rfc5424) for more details.

##### Signalling resource status

In many simple cases, a provider passes off work to an external tool. Detailed logging happens there, and then reports back to Puppet by acknowledging these changes. Signalling can be:

```ruby
@apt_key_cmd.run(context, action, key_id)
context.processed(key_id, is, should)
```

This will report all changes from `is` to `should`, using default messages.

Providers that want to have more control over the logging throughout the processing can use the more specific `created(title)`, `updated(title)`, `deleted(title)`, `unchanged(title)` methods. To report the change of an attribute, the `context` provides a `attribute_changed(title, attribute, old_value, new_value, message)` method.

##### Logging contexts

Most of those messages are expected to be relative to a specific resource instance, and a specific operation on that instance. To enable detailed logging without repeating key arguments, and to provide consistent error logging, the context provides *logging context* methods to capture the current action and resource instance:

```ruby
context.updating(title) do
  if apt_key_not_found(title)
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

Logging contexts process all exceptions. [`StandardError`s](https://ruby-doc.org/core/StandardError.html) are assumed to be regular failures in handling resources, and are consumed after logging. Everything else is assumed to be a fatal application-level issue, and is passed up the stack, ending execution. See the [Ruby documentation](https://ruby-doc.org/core/Exception.html) for details on which exceptions are not a `StandardError`.

The equivalent long-hand form with manual error handling:

```ruby
context.updating(title)
begin
  unless title_got_passed_to_set(title)
    raise Puppet::DevError, 'Managing resource outside of requested set: %{title}')
  end

  if apt_key_not_found(title)
    context.warning('Original key not found')
  end

  # Update the key by calling CLI tool
  result = @apt_key_cmd.run(...)

  if result.exitstatus != 0
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

##### Logging reference

The following action/block methods are available:

* Block functions: these functions provide logging and timing around a provider's core actions. If the the passed `&block` returns, the action is recorded as successful. To signal a failure, the block should raise an exception explaining the problem.
  * `creating(titles, message: 'Creating', &block)`
  * `updating(titles, message: 'Updating', &block)`
  * `deleting(titles, message: 'Deleting', &block)`
  * `processing(title, is, should, message: 'Processing', &block)`: generic processing of a resource, produces default change messages for the difference between `is:` and `should:`.
  * `failing(titles, message: 'Failing', &block)`: unlikely to be used often, but provided for completeness - always records a failure.

* Action functions
  * `created(titles, message: 'Created')`
  * `updated(titles, message: 'Updated')`
  * `deleted(titles, message: 'Deleted')`
  * `processed(title, is, should)`: the resource has been processed - produces default logging for the resource and each attribute
  * `failed(titles, message:)`: the resource has not been updated successfully

* Attribute Change notifications
  * `attribute_changed(title, attribute, is, should, message: nil)`: notify the runtime environment that a specific attribute for a specific resource has changed. `is` and `should` are the original and the new value of the attribute. Either can be `nil`.

* Plain messages
  * `debug(message)`
  * `debug(titles, message:)`
  * `info(message)`
  * `info(titles, message:)`
  * `notice(message)`
  * `notice(titles, message:)`
  * `warning(message)`
  * `warning(titles, message:)`
  * `err(message)`
  * `err(titles, message:)`

`titles` can be a single identifier for a resource or an array of values, if the following block batch processes multiple resources in one pass. If that processing is not atomic, providers should instead use the non-block forms of logging, and provide accurate status reporting on the individual parts of update operations.

A single `set()` execution may only log messages for instances that have been passed, as part of the `changes` to process. Logging for instances not requested to be changed will cause an exception - the runtime environment is not prepared for other resources to change.

The provider is free to call different logging methods for different resources in any order it needs to. The only ordering restriction is for all calls specifying the same `title`. The `attribute_changed` logging needs to be done before that resource's action logging, and if a context is opened, needs to be opened before any other logging for this resource.

## Known limitations

This API is not a full replacement for the power of 3.x style types and providers. Here is an (incomplete) list of missing pieces and thoughts on how to solve these. The goal of the new Resource API is not to be a replacement of the prior one, but to be a simplified way to get results for the majority of use cases.

### Multiple providers for the same type

The original Puppet type and provider API allows multiple providers for the same resource type. This allows the creation of abstract resource types, such as package, which can span multiple operating systems. Automatic selection of an os-appropriate provider means less work for the user, as they don't have to address in their code whether the package needs to be managed using apt or yum.

Allowing multiple providers does not come for free. The previous implementation incurs a number of complexity costs that are shouldered by the type or provider developer.

    attribute sprawl
    disparate feature sets between the different providers for the same abstract type
    complexity in implementation of both the type and provider pieces stemming from the two issues above

The Resource API will not implement support for multiple providers at this time.

Should support for multiple providers be desirable for a given type, the two options are:

1. Use the older, more complex API.
2. Implement multiple similar types using the Resource API, and select the platform-appropriate type in Puppet code. For example:

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

Neither of these options are ideal; and are documented as a limitation. Improvement ideas include forward porting the status quo by enabling multiple implementations to register for the same definition, or allowing definitions to declare (partial) equivalence to other definitions (ala "apt::package is a package").

### Composite namevars

The current API does not provide a way to specify composite namevars - types with multiple namevars. [`title_patterns`](https://github.com/puppetlabs/puppet-specifications/blob/master/language/resource_types.md#title-patterns) are already very data driven, and will be easy to add at a later point.

### Puppet 4 data types

Currently, only built-in Puppet 4 data types are usable. This is because the type information is required on the agent, but Puppet has not made it available yet. This work is tracked in [PUP-7197](https://tickets.puppetlabs.com/browse/PUP-7197). Even once that is implemented, modules will have to wait until the functionality is widely available before being able to rely on it.

### Catalog access

There is no way to access the catalog from the provider. Several existing types rely on this to implement advanced functionality. Some of these use cases would be better off being implemented as "external" catalog transformations, instead of munging the catalog from within the compilation process.

### Logging for unmanaged instances

Previously, the provider could provide log messages for resource instances that were not passed into the `set` call. In the current implementation, these will cause an error.
