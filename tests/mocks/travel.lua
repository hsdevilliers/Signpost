-- Test doubles for tests/travel_spec.lua.
-- Loaded as an addon file (addon.load's `extra`, before Engine/Travel.lua) it installs a stub ns.Directives registry
-- unless the real Engine/Directives.lua already did; loaded with dofile it returns the helpers below.
local ADDON_NAME, ns = ...

local M = {}

function M.registry()
	local registry = { defs = {} }
	function registry:Register(name, def)
		self.defs[name] = def
	end
	function registry:Get(name)
		return self.defs[name]
	end
	function registry:Names()
		local names = {}
		for name in pairs(self.defs) do
			names[#names + 1] = name
		end
		table.sort(names)
		return names
	end
	return registry
end

if type(ns) == "table" and ns.Directives == nil then
	ns.Directives = M.registry()
end

-- Synthetic geometry, not real coordinates: each map is a rectangle of world yards (x0, y0, w, h) on one instance.
-- The map IDs and names are the client's, so specs read naturally.
M.WORLD = {
	[947] = { name = "Azeroth", type = 1, parent = 0 },
	[1414] = { name = "Kalimdor", type = 2, parent = 947, instance = 1, x0 = 0, y0 = 0, w = 20000, h = 20000 },
	[1411] = { name = "Durotar", type = 3, parent = 1414, instance = 1, x0 = 12000, y0 = 8000, w = 4000, h = 4000 },
	[1413] = { name = "The Barrens", type = 3, parent = 1414, instance = 1, x0 = 8000, y0 = 8000, w = 4000, h = 6000 },
	[1454] = { name = "Orgrimmar", type = 3, parent = 1414, instance = 1, x0 = 12000, y0 = 6000, w = 1000, h = 1000 },
	[1415] = { name = "Eastern Kingdoms", type = 2, parent = 947, instance = 0, x0 = 0, y0 = 0, w = 20000, h = 20000 },
	[1434] = {
		name = "Stranglethorn Vale",
		type = 3,
		parent = 1415,
		instance = 0,
		x0 = 5000,
		y0 = 12000,
		w = 3000,
		h = 5000,
	},
	[9001] = { name = "Test Village", type = 5, parent = 1413, instance = 1, x0 = 9000, y0 = 9000, w = 400, h = 400 },
}

local function toWorld(world, map, x, y)
	local m = world[map]
	if not m or not m.w then
		return nil
	end
	return m.x0 + x / 100 * m.w, m.y0 + y / 100 * m.h, m.instance
end

-- Percent coordinates on `map` of the point `yards` east of (x, y) on the same map.
function M.east(map, x, y, yards, world)
	local m = (world or M.WORLD)[map]
	return map, x + yards / m.w * 100, y
end

-- A scriptable ns.Context: set pos with MoveTo/Lose, taxi, bind, known[name], and t (seconds) with Advance.
function M.context(world)
	world = world or M.WORLD
	local ctx = { t = 1000, taxi = false, known = {}, noted = {} }
	function ctx:Now()
		return self.t
	end
	function ctx:Advance(seconds)
		self.t = self.t + seconds
	end
	function ctx:Position()
		return self.pos
	end
	function ctx:MoveTo(map, x, y, fields)
		local wx, wy, instance = toWorld(world, map, x, y)
		self.pos = { map = map, x = x, y = y, wx = wx, wy = wy, instance = instance }
		for key, value in pairs(fields or {}) do
			self.pos[key] = value
		end
	end
	-- the client gives no position at all (instances; maybe transports)
	function ctx:Lose()
		self.pos = nil
	end
	function ctx:OnTaxi()
		return self.taxi
	end
	function ctx:BindLocation()
		return self.bind
	end
	function ctx:TaxiNodeKnown(name)
		return self.known[name]
	end
	function ctx:NoteTaxiNodes(nodes)
		self.noted[#self.noted + 1] = nodes
	end
	function ctx:InMap(mapID, rootMapID)
		for _ = 1, 20 do
			if mapID == nil then
				return false
			end
			if mapID == rootMapID then
				return true
			end
			local m = world[mapID]
			mapID = m and m.parent
		end
		return false
	end
	function ctx:Distance(map, x, y)
		local p = self.pos
		if not p or not p.map or not p.x then
			return nil
		end
		local ax, ay, ai = toWorld(world, p.map, p.x, p.y)
		local bx, by, bi = toWorld(world, map, x, y)
		if not ax or not bx or ai ~= bi then
			return nil
		end
		return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
	end
	return ctx
end

-- C_Map over the same world (GetMapInfo for names, types and parents; GetBestMapForUnit from the context).
function M.maps(ctx, world)
	world = world or M.WORLD
	return {
		GetMapInfo = function(id)
			local m = world[id]
			return m and { mapID = id, name = m.name, mapType = m.type, parentMapID = m.parent }
		end,
		GetBestMapForUnit = function()
			return ctx.pos and ctx.pos.map
		end,
	}
end

-- A step as the parser would build it, from directive lines (".boat 1413,1,2 > 1434,3,4").
function M.step(ns_, id, lines)
	local step = { id = id, directives = {}, sticky = {} }
	for index, line in ipairs(lines) do
		local name, argString = line:match("^%.(%S+)%s*(.*)$")
		local def = assert(ns_.Directives:Get(name), name)
		local args = assert(def.parse(argString, { source = "spec", line = index, guideId = "spec" }))
		step.directives[index] = { name = name, args = args, def = def, line = index }
	end
	return step
end

-- A ns.Progress stand-in: current step, sticky steps and per-directive state tables.
function M.progress(steps)
	local progress = { states = {}, sticky = {} }
	local byId = {}
	for _, step in ipairs(steps) do
		byId[step.id] = step
	end
	function progress:Guide()
		return { byId = byId, steps = steps }
	end
	function progress:Current()
		return self.current
	end
	function progress:Sticky()
		return self.sticky
	end
	function progress:State(stepId)
		local states = self.states[stepId]
		if not states then
			states = {}
			for index in ipairs(byId[stepId].directives) do
				states[index] = {}
			end
			self.states[stepId] = states
		end
		return states
	end
	return progress
end

return M
