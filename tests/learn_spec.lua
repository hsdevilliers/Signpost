local addon = dofile("tests/helpers/addon.lua")
local mocks = dofile("tests/mocks/learn.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local GORNEK = "Creature-0-1465-1-47-3143-00004F2B3C"
local ZURETH = "Creature-0-1465-1-47-3287-00004F2B3D"
local TRAINER = "Creature-0-1465-1-47-3154-00004F2B3E"
local VENDOR = "Creature-0-1465-1-47-3158-00004F2B3F"
local FLIGHT_MASTER = "Creature-0-1465-1-47-3310-00004F2B40"
local POSTER = "GameObject-0-1465-1-47-1617-00004F2B41"
local PLAYER = "Player-1465-0A1B2C3D"
local PET = "Pet-0-1465-1-47-3100-01004F2B42"

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
	return ns, mock, world
end

local function talkTo(world, guid, name)
	world.units.npc = { guid = guid, name = name }
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

local function count(tbl)
	local n = 0
	for _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

describe("Learn", function()
	after_each(function()
		mocks.uninstall(G)
	end)

	describe("SavedVariables", function()
		it("adds the learned tables of ENGINE.md to the defaults and keeps what is stored", function()
			local ns = load(function()
				G.SignpostDB = {
					dbVersion = 1,
					learned = { npcs = { [5] = { n = "Old", map = 1411, x = 1, y = 2, t = 1, c = 1 } } },
				}
			end)
			local learned = ns.db.learned
			for _, name in ipairs({ "npcs", "objects", "quests", "taxi", "crossings", "trainers", "vendors" }) do
				assert.is_table(learned[name], name)
			end
			assert.are.equal("Old", learned.npcs[5].n)
			assert.are.same({}, learned.quests)
		end)

		it("loads and handles every event without errors on a client that lacks the APIs", function()
			local ns, mock = load(function()
				mocks.uninstall(G)
			end)
			for _, event in ipairs({
				"GOSSIP_SHOW",
				"QUEST_GREETING",
				"QUEST_DETAIL",
				"QUEST_PROGRESS",
				"QUEST_COMPLETE",
				"TRAINER_SHOW",
				"TRAINER_UPDATE",
				"MERCHANT_SHOW",
				"MERCHANT_UPDATE",
				"TAXIMAP_OPENED",
				"ZONE_CHANGED_NEW_AREA",
			}) do
				mock.fire(event)
			end
			mock.fire("QUEST_ACCEPTED", 787)
			mock.fire("QUEST_TURNED_IN", 787, 100, 0)
			ns.Learn:Sample()
			assert.are.same({}, mock.errors)
			assert.are.same({}, ns.db.errors)
			assert.are.same(
				{ npcs = 0, objects = 0, quests = 0, taxi = 0, crossings = 0, trainers = 0, vendors = 0 },
				ns.Learn:Counts()
			)
		end)
	end)

	describe("NPCs and objects", function()
		it("records an NPC at gossip with its name and position, rounded to two decimals", function()
			local ns, mock, world = load()
			talkTo(world, GORNEK, "Gornek")
			world.x, world.y = 0.421349, 0.687051
			mock.fire("GOSSIP_SHOW")
			assert.are.same(
				{ n = "Gornek", map = 1411, x = 42.13, y = 68.71, t = 1790000000, c = 1 },
				ns.db.learned.npcs[3143]
			)
			assert.are.same(ns.db.learned.npcs[3143], ns.Learn:Get("npcs", 3143))
		end)

		it("records the NPCs of quest dialogs, trainers, vendors and flight masters", function()
			local ns, mock, world = load()
			for i, event in ipairs({
				"QUEST_GREETING",
				"QUEST_DETAIL",
				"QUEST_PROGRESS",
				"QUEST_COMPLETE",
				"TRAINER_SHOW",
				"MERCHANT_SHOW",
				"TAXIMAP_OPENED",
			}) do
				talkTo(world, string.format("Creature-0-1465-1-47-%d-00004F2B3C", 100 + i), "NPC " .. i)
				mock.fire(event)
			end
			assert.are.equal(7, count(ns.db.learned.npcs))
			assert.are.equal("NPC 7", ns.db.learned.npcs[107].n)
		end)

		it("averages repeat visits to the same spot, counts visits, and moves a record seen elsewhere", function()
			local ns, mock, world = load()
			talkTo(world, GORNEK, "Gornek")
			world.x = 0.421
			mock.fire("GOSSIP_SHOW")
			-- the same visit: neither counted nor averaged
			mock.clock = mock.clock + 30
			world.x = 0.428
			mock.fire("QUEST_DETAIL")
			local npc = ns.db.learned.npcs[3143]
			assert.are.same({ 42.1, 1, mock.clock }, { npc.x, npc.c, npc.t })
			-- later visits: weighted mean, two decimals
			mock.clock = mock.clock + 100
			world.x = 0.421
			mock.fire("GOSSIP_SHOW")
			mock.clock = mock.clock + 100
			world.x = 0.422
			mock.fire("GOSSIP_SHOW")
			assert.are.same({ 42.13, 3 }, { npc.x, npc.c })
			-- far away: the NPC moved
			mock.clock = mock.clock + 100
			world.x = 0.6
			mock.fire("GOSSIP_SHOW")
			assert.are.same({ 60, 1 }, { npc.x, npc.c })
		end)

		it("records game objects separately", function()
			local ns, mock, world = load()
			talkTo(world, POSTER, "Wanted Poster")
			mock.fire("QUEST_GREETING")
			assert.are.equal("Wanted Poster", ns.db.learned.objects[1617].n)
			assert.is_nil(ns.db.learned.npcs[1617])
		end)

		it("keeps no position where the client has none, and no name the client does not know yet", function()
			local ns, mock, world = load()
			talkTo(world, GORNEK, nil)
			world.x = nil
			mock.fire("GOSSIP_SHOW")
			assert.is_nil(ns.db.learned.npcs[3143])
			world.x = 0.5
			mock.fire("GOSSIP_SHOW")
			assert.is_nil(ns.db.learned.npcs[3143].n)
			assert.are.equal(50, ns.db.learned.npcs[3143].x)
		end)
	end)

	describe("privacy", function()
		it("never records players or pets, nor their names", function()
			local ns, mock, world = load()
			world.questID = 787
			world.services = { { id = 1494 } }
			world.merchant = { { id = 2516 } }
			world.taxiNodes = { { name = "Razor Hill", type = "CURRENT" } }
			for _, who in ipairs({ { PLAYER, "Someplayer" }, { PET, "Fluffy" } }) do
				talkTo(world, who[1], who[2])
				for _, event in ipairs({
					"GOSSIP_SHOW",
					"QUEST_DETAIL",
					"QUEST_COMPLETE",
					"TRAINER_SHOW",
					"MERCHANT_SHOW",
					"TAXIMAP_OPENED",
				}) do
					mock.fire(event)
				end
				mock.fire("QUEST_ACCEPTED", 787)
				mock.fire("QUEST_TURNED_IN", 787, 0, 0)
			end
			local learned = ns.db.learned
			assert.is_false(contains(learned, "Someplayer"))
			assert.is_false(contains(learned, "Fluffy"))
			assert.are.same({}, learned.npcs)
			assert.are.same({}, learned.quests)
			assert.are.same({}, learned.trainers)
			assert.are.same({}, learned.vendors)
			-- the flight node itself is still learned, without a flight master
			assert.is_nil(learned.taxi["Razor Hill"].npc)
		end)

		it("skips secret values instead of touching them", function()
			local ns, mock, world = load()
			talkTo(world, GORNEK, "Gornek")
			G.issecretvalue = function(value)
				return value == GORNEK
			end
			mock.fire("GOSSIP_SHOW")
			assert.are.same({}, ns.db.learned.npcs)
			G.issecretvalue = function(value)
				return value == "Gornek"
			end
			mock.fire("GOSSIP_SHOW")
			assert.is_nil(ns.db.learned.npcs[3143].n)
			assert.are.same({}, mock.errors)
		end)
	end)

	describe("quests", function()
		it("links a quest to the NPC that offered it and the one that took it back", function()
			local ns, mock, world = load()
			talkTo(world, GORNEK, "Gornek")
			world.questID = 4641
			mock.fire("QUEST_DETAIL")
			mock.fire("QUEST_ACCEPTED", 4641)
			talkTo(world, ZURETH, "Zureth")
			mock.fire("QUEST_PROGRESS")
			mock.fire("QUEST_COMPLETE")
			mock.fire("QUEST_TURNED_IN", 4641, 80, 0)
			assert.are.same(
				{ start = { npc = 3143 }, finish = { npc = 3287 }, t = 1790000000 },
				ns.db.learned.quests[4641]
			)
		end)

		it("keeps each quest's NPC through a chain whose next dialog opens before the turn-in event", function()
			local ns, mock, world = load()
			talkTo(world, GORNEK, "Gornek")
			world.questID = 788
			mock.fire("QUEST_COMPLETE")
			world.questID = 789
			mock.fire("QUEST_DETAIL")
			mock.fire("QUEST_TURNED_IN", 788, 0, 0)
			-- the older argument order (log index, quest ID)
			mock.fire("QUEST_ACCEPTED", 3, 789)
			assert.are.same({ npc = 3143 }, ns.db.learned.quests[788].finish)
			assert.are.same({ npc = 3143 }, ns.db.learned.quests[789].start)
		end)

		it("links quests offered by game objects", function()
			local ns, mock, world = load()
			talkTo(world, POSTER, "Wanted Poster")
			world.questID = 790
			mock.fire("QUEST_DETAIL")
			mock.fire("QUEST_ACCEPTED", 790)
			assert.are.same({ obj = 1617 }, ns.db.learned.quests[790].start)
		end)

		it("learns nothing about a quest accepted without a dialog, or long after it", function()
			local ns, mock, world = load()
			mock.fire("QUEST_ACCEPTED", 999)
			talkTo(world, GORNEK, "Gornek")
			world.questID = 791
			mock.fire("QUEST_DETAIL")
			mock.now = mock.now + 600
			mock.fire("QUEST_ACCEPTED", 791)
			assert.are.same({}, ns.db.learned.quests)
		end)
	end)

	describe("trainers", function()
		it("records the spell IDs of trainer services from their tooltip data", function()
			local ns, mock, world = load()
			talkTo(world, TRAINER, "Trainer")
			world.services = { { id = 1494 }, false, { id = 75 }, { id = 9999, type = 0 } }
			mock.fire("TRAINER_SHOW")
			assert.are.same({ spells = { 75, 1494 }, t = 1790000000 }, ns.db.learned.trainers[3154])
			assert.are.equal("Trainer", ns.db.learned.npcs[3154].n)
			-- a later list (other filters, after buying) adds to it
			world.services = { { id = 2973 } }
			mock.fire("TRAINER_UPDATE")
			assert.are.same({ 75, 1494, 2973 }, ns.db.learned.trainers[3154].spells)
		end)

		it("names a profession trainer's skill line from the client's own profession list", function()
			local ns, mock, world = load(function(_, w)
				G.Enum.Profession = { Alpha = 1, Beta = 2 }
				G.C_TradeSkillUI = {
					GetProfessionSkillLineID = function(enum)
						return enum * 100
					end,
					GetProfessionInfoBySkillLineID = function(skillLine)
						return { professionID = skillLine, professionName = skillLine == 200 and "Beta" or "Alpha" }
					end,
				}
				w.tradeskill = true
			end)
			talkTo(world, TRAINER, "Trainer")
			world.services = { { id = 2108, skill = "Beta" } }
			mock.fire("TRAINER_SHOW")
			assert.are.equal(200, ns.db.learned.trainers[3154].skill)
		end)

		it("records no trainer where the client gives no spell IDs (the NPC is still learned)", function()
			local ns, mock, world = load()
			talkTo(world, TRAINER, "Trainer")
			world.services = { { id = 1494 }, { id = 75 } }
			G.C_TooltipInfo = nil
			mock.fire("TRAINER_SHOW")
			assert.are.same({}, ns.db.learned.trainers)
			assert.is_table(ns.db.learned.npcs[3154])
		end)

		it("keeps at most LIMITS.spellsPerTrainer spells", function()
			local ns, mock, world = load()
			ns.Learn.LIMITS.spellsPerTrainer = 2
			talkTo(world, TRAINER, "Trainer")
			world.services = { { id = 30 }, { id = 20 }, { id = 10 } }
			mock.fire("TRAINER_SHOW")
			assert.are.same({ 20, 30 }, ns.db.learned.trainers[3154].spells)
		end)
	end)

	describe("vendors", function()
		it("records the item IDs a vendor sells, from the ID or else the item link", function()
			local ns, mock, world = load()
			talkTo(world, VENDOR, "Vendor")
			world.merchant = {
				{ id = 2516 },
				{ link = "|cffffffff|Hitem:159::::::::1:::::::|h[Refreshing Spring Water]|h|r" },
				{ id = 2516 },
				{},
			}
			mock.fire("MERCHANT_SHOW")
			assert.are.same({ items = { 159, 2516 }, t = 1790000000 }, ns.db.learned.vendors[3158])
			world.merchant = { { id = 4540 } }
			mock.fire("MERCHANT_UPDATE")
			assert.are.same({ 159, 2516, 4540 }, ns.db.learned.vendors[3158].items)
			-- IDs only: nothing else about the items is kept
			assert.is_false(contains(ns.db.learned, "Refreshing Spring Water"))
		end)

		it("keeps at most LIMITS.itemsPerVendor items", function()
			local ns, mock, world = load()
			ns.Learn.LIMITS.itemsPerVendor = 1
			talkTo(world, VENDOR, "Vendor")
			world.merchant = { { id = 2516 }, { id = 159 } }
			mock.fire("MERCHANT_SHOW")
			assert.are.same({ 2516 }, ns.db.learned.vendors[3158].items)
		end)
	end)

	describe("flight masters", function()
		it("records the node the taxi map opened at, with its flight master and position", function()
			local ns, mock, world = load()
			talkTo(world, FLIGHT_MASTER, "Flight Master")
			world.x, world.y = 0.5353, 0.4365
			world.taxiNodes = {
				{ name = "Orgrimmar", type = "REACHABLE" },
				{ name = "Razor Hill", type = "CURRENT" },
			}
			mock.fire("TAXIMAP_OPENED")
			assert.are.same(
				{ map = 1411, x = 53.53, y = 43.65, npc = 3310, t = 1790000000, c = 1 },
				ns.db.learned.taxi["Razor Hill"]
			)
			assert.is_nil(ns.db.learned.taxi.Orgrimmar)
			assert.are.equal("Flight Master", ns.db.learned.npcs[3310].n)
		end)

		it("takes node ID and faction from the flight map API when it marks the current node", function()
			local ns, mock, world = load()
			talkTo(world, FLIGHT_MASTER, "Flight Master")
			world.flightNodes = {
				{ name = "Orgrimmar", nodeID = 23, faction = 1, state = 1 },
				{ name = "Razor Hill", nodeID = 25, faction = 1, state = 0 },
			}
			mock.fire("TAXIMAP_OPENED")
			local node = ns.db.learned.taxi["Razor Hill"]
			assert.are.same({ 25, 1, 3310 }, { node.id, node.faction, node.npc })
		end)
	end)

	describe("zone crossings", function()
		-- A position sample on Durotar's west edge, then a second later 7 yards on in the Barrens; `arrive` changes
		-- the world just before ZONE_CHANGED_NEW_AREA.
		local function crossToBarrens(ns, mock, world, arrive)
			world.map, world.x, world.y, world.wx, world.wy = 1411, 0.0123, 0.4, 1000, 2000
			ns.Learn:Sample()
			mock.now = mock.now + 1
			world.map, world.x, world.y, world.wx, world.wy = 1413, 0.9876, 0.4, 1007, 2000
			if arrive then
				arrive(world, mock)
			end
			mock.fire("ZONE_CHANGED_NEW_AREA")
		end

		it("records the last position in the old zone and the first in the new one", function()
			local ns, mock, world = load()
			crossToBarrens(ns, mock, world)
			assert.are.same({
				{
					from = { map = 1411, x = 1.23, y = 40 },
					to = { map = 1413, x = 98.76, y = 40 },
					t = 1790000000,
					c = 1,
				},
			}, ns.db.learned.crossings)
		end)

		it("counts and refines a crossing walked again at the same spot", function()
			local ns, mock, world = load()
			crossToBarrens(ns, mock, world)
			mock.clock = mock.clock + 500
			crossToBarrens(ns, mock, world, function(w)
				w.x = 0.988
			end)
			local crossings = ns.db.learned.crossings
			assert.are.equal(1, #crossings)
			assert.are.same({ 2, mock.clock, 98.78 }, { crossings[1].c, crossings[1].t, crossings[1].to.x })
		end)

		it("ignores teleports, flights, transports, stale samples, instances and continent maps", function()
			local cases = {
				["a teleport"] = function(world)
					world.wx = 1600
				end,
				["a stale sample"] = function(_, mock)
					mock.now = mock.now + 7
				end,
				["a taxi"] = function(world)
					world.taxi = true
				end,
				-- 14 yards in a second is a possible ride, but not while standing still
				["a boat"] = function(world)
					world.speed, world.wx = 0, 1014
				end,
				["another world"] = function(world)
					world.instance = 0
				end,
				["an instance"] = function(world)
					world.instanceType = "party"
				end,
				["a continent map"] = function(world)
					world.map = 1414
					world.maps[1414] = { mapID = 1414, mapType = 2 }
				end,
			}
			for name, arrive in pairs(cases) do
				local ns, mock, world = load()
				crossToBarrens(ns, mock, world, arrive)
				assert.are.same({}, ns.db.learned.crossings, name)
				mocks.uninstall(G)
			end
		end)

		it("uses the sample from before the map changed when a tick already saw the new zone", function()
			local ns, mock, world = load()
			world.map, world.x, world.wx = 1411, 0.0123, 1000
			ns.Learn:Sample()
			mock.now = mock.now + 0.5
			world.map, world.x, world.wx = 1413, 0.9876, 1004
			ns.Learn:Sample()
			mock.now = mock.now + 0.2
			world.wx = 1005
			mock.fire("ZONE_CHANGED_NEW_AREA")
			assert.are.equal(1, #ns.db.learned.crossings)
			assert.are.same({ map = 1411, x = 1.23, y = 50 }, ns.db.learned.crossings[1].from)
		end)

		it("ignores zone changes across a loading screen", function()
			local ns, mock, world = load()
			world.map, world.x, world.wx = 1411, 0.0123, 1000
			ns.Learn:Sample()
			mock.fire("LOADING_SCREEN_ENABLED")
			ns.Learn:Sample()
			world.map, world.x, world.wx = 1413, 0.9876, 1003
			mock.fire("ZONE_CHANGED_NEW_AREA")
			mock.fire("LOADING_SCREEN_DISABLED")
			mock.fire("PLAYER_ENTERING_WORLD")
			mock.fire("ZONE_CHANGED_NEW_AREA")
			assert.are.same({}, ns.db.learned.crossings)
		end)

		it("samples the position once a second from login", function()
			local ns, _, world = load()
			assert.is_table(ns.Learn.ticker)
			world.map, world.x = 1413, 0.25
			ns.Learn.ticker.fn()
			assert.are.same({ 1413, 25 }, { ns.Learn.lastSample.map, ns.Learn.lastSample.x })
		end)
	end)

	describe("limits", function()
		it("drops the record seen longest ago when a capped table is full", function()
			local ns, mock, world = load()
			ns.Learn.LIMITS.npcs = 2
			for i, id in ipairs({ 101, 102, 103 }) do
				mock.clock = 1790000000 + i
				talkTo(world, string.format("Creature-0-1465-1-47-%d-00004F2B3C", id), "NPC")
				mock.fire("GOSSIP_SHOW")
				if id == 102 then
					-- seeing 101 again makes 102 the oldest
					mock.clock = mock.clock + 100
					talkTo(world, "Creature-0-1465-1-47-101-00004F2B3C", "NPC")
					mock.fire("GOSSIP_SHOW")
				end
			end
			local npcs = ns.db.learned.npcs
			assert.are.equal(2, count(npcs))
			assert.is_table(npcs[101])
			assert.is_nil(npcs[102])
			assert.is_table(npcs[103])
			assert.are.equal(2, ns.Learn:Count("npcs"))
		end)

		it("caps the crossings list", function()
			local ns, mock = load()
			ns.Learn.LIMITS.crossings = 2
			for i = 1, 3 do
				mock.clock = 1790000000 + i
				ns.Learn:AddCrossing({ map = 1, x = 10 * i, y = 10 }, { map = 2, x = 10 * i, y = 10 })
			end
			local crossings = ns.db.learned.crossings
			assert.are.same({ 20, 30 }, { crossings[1].from.x, crossings[2].from.x })
		end)
	end)

	it("prints what it has learned", function()
		local ns, mock, world = load()
		talkTo(world, GORNEK, "Gornek")
		mock.fire("GOSSIP_SHOW")
		SlashCmdList.SIGNPOST("learned")
		local last = mock.printed[#mock.printed]
		assert.truthy(last:find("learned: 1 NPCs, 0 objects, 0 quests", 1, true))
		assert.are.equal(1, ns.Learn:Count("npcs"))
	end)
end)
