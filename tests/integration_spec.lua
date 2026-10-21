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
		assert.are.same({ "[ ] Accept the first quest" }, ns.StepFrame.DescribeLines(ns.Progress:Current()))
	end)

	it("gives a .level line its done mark and ticks it when the level is reached", function()
		local ns, world, mock = start(nil, {
			chapters = {
				valley = [[
#chapter 1-6 Valley
step
  .goto 1411,43.35,68.70
  .level 2
  .accept 4641 >> Accept the first quest
step
  .turnin 4641
  .hub valley
]],
			},
		})
		assert.are.same(
			{ "[ ] Reach level 2", "[ ] Accept the first quest" },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)
		world.level = 2
		event(world, mock, "PLAYER_LEVEL_UP", 2)
		assert.are.same(
			{ ns.UI.MARK.done .. " Reach level 2", "[ ] Accept the first quest" },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)
	end)

	it("walks the route on quest log, profession, position and level changes only", function()
		local ns, world, mock = start()

		world.log = { quest(QUEST, { objectives = { objective("Boar slain", 0, 2) } }) }
		event(world, mock, "QUEST_ACCEPTED", QUEST)
		assert.are.equal("valley:2", current(ns))
		-- one line for the quest with its done mark: the objectives' progress is the quest log's
		assert.are.same({ '[ ] Complete "Quest 4641"' }, ns.StepFrame.DescribeLines(ns.Progress:Current()))
		world.log[1].objectives = { objective("Boar slain", 1, 2) }
		event(world, mock, "QUEST_LOG_UPDATE")
		assert.are.equal("valley:2", current(ns))
		assert.are.same({ '[ ] Complete "Quest 4641"' }, ns.StepFrame.DescribeLines(ns.Progress:Current()))

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

	-- The engine announces the current step again when it parses the guide again (a profession plan change, a guide
	-- choice): the quest tracker must not take that for a new step.
	local function trackedStepWithAStray(setup)
		local ns, world, mock, log = start(setup)
		ns.db.settings.trackStepQuests = true -- chosen here, so this walk does not depend on the module's default
		world.log = {
			quest(QUEST, { objectives = { objective("Boar slain", 0, 2) } }),
			quest(5000, { objectives = { objective("Other", 0, 2) } }),
		}
		world.watch = {}
		event(world, mock, "QUEST_ACCEPTED", QUEST)
		assert.are.equal("valley:2", current(ns))
		assert.are.same({ QUEST }, world.watch)
		assert.are.equal(QUEST, world.superTracked)
		return ns, world, mock, log
	end

	it("keeps staying hands off when the engine parses the guide again for the same step", function()
		local ns, world, mock, log = trackedStepWithAStray()
		-- the player tracks another quest by hand, and the game tracks one that was just accepted
		table.insert(world.watch, 5000)
		world.log[#world.log + 1] = quest(5001, { objectives = { objective("New", 0, 1) } })
		table.insert(world.watch, 5001)
		event(world, mock, "QUEST_ACCEPTED", 5001)
		assert.is_true(ns.Tracking.state.manual)
		local announced = #log.steps
		ns.Progress:OnPlanChanged(nil) -- what PROFESSION_PLAN_CHANGED does
		world.advance(1.5)
		assert.is_true(#log.steps > announced) -- the same step was announced again
		assert.are.equal("valley:2", current(ns))
		assert.is_true(ns.Tracking.state.manual)
		assert.are.same({ QUEST, 5000, 5001 }, world.watch)
	end)

	it("sets the tracking again without moving the focus when the engine parses the guide again", function()
		local ns, world, _, log = trackedStepWithAStray()
		world.superTracked = nil
		table.insert(world.watch, 5000) -- something the module did not set, which nothing has noticed yet
		local announced = #log.steps
		ns.Progress:OnPlanChanged(nil)
		world.advance(1.5)
		assert.is_true(#log.steps > announced) -- the same step was announced again
		assert.are.equal("valley:2", current(ns))
		assert.are.same({ QUEST }, world.watch)
		assert.is_nil(world.superTracked)
		assert.is_false(ns.Tracking.state.manual)
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

	-- The saved place belongs to the guide's text (the fingerprint); the profession plan is not part of it, so a character
	-- that has since declined a profession, whose track steps leave the route, is not placed again.
	it("keeps the place across a reload whatever the profession plan has become", function()
		local ns, world, mock = start()
		world.log = { quest(QUEST, { objectives = { objective("Boar slain", 0, 2) } }) }
		event(world, mock, "QUEST_ACCEPTED", QUEST)
		assert.are.equal("valley:2", current(ns))
		assert.are.same({ "skinning" }, ns.Progress:Guide().plan.primary)
		local saved = ns.Util.CopyTable(ns.char)
		saved.declinedProfessions = { skinning = true } -- the next session has no skinning track
		contextMock.uninstall()
		local reloaded, _, mock2 = start(function(w)
			G.SignpostCharDB = saved
			w.log = { quest(QUEST, { objectives = { objective("Boar slain", 1, 2) } }) }
		end)
		assert.are.same({}, reloaded.Progress:Guide().plan.primary)
		assert.is_nil(reloaded.Progress:Guide().byId["track:skinning:1"])
		assert.are.equal("valley:2", current(reloaded))
		assert.are.equal("first", reloaded.char.progress["test-integration"].placed.reason) -- never placed again
		for _, line in ipairs(mock2.printed) do
			assert.is_nil(line:find("may not match", 1, true), line)
		end
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

	it("pins quest givers from the pack, nothing for a doing step, and only the stickies still active", function()
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
		assert.are.same(
			{ '[ ] Accept "Test Quest" from Test Giver' },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)
		assert.are.same({ "Reach level 2", "Reach level 3" }, ns.StepFrame:StickyLines(ns.Progress:Current(), {}))

		world.log = { quest(9001, { objectives = { objective("Test Boar slain", 0, 3) } }) }
		event(world, mock, "QUEST_ACCEPTED", 9001)
		assert.are.equal("camp:2", current(ns))
		-- a doing step: the quest log marks the objectives (the pack knows two spawns of the boar), the guide draws none
		assert.are.same({}, ns.Pins:Collect())
		assert.are.same({ '[ ] Complete "Test Quest"' }, ns.StepFrame.DescribeLines(ns.Progress:Current()))
		assert.are.same({ "Reach level 2", "Reach level 3" }, ns.StepFrame:StickyLines(ns.Progress:Current(), {}))

		world.level = 2
		event(world, mock, "PLAYER_LEVEL_UP", 2)
		assert.are.same({ "Reach level 3" }, ns.StepFrame:StickyLines(ns.Progress:Current(), {}))
		assert.are.equal(1, #ns.Progress:Sticky())
	end)

	-- Pick up two quests, do them in one step, hand them in: the step kinds as the user described them (2026-10-20).
	local HUNT = [[
#chapter 1-6 Hunt
step
  .goto 1411,30,30
  .accept 9001
  .accept 9002
step
  .goto 1411,50,50
  .complete 9001
  .complete 9002
step
  .goto 1411,30,30
  .turnin 9001
  .turnin 9002
]]
	local HUNT_GUIDE = { id = "test-hunt", name = "Hunt", levels = { 1, 10 }, text = "#include hunt\n" }

	it("walks a doing step of two quests: no markers, tracked, done only when both are complete", function()
		local ns, world, mock = start(function()
			local data = pack()
			data.quests[9002] = {
				n = "Other Quest",
				s = { npc = { 9101 } },
				e = { npc = { 9101 } },
				o = { { k = "kill", id = 9102 } },
				src = "questie",
			}
			G.Signpost_Data = data
		end, { chapters = { hunt = HUNT }, guide = HUNT_GUIDE })
		local DONE = "|cff40d040[x]|r "
		ns.db.settings.trackStepQuests = true -- chosen here, so this walk does not depend on the module's default

		-- pick up: one pin at the quest giver, for both quests
		assert.are.equal("hunt:1", current(ns))
		local entries = ns.Pins:Collect()
		assert.are.equal(1, #entries)
		assert.are.same({ "accept", 9101, 9001, 9002 }, {
			entries[1].target.kind,
			entries[1].target.npc,
			entries[1].target.quests[1],
			entries[1].target.quests[2],
		})
		assert.are.same(
			{ '[ ] Accept "Test Quest" from Test Giver', '[ ] Accept "Other Quest" from Test Giver' },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)

		-- do: nothing drawn, one line per quest with its mark, no objective counters, and the quest tracker holds
		-- exactly these two quests (an older quest the player was tracking is dropped)
		world.log = {
			quest(9001, { objectives = { objective("Test Boar slain", 0, 3) } }),
			quest(9002, { objectives = { objective("Test Boar slain", 0, 3) } }),
			quest(9003, { objectives = { objective("Older", 0, 3) } }),
		}
		world.watch = { 9003 }
		event(world, mock, "QUEST_ACCEPTED", 9002)
		assert.are.equal("hunt:2", current(ns))
		assert.are.same({ 9001, 9002 }, world.watch)
		assert.are.same({}, ns.Pins:Collect())
		assert.are.same(
			{ '[ ] Complete "Test Quest"', '[ ] Complete "Other Quest"' },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)

		-- one quest complete is not enough: the step stays, its line is marked
		world.log[1].objectives = { objective("Test Boar slain", 3, 3) }
		event(world, mock, "QUEST_LOG_UPDATE")
		assert.are.equal("hunt:2", current(ns))
		assert.are.same(
			{ DONE .. 'Complete "Test Quest"', '[ ] Complete "Other Quest"' },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)
		assert.are.same({}, ns.Pins:Collect())

		-- both complete: on to the hand-in, which pins the quest giver again and keeps the two quests tracked
		world.log[2].objectives = { objective("Test Boar slain", 3, 3) }
		event(world, mock, "QUEST_LOG_UPDATE")
		assert.are.equal("hunt:3", current(ns))
		assert.are.same({ 9001, 9002 }, world.watch)
		entries = ns.Pins:Collect()
		assert.are.equal(1, #entries)
		assert.are.same({ "turnin", 9101 }, { entries[1].target.kind, entries[1].target.npc })
		assert.are.same(
			{ '[ ] Turn in "Test Quest" to Test Giver', '[ ] Turn in "Other Quest" to Test Giver' },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)
	end)

	-- A pick-up of two NPCs of one area (the tools write each NPC's .goto followed by its quests): one pin for each NPC
	-- with its own quests, which goes once they are in the log, and a done mark on each line of the card.
	local JOINED = [[
#chapter 1-6 Joined
step
  .goto 1411,30,30
  .accept 9001
  .goto 1411,40,40
  .accept 9002
step
  .goto 1411,50,50
  .complete 9001
  .complete 9002
]]
	local JOINED_GUIDE = { id = "test-joined", name = "Joined", levels = { 1, 10 }, text = "#include joined\n" }

	it("pins each NPC of a joined pick-up with its own quests and marks each line as it is done", function()
		local ns, world, mock = start(nil, { chapters = { joined = JOINED }, guide = JOINED_GUIDE })
		local DONE = "|cff40d040[x]|r "
		assert.are.equal("joined:1", current(ns))
		local entries = ns.Pins:Collect()
		assert.are.equal(2, #entries)
		assert.are.same({ { "accept", 30, 9001 }, { "accept", 40, 9002 } }, {
			{ entries[1].target.kind, entries[1].target.x, entries[1].target.quests[1] },
			{ entries[2].target.kind, entries[2].target.x, entries[2].target.quests[1] },
		})
		assert.are.same(
			{ '[ ] Accept "Quest #9001"', '[ ] Accept "Quest #9002"' },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)
		-- a pin's tooltip lists the lines of its own quests only
		assert.are.same(
			{ '[ ] Accept "Quest #9002"' },
			ns.StepFrame.DescribeLines((ns.Progress:Current()), { [9002] = true })
		)

		-- one accepted: its pin and its line's open mark are gone; the other NPC's pin stays
		world.log = { quest(9001, { objectives = { objective("Boar slain", 0, 3) } }) }
		event(world, mock, "QUEST_ACCEPTED", 9001)
		assert.are.equal("joined:1", current(ns))
		entries = ns.Pins:Collect()
		assert.are.equal(1, #entries)
		assert.are.same(
			{ "accept", 40, 9002 },
			{ entries[1].target.kind, entries[1].target.x, entries[1].target.quests[1] }
		)
		assert.are.same(
			{ DONE .. 'Accept "Quest 9001"', '[ ] Accept "Quest #9002"' },
			ns.StepFrame.DescribeLines(ns.Progress:Current())
		)

		world.log[2] = quest(9002, { objectives = { objective("Boar slain", 0, 3) } })
		event(world, mock, "QUEST_ACCEPTED", 9002)
		assert.are.equal("joined:2", current(ns)) -- a doing step now: no pins at all
		assert.are.same({}, ns.Pins:Collect())
	end)

	-- A group quest of a normal route is an optional-only step for each stage (Engine/Conditions.lua OptionalOnly):
	-- the route does not stop at it unless the player takes the quest.
	local GROUP = [[
#chapter 1-6 Group
step
  .goto 1411,30,30
  .accept 9001
step
  .goto 1411,40,40
  .accept 9500
  .optional 9500
step
  .goto 1411,50,50
  .complete 9500
  .optional 9500
step
  .goto 1411,40,40
  .turnin 9500
  .optional 9500
step
  .goto 1411,30,30
  .turnin 9001
]]
	local GROUP_GUIDE = { id = "test-group", name = "Group", levels = { 1, 10 }, text = "#include group\n" }

	it("passes the steps of a group quest the player does not take, and offers it beside the step before", function()
		local ns, world, mock = start(nil, { chapters = { group = GROUP }, guide = GROUP_GUIDE })
		assert.are.equal("group:1", current(ns))
		-- the group quest's three steps are the next three: one line, for the one quest (the card's own text is
		-- tests/ui_spec.lua's)
		assert.are.same({ "Quest #9500 (group quest)" }, ns.StepFrame:OptionalLines(ns.Progress:Current()))

		world.log = { quest(9001, { objectives = { objective("Boar slain", 0, 3) } }) }
		event(world, mock, "QUEST_ACCEPTED", 9001)
		-- 9001 is in the log: the step ends, and the three steps of the group quest are passed one after the other
		assert.are.equal("group:5", current(ns))
		local record = ns.char.progress["test-group"]
		assert.is_true(record.done["group:2"] and record.done["group:3"] and record.done["group:4"])
		assert.are.same({}, ns.StepFrame:OptionalLines(ns.Progress:Current()))
	end)

	-- The engine looks at the quest log when it first evaluates at login; the client may not have sent it yet, and an
	-- empty log that has not arrived must not pass the steps of a group quest the character holds (R-engine-1 #3).
	describe("when the client has not sent the quest log yet", function()
		-- a session that has the log from the start, then its SavedVariables as the client gives them back
		local function savedAt(stepNumber, log)
			local ns, world = start(function(w)
				w.log = log
			end, { chapters = { group = GROUP }, guide = GROUP_GUIDE })
			assert.is_true(ns.Progress:JumpTo(stepNumber))
			world.advance(1.1)
			assert.are.equal("group:" .. stepNumber, current(ns))
			local saved = ns.Util.CopyTable(ns.char)
			contextMock.uninstall()
			return saved
		end

		local function wolf(have)
			return quest(9500, { objectives = { objective("Wolf slain", have, 2) } })
		end
		local function boar()
			return quest(9001, { objectives = { objective("Boar slain", 0, 3) } })
		end

		it("keeps the character who holds the group quest at its step, before and after the log arrives", function()
			local saved = savedAt(3, { boar(), wolf(1) })
			local ns, world, mock = start(function(w)
				G.SignpostCharDB = saved
				w.log = {} -- not sent yet
			end, { chapters = { group = GROUP }, guide = GROUP_GUIDE })
			assert.is_false(ns.Context:QuestLogLoaded())
			assert.are.equal("group:3", current(ns)) -- its quest is not in the log it can see, and it does not pass
			world.log = { boar(), wolf(1) } -- the client sends the log
			event(world, mock, "QUEST_LOG_UPDATE")
			assert.is_true(ns.Context:QuestLogLoaded())
			assert.are.equal("group:3", current(ns))
			local record = ns.char.progress["test-group"]
			assert.is_nil(record.done["group:3"])
			assert.is_nil(record.done["group:4"])
			assert.are.same({}, ns.StepFrame:OptionalLines(ns.Progress:Current()))
		end)

		it(
			"passes the steps of a group quest the character does not hold once the log has arrived without it",
			function()
				local saved = savedAt(2, { boar() })
				local ns, world, mock = start(function(w)
					G.SignpostCharDB = saved
					w.log = {} -- not sent yet
				end, { chapters = { group = GROUP }, guide = GROUP_GUIDE })
				assert.are.equal("group:2", current(ns)) -- it cannot tell yet that the quest is not taken
				world.log = { boar() }
				event(world, mock, "QUEST_LOG_UPDATE")
				assert.are.equal("group:5", current(ns))
				local record = ns.char.progress["test-group"]
				assert.is_true(record.done["group:2"] and record.done["group:3"] and record.done["group:4"])
			end
		)
	end)

	-- The card lists the current step's own quest in its body; the Optional: line is for the group quests coming up, and
	-- must not repeat that one (R-engine-2 #3).
	it("does not offer, beside the step of a group quest, the quest that step lists itself", function()
		local ns = start(nil, { chapters = { group = GROUP }, guide = GROUP_GUIDE })
		assert.are.same({ "Quest #9500 (group quest)" }, ns.StepFrame:OptionalLines(ns.Progress:Current())) -- from group:1
		for _, stepNumber in ipairs({ 2, 3, 4 }) do
			assert.is_true(ns.Progress:JumpTo(stepNumber)) -- held there, the quest not taken
			local step = ns.Progress:Current()
			assert.are.equal("group:" .. stepNumber, step.id)
			local body = ns.StepFrame.DescribeLines(step)
			assert.are.equal(1, #body)
			assert.is_truthy(body[1]:find("Quest #9500", 1, true)) -- the body names it
			assert.are.same({}, ns.StepFrame:OptionalLines(step), step.id) -- and the line beside it does not
		end
	end)

	it("does not pass a group quest the player took, and offers nothing once it is in the log", function()
		local ns, world, mock = start(nil, { chapters = { group = GROUP }, guide = GROUP_GUIDE })
		assert.are.equal("group:1", current(ns))
		-- the player took the group quest on the way, before the first step ended
		world.log = { quest(9500, { objectives = { objective("Wolf slain", 0, 2) } }) }
		event(world, mock, "QUEST_ACCEPTED", 9500)
		assert.are.same({}, ns.StepFrame:OptionalLines(ns.Progress:Current())) -- it is in the log: no longer offered
		world.log[2] = quest(9001, { objectives = { objective("Boar slain", 0, 3) } })
		event(world, mock, "QUEST_ACCEPTED", 9001)
		assert.are.equal("group:3", current(ns)) -- its accept is satisfied; its doing step waits for the player
		assert.are.same({ '[ ] Complete "Quest 9500"' }, ns.StepFrame.DescribeLines(ns.Progress:Current()))
		world.log[1].objectives = { objective("Wolf slain", 2, 2) }
		event(world, mock, "QUEST_LOG_UPDATE")
		assert.are.equal("group:4", current(ns)) -- the turn-in is not passed either
		world.log = { world.log[2] } -- 9500 is handed in: out of the log, flagged completed
		world.completed = { 9500 }
		event(world, mock, "QUEST_TURNED_IN", 9500, 0, 0)
		assert.are.equal("group:5", current(ns))
	end)

	it("keeps counting a .craft step's casts after a reload (its state comes back from SavedVariables)", function()
		local FORGE = "#chapter 1-6 Forge\nstep\n  .craft 2018,3\nstep\n  .note Done.\n"
		local content = {
			chapters = { forge = FORGE },
			guide = { id = "test-forge", name = "Forge", levels = { 1, 10 }, text = "#include forge\n" },
		}
		local ns, world, mock = start(nil, content)
		assert.are.equal("forge:1", current(ns))
		event(world, mock, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2018)
		event(world, mock, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 2018)
		event(world, mock, "UNIT_SPELLCAST_SUCCEEDED", "target", "Cast-3", 2018) -- not the player's
		assert.are.equal("forge:1", current(ns))

		local saved = ns.Util.CopyTable(ns.char)
		contextMock.uninstall()
		local reloaded, world2, mock2 = start(function()
			G.SignpostCharDB = saved
		end, content)
		assert.are.equal("forge:1", current(reloaded))
		assert.are.same({ "Craft Spell #2018 (2/3)" }, reloaded.StepFrame.DescribeLines(reloaded.Progress:Current()))
		event(world2, mock2, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 2018)
		assert.are.equal("forge:2", current(reloaded))
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
