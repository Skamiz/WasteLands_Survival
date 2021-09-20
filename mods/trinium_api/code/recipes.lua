api.recipes = {
	methods = {}, -- unordered map
	usages = {}, -- unordered map of lists
	recipes = {}, -- unordered map of lists
	recipes_by_method = {}, -- unordered_map of lists
	recipe_registry = {}, -- list
	implementing_objects = {}, -- {ItemString => RecipeId<>}
	type_to_impl = {}, -- {String => ItemString<>}
}
local recipes = api.recipes
local func = api.functions
local dm = api.DataMesh

function recipes.stringify(size, inputs)
	local string = inputs[1] or ""
	for i = 2, size do
		string = string .. ";" .. (inputs[i] or "")
	end
	return string
end

function recipes.convert_to_itemmap(inputs)
	local map = {}
	for _, z in pairs(inputs) do
		local k, v = unpack(z:split" ")
		v = tonumber(v) or 1
		if k then map[k] = (map[k] or 0) + v end
	end
	map[""] = nil
	return map
end

local split = function(k) return k:split" " end
local concat = function(k) return table.concat(k, " ") end
function recipes.divide(a, b)
	a = dm:new():data(a):map(split):map(function(x) return {x[1], tonumber(x[2])} end)
	b = dm:new():data(b):map(split):map(function(x) return {x[1], tonumber(x[2])} end)
	local gcd = 0
	a:forEach(function(r) gcd = math.gcd(r[2], gcd) end)
	b:forEach(function(r) gcd = math.gcd(r[2], gcd) end)
	if not gcd then return a:map(concat):data(), b:map(concat):data() end
	a = a:map(function(x) return {x[1], x[2] ~= gcd and math.floor(x[2] / gcd) or nil} end):map(concat):data()
	b = b:map(function(x) return {x[1], x[2] ~= gcd and math.floor(x[2] / gcd) or nil} end):map(concat):data()
	return a, b
end

function recipes.add(method, inputs, outputs, data)
	local method_table = assert(api.recipes.methods[method], "Method " .. method .. " not registered!")
	data = data or {}

	-- Processing inputs (e.g., MC method of creating workbench recipes)
	inputs, outputs, data = method_table.process(inputs, outputs, data)
	if inputs == -1 or outputs == -1 or data == -1 then return end

	-- Redoing all the redirects
	local redirects = {method = 1}
	while type(method_table.callback(inputs, outputs, data)) == "string" do
		method = method_table.callback(inputs, outputs, data)
		assert(not redirects[method], "Infinite loop detected!")
		method_table = assert(api.recipes.methods[method], "Method " .. method .. " not registered!")
		redirects[method] = 1
	end
	data.author_mod = minetest.get_current_modname() or "???"

	assert(method_table.input_amount >= table.maxn(inputs), "Too many inputs!")
	assert(method_table.output_amount >= table.maxn(outputs), "Too many outputs!")

	assert(method_table.recipe_correct(data),
			"Invalid recipe: " .. recipes.stringify(method_table.input_amount, inputs) ..
					" for " .. method .. " by " .. data.author_mod)

	-- Registering recipe
	local new_amount = #recipes.recipe_registry + 1

	if data.divisible then
		inputs, outputs = recipes.divide(inputs, outputs)
	end

	recipes.recipe_registry[new_amount] = {
		type = method,
		inputs = inputs,
		outputs = outputs,
		data = data,
		inputs_string = recipes.stringify(method_table.input_amount, inputs),
		outputs_string = recipes.stringify(method_table.output_amount, outputs),
		inputs_map = recipes.convert_to_itemmap(inputs),
		outputs_map = recipes.convert_to_itemmap(outputs),
	}

	if not data.secret_recipe and method_table.callback(inputs, outputs, data) then
		local cache = {}
		local k0
		for _, v in pairs(inputs) do
			k0 = v:split" "[1]
			if not cache[k0] then
				if k0:split":"[1] ~= "group" then
					recipes.usages[k0] = recipes.usages[k0] or {}
					table.insert(recipes.usages[k0], new_amount)
				else
					local grname = k0:split":"[2]
					api.register_on_group_calculation(grname, function(list)
						for i = 1, #list do
							local k = list[i]
							recipes.usages[k] = recipes.usages[k] or {}
							table.insert(recipes.usages[k], new_amount)
						end
					end)
				end
			end
			cache[k0] = 1
		end
		cache = {}
		local k
		for _, v in pairs(outputs) do
			k = v:split" "[1]
			if not cache[k] then
				cache[k] = 1
				recipes.recipes[k] = recipes.recipes[k] or {}
				table.insert(recipes.recipes[k], new_amount)
			end
		end
		table.insert(api.recipes.recipes_by_method[method], new_amount)
	end

	return new_amount
end

function recipes.add_method(method, tbl)
	assert(tbl.input_amount, method.." recipe method misses input_amount")
	assert(tbl.output_amount, method.." recipe method misses output_amount")

	api.recipes.methods[method] = api.set_defaults(tbl, {
		callback = func.const(true),
		process = function(a, b, c)
			return a, b, c
		end,
		formspec_begin = func.const"",
		can_perform = func.const(true),
		recipe_correct = func.const(true),
	})

	api.recipes.recipes_by_method[method] = {}
	api.recipes.type_to_impl[method] = {}
end

function recipes.add_implementor(method, obj)
	if not recipes.implementing_objects[obj] then
		recipes.implementing_objects[obj] = {}
	end
	table.insert(recipes.implementing_objects[obj], api.recipes.recipes_by_method[method])
	table.insert(api.recipes.type_to_impl[method], obj)
end

function recipes.get_coords(width, shift_x, shift_y, n)
	return math.modulate(n, width) + shift_x, math.ceil(n / width) + shift_y
end

function recipes.coord_getter(width, dx, dy)
	return function(n)
		return recipes.get_coords(width, dx, dy, n)
	end
end

function recipes.check_inputs(input_map, needed_inputs)
	return table.every(needed_inputs, function(v, k)
		if k:split":"[1] ~= "group" then
			return input_map[k] and input_map[k] >= v
		else
			--[[
				TODO: rewrite this part and write unit-tests
				this part gives False Positives at the moment:
					when same item is in 2 groups both needed for recipe,
				Making recipes with both group:cracky and group:stone doesn't make sense though,
				so I'm leaving it out.
			]]--
			local list = api.get_grouped_items(k:split":"[2])
			local sum = table.sum(table.map(list, function(i) return input_map[i] end))
			return sum >= v
		end
	end)
end

-- In order for the function to work, recipe must be shifted to the topleft corner
function recipes.check_inputs_shaped(input_array, recipe, recipe_width, recipe_height, expected_width, expected_height)
	for i = 0, expected_width - recipe_width do
		for j = 0, expected_height - recipe_height do
			local good = true
			local shift = j * expected_width + i
			local new_recipe = {}
			for k = 1, expected_width * expected_height do
				local fix = math.modulate(k + shift, expected_width * expected_height)
				if not ((input_array[fix]:is_empty() and not recipe[k]) or
						api.item_satisfies(recipe[k], input_array[fix]:get_name())) then
					good = false
					break
				end
			end
			if good then
				return true
			end
		end
	end
	return false
end

function recipes.get_next(all_recipes, input_map, key)
	key = key or 0
	while key < #all_recipes do
		key = key + 1
		if recipes.check_inputs(input_map, recipes.recipe_registry[all_recipes[key]].inputs_map) then
			return key, all_recipes[key], recipes.recipe_registry[all_recipes[key]]
		end
	end
end

function recipes.availables_iterator(method, input_map)
	local all_recipes = recipes.recipes_by_method[method]
	return function(state, key) return recipes.get_next(state.recipes, state.map, key) end,
			{recipes = all_recipes, map = input_map}, 0
end

function recipes.availables_count(...)
	local i = 0
	for _ in recipes.availables_iterator(...) do i = i + 1 end
	return i
end

local function process(processed, i)
	local size = #processed
	local decrement = false
	for j = 1, size do
		if processed[j] == i then
			decrement = true
		end
		if decrement then
			processed[j] = processed[j + 1]
		end
	end
end

-- Remove broken recipes (as in recipe with <group:unexisting> input)
api.register_on_group_calculation(function()
	for i = 1, #recipes.recipe_registry do
		local rec = recipes.recipe_registry[i]
		for k in pairs(rec.inputs_map) do
			if k:split":"[1] == "group" and #api.get_grouped_items(k:split":"[2]) == 0 then
				minetest.log("warning", "Removing recipe with " .. k)
				process(recipes.recipes_by_method[rec.type], i)
				for k2 in pairs(rec.outputs_map) do
					process(recipes.recipes[k2], i)
				end
				break
			end
		end
	end
end)
