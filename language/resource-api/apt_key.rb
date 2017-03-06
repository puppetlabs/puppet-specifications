require 'puppet/pops/patterns'
require 'puppet/pops/utils'

require 'pry'

DEFINITION = {
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
        content:     {
            type: 'Optional[String]',
            docs: 'The content of, or string representing, a GPG key.',
        },
        source:      {
            type: 'Variant[Stdlib::Absolutepath, Pattern[/\A(https?|ftp):\/\//]]',
            docs: 'Location of a GPG key file, /path/to/file, ftp://, http:// or https://',
        },
        server:      {
            type:    'Pattern[/\A((hkp|http|https):\/\/)?([a-z\d])([a-z\d-]{0,61}\.)+[a-z\d]+(:\d{2,5})?$/]',
            docs:    'The key server to fetch the key from based on the ID. It can either be a domain name or url.',
            default: 'keyserver.ubuntu.com'
        },
        options:     {
            type: 'Optional[String]',
            docs: 'Additional options to pass to apt-key\'s --keyserver-options.',
        },
        fingerprint: {
            type:      'String',
            docs:      'The 40-digit hexadecimal fingerprint of the specified GPG key.',
            read_only: true,
        },
        long:        {
            type:      'String',
            docs:      'The 16-digit hexadecimal id of the specified GPG key.',
            read_only: true,
        },
        short:       {
            type:      'String',
            docs:      'The 8-digit hexadecimal id of the specified GPG key.',
            read_only: true,
        },
        expired:     {
            type:      'Boolean',
            docs:      'Indicates if the key has expired.',
            read_only: true,
        },
        expiry:      {
            # TODO: should be DateTime
            type:      'String',
            docs:      'The date the key will expire, or nil if it has no expiry date, in ISO format.',
            read_only: true,
        },
        size:        {
            type:      'Integer',
            docs:      'The key size, usually a multiple of 1024.',
            read_only: true,
        },
        type:        {
            type:      'String',
            docs:      'The key type, one of: rsa, dsa, ecc, ecdsa.',
            read_only: true,
        },
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
}

module Puppet::SimpleResource
  class TypeShim
    attr_reader :values

    def initialize(title, resource_hash)
      # internalize and protect - needs to go deeper
      @values        = resource_hash.dup
      # "name" is a privileged key
      @values[:name] = title
      @values.freeze
    end

    def to_resource
      ResourceShim.new(@values)
    end

    def name
      values[:name]
    end
  end

  class ResourceShim
    attr_reader :values

    def initialize(resource_hash)
      @values = resource_hash.dup.freeze # whatevs
    end

    def title
      values[:name]
    end

    def prune_parameters(*args)
      puts "not pruning #{args.inspect}" if args.length > 0
      self
    end

    def to_manifest
      [
          "apt_key { #{values[:name].inspect}: ",
      ] + values.keys.select { |k| k != :name }.collect { |k| "  #{k} => #{values[k].inspect}," } + ['}']
    end
  end
end

Puppet::Type.newtype(DEFINITION[:name].to_sym) do
  @doc = DEFINITION[:docs]

  has_namevar = false

  DEFINITION[:attributes].each do |name, options|
    puts "#{name}: #{options.inspect}"

    # TODO: using newparam everywhere would suppress change reporting
    #       that would allow more fine-grained reporting through logger,
    #       but require more invest in hooking up the infrastructure to emulate existing data
    param_or_property = if options[:read_only] || options[:namevar]
                          :newparam
                        else
                          :newproperty
                        end
    send(param_or_property, name.to_sym) do
      unless options[:type]
        fail("#{DEFINITION[:name]}.#{name} has no type")
      end

      if options[:docs]
        desc "#{options[:docs]} (a #{options[:type]}"
      else
        warn("#{DEFINITION[:name]}.#{name} has no docs")
      end

      if options[:namevar]
        puts 'setting namevar'
        isnamevar
        has_namevar = true
      end

      # read-only values do not need type checking
      if not options[:read_only]
        # TODO: this should use Pops infrastructure to avoid hardcoding stuff, and enhance type fidelity
        # validate do |v|
        #   type = Puppet::Pops::Types::TypeParser.singleton.parse(options[:type]).normalize
        #   if type.instance?(v)
        #     return true
        #   else
        #     inferred_type = Puppet::Pops::Types::TypeCalculator.infer_set(value)
        #     error_msg = Puppet::Pops::Types::TypeMismatchDescriber.new.describe_mismatch("#{DEFINITION[:name]}.#{name}", type, inferred_type)
        #     raise Puppet::ResourceError, error_msg
        #   end
        # end

        case options[:type]
          when 'String'
            # require any string value
            newvalue // do
            end
          when 'Boolean'
            ['true', 'false', :true, :false, true, false].each do |v|
              newvalue v do
              end
            end

            munge do |v|
              case v
                when 'true', :true
                  true
                when 'false', :false
                  false
                else
                  v
              end
            end
          when 'Integer'
            newvalue /^\d+$/ do
            end
            munge do |v|
              Puppet::Pops::Utils.to_n(v)
            end
          when 'Float', 'Numeric'
            newvalue Puppet::Pops::Patterns::NUMERIC do
            end
            munge do |v|
              Puppet::Pops::Utils.to_n(v)
            end
          when 'Enum[present, absent]'
            newvalue :absent do
            end
            newvalue :present do
            end
          when 'Variant[Pattern[/\A(0x)?[0-9a-fA-F]{8}\Z/], Pattern[/\A(0x)?[0-9a-fA-F]{16}\Z/], Pattern[/\A(0x)?[0-9a-fA-F]{40}\Z/]]'
            # the namevar needs to be a Parameter, which only has newvalue*s*
            newvalues(/\A(0x)?[0-9a-fA-F]{8}\Z/, /\A(0x)?[0-9a-fA-F]{16}\Z/, /\A(0x)?[0-9a-fA-F]{40}\Z/)
          when 'Optional[String]'
            newvalue :undef do
            end
            newvalue // do
            end
          when 'Variant[Stdlib::Absolutepath, Pattern[/\A(https?|ftp):\/\//]]'
            # TODO: this is wrong, but matches original implementation
            [/^\//, /\A(https?|ftp):\/\//].each do |v|
              newvalue v do
              end
            end
          when /^(Enum|Optional|Variant)/
            fail("#{$1} is not currently supported")
        end
      end
    end
  end

  unless has_namevar
    fail("#{DEFINITION[:name]} has no namevar")
  end

  def self.fake_system_state
    @fake_system_state ||= {
        'BBCB188AD7B3228BCF05BD554C0BE21B5FF054BD' => {
            ensure:      :present,
            fingerprint: 'BBCB188AD7B3228BCF05BD554C0BE21B5FF054BD',
            long:        '4C0BE21B5FF054BD',
            short:       '5FF054BD',
            size:        2048,
            type:        :rsa,
            created:     '2013-06-07 23:55:31 +0100',
            expiry:      nil,
            expired:     false,
        },
        'B71ACDE6B52658D12C3106F44AB781597254279C' => {
            ensure:      :present,
            fingerprint: 'B71ACDE6B52658D12C3106F44AB781597254279C',
            long:        '4AB781597254279C',
            short:       '7254279C',
            size:        1024,
            type:        :dsa,
            created:     '2007-03-08 20:17:10 +0000',
            expiry:      nil,
            expired:     false
        },
        '9534C9C4130B4DC9927992BF4F30B6B4C07CB649' => {
            ensure:      :present,
            fingerprint: '9534C9C4130B4DC9927992BF4F30B6B4C07CB649',
            long:        '4F30B6B4C07CB649',
            short:       'C07CB649',
            size:        4096,
            type:        :rsa,
            created:     '2014-11-21 21:01:13 +0000',
            expiry:      '2022-11-19 21:01:13 +0000',
            expired:     false
        },
        '126C0D24BD8A2942CC7DF8AC7638D0442B90D010' => {
            ensure:      :present,
            fingerprint: '126C0D24BD8A2942CC7DF8AC7638D0442B90D010',
            long:        '7638D0442B90D010',
            short:       '2B90D010',
            size:        4096,
            type:        :rsa,
            created:     '2014-11-21 21:13:37 +0000',
            expiry:      '2022-11-19 21:13:37 +0000',
            expired:     false
        },
        'ED6D65271AACF0FF15D123036FB2A1C265FFB764' => {
            ensure:      :present,
            fingerprint: 'ED6D65271AACF0FF15D123036FB2A1C265FFB764',
            long:        '6FB2A1C265FFB764',
            short:       '65FFB764',
            size:        4096,
            type:        :rsa,
            created:     '2010-07-10 01:13:52 +0100',
            expiry:      '2017-01-05 00:06:37 +0000',
            expired:     true
        },
    }
  end

  def self.get
    puts 'get'
    fake_system_state
  end

  def self.set(current_state, target_state, noop = false)
    puts "enforcing change from #{current_state} to #{target_state} (noop=#{noop})"
    target_state.each do |title, resource|
      # additional validation for this resource goes here

      # set default value
      resource[:ensure] ||= :present

      current = current_state[title]
      if current && resource[:ensure].to_s == 'absent'
        # delete the resource
        puts "deleting #{title}"
        fake_system_state.delete_if { |k, _| k==title }
      elsif current && resource[:ensure].to_s == 'present'
        # update the resource
        puts "updating #{title}"
        resource = current.merge(resource)
        fake_system_state[title] = resource.dup
      elsif !current && resource[:ensure].to_s == 'present'
        # create the resource
        puts "creating #{title}"
        fake_system_state[title] = resource.dup
      end
      # TODO: update Type's notion of reality to ensure correct puppet resource output with all available attributes
    end
  end

  def self.instances
    puts 'instances'
    # klass = Puppet::Type.type(:api)
    get.collect do |title, resource_hash|
      Puppet::SimpleResource::TypeShim.new(title, resource_hash)
    end
  end

  def retrieve
    puts 'retrieve'
    result        = Puppet::Resource.new(self.class, title)
    current_state = self.class.get[title]

    if current_state
      current_state.each do |k, v|
        result[k]=v
      end
    else
      result[:ensure] = :absent
    end

    @rapi_current_state = current_state
    result
  end

  def flush
    puts 'flush'
    # binding.pry
    target_state = Hash[@parameters.collect { |k, v| [k, v.value] }]
    self.class.set({title => @rapi_current_state}, {title => target_state}, false)
  end

end
