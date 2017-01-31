#!/usr/bin/ruby

require 'json'

current_state_json = <<INPUT
[
  {
    "name": "BBCB188AD7B3228BCF05BD554C0BE21B5FF054BD",
    "ensure": "present",
    "fingerprint": "BBCB188AD7B3228BCF05BD554C0BE21B5FF054BD",
    "long": "4C0BE21B5FF054BD",
    "short": "5FF054BD",
    "size": "2048",
    "type": "rsa",
    "created": "2013-06-07 23:55:31 +0100",
    "expiry": null,
    "expired": false
  },
  {
    "name": "B71ACDE6B52658D12C3106F44AB781597254279C",
    "ensure": "present",
    "fingerprint": "B71ACDE6B52658D12C3106F44AB781597254279C",
    "long": "4AB781597254279C",
    "short": "7254279C",
    "size": "1024",
    "type": "dsa",
    "created": "2007-03-08 20:17:10 +0000",
    "expiry": null,
    "expired": false
  },
  {
    "name": "9534C9C4130B4DC9927992BF4F30B6B4C07CB649",
    "ensure": "present",
    "fingerprint": "9534C9C4130B4DC9927992BF4F30B6B4C07CB649",
    "long": "4F30B6B4C07CB649",
    "short": "C07CB649",
    "size": "4096",
    "type": "rsa",
    "created": "2014-11-21 21:01:13 +0000",
    "expiry": "2022-11-19 21:01:13 +0000",
    "expired": false
  },
  {
    "name": "126C0D24BD8A2942CC7DF8AC7638D0442B90D010",
    "ensure": "present",
    "fingerprint": "126C0D24BD8A2942CC7DF8AC7638D0442B90D010",
    "long": "7638D0442B90D010",
    "short": "2B90D010",
    "size": "4096",
    "type": "rsa",
    "created": "2014-11-21 21:13:37 +0000",
    "expiry": "2022-11-19 21:13:37 +0000",
    "expired": false
  },
  {
    "name": "D21169141CECD440F2EB8DDA9D6D8F6BC857C906",
    "ensure": "present",
    "fingerprint": "D21169141CECD440F2EB8DDA9D6D8F6BC857C906",
    "long": "9D6D8F6BC857C906",
    "short": "C857C906",
    "size": "4096",
    "type": "rsa",
    "created": "2013-08-17 12:36:56 +0100",
    "expiry": "2021-08-15 12:36:56 +0100",
    "expired": false
  },
  {
    "name": "75DDC3C4A499F1A18CB5F3C8CBF8D6FD518E17E1",
    "ensure": "present",
    "fingerprint": "75DDC3C4A499F1A18CB5F3C8CBF8D6FD518E17E1",
    "long": "CBF8D6FD518E17E1",
    "short": "518E17E1",
    "size": "4096",
    "type": "rsa",
    "created": "2010-08-27 21:23:43 +0100",
    "expiry": "2018-03-05 20:23:43 +0000",
    "expired": false
  },
  {
    "name": "9FED2BCBDCD29CDF762678CBAED4B06F473041FA",
    "ensure": "present",
    "fingerprint": "9FED2BCBDCD29CDF762678CBAED4B06F473041FA",
    "long": "AED4B06F473041FA",
    "short": "473041FA",
    "size": "4096",
    "type": "rsa",
    "created": "2010-08-07 01:21:01 +0100",
    "expiry": "2017-08-05 01:21:01 +0100",
    "expired": false
  },
  {
    "name": "0E4EDE2C7F3E1FC0D033800E64481591B98321F9",
    "ensure": "present",
    "fingerprint": "0E4EDE2C7F3E1FC0D033800E64481591B98321F9",
    "long": "64481591B98321F9",
    "short": "B98321F9",
    "size": "4096",
    "type": "rsa",
    "created": "2012-04-27 20:08:37 +0100",
    "expiry": "2020-04-25 20:08:37 +0100",
    "expired": false
  },
  {
    "name": "A1BD8E9D78F7FE5C3E65D8AF8B48AD6246925553",
    "ensure": "present",
    "fingerprint": "A1BD8E9D78F7FE5C3E65D8AF8B48AD6246925553",
    "long": "8B48AD6246925553",
    "short": "46925553",
    "size": "4096",
    "type": "rsa",
    "created": "2012-05-08 16:11:49 +0100",
    "expiry": "2019-05-07 16:11:49 +0100",
    "expired": false
  },
  {
    "name": "ED6D65271AACF0FF15D123036FB2A1C265FFB764",
    "ensure": "present",
    "fingerprint": "ED6D65271AACF0FF15D123036FB2A1C265FFB764",
    "long": "6FB2A1C265FFB764",
    "short": "65FFB764",
    "size": "4096",
    "type": "rsa",
    "created": "2010-07-10 01:13:52 +0100",
    "expiry": "2017-01-05 00:06:37 +0000",
    "expired": true
  },
  {
    "name": "47B320EB4C7C375AA9DAE1A01054B7A24BD6EC30",
    "ensure": "present",
    "fingerprint": "47B320EB4C7C375AA9DAE1A01054B7A24BD6EC30",
    "long": "1054B7A24BD6EC30",
    "short": "4BD6EC30",
    "size": "4096",
    "type": "rsa",
    "created": "2013-02-06 00:06:17 +0000",
    "expiry": "2019-02-11 18:39:07 +0000",
    "expired": false
  },
  {
    "name": "F838D657CCAF0E4A6375B0E9AE8282E5A5FC3E74",
    "ensure": "present",
    "fingerprint": "F838D657CCAF0E4A6375B0E9AE8282E5A5FC3E74",
    "long": "AE8282E5A5FC3E74",
    "short": "A5FC3E74",
    "size": "4096",
    "type": "rsa",
    "created": "2016-08-18 22:06:06 +0100",
    "expiry": "2021-08-17 22:06:06 +0100",
    "expired": false
  }
]
INPUT

current_state = JSON.parse(current_state_json)

# re-parse json to avoid linking objects
target_state =  JSON.parse(current_state_json)
target_state[2]['ensure'] = 'absent'


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


set(current_state, target_state)
