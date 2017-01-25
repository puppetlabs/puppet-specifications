Puppet::SimpleResource.define(
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
            type:      'String',
            docs:      'The date the key will expire, or nil if it has no expiry date, in ISO format.',
            read_only: true,
        },
        size:        {
            type:      'String',
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
)

Puppet::SimpleResource.implement('apt_key') do
  commands apt_key: 'apt-key'
  commands gpg: '/usr/bin/gpg'

  def get
    cli_args   = %w(adv --list-keys --with-colons --fingerprint --fixed-list-mode)
    key_output = apt_key(cli_args).encode('UTF-8', 'binary', :invalid => :replace, :undef => :replace, :replace => '')
    pub_line   = nil
    fpr_line   = nil

    key_output.split("\n").collect do |line|
      if line.start_with?('pub')
        pub_line = line
      elsif line.start_with?('fpr')
        fpr_line = line
      end

      next unless (pub_line and fpr_line)

      result   = key_line_to_hash(pub_line, fpr_line)

      # reset everything
      pub_line = nil
      fpr_line = nil

      result
    end.compact!
  end

  def self.key_line_to_hash(pub_line, fpr_line)
    pub_split = pub_line.split(':')
    fpr_split = fpr_line.split(':')

    # set key type based on types defined in /usr/share/doc/gnupg/DETAILS.gz
    key_type  = case pub_split[3]
                  when '1'
                    :rsa
                  when '17'
                    :dsa
                  when '18'
                    :ecc
                  when '19'
                    :ecdsa
                  else
                    :unrecognized
                end

    fingerprint = fpr_split.last
    expiry      = pub_split[6].empty? ? nil : Time.at(pub_split[6].to_i)

    {
        name:        fingerprint,
        ensure:      'present',
        fingerprint: fingerprint,
        long:        fingerprint[-16..-1], # last 16 characters of fingerprint
        short:       fingerprint[-8..-1], # last 8 characters of fingerprint
        size:        pub_split[2],
        type:        key_type,
        created:     Time.at(pub_split[5].to_i),
        expiry:      expiry,
        expired:     expiry && Time.now >= expiry,
    }
  end

  def set(current_state, target_state, noop = false)
    existing_keys = Hash[current_state.collect { |k| [k[:name], k] }]
    target_state.each do |key|
      logger.warning(key[:name], 'The id should be a full fingerprint (40 characters) to avoid collision attacks, see the README for details.') if key[:name].length < 40
      if key[:source] and key[:content]
        logger.fail(key[:name], 'The properties content and source are mutually exclusive')
        next
      end

      current = existing_keys[k[:name]]
      if current && key[:ensure].to_s == 'absent'
        logger.deleting(key[:name]) do
          begin
            apt_key('del', key[:short], noop: noop)
            r = execute(["#{command(:apt_key)} list | grep '/#{resource.provider.short}\s'"], :failonfail => false)
          end while r.exitstatus == 0
        end
      elsif current && key[:ensure].to_s == 'present'
        # No updating implemented
        # update(key, noop: noop)
      elsif !current && key[:ensure].to_s == 'present'
        create(key, noop: noop)
      end
    end
  end

  def create(key, noop = false)
    logger.creating(key[:name]) do |logger|
      if key[:source].nil? and key[:content].nil?
        # Breaking up the command like this is needed because it blows up
        # if --recv-keys isn't the last argument.
        args = ['adv', '--keyserver', key[:server]]
        if key[:options]
          args.push('--keyserver-options', key[:options])
        end
        args.push('--recv-keys', key[:id])
        apt_key(*args, noop: noop)
      elsif key[:content]
        temp_key_file(key[:content], logger) do |key_file|
          apt_key('add', key_file, noop: noop)
        end
      elsif key[:source]
        key_file = source_to_file(key[:source])
        apt_key('add', key_file.path, noop: noop)
        # In case we really screwed up, better safe than sorry.
      else
        logger.fail("an unexpected condition occurred while trying to add the key: #{key[:id]} (content: #{key[:content].inspect}, source: #{key[:source].inspect})")
      end
    end
  end

  # This method writes out the specified contents to a temporary file and
  # confirms that the fingerprint from the file, matches the long key that is in the manifest
  def temp_key_file(key, logger)
    file = Tempfile.new('apt_key')
    begin
      file.write key[:content]
      file.close
      if name.size == 40
        if File.executable? command(:gpg)
          extracted_key = execute(["#{command(:gpg)} --with-fingerprint --with-colons #{file.path} | awk -F: '/^fpr:/ { print $10 }'"], :failonfail => false)
          extracted_key = extracted_key.chomp

          unless extracted_key.match(/^#{name}$/)
            logger.fail("The id in your manifest #{key[:name]} and the fingerprint from content/source do not match. Please check there is not an error in the id or check the content/source is legitimate.")
          end
        else
          logger.warning('/usr/bin/gpg cannot be found for verification of the id.')
        end
      end
      yield file.path
    ensure
      file.close
      file.unlink
    end
  end
end
