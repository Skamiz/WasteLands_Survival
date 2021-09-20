local reg = api.recipes.recipe_registry
local get_coords = api.recipes.get_coords

function api.make_activated_multiblock(...)
	local layers = {...}
	local removing = false
	if type(layers[#layers]) == "table" then
		removing = layers[#layers]
		layers[#layers] = nil
	end

	layers = table.map(layers, function(x) return reg[x] end)
	local activator, center, dx, w, output
	for i = 1, #layers do
		local t, x, y = unpack(layers[i].type:split"_")
		assert(t == "multiblock", "Cannot layer non-multiblocks!")
		x = tonumber(x)
		y = tonumber(y)
		assert(x % 2 == 1 and x == y, "Cannot layer even or non-square multiblocks!")
		if layers[i].data.h == 0 then
			activator = layers[i].data.activator
			center = layers[i].inputs[(x * y + 1) / 2]
			dx = (x + 1) / 2
			w = x
			output = layers[i].outputs[1]
		end
	end

	local old_activator_run = api.get_field(activator, "on_place") or api.functions.empty
	minetest.override_item(activator, {
		on_place = function(item, player, ptth)
			local rv = old_activator_run(item, player, ptth)
			if not player:get_player_control().sneak then return rv end
			local under_pos = ptth.under
			if not api.item_satisfies(center, minetest.get_node(under_pos).name) then return rv end
			if table.every(layers, function(layer)
				for k = 1, w * w do
					local x, y = get_coords(w, -dx, -dx, k)
					local pos = vector.add(under_pos, {z = y, x = x, y = layer.data.h})
					local actual_node = minetest.get_node(pos).name
					if not api.item_satisfies(layer.inputs[k] or "air", actual_node) then
						return false
					end
				end
				return true
			end) then
				minetest.set_node(under_pos, {name = output})
				if removing then
					for i = 1, #removing do
						minetest.set_node(vector.add(under_pos, removing[i]), {name = "air"})
					end
				end
			end

			return rv
		end
	})
end
