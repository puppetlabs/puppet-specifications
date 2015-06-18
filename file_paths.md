Puppet Installation Layout
==========================

This table specifies the file paths in a Puppet installation and the corresponding settings, denoted as `:setting`. The 3.x column shows the difference of the specification vs the 3.x implementation.

# Index

* [puppet-agent (*nix)](#puppet-agent-nix)
* [puppet-agent (Windows)](#puppet-agent-windows)
* [puppet-agent (non-root)](#puppet-agent-non-root)
* [puppet-db](#puppet-db)
* [puppetserver](#puppetserver)
* [puppetmaster](#puppetmaster)
* [Notes](#notes)

# puppet-agent (*nix)

The package will create two services `puppet` and `mcollective`, both
running as `root` by default. It will not create a `puppet` user or group.
The files annotated by an '*' indicate that they are created by package installation.

    Path                                  Setting                        3.x
    /etc/puppetlabs *                                                    n/a

    /etc/puppetlabs/code *                # :codedir                     contents moved from :confdir
        environments *                    # :environmentpath
          production *
            environment.conf *
            manifests *
            modules *
        hiera.yaml *                      # :hiera_config
        hieradata *                       # n/a
        modules *                         # user modulepath

    /etc/puppetlabs/mcollective *
        client.cfg *
        facts.yaml *
        server.cfg *

    /etc/puppetlabs/puppet *              # :confdir                     /etc/puppet
        auth.conf *                       # :rest_authconfig
        autosign.conf                     # :autosign
        binder_config.yaml                # :binder_config
        csr_attributes.yaml               # :csr_attributes
        custom_trusted_oid_mapping.yaml   # :trusted_oid_mapping_file
        device.conf                       # :deviceconfig
        fileserver.conf                   # :fileserverconfig
        puppet.conf *                     # :config
        routes.yaml                       # :route_file
        ssl                               # :ssldir                      /etc/puppet/ssl

    /opt/puppetlabs/bin *                 # symlink targets of puppet related binaries
        cfacter@ *                        -> /opt/puppetlabs/puppet/bin/cfacter
        facter@ *                         -> /opt/puppetlabs/puppet/bin/facter
        hiera@ *                          -> /opt/puppetlabs/puppet/bin/hiera
        mco@ *                            -> /opt/puppetlabs/puppet/bin/mco
        puppet@ *                         -> /opt/puppetlabs/puppet/bin/puppet

    /opt/puppetlabs/facter
        facts.d                           # external facts directory (not pluginsync'ed)

    /opt/puppetlabs/mcollective/
        plugins                           # user installed plugins

    /opt/puppetlabs/puppet *              # ruby-puppet root
        bin *
            cfacter *
            facter *
            gem *
            hiera *
            mco *
            mcollectived *
            openssl *
            puppet *
            ruby *
            virt-what *
        cache *                           # :vardir                      /var/lib/puppet
            bucket                        # :bucketdir
            client_yaml                   # :clientyamldir
            client_data                   # :client_datadir
            clientbucket                  # :clientbucketdir
            devices                       # :devicedir
            facts.d                       # :pluginfactdest (pluginsync'ed)
            lib                           # :libdir
            facts                         # used to generate :factpath
            puppet-module                 # :module_working_dir
            reports                       # :reportdir
            server_data                   # :server_datadir
            state                         # :statedir
            yaml                          # :yamldir
        include *
            facter *
            openssl *
        lib *
            libaugeas.so *
            libcrypto.so *
            libfacter.so *
            libruby.so *
            libssl.so *
            ruby *
                vendor_ruby *             # ruby code
                    cfacter.rb *
                    facter.rb *
                    hiera.rb *
                    mcollective.rb *
                    puppet.rb *
            virt-what *
                virt-what-cpuid-helper *
        modules *                         # system modulepath            /usr/share/puppet/modules
        share *
            augeas *
            man *
            vim *
        ssl *

    /var/log/puppetlabs *
        mcollective.log
        puppet *                          # :logdir                      /var/lib/puppet/log
            puppet.log                    # not enabled by default

    /var/run/puppetlabs *                 # :rundir                      /var/lib/puppet/run
        agent.pid                         # :pidfile
        mcollectived.pid

# puppet-agent (windows)

On recent versions of Windows, e.g. 2008 & 2012, the installation path
defaults to `C:\Program Files\Puppet Labs` and the common app data
directory defaults to `C:\ProgramData`. On 2003, common app data is
under `C:\Documents and Settings\All Users\Application Data`. Also
when installing puppet-agent 32-bit on 64-bit windows, the
installation path defaults to `C:\Program Files (x86)\Puppet
Labs`. The examples below assume 2008/2012 and puppet-agent (64-bit).

The package will create two services `puppet` and `mcollective`
running as `LocalSystem` by default. It will not create a `puppet`
user or group.

    Path                                      Setting                        3.x
    C:\ProgramData                                                           n/a

    C:\ProgramData\PuppetLabs\code *          # :codedir                     contents moved from C:\ProgramData\PuppetLabs\puppet\etc (:confdir)
        environments *                        # :environmentpath
          production *
            environment.conf *
            manifests *
            modules *
        hiera.yaml *                          # :hiera_config
        hieradata *                           # n/a
        modules *                             # user modulepath

    C:\ProgramData\PuppetLabs\facter *                                       same
        facts.d *                             # external facts directory (not pluginsync'ed)

    C:\ProgramData\PuppetLabs\mcollective
        plugins *                             # user installed plugins
        etc *                                                                same
            client.cfg
            facts.yaml
            server.cfg
        var *                                                                same
            log *
                mcollective.log

    C:\ProgramData\PuppetLabs\puppet
    -------------------------------------------------------------------------------------------------------               
        cache                                 # :vardir                      C:\ProgramData\PuppetLabs\puppet\var
            bucket                            # :bucketdir
            client_yaml                       # :clientyamldir
            client_data                       # :client_datadir
            clientbucket                      # :clientbucketdir
            devices                           # :devicedir
            facts.d                           # :pluginfactdest (pluginsync'ed)
            lib                               # :libdir
            facts                             # used to generate :factpath
            puppet-module                     # :module_working_dir
            reports                           # :reportdir
            server_data                       # :server_datadir
            state                             # :statedir
            yaml                              # :yamldir
    -------------------------------------------------------------------------------------------------------               
        etc *                                 # :confdir                     same
            auth.conf                         # :rest_authconfig
            autosign.conf                     # :autosign
            binder_config.yaml                # :binder_config
            csr_attributes.yaml               # :csr_attributes
            custom_trusted_oid_mapping.yaml   # :trusted_oid_mapping_file
            device.conf                       # :deviceconfig
            fileserver.conf                   # :fileserverconfig
            puppet.conf *                     # :config
            routes.yaml                       # :route_file
            ssl                               # :ssldir
    -------------------------------------------------------------------------------------------------------               
        var *
            log                               # :logdir                      same
                puppet.log                    # not enabled by default
            run                               # :rundir                      same
                agent.pid                     # :pidfile

    C:\Program Files\Puppet Labs\Puppet\bin *
        cfacter.bat *                         # bat file wrappers
        environment.bat *                     # setup LOAD_PATH
        facter.bat *
        hiera.bat *
        mco.bat *
        puppet.bat *
        puppet_shell.bat *                    # targets for shortcuts
        run_cfacter_interactive.bat *
        run_facter_interactive.bat *
        run_puppet_interactive.bat *

    C:\Program Files\Puppet Labs\Puppet\cfacter *
        bin *                                 # executables and dlls
            cfacter.exe *
            libfacter.so *
            lib*.dll *
        inc *                                 # cfacter headers
            facter *
        lib *
            cfacter.rb *                      # ruby bindings

    C:\Program Files\Puppet Labs\Puppet\facter *
        bin *
            facter *                          # ruby bin wrapper
        lib *
            facter.rb *

    C:\Program Files\Puppet Labs\Puppet\hiera *
        bin *
            hiera *                           # ruby bin wrapper
        lib *
            hiera.rb *

    C:\Program Files\Puppet Labs\Puppet\mcollective *
        bin *
            mcollectived *                    # ruby bin wrapper
            mco *
        lib *
            mcollective.rb *

    C:\Program Files\Puppet Labs\Puppet\misc *
        LICENSE.rtf *                         # license
        puppetlabs.ico *                      # icon for start menu shortcut
        puppetres.dll *                       # event log message resource dll
        versions.txt *                        # versions of components

    C:\Program Files\Puppet Labs\Puppet\puppet *
        bin *
            puppet *                          # ruby bin wrapper
        lib *
            puppet.rb *

    C:\Program Files\Puppet Labs\Puppet\service *
        daemon.rb *                           # windows service daemon

    C:\Program Files\Puppet Labs\Puppet\sys *
        ruby *
            bin *
                ruby.exe *
                ssleay32.dll *                # openssl dll
            include *
            lib *
            share *

        tools *
            bin *
              elevate.exe *                   # Used to elevate interactive commands

# puppet-agent (non-root)

When running as non-root on \*nix and Windows, puppet will use the
following *top-level* paths, where `~` is expanded to the user's home
directory. On Windows this is `C:\Users\username` (or `C:\Documents
and Settings\username` for Windows 2003).

Only the top-level paths are different when running as non-root. Files
and directories that descend from the top-level are the same when
running as root and non-root, e.g. `puppet.conf` is always
`$confdir/puppet.conf`. As a result, only the top-level paths are shown.

    ~/.puppetlabs/etc/puppet              # :confdir                    ~/.puppet
    ~/.puppetlabs/etc/code                # :codedir                    n/a
    ~/.puppetlabs/opt/puppet/cache        # :vardir                     ~/.puppet/var
    ~/.puppetlabs/var/run                 # :rundir                     ~/.puppet/var/run
    ~/.puppetlabs/var/log                 # :logdir                     ~/.puppet/var/log
    ~/.puppetlabs/opt/facter/facts.d      # n/a                         ~/.facter/facts.d

These sections describe other Puppet packages that rely on puppet-agent to create the initial directory layout. It does not attempt to specify the full set of file paths for these packages, just cases where the other package has a dependency on puppet-agent.

# puppet-db

    /etc/puppetlabs/puppet
        puppetdb.conf


# puppetserver

The package will install a service named `puppetserver`, create a
`puppet` user and group, and run the service as the `puppet` user.

    /etc/puppetlabs/puppetserver
        logback.xml
        conf.d
            puppetserver.conf

    /opt/puppetlabs/bin                   # symlinks of puppet server binaries
        puppetserver@                     -> /opt/puppetlabs/server/apps/puppetserver/bin/puppetserver

    /opt/puppetlabs/server                # serverside apps live underneath
        apps
            httpd                         # httpd app dir
                bin
                    httpd
                lib

            puppetserver                  # puppetserver app dir
                bin
                    puppetserver
                lib
        bin                               # symlinks of server binaries
            httpd@                        -> /opt/puppetlabs/server/apps/httpd/bin/httpd
            puppetserver@                 -> /opt/puppetlabs/server/apps/puppetserver/bin/puppetserver

        data
            puppetserver                  # :vardir (and $HOME for services that use it)
                bucket                    # :bucketdir
                reports                   # :reportdir
                server_data               # :server_datadir
                yaml                      # :yamldir

    /var/log/puppetlabs
        puppetserver *                    # writeable by puppetserver
            puppetserver.log

    /var/run/puppetlabs                   # :rundir                      /var/lib/puppet/run
        puppetserver                      # writeable by puppetserver
            puppetserver.pid

# puppetmaster

This is a compatibility package using passenger to serve a ruby based puppetmaster.

The package will install passenger in conjunction with Apache, create a
`puppet` user and group, and run the instance as the `puppet` user.

    /opt/puppetlabs/server *              # serverside apps live underneath
        data *
            puppetmaster *                # :vardir (and $HOME for services that use it)
                bucket                    # :bucketdir
                reports                   # :reportdir
                server_data               # :server_datadir
                yaml                      # :yamldir

    /var/log/puppetlabs
        puppetmaster *                    # writeable by puppetmaster
            puppetmaster.log

    /var/run/puppetlabs                   # :rundir                      /var/lib/puppet/run
        puppetmaster *                    # writeable by puppetmaster
            puppetmaster.pid

# Notes

## ssldir
The current specification calls for the puppet-agent and puppetserver to continue sharing an `ssldir`. The main reason being the node running the puppetserver needs to use the agent's private key when acting as an SSL client. There are issues with this approach, but it's not something
we are trying to solve now.
