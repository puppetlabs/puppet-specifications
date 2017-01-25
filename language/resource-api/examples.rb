SHARED_PACKAGE_ATTRIBUTES = {
    name: { type: 'String' },
    ENSURE_ATTRIBUTE,
    reinstall_on_refresh: { type: 'Boolean'},
}.freeze

LOCAL_PACKAGE_ATTRIBUTES = {
    source: { type: 'String' },
}.freeze

VERSIONABLE_PACKAGE_ATTRIBUTES = {
    version: { type: 'String' },
}.freeze

APT_PACKAGE_ATTRIBUTES = {
    install_options: { type: 'String' },
    responsefile: { type: 'String' },
}.freeze

Puppet::SimpleResource.define(
  name: 'package_rpm',
  attributes: {}.merge(SHARED_PACKAGE_ATTRIBUTES).merge(LOCAL_PACKAGE_ATTRIBUTES),
)

Puppet::SimpleResource.define(
    name: 'package_apt',
    attributes: {}.merge(SHARED_PACKAGE_ATTRIBUTES).merge(LOCAL_PACKAGE_ATTRIBUTES).merge(VERSIONABLE_PACKAGE_ATTRIBUTES).merge(APT_PACKAGE_ATTRIBUTES),
)

