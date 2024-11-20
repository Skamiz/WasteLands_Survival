local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
food = {}

dofile(modpath .. '/bugs.lua')
dofile(modpath .. '/cauldron.lua')

minetest.register_craftitem("food:can", {
	description = "A Can of Preserved Food",
	inventory_image = "food_can.png",
	groups = {food = 1},
	on_use = minetest.item_eat(6),
})
