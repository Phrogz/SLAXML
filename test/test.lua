package.path = '../?.lua;' .. package.path

require 'slaxml'
require 'io'
require 'lunity'

module( 'TEST_LXSC', lunity )

local XML = {}
for filename in io.popen('ls files'):lines() do
	XML[filename:match('^(.-)%.[^.]+$')] = io.open("files/"..filename):read('*all')
end


function test_dom()
	local doc = SLAXML:dom(XML['entities_and_namespaces'])
	assertEqual(doc.type,'document')
	assertEqual(doc.kids[1].type,'pi')
	assertEqual(#doc.kids,2)
	assertEqual(doc.kids[2],doc.root)
	assertEqual(#doc.root.kids,5)
	assertEqual(#doc.root.el,2)
	assertEqual(doc.root.attr.version,"1.0")
	assertEqual(doc.root.attr.xmlns,"http://www.w3.org/2005/07/scxml")
	assertEqual(doc.root.attr['xmlns:p'],"http://phrogz.net/")

	local s = doc.root.el[1]
	assertEqual(s.name,'script')
	assertEqual(s.type,'element')
	assertEqual(#s.kids,2)
	assertEqual(#s.el,0)
	assertEqual(s.kids[1].type,'text')
	assertEqual(s.kids[2].type,'text')

	local t = doc.root.el[2].el[1]
	assertEqual(t.name,'transition')
	assertEqual(t.kids[6].type,'comment')
end

function test_entities()
	local doc = SLAXML:dom(XML['entities_and_namespaces'])
	local s = doc.root.el[1]
	assertEqual(s.kids[1].text,' ampersand = "&"; ')
	assertEqual(s.kids[2].text,"\n\t\tquote = '\"'\n\t\tapos  = \"'\"\n\t")

	local t = doc.root.el[2].el[1]
	assertEqual(t.attr.cond,[[ampersand=='&' and quote=='"' and apos=="'"]])

	assertEqual(t.kids[6].value,' your code &gt; all ')
	assertEqual(t.kids[6].text,t.kids[6].value)
end

function test_namespaces()
	local scxmlNS  = "http://www.w3.org/2005/07/scxml"
	local phrogzNS = "http://phrogz.net/"
	local barNS    = "bar"

	local doc = SLAXML:dom(XML['entities_and_namespaces'])
	local s = doc.root.el[1]
	local p = doc.root.el[2].el[1].el[2]
	local foo  = doc.root.el[2].el[1].el[3]
	local bar1 = foo.el[1]
	local bar2 = doc.root.el[2].el[1].el[5]

	assertEqual(doc.root.nsURI,scxmlNS)
	assertEqual(s.nsURI,scxmlNS)
	assertEqual(p.name,'goToSlide')
	assertEqual(p.nsURI,phrogzNS)

	assertEqual(foo.name,'foo')
	assertEqual(foo.nsURI,barNS)
	assertEqual(bar1.nsURI,barNS)
	assertEqual(bar2.nsURI,scxmlNS)
end

runTests{ useANSI=false }