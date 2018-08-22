Pcore serialization
===
Pcore Serialization in contrast to the human readable [Pcore Generic Data Format][1] is
designed to make the best effort to produce a compact and "machine friendly" data stream
that can be processed by a streaming data format parser.
It does this by using a compact representation of values that performs deduplification
of complex data and by including up front counts for values containing sequences.

The Pcore Serializer has two levels - a *semantic* "higher level" that handles
values of all data types defined by and in Pcore, and a lower *intrinsic*
reader/writer level that handles the "on-the-wire" format. The lower level
is required to handle intrinsic values of the types
`Boolean`, `Undef`, `String`, `Integer`, and `Float`.
The lower level must also have a way to write extensions with a payload such
that extensions are distinct from intrinsic values.

Notably, both `Array` and `Hash` are handled as extensions because many
lower level formats have restrictions on keys in hashes and there needs to
be a way to encode extensions distinctly. For stream processing it is also beneficial
to know the count of elements up front as opposed having to wait until an entire sequence
is read before knowing the count.

As an example: in the JSON reader/writer provided with Pcore all extensions
are encoded as a JSON Array containing extension id, and payload.

Extensions
---
The following table shows the extensions used by Pcore Serialization and what the respective
extension's payload is. A payload of '-' means that the extension has no payload.

By design, there are no free extensions for user defined types as all reserved extensions are
for the future use of Pcore Serialization.

| Extension   | Token       | Payload
| ---         | ---         | ---
| 0x00 | INNER_TABULATION   | index
| 0x01 | TABULATION         | index
| 0x02 - 0x0F | *reserved*  |      
| 0x10 | ARRAY_START        | count of elements, sequence of each element
| 0x11 | MAP_START          | count of elements, sequence of elements' key, value pairs
| 0x12 | PCORE_OBJECT_START | type reference, count of given attributes, each attribute
| 0x13 | OBJECT_START       | count of given attributes, the type, each attribute
| 0x14 | SENSITIVE_START    | the sensitive value
| 0x15 - 0x1F | *reserved*  |
| 0x20 | DEFAULT            | -
| 0x21 | COMMENT            | the comment string
| 0x22 - 0x2F | *reserved*  |
| 0x30 | REGEXP             | the regexp in string form
| 0x31 | TYPE_REFERENCE     | type name
| 0x32 | *unused*           |
| 0x33 | TIME               | integer seconds, integer fraction in nanosec
| 0x34 | TIMESPAN           | integer seconds, integer fraction in nanosec
| 0x35 | VERSION            | the version in string form
| 0x36 | VERSION_RANGE      | the version range in string form
| 0x37 | BINARY             | the binary in binary form (only for binary lower level)
| 0x38 | BASE64             | a binary in base64 form (only for textual lower level)
| 0x39 | URI                | the URI in string form
| 0x3A - 0xFF | *reserved*  |


INNER TABULATION
---
Inner tabulation is provided by the reader/writer. It tabulates all strings, and if a string
has already been written (and thereby given an index) the output will
then contain:

```
  INNER_TABLUATION <it-idx>
```

Note that only String values are tabulated as it would be worse to tabulate
numerical values, booleans and undef/null than including them as is.

TABULATION
---
Tabulation of non intrinsic values are performed by the semantic layer. It will tabulate all
complex values such that if a value has already been written (and therefore given an index)
the output will then contain:

```
  TABULATION <t-idx>
```

OBJECT_START vs. PCORE_OBJECT_START
---
All values that are instances of a type in the `Pcore::` name space (i.e. in the type system
itself), and all object values when serializing "by reference" produce `PCORE_OBJECT_START`
with a payload of type in puppet language string form and count of attributes with serialized
values followed by the serialized attributes.

When serializing with "by reference" set to `false`, then values of non `Pcore::` name spaced types
produce `OBJECT_START` with a payload of attribute count followed by the serialized type, and then the value's serialized attributes.


[1]:pcore-generic-data.md
