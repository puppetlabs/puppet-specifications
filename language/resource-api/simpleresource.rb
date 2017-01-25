Puppet::SimpleResource.define(
    name: 'iis_application_pool',
    docs: 'Manage an IIS application pool through a powershell proxy.',
    attributes: {
        ensure: {
            type: 'Enum[present, absent]',
            docs: 'Whether this ApplicationPool should be present or absent on the target system.'
        },
        name: {
            type: 'String',
            docs: 'The name of the ApplicationPool.',
            namevar: true,
        },
        state: {
            type: 'Enum[running, stopped]',
            docs: 'The state of the ApplicationPool.',
            default: 'running',
        },
        managedpipelinemode: {
            type: 'String',
            docs: 'The managedPipelineMode of the ApplicationPool.',
        },
        managedruntimeversion: {
            type: 'String',
            docs: 'The managedRuntimeVersion of the ApplicationPool.',
        },
    }
) do

  require 'puppet/provider/iis_powershell'
  include Puppet::Provider::IIS_PowerShell

  def get
    result = run('fetch_application_pools.ps1', logger) # call out to powershell to talk to the API

    # returns an array of hashes with data according to the schema above
    JSON.parse(result)
  end

  def set(goals, noop = false)
    result = run('enforce_application_pools.ps1', goals, logger, noop) # call out to powershell to talk to the API

    # returns an array of hashes with status data from the changes
    JSON.parse(result)
  end

end
