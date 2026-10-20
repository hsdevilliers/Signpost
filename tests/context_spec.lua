local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local quest, header, objective = contextMock.quest, contextMock.header, contextMock.objective

local lastWorld

-- Loads the addon plus Engine/Context.lua on a scripted client and logs in. setup(world, mock) runs before any addon
-- file loads. `fired` collects every CONTEXT_CHANGED from then on; the initial refresh happens on the first frame.
local function start(setup)
	local world
	local ns, mock = addon.load({
		extra = { "Engine/Context.lua" },
		before = function(m)
			world = contextMock.install(m)
			if setup then
				setup(world, m)
			end
		end,
	})
	lastWorld = world
	local fired = {}
	ns.Events:RegisterMessage("CONTEXT_CHANGED", function(_, what)
		fired[#fired + 1] = what
	end)
	return ns, world, mock, fired
end

local function count(list, value)
	local n = 0
	for _, item in ipairs(list) do
		if item == value then
			n = n + 1
		end
	end
	return n
end

-- Lets every pending refresh and signal happen, then forgets the signals.
local function settle(world, fired)
	world.advance(1)
	for i = #fired, 1, -1 do
		fired[i] = nil
	end
end

local function near(expected, actual, tolerance)
	assert.is_number(actual)
	assert.is_true(math.abs(expected - actual) < (tolerance or 1e-6), string.format("%s ~= %s", expected, actual))
end

local function printed(mock, text)
	for _, line in ipairs(mock.printed) do
		if line:find(text, 1, true) then
			return true
		end
	end
	return false
end

describe("ns.Context", function()
	after_each(function()
		-- Health and power are secret values on Forever: Context must never read them.
		if lastWorld then
			assert.are.equal(0, lastWorld.calls.secret)
		end
		lastWorld = nil
		contextMock.uninstall()
	end)

	describe("loading", function()
		it("loads without errors and signals the state it found on the next frame", function()
			local ns, world, mock, fired = start(function(w)
				w.log = { quest(1) }
			end)
			assert.are.same({}, mock.errors)
			assert.are.same({}, ns.db.errors)
			assert.are.same({}, fired)
			world.advance(0)
			for _, what in ipairs({ "quests", "level", "zone", "position", "taxi", "bind" }) do
				assert.are.equal(1, count(fired, what), what)
			end
			-- nothing asked about yet, nothing learned: nothing to signal
			assert.are.equal(0, count(fired, "spells"))
			assert.are.equal(0, count(fired, "bags"))
			assert.are.equal(0, count(fired, "skills"))
			assert.are.same({}, mock.errors)
		end)

		it("lists events the client rejects and polls a kind left without any", function()
			local ns, world, mock, fired = start(function(w, m)
				m.unknownEvents.BAG_UPDATE_DELAYED = true
				m.unknownEvents.LEARNED_SPELL_IN_TAB = true -- absent on Forever
				m.unknownEvents.HEARTHSTONE_BOUND = true
				w.items[5] = 0
			end)
			assert.are.same({}, mock.errors)
			assert.are.same({}, ns.db.errors)
			local missing = {}
			for _, event in ipairs(ns.Context.missingEvents) do
				missing[event] = true
			end
			assert.are.same(
				{ BAG_UPDATE_DELAYED = true, LEARNED_SPELL_IN_TAB = true, HEARTHSTONE_BOUND = true },
				missing
			)
			settle(world, fired)
			assert.are.equal(0, ns.Context:ItemCount(5))
			world.items[5] = 2
			world.advance(2.5)
			assert.are.equal(1, count(fired, "bags"))
			assert.are.equal(2, ns.Context:ItemCount(5))
			-- the bind location is sampled anyway
			world.bind = "Other Inn"
			world.advance(0.5)
			assert.are.equal("Other Inn", ns.Context:BindLocation())
		end)
	end)

	describe("quest log", function()
		it("caches quests by questID with their objectives", function()
			local ns = start(function(w)
				w.log = {
					header("Zone"),
					quest(1, { objectives = { objective("Boar slain", 3, 10) } }),
					quest(2, { complete = true, objectives = { objective("Tusk", 5, 5, "item") } }),
				}
			end)
			local context = ns.Context
			assert.is_true(context:QuestInLog(1))
			assert.is_false(context:QuestInLog(99))
			assert.is_false(context:QuestInLog(nil))
			assert.are.same({
				{ text = "Boar slain: 3/10", type = "monster", finished = false, have = 3, need = 10 },
			}, context:Objectives(1))
			assert.is_nil(context:Objectives(99))
			assert.is_false(context:QuestReady(1))
			assert.is_true(context:QuestReady(2))
			assert.is_false(context:QuestReady(99))
			assert.are.equal("Quest 1", context:QuestLog()[1].title)
			assert.is_nil(context:QuestLog()[0])
		end)

		it("counts a quest as ready when every objective is done or the client says complete, unless failed", function()
			local ns = start(function(w)
				w.log = {
					quest(1, { objectives = { objective("A", 2, 2), objective("B", 1, 1) } }),
					quest(2, { complete = true }),
					quest(3),
					quest(4, { complete = true, failed = true }),
					quest(5, { objectives = { objective("A", 2, 2), objective("B", 0, 1) } }),
				}
			end)
			local context = ns.Context
			assert.is_true(context:QuestReady(1))
			assert.is_true(context:QuestReady(2))
			assert.is_false(context:QuestReady(3)) -- no objectives and not complete
			assert.is_false(context:QuestReady(4))
			assert.is_false(context:QuestReady(5))
			assert.are.same({}, context:Objectives(3))
		end)

		it("re-reads the log once per burst of quest events and signals only real changes", function()
			local ns, world, mock, fired = start(function(w)
				w.log = { quest(1, { objectives = { objective("Boar slain", 0, 10) } }) }
			end)
			settle(world, fired)
			local reads = 0
			local walk = G.C_QuestLog.GetNumQuestLogEntries
			G.C_QuestLog.GetNumQuestLogEntries = function(...)
				reads = reads + 1
				return walk(...)
			end
			world.log[1].objectives[1] = objective("Boar slain", 1, 10)
			mock.fire("QUEST_LOG_UPDATE")
			mock.fire("QUEST_WATCH_UPDATE", 1)
			mock.fire("UNIT_QUEST_LOG_CHANGED", "player")
			mock.fire("QUEST_LOG_UPDATE")
			world.advance(0)
			assert.are.equal(1, reads)
			assert.are.same({ "quests" }, fired)
			assert.are.equal(1, ns.Context:Objectives(1)[1].have)

			world.advance(1)
			mock.fire("QUEST_LOG_UPDATE")
			world.advance(1)
			assert.are.same({ "quests" }, fired)

			reads = 0
			mock.fire("UNIT_QUEST_LOG_CHANGED", "party1")
			world.advance(1)
			assert.are.equal(0, reads)

			world.log[#world.log + 1] = quest(7)
			mock.fire("QUEST_ACCEPTED", 7)
			assert.is_true(ns.Context:QuestInLog(7))
			world.advance(0)
			assert.are.same({ "quests", "quests" }, fired)
		end)

		it("asks per quest while a collapsed header may hide quests from the walk", function()
			local ns, world = start(function(w)
				w.hideCollapsed = true
				w.log = {
					header("First", true),
					quest(5, { objectives = { objective("Boar slain", 10, 10) } }),
					header("Second"),
					quest(6),
				}
			end)
			local context = ns.Context
			assert.is_nil(context:QuestLog()[5])
			assert.is_true(context:QuestInLog(5))
			assert.is_true(context:QuestReady(5))
			assert.are.equal(10, context:Objectives(5)[1].have)
			assert.is_true(context:QuestInLog(6))
			assert.is_false(context:QuestInLog(7))

			-- without a collapsed header the walk is complete and nothing is asked per quest
			local asked = 0
			local onQuest = G.C_QuestLog.IsOnQuest
			G.C_QuestLog.IsOnQuest = function(...)
				asked = asked + 1
				return onQuest(...)
			end
			world.log[1].collapsed = false
			ns.Context:Invalidate("quests")
			assert.is_true(context:QuestInLog(5))
			assert.is_false(context:QuestInLog(7))
			assert.are.equal(0, asked)
		end)
	end)

	describe("completed quests", function()
		it("loads GetAllCompletedQuestIDs and falls back to IsQuestFlaggedCompleted", function()
			local ns = start(function(w)
				w.completed = { 10, 11 }
				w.flagged[12] = true
			end)
			local context = ns.Context
			assert.is_true(context:QuestCompleted(10))
			assert.is_true(context:QuestCompleted(11))
			assert.is_true(context:QuestCompleted(12))
			assert.is_false(context:QuestCompleted(13))
			assert.is_false(context:QuestCompleted("10"))
		end)

		it("reads the list again at QUEST_LOG_UPDATE while it is still empty", function()
			local ns, world, mock = start(function(w)
				w.completed = { 10 }
				w.completedListEmpty = true
			end)
			local context = ns.Context
			world.advance(0)
			assert.are.equal(0, context.completedCount)
			assert.is_true(context:QuestCompleted(10)) -- asked per quest meanwhile

			world.completedListEmpty = false
			world.completed = { 10, 20 }
			local calls = world.calls.GetAllCompletedQuestIDs
			mock.fire("QUEST_LOG_UPDATE")
			world.advance(0.2)
			assert.is_true(world.calls.GetAllCompletedQuestIDs > calls)
			assert.are.equal(2, context.completedCount)
			assert.is_true(context:QuestCompleted(20))

			calls = world.calls.GetAllCompletedQuestIDs
			mock.fire("QUEST_LOG_UPDATE")
			world.advance(1)
			assert.are.equal(calls, world.calls.GetAllCompletedQuestIDs)
		end)

		it("counts a turn-in at once and keeps it when the client's list lags behind", function()
			local ns, world, mock, fired = start(function(w)
				w.log = { quest(1, { complete = true }) }
			end)
			local context = ns.Context
			settle(world, fired)
			mock.fire("QUEST_TURNED_IN", 1, 100, 0)
			assert.is_true(context:QuestCompleted(1))
			world.advance(0)
			assert.are.same({ "quests" }, fired)

			world.log = {}
			mock.fire("QUEST_REMOVED", 1)
			world.advance(1)
			assert.is_false(context:QuestInLog(1))
			assert.is_true(context:QuestCompleted(1))
			assert.are.same({ "quests", "quests" }, fired)
		end)
	end)

	describe("CONTEXT_CHANGED", function()
		it("fires at most once per 0.2 s per kind and always ends on the latest state", function()
			local ns, world, mock, fired = start(function(w)
				w.log = { quest(1, { objectives = { objective("Boar slain", 0, 10) } }) }
			end)
			settle(world, fired)
			local function kill(n)
				world.log[1].objectives[1] = objective("Boar slain", n, 10)
				mock.fire("QUEST_LOG_UPDATE")
			end
			kill(1)
			world.advance(0)
			assert.are.same({ "quests" }, fired)
			kill(2)
			world.advance(0.05)
			kill(3)
			world.advance(0.14) -- 0.19 s after the first signal
			assert.are.equal(1, #fired)
			world.advance(0.02) -- 0.21 s
			assert.are.same({ "quests", "quests" }, fired)
			assert.are.equal(3, ns.Context:Objectives(1)[1].have)
			world.advance(1)
			assert.are.equal(2, #fired)
		end)

		it("throttles each kind on its own", function()
			local ns, world, mock, fired = start(function(w)
				w.log = { quest(1, { objectives = { objective("Boar slain", 0, 10) } }) }
			end)
			settle(world, fired)
			assert.are.equal(0, ns.Context:ItemCount(5))
			world.log[1].objectives[1] = objective("Boar slain", 1, 10)
			mock.fire("QUEST_LOG_UPDATE")
			world.advance(0)
			world.items[5] = 2
			mock.fire("BAG_UPDATE_DELAYED")
			world.advance(0)
			assert.are.same({ "quests", "bags" }, fired)
		end)

		it("answers a query from fresh data and signals the change on a later frame", function()
			local ns, world, mock, fired = start(function(w)
				w.items[5] = 1
			end)
			settle(world, fired)
			assert.are.equal(1, ns.Context:ItemCount(5))
			world.items[5] = 3
			mock.fire("BAG_UPDATE_DELAYED")
			assert.are.equal(3, ns.Context:ItemCount(5))
			assert.are.same({}, fired)
			world.advance(0)
			assert.are.same({ "bags" }, fired)
		end)
	end)

	describe("spells, skills, bags and level", function()
		it("knows a spell from any of the client's spell APIs and signals learned ones", function()
			local ns, world, mock, fired = start(function(w)
				w.spells[200] = "book"
				w.spells[300] = "legacy"
			end)
			local context = ns.Context
			settle(world, fired)
			assert.is_false(context:SpellKnown(100))
			assert.is_true(context:SpellKnown(200))
			assert.is_true(context:SpellKnown(300))
			assert.is_false(context:SpellKnown(nil))

			world.spells[100] = "player"
			mock.fire("SPELLS_CHANGED")
			world.advance(0)
			assert.are.same({ "spells" }, fired)
			assert.is_true(context:SpellKnown(100))

			world.advance(1)
			mock.fire("SPELLS_CHANGED")
			world.advance(1)
			assert.are.equal(1, #fired)

			mock.fire("LEARNED_SPELL_IN_SKILL_LINE", 999, 1)
			world.advance(1)
			assert.are.same({ "spells", "spells" }, fired)
		end)

		it("reads skills from ns.Player.professions and signals rank changes", function()
			local ns, world, mock, fired = start()
			local context = ns.Context
			settle(world, fired)
			-- a stand-in for Core/Player.lua, which another track extends with professions
			ns.Player = { professions = { [111] = { key = "alpha", name = "Alpha", rank = 1, max = 75 } } }
			local rank, max = context:Skill(111)
			assert.are.equal(1, rank)
			assert.are.equal(75, max)
			assert.is_nil(context:Skill(222))

			ns.Events:Fire("PLAYER_PROFESSIONS_CHANGED", ns.Player.professions)
			world.advance(0)
			assert.are.same({ "skills" }, fired)

			ns.Player.professions[111].rank = 2
			mock.fire("SKILL_LINES_CHANGED")
			world.advance(1)
			assert.are.same({ "skills", "skills" }, fired)
			assert.are.equal(2, (context:Skill(111)))

			mock.fire("SKILL_LINES_CHANGED")
			world.advance(1)
			assert.are.equal(2, #fired)
		end)

		it("counts items in the bags and signals changes of the ones asked about", function()
			local ns, world, mock, fired = start(function(w)
				w.items[5] = 1
			end)
			local context = ns.Context
			settle(world, fired)
			assert.are.equal(1, context:ItemCount(5))
			assert.are.equal(0, context:ItemCount(6))
			assert.are.equal(0, context:ItemCount(nil))

			world.items[5] = 4
			mock.fire("BAG_UPDATE_DELAYED")
			world.advance(0)
			assert.are.same({ "bags" }, fired)
			assert.are.equal(4, context:ItemCount(5))

			world.advance(1)
			world.items[7] = 9 -- nobody asked about item 7
			mock.fire("BAG_UPDATE_DELAYED")
			world.advance(1)
			assert.are.equal(1, #fired)
		end)

		it("takes the level from PLAYER_LEVEL_UP even while UnitLevel lags", function()
			local ns, world, mock, fired = start()
			local context = ns.Context
			assert.are.equal(1, context:Level())
			settle(world, fired)
			mock.fire("PLAYER_LEVEL_UP", 2)
			assert.are.equal(2, context:Level())
			world.advance(0)
			assert.are.same({ "level" }, fired)

			world.level = 2
			mock.fire("PLAYER_ENTERING_WORLD", false, false)
			world.advance(1)
			assert.are.equal(2, context:Level())
			assert.are.equal(1, count(fired, "level"))
		end)
	end)

	describe("position", function()
		it("reports map percent from C_Map and world yards from HereBeDragons", function()
			local ns = start()
			local position = ns.Context:Position()
			assert.are.equal(1411, position.map)
			near(43.35, position.x)
			near(68.70, position.y)
			near(1000 - 5287.5 * 0.4335, position.wx)
			near(2000 - 3525 * 0.687, position.wy)
			assert.are.equal(1, position.instance)
			assert.is_false(position.taxi)
			assert.are.equal(1411, ns.Context:Map())
		end)

		it("samples every half second and signals moves, not standing still", function()
			local ns, world, _, fired = start()
			settle(world, fired)
			world.x = world.x + 1 -- 52.9 yards east
			world.advance(0.5)
			assert.are.same({ "position" }, fired)
			world.advance(2)
			assert.are.equal(1, #fired)
			world.x = world.x + 0.01 -- half a yard
			world.advance(1)
			assert.are.equal(1, #fired)

			world.map, world.x, world.y = 1413, 50, 50
			world.advance(0.5)
			assert.are.equal(1, count(fired, "zone"))
			assert.are.equal(2, count(fired, "position"))
			assert.are.equal(1413, ns.Context:Map())
		end)

		it("sees a zone change in the frame its event arrives", function()
			local ns, world, mock, fired = start()
			settle(world, fired)
			assert.are.equal(1411, ns.Context:Map())
			world.map, world.x, world.y = 1454, 50, 50
			mock.fire("ZONE_CHANGED_NEW_AREA")
			assert.are.equal(1454, ns.Context:Map())
			world.advance(0)
			assert.are.equal(1, count(fired, "zone"))
		end)

		it("is nil without a map or world position, and has no coordinates in an instance", function()
			local ns, world, mock = start(function(w)
				w.map = nil
			end)
			local context = ns.Context
			assert.is_nil(context:Position())
			assert.is_nil(context:Map())
			assert.is_nil(context:Distance(1411, 50, 50))
			assert.is_false(context:InMap(nil, 1411))
			world.advance(2)

			world.map, world.inInstance = 1411, true
			world.advance(0.5)
			local position = context:Position()
			assert.are.equal(1411, position.map)
			assert.is_nil(position.x)
			assert.is_nil(position.wx)
			assert.is_nil(context:Distance(1411, 50, 50))
			world.advance(2)
			assert.are.same({}, mock.errors)
			assert.are.same({}, ns.db.errors)
		end)

		it("measures yards to a point through HereBeDragons, on the same continent only", function()
			local ns = start()
			local context = ns.Context
			near(52.875, context:Distance(1411, 44.35, 68.70), 1e-3)
			near(0, context:Distance(1411, 43.35, 68.70), 1e-3)
			local position = context:Position()
			local dx, dy = (1500 - 1700 * 0.5) - position.wx, (2600 - 1100 * 0.5) - position.wy
			near(math.sqrt(dx * dx + dy * dy), context:Distance(1454, 50, 50), 1e-3)
			assert.is_nil(context:Distance(1420, 50, 50)) -- another continent
			assert.is_nil(context:Distance(9999, 50, 50)) -- a map HereBeDragons does not know
			assert.is_nil(context:Distance(1411, nil, 50))
		end)
	end)

	describe("map tree", function()
		it("walks parents through C_Map.GetMapInfo, cached; a city is not inside its zone", function()
			local ns, world = start()
			local context = ns.Context
			assert.is_true(context:InMap(1411, 1411))
			assert.is_true(context:InMap(1411, 1414))
			assert.is_true(context:InMap(1411, 947))
			assert.is_false(context:InMap(1454, 1411)) -- Orgrimmar is a sibling of Durotar
			assert.is_true(context:InMap(1454, 1414))
			assert.is_false(context:InMap(1420, 1414))
			assert.is_true(context:InMap(nil, 1414)) -- the player's map
			assert.is_false(context:InMap(nil, 1413))
			assert.is_false(context:InMap(9999, 1414))
			assert.is_false(context:InMap(1411, nil))
			for _ = 1, 3 do
				context:InMap(1454, 1411)
			end
			assert.are.equal(1, world.calls.GetMapInfo[1454])
			assert.are.equal(1, world.calls.GetMapInfo[1414])
			assert.are.equal(1414, context:Continent(1411))
			assert.are.equal(1414, context:Continent())
			assert.are.equal(1415, context:Continent(1420))
			assert.is_nil(context:Continent(947))
		end)

		it("falls back to the data pack's maps table for a map the client does not describe", function()
			local ns = start(function()
				G.Signpost_Data = {
					_meta = { schema = 1 },
					maps = { [2524] = { n = "Darkspear Islands", t = 6, parent = 1414 } },
				}
			end)
			assert.is_true(ns.Context:InMap(2524, 1414))
			assert.is_false(ns.Context:InMap(2524, 1411))
		end)
	end)

	describe("taxi and bind location", function()
		it("follows UnitOnTaxi through control events and the half-second sample", function()
			local ns, world, mock, fired = start()
			local context = ns.Context
			settle(world, fired)
			assert.is_false(context:OnTaxi())
			world.onTaxi = true
			mock.fire("PLAYER_CONTROL_LOST")
			assert.is_true(context:OnTaxi())
			assert.is_true(context:Position().taxi) -- same frame, same answer
			world.advance(0.5)
			assert.are.equal(1, count(fired, "taxi"))
			assert.is_true(context:Position().taxi)

			world.onTaxi = false -- landed, no event
			world.advance(0.5)
			assert.are.equal(2, count(fired, "taxi"))
			assert.is_false(context:OnTaxi())
		end)

		it("follows the bind location", function()
			local ns, world, mock, fired = start()
			local context = ns.Context
			assert.are.equal("Test Inn", context:BindLocation())
			settle(world, fired)
			world.bind = "Other Inn"
			world.advance(0.5)
			assert.are.same({ "bind" }, fired)
			assert.are.equal("Other Inn", context:BindLocation())
			world.bind = "Third Inn"
			mock.fire("HEARTHSTONE_BOUND")
			assert.are.equal("Third Inn", context:BindLocation())
		end)

		it("learns flight nodes from the classic flight map, by full or short name", function()
			local ns, world, mock, fired = start(function(w)
				w.classicTaxi = {
					{ name = "Ratchet, The Barrens", type = "CURRENT" },
					{ name = "Crossroads, The Barrens", type = "REACHABLE" },
					{ name = "Hilltop, The Barrens", type = "DISTANT" },
					{ name = "Far Away, Somewhere", type = "NONE" },
					{ name = "zzOLDTest Port, Nowhere", type = "REACHABLE" },
				}
			end)
			local context = ns.Context
			settle(world, fired)
			assert.is_nil(context:TaxiNodeKnown("Ratchet"))
			mock.fire("TAXIMAP_OPENED", 1)
			assert.is_true(context:TaxiNodeKnown("Ratchet"))
			assert.is_true(context:TaxiNodeKnown("ratchet, the barrens"))
			assert.is_true(context:TaxiNodeKnown("  Crossroads "))
			assert.is_true(context:TaxiNodeKnown("Hilltop"))
			assert.is_false(context:TaxiNodeKnown("Far Away"))
			assert.is_nil(context:TaxiNodeKnown("zzOLDTest Port"))
			assert.is_nil(context:TaxiNodeKnown("Nowhere Else"))
			assert.is_nil(context:TaxiNodeKnown(nil))
			world.advance(0)
			assert.are.same({ "taxi" }, fired)
			assert.is_true(ns.char.taxiNodes["Ratchet, The Barrens"].known)
			assert.is_nil(ns.char.taxiNodes["zzOLDTest Port, Nowhere"])

			-- known stays known
			world.classicTaxi = { { name = "Ratchet, The Barrens", type = "NONE" } }
			mock.fire("TAXIMAP_OPENED", 1)
			world.advance(1)
			assert.is_true(context:TaxiNodeKnown("Ratchet"))
			assert.are.equal(1, #fired)

			-- learned later
			world.classicTaxi = { { name = "Far Away, Somewhere", type = "REACHABLE" } }
			mock.fire("TAXIMAP_OPENED", 1)
			world.advance(1)
			assert.is_true(context:TaxiNodeKnown("Far Away"))
			assert.are.equal(2, #fired)

			-- kept per character across a reload, before any flight map opens
			local saved = SignpostCharDB
			local reloaded = start(function()
				G.SignpostCharDB = saved
			end)
			assert.is_true(reloaded.Context:TaxiNodeKnown("Ratchet"))
			assert.is_false(reloaded.Context:TaxiNodeKnown("Nowhere") == true)
		end)

		it("reads the C_TaxiMap shape when the classic list is empty", function()
			local ns, _, mock = start(function(w)
				w.taxiByMap[1414] = {
					{ nodeID = 1, name = "Alpha, Kalimdor", state = 1 },
					{ nodeID = 2, name = "Beta, Kalimdor", state = 2, isUndiscovered = true },
					{ nodeID = 3, name = "Gamma, Kalimdor", state = 2 },
					{ nodeID = 4, name = "Delta, Kalimdor", state = 0, isUndiscovered = false },
				}
			end)
			local context = ns.Context
			mock.fire("TAXIMAP_OPENED", 2)
			assert.is_true(context:TaxiNodeKnown("Alpha"))
			assert.is_false(context:TaxiNodeKnown("Beta"))
			assert.is_nil(context:TaxiNodeKnown("Gamma")) -- unreachable says nothing about known
			assert.is_true(context:TaxiNodeKnown("Delta"))
			assert.are.equal(4, ns.char.taxiNodes["Delta, Kalimdor"].id)
			local nodes = context:ReadTaxiMap()
			assert.are.equal(4, #nodes)
			assert.is_true(nodes[4].current)
		end)

		it("reads the flight map once more when it is empty at TAXIMAP_OPENED", function()
			local ns, world, mock = start()
			mock.fire("TAXIMAP_OPENED", 1)
			world.classicTaxi = { { name = "Ratchet, The Barrens", type = "CURRENT" } }
			assert.is_nil(ns.Context:TaxiNodeKnown("Ratchet"))
			world.advance(0.3)
			assert.is_true(ns.Context:TaxiNodeKnown("Ratchet"))
		end)

		it("stores the node id from either the id or the nodeID field", function()
			local ns, mock = addon.load({
				login = false,
				extra = { "Engine/Context.lua" },
				before = function(m)
					lastWorld = contextMock.install(m)
				end,
			})
			mock.fire("ADDON_LOADED", "Signpost")
			ns.Context:NoteTaxiNodes({
				{ name = "A, Zone", known = true, id = 7 },
				{ name = "B, Zone", known = true, nodeID = 9 },
			})
			assert.are.equal(7, ns.char.taxiNodes["A, Zone"].id)
			assert.are.equal(9, ns.char.taxiNodes["B, Zone"].id)
		end)

		it("keeps nodes noted before SavedVariables are ready", function()
			local ns, mock = addon.load({
				login = false,
				extra = { "Engine/Context.lua" },
				before = function(m)
					lastWorld = contextMock.install(m)
				end,
			})
			assert.is_true(ns.Context:NoteTaxiNodes({ { name = "Early, Zone", known = true }, "junk", {} }))
			mock.fire("ADDON_LOADED", "Signpost")
			assert.is_true(ns.char.taxiNodes["Early, Zone"].known)
			assert.is_true(ns.Context:TaxiNodeKnown("Early"))
			assert.is_false(ns.Context:NoteTaxiNodes({ { name = "Early, Zone", known = true } }))
			assert.is_false(ns.Context:NoteTaxiNodes(nil))
		end)
	end)

	describe("secret values", function()
		it("treats secret numbers as unknown instead of comparing them", function()
			local SECRET = 123456.5
			local ns, world, mock = start(function(w)
				G.issecretvalue = function(value)
					return value == SECRET
				end
				w.log = {
					quest(1, {
						objectives = {
							{
								text = "Hidden",
								type = "monster",
								finished = false,
								numFulfilled = SECRET,
								numRequired = 10,
							},
						},
					}),
				}
			end)
			local context = ns.Context
			assert.is_nil(context:Objectives(1)[1].have)
			assert.are.equal(10, context:Objectives(1)[1].need)
			G.UnitPosition = function()
				return SECRET, SECRET, 0, 1
			end
			world.advance(1)
			local position = context:Position()
			assert.are.equal(1411, position.map)
			assert.is_nil(position.wx)
			assert.is_nil(context:Distance(1411, 50, 50))
			assert.is_false(context:QuestCompleted(SECRET))
			assert.are.same({}, mock.errors)
			assert.are.same({}, ns.db.errors)
		end)
	end)

	describe("errors", function()
		it("records a refresh that fails and keeps answering from the old cache", function()
			local ns, world, mock = start(function(w)
				w.log = { quest(1) }
			end)
			local context = ns.Context
			assert.is_true(context:QuestInLog(1))
			-- Forever has secret tables (issecrettable); indexing one may raise.
			G.C_QuestLog.GetInfo = function()
				return setmetatable({}, {
					__index = function()
						error("attempt to index a secret table")
					end,
				})
			end
			mock.fire("QUEST_LOG_UPDATE")
			assert.is_true(context:QuestInLog(1))
			world.advance(1)
			assert.are.equal(1, #ns.db.errors)
			assert.truthy(ns.db.errors[1].msg:find("secret table", 1, true))
			assert.is_true(context:QuestInLog(1))
		end)
	end)

	describe("/signpost context", function()
		it("prints a summary and saves the cached state to SignpostDB.context", function()
			local ns, world, mock = start(function(w)
				w.log = { quest(1, { complete = true }) }
				w.completed = { 10 }
			end)
			world.advance(0)
			SlashCmdList.SIGNPOST("context")
			local saved = ns.db.context
			assert.are.equal(1, saved.level)
			assert.are.equal(1411, saved.position.map)
			assert.are.equal(947, saved.mapChain[3].id)
			assert.are.equal(1, saved.quests[1].id)
			assert.is_true(saved.quests[1].ready)
			assert.are.equal(1, saved.completed)
			assert.are.equal("Test Inn", saved.bind)
			assert.is_true(printed(mock, "context: level 1, map 1411"))
			assert.are.same({}, ns.db.errors)
		end)
	end)
end)
