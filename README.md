# SLAXML
SLAXML is a pure-Lua SAX-like streaming XML parser. It is more robust than
many (simpler) pattern-based parsers that exist ([such as mine][1]), properly
supporting code like `<expr test="5 > 7" />`, CDATA nodes, comments, namespaces,
and processing instructions.

It is currently not a truly valid XML parser, however, as it allows some invalid
XML such as `<foo></bar>` to be parsed (and reported) as such.
See the "Limitations / TODO" section below for more details.

[1]: http://phrogz.net/lua/AKLOMParser.lua

## Usage
    require 'slaxml'

    local myxml = io.open('my.xml'):read()

    -- Specify as many/few of these as you like
    parser = SLAXML:parser{
      startElement = function(name,nsURI)       end, -- When "<foo" or <x:foo is seen
      attribute    = function(name,value,nsURI) end, -- attribute found on current element
      closeElement = function(name,nsURI)       end, -- When "</foo>" or </x:foo> or "/>" is seen
      text         = function(text)             end, -- text and CDATA nodes
      comment      = function(content)          end, -- comments
      pi           = function(target,content)   end, -- processing instructions e.g. "<?yes mon?>"
      namespace    = function(nsURI)            end, -- when xmlns="..." is seen (after startElement)
    }

    -- Ignore whitespace-only text nodes and strip leading/trailing whitespace from text
    -- (does not strip leading/trailing whitespace from CDATA)
    parser:parse(myxml,{stripWhitespace=true})

If you just want to see if it will parses your document correctly, you can simply do:

    require 'slaxml'
    SLAXML:parse(myxml)

…which will cause SLAXML to use its built-in callbacks that print the results as seen.

## DOM Builder

If you simply want to build tables from your XML, you can alternatively:

    require 'slaxdom'
    local doc = SLAXML:dom(myxml)

The returned table is a 'document' comprised of tables for elements, attributes, text nodes, comments, and processing instructions. See the following documentation for what each supports.

### DOM Table Features

* **Document** - the root table returned from the `SLAXML:dom()` method.
  * <strong>`doc.type`</strong> : the string `"document"`
  * <strong>`doc.name`</strong> : the string `"#doc"`
  * <strong>`doc.kids`</strong> : an array table of child processing instructions, the root element, and comment nodes.
  * <strong>`doc.root`</strong> : the root element for the document
* **Element**
  * <strong>`someEl.type`</strong> : the string `"element"`
  * <strong>`someEl.name`</strong> : the string name of the element (without any namespace prefix)
  * <strong>`someEl.nsURI`</strong> : the namespace URI for this element; `nil` if no namespace is applied
  * <strong>`someEl.attr`</strong> : a table of attributes, indexed by name and index
      * `local value = someEl.attr['attribute-name']` : any namespace prefix of the attribute is not part of the name
      * `local someAttr = someEl.attr[1]` : an single attribute table (see below); useful for iterating all attributes of an element, or for disambiguating attributes with the same name in different namespaces
  * <strong>`someEl.kids`</strong> : an array table of child elements, text nodes, comment nodes, and processing instructions
  * <strong>`someEl.el`</strong> : an array table of child elements only
  * <strong>`someEl.parent`</strong> : reference to the the parent element or document table
* **Attribute**
  * <strong>`someAttr.type`</strong> : the string `"attribute"`
  * <strong>`someAttr.name`</strong> : the name of the attribute (without any namespace prefix)
  * <strong>`someAttr.value`</strong> : the string value of the attribute (with XML and numeric entities unescaped)
  * <strong>`someEl.nsURI`</strong> : the namespace URI for the attribute; `nil` if no namespace is applied
  * <strong>`someEl.parent`</strong> : reference to the the parent element table
* **Text** - for both CDATA and normal text nodes
  * <strong>`someText.type`</strong> : the string `"text"`
  * <strong>`someText.name`</strong> : the string `"#text"`
  * <strong>`someText.value`</strong> : the string content of the text node (with XML and numeric entities unescaped for non-CDATA elements)
  * <strong>`someText.parent`</strong> : reference to the the parent element table
* **Comment**
  * <strong>`someComment.type`</strong> : the string `"comment"`
  * <strong>`someComment.name`</strong> : the string `"#comment"`
  * <strong>`someComment.value`</strong> : the string content of the attribute
  * <strong>`someComment.parent`</strong> : reference to the the parent element or document table
* **Processing Instruction**
  * <strong>`someComment.type`</strong> : the string `"pi"`
  * <strong>`someComment.name`</strong> : the string name of the PI, e.g. `<?foo …?>` has a name of `"foo"`
  * <strong>`someComment.value`</strong> : the string content of the PI, i.e. everything but the name
  * <strong>`someComment.parent`</strong> : reference to the the parent element or document table

### Finding Text for a DOM Element

The following function can be used to calculate the "inner text" for an element:

    function elementText(el)
      local pieces = {}
      for _,n in ipairs(el.kids) do
        if n.type=='element' then pieces[#pieces+1] = elementText(n)
        elseif n.type=='text' then pieces[#pieces+1] = n.value
        end
      end
      return table.concat(pieces)
    end

    local xml  = [[<p>Hello <em>you crazy <b>World</b></em>!</p>>]]
    local para = SLAXML:dom(xml).root
    print(elementText(para)) --> "Hello you crazy World!""

### A Simpler DOM

If you want the DOM tables to be simpler-to-serialize you can supply the `simple` option via:

    local dom = SLAXML:dom(myXML,{ simple=true })

In this case no table will have a `parent` attribute, elements will not have the `el` collection, and the `attr` collection will be a simple array (without values accessible directly via attribute name). In short, the output will be a strict hierarchy with no internal references to other tables, and all data represented in exactly one spot.


## Known Limitations / TODO
- Does not require or enforce well-formed XML (or report/fail on invalid)
- No support for entity expansion other than
  `&lt; &gt; &quot; &apos; &amp;` and numeric ASCII entities like `&#10;`
- XML Declarations (`<?xml version="1.x"?>`) are incorrectly reported
  as Processing Instructions
- No support for DTDs
- No support for extended characters in element/attribute names


## History

### v0.4 2013-Feb-16
+ DOM adds `.parent` references
+ `SLAXML.ignoreWhitespace` is now `:parse(xml,{stripWhitespace=true})`
+ "simple" mode for DOM parsing

### v0.3 2013-Feb-15
+ Support namespaces for elements and attributes
  + `<foo xmlns="barURI">` will call `startElement("foo",nil)` followed by
    `namespace("barURI")` (and then `attribute("xmlns","barURI",nil)`);
    you must apply the namespace to your element after creation.
  + Child elements without a namespace prefix that inherit a namespace will
    receive `startElement("child","barURI")`
  + `<xy:foo>` will call `startElement("foo","uri-for-xy")`
  + `<foo xy:bar="yay">` will call `attribute("bar","yay","uri-for-xy")`
  + Runtime errors are generated for any namespace prefix that cannot be resolved
+ Add (optional) DOM parser that validates hierarchy and supports namespaces

### v0.2 2013-Feb-15
+ Supports expanding numeric entities e.g. `&#34;` -> `"`
+ Utility functions are local to parsing (not spamming the global namespace)

### v0.1 2013-Feb-7
+ Option to ignore whitespace-only text nodes
+ Supports unescaped > in attributes
+ Supports CDATA
+ Supports Comments
+ Supports Processing Instructions


## License
Copyright © 2013 [Gavin Kistner](mailto:!@phrogz.net)

Licensed under the [MIT License](http://opensource.org/licenses/MIT). See LICENSE.txt for more details.
