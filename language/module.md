# Puppet Module Schema

This document describes allowed (optional) and required files and directories in
a Puppet Module Release.

## Table of contents

* [What is a Puppet Module](#what-is-a-puppet-module)
* [Allowed files and directories](#allowed-files-and-directories)
* [Explanations and reasoning](#explanations-and-reasoning)
* [Schema versioning](#schema-versioning)

## What is a Puppet Module

A module in the sense of this document is a compressed tar archive. It is
usually distributed via [forge.puppet.com](https://forge.puppet.com/). A module
is usually developed in a git repository. Some files in the git repository are
only used for development and testing. They should not be released.

Common files often seen in a vcs repository that are used for development but
shall not be released:

`/spec`, `/Rakefile`, `/Gemfile`, `/.gitignore`, `/.github/`, `/.devcontainer`, `/Dockerfile`, `/.git`

Note that above are just examples and not a complete list. The goal of this
document is to provide an allowlist (*for a module release, not a VCS repo*),
not a denylist.

The official
[Puppet documentation](https://www.puppet.com/docs/puppet/latest/modules_fundamentals.html)
already explains what a module is and what it can contain.

## Allowed files and directories

| Directories and Files | Purpose |
|-----------------------|---------|
| `/manifests/`         | MAY contain Puppet code |
| `/hiera.yaml`         | A module MAY define a Hiera configuration for Hiera data within this module |
| `/data/`              | If the module has a `hiera.yaml`, the related data has to be within `/data/` |
| `/templates/`         | Stores [epp](https://www.puppet.com/docs/puppet/latest/lang_template_epp.html) (preferred) or [erb](https://www.puppet.com/docs/puppet/latest/lang_template_erb.html) templates |
| `/files/`             | Static files that Puppet code within the module will distribute |
| `/examples/`          | Example Puppet snippets that explain how to use the module. They can be used within acceptance tests |
| `/facts.d/`           | [External facts](https://www.puppet.com/docs/puppet/latest/external_facts.html) that are synced via [pluginsync](https://www.puppet.com/docs/puppet/latest/plugins_in_modules.html) |
| `/lib/facter/`        | MAY contain custom facts |
| `/lib/puppet/type/`   | Custom Resource types |
| `/lib/puppet/provider/` | Custom provider for one or multiple Resource types |
| `/lib/puppet/functions/` | Modern functions in Ruby for the new API |
| `/lib/puppet/datatypes/` | Custom Puppet Data types |
| `/lib/puppet/face/`   | Custom Puppet Faces |
| `/lib/puppet/feature/` | Custom Puppet Features for providers |
| `/lib/puppet/property/` | Custom Puppet Properties for Types/Providers |
| `/lib/puppet/transport/` | Puppet Device Transports for the Resource API |
| `/lib/puppet/util/network_device` | Puppet Device Transports |
| `/lib/puppet/parser/functions/` | Legacy functions in Ruby |
| `/lib/puppet_x/`      | Custom Ruby modules to extend types, providers, functions or facts |
| `/lib/augeas/lenses/` | Custom [Augeas](https://augeas.net/) lenses |
| `/functions/`         | MAY contain [functions written in Puppet DSL](https://www.puppet.com/docs/puppet/latest/lang_write_functions_in_puppet.html) |
| `/metadata.json`      | The `metadata.json` file MUST be present and MUST adhere to [Puppet's metadata](https://www.puppet.com/docs/puppet/latest/modules_metadata.html). [metadata-json-lint](https://github.com/voxpupuli/metadata-json-lint#metadata-json-lint) can be used to validate your file. |
| `/README`             | A README that describes what the module does. It's best practice to add a file extension like `.md`, `.rst` when a markup language is used |
| `/LICENSE`            | The `/LICENSE` file, with an optional file extension, SHOULD be included in the module. If the file is present, it MUST match `/metadata.json`'s license field. |
| `/CHANGELOG`          | A module SHOULD contain a changelog that's updated for every release. A new release SHOULD NOT alter existing changelog entries. It MAY use a file extension if a markup language is used. The [Puppet forge](https://forge.puppet.com/) supports the markdown markup language. |
| `/docs/`              | Directory for additional documentation |
| `/REFERENCE.md`       | [puppet-strings](https://www.puppet.com/docs/puppet/latest/puppet_strings.html) based documentation in markdown, updated on each release |
| `/locales/`           | Used for i18n support, can contain translated strings, deprecated within Puppet |
| `/scripts/`           | May serve static files, like `/files/` (see [PUP-11187](https://puppet.atlassian.net/browse/PUP-11187) for background) |
| `/tasks/`             | Contains [Tasks for Bolt](https://www.puppet.com/docs/bolt/latest/tasks.html) |
| `/plans/`             | Contains [Plans for Bolt](https://www.puppet.com/docs/bolt/latest/plans) |
| `/types/`             | Contains [type aliases](https://www.puppet.com/docs/puppet/latest/lang_type_aliases.html) |
| `/bolt_plugin.json`   | The file can contain metadata about [a Bolt plugin](https://www.puppet.com/docs/bolt/latest/writing_plugins.html#module-structure) |


## Mandatory files

Mandatory are:
* `/metadata.json`
* `/README`
* `/LICENSE`
* `/CHANGELOG`

## Explanations and reasoning

In the past, modules sometines contained a `/Modulefile`. It contained metadata
about the module. The `/metadata.json` is the successor. A module can now only
have a `/metadata.json`. It must not have a `/Modulefile`.

The `/REFERENCE.md` file is optional. It's generated by puppet-strings. Some
modules might use a different tool for documentation (and then cannot generate
a `REFERENCE.md`). If a `/REFERENCE.md` is present in the release, it has to be
up to date.

## Schema versioning

This is version 0 of the schema. A changelog will be added when the schema is
updated.

A potential change is the removal of `/locales/`. The i18n support in puppet is
currently deprecated, but still possible. When it's removed from Puppet and
Puppetserver, the schema will be updated to reflect this.
