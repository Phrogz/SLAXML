--[=====================================================================[
v0.1.1 Copyright © 2013 Gavin Kistner <!@phrogz.net>; MIT Licensed
See http://github.com/Phrogz/SLAXML for details.
--]=====================================================================]
SLAXML = {
	VERSION = "0.1.1",
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
	local find, sub, gsub = string.find, string.sub, string.gsub
	-- local sub, gsub, find, push, pop, unescape = string.sub, string.gsub, string.find, table.insert, table.remove, unescape
	local first, last, match1, match2, match3, match4, pos2
	local pos = 1
	local state = "text"
	local textStart = 1
	local currentElement

	function unescape(str)
		str  = gsub( str, '&lt;', '<' )
		str  = gsub( str, '&gt;', '>' )
		str  = gsub( str, '&quot;', '"' )
		str  = gsub( str, '&apos;', "'" )
		return gsub( str, '&amp;', '&' )
	end

	function finishText()
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

	function findPI()
		first, last, match1, match2 = find( xml, '^<%?([:%a_][:%w_.-]*) ?(.-)%?>', pos )
		if first then
			finishText()
			if self._call.pi then self._call.pi(match1,match2) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	function findComment()
		first, last, match1 = find( xml, '^<!%-%-(.-)%-%->', pos )
		if first then
			finishText()
			if self._call.comment then self._call.comment(match1) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	function startElement()
		first, last, match1 = find( xml, '^<([:%a_][:%w_.-]*)', pos )
		if first then
			finishText()
			currentElement = match1
			if self._call.startElement then self._call.startElement(match1) end
			pos = last+1
			return true
		end
	end

	function findAttribute()
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

	function findCDATA()
		first, last, match1 = find( xml, '^<!%[CDATA%[(.-)%]%]>', pos )
		if first then
			finishText()
			if self._call.text then self._call.text(match1) end
			pos = last+1
			textStart = pos
			return true
		end
	end

	function closeElement()
		first, last, match1 = find( xml, '^%s*(/?)>', pos )
		if first then
			state = "text"
			pos = last+1
			textStart = pos
			if match1=="/" and self._call.closeElement then self._call.closeElement(currentElement) end
			return true
		end
	end

	function findElementClose()
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