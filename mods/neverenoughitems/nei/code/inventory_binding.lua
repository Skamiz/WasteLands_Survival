local bi = nei.bound_inventories
local dps = {}

local sizes = {trash = 1, crafting = 9, output = 1}
function api.save_inventory(pn)
	for k in pairs(dps[pn]._strings) do
		for i = 1, sizes[k] do
			dps[pn][k][i] = bi[pn]:get_stack(k, i):to_string()
		end
	end
end

minetest.register_on_joinplayer(function(player)
	local pn = player:get_player_name()
	local dp = api.get_data_pointer(pn, "bound_inventories")
	dps[pn] = dp
	bi[pn] = minetest.create_detached_inventory("bound~" .. pn, {
		allow_move = function(_, from_list, _, _, _, count)
			return from_list ~= "trash" and count or 0
		end,

		allow_take = function(_, _, _, stack)
			return stack:get_count()
		end,

		on_move = function(inv, from_list, from_index, to_list, to_index)
			dp[from_list] = dp[from_list] or {}
			dp[to_list] = dp[to_list] or {}

			if to_list == "crafting" then
				api.try_craft(player)
			elseif to_list == "trash" then
				inv:set_stack("trash", 1, "")
			end

			dp[from_list][from_index] = inv:get_stack(from_list, from_index):to_string()
			dp[to_list][to_index] = inv:get_stack(to_list, to_index):to_string()
		end,

		on_put = function(inv, list_name, index)
			dp[list_name] = dp[list_name] or {}

			if list_name == "trash" then
				inv:set_stack("trash", 1, "")
			elseif list_name == "crafting" then
				api.try_craft(player)
			end

			dp[list_name][index] = inv:get_stack(list_name, index):to_string()
		end,

		on_take = function(inv, list_name, index)
			if not dp[list_name] then
				dp[list_name] = {}
			end
			dp[list_name][index] = inv:get_stack(list_name, index):to_string()
			if list_name == "crafting" then
				api.try_craft(player)
			end
		end,
	})
	api.initialize_inventory(bi[pn], sizes)
	for k, v in pairs(dp._strings) do
		for k1, v1 in pairs(v) do
			bi[pn]:set_stack(k, k1, v1)
		end
	end
end)
