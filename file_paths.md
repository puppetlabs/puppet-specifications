Puppet Installation Layout
==========================

This table specifies the file paths in a Puppet installation and the corresponding settings, denoted as `:setting`. The 3.x column shows the difference of the specification vs the 3.x implementation.

puppet-agent
------------

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
        plugins

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
        mcollectived.log

    /var/run/puppetlabs                   # :rundir                      /var/lib/puppet/run
        agent.pid                         # :pidfile
        mcollective.pid
        mcollectived.pid

These sections describe other Puppet packages that rely on puppet-agent to create the initial directory layout. It does not attempt to specify the full set of file paths for these packages, just cases where the other package has a dependency on puppet-agent.

puppetdb
--------

    /etc/puppetlabs/puppet
        puppetdb.conf


puppet-server
-------------

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

Notes
-----

### ssldir <a id="note-ssldir"></a>
The current specification calls for the puppet-agent and puppet-master to continue sharing an `ssldir`. The main reason being the master needs to use the agent's private key when acting as an SSL client. There are issues with this approach, but it's not something
we are trying to solve now.
