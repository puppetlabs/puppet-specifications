Puppet Language Specification
===
This specification is a technical description of the Puppet Programming Language.

Terminology
---
<dl>
  <dt>Puppet Program</dt>
  <dd>A Program written in the Puppet Programming Language, also known as the "Puppet DSL"</dd>

  <dt>Program</dt>
  <dd>A Program written in the Puppet Language unless text refers to some other language
      like Ruby Program, Java Program etc.
  </dd>
  
  <dt>LHS</dt>
  <dd>Left Hand Side, the left operand in a binary expression.</dd>
  
  <dt>RHS</dt>
  <dd>Right Hand Side, the right operand in a binary expression.</dd>
  
  <dt>Lexing</dt>
  <dd>The act of turning source text into tokens that are recognized by a parser.</dd>

  <dt>Parsing</dt>
  <dd>The act of turning source text into a abstract syntax model.</dd>
  
  <dt>Loading</dt>
  <dd>The act of locating source text, parsing, and evaluating logic to the point where
      definitions are available (but not necessarily evaluated in full).
  </dd>
  
  <dt>Evaluation</dt>
  <dd>The act of carrying out the instructions in the Puppet Program being executed.</dd>
  
  <dt>Compilation</dt>
  <dd>The act of producing a Catalog by executing a Puppet Program.
      Also known as Catalog Building.
  </dd>

  <dt>Declaration</dt>
  <dd>The act of introducing a named and possibly typed element into a Program.</dd>

  <dt>Definition</dt>
  <dd>The act of assigning/setting the content/value of an element in the Program</dd>
  
  <dt>Manifest</dt>
  <dd>A file with source code in the Puppet Programming Language.
      The extension .pp is used for such files.
  </dd>
<dl>

Grammar Notation
---
Grammars (lexical and syntactic) are written in a variant of Extended Backus Naur Form (EBNF) with the following syntax and semantics:

| syntax | meaning
|------  | -------
| 'c'    | the terminal character c
| '\r'   | the terminal ascii character CR
| '\n'   | the terminal ascii character NL
| '\t'   | the terminal ascii character TAB
| '\\'   | the terminal ascii character BACKSLASH
| rule:  | a rule name, (all uppercase rule is a terminal rule, mixed case is a regular rule)
| TOKEN: | a terminal token rule
| ( )    | groups elements
| ?      | the preceding element occurs zero or one time
| *      | the preceding element occurs zero or many times
| +      | the preceding element occurs one or many times
| &#124; | or
| /re/   | a regular expression as defined by Ruby 2.0
| ;      | rule end
| sym =  | symbolic naming of rule to the right
| sym += | symbolic naming of array containing iterative values from rule on right
| rule&lt;Type&gt; | A rule call that when evaluated produces the given (runtime type)
| rule &lt;Type&gt;: | A type safe rule that when evaluated produces the given (runtime type)

The presence of `sym=` and `sym+=` does not alter the grammar, they only provide notation to
be able to refer to the various parts of the rule using symbolic names.

### Grammar Example
```
Hello: 'h' 'e' 'l' 'l' 'o' ;
Hi: 'h' 'i' ;
NAME: /[A-Za-z]+/ ;
Greeting: (Hello | Hi ) NAME '!'?;

StringAccess
  : Expression<String> '[' from = Int (',' to = Int)? ']'
  ;

Int <Integer> : Expression ;
  
ASequenceOfNames
  : (names += NAME)+
  ;
  
```
### Set Algebra Notation

Algebra notation is used in the specification to describe the operations on
types as well as other logical constructs. Here is a repetition of the set theory notations
used in this specification:

`X` is *member of* (the set `Y`) (can be read as `exists in`)

    X ∈ Y

`X` is *not member of* (the set `Y`) (can be read as `exists in`)

    X ∉ Y

The *union* of `X` and `Y` (all that are in `X`, in `Y`, or in both)

    X ∪ Y
    
The intersection of `X` and `Y` (all that are in both `X` and `Y`)

    X ∩ Y
    
Implies, gives, produces (depending on context)

    →
    
The empty set

    ∅

    
#### Examples:

The union of the type Integer and the type Float is Numeric:

    Integer ∪ Float → Numeric

This means that if there is a collection of objects that consist of integers and float
(but no instances of any other type), then the collection is of
`Collection[Numeric]` types.
