local one = {"", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"}
local ten = {"", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC"}
local hun = {"", "C", "CC", "CCC", "CD", "D", "DC", "DCC", "DCCC", "CM"}
function api.roman_number(a)
	local k = a % 1000
	local str = ("M"):rep(math.floor(a / 1000))

	str = str .. hun[(k - k % 100) / 100 + 1]
	str = str .. ten[(k % 100 - k % 10) / 10 + 1]
	str = str .. one[k % 10 + 1]
	return str
end

function api.table_multiply(tbl, n)
	return table.map(tbl, function(r) return r * n end)
end

function api.dump(...)
	local string = ""
	local add
	for _, x in ipairs(table.remap{...}) do
		add = dump(x)
		if type(x) == "string" then
			add = add:sub(2, -2)
		end
		string = string .. add .. "  "
	end
	minetest.log("warning", string:sub(1, -3))
end

function api.get_setting(name, default)
	local s = minetest.settings:get(name)
	if not s then
		minetest.settings:set(name, default)
		s = default
	end
	return s
end

function api.set_defaults(tbl, reserved_tbl)
	tbl = tbl or {}
	if not reserved_tbl then return tbl end
	for k, v in pairs(reserved_tbl) do
		if not tbl[k] then
			tbl[k] = v
		end
	end
	return tbl
end

function api.string_capitalization(str)
	return str:sub(1, 1):upper() .. str:sub(2):lower()
end

function api.string_separation(str)
	local a = api.string_capitalization(str):gsub("_", " ")
	return a
end

function api.string_superseparation(str)
	local a = api.string_separation(str):gsub("%W%l", string.upper)
	return a
end

function api.translate_requirements(tbl)
	local tbl1 = {}
	for _, k, v in table.asort(tbl, function(a, b) return tbl[a] > tbl[b] end) do
		tbl1[#tbl1 + 1] = "\n" ..
				minetest.colorize("#CCC", v .. " " .. ((minetest.registered_nodes[k] or {}).description or "???"))
	end
	return table.concat(tbl1, "")
end

function api.get_field(item, fn)
	item = minetest.registered_items[item]
	if not item then return nil end
	return item[fn]
end

function api.get_description(item)
	return (api.get_field(item, "description") or item):split"\n"[1] or ""
end

function api.get_fs_texture(...)
	local textures = {}
	for _, v in ipairs{...} do
		table.insert(textures, table.concat{"(", api.get_field(v, "inventory_image"), ")^[brighten"})
	end
	return unpack(textures)
end

function api.process_color(color)
	if type(color) == "string" then return color end
	color = ("%xB0"):format(color[1] * 256 * 256 + color[2] * 256 + color[3])
	color = ("0"):rep(8 - #color) .. color
	return color
end

function api.color_string(color)
	return api.process_color(color):sub(1, 6)
end

function api.adder()
	local x = {}
	return x, function(name, def) x[name] = def end
end

function api.recolor_facedir(pos, n)
	local node = minetest.get_node(pos)
	node.param2 = (node.param2 % 32) + (n * 32)
	minetest.swap_node(pos, node)
end

function api.assert(x, y, z, t)
	return assert(x, "\n" .. y .. " requested nonexistent " .. z .. " " .. t)
end

function api.set_master_prepend(string)
	minetest.register_on_joinplayer(function(player)
		player:set_formspec_prepend(string)
	end)
end

local groups = {}
local function update_groups(name, groupsz)
	for k in pairs(groupsz) do
		groups[k] = groups[k] or {}
		table.insert(groups[k], name)
	end
end
local groupcalc = {} -- these depend on group name
local groupcalc2 = {} -- these are unconditional
function api.register_on_group_calculation(gr, func)
	if func then
		groupcalc[gr] = groupcalc[gr] or {}
		table.insert(groupcalc[gr], func)
	else
		table.insert(groupcalc2, gr)
	end
end
minetest.register_on_mods_loaded(function()
	for k, v in pairs(minetest.registered_items) do
		update_groups(k, v.groups)
	end
	function api.get_grouped_items(name)
		return groups[name] or {}
	end

	for k, v in pairs(groups) do
		if groupcalc[k] then
			for i = 1, #groupcalc[k] do
				groupcalc[k][i](v)
			end
		end
	end
	groupcalc = nil

	for i = 1, #groupcalc2 do
		groupcalc2[i]()
	end
	groupcalc2 = nil
end)

function api.item_satisfies(expected, obtained)
	return obtained == expected or (
		expected and
		expected:split":"[1] == "group" and
		minetest.get_item_group(obtained, expected:split":"[2]) > 0
	)
end

if minetest.random_sequence then
	api.random_sequence = minetest.random_sequence
else
	-- Written by ashtrayoz for MT engine and not included yet
	local random_sequence = PcgRandom(math.random(10^8))
	function api.random_sequence(limit)
		local used, used_count = {}, 0
		return function()
			if used_count >= limit then return end
			local attempt = random_sequence:next(1, limit)
			if used[attempt] then attempt = nil end
			if not attempt then -- We have 3 retry strategies.
				attempt = random_sequence:next(1, limit) -- 1: just another random number
				if used[attempt] then
					local start = attempt + 1
					attempt = nil
					for i = start, limit do -- 2: seek upwards
						if not used[i] then
							attempt = i
							break
						end
					end
					if not attempt then
						for i = start - 2, 1, -1 do  -- 3: seek downwards
							if not used[i] then
								attempt = i
								break
							end
						end
					end
				end
			end
			used[attempt] = true
			used_count = used_count + 1
			return attempt
		end
	end
end

function api.randomize(max, amount)
	local output = {}
	local linear_add, random_add = math.floor(amount / max), amount % max
	for i = 1, random_add do
		for _ = 1, max do
			table.insert(output, i)
		end
	end

	local k = 0
	for number in api.random_sequence(max) do
		k = k + 1
		table.insert(output, number)
		if k == linear_add then break end
	end
	return output
end

function api.dropper(tbl)
	return function(pos, _, oldmetadata, digger)
		for i = 1, #tbl do
			local inv = oldmetadata.inventory[tbl[i]]
			for j = 1, #inv do
				local stack = inv[j]
				if not stack:is_empty() then
					minetest.item_drop(stack, digger, pos)
				end
			end
		end
	end
end
