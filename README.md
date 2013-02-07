# SLAXML
SLAXML is a pure-Lua SAX-like streaming XML parser. It is more robust than 
many (simpler) pattern-based parsers that exist ([such as mine][1]), supporting code like `<foo test="5>7"/>`, CDATA nodes and comments and processing instructions.

It is currently not a truly valid XML parser, however, as it allows completely invalid XML such
as `<foo></bar>` to be parsed and reported as such. It is also not namespace-aware. See the "Limitations / TODO" section below for more details.

[1] http://phrogz.net/lua/AKLOMParser.lua

# Usage
    require 'slaxml'
    -- Skip whitespace-only text nodes and strip leading/trailing whitespace from text nodes
    SLAXML.ignoreWhitespace = true 

    -- Specify as many/few of these as you like
    parser = SLAXML:parser{
      startElement = function(name)           end, -- When "<foo" is seen
      attribute    = function(name,value)     end, -- attribute found
      closeElement = function(name)           end, -- When "</foo" or "/>" is seen
      text         = function(text)           end, -- text and CDATA nodes
      comment      = function(content)        end, -- comments
      pi           = function(target,content) end, -- processing instructions e.g. "<?yes mon?>"
    }

    myxml = io.open('my.xml'):read()
    parser:parse(myxml)

If you just want to see if it parses your document correctly, you can also use just:

    require 'slaxml'
    SLAXML:parse(myxml)

…which will cause SLAXML to use its built-in callbacks that print the results as seen.

# History

## v0.1 2013-Feb-7
### Features
+ Option to ignore whitespace-only text nodes
+ Supports unescaped > in attributes
+ Supports CDATA
+ Supports Comments
+ Supports Processing Instructions

### Limitations / TODO
- Does not require or enforce well-formed XML (or report/fail on invalid)
- No support for namespaces:
  - xmlns="…" attributes look like any other
  - xmlns:foo="…" attributes will report name as "xmlns:foo"
  - <foo:bar> elements will report name as "foo:bar"
  - foo:bar="…" attributes will report name as "foo:bar"
- No support for entity expansion other than
  &lt; &gt; &quot; &apos; &amp;
- XML Declarations <?xml version="1.x"?> are incorrectly reported
  as Processing Instructions
- No support for DTDs
- No support for extended characters in element/attribute names

# License
Copyright © 2013 [Gavin Kistner](mailto:!@phrogz.net)

Licensed under the MIT License. See LICENSE.txt for more details.
