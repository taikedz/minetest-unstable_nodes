unstablenodes = {}

local unstabledepth = 3
local unstablerange = 5
local falldelay = 0.1

local function is_unstable(nodename)

	minetest.debug("Checking "..nodename )
	return (minetest.get_item_group(nodename, "unstable") > 0)
end

local function can_fall_through(nodename)
	return minetest.registered_nodes[nodename].buildtable_to or nodename == "air"
end

local function monitor_fall(obj)
	minetest.after(0.2, function()
		if math.abs(obj:getvelocity().y) > 0 then
			monitor_fall(obj)
		else
			local nodename = obj:get_luaentity().name
			local pos = obj:getpos()
			obj:remove()
			minetest.set_node(pos, {name=nodename})
		end
	end)
end

local function add_unstable_node(pos, nodename)
	if minetest.registered_entities[nodename] then
		local obj = minetest.add_entity(pos, nodename)
		local luae = obj:get_luaentity()
		if luae then
			obj:setvelocity({x=0, y= -luae.fallspeed, z=0})
			monitor_fall(obj)
			return true
		else
			obj:remove()
			return false
		end
	end
end

local function entityfall(pos)
	local node = minetest.get_node(pos)
	minetest.debug("Falling "..minetest.pos_to_string(pos))

	-- Remove node
	minetest.remove_node(pos)

	-- Add entity
	return add_unstable_node(pos, node.name)

end

local function fallunstable(pos, limit)
	if not limit then
		limit = unstabledepth
	end
	minetest.debug("Limit: "..tostring(limit) )

	if limit < 1 then
		return false
	end

	local node = minetest.get_node(pos)

	if not is_unstable(node.name) then
		return false
	end

	local posunder = {x = pos.x, y = pos.y - 1, z = pos.z}
	local posover = {x = pos.x, y = pos.y + 1, z = pos.z}
	
	local undernode = minetest.get_node(posunder)
	if not is_unstable(undernode.name) and not can_fall_through(undernode.name) then
		return false

	elseif can_fall_through(undernode.name) then
		minetest.after(falldelay * (limit-1), function()
			entityfall(pos)
		end)
		return true
	else
		minetest.log("error","unexpected condition on unstable ground")
	end
	return false
end

minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
	if is_unstable(node.name) then
		local unodes = minetest.find_nodes_in_area(
			{x=pos.x-unstablerange, y=pos.y-unstabledepth, z=pos.z-unstablerange},
			{x=pos.x+unstablerange, y=pos.y, z=pos.z+unstablerange},
			{"group:unstable"}
		)
		for _,thepos in pairs(unodes) do
			fallunstable(thepos)
		end
	end
end)

function unstablenodes.define_unstable_node(nodename, fallspeed)
	local tileset = minetest.registered_nodes[nodename].tiles
	if type(tileset) == "string" then
		tileset = {tileset}
	end
	local newtileset = {}

	for k,v in pairs(tileset) do
		if type(v) == "table" then
			newtileset[k] = v.name
		else
			newtileset[k] = v
		end
	end

	minetest.debug(dump(newtileset))
	while #newtileset < 6 do
		newtileset[#newtileset+1] = newtileset[#newtileset]
	end

	local def = {
		name = nodename,
		textures = newtileset,
		visual = "cube",
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		fallspeed = fallspeed or 10,
		physical = true,
		on_activate = function(self)
			monitor_fall(self.object)
		end
	}

	minetest.register_entity(nodename, def)
end

function unstablenodes.add_unstable_version(nodename)
	local newdirtdef = {}
	local newnodename = "unstablenodes:"..nodename:gsub(":","_")
	local oldnodedef = minetest.registered_nodes[nodename]
	if oldnodedef then
		for k,v in pairs(oldnodedef) do
			newdirtdef[k] = v
		end
		newdirtdef.groups.unstable = 1
		newdirtdef.description = "Unstable "..newdirtdef.description


		minetest.register_node(newnodename,newdirtdef)
		unstablenodes.define_unstable_node(newnodename)

		minetest.register_craft({
			output = newnodename,
			type = "shapeless",
			recipe = {nodename, "group:falling_node"}
		})
	else
		minetest.log("error","Could not register an unstable version of non-existent node "..nodename)
	end
end

unstablenodes.add_unstable_version("default:cobble")
unstablenodes.add_unstable_version("default:dirt_with_grass")
minetest.register_alias("unstablenodes:unstable_dirt","unstablenodes:default_dirt_with_grass")