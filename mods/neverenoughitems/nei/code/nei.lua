local recipes = api.recipes

local nei = nei
local S = nei.S

local context = {}
context.button_id = function(id) return "view_recipe~" .. id .. "~1~1~contexted" end

function nei.draw_recipe_raw(id)
	assert(api.get_grouped_items, "nei.draw_recipe_raw cannot be called before Group Init!")
	local recipe = recipes.recipe_registry[math.modulate(id, #recipes.recipe_registry)]
	local method = recipes.methods[recipe.type]

	local formspec = ("%s label[0,0;%s]"):format(method.formspec_begin(recipe.data, context), method.formspec_name)

	local it, ot = recipe.data.input_tooltips or {}, recipe.data.output_tooltips or {}
	local item_name, amount, x, y, arr, chance
	for i = 1, method.input_amount do
		amount = nil
		if recipe.inputs[i] then
			arr = recipe.inputs[i]:split" "
			item_name, amount = unpack(arr)
		else
			item_name = ""
		end

		if item_name:split":"[1] == "group" then
			local group_name = item_name:split":"[2]
			local list = api.get_grouped_items(group_name)
			-- if #list == 0 then return end
			item_name = list[1]

			if #list > 1 and not it[i] then
				local message = {S("Possible substitutions:")}
				for j = 1, #list do
					table.insert(message, api.get_description(list[j]))
				end
				message = minetest.colorize("#CCC", table.concat(message, "\n"))
				it[i] = "group:" .. group_name .. "\n\n" .. message
			end
		end

		x, y = method.get_input_coords(i)
		formspec = formspec .. ([=[
			item_image_button[${width},${height};1,1;${id};view_recipe~${id}~1~1~i${number};${amount}]
			box[${box_x},${box_y};0.9375,0.95;#0000FF]
		]=]):from_table{
			width = x,
			height = y,
			id = item_name,
			number = i,
			amount = amount ~= "1" and amount or "",
			box_x = x - 1 / 20,
			box_y = y - 1 / 20,
		}

		if it[i] or not minetest.registered_items[item_name] then
			formspec = formspec .. ("tooltip[view_recipe~%s~1~1~i%s;%s]"):format(item_name, i, it[i] or item_name)
		end
	end

	for i = 1, method.output_amount do
		chance, amount = nil, nil
		if recipe.outputs[i] then
			arr = recipe.outputs[i]:split" "
			item_name, amount, chance = unpack(arr)
		else
			item_name = ""
		end
		x, y = method.get_output_coords(i)
		formspec = formspec .. ([=[
			item_image_button[${width},${height};1,1;${id};view_recipe~${id}~1~1~o${number};${amount}]
			box[${box_x},${box_y};0.9375,0.95;#FFA500]
		]=]):from_table{
			width = x,
			height = y,
			id = item_name,
			number = i,
			amount = table.f_concat({amount ~= "1" and amount or nil, chance and chance .. " %"}, "\n"),
			box_x = x - 1 / 20,
			box_y = y - 1 / 20,
		}

		if ot[i] or not minetest.registered_items[item_name] then
			formspec = formspec .. ("tooltip[view_recipe~%s~1~1~o%s;%s]"):format(item_name, i, ot[i] or item_name)
		end
	end

	return {form = formspec, w = method.formspec_width, h = method.formspec_height, method = recipe.type}
end

function nei.draw_recipe_wrapped(item, player, id, r_type)
	item = (minetest.registered_items[item] or {}).name or item -- process aliases
	local tbl
	if r_type == 1 then
		tbl = recipes.recipes[item]
	elseif r_type == 2 then
		tbl = recipes.usages[item]
	elseif r_type == 3 then
		tbl = table.merge({}, unpack(recipes.implementing_objects[item] or {}))
	end
	tbl = tbl or {}

	tbl = table.remap(table.filter(tbl, function(r)
		local v = recipes.recipe_registry[r]
		return recipes.methods[v.type].can_perform(player, v.data)
	end))

	local fs_base

	local decr = false
	if #tbl > 0 then
		id = math.modulate(id, #tbl)
		fs_base = nei.draw_recipe_raw(tbl[math.modulate(id, #tbl)])

		-- Process implementors
		local tti = recipes.type_to_impl[fs_base.method]
		if #tti > 0 then
			decr = true
			fs_base.form = fs_base.form .. ([=[
				box[%s,-0.275;0.1,%s;#FFFF00]
			]=]):format(fs_base.w + 0.125, fs_base.h + 1.7)

			for i = 1, #tti do
				fs_base.form = fs_base.form .. ([=[
					item_image_button[${x},${y};1,1;${item};view_recipe~${item}~1~1;]
					box[${box_x},${box_y};0.9375,0.95;#FFFF00]
				]=]):from_table{
					x = fs_base.w + 0.5,
					y = i - 1,
					item = tti[i],
					box_x = fs_base.w + 9 / 20,
					box_y = i - 21 / 20,
				}
			end
			fs_base.arrow_x = fs_base.w
			fs_base.w = fs_base.w + 1.5
		end
	else
		id = 0
		local message = ""
		if r_type == 1 then
			message = S"recipes"
		elseif r_type == 2 then
			message = S"usages"
		elseif r_type == 3 then
			message = S"implements"
		end

		fs_base = {
			w = 6,
			h = 4,
			form = ([=[
				label[0,0.25;%s]
				label[0,1;%s]
				item_image[2,1.5;2,2;%s]
			]=]):format(S("No @1 found for this item.", message), item, item),
		}
	end

	local arrow_w = (fs_base.arrow_x or fs_base.w) - 1
	local actual_formspec = {
		("size[%s,%s]"):format(fs_base.w, fs_base.h + 1),
		("tabheader[0,0;change_nei_mode~${item};${rec},${use},${impl};${current};true;false]"):from_table{
			item = item,
			current = r_type,
			rec = S"Recipes",
			use = S"Usages",
			impl = S"Implements",
		},
		fs_base.form,
		("label[1,%s;%s]"):format(fs_base.h + 0.5, S("Recipe @1 of @2", id, #tbl)),
		("button[0,%s;1,1;view_recipe~%s~%s~%s;<]"):format(fs_base.h + 0.3, item, id - 1, r_type),
		("button[%s,%s;1,1;view_recipe~%s~%s~%s;>]"):format(arrow_w, fs_base.h + 0.3, item, id + 1, r_type),
	}

	return table.concat(actual_formspec), {x = fs_base.w, y = fs_base.h, decr_x = fs_base.w - (decr and 1.275 or 0)},
			id ~= 0 and tbl[id] or 0
end

minetest.register_on_player_receive_fields(function(player, form_name, fields)
	if form_name ~= "nei:recipe_view" then return end
	local fs = false

	for k, v in pairs(fields) do
		local k_split = k:split"~" -- Module, action, parameters
		local a = k_split[1]
		if a == "change_nei_mode" then
			fs = nei.draw_recipe_wrapped(k_split[2], player, 1, tonumber(v))
		elseif a == "view_recipe" then
			local item, num, type = k_split[2], tonumber(k_split[3]), tonumber(k_split[4])
			fs = nei.draw_recipe_wrapped(item, player, num, type)
		end
	end

	if fs then
		local pn = player:get_player_name()
		minetest.show_formspec(pn, "nei:recipe_view", fs)
	end
end)
