-- Optional parser that creates a flat DOM from parsing
require 'slaxml'
function SLAXML:dom(xml,ignoreWhitespace)
	SLAXML.ignoreWhitespace = ignoreWhitespace
	local push, pop = table.insert, table.remove
	local stack = {}
	local doc = { type="document", name="#doc", kids={} }
	local current = doc
	local builder = SLAXML:parser{
		startElement = function(name,nsURI)
			local el = { type="element", name=name, kids={}, el={}, attr={}, nsURI=nsURI, parent=current }
			if current==doc then
				if doc.root then
					error(("Encountered element '%s' when the document already has a root '%s' element"):format(name,doc.root.name))
				else
					doc.root = el
				end
			end
			push(current.kids,el)
			if current.el then push(current.el,el) end
			current = el
			push(stack,el)
		end,
		namespace = function(nsURI)
			current.nsURI = nsURI
		end,
		attribute = function(name,value,nsURI)
			if not current or current.type~="element" then
				error(("Encountered an attribute %s=%s but I wasn't inside an element"):format(name,value))
			else
				current.attr[name] = value
				push(current.attr,{type='attribute',name=name,nsURI=nsURI,value=value,parent=current})
			end
		end,
		closeElement = function(name)
			if current.name~=name or current.type~="element" then
				error(("Received a close element notification for '%s' but was inside a '%s' %s"):format(name,current.name,current.type))
			end
			pop(stack)
			current = stack[#stack]
		end,
		text = function(value)
			if current.type~='document' then
				if current.type~="element" then
					error(("Received a text notification '%s' but was inside a %s"):format(value,current.type))
				else
					push(current.kids,{type='text',name='#text',value=value,parent=current})
				end
			end
		end,
		comment = function(value)
			push(current.kids,{type='comment',name='#comment',value=value,parent=current})
		end,
		pi = function(name,value)
			push(current.kids,{type='pi',name=name,value=value,parent=current})
		end
	}
	builder:parse(xml)
	return doc
end
