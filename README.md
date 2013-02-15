# SLAXML
SLAXML is a pure-Lua SAX-like streaming XML parser. It is more robust than 
many (simpler) pattern-based parsers that exist ([such as mine][1]), properly
supporting code like `<expr test="5 > 7" />`, CDATA nodes, comments, namespaces,
and processing instructions.

It is currently not a truly valid XML parser, however, as it allows some invalid
XML such as `<foo></bar>` to be parsed (and reported) as such.
See the "Limitations / TODO" section below for more details.

[1]: http://phrogz.net/lua/AKLOMParser.lua

# Usage
    require 'slaxml'
    -- Skip whitespace-only text nodes and strip leading/trailing whitespace from text nodes
    SLAXML.ignoreWhitespace = true 

    -- Specify as many/few of these as you like
    parser = SLAXML:parser{
      startElement = function(name,nsURI)       end, -- When "<foo" or <x:foo is seen
      attribute    = function(name,value,nsURI) end, -- attribute found on current element
      closeElement = function(name)             end, -- When "</foo" or "/>" is seen
      text         = function(text)             end, -- text and CDATA nodes
      comment      = function(content)          end, -- comments
      pi           = function(target,content)   end, -- processing instructions e.g. "<?yes mon?>"
      namespace    = function(nsURI)            end, -- when xmlns="..." is seen (after startElement)
    }

    myxml = io.open('my.xml'):read()
    parser:parse(myxml)

If you just want to see if it parses your document correctly, you can also use just:

    require 'slaxml'
    SLAXML:parse(myxml)

…which will cause SLAXML to use its built-in callbacks that print the results as seen.

If you want to build a table object model from your XML (with simple collections like
`.kids` and `.attr` for navigating the hierarchy) then you can alternatively:

    require 'slaxdom'
    local doc = SLAXML:dom(myxml)
    print( doc.root.name  )
    print( doc.root.nsURI )
    print( doc.root.attr['version'] )
    for i,node in ipairs(doc.root.kids) do
      -- includes elements, comments, textnodes and PIs
      print("Child #",i,"is",node.type,node.name)
    end
    for i,el in ipairs(doc.root.el) do
      -- includes only elements
      print("Element #",i,"is",node.name)
      for name,value in pairs(node.attr) do
        print("",name,"=",value)
      end
    end


# History

## v0.3 2013-Feb-15
### Features
+ Support namespaces for elements and attributes
  + `<foo xmlns="bar">` will call `startElement("foo",nil)` followed by `namespace("bar")`
    + Child elements inheriting the default namespace will call `startElement("child","bar")`
  + `<xy:foo>` will call `startElement("foo","uri-for-xy-namespace")` or error if not found
  + `<foo xy:bar="yay">` will call `attribute("bar","yay","uri-for-xy-namespace")` or error if not found
+ Add (optional) DOM parser that validates hierarchy and supports namespaces
  - Except that namespaced attributes with the same name will collide

## v0.2 2013-Feb-15
### Features
+ Supports expanding numeric entities e.g. `&#34;` -> `"`
+ Utility functions are local to parsing (not spamming the global namespace)

## v0.1 2013-Feb-7
### Features
+ Option to ignore whitespace-only text nodes
+ Supports unescaped > in attributes
+ Supports CDATA
+ Supports Comments
+ Supports Processing Instructions

### Limitations / TODO
- Does not require or enforce well-formed XML (or report/fail on invalid)
- No support for entity expansion other than
  `&lt; &gt; &quot; &apos; &amp;` and numeric ASCII entities like `&#10;`
- XML Declarations (`<?xml version="1.x"?>`) are incorrectly reported
  as Processing Instructions
- No support for DTDs
- No support for extended characters in element/attribute names

# License
Copyright © 2013 [Gavin Kistner](mailto:!@phrogz.net)

Licensed under the [MIT License](http://opensource.org/licenses/MIT). See LICENSE.txt for more details.
