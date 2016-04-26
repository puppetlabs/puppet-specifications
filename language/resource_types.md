# Puppet Resource Types

This document describes puppet's Ruby DSL for defining resource types, aka [custom types](https://docs.puppet.com/guides/custom_types.html#types). Examples are taken from the `puppetlabs-aws` module and core puppet.

The second part of the document describes issues that cause puppet resource types to leak across environments (lack of environment isolation).

## Puppet::Type.newtype method

Defines a new puppet resource type and registers the type using the specified symbolic name. For example, to define a resource type named `ec2_instance`: 

```ruby
Puppet::Type.newtype(:ec2_instance) do
  # definition goes here
end
```

The `newtype` method creates a new class `Puppet::Type::Ec2_instance`, which subclasses `Puppet::Type`. The block passed to the `newtype` method defines methods and variables on the `Puppet::Type::Ec2_instance` class.

## Puppet::Type.type method

Defines a method for retrieving the class for a resource type, for example, when writing a provider for the `ec2_instance` type:

```ruby
Puppet::Type.type(:ec2_instance).provide(:v2, ...) do
  # provider definition
end
```

## Puppet::Type::&lt;name&gt; methods

Within the `Puppet::Type.newtype` block, the following DSL methods are often called, and are evaluated in the context of the  `Puppet::Type::<name>` class:

### doc string

Defines the documentation string for the type, which is output when running `puppet describe <type>`. The doc string is usually set via the `Puppet::Type` class variable, though there is also a `Puppet::Type.doc=` class method.

```ruby
Puppet::Type.newtype(:ec2_instance) do
  @doc = 'A type representing an AWS VPC'
end
```

### namevar

The type must specify a parameter to uniquely identify the resource. Conceptually this is referred to as the namevar. The type can specify multiple namevar parameters, which is referred to a composite namevar. For example, the identity of a `package` resource is based on the name of the package and provider, because you can have different types of packages with the same name, e.g. rpm and gem.

Puppet will implicitly treat any parameter named `name` as a namevar. A parameter can explicitly specify that it is a namevar, described in the Parameter & Properties section below.

### title patterns

Provides a way for setting attributes from the title. For example, the `file` resource sets its `path` namevar based on its `title`, stripping trailing slashes in the process. So if `title` is `/foo/bar//`, then `path` will be `/foo/bar`.

```ruby
Puppet::Type.newtype(:file) do
  def self.title_patterns
    [ [ /^(.*?)\/*\Z/m, [ [ :path ] ] ] ]
  end
end
```

A type must define a `title_patterns` method when using composite namevars so that puppet knows how to decompose the `title` into its constituent namevars, e.g. see [java-ks](https://github.com/puppetlabs/puppetlabs-java_ks/blob/abac95473a505080f60b4d0118c82d3568063da0/lib/puppet/type/java_ks.rb#L150-L176), [websphere](https://github.com/puppetlabs/puppetlabs-websphere_application_server/blob/cd2dbc59c43030db36a81f9c1ed155d5fbe4e85c/lib/puppet/type/websphere_sdk.rb#L11-L28).

### ensureable

Creates an `ensure` property with acceptable values of `present` and `absent`, each of which invoke the provider's `create` and `destroy` methods, respectively:

```ruby
Puppet::Type.newtype(:ec2_instance) do
  ensurable
end
```

Ensurable can also take a block, and in that case, the type should define the allowed set of values. For example, the `package` type defines allowed values as:

```ruby
Puppet::Type.newtype(:package) do
  ensurable do
    newvalue(:present)
    newvalue(:absent)
    newvalue(:purged)
    newvalue(:held)
    newvalue(:latest)
    newvalue(/./)
  end
end
```

### newproperty

Defines a new property for a type. Puppet will ensure the resource's current state (as retrieved by the provider) matches the property's desired state (as expressed in the manifest).

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newproperty(:region) do
  end
end
```

### newparam

Defines a new parameter for the type. Puppet does not enforce state for a parameter. Instead parameters specify additional information about how the provider should ensure the resource and its properties are in the correct state.

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newparam(:user_data) do
  end
end
```

### newmetaparam

Defines a new metaparameter for a type. Puppet has several built-in metaparameters described below. It is uncommon for types to define new metaparams as these generally require puppet core changes to be useful, e.g. `noop`, `tag`, `schedule`, etc.

### validate

Performs per-resource validation at catalog application time. This method is often used to validate related parameters and properties for a single resource, e.g. mutually exclusive properties or if one property requires another. One concrete example is the `file` resource requires the `source` parameter to be set if the `recurse` parameter is set to `remote`:

```ruby
Puppet::Type.newtype(:file) do
  validate do
    self.fail "You cannot specify a remote recursion without a source" if !self[:source] && self[:recurse] == :remote
  end
end
```

### autorelations

Allows a type to define automatic relationships (`before`, `subscribe`, `require`, `notify`) between each instance of the type and instances of a different type. For example, the `exec` type will autorequire any file resource whose `path` matches the exec  `command`. Note the relationship will only be added to the catalog if puppet is managing both ends of the relationship. That way puppet will automatically create the file containing the command to execute, before trying to executing it, regardless of manifest order.

```ruby
autorequire(:file) do
  reqs = []
  self[:command].scan(file_regex) { |str|
    reqs << str
  }
  reqs
end
```

Autorequires are by far the most common, though recently puppet added support for `autobefore`, `autonotify`, and `autosubscribe`.

### pre_run_check

The agent will call the `pre_run_check` method for each `Puppet::Type` instance in the agent's catalog. This provides an opportunity for a resource to perform consistency checks/validation against other resources in the catalog. It differs from the `validate` method, since it is called later during catalog application, and can rely on the catalog having all generated resources.

### provider features

Defines a feature for the type, which allows puppet to perform additional validation on the agent at catalog application time based on the selected provider. For example the `service` type defines an `enableable` feature:

```ruby
Puppet::Type.newtype(:service) do
  feature :enableable
end
```

And the type specifies that the `enable` property can only be managed if the selected provider supports the `enableable` feature. This validation check is performed at catalog application time, once the provider has been resolved on the agent.

```ruby
Puppet::Type.newtype(:service) do
  newproperty(:enable, :required_features => :enableable) do
  end
end
```

An array of features can also be specified, e.g.

```ruby
  newproperty(:enable, :required_features => [:green, :blue]) do
  end
```

A **provider** indicates it supports the feature using `has_feature`:

```ruby
Puppet::Type.type(:service).provide :launchd, :parent => :base do
  has_feature :enableable
end
```

A type can also restrict allowed parameter/property values based on provider features. For example, the `enable` property can only be set to `mask` if the provider is `maskable`:

```ruby
Puppet::Type.newtype(:service) do
  feature :maskable

  newproperty(:enable, :required_features => :enableable) do
    ...
    newvalue(:mask, :event => :service_disabled, :required_features => :maskable) do
      provider.mask
    end
  end
end
```

### mixins

Since puppet resource types are defined in ruby, you can mixin additional functionality. The AWS module uses this to create subclasses for different types of Route53 DNS records:

```ruby
Puppet::Type.newtype(:route53_a_record) do
  extend PuppetX::Puppetlabs::Route53Record
  @doc = 'Type representing a Route53 DNS record.'
  create_properties_and_params()
end
```

where the base module defines common parameters and properties for all `Route53Records`:

```ruby
module PuppetX
  module Puppetlabs
    module Route53Record
      def create_properties_and_params
        ensurable
        newproperty(:zone) do
        end
      end
    end
  end
end
```

## Parameter & Property DSL Methods

The following DSL methods are commonly used for individual parameters and properties within the body of `newparam` and `newproperty` respectively:

### desc

Description of the property, output when running `puppet describe <type>`:

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newproperty(:region) do
    desc 'The region in which to launch the instance.'
  end
end
```

### isnamevar

Specifies that the parameter is the `namevar` (aka identity) for the resource:

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newparam(:name) do
    isnamevar
  end
end
```

As mentioned earlier, if a type specifies a parameter named `:name`, it will automatically be the namevar, so the call to `isnamevar` is redundant, but is explicit.

Alternatively, you can pass an option when calling newparam:

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newparam(:name, :namevar => true) do
  end
end
```

Note that the namevar is necessarily a parameter, and not a property, since changing the name identifies a different resource as opposed to changing the name of an existing resource.

Defining a parameter as the namevar also means it is required. Normally the namevar is automatically set to be the same as the title, unless the type overrides the `title_patterns` method, e.g. for composite namevars.

### validate

Validates an individual parameter value at catalog application time. The value to validate is yielded to the block:

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newproperty(:region) do
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end
end
```

Puppet parameter and properties can be multi-valued. For example, the `ec2_instance` can be given a list of `security_groups`, and each value in the list will be yielded to the `validate` method:

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newproperty(:security_groups, ...) do
    validate do |value|
      fail 'security_groups should be ...' if value !~ /something/
    end
  end
end
```

### munge

Normalizes the desired (aka `should`) property value at catalog application time. Puppet will compare the normalized value against the `current` value the provider returns to determine if the property is insync or not. There is also an `unmunge` method, less commonly used. For example, the `ec2_autoscalinggroup` defines a minimum number of instances in the group, where the value is munged from a string to an integer:

```ruby
Puppet::Type.newtype(:ec2_autoscalinggroup) do
  newproperty(:min_size) do
    munge do |value|
      value.to_i
    end
  end
end
```

Often times the logic for validation and munging is the same, e.g. try to convert a value into an integer. As a result, the `validate` logic is omitted, and validation is performed during `munge`.

### newvalue

Defines an enumeration of values for a parameter or property. For example the `ec2_instance` type uses the plural form `newvalues` to define an enumeration of `instance_initiated_shutdown_behavior` values:

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newparam(:instance_initiated_shutdown_behavior) do
    desc 'Whether the instance stops or terminates when you initiate shutdown from the instance.'
    newvalues(:stop, :terminate)
  end
end
```

The singular form `newvalue` defines one possible value and takes a block. At catalog application time, if puppet determines the property is not insync, it will call the block to "sync" that resource's property. It's common to define multiple `newvalue` blocks, where each value's block calls an appropriate provider method.

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newproperty(:ensure) do
    newvalue(:running) do
      provider.create unless provider.running?
    end
    newvalue(:stopped) do
      provider.stop unless provider.stopped?
    end
  end
end
```

The `newvalue` and `newvalues` methods can also be passed a regex. Puppet will compare explicit symbols/strings first, and if there are no matches, compare regex's. For example, the `package` type defines:

```ruby
Puppet::Type.newtype(:package) do
  newproperty(:ensure) do
    newvalue(:present)
    newvalue(:absent)
    ...
    newvalue(/./)
  end
end
```

The last regex is used to match version strings, e.g `ensure => '1.2.3'`

### aliasvalue

Aliases a value to be the same as an existing value. For example, the package type aliases `installed` to be the same as `present`, because it's more natural to declare that a package is `installed`:

```
Puppet::Type.newtype(:ec2_instance) do
  newproperty(:ensure) do
    newvalue(:present)
    aliasvalue(:installed, :present)
  end
end
```

### defaultto

Defines the default value for a parameter. If a value is specified, then `defaultto` creates a `default` method with a block that always returns the specified value.

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newparam(:instance_initiated_shutdown_behavior) do
    newvalues(:stop, :terminate)
    defaultto :stop
  end
end
```

If a block is specified, then the block is called to retrieve the default value at catalog application time. For example, the `filebucket` type defines a `server` parameter: 

```ruby
Puppet::Type.newtype(:filebucket) do
  newparam(:server) do
    desc "The server providing the remote filebucket service."
    defaultto { Puppet[:server] }
  end
end
```

The default value of `Puppet[:server]` works for all agents, because the default value is resolved at catalog application time, not compilation time.

### is_to_s/should_to_s/change_to_s

Overrides log messages for a property at catalog application time. Common examples are convert an id to a human readable name, sorting multi-valued attributes, redacting passwords, etc.

```ruby
Puppet::Type.newtype(:user) do
  newproperty(:password) do
    def is_to_s(currentvalue)
      return '[old password hash redacted]'
    end
  end
end
```

## Parameter/Property Options

The following options are passed to the `newparam` and `newproperty` methods to modify their behavior. These are largely hacks because puppet's predefined parameter/properties types are not well-specified or complete. For example, there isn't a `Puppet::Parameter::Integer` class.

### array_matching

By default, if multiple desired (aka `should`) values are specified in a manifest, puppet will make sure the current (aka `is`) value matches at least one of the desired values. Alternatively, you can specify `array_matching => all`, and puppet will ensure that the array of current values match the desired values.

By default, the `insync?` comparison is sensitive to order and duplicate values, so sometimes a type will override the `insync?` method. For example, security groups are compared set-wise, which ignores duplicates.

```ruby
Puppet::Type.newtype(:ec2_instance) do
  newproperty(:security_groups, :array_matching => :all) do
    desc 'The security groups to associate the instance.'
    def insync?(is)
      is.to_set == should.to_set
    end
  end
end
```

### parent

Specifies a parent class that the newly defined property/parameter should extend. For example, the `ec2_instance` type defines a `tags` property that inherits from the `PuppetX::Property::AwsTag` class:

```ruby
require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_instance) do
  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the instance.'
  end
end
```

The `PuppetX::Property::AwsTag` class is defined in helper code, so the type must require it using a relative path. The helper code defines logic for validating aws tags and how log messages are written:

```ruby
module PuppetX
  module Property
    class AwsTag < Puppet::Property

      def format_tags(value)
        Hash[value.sort]
      end

      [:should_to_s, :is_to_s].each { |method|
        alias_method method, :format_tags
      }

      validate do |value|
        fail 'tags should be a Hash' unless value.is_a?(Hash)
      end
    end
  end
end
```

###  boolean

Meta-programs a predicate method for the parameter/property. For example, the file type defines a `force` parameter:

```ruby
newparam(:force, :boolean => true, :parent => Puppet::Parameter::Boolean) do
end
```

which defines a `Puppet::Type::File#force?` method. It's not clear who calls this method, but the pattern of specifying both `:boolean => true, :parent => Puppet::Parameter::Boolean` is copy/pasted everywhere.

```ruby
irb(main):008:0> Puppet::Type.type(:file).new(:path => '/tmp/foo', :force => true).force?
=> true
```

# Environment Isolation Issues

When the master compiles a catalog for the first time, it loads puppet resource types from that request's environment-specific modulepath. If the master then compiles a catalog using a different environment, it will use whatever type information was loaded from the previous environment. We refer to this as puppet types leaking across environments.

In the future, we want to isolate types within an environment, so that you can deploy different module versions in different environments, e.g. dev, qa, prod, but still get consistent results in any given environment.

This section describes issues with the way puppet resource types are defined and loaded, which prevent environment isolation.

1. The main issue is that the `Puppet::Type.newtype` method defines a class that is global in the ruby runtime. So you can't have two different versions of the type in the same ruby runtime.

1. Types often require helper code, like the `AwsTag` example, and that has the same issue as above.

1. Types use various tricks to require helper code in order to support when running on the master and when running `puppet apply`. For example:

    ```ruby
    require_relative '../../puppet_x/puppetlabs/property/tag.rb'
    ```
    ```ruby
    require Pathname.new(__FILE__).dirname + '../' + 'puppet_x/puppetlabs/powershell_version'
    ```
    ```ruby
    begin
      require "puppet_x/puppetlabs/registry"
    rescue LoadError => detail
      require Pathname.new(__FILE__).dirname + "../../" + "puppet_x/puppetlabs/registry"
    end
    ```

1. The `Puppet::Type.newtype` method adds a `provider` parameter to the type and **loads all providers for the type**, even when the type is loaded on the master. A comment in the code says it is to [determine the default provider](https://github.com/puppetlabs/puppet/blob/4.4.1/lib/puppet/metatype/manager.rb#L115-L117), but that is no longer true. We only determine the default provider when the type is loaded on the agent, and we resolve provider confines and suitability.

1. The `title_patterns` method is called during **compilation** and causes attribute values to be set on the resource that is serialized in the catalog. For example given `file { '/foo/bar//': ensure => file }`, the catalog will contain:

```json
    {
      "type": "File",
      "title": "/foo/bar//",
      "parameters": {
        "path": "/foo/bar",
        "ensure": "file"
      }
    },
```

There has been confusion over time about exactly what parts of a type are evaluated on the master vs agent. Part of the confusion is because the master will apply multiple settings catalogs for file/directory based-settings, e.g. `ssldir`. This ensures the files exist and have the correct permissions. However, it causes the master's ruby process to behave like an agent, so all of the validate, munge, etc methods for `Puppet::Type::File` are evaluated on the master. Also when the master is running as root, the same applies to the `Puppet::Type::User` and `Puppet::Type::Group` types so that the master can manage permissions for those file/directories. But generally speaking, the master does not call the validate, munge, etc methods.
