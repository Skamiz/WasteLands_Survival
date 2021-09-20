api = {}

local path = minetest.get_modpath"trinium_api" .. "/code"

api.S = minetest.get_translator"trinium_api"

function api.deprecate(f, old, new)
	return function(...)
		minetest.log("warning", old .. " is deprecated, use " .. new .. "instead")
		f(...)
	end
end

dofile(path .. "/data_pointers.lua")
dofile(path .. "/data_mesh.lua")
dofile(path .. "/stdlib.lua")
dofile(path .. "/random.lua")
dofile(path .. "/sandboxing.lua")
dofile(path .. "/algorithm.lua")
dofile(path .. "/inventory.lua")
dofile(path .. "/recipes.lua")
dofile(path .. "/multiblock.lua")
dofile(path .. "/activated_multiblock.lua")
dofile(path .. "/math.lua")
dofile(path .. "/queueing.lua")
