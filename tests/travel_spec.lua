local addon = dofile("tests/helpers/addon.lua")
local mocks = dofile("tests/mocks/travel.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

-- The registry stub must load before Engine/Travel.lua (it steps aside once Engine/Directives.lua is in the TOC).
local EXTRA = { "tests/mocks/travel.lua", "Engine/Travel.lua", "Guides/Travel/Borders.lua" }

-- Client globals these specs set that tests/wow_mock.lua does not reset itself.
local CLIENT = {
	"GetSubZoneText",
	"GetZoneText",
	"GetMinimapZoneText",
	"GetRealZoneText",
	"NumTaxiNodes",
	"TaxiNodeName",
	"TaxiNodeGetType",
	"C_Spell",
}

-- Synthetic test IDs (not the client's).
local HEARTH_SPELL = 99001

local function load(pack)
	local ns, mock = addon.load({
		extra = EXTRA,
		before = function()
			G.Signpost_Data = pack and { _meta = { schema = 1 }, travel = pack.travel, maps = pack.maps }
		end,
	})
	local ctx = mocks.context()
	G.C_Map = mocks.maps(ctx)
	ns.Context = ctx
	return ns, mock, ctx
end

local function directive(ns, name)
	return assert(ns.Directives:Get(name), name)
end

local function parse(ns, line)
	local name, argString = line:match("^%.(%S+)%s*(.*)$")
	return directive(ns, name).parse(argString, { source = "spec", line = 1, guideId = "spec" })
end

-- Errors raised by Engine/Travel.lua (or these doubles) under ns.SafeCall.
local function travelErrors(mock)
	local found = {}
	for _, message in ipairs(mock.errors) do
		if message:lower():find("travel", 1, true) then
			found[#found + 1] = message
		end
	end
	return found
end

-- A guide with the given steps, the first one current, plus a recorder for TRANSPORT_STATE.
local function route(ns, steps)
	local progress = mocks.progress(steps)
	progress.current = steps[1]
	ns.Progress = progress
	local seen = {}
	ns.Events:RegisterMessage("TRANSPORT_STATE", function(_, stepId, state)
		seen[#seen + 1] = stepId .. "=" .. state
	end)
	return progress, seen
end

local function changed(ns, what)
	ns.Events:Fire("CONTEXT_CHANGED", what or "position")
end

after_each(function()
	for _, name in ipairs(CLIENT) do
		G[name] = nil
	end
end)

describe("travel directives", function()
	it("registers the eight travel directives", function()
		local ns, mock = load()
		for _, name in ipairs({ "path", "zone", "fp", "fly", "boat", "zeppelin", "hs", "home" }) do
			local def = directive(ns, name)
			assert.are.equal("travel", def.kind, name)
			for _, fn in ipairs({ "parse", "isSatisfied", "targets", "describe" }) do
				assert.is_function(def[fn], name .. "." .. fn)
			end
		end
		assert.are.same({}, travelErrors(mock))
	end)

	it("matches flight node names the way guides write them", function()
		local ns = load()
		local matches = ns.Travel.NodeNameMatches
		assert.is_true(matches("Ratchet", "Ratchet, The Barrens"))
		assert.is_true(matches("ratchet, the barrens", "Ratchet, The Barrens"))
		assert.is_true(matches("Crossroads", "The Crossroads, The Barrens"))
		assert.is_true(matches("Orgrimmar", "Orgrimmar, Durotar"))
		assert.is_false(matches("The Barrens", "Ratchet, The Barrens"))
		assert.is_false(matches(nil, "Ratchet, The Barrens"))
	end)
end)

describe("parsing", function()
	local ns
	before_each(function()
		ns = load()
	end)

	it("reads .path waypoints, possibly across maps", function()
		assert.are.same({
			points = {
				{ map = 1411, x = 52, y = 43.5 },
				{ map = 1411, x = 47.8, y = 41 },
				{ map = 1413, x = 61.9, y = 54.9 },
			},
		}, parse(ns, ".path 1411,52.0,43.5 ; 1411,47.8,41.0 ; 1413,61.9,54.9"))
		assert.are.same({ points = { { map = 1411, x = 1, y = 2 } } }, parse(ns, ".path 1411,1,2 >> Run west"))
	end)

	it("rejects bad .path waypoints with a message", function()
		for _, line in ipairs({
			".path",
			".path 1411,52",
			".path 1411,120,5",
			".path Durotar,1,2",
			".path 1411,1,2 ;",
			".path 1411,1,2,15",
		}) do
			local args, problem = parse(ns, line)
			assert.is_nil(args, line)
			assert.is_string(problem, line)
		end
	end)

	it("reads .zone, .fp, .fly, .hs and .home", function()
		assert.are.same({ map = 1413 }, parse(ns, ".zone 1413"))
		assert.is_nil((parse(ns, ".zone The Barrens")))
		assert.is_nil((parse(ns, ".zone 1413.5")))
		assert.are.same({ map = 1413, name = "Ratchet" }, parse(ns, ".fp 1413,Ratchet"))
		assert.are.same({ map = 1413, name = "Ratchet, The Barrens" }, parse(ns, ".fp 1413, Ratchet, The Barrens"))
		assert.is_nil((parse(ns, ".fp Ratchet")))
		assert.is_nil((parse(ns, ".fp 1413,")))
		assert.are.same({ name = "Orgrimmar" }, parse(ns, ".fly Orgrimmar"))
		assert.is_nil((parse(ns, ".fly")))
		assert.are.same({ name = "Razor Hill" }, parse(ns, ".hs Razor Hill"))
		assert.is_nil((parse(ns, ".hs")))
		assert.are.same({}, parse(ns, ".home"))
		local args, problem = parse(ns, ".home Razor Hill")
		assert.is_nil(args)
		assert.truthy(problem:find("no arguments", 1, true))
	end)

	it("reads .boat and .zeppelin as departure > arrival", function()
		assert.are.same(
			{ kind = "boat", from = { map = 1413, x = 63.9, y = 38.6 }, to = { map = 1434, x = 27.2, y = 77.1 } },
			parse(ns, ".boat 1413,63.9,38.6 > 1434,27.2,77.1 >> Take the boat")
		)
		assert.are.equal("zeppelin", parse(ns, ".zeppelin 1411,1,2 > 1434,3,4").kind)
		assert.is_nil((parse(ns, ".boat 1413,63.9,38.6")))
		assert.is_nil((parse(ns, ".boat 1413,63.9,38.6 > 1434,27.2")))
		assert.is_nil((parse(ns, ".zeppelin 1411,1,2 > 1434,3,4 > 1413,5,6")))
	end)
end)

describe(".path", function()
	local ns, ctx, path
	before_each(function()
		local _
		ns, _, ctx = load()
		path = directive(ns, "path")
	end)

	-- Three waypoints 400 yd apart along Durotar's y = 10 line (1% of Durotar is 40 yd in the test world).
	local LINE = ".path 1411,10,10 ; 1411,20,10 ; 1411,30,10"

	it("advances waypoint by waypoint within 15 yd and completes at the last", function()
		local args, state = parse(ns, LINE), {}
		ctx:MoveTo(1411, 5, 10) -- 200 yd before the first
		assert.is_false(path.isSatisfied(args, ctx, state))
		assert.are.equal(1, state.next)
		ctx:MoveTo(1411, 10.25, 10) -- 10 yd from the first
		assert.is_false(path.isSatisfied(args, ctx, state))
		assert.are.equal(2, state.next)
		ctx:MoveTo(1411, 20.3, 10) -- 12 yd from the second
		assert.is_false(path.isSatisfied(args, ctx, state))
		ctx:MoveTo(1411, 30, 10.2) -- 8 yd from the last
		assert.is_true(path.isSatisfied(args, ctx, state))
		assert.are.equal(4, state.next)
	end)

	it("pins the next waypoint for the minimap and every waypoint for the world map", function()
		local args, state = parse(ns, LINE), {}
		ctx:MoveTo(1411, 10, 10)
		local targets = path.targets(args, ctx, state)
		assert.are.equal(3, #targets)
		for index, target in ipairs(targets) do
			assert.are.equal("waypoint", target.kind)
			assert.are.equal(index, target.index)
			assert.are.equal(3, target.count)
			assert.are.equal(15, target.radius)
			assert.are.equal(1411, target.map)
		end
		assert.is_true(targets[1].reached)
		assert.is_true(targets[2].next)
		assert.is_true(targets[2].minimap)
		assert.is_false(targets[1].minimap)
		assert.is_false(targets[3].minimap)
		assert.are.equal("Waypoint 2/3", targets[2].label)
	end)

	it("counts every earlier waypoint once a later one is reached", function()
		local args, state = parse(ns, LINE), {}
		ctx:MoveTo(1411, 20, 10.1)
		assert.is_false(path.isSatisfied(args, ctx, state))
		assert.are.equal(3, state.next)
	end)

	it("keeps its progress while the position is unknown", function()
		local args, state = parse(ns, LINE), {}
		ctx:MoveTo(1411, 10, 10)
		path.isSatisfied(args, ctx, state)
		ctx:Lose()
		assert.is_false(path.isSatisfied(args, ctx, state))
		assert.are.equal(2, state.next)
	end)

	it("uses the waypoint radius from the settings", function()
		local args = parse(ns, LINE)
		ctx:MoveTo(1411, 11, 10) -- 40 yd from the first
		local state = {}
		path.isSatisfied(args, ctx, state)
		assert.are.equal(1, state.next)
		ns.db.settings.waypointRadius = 50
		path.isSatisfied(args, ctx, state)
		assert.are.equal(2, state.next)
	end)

	it("crosses into the next zone and says where it leads", function()
		local args, state = parse(ns, ".path 1411,1,50 ; 1413,99,50"), {}
		assert.are.equal("Follow the waypoints to The Barrens", path.describe(args, ctx))
		ctx:MoveTo(1411, 1, 50)
		path.isSatisfied(args, ctx, state)
		assert.are.equal("Follow the waypoints to The Barrens (waypoint 2/2)", path.describe(args, ctx, state))
		ctx:MoveTo(1413, 99.2, 50)
		assert.is_true(path.isSatisfied(args, ctx, state))
	end)

	it("is brought up to date on every context change for the current step", function()
		local step = mocks.step(ns, "spec:path", { LINE })
		local progress = route(ns, { step })
		ctx:MoveTo(1411, 10, 10)
		changed(ns)
		assert.are.equal(2, progress:State("spec:path")[1].next)
	end)
end)

describe(".zone", function()
	local ns, ctx, zone
	before_each(function()
		local _
		ns, _, ctx = load()
		zone = directive(ns, "zone")
	end)

	it("is satisfied in the zone and anywhere below it in the map tree", function()
		ctx:MoveTo(1413, 50, 50)
		assert.is_true(zone.isSatisfied({ map = 1413 }, ctx))
		ctx:MoveTo(9001, 50, 50) -- a map below The Barrens
		assert.is_true(zone.isSatisfied({ map = 1413 }, ctx))
		ctx.pos = { map = 1413 } -- a map but no coordinates
		assert.is_true(zone.isSatisfied({ map = 1413 }, ctx))
	end)

	it("is not satisfied in a sibling map or without a position", function()
		ctx:MoveTo(1454, 50, 50) -- Orgrimmar is not below Durotar (FOREVER-API-NOTES)
		assert.is_false(zone.isSatisfied({ map = 1411 }, ctx))
		ctx:Lose()
		assert.is_false(zone.isSatisfied({ map = 1411 }, ctx))
	end)

	it("has no pin and names the zone", function()
		assert.are.same({}, zone.targets({ map = 1413 }, ctx))
		assert.are.equal("Enter The Barrens", zone.describe({ map = 1413 }, ctx))
	end)
end)

describe(".fp", function()
	it("is satisfied when ns.Context knows the node by the guide's name", function()
		local ns, _, ctx = load()
		local fp, args = directive(ns, "fp"), parse(ns, ".fp 1413,Ratchet")
		assert.is_false(fp.isSatisfied(args, ctx))
		ctx.known.Ratchet = true
		assert.is_true(fp.isSatisfied(args, ctx))
	end)

	it("asks ns.Context for the client's name of the node too", function()
		local ns, _, ctx = load()
		G.C_TaxiMap = {
			GetTaxiNodesForMap = function(mapID)
				if mapID == 1414 then
					return {
						{ nodeID = 80, name = "Ratchet, The Barrens", position = { x = 0.6, y = 0.5 }, faction = 0 },
					}
				end
				return {}
			end,
		}
		local fp, args = directive(ns, "fp"), parse(ns, ".fp 1413,Ratchet")
		ctx.known["Ratchet, The Barrens"] = true
		assert.is_true(fp.isSatisfied(args, ctx))
	end)

	it("learns known nodes when a flight map opens and feeds them to ns.Context", function()
		local ns, mock, ctx = load()
		local names = { "Razor Hill, Durotar", "Ratchet, The Barrens", "zzOLDTest Node, Durotar" }
		local kinds = { "CURRENT", "NONE", "REACHABLE" }
		G.NumTaxiNodes = function()
			return 3
		end
		G.TaxiNodeName = function(slot)
			return names[slot]
		end
		G.TaxiNodeGetType = function(slot)
			return kinds[slot]
		end
		mock.fire("TAXIMAP_OPENED")
		assert.are.same({
			{ name = "Razor Hill, Durotar", known = true, current = true, slot = 1 },
			{ name = "Ratchet, The Barrens", known = false, current = false, slot = 2 },
		}, ctx.noted[1])
		local fp = directive(ns, "fp")
		assert.is_true(fp.isSatisfied(parse(ns, ".fp 1411,Razor Hill"), ctx))
		assert.is_false(fp.isSatisfied(parse(ns, ".fp 1413,Ratchet"), ctx))
		assert.are.same({}, travelErrors(mock))
	end)

	it("reads the map-shaped taxi API as well", function()
		local ns, mock, ctx = load()
		ctx:MoveTo(1413, 50, 50)
		G.Enum = { FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 } }
		G.C_TaxiMap = {
			GetAllTaxiNodes = function()
				return {
					{ nodeID = 25, name = "Crossroads, The Barrens", state = 0 },
					{ nodeID = 77, name = "Camp Taurajo, The Barrens", state = 2 },
				}
			end,
		}
		mock.fire("TAXIMAP_OPENED")
		local fp = directive(ns, "fp")
		assert.is_true(fp.isSatisfied(parse(ns, ".fp 1413,Crossroads"), ctx))
		assert.is_false(fp.isSatisfied(parse(ns, ".fp 1413,Camp Taurajo"), ctx))
		assert.are.equal(25, ctx.noted[1][1].nodeID)
	end)

	it("pins the flight master: learned position, then the data pack, then the client", function()
		local pack = {
			travel = {
				flightMasters = { [111] = { node = "Ratchet, The Barrens", p = { 1413, 63.5, 37.5 }, side = "both" } },
			},
		}
		local ns, _, ctx = load(pack)
		local fp, args = directive(ns, "fp"), parse(ns, ".fp 1413,Ratchet")
		local target = fp.targets(args, ctx)[1]
		assert.are.same({ 1413, 63.5, 37.5, "taxi", 111 }, { target.map, target.x, target.y, target.kind, target.npc })
		ns.db.learned.taxi["Ratchet, The Barrens"] = { map = 1413, x = 63, y = 37, npc = 111 }
		target = fp.targets(args, ctx)[1]
		assert.are.same({ 1413, 63, 37 }, { target.map, target.x, target.y })
		assert.are.equal("Ratchet flight master", target.label)

		ns, _, ctx = load()
		G.C_TaxiMap = {
			GetTaxiNodesForMap = function(mapID)
				if mapID == 1413 then
					return { { nodeID = 80, name = "Ratchet, The Barrens", position = { x = 0.62, y = 0.38 } } }
				end
				return {}
			end,
		}
		target = directive(ns, "fp").targets(args, ctx)[1]
		assert.are.same({ 1413, 62, 38 }, { target.map, target.x, target.y })
		assert.are.same({}, directive(ns, "fp").targets(parse(ns, ".fp 1413,Nowhere"), ctx))
	end)
end)

describe(".fly", function()
	-- Flight masters at Razor Hill (Durotar 50,50) and Orgrimmar (50,50); an enemy one right next to Razor Hill's.
	local PACK = {
		travel = {
			flightMasters = {
				[301] = { node = "Razor Hill, Durotar", p = { 1411, 50, 50 }, side = "Horde" },
				[302] = { node = "Orgrimmar, Durotar", p = { 1454, 50, 50 }, side = "Horde" },
				[303] = { node = "Enemy Camp, Durotar", p = { 1411, 50.5, 50 }, side = "Alliance" },
			},
		},
	}

	it("goes waiting -> boarded -> arrived and announces each change", function()
		local ns, mock, ctx = load(PACK)
		local step = mocks.step(ns, "spec:fly", { ".fly Orgrimmar" })
		local _, seen = route(ns, { step })
		ctx:MoveTo(1411, 50.6, 50)
		changed(ns)
		assert.are.equal("waiting", ns.Travel:TransportState("spec:fly"))
		local fly, args = directive(ns, "fly"), step.directives[1].args
		local state = ns.Progress:State("spec:fly")[1]
		local target = fly.targets(args, ctx, state)[1]
		assert.are.same({ 1411, 50, 50, "taxi", 301 }, { target.map, target.x, target.y, target.kind, target.npc })

		ctx.taxi = true
		ctx:Advance(5)
		changed(ns, "taxi")
		assert.are.equal("boarded", ns.Travel:TransportState("spec:fly"))
		target = fly.targets(args, ctx, state)[1]
		assert.are.same({ 1454, 50, 50, 302 }, { target.map, target.x, target.y, target.npc })
		assert.are.equal("Flying to Orgrimmar...", ns.Travel:TransitText("spec:fly"))

		ctx:Advance(60)
		ctx.taxi = false
		ctx:MoveTo(1454, 51, 50)
		changed(ns, "taxi")
		assert.is_true(fly.isSatisfied(args, ctx, state))
		assert.are.same({ "spec:fly=boarded", "spec:fly=arrived" }, seen)
		assert.is_nil(ns.Travel:TransitText("spec:fly"))
		assert.are.same({}, travelErrors(mock))
	end)

	it("goes back to waiting when the flight lands somewhere else", function()
		local ns, _, ctx = load(PACK)
		local fly, args, state = directive(ns, "fly"), parse(ns, ".fly Orgrimmar"), {}
		ctx:MoveTo(1411, 50, 50)
		ctx.taxi = true
		fly.isSatisfied(args, ctx, state)
		assert.are.equal("boarded", state.phase)
		ctx:Advance(60)
		ctx.taxi = false
		ctx:MoveTo(1413, 50, 50)
		assert.is_false(fly.isSatisfied(args, ctx, state))
		assert.are.equal("waiting", state.phase)
	end)

	it("counts any landing when the node's position is unknown", function()
		local ns, _, ctx = load()
		local fly, args, state = directive(ns, "fly"), parse(ns, ".fly Somewhere Far"), {}
		ctx:MoveTo(1411, 50, 50)
		assert.is_false(fly.isSatisfied(args, ctx, state))
		ctx.taxi = true
		assert.is_false(fly.isSatisfied(args, ctx, state))
		ctx:Advance(30)
		ctx.taxi = false
		ctx:MoveTo(1413, 20, 20)
		assert.is_true(fly.isSatisfied(args, ctx, state))
	end)

	it("does not let the previous step's flight complete a flight to an unknown node", function()
		local ns, _, ctx = load()
		local fly = directive(ns, "fly")
		local first, second = parse(ns, ".fly Somewhere Far"), parse(ns, ".fly Even Farther")
		local firstState = {}
		ctx:MoveTo(1411, 50, 50)
		ctx.taxi = true
		fly.isSatisfied(first, ctx, firstState)
		ctx:Advance(60)
		ctx.taxi = false
		ctx:MoveTo(1413, 20, 20)
		assert.is_true(fly.isSatisfied(first, ctx, firstState))
		local secondState = {}
		ctx:Advance(5)
		assert.is_false(fly.isSatisfied(second, ctx, secondState))
		ctx.taxi = true
		fly.isSatisfied(second, ctx, secondState)
		ctx:Advance(60)
		ctx.taxi = false
		ctx:MoveTo(1413, 80, 80)
		assert.is_true(fly.isSatisfied(second, ctx, secondState))
	end)

	it("counts a flight that ended just before the step began", function()
		local ns, _, ctx = load(PACK)
		local fly, args = directive(ns, "fly"), parse(ns, ".fly Orgrimmar")
		ctx:MoveTo(1411, 50, 50)
		ctx.taxi = true
		ns.Travel:Sample(ctx)
		ctx:Advance(60)
		ctx.taxi = false
		ctx:MoveTo(1454, 50, 50)
		ctx:Advance(30)
		assert.is_true(fly.isSatisfied(args, ctx, {}))
		ctx:Advance(ns.Travel.GRACE)
		assert.is_false(fly.isSatisfied(args, ctx, {}))
	end)

	it("pins only flight masters the player's faction can use", function()
		local ns, _, ctx = load()
		G.Enum = { FlightPathFaction = { Neutral = 0, Horde = 1, Alliance = 2 } }
		G.C_TaxiMap = {
			GetTaxiNodesForMap = function(mapID)
				if mapID == 1411 then
					return {
						{ nodeID = 1, name = "Near Enemy, Durotar", position = { x = 0.5, y = 0.5 }, faction = 2 },
						{ nodeID = 2, name = "Far Friend, Durotar", position = { x = 0.6, y = 0.5 }, faction = 1 },
						{ nodeID = 3, name = "Off The Map, Somewhere", position = { x = 1.4, y = 0.5 }, faction = 0 },
					}
				end
				return {}
			end,
		}
		ctx:MoveTo(1411, 50.1, 50)
		local node = ns.Travel:NearestTaxiNode(ctx)
		assert.are.equal("Far Friend, Durotar", node.name)
	end)
end)

describe(".boat and .zeppelin", function()
	-- A dock in the Barrens (90,50) on one continent and one in Stranglethorn Vale (50,50) on the other.
	local CROSSING = ".boat 1413,90,50 > 1434,50,50"
	-- The same continent: a dock in the Barrens (90,50) and one in Durotar (10,50), about 1280 yd apart.
	local COASTAL = ".boat 1413,90,50 > 1411,10,50"

	it("boards on a loading screen after the dock and arrives in the destination's zone", function()
		local ns, mock, ctx = load()
		local step = mocks.step(ns, "spec:boat", { CROSSING })
		local _, seen = route(ns, { step })
		local boat, args = directive(ns, "boat"), step.directives[1].args
		local state = ns.Progress:State("spec:boat")[1]

		ctx:MoveTo(1413, 85, 50) -- 200 yd from the dock
		changed(ns)
		assert.are.equal("waiting", ns.Travel:TransportState("spec:boat"))
		local target = boat.targets(args, ctx, state)[1]
		assert.are.same({ 1413, 90, 50, "dock" }, { target.map, target.x, target.y, target.kind })
		assert.are.equal("Board the boat here", target.label)
		assert.are.equal("Take the boat to Stranglethorn Vale", boat.describe(args, ctx, state))

		ctx:MoveTo(1413, 90.5, 50) -- on the pier
		changed(ns)
		ctx:Advance(60)
		mock.fire("PLAYER_ENTERING_WORLD", false, false) -- the loading screen in mid-crossing
		assert.are.equal("waiting", ns.Travel:TransportState("spec:boat")) -- the position is still the old one
		ctx:Advance(1)
		ctx:MoveTo(1415, 40, 70) -- at sea, on the other continent
		changed(ns)
		assert.are.equal("boarded", ns.Travel:TransportState("spec:boat"))
		target = boat.targets(args, ctx, state)[1]
		assert.are.same({ 1434, 50, 50, "The boat arrives here" }, { target.map, target.x, target.y, target.label })
		assert.are.equal("Sailing to Stranglethorn Vale...", ns.Travel:TransitText("spec:boat"))

		ctx:Advance(30)
		ctx:MoveTo(1434, 50.5, 50.5)
		changed(ns)
		assert.is_true(boat.isSatisfied(args, ctx, state))
		assert.are.same({ "spec:boat=boarded", "spec:boat=arrived" }, seen)
		assert.are.same({}, travelErrors(mock))
	end)

	it("boards when the position goes away on board and arrives near the arrival dock", function()
		local ns, _, ctx = load()
		local boat, args, state = directive(ns, "boat"), parse(ns, COASTAL), {}
		ctx:MoveTo(1413, 90, 50.2)
		boat.isSatisfied(args, ctx, state)
		ctx:Advance(10)
		ctx:Lose()
		assert.is_false(boat.isSatisfied(args, ctx, state))
		assert.are.equal("boarded", state.phase)
		ctx:Advance(60)
		ctx:MoveTo(1411, 10, 50.5)
		assert.is_true(boat.isSatisfied(args, ctx, state))
	end)

	it("boards when UnitPosition goes away, over open sea, or on another instance", function()
		local ns, _, ctx = load()
		local boat, args = directive(ns, "boat"), parse(ns, COASTAL)
		local function boardedAfter(move)
			local state = {}
			ctx:MoveTo(1413, 90, 50)
			boat.isSatisfied(args, ctx, state)
			ctx:Advance(20)
			move()
			boat.isSatisfied(args, ctx, state)
			return state.phase
		end
		assert.are.equal(
			"boarded",
			boardedAfter(function()
				ctx:MoveTo(1413, 80, 50)
				ctx.pos.wx = nil
			end)
		)
		assert.are.equal(
			"boarded",
			boardedAfter(function()
				ctx:MoveTo(1414, 57, 52) -- the continent's map, not a zone
			end)
		)
		assert.are.equal(
			"boarded",
			boardedAfter(function()
				ctx:MoveTo(1413, 80, 50, { instance = 7 })
			end)
		)
	end)

	it("does not take a walk away from the dock for boarding", function()
		local ns, _, ctx = load()
		local boat, args, state = directive(ns, "boat"), parse(ns, COASTAL), {}
		ctx:MoveTo(1413, 90, 50)
		boat.isSatisfied(args, ctx, state)
		ctx:Advance(100)
		ctx:MoveTo(1413, 70, 50) -- 800 yd away, slowly
		assert.is_false(boat.isSatisfied(args, ctx, state))
		ctx:Advance(200) -- still within the boarding window
		ctx:MoveTo(1454, 50, 50) -- into a city: a zone-level map
		assert.is_false(boat.isSatisfied(args, ctx, state))
		assert.are.equal("waiting", state.phase)
	end)

	it("needs the player to have been elsewhere: no completion for starting in the destination", function()
		local ns, _, ctx = load()
		local boat, args, state = directive(ns, "boat"), parse(ns, CROSSING), {}
		ctx:MoveTo(1434, 50, 50)
		assert.is_false(boat.isSatisfied(args, ctx, state))
		ctx:Advance(60)
		ctx:MoveTo(1434, 10, 10) -- elsewhere in the same zone
		assert.is_false(boat.isSatisfied(args, ctx, state))
		assert.are.equal("waiting", state.phase)
	end)

	it("completes on arrival even when no boarding signal was seen", function()
		local ns, _, ctx = load()
		local boat, args, state = directive(ns, "boat"), parse(ns, COASTAL), {}
		ctx:MoveTo(1413, 90, 50)
		boat.isSatisfied(args, ctx, state)
		ctx:Advance(90)
		ctx:MoveTo(1411, 5, 50) -- 200 yd short of the arrival dock, but in its zone
		assert.is_true(boat.isSatisfied(args, ctx, state))
	end)

	it("uses only the arrival radius when the departure lies in the destination's zone", function()
		local ns, _, ctx = load()
		local boat, args, state = directive(ns, "boat"), parse(ns, ".boat 1413,10,10 > 1413,90,90"), {}
		ctx:MoveTo(1413, 10, 10)
		boat.isSatisfied(args, ctx, state)
		ctx:Advance(120)
		ctx:MoveTo(1413, 50, 50)
		assert.is_false(boat.isSatisfied(args, ctx, state))
		ctx:Advance(60)
		ctx:MoveTo(1413, 90, 89) -- 60 yd from the arrival dock
		assert.is_true(boat.isSatisfied(args, ctx, state))
	end)

	it("runs the same machine for zeppelins", function()
		local ns, _, ctx = load()
		local zeppelin = directive(ns, "zeppelin")
		local args, state = parse(ns, ".zeppelin 1411,10,10 > 1434,50,50"), {}
		ctx:MoveTo(1411, 10, 10)
		assert.are.equal("Board the zeppelin here", zeppelin.targets(args, ctx, state)[1].label)
		assert.are.equal("Take the zeppelin to Stranglethorn Vale", zeppelin.describe(args, ctx, state))
		ctx:Advance(40)
		ctx:MoveTo(1415, 30, 60)
		assert.is_false(zeppelin.isSatisfied(args, ctx, state))
		assert.are.equal("Riding the zeppelin to Stranglethorn Vale...", zeppelin.describe(args, ctx, state))
		ctx:Advance(40)
		ctx:MoveTo(1434, 50, 50)
		assert.is_true(zeppelin.isSatisfied(args, ctx, state))
	end)

	it("reports no transport state for other steps", function()
		local ns = load()
		local walk = mocks.step(ns, "spec:walk", { ".zone 1413" })
		route(ns, { walk })
		assert.is_nil(ns.Travel:TransportState("spec:walk"))
		assert.is_nil(ns.Travel:TransportState("spec:missing"))
		assert.is_nil(ns.Travel:TransitText("spec:walk"))
	end)
end)

describe(".hs", function()
	local PACK = {
		travel = {
			inns = {
				[201] = { p = { 1454, 54, 68 }, side = "both" },
				[202] = { p = { 1411, 51.5, 41.6 }, side = "Horde" },
				[203] = { p = { 1411, 51, 41 }, side = "Alliance" },
			},
		},
	}

	it("is satisfied when the bind location is the inn", function()
		local ns, _, ctx = load()
		local hs = directive(ns, "hs")
		assert.is_false(hs.isSatisfied({ name = "Razor Hill" }, ctx))
		ctx.bind = "Razor Hill"
		assert.is_true(hs.isSatisfied({ name = "Razor Hill" }, ctx))
		assert.is_true(hs.isSatisfied({ name = " razor  hill " }, ctx))
		assert.is_false(hs.isSatisfied({ name = "Orgrimmar" }, ctx))
		ctx.bind = "The Crossroads"
		assert.is_true(hs.isSatisfied({ name = "Crossroads" }, ctx))
		assert.are.equal("Make Crossroads your home", hs.describe({ name = "Crossroads" }, ctx))
	end)

	it("pins a city's innkeeper, or the nearest one once in the inn's town", function()
		local ns, _, ctx = load(PACK)
		local hs = directive(ns, "hs")
		ctx:MoveTo(1413, 50, 50)
		local target = hs.targets({ name = "Orgrimmar" }, ctx)[1]
		assert.are.same({ 1454, 54, 68, "inn", 201 }, { target.map, target.x, target.y, target.kind, target.npc })
		assert.are.same({}, hs.targets({ name = "Razor Hill" }, ctx))
		G.GetSubZoneText = function()
			return "Razor Hill"
		end
		ctx:MoveTo(1411, 51, 41)
		target = hs.targets({ name = "Razor Hill" }, ctx)[1]
		assert.are.equal(202, target.npc) -- 203 is nearer but not for this faction
	end)
end)

describe(".home", function()
	local function hearthstone()
		G.C_Item = {
			GetItemSpell = function(item)
				if item == 6948 then
					return "Hearthstone", HEARTH_SPELL
				end
			end,
		}
	end

	it("needs a hearthstone cast, then the bind location", function()
		local ns, mock, ctx = load()
		hearthstone()
		local home, state = directive(ns, "home"), {}
		ctx.bind = "Razor Hill"
		ctx:MoveTo(1411, 51, 41)
		G.GetSubZoneText = function()
			return "Razor Hill"
		end
		assert.is_false(home.isSatisfied({}, ctx, state)) -- at the inn, but never hearthed
		mock.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-1", HEARTH_SPELL)
		mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 12345)
		assert.is_nil(ns.Travel.facts.hearthAt)
		mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", HEARTH_SPELL)
		assert.are.equal(ctx.t, ns.Travel.facts.hearthAt)
		assert.is_true(home.isSatisfied({}, ctx, state))
		assert.are.equal("Hearth to Razor Hill", home.describe({}, ctx))
		assert.are.same({}, travelErrors(mock))
	end)

	it("takes the teleport for arrival when the bind name matches no zone text", function()
		local ns, mock, ctx = load()
		hearthstone()
		local home, state = directive(ns, "home"), {}
		ctx.bind = "Somewhere Else"
		ctx:MoveTo(1413, 50, 50)
		home.isSatisfied({}, ctx, state)
		ctx:Advance(10)
		mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", HEARTH_SPELL)
		assert.is_false(home.isSatisfied({}, ctx, state))
		ctx:Advance(1)
		ctx:MoveTo(1411, 51, 41) -- about 4000 yd in a second
		assert.is_true(home.isSatisfied({}, ctx, state))
		ctx:MoveTo(1411, 70, 70)
		assert.is_true(home.isSatisfied({}, ctx, state)) -- stays done
	end)

	it("counts a cast shortly before the step began, not an old one", function()
		local ns, mock, ctx = load()
		hearthstone()
		local home = directive(ns, "home")
		ctx.bind = "Razor Hill"
		G.GetSubZoneText = function()
			return "Razor Hill"
		end
		ctx:MoveTo(1411, 51, 41)
		mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", HEARTH_SPELL)
		ctx:Advance(60)
		assert.is_true(home.isSatisfied({}, ctx, {}))
		ctx:Advance(ns.Travel.GRACE)
		assert.is_false(home.isSatisfied({}, ctx, {}))
	end)

	it("starts afresh from a state saved before the computer restarted (GetTime counts from its start)", function()
		local ns, mock, ctx = load()
		hearthstone()
		local home = directive(ns, "home")
		ctx.bind = "Razor Hill"
		G.GetSubZoneText = function()
			return "Razor Hill"
		end
		ctx:MoveTo(1411, 51, 41)
		local saved = { since = ctx.t + 100000 }
		assert.is_false(home.isSatisfied({}, ctx, saved))
		mock.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", HEARTH_SPELL)
		assert.is_true(home.isSatisfied({}, ctx, saved))
	end)

	it("recognizes the hearthstone by its spell's name when the item gives no spell ID", function()
		local ns = load()
		G.C_Item = {
			GetItemSpell = function()
				return "Hearthstone"
			end,
		}
		G.C_Spell = {
			GetSpellInfo = function(spellID)
				return spellID == HEARTH_SPELL and { name = "Hearthstone" } or { name = "Other" }
			end,
		}
		assert.is_true(ns.Travel.IsHearthSpell(HEARTH_SPELL))
		assert.is_false(ns.Travel.IsHearthSpell(12345))
		assert.is_false(ns.Travel.IsHearthSpell(nil))
	end)

	it("falls back to the item's own name without C_Item.GetItemSpell", function()
		local ns = load()
		G.C_Item = {
			GetItemInfo = function(item)
				if item == 6948 then
					return "Hearthstone", "|Hitem:6948|h"
				end
			end,
		}
		G.C_Spell = {
			GetSpellInfo = function(spellID)
				return spellID == HEARTH_SPELL and { name = "Hearthstone" } or { name = "Other" }
			end,
		}
		assert.is_true(ns.Travel.IsHearthSpell(HEARTH_SPELL))
		assert.is_false(ns.Travel.IsHearthSpell(12345))
	end)

	it("remembers the spell ID once the client gives it", function()
		local ns = load()
		local calls = 0
		G.C_Item = {
			GetItemSpell = function()
				calls = calls + 1
				return "Hearthstone", HEARTH_SPELL
			end,
		}
		assert.is_false(ns.Travel.IsHearthSpell(12345))
		assert.is_true(ns.Travel.IsHearthSpell(HEARTH_SPELL))
		assert.are.equal(1, calls)
	end)
end)

describe("position samples", function()
	it("record jumps: another instance, or far and fast; not slow travel or taxi rides", function()
		local ns, _, ctx = load()
		local travel = ns.Travel
		ctx:MoveTo(1413, 50, 50)
		travel:Sample(ctx)
		ctx:Advance(60)
		ctx:MoveTo(1413, 60, 50) -- 400 yd in a minute
		travel:Sample(ctx)
		assert.is_nil(travel.facts.jumpAt)
		ctx:Advance(1)
		ctx:MoveTo(1413, 70, 50) -- 400 yd in a second
		travel:Sample(ctx)
		assert.are.equal(ctx.t, travel.facts.jumpAt)
		ctx:Advance(1)
		ctx.taxi = true
		ctx:MoveTo(1413, 90, 50) -- 800 yd in a second, on a taxi
		travel:Sample(ctx)
		assert.are.equal(ctx.t - 1, travel.facts.jumpAt)
		assert.are.equal(ctx.t, travel.facts.taxiAt)
		ctx:Advance(1)
		ctx.taxi = false
		travel:Sample(ctx)
		assert.are.equal(ctx.t, travel.facts.landedAt)
		ctx:Advance(1)
		ctx:MoveTo(1434, 50, 50) -- another continent
		travel:Sample(ctx)
		assert.are.equal(ctx.t, travel.facts.jumpAt)
		ctx:Lose()
		travel:Sample(ctx)
		assert.are.equal(ctx.t, travel.facts.unavailableAt)
	end)

	it("record loading screens but not the login or a reload", function()
		local ns, mock, ctx = load()
		mock.fire("PLAYER_ENTERING_WORLD", true, false)
		mock.fire("PLAYER_ENTERING_WORLD", false, true)
		assert.is_nil(ns.Travel.facts.loadingAt)
		mock.fire("PLAYER_ENTERING_WORLD", false, false)
		assert.are.equal(ctx.t, ns.Travel.facts.loadingAt)
	end)
end)

describe("borders", function()
	it("seeds the PLAN's crossings with map IDs only and a reason", function()
		local ns = load()
		local borders = ns.Travel:Borders()
		local names = {}
		for index, border in ipairs(borders) do
			names[index] = border.name
			assert.is_nil(border.from[2], border.name)
			assert.is_nil(border.to[2], border.name)
			assert.is_string(border.todo, border.name)
			assert.are.equal("guide", border.src)
			assert.are.equal("both", border.side)
		end
		assert.are.same({
			"Durotar/The Barrens",
			"The Barrens/Stonetalon Mountains",
			"The Barrens/Ashenvale",
			"The Barrens/Thousand Needles",
			"The Barrens/Dustwallow Marsh",
		}, names)
		assert.are.same({ 1411 }, borders[1].from)
		assert.are.same({ 1413 }, borders[1].to)
		assert.are.same({}, ns.Travel.borderErrors)
	end)

	it("filters by zone, either way round", function()
		local ns = load()
		assert.are.equal(5, #ns.Travel:Borders(1413))
		assert.are.equal(1, #ns.Travel:Borders(1411))
		assert.are.equal("Durotar/The Barrens", ns.Travel:Borders(1413, 1411)[1].name)
		assert.are.equal(0, #ns.Travel:Borders(1440, 1442))
	end)

	it("keeps valid entries with their coordinates and rejects the rest", function()
		local ns = load()
		local kept = ns.Travel:RegisterBorders({
			{ name = "", from = { 1411 }, to = { 1413 } },
			{ name = "No map", from = { "1411" }, to = { 1413 } },
			{ name = "Known road", from = { 1411, 1, 2 }, to = { 1454, 99, 2 } },
		})
		assert.are.equal(1, kept)
		assert.are.equal(2, #ns.Travel.borderErrors)
		local road = ns.Travel:Borders(1454)[1]
		assert.are.same({ "Known road", { 1411, 1, 2 }, { 1454, 99, 2 } }, { road.name, road.from, road.to })
		assert.is_nil(road.todo)
	end)

	it("prefers the data pack's crossings for the same pair of zones", function()
		local ns = load({
			travel = {
				crossings = {
					{ from = { 1413, 99.5, 40 }, to = { 1411, 0.5, 40 }, name = "Southfury bridge", src = "learned" },
					{ from = { 1413, 10, 10 }, to = { 1442, 90, 90 }, src = "learned" },
					{ from = { 1454, 1, 1 }, to = { 1411, 2, 2 } },
					{ from = { 1413 }, to = { 1440 } }, -- no coordinates: ignored
				},
			},
		})
		local bridge = ns.Travel:Borders(1411, 1413)
		assert.are.equal(1, #bridge)
		assert.are.same(
			{ "Southfury bridge", { 1413, 99.5, 40 }, { 1411, 0.5, 40 }, "learned" },
			{ bridge[1].name, bridge[1].from, bridge[1].to, bridge[1].src }
		)
		assert.is_nil(bridge[1].todo)
		local stonetalon = ns.Travel:Borders(1442)[1]
		assert.are.same({ "The Barrens/Stonetalon Mountains", 10 }, { stonetalon.name, stonetalon.from[2] })
		assert.is_string(ns.Travel:Borders(1440)[1].todo)
		local extra = ns.Travel:Borders(1454)[1]
		assert.are.same({ "Orgrimmar/Durotar", "pack" }, { extra.name, extra.src })
		assert.are.equal(6, #ns.Travel:Borders())
	end)
end)
