Lexical Structure
===

Unicode
---

<table><tr><th>Puppet Language keywords and punctuation uses only ASCII. Strings (single and double quoted), Heredoc text, and Comments can contain non ASCII:</th></tr>
<tr><th>Since Puppet 4.4.0</th></tr>
<tr><td>
  All Puppet source code is expected to be in UTF-8. Non Ascii characters must be in UTF-8 and
  may appear in comments, single and double quoted strings, heredocs, and templates.
  <br/>
  <p>Byte order marks (BOM) are not allowed. If present an error is raised identifying the
  kind of byte order mark.</p>
</td></tr>
<tr><th>Before Puppet 4.4.0</th></tr>
<tr><td>
  The implementation uses Ruby default encoding when reading
  Puppet source text files.
  Thus, while the language itself does not make use of any non ASCII characters, it is possible
  to include other characters in strings given that the source file is written using the Ruby
  runtime environments default encoding and that a Ruby version is used that supports encodings.
  For Puppet code running on runtimes before Puppet 4.4.0, the only platform neutral way to use non  
  ASCII characters in the source is to use the Puppet 4x Unicode Escape mechanism \uXXXX.
  <br/>
  <p>Byte order marks (BOM) causes undefined behavior.</p>
</td></tr>
</table>

Not Completely Context Free
---
The Puppet Programming Language's lexical structure is not completely context free; the interpretation of the source text differs in a few cases depending on the previously seen significant token.

Line Terminators
---
The sequence of input characters in a Program's source file is divided into lines by recognizing
*line terminators*

```
LineTerminator
  : '\r'? '\n'
  ;
```

Line Numbers and Positions on Line
---
The first line is given the line number 1. The first character on a line is in position 1.

Whitespace
---
Whitespace between tokens is generally insignificant except for a few exceptional cases
noted in the section about Punctuation TBD. REF TO PUNCTUATION SPECIAL PROCESSING.

```
WHITESPACE
  : /([[:blank:]]|\r\n)+/
  ;
```

The regular expression `[:blank:]` matches all types of unicode spaces. This is done in order
to not disrupt lexical processing when text is copy / pasted from published examples since
these may contain hard spaces, narrow spaces etc. 

Comments
---
Comments between tokens are stripped away. Comments may be written as *single line comments* or
*multi line comments*.

    # this is a single line comment
    
    /* this is a multi-
       line comment.
    */

A single line comment inside a multi line comment (or vice versa) has no special meaning.
The lexical grammar implies that comments do not occur inside of literal strings.

```
SINGLE_LINE_COMMENT
  : /#[^\r\n]*(\r?\n)?/
  ;
  
MULTI_LINE_COMMENT
  : /\/\*(.*?)\*\//m
  ;
```

A single line comment starts with a `#` and runs to the end of the line, or to the end of the input if there is no line ending and this is the last line.

A multi line comment consists of at least `/**/`, allows embedded `/*`, but is terminated
by the first occurrence of `*/`. It is not possible to escape the end of the multiline
comment.

<table><tr><th>Note</th></tr>
<tr><td>
  Documentation processing tools makes comments in certain positions appear as documentation.
  These tools may have additional rules regarding placement and content. Such rules
  are not defined by this specification.
</td></tr>
</table>

Numbers
---
Numbers are recognized in decimal integer and floating point form as well as integers
in octal and hexadecimal form. All numbers start with a digit.

```
NUMBER
  : HEX | OCTAL | DECIMAL | FLOAT
  ;

HEX
  : /0[xX][0-9a-fA-F]+/
  ;

OCTAL
  : /0[0-7]+/
  ;

DECIMAL
  : /[1-9][0-9]*/
  ;

FLOAT
  : /0?\d+(\.\d+)?([eE]-?\d+)?
  ;
```

A number that starts with `0` and is not followed by a period `.` must be a valid octal number.
All numbers containing a decimal period `.` or an exponential are interpreted as floating point
numbers and all other are integers.

All given numbers must be valid in their implied radix.

<table>
<tr><th>Note</th></tr>
<tr><td>
  Literal numbers maintain their radix (hex, octal, or decimal) but this is lost in evaluation where
  all values are decimal and string formatting is required. 
</td></tr>
<tr><th>Future</th></tr>
<tr><td>
  The exponent may allow a '+' in the future.
</td></tr>
</table>


Strings
---
Strings of text are available in single and double quoted form. Both kinds of strings
can extend over multiple lines. Heredoc is an alternative form of String (see below).

<table>
<tr><th>Note</th></tr>
<tr><td>
  Line endings in strings contains the corresponding characters
  from the source text file - there is no transformation of <code>\r\n</code> into <code>\n</code>
  or vice versa.
</td></tr>
<tr><th>Future</th></tr>
<tr><td>
  This may change in the future.
</td></tr>
</table>

### Single Quoted String

A *Single Quoted String* starts and ends with `'`. The following escape sequences are supported:

#### Single Quoted String Escape Sequences

| sequence | result
| ---      | ---
| `\'`     | a single `'`
| `\\`     | a single `\`
| `\` *any other*     | a single `\` followed by *any other*

### Double Quoted String

A *Double Quoted String* starts and ends with `"`. In addition to supporting an extended
set of escape sequences, a double quoted string also supports interpolation of Puppet Language
expressions.

#### Double Quoted String Escape Sequences

| sequence            | result
| ---                 | ---
| `\"`                | a single `"`
| `\\`                | a single `\` (and removes the escaping power of the escaped \)
| `\r`                | an ASCII CR
| `\n`                | an ASCII NL
| `\t`                | an ASCII TAB
| `\s`                | an ASCII SPACE
| `\uXXXX`            | a UNICODE character denoted by 4 hex digits i.e. /[0-9a-fA-F]{4}/
| `\u{XXXX}`          | a UNICODE character denoted by 1-6 hex digits i.e. /[0-9a-fA-F]{1,6}/
| `\` *any other*     | a single `\` followed by *any other* (removes any special meaning from *any other*)

#### Double Quoted String Expression Interpolation

A double quoted string is delivered using three different tokens: `DQPRE`, `DQMID`, and `DQPOST`. Any other tokens may appear between a `DQPRE` and a `DQMID`, and between a `DQMID` and a `DQPOST`. An interpolated string may consist of only a `DQPRE` and a `DQPOST`, or be optimized into a single `STRING` token if there is no interpolation.

A `DQPRE` starts with `"` and is terminated by `$NAME`, or `${`. A `DQMID` starts automatically in the first non `NAME` character after the sequence `$`, `NAME`, or a `}` that balances the opening `${` and is terminated the same way as `DQPRE`. A `DQPOST` starts the same way as a `DQMID`, and is terminated by a closing `"`.

A double quoted string may contain nested (complete) double quoted strings in the interpolated
expressions.

The lexical processing delivers a `$`, `NAME` sequence as a `VARIABLE` token (as if the user had
written `${$name}`). No lexical processing is performed for interpolation using `${ }`; this
is instead done as part of syntactic and semantic processing of the result.

Here are some examples to illustrate:

    "Hello $name"
    #=> DQPRE('Hello '), VARIABLE(name), DQPOST('')
    
    "Hello ${name}"
    #=> DQPRE('Hello '), NAME('name'), DQPOST('')
    
    "Hello nbr ${1+1}, what is your name?"
    #=> DQPRE('Hello nor ', NUMBER(1), PLUS(+), NUMBER(1), DQPOST(', what is your name?')
    
    "Hello $name1 and $name2!"
    #=> DQPRE('Hello '), VARIABLE('name1'), DQMID(' and '), VARIABLE('name2'), DQPOST('!')

The String Interpolation Expression is further explained in [Expressiona][1]

[1]: expressions.md

Regular Expressions
---
A *Regular Expression* is written on the form

```
REGEXP
  : /[^\/\n]*\//
  ;
```
This means that a regular expression starts and ends with `/` and may not extend over multiple lines.

The syntax of the Puppet Language regular expression is defined by the Ruby Regular Expression.
The Puppet Language does not support the use of `\A`, and `\z` and does not support modifiers after
the closing `/`.

A *Regular Expression* is recognized in most lexical contexts but not in positions where
an operator is accepted. Specifically, it is not recognized
when appearing after `')'`, `']'`, `'|>>'`, `'|>'`, `NAME`, `REF`, `STRING`, `BOOLEAN`, `REGEX`, `HEREDOC`, and the string-parts of a double quoted string with interpolation.

There is one ambiguity in that a Regular Expression must be allowed to appear after a `'}'` (end of a case expression option and start of a new). This clashes with constructs where `'}'` is the end of an expression that produces an *R-value* and where it is possible to divide the result. In the event the program logic required several divisions (e.g. `...} /<expr>/<expr>` the source must place the
second `'/'` on a new line to avoid `/<expr>/` to be recognized as a regular expression (or alternatively compute a single divisor to avoid the repeated division).


Identifiers
---
Identifiers are *bare words* (a bare word is an unquoted sequence of letters and the underscore
(`_`) character). The meaning of a bare word is context specific and is described in the language grammar; it may be interpreted as a string/symbol, or be a name/identifier.

There are two main kinds of identifiers depending on if the sequence starts with a lower or upper case letter.

Identifiers may be qualified with a *name-space*. The name-space separator is `::` and it may also be
used first in the name to *anchor* the name in the root/global namespace. Each segment of a qualified identifier must follow the same format, all segments must start with a letter of the same case.

Keywords can not be used as identifiers (names) of elements, but may be used as names of attributes/properties.

### Lower Case Bare Words / NAME / Qualified Name

```
NAME
  : /(::)?[a-z]\w*(::[a-z]\w*)*/
  ;
```

Examples:

    apache::port
    ::apache
    ::apache::port

### Upper Case Bare Words / REF / Qualified Reference

```
REF
  : /(::)?[A-Z]\w*(::[A-Z]\w*)*/
  ;
```

Examples:

    File
    ::File
    Class
    Integer
    
<table>
<tr><th>Note</th></tr>
<tr><td>
  Many upper case words denote built in types and these names should be considered to be reserved.
</td></tr>
</table>


Variable
---
A variable in the language is always preceded by `$`. (There are special cases in double quoted
string expression interpolation where a `NAME` may be taken as a variable name).

```
VARIABLE
  : /\$(::)?(\w+::)*\w+/
  ;
```

Note that there is a difference between what is lexically recognized as a variable and a valid variable reference. The lexically recognized variable accepts the following illegal
names:

    $0xG   # Numeric variable that is not a valid decimal number
    $0080  # A Numeric variable may be 0 (exactly), or a decimal value that does not start with 0
    $Abc   # Variables may not start with upper case letter

The distinction between lexicographic variable and valid variable is mainly important for
string interpolation. Here is an example:

    "Hello $00080, how are you"

This is an attempt to interpolate the invalid variable `$00080` and not an interpolation of the valid variable `$0` followed by the text `'0080, how are you'`. If the latter was intended, it should be 
written in one of these forms:

    "Hello ${0}0080, how are you"
    "Hello ${$0}0080, how are you"

See the following sections in [Expressions][1] for more information:

* String Interpolation
* Types, Values, and Variables

Keywords
---
When an *Identifier* had been identified and it is equal (in its entirety) to a keyword, the
keyword token is produced instead of a `NAME` token. Keywords are case sensitive.

| Literal | value
| ---     | ---
| `false`   | Boolean false
| `true`    | Boolean true
| `undef`   | The Puppet Language notion of nil / null / undefined

| Keywords
| ---
| `and`
| `case`
| `class`
| `default`
| `define`
| `else`
| `elsif`
| `function`
| `if`
| `in`
| `inherits`
| `node`
| `or`
| `type`
| `unless`

The semantics of these is described in [Expressions][1].

The following keywords are considered reserved for future use and should be avoided.

| Reserved Words
| ---
| `private`
| `attr`

These names are reserved for types, and are unsuitable as identifiers for other kinds of
elements:

| Reserved Names / Types
| ---
| `any, Any`
| `array, Array`
| `attr, Attr`
| `boolean, Boolean`
| `catalogentry, catalogEntry, CatalogEntry`
| `class, Class`
| `collection, Collection`
| `data, Data`
| `default, Default`
| `enum, Enum`
| `float, Float`
| `hash, Hash`
| `integer, Integer`
| `numeric, Numeric`
| `object, Object`
| `optional, Optional`
| `scalar, Scalar`
| `pattern, Pattern`
| `private, Private`
| `resource, Resource`
| `runtime, Runtime`
| `string, String`
| `struct, Struct`
| `tuple, Tuple`
| `type, Type`
| `undef, Undef`
| `variant, Variant`

While the lower case names are perfectly fine to use unless they are also keywords (i.e. when they
have no special meaning) they should not be  used as names of functions, classes, or user defined
defined resource types as the name would clashes with the built in types. This occurs because lower
case named definitions automatically get an upper cased type reference.


Separators / Punctuation
---
```
( ) { } [ ] ; , . | :
```

### Special Punctuation Processing

* When a `[` is preceded by `WHITESPACE` or is at the beginning of the input the delivered token is  
  `LISTSTART`, else the token `LBRACK`. This is done to disambiguate `$a[1]` (index operation on `
   $a`) from `$a [1]`  (lookup of variable value `$a`, followed by an array with the value `1`),
   and similar ambiguities.

* When a `{` is preceded by a `?` (`WHITESPACE` ignored) the delivered token is
  `SELBRACE` (select brace) instead of `LBRACE` to 
  disambiguate between the clash of a general expression (a hash value) and the start of a select 
  expression block. This is further discussed in the grammar / semantics of the language.

Operators
---
These are the operators of the Puppet Programming Language. They are lexicographically delivered
as individual tokens. Their semantics are specified in [Expressions][1].

```
= < > ! ?
== <= >= !=
=~ !~
+ - * / %
<< >>
<| |>
<<| |>>
=> +>
-> <-
~> <~
@ @@
~
```

Heredoc
---
A *Heredoc* is a lexical processing function that processes *out of band* text appearing on the lines (or if multiple heredocs are present on the same line, on the lines after the preceding
heredoc), until an end marker specified by the heredoc.

    $a = [@(END1), @(END2)]
    This is the text in the first heredoc, until the end marker is seen
    END1
    This is the text in the second heredoc, until the end marker is seen
    END2

The heredoc consists of an heredoc expression enclosed in `@( )`. The heredoc expression
consists of a specification of the endtag, an optional syntax specification, and an optional
specification of escape sequence processing.

From a lexical perspective, the HEREDOC lexical function is recognized by:

```
HEREDOC
  : /@\(([^:\/\r\n\)]+)(?::[:blank:]*([a-z][a-zA-Z0-9_+]+)[:blank:]*)?(?:\/((?:\w|[$])*)[:blank:]*)?\)/
  ;
```

Which is then processed by a separate heredoc processor for internal syntax:

```
HeredocExpression
  : '@' '(' EndTag (':' Syntax)? ('/' Escapes* )? ')'
  ;

EndTag
  : DoubleQuotedEndTag | TextEndTag
  ;

DoubleQuotedEndTag
  : /^"(.*)"$/
  ;

TextEndTag
  : /[^:\/\r\n\)]+/
  ;

Syntax
  : /[a-z][a-zA-Z_+]+/
  ;

Escapes
  : 't' | 'r' | 'n' | 's' | 'u' | 'L' | '$'
  ;
```
A recognized heredoc lexical function that does not comply with the heredoc processing rules
raises an error.

The text that belongs to the heredoc expression ends when a line begins with:

```
WHITESPACE? ('|' WHITESPACE?)? ('-' WHITESPACE?)?  <<EndTag>>
```

Where `<<EndTag>>` denotes the `EndTag` *text* as given in the heredoc expression. The `|` is an optional marker that indicates where the left margin is, and the `-` denotes if right trimming should
be performed on the last line of text.

The lexical processing produces at least three tokens for a heredoc; a `HEREDOC` with a value corresponding
to the Syntax expression part, followed by a token containing text positioning information, followed by a `STRING`, or `DQPRE`, `DQMID*`, `DQPOST` sequence.

See [Heredoc][2] for details about the semantics.

[2]: heredoc.md

Template Mode
---
The lexing process may be initialized in *Template Mode*. In this mode, the stream of source text starts in text/*Unquoted String* mode and allows for the source to weave logic into the text
in various ways.

The EPP lexical tokens are only recognized in templates. In general, the opening type tokens escape from text mode to expression mode (in various ways), and the closing type tokens returns from expression mode to text mode.

```
<% <%- <%= <%% <%#
%> -%> 

```
Template processing is detailed in TBD. REF TO EPP

The lexical processing of EPP produces an `EPPSTART` token at the beginning of the text sequence. This
token may be followed by tokens that constitute a parameter list. The lexical processing of
the rest of the template is broken up into `RENDER_STRING` and `RENDER_EXPRESSION` tokens intermixed with regular tokens.

Other
---
All other tokens are delivered as an `OTHER` token, and will cause the grammar to issue a syntax error.
