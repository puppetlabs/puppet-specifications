#!/usr/bin/ruby

require 'json'


def key_line_to_hash(pub_line, fpr_line)
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
      expired:     !!(expiry && Time.now >= expiry),
  }
end

key_output = <<EOM
Executing: /tmp/apt-key-gpghome.C186ICxj0z/gpg.1.sh --list-keys --with-colons --fingerprint --fixed-list-mode
tru:t:1:1485776129:0:3:1:5
pub:-:2048:1:4C0BE21B5FF054BD:1370645731:::-:::scESC:::::::
fpr:::::::::BBCB188AD7B3228BCF05BD554C0BE21B5FF054BD:
uid:-::::1370645731::B3A2F66693E8C5D4B1A6014AC73F5707E76443D7::Blue Jeans Network <netops@bluejeans.com>:
sub:-:2048:1:4AB781597254279C:1370645731::::::e::::::
fpr:::::::::B71ACDE6B52658D12C3106F44AB781597254279C:
pub:-:1024:17:A040830F7FAC5991:1173385030:::-:::scESC:::::::
fpr:::::::::4CCA1EAF950CEE4AB83976DCA040830F7FAC5991:
uid:-::::1175811711::0F5F08408BC3D293942A5E5A2D1AE1BD277FF5DB::Google, Inc. Linux Package Signing Key <linux-packages-keymaster@google.com>:
sub:-:2048:16:4F30B6B4C07CB649:1173385035::::::e::::::
fpr:::::::::9534C9C4130B4DC9927992BF4F30B6B4C07CB649:
pub:-:4096:1:7638D0442B90D010:1416603673:1668891673::-:::scSC:::::::
rvk:::1::::::309911BEA966D0613053045711B4E5FF15B0FD82:80:
rvk:::1::::::FBFABDB541B5DC955BD9BA6EDB16CF5BB12525C4:80:
rvk:::1::::::80E976F14A508A48E9CA3FE9BC372252CA1CF964:80:
fpr:::::::::126C0D24BD8A2942CC7DF8AC7638D0442B90D010:
uid:-::::1416603673::15C761B84F0C9C293316B30F007E34BE74546B48::Debian Archive Automatic Signing Key (8/jessie) <ftpmaster@debian.org>:
pub:-:4096:1:9D6D8F6BC857C906:1416604417:1668892417::-:::scSC:::::::
rvk:::1::::::FBFABDB541B5DC955BD9BA6EDB16CF5BB12525C4:80:
rvk:::1::::::309911BEA966D0613053045711B4E5FF15B0FD82:80:
rvk:::1::::::80E976F14A508A48E9CA3FE9BC372252CA1CF964:80:
fpr:::::::::D21169141CECD440F2EB8DDA9D6D8F6BC857C906:
uid:-::::1416604417::088FA6B00E33BCC6F6EB4DFEFAC591F9940E06F0::Debian Security Archive Automatic Signing Key (8/jessie) <ftpmaster@debian.org>:
pub:-:4096:1:CBF8D6FD518E17E1:1376739416:1629027416::-:::scSC:::::::
fpr:::::::::75DDC3C4A499F1A18CB5F3C8CBF8D6FD518E17E1:
uid:-::::1376739416::2D9AEBB80FC7D1724686A20DC5712C7D0DC07AF6::Jessie Stable Release Key <debian-release@lists.debian.org>:
pub:-:4096:1:AED4B06F473041FA:1282940623:1520281423::-:::scSC:::::::
fpr:::::::::9FED2BCBDCD29CDF762678CBAED4B06F473041FA:
uid:-::::1282940896::CED55047A1889F383B10CE9D04346A5CA12E2445::Debian Archive Automatic Signing Key (6.0/squeeze) <ftpmaster@debian.org>:
pub:-:4096:1:64481591B98321F9:1281140461:1501892461::-:::scSC:::::::
fpr:::::::::0E4EDE2C7F3E1FC0D033800E64481591B98321F9:
uid:-::::1281140461::BB638CC58BB7B36929C2C6DEBE580CC46FC94B36::Squeeze Stable Release Key <debian-release@lists.debian.org>:
pub:-:4096:1:8B48AD6246925553:1335553717:1587841717::-:::scSC:::::::
fpr:::::::::A1BD8E9D78F7FE5C3E65D8AF8B48AD6246925553:
uid:-::::1335553717::BCBD552DFB543AADFE3812AF631B17F5EDEF820E::Debian Archive Automatic Signing Key (7.0/wheezy) <ftpmaster@debian.org>:
pub:-:4096:1:6FB2A1C265FFB764:1336489909:1557241909::-:::scSC:::::::
fpr:::::::::ED6D65271AACF0FF15D123036FB2A1C265FFB764:
uid:-::::1336489909::0BB8E4C85595D59CE65881DDD593ECBAE583607B::Wheezy Stable Release Key <debian-release@lists.debian.org>:
pub:e:4096:1:1054B7A24BD6EC30:1278720832:1483574797::-:::sc:::::::
fpr:::::::::47B320EB4C7C375AA9DAE1A01054B7A24BD6EC30:
uid:e::::1460074501::BA4BCA138CEBDF8444241CE928DEE1AD79612E6C::Puppet Labs Release Key (Puppet Labs Release Key) <info@puppetlabs.com>:
pub:-:4096:1:B8F999C007BB6C57:1360109177:1549910347::-:::scESC:::::::
fpr:::::::::8735F5AF62A99A628EC13377B8F999C007BB6C57:
uid:-::::1455302347::A8FC88656336852AD4301DF059CEE6134FD37C21::Puppet Labs Nightly Build Key (Puppet Labs Nightly Build Key) <delivery@puppetlabs.com>:
uid:-::::1455302347::4EF2A82F1FF355343885012A832C628E1A4F73A8::Puppet Labs Nightly Build Key (Puppet Labs Nightly Build Key) <info@puppetlabs.com>:
sub:-:4096:1:AE8282E5A5FC3E74:1360109177:1549910293:::::e::::::
fpr:::::::::F838D657CCAF0E4A6375B0E9AE8282E5A5FC3E74:
pub:-:4096:1:7F438280EF8D349F:1471554366:1629234366::-:::scESC:::::::
fpr:::::::::6F6B15509CF8E59E6E469F327F438280EF8D349F:
uid:-::::1471554366::B648B946D1E13EEA5F4081D8FE5CF4D001200BC7::Puppet, Inc. Release Key (Puppet, Inc. Release Key) <release@puppet.com>:
sub:-:4096:1:A2D80E04656674AE:1471554366:1629234366:::::e::::::
fpr:::::::::07F5ABF8FE84BC3736D2AAD3A2D80E04656674AE:
EOM



pub_line   = nil
fpr_line   = nil

instances = key_output.split("\n").collect do |line|
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

puts JSON.generate(instances)
