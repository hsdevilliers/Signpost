-- Engine/Tracking.lua: the quest log's tracked quests follow the current step. The real modules (Context, Events,
-- Tracking, the UI) on the scripted client of tests/mocks/context.lua, whose quest log has a watch list in both API
-- shapes; ns.Progress is a stand-in whose guide and current step the test sets (tests/integration_spec.lua walks the
-- real one).
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local quest, objective, header = contextMock.quest, contextMock.objective, contextMock.header

local sessions = {}

after_each(function()
	local checked = sessions
	sessions = {}
	contextMock.uninstall()
	for _, session in ipairs(checked) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
end)

-- A quest log of quests that are not done yet; opts.log = { questID or quest entry, ... }, opts.watch the tracked
-- ones to begin with, opts.enabled = false the player's choice (the setting is chosen explicitly, so these specs do
-- not depend on the default; opts.enabled = "default" leaves it unchosen), opts.guide = false no guide is active,
-- opts.setup(world) runs before any file loads. Returns a session with the world, the namespace and the helpers `step`
-- (a step from directive lines), `enter` (a step becomes current), `settle` (the client's events and timers run) and
-- `errors` (what the module recorded in the error log, which it empties).
local function start(opts)
	opts = opts or {}
	local world
	local ns, mock = addon.load({
		login = false,
		before = function(m)
			world = contextMock.install(m)
			world.log = {}
			for _, entry in ipairs(opts.log or { 101, 102, 103, 104 }) do
				world.log[#world.log + 1] = type(entry) == "table" and entry
					or quest(entry, { objectives = { objective("Things", 0, 3) } })
			end
			world.watch = opts.watch or { 103, 104, 101 }
			if opts.setup then
				opts.setup(world)
			end
		end,
	})
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	world.advance(1)
	local session = { ns = ns, mock = mock, world = world, hasGuide = opts.guide ~= false }
	ns.Progress = {
		Guide = function()
			if session.hasGuide then
				return {}
			end
		end,
		Current = function()
			return session.current, 1
		end,
	}
	if opts.enabled ~= "default" then
		ns.db.settings.trackStepQuests = opts.enabled ~= false
	end
	-- A step as the parser builds it: step("t:1", ".goto 1411,10,10", ".complete 101").
	function session.step(id, ...)
		local directives = {}
		for i, line in ipairs({ ... }) do
			directives[i] = assert(ns.Directives:ParseLine(line, { source = "test", line = i }))
		end
		return { id = id, directives = directives, sticky = {}, optional = {} }
	end
	function session.enter(current)
		session.current = current
		ns.Events:Fire("STEP_CHANGED", current, 1, "auto")
	end
	-- The client says something changed: the event, then enough time for Context's refresh and its CONTEXT_CHANGED.
	function session.settle(event, ...)
		if event then
			mock.fire(event, ...)
		end
		world.advance(1.1)
	end
	function session.errors()
		local list, taken = ns.db.errors, {}
		for i = #list, 1, -1 do
			table.insert(taken, 1, table.remove(list, i).msg)
		end
		return taken
	end
	sessions[#sessions + 1] = session
	return session
end

-- Every call that changed the watch list, as "add 102" / "remove 103" (a quest ID, or a quest log number in the Classic
-- shape).
local function changes(world)
	local list = {}
	for _, call in ipairs(world.watchCalls) do
		if call[1] == "AddQuestWatch" then
			list[#list + 1] = "add " .. tostring(call[2])
		elseif call[1] == "RemoveQuestWatch" then
			list[#list + 1] = "remove " .. tostring(call[2])
		end
	end
	return list
end

-- Whether the client was told to point the tracker at a quest.
local function focused(world)
	for _, call in ipairs(world.watchCalls) do
		if call[1] == "SetSuperTrackedQuestID" then
			return true
		end
	end
	return false
end

local function forget(world)
	world.watchCalls = {}
end

local function accept(s, questID)
	s.world.log[#s.world.log + 1] = quest(questID, { objectives = { objective("New", 0, 1) } })
end

describe("quest tracking follows the step", function()
	it("tracks the quests of the step's .complete and .turnin lines, then untracks every other quest", function()
		local s = start()
		s.enter(s.step("t:1", ".goto 1411,10,10", ".complete 101", ".turnin 102", ".accept 105"))
		assert.are.same({ 101, 102 }, s.world.watch)
		-- 101 was tracked already; the step's quest first, the others after
		assert.are.same({ "add 102", "remove 103", "remove 104" }, changes(s.world))
	end)

	it("points the tracker at the first quest of the step that is not complete yet", function()
		local s = start({
			log = {
				quest(101, { objectives = { objective("Done", 3, 3) } }),
				quest(102, { objectives = { objective("Not yet", 1, 3) } }),
				quest(103, { objectives = { objective("Not yet", 1, 3) } }),
			},
			watch = {},
		})
		s.enter(s.step("t:1", ".complete 101", ".complete 102", ".complete 103"))
		assert.are.equal(102, s.world.superTracked)
		-- a step whose quests are all complete leaves the focus where it was
		s.world.superTracked = nil
		s.enter(s.step("t:2", ".turnin 101"))
		assert.is_nil(s.world.superTracked)
	end)

	it("skips a quest that is not in the quest log", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 101", ".complete 999", ".turnin 998"))
		assert.are.same({ 101 }, s.world.watch)
		assert.are.same({ "remove 103", "remove 104" }, changes(s.world))
	end)

	it("names a quest once, however many lines are about it", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 102", ".turnin 102"))
		assert.are.same({ "add 102" }, changes(s.world))
	end)

	it("leaves the tracking alone for a step that names no quest in the log", function()
		local s = start()
		s.enter(s.step("t:1", ".goto 1411,10,10", ".accept 105", ".note Mind the boars."))
		s.enter(s.step("t:2", ".turnin 999")) -- named, but not in the log
		s.enter(s.step("t:3", ".level 5"))
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		assert.are.same({}, s.world.watchCalls)
	end)

	it("treats a quest the game tracked by itself (the automatic watch type, 0) as tracked", function()
		local s = start({
			watch = { 103, 101 },
			setup = function(world)
				G.Enum.QuestWatchType = { Automatic = 0, Manual = 1 }
				world.watchTypes[101] = 0
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.are.same({ "add 102", "remove 103" }, changes(s.world)) -- 101 is not added again
	end)

	it("passes the manual watch type when the client has one", function()
		local s = start({
			watch = {},
			setup = function()
				G.Enum.QuestWatchType = { Automatic = 0, Manual = 1 }
			end,
		})
		s.enter(s.step("t:1", ".complete 101"))
		local add
		for _, call in ipairs(s.world.watchCalls) do
			if call[1] == "AddQuestWatch" then
				add = call
			end
		end
		assert.are.same({ "AddQuestWatch", 101, 1 }, add)
	end)
end)

describe("quest tracking: when it acts", function()
	it("is on by default, which the user chose (2026-10-20), until the player says otherwise", function()
		local s = start({ enabled = "default" })
		assert.is_true(s.ns.Tracking.DEFAULT_ENABLED)
		assert.is_nil(s.ns.db.settings.trackStepQuests)
		assert.is_true(s.ns.Tracking:Enabled())
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("follows the module's default until the player chooses, and saves only the choice", function()
		local s = start({ enabled = "default" })
		local Tracking = s.ns.Tracking
		Tracking.DEFAULT_ENABLED = false
		assert.is_false(Tracking:Enabled())
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({}, s.world.watchCalls)
		Tracking.DEFAULT_ENABLED = true
		assert.is_true(Tracking:Enabled())
		s.enter(s.step("t:2", ".complete 101"))
		assert.are.same({ 101 }, s.world.watch)
		assert.is_nil(s.ns.db.settings.trackStepQuests)
		Tracking:SetEnabled(false)
		assert.is_false(s.ns.db.settings.trackStepQuests)
		assert.is_false(Tracking:Enabled())
	end)

	it("does nothing when the player turned it off, and does not put anything back", function()
		local s = start({ enabled = false })
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		assert.are.same({}, s.world.watchCalls)
		assert.is_false(s.ns.Tracking:Enabled())
	end)

	it("acts only while a guide is active", function()
		local s = start({ guide = false })
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		s.ns.Tracking:SetEnabled(true) -- turned on without a guide: nothing to follow
		assert.are.same({}, s.world.watchCalls)
	end)

	it("does nothing at all while the step card is hidden, and acts again once it is shown", function()
		local s = start({ watch = {} })
		G.SlashCmdList.SIGNPOST("hide") -- the saved flag, as the Journal's "Show the step card" box sets it
		assert.is_false(s.ns.db.stepFrame.shown)
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		accept(s, 105)
		table.insert(s.world.watch, 105)
		s.settle("QUEST_ACCEPTED", 105)
		s.ns.Tracking:SetEnabled(true) -- not even when the setting is turned on
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({ 105 }, s.world.watch)
		G.SlashCmdList.SIGNPOST("show")
		s.enter(s.step("t:2", ".complete 101"))
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("is not stopped by the card's own hides in combat, when dead or while the Journal is open", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101")) -- builds the card
		local frame = s.ns.StepFrame.frame
		assert.is_true(frame:IsShown())
		local hides = {
			combat = function()
				s.mock.fire("PLAYER_REGEN_DISABLED")
			end,
			dead = function()
				G.UnitIsDeadOrGhost = function()
					return true
				end
				s.mock.fire("PLAYER_DEAD")
			end,
			journal = function()
				s.ns.Journal = {
					IsShown = function()
						return true
					end,
				}
				s.ns.StepFrame:UpdateVisibility()
			end,
		}
		for name, hide in pairs(hides) do
			frame:Show()
			s.ns.StepFrame.inCombat = false
			G.UnitIsDeadOrGhost, s.ns.Journal = nil, nil
			s.world.watch = {}
			hide()
			assert.is_false(frame:IsShown(), name) -- the card hides itself...
			s.enter(s.step("t:" .. name, ".complete 101"))
			assert.are.same({ 101 }, s.world.watch, name) -- ...and the tracker follows the step all the same
		end
		G.UnitIsDeadOrGhost = nil
	end)

	it("takes effect at once when turned on, and leaves the tracking as it is when turned off", function()
		local s = start({ enabled = false })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({}, s.world.watchCalls)
		s.ns.Tracking:SetEnabled(true)
		assert.are.same({ 101, 102 }, s.world.watch)
		forget(s.world)
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.are.same({}, s.world.watchCalls)
	end)
end)

describe("quest tracking: where the focus goes", function()
	it("points the tracker once for a step that began, not again when the same step is announced again", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.equal(101, s.world.superTracked)
		s.world.superTracked = nil
		forget(s.world)
		s.enter(s.step("t:1", ".complete 101", ".complete 102")) -- a re-parse: the same step, a new table
		assert.is_false(focused(s.world))
		s.enter(s.step("t:2", ".complete 102")) -- another step
		assert.is_true(focused(s.world))
		assert.are.equal(102, s.world.superTracked)
	end)

	it("leaves the focus alone when it already points at one of the step's quests", function()
		local s = start({
			watch = {},
			setup = function(world)
				world.superTracked = 102
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.is_false(focused(s.world))
		assert.are.equal(102, s.world.superTracked)
		assert.are.same({ 101, 102 }, s.world.watch)
	end)

	it("does not move the focus when the quest log changes during the step", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		s.world.superTracked = nil
		accept(s, 105)
		table.insert(s.world.watch, 105)
		forget(s.world)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.same({ "remove 105" }, changes(s.world)) -- the tracking was set again...
		assert.is_false(focused(s.world)) -- ...and the focus left alone
		assert.is_nil(s.world.superTracked)
	end)

	it("points the tracker at the step's quests when they arrive after the step began, once", function()
		local s = start({ log = {}, watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102")) -- the quest log has not loaded yet
		assert.are.same({}, s.world.watchCalls)
		s.world.log = { quest(101, { objectives = { objective("A", 0, 3) } }), quest(102, { objectives = {} }) }
		s.settle("QUEST_LOG_UPDATE")
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.are.equal(101, s.world.superTracked)
		s.world.superTracked = nil
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.is_nil(s.world.superTracked) -- not again
	end)
end)

describe("quest tracking when the client's API differs or fails", function()
	it("falls back to the Classic functions on quest log numbers", function()
		local s = start({
			setup = function(world)
				world.useClassicWatch()
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".turnin 102"))
		assert.are.same({ 101, 102 }, s.world.watch)
		-- the quests are the 1st to 4th of the quest log: 102 comes, 103 and 104 go
		assert.are.same({ "add 2", "remove 3", "remove 4" }, changes(s.world))
		assert.is_nil(s.world.superTracked) -- no C_SuperTrack in this shape
	end)

	it("finds the quest log numbers by walking the log when the client has no function for them", function()
		local s = start({
			log = { header("Durotar", false), 101, 102, 103, 104 },
			setup = function(world)
				world.useClassicWatch()
				G.C_QuestLog.GetLogIndexForQuestID, G.C_QuestLog.GetQuestIDForLogIndex = nil, nil
			end,
			watch = { 103, 104, 101 },
		})
		s.enter(s.step("t:1", ".complete 101", ".turnin 102"))
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.are.same({ "add 3", "remove 4", "remove 5" }, changes(s.world)) -- a header is the 1st entry
	end)

	it("takes the Classic functions when C_QuestLog has only one of AddQuestWatch and RemoveQuestWatch", function()
		local s = start({
			setup = function(world)
				world.useClassicWatch()
				-- an incomplete retail shape: the retail function that is there must not be the one used
				G.C_QuestLog.AddQuestWatch = function()
					error("not this one")
				end
			end,
		})
		s.enter(s.step("t:1", ".complete 102"))
		assert.are.same({ 102 }, s.world.watch)
		assert.are.same({ "add 2", "remove 3", "remove 4", "remove 1" }, changes(s.world))
	end)

	it("copes with a client that has neither shape", function()
		local s = start({
			setup = function(world)
				world.useClassicWatch()
				G.AddQuestWatch, G.RemoveQuestWatch = nil, nil
			end,
		})
		s.enter(s.step("t:1", ".complete 102"))
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		assert.are.same({}, s.world.watchCalls)
	end)

	it("leaves the tracker as it was when AddQuestWatch raises, says so once and stops", function()
		local s = start({
			log = { 101, 102, 103 },
			watch = { 102, 103 },
			setup = function(world)
				world.watchFails.AddQuestWatch = true
			end,
		})
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({ 102, 103 }, s.world.watch) -- nothing was untracked
		assert.are.same({ "add 101" }, changes(s.world)) -- the add that raised was tried; no removal followed
		assert.is_true(s.ns.Tracking.failed)
		local errors = s.errors()
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("quest tracking stopped", 1, true))
		-- it stays stopped for the next steps, quietly
		forget(s.world)
		s.world.watchFails.AddQuestWatch = nil
		s.enter(s.step("t:2", ".complete 102"))
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({}, s.errors())
		-- until the setting is toggled
		s.ns.Tracking:SetEnabled(false)
		s.ns.Tracking:SetEnabled(true)
		assert.is_false(s.ns.Tracking.failed)
		assert.are.same({ 102 }, s.world.watch)
	end)

	it("leaves the tracker as it was when the client refuses every quest, says so once and stops", function()
		local s = start({
			log = { 101, 102 },
			watch = { 102 },
			setup = function(world)
				world.watchLimit = 0
			end,
		})
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({ 102 }, s.world.watch)
		for _, call in ipairs(s.world.watchCalls) do
			assert.are_not.equal("RemoveQuestWatch", call[1])
		end
		assert.is_true(s.ns.Tracking.failed)
		assert.are.equal(1, #s.errors())
		forget(s.world)
		s.enter(s.step("t:2", ".complete 102"))
		assert.are.same({}, s.world.watchCalls)
	end)

	it("keeps going when the client tracks some of the step's quests and refuses the rest", function()
		local s = start({ watch = {} })
		s.world.watchLimit = 1
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ 101 }, s.world.watch)
		assert.is_false(s.ns.Tracking.failed)
		-- what the client left is what it expected: the player is not blamed for the refused quest
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.is_false(s.ns.Tracking.state.manual)
	end)

	it("adds the quests a full tracker refused once it has made room", function()
		local s = start({ log = { 101, 102, 103 }, watch = { 103 } })
		s.world.watchLimit = 2
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		-- 101 fits; 102 is refused until 103 is gone
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.is_false(s.ns.Tracking.failed)
	end)

	it("never lets an API that raises stop the step engine", function()
		for _, name in ipairs({
			"RemoveQuestWatch",
			"GetNumQuestWatches",
			"GetQuestIDForQuestWatchIndex",
			"SetSuperTrackedQuestID",
			"GetSuperTrackedQuestID",
		}) do
			local s = start({
				setup = function(world)
					world.watchFails[name] = true
				end,
			})
			s.enter(s.step("t:1", ".complete 101", ".complete 102"))
			assert.is_true(#s.world.watchCalls > 0, name)
			assert.is_false(s.ns.Tracking.failed, name)
			-- and the engine is still listening: the next step is followed all the same
			s.world.watchFails[name] = nil
			s.enter(s.step("t:2", ".complete 103"))
			assert.are.same({ 103 }, s.world.watch, name)
		end
	end)

	it("cannot confirm a quest is tracked when GetQuestWatchType raises: it stops, untracking nothing", function()
		local s = start({
			setup = function(world)
				world.watchFails.GetQuestWatchType = true
			end,
		})
		s.enter(s.step("t:1", ".complete 102"))
		-- the step's quest was added (that works), but nothing could confirm it, so nothing was untracked
		assert.are.same({ 103, 104, 101, 102 }, s.world.watch)
		assert.is_true(s.ns.Tracking.failed)
		assert.are.equal(1, #s.errors())
	end)

	it("still untracks the others when the watch list cannot be listed", function()
		local s = start({
			setup = function(world)
				world.watchFails.GetNumQuestWatches = true
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ 101, 102 }, s.world.watch)
	end)

	it("asks the watch list when the client has no GetQuestWatchType", function()
		local s = start({
			watch = {},
			setup = function()
				G.C_QuestLog.GetQuestWatchType = nil
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.is_false(s.ns.Tracking.failed)
	end)
end)

describe("quest tracking while the step is current", function()
	it("untracks a quest the player accepts meanwhile, once the quest log changes", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ 101, 102 }, s.world.watch)
		-- the game tracks a new quest as it is accepted; the step is not about it
		accept(s, 105)
		table.insert(s.world.watch, 105)
		forget(s.world)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.are.same({ "remove 105" }, changes(s.world))
		assert.is_false(s.ns.Tracking.state.manual)
	end)

	it("tracks a quest of the step that was not in the log when the step began, once it is", function()
		local s = start({ log = { 101, 103 }, watch = { 103 } })
		s.enter(s.step("t:1", ".complete 101", ".complete 106"))
		assert.are.same({ 101 }, s.world.watch)
		s.world.log[#s.world.log + 1] = quest(106, { objectives = { objective("Late", 0, 1) } })
		s.settle("QUEST_ACCEPTED", 106)
		assert.are.same({ 101, 106 }, s.world.watch)
	end)

	it("asks nothing of the client when only a quest's progress changes", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101"))
		forget(s.world)
		s.world.log[1].objectives = { objective("Things", 2, 3) }
		s.settle("QUEST_LOG_UPDATE")
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("lets go of a quest that was abandoned without putting anything back", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.remove(s.world.log, 2) -- 102 is abandoned; the game drops it from the watch list too
		table.remove(s.world.watch, 2)
		forget(s.world)
		s.settle("QUEST_REMOVED", 102)
		assert.are.same({}, changes(s.world))
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("leaves the tracking alone once the guide is gone or the player turns the setting off", function()
		for _, stop in ipairs({
			function(s)
				s.hasGuide = false
			end,
			function(s)
				s.ns.Tracking:SetEnabled(false)
			end,
			function()
				G.SlashCmdList.SIGNPOST("hide")
			end,
		}) do
			local s = start({ watch = {} })
			s.enter(s.step("t:1", ".complete 101"))
			stop(s)
			accept(s, 105)
			table.insert(s.world.watch, 105)
			forget(s.world)
			s.settle("QUEST_ACCEPTED", 105)
			assert.are.same({}, s.world.watchCalls)
			assert.are.same({ 101, 105 }, s.world.watch)
		end
	end)

	it("does not fight the player: after a change by hand it stays hands off until the step changes", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 103) -- the player tracks another quest
		-- a quest is accepted, which would have sent the tracker back to the step's quests
		accept(s, 105)
		table.insert(s.world.watch, 105)
		forget(s.world)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.same({}, changes(s.world))
		assert.are.same({ 101, 102, 103, 105 }, s.world.watch)
		assert.is_true(s.ns.Tracking.state.manual)
		-- and it stays that way for the rest of the step, whatever else happens to the quest log
		table.remove(s.world.log, 4) -- 104 is abandoned
		s.settle("QUEST_REMOVED", 104)
		assert.are.same({}, changes(s.world))
		-- the next step is a new start
		s.enter(s.step("t:2", ".complete 102"))
		assert.are.same({ 102 }, s.world.watch)
		assert.is_false(s.ns.Tracking.state.manual)
	end)

	it("stays hands off even when the player puts their change back", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 103) -- tracked by hand...
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105) -- ...noticed at the next change of the quest log
		assert.is_true(s.ns.Tracking.state.manual)
		table.remove(s.world.watch, 3) -- ...and untracked again: the tracker looks as the module left it
		accept(s, 106)
		table.insert(s.world.watch, 106)
		forget(s.world)
		s.settle("QUEST_ACCEPTED", 106)
		assert.are.same({}, changes(s.world))
		assert.are.same({ 101, 102, 106 }, s.world.watch)
	end)

	it("takes a step quest the player untracked for their choice as well", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.remove(s.world.watch, 1) -- the player stops tracking 101
		accept(s, 105)
		forget(s.world)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.same({}, changes(s.world))
		assert.are.same({ 102 }, s.world.watch)
	end)
end)

describe("quest tracking and the quest log's collapsed headers", function()
	-- A header the player collapsed hides its quests from the walk of the log; they are still in it.
	local function collapsedLog()
		return {
			header("Durotar", true),
			quest(101, { objectives = { objective("A", 0, 3) } }),
			quest(102, { objectives = { objective("B", 0, 3) } }),
			header("Orgrimmar", false),
			quest(103, { objectives = { objective("C", 0, 3) } }),
		}
	end

	it("tracks and keeps a step quest that sits under a collapsed header", function()
		local s = start({
			log = collapsedLog(),
			watch = { 101, 103 },
			setup = function(world)
				world.hideCollapsed = true
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".complete 103"))
		assert.are.same({ 101, 103 }, s.world.watch)
		assert.are.same({}, changes(s.world))
		-- one that is not tracked yet is tracked all the same
		s.enter(s.step("t:2", ".complete 102", ".complete 103"))
		assert.are.same({ 103, 102 }, s.world.watch)
		assert.are.same({ "add 102", "remove 101" }, changes(s.world))
	end)

	it("does not set the tracking again when a header is collapsed or expanded", function()
		local s = start({
			log = { header("Durotar", false), 101, 102, 103 },
			watch = {},
			setup = function(world)
				world.hideCollapsed = true
			end,
		})
		s.enter(s.step("t:1", ".complete 101"))
		s.world.superTracked = nil
		forget(s.world)
		s.world.log[1].collapsed = true -- the quests drop out of the walk of the log
		s.settle("QUEST_LOG_UPDATE")
		assert.are.same({}, s.world.watchCalls)
		s.world.log[1].collapsed = false
		s.settle("QUEST_LOG_UPDATE")
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({ 101 }, s.world.watch)
		assert.is_false(s.ns.Tracking.state.manual)
	end)
end)

describe("quest tracking when the same step is announced again", function()
	it("keeps the decision to stay hands off", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 103) -- by hand
		accept(s, 105)
		table.insert(s.world.watch, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.is_true(s.ns.Tracking.state.manual)
		forget(s.world)
		s.enter(s.step("t:1", ".complete 101", ".complete 102")) -- the engine parsed the guide again
		assert.is_true(s.ns.Tracking.state.manual)
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({ 101, 102, 103, 105 }, s.world.watch)
	end)

	it("otherwise sets the tracking again, without moving the focus", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		s.world.superTracked = nil
		table.insert(s.world.watch, 103) -- something the module did not set, which nobody has noticed yet
		forget(s.world)
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ "remove 103" }, changes(s.world))
		assert.is_false(focused(s.world))
		assert.are.same({ 101, 102 }, s.world.watch)
	end)

	it("is a new start when the setting is turned on again", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 103)
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.is_true(s.ns.Tracking.state.manual)
		s.ns.Tracking:SetEnabled(false)
		s.ns.Tracking:SetEnabled(true)
		assert.is_false(s.ns.Tracking.state.manual)
		assert.are.same({ 101, 102 }, s.world.watch)
	end)
end)
