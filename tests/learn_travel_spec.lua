-- Specs for the travel parts of Core/Learn.lua: boat and zeppelin rides, innkeepers and /signpost ride. The client is
-- the scriptable one of tests/mocks/learn.lua; every second of play is one tick of the position sample (Learn:Sample).
local addon = dofile("tests/helpers/addon.lua")
local mocks = dofile("tests/mocks/learn.lua")
local G = addon.G

local INNKEEPER = "Creature-0-1465-1-47-6929-00004F2B3C"
local PLAYER = "Player-1465-0A1B2C3D"
local PET = "Pet-0-1465-1-47-3100-01004F2B42"
local BINDER_ICON = "Interface\\GossipFrame\\BinderGossipIcon"

-- Two docks on two continents, as the client would report them while the player stands there. Their world coordinates
-- are alike on purpose: only the other world (instance) tells them apart.
local WEST_DOCK = { map = 1411, x = 0.509, y = 0.13, wx = 1000, wy = 2000, instance = 1, subzone = "West Dock" }
local EAST_DOCK = { map = 1420, x = 0.608, y = 0.589, wx = 1000, wy = 2000, instance = 0, subzone = "East Dock" }

local NONE = {} -- a field set to NONE is taken out of the world (no map position, say)

local function load(before)
	local world
	local ns, mock = addon.load({
		extra = { "Core/Learn.lua" },
		before = function(m)
			world = mocks.install(G)
			if before then
				before(m, world)
			end
		end,
	})
	-- The travel tables are made when first used (the others are in the defaults, which tests/core_spec.lua pins): the
	-- specs look at them from the start.
	ns.Learn:Table("rides")
	ns.Learn:Table("inns")
	return ns, mock, world
end

-- Whether text occurs anywhere (keys or values) in a nested table.
local function contains(value, text)
	if type(value) == "string" then
		return value:find(text, 1, true) ~= nil
	elseif type(value) == "table" then
		for key, item in pairs(value) do
			if contains(key, text) or contains(item, text) then
				return true
			end
		end
	end
	return false
end

-- Sets the world, lets a second pass and takes the position sample the ticker takes.
local function tick(ns, mock, world, state)
	for key, value in pairs(state or {}) do
		if value == NONE then
			world[key] = nil
		else
			world[key] = value
		end
	end
	mock.now = mock.now + 1
	ns.Learn:Sample()
end

local function stand(ns, mock, world, where, count)
	for _ = 1, count do
		tick(ns, mock, world, where)
	end
end

-- The deck moves `yards` along the world every second; the player's own speed is 0.
local function carry(ns, mock, world, count, yards)
	for _ = 1, count do
		tick(ns, mock, world, { wx = world.wx + yards })
	end
end

-- A loading screen of `seconds`, in the order the client sends its events, that ends where `where` says.
local function loading(mock, world, where, seconds)
	mock.fire("LOADING_SCREEN_ENABLED")
	mock.now = mock.now + seconds
	for key, value in pairs(where) do
		world[key] = value
	end
	mock.fire("LOADING_SCREEN_DISABLED")
	mock.fire("PLAYER_ENTERING_WORLD")
end

-- A ride: three seconds on the pier, twelve carried, a loading screen of eight, four more carried, three on the ground.
-- Returns when the ride began (the first carried sample) and when the player was on the ground again.
local function ride(ns, mock, world, from, to)
	world.speed = 0
	stand(ns, mock, world, from, 3)
	local began = mock.now + 1
	carry(ns, mock, world, 12, 20)
	loading(mock, world, to, 8)
	carry(ns, mock, world, 4, 20)
	stand(ns, mock, world, {}, 1)
	local arrived = mock.now
	stand(ns, mock, world, {}, 2)
	return began, arrived
end

local function talkTo(world, guid, name)
	world.units.npc = { guid = guid, name = name }
end

local function printed(mock)
	return table.concat(mock.printed, "\n")
end

describe("Learn: boat and zeppelin rides", function()
	after_each(function()
		mocks.uninstall(G)
	end)

	it("records the dock the player left and the one they arrived at, across a loading screen", function()
		local ns, mock, world = load()
		local began, arrived = ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		assert.are.equal(24, arrived - began)
		assert.are.same({
			{
				from = { map = 1411, x = 50.9, y = 13 },
				to = { map = 1420, x = 60.8, y = 58.9 },
				side = "Horde",
				fromArea = "West Dock",
				toArea = "East Dock",
				secs = 24,
				t = 1790000000,
				c = 1,
			},
		}, ns.db.learned.rides)
		assert.are.same({ rides = 1, inns = 0 }, ns.Learn:TravelCounts())
	end)

	it("records a ride in which the client gives no map position on board", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, WEST_DOCK, 3)
		stand(ns, mock, world, { x = NONE }, 20)
		stand(ns, mock, world, { x = 0.3, wx = 2400 }, 3)
		local rides = ns.db.learned.rides
		assert.are.equal(1, #rides)
		assert.are.same({ map = 1411, x = 50.9, y = 13 }, rides[1].from)
		assert.are.same({ map = 1411, x = 30, y = 13 }, rides[1].to)
		assert.are.equal(21, rides[1].secs) -- from the first sample without a position to the first on the ground again
	end)

	it("counts a ride again and refines the docks when it is ridden between the same two docks", function()
		local ns, mock, world = load()
		ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		loading(mock, world, WEST_DOCK, 5) -- a hearthstone back
		mock.clock = mock.clock + 100
		local nearby = { map = 1411, x = 0.513, y = 0.13, wx = 1000, wy = 2000, instance = 1, subzone = "West Dock" }
		ride(ns, mock, world, nearby, EAST_DOCK)
		local rides = ns.db.learned.rides
		assert.are.equal(1, #rides)
		assert.are.same({ 2, mock.clock, 51.1 }, { rides[1].c, rides[1].t, rides[1].from.x })
		-- the way back is a ride of its own (tools/signpost_tools/learned.py joins the two)
		ride(ns, mock, world, EAST_DOCK, WEST_DOCK)
		assert.are.equal(2, #ns.db.learned.rides)
		assert.are.same({ map = 1420, x = 60.8, y = 58.9 }, ns.db.learned.rides[2].from)
	end)

	it("takes the kind from /signpost ride, once, and only when it was named recently", function()
		local ns, mock, world = load()
		SlashCmdList.SIGNPOST("ride zeppelin")
		assert.truthy(printed(mock):find("recorded as a zeppelin", 1, true))
		ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		assert.are.equal("zeppelin", ns.db.learned.rides[1].kind)
		-- used up: the next ride is not named
		loading(mock, world, { map = 1413, x = 0.2, y = 0.2, wx = 3000, wy = 3000, instance = 1, subzone = "" }, 5)
		ride(
			ns,
			mock,
			world,
			{ map = 1413, x = 0.2, y = 0.2, wx = 3000, wy = 3000, instance = 1, subzone = "" },
			EAST_DOCK
		)
		assert.is_nil(ns.db.learned.rides[2].kind)
		-- named too long ago
		SlashCmdList.SIGNPOST("ride boat")
		mock.now = mock.now + 700
		loading(mock, world, WEST_DOCK, 5)
		ride(
			ns,
			mock,
			world,
			WEST_DOCK,
			{ map = 1413, x = 0.9, y = 0.9, wx = 5000, wy = 5000, instance = 1, subzone = "" }
		)
		assert.is_nil(ns.db.learned.rides[3].kind)
		SlashCmdList.SIGNPOST("ride boat")
		SlashCmdList.SIGNPOST("ride clear")
		assert.is_nil(ns.Learn.rideKind)
		SlashCmdList.SIGNPOST("ride")
		assert.truthy(printed(mock):find("say what you are about to ride", 1, true))
	end)

	it(
		"is not fooled by a hearthstone, a teleport or a summon: a loading screen with no stretch of being carried",
		function()
			local ns, mock, world = load()
			world.speed = 0
			stand(ns, mock, world, WEST_DOCK, 5)
			loading(mock, world, EAST_DOCK, 10)
			stand(ns, mock, world, {}, 6)
			assert.are.same({}, ns.db.learned.rides)
		end
	)

	it("is not fooled by a flight, an instance, death, or a mount", function()
		local cases = {
			["a flight"] = function(ns, mock, world)
				world.taxi = true
				carry(ns, mock, world, 20, 20)
				world.taxi = false
			end,
			["an instance"] = function(ns, mock, world)
				world.instanceType = "party"
				carry(ns, mock, world, 20, 20)
				world.instanceType = "none"
			end,
			["death"] = function(ns, mock, world)
				world.dead = true
				carry(ns, mock, world, 20, 20)
				world.dead = false
			end,
			["a mount"] = function(ns, mock, world)
				world.speed = 14
				carry(ns, mock, world, 40, 14)
				world.speed = 0
			end,
		}
		for name, run in pairs(cases) do
			local ns, mock, world = load()
			world.speed = 0
			stand(ns, mock, world, WEST_DOCK, 3)
			run(ns, mock, world)
			stand(ns, mock, world, {}, 4)
			assert.are.same({}, ns.db.learned.rides, name)
			mocks.uninstall(G)
		end
	end)

	it("goes on through a pause of a second (a transport slowing down is not the end of the ride)", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, WEST_DOCK, 3)
		carry(ns, mock, world, 8, 20)
		stand(ns, mock, world, { x = 0.55 }, 1) -- a second at rest, somewhere else on the map
		carry(ns, mock, world, 8, 20)
		loading(mock, world, EAST_DOCK, 8)
		carry(ns, mock, world, 4, 20)
		stand(ns, mock, world, {}, 3)
		local rides = ns.db.learned.rides
		assert.are.equal(1, #rides)
		assert.are.same({ map = 1411, x = 50.9, y = 13 }, rides[1].from) -- the dock, not the pause
	end)

	it("does not take a jump of hundreds of yards in a second for a ride (a summon, a portal)", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, WEST_DOCK, 3)
		carry(ns, mock, world, 20, 500)
		stand(ns, mock, world, {}, 3)
		assert.are.same({}, ns.db.learned.rides)
	end)

	it("does not start a ride from a dock last seen long ago", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, WEST_DOCK, 3)
		mock.now = mock.now + 100 -- the samples stopped for a while
		stand(ns, mock, world, { x = NONE }, 20)
		stand(ns, mock, world, { x = 0.3, wx = 2400 }, 3)
		assert.are.same({}, ns.db.learned.rides)
	end)

	it("is not fooled by a hearthstone followed by seconds without a map position", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, WEST_DOCK, 5)
		loading(mock, world, EAST_DOCK, 3)
		stand(ns, mock, world, { x = NONE }, 20)
		stand(ns, mock, world, { x = 0.3 }, 3)
		assert.are.same({}, ns.db.learned.rides)
	end)

	it("keeps no dock on a continent map (the open sea)", function()
		local ns, mock, world = load()
		world.maps[1414] = { mapID = 1414, mapType = 2 }
		ride(
			ns,
			mock,
			world,
			WEST_DOCK,
			{ map = 1414, x = 0.4, y = 0.4, wx = 500, wy = 700, instance = 0, subzone = "" }
		)
		assert.are.same({}, ns.db.learned.rides)
	end)

	it("keeps the kind a ride was named when it is ridden again without naming it", function()
		local ns, mock, world = load()
		SlashCmdList.SIGNPOST("ride boat")
		ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		loading(mock, world, WEST_DOCK, 5)
		ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		assert.are.same(
			{ 1, "boat", 2 },
			{ #ns.db.learned.rides, ns.db.learned.rides[1].kind, ns.db.learned.rides[1].c }
		)
	end)

	it("is not fooled by a flight, an instance or death that also takes the map position away", function()
		local cases = {
			["a flight"] = { taxi = true },
			["an instance"] = { instanceType = "party" },
			["death"] = { dead = true },
		}
		for name, state in pairs(cases) do
			local ns, mock, world = load()
			world.speed = 0
			stand(ns, mock, world, WEST_DOCK, 3)
			local gone = { x = NONE }
			for key, value in pairs(state) do
				gone[key] = value
			end
			stand(ns, mock, world, gone, 20)
			stand(ns, mock, world, { x = 0.3, wx = 2400, taxi = false, instanceType = "none", dead = false }, 4)
			assert.are.same({}, ns.db.learned.rides, name)
			mocks.uninstall(G)
		end
	end)

	it("does not take stopping after a run for a ride", function()
		local ns, mock, world = load()
		world.speed = 14
		carry(ns, mock, world, 30, 14)
		world.speed = 0
		carry(ns, mock, world, 1, 10) -- the second in which the player stopped: moved, and no longer moving
		stand(ns, mock, world, {}, 4)
		assert.are.same({}, ns.db.learned.rides)
	end)

	it("needs three samples in a row of being carried", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, WEST_DOCK, 3)
		for _ = 1, 8 do
			carry(ns, mock, world, 2, 20)
			stand(ns, mock, world, {}, 1)
		end
		loading(mock, world, EAST_DOCK, 5)
		stand(ns, mock, world, {}, 4)
		assert.are.same({}, ns.db.learned.rides)
	end)

	it("keeps only stretches of fifteen seconds or more, between docks 300 yards apart or in another world", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, WEST_DOCK, 3)
		carry(ns, mock, world, 4, 20) -- far apart (another world) but only about eight seconds
		loading(mock, world, EAST_DOCK, 1)
		stand(ns, mock, world, {}, 3)
		assert.are.same({}, ns.db.learned.rides)
		-- long, but it ends where it began
		stand(ns, mock, world, WEST_DOCK, 3)
		carry(ns, mock, world, 10, 20)
		carry(ns, mock, world, 10, -20)
		stand(ns, mock, world, {}, 3)
		assert.are.same({}, ns.db.learned.rides)
	end)

	it("forgets a ride that cannot tell whether the player is carried, or lasts too long", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, WEST_DOCK, 3)
		stand(ns, mock, world, { x = NONE }, 5)
		assert.is_table(ns.Learn.ride)
		G.GetUnitSpeed = nil -- no reading of the player's own speed: positions come back, nothing says carried or not
		stand(ns, mock, world, { x = 0.3 }, 70)
		assert.is_nil(ns.Learn.ride)
		assert.is_nil(ns.Learn.dock)
		assert.are.same({}, ns.db.learned.rides)
		-- an unmapped stretch that never ends is no ride either
		G.GetUnitSpeed = function()
			return world.speed
		end
		stand(ns, mock, world, {}, 3)
		stand(ns, mock, world, { x = NONE }, 2)
		assert.is_table(ns.Learn.ride)
		mock.now = mock.now + 1000
		stand(ns, mock, world, { x = NONE }, 1)
		assert.is_nil(ns.Learn.ride)
	end)

	it("needs a dock: no ride begins out of nowhere", function()
		local ns, mock, world = load()
		world.speed = 0
		stand(ns, mock, world, { x = NONE }, 30) -- no position since login, and nothing before it
		stand(ns, mock, world, { x = 0.3, wx = 2400 }, 4)
		assert.are.same({}, ns.db.learned.rides)
		mocks.uninstall(G)
		ns, mock, world = load()
		world.speed = 0
		carry(ns, mock, world, 20, 20) -- carried right after login: nothing says where it began
		stand(ns, mock, world, {}, 4)
		assert.are.same({}, ns.db.learned.rides)
	end)

	it("records nothing without the player's yes on a release build", function()
		local ns, mock, world = load()
		ns.isDev = false
		ns.db.contribute.enabled = false
		ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		assert.are.same({}, ns.db.learned.rides)
		SlashCmdList.SIGNPOST("ride boat")
		assert.truthy(printed(mock):find("nothing is recorded until you agree", 1, true))
		assert.is_nil(ns.Learn.rideKind)
		ns.db.contribute.enabled = true
		loading(mock, world, WEST_DOCK, 5)
		ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		assert.are.equal(1, #ns.db.learned.rides)
	end)

	it("keeps nothing about the player: no name, no chat", function()
		local ns, mock, world = load()
		world.units.player = { guid = PLAYER, name = "Someplayer" }
		world.units.pet = { guid = PET, name = "Fluffy" }
		ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		assert.are.equal(1, #ns.db.learned.rides)
		assert.is_false(contains(ns.db.learned, "Someplayer"))
		assert.is_false(contains(ns.db.learned, "Fluffy"))
		-- what a ride holds: two positions, the areas, the faction, the time it took, the counts
		local keys = {}
		for key in pairs(ns.db.learned.rides[1]) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		assert.are.same({ "c", "from", "fromArea", "secs", "side", "t", "to", "toArea" }, keys)
	end)

	it("drops the ride seen longest ago when the list is full", function()
		local ns, mock, world = load()
		ns.Learn.LIMITS.rides = 2
		local docks = {
			{ map = 1411, x = 0.1, y = 0.1, wx = 1000, wy = 1000, instance = 1, subzone = "A" },
			{ map = 1411, x = 0.5, y = 0.5, wx = 4000, wy = 4000, instance = 1, subzone = "B" },
			{ map = 1411, x = 0.9, y = 0.9, wx = 7000, wy = 7000, instance = 1, subzone = "C" },
		}
		for i = 1, 3 do
			mock.clock = 1790000000 + i
			loading(mock, world, docks[i], 5)
			ride(ns, mock, world, docks[i], EAST_DOCK)
		end
		local areas = {}
		for _, found in ipairs(ns.db.learned.rides) do
			areas[#areas + 1] = found.fromArea
		end
		table.sort(areas)
		assert.are.same({ "B", "C" }, areas)
	end)
end)

describe("Learn: innkeepers", function()
	after_each(function()
		mocks.uninstall(G)
	end)

	local function binder(name, icon)
		return { name = name or "Make this inn your home.", icon = icon or BINDER_ICON }
	end

	it("records an innkeeper where the player stood at the window that offers to make the inn their home", function()
		local ns, mock, world = load()
		talkTo(world, INNKEEPER, "Innkeeper")
		world.gossip = { { name = "I want to browse your goods." }, binder() }
		world.x, world.y = 0.5151, 0.4164
		mock.fire("GOSSIP_SHOW")
		assert.are.same({ map = 1411, x = 51.51, y = 41.64, t = 1790000000, c = 1 }, ns.db.learned.inns[6929])
		assert.are.equal(1, ns.Learn:TravelCounts().inns)
		assert.are.equal("Innkeeper", ns.db.learned.npcs[6929].n) -- the NPC itself is learned as for any gossip
	end)

	it("knows the option by the icon's file ID or by its words", function()
		local cases = {
			["file ID"] = function(world)
				world.files[BINDER_ICON] = 136458
				world.gossip = { { name = "x", icon = 136458 } }
			end,
			["words"] = function(world)
				world.gossip = { { name = "Make this inn your home." } }
			end,
			["path"] = function(world)
				world.gossip = { { name = "x", icon = BINDER_ICON } }
			end,
		}
		for name, setup in pairs(cases) do
			local ns, mock, world = load()
			talkTo(world, INNKEEPER, "Innkeeper")
			setup(world)
			mock.fire("GOSSIP_SHOW")
			assert.is_table(ns.db.learned.inns[6929], name)
			mocks.uninstall(G)
		end
	end)

	it("learns no inn from a trainer, a vendor, a player or a pet", function()
		local ns, mock, world = load()
		talkTo(world, INNKEEPER, "Vendor")
		world.gossip = {
			{ name = "I want to browse your goods.", icon = 7 },
			{ name = "Train me.", icon = 8 },
			{ name = "Where is the nearest inn?", icon = 9 }, -- "inn" alone is not the option that sets the home
		}
		mock.fire("GOSSIP_SHOW")
		for _, who in ipairs({ { PLAYER, "Someplayer" }, { PET, "Fluffy" } }) do
			talkTo(world, who[1], who[2])
			world.gossip = { binder() }
			mock.fire("GOSSIP_SHOW")
		end
		assert.are.same({}, ns.db.learned.inns)
		assert.is_false(contains(ns.db.learned, "Someplayer"))
		assert.is_false(contains(ns.db.learned, "Fluffy"))
	end)

	it("counts a visit once and moves an innkeeper seen somewhere else", function()
		local ns, mock, world = load()
		talkTo(world, INNKEEPER, "Innkeeper")
		world.gossip = { binder() }
		world.x = 0.5
		mock.fire("GOSSIP_SHOW")
		mock.clock = mock.clock + 30
		mock.fire("GOSSIP_SHOW")
		assert.are.equal(1, ns.db.learned.inns[6929].c)
		mock.clock = mock.clock + 100
		mock.fire("GOSSIP_SHOW")
		assert.are.equal(2, ns.db.learned.inns[6929].c)
		world.x = 0.8
		mock.fire("GOSSIP_SHOW")
		assert.are.same({ 80, 1 }, { ns.db.learned.inns[6929].x, ns.db.learned.inns[6929].c })
	end)

	it("keeps the bind location's name when the player made the inn their home a moment after the window", function()
		local ns, mock, world = load()
		world.bind = "Orgrimmar"
		ns.Learn:Sample() -- the first reading is only noted
		talkTo(world, INNKEEPER, "Innkeeper")
		world.gossip = { binder() }
		mock.fire("GOSSIP_SHOW")
		mock.now = mock.now + 1
		ns.Learn:Sample()
		assert.is_nil(ns.db.learned.inns[6929].n) -- nothing changed yet
		mock.now = mock.now + 5
		world.bind = "Razor Hill"
		ns.Learn:Sample()
		assert.are.equal("Razor Hill", ns.db.learned.inns[6929].n)
		-- a later change of the bind location is not that inn's name
		mock.now = mock.now + 5
		world.bind = "Undercity"
		ns.Learn:Sample()
		assert.are.equal("Razor Hill", ns.db.learned.inns[6929].n)
	end)

	it("ignores a bind location that changes long after the window, or with no window at all", function()
		local ns, mock, world = load()
		world.bind = "Orgrimmar"
		ns.Learn:Sample()
		world.bind = "Razor Hill"
		ns.Learn:Sample() -- no innkeeper was talked to
		talkTo(world, INNKEEPER, "Innkeeper")
		world.gossip = { binder() }
		mock.fire("GOSSIP_SHOW")
		mock.now = mock.now + 200
		world.bind = "Undercity"
		ns.Learn:Sample()
		assert.is_nil(ns.db.learned.inns[6929].n)
	end)

	it("records nothing without the player's yes on a release build", function()
		local ns, mock, world = load()
		ns.isDev = false
		ns.db.contribute.enabled = false
		talkTo(world, INNKEEPER, "Innkeeper")
		world.gossip = { binder() }
		mock.fire("GOSSIP_SHOW")
		assert.are.same({}, ns.db.learned.inns)
	end)

	it("keeps at most LIMITS.inns innkeepers, dropping the one seen longest ago", function()
		local ns, mock, world = load()
		ns.Learn.LIMITS.inns = 2
		world.gossip = { binder() }
		for i, id in ipairs({ 101, 102, 103 }) do
			mock.clock = 1790000000 + i
			talkTo(world, string.format("Creature-0-1465-1-47-%d-00004F2B3C", id), "Innkeeper")
			mock.fire("GOSSIP_SHOW")
		end
		assert.is_nil(ns.db.learned.inns[101])
		assert.is_table(ns.db.learned.inns[102])
		assert.is_table(ns.db.learned.inns[103])
	end)
end)

describe("Learn: travel commands", function()
	after_each(function()
		mocks.uninstall(G)
	end)

	it("prints what /signpost learned has recorded of the travel", function()
		local ns, mock, world = load()
		ride(ns, mock, world, WEST_DOCK, EAST_DOCK)
		talkTo(world, INNKEEPER, "Innkeeper")
		world.gossip = { { name = "Make this inn your home." } }
		mock.fire("GOSSIP_SHOW")
		SlashCmdList.SIGNPOST("learned")
		assert.truthy(printed(mock):find("learned: 1 boat or zeppelin rides, 1 innkeepers", 1, true))
		-- the line about everything else stays the last one
		assert.truthy(mock.printed[#mock.printed]:find("learned: ", 1, true))
		assert.truthy(ns.Slash.commands.ride.help)
	end)

	it("loads and handles everything without errors on a client that lacks the APIs", function()
		local ns, mock = load(function()
			mocks.uninstall(G)
		end)
		for _, event in ipairs({
			"GOSSIP_SHOW",
			"LOADING_SCREEN_ENABLED",
			"LOADING_SCREEN_DISABLED",
			"PLAYER_ENTERING_WORLD",
		}) do
			mock.fire(event)
		end
		for _ = 1, 5 do
			ns.Learn:Sample()
		end
		SlashCmdList.SIGNPOST("ride boat")
		SlashCmdList.SIGNPOST("learned")
		assert.are.same({}, mock.errors)
		assert.are.same({}, ns.db.errors)
		assert.are.same({ rides = 0, inns = 0 }, ns.Learn:TravelCounts())
	end)
end)
