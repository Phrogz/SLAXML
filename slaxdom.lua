-- Optional parser that creates a flat DOM from parsing
local SLAXML = require 'slaxml'
function SLAXML:dom(xml,opts)
	if not opts then opts={} end
	local rich = not opts.simple
	local push, pop = table.insert, table.remove
	local doc = {type="document", name="#doc", kids={}}
	local current,stack = doc, {doc}
	local builder = SLAXML:parser{
		startElement = function(name,nsURI,nsPrefix)
			local el = { type="element", name=name, kids={}, el=rich and {} or nil, attr={}, nsURI=nsURI, nsPrefix=nsPrefix, parent=rich and current or nil }
			if current==doc then
				if doc.root then error(("Encountered element '%s' when the document already has a root '%s' element"):format(name,doc.root.name)) end
				doc.root = rich and el or nil
			end
			push(current.kids,el)
			if current.el then push(current.el,el) end
			current = el
			push(stack,el)
		end,
		attribute = function(name,value,nsURI,nsPrefix)
			if not current or current.type~="element" then error(("Encountered an attribute %s=%s but I wasn't inside an element"):format(name,value)) end
			local attr = {type='attribute',name=name,nsURI=nsURI,nsPrefix=nsPrefix,value=value,parent=rich and current or nil}
			if rich then current.attr[name] = value end
			push(current.attr,attr)
		end,
		closeElement = function(name)
			if current.name~=name or current.type~="element" then error(("Received a close element notification for '%s' but was inside a '%s' %s"):format(name,current.name,current.type)) end
			pop(stack)
			current = stack[#stack]
		end,
		text = function(value,cdata)
			-- documents may only have text node children that are whitespace: https://www.w3.org/TR/xml/#NT-Misc
			if current.type=='document' and not value:find('^%s+$') then error(("Document has non-whitespace text at root: '%s'"):format(value:gsub('[\r\n\t]',{['\r']='\\r', ['\n']='\\n', ['\t']='\\t'}))) end
			push(current.kids,{type='text',name='#text',cdata=cdata and true or nil,value=value,parent=rich and current or nil})
		end,
		comment = function(value)
			push(current.kids,{type='comment',name='#comment',value=value,parent=rich and current or nil})
		end,
		pi = function(name,value)
			push(current.kids,{type='pi',name=name,value=value,parent=rich and current or nil})
		end
	}
	builder:parse(xml,opts)
	return doc
end

local attresc = {["<"]="&lt;", ["&"]="&amp;", ['"']="&quot;"}
local textesc = {["<"]="&lt;", ["&"]="&amp;"}

-- opts.indent: number of spaces, or string
-- opts.sort:   sort attributes?
-- opts.omit:   namespaces to strip during serialization
-- opts.cdata:  true to force all text nodes to be cdata, false to force all text nodes to be plain, nil to preserve
function SLAXML:xml(n,opts)
	opts = opts or {}
	local out = {}
	local tab = opts.indent and (type(opts.indent)=="number" and string.rep(" ",opts.indent) or opts.indent) or ""
	local ser = {}
	local omit = {}
	if opts.omit then for _,s in ipairs(opts.omit) do omit[s]=true end end

	function ser.document(n)
		for _,kid in ipairs(n.kids) do
			if ser[kid.type] then ser[kid.type](kid,0) end
		end
	end

	function ser.pi(n,depth)
		depth = depth or 0
		table.insert(out, tab:rep(depth)..'<?'..n.name..' '..n.value..'?>')
	end

	function ser.element(n,depth)
		if n.nsURI and omit[n.nsURI] then return end
		depth = depth or 0
		local indent = tab:rep(depth)
		local name = n.nsPrefix and n.nsPrefix..':'..n.name or n.name
		local result = indent..'<'..name
		if n.attr and n.attr[1] then
			local sorted = n.attr
			if opts.sort then
				sorted = {}
				for i,a in ipairs(n.attr) do sorted[i]=a end
				table.sort(sorted,function(a,b)
					if a.nsPrefix and b.nsPrefix then
						return a.nsPrefix==b.nsPrefix and a.name<b.name or a.nsPrefix<b.nsPrefix
					elseif not (a.nsPrefix or b.nsPrefix) then
						return a.name<b.name
					elseif b.nsPrefix then
						return true
					else
						return false
					end
				end)
			end

			local attrs = {}
			for _,a in ipairs(sorted) do
				if (not a.nsURI or not omit[a.nsURI]) and not (omit[a.value] and a.name:find('^xmlns:')) then
					attrs[#attrs+1] = ' '..(a.nsPrefix and (a.nsPrefix..':') or '')..a.name..'="'..a.value:gsub('[<&"]',attresc)..'"'
				end
			end
			result = result..table.concat(attrs,'')
		end
		result = result .. (n.kids and n.kids[1] and '>' or '/>')
		table.insert(out, result)
		if n.kids and n.kids[1] then
			for _,kid in ipairs(n.kids) do
				if ser[kid.type] then ser[kid.type](kid,depth+1) end
			end
			table.insert(out, indent..'</'..name..'>')
		end
	end

	function ser.text(n,depth)
		if opts.cdata==true or (n.cdata and opts.cdata~=false) then
			table.insert(out, tab:rep(depth)..'<![CDATA['..n.value..']]>')
		else
			table.insert(out, tab:rep(depth)..n.value:gsub('[<&]', textesc))
		end
	end

	function ser.comment(n,depth)
		table.insert(out, tab:rep(depth)..'<!--'..n.value..'-->')
	end

	ser[n.type](n,0)

	return table.concat(out, opts.indent and '\n' or '')
end

-- breadth-first crawl starting at the node, invoking callbacks based on node type and then name
-- SLAXML:survey(doc, {comment={['*']=print}, element={root=tostring, leaf=holler}})
function SLAXML:survey(node,callbacks)
	local q,i = {node},1
	while q[i] do
		node = q[i]
		if callbacks[node.type] then
			local callback = callbacks[node.type][node.name] or callbacks[node.type]['*']
			if callback then callback(node) end
		end
		if node.kids then
			local n=#q
			for i,k in ipairs(node.kids) do q[n+i]=k end
		end
		i = i+1
	end
end

-- depth-first crawl starting at the node, invoking callbacks based on node type and then name
-- SLAXML:survey(doc, {comment={['*']=print}, element={root=tostring, leaf=holler}})
function SLAXML:dive(node,callbacks)
	local q = {node}
	while q[1] do
		node = table.remove(q)
		if callbacks[node.type] then
			local callback = callbacks[node.type][node.name] or callbacks[node.type]['*']
			if callback then callback(node) end
		end
		if node.kids then
			local n=#q+#node.kids+1
			for i,k in ipairs(node.kids) do q[n-i]=k end
		end
	end
end

-- find the namespace prefix matching the supplied namespace URI, walking up from the node
function SLAXML:prefix(node,nsURI)
	while node do
		if node.attr then for _,a in ipairs(node.attr) do
			if a.value==nsURI then
				local _,_,prefix = a.name:find('^xmlns:(%w+)')
				if prefix then return prefix end
			end
		end end
		node = node.parent
	end
end

-- Find an attribute on an element by nsURI and name; if value is non-nil, also set the value
-- If value is supplied and the attribute does not exist, it will be created
function SLAXML:attr(el,nsURI,name,value)
	if not el.attr then return end
	for _,a in ipairs(el.attr) do
		if a.name==name and a.nsURI==nsURI then
			if value~=nil then
				value=tostring(value)
				el.attr[name] = value
				a.value = value
			end
			return a
		end
	end
	if value~=nil then
		-- if we got here, the attribute didn't exist, and must be created
		local nsPrefix = nsURI and self:prefix(el,nsURI)
		local a = {type='attribute',name=name,nsURI=nsURI,nsPrefix=nsPrefix,value=value,parent=el}
		table.insert(el.attr,a)
		-- TODO: detect if this dom is rich; don't add parent or shortcut value unless it is
		el.attr[name] = value
		return a
	end
end

-- Remove an attribute node from its parent element
function SLAXML:removeAttr(el,nsURI,name)
	if not el.attr then return end
	for i,a in ipairs(el.attr) do
		if a.name==name and a.nsURI==nsURI then
			el.attr[name]=nil
			return table.remove(el.attr,i)
		end
	end
end

local function removeFromArray(a,v)
	for i,v2 in ipairs(a) do if v2==v then table.remove(a,i) return i end end
end

-- Remove a node from the DOM; returns false if the node could not be removed, nil otherwise
function SLAXML:remove(node, parent)
	parent = parent or node.parent
	if not parent then return end
	if node.type=='attribute' then parent.attr[node.name]=nil end
	removeFromArray(node.type=='attribute' and parent.attr or parent.kids, node)
	if parent.el then removeFromArray(parent.el) end
	return true
end

-- Move a node to a new parent
function SLAXML:reparent(node, mom)
	if node.parent==mom then return end
	if self:remove(node) then
		if mom then
			if node.type=='attribute' then
				table.insert(mom.attr, node)
				mom.attr[node.name] = node.value
			else
				table.insert(mom.kids, node)
				if node.type=='element' and mom.el then table.insert(mom.el, node) end
			end
		end
		node.parent = mom
		return true
	end
end

-- Find the combined text from the node and all its descendants
function SLAXML:text(node)
	if node.type=='element' then
		local pieces = {}
		for _,n in ipairs(node.kids) do
			if n.type=='element' then
				pieces[#pieces+1] = self:text(n)
			elseif n.type=='text' then
				pieces[#pieces+1] = n.value
			end
		end
		return table.concat(pieces)
	elseif node.type=='document' then
		return text(node.root)
	else
		return n.value
	end
end

-- Return the first descendant node (not self) matching the specified criteria; use nil for any to ignore that criteria
-- type:  string or nil
-- nsURI: string or nil
-- name:  string or nil
-- value: string or nil
-- attr:  table of name=value that must be matched (nsURI ignored)
function SLAXML:find(node, criteria)
	if node.kids then
		for _,k in ipairs(node.kids) do
			if (not criteria.type  or (criteria.type ==k.type))  and
			   (not criteria.nsURI or (criteria.nsURI==k.nsURI)) and
			   (not criteria.name  or (criteria.name ==k.name))  and
			   (not criteria.value or (criteria.value==k.value)) then
				local ok = true
				if criteria.attr then
					if k.attr then
						for name,value in pairs(criteria.attr) do
							if k.attr[name]~=value then ok=false break end
						end
					else
						ok = false
					end
				end
				if ok then return k end
			elseif k.kids then
				local n = self:find(k, criteria)
				if n then return n end
			end
		end
	end
end

return SLAXML