--[=========================================================================[
   Lunity v0.12 by Gavin Kistner
   See http://github.com/Phrogz/Lunity for usage documentation.
   Licensed under Creative Commons Attribution 3.0 United States License.
   See http://creativecommons.org/licenses/by/3.0/us/ for details.
--]=========================================================================]

-- Cache these so we can silence the real ones during a run
local print,write = print,io.write

-- FIXME: this will fail if two test suites are running interleaved
local assertsPassed, assertsAttempted
local function assertionSucceeded()
	assertsPassed = assertsPassed + 1
	write('.')
	return true
end

-- This is the table that will be used as the environment for the tests,
-- making assertions available within the file.
local lunity = setmetatable({}, {__index=_G})

function lunity.fail(msg)
	assertsAttempted = assertsAttempted + 1
	if not msg then msg = "(test failure)" end
	error(msg, 2)
end

function lunity.assert(testCondition, msg)
	assertsAttempted = assertsAttempted + 1
	if not testCondition then
		if not msg then msg = "assert() failed: value was "..tostring(testCondition) end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertEqual(actual, expected, msg)
	assertsAttempted = assertsAttempted + 1
	if actual~=expected then
		if not msg then
			msg = string.format("assertEqual() failed: expected %s, was %s",
				tostring(expected),
				tostring(actual)
			)
		end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertType(actual, expectedType, msg)
	assertsAttempted = assertsAttempted + 1
	if type(actual) ~= expectedType then
		if not msg then
			msg = string.format("assertType() failed: value %s is a %s, expected to be a %s",
				tostring(actual),
				type(actual),
				expectedType
			)
		end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertTableEquals(actual, expected, msg, keyPath)
	assertsAttempted = assertsAttempted + 1
	-- Easy out
	if actual == expected then
		if not keyPath then
			return assertionSucceeded()
		else
			return true
		end
	end

	if not keyPath then keyPath = {} end

	if type(actual) ~= 'table' then
		if not msg then
			msg = "Value passed to assertTableEquals() was not a table."
		end
		error(msg, 2 + #keyPath)
	end

	-- Ensure all keys in t1 match in t2
	for key,expectedValue in pairs(expected) do
		keyPath[#keyPath+1] = tostring(key)
		local actualValue = actual[key]
		if type(expectedValue)=='table' then
			if type(actualValue)~='table' then
				if not msg then
					msg = "Tables not equal; expected "..table.concat(keyPath,'.').." to be a table, but was a "..type(actualValue)
				end
				error(msg, 1 + #keyPath)
			elseif expectedValue ~= actualValue then
				lunity.assertTableEquals(actualValue, expectedValue, msg, keyPath)
			end
		else
			if actualValue ~= expectedValue then
				if not msg then
					if actualValue == nil then
						msg = "Tables not equal; missing key '"..table.concat(keyPath,'.').."'."
					else
						msg = "Tables not equal; expected '"..table.concat(keyPath,'.').."' to be "..tostring(expectedValue)..", but was "..tostring(actualValue)
					end
				end
				error(msg, 1 + #keyPath)
			end
		end
		keyPath[#keyPath] = nil
	end

	-- Ensure actual doesn't have keys that aren't expected
	for k,_ in pairs(actual) do
		if expected[k] == nil then
			if not msg then
				msg = "Tables not equal; found unexpected key '"..table.concat(keyPath,'.').."."..tostring(k).."'"
			end
			error(msg, 2 + #keyPath)
		end
	end

	return assertionSucceeded()
end

function lunity.assertNotEqual(actual, expected, msg)
	assertsAttempted = assertsAttempted + 1
	if actual==expected then
		if not msg then
			msg = string.format("assertNotEqual() failed: value not allowed to be %s",
				tostring(actual)
			)
		end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertTrue(actual, msg)
	assertsAttempted = assertsAttempted + 1
	if actual ~= true then
		if not msg then
			msg = string.format("assertTrue() failed: value was %s, expected true",
				tostring(actual)
			)
		end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertFalse(actual, msg)
	assertsAttempted = assertsAttempted + 1
	if actual ~= false then
		if not msg then
			msg = string.format("assertFalse() failed: value was %s, expected false",
				tostring(actual)
			)
		end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertNil(actual, msg)
	assertsAttempted = assertsAttempted + 1
	if actual ~= nil then
		if not msg then
			msg = string.format("assertNil() failed: value was %s, expected nil",
				tostring(actual)
			)
		end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertNotNil(actual, msg)
	assertsAttempted = assertsAttempted + 1
	if actual == nil then
		if not msg then msg = "assertNotNil() failed: value was nil" end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertTableEmpty(actual, msg)
	assertsAttempted = assertsAttempted + 1
	if type(actual) ~= "table" then
		msg = string.format("assertTableEmpty() failed: expected a table, but got a %s",
			type(table)
		)
		error(msg, 2)
	else
		local key, value = next(actual)
		if key ~= nil then
			if not msg then
				msg = string.format("assertTableEmpty() failed: table has non-nil key %s=%s",
					tostring(key),
					tostring(value)
				)
			end
			error(msg, 2)
		end
		return assertionSucceeded()
	end
end

function lunity.assertTableNotEmpty(actual, msg)
	assertsAttempted = assertsAttempted + 1
	if type(actual) ~= "table" then
		msg = string.format("assertTableNotEmpty() failed: expected a table, but got a %s",
			type(actual)
		)
		error(msg, 2)
	else
		if next(actual) == nil then
			if not msg then
				msg = "assertTableNotEmpty() failed: table has no keys"
			end
			error(msg, 2)
		end
		return assertionSucceeded()
	end
end

function lunity.assertSameKeys(t1, t2, msg)
	assertsAttempted = assertsAttempted + 1
	local function bail(k,x,y)
		if not msg then msg = string.format("Table #%d has key '%s' not present in table #%d",x,tostring(k),y) end
		error(msg, 3)
	end
	for k,_ in pairs(t1) do if t2[k]==nil then bail(k,1,2) end end
	for k,_ in pairs(t2) do if t1[k]==nil then bail(k,2,1) end end
	return assertionSucceeded()
end

-- Ensures that the value is a function OR may be called as one
function lunity.assertInvokable(value, msg)
	assertsAttempted = assertsAttempted + 1
	local meta = getmetatable(value)
	if (type(value) ~= 'function') and not (meta and meta.__call and (type(meta.__call)=='function')) then
		if not msg then
			msg = string.format("assertInvokable() failed: '%s' can not be called as a function",
				tostring(value)
			)
		end
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertErrors(invokable, ...)
	lunity.assertInvokable(invokable)
	if pcall(invokable,...) then
		local msg = string.format("assertErrors() failed: %s did not raise an error",
			tostring(invokable)
		)
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.assertDoesNotError(invokable, ...)
	lunity.assertInvokable(invokable)
	if not pcall(invokable,...) then
		local msg = string.format("assertDoesNotError() failed: %s raised an error",
			tostring(invokable)
		)
		error(msg, 2)
	end
	return assertionSucceeded()
end

function lunity.is_nil(value)      return type(value)=='nil'      end
function lunity.is_boolean(value)  return type(value)=='boolean'  end
function lunity.is_number(value)   return type(value)=='number'   end
function lunity.is_string(value)   return type(value)=='string'   end
function lunity.is_table(value)    return type(value)=='table'    end
function lunity.is_function(value) return type(value)=='function' end
function lunity.is_thread(value)   return type(value)=='thread'   end
function lunity.is_userdata(value) return type(value)=='userdata' end

local function run(self, opts)
	if not opts then opts = {} end
	if opts.quiet then
		_G.print = function() end
		io.write = function() end
	end

	assertsPassed = 0
	assertsAttempted = 0

	local useANSI,useHTML = true, false
	if opts.useHTML ~= nil then useHTML=opts.useHTML end
	if not useHTML and opts.useANSI ~= nil then useANSI=opts.useANSI end

	local suiteName = getmetatable(self).name

	if useHTML then
		print("<h2 style='background:#000; color:#fff; margin:1em 0 0 0; padding:0.1em 0.4em; font-size:120%'>"..suiteName.."</h2><pre style='margin:0; padding:0.2em 1em; background:#ffe; border:1px solid #eed; overflow:auto'>")
	else
		print(string.rep('=',78))
		print(suiteName)
		print(string.rep('=',78))
	end
	io.stdout:flush()


	local testnames = {}
	for name, test in pairs(self) do
		if type(test)=='function' and name~='before' and name~='after' then
			testnames[#testnames+1]=name
		end
	end
	table.sort(testnames)


	local startTime = os.clock()
	local passed = 0
	for _,name in ipairs(testnames) do
		local scratchpad = {}
		write(name..": ")
		if self.before then self.before(scratchpad) end
		local successFlag, errorMessage = pcall(self[name], scratchpad)
		if successFlag then
			print("pass")
			passed = passed + 1
		else
			if useANSI then
				print("\27[31m\27[1mFAIL!\27[0m")
				print("\27[31m"..errorMessage.."\27[0m")
			elseif useHTML then
				print("<b style='color:red'>FAIL!</b>")
				print("<span style='color:red'>"..errorMessage.."</span>")
			else
				print("FAIL!")
				print(errorMessage)
			end
		end
		io.stdout:flush()
		if self.after then self.after(scratchpad) end
	end
	local elapsed = os.clock() - startTime

	if useHTML then
		print("</pre>")
	else
		print(string.rep('-', 78))
	end

	print(string.format("%d/%d tests passed (%0.1f%%)",
		passed,
		#testnames,
		100 * passed / #testnames
	))

	if useHTML then print("<br>") end

	print(string.format("%d total successful assertion%s in ~%.0fms (%.0f assertions/second)",
		assertsPassed,
		assertsPassed == 1 and "" or "s",
		elapsed*1000,
		assertsAttempted / elapsed
	))

	if not useHTML then print("") end
	io.stdout:flush()

	if opts.quiet then
		_G.print = print
		io.write = write
	end
end

return function(name)
	return setmetatable(
		{test=setmetatable({}, {__call=run, name=name or '(test suite)'})},
		{__index=lunity}
	)
end