function api.sandbox_loadstring(func)
	if func:byte(1) == 27 then
		return false, "Cannot run bytecode"
	end
	local err
	func, err = loadstring(func)
	if not func then
		return false, err
	end
	return true, func
end

function api.sandbox_call(sandbox, func, ...)
	if type(func) == "string" then
		local err
		err, func = api.sandbox_loadstring(func)
		if not err then
			return false, func
		end
	end

	setfenv(func, sandbox)
	local good, data = pcall(func, ...)
	if not good then
		return false, data
	else
		return true, data
	end
end

local function timeout()
	debug.sethook()
	error("Execution timed out")
end

function api.limited_call(limit, func, ...)
	return pcall(function(...)
		debug.sethook(timeout, "", limit)
		local ok, val = pcall(func, ...)
		debug.sethook()
		assert(ok, val)
		return val
	end, ...)
end
