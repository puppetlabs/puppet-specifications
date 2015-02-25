Puppet Installation Layout
==========================

This table specifies the file paths in a Puppet installation and the corresponding settings, denoted as `:setting`. The 3.x column shows the difference of the specification vs the 3.x implementation.

# Index

* [puppet-agent (*nix)](#puppet-agent-nix)
* [puppet-agent (Windows)](#puppet-agent-windows)
* [puppet-db](#puppet-db)
* [puppetserver](#puppetserver)
* [Notes](#notes)

# puppet-agent (*nix)

    Path                                  Setting                        3.x
    /etc/puppetlabs                                                      n/a

    /etc/puppetlabs/code                  # :codedir                     contents moved from :confdir
        environments                      # :environmentpath
        hiera.yaml                        # :hiera_config
        hieradata                         # n/a
        modules                           # user modulepath

    /etc/puppetlabs/mcollective
        client.cfg
        facts.yaml
        server.cfg

    /etc/puppetlabs/puppet                # :confdir                     /etc/puppet
        auth.conf                         # :rest_authconfig
        autosign.conf                     # :autosign
        binder_config.yaml                # :binder_config
        csr_attributes.yaml               # :csr_attributes
        custom_trusted_oid_mapping.yaml   # :trusted_oid_mapping_file
        device.conf                       # :deviceconfig
        fileserver.conf                   # :fileserverconfig
        puppet.conf                       # :config
        routes.yaml                       # :route_file
        ssl                               # :ssldir                      /etc/puppet/ssl

    /opt/puppetlabs/bin                   # symlink targets of puppet related binaries
        cfacter@                          -> /opt/puppetlabs/puppet/bin/cfacter
        facter@                           -> /opt/puppetlabs/puppet/bin/facter
        hiera@                            -> /opt/puppetlabs/puppet/bin/hiera
        mco@                              -> /opt/puppetlabs/puppet/bin/mco
        puppet@                           -> /opt/puppetlabs/puppet/bin/puppet

    /opt/puppetlabs/facter
        facts.d                           # external facts directory (not pluginsync'ed)

    /opt/puppetlabs/mcollective/
        plugins                           # user installed plugins

    /opt/puppetlabs/puppet                # ruby-puppet root
        bin
            cfacter
            facter
            gem
            hiera
            mco
            mcollectived
            openssl
            puppet
            ruby
            virt-what
        cache                             # :vardir                      /var/lib/puppet
            bucket                        # :bucketdir
            client_yaml                   # :clientyamldir
            client_data                   # :client_datadir
            clientbucket                  # :clientbucketdir
            devicedir                     # :devices
            facts.d                       # :pluginfactdest (pluginsync'ed)
            lib                           # :libdir
            facts                         # used to generate :factpath
            puppet-module                 # :module_working_dir
            reports                       # :reportdir
            server_datadir                # :server_data
            state                         # :statedir
            yaml                          # :yamldir
        include
            facter
            openssl
        lib
            libaugeas.so
            libcrypto.so
            libfacter.so
            libruby.so
            libssl.so
            ruby
                vendor_ruby               # ruby code
                    cfacter.rb
                    facter.rb
                    hiera.rb
                    mcollective.rb
                    puppet.rb
            virt-what
                virt-what-cpuid-helper
        modules                           # system modulepath            /usr/share/puppet/modules
        share
            augeas
            man
            vim
        ssl

    /var/log/puppetlabs                   # :logdir                      /var/lib/puppet/log
        puppet.log                        # not enabled by default
        mcollective.log

    /var/run/puppetlabs                   # :rundir                      /var/lib/puppet/run
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

    Path                                      Setting                        3.x
    C:\ProgramData                                                           n/a

    C:\ProgramData\PuppetLabs\code            # :codedir                     contents moved from C:\ProgramData\PuppetLabs\puppet\etc (:confdir)
        environments                          # :environmentpath
        hiera.yaml                            # :hiera_config
        hieradata                             # n/a
        modules                               # user modulepath

    C:\ProgramData\PuppetLabs\mcollective\etc                                same
        client.cfg
        facts.yaml
        server.cfg

    C:\ProgramData\PuppetLabs\mcollective\var                                same
        log
            mcollective.log

    C:\ProgramData\PuppetLabs\puppet\etc      # :confdir                     same
        csr_attributes.yaml                   # :csr_attributes
        custom_trusted_oid_mapping.yaml       # :trusted_oid_mapping_file
        puppet.conf                           # :config
        ssl                                   # :ssldir

    C:\ProgramData\PuppetLabs\puppet\cache    # :vardir                      C:\ProgramData\PuppetLabs\puppet\var
        bucket                                # :bucketdir
        client_yaml                           # :clientyamldir
        client_data                           # :client_datadir
        clientbucket                          # :clientbucketdir
        devicedir                             # :devices
        facts.d                               # :pluginfactdest (pluginsync'ed)
        lib                                   # :libdir
        facts                                 # used to generate :factpath
        puppet-module                         # :module_working_dir
        reports                               # :reportdir
        server_datadir                        # :server_data
        state                                 # :statedir
        yaml                                  # :yamldir

    C:\ProgramData\PuppetLabs\facter                                         same
        facts.d                               # external facts directory (not pluginsync'ed)

    C:\ProgramData\PuppetLabs\mcollective
        plugins                               # user installed plugins

    C:\ProgramData\PuppetLabs\puppet\var\log  # :logdir                      same
        puppet.log                            # not enabled by default

    C:\ProgramData\PuppetLabs\puppet\var\run  # :rundir                      same
        agent.pid                             # :pidfile

    C:\Program Files\Puppet Labs\Puppet\bin
        cfacter.bat                           # bat file wrappers
        facter.bat
        hiera.bat
        mco.bat
        puppet.bat
        environment.bat                       # setup LOAD_PATH
        *_interactive.bat                     # targets for shortcuts

    C:\Program Files\Puppet Labs\Puppet\cfacter
        bin                                   # executables and dlls
            cfacter.exe
            libfacter.so
            lib*.dll
        inc                                   # cfacter headers
            facter
        lib
            cfacter.rb                        # ruby bindings

    C:\Program Files\Puppet Labs\Puppet\facter
        bin
            facter                            # ruby bin wrapper
        lib
            facter.rb

    C:\Program Files\Puppet Labs\Puppet\hiera
        bin
            hiera                             # ruby bin wrapper
        lib
            hiera.rb

    C:\Program Files\Puppet Labs\Puppet\mcollective
        bin
            mcollectived                      # ruby bin wrapper
        lib
            mcollective.rb

    C:\Program Files\Puppet Labs\Puppet\misc
        LICENSE.rtf                           # license
        puppetlabs.ico                        # icon for start menu shortcut
        puppetres.dll                         # event log message resource dll
        versions.txt                          # versions of components

    C:\Program Files\Puppet Labs\Puppet\puppet
        bin
            puppet                            # ruby bin wrapper
        lib
            puppet.rb

    C:\Program Files\Puppet Labs\Puppet\service
        daemon.rb                             # windows service daemon

    C:\Program Files\Puppet Labs\Puppet\sys
        ruby
            bin
                ruby.exe
                ssleay32.dll                  # openssl dll
            include
            lib
            share

        tools
            bin
                elevate.exe                   # Used to elevate interactive commands


These sections describe other Puppet packages that rely on puppet-agent to create the initial directory layout. It does not attempt to specify the full set of file paths for these packages, just cases where the other package has a dependency on puppet-agent.

# puppet-db

    /etc/puppetlabs/puppet
        puppetdb.conf


# puppetserver

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
                etc
                lib

            puppetserver                  # puppetserver app dir
                bin
                    puppetserver
                etc
                lib
        bin                               # symlinks of server binaries
            httpd@                        -> /opt/puppetlabs/server/apps/httpd/bin/httpd
            puppetserver@                 -> /opt/puppetlabs/server/apps/puppetserver/bin/puppetserver

        data
            puppetserver                  # :vardir (and $HOME for services that use it)
                bucket                    # :bucketdir
                reports                   # :reportdir
                server_datadir            # :server_data
                yaml                      # :yamldir


# Notes

## ssldir
The current specification calls for the puppet-agent and puppet-master to continue sharing an `ssldir`. The main reason being the master needs to use the agent's private key when acting as an SSL client. There are issues with this approach, but it's not something
we are trying to solve now.
