-- Wave 1 integration: the real modules together (Core/Player, Registry, Parser, Directives, Conditions, Context,
-- Professions, Travel, Progress, Learn and the UI on the generic client mock), driven through the scripted client of
-- tests/mocks/context.lua. Each module's own spec stubs its neighbours; this one checks that their contracts meet:
-- a guide registered as Guides/ files do, parsed with its profession track at login, walked on quest log, profession,
-- level and position changes only.
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local quest, objective = contextMock.quest, contextMock.objective

-- Test IDs and coordinates (not real data): Durotar 1411 and The Barrens 1413 as in the context mock's map tree.
local QUEST = 4641
local VALLEY = [[
#chapter 1-6 Valley
step
  .goto 1411,43.35,68.70
  .accept 4641 >> Accept the first quest
step
  .complete 4641
  .sticky .level 2
step
  .turnin 4641
  .hub valley
step
  .path 1411,45,68.7 ; 1411,47,68.7
  .zone 1413
step
  .note The end of the test route.
]]

local TRACK = [[
#track skinning
step @hub valley
  .trainprof skinning
]]

local GUIDE = {
	id = "test-integration",
	name = "Integration",
	faction = "*",
	races = { "*" },
	classes = { "*" },
	levels = { 1, 10 },
	text = "#professions skinning\n#include valley\n",
}

local function profession()
	return { skillLine = 393, primary = true, gathering = true, ranks = { 75, 150, 225, 300 } }
end

local sessions = {}
-- Client functions some tests define (the context mock does not).
local OWN_GLOBALS = { "UnitGUID", "UnitName", "GetQuestID" }

after_each(function()
	for _, session in ipairs(sessions) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
	sessions = {}
	contextMock.uninstall()
	for _, name in ipairs(OWN_GLOBALS) do
		G[name] = nil
	end
end)

-- Loads every TOC file on the scripted client, registers the test guide, chapters, profession module and track the
-- way their files would at load, then logs in and lets the first frames pass. setup(world) runs before any file loads
-- (set a data pack there); content = { chapters = { [id] = text }, guide = def } replaces the valley route.
local function start(setup, content)
	content = content or {}
	local world
	local ns, mock = addon.load({
		login = false,
		before = function(m)
			world = contextMock.install(m)
			if setup then
				setup(world)
			end
		end,
	})
	for id, text in pairs(content.chapters or { valley = VALLEY }) do
		assert.is_true(ns.Chapters:Register(id, text))
	end
	assert.is_true(ns.Professions:Register("skinning", profession()))
	assert.is_true(ns.Professions:RegisterTrack("skinning", TRACK))
	assert.is_true(ns.Guides:Register(content.guide or GUIDE))
	local log = { steps = {}, sticky = {} }
	ns.Events:RegisterMessage("STEP_CHANGED", function(_, step, _, reason)
		log.steps[#log.steps + 1] = step.id .. ":" .. reason
	end)
	ns.Events:RegisterMessage("STICKY_CHANGED", function(_, list)
		log.sticky[#log.sticky + 1] = #list
	end)
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	world.advance(1)
	sessions[#sessions + 1] = { ns = ns, mock = mock }
	return ns, world, mock, log
end

local function current(ns)
	local step = ns.Progress:Current()
	return step and step.id
end

-- Lets the client "send" an event, then enough time pass for Context's next-frame refresh, its CONTEXT_CHANGED and
-- Progress's once-a-second evaluation.
local function event(world, mock, name, ...)
	if name then
		mock.fire(name, ...)
	end
	world.advance(1.1)
end

local function learnSkinning(rank)
	G.GetProfessions = function()
		return 41
	end
	G.GetProfessionInfo = function(index)
		if index == 41 then
			return "Skinning", 134366, rank, 75, 1, 0, 393
		end
	end
end

describe("Wave 1 integration", function()
	it("parses the guide with its profession track at login and starts at the first step", function()
		local ns, _, _, log = start()
		local guide = ns.Progress:Guide()
		assert.are.equal("test-integration", guide.id)
		assert.are.same({}, guide.errors)
		local ids = {}
		for i, step in ipairs(guide.steps) do
			ids[i] = step.id
		end
		assert.are.same({ "valley:1", "valley:2", "valley:3", "track:skinning:1", "valley:4", "valley:5" }, ids)
		assert.are.same({ "skinning" }, guide.plan.primary)
		assert.are.equal("Valley", guide.chapters[guide.steps[4].chapter].name)
		assert.are.equal("valley:1", current(ns))
		assert.are.same({ "valley:1:load" }, log.steps)
		-- without the data pack, the accept's pin is the step's .goto, named by the accept's ">>" text
		local entries = ns.Pins:Collect()
		assert.are.equal(1, #entries)
		assert.are.equal("accept", entries[1].target.kind)
		assert.are.same({ QUEST }, entries[1].target.quests)
		assert.are.same({ "Accept the first quest" }, ns.StepFrame.DescribeLines(ns.Progress:Current()))
	end)

	it("walks the route on quest log, profession, position and level changes only", function()
		local ns, world, mock = start()

		world.log = { quest(QUEST, { objectives = { objective("Boar slain", 0, 2) } }) }
		event(world, mock, "QUEST_ACCEPTED", QUEST)
		assert.are.equal("valley:2", current(ns))
		local lines = ns.StepFrame.DescribeLines(ns.Progress:Current())
		assert.are.equal('Complete "Quest 4641"', lines[1])
		assert.are.equal("- Boar slain: 0/2", lines[2])

		world.log[1].objectives = { objective("Boar slain", 2, 2) }
		event(world, mock, "QUEST_LOG_UPDATE")
		assert.are.equal("valley:3", current(ns))
		-- the sticky .level 2 of the step just passed stays beside the route
		local sticky = ns.Progress:Sticky()
		assert.are.equal(1, #sticky)
		assert.are.equal("valley:2", sticky[1].id)
		assert.are.same({ "Reach level 2" }, ns.StepFrame:StickyLines(ns.Progress:Current(), {}))

		world.log = {}
		world.completed = { QUEST }
		event(world, mock, "QUEST_TURNED_IN", QUEST, 0, 0)
		assert.are.equal("track:skinning:1", current(ns))

		learnSkinning(1)
		event(world, mock, "SKILL_LINES_CHANGED")
		assert.are.equal("valley:4", current(ns))

		-- the path: the first waypoint is the minimap's, then the second, then the zone
		local waypoints = ns.Pins:Targets(ns.Progress:Current())
		assert.are.equal(2, #waypoints)
		assert.is_true(waypoints[1].next)
		world.x = 45
		event(world, mock)
		waypoints = ns.Pins:Targets(ns.Progress:Current())
		assert.is_true(waypoints[1].reached)
		assert.is_true(waypoints[2].next)
		world.x = 47
		event(world, mock)
		assert.are.equal("valley:4", current(ns)) -- the waypoints are done, the zone is not
		world.map, world.x, world.y = 1413, 10, 10
		event(world, mock, "ZONE_CHANGED_NEW_AREA")
		assert.are.equal("valley:5", current(ns))

		world.level = 2
		event(world, mock, "PLAYER_LEVEL_UP", 2)
		assert.are.same({}, ns.Progress:Sticky())
		local record = ns.char.progress["test-integration"]
		assert.are.equal("valley:5", record.current)
		assert.is_true(record.done["track:skinning:1"])
	end)

	it("auto-skips what the character has done at login, and skipping a track's learn step declines it", function()
		local ns, world, mock, log = start(function(w)
			w.completed = { QUEST }
		end)
		assert.are.equal("track:skinning:1", current(ns))
		assert.are.same({ "track:skinning:1:load" }, log.steps)

		ns.Progress:Skip()
		assert.is_true(ns.char.declinedProfessions.skinning)
		assert.are.same({}, ns.Progress:Guide().plan.primary)
		assert.is_nil(ns.Progress:Guide().byId["track:skinning:1"])
		assert.are.equal("valley:4", current(ns))

		-- `<` right after the skip restores the profession and its step
		ns.Progress:Back()
		assert.is_nil(ns.char.declinedProfessions.skinning)
		assert.are.equal("track:skinning:1", current(ns))
		event(world, mock)
		assert.are.equal("track:skinning:1", current(ns))
	end)

	it("keeps progress across a reload and picks a newly selected guide", function()
		local ns, world, mock = start()
		world.log = { quest(QUEST, { objectives = { objective("Boar slain", 0, 2) } }) }
		event(world, mock, "QUEST_ACCEPTED", QUEST)
		assert.are.equal("valley:2", current(ns))

		local saved = ns.Util.CopyTable(ns.char)
		contextMock.uninstall()
		local reloaded = start(function(w)
			G.SignpostCharDB = saved
			w.log = { quest(QUEST, { objectives = { objective("Boar slain", 1, 2) } }) }
		end)
		assert.are.equal("valley:2", current(reloaded))

		-- a second guide for everyone, chosen by hand: the engine loads it at once
		reloaded.Guides:Register({
			id = "test-other",
			name = "Other",
			levels = { 1, 10 },
			text = "step\n  .note Another guide.\n",
		})
		assert.is_true(reloaded.Guides:Select("test-other"))
		assert.are.equal("test-other", reloaded.Progress:Guide().id)
		assert.are.equal("test-other:1", current(reloaded))
	end)

	-- A data pack in Data/Schema.lua's shape, as the questie layer writes it (test IDs and names, not real data).
	local CAMP = [[
#chapter 1-6 Camp
step
  .accept 9001
  .sticky .level 2
  .sticky .level 3
step
  .complete 9001
step
  .turnin 9001
]]
	local CAMP_GUIDE = { id = "test-camp", name = "Camp", levels = { 1, 10 }, text = "#include camp\n" }
	local function pack()
		return {
			_meta = { schema = 1, source = "test" },
			quests = {
				[9001] = {
					n = "Test Quest",
					s = { npc = { 9101 } },
					e = { npc = { 9101 } },
					o = { { k = "kill", id = 9102 } },
					src = "questie",
				},
			},
			npcs = {
				[9101] = { n = "Test Giver", side = "both", p = { { 1411, 30, 30 } } },
				[9102] = { n = "Test Boar", side = "none", p = { { 1411, 50, 50 }, { 1411, 52, 52 } } },
			},
		}
	end

	it("pins quest givers and objectives from the data pack and shows only the stickies still active", function()
		local ns, world, mock = start(function()
			G.Signpost_Data = pack()
		end, { chapters = { camp = CAMP }, guide = CAMP_GUIDE })
		assert.are.equal("camp:1", current(ns))
		local entries = ns.Pins:Collect()
		assert.are.equal(1, #entries)
		assert.are.same({ 1411, 30, 30, "accept", 9101 }, {
			entries[1].target.map,
			entries[1].target.x,
			entries[1].target.y,
			entries[1].target.kind,
			entries[1].target.npc,
		})
		-- the step's own sticky directives are "Ongoing:" lines, not body lines
		assert.are.same({ 'Accept "Test Quest" from Test Giver' }, ns.StepFrame.DescribeLines(ns.Progress:Current()))
		assert.are.same({ "Reach level 2", "Reach level 3" }, ns.StepFrame:StickyLines(ns.Progress:Current(), {}))

		world.log = { quest(9001, { objectives = { objective("Test Boar slain", 0, 3) } }) }
		event(world, mock, "QUEST_ACCEPTED", 9001)
		assert.are.equal("camp:2", current(ns))
		entries = ns.Pins:Collect()
		assert.are.equal(2, #entries)
		for _, entry in ipairs(entries) do
			assert.are.same({ "objective", 9102, "Test Boar slain: 0/3" }, {
				entry.target.kind,
				entry.target.npc,
				entry.target.label,
			})
		end
		assert.are.same({ "Reach level 2", "Reach level 3" }, ns.StepFrame:StickyLines(ns.Progress:Current(), {}))

		world.level = 2
		event(world, mock, "PLAYER_LEVEL_UP", 2)
		assert.are.same({ "Reach level 3" }, ns.StepFrame:StickyLines(ns.Progress:Current(), {}))
		assert.are.equal(1, #ns.Progress:Sticky())
	end)

	it("lets what Learn records stand in for the data pack's quest givers", function()
		local ns, world, mock = start(function()
			G.UnitGUID = function(unit)
				return unit == "npc" and "Creature-0-1465-1-47-9101-00004F2B3C" or nil
			end
			G.UnitName = function(unit)
				return unit == "npc" and "Test Giver" or nil
			end
			G.GetQuestID = function()
				return 9001
			end
		end, { chapters = { camp = CAMP }, guide = CAMP_GUIDE })
		mock.fire("QUEST_DETAIL")
		world.log = { quest(9001, { objectives = { objective("Test Boar slain", 0, 3) } }) }
		event(world, mock, "QUEST_ACCEPTED", 9001)
		assert.are.equal("camp:2", current(ns))
		local Pack = ns.Directives.Pack
		assert.are.same({ npcs = { 9101 }, objects = {} }, Pack.QuestStarters(9001))
		assert.are.same({ { map = 1411, x = 43.35, y = 68.7 } }, Pack.Positions("npc", 9101))
		assert.are.equal("Test Giver", Pack.Name("npc", 9101))
	end)
end)
