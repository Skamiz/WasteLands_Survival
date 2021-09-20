local S = nei.S
local integrator = {description = nei.S"Integrated Inventory"}

local registered_filters = {}
local filter_strings = {}
local antitable = {}
function nei.register_filter(name, call)
	table.insert(registered_filters, call)
	table.insert(filter_strings, name)
	assert(not antitable[name], "Filter " .. name .. " already registered!")
	antitable[name] = #filter_strings
end

function nei.satisfies_search(search_string)
	local expansion = api.search(search_string, api.functions.identity, function(z)
		local tbl = {}
		local i = z:match("%(([^()]+)%)")
		if i then
			local tbl2 = i:split"|"
			for j = 1, #tbl2 do
				local k = tbl2[j]
				local str = z:gsub("%(([^()]+)%)", k, 1)
				tbl[str] = 1
			end
		end
		return tbl
	end):push(search_string):map(function(q)
		return q:gsub("%*", ".*")
	end):filter(function(z) return not z:find"%(" end)

	local exp2 = api.DataMesh:new()
	expansion:forEach(function(q)
		for _,i in pairs(q:split"|") do
			exp2:push(i:split" ")
		end
	end)
	exp2:filter(function(q) return q ~= "" end)

	return function(v)
		if v.mod_origin == "*builtin*" then return false end
		if v.groups and v.groups.not_in_creative_inventory then return false end
		if not v.description then return false end
		if search_string == "" then return true end
		local desc, name = v.description:lower(), v.name:lower()
		return exp2:exists(function(z)
			return table.every(z, function(z2)
				if z2:sub(1, 1) == "@" then
					return name:find(z2:sub(2))
				else
					return desc:find(z2)
				end
			end)
		end)
	end
end

nei.modifiers, nei.add_modifier = api.adder()
function nei.get_description(item, player_name)
	local start = api.get_description(item)
	for _,func in pairs(nei.modifiers) do
		start = func(item, start, player_name)
	end
	return start
end

minetest.register_on_mods_loaded(function()
	local modnames = minetest.get_modnames()
	for i = 1, #modnames do
		local name = modnames[i]
		if table.count(table.filter(minetest.registered_items, nei.satisfies_search("@" .. name))) > 0 then
			nei.register_filter(S("@1 Mod", api.string_superseparation(name)), nei.satisfies_search("@" .. name))
		end
	end
end)

local width, height, cell_size, nei_left = 8, 8, 1, false
local function get_formspec_array(search_string, mode, filters, cf, pn)
	local ss = search_string:lower()
	local formspec, i = {}, 0
	local length_per_page = width * height
	local items = table.filter(minetest.registered_items, nei.satisfies_search(ss))

	for k in pairs(items) do
		for j in pairs(filters) do
			if registered_filters[j](items[k]) then
				items[k] = nil
				break
			end
		end
	end

	local x, y
	local page_amount = math.max(math.ceil(table.count(items) / length_per_page), 1)
	local pa = math.ceil(table.count(items) / length_per_page)
	for j = 1, page_amount do
		formspec[j] = ([=[
			field[0.3,${height_search};${width_search},1;search;;${search}]
			field_close_on_enter[search;false]
			style[search_use;bgcolor=green]
			button[${width_search},${height_search_buttons};1,1;search_use;>>]
			style[search_clear;bgcolor=red]
			button[${width_search2},${height_search_buttons};1,1;search_clear;X]
			label[1,0.2;${page_number}]
			button[0,0.2;1,0.5;page_open~-1;<]
			button[${width_search2},0.2;1,0.5;page_open~+1;>]
			dropdown[0,${persistent_height};${drop_w};persistent_filter;${persistent_filter};${persistent_filter_key}]
			button[${drop_w},${persistent_height2};2,1;persistent_filter_button;${button_label}]
			style_type[item_image_button;border=false]
		]=]):from_table{
			height_search = height * cell_size + 1.3,
			height_search_buttons = height * cell_size + 1,
			width_search = width * cell_size - 2,
			width_search2 = width * cell_size - 1,
			search = search_string,
			page_number = width <= 6 and S("@1/@2", math.min(j, pa), pa) or S("Page @1/@2", math.min(j, pa), pa),

			persistent_filter_key = cf,
			persistent_filter = table.concat(filter_strings, ","),
			persistent_height = height * cell_size + 2.1,
			persistent_height2 = height * cell_size + 2,
			button_label = filters[cf] and S"Show" or S"Hide",
			drop_w = width - 2,
		}

		if creative.is_enabled_for(pn) then
			formspec[j] = formspec[j] .. ([=[
				button[${change_mode_coord},0.2;3,0.5;change_mode;${change_mode_text}]
				tooltip[change_mode;${current_mode}]
			]=]):from_table{
				change_mode_coord = width * cell_size - 4,
				change_mode_text = S"Change Mode",
				current_mode = S("Current mode: @1", mode == 0 and S"Recipes" or S"Cheat"),
			}
		end
	end
	local j = 1
	local tbl = {}
	for _, z in pairs(items) do
		tbl[#tbl + 1] = z
	end
	table.sort(tbl, api.sort_by_param"name")
	for _, v in ipairs(tbl) do
		if v.type ~= "none" then
			x = i % width
			y = (i - x) / width
			formspec[j] = formspec[j] .. ([=[
				item_image_button[${cell_x},${cell_y};${cell_size},${cell_size};${item_id};${current_mode}~${item_id};]
				tooltip[${current_mode}~${item_id};${description}]=] .. "\n${mod_origin}]"):from_table{
				cell_x = x * cell_size,
				cell_y = y * cell_size + 1,
				cell_size = cell_size,
				item_id = v.name,
				current_mode = mode == 1 and "give" or "view_recipe",
				description = nei.get_description(v.name, pn),
				mod_origin = minetest.colorize("#4d82d7", api.string_superseparation(api.get_field(v.name, "mod_origin"))),
			}
			i = i + 1
			if i >= length_per_page then
				i = 0
				j = j + 1
			end
		end
	end

	return formspec, page_amount, {x = width * cell_size, y = height * cell_size + 2.6}
end
function nei.update_formspec_array(pn, context, search)
	context = context or betterinv.contexts[pn][betterinv.selections[pn]]
	search = search or context.search or ""
	context.search = search
	context.formspecs_array, context.page_amount, context.size =
			get_formspec_array(search, context.mode, context.filters, context.cf, pn)
end

function integrator.getter(player, context)
	local pn = player:get_player_name()
	if not context.initialized then
		context.cf = 1
		context.filters = api.get_data_pointer(pn, "integrated_persistent_filters")._strings
		context.mode = 0
		nei.update_formspec_array(pn, context, "")
		context.page = 1
		context.initialized = true
	end

	local nei_fs, nei_size = context.formspecs_array[math.min(context.page, context.page_amount)], context.size
	local fs_base = ([=[
		container[${nei_begin},0]
		${nei}
		container_end[]
		container[${inv_begin},0]
		list[current_player;main;0,${hb_y};8,1;]
		list[current_player;main;0,${inv_y};8,3;8]
		image[0,${hb_y};1,1;gui_hb_bg.png]
		image[1,${hb_y};1,1;gui_hb_bg.png]
		image[2,${hb_y};1,1;gui_hb_bg.png]
		image[3,${hb_y};1,1;gui_hb_bg.png]
		image[4,${hb_y};1,1;gui_hb_bg.png]
		image[5,${hb_y};1,1;gui_hb_bg.png]
		image[6,${hb_y};1,1;gui_hb_bg.png]
		image[7,${hb_y};1,1;gui_hb_bg.png]
		list[detached:bound~${pn};trash;0.5,0.5;1,1]
		image[0.5,1.5;1,1;trinium_gui.trash.png]
		container_end[]
	]=]):from_table{
		nei = nei_fs,
		hb_y = nei_size.y - 4.7,
		inv_y = nei_size.y - 3.6,
		pn = pn,
		nei_begin = nei_left and 0 or 8.5,
		inv_begin = nei_left and width + 0.5 or 0,
	}

	return betterinv.generate_formspec(player, fs_base, {x = 8.5 + nei_size.x, y = nei_size.y}, false, false)
end

function integrator.processor(player, context, fields)
	if fields.quit then return end
	if fields.key_enter then
		fields.search_use = 1
	end
	local pn = player:get_player_name()

	if fields.persistent_filter then
		context.cf = antitable[fields.persistent_filter]
	end
	local search = fields.search
	for k in pairs(fields) do
		local k_split = k:split("~") -- Module, action, parameters
		local a = k_split[1]
		if a == "persistent_filter_button" then
			context.filters[context.cf] = not context.filters[context.cf] and 1 or nil
		elseif a == "search_clear" then
			search = ""
		elseif a == "page_open" then
			context.page = math.modulate(context.page + tonumber(k_split[2]), context.page_amount)
		elseif a == "change_mode" then
			context.mode = 1 - context.mode
		elseif a == "view_recipe" then
			local item, num, type = k_split[2], tonumber(k_split[3]), tonumber(k_split[4])
			local fs = nei.draw_recipe_wrapped(item, player, num or 1, type or 1)
			minetest.show_formspec(pn, "nei:recipe_view", fs)
		elseif a == "give" then
			local item = k_split[2]
			local stack = minetest.registered_items[item].stack_max
			player:get_inventory():add_item("main", item .. " " .. stack)
			cmsg.push_message_player(player, S("Given @1 @2 to @3", stack, item, pn))
		end
		nei.update_formspec_array(pn, context, search)
	end
end

betterinv.register_tab("default", integrator)
api.set_master_prepend[=[
	bgcolor[#111B;true]
	background[5,5;1,1;gui_formbg.png;true]
	listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]
]=]
