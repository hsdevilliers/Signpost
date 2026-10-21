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

-- The fingerprint of the test guide's text as this session registered it (Engine/Parser.lua).
local function fingerprintOf(ns, guideId)
	local def = ns.Guides:Get(guideId or GUIDE_ID)
	return ns.Parser:ParseGuide(def, { player = {} }).fingerprint
end

-- A record made by hand is for the text this session registered, as a record the addon wrote would be: it gets that
-- fingerprint, unless it has one already (it came out of an earlier session of the spec).
local function stamp(ns, saved)
	for guideId, record in pairs(saved.progress or {}) do
		if type(record) == "table" and record.fingerprint == nil and ns.Guides:Get(guideId) then
			record.fingerprint = fingerprintOf(ns, guideId)
		end
	end
end

-- One play session. opts: level, completed (quest IDs), log (quest log entries), saved (SignpostCharDB from an earlier
-- session; a record in it that has no fingerprint gets the one of this session's guide text, unless opts.unstamped: an
-- older version wrote none), chapters (the chapter texts of the session instead of CHAPTERS), advance (seconds let pass
-- after login, default 1), noGuide (register no guide), setup(ns) (before login).
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
	for id, text in pairs(opts.chapters or CHAPTERS) do
		assert.is_true(ns.Chapters:Register(id, text))
	end
	if not opts.noGuide then
		assert.is_true(ns.Guides:Register(GUIDE))
	end
	if opts.setup then
		opts.setup(ns)
	end
	if opts.saved and not opts.unstamped then
		stamp(ns, opts.saved)
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
		-- the load itself went through, not a later evaluation picking up the pieces: the engine's own auto-skip
		-- found the place
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

	-- A character that has done the whole valley and is working on a quest in the plains. The client has sent its quest
	-- log and not its list of completed quests yet.
	local function onThePlains()
		return {
			level = 7,
			completed = {},
			log = { quest(201, { objectives = { objective("Boars", 1, 4) } }) },
			advance = 0.5,
		}
	end

	it(
		"does not take a quest in the log for the quest history: the list of completed quests has to be there",
		function()
			local ns, world, mock, log = start(onThePlains())
			assert.are.equal("valley:1", current(ns)) -- still waiting
			assert.are.equal(0, #log.placed)
			assert.are.equal(0, count(mock, "Your place"))
			historyArrives(world, mock, { 101, 102, 103 })
			assert.are.equal("plains:2", current(ns))
			assert.are.same({ { index = 10, reason = "first" } }, log.placed)
			-- the valley is done, as the list says, and not "skipped", as the log alone would have it
			assert.are.same({}, keys(record(ns).skipped))
			for i = 1, 8 do
				assert.is_true(ns.Progress:IsDone("valley:" .. i), i)
			end
		end
	)

	it("goes by the log and the level when the list never comes, and puts it right when it does", function()
		local ns, world, mock, log = start(onThePlains())
		world.advance(6) -- the wait is over
		assert.are.equal("plains:2", current(ns))
		assert.are.equal("history", record(ns).placed.mode) -- the quest in the log is a history of its own
		assert.are.equal(8, #keys(record(ns).skipped)) -- the valley, as far as anyone knows
		historyArrives(world, mock, { 101, 102, 103 })
		assert.are.equal("plains:2", current(ns))
		assert.are.equal("refine", record(ns).placed.reason)
		assert.are.same({}, keys(record(ns).skipped))
		assert.are.equal(1, count(mock, "Your quest history has loaded: placing you again."))
		assert.are.same({ "first", "refine" }, { log.placed[1].reason, log.placed[2].reason })
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

-- A step id is a position in the guide's text, so a record made for another text of the guide cannot be trusted: the
-- same id can be another step (docs/ENGINE.md "Engine/Progress.lua", the fingerprint). The fingerprint is the Parser's
-- checksum of the guide's text and the chapters it included.
describe("a saved place made for another text of the guide", function()
	-- The valley of a newer version of the guide: two steps for a quest nobody here has done in front of the old ones,
	-- so that every id from valley:1 on means another step, and the ids the old record marks done are not what they were.
	local VALLEY_V2 = [[
#chapter 1-6 Valley
step
  .accept 100
step
  .turnin 100
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
]]
	local function newer()
		return { valley = VALLEY_V2, plains = CHAPTERS.plains }
	end

	-- the record a session of the old text leaves behind, as the client would give it back
	local function oldRecord()
		local ns = start({ level = 4, completed = { 101, 102 } })
		assert.are.equal("valley:6", current(ns))
		return ns.Util.CopyTable(ns.char), ns
	end

	it("keeps its place, with no word, when the text is the same", function()
		local saved, first = oldRecord()
		local ns, _, mock, log = start({ level = 4, completed = { 101, 102 }, saved = saved })
		assert.are.equal("valley:6", current(ns))
		assert.are.equal(0, #log.placed)
		assert.are.equal(0, count(mock, "Your place"))
		assert.are.equal(0, count(mock, "may not match"))
		assert.are.same(first.char.progress[GUIDE_ID].placed, record(ns).placed)
		assert.are.equal(fingerprintOf(first), record(ns).fingerprint)
	end)

	it("stores the fingerprint of the text with the first placement", function()
		local saved, first = oldRecord()
		assert.are.equal("first", saved.progress[GUIDE_ID].placed.reason)
		assert.are.equal(fingerprintOf(first), saved.progress[GUIDE_ID].fingerprint)
		assert.is_string(saved.progress[GUIDE_ID].fingerprint)
	end)

	it("places the character again from its quest history when the ids are the same and the text is not", function()
		local saved = oldRecord()
		assert.is_true(saved.progress[GUIDE_ID].done["valley:1"]) -- the old valley:1 is a step that was done
		local oldFingerprint = saved.progress[GUIDE_ID].fingerprint
		local ns, _, mock, log = start({ level = 4, completed = { 101, 102 }, saved = saved, chapters = newer() })
		assert.are.equal("valley:8", current(ns)) -- accept 103, whichever ids the quests have now
		assert.are.equal("lost", record(ns).placed.reason)
		assert.are.same({ { index = 8, reason = "lost" } }, log.placed)
		assert.are.equal(1, count(mock, "Your saved place may not match this version of the guide"))
		assert.are.equal(1, count(mock, "Your place: step 8/15 (Valley)."))
		-- the marks are the history's, not the old record's: the step for quest 100, which was never done, is not done
		assert.is_false(ns.Progress:IsDone("valley:1"))
		assert.is_true(ns.Progress:IsSkipped("valley:1"))
		assert.is_true(ns.Progress:IsSkipped("valley:2"))
		assert.is_true(ns.Progress:IsDone("valley:5"))
		assert.is_false(ns.Progress:IsDone("valley:9")) -- ahead of the pointer
		assert.are.equal(fingerprintOf(ns), record(ns).fingerprint)
		assert.are_not.equal(oldFingerprint, record(ns).fingerprint)
	end)

	it("keeps that new place at the next login", function()
		local ns = start({ level = 4, completed = { 101, 102 }, saved = oldRecord(), chapters = newer() })
		assert.are.equal("valley:8", current(ns))
		local again, _, mock, log = start({
			level = 4,
			completed = { 101, 102 },
			saved = ns.Util.CopyTable(ns.char),
			chapters = newer(),
		})
		assert.are.equal("valley:8", current(again))
		assert.are.equal(0, #log.placed)
		assert.are.equal(0, count(mock, "Your place"))
	end)

	it("notices a changed chapter that a guide includes, not only a change of the guide's own text", function()
		local saved = oldRecord()
		local ns, _, _, log = start({
			level = 4,
			completed = { 101, 102 },
			saved = saved,
			chapters = {
				valley = CHAPTERS.valley .. "step\n  .note A step added at the end.\n",
				plains = CHAPTERS.plains,
			},
		})
		assert.are.same({ { index = 6, reason = "lost" } }, log.placed)
		assert.are.equal("valley:6", current(ns))
	end)

	it("does not let the old marks move the pointer while the quest history is still on its way", function()
		-- the old record says valley:1 to valley:5 are done; for this text they are not, and the history is not there yet
		local saved = oldRecord()
		local ns, world, mock, log = start({
			level = 4,
			completed = {},
			saved = saved,
			chapters = newer(),
			advance = 0.5,
		})
		assert.are.equal("valley:1", current(ns)) -- the old record's valley:6 is not where this character is
		assert.are.same({}, keys(record(ns).done))
		assert.are.equal(0, #log.placed)
		historyArrives(world, mock, { 101, 102 })
		assert.are.equal("valley:8", current(ns))
		assert.are.same({ { index = 8, reason = "lost" } }, log.placed)
		assert.are.equal(1, count(mock, "Your saved place may not match this version of the guide"))
	end)

	it("says why also when the history never comes and the level has to do", function()
		local ns, world, mock = start({
			level = 4,
			completed = {},
			saved = oldRecord(),
			chapters = newer(),
			advance = 0.5,
		})
		world.advance(6) -- the wait for the history is over
		assert.are.equal("lost", record(ns).placed.reason)
		assert.are.equal("level", record(ns).placed.mode)
		assert.are.equal(1, count(mock, "Your saved place may not match this version of the guide"))
		assert.are.equal(0, count(mock, "your saved place is not in it any more"))
	end)

	it("places a record that has no fingerprint once, and keeps it from then on", function()
		local old = {
			dbVersion = 2,
			progress = { [GUIDE_ID] = { current = "valley:3", done = { ["valley:1"] = true, ["valley:2"] = true } } },
		}
		local ns, _, mock, log = start({ level = 4, completed = { 101, 102 }, saved = old, unstamped = true })
		assert.are.equal("valley:6", current(ns))
		assert.are.same({ { index = 6, reason = "lost" } }, log.placed)
		assert.are.equal(1, count(mock, "Your saved place may not match this version of the guide"))
		assert.are.equal(fingerprintOf(ns), record(ns).fingerprint)
		local again, _, mock2, log2 = start({ level = 4, completed = { 101, 102 }, saved = ns.Util.CopyTable(ns.char) })
		assert.are.equal("valley:6", current(again))
		assert.are.equal(0, #log2.placed)
		assert.are.equal(0, count(mock2, "Your place"))
	end)

	it("treats a fresh record as new, not as outdated, and stamps it", function()
		local ns, _, mock = start({ level = 1 })
		assert.are.equal("first", record(ns).placed.reason)
		assert.are.equal(0, count(mock, "may not match"))
		assert.are.equal(fingerprintOf(ns), record(ns).fingerprint)
	end)

	it("does not place a record again when the guide is parsed again for another profession plan", function()
		local ns, _, mock, log = start({ level = 4, completed = { 101, 102 } })
		local stamped = record(ns).fingerprint
		ns.Events:Fire(
			"PROFESSION_PLAN_CHANGED",
			{ primary = { "skinning" }, secondary = {}, declined = {}, learned = {}, unknown = {} }
		)
		ns.Events:Fire(
			"PROFESSION_PLAN_CHANGED",
			{ primary = {}, secondary = {}, declined = {}, learned = {}, unknown = {} }
		)
		assert.are.equal(1, #log.placed)
		assert.are.equal(1, count(mock, "Your place"))
		assert.are.equal(stamped, record(ns).fingerprint)
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

-- A guide whose first step starts an ongoing goal (a sticky directive, as the profession tracks' skill goals are): the
-- level to reach, which rides beside the route from that step on. Level 15 is above anything these specs reach on
-- their own, so a goal is ongoing until a spec raises the level.
local STICKY_TEXT = table.concat({
	"#chapter 1-12 Sticky",
	"step",
	"  .accept 101",
	"  .sticky .level 15",
	"step",
	"  .complete 101",
	"step",
	"  .turnin 101",
	"  .accept 102",
	"step",
	"  .complete 102",
	"step",
	"  .turnin 102",
	"",
}, "\n")

local function stickyGuide(ns)
	assert.is_true(ns.Chapters:Register("stk", STICKY_TEXT))
	assert.is_true(ns.Guides:Register({
		id = "stk-place",
		name = "Sticky",
		faction = "*",
		races = { "*" },
		classes = { "*" },
		levels = { 1, 12 },
		text = "#include stk\n",
	}))
end

-- the steps with a goal going beside the route, as ids
local function ongoing(ns)
	local ids = {}
	for _, step in ipairs(ns.Progress:Sticky()) do
		ids[#ids + 1] = step.id
	end
	return ids
end

local function boars(have)
	return quest(101, { objectives = { objective("Boars", have or 0, 3) } })
end

-- A session of the sticky guide; opts as for start(). A character with no completed quest has no list to wait for only
-- after the wait is over, so those sessions let it pass.
local function stickySession(opts)
	opts.noGuide, opts.setup = true, stickyGuide
	return start(opts)
end

describe("the goals of the steps a placement passes", function()
	-- a walker: logs in at level 1 with nothing done and takes the first quest
	local function walker()
		local ns, world, mock = stickySession({ level = 1 })
		world.log = { boars() }
		mock.fire("QUEST_ACCEPTED", 101)
		world.advance(1.5)
		return ns, world, mock
	end

	it("has the same ongoing goals for a character placed at a step as for one that walked to it", function()
		local walked = walker()
		assert.are.equal("stk:2", current(walked))
		assert.are.same({ "stk:1" }, ongoing(walked))
		-- the same character at a later login: placed, by the quest in its log and its level (no quest is done, so the
		-- list of completed quests is empty and the placement waits for it)
		local placed = stickySession({ level = 4, log = { boars() }, advance = 6 })
		assert.are.equal("stk:2", current(placed))
		assert.are.equal("first", placed.char.progress["stk-place"].placed.reason)
		assert.are.same(ongoing(walked), ongoing(placed))
		-- and the goal ends the same way: at level 15 neither has it any more
		local ns, world, mock = stickySession({ level = 4, log = { boars() }, advance = 6 })
		assert.are.same({ "stk:1" }, ongoing(ns))
		world.level = 15
		mock.fire("PLAYER_LEVEL_UP", 15)
		world.advance(2)
		assert.are.same({}, ongoing(ns))
	end)

	it("does not start a goal that is met already, nor the goal of a step it marks skipped", function()
		-- everything done: the placement is at the end, the first step done and its goal met at level 15
		local met = stickySession({ level = 15, completed = { 101, 102 } })
		assert.is_true(met.Progress:IsDone("stk:1"))
		assert.are.same({}, ongoing(met))
		-- the same at level 9: the goal is not met, and is going
		local notYet = stickySession({ level = 9, completed = { 101, 102 } })
		assert.is_true(notYet.Progress:IsDone("stk:1"))
		assert.are.same({ "stk:1" }, ongoing(notYet))
		-- a character that did the end of the guide and not its beginning: step 1 is skipped, and a skipped step's goal is
		-- dismissed
		local skipped = stickySession({ level = 9, completed = { 102 } })
		assert.is_true(skipped.Progress:IsSkipped("stk:1"))
		assert.are.same({}, ongoing(skipped))
	end)

	it("starts the goal when the player asks to be placed, and tells the step card", function()
		local ns, world = walker()
		wipe(ns.char.progress["stk-place"].sticky) -- a record that did not keep the goal (a walk before it was kept)
		assert.are.same({}, ongoing(ns))
		local heard = {}
		ns.Events:RegisterMessage("STICKY_CHANGED", function(_, list)
			heard[#heard + 1] = #list
		end)
		world.level = 4
		ns.Context:Invalidate("level")
		slash("place")
		assert.are.same({ "stk:1" }, ongoing(ns))
		world.advance(0.5)
		assert.are.same({ 1 }, heard)
	end)

	-- `<` takes a placement back: the pointer, the marks (done, skipped), the goals and the furthest step as they were.
	-- Each of these has marks that differ before and after the placement, or the undo would look right whatever it did.
	describe("and `<` right after Find my place", function()
		it("gives back the goal the placement dismissed", function()
			local ns, world, mock = walker()
			assert.are.same({ "stk:1" }, ongoing(ns))
			-- the quest is dropped and the character is at level 4: nothing says it took step 1, which is now skipped
			world.log = {}
			world.level = 4
			mock.fire("PLAYER_LEVEL_UP", 4)
			mock.fire("QUEST_REMOVED", 101)
			world.advance(2)
			assert.are.equal("stk:2", current(ns))
			slash("place")
			assert.is_true(ns.Progress:IsSkipped("stk:1"))
			assert.are.same({}, ongoing(ns))
			slash("back")
			assert.are.equal("stk:2", current(ns))
			assert.are.same({ "stk:1" }, ongoing(ns))
			assert.is_false(ns.Progress:IsSkipped("stk:1"))
			assert.is_true(ns.Progress:IsDone("stk:1"))
		end)

		it("gives back a skip the placement cleared, on a step other than the one it returns to", function()
			local ns = stickySession({ level = 4, log = { boars() }, advance = 6 })
			assert.are.equal("stk:2", current(ns))
			slash("step 4")
			slash("skip") -- stk:4 is skipped by hand, and the pointer goes on to stk:5
			assert.are.equal("stk:5", current(ns))
			assert.is_true(ns.Progress:IsSkipped("stk:4"))
			slash("place") -- back to where the quests say, stk:2, with the marks from there on cleared
			assert.are.equal("stk:2", current(ns))
			assert.is_false(ns.Progress:IsSkipped("stk:4"))
			slash("back")
			assert.are.equal("stk:5", current(ns))
			assert.is_true(ns.Progress:IsSkipped("stk:4"))
			assert.is_true(ns.Progress:IsDone("stk:1"))
		end)

		it("gives back the furthest step reached, which decides whether a press of > is held", function()
			local ns, world = stickySession({ level = 1 })
			assert.are.equal("stk:1", current(ns))
			-- the first quest is done by now: Find my place takes the character to stk:3, the furthest step so far
			world.completed = { 101 }
			slash("place")
			assert.are.equal("stk:3", current(ns))
			slash("back")
			assert.are.equal("stk:1", current(ns))
			-- from the front the engine passes what is done, as for a walker: > goes on to stk:3 (stk:2 is done); with the
			-- furthest step still stk:3 it would be held at stk:2
			slash("next")
			assert.are.equal("stk:3", current(ns))
		end)

		it("keeps the furthest step reached when it was beyond the step it returns to", function()
			local ns, world = stickySession({ level = 1 })
			slash("step 3") -- the furthest step reached is stk:3 ...
			slash("back")
			slash("back")
			assert.are.equal("stk:1", current(ns)) -- ... and the pointer is back at stk:1
			world.completed = { 101 }
			slash("place")
			assert.are.equal("stk:3", current(ns))
			slash("back")
			assert.are.equal("stk:1", current(ns))
			-- behind the furthest step > goes one step at a time, and holds the step it lands on (stk:2 is done, and is
			-- not passed); with the furthest step lost it would be passed at once
			slash("next")
			assert.are.equal("stk:2", current(ns))
		end)
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
