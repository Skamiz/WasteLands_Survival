-- TODO add bowl of water

--[[
Asume:
	1 node of water, thus one bucket of water fills the bar completely (20 half drops)
	1 node of water is  1000 cooking units
	1000 units of food fil the bar completely
	you get one half drop/hunch for 50 units of water/nutrition

	lets just say that a cauldrons max capacity is 5000 units... or maybe 3000?
	and a bowl holds 500... or 250; look it's complicated since the stews probably aren't going to be very stackable

	50 units are 1 portion

	?distinct stew and soup? depending on fluid content

	?a crafting recipe which allows to mix several stews together to redistribute content so they are stackable

	a hat with bottle which keeps you automatically hydrated

	TODO: make it so ingredients can only be added when cauldron stands on hot node.
]]

local cauldron_capacity = 5000
local bowl_capacity = 500

local foods = {
	["food:can"] = {food = 300}
}


local function sort_content(a, b)
	return a.amount > b.amount
end

-- purely for convenience of typeing
local ser = minetest.serialize
local des = minetest.deserialize

minetest.register_node("food:cauldron", {
	description = "Cauldron",
	drawtype = "nodebox",
	paramtype = "light",
	tiles = {
		"food_pot_bottom.png",
		"food_pot_bottom.png",
		"food_pot.png",
	},
	is_ground_content = false,
	groups = {oddly_breakable_by_hand = 2},
	node_box = {
		type = "fixed",
		fixed = {
			{-7/16, 5/16, -7/16, -5/16, 0.5, 7/16},
			{5/16, 5/16, -7/16, 7/16, 0.5, 7/16},
			{-7/16, 5/16, -7/16, 7/16, 0.5, -5/16},
			{-7/16, 5/16, 5/16, 7/16, 0.5, 7/16},

			{-6/16, 3/16, -6/16, -5/16, 5/16, 6/16},
			{5/16, 3/16, -6/16, 6/16, 5/16, 6/16},
			{-6/16, 3/16, -6/16, 6/16, 5/16, -5/16},
			{-6/16, 3/16, 5/16, 6/16, 5/16, 6/16},

			{-7/16, -7/16, -7/16, -5/16, 3/16, 7/16},
			{5/16, -7/16, -7/16, 7/16, 3/16, 7/16},
			{-7/16, -7/16, -7/16, 7/16, 3/16, -5/16},
			{-7/16, -7/16, 5/16, 7/16, 3/16, 7/16},

			{-6/16, -0.5, -6/16, 6/16, -6/16, 6/16},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-6/16, -0.5, -6/16, 6/16, -7/16, 6/16},
			{-7/16, -7/16, -7/16, 7/16, 3/16, 7/16},
			{-6/16, 3/16, -6/16, 6/16, 5/16, 6/16},
			{-7/16, 5/16, -7/16, 7/16, 0.5, 7/16},

		}

	},
	on_rightclick = function(pos, node, clicker, itemstack)
		-- TODO: prevent the cauldron form consuming hand objects
		local item_name = itemstack:get_name()
		if minetest.get_item_group(item_name, "clean_water_bucket") > 0 then
			minetest.set_node(pos, {name = "food:cauldron_with_water"})

			local item_def = minetest.registered_items[item_name]
			return ItemStack(item_def._bucket.bucket_empty)
		end
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Empty Cauldron\nCan be filled with a bucket of clean water.")
	end,
})

local function count_content(content)
	local total = 0
	for i, component in ipairs(content) do
		total = total + component.amount
	end
	return total
end

local function get_content_list(meta)
	local content = des(meta:get_string("content"))
	local s = "Contains:"
	for i, component in ipairs(content) do
		-- TODO: 'units' vs 'unit'
		s = s .. "\n"
		s = s .. component.amount .. " units of "
		local def = minetest.registered_items[component.ingredient]
		if def and def.description then
			s = s .. def.description
		else
			s = s .. component.ingredient
		end
	end
	return s
end

minetest.register_node("food:cauldron_with_water", {
	description = "Cauldron with Water",
	drawtype = "nodebox",
	paramtype = "light",
	tiles = {
		"food_pot_top.png",
		"food_pot_bottom.png",
		"food_pot.png",
	},
	is_ground_content = false,
	groups = {oddly_breakable_by_hand = 2},
	node_box = {
		type = "fixed",
		fixed = {
			{-7/16, 5/16, -7/16, -5/16, 0.5, 7/16},
			{5/16, 5/16, -7/16, 7/16, 0.5, 7/16},
			{-7/16, 5/16, -7/16, 7/16, 0.5, -5/16},
			{-7/16, 5/16, 5/16, 7/16, 0.5, 7/16},

			{-6/16, -8/16, -6/16, 6/16, 5/16, 6/16},

			{-7/16, -7/16, -7/16, 7/16, 3/16, 7/16},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-6/16, -0.5, -6/16, 6/16, -7/16, 6/16},
			{-7/16, -7/16, -7/16, 7/16, 3/16, 7/16},
			{-6/16, 3/16, -6/16, 6/16, 5/16, 6/16},
			{-7/16, 5/16, -7/16, 7/16, 0.5, 7/16},
		}
	},
	on_punch = function(pos, node, clicker, itemstack)
		local hud_elements = {}
		local meta = minetest.get_meta(pos)
		local content = des(meta:get_string("content"))

		-- clicker:hud_add()

		local n = 0
		for i, component in ipairs(content) do
			local def = minetest.registered_items[component.ingredient]
			local ingredient = component.ingredient

			if def then
				if def.inventory_image then
					ingredient = def.inventory_image
				end
				if def.type == "node" then
					ingredient = def.tiles[1]
					if type(ingredient) == "table" then
						ingredient = ingredient.name
					end
				end
			else
				ingredient = "unknown_item.png"
			end

			hud_elements[#hud_elements + 1] = clicker:hud_add({
				hud_elem_type = "image",
				position = {x = 0, y = 0.5},
				alignment = {x = 1, y = 0},
	        	offset = {x = 0, y = n * 32},
				scale = {x = 2, y = 2},
				-- number = 0xFFFFFF,
				text = ingredient,
			})
			hud_elements[#hud_elements + 1] = clicker:hud_add({
				hud_elem_type = "text",
				position = {x = 0, y = 0.5},
				alignment = {x = 1, y = 0},
	        	offset = {x = 32 + 5, y = n * 32},
				number = 0xFFFFFF,
				text = component.amount,
			})
			n = n + 1
			-- minetest.chat_send_all("Ingredient: " .. component.ingredient .. "; Amount: " .. component.amount)
		end



		minetest.after(3, function()
			for _, v in pairs(hud_elements) do
				clicker:hud_remove(v)
			end
		end)
		-- after

	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		-- meta:set_string("infotext", "Cauldron with Water")
		local content = {{ingredient = "ws_core:water_source", amount = 1000}}
		meta:set_string("content", ser(content))

		meta:set_string("infotext", "Cauldron\n" .. get_content_list(meta))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		local item_name = itemstack:get_name()

		if item_name == "" then return end

		local meta = minetest.get_meta(pos)
		local content = des(meta:get_string("content"))

		pos.y = pos.y - 1
		local bellow_name = minetest.get_node(pos).name
		if minetest.get_item_group(bellow_name, "hot") <= 0 then
			minetest.chat_send_player(clicker:get_player_name(), "You can't add it, the cauldron needs to stand above a source of heat.")
			return
		end

		if (count_content(content) + 50) > cauldron_capacity then
			minetest.chat_send_player(clicker:get_player_name(), "You can't add that, the cauldron is too full.")
			return
		end

		local found = false
		for i, component in ipairs(content) do
			if component.ingredient == item_name then
				component.amount = component.amount + 50
				found = true
			end
		end
		if not found then
			table.insert(content, {ingredient = item_name, amount = 50})
		end
		table.sort(content, sort_content)
		meta:set_string("content", ser(content))

		-- meta:set_string("infotext", "Cauldron\n" .. get_content_list(meta))

		itemstack:take_item()
		return itemstack
	end,
})


minetest.register_craftitem("food:bowl", {
    description = "Empty Bowl",
	inventory_image = "food_bowl.png",
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.under
		local node = minetest.get_node(pos)
		if node.name == "food:cauldron_with_water" then
			local stew = ItemStack("food:stew")
			local s_meta = stew:get_meta()

			local c_meta = minetest.get_meta(pos)
			local c_content = des(c_meta:get_string("content"))

			local total = 0
			for i, component in ipairs(c_content) do
				total = total + component.amount
			end

			local fraction = bowl_capacity/total
			local to_go = bowl_capacity

			fraction = math.min(fraction, 1)

			local s_content = {}
			for i, component in ipairs(c_content) do
				local transfer = math.floor(component.amount * fraction)
				s_content[i] = {ingredient = component.ingredient, amount = transfer}
				c_content[i].amount = c_content[i].amount - transfer

				if c_content[i].amount == 0 then c_content[i] = nil end

				to_go = to_go - transfer
			end

			-- WARNING in very specific circumstances this can result in an ingredient being present in negative amounts
			if to_go ~= 0 and c_content[1] then
				s_content[1].amount = s_content[1].amount + to_go
				c_content[1].amount = c_content[1].amount - to_go
				if c_content[1].amount == 0 then c_content[1] = nil end
			end

			table.sort(c_content, sort_content)
			c_meta:set_string("content", ser(c_content))
			c_meta:set_string("infotext", "Cauldron\n" .. get_content_list(c_meta))
			if not c_content[1] then minetest.set_node(pos, {name = "food:cauldron"}) end

			table.sort(s_content, sort_content)
			s_meta:set_string("content", ser(s_content))
			s_meta:set_string("description", "Bowl of Stew\n" .. get_content_list(s_meta))

			local inv = placer:get_inventory()

			local rest = inv:add_item("main", stew)
			if not rest:is_empty() then
				minetest.add_item(placer:get_pos(), rest)
			end

			-- take from lowest to heights and from the heighest take the fractions left


			-- if total < 500 then
			-- 	s_meta:set_string("content", ser(content))
			-- end




			itemstack:take_item()
			return itemstack
		end
		return minetest.item_place(itemstack, placer, pointed_thing)
	end,
})

minetest.register_craftitem("food:stew", {
    description = "Bowl of Stew",
	inventory_image = "food_stew.png",
	on_use = function(itemstack, user, pointed_thing)
		local player_name = user:get_player_name()
		local meta = itemstack:get_meta()
		local content = des(meta:get_string("content"))
		local water, food = 0, 0

		for i, component in ipairs(content) do
			if component.ingredient == "ws_core:water_source" then
				water = water + component.amount
			else
				food = food + component.amount
			end
		end

		water = math.floor(water/50)
		food = math.floor(food/50)

		thirst.decrease_thirst(player_name, water)
		local hunger = hbhunger.hunger[player_name]
		local new_hunger = math.min(hunger + food, 30)
		hbhunger.hunger[player_name] = new_hunger
		-- hbhunger.set_hunger_raw(user)

		local inv = user:get_inventory()
		if inv:room_for_item("main", "food:bowl") then
			inv:add_item("main", "food:bowl")
		else
			minetest.add_item(user:get_pos(), "food:bowl")
		end

		itemstack:take_item()
		return itemstack
	end
})
