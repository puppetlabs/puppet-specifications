define package (
  Ensure $ensure,
  Enum[apt, rpm] $provider,
  Optional[String] $source          = undef,
  Optional[String] $version         = undef,
  Optional[String] $install_options = undef,
  Optional[String] $responsefile    = undef,
  Optional[Hash] $options           = { },
) {
  case $provider {
    apt: {
      package_apt { $title:
        ensure          => $ensure,
        source          => $source,
        version         => $version,
        install_options => $install_options,
        responsefile    => $responsefile,
        *               => $options,
      }
    }
    rpm: {
      package_rpm { $title:
        ensure => $ensure,
        source => $source,
        *      => $options,
      }
      if defined($version) { fail("RPM doesn't support \$version") }
      # ...
    }
  }
}
