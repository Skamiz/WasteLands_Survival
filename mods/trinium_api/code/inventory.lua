local DataMesh = api.DataMesh

function api.initialize_inventory(inv, def)
	for k, v in pairs(def) do
		inv:set_size(k, v)
	end
end

function api.initializer(def0)
	return function(pos)
		local def = table.copy(def0)
		local meta = minetest.get_meta(pos)
		if def.formspec then
			meta:set_string("formspec", def.formspec)
			def.formspec = nil
		end
		api.initialize_inventory(meta:get_inventory(), def)
	end
end

function api.inv_to_itemmap(...)
	local map, inv = {}, {...}
	for _, v in pairs(inv) do
		for _, v1 in pairs(v) do
			local name, count = v1:get_name(), v1:get_count()
			if not map[name] then map[name] = 0 end
			map[name] = map[name] + count
		end
	end
	map[""] = nil
	return map
end

function api.get_item_identifier(stack)
	local s = stack:to_string():split(" ")
	if not s[1] then return nil end
	return s[1] .. (s[3] and " " .. table.concat(table.multi_tail(s, 2), " ") or "")
end

function api.count_stacks(inv, list, disallow_multi_stacks)
	local dm = DataMesh:new():data(inv:get_list(list)):filter(function(v)
		return not v:is_empty()
	end)
	if not disallow_multi_stacks then
		dm = dm:map(function(v)
			return v:get_name()
		end):unique()
	end
	return dm:count()
end

function api.formspec_escape_reverse(text)
	text = text:gsub("\\%[", "["):gsub("\\%]", "]"):gsub("\\\\", "\\"):gsub("\\,", ","):gsub("\\;", ";")
	return text
end

function api.merge_itemmaps(a, b)
	for k, v in pairs(b) do
		a[k] = (a[k] or 0) + v
	end
end

function api.add_items(inventory, list, inputs)
	for _, v in pairs(inputs) do inventory:add_item(list, v) end
end

-- unlike previous function, this one needs to process <group:x>
function api.remove_items(inventory, list, inputs)
	local map = api.inv_to_itemmap(inventory:get_list(list))
	for _, v in pairs(inputs) do
		if v:split":"[1] ~= "group" then
			inventory:remove_item(list, v)
		else
			local group, count = unpack(v:split":"[2]:split" ")
			count = tonumber(count) or 1
			local grouped = api.get_grouped_items(group)
			for i = 1, #grouped do
				local item = grouped[i]
				local decr = math.min(count, map[item] or 0)
				if decr > 0 then
					inventory:remove_item(list, item .. " " .. decr)
					count = count - decr
				end
				if count == 0 then break end
			end
		end
	end
end
