Moving Non-Core Types & Providers
=================

## Index

* [Goals](#goals)
* [User Stories](#user-stories)
* [File Path Changes](#file-path-changes)
* [Resource Type Taxonomy](#resource-type-taxonomy)
  * [Internal](#internal)
  * [Core](#core)
  * [External](#external)
  * [Dependencies](#dependencies)
* [Packaging](#packaging)
* [Technical Issues](#technical-issues)
  * [Module Names](#module-names)
  * [Builtin Types](#builtin-types)
  * [Environment Isolation](#environment-isolation)
  * [Module Dependencies](#module-dependencies)
  * [Module Precedence](#module-precedence)
  * [Agent Compatibility](#agent-compatibility)

# Goals

* Extract non-core types and providers from the puppet repo and move them to modules. Doing so will reduce the surface area of puppet, decrease puppet CI cycle times, while making the extracted types and providers more accessible to community members and increasing their maintainability.
* Continue to bundle some modules with puppet-agent during packaging so that users have a batteries-included experience.

# User Stories

## Serverless Puppet

As an admin, I want to run masterless puppet and immediately be able to manage basic resources on my system, so that I can more quickly get value from puppet. I do not want to search the forge in order to perform basic system tasks. The preinstalled modules should make sense for the local platform I'm running puppet on. On \*nix, I should be able to manage cron, and on Windows, powershell resources.

## Server-based Catalog Compilation

As an admin, I should be able to compile catalogs for resources whose types are included in the locally installed puppet-agent package, so that I don't have to install modules I already have.

## Server-based Catalog Application

As an admin, if catalog compilation succeeds, then I want assurance that the catalog will be applied consistently across all agent versions regardless of which preinstalled modules are on each agent. For example, if the master has a newer version of a type, then all agents in that environment should use the same version of the type (and its provider) at catalog application time.

## Module Updates

As an admin, if there is a problem with a type/provider packaged with puppet-agent, I want to be able to install a newer version from the forge (for both serverless and server-based), so that I don't need to wait for Puppet to release a new puppet-agent build.

## Puppet-Agent Updates

As an admin, when the puppet-agent package is updated, I want to be able to use the new versions of types and providers that come with the new package, even if that means overwriting and deleting older preinstalled versions. However, installing a new puppet-agent package should not clobber modules I've installed via puppet module tool, r10k, etc.

## Module Pinning

As an admin, if I update the puppet-agent package, and it updates a preinstalled module, but the module introduces a regression, I want to easily install the older version of the module from the forge.  I don't want to be forced to downgrade puppet-agent packages, because that process introduces more risk.

## Environment Isolation

As an admin, I want to be able to use deploy different versions of extracted modules in different environments without breaking environment isolation.

## Module Contributor

As an experienced puppet user, when I fix a bug in a puppet-maintained provider I use, I want to contribute that fix back upstream with a minimum of friction, so that I don't have to carry the patch to future versions of the agent.

## Community Maintainer

As a puppet community member with expertise in parts of the provider ecosystem, I want to manage the flow of fixes and contributions into the providers I care about, so that contributions and module releases can happen rapidly without requiring puppet core contributors to do a full agent release.

# File Path Changes

Puppet's default `basemodulepath` includes two module directories visible to all environments:

    /etc/puppetlabs/code/modules
    /opt/puppetlabs/puppet/modules

The first is where modules are typically installed to via puppet module tool, r10k, codemanager/filesync. The second path typically contains modules that are installed in PE environments, though there is nothing stopping users from manually installing modules there, e.g. `puppet module tool install puppetlabs-apt --target-dir /opt/puppetlabs/puppet/modules`. It is important that preinstalled modules do not use those same locations, otherwise, it will confuse package managers.

We propose a new directory `/opt/puppetlabs/puppet/vendor_modules` (which parallels ruby's `vendor_ruby`) to be created at puppet-agent installation time and containing all modules added to puppet-agent at packaging. The directory should be appended to the default `basemodulepath` so that the modules are available during compilation and application.

# Resource Type Taxonomy

## Internal

The following types are internal to Puppet and will remain as is:

    component
    schedule
    stage
    whit

## Core

The following types will be left in Puppet for now. The `file`, `user`, and `group` types are needed to apply settings catalogs. The `filebucket`, `resources`, and `tidy` types know too much about puppet internals to be extracted. The `notify` type is used extensively in puppet rspec tests as it is the most basic (providerless) type. The `package` and `service` types have multiple providers for each type, which makes removal more difficult. We may extract them at a later time (TBD).

    exec
    file
    filebucket
    group
    notify
    package
    resources
    service
    tidy
    user

## External

The following types and providers will be extracted from Puppet. A subset (details TBD below) will be added back to puppet-agent during packaging.

Each top-level path below specifies the name of the module, e.g. `augeas`, and the files contained within each module. The modules will be installed in a new directory visible to Puppet's autoloader, so catalog compilation and application will just work without additional configuration. Puppet will prefer modules in the modulepath and pluginsync'ed lib directory over the packaged modules, so that newer versions of modules can fix bugs in packaged modules.

    Path                                           Comments

    <vendor_modules>/                              (*nix) /opt/puppetlabs/puppet/vendor_modules/
                                                   (Windows) C:\Program Files\Puppet Labs\Puppet\puppet\vendor_modules

      augeas_core/                                 Depends on 'puppet/parameter/boolean'
        lib/puppet/feature/augeas.rb               Extracted from lib/puppet/features/base.rb        
        lib/puppet/type/augeas.rb
        lib/puppet/provider/augeas/augeas.rb

      cron_core/                                   Depends on 'puppet/provider/parsedfile',
        lib/puppet/type/cron.rb                               'puppet/util/filetype'

      host_core/                                   Depends on 'puppet/property/ordered_list',
        lib/puppet/type/host.rb                               'puppet/provider/parsedfile',
        lib/puppet/provider/host/parsed.rb

      k5login_core/                                Depends on 'puppet/type/file/selcontext',
        lib/puppet/type/k5login.rb                            'puppet/util/selinux'
                                                              
      mailalias_core/                              Depends on 'puppet/provider/parsedfile'
        lib/puppet/type/mailalias.rb
        lib/puppet/provider/mailalias/aliases.rb
     
      maillist_core/
        lib/puppet/type/maillist.rb
        lib/puppet/provider/maillist/maillist.rb

      macdslocal_core/                             Depends on 'puppet/provider/nameservice/directory_service',
        lib/puppet/type/                                      'puppet/util/plist'
          computer.rb
          macauthorization.rb
          mcx.rb
        lib/puppet/provider/
          computer.rb
          macauthorization.rb
          mcxcontent.rb

      mount_core/                                  Depends on 'puppet/property/boolean',
        lib/puppet/type/mount.rb                              'puppet/provider/parsedfile'
        lib/puppet/provider/mount.rb
        lib/puppet/provider/mount/parsed.rb

      nagios_core/                                 Depends on 'puppet/provider/parsedfile'
        lib/puppet/external/nagios.rb
        lib/puppet/external/nagios/
          base.rb
          grammer.py
          makefile
          parser.rb
        lib/puppet/type/
          nagios_*.rb
        lib/puppet/provider/naginator.rb          
        lib/puppet/util/nagios_maker.rb

      network_device_core/
        lib/puppet/feature/telnet.rb
        lib/puppet/type/
          router.rb
          interface.rb
          vlan.rb
        lib/puppet/provider/
          cisco.rb
          interface/cisco.rb
          vlan/cisco.rb
        lib/puppet/util/
          network_device.rb
          network_device/*

      scheduled_task_core/                         Depends on 'puppet/util/windows'
        lib/puppet/type/scheduled_task.rb
        lib/puppet/provider/scheduled_task/win32_taskscheduler.rb
        lib/puppet/util/windows/taskscheduler.rb
      
      selinux_core/                                Depends on 'puppet/type/file/selcontext',
        lib/puppet/feature/selinux.rb                         'puppet/util/selinux'
        lib/puppet/type/
          selboolean.rb
          selmodule.rb
        lib/puppet/provider/
          selmodule/seboolean.rb
          selmodule/semodule.rb

      sshkeys_core/                                Depends on 'puppet/provider/parsed'
        lib/puppet/type/
         sshkey.rb
         ssh_authorized_key.rb
        lib/puppet/provider/
         sshkey/parsed.rb
         ssh_authorized_key/parsed.rb

      yumrepo_core/                                Depends on 'puppet/util/filetype'
        lib/puppet/type/yumrepo.rb
        lib/puppet/provider/yumrepo/inifile.rb
        lib/puppet/util/inifile.rb

      zfs_core/
        lib/puppet/type/zfs.rb
        lib/puppet/provider/zfs/zfs.rb

      zone_core/                                   Depends on 'puppet/property/list'
        lib/puppet/type/zone.rb
        lib/puppet/provider/zone/zone.rb

      zpool_core/
        lib/puppet/type/zpool.rb
        lib/puppet/provider/zpool/zpool.rb

## Dependencies

The following classes are public API used by the above modules.

    Puppet::Error
    Puppet::FileSystem
    Puppet::Parameter
    Puppet::Property
    Puppet::Resource
    Puppet::Settings
    Puppet::Type
    Puppet::Util

The following classes are specific to a few different types and providers, which makes extracting them difficult:

    Puppet::Provider::NameService::DirectoryService  Used by mac user and group providers
    Puppet::Type::File::SelContext                   Used by :file, :k5login and :sel*
    Puppet::Util::FileType                           Used by :cron, :yumrepo
    Puppet::Util::PList                              Used by mac types
    Puppet::Util::SELinux                            Used by :file, :k5login and :sel*
    Puppet::Util::Windows                            Used by various windows types

# Packaging

This section lists which modules will be preinstalled in puppet-agent by platform family:

TBD

# Technical Issues

## Module Names

The puppet ecosystem contains modules that have the same name as some of the
core types we want to extract: `augeas`, `cron`, `mount`, `selinux`. However,
there can only be one version of a module installed per-environment (unless you
use tricks like adding multiple directories to the `modulepath`). To avoid
naming collisions, I'm proposing we append `_core` to all of the module names
that we extract, e.g. `augeas_core`. This only changes the name of the module,
not the names of the types contained within. Also it doesn't eliminate a
collision, just makes it less likely.

## Builtin Types

The loaders register builtin types based on
`Puppet::Pops::Loader::StaticLoader#BUILTIN_TYPE_NAMES`. This is an
optimization since we know the types exist in puppet and we don't need to scan
the filesystem based on the per-environment modulepath. Any type removed from
puppet, should be removed from `BUILTIN_TYPE_NAMES`. This will have an impact
on compiler performance where the timeout is not unlimited.

## Environment Isolation

All of the types extracted from puppet and removed from `BUILTIN_TYPE_NAMES`
above, will be subject to [environment
isolation](https://puppet.com/docs/puppet/5.4/environment_isolation.html#environment-isolation)
issues. Users that install newer versions of modules containing types that are
also vendored, should use `puppet generate types` to ensure types in one
environment don't affect other environments. This isn't really a new concern,
it's just that users haven't had to `puppet generate types` for builtin types
before.

## Module Dependencies

The autoloader does not rely on module metadata to load types. So any module
that relies on an type, should just work in Puppet 6 provided the extracted
module is vendored into puppet-agent (eg `augeas`), or the user installs the module
(eg `nagios`).

## Module Precedence

### Catalog Compilation

It should be possible to install a new version of a module and have that take
precedence over the `vendor_modules` directory during compilation (or `puppet
apply`). That will require a change to the autoloader to search for types.

### Pluginsync

All modules visible in the current environment's modulepath should have their
lib directories copied to the agent during pluginsync. If there are multiple
versions of the same type installed (one in the `vendor_modules` directory,
another in `$codedir/environments/production/modules`), then it's important that
we pluginsync the same type/provider version as was used during compilation. So
pluginsync and the compiler need to use the same precedence order when resolving
types.

### Catalog Application

Agents may have different versions of vendored modules than the server used to
compile the catalog. The agent should always use the pluginsync'ed version of
the type and providers instead of whatever version is present in the agent's
puppet-agent package.

## Agent Compatibility

Pre-6.0 agents will always prefer the builtin version over what was
pluginsynced. If a new property/parameter is added to the type on the master and
the manifest attempts to use that property/parameter, then old agents will not
be able to apply the catalog. This is the same issue we had with virtual
packages in puppet 4.x. Recommend users only deploy updated modules for builtin
types in environments where there are only Puppet 6+ agents.
