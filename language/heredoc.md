Puppet Heredoc
===
Puppet Heredoc is a feature that allows longer sequences of verbatim text to appear in
a Puppet Program. The term Heredoc is borrowed from the Ruby Language. The Puppet Heredoc
has similar traits as the Heredoc in Ruby, but differs in syntax and offered extra features.

Grammar
---
Heredoc is done by lexical processing of the source text, and the detailed grammar for 
heredoc is found in [Lexical Structure][1].

[1]: lexical_structure.md#heredoc


The grammar defines the `@()` operator to indicate *"here doc, until given end tag"*, e.g.

    $a = @(END)
    This is the text that gets assigned to $a.
    And this too.
    END

Further, the operator allows specification of the semantics of the
contained text, as follows:

<table>
<tr>
  <td><tt>@(END)</tt></td><td>no interpolation and no escapes</td></tr>
<tr>
  <td><tt>@("END")</tt></td>
  <td>double quoted string semantics for interpolation and no escapes</td>
</tr>
</table>

It is possible to optionally specify a **syntax** that allows validation of the heredoc text, as in this example specifying
that this text should be valid JSON.

    $a = @(END:json)
    This is supposed to be valid JSON text
    END

And it is possible to specify the processing of escaped characters. By default both 
the `@(END)` form as well as the `@("END")` form has no escapes and text is verbatim. It is possible to turn on all
escapes, or individual escapes by ending the heredoc specification with a `/`. If followed by only a `/` all escapes are turned on,
and if followed by individual escapes, only the specified escapes are turned on.
In this example, the user specifies that `\t` should be turned into tab characters:

    $a = @(END/t)
    There is a tab\tbefore 'before'
    END


These features are explained in more details in the following sections.

The Heredoc Tag
---
The heredoc tag is written on the form:

    @( <endtag> [:<syntax>] [/<escapes>] )


The heredoc endtag may consist of any text except the delimiters (see details below).
Syntax is optionally specified with a `:` (colon) followed by the name of the syntax used in the text.
Escapes are optionally specified with a `/` followed by the possible escapes.

Here are the details:

  * &lt;endtag&gt; is any text not containing `:`, `/`, `)` or `\r`, `\n` (This is the text that indicates the end of the text)
  * &lt;syntax&gt; is [a-z][a-zA-Z0-9_+]*, and is the name of a syntax. This is validated to not contain empty segments between
    `+` signs. The result is always downcased.
  * &lt;escapes&gt; zero or more of the letters t, s, r, n, L, $ where
    * \t is replaced by a tab character
    * \s is replaced by a space
    * \r is replaced by carriage-return
    * \n is replaced by a new-line
    * \L replaces escaped end of line (\r?\n) with nothing
    * \$ is replaced by a $ and prevents any interpolation
    * If any of the other escapes are specified \\ is replaced by one \
  * if &lt;escapes&gt; is empty (no characters) all escapes t, s, r, n, L, and $ are turned on.
  * It is an error to specify any given escape character more than once in the specification.

The three parts in the heredoc tag may be surrounded by whitespace for readability. The list
of escapes may not contain whitepsaces.

End Marker
---

The end marker consists of the heredoc endtag (specified at the opening `@`) and
optional operators to control trimming.

The end marker must appear on a line of its own. It may have leading and
trailing whitespace, but no other text (it is then not recognized as the
end of the heredoc). In contrast to Ruby heredoc, there is no need to
specify at the opening that the end tag may be indented.

The end marker may optionally start with one of the following operators:

<table>
<tr>
  <td><tt>-</tt></td>
  <td>indicates that trailing whitespace (including new line)
  is trimmed from the <i>last line</i>.</td>
</tr>
<tr>
  <td><tt>|</tt></td>
  <td>indentation marker, any left white-space on each line in the text that matches
  the white-space to the left of the position of the `|` char
  is trimmed from the text on all lines in the heredoc. Typically this is a sequence of spaces. A mix of tabs and spaces
  may be used, but there is no tab/space conversion, the same sequence used to indent lines should be used
  to indent the pipe char (thus, it is not possible to trim "part of a tab").</td>
</tr>
<tr>
  <td><tt>|-</tt></td>
  <td>combines indentation and trimming of trailing whitespace</td>
</tr>
</table>

The optional start may be separated from the end marker by whitespace
(but not newline). These are legal end markers:

    -END    
    - END
    |END
    | END
    |           END
    |- END

The sections [Indentation](#indentation), and [Trimming](#trimming)
contains examples and further details.

Indentation
---

The position of the | marker before the end tag controls how much
leading whitespace to trim from the text.

    0.........1.........2.........3.........4.........5.........6
    $a = @(END)
      This is indented 2 spaces in the source, but produces
      a result flush left with the initial 'T'
        This line is thus indented 2 spaces.
      | END

Without the leading pipe operator, the end tag may be placed anywhere on
the line. This will include all leading whitespace.

    0.........1.........2.........3.........4.........5.........6
    $a = @(END)
      This is indented 2 spaces in the source, and produces
      a result with left margin equal to the source file's left edge.
        This line is thus indented 4 spaces.
                                            END

When the indentation is right of the beginning position of some lines
the present left whitespace is removed, but not further adjustment is
made, thus altering the relative indentation.

    0.........1.........2.........3.........4.........5.........6
    $a = @(END)
      XXX
        YYY
       | END

Results in the string `XXX\n YYY\n`

### Tabs in the input and indentation

The left trimming is based on using the whitepsace to the left of the pipe character
as a pattern. Thus, a mix of space and tabs may be used, but there is no tab to/from space
conversion so it is not possible to trim part of a "tab". (**Note: It is considered best practice to
always use spaces for indentation**).

Trimming
---

It is possible to trim the trailing whitespace from the last line (the
line just before the end tag) by starting the end tag with a minus '-'.
When a '-' is used this is the indentation position.

    0.........1.........2.........3.........4.........5.........6
    $a = @(END)
      This line will not be terminated by a new line
      -END
    $b = @(END)
      This line will not be terminated by a new line
      |- END

This is equivalent to:

    $a =  '  This line will not be terminated by a new line'
    $b =  'This line will not be terminated by a new line'

It is allowed to have whitespace between the - and the tag, e.g.

    0.........1.........2.........3.........4.........5.........6
    $a = @(END)     
      This line will not be terminated by a new line
      - END

Splitting and joining long lines
---
If content has very long lines, lines can be split, and then joined by escaping the
new line character.


    0.........1.........2.........3.........4.........5.........6
    $a = @(END/L)     
      I am a very long line of text that is difficult to work \
      with. The escaped end of line joins the long line into one.
     | - END

* There is a bug in the current implementation [PUP-3091][2] since
  trimming of left margin should take place before joining lines.

[2]: https://tickets.puppetlabs.com/browse/PUP-3091

Spaces allowed in the tag
---

White space is allowed in the tag name. Spaces are significant between words.

    0.........1.........2.........3.........4.........5.........6
    $a = @(Verse 8 of The Raven)
      Then this ebony bird beguiling my sad fancy into smiling,
      By the grave and stern decorum of the countenance it wore,
      `Though thy crest be shorn and shaven, thou,' I said, `art sure no craven.
      Ghastly grim and ancient raven wandering from the nightly shore -
      Tell me what thy lordly name is on the Night's Plutonian shore!'
      Quoth the raven, `Nevermore.'
      | Verse 8 of The Raven

The comparison of opening and end tag is performed by first removing any quotes from the opening
tag, then trimming leading/trailing whitespace, and then comparing the endtag against the text.
The endtag must be written with the same internal spacing and capitalization as in the opening tag
to be recognized.

Escapes
---
By default escapes in the text (e.g. \n) is treated as verbatim text. The rationale for this, is that
heredoc is most often used for verbatim text, where any escapes makes it very tedious to correctly mark up
special characters. There are however usecases where it is important to have detailed control over escapes.

The set of allowed escapes are fixed to: t, s, r, n, $, and L (as shown earlier). The 'L' is special in that it allows the
end of lines to be escaped (with the effect of joining them). The 'L' automatically handles line endings with carriage return/
line feed combinations. (In case it is not obvious: You can not insert an `\L` in the text). Here is an example:

    $a = @(END/L)
    First line, \
    also on first line in result
    |- END

Produces

    First line, also on first line in result


Without the specification of `/L` the result would have been

    First line,
    also on first line in result

When an escape is on for any character, it is always possible to escape the backslash to prevent replacement from
taking place.

    $a = @(END/L)
    First line, \\
    on second line
    |- END

An empty escapes specification turns on all escapes.

Multiple Heredoc on the same line
---

It is possible to use more than one heredoc on the same line as in this
example:

    foo(@(FIRST), @(SECOND))
      This is the text for the first heredoc
        FIRST
      This is the text for the second
        SECOND

If however, the line is broken like this:

    foo(@(FIRST),
    @(SECOND))

Then the heredocs must appear in this order:

    foo(@(FIRST),
      This is the text for the first heredoc
      FIRST
    @(SECOND))
      This is the text for the second
      SECOND

Additional semantics
---

The `@(tag)` is equivalent to a right value (i.e. a string), only that its
content begins on the next line of not already consumed heredoc text. The
shuffling around of the text is a purely lexical exercise.

Thus, it is possible to continue the heredoc expression, e.g. with a
method call.

    $a = @(END).upcase()
      I am not shouting. At least not yet...
      | END

(It is not possible to continue the expression after the end-tag).


Syntax Checking of Heredoc Text
---
Syntax checking of a heredoc text is made possible by allowing the heredoc to be tagged with the name
of a syntax/language. Here are some examples:

    @(END:javascript)
    @(END:ruby)
    @(END:property_file)
    @(END:yaml)
    @(END:json)
    @(END:myschema+json)
    @("END":epp)

This way, the checking can take place server side before the content
is (much later) used with possibly very hard to detect problems as a
result.

The given syntax name is given to a syntax checker implementation that is selected
based on the name. The syntax name characters `+` and `.` are translated to two and one underscore
character respectively. (See more about `+` below). A period is allowed since many mime types
have this in their names .


A `+` character is allowed as a name separator (in the style of RFC2046-Mime Media Types).
The intent is to describe syntax that is encoded in formats such as xml or json where the content
must be valid json, xml etc. *and* be valid in the specified dialect/"schema" (e.g. xslt+xml).
Mime media types includes the use of `.` (e.g. vnd.apple.installer+xml).

By convention, the most specific syntax should be placed first.
When mapping syntax to a checker, each `+` defines a name segment.
An attempt is first made with the full name (e.g. 'xslt+xml'), and if no
such function exists, the leftmost
name segment is dropped, and a new attempt is made to find a checker (e.g. 'xml').
The first found checker is given the
task of validating the string. If no checker is found, the string is not validated.

The full syntax string is passed to the validation function to allow
mapping of segments to schema names, thus allowing once checker to check many more
specific syntaxes without having to explicitly specify this.

Checkers are wired into the Puppet runtime by using the binder. Puppet comes bundled
with a syntax checker for 'json'.

The API for extending puppet with additional checkers is currently experimental. See
the source of `puppetx/syntax_checker.rb`, and `puppets/puppetlabs/syntax_checkers/json.rb` for
reference.

The implementation should inherit from the `Puppetx::Puppet::SyntaxChecker` and be placed
in a module under `lib/puppetx/mymodule/syntax_checkers/`. A binding that wires it and makes
it available for a given syntax should be placed in the module's directory
`lib/puppet/bindings/<modulename>/default.rb` with the following content:

    Puppet::Bindings::newbindings('<modulename>::default' do
      bind {
        name 'mysyntax'
        instance_of  'Puppetx::Puppet::SyntaxChecker'
        in_multibind 'puppetx::puppet::syntaxcheckers'
        to_instance  'Puppetx::<MyModule>::SyntaxCheckers::MySyntax'
      }
    end
    
This binding is automatically included, and can then be used in a heredoc:

    @(END:mysyntax)
    Oh, my syntax, my beautiful syntax,
    please tell me when you find an errr.
    END
