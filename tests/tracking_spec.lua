-- Engine/Tracking.lua: the quest log's tracked quests follow the current step. The real modules (Context, Events,
-- Tracking, the UI) on the scripted client of tests/mocks/context.lua, whose quest log has a watch list in both API
-- shapes; ns.Progress is a stand-in whose guide and current step the test sets (tests/integration_spec.lua walks the
-- real one).
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local quest, objective = contextMock.quest, contextMock.objective

local sessions = {}

after_each(function()
	for _, session in ipairs(sessions) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
	sessions = {}
	contextMock.uninstall()
end)

-- A quest log of quests that are not done yet; opts.log = { questID or quest entry, ... }, opts.watch the tracked
-- ones to begin with, opts.enabled = false the player's choice (the setting is chosen explicitly, so these specs do
-- not depend on the default), opts.guide = false no guide is active, opts.setup(world) runs before any file loads.
-- Returns a session with the world, the namespace and the helpers `step` (a step from directive lines), `enter` (a
-- step becomes current) and `settle` (the client's events and timers run).
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
	ns.db.settings.trackStepQuests = opts.enabled ~= false
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

local function forget(world)
	world.watchCalls = {}
end

local function accept(s, questID)
	s.world.log[#s.world.log + 1] = quest(questID, { objectives = { objective("New", 0, 1) } })
end

describe("quest tracking follows the step", function()
	it("untracks every other quest and tracks those of the step's .complete and .turnin lines", function()
		local s = start()
		s.enter(s.step("t:1", ".goto 1411,10,10", ".complete 101", ".turnin 102", ".accept 105"))
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.are.same({ "remove 103", "remove 104", "add 102" }, changes(s.world)) -- 101 was tracked already
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

	it("does nothing when the player turned it off, and does not put anything back", function()
		local s = start({ enabled = false })
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		assert.are.same({}, s.world.watchCalls)
		assert.is_false(s.ns.Tracking:Enabled())
	end)

	it("follows the module's default until the player chooses, and saves only the choice", function()
		local s = start()
		local Tracking = s.ns.Tracking
		s.ns.db.settings.trackStepQuests = nil
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

	it("acts only while a guide is active", function()
		local s = start({ guide = false })
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		s.ns.Tracking:SetEnabled(true) -- turned on without a guide: nothing to follow
		assert.are.same({}, s.world.watchCalls)
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

describe("quest tracking when the client's API differs or fails", function()
	it("falls back to the Classic functions on quest log numbers", function()
		local s = start({
			setup = function(world)
				world.useClassicWatch()
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".turnin 102"))
		assert.are.same({ 101, 102 }, s.world.watch)
		-- the quests are the 1st to 4th of the quest log: 103 and 104 go, 102 comes
		assert.are.same({ "remove 3", "remove 4", "add 2" }, changes(s.world))
		assert.is_nil(s.world.superTracked) -- no C_SuperTrack in this shape
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
		assert.are.same({ "remove 3", "remove 4", "remove 1", "add 2" }, changes(s.world))
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

	it("never lets an API that raises stop the step engine", function()
		for _, name in ipairs({
			"AddQuestWatch",
			"RemoveQuestWatch",
			"GetQuestWatchType",
			"GetNumQuestWatches",
			"GetQuestIDForQuestWatchIndex",
			"SetSuperTrackedQuestID",
		}) do
			local s = start({
				setup = function(world)
					world.watchFails[name] = true
				end,
			})
			s.enter(s.step("t:1", ".complete 101", ".complete 102"))
			assert.is_true(#s.world.watchCalls > 0, name)
			-- and the engine is still listening: the next step is followed all the same
			s.world.watchFails[name] = nil
			s.enter(s.step("t:2", ".complete 103"))
			assert.are.same({ 103 }, s.world.watch, name)
		end
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

	it("keeps going when the client refuses to track more quests than it allows", function()
		local s = start({ watch = {} })
		s.world.watchLimit = 1
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ 101 }, s.world.watch)
		-- what the client left is what it expected: the player is not blamed for the refused quest
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.is_false(s.ns.Tracking.state.manual)
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

	it("leaves the tracking alone once the guide is gone or the player turns the setting off", function()
		for _, stop in ipairs({
			function(s)
				s.hasGuide = false
			end,
			function(s)
				s.ns.Tracking:SetEnabled(false)
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
