
minetest.register_craftitem("mobs_wls:spider_capsule", {
	description = "Spider Capsule",
	inventory_image = "creature_pod.png",
	on_place = function(itemstack, placer, pointed_thing)
		minetest.add_entity(pointed_thing.above, "mobs_wls:spider")
	end,
})

local function spider_logic(self)
	if self.hp <= 0 then
		mobkit.clear_queue_high(self)
		mobkit.hq_die(self)
		return
	end

	if mobkit.timer(self,1) then
		local prty = mobkit.get_queue_priority(self)

		local plyr = mobkit.get_nearby_player(self)

		if prty < 10 and plyr then
			mobkit.hq_warn(self,10,plyr)
			return
		end

		if mobkit.is_queue_empty_high(self) then
			mobkit.hq_roam(self,0)
		end
	end
end


minetest.register_entity("mobs_wls:spider",{
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		collisionbox = {-0.3, -0.5, -0.3, 0.3, 0.1, 0.3},
		-- selectionbox = {-1, -1, -1, 1, 1, 1},
		visual = "mesh",
		mesh = "spider.b3d",
		textures = {"spider_baby.png"},
		visual_size = {x = 1.5, y = 1.5, z = 1.5}
	},
	timeout = 5,
	buoyancy = 0.5,
	lung_capacity = 5,
	max_hp = 20,
	on_step = mobkit.stepfunc,
	on_activate = mobkit.actfunc,
	get_staticdata = mobkit.statfunc,
	logic = spider_logic,
	animation = {
		stand={range={x=1,y=20},speed=4,loop=true},
		walk={range={x=40,y=80},speed=30,loop=true},
	},
	max_speed = 5,					-- m/s
	jump_height = 0.5,				-- nodes/meters
	view_range = 11,					-- nodes/meters
	attack={range=1, damage_groups={fleshy=2}},
	on_punch=function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if mobkit.is_alive(self) then
			mobkit.hurt(self,tool_capabilities.damage_groups.fleshy or 1)
		end
	end
})
