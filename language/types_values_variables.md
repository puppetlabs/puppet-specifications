Types, Values, and Variables
===
The Puppet Programming Language is a dynamically typed language, which means that the
type of values are not in general known until *runtime* (when the program logic is evaluated).

The Puppet Programming Language has a type system as well as operations on types.

The Kinds of Types and Values
---
There are two kinds of types in the Puppet Programming Language; *Puppet Types*, and the types of the underlying runtime "platform" language - the *Platform Types*.

Many of the types in the type system are *Parameterized Types* which means that a *Base Type* can be further specialized.

When describing types, the term **assignability** (in different forms) is used to describe the relationship between two types such that
a type T is assignable from a type T2 if all possible values having type T2 are also values of type T. This can also be expressed as
"a type T2 is assignable to a type T", or "T accepts T2" (as a short form of "A variable typed T accepts an assignment of a value of
type T2"). As an example we can say; "The type ´Numeric´ is assignable from the type ´Integer´".

### Platform Types

At present, the only existing implementation of the
Puppet Language is written in Ruby, but there may be other implementations in the future. In general,
the ability to refer to platform types is to allow configuration of a runtime, and handle
references to concepts such as plugins. **Regular Programs in the Puppet Programming Language
do not make use of the platform types**.

A Platform type is a *Parameterized Type* taking two parameters; the name of the type (currently only `Ruby`), and a reference to the *type name in the platforms type system* encoded as a Puppet String.

As an example, if there is a puppet extension written in Ruby with the name `Puppetx::MyModule::MyClass`, the platform type is `Runtime['Ruby', 'Puppetx::MyModule::MyClass']`.

### The Undef Type

There is a special undefined/null/nil type - called `Undef`; the type of the expression `undef`.

A value of `Undef` type is assignable to any other *optional* type with the meaning *it is allowed to have no value*.
This is achieved by using the type `Optional[T]` instead of just the type `T`, by using `Any` to accept anything,
or using `Data` to accept a pre-defined set of data types (including `Undef`), or using a `Variant` where one of the
accepted types accepts an `Undef` value.


### The Default Type

The type of the expression `default` is `Default`. The `Default` type is used to signal special behavior for various expressions in the language.

### Puppet Types

Puppet Types include the types that are meaningful in a Puppet Program - these are divided into
the conceptual categories **Data Types** e.g.:

*  `Integer`
*  `Float`
*  `Boolean`
*  `String`
*  `Array`
*  `Hash`
*  `Undef`

**Scalar Types** e.g.:
*  `Integer`
*  `Float`
*  `Boolean`
*  `String`
*  `Regexp`
*  `SemVer`
*  `Timespan`
*  `Timestamp`

**Catalog Types** e.g.:

* `Resource`
* `Class`

**Abstract Types** e.g.:

* `Any`; the parent type of all types
* `CatalogEntry`; the parent type of all types that are included in a *Puppet Catalog*
* `Collection`; a parent type of `Array` and `Hash`
* `Data`; a parent type of all data directly representable as JSON
  (alias for `Variant[Undef, ScalarData, Array[Data], Hash[String, Data]]`)
* `Enum`; an enumeration of strings
* `Iterator`; a special kind of lazy `Iterable` suitable for chaining
* `NotUndef`; a type that represents all types not assignable from the `Undef` type
* `Numeric`; the parent type of all numeric data types (`Integer`, `Float`)
* `Optional`; either `Undef` or a specific type
* `Pattern`; an enumeration of regular expression patterns
* `RichData'`; a parent type of all data types except the non serializeable types `Callable`, `Iterator`, `Iterable`, and `Runtime`
* `Scalar`; the same as `Variant[ScalarData, Regexp, SemVer, Timespan, Timestamp]`
* `ScalarData`; a parent type of all single valued data types that are directly representable in JSON
  (alias for `Variant[Integer, Float, String, Boolean]`)
* `SemVerRange`; a range of `SemVer` versions
* `Struct`; a Hash where each entry is individually named and typed
* `Tuple`; an `Array` where each slot is typed individually
* `Variant`; one of a selection of types
* `Iterable`; a type that represents all types that allow iteration

(The term *abstract* denotes that instances of such a type are always an instance of some other
*concrete* type).

and **Platform Types**:

* `Callable`; something that can be called (function, lambda)
* `Default`; the "default value" type
* `Runtime`; the type of runtime (non Puppet) types
* `Sensitive`; a type that represents a data type that have "clear text" restrictions
* `Type`; the type of types
* `Undef`; the "no value" type


All types are organized into one *Type System*.

The conceptual categories shown above are for documentation purposes (e.g. there is no type
in the type system called "DataType"), and to establish names for these categories that can be used
when talking about types.

Optional Typing
---
Typing is optional. When something is not typed, it has the type `Any`.

Type Aliases
---
It is possible to create type aliases in the Puppet Programming Language. An aliased type is
indistinguishable from the original type.

~~~
type MyInteger = Integer
~~~

Recursive Types
---
It is possible to create type aliases for recursive types. An alias definition may refer to itself.

~~~
type IntegerTree = Array[Variant[Integer, IntegerTree]]
~~~

For more details see the type alias expression.

The Type System
===============

A type is denoted by an upper cased bare word; e.g. `Integer` (an integer value) optionally followed
by one or more type parameters enclosed in square brackets `[]`, e.g. `Integer[1,10]` (integer values
1 to 10 inclusive), or `Array[String[1]]` (an array of non empty strings). See the description of each
type for the available type parameters.

The type hierarchy is shown in the figure below. (A single capital letter denotes a
reference to a type, lower case type parameters have special processing rules as shown
in section specific to each type). Note that a type supporting parameters also may be referenced
without any parameters, in which case type specific rules apply. Also note that the same type
may appear more than once in the hierarchy (e.g. a `ScalarData` is both `Scalar` and `Data`).

     Any
       |- Scalar
       |  |- ScalarData
       |  |  |- Numeric
       |  |  |  |- Integer[from, to]
       |  |  |  |  |- (Integer with range inside another Integer)
       |  |  |  |- Float[from, to]
       |  |  |  |  |- (Float with range inside another Float)
       |  |  |
       |  |  |- String[from, to]
       |  |  |  |- Enum[*strings]
       |  |  |  |  | - (narrower Enum - a subset of options)
       |  |  |  |- Pattern[*patterns]
       |  |  |  |  | - (Enum with all options matching pattern)
       |  |  |
       |  |  |- Boolean
       |  |
       |  |- Regexp[pattern_string]
       |  |- SemVer
       |  |- Timespan
       |  |- Timestamp
       |
       |- SemVerRange
       |- Collection
       |  |- Array[T, from, to]
       |  |  |- Tuple[*types, from, to]
       |  |- Hash[K, V, from, to]
       |  |  |- Struct[{ key => T, ...}]
       |
       |- Variant[*types]
       |- Optional[type]
       |- NotUndef[type]
       |
       |- Iterator[type]
       |- Iterable[type]
       |  |- String
       |  |- Array[type]
       |  |- Hash[type]
       |  |- Type[Integer[from,to]]
       |  |- Type[Enum[*strings]]
       |  |- Iterator[type]
       |
       |- CatalogEntry
       |  |- Resource[type_name, title]
       |  |- Class[class_name]
       |
       |- Undef
       |- Data
       |  |- ScalarData
       |  |- Undef
       |  |- Array[Data]
       |  |- Hash[String, Data]
       |
       |- RichData
       |  |- Default
       |  |- Object
       |  |- Scalar
       |  |- SemVerRange
       |  |- Sensitive
       |  |- Type
       |  |- Undef
       |  |- Array[RichData]
       |  |- Hash[RichData, RichData]
       |
       |- Callable[signature...]
       |- Default
       |- Object[specification...]
       |- Runtime[runtime_name, class_name]
       |- Sensitive[T]
       |- Type[T]
       |- TypeSet[specification...]

In addition to these types, a Qualified Reference that does not represent any of the other types is an alias for `Resource[the_qualified_reference]` (e.g. `File` is shorthand notation for `Resource[File]` / `Resource[file]`).

The descriptions use [Set Algebra Notation][1] to describe properties / operations on types.

[1]: intro.md#set-algebra-notation

Runtime Types
---

An implementation of the Puppet Language is allowed to make efficient use of the underlying
runtime and may choose to represent instances of puppet types using
instances of types
in the platform language's type system. In these cases, it is allowed to map these types
directly to the puppet type system.

### Ruby Object to Type Mapping

The Ruby implementation of the Puppet Programming Language uses the Ruby classes `String`, `Integer` (in some versions subclasses thereof, etc), `Float`, `Hash`, `Array`, `Regexp`, `TrueClass`, `FalseClass`, `NilObj`. Instances of these Ruby types are directly mapped to the corresponding puppet types (e.g. even if an instance of a puppet `String` is an instance of the Ruby class called `String`, it is not interpreted as `Runtime['Ruby', 'String']`.

The catalog types are mapped to their corresponding runtime implementation in Ruby.

### Runtime['Ruby', T]

Represents a type in the platform's type system (currently only 'Ruby'). The type parameter T
must be of `String` type and contain a valid string representation of the Ruby type. The referenced type does not have to exist; it is still a reference to a type (albeit a currently not existing type). The type must exist when operations are performed on the type (i.e. it must be loadable).

An Runtime['Ruby'] type without a type name represents all/any Ruby runtime types.

### Any

Represents the abstract type "any instance".

#### Type Algebra on Any

    Any ∪ Any        → Any
    Any ∪ (T != Any) → Any

### Undef

Represents the notion of "missing value". `Undef` is the type of the expression `undef`.

Values of the `Undef` type can always undergo a widening reference conversion to any other type. The reverse is however not true; only the value `undef` has the type `Undef`.

In practice, to accept a typed value that may be `Undef`, an `Optional[T]`, or `Variant[Undef, T]`
must be used.

#### Type Algebra on Undef

    Undef ∪ Undef          → Undef
    Undef ∪ (T ∉ Undef)    → Any

### Data

Represents the abstract notion of "concrete JSON data". It is an alias for `Variant[ScalarData, Array[Data], Hash[String, Data], Undef]`
Note that a hash element key must be `String`.

#### Type Algebra on Data

    Data ∪ Data                 → Data
    Data ∪ Numeric              → Data
    Data ∪ String               → Data
    Data ∪ Array[Data]          → Data
    Data ∪ Hash[String, Data]   → Data
    Data ∪ Undef                → Data
    Data ∪ (T ∉ Data)           → Any

### RichData

Represents the abstract notion of "serializeable" and includes all the types in the type system except
`Runtime`, `Callable`, `Iterator` and `Iterable`. It is expressed as an alias o
`Variant[Default, Object, Scalar, SemVerRange, Type, Undef, Array[RichData], Hash[RichData, RichData]]`)

### ScalarData

Represents a restricted set of "value" data types that have concrete direct representation in JSON.
`ScalarData` is an alias for `Variant[Integer, Float, String, Boolean]`.

### Scalar

Represents the abstract notion of "value", its subtypes are `Numeric`, `String` (including subtypes
`Pattern`, and `Enum`), `Boolean`, `Regexp`, `TimeStamp`, `TimeSpan`, and `SemVer`.

#### Type Algebra on Scalar

    Scalar ∪ Scalar          → Scalar
    Scalar ∪ (T ∈ Scalar)    → Scalar
    Scalar ∪ (T ∉ Scalar)    → Any

### Numeric

Represents the abstract notion of "number", its subtypes are `Integer` and `Float`.

#### Type Algebra on Numeric

    Numeric ∪ Numeric          → Numeric
    Numeric ∪ (T ∈ Numeric)    → Numeric
    Numeric ∪ (T ∈ Scalar)     → Scalar
    Numeric ∪ (T ∉ Scalar)     → Any

#### Numeric.new

Since version 4.5.0

A new `Integer` or `Float` can be created from `Integer`, `Float`, `Boolean` and
`String` values.

~~~ puppet

Callable[Variant[Numeric, Boolean, String]]

~~~

* If the value has a decimal period, or if given in scientific notation
  (e/E), the result is a `Float`, otherwise the value is an `Integer`.
* The conversion from `String` always uses a radix based on the prefix of the string.
* Conversion from Boolean results in 0 for `false` and 1 for `true`.

Example Converting to Numeric

~~~ puppet

$a_number = Numeric(true)    # results in 1
$a_number = Numeric("0xFF")  # results in 255
$a_number = Numeric("010")   # results in 8
$a_number = Numeric("3.14")  # results in 3.14 (a float)

~~~

### Integer ([from, to])

Represents a range of integral numeric value. The default is the range MIN INTEGER to MAX INTEGER.

An Integer value is a signed 64 bit integral value in the range MIN INTEGER=-2^63
and MAX INTEGER=2^63-1.

**Note: while the Puppet runtime implemented in Ruby may make use of BigInt to represent
values outside of this range, such values cannot correctly be represented in catalogs and
Puppet db.**

The `Integer` type can optionally be parameterized with `from`, `to` values to provide a range.
The range must be *ascending*.

If `from` is unassigned, the default is MIN INTEGER, and if `to` is unassigned, the default is MAX INTEGER.

From the Puppet Language, the default values are set by using a literal `default`. If only one
parameter is given, it is taken as both `from` and `to`, (thus producing a range of one value).
The `from` and `to` are inclusive. It is not possible to create an empty range (such construct,
if allowed would represent the set of all integers that are not integers, which would make it
a paradox).

Examples:

     Integer[0, default]   # All positive (or 0) integers
     Integer[1, default]   # All positive integers
     Integer[default, 0]   # All negative (or 0) integers
     Integer[default, -1]  # All negative integers

When performing tests in the Puppet Programming Language, a range inside of another is
considered to be less than the wider range (i.e. a subset of). They are equal if, and only
if the lower and upper bounds are equal.

     Integer[1,10] > Integer[2,3]   # => true
     Integer[1,10] == Integer[2,3]  # => false (they are not equal)
     Integer[1,10] > Integer[0,5]   # => false (overlap)
     Integer[1,10] > Integer[1,10]  # => false (not a subset, they are equal)
     Integer[1,10] >= Integer[1,10] # => true (they are equal)
     Integer[1,10] == Integer[1,10] # => true (they are equal)

Testing value against range:

     $value =~ Integer[1,10]

     $value ? { Integer[1,10] => true }

     case $value {
       Integer[1,10] : { true }
     }

Iterating over an integer range:

     Integer[1,5].each |$x| { notice $x } # => notices 1,2,3,4,5

     Integer[0, default].each |$x| { notice $x } # error, unbound range (infinite)

#### Type Algebra on Integer

    Integer ∪ Integer               → Integer
    Integer ∪ Float                 → Numeric
    Integer ∪ Numeric               → Numeric
    Integer ∪ (T ∈ Scalar)          → Scalar
    Integer ∪ (T ∉ Scalar)          → Any
    Integer[a, b] ∪ Integer[c, d]   → Integer[min(a, c), max(b,d)]

#### Integer.new

Since version 4.5.0

A new `Integer` can be created from `Integer`, `Float`, `Boolean`, and `String` values.
For conversion `from` String it is possible to specify the radix.

| Radix Name      | Base   | Prefixes    |
| ---             | ---    | ---         |
| binary          |  2     | `0b` `0B`   |
| octal           |  8     | `0`         |
| decimal         | 10     | *no prefix* |
| hexadecimal     | 16     | `0x` `0X`   |

Signature:

~~~ puppet

type Radix = Variant[Default, Integer[2,2], Integer[8,8], Integer[10,10], Integer[16,16]]
type 'NamedArgs   = Struct[{from => Convertible, Optional[radix] => Radix}]'
Callable[Variant[String, Numeric, Boolean] Radix, 1, 2]
Callable[NamedArgs]

~~~

* When converting from `String` the default radix is 10
* If radix is not specified or set to `default` an attempt is made to detect the radix by
  matching the radix prefix against the start of the string.
  Strings without such a prefix are decimal.
* Conversion from `String` accepts an optional sign in the string.
* When radix is 2, 8, or 16, the conversion accepts an optional leading corresponding radix prefix.
* Conversion from `Boolean` results in 0 for `false` and 1 for `true`.
* Radix is only applicable to `String` conversion, and is ignored for all others.
* `Float` value fractions are truncated (no rounding)

Example Converting to Integer

~~~ puppet

$a_number = Integer("0xFF", 16)  # results in 255
$a_number = Numeric("010")       # results in 8
$a_number = Numeric("010", 10)   # results in 10
$a_number = Integer(true)        # results in 1
$a_number = Numeric("0x10", 10)  # this is an error. Prefix and radix does not match.

~~~

### Float ([from, to])

Represents a range of *inexact* real number values. The default is the range +/- Infinity.

A float is an *inexact* real number using the native architecture's double precision floating
point representation. In contrast to `Integer`, operations on `Float` can cause the result to be negative or positive *Infinity* (i.e. it loses precision to the point where there is no value digits left). This is treated as an error in the Puppet Programming Language (it can be observed by dividing a floating point value with 0).

A `Float` range behaves as an `Integer` range and accepts both integer, and float values when
specifying the range. It is however, not possible to iterate over a `Float` range.

You can learn more about floating point than you ever want to know from these articles:

* docs.sun.com/source/806-3568/ncg_goldberg.html
* wiki.github.com/rdp/ruby_tutorials_core/ruby-talk-faq#wiki-floats_imprecise
* en.wikipedia.org/wiki/Floating_point#Accuracy_problems

#### Type Algebra on Float

    Float ∪ Float               → Float
    Float ∪ Integer             → Numeric
    Float ∪ Numeric             → Numeric
    Float ∪ (T ∈ Scalar)        → Scalar
    Float ∪ (T ∉ Scalar)        → Any
    Float[a, b] ∪ Float[c, d]   → Float[min(a, c), max(b,d)]

#### Float.new

Since version 4.5.0

A new `Float` can be created from `Integer`, `Float`, `Boolean`, and `String` values.
For conversion from `String` both float and integer formats are supported.

* For an integer, the floating point fraction of .0 is added to the value.
* A boolean `true` is converted to 1.0, and a `false` to 0.0
* In `String` format, integer prefixes for hex and binary radix are understood (but not octal since
  floating point in string format may start with a '0').

### Timespan ([from, to])

Since version 4.8.0

Represents a range of timespan values. The default is the range +/- Infinity.

A timespan is an duration, measured in seconds, with nanosecond precision.

A `Timespan` range behaves as an `Integer` range and accepts integer, float, or timespan values when
specifying the range. It is however, not possible to iterate over a `Timespan` range.

#### Type Algebra on Timespan

    Timespan ∪ Timespan            → Timespan
    Timespan ∪ Numeric             → Scalar
    Timespan ∪ (T ∈ Scalar)        → Scalar
    Timespan ∪ (T ∉ Scalar)        → Any
    Timespan[a, b] ∪ Timespan[c, d]   → Timespan[min(a, c), max(b,d)]

#### Timespan.new

A new `Timespan` can be created from `Integer`, `Float`, `String`, and `Hash` values. Several variants of the constructor are provided.

##### Timespan from seconds

When a Float is used, the decimal part represents fractions of a second.

```puppet
function Timespan.new(
  Variant[Float, Integer] $value
)
```

##### Timespan from days, hours, mintues, seconds, and fractions of a second

The arguments can be passed separately in which case the first four; days, hours, minutes, and seconds are mandatory and the rest are optional.
All values may overflow and/or be negative. The internal 128-bit nanosecond integer is calculated as:

```
(((((days * 24 + hours) * 60 + minutes) * 60 + seconds) * 1000 + milliseconds) * 1000 + microseconds) * 1000 + nanoseconds
```

```puppet
function Timespan.new(
  Integer $days, Integer $hours, Integer $minutes, Integer $seconds,
  Integer $milliseconds = 0, Integer $microseconds = 0, Integer $nanoseconds = 0
)
```

or, all arguments can be passed as a `Hash`, in which case all entries are optional:

```puppet
function Timespan.new(
  Struct[{
    Optional[negative] => Boolean,
    Optional[days] => Integer,
    Optional[hours] => Integer,
    Optional[minutes] => Integer,
    Optional[seconds] => Integer,
    Optional[milliseconds] => Integer,
    Optional[microseconds] => Integer,
    Optional[nanoseconds] => Integer
  }] $hash
)
```

##### Timespan from String and format directive patterns

The first argument is parsed using the format optionally passed as a string or array of strings. When an array is used, an attempt
will be made to parse the string using the first entry and then with each entry in succession until parsing succeeds. If the second
argument is omitted, an array of default formats will be used.

It's an error if no format was able to parse the given string.

```puppet
function Timespan.new(
  String $string, Variant[String[2],Array[String[2]], 1] $format = <default format>)
)
```

the arguments may also be passed as a `Hash`:

```puppet
function Timespan.new(
  Struct[{
    string => String[1],
    Optional[format] => Variant[String[2],Array[String[2]], 1]
  }] $hash
)
```

The directive consists of a percent (%) character, zero or more flags, optional minimum field width and
a conversion specifier as follows:
```
%[Flags][Width]Conversion
```

###### Flags:

| Flag  | Meaning
| ----  | ---------------
| -     | Don't pad numerical output
| _     | Use spaces for padding
| 0     | Use zeros for padding

###### Format directives:

| Format | Meaning |
| ------ | ------- |
| D | Number of Days |
| H | Hour of the day, 24-hour clock |
| M | Minute of the hour (00..59) |
| S | Second of the minute (00..59) |
| L | Millisecond of the second (000..999) |
| N | Fractional seconds digits |

The format directive that represents the highest magnitude in the format will be allowed to
overflow. I.e. if no "%D" is used but a "%H" is present, then the hours may be more than 23.

The default array contains the following patterns:

```
['%D-%H:%M:%S.%-N', '%H:%M:%S.%-N', '%M:%S.%-N', '%S.%-N', '%D-%H:%M:%S', '%H:%M:%S', '%D-%H:%M', '%S']
```

Examples - Converting to Timespan

```puppet
$duration = Timespan(13.5)       # 13 seconds and 500 milliseconds
$duration = Timespan({days=>4})  # 4 days
$duration = Timespan(4, 0, 0, 2) # 4 days and 2 seconds
$duration = Timespan('13:20')    # 13 hours and 20 minutes (using default pattern)
$duration = Timespan('10:03.5', '%M:%S.%L') # 10 minutes, 3 seconds, and 5 milliseconds
$duration = Timespan('10:03.5', '%M:%S.%N') # 10 minutes, 3 seconds, and 5 nanoseconds
```

### Timestamp ([from, to])

Since version 4.8.0

Represents a range of timestamp values. The default is the range +/- Infinity.

A timestamp is an moment in time, measured in seconds since epoch (1970-01-01 00:00:00 UTC), with nanosecond precision.

A `Timestamp` range behaves as an `Integer` range and accepts integer, float, or timestamp values when
specifying the range. It is however, not possible to iterate over a `Timestamp` range.

#### Type Algebra on Timestamp

    Timestamp ∪ Timestamp           → Timestamp
    Timestamp ∪ Numeric             → Scalar
    Timestamp ∪ (T ∈ Scalar)        → Scalar
    Timestamp ∪ (T ∉ Scalar)        → Any
    Timestamp[a, b] ∪ Timestamp[c, d]   → Timestamp[min(a, c), max(b,d)]

#### Timestamp.new

A new `Timestamp` can be created from `Integer`, `Float`, `String`, and `Hash` values. Several variants of the constructor are provided.

##### Timestamp from seconds since epoch (1970-01-01 00:00:00 UTC)

Without arguments, a Timestamp that represents the current time is created.

```puppet
function Timestamp.new()
```

When a Float is used, the decimal part represents fractions of a second.

```puppet
function Timestamp.new(
  Variant[Float, Integer] $value
)
```

##### Timestamp from String and patterns consisting of format directives

The first argument is parsed using the format optionally passed as a string or array of strings. When an array is used, an attempt
will be made to parse the string using the first entry and then with each entry in succession until parsing succeeds. If the second
argument is omitted, an array of default formats will be used.

It's an error if no format was able to parse the given string.

```puppet
function Timestamp.new(
  String $string, Variant[String[2],Array[String[2]], 1] $format = <default format>)
)
```

the arguments may also be passed as a `Hash`:

```puppet
function Timestamp.new(
  Struct[{
    string => String[1],
    Optional[format] => Variant[String[2],Array[String[2]], 1]
  }] $hash
)
```

The directive consists of a percent (%) character, zero or more flags, optional minimum field width and
a conversion specifier as follows:
```
%[Flags][Width]Conversion
```

###### Flags:

| Flag  | Meaning
| ----  | ---------------
| -     | Don't pad numerical output
| _     | Use spaces for padding
| 0     | Use zeros for padding
| #     | Change names to upper-case or change case of am/pm
| ^     | Use uppercase
| :     | Use colons for %z

###### Format directives (names and padding can be altered using flags):

*Date (Year, Month, Day):*

| Format | Meaning |
| ------ | ------- |
| Y | Year with century, zero-padded to at least 4 digits |
| C | year / 100 (rounded down such as 20 in 2009) |
| y | year % 100 (00..99) |
| m | Month of the year, zero-padded (01..12) |
| B | The full month name ("January") |
| b | The abbreviated month name ("Jan") |
| h | Equivalent to %b |
| d | Day of the month, zero-padded (01..31) |
| e | Day of the month, blank-padded ( 1..31) |
| j | Day of the year (001..366) |

*Time (Hour, Minute, Second, Subsecond):*

| Format | Meaning |
| ------ | ------- |
| H | Hour of the day, 24-hour clock, zero-padded (00..23) |
| k | Hour of the day, 24-hour clock, blank-padded ( 0..23) |
| I | Hour of the day, 12-hour clock, zero-padded (01..12) |
| l | Hour of the day, 12-hour clock, blank-padded ( 1..12) |
| P | Meridian indicator, lowercase ("am" or "pm") |
| p | Meridian indicator, uppercase ("AM" or "PM") |
| M | Minute of the hour (00..59) |
| S | Second of the minute (00..60) |
| L | Millisecond of the second (000..999). Digits under millisecond are truncated to not produce 1000 |
| N | Fractional seconds digits, default is 9 digits (nanosecond). Digits under a specified width are truncated to avoid carry up |

*Time (Hour, Minute, Second, Subsecond):*

| Format | Meaning |
| ------ | ------- |
| z   | Time zone as hour and minute offset from UTC (e.g. +0900) |
| :z  | hour and minute offset from UTC with a colon (e.g. +09:00) |
| ::z | hour, minute and second offset from UTC (e.g. +09:00:00) |
| Z   | Abbreviated time zone name or similar information.  (OS dependent) |

*Weekday:*

| Format | Meaning |
| ------ | ------- |
| A | The full weekday name ("Sunday") |
| a | The abbreviated name ("Sun") |
| u | Day of the week (Monday is 1, 1..7) |
| w | Day of the week (Sunday is 0, 0..6) |

*ISO 8601 week-based year and week number:*

The first week of YYYY starts with a Monday and includes YYYY-01-04.
The days in the year before the first week are in the last week of
the previous year.

| Format | Meaning |
| ------ | ------- |
| G | The week-based year |
| g | The last 2 digits of the week-based year (00..99) |
| V | Week number of the week-based year (01..53) |

*Week number:*

The first week of YYYY that starts with a Sunday or Monday (according to %U
or %W). The days in the year before the first week are in week 0.

| Format | Meaning |
| ------ | ------- |
| U | Week number of the year. The week starts with Sunday. (00..53) |
| W | Week number of the year. The week starts with Monday. (00..53) |

*Seconds since the Epoch:*

| Format | Meaning |
| s | Number of seconds since 1970-01-01 00:00:00 UTC. |

*Literal string:*

| Format | Meaning |
| ------ | ------- |
| n | Newline character (\n) |
| t | Tab character (\t) |
| % | Literal "%" character |

*Combination:*

| Format | Meaning |
| ------ | ------- |
| c | date and time (%a %b %e %T %Y) |
| D | Date (%m/%d/%y) |
| F | The ISO 8601 date format (%Y-%m-%d) |
| v | VMS date (%e-%^b-%4Y) |
| x | Same as %D |
| X | Same as %T |
| r | 12-hour time (%I:%M:%S %p) |
| R | 24-hour time (%H:%M) |
| T | 24-hour time (%H:%M:%S) |

The default array contains the following patterns:

```
['%FT%T.%L %Z', '%FT%T %Z', '%F %Z', '%FT%T.L', '%FT%T', '%F']
```

Examples - Converting to Timestamp

```puppet
$ts = Timestamp(1473150899)                              # 2016-09-06 08:34:59 UTC
$ts = Timestamp({string=>'2015', format=>'%Y'})          # 2015-01-01 00:00:00.000 UTC
$ts = Timestamp('Wed Aug 24 12:13:14 2016', '%c')        # 2016-08-24 12:13:14 UTC
$ts = Timestamp('Wed Aug 24 12:13:14 2016 PDT', '%c %Z') # 2016-08-24 19:13:14.000 UTC
```

### String([from, to])

Represents a sequence of Unicode characters up to a maximum length of 2^31-1 (the maximum
non negative 32 bit value).

The `String` type represents all strings. Abstract subtypes of String (`Enum`, `Pattern`) describes subsets matching an enumeration of strings, or those that match an enumeration of patterns
(regular expressions).

A `String` can be parameterized with a size constraint. One or two parameters can be used.
When one parameter is used, it is either an integer value describing the minimum number of
characters in the string, or it is an `Integer` range fully specifying the size range. When
two parameters are used they represent the from and to values as described for the `Integer`
range type.

    'abc' =~ String[1]   # true, has more than one character
    'abc' =~ String[1,2] # false, has more than two characters

    $size = Integer[1,2]
    'abc' =~ String[$size] # false, has more than 2 characters

Internally, when performing type inference, the `String` type is also parameterized to the set of
strings it represents - this has very little practical consequence in a Puppet Programs except
when the type system is used from Ruby logic.

Given the input:

     ['a', 'b', 'c']

The type is inferred to `Array[String]`, internally the String type also holds the values
['a', 'b', 'c']]`. This allows type calculations to assert:

     ['a', 'b', 'c'] =~ Array[Pattern['a-z']]  # true


#### Type Algebra on String

The commonality of two strings is the union of the two strings. The notation `String<a>` is
used to describe a String having the string content 'a'. This notation is used in this specification
only, it can not be used in the Puppet Programming Language.

    type_of([a,b,c])                 # => Array[String<a,b,c>]
    String<a,b,c> == String<b,c,a>   # => true
    typeof([String<a,b>, String<c>]) # => Array[Type[String<a,b,c>]]

    String    ∪ String     → String
    String<x> ∪ String<x>  → String<x>
    String<x> ∪ String<y>  → String<x,y>
    String    ∪ Enum       → String
    String<x> ∪ Enum[x]    → String<x>
    String    ∪ Pattern    → String
    String ∪ (T ∈ Scalar)  → Scalar
    String ∪ (T ∉ Scalar)  → Any

#### String.new

Since version 4.5.0

Conversion to String is the most comprehensive conversion as there are many
use cases where a String representation is wanted. The defaults for the many options
have been chosen with care to be the most basic "value in textual form" representation.

A new String can be created from all other data types. The process is performed in
several steps - first the type of the given value is inferred, then the resulting type
is used to find the most significant format specified for that type. And finally,
the found format is used to convert the given value.

The mapping from type to format is referred to as the format map. This map
allows different formatting depending on type.

Example: Positive Integers in Hexadecimal prefixed with '0x', negative in Decimal

~~~ puppet

$format_map = { 
  Integer[default, -1] => "%d",
  Integer[0, default] => "%#x"
}
String("-1", $format_map)  # produces '-1'
String("10", $format_map)  # produces '0xa'

~~~

A format is specified on the form:

~~~

%[Flags][Width][.Precision]Format

~~~

`Width` is the number of characters into which the value should be fitted. This allocated space is
padded if value is shorter. By default it is space padded, and the flag 0 will cause padding with 0
for numerical formats.

`Precision` is the number of fractional digits to show for floating point, and the maximum characters
included in a string format.

Note that all data type supports the formats `s` and `p` with the meaning "default string representation" and
"default programmatic string representation" (as an example, a String is quoted in 'p' format).

##### Signatures of String conversion

~~~ puppet

type Format = Pattern[/^%([\s\+\-#0\[\{<\(\|]*)([1-9][0-9]*)?(?:\.([0-9]+))?([a-zA-Z])/]
type ContainerFormat = Struct[{
  format         => Optional[String],
  separator      => Optional[String],
  separator2     => Optional[String],
  string_formats => Hash[Type, Format]
  }]
type TypeMap = Hash[Type, Variant[Format, ContainerFormat]]
type Formats = Variant[Default, String[1], TypeMap]

Callable[Any, Formats]

~~~

Where:
* `separator` is the string used to separate entries in an array, or hash (extra space should not be included at
  then end), defaults to `","`
* `separator2` is the separator between key and value in a hash entry (space padding should be included as
  wanted), defaults to `" => ".
* `string_formats` is a type to format map for values contained in arrays and hashes - defaults to `{Any => "%p"}`. Note that
  these nested formats are not applicable to containers which are always formatted as per the top level format specification.

Example Simple Conversion to String (using defaults)

~~~ puppet

$str = String(10)      # produces '10'
$str = String([10])    # produces '["10"]'

~~~

Example Simple Conversion to String specifying the format for the given value directly

~~~ puppet

$str = String(10, "%#x")    # produces '0x10'
$str = String([10], "%(a")  # produces '("10")'

~~~

Example Specifying type for values contained in an array

~~~ puppet

$formats = { Array => {format => '%(a', string_formats => { Integer => '%#x' } }
$str = String([1,2,3], $formats) # produces '(0x1, 0x2, 0x3)'

~~~

Given formats are merged with the default formats, and matching of values to convert against format is based on
the specificity of the mapped type; for example, different formats can be used for short and long arrays.

##### Integer to String

| Format  | Integer Formats
| ------  | ---------------
| d       | Decimal, negative values produces leading '-'
| x X     | Hexadecimal in lower or upper case. Uses ..f/..F for negative values unless + is also used. A `#` adds prefix 0x/0X.
| o       | Octal. Uses ..0 for negative values unless ´+´ is also used. A `#` adds prefix 0.
| b B     | Binary with prefix 'b' or 'B'. Uses ..1/..1 for negative values unless `+` is also used
| c       | numeric value representing a Unicode value, result is a one unicode character string, quoted if alternative flag # is used
| s       | same as d, or d in quotes if alternative flag # is used
| p       | same as d
| eEfgGaA | converts integer to float and formats using the floating point rules

Defaults to `d`.

Note that the notation `..0`, `..1`, `..f`, `..F` indicates that value is truncated at the number of known
value bits and that the actual leftmost bits depends on the physical representation (8, 16, 32, 64 bits). This because
negative values are in 2's complement format and have the highest order bit set to 1. Use the `+` flag to instead output
as negative value.

##### Float to String

| Format  | Float formats
| ------  | -------------
| f       | floating point in non exponential notation
| e E     | exponential notation with 'e' or 'E'
| g G     | conditional exponential with 'e' or 'E' if exponent < -4 or >= the precision
| a A     | hexadecimal exponential form, using 'x'/'X' as prefix and 'p'/'P' before exponent
| s       | converted to string using format p, then applying string formatting rule, alternate form # quotes result
| p       | f format with minimum significant number of fractional digits, prec has no effect
| dxXobBc | converts float to integer and formats using the integer rules

Defaults to `p`

##### Timespan to String

| Format  | Timespan formats
| ----    | ------------------
| s       | formats according to the timespan format string '%D-%H:%M:%S' 
| p       | programmatic representation - "Timespan(<quoted string>)" where <quoted string> is the result of using '%s' within quotes 
| dxXobB  | converts timespan to integer representing seconds and formats using the integer rules
| eEfgGaA | converts timespan to float representing seconds and fractions of second and formats using the floating point rules

A Timespan can also be formatted using the Puppet function `strftime()` and the format directives listed under **Timespan.new** 

##### Timestamp to String

| Format  | Timestamp formats
| ----    | ------------------
| s       | formats according to the timestamp format string '%FT%T.%L %Z' 
| p       | programmatic representation - "Timestamp(<quoted string>)" where <quoted string> is the result of using '%s' within quotes 
| dxXobB  | converts timestamp to integer representing seconds since epoch and formats using the integer rules
| eEfgGaA | converts timestamp to float representing seconds since epoch and fractions of second and formats using the floating point rules

A Timestamp can also be formatted using the Puppet function `strftime()` and the format directives listed under **Timestamp.new**

##### SemVer to String

| Format  | SemVer formats
| ----    | ------------------
| s       | \<major\>.\<minor\>.\<patch\>\[-\<prerelease\>\]\[+\<build\>\]
| p       | programmatic representation - "SemVer(<quoted string>)" where <quoted string> is the result of using '%s' within quotes 

##### SemVerRange to String

| Format  | SemVerRange formats
| ----    | ------------------
| s       | formatted according to [semver range specification](https://github.com/npm/node-semver)
| p       | programmatic representation - "SemVerRange(<quoted string>)" where <quoted string> is the result of using '%s' within quotes 

##### String to String

| Format | String
| ------ | ------
| s      | unquoted string, verbatim output of control chars
| p      | programmatic representation - strings are quoted, interior quotes and control chars are escaped
| C      | each :: name segment capitalized, quoted if alternative flag # is used
| c      | capitalized string, quoted if alternative flag # is used
| d      | downcased string, quoted if alternative flag # is used
| u      | upcased string, quoted if alternative flag # is used
| t      | trims leading and trailing whitespace from the string, quoted if alternative flag # is used

Defaults to `s` at top level and `p` inside array or hash.

##### Boolean to String

| Format    | Boolean Formats
| ----      | -------------------   
| t T       | 'true'/'false' or 'True'/'False' , first char if alternate form is used (i.e. 't'/'f' or 'T'/'F').
| y Y       | 'yes'/'no', 'Yes'/'No', 'y'/'n' or 'Y'/'N' if alternative flag # is used
| dxXobB    | numeric value 0/1 in accordance with the given format which must be valid integer format
| eEfgGaA   | numeric value 0.0/1.0 in accordance with the given float format and flags
| s         | 'true' / 'false'
| p         | 'true' / 'false'

##### Regexp to String

| Format    | Regexp Formats (%/)
| ----      | ------------------
| s         | / / delimiters, alternate flag replaces / delimiters with quotes
| p         | / / delimiters

##### Undef to String

| Format    | Undef formats
| ------    | -------------
| s         | empty string, or quoted empty string if alternative flag # is used
| p         | 'undef', or quoted '"undef"' if alternative flag # is used
| n         | 'nil', or 'null' if alternative flag # is used
| dxXobB    | 'NaN'
| eEfgGaA   | 'NaN'
| v         | 'n/a'
| V         | 'N/A'
| u         | 'undef', or 'undefined' if alternative # flag is used

##### Default value to String

| Format    | Default formats
| ------    | ---------------
| d D       | 'default' or 'Default', alternative form # causes value to be quoted
| s         | same as d
| p         | same as d

##### Array & Tuple to String

| Format    | Array/Tuple Formats
| ------    | -------------
| a         | formats with `[ ]` delimiters and `,`, alternate form `#` indents nested arrays/hashes
| s         | same as a
| p         | same as a

See "Flags" `<[({\|` for formatting of delimiters, and "Additional parameters for containers; Array and Hash" for
more information about options.

The alternate form flag `#` will cause indentation of nested array or hash containers. If width is also set
it is taken as the maximum allowed length of a sequence of elements (not including delimiters). If this max length
is exceeded, each element will be indented.

##### Hash & Struct to String

| Format    | Hash/Struct Formats
| ------    | -------------
| h         | formats with `{ }` delimiters, `,` element separator and ` => ` inner element separator unless overridden by flags 
| s         | same as h
| p         | same as h
| a         | converts the hash to an array of [k,v] tuples and formats it using array rule(s)

See "Flags" `<[({\|` for formatting of delimiters, and "Additional parameters for containers; Array and Hash" for
more information about options.

The alternate form flag `#` will format each hash key/value entry indented on a separate line.

##### Type to String

| Format    | Array/Tuple Formats
| ------    | -------------
| s         | The same as p, quoted if alternative flag # is used
| p         | Outputs the type in string form as specified by the Puppet Language

##### Flags

| Flag     | Effect 
| ------   | ------
| (space)  | space instead of + for numeric output (- is shown), for containers skips delimiters
| #        | alternate format; prefix 0x/0x, 0 (octal) and 0b/0B for binary, Floats force decimal '.'. For g/G keep trailing 0.
| +        | show sign +/- depending on value's sign, changes x,X, o,b, B format to not use 2's complement form
| -        | left justify the value in the given width
| 0        | pad with 0 instead of space for widths larger than value
| <[({\|   | defines an enclosing pair <> [] () {} or \| \| when used with a container type

### Enum[*strings]

Represents all strings that are equal to one of the string type parameters given to the `Enum` type.

Example:

     Enum['port', 'name', 'ip']

When matched against a `String` with a size constraint, all enumerated strings must comply with
the size constraint.

An `Enum` without any given parameters matches all other Enum, and thus matches all possible Strings.

When iterated over, an enum will present each unique value in lexiographical order.

#### Type Algebra

The commonality of two `Enum` types is the set operation enum | enum.

     type_of([Enum[a,b,c], Enum[x,b,c]] # => Array[Type[Enum[a,b,c,x]]

### Pattern[*patterns]

Represents all strings that match any of the given patterns (typically one pattern is used).
The type parameters can be a string expression, literal regular expressions, `Pattern` type,
or `Regexp` type (or a mix).

A `Pattern` without regular expressions matches all other Patterns, and thus matches all Strings
and all Enums.

Example:

     Pattern['.*']
     Pattern[/^all of me$/]

#### Type Algebra

The commonality of two Pattern types is the set operation pattern | pattern:

     type_of([Pattern[a], Pattern[b]]) # => Array[Type[Pattern[a,b]]]

### Boolean

The types of the boolean expressions `true` and `false`.

#### Boolean.new

Since version 4.5.0

Accepts a single value as argument:

* Float 0.0 is `false`, all other float values are `true`
* Integer 0 is `false`, all other integer values are `true`
* Strings
  * `true` if string is one of 'true', 'yes', or 'y' (case independent compare)
  * `false` if string is one of 'false', 'no', or 'n' (case independent compare)
* Boolean is already boolean and is simply returned

Examples of converting to Boolean:

~~~ puppet
$b2 = Boolean('true')  # true
$b2 = Boolean('false') # false
$b1 = Boolean('YEs')   # true
$b1 = Boolean(0)       # false

~~~

### Regexp[pattern]

An unparameterized `Regexp` describes the set of all regular expressions. A parameterized `Regexp`
describe the very narrow set of source expression identical regular expressions.

The type of a Regular Expression produced by a Literal Regular Expression:

     LiteralRegularExpression
       : '/' RegexpString '/'
       ;

A `Regexp` `Type` is created by:

     RegexpTypeExpression
       : 'Regexp' ('[' PatternStringExpression | LiteralRegularExpression ']')?
       ;

     PatternStringExpression<String> : Expression ;

See also Match Expression (`=~` and `!~`) for more usage of the `Regexp` type.

The syntax of the Regular Expression is defined by Ruby's implementation. Puppet's regular
expressions does not support options. If an attempt is made to specify options,
this will result in an error (e.g. `/.*/m`).

The result of `Regexp[pattern]` is a parameterized `Regexp` type that in certain operations
can be used instead of a literal regular expression.

If a non parameterized `Regexp` is used where a pattern is required, the pattern defaults to
the empty pattern `//`.

<table><tr><th>Note</th></tr>
<tr><td>
  The Puppet Programming Language may be given control over options and support \A and \Z in
  the future as it is unclear why this is not already supported. (The omission of these features
  makes it difficult to work with multi line strings and regular expression matching).
</td></tr>
</table>


#### Type Algebra on Regexp

    Regexp       ∪  Regexp         → Regexp
    Regexp[R]    ∪  Regexp[R]      → Regexp[R]
    Regexp[R]    ∪  Regexp[Q]      → Regexp
    Regexp[?]    ∪  (T ∈ Scalar)   → Scalar
    Regexp[?]    ∪  (T ∉ Scalar)   → Any

### SemVer[version-ranges]

Since Version 4.5.0

Represents all [Semantic Versions](http://semver.org/) which can be narrowed to a single specific
semantic version, or to a disjunct set of version ranges.

An instance of this type describes a single version.

The `SemVer` type is accompanied by the `SemVerRange` type which as a type represents all ranges
and which's instances represent a contiguous version range.

A `SemVer` type may be parameterized with one or more of:

* SemVer instances
* Strings representing single versions or ranges of versions
* SemVerRange instances representing a contiguous version range

An instance of `SemVer` can be created from a String, individual values, or a hash of individual values.

A SemVer instance consists of up to 5 segments:

* major version
* minor version
* patch (version)
* prerelease tag
* build tag

Examples

~~~ puppet

$t = SemVer[SemVerRange('>=1.0.0 <2.0.0'), SemVerRange('>=3.0.0 <4.0.0')]
notice(SemVer('1.2.3') =~ $t) # true
notice(SemVer('2.3.4') =~ $t) # false
notice(SemVer('3.4.5') =~ $t) # true

~~~


#### SemVer Type Algebra

* When type is inferred, adjacent and overlapping version ranges will be merged.
* When a parameterized SemVer is created, adjacent and overlapping version ranges will be normalized (merged)
* A SemVer instance matches a SemVerType if it is enclosed in one of the types ranges

#### SemVer.new

Signatures:

~~~
type PositiveInteger = Integer[0,default]
type SemVerQualifier = Pattern[/\A(?<part>[0-9A-Za-z-]+)(?:\.\g<part>)*\Z/]
type SemVerString = String[1]
type SemVerHash =Struct[{
  major                =>PositiveInteger,
  minor                =>PositiveInteger,
  patch                =>PositiveInteger,
  Optional[prerelease] =>SemVerQualifier,
  Optional[build]      =>SemVerQualifier
}]

function SemVer.new(SemVerString $str)
function SemVer.new(
        PositiveInteger           $major
        PositiveInteger           $minor
        PositiveInteger           $patch
        Optional[SemVerQualifier] $prerelease = undef
        Optional[SemVerQualifier] $build = undef
        )
function SemVer.new(SemVerHash $hash_args)
~~~

### SemVerRange

A SemVerRange represents all Semantic Version Ranges. New ranges an be constructed using `SemVerRange.new`.

The string format of a SemVerRang is specified by the [SemVer Range Grammar](https://github.com/npm/node-semver#range-grammar).
The logical or `||` operator is not supported in the Puppet Type System SemVerRange type.

#### SemVerRange Type Algebra

* A SemVerRange type matches all instances of SemVerRange
* SemVerRange < Any

#### SemVerRange.new

Signatures:

~~~ puppet

type SemVerRangeString = String[1]
type SemVerRangeHash = Struct[{
  min                   => Variant[default, SemVer],
  Optional[max]         => Variant[default, SemVer],
  Optional[exclude_max] => Boolean
}]

function SemVerRange.new( SemVerRangeString $semver_range_string)

function SemVerRange.new(
           Variant[default,SemVer] $min
           Variant[default,SemVer] $max
           Optional[Boolean]       $exclude_max = undef
         }

function SemVerRange.new(SemVerRangeHash $semver_range_hash)
~~~

### Array[V, from, to]

`Array` represents an ordered collection of elements of type `V`, optionally constrained in
size by the integer range parameters *from* and *to*. 

The first index in an array instance is a non negative integer and starts with 0.
(Operations in the Puppet Language allows negative values to be used to perform different calculations w.r.t index). See Array [] operation (TODO: REFERENCE TO THIS EXPRESSION SPEC).

The type of `V` is unrestricted.

When used without parameters, the default is `Array[Any]`.

An empty array is denoted with `Array[0, 0]`.
It is illegal to specify the element type for an empty array. An empty array is accepted by
any typed arraay that allows *from* to be 0.

#### Type Algebra on Array

    Array        ∪  Array         → Array
    Array[R]     ∪  Array[R]      → Array[R]
    Array[R]     ∪  Array[Q]      → Array[R ∪ Q]
    Array[R,a,b] ∪  Array[Q,c,d]  → Array[R ∪ Q, min(a,c), max(b,d)]
    Array[?]     ∪  Hash[?,?]     → Collection

#### Array.new

Since version 4.5.0

When given a single value as argument:

* A non empty `Hash` is converted to an array matching `Array[Tuple[Any,Any], 1]`
* An empty `Hash` becomes an empty array
* An `Array` is simply returned
* An `Iterable[T]` is turned into an array of `T` instances

When given a second Boolean argument
* if `true`, a value that is not already an array is returned as a one element array
* if `false`, (the default), converts the first argument as shown above.

Example ensuring value is array

~~~ puppet

$arr = Array($value, true)

~~~

### Hash[K, V, from, to]

`Hash` represents an ordered collection of associations between a key (of `K` type), and
a value (of `V` type), optionally constrained in size by the integer range parameters *from* and
*to*.

The types of `K` and `V` are unrestricted.

While the key is generally not restricted, it is recommended that `Undef` is not accepted
as a key (not accepting `Undef` is the default for hashes that conforms to the `Data` type).

The hash maintains the order of the entries so that iteration over the hash yields the entries
in the order they were inserted. When hashes are merged (using the `+` operator), the order of the keys
in the constructed hash have the same order as the LHS side keys, and the RHS keys not present in the LHS
are inserted at the end of the resulting hash in their RHS order.

* An unparameterized `Hash` is the same as `Hash[Any, Any]`
* An empty hash is denoted with `Hash[0, 0]`.
* It is illegal to specify the key and/or element type for an empty hash.
* An empty hash is accepted by any typed hash that allows *from* to be 0. 

#### Type Algebra on Hash

    Hash          ∪  Hash               → Hash
    Hash[K,V]     ∪  Hash[Q,W]          → Hash[K ∪ Q, V ∪ W]
    Hash[K,V,a,b] ∪  Hash[Q,W,c,d]      → Hash[K ∪ Q, V ∪ W, min(a,c), max(b,d)]
    Hash[?]       ∪  (T ∈ Collection)   → Collection
    Hash[?]       ∪  (T ∉ Collection)   → Any

#### Hash.new

Since version 4.5.0

Accepts a single value as argument:

* An empty `Array` becomes an empty Hash
* An `Array` matching `Array[Tuple[Any,Any], 1]` is converted to a hash where each tuple describes a key/value entry
* An `Array` with an even number of entries is interpreted as `[key1, val1, key2, val2, ...]`
* An `Iterable` is turned into an `Array` and then converted to Hash as per the array rules
* A `Hash` is simply returned

### Struct Type

The `Struct` type fully specifies the content of a `Hash`. The type is parameterized with a hash where each key must be a type from which a non empty string can be derived, and the values must be types.

Each key should be either a literal `key`, `NotUndef[key]` or `Optional[key]`.

A key in the form of a string literal will be converted into its corresponding `String` type. It becomes `Optional[key]` if the value type is assignable from `Undef`. This means that by default, keys are optional if their values are. An explicit `NotUndef` or `Optional` wrapper can be added to make the key behavior explicit.

When a `Struct` has a `NotUndef` key it will only accept a hash where this key is included. This applies even if the value type is optional (assignable from `Undef`). Conversely, if it has an
`Optional` key it will accept a hash where the key is excluded even if the value type doesn't accept `undef`.

Example 1. The hash must contain the keys mode and path, and mode must have a value that is one of the strings "read", "write", or "update", and the key path must have a `String` value that is at least 1 character in length.

    Struct[{mode=>Enum[read, write, update], path=>String[1]}]


Example 2. The key defaults to `Optional[article]` since `undef` is an instance of `Data`. An empty hash is hence an instance of this `Struct`.

    Struct[{article=>Data}]


Example 3. The key defaults to `NotUndef[article]` so a matching entry must be present in the hash and its value cannot be `undef`.

    Struct[{article=>NotUndef[Data]}]


Example 4. The 'article' entry must be present in the hash but the value can be `undef` since it is an instance of `Data`.

    Struct[{NotUndef[article]=>Data}]


Example 5. The 'article' entry is optional but when present its value cannot be `undef`.

    Struct[{Optional[article]=>NotUndef[Data]}]


A `Struct` type is compatible with a `Hash` type both ways, given that the constraints they express are met. A `Struct` is a `Collection`, but its size is controlled by the specified named entries
such that the `from` size is determined by the number of required keys and the `to` size corresponds to the total number of entries.

A hash that has keys not specified in the `Struct` will not match.

An unparameterized `Struct` matches all structs and all hashes.

#### Type Algebra on Struct

    Struct               ∪  Struct             → Struct
    Struct[T]            ∪  Struct[T]          → Struct[x]
    Struct[T]            ∪  Struct[S (S ∉ T)]  → Struct
    Struct[{s => T}]     ∪  Hash[K,V]          → Hash[String ∪ K, T ∪ V]
    Struct[?]            ∪  (T ∈ Collection)   → Collection
    Struct[?]            ∪  (T ∉ Collection)   → Any

#### Struct.new

Since version 4.5.0

`Struct.new` works exactly as `Hash.new`, only that the constructed hash is
asserted against the given struct type.

### Tuple Type

The `Tuple` type fully specifies the content of an `Array`. It is to `Array` what `Struct` is to `Hash`, with entries identified by their position instead of by name. A variable number of optional and trailing entries can also be specified.

    Tuple[T1, T2]                   # A tuple of exactly T1 and T2
    Tuple[T1, T2, 1]                # A tuple with a variable number of T2 (>= 0)
    Tuple[T1, T2, 1, 3]             # A tuple with a variable number of T2 (0-3 inclusive)
    Tuple[T1, 5, 5]                 # A tuple with exactly 5 T1
    Tuple[T1, 5, 10]                # A tuple 5 to 10 T1
    Tuple[T1, T1, T2, 1, 3]         # A tuple of one T1, two T1, or two T1 followed by one T2

All entries in the `Tuple` (except the optional size constraint min/max count) must be a type and denotes that there must be an occurrence of this type at this position. The tuple can be modified such that the min and max occurrences of the given types in the type sequence can be specified. The specification is made with one or two integer values or the keyword `default`. The min/max works the same way as for an `Integer` range. This way, if optional entries are wanted in the tuple the min is set to a value lower than the number of given types, and if the last type should repeat the max is given as a value higher than the number of given types. As an example, a size constraint entered as `Tuple[T, 0, 1]` means `T` occurs 0 or 1 time. If the max is unspecified, it defaults to infinity (which may also be spelled out with the keyword default).

     ["a", 1]     =~ Tuple[String, Integer]      # true
     ["a", 1,2,3] =~ Tuple[String, Integer, 1]   # true
     ["a", 1,2,3] =~ Tuple[String, Integer, 0]   # true
     ["a", 1,2,3] =~ Tuple[String, Integer, 0,2] # false
     ["a", 1,2,3] =~ Tuple[String, Integer, 4]   # true
     ["a", 1,2,3] =~ Tuple[String, Integer, 5]   # false

The `Tuple` type is a subtype of `Collection`. Its size is specified by the given sequence and the size constraint (which defaults to exactly the given sequence).

#### Type Algebra on Tuple

    Array[T] == Tuple[T,0,default]

    Tuple           ∪  Tuple           → Tuple
    Tuple[R, ...]   ∪  Tuple[S, ...]   → Tuple[R ∪ S, ...]

#### Tuple.new

Since version 4.5.0

Conversion to a `Tuple` works exactly as conversion to an `Array` (Array.new), only that the constructed array is
asserted against the given tuple type.


### Collection[to, from]

A Collection is the common type for `Array` and `Hash` (and subtypes `Tuple` and `Struct`), it may optionally be parameterized with a size constraint (`from` a min size to a `max` size). The `to` and `from` parameters
are the same as for an `Integer` range. The size constraint can also be specified with a
single `Integer` range parameter.

#### Type Algebra on Collection

    Collection  ∪  Collection    → Collection
    Collection  ∪  Array         → Collection
    Collection  ∪  Hash          → Collection

    [1,2,3]      =~ Collection[1,3]  # true, size >= 1 and <= 3
    {a=>1, b=>2} =~ Collection[3]    # false, size is < 3

### Variant[*types]

A `Variant` type represents a disjunct set of types. (Other terms used for this in other languages
are Discrimination Union, Disjoint Union, Variant Record, Tagged Union).

Examples:

    $array_of_numbers =~ Array[Variant[Integer[1000, 1999], Integer[10000, default]]]

which is true if all the numbers in an array of numbers are between 1000 and 1999 or >= 10000

#### Type Algebra on Variant

    Variant         ∪  Variant          → Variant
    Variant[*T]     ∪  Variant[*Q]      → Variant[*T | *Q]
    Variant[*T]     ∪  Q                → Variant[*T | Q]

    Variant[Optional[T]] == Variant[T, Undef] == Optional[Variant[T]] == Optional[T]

### Optional[T]

The `Optional` type is parameterized with a single type. It represents the given type or
Undef. An unparameterized `Optional` represents nothing.

The parameter can be a literal string in which case it is converted into its corresponding
`String` type.

#### Type Algebra on Optional

    Optional[T]  ∪  T            → T
    Optional[T]  ∪  Undef        → Optional[T]
    Optional[T]  ∪  Optional[R]  → Optional[T ∪ R]

#### Optional[T].new

Since version 4.5.0

Calling `new` on an `Optional[T]` is the same as calling `new` on `T` and then asserting that the result is `T` or `undef`.

### NotUndef[T]

The `NotUndef` type is parameterized with a single type. It represents all types assignable
to the given type except those that are assignable from the `Undef` type. An unparameterized
`NotUndef` is the same as `NotUndef[Any]`.

The parameter can be a literal string in which case it is converted into its corresponding
`String` type.

#### Type Algebra on NotUndef

    NotUndef[T]  ∪  T            → NotUndef[T]
    NotUndef[T]  ∪  Undef        → Variant[]
    NotUndef[T]  ∪  NotUndef[R]  → NotUndef[T ∪ R]

#### NotUndef[T].new

Since version 4.5.0

Calling `new` on a `NotUndef[T]` is the same as calling `new` on `T` and then asserting that the result is not `undef`.

### Iterable[T]

Since version 4.4.0.

The `Iterable` type represents all data types that can be iterated; i.e. that the value is some kind of container of individual values. The `Iterable` type is abstract in that it does not specify if it represents a concrete data type (such as `Array`) that has storage in memory, of if it is an algorithmic construct like a transformation function (e.g the `step()` function).

The `Iterable` type is of value when writing generic iterative functions. In the implementation of such functions it is almost always the type parameter `T` that is of interest, and often not even that, as the operation may be some shuffling around of abstract things that the function does not really care about. It is seldom the case that it matters if the source is an `Array`, a `Hash`, or some algorithmic transformation.

The Iterable types are:

* `String` => `Iterable[String]`; where each character in the string is produced as a string.
* `Array[T]` => `Iterable[T]`; where each element from index `0`, to index `n` is produced
* `Hash[K,V]` => `Iterable[Tuple[K,V]]`; - where each hash entry (key, value), in the order they were added to the hash, are produced. It is up to the iterative function to treat the values as a singe tuple, or as two separate values when yielding them to the next function in a chain of iterables.
* `Integer[n,n]` => `Iterable[Integer[0,n-1]]`; represents a "times" iteration from `0` up to `n - 1`.
* `Type[Integer[from, to]]` => `Iterable[Integer[from, to]`; represents the range of values `from -> to`, yielding each value in the range.
* `Type[Enum[*strings]]` => `Iterable[Enum[*strings]]`; yields each of the enum strings in the order they were specified in the `Enum` type.
* `Iterator[T]` => `Iterable[T]`; represents an algorithmic transformation of some source and yields a series of type `T` values.

For a value to be considered `Iterable` it must represent a bounded sequence of values. As an example `Integer[1,default]` represents all numbers from 1 to positive infinity and it can not be iterated.

### Iterator[T]

Since version 4.4.0.

The `Iterator` type is an `Iterable` that does not have a concrete backing data type holding a copy of the values it will produce when iterated over. It represents an algorithmic transformation of some source (which in turn can be algorithmic). When iterated it will produce values of type `T`.

An Iterator may not be assigned to an attribute of a resource, and it may not be used as an argument to a version 3.x functions. To create a concrete value an Iterator must be "rolled out" by using a function at the end of a chain that produces a concrete value.

Example 1; `step()` in combination with `reverse_each()`, and a `map()`

~~~
$array_of_numbers = [1, 2, 3]
$result = $array_of_numbers.reverse_each.step(2).map |$x| { $x * 100 }

~~~

Given Example 1, the value of `$result` would be `[300, 200, 100]`.

Note that, in each connection in the chain, there may either be a concrete value, the reverse_each could construct a new `Array` with the elements in reverse order, or it can produce an `Iterator`, that when a new value is pulled from the end of the chain (in the example by `map()`) will calculate which of the values is the next in reverse order, and produce that without requiring an intermediate `Array` to hold the values. View a chain of iterative functions like a pipe-line where values flow through the pipe. Contrast this with transport by tank truck where not a single drop will appear until the truck arrives with the full load.

An Iterator can be transformed to an `Array` by using the unary Unfold Operator (a.k.a splat).

~~~
$a = *[1,2,3].reverse_each
notice $a =~ Array
~~~

Will notice `true`.


### Catalog Entry

Represents the abstract notion of "something that is an entry in a puppet catalog". Its
subtypes are `Resource`, and `Class`.

<table><tr><th>Note</th></tr>
<tr><td>
  Stage may get its own type in a future specification.
</td></tr>
</table>

### Resource[type_name, *title]

Represents a *Puppet Resource* (a resource managed by Puppet).

The Resource type is parameterized by `type_name`, and optionally `title`(s).

* The `type_name` parameter can be an `Expression` evaluating to a `Resource` type, or a `String`
  containing the name of the resource type (case insensitive).

* The title type parameter is optional and multi valued. Each title is an `Expression` evaluating
  to a `String` representing the title of a resource.

* If no title is given, the result is a reference to the type itself; e.g. `Resource[File]`,
  `Resource['file']`, `Resource[file]` are all references to the puppet resource type called
  `"File"`.

* When a single title is given, the result is a reference to the singleton instance of the
  resource uniquely identified by the title string.

* When multiple titles are given, the result is an `Array[Resource[T]]`; e.g.
  `Resource[File, 'a', 'b']`  produces the array `[Resource[File, 'a'], Resource[File, 'b']]`.

#### Shorthand Notation

Any Qualified Reference that does not reference a known type is interpreted as a reference
to a `Resource` type. Thus `Resource[File]` and `File` are equivalent references.

The shorthand notated resource types supports type parameterization with title(s). These
are equivalent: `Resource[File, 'a', 'b']`, `File['a', 'b']`, they both produce an equivalent
array of two references - `File['a']` and `File['b']`.

#### Type Algebra on Resource

    Resource <= Resource[RT] <= Resource[RT, T]
    Resource[RT1]   != Resource[RT2]
    Resource[RT, T] != Resource[RT, T2]
    Resource[RT]    == RT
    Resource[RT, T] == RT[T]

    Resource        ∪  Resource            → Resource
    Resource[RT]    ∪  Resource[RT]        → Resource[RT]
    Resource[RT1]   ∪  Resource[RT2]       → Resource
    Resource[RT,T]  ∪  Resource[RT, T]     → Resource[RT, T]
    Resource[RT,T1] ∪  Resource[RT, T2]    → Resource[RT]
    Resource[?]     ∪  (T ∈ CatalogEntry)  → CatalogEntry
    Resource[?]     ∪  (T ∉ CatalogEntry)  → Any

### Class[*class_name]

Represents a Puppet (Host) Class. The `Class` type is parameterized with the name of
the class (`String`, or Qualified Name).

If multiple class names are given, an `Array` of parameterized `Class` types is produced.

<table><tr><th>Note</th></tr>
<tr><td>
  In 3x it is allowed to also use an upper case Resource reference e.g. <tt>Class[Baz]</tt>. This
  is currently supported in the new implementation. It should not if names are strict as this
  really means
  <tt>Class[Resource[Baz]]</tt>. <b>Discuss if this support should be removed</b>.
</td></tr>
</table>


### Class Inheritance

The type system does not treat (Host) Class inheritance as subtyping.

The reason for this is that if the type system were to do this, then classes need to be loaded in order for type operations to correctly answer if a class inherits another. There is a suspicion
that this may affect the result (logic may reference a class that should not be loaded because
it is used as a condition to load classes that are not present. Loading a class may also have other
side effects as it is not a pure load operation).

<table><tr><th>Note</th></tr>
<tr><td>
  Further work is needed to make a final decision. If the decision is made to keep it the way
  it is currently implemented, the user logic will need to check twice, or with a <tt>Variant</tt>
  (is it the subclass or the superclass); this since Puppet only supports one level deep inheritance.
</td></tr>
</table>


#### Type Algebra on Class

    Class > Class[c]
    Class       ∪  Class               → Class
    Class[c]    ∪  Class[c]            → Class[c]
    Class[c1]   ∪  Class[c2]           → Class
    Class[?]    ∪  (T ∈ CatalogEntry)  → CatalogEntry
    Class[?]    ∪  (T ∉ CatalogEntry)  → Any

### Type[T]

`Type` is the type of types. It is parameterized by the type e.g the type of `String` is `Type[String]`. Consequently, the type of `Type[String]` is `Type[Type[String]]`, and so on
until infinity.

#### Type Algebra on Type

    Type        ∪  Type                → Type
    Type        ∪  Type[T]             → Type
    Type[T]     ∪  Type[T]             → Type[T]
    Type[?]     ∪  (T ∉ Type)          → Any

### Callable[signature]

`Callable` is the type of callable elements; functions and lambdas. The `Callable` type
will typically not be used literally in the Puppet Language until there is support for
functions written in the Puppet Language.
`Callable` is of importance for those who write functions in Ruby and want to type
check lambdas that are given as arguments to functions in Ruby. They are also important
in error messages when communicating why a given set of arguments do not match a signature.

The signature of a `Callable` denotes the type and multiplicity of the arguments it accepts and consists of a sequence of parameters; a list of types, where the three last entries may optionally be min count, max count, and a `Callable` (which is taken as its block_type).

Since Puppet 4.7.0 a `Callable` can optionally describe a return type. When return type is something other than `Any`,
the signature consists of an array of parameters, followed by the return type such that `Callable[[Integer, 2, 2], Float]` is a
callable that takes two `Integer` parameters, and produces/returns a `Float`.

* If neither min or max are specified the parameters must match exactly.
* A min < size(params) means that the difference is optional.
* If max > size(params) means that the last type repeats until the given max cap number of arguments
* if max is literal `default`, the max value is unbound (+Infinity).
* If no types and no min/max are given, the Callable describes any callable i.e. `Callable[0, default]` (i.e. no type constraint, and any number of parameters).
* `Callable[0,0]` is a callable that does not accept parameters
* If no types are given, and the min/max count is not `[0,0]`, then the callable describes only the
  untyped arity and it places no constraints on the parameter types, e.g. `Callable[2,2]` means
  callable with 2 parameters.


#### Type Algebra on Callable

`Callable` type algebra is different from other types as it seems to work in reverse. This is because its purpose is to describe the *callability* of the instance, not its essence (even if the type
serves dual purpose by simply reversing the comparison). (This is known as [Contravariance][3] in computer science).
As an example, a lambda that is `Callable[Numeric]` can be called with one
argument being a `Numeric`, `Float`, or an `Integer`, but not with a `Scalar`, or `Any`. Thus, while it seems intuitive that a `Callable[Integer`] should be assignable to a `Callable[Any]` (since `Any` is a wider type), this is not true because it cannot be called with an `Any`. **The reason for checking the type of a callable is to detect if it can be called a certain way** - thus `assignable?(Callable[Any], Callable[Integer])` really is a declaration that there is an *intent to call* the callable with one `Any` argument (which it does not accept).

This also means that generality works the opposite way; `Callable[String] ∪ Callable[Scalar]` yields `Callable[String]` - since both can be called with a `String`, but not with any `Scalar`.

Internally the `Callable` is represented by a `Tuple`, and an optional `Callable` (block). Type algebra is performed on these individually. Since Puppet 4.7.0, the calculation also involves the return type.

    Callable         ∪  Callable                         → Callable[0,default]
    Callable[?]      ∪  T (T ∉ Callable)                 → Any
    Callable[D]      ∪  Callable[E (E == D)]             → Callable[D]
    Callable[D]      ∪  Callable[E (E > D)]              → Callable[D]
    Callable[D]      ∪  Callable[E (E < D)]              → Callable[E]
    Callable[D]      ∪  Callable[E (!(E >= D || E < D))] → Callable

Here the parameter letter denotes the full callable specification (tuple and block):

The rationale of the last expression is that two disjunct callables cannot be called
in a common way e.g. `Callable[Array] ∪ Callable[Integer]` cannot be called with exactly
the same argument, since no such argument exists.

In general:


    B ∈ Callable
    C ∈ Callable
    S ∈ Tuple[X]
    T ∈ Tuple[Y]
    Callable[*S, B]  ∪  Callable[*T, C]    → Callable[*(S ∪ T), B ∪ C]

Here `*S`, `*T` denotes, the syntax of the `Tuple` parameters expanded.

Examples:

    Callable[String] ∪ Callable[Scalar]  → Callable[String]
    Callable[String] ∪ Callable[Numeric] → Callable

    A ∈ Callable[String, Callable[String]]
    B ∈ Callable[Scalar, Callable[Scalar]]
    A ∪ B → Callable[String, Callable[String]]

<table>
<tr><th>Note</th></tr>
<tr><td>
A future version of the spec may provide a better generalization of two callables such
that it either preserves the arity, or that a <tt>Variant</tt> of the two callables is
produced. This change will be made if the distinction has practical value.
</td></tr>
</table>

[3]: http://en.wikipedia.org/wiki/Covariance_and_contravariance_(computer_science)#Function_types

### Sensitive[T]

The `Sensitive` type describes a value that is (as implied by the name) sensitive with respect to disclosure.
At runtime, values that are sensitive can be wrapped in an instance of the Sensitive runtime type using `Sensitive.new`.
When a sensitive value is processed (for example logged), its value is changed so its string form is the string `"redacted"`.

When matching a `Sensitive[T]` against sensitive values the inferred type of a value is always generalized to not
disclose sensitive information. As an example, disclosing the length of a String gives away too much information.
Therefore, when using the Sensitive data type, it is only meaningful to use the basic concrete data types.

It is possible to unwrap an instance of Sensitive data type to obtain the clear text value. When doing so utmost care
should be taken to not disclose the value in clear text (it should not be logged). The function `unwrap` performs unwrapping.

    $secret = Sensitive(42)
    $processed = $secret.unwrap |$sensitive| { $sensitive * 2 }
    notice $processed  # notices 84

In general, care should be taken to also not disclose derived information (as in the example above).

<table>
<tr><th>Note</th></tr>
<tr><td>
  The Sensitive data type is the first data type in an expected family of data types to be used to handle
  sensitive/secret data. It expected that future versions also will have support for Encrypted data. In its current
  form, the Sensitive data type maintains the wrapped value in clear text. It is therefore only an aid to ensure that
  sensitive values are not inadvertently disclosed.
</tr></td>
</table>

#### Type Algebra on Sensitive[T]

* A `Sensitive[T]` is assignable to `Sensitive[T2]` if `T` is assignable to `T2`.
* Nothing besides Sensitive is assignable to Sensitive.
* The relationship between two `Sensitive` types is based on their type parameter.

#### Sensitive.new

Creates a new instance of the Sensitive type. Optionally, a type parameter can be given that asserts that the given value is of the expected data type.

    $x = Sensitive.new('say friend')
    $x = Sensitive('password')
    $x = Sensitive[String].new('secret')

#### Operations on Sensitive values

There is no automatic unwrapping of sensitive values. As a consequence it is not possible to perform operations on sensitive values other than interpolating it as a String. When such interpolation takes place, the value is shown as `"[redacted]"`.

#### Use of Sensitive values in Resources

Sensitive values can be used in resources. It is not allowed to use a sensitive value as a resource title.

### Object Type, TypeSet

The types `Object` and `TypeSet` are defined in the Puppet Type system as an experimental feature.

Operations per Type
---
The operations available per type is specified in the section TODO REF TO OPERATORS DOCUMENT.

Variables
---
A variable is a storage container for a value. Variables are immutable (once assigned they cannot be assigned to another value, and the value it is referring to is also immutable. Variables are also used to define parameters of defines, classes, lambdas (and functions) - the term *parameter* is
used to denote such variables.

The type of a non parameter variable is determined by what is assigned to it.

The type of a parameter may be optionally specified in which case a given value for that parameter
must be compliant with the given type. An untyped parameter accepts a value of any type (i.e. `Any`)

### Variable Names

Variable names must conform to the following syntax:

     Variable
       : '$' (NumericVariable | NamedVariable )
       ;

     NumericVariable
       : /0|([1-9][0-9]*)/
       ;

     NamedVariable
       : /[a-z_]\w*/
       | /(::)?[a-z]\w*(::[a-z]\w*)*/
       ;

* That is, a numeric variable must be a valid decimal number (a name that starts with 0 and has
  additional digits is also illegal).

* A named variable must start with a lower case letter a-z or '_' (underscore)
  and after that contain any word characters (a-z, A-Z, 0-9 or _). Specifically, a hyphen character
  or a period are not allowed as they were in some earlier versions of the Puppet Programming
  Language.

* Also note that it is not allowed to use an upper case letter in the initial position of a name
  segment.
* It is also not allowed to use an underscore in the initial position of a name segment
  in a fully qualified variable.

* The last segment of a qualified variable name is case sensitive - e.g. the variable `$varA` is not
  the same variable as `$vara`. All other segments are case insensitive.

* It is illegal to reference a numeric variable with a fully qualified name (i.e. a match result in
  another name-space).

**In this version of the specification variables last segment is specified to be case sensitive.
This may change in a future version as it is inconsistent with how class/type names are handled.**

### Variable Reference

An expression such as `$x` evaluates to the value bound (assigned) to the variable name. Numeric
variables are assigned as a side effect of evaluating a match expression. SEE TODO REF. It is legal to reference any numeric variable, but it is illegal to reference a named variable that does not exist. A variable that has been assigned, a built in variable, or a variable that represents a parameter value that is provided by the runtime (e.g. metaparameters) are said to exist.

**In this version of the specification strict variable lookup is optional (controlled by a feature switch). It is not on by default in Puppet 4.x, but will be mandatory in Puppet 5.0.**

### Initial Values of Variables

A Puppet Programming Language Variable comes into existence when an assignment is made to
the variable. There is no such thing as an un-initialized variable since all variables that
exist have a value (even if that value may be the literal `undef` value).

All numeric variables are said to exist. If they have not been set by the last match expression in
the same scope, they evaluate to `undef`.

Variables that have not been assigned, do not exist, and thus do not have a value. When
strict variables feature is turned off, a reference to such a variable results in the value `undef`.

Conversions and Promotions
===
The Puppet Programming Language is in general dynamically typed (everything is
an `Any` unless declared or specified otherwise). There are various operators that perform
type conversion.
If required and when possible, there are functions that perform explicit type conversion,
and there are typed parameters that will perform type conversion when required and possible.

The exact conversions are documented per language feature. This section describes the general
conversions and promotions.

Numeric Conversions
---
* When arithmetic operations are done on `Numeric` types - if one or both operands
  are of `Float` type, the result is also of `Float` type.

* There are never any under or overflow when performing integer arithmetic. The implementation
  handles automatic conversion from 32 to 64 bit numbers to bignum.

* `Numeric` types are only converted to `String` when they are interpolated into a double quoted
  string, or when explicitly converted using a function such as `sprintf`. Interpolation converts
  the numeric value using a decimal (base 10) format.

String to Numeric Conversion
---

* Automatic conversion between `String` and `Numeric` is performed for arithmetic operations, but
  not for comparisons.

* Arithmetic operations are done on `Numeric` or `String` types - if an operand is not `Numeric` or a
  `String` that can be converted to `Numeric`, the operation will fail.

* Explicit `String` to `Numeric` conversion can be performed with the function `scanf()`.

<table>
<tr><th>Note</th></tr>
<tr><td>
  Versions of Puppet before 4.0 performed automatic conversion of String to Numeric if the LHS was
  Numeric, and the RHS a String (but not consistently for all operators). Versions of "future
  parser" before 3.4.7 performed String to Numeric conversion if Strings could successfully be
  converted. Since 3.7.4, only arithmetic operations cause automatic conversion and fails if
  values are not convertible to numeric.
</tr></td>
</table>


Boolean Conversion
---
Puppet has a sense of boolean "truth" and will convert values to `Boolean` as shown below in
the Boolean logic expressions `if`, `unless`, `and`, `or` and `!` (not):

     ''        → true
     undef     → false
     false     → false
     any other → true

<table>
<tr><th>Note</th></tr>
<tr><td>
  3x treats '' (empty string) as equivalent to <tt>undef</tt>.
</tr></td>
</table>

String to Regexp Conversion
---
If the RHS operand of a match expression evaluates to a `String`, the string is converted into a regular expression.

To String Conversions
---
### Qualified Name and Qualified Reference to String

Qualified Names evaluate to string type unless the name appears in an expression that uses
the name as a reference to an instance (e.g. the name of a function in a function call).

The reverse is not generally true; a string value can not always be used where a Qualified Name is
allowed (e.g. `$"x"` is not a valid reference to the variable named `'x'`).

### Qualified Reference to String

Qualified References are only converted to `String` when interpolated into a `String` expression.

### Hash to String

A `Hash[K,V]` is turned into a string when it is interpolated. The string consists of `'{'` `'}'` around
a comma separated list of entries where each entry is `K '=>' V` and `K` and `V` are converted to string
form. The resulting string is formatted with one space padding after each comma. No trailing
comma is produced. There is no space after `'{'` and no space before `'}'`.

### Array to String

An `Array[T]` is turned into a string when it is interpolated. The string consists of `'['` `']'` around
a comma separated list of entries where each entry `T` is converted to string form. The resulting string is
formatted with one padding space after each comma. No trailing comma is produced. There is no space after `'['` and no space before `']'`.

### Type to String

A `Type` is turned into a string when it is interpolated. The string consists of the type name in upper case, and if it is parameterized followed by the string form of the parameters enclosed in `'['` `']'`.
When there are multiple parameters, they are comma separated, and padded with one space after each comma. There is no space after `'['`, and no space before `']'`. In general the form is compliant
with how the types are specified in Puppet Programming Language source form.

### Regexp to String

A `Regexp` is turned into a `String` when it is interpolated. The string consists of the source of
the regular expression as given in the Puppet Programming Language, enclosed in `'/'` `'/'`.

### Numeric to String

A `Numeric` is turned into a `String` when it is interpolated. The result is in decimal radix (i.e. base 10).

### Any to String

Conversion of any other type to `String` is undefined. It will typically be the underlying
runtime system's string representation of the object.
