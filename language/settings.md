New Settings
============

A strict_variables setting has been added to Puppet.  Setting this value true causes the future parser to raise errors when referencing unknown variables.  It does not effect referencing variables explicitly set to undef.

It's default is false.

Note: If this setting is set true with the original parser implementation, an error will be raised because of an uncaught throw of :undefined_variable.
