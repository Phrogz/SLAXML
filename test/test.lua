package.path = '../?.lua;' .. package.path

require 'slaxdom'
require 'io'
require 'lunity'

module( 'TEST_LXSC', lunity )

local XML = {}
for filename in io.popen('ls files'):lines() do
	XML[filename:match('^(.-)%.[^.]+$')] = io.open("files/"..filename):read('*all')
end

function test_dom()
	local function checkParentage(el)
		for _,child in ipairs(el.kids) do
			assertEqual(child.parent,el,("'%s' children should have a .parent pointing to their parent '%s'"):format(child.type,el.type))
			if child.kids then checkParentage(child) end
		end
	end

	local doc = SLAXML:dom(XML['entities_and_namespaces'])
	assertEqual(doc.type,'document')
	assertEqual(doc.kids[1].type,'pi')
	assertEqual(#doc.kids,2)
	assertEqual(doc.kids[2],doc.root)
	assertEqual(#doc.root.kids,7)
	assertEqual(#doc.root.el,3)
	assertEqual(doc.root.attr.version,"1.0")
	assertEqual(doc.root.attr.xmlns,"http://www.w3.org/2005/07/scxml")
	assertEqual(doc.root.attr['xmlns:p'],"http://phrogz.net/")

	checkParentage(doc)

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

	for _,attr in ipairs(doc.root.attr) do
		assertEqual(attr.parent,doc.root,"Attributes should reference their parent element")
		assertEqual(attr.type,"attribute")
		assertNil(attr.nsURI,"No attribute on the root of this document has a namespace")
	end
end

function test_dom_entities()
	local doc = SLAXML:dom(XML['entities_and_namespaces'])
	local s = doc.root.el[1]
	assertEqual(s.kids[1].text,' ampersand = "&"; ')
	assertEqual(s.kids[2].text,"quote = '\"'; apos  = \"'\"")

	local t = doc.root.el[2].el[1]
	assertEqual(t.attr.cond,[[ampersand=='&' and quote=='"' and apos=="'"]])

	assertEqual(t.kids[6].value,' your code &gt; all ')
	assertEqual(t.kids[6].text,t.kids[6].value)
end

function test_dom_namespaces()
	local scxmlNS  = "http://www.w3.org/2005/07/scxml"
	local phrogzNS = "http://phrogz.net/"
	local barNS    = "bar"
	local xNS,yNS  = "xNS", "yNS"

	local doc = SLAXML:dom(XML['entities_and_namespaces'])
	local s = doc.root.el[1]
	local p = doc.root.el[2].el[1].el[2]
	local t = doc.root.el[2].el[1]
	local foo  = t.el[3]
	local bar1 = foo.el[1]
	local bar2 = t.el[4]
	local wrap = doc.root.el[3]
	local e = wrap.el[1]

	assertEqual(doc.root.nsURI,scxmlNS)
	assertEqual(s.nsURI,scxmlNS)
	assertEqual(p.name,'goToSlide')
	assertEqual(p.nsURI,phrogzNS)

	assertEqual(foo.name,'foo')
	assertEqual(foo.nsURI,barNS)
	assertEqual(bar1.nsURI,barNS)
	assertEqual(bar2.nsURI,scxmlNS)

	assertEqual(wrap.nsURI,scxmlNS)
	assertEqual(wrap.attr['xmlns:x'],xNS)
	assertEqual(wrap.attr['xmlns:y'],yNS)
	assertEqual(e.name,'e')
	assertEqual(e.nsURI,scxmlNS)
	assertEqual(#e.attr,6)
	assertEqual(e.attr.a1,"a1")
	assert(e.attr.a2=="a2" or e.attr.a2=="a2-x")

	local nsByValue = {}
	for _,attr in ipairs(e.attr) do nsByValue[attr.value] = attr.nsURI end
	assertNil(nsByValue['a1'])
	assertNil(nsByValue['a2'])
	assertNil(nsByValue['a3'])
	assertEqual(nsByValue['a2-x'],xNS)
	assertEqual(nsByValue['a3-x'],xNS)
	assertEqual(nsByValue['a3-y'],yNS)
end

runTests{ useANSI=false }

