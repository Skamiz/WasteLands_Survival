local DataMesh = api.DataMesh

--[[ Difficult algorithms ]]--
function api.advanced_search(begin, serialize, vertex)
	local dm = DataMesh:new()
	local dd = dm._data
	local used = {}
	local operation = {[begin] = 1}
	local under_operation
	local step = 0
	local finished
	repeat
		finished = true
		under_operation = {}
		step = step + 1
		for v in pairs(operation) do
			if not used[serialize(v)] then
				used[serialize(v)] = 1
				if step > 1 then
					table.insert(dd, {v, step})
				end
				finished = false
				for v1 in pairs(vertex(v, step)) do
					under_operation[v1] = 1
				end
			end
		end

		operation = table.copy(under_operation)
	until finished
	return dm
end

function api.search(begin, serialize, vertex)
	return api.advanced_search(begin, serialize, vertex):map(function(r) return r[1] end)
end

function api.binary_search(func) -- 0 at 1, 1 at infinity, integer, monotonic
	if func(1) then return 0 end
	local i = 1
	while not func(i) do i = i * 8 end
	local threshold = i / 2
	while threshold >= 1 do
		if func(i) then
			i = i - threshold
		elseif not func(i + 1) then
			i = i + threshold
		end

		threshold = threshold / 2
	end
	return i
end

--[[ Transformers ]]--
function api.iterator(callback)
	return function(max, current)
		if max == current then return end
		current = current + 1
		return callback(current)
	end
end

function api.wrap_args(func, ...)
	local begin = {...}
	return function(...)
		return func(unpack(begin), ...)
	end
end

function api.restrict(min, val, max)
	return val < min and min or (val > max and max or val)
end

--[[ Small Functions ]]--
function api.sort_by_param(param, x)
	if not x then
		return function(a, b)
			return a[param] < b[param]
		end
	else
		return function(a, b)
			return a[param] > b[param]
		end
	end
end

function api.exposed_var()
	local tbl = {good = true}
	return tbl, function() return not tbl.good end
end

api.functions = {}
local func = api.functions

function func.identity(a)
	return a
end

function func.const(a)
	return function()
		return a
	end
end

function func.equal(a)
	return function(b)
		return a == b
	end
end

function func.empty() end

function func.new_object()
	return {}
end
