local path = minetest.get_modpath"nei" .. "/code"

nei = {}
nei.S = minetest.get_translator"nei"
nei.bound_inventories = {}

dofile(path .. "/creative.lua")
dofile(path .. "/inventory_binding.lua")
dofile(path .. "/nei.lua")
dofile(path .. "/integrated_inventory.lua")
dofile(path .. "/recipe_compat.lua")
