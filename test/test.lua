package.path = '../?.lua;' .. package.path

local SLAXML = require 'slaxdom'
require 'io'
require 'lunity'

module( 'TEST_SLAXML', lunity )

local XML = {}
for filename in io.popen('ls files'):lines() do
	XML[filename:match('^(.-)%.[^.]+$')] = io.open("files/"..filename):read('*all')
end

local function countParsings(xmlName,options,expected)
	local counts,counters = {},{}
	expected.closeElement = expected.startElement
	for name,_ in pairs(expected) do
		counts[name]   = 0
		counters[name] = function() counts[name]=counts[name]+1 end
	end
	SLAXML:parser(counters):parse(XML[xmlName],options)
	for name,ct in pairs(expected) do
		assertEqual(counts[name],ct,"There should have been be exactly "..ct.." "..name.."() callback(s) in "..xmlName..", not "..counts[name])
	end
end

function test_namespace()
	local elementStack = {}
	SLAXML:parser{
		startElement = function(name,nsURI)
			table.insert(elementStack,{name=name,nsURI=nsURI})
		end,
		closeElement = function(name,nsURI)
			local pop = table.remove(elementStack)
			assertEqual(name,pop.name,"Got close "..name.." to close "..pop.name)
			assertEqual(nsURI,pop.nsURI,"Got close namespace "..(nsURI or "nil").." to close namespace "..(pop.nsURI or "nil"))
		end,
	}:parse(XML['namespace_prefix'])
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

function test_slim_and_trim_dom()
	local function checkParentage(el)
		for _,child in ipairs(el.kids) do
			assertNil(child.parent,'"slim" dom children should not have a parent')
			if child.kids then checkParentage(child) end
		end
	end

	local doc = SLAXML:dom(XML['entities_and_namespaces'],{simple=true,stripWhitespace=true})
	assertEqual(doc.type,'document')
	assertEqual(doc.kids[1].type,'pi')
	assertEqual(#doc.kids,2)
	assertEqual(doc.kids[2],doc.root)
	assertEqual(#doc.root.kids,3)
	assertNil(doc.root.el)
	assertNil(doc.root.attr.version)
	assertNil(doc.root.attr.xmlns)
	assertNil(doc.root.attr['xmlns:p'])
	assertEqual(#doc.root.attr,3)

	checkParentage(doc)

	local s = doc.root.kids[1]
	assertEqual(s.name,'script')
	assertEqual(s.type,'element')
	assertEqual(#s.kids,2)
	assertEqual(s.kids[1].type,'text')
	assertEqual(s.kids[2].type,'text')

	local t = doc.root.kids[2].kids[1]
	assertEqual(t.name,'transition')
	assertEqual(#t.kids,5)
	assertEqual(t.kids[3].type,'comment')
end

function test_dom_entities()
	local doc = SLAXML:dom(XML['entities_and_namespaces'])
	local s = doc.root.el[1]
	assertEqual(s.kids[1].value,' ampersand = "&"; ')
	assertEqual(s.kids[2].value,"quote = '\"'; apos  = \"'\"")

	local t = doc.root.el[2].el[1]
	assertEqual(t.attr.cond,[[ampersand=='&' and quote=='"' and apos=="'"]])

	assertEqual(t.kids[6].value,' your code &gt; all ')
end

function test_xml_namespace()
	local doc = SLAXML:dom(XML['xml_namespace'])
	for i,attr in ipairs(doc.root.attr) do
		if attr.name=='space' then
			assertEqual(attr.nsURI,[[http://www.w3.org/XML/1998/namespace]])
			break
		end
	end
end

function test_xml_namespace_immediate_use()
	local doc = SLAXML:dom(XML['namespace_declare_and_use'])
	local cat1 = doc.root.el[1]
	assertEqual(cat1.name,'cat')
	assertEqual(cat1.nsURI,'cat')
	local cat2 = cat1.el[1]
	assertEqual(cat2.name, 'cat')
	assertEqual(cat2.nsURI,'cat')
	local dog1 = cat1.el[2]
	assertEqual(dog1.name, 'dog')
	assertEqual(dog1.nsURI,'dog')
	local cat3 = dog1.el[1]
	assertEqual(cat3.name, 'cat')
	assertEqual(cat3.nsURI,'cat')
	local hog1 = dog1.el[2]
	assertEqual(hog1.name, 'hog')
	assertEqual(hog1.nsURI,'hog')
	for _,attr in ipairs(hog1.attr) do
		if attr.value=='yes' then
			assertEqual(attr.nsURI,attr.name)
		end
	end
	local hog2 = hog1.el[1]
	assertEqual(hog2.name, 'hog')
	assertEqual(hog2.nsURI,'hog')
	local bog1 = hog1.el[2]
	assertEqual(bog1.name, 'bog')
	assertEqual(bog1.nsURI,'bog')
	local dog2 = dog1.el[3]
	assertEqual(dog2.name, 'dog')
	assertEqual(dog2.nsURI,'dog')
	local cog2 = doc.root.el[2]
	assertEqual(cog2.name, 'cog')
	assertEqual(cog2.nsURI,'cog')
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

function testz_invalid_documents()
	local silentParser = SLAXML:parser{}
	assertErrors(silentParser.parse, silentParser, XML['invalid_unquoted']        )
	assertErrors(silentParser.parse, silentParser, XML['invalid_pi_only']         )
	assertErrors(silentParser.parse, silentParser, XML['invalid_unclosed_tags']   )
	assertErrors(silentParser.parse, silentParser, XML['invalid_literal_gtamplt'] )
end

function test_simplest()
	countParsings('root_only',{},{
		pi           = 0,
		comment      = 0,
		startElement = 1,
		attribute    = 0,
		text         = 0,
		namespace    = 0,
	})
end

function test_whitespace()
	countParsings('lotsaspace',{},{
		pi           = 0,
		comment      = 0,
		startElement = 3,
		attribute    = 2,
		text         = 5,
		namespace    = 0,
	})

	countParsings('lotsaspace',{stripWhitespace=true},{
		pi           = 0,
		comment      = 0,
		startElement = 3,
		attribute    = 2,
		text         = 2,
		namespace    = 0,
	})

	local simple = SLAXML:dom(XML['lotsaspace'],{stripWhitespace=true}).root
	local a = simple.el[1]
	assertEqual(a.kids[1].value,"It's the end of the world\n  as we know it, and I feel\n	fine.")
	assertEqual(a.kids[2].value,"\nIt's a [raw][[raw]] >\nstring that <do/> not care\n	about honey badgers.\n\n  ")
end

runTests{ useANSI=false }