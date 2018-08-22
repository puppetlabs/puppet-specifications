
Pcore values as Generic Data
====
Pcore's Generic Data transformation transforms data such that
it complies with the Pcore `Data` type; a type that is constrained to only match
values that can be directly encoded in JSON. This document specifies this format.

| Pcore Type | Is Represented as |
| ---        | ---               |
| `Numeric`, `String`, `Boolean` | corresponding JSON data type (see below for details)|
| `Undef` | JSON `null` |
| `Array` | JSON array |
| a `Hash` =~ `Data` | JSON Object (Hash) |
| a `Hash` !~ `Data` | Pcore Object representation of a Hash as JSON Object |
| `Runtime` | Runtime values that are not Pcore values cannot be represented |
| all other | Pcore Object representation as JSON Object |

A `Numeric` value (`Integer` and `Float`) are represented by their
corresponding Ruby runtime types. When converted to JSON there is only one
numeric JSON datatype and the resulting deserialized data type is determined
by the deserializer and the language runtime. As an example, JavaScript does
not have a distinction between integers and floating point values, and will also
lose precision in integers because they are represented as floating point in a
JavaScript runtime.

A `Hash` value requires special treatment if it has keys that are illegal in JSON.
(JSON only allows keys that are Strings whereas Pcore allows almost any value
as a key). The alternative form is to encode such a "rich hash" as a Pcore Object
with the hash entries encoded as an array of alternating key, value entries.

A `Runtime` value is a representation of a runtime programming language value
that is not described by any other Pcore data type. It exists primarily to be able to
map Pcore data types to runtime types, and to capture and report such "alien" values.
An implementation of conversion to a Generic Data Hash can make a best effort to
convert (for example by using a "to string" representation) but must at all times
at least produce a warning. For typical use it is recommended to make the conversion
such that an error is raised when encountering a `Runtime` value.

All other values are represented as Pcore Objects. A Pcore Object is represented as
a `Hash` with the special key `__ptype` mapped to the data type name in `String`
form.

Then there are three cases for the value(s) of a data type:

* If the value is of a data type that is specified to have a single `String` value representation,
  then the hash will have the key `__pvalue` set to the values string representation.
* If the value is completely defined by the type (like the `Default` data type), there
  is no `__pvalue` key.
* Otherwise, the attributes of the value are encoded as additional key/value entries
  in the same hash.

### Examples

**A Regular Expression**

```puppet
/.*/
```

is converted to:

```json
  {
    "__ptype": "Regexp",
    "__pvalue": ".*"
  }
```

**A Timestamp**

```puppet
Timestamp()
```

is converted to (or rather was converted to when this was written as Timestamp() means "now"):

```json
  {
    "__ptype": "Timestamp",
    "__pvalue": "2018-08-20T12:07:15.710381000 UTC"
  }
```

**A default value**

```puppet
default
```

is converted to:

```json
  {
    "__ptype": "Default",
  }
```

**An Array**

```puppet
[1, 2, 3]
```

is converted to:

```json
  [
    1,
    2,
    3
  ]
```

**A Hash =~ Data**

```puppet
{ a => 10, b => 20}
```

is converted to:

```json
  {
    "a": 10,
    "b": 20
  }
```

**A Hash !~ Data**

```puppet
{ 10 => a, 20 => b}
```

is converted to:

```json
  {
    "__ptype": "Hash",
    "__pvalue": [
          10, "a",
          20, "b"
        ]
  }
```

**All values that are of Object Type**

```puppet
type Car = Object[
  attributes => {
    regnbr => String,
    color => String
  }
]
Car("abc123", "red")
```

is converted to:

```json
  {
    "__ptype": "Car",
    "regnbr": "abc123",
    "color": "red"
  }
```
