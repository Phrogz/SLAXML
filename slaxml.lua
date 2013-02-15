--[=====================================================================[
v0.2 Copyright © 2013 Gavin Kistner <!@phrogz.net>; MIT Licensed
See http://github.com/Phrogz/SLAXML for details.
--]=====================================================================]
SLAXML = {
	VERSION = "0.2",
	ignoreWhitespace = true,
	_call = {
		pi = function(target,content)
			print(string.format("<?%s %s?>",target,content))
		end,
		comment = function(content)
			print(string.format("<!-- %s -->",content))
		end,
		startElement = function(name)
			print(string.format("<%s>",name))
		end,
		attribute = function(name,value)
			print(string.format("  %s=%q",name,value))
		end,
		text = function(text)
			print(string.format("  text: %q",text))
		end,
		closeElement = function(name)
			print(string.format("</%s>",name))
		end,
	}
}

function SLAXML:parser(callbacks)
	return { _call=callbacks or self._call, parse=SLAXML.parse }
end

function SLAXML:parse(xml)
	-- Cache references for maximum speed
	local find, sub, gsub, char = string.find, string.sub, string.gsub, string.char
	-- local sub, gsub, find, push, pop, unescape = string.sub, string.gsub, string.find, table.insert, table.remove, unescape
	local first, last, match1, match2, pos2
	local pos = 1
	local state = "text"
	local textStart = 1
	local currentElement

	local entityMap  = { ["lt"]="<", ["gt"]=">", ["amp"]="&", ["quot"]='"', ["apos"]="'" }
	local entitySwap = function(orig,n,s) return entityMap[s] or n=="#" and char(s) or orig end
	local function unescape(str) return gsub( str, '(&(#?)([%d%a]+);)', entitySwap ) end

	local function finishText()
		if first>textStart and self._call.text then
			local text = sub(xml,textStart,first-1)
			if SLAXML.ignoreWhitespace then
				text = gsub(text,'^%s+','')
				text = gsub(text,'%s+$','')
				if #text==0 then text=nil end
			end
			if text then self._call.text(unescape(text)) end
		end
	end

	local function findPI()
		first, last, match1, match2 = find( xml, '^<%?([:%a_][:%w_.-]*) ?(.-)%?>', pos )
		if first then
			finishText()
			if self._call.pi then self._call.pi(match1,match2) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function findComment()
		first, last, match1 = find( xml, '^<!%-%-(.-)%-%->', pos )
		if first then
			finishText()
			if self._call.comment then self._call.comment(match1) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function startElement()
		first, last, match1 = find( xml, '^<([:%a_][:%w_.-]*)', pos )
		if first then
			finishText()
			currentElement = match1
			if self._call.startElement then self._call.startElement(match1) end
			pos = last+1
			return true
		end
	end

	local function findAttribute()
		first, last, match1 = find( xml, '^%s+([:%a_][:%w_.-]*)%s*=%s*', pos )
		if first then
			pos2 = last+1
			first, last, match2 = find( xml, '^"([^<"]+)"', pos2 ) -- FIXME: disallow non-entity ampersands
			if first then
				if self._call.attribute then self._call.attribute(match1,unescape(match2)) end
				pos = last+1
				return true
			else
				first, last, match2 = find( xml, "^'([^<']+)'", pos2 ) -- FIXME: disallow non-entity ampersands
				if first then
					-- TODO: unescape entities in match2
					if self._call.attribute then self._call.attribute(match1,unescape(match2)) end
					pos = last+1
					return true
				end
			end
		end
	end

	local function findCDATA()
		first, last, match1 = find( xml, '^<!%[CDATA%[(.-)%]%]>', pos )
		if first then
			finishText()
			if self._call.text then self._call.text(match1) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	local function closeElement()
		first, last, match1 = find( xml, '^%s*(/?)>', pos )
		if first then
			state = "text"
			pos = last+1
			textStart = pos
			if match1=="/" and self._call.closeElement then self._call.closeElement(currentElement) end
			return true
		end
	end

	local function findElementClose()
		first, last, match1 = find( xml, '^</([:%a_][:%w_.-]*)%s*>', pos )
		if first then
			finishText()
			if self._call.closeElement then self._call.closeElement(match1) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	while pos<#xml do
		if state=="text" then
			if not (findPI() or findComment() or findCDATA() or findElementClose()) then		
				if startElement() then
					state = "attributes"
				else
					-- TODO: scan up until the next < for speed
					pos = pos + 1
				end
			end
		elseif state=="attributes" then
			if not findAttribute() then
				if not closeElement() then
					error("Was in an element and couldn't find attributes or the close.")
				end
			end
		end
	end
end

function SLAXML:dom(xml,ignoreWhitespace,slim)
	SLAXML.ignoreWhitespace = ignoreWhitespace
	local push, pop = table.insert, table.remove
	local stack = {}
	local doc = { type="document", name="#doc", kids={} }
	local current = doc
	local builder = SLAXML:parser{
		startElement = function(name)
			local el = { type="element", name=name, kids={}, el={}, attr={} }
			if current==doc then
				if doc.root then
					error(("Encountered element '%s' when the document already has a root '%s' element"):format(name,doc.root.name))
				else
					doc.root = el
				end
			end
			if current.type~="element" and current.type~="document" then
				error(("Encountered an element inside of a %s"):format(current.type))
			else
				push(current.kids,el)
				if current.el then push(current.el,el) end
			end
			current = el
			push(stack,el)
		end,
		attribute = function(name,value)
			if not current or current.type~="element" then
				error(("Encountered an attribute %s=%s but I wasn't inside an element"):format(name,value))
			else
				current.attr[name] = value
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
					push(current.kids,{type='text',name='#text',value=value,text=value})
					if current.text then current.text = current.text..value else current.text=value end
				end
			end
		end,
		comment = function(value)
			push(current.kids,{type='comment',name='#comment',value=value,text=value})
		end,
		pi = function(name,value)
			push(current.kids,{type='pi',name=name,value=value})
		end
	}
	builder:parse(xml)
	return doc
end