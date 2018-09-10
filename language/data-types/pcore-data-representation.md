Pcore Data Representation
===
Puppet's type system (Pcore) has two kinds of data representation (in addition to being able to describe data in the Puppet Programming Language itself).

* [Pcore Generic Data][1] - As a programming language specific but generic data structure (that can then be
  serialized using a technology of choice for that programming language).
* [Pcore Serialization][2] - As a Pcore specific encoding using either a textual or binary "on the wire" format.

Important Note about Circular Data
---
Regular data in Puppet is never circular since to all values are immutable and thus making it
impossible to create such a structure. This means that care must be taken in custom Ruby logic
that is integrated with Puppet to ensure that such custom logic does not return circular data.

While regular data in Puppet cannot be circular, definitions of data types can be. Consider
the type `type StringTree = Array[Variant[String, StringTree]]` - when this type is serialized
(as opposed to a serialization of a value of this type) it clearly needs to be able to
refer back to itself recursively.

There are features in Pcore data representation to handle circular type definitions. Either:

* with "type_by_reference = true" makes references to data types be by name and
  deserialization resolves names to loadable types available when deserializing.
* with "type_by_reference = false" the definitions of the referenced types are included
  in the serialized result and deserialization adds the included type definitions
  to the set of available types in the deserializing environment.
* When there is a circular type definition, a reference is used with a "back pointer"
  expressed as a [JSON path expressions][4].  

See [Pcore Ruby Data API][3] for more information about these features.

Pcore Generic Data
---
Converting data in memory created by a programming language into a generic representation in
that programming language makes it easy to then handle serialization and deserialization
and to mix such serialization with other generic serializations. An advantage of this format
is that the result is humanly readable and that it can be both read and written generically
(without having to have an implementation of pcore serialization). See [Pcore Generic Data][1]
for the specification of this format. This is the format known as "rich data" that is used by
for example, a serialized Puppet Catalog.

The Ruby API for Pcore Generic Data transformation produces a `Hash` that can be transformed
to JSON, YAML or other formats, and transformed back to runtime objects from such a deserialized
`Hash`.

Pcore Serialization
---
The Pcore specific serialization support produces more compact and efficient output
but sacrifices human readability. See [Pcore Serialization][2] for the specification of this format.
While specific to Pcore, the currently available
on-the-wire formats (encodings) are however chosen such that they can be generically
read and written by most programming languages (e.g. by using JSON for textual representation,
and MsgPack for binary), but requires an implementation of Pcore to transform to/from
semantic data values as portions of the serialized data may be opaque.

The Ruby API for Pcore Serialization typically transforms to/from some kind of IO.

[1]:pcore-generic-data.md
[2]:pcore-serialization.md
[3]:pcore-ruby-data-api.md
[4]:http://goessner.net/articles/JsonPath/index.html#e2
