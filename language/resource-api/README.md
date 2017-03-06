# Resource API

A *resource* is the basic thing that is managed by puppet. Each resource has a set of attributes describing its current state. Some of the attributes can be changed throughout the life-time of the resource, some attributes only report back, but cannot be changed (see `read_only`) others can only be set once during initial creation (see `init_only`). To gather information about those resources, and to enact changes in the real world, puppet requires a piece of code to *implement* this interaction. The implementation can have parameters that influence its mode of operation (see `parameter`). To describe all these parts to the infrastructure, and the consumers, the resource *Definition* (f.k.a. 'type') contains definitions for all of them. The *Implementation* (f.k.a. 'provider') contains code to *get* and *set* the system state.

# Resource Definition

```ruby
Puppet::ResourceDefinition.register(
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
            type:    'Variant[Pattern[/\A(0x)?[0-9a-fA-F]{8}\Z/], Pattern[/\A(0x)?[0-9a-fA-F]{16}\Z/], Pattern[/\A(0x)?[0-9a-fA-F]{40}\Z/]]',
            docs:    'The ID of the key you want to manage.',
            namevar: true,
        },
        # ...
        created:     {
            type:      'String',
            docs:      'Date the key was created, in ISO format.',
            read_only: true,
        },
    },
    autorequires: {
        file:    '$source', # will evaluate to the value of the `source` attribute
        package: 'apt',
    },
)
```

The `Puppet::ResourceDefinition.register(options)` function takes a Hash with the following top-level keys:

* `name`: the name of the resource. For autoloading to work, the whole function call needs to go into `lib/puppet/type/<name>.rb`.
* `docs`: a doc string that describes the overall working of the type, gives examples, and explains pre-requisites as well as known issues.
* `attributes`: an hash mapping attribute names to their details. Each attribute is described by a hash containing the puppet 4 data `type`, a `docs` string, and whether the attribute is the `namevar`, `read_only`, `init_only`, or a `parameter`.
  * `namevar`: marks an attribute as part of the "primary key", or "identity" of the resource. A given set of namevar values needs to distinctively identify a instance.
  * `init_only`: this attribute can only be set during creation of the resource. Its value will be reported going forward, but trying to change it later will lead to an error. For example, the base image for a VM, or the UID of a user.
  * `read_only`: values for this attribute will be returned by `get()`, but `set()` is not able to change them. Values for this should never be specified in a manifest. For example the checksum of a file, or the MAC address of a network interface.
  * `parameter`: these attributes influence how the implementation behaves, and cannot be read from the target system. For example, the target file on inifile, or credentials to access an API.
* `autorequires`, `autobefore`, `autosubscribe`, and `autonotify`: a Hash mapping resource types to titles. Currently the titles must either be constants, or, if the value starts with a dollar sign, a reference to the value of an attribute.

# Resource Implementation

At runtime the current and intended system states for a single resource instance are always represented as ruby Hashes of the resource's attributes, and applicable operational parameters.

The two fundamental operations to manage resources are reading and writing system state. These operations are implemented in the `ResourceImplementation` as `get` and `set`:

```ruby
Puppet::ResourceImplementation.register('apt_key') do
  def get
    {
      'title': {
        name: 'title',
        # ...
      },
    }
  end

  def set(changes, noop: false)
    changes.each do |title, change|
      current = change.has_key? :current ? change[:current] : get_single(title)
      target = change[:target]
      # ...
    end
  end
end
```

The `get` method returns a Hash of all resources currently available, keyed by their title. If the `get` method raises an exception, the implementation is marked as unavailable during the current run, and all resources of its type will fail. The error message will be reported to the user.

The `set` method updates resources to a new state. The `changes` parameter gets passed an a hash of change requests, keyed by resource title. Each value is another hash with a `:target` key, and an optional `:current` key. Those values will be of the same shape as those returned by `get`. After the `set`, all resources should be in the state defined by the `:target` value. For convenience, `:current` may contain the last available system state from a prior `get` call. If the `:current` value is `nil`, the resources was not found by `get`. If there is no `:current` key, the runtime did not have a cached state available. When `noop` is set to true, the implementation must not change the system state, but only report what it would change. The `set` method should always return `nil`. Any progress signalling should be done through the logging utilities described below. Should the `set` method throw an exception, all resources that should change in this call, and haven't already been marked with a definite state, will be marked as failed.


# Runtime Environment

The primary runtime environment for the implementation is the puppet agent, a long-running daemon process. The implementation can also be used in the puppet apply command, a one-shot version of the agent, or the puppet resource command, a short-lived CLI process for listing or managing a single resource type. Other callers who want to access the implementation will have to emulate those environments. In any case the registered block will be surfaced in a clean class which will be instantiated once for each transaction. The implementation can define any number of helper methods to support itself. To allow for a transaction to set up the prerequisites for an implementation, and use it immediately, the provider is instantiated as late as possible. A transaction will usually call `get` once, and may call set any number of times to effect change. The object instance hosting the `get` and `set` methods can be used to cache ephemeral state during execution. The implementation should not try to cache state beyond the transaction, to avoid interfering with the agent daemon. In many other cases caching beyond the transaction won't help anyways, as the hosting process will only manage a single transaction.

## Utilities

The runtime environment provides some utilities to make the implementation's life easier, and provide a uniform experience for its users.

### Commands

To use CLI commands in a safe and comfortable manner, the implementation can use the `commands` method to access shell commands. You can either use a full path, or a bare command name. In the latter case puppet will use the system PATH setting to search for the command. If the commands are not available, an error will be raised and the resources will fail in this run. The commands are aware of whether noop is in effect or not, and will signal success while skipping the real execution if necessary.

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

By default the stdout of the command is logged to debug, while the stderr is logged to warning. To access the stdout in the implementation, use the command name with `_lines` appended, and process it through the returned [Enumerable](http://ruby-doc.org/core/Enumerable.html) line-by-line. For example, to process the list of all apt keys:

```ruby
apt_key_lines(%w{adv --list-keys --with-colons --fingerprint --fixed-list-mode}).collect do |line|
  # process each line here, and return a result
end
```

> Note: the output of the command is streamed through the Enumerable. If the implementation requires the exit value of the command before processing, or wants to cache the output, use `to_a` to read the complete stream in one go.

If the command returns a non-zero exit code, an error is signalled to puppet. If this happens during `get`, all managed resources of this type will fail. If this happens during a `set`, all resources that have been scheduled for processing in this call, but not yet have been marked as a success will be marked as failed. To avoid this behaviour, call the `try_` prefix variant. In this (hypothetical) example, `apt-key` signals already deleted keys with an exit code of `1`, which is OK when the implementation is trying to delete the key:

```ruby
try_apt_key 'del', key_id

if [0, 1].contains $?.exitstatus
  # success, or already deleted
else
  # fail
end
```

The exit code is signalled through the ruby standard variable `$?` as a [`Process::Status` object](https://ruby-doc.org/core/Process/Status.html)

<!-- TODO: add a set `run_command` or `execute` methods that provide the same functionality without hardcoding the binary path -->

### Logging and Reporting

The implementation needs to signal changes, successes and failures to the runtime environment. The `logger` provides a structured way to do so.

#### General messages

To provide feedback about the overall operation of the implementation, the logger provides the usual set of [loglevel](https://docs.puppet.com/puppet/latest/metaparameter.html#loglevel) methods that take a string, and pass that up to puppet's logging infrastructure:

```ruby
logger.warning("Unexpected state detected, continuing in degraded mode.")
```

will result in the following message:

```text
Warning: apt_key: Unexpected state detected, continuing in degraded mode.
```

* debug: detailed messages to understand everything that is happening at runtime; only shown on request
* info: high level progress messages; especially useful before long-running operations, or before operations that can fail, to provide context to interactive users
* notice: use this loglevel to indicate state changes and similar events of notice from the regular operations of the implementation
* warning: signal error conditions that do not (yet) prohibit execution of the main part of the implementation; for example deprecation warnings, temporary errors.
* err: signal error conditions that have caused normal operations to fail
* critical/alert/emerg: should not be used by resource implementations

See [wikipedia](https://en.wikipedia.org/wiki/Syslog#Severity_level) and [RFC424](https://tools.ietf.org/html/rfc5424) for more details.

#### Logging contexts

Most of an implementation's messages are expected to be relative to a specific resource instance, and a specific operation on that instance. For example, to report the change of an attribute:

```ruby
logger.attribute_changed(title:, attribute:, old_value:, new_value:, message: "Changed #{attribute} from #{old_value.inspect} to #{newvalue.inspect}")
```

To enable detailed logging without repeating key arguments, and provide consistent error logging, the logger provides *logging context* methods that capture the current action and resource instance.

```ruby
logger.updating(title: title) do
  if key_not_found
    logger.warning('Original key not found')
  end

  # Update the key by calling CLI tool
  apt_key(...)

  logger.attribute_changed(
    attribute: 'content',
    old_value: nil,
    new_value: content_hash,
    message: "Created with content hash #{content_hash}")
end
```

will result in the following messages (of course, with the `#{}` sequences replaced by the true values):

```text
Debug: Apt_key[#{title}]: Started updating
Warning: Apt_key[#{title}]: Updating: Original key not found
Debug: Apt_key[#{title}]: Executing 'apt-key ...'
Debug: Apt_key[#{title}]: Successfully executed 'apt-key ...'
Notice: Apt_key[#{title}]: Updating content: Created with content hash #{content_hash}
Notice: Apt_key[#{title}]: Successfully updated
# TODO: update messages to match current log message formats for resource messages
```

In the case of an exception escaping the block, the error is logged appropriately:

```text
Debug: Apt_key[#{title}]: Started updating
Warning: Apt_key[#{title}]: Updating: Original key not found
Error: Apt_key[#{title}]: Updating failed: #{exception message}
# TODO: update messages to match current log message formats for resource messages
```

Logging contexts process all exceptions. [`StandardError`s](https://ruby-doc.org/core/StandardError.html) are assumed to be regular failures in handling a resources, and they are swallowed after logging. Everything else is assumed to be a fatal application-level issue, and is passed up the stack, ending execution. See the [ruby documentation](https://ruby-doc.org/core/Exception.html) for details on which exceptions are not `StandardError`s.

The equivalent long-hand form with manual error handling:

```ruby
logger.updating(title: title)
begin
  if key_not_found
    logger.warning(title: title, message: 'Original key not found')
  end

  # Update the key by calling CLI tool
  try_apt_key(...)

  if $?.exitstatus != 0
    logger.error(title: title, "Failed executing apt-key #{...}")
  else
    logger.attribute_changed(
      title:     title,
      attribute: 'content',
      old_value: nil,
      new_value: content_hash,
      message:   "Created with content hash #{content_hash}")
  end
  logger.changed(title: title)
rescue StandardError => e
  logger.error(title: title, exception: e, message: 'Updating failed')
  raise unless e.is_a? StandardError
end
```

This example is only for demonstration purposes. In the normal course of operations, implementations should always use the utility functions.

#### Logging reference

The following action/context methods are available:

* `creating(title, message: 'Creating', &block)`
* `updating(title, message: 'Updating', &block)`
* `deleting(title, message: 'Deleting', &block)`
* `attribute_changed(title, attribute, old_value:, new_value:, message: nil)`

* `created(title, message: 'Created')`
* `updated(title, message: 'Updated')`
* `deleted(title, message: 'Deleted')`
* `unchanged(title, message: 'Unchanged')`: the resource did not require a change

* `fail(title:, message:)` - abort the current context with an error

# Known Limitations

This API is not a full replacement for the power of 3.x style types and providers. Here is a (incomplete) list of missing pieces and thoughts on how to go about solving these. In the end, the goal of the new Resource API is not to be a complete replacement of prior art, but a cleaner way to get good results for the majority of simple cases.

## Multiple implementations

The previous version of this API allowed multiple implementations for the same resource type. This leads to the following problems:

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

Some resources, like files, cannot (or should not) be completely enumerated each time puppet runs. In some cases, the runtime environment knows that it doesn't require all resource instances. The current API does not provide a way to support those use-cases. An easy way forward would be to add a `find(title)` method that would return data for a single resource instance. A more involved solution my leverage PQL, but would require a much more sophisticated implementation. This also interacts with composite namevars.

## Catalog access

There is no way to access the catalog from the implementation. Several existing types rely on this to implement advanced functionality. Some of those use-cases would be better suited to be implemented as "external" catalog transformations, instead of munging the catalog from within the compilation process.

## Logging for unmanaged instances

The implementation could provide log messages for resource instances that were not passed into the `set` call. In the current implementation those will be reported to the log, but will not cause the same resource-based reporting as a managed resource. How this is handeled in the future might change drastically.


# Earlier notes

## Draft for new type and provider API

The type and provider API has been the bane of my existence since I [started writing native resources](https://github.com/DavidS/puppet-mysql-old/commit/d33c7aa10e3a4bd9e97e947c471ee3ed36e9d1e2). Now, finally, we'll do something about it. I'm currently working on designing a nicer API for types and providers. My primary goals are to provide a smooth and simple ruby developer experience for both scripters and coders. Secondary goals were to eliminate server side code, and make puppet 4 data types available. Currently this is completely aspirational (i.e. no real code has been written), but early private feedback was encouraging.

To showcase my vision, this [gist](https://gist.github.com/DavidS/430330ae43ba4b51fe34bd27ddbe4bc7) has the [apt_key type](https://github.com/puppetlabs/puppetlabs-apt/blob/master/lib/puppet/type/apt_key.rb) and [provider](https://github.com/puppetlabs/puppetlabs-apt/blob/master/lib/puppet/provider/apt_key/apt_key.rb) ported over to my proposal. The second example there is a more long-term teaser on what would become possible with such an API.

The new API, like the existing, has two parts: the implementation that interacts with the actual resources, a.k.a. the provider, and information about what the implementation is all about. Due to the different usage patterns of the two parts, they need to be passed to puppet in two different calls:

The `Puppet::SimpleResource.implement()` call receives the `current_state = get()` and `set(current_state, target_state, noop)` methods. `get` returns a list of discovered resources, while `set` takes the target state and enforces those goals on the subject. There is only a single (ruby) object throughout an agent run, that can easily do caching and what ever else is required for a good functioning of the provider. The state descriptions passed around are simple lists of key/value hashes describing resources. This will allow the implementation wide latitude in how to organise itself for simplicity and efficiency.  

The `Puppet::SimpleResource.define()` call provides a data-only description of the Type. This is all that is needed on the server side to compile a manifest. Thanks to puppet 4 data type checking, this will already be much more strict (with less effort) than possible with the current APIs, while providing more automatically readable documentation about the meaning of the attributes.


Details in no particular order:

* All of this should fit on any unmodified puppet4 installation. It is completely additive and optional. Currently.

* The Type definition
  * It is data-only.
  * Refers to puppet data types.
  * No code runs on the server.
  * This information can be re-used in all tooling around displaying/working with types (e.g. puppet-strings, console, ENC, etc.).
  * autorelations are restricted to unmodified attribute values and constant values.
  * No more `validate` or `munge`! For the edge cases not covered by data types, runtime checking can happen in the implementation on the agent. There it can use local system state (e.g. different mysql versions have different max table length constraints), and it will only fail the part of the resource tree, that is dependent on this error. There is already ample precedent for runtime validation, as most remote resources do not try to replicate the validation their target is already doing anyways.
  * It maps 1:1 to the capabilities of PCore, and is similar to the libral interface description (see [libral#1](https://github.com/puppetlabs/libral/pull/2)). This ensures future interoperability between the different parts of the ecosystem.
  * Related types can share common attributes by sharing/merging the attribute hashes.
  * `defaults`, `read_only`, and similar data about attributes in the definition are mostly aesthetic at the current point in time, but will make for better documentation, and allow more intelligence built on top of this later.

* The implementation are two simple functions `current_state = get()`, and `set(current_state, target_state, noop)`.
  * `get` on its own is already useful for many things, like puppet resource.
  * `set` receives the current state from `get`. While this is necessary for proper operation, there is a certain race condition there, if the system state changes between the calls. This is no different than what current implementations face, and they are well-equipped to deal with this.
  * `set` is called with a list of resources, and can do batching if it is beneficial. This is not yet supported by the agent.
  * the `current_state` and `target_state` values are lists of simple data structures built up of primitives like strings, numbers, hashes and arrays. They match the schema defined in the type.
  * Calling `r.set(r.get, r.get)` would ensure the current state. This should run without any changes, proving the idempotency of the implementation.
  * The ruby instance hosting the `get` and `set` functions is only alive for the duration of an agent transaction. An implementation can provide a `initialize` method to read credentials from the system, and setup other things as required. The single instance is used for all instances of the resource.
  * There is no direct dependency on puppet core libraries in the implementation.
    * While implementations can use utility functions, they are completely optional.
    * The dependencies on the `logger`, `commands`, and similar utilities can be supplied by a small utility library (TBD).

* Having a well-defined small API makes remoting, stacking, proxying, batching, interactive use, and other shenanigans possible, which will make for a interesting time ahead.

* The logging of updates to the transaction is only a sketch. See the usage of `logger` throughout the example. I've tried different styles for fit.
  * the `logger` is the primary way of reporting back information to the log, and the report.
  * results can be streamed for immediate feedback
  * block-based constructs allow detailed logging with little code ("Started X", "X: Doing Something", "X: Success|Failure", with one or two calls, and only one reference to X)

* Obviously this is not sufficient to cover everything existing types and providers are able to do. For the first iteration we are choosing simplicity over functionality.
  * Generating more resource instances for the catalog during compilation (e.g. file#recurse or concat) becomes impossible with a pure data-driven Type. There is still space in the API to add server-side code.
  * Some resources (e.g. file, ssh_authorized_keys, concat) cannot or should not be prefetched. While it might not be convenient, a provider could always return nothing on the `get()` and do a more customized enforce motion in the `set()`.
  * With current puppet versions, only "native" data types will be supported, as type aliases do not get pluginsynced. Yet.
  * With current puppet versions, `puppet resource` can't load the data types, and therefore will not be able to take full advantage of this. Yet.

* There is some "convenient" infrastructure (e.g. parsedfile) that needs porting over to this model.

* Testing becomes possible on a completely new level. The test library can know how data is transformed outside the API, and - using the shape of the type - start generating test cases, and checking the actions of the implementation. This will require developer help to isolate the implementation from real systems, but it should go a long way towards reducing the tedium in writing tests.


What do you think about this?


Cheers, David
