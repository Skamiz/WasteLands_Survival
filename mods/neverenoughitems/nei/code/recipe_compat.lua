local recipes = api.recipes
local S = api.S

recipes.add_method("drop", {
	input_amount = 1,
	output_amount = 9,
	get_input_coords = function()
		return 0, 2
	end,
	get_output_coords = function(n)
		return math.modulate(n, 3) + 2, math.ceil(n / 3)
	end,
	formspec_width = 6,
	formspec_height = 5,
	formspec_name = api.S"Drop",
	formspec_begin = function(data)
		return data.max_items and ("textarea[0.25,4.7;7,1;;;%s]"):format(api.S("Max Drop: @1", data.max_items)) or ""
	end,

	process = function(a, outputs, b)
		if type(outputs[1]) == "string" then return a, outputs, b end
		local outputs1 = {}

		if outputs then
			table.walk(outputs, function(v)
				if type(v) == "string" then
					table.insert(outputs1, v)
				else
					if v.items then
						table.walk(v.items, function(v1)
							table.insert(outputs1, v1 .. (#(v1:split(" ")) == 1 and " 1" or "") ..
									" " .. math.ceil(10000 / (v.rarity or 1)) / 100)
						end)
					end
				end
			end)
		end

		return a, #outputs1 > 9 and -1 or outputs1, b
	end,
})

local function update_drop(name, drop)
	if drop and drop ~= "" then
		api.recipes.add("drop", {name},
				type(drop) == "table" and drop.items or {drop},
				{max_items = type(drop) == "table" and drop.max_items})
	end
end

minetest.register_on_mods_loaded(function()
	for item, v in pairs(minetest.registered_items) do
		update_drop(item, v.drop)
		minetest.override_item(item, {})
	end
end)

recipes.add_method("crafting_table", {
	input_amount = 9,
	output_amount = 1,
	get_input_coords = recipes.coord_getter(3, -1, 0),
	get_output_coords = recipes.coord_getter(1, 3.5, 1),
	formspec_width = 5.5,
	formspec_height = 4.5,
	formspec_name = S"Crafting",
	formspec_begin = function(data)
		local arrow = "image[3.25,2;1,1;gui_furnace_arrow_bg.png]"
		if not data.shapeless then return arrow end
		return arrow .. ("textarea[0.25,4.25;6,1.5;;;%s]"):format(S"Shapeless")
	end,
})

recipes.add_method("furnace", {
	input_amount = 1,
	output_amount = 1,
	get_input_coords = recipes.coord_getter(1, -1, 0),
	get_output_coords = recipes.coord_getter(1, 1, 0),
	formspec_width = 5,
	formspec_height = 4,
	formspec_name = S"Furnace",
	formspec_begin = function(data)
		local tbl = {}
		table.insert(tbl, S("Time: @1 seconds", data.time))
		return ("image[1,1;1,1;gui_furnace_arrow_bg.png]textarea[0.25,2.25;4.5,1.5;;;%s]")
				:format(table.concat(tbl, "\n"))
	end,
})

local old_rc = minetest.register_craft
function minetest.register_craft(definition)
	old_rc(definition)

	local type = definition.type
	local data = {}
	if type == "shapeless" then
		recipes.add("crafting_table", definition.recipe, {definition.output}, {shapeless = 1})
	elseif not type then
		local inputs = definition.recipe
		local inputs2 = {}
		local w = #inputs[1]
		for i = 1, #inputs do
			for j = 1, w do
				if inputs[i][j] ~= "" then
					inputs2[(i - 1) * 3 + j] = inputs[i][j]
				end
			end
		end

		recipes.add("crafting_table", inputs2, {definition.output})
	elseif type == "cooking" then
		recipes.add("furnace", {definition.recipe}, {definition.output}, {time = definition.time or 3})
	end
end
