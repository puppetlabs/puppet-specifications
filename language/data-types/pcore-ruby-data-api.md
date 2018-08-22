The Ruby Pcore API for data
===

The Generic Data API
===
The Generic Data API can convert runtime values to generic data, and back again to
runtime values. This API does not define any actual serialization, but since it
guarantees that converted runtime values conform to the Data type, it is safe to
simply convert the returned value to JSON or YAML (or some other format).

Converting to Generic Data
---
To get any data transformed to generic data:

```ruby
val = "the value to convert"
converted = Puppet::Pops::Serialization::ToDataConverter.convert(val,
  :rich_data => true,
  :type_by_reference => true,
  :symbol_as_string => false,
  :local_reference => false,
  )
```

The options are:

| Option | Meaning |
| ---    | ---     |
| `:rich_data`     | If non Data should be transformed to strings or Generic Data
| `:type_by_reference` | If true, types are string references otherwise the types definition
| `:local_reference`   | If true deduplification will take place
| `:symbol_as_string`  | If true, symbols are turned into strings instead of Runtime instances
| `:path_prefix`       | A string that is output in errors and warnings before the actual issue.

The format used by Puppet's `--rich_data` option is the same as what is shown in the example above.

Rich Data (`:rich_data` => true) will transform rich data to a `Hash` with the meta keys
`__ptype` and `__pvalue` as shown in [Generic Data Format][1]. If the option is false, all
rich data values will be transformed to strings on a best effort and a warning is issued. While
the result is often readable by a human, it cannot be read back in without loss of data type.

Deduplicfication (`:local_reference` => `true`) is an experimental feature that replaces duplicate
entires in the result with an instance of a `LocalRef` that has a value that is a json path to
the original value.

Type expansion (`:type_by_reference` => `false`) is an experimental feature that instead of
using a type reference string as the value of the `__ptype` key will have a full representation
of that data type. This is useful when the recipient does not have prior knowledge of the data type.

Replacing Symbols can be done with (`symbols_as_string` => `true`). This will transform
all Ruby `Symbol` instances except `:undef` and `:default` (which have special meaning) to
the corresponding string. When the option is `true` all non special symbols are
transformed to instances of `Runtime['Ruby', 'Symbol']`.

Converting From Generic Data
---
To convert generic data back from the generic form to runtime instances:

```ruby
val = Puppet::Pops::Serialization::FromDataConverter.convert(converted)
```

The method allows options to specify a loader to use (defaults to puppet's standard loader),
and also if values with unresolved type references should be kept in the result or if
the operation should error.

| Option | Meaning |
| ---    | ---     |
| `:loader`           | The loader to use, if not specified the standard loader is used
| `:allow_unresolved` | If `true`, unresolved type references will not error. Defaults to `false`.

Both options are for advanced usage, and you should probably only use the defaults.

Pcore Serialization Ruby API
===

Using JSON serialization
---

### Serializing

This example shows how to serialize a `value` to a json string:

```ruby
io = StringIO.new
writer = Puppet::Pops::Serialization::JSON::Writer.new(io)
serializer = Puppet::Pops::Serialization::Serializer.new(writer, :type_by_reference => true)
serializer.write(value)
serializer.finish
serialized_string = io.string
```

The `Serializer` can be initialized with the option `:type_by_reference` which
if it is set to `true` will include type references instead of serializing the
definition of used (custom) types. When set to `true` the types must be available
to the loader used when deserializing.

Any Ruby IO object can be given to the Writer.

### Deserializing

This example shows how to deserialize the `serialized_string` as produced by
the example above into the `value` it used as input:

```ruby
io = StringIO.new(serialized_string)
reader = Puppet::Pops::Serialization::JSON::Reader.new(io)
loader = scope.compiler.loaders.find_loader(nil) # use the standard loader for the environment
deserializer = Puppet::Pops::Serialization::Deserializer.new(reader, loader)
value = deserializer.read()
```

Any Ruby IO object can be given to the Reader.
Note that a loader is required to find the data types referenced in the serialized data.

Using Other Serializers
---
Other serializers work exactly the same way - as an example, to use the MsgPack based serializer
the writer would be `Puppet::Pops::Serialization::MsgPack::Writer`, and the reader `Puppet::Pops::Serialization::MsgPack::Reader`, while the rest of the examples for JSON
would be essentially the same (since MsgPack is binary some care must be taken to handle the
resulting binary string if StringIO is used.

[1]:pcore-generic-data.md
