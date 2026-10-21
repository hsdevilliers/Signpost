-- Placing a character in a guide (Engine/Progress.lua "Placement" over Engine/Placement.lua): the first time a guide
-- runs for a character with no progress in it, when the quest history is late, when the saved step is gone, on demand
-- (/signpost place) and after /signpost reset progress. The real engine, parser and context on the scripted client of
-- tests/mocks/context.lua; the guide and its quest IDs are made up.
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local quest, objective = contextMock.quest, contextMock.objective

-- Valley: steps 1 to 8 (levels 1 to 6), Plains: steps 9 to 13 (levels 6 to 12). Quests 101 to 103 and 201 to 202.
local CHAPTERS = {
	valley = [[
#chapter 1-6 Valley
step
  .accept 101
step
  .complete 101
step
  .turnin 101
  .accept 102
step
  .complete 102
step
  .turnin 102
step
  .accept 103
step
  .complete 103
step
  .turnin 103
]],
	plains = [[
#chapter 6-12 Plains
step
  .accept 201
step
  .complete 201
step
  .turnin 201
  .accept 202
step
  .complete 202
step
  .turnin 202
]],
}

local GUIDE_ID = "test-place"
local GUIDE = {
	id = GUIDE_ID,
	name = "Place Test",
	faction = "*",
	races = { "*" },
	classes = { "*" },
	levels = { 1, 12 },
	text = "#include valley\n#include plains\n",
}

local sessions = {}

after_each(function()
	local finished = sessions
	sessions = {}
	contextMock.uninstall()
	for _, session in ipairs(finished) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
end)

-- One play session. opts: level, completed (quest IDs), log (quest log entries), saved (SignpostCharDB from an earlier
-- session), advance (seconds let pass after login, default 1), noGuide (register no guide), setup(ns) (before login).
local function start(opts)
	opts = opts or {}
	local world
	local ns, mock = addon.load({
		login = false,
		before = function(m)
			world = contextMock.install(m)
			world.level = opts.level or 1
			world.completed = opts.completed or {}
			world.log = opts.log or {}
			G.SignpostCharDB = opts.saved
		end,
	})
	for id, text in pairs(CHAPTERS) do
		assert.is_true(ns.Chapters:Register(id, text))
	end
	if not opts.noGuide then
		assert.is_true(ns.Guides:Register(GUIDE))
	end
	if opts.setup then
		opts.setup(ns)
	end
	local log = { steps = {}, placed = {} }
	ns.Events:RegisterMessage("STEP_CHANGED", function(_, step, _, reason)
		log.steps[#log.steps + 1] = step.id .. ":" .. reason
	end)
	ns.Events:RegisterMessage("GUIDE_PLACED", function(_, result, reason)
		log.placed[#log.placed + 1] = { index = result.index, reason = reason }
	end)
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	world.advance(opts.advance or 1)
	sessions[#sessions + 1] = { ns = ns, mock = mock }
	return ns, world, mock, log
end

local function current(ns)
	local step = ns.Progress:Current()
	return step and step.id
end

local function record(ns)
	return ns.char.progress[GUIDE_ID]
end

local function slash(text)
	G.SlashCmdList.SIGNPOST(text)
end

-- how many of the chat lines contain the text
local function count(mock, text)
	local found = 0
	for _, line in ipairs(mock.printed) do
		if line:find(text, 1, true) then
			found = found + 1
		end
	end
	return found
end

local function keys(set)
	local list = {}
	for key in pairs(set) do
		list[#list + 1] = key
	end
	table.sort(list)
	return list
end

-- the history arrives: the client's list fills in and says so
local function historyArrives(world, mock, completed)
	world.completed = completed
	mock.fire("QUEST_LOG_UPDATE")
	world.advance(1.2)
end

-- quests turned in during play: the client says so, and its list of completed quests has them
local function turnIn(world, mock, ids)
	for _, id in ipairs(ids) do
		world.completed[#world.completed + 1] = id
		mock.fire("QUEST_TURNED_IN", id, 0, 0)
	end
	world.advance(1.2)
end

describe("a character new to a guide", function()
	it("stays at the first step and hears nothing when it has nothing done", function()
		local ns, _, mock, log = start({ level = 1 })
		assert.are.equal("valley:1", current(ns))
		assert.are.equal(0, count(mock, "Your place"))
		assert.are.same({ "valley:1:load" }, log.steps)
		assert.are.equal("none", record(ns).placed.mode)
		assert.are.equal("first", record(ns).placed.reason)
	end)

	it("starts where its quests say, with the steps before marked done, and says why", function()
		local ns, _, mock, log = start({ level = 4, completed = { 101, 102 } })
		assert.are.equal("valley:6", current(ns))
		for i = 1, 5 do
			assert.is_true(ns.Progress:IsDone("valley:" .. i))
		end
		assert.are.same({}, keys(record(ns).skipped))
		assert.are.same({ "valley:6:load" }, log.steps) -- one step change, the load, on the right step
		assert.are.equal(
			1,
			count(
				mock,
				"Your place: step 6/13 (Valley). 2 of this guide's 5 quests are done, 0 are in your quest log, and you are level 4."
			)
		)
		assert.are.equal(1, count(mock, "Wrong? Click a step in the Journal, or type /signpost place to try again."))
		assert.are.equal("history", record(ns).placed.mode)
		assert.are.equal("valley:6", record(ns).placed.step)
		assert.are.same({ { index = 6, reason = "first" } }, log.placed)
	end)

	it("puts the pointer on the step where it is working when a quest is in the log", function()
		local ns, _, mock = start({
			level = 3,
			completed = { 101 },
			log = { quest(102, { objectives = { objective("Boar slain", 1, 4) } }) },
		})
		assert.are.equal("valley:4", current(ns)) -- 102 is accepted, its complete step is next
		assert.are.equal(1, count(mock, "1 of this guide's 5 quests are done, 1 are in your quest log"))
	end)

	it("marks the quests it did not do before its place as skipped", function()
		local ns, _, mock = start({ level = 6, completed = { 101, 103 } })
		assert.are.equal("plains:1", current(ns))
		assert.are.same({ "valley:3", "valley:4", "valley:5" }, keys(record(ns).skipped))
		for _, id in ipairs({ "valley:1", "valley:2", "valley:6", "valley:7", "valley:8" }) do
			assert.is_true(ns.Progress:IsDone(id), id)
		end
		assert.are.equal(1, count(mock, "3 earlier steps you have not done are marked skipped."))
	end)

	it("names the step the engine settled on, past a step it passes at once", function()
		local ns, _, mock = start({
			level = 4,
			completed = { 101 },
			noGuide = true,
			setup = function(n)
				n.Chapters:Register(
					"gate",
					table.concat({
						"#chapter 1-12 Gate",
						"step",
						"  .accept 101",
						"step",
						"  .level 2",
						"step",
						"  .accept 102",
						"step",
						"  .complete 102",
						"",
					}, "\n")
				)
				assert.is_true(n.Guides:Register({
					id = "gate-place",
					name = "Gate",
					faction = "*",
					races = { "*" },
					classes = { "*" },
					levels = { 1, 12 },
					text = "#include gate\n",
				}))
			end,
		})
		-- the placement puts the pointer on the level 2 gate, which the level 4 character has passed: the engine goes on
		assert.are.equal("gate:3", current(ns))
		assert.are.equal("gate:2", ns.char.progress["gate-place"].placed.step)
		assert.are.equal(1, count(mock, "Your place: step 3/4 (Gate)."))
	end)

	it("loads the guide even when the placement itself fails", function()
		local ns, _, mock, log = start({
			level = 4,
			completed = { 101, 102 },
			setup = function(n)
				n.Progress.ApplyPlacement = function()
					error("broken placement")
				end
			end,
		})
		assert.is_truthy(ns.Progress:Current()) -- the engine runs
		-- the load itself went through, not a later evaluation picking up the pieces: the engine's own auto-skip found the place
		assert.are.same({ "valley:6:load" }, log.steps)
		assert.is_truthy(ns.db.errors[1].msg:find("broken placement", 1, true)) -- and the error is on record
		wipe(ns.db.errors) -- seen; the after_each check is for unexpected errors
		wipe(mock.errors)
	end)

	it("never marks the step it puts the pointer on", function()
		local ns = start({ level = 4, completed = { 101, 102 } })
		assert.is_false(ns.Progress:IsDone("valley:6"))
		assert.is_false(ns.Progress:IsSkipped("valley:6"))
		for i = 7, 8 do
			assert.is_false(ns.Progress:IsDone("valley:" .. i))
		end
		assert.is_false(ns.Progress:IsDone("plains:1"))
	end)

	it("places an unfinished character in a guide it has all done at the last step", function()
		local ns, _, mock = start({ level = 12, completed = { 101, 102, 103, 201, 202 } })
		assert.are.equal("plains:5", current(ns))
		assert.are.equal(1, count(mock, "All of this guide's quests are done: your place is its last step, 13/13."))
	end)

	it("says so when its level is above the guide's top level", function()
		local ns, _, mock = start({ level = 15, completed = { 101, 102, 103, 201 } })
		assert.are.equal("plains:5", current(ns))
		assert.are.equal(
			1,
			count(mock, "This guide ends at level 12 and you are level 15: your place is its last step, 13/13.")
		)
	end)

	it("places a second guide chosen later in the same way, and leaves the first alone", function()
		local ns, _, _, _ = start({ level = 4, completed = { 101, 102 } })
		assert.are.equal("valley:6", current(ns))
		-- the same character takes another guide: its own record
		ns.Chapters:Register(
			"camp",
			"#chapter 1-12 Camp\nstep\n  .accept 101\nstep\n  .complete 101\nstep\n  .turnin 101\nstep\n  .accept 301\n"
		)
		assert.is_true(ns.Guides:Register({
			id = "z-other-place",
			name = "Other",
			faction = "*",
			races = { "*" },
			classes = { "*" },
			levels = { 1, 12 },
			text = "#include camp\n",
		}))
		assert.is_true(ns.Guides:Select("z-other-place", ns.Player))
		assert.are.equal("camp:4", current(ns)) -- 101 is done: the accept of 301 is next
		assert.are.equal("z-other-place", ns.Progress:Guide().id)
		assert.are.equal("valley:6", ns.char.progress[GUIDE_ID].current)
	end)
end)

describe("a placement that waits for the quest history", function()
	it("waits for the history above the first levels, and places once it arrives", function()
		local ns, world, mock, log = start({ level = 8, advance = 0.5 })
		assert.are.equal("valley:1", current(ns)) -- nothing is known yet
		assert.are.equal(0, count(mock, "Your place"))
		historyArrives(world, mock, { 101, 102, 103, 201 })
		assert.are.equal("plains:3", current(ns))
		assert.are.equal(1, count(mock, "Your place: step 11/13 (Plains). 4 of this guide's 5 quests are done"))
		assert.are.equal("first", record(ns).placed.reason)
		assert.are.same({ { index = 11, reason = "first" } }, log.placed)
		-- once: more quest events do not place it again
		mock.fire("QUEST_LOG_UPDATE")
		world.advance(2)
		assert.are.equal(1, #log.placed)
	end)

	it("goes by the level when the history does not come, and says it is a guess", function()
		local ns, world, mock = start({ level = 4, advance = 0.5 })
		assert.are.equal("valley:1", current(ns))
		world.advance(6) -- the wait is over
		assert.are.equal("valley:5", current(ns)) -- where the guide expects a level 4
		assert.are.equal(
			1,
			count(
				mock,
				"Your place: step 5/13 (Valley). None of this guide's quests are done yet, so this is a guess from your level (4)."
			)
		)
		assert.are.equal(1, count(mock, "Not sure about this one"))
		assert.are.equal("level", record(ns).placed.mode)
		-- the quests before it are not done as far as anyone knows: skipped
		assert.are.same({ "valley:1", "valley:2", "valley:3", "valley:4" }, keys(record(ns).skipped))
		assert.are.same({}, keys(record(ns).done))
	end)

	it("places again, once, when the history turns up after the wait", function()
		local ns, world, mock, log = start({ level = 4, advance = 0.5 })
		world.advance(6)
		assert.are.equal("valley:5", current(ns))
		historyArrives(world, mock, { 101, 102, 103 })
		assert.are.equal("plains:1", current(ns))
		assert.are.equal(1, count(mock, "Your quest history has loaded: placing you again."))
		assert.are.equal("refine", record(ns).placed.reason)
		assert.are.equal(2, #log.placed)
		-- and not a third time
		historyArrives(world, mock, { 101, 102, 103, 201 })
		assert.are.equal(2, #log.placed)
	end)

	it("does not place it again when the player has moved on before the history came", function()
		local ns, world, mock, log = start({ level = 4, advance = 0.5 })
		world.advance(6)
		slash("next")
		local after = current(ns)
		historyArrives(world, mock, { 101, 102, 103 })
		assert.are.equal(1, #log.placed)
		assert.are.equal(0, count(mock, "placing you again"))
		assert.are_not.equal("plains:1", after)
	end)

	it("does not wait longer when the guide is parsed again during the wait", function()
		local ns, world = start({ level = 4, advance = 0.5 })
		world.advance(3)
		ns.Events:Fire(
			"PROFESSION_PLAN_CHANGED",
			{ primary = {}, secondary = {}, declined = {}, learned = {}, unknown = {} }
		)
		assert.are.equal("valley:1", current(ns))
		world.advance(2.6) -- 6 s after login: the first wait is over
		assert.are.equal("valley:5", current(ns))
	end)

	it("does not wait at level 2 or below", function()
		local ns, _, mock = start({ level = 2, completed = {}, advance = 0.1 })
		assert.are.equal("valley:1", current(ns))
		assert.are.equal("first", record(ns).placed.reason)
		assert.are.equal(0, count(mock, "Your place"))
	end)

	it("is cancelled by another guide being chosen while it waits", function()
		local ns, world, mock, log = start({ level = 8, advance = 0.5 })
		ns.Chapters:Register("camp", "#chapter 1-12 Camp\nstep\n  .accept 301\n")
		assert.is_true(ns.Guides:Register({
			id = "z-other-place",
			name = "Other",
			faction = "*",
			races = { "*" },
			classes = { "*" },
			levels = { 1, 12 },
			text = "#include camp\n",
		}))
		assert.is_true(ns.Guides:Select("z-other-place", ns.Player))
		local placedBefore = #log.placed
		world.advance(6) -- the first guide's wait runs out: nothing for it
		assert.are.equal("z-other-place", ns.Progress:Guide().id)
		assert.is_true(#log.placed <= placedBefore + 1) -- at most the other guide's own
		assert.are.equal(0, count(mock, "step 11/13"))
	end)
end)

describe("a saved place that is not in the guide", function()
	local function gone()
		return {
			dbVersion = 2,
			progress = {
				[GUIDE_ID] = {
					current = "old:7",
					done = { ["old:1"] = true, ["old:2"] = true },
					skipped = { ["old:3"] = true },
				},
			},
		}
	end

	it("places the character instead of starting over, and says what happened", function()
		local ns, _, mock = start({ level = 4, completed = { 101, 102 }, saved = gone() })
		assert.are.equal("valley:6", current(ns))
		assert.are.equal(1, count(mock, "The guide was updated and your saved place is not in it any more."))
		assert.are.equal(1, count(mock, "Your place: step 6/13 (Valley)."))
		assert.are.equal("lost", record(ns).placed.reason)
		-- the marks of steps the guide does not have are dropped
		assert.is_nil(record(ns).done["old:1"])
		assert.is_nil(record(ns).skipped["old:3"])
		assert.is_true(ns.Progress:IsDone("valley:5"))
	end)

	it("says it even when there is nothing to go on", function()
		local ns, _, mock = start({ level = 1, saved = gone() })
		assert.are.equal("valley:1", current(ns))
		assert.are.equal(1, count(mock, "The guide was updated and your saved place is not in it any more."))
		assert.are.equal(1, count(mock, "Your place: step 1."))
	end)

	it("keeps the old rule when some marks still match: after the furthest done step", function()
		local saved = {
			dbVersion = 2,
			progress = { [GUIDE_ID] = { current = "valley:99", done = { ["valley:1"] = true, ["valley:2"] = true } } },
		}
		local ns, _, mock, log = start({ level = 4, completed = {}, saved = saved })
		assert.are.equal("valley:3", current(ns))
		assert.are.equal(0, #log.placed)
		assert.are.equal(0, count(mock, "Your place"))
	end)
end)

describe("a character with progress in the guide", function()
	local function playing()
		return {
			dbVersion = 2,
			progress = {
				[GUIDE_ID] = {
					current = "valley:4",
					done = { ["valley:1"] = true, ["valley:2"] = true, ["valley:3"] = true },
				},
			},
		}
	end

	it("is not placed, whatever its quests say", function()
		local ns, _, mock, log = start({ level = 12, completed = { 101, 102, 103, 201, 202 }, saved = playing() })
		assert.are.equal(0, #log.placed)
		assert.are.equal(0, count(mock, "Your place"))
		assert.is_nil(record(ns).placed)
		-- the engine did what it always did: passed what is done
		assert.are.equal("plains:5", current(ns))
	end)

	it("keeps its place at the next login, placed once or not", function()
		local ns, world = start({ level = 4, completed = { 101, 102 } })
		assert.are.equal("valley:6", current(ns))
		local saved = ns.Util.CopyTable(ns.char)
		local again, _, mock, log = start({ level = 4, completed = { 101, 102 }, saved = saved })
		assert.are.equal("valley:6", current(again))
		assert.are.equal(0, #log.placed)
		assert.are.equal(0, count(mock, "Your place"))
		assert.is_not_nil(world)
	end)

	it("is not placed again when the guide is parsed again for a new profession plan", function()
		local ns, _, mock, log = start({ level = 4, completed = { 101, 102 } })
		assert.are.equal(1, #log.placed)
		local placed = record(ns).placed
		ns.Events:Fire(
			"PROFESSION_PLAN_CHANGED",
			{ primary = {}, secondary = {}, declined = {}, learned = {}, unknown = {} }
		)
		assert.are.equal(1, #log.placed)
		assert.are.equal(placed, record(ns).placed)
		assert.are.equal(1, count(mock, "Your place"))
	end)

	it("treats a record whose only trace is the first step as new (the wait was cut short)", function()
		local saved = { dbVersion = 2, progress = { [GUIDE_ID] = { current = "valley:1" } } }
		local ns = start({ level = 4, completed = { 101, 102 }, saved = saved })
		assert.are.equal("valley:6", current(ns))
		assert.are.equal("first", record(ns).placed.reason)
	end)
end)

describe("Find my place (/signpost place)", function()
	-- a character placed at valley:6 by its quests, who then goes back by hand to valley:2
	local function wandered()
		local ns, world, mock, log = start({ level = 4, completed = { 101, 102 } })
		assert.are.equal("valley:6", current(ns))
		slash("step 2")
		assert.are.equal("valley:2", current(ns))
		return ns, world, mock, log
	end

	it("moves the pointer to where the quests say, with the marks, and says where", function()
		local ns, _, mock, log = wandered()
		slash("place")
		assert.are.equal("valley:6", current(ns))
		assert.are.equal("valley:6:place", log.steps[#log.steps])
		assert.are.equal(2, count(mock, "Your place: step 6/13 (Valley). 2 of this guide's 5 quests are done"))
		assert.is_true(ns.Progress:IsDone("valley:5"))
		assert.is_true(ns.Progress:IsDone("valley:2")) -- the step the player went back to
		assert.are.equal("manual", record(ns).placed.reason)
		assert.are.equal("manual", log.placed[#log.placed].reason)
	end)

	it("marks the steps before the pointer done where the quests are and skipped where they are not", function()
		local ns, world, mock = start({ level = 6, completed = { 101, 103 } })
		assert.are.equal("plains:1", current(ns))
		slash("step 1")
		slash("place")
		assert.are.equal("plains:1", current(ns))
		assert.are.same({ "valley:3", "valley:4", "valley:5" }, keys(record(ns).skipped))
		assert.are.same({ "valley:1", "valley:2", "valley:6", "valley:7", "valley:8" }, keys(record(ns).done))
		assert.is_not_nil(world)
		assert.is_not_nil(mock)
	end)

	it("clears the marks from the pointer on, so that the steps the player pressed past are looked at again", function()
		local ns, _, mock, log = start({ level = 4, completed = { 101, 102 } })
		assert.are.equal("valley:6", current(ns))
		slash("next")
		slash("next")
		slash("next")
		assert.are.equal("plains:1", current(ns)) -- valley has eight steps
		assert.is_true(ns.Progress:IsDone("valley:6"))
		assert.is_true(ns.Progress:IsDone("valley:8"))
		slash("place")
		assert.are.equal("valley:6", current(ns)) -- the quests of those steps are not done
		assert.is_false(ns.Progress:IsDone("valley:6"))
		assert.is_false(ns.Progress:IsDone("valley:7"))
		assert.is_false(ns.Progress:IsDone("valley:8"))
		assert.are.equal("valley:6:place", log.steps[#log.steps])
		assert.are.equal(2, count(mock, "Your place: step 6/13"))
	end)

	it("keeps a skip the player made by hand on a step with no quest of its own", function()
		local ns = start({
			level = 9,
			completed = { 101, 102 },
			noGuide = true,
			setup = function(n)
				n.Chapters:Register(
					"road",
					table.concat({
						"#chapter 1-12 Road",
						"step",
						"  .accept 101",
						"step",
						"  .note Walk on to the next town.",
						"step",
						"  .accept 102",
						"step",
						"  .accept 103",
						"",
					}, "\n")
				)
				assert.is_true(n.Guides:Register({
					id = "road-place",
					name = "Road",
					faction = "*",
					races = { "*" },
					classes = { "*" },
					levels = { 1, 12 },
					text = "#include road\n",
				}))
			end,
		})
		assert.are.equal("road:4", current(ns))
		assert.is_true(ns.Progress:IsDone("road:2")) -- no quest in it: done by the placement
		slash("step 2")
		slash("skip")
		assert.is_true(ns.Progress:IsSkipped("road:2"))
		slash("place")
		assert.is_true(ns.Progress:IsSkipped("road:2")) -- the player's own decision stands
		assert.is_true(ns.Progress:IsDone("road:1"))
		assert.is_true(ns.Progress:IsDone("road:3"))
		assert.are.equal("road:4", current(ns))
	end)

	it("is undone by <, which takes back the pointer and the marks", function()
		local ns, _, mock = wandered()
		local before = { done = keys(record(ns).done), skipped = keys(record(ns).skipped) }
		slash("place")
		assert.are.equal("valley:6", current(ns))
		slash("back")
		assert.are.equal("valley:2", current(ns))
		assert.are.same(before.done, keys(record(ns).done))
		assert.are.same(before.skipped, keys(record(ns).skipped))
		-- and then < is the plain back again
		slash("back")
		assert.are.equal("valley:1", current(ns))
		slash("back")
		assert.truthy(mock.printed[#mock.printed]:find("This is the first step.", 1, true))
	end)

	it("is plain back once the player has moved on from the place", function()
		local ns = wandered()
		slash("place")
		slash("next")
		local moved = current(ns)
		slash("back")
		assert.are.equal("valley:6", current(ns)) -- one step back, no undo
		assert.are_not.equal(moved, current(ns))
		assert.is_true(ns.Progress:IsDone("valley:5"))
		-- back on the step the placement ended on, a move by hand has dropped the undo for good
		slash("back")
		assert.are.equal("valley:5", current(ns))
	end)

	it("is not taken back by < after the player skipped a dungeon chapter", function()
		local ns = start({
			level = 3,
			noGuide = true,
			log = { quest(101, { objectives = { objective("Boar slain", 1, 4) } }) },
			setup = function(n)
				n.Chapters:Register(
					"fields",
					table.concat({
						"#chapter 1-6 Fields",
						"step",
						"  .accept 101",
						"step",
						"  .complete 101",
						"step",
						"  .turnin 101",
						"#chapter 6-8 Cellar #dungeon",
						"step",
						"  .accept 301",
						"step",
						"  .complete 301",
						"#chapter 8-10 Hills",
						"step",
						"  .accept 401",
						"",
					}, "\n")
				)
				assert.is_true(n.Guides:Register({
					id = "dungeon-place",
					name = "Dungeon",
					faction = "*",
					races = { "*" },
					classes = { "*" },
					levels = { 1, 10 },
					text = "#include fields\n",
				}))
			end,
		})
		assert.are.equal("fields:2", current(ns)) -- 101 is in the log: its complete step
		slash("step 1")
		slash("place")
		assert.are.equal("fields:2", current(ns))
		assert.is_true(ns.Progress:SetChapterSkipped(2, true)) -- the cellar is ahead: the pointer stays
		assert.are.equal("fields:2", current(ns))
		slash("back")
		assert.are.equal("fields:1", current(ns))
		assert.is_true(ns.Progress:ChapterSkipped(2)) -- the undo would have given the cellar back
	end)

	it("is plain back after the engine moved the pointer on by itself", function()
		local ns, world, mock = wandered()
		slash("place")
		assert.are.equal("valley:6", current(ns))
		turnIn(world, mock, { 103 }) -- quest 103 is done by hand-in: the engine passes valley:6 to 8
		local moved = current(ns)
		assert.are_not.equal("valley:6", moved)
		slash("back")
		assert.are_not.equal("valley:2", current(ns)) -- not the undo
	end)

	it("says there is nothing to go on for a character with nothing done", function()
		local ns, _, mock = start({ level = 1 })
		slash("place")
		assert.are.equal("valley:1", current(ns))
		assert.are.equal(1, count(mock, "Your place: step 1. None of this guide's quests are done and you are level 1"))
	end)

	it("says there is no guide when there is none", function()
		local _, _, mock = start({ noGuide = true })
		slash("place")
		assert.are.equal(1, count(mock, "No guide is loaded for this character."))
	end)

	it("is in /signpost help, with reset progress", function()
		local _, _, mock = start({ level = 1 })
		slash("help")
		assert.are.equal(1, count(mock, "/signpost place - "))
		assert.are.equal(1, count(mock, "/signpost reset progress - "))
		assert.are.equal(1, count(mock, "/signpost reset - "))
	end)
end)

describe("/signpost reset progress", function()
	local function placedAndPlaying()
		local ns, world, mock = start({ level = 4, completed = { 101, 102 } })
		slash("skip") -- a mark that a placement would not make
		assert.is_true(ns.Progress:IsSkipped("valley:6"))
		return ns, world, mock
	end

	it("asks first and changes nothing", function()
		local ns, _, mock = placedAndPlaying()
		slash("reset progress")
		assert.are.equal(1, count(mock, "This forgets your progress in Place Test"))
		assert.are.equal(1, count(mock, "type /signpost reset progress again within 30 seconds"))
		assert.is_true(ns.Progress:IsSkipped("valley:6"))
		assert.are.equal("valley:7", current(ns))
	end)

	it("forgets the progress when typed twice, and places the character again", function()
		local ns, _, mock = placedAndPlaying()
		slash("reset progress")
		slash("reset progress")
		assert.are.equal(1, count(mock, "Your progress in Place Test was cleared."))
		assert.is_false(ns.Progress:IsSkipped("valley:6"))
		assert.are.equal("valley:6", current(ns)) -- placed again from the same quests
		assert.is_true(ns.Progress:IsDone("valley:5"))
		assert.are.equal("first", record(ns).placed.reason)
	end)

	it("starts from the first step when there is no history to place it by", function()
		local ns, _, mock = start({ level = 1 })
		slash("next")
		slash("next")
		assert.are.equal("valley:3", current(ns))
		slash("reset progress")
		slash("reset progress")
		assert.are.equal(1, count(mock, "Your progress in Place Test was cleared."))
		assert.are.equal("valley:1", current(ns))
		assert.are.same({}, keys(record(ns).done))
		assert.are.same({}, keys(record(ns).skipped))
	end)

	it("asks again when the second typing comes too late", function()
		local ns, world, mock = placedAndPlaying()
		slash("reset progress")
		world.advance(31)
		slash("reset progress")
		assert.are.equal(2, count(mock, "This forgets your progress in Place Test"))
		assert.are.equal(0, count(mock, "was cleared"))
		assert.is_true(ns.Progress:IsSkipped("valley:6"))
	end)

	it("leaves /signpost reset to the step frame", function()
		local ns, _, mock = placedAndPlaying()
		slash("reset")
		assert.are.equal(1, count(mock, "Step frame reset"))
		assert.is_true(ns.Progress:IsSkipped("valley:6"))
		assert.are.equal(0, count(mock, "This forgets your progress"))
	end)

	it("says there is no guide when there is none", function()
		local _, _, mock = start({ noGuide = true })
		slash("reset progress")
		assert.are.equal(1, count(mock, "No guide is loaded for this character."))
	end)
end)

describe("two-word slash commands", function()
	it("run before their first word, which keeps everything else typed after it", function()
		local ns = start({ level = 1 })
		local seen = {}
		ns.Slash:Register("thing", function(args)
			seen[#seen + 1] = "thing:" .. args
		end, "one word")
		ns.Slash:Register("thing special", function(args)
			seen[#seen + 1] = "special:" .. args
		end, "two words")
		slash("thing")
		slash("thing other words")
		slash("thing special")
		slash("THING Special and more")
		assert.are.same({ "thing:", "thing:other words", "special:", "special:and more" }, seen)
	end)
end)
