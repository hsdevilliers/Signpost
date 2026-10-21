-- Engine/Tracking.lua: the quest log's tracked quests follow the current step: its state machine (idle, following,
-- backed off for the player, backed off for the client, restoring), the player's earlier tracking given back, the
-- retries with a back-off, the step card shown again, the game's own tracking told from the player's, what a reload
-- keeps, /signpost tracking and /signpost tracking test, and the quest log capacity probe of Core/Probe.lua. The real
-- modules (Context, Events, Tracking, the UI) on the scripted client of tests/mocks/context.lua, whose quest log has a
-- watch list in both API shapes; ns.Progress is a stand-in whose guide and current step the test sets
-- (tests/integration_spec.lua walks the real one).
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local quest, objective, header = contextMock.quest, contextMock.objective, contextMock.header

local sessions = {}
-- Client globals some specs define that neither the mocks nor the addon clear.
local OWN_GLOBALS = { "InCombatLockdown", "MAX_QUESTLOG_QUESTS", "MAX_WATCHABLE_QUESTS", "Constants" }

after_each(function()
	local checked = sessions
	sessions = {}
	contextMock.uninstall()
	for _, name in ipairs(OWN_GLOBALS) do
		G[name] = nil
	end
	for _, session in ipairs(checked) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
end)

-- A quest log of quests that are not done yet; opts.log = { questID or quest entry, ... }, opts.watch the tracked
-- ones to begin with, opts.enabled = false the player's choice (the setting is chosen explicitly, so these specs do
-- not depend on the default; opts.enabled = "default" leaves it unchosen), opts.guide = false no guide is active,
-- opts.charDB / opts.accountDB the saved variables a reload brings back, opts.setup(world) runs before any file
-- loads. Returns a session with the world, the namespace and the helpers `step` (a step from directive lines), `enter`
-- (a step becomes current), `settle` (the client's events and timers run) and `errors` (what the module recorded in
-- the error log, which it empties).
local function start(opts)
	opts = opts or {}
	local world
	local ns, mock = addon.load({
		login = false,
		before = function(m)
			if opts.charDB then
				G.SignpostCharDB = opts.charDB
			end
			if opts.accountDB then
				G.SignpostDB = opts.accountDB
			end
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

-- The module's state, as /signpost tracking names it.
local function mode(s)
	return s.ns.Tracking.state.mode
end

-- Whether the chat has said this (plain text, the addon's colored prefix left out).
local function said(s, text)
	for _, line in ipairs(s.mock.printed) do
		if line:find(text, 1, true) then
			return true
		end
	end
	return false
end

-- How many times the client was asked to track (AddQuestWatch) or untrack a quest.
local function writes(world, name)
	local count = 0
	for _, call in ipairs(world.watchCalls) do
		if call[1] == name then
			count = count + 1
		end
	end
	return count
end

-- The same character after a /reload: SignpostCharDB and SignpostDB come back from "disk", the quest log and the
-- tracker stay as the server has them, the addon and its modules load again, nothing is announced yet (a step is
-- entered by the test, as the engine's first STEP_CHANGED would).
local function reload(s, opts)
	opts = opts or {}
	local char, account = s.ns.Util.CopyTable(s.ns.char), s.ns.Util.CopyTable(s.ns.db)
	local log, watch = s.world.log, s.world.watch
	contextMock.uninstall()
	opts.log, opts.watch, opts.charDB, opts.accountDB = log, watch, char, account
	opts.enabled = opts.enabled or "default"
	return start(opts)
end

-- Watch types, as Mainline has them: the game's own tracking is Automatic.
local function watchTypes()
	G.Enum.QuestWatchType = { Automatic = 0, Manual = 1 }
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

	it(
		"is not about a quest its step only picks up: an .accept line names nothing, also for a quest in the log",
		function()
			local s = start() -- the log holds 101 to 104, and 103, 104 and 101 are tracked
			s.enter(s.step("t:1", ".goto 1411,10,10", ".accept 102"))
			assert.are.same({ 103, 104, 101 }, s.world.watch)
			assert.are.same({}, s.world.watchCalls) -- a step that names no quest makes no client call
			-- beside a line that names a quest, the pick-up adds nothing to what is tracked
			s.enter(s.step("t:2", ".accept 102", ".complete 101"))
			assert.are.same({ 101 }, s.world.watch)
			assert.are.same({ 101 }, s.ns.Tracking.NamedQuests(s.step("t:3", ".accept 102", ".complete 101")))
		end
	)

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

	it("takes effect at once when turned on, and gives the player's earlier tracking back when turned off", function()
		local s = start({ enabled = false })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({}, s.world.watchCalls)
		s.ns.Tracking:SetEnabled(true)
		assert.are.same({ 101, 102 }, s.world.watch)
		forget(s.world)
		s.ns.Tracking:SetEnabled(false)
		-- 101 was tracked before and is a quest of the step: it stays where it is; the others come back after it
		assert.are.same({ 101, 103, 104 }, s.world.watch)
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

	it("leaves the tracker as it was when AddQuestWatch raises, says so once and backs off for the client", function()
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
		assert.are.equal("client", mode(s))
		local errors = s.errors()
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("quest tracking backed off", 1, true))
		-- quiet for the next steps and quest log changes while the back-off lasts, whatever the client does now
		forget(s.world)
		s.world.watchFails.AddQuestWatch = nil
		s.enter(s.step("t:2", ".complete 102"))
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({}, s.errors())
		assert.are.equal("client", mode(s))
		-- the back-off runs out, the client takes it now, and the module follows the step it is on then
		s.world.advance(5)
		assert.are.same({ 102 }, s.world.watch)
		assert.are.equal("following", mode(s))
		assert.are.same({}, s.errors())
	end)

	it("leaves the tracker as it was when the client refuses every quest, says so once and backs off", function()
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
		assert.are.equal("client", mode(s))
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
		assert.are.equal("following", mode(s))
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
		assert.are.equal("following", mode(s))
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
			assert.are_not.equal("client", mode(s), name)
			-- and the engine is still listening: the next step is followed all the same
			s.world.watchFails[name] = nil
			s.enter(s.step("t:2", ".complete 103"))
			assert.are.same({ 103 }, s.world.watch, name)
		end
	end)

	it("cannot confirm a quest is tracked when GetQuestWatchType raises: it backs off, untracking nothing", function()
		local s = start({
			setup = function(world)
				world.watchFails.GetQuestWatchType = true
			end,
		})
		s.enter(s.step("t:1", ".complete 102"))
		-- the step's quest was added (that works), but nothing could confirm it, so nothing was untracked
		assert.are.same({ 103, 104, 101, 102 }, s.world.watch)
		assert.are.equal("client", mode(s))
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
		assert.are.equal("following", mode(s))
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

describe("quest tracking: the state machine", function()
	it("walks idle, following, backed off for the player, backed off for the client and restoring", function()
		local s = start({ log = { 101, 102, 103, 104 }, watch = { 103 } })
		assert.are.equal("idle", mode(s)) -- no step yet
		-- a step that names no quest in the log has nothing to manage; the module is still in charge
		s.enter(s.step("t:1", ".goto 1411,10,10", ".accept 105"))
		assert.are.equal("following", mode(s))
		s.enter(s.step("t:2", ".complete 101", ".complete 102"))
		assert.are.equal("following", mode(s))
		assert.are.same({ 101, 102 }, s.world.watch)
		-- the player tracks a quest by hand, and the next change of the quest log notices
		table.insert(s.world.watch, 103)
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal("player", mode(s))
		assert.is_true(s.ns.Tracking.state.manual)
		-- the next step starts again
		s.enter(s.step("t:3", ".complete 104"))
		assert.are.equal("following", mode(s))
		assert.is_false(s.ns.Tracking.state.manual)
		s.world.watchFails.AddQuestWatch = true
		s.enter(s.step("t:4", ".complete 103"))
		assert.are.equal("client", mode(s))
		s.errors()
		-- turned off, the player's earlier tracking comes back and the module is idle again
		s.world.watchFails.AddQuestWatch = nil
		s.ns.Tracking:SetEnabled(false)
		assert.are.equal("idle", mode(s))
		assert.are.same({ 103 }, s.world.watch)
	end)

	it("is idle when the client has no watch functions at all", function()
		local s = start({
			setup = function(world)
				world.useClassicWatch()
				G.AddQuestWatch, G.RemoveQuestWatch = nil, nil
			end,
		})
		s.enter(s.step("t:1", ".complete 102"))
		assert.are.equal("idle", mode(s))
	end)

	it("is idle while it may not act, and sets a step that began meanwhile once it may", function()
		local s = start({ enabled = false })
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.equal("idle", mode(s))
		assert.are.equal("t:1", s.ns.Tracking.state.step.id)
		s.ns.Tracking:SetEnabled(true)
		assert.are.equal("following", mode(s))
	end)
end)

describe("quest tracking: giving the player's earlier tracking back", function()
	it("puts it back when the setting is turned off, and says so", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		assert.are.same({ 102 }, s.world.watch)
		forget(s.world)
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		-- what the module added is untracked first, then what it removed is tracked again, in the player's order
		assert.are.same({ "remove 102", "add 103", "add 104", "add 101" }, changes(s.world))
		assert.is_true(said(s, "your earlier tracking is back (3 tracked again, 1 untracked)"))
		assert.is_nil(s.ns.char.tracking.before)
	end)

	it("keeps what the player had before the module's first change, not what a later step started from", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		s.enter(s.step("t:2", ".complete 103"))
		assert.are.same({ 103 }, s.world.watch)
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({ 103, 104, 101 }, s.world.watch)
	end)

	it("gives it back once, and remembers anew at the next takeover", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		s.ns.Tracking:SetEnabled(false)
		forget(s.world)
		s.ns.Tracking:SetEnabled(false) -- nothing is left to give back
		assert.are.same({}, s.world.watchCalls)
		-- on again, with the tracker as the player has it now, and off again
		s.world.watch = { 104 }
		s.ns.Tracking:SetEnabled(true)
		assert.are.same({ 102 }, s.world.watch)
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({ 104 }, s.world.watch)
	end)

	it("never fights a later change by the player", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		-- the player untracks the step's quest and tracks one that was just accepted
		table.remove(s.world.watch, 1)
		accept(s, 105)
		table.insert(s.world.watch, 105)
		s.settle("QUEST_ACCEPTED", 105)
		forget(s.world)
		s.ns.Tracking:SetEnabled(false)
		-- 102 is not untracked again (the player did that), 105 stays, the earlier quests come back
		assert.are.same({ "add 103", "add 104", "add 101" }, changes(s.world))
		assert.are.same({ 105, 103, 104, 101 }, s.world.watch)
	end)

	it("does not track again a quest the player untracked after the module left it tracked", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 101")) -- 101 was tracked already, and is the step's
		assert.are.same({ 101 }, s.world.watch)
		table.remove(s.world.watch, 1) -- the player does not want it any more
		forget(s.world)
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({ "add 103", "add 104" }, changes(s.world))
		assert.are.same({ 103, 104 }, s.world.watch)
	end)

	it("puts back only what is still in the quest log, and leaves the tracker alone when nothing of it is", function()
		local s = start({ log = { 101, 102, 103, 104 }, watch = { 103, 104 } })
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.same({ 101 }, s.world.watch)
		-- both quests the player was tracking are handed in
		s.world.log = { s.world.log[1], s.world.log[2] }
		s.settle("QUEST_REMOVED", 103)
		forget(s.world)
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({}, changes(s.world))
		assert.are.same({ 101 }, s.world.watch)
		assert.is_true(said(s, "the quests you were tracking before are done"))
		-- a quest that is gone is skipped, the others come back
		local t = start({ log = { 101, 102, 103, 104 }, watch = { 103, 104 } })
		t.enter(t.step("t:1", ".complete 101"))
		t.world.log = { t.world.log[1], t.world.log[2], t.world.log[3] }
		t.settle("QUEST_REMOVED", 104)
		t.ns.Tracking:SetEnabled(false)
		assert.are.same({ 103 }, t.world.watch)
	end)

	it("does not need the step card or a guide: turning the setting off is the player's own act", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		G.SlashCmdList.SIGNPOST("hide")
		s.hasGuide = false
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({ 103, 104, 101 }, s.world.watch)
	end)

	it("hiding the step card gives nothing back, it only pauses the module", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		forget(s.world)
		G.SlashCmdList.SIGNPOST("hide")
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({ 102 }, s.world.watch)
	end)

	it("gives it back when the guide is gone", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		s.hasGuide = false
		s.ns.Events:Fire("GUIDE_SELECTED")
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		assert.are.equal("idle", mode(s))
		-- a guide that is still there is no reason to give anything back
		local t = start()
		t.enter(t.step("t:1", ".complete 102"))
		t.ns.Events:Fire("GUIDE_SELECTED")
		assert.are.same({ 102 }, t.world.watch)
	end)

	it("does nothing when the module never changed the tracker", function()
		local s = start({ enabled = false })
		s.enter(s.step("t:1", ".complete 102"))
		local before = #s.mock.printed
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({}, s.world.watchCalls)
		assert.are.equal(before, #s.mock.printed)
	end)

	it("survives a reload: what the player had before the module took over is still given back", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		local t = reload(s)
		t.enter(t.step("t:1", ".complete 102")) -- the engine announces the step again at login
		assert.are.same({ 102 }, t.world.watch)
		assert.are.same({}, changes(t.world)) -- the tracker is as the module left it: nothing to change
		t.ns.Tracking:SetEnabled(false)
		assert.are.same({ 103, 104, 101 }, t.world.watch)
	end)

	it("says so when the client does not take what it is asked", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		s.world.watchFails.AddQuestWatch = true
		s.ns.Tracking:SetEnabled(false)
		assert.is_true(said(s, "your earlier tracking is back (0 tracked again, 1 untracked)"))
		assert.is_true(said(s, "the client did not take 3 of those changes"))
		assert.is_nil(s.ns.char.tracking.before) -- once, whatever the client did
	end)
end)

describe("quest tracking: backed off for the client", function()
	-- The calls to AddQuestWatch since the module began, and the time since then.
	local function failing()
		local s = start({
			log = { 101, 102 },
			watch = { 102 },
			setup = function(world)
				world.watchFails.AddQuestWatch = true
			end,
		})
		s.enter(s.step("t:1", ".complete 101"))
		s.errors()
		local began = s.mock.now
		s.after = function(seconds)
			s.world.advance(seconds - (s.mock.now - began))
		end
		s.adds = function()
			return writes(s.world, "AddQuestWatch")
		end
		return s
	end

	it("tries again 5, 15, 45, 120 and 300 seconds after the failures, and then no more on its own", function()
		local s = failing()
		assert.are.equal(1, s.adds())
		for i, at in ipairs({ 5, 20, 65, 185, 485 }) do
			s.after(at - 0.5)
			assert.are.equal(i, s.adds(), "before " .. at)
			s.after(at + 0.5)
			assert.are.equal(i + 1, s.adds(), "at " .. at)
		end
		s.after(100000)
		assert.are.equal(6, s.adds())
		assert.are.equal("client", mode(s))
		assert.are.same({}, s.errors()) -- the streak has its one entry
	end)

	it("does not hammer the client with a burst of steps and quest log changes", function()
		local s = failing()
		for i = 1, 40 do
			s.enter(s.step("t:" .. (i + 1), ".complete 101"))
		end
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal(1, s.adds())
	end)

	it("tries again at a step or a change of the quest log that comes after the last back-off", function()
		local s = failing()
		s.after(500) -- the sixth failure, at 485: the next try is due at 785
		assert.are.equal(6, s.adds())
		s.enter(s.step("t:2", ".complete 101"))
		s.after(700)
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal(6, s.adds())
		s.after(800)
		s.enter(s.step("t:3", ".complete 101"))
		assert.are.equal(7, s.adds())
		s.enter(s.step("t:4", ".complete 101")) -- and not again within the back-off
		assert.are.equal(7, s.adds())
		s.world.watchFails.AddQuestWatch = nil
		s.after(1200)
		accept(s, 106)
		s.settle("QUEST_ACCEPTED", 106)
		assert.are.equal("following", mode(s))
	end)

	it("treats the watch list changing as a retry once the back-off is over", function()
		local s = failing()
		s.after(500)
		s.world.watchFails.AddQuestWatch = nil
		s.after(600) -- not due yet
		s.mock.fire("QUEST_WATCH_LIST_CHANGED")
		s.world.advance(0.5)
		assert.are.equal("client", mode(s))
		s.after(800)
		s.mock.fire("QUEST_WATCH_LIST_CHANGED")
		s.mock.fire("QUEST_WATCH_LIST_CHANGED") -- a bunch of them is looked at once
		s.world.advance(0.5)
		assert.are.equal("following", mode(s))
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("recovers when the player frees a slot in a full tracker", function()
		local s = start({
			log = { 101, 102, 103, 104 },
			watch = { 103, 104 },
			setup = function(world)
				world.watchLimit = 2
			end,
		})
		s.enter(s.step("t:1", ".complete 101"))
		assert.are.equal("client", mode(s))
		assert.are.same({ 103, 104 }, s.world.watch)
		assert.are.equal(1, #s.errors())
		table.remove(s.world.watch) -- the player untracks one
		s.world.advance(5)
		assert.are.equal("following", mode(s))
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("starts the back-off over after a success", function()
		local s = failing()
		s.after(6) -- the second failure
		assert.are.equal(2, s.adds())
		s.world.watchFails.AddQuestWatch = nil
		s.after(21) -- the third try succeeds
		assert.are.equal("following", mode(s))
		s.world.watchFails.AddQuestWatch = true
		local before = s.adds()
		s.enter(s.step("t:2", ".complete 102"))
		assert.are.equal(before + 1, s.adds())
		s.world.advance(5.1) -- the first back-off again, not the 45 s the old streak had reached
		assert.are.equal(before + 2, s.adds())
		s.errors()
	end)

	it("forgets the back-off when the setting is toggled", function()
		local s = failing()
		s.world.watchFails.AddQuestWatch = nil
		s.ns.Tracking:SetEnabled(false)
		s.ns.Tracking:SetEnabled(true)
		assert.are.equal("following", mode(s))
		assert.are.same({ 101 }, s.world.watch)
		s.world.advance(1000) -- no timer of the old streak is left
		assert.are.equal(2, s.adds())
	end)

	it("does not try while the module may not act, and an old timer does nothing", function()
		local s = failing()
		G.SlashCmdList.SIGNPOST("hide")
		s.world.advance(100)
		assert.are.equal(1, s.adds())
		s.world.watchFails.AddQuestWatch = nil
		G.SlashCmdList.SIGNPOST("show") -- the card shown again is a new start, with the back-off forgotten
		assert.are.equal("following", mode(s))
		assert.are.same({ 101 }, s.world.watch)
	end)
end)

describe("quest tracking: the step card shown again", function()
	it("sets the tracking for the current step when the card is shown again", function()
		local s = start({ watch = {} })
		G.SlashCmdList.SIGNPOST("hide")
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({}, s.world.watchCalls)
		G.SlashCmdList.SIGNPOST("show")
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.are.equal(101, s.world.superTracked) -- a new start: the arrow points at the step's first open quest
	end)

	it("does so whichever way the card's saved flag is turned on", function()
		local s = start({ watch = {} })
		G.SlashCmdList.SIGNPOST("hide")
		s.enter(s.step("t:1", ".complete 101"))
		s.ns.StepFrame:SetShown(true) -- the Journal's "Show the step card"
		assert.are.same({ 101 }, s.world.watch)
		s.world.watch = {}
		G.SlashCmdList.SIGNPOST("hide")
		s.ns.StepFrame:Reset() -- /signpost reset shows it too
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("does nothing when the card was shown already, or is hidden again", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101"))
		forget(s.world)
		G.SlashCmdList.SIGNPOST("show")
		s.ns.StepFrame:SetShown(true)
		G.SlashCmdList.SIGNPOST("hide")
		assert.are.same({}, s.world.watchCalls)
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("does nothing while the setting is off or no guide is active", function()
		local s = start({ enabled = false, watch = {} })
		G.SlashCmdList.SIGNPOST("hide")
		s.enter(s.step("t:1", ".complete 101"))
		G.SlashCmdList.SIGNPOST("show")
		assert.are.same({}, s.world.watchCalls)
		local t = start({ guide = false, watch = {} })
		G.SlashCmdList.SIGNPOST("hide")
		t.enter(t.step("t:1", ".complete 101"))
		G.SlashCmdList.SIGNPOST("show")
		assert.are.same({}, t.world.watchCalls)
	end)

	it("is a new start: what the player did by hand during the step is forgotten", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 103)
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal("player", mode(s))
		G.SlashCmdList.SIGNPOST("hide")
		G.SlashCmdList.SIGNPOST("show")
		assert.are.equal("following", mode(s))
		assert.are.same({ 101, 102 }, s.world.watch)
		assert.is_nil(s.ns.char.tracking.handsOff)
	end)
end)

describe("quest tracking: the game's own tracking is not the player's", function()
	it(
		"does not take a quest the game tracked by itself (the automatic watch type) for a change by the player",
		function()
			local s = start({ watch = {}, setup = watchTypes })
			s.enter(s.step("t:1", ".complete 101", ".complete 102"))
			-- the player kills something that advances an older quest, and the game tracks it; then a quest is accepted
			table.insert(s.world.watch, 104)
			s.world.watchTypes[104] = 0
			accept(s, 105)
			table.insert(s.world.watch, 105)
			s.world.watchTypes[105] = 0
			forget(s.world)
			s.settle("QUEST_ACCEPTED", 105)
			assert.are.equal("following", mode(s))
			assert.is_false(s.ns.Tracking.state.manual)
			-- neither is the step's: both are untracked at once
			assert.are.same({ 101, 102 }, s.world.watch)
			assert.are.same({ "remove 104", "remove 105" }, changes(s.world))
		end
	)

	it("still takes a quest tracked by hand (the manual watch type) for the player's", function()
		local s = start({ watch = {}, setup = watchTypes })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 104)
		s.world.watchTypes[104] = 1
		accept(s, 105)
		table.insert(s.world.watch, 105)
		s.world.watchTypes[105] = 0
		forget(s.world)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal("player", mode(s))
		assert.are.same({}, changes(s.world))
	end)

	it("cannot tell them apart without watch types: the change stays the player's, the old limit", function()
		local s = start({
			watch = {},
			setup = function()
				watchTypes()
				G.C_QuestLog.GetQuestWatchType = nil
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 104)
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal("player", mode(s))
	end)

	it(
		"takes a watch change seen as it happens, right after the game accepted or advanced a quest, for the game's",
		function()
			local s = start({ watch = {} }) -- no watch types on this client
			s.enter(s.step("t:1", ".complete 101", ".complete 102"))
			s.mock.fire("QUEST_WATCH_UPDATE", 103) -- the game advanced a quest...
			table.insert(s.world.watch, 103) -- ...and tracked it
			s.mock.fire("QUEST_WATCH_LIST_CHANGED", 103, true)
			s.world.advance(0.5)
			assert.are.equal("following", mode(s))
			-- that is settled: once the evidence is gone another look does not hold the game's change against the player
			s.world.advance(3)
			s.mock.fire("QUEST_WATCH_LIST_CHANGED")
			s.world.advance(0.5)
			assert.are.equal("following", mode(s))
			-- and a change by the player after it is judged on its own
			table.insert(s.world.watch, 104)
			s.mock.fire("QUEST_WATCH_LIST_CHANGED", 104, true)
			s.world.advance(0.5)
			assert.are.equal("player", mode(s))
			assert.are.equal("t:1", s.ns.char.tracking.handsOff) -- at once, saved
		end
	)

	it("takes a watch change right after the game accepted a quest for the game's as well", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		s.mock.fire("QUEST_ACCEPTED", 106) -- the game accepts a quest and, with it, tracks one of the older ones
		table.insert(s.world.watch, 103)
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 103, true)
		s.world.advance(0.5)
		assert.are.equal("following", mode(s))
	end)

	-- "Right after" is GAME_WINDOW (2 s) by the clock: the specs above all have the change come in the same instant, so
	-- a window of nothing would do for them.
	it("takes a watch change up to two seconds after the game accepted a quest for the game's", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		s.mock.fire("QUEST_ACCEPTED", 106)
		s.world.advance(1.5) -- some way into the window
		table.insert(s.world.watch, 103)
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 103, true)
		s.world.advance(0.5)
		assert.are.equal("following", mode(s))
	end)

	it("takes the same change for the player's once the window is over", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		s.mock.fire("QUEST_ACCEPTED", 106)
		s.world.advance(2.5) -- just past it
		table.insert(s.world.watch, 103)
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 103, true)
		s.world.advance(0.5)
		assert.are.equal("player", mode(s))
	end)

	it("takes the same change for the player's when the game did nothing just before it", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		s.mock.fire("QUEST_ACCEPTED", 103)
		s.world.advance(3) -- long ago
		table.insert(s.world.watch, 103)
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 103, true)
		s.world.advance(0.5)
		assert.are.equal("player", mode(s))
	end)

	it("lets the game's timing decide only when the client does not say the watch type", function()
		local s = start({ watch = {}, setup = watchTypes })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		s.mock.fire("QUEST_ACCEPTED", 103)
		table.insert(s.world.watch, 103)
		s.world.watchTypes[103] = 1 -- the client says it is a manual watch
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 103, true)
		s.world.advance(0.5)
		assert.are.equal("player", mode(s))
	end)

	it("does not take its own writes for a change by the player", function()
		local s = start({ watch = { 103 } })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		forget(s.world)
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 101, true) -- the client announces what the module just did
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 103, false)
		s.world.advance(0.5)
		assert.are.equal("following", mode(s))
		assert.are.same({}, changes(s.world))
	end)

	it("looks at a bunch of watch list events once", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		forget(s.world)
		for i = 1, 6 do
			s.mock.fire("QUEST_WATCH_LIST_CHANGED", 100 + i, true)
		end
		s.world.advance(0.5)
		assert.are.equal(1, writes(s.world, "GetNumQuestWatches")) -- one look, not six
		s.mock.fire("QUEST_WATCH_LIST_CHANGED") -- and the next bunch is looked at too
		s.world.advance(0.5)
		assert.are.equal(2, writes(s.world, "GetNumQuestWatches"))
	end)

	it("takes it that the game dropped a watch of its own that the module had left standing", function()
		local s = start({
			watch = { 101 },
			setup = function(world)
				watchTypes()
				world.watchTypes[101] = 0 -- the game tracks 101 by itself, and the step is about it
			end,
		})
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ 101, 102 }, s.world.watch) -- 101 is left alone, it is tracked
		table.remove(s.world.watch, 1) -- the game drops its own watch
		accept(s, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal("following", mode(s))
		assert.are.same({ 102, 101 }, s.world.watch) -- the step's quest is tracked again
	end)

	it("does not judge a quest that arrives: it is untracked unless the step is about it", function()
		local s = start({ watch = {}, setup = watchTypes })
		s.enter(s.step("t:1", ".complete 101"))
		accept(s, 105)
		table.insert(s.world.watch, 105)
		s.world.watchTypes[105] = 1 -- even a watch that looks manual: a new quest is not compared
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal("following", mode(s))
		assert.are.same({ 101 }, s.world.watch)
	end)

	it("keeps the first observations of the game's own tracking for the developer, a few only", function()
		local s = start({ watch = {}, setup = watchTypes })
		s.enter(s.step("t:1", ".complete 101"))
		table.insert(s.world.watch, 104)
		s.world.watchTypes[104] = 0
		accept(s, 105)
		table.insert(s.world.watch, 105)
		s.world.watchTypes[105] = 0
		s.settle("QUEST_ACCEPTED", 105)
		local seen = s.ns.db.probe.trackingSeen
		local changed, arrived
		for _, entry in ipairs(seen) do
			if entry.what == "changed" then
				changed = entry
			elseif entry.what == "arrived" then
				arrived = entry
			end
		end
		assert.are.equal(104, changed.quest)
		assert.are.equal("game", changed.by)
		assert.are.equal("auto", changed.kind)
		assert.is_true(changed.tracked)
		assert.are.equal(105, arrived.quest)
		assert.is_true(arrived.tracked) -- the game tracked it as it was accepted
		assert.are.equal("auto", arrived.kind)
		assert.are.equal(0, arrived.watchType)
		for i = 1, 20 do
			accept(s, 200 + i)
			s.settle("QUEST_ACCEPTED", 200 + i)
		end
		assert.are.equal(12, #s.ns.db.probe.trackingSeen)
	end)

	it("keeps twelve observations at most also when many changes are told at once", function()
		local log = {}
		for id = 101, 120 do
			log[#log + 1] = id
		end
		local s = start({ log = log, watch = {} })
		s.enter(s.step("t:1", ".complete 101"))
		for id = 102, 116 do
			table.insert(s.world.watch, id) -- fifteen quests the player tracks by hand
		end
		accept(s, 201)
		s.settle("QUEST_ACCEPTED", 201)
		assert.are.equal("player", mode(s))
		assert.are.equal(12, #s.ns.db.probe.trackingSeen)
	end)
end)

describe("quest tracking after a reload", function()
	-- The player took the tracker in hand during the step: a quest tracked by hand, noticed at the next accept.
	local function inHand()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 103)
		accept(s, 105)
		table.insert(s.world.watch, 105)
		s.settle("QUEST_ACCEPTED", 105)
		assert.are.equal("player", mode(s))
		return s
	end

	it("keeps hands off for the step the player took in hand before it", function()
		local s = inHand()
		assert.are.equal("t:1", s.ns.char.tracking.handsOff)
		local t = reload(s)
		t.enter(t.step("t:1", ".complete 101", ".complete 102")) -- the same step at login
		assert.are.equal("player", mode(t))
		assert.are.same({}, t.world.watchCalls)
		assert.are.same({ 101, 102, 103, 105 }, t.world.watch)
		-- and the same step announced again after the reload keeps it
		t.enter(t.step("t:1", ".complete 101", ".complete 102"))
		assert.are.equal("player", mode(t))
		assert.are.same({}, t.world.watchCalls)
	end)

	it("starts again with the next step, which forgets the saved fact", function()
		local s = inHand()
		local t = reload(s)
		t.enter(t.step("t:1", ".complete 101", ".complete 102"))
		t.enter(t.step("t:2", ".complete 102"))
		assert.are.equal("following", mode(t))
		assert.are.same({ 102 }, t.world.watch)
		assert.is_nil(t.ns.char.tracking.handsOff)
		-- coming back to the first step is a new start too
		t.enter(t.step("t:1", ".complete 101", ".complete 102"))
		assert.are.equal("following", mode(t))
	end)

	it("honours the saved fact only for the step it names", function()
		local s = inHand()
		local t = reload(s)
		-- the engine resumes on another step (it moved on, or the guide changed): a new start, not the old decision
		t.enter(t.step("t:2", ".complete 102"))
		assert.are.equal("following", mode(t))
		assert.are.same({ 102 }, t.world.watch)
		assert.is_nil(t.ns.char.tracking.handsOff)
	end)

	it("sets the tracking once after a reload when the player had not touched it", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		local t = reload(s)
		table.insert(t.world.watch, 103) -- nobody noticed: the reload came first, and no logout saw it
		t.enter(t.step("t:1", ".complete 101", ".complete 102"))
		assert.are.equal("following", mode(t))
		assert.are.same({ 101, 102 }, t.world.watch)
	end)

	it("notices a change by the player at logout, so that a reload right after it is remembered", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 103) -- no change of the quest log, no event: nothing has noticed
		assert.are.equal("following", mode(s))
		s.mock.fire("PLAYER_LOGOUT") -- a reload is a logout
		assert.are.equal("t:1", s.ns.char.tracking.handsOff)
		local t = reload(s)
		t.enter(t.step("t:1", ".complete 101", ".complete 102"))
		assert.are.equal("player", mode(t))
		assert.are.same({ 101, 102, 103 }, t.world.watch)
	end)

	it("does not take the game's own tracking for the player's at logout", function()
		local s = start({ watch = {}, setup = watchTypes })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		table.insert(s.world.watch, 103)
		s.world.watchTypes[103] = 0
		s.mock.fire("PLAYER_LOGOUT")
		assert.is_nil(s.ns.char.tracking.handsOff)
	end)

	it("looks at nothing at logout while it is paused: no card, no judgement, nothing saved", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.equal("following", mode(s))
		G.SlashCmdList.SIGNPOST("hide") -- the module is paused from here on, in the state it was in
		assert.are.equal("hidden", s.ns.Tracking:Paused())
		table.insert(s.world.watch, 103) -- a change by hand that it would take for the player's if it looked
		forget(s.world)
		s.mock.fire("PLAYER_LOGOUT")
		assert.are.equal("following", mode(s))
		assert.is_nil(s.ns.char.tracking.handsOff)
		assert.are.same({}, s.world.watchCalls) -- it did not even read the tracker
	end)

	it("honours the saved fact until the player turns the setting on again", function()
		local s = inHand()
		local t = reload(s)
		t.enter(t.step("t:1", ".complete 101", ".complete 102"))
		assert.are.equal("player", mode(t))
		t.ns.Tracking:SetEnabled(false)
		t.ns.Tracking:SetEnabled(true)
		assert.are.equal("following", mode(t))
		assert.are.same({ 101, 102 }, t.world.watch)
		assert.is_nil(t.ns.char.tracking.handsOff)
	end)

	it("forgets the saved fact when the setting is toggled even if no step is in hand yet", function()
		local s = inHand()
		s.ns.Tracking:SetEnabled(false)
		assert.is_nil(s.ns.char.tracking.handsOff)
	end)

	it("forgets the saved fact when the setting is turned on while no guide is active to begin a step", function()
		local s = inHand()
		assert.are.equal("t:1", s.ns.char.tracking.handsOff)
		s.hasGuide = false -- no step to begin: only the setting's own bookkeeping can forget the fact
		s.ns.Tracking:SetEnabled(true)
		assert.is_nil(s.ns.char.tracking.handsOff)
		assert.are.equal("idle", mode(s))
	end)
end)

describe("/signpost tracking", function()
	it(
		"prints the setting, the state, what the module last set, what it keeps to give back and what the client has",
		function()
			local s = start()
			s.enter(s.step("t:1", ".complete 102"))
			G.SlashCmdList.SIGNPOST("tracking")
			assert.is_true(said(s, "Quest tracking is on (your choice). State: following. Step: t:1."))
			assert.is_true(
				said(s, "Last set by the module: 102. Your earlier tracking, kept to give back: 103, 104, 101.")
			)
			assert.is_true(
				said(s, "Tracked now: 102 (1). Watch functions: the retail shape; missing: Enum.QuestWatchType.")
			)
			assert.is_true(
				said(
					s,
					"Recorded for the developer: 0 observations of the game's own tracking; "
						.. "the test has not been run (/signpost tracking test)."
				)
			)
		end
	)

	it("says when the setting is the default and why the module is paused", function()
		local s = start({ enabled = "default" })
		s.enter(s.step("t:1", ".complete 102"))
		G.SlashCmdList.SIGNPOST("hide")
		G.SlashCmdList.SIGNPOST("tracking status")
		assert.is_true(
			said(s, "Quest tracking is on (the default). State: following (paused: the step card is hidden).")
		)
		local t = start({ enabled = false })
		G.SlashCmdList.SIGNPOST("tracking")
		assert.is_true(
			said(t, "Quest tracking is off (your choice). State: idle (paused: the setting is off). Step: none yet.")
		)
	end)

	it("says when it is backed off, for the client or for the player", function()
		local s = start({
			log = { 101, 102 },
			watch = { 102 },
			setup = function(world)
				world.watchFails.AddQuestWatch = true
			end,
		})
		s.enter(s.step("t:1", ".complete 101"))
		s.errors()
		G.SlashCmdList.SIGNPOST("tracking")
		assert.is_true(said(s, "State: client."))
		assert.is_true(
			said(s, "Backed off for the client: 1 failed tries in a row, the next one in 5 s at the earliest.")
		)
		local t = start({ watch = {} })
		t.enter(t.step("t:1", ".complete 101"))
		table.insert(t.world.watch, 103)
		accept(t, 105)
		t.settle("QUEST_ACCEPTED", 105)
		G.SlashCmdList.SIGNPOST("tracking")
		assert.is_true(said(t, "State: player."))
		assert.is_true(said(t, "Backed off for you: you changed the tracker during this step"))
	end)

	it("says which of the functions the client lacks, and when it has neither shape", function()
		local s = start({
			setup = function(world)
				world.useClassicWatch()
				G.AddQuestWatch, G.RemoveQuestWatch = nil, nil
			end,
		})
		G.SlashCmdList.SIGNPOST("tracking")
		assert.is_true(said(s, "This client has neither the retail nor the Classic quest watch functions"))
		local t = start({
			setup = function(world)
				world.useClassicWatch()
			end,
		})
		G.SlashCmdList.SIGNPOST("tracking")
		assert.is_true(said(t, "Watch functions: the classic shape; missing:"))
	end)

	it("knows the test was run, and says how to use it when asked for something else", function()
		local s = start()
		G.SlashCmdList.SIGNPOST("tracking test")
		s.world.advance(2)
		G.SlashCmdList.SIGNPOST("tracking")
		assert.is_true(said(s, "the test has been run (SignpostDB.probe.tracking)"))
		G.SlashCmdList.SIGNPOST("tracking nonsense")
		assert.is_true(said(s, "Usage: /signpost tracking, or /signpost tracking test."))
	end)
end)

describe("/signpost tracking test", function()
	-- Runs the test and lets its settling time pass.
	local function runTest(s)
		G.SlashCmdList.SIGNPOST("tracking test")
		s.world.advance(2)
	end

	it(
		"watches a quest of the log and unwatches it again, records what the client answered, and says what it did",
		function()
			local s = start() -- the log has 101 to 104, the tracker 103, 104 and 101
			runTest(s)
			assert.are.same({ "add 102", "remove 102" }, changes(s.world))
			assert.are.same({ 103, 104, 101 }, s.world.watch) -- never left changed
			local run = s.ns.db.probe.tracking
			assert.is_true(run.complete)
			assert.is_true(run.restored)
			assert.are.equal("retail", run.shape)
			assert.are.equal(102, run.quest)
			assert.are.same({ count = 3, list = { 103, 104, 101 }, watched = false }, run.before)
			assert.are.same({
				call = "C_QuestLog.AddQuestWatch",
				ok = true,
				returns = { n = 1, true },
				readback = { count = 4, watched = true, watchType = 1, inList = true },
			}, run.calls[1])
			assert.are.same({
				call = "C_QuestLog.RemoveQuestWatch",
				ok = true,
				returns = { n = 1, true },
				readback = { count = 3, watched = false, inList = false },
			}, run.calls[2])
			assert.are.same({ count = 3, watched = false, inList = false }, run.later)
			assert.are.equal("function", run.functions["C_QuestLog.AddQuestWatch"])
			assert.are.equal("nil", run.functions["Enum.QuestWatchType"])
			assert.are.same({}, run.events)
			assert.is_true(run.eventsRegistered.QUEST_WATCH_LIST_CHANGED)
			assert.is_true(
				said(s, "Quest tracking test: I watched quest 102 and unwatched it again (the retail shape).")
			)
			assert.is_true(
				said(s, "C_QuestLog.AddQuestWatch returned true; read back at once: tracked yes, 4 quests tracked.")
			)
			assert.is_true(
				said(s, "C_QuestLog.RemoveQuestWatch returned true; read back at once: tracked no, 3 quests tracked.")
			)
			assert.is_true(said(s, "Events seen meanwhile: none. Quests tracked before: 3, afterwards: 3."))
			assert.is_true(said(s, "Your tracker is as it was."))
			assert.is_true(said(s, "Saved to SignpostDB.probe.tracking; /reload writes it to disk."))
			assert.is_false(s.ns.Tracking.testing)
		end
	)

	it("passes the manual watch type and names the types the client has", function()
		local s = start({ setup = watchTypes })
		runTest(s)
		local add
		for _, call in ipairs(s.world.watchCalls) do
			if call[1] == "AddQuestWatch" then
				add = call
			end
		end
		assert.are.same({ "AddQuestWatch", 102, 1 }, add)
		assert.are.same({ Automatic = 0, Manual = 1 }, s.ns.db.probe.tracking.enum)
		assert.are.equal("table", s.ns.db.probe.tracking.functions["Enum.QuestWatchType"])
	end)

	it("takes off and puts back the quest tracked last when every quest is tracked, which keeps the order", function()
		local s = start({
			watch = { 101, 102, 103, 104 },
			setup = function(world)
				watchTypes()
				world.watchTypes[104] = 0
			end,
		})
		runTest(s)
		assert.are.same({ "remove 104", "add 104" }, changes(s.world))
		assert.are.same({ 101, 102, 103, 104 }, s.world.watch)
		local run = s.ns.db.probe.tracking
		assert.are.equal(104, run.quest)
		assert.is_true(run.before.watched)
		assert.is_true(run.restored)
		-- it is put back as the kind of watch it was
		local add
		for _, call in ipairs(s.world.watchCalls) do
			if call[1] == "AddQuestWatch" then
				add = call
			end
		end
		assert.are.same({ "AddQuestWatch", 104, 0 }, add)
	end)

	it("does not run in combat, and changes nothing", function()
		local s = start()
		G.InCombatLockdown = function()
			return true
		end
		runTest(s)
		assert.are.same({}, s.world.watchCalls)
		assert.is_true(said(s, "not in combat, please. Nothing was changed."))
		assert.is_nil(s.ns.db.probe)
		assert.is_false(s.ns.Tracking.testing)
	end)

	it("says so when the quest log is empty", function()
		local s = start({ log = {}, watch = {} })
		runTest(s)
		assert.are.same({}, changes(s.world))
		assert.is_true(said(s, "your quest log is empty"))
		assert.is_true(s.ns.db.probe.tracking.complete)
		assert.truthy(s.ns.db.probe.tracking.note:find("empty", 1, true))
		assert.is_false(s.ns.Tracking.testing)
	end)

	it("says so when the client has no watch functions, and still records which functions it has", function()
		local s = start({
			setup = function(world)
				world.useClassicWatch()
				G.AddQuestWatch, G.RemoveQuestWatch = nil, nil
			end,
		})
		runTest(s)
		local run = s.ns.db.probe.tracking
		assert.are.equal("none", run.shape)
		assert.are.equal("nil", run.functions["C_QuestLog.AddQuestWatch"])
		assert.are.equal("nil", run.functions.AddQuestWatch)
		assert.is_true(said(s, "this client has none of the quest watch functions I know"))
		assert.is_false(s.ns.Tracking.testing)
	end)

	it("works the same on the Classic shape", function()
		local s = start({
			setup = function(world)
				world.useClassicWatch()
			end,
		})
		runTest(s)
		assert.are.same({ "add 2", "remove 2" }, changes(s.world)) -- 102 is the second quest of the log
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		local run = s.ns.db.probe.tracking
		assert.are.equal("classic", run.shape)
		assert.are.equal("AddQuestWatch", run.calls[1].call)
		assert.is_true(run.restored)
	end)

	it("records an AddQuestWatch that raises, with its error, and leaves the tracker alone", function()
		local s = start({
			setup = function(world)
				world.watchFails.AddQuestWatch = true
			end,
		})
		runTest(s)
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		local run = s.ns.db.probe.tracking
		assert.is_false(run.calls[1].ok)
		assert.truthy(run.calls[1].error:find("raised in AddQuestWatch", 1, true))
		assert.is_false(run.calls[1].readback.watched)
		assert.is_true(run.restored)
		assert.is_true(said(s, "C_QuestLog.AddQuestWatch raised:"))
	end)

	it("tries once more to put the tracker back, and says plainly when it could not", function()
		local s = start({
			setup = function(world)
				world.watchFails.RemoveQuestWatch = true
			end,
		})
		runTest(s)
		assert.are.same({ 103, 104, 101, 102 }, s.world.watch) -- the client would not untrack it
		local run = s.ns.db.probe.tracking
		assert.is_false(run.restored)
		assert.is_true(run.repaired)
		assert.are.equal(2, writes(s.world, "RemoveQuestWatch")) -- the test's own, and the repair
		assert.is_true(
			said(s, "I could not put your tracker back: quest 102 is still tracked. Please untrack it by hand.")
		)
		-- a repair that works is not reported as a failure
		local t = start({})
		t.world.watchFails.RemoveQuestWatch = true
		G.SlashCmdList.SIGNPOST("tracking test")
		t.world.advance(0.5)
		t.world.watchFails.RemoveQuestWatch = nil
		t.world.advance(2)
		assert.are.same({ 103, 104, 101 }, t.world.watch)
		assert.is_true(t.ns.db.probe.tracking.restored)
		assert.is_true(t.ns.db.probe.tracking.repaired)
		assert.is_true(said(t, "Your tracker is as it was (it took a second try)."))
	end)

	it("records the watch events that arrive while it waits", function()
		local s = start()
		G.SlashCmdList.SIGNPOST("tracking test")
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 102, true)
		s.world.advance(0.5)
		s.mock.fire("QUEST_LOG_UPDATE")
		s.world.advance(2)
		local run = s.ns.db.probe.tracking
		assert.are.equal(2, #run.events)
		assert.are.same({ event = "QUEST_WATCH_LIST_CHANGED", at = 0, args = { n = 2, 102, true } }, run.events[1])
		assert.are.equal("QUEST_LOG_UPDATE", run.events[2].event)
		assert.are.equal(0.5, run.events[2].at)
		assert.is_true(said(s, "Events seen meanwhile: QUEST_WATCH_LIST_CHANGED, QUEST_LOG_UPDATE."))
		-- and it stops listening when it is done
		s.mock.fire("QUEST_WATCH_LIST_CHANGED", 102, true)
		assert.are.equal(2, #s.ns.db.probe.tracking.events)
	end)

	it("records the limits the client names", function()
		local s = start({
			setup = function()
				G.Constants = { QuestWatchConsts = { MAX_QUEST_WATCHES = 25 } }
				G.MAX_WATCHABLE_QUESTS = 5
			end,
		})
		runTest(s)
		assert.are.same(
			{ retailConstants = { MAX_QUEST_WATCHES = 25 }, maxWatchableQuests = 5 },
			s.ns.db.probe.tracking.limits
		)
	end)

	it("does not start a second test while one is running", function()
		local s = start()
		G.SlashCmdList.SIGNPOST("tracking test")
		G.SlashCmdList.SIGNPOST("tracking test")
		assert.is_true(said(s, "The quest tracking test is still running."))
		s.world.advance(2)
		assert.are.same({ "add 102", "remove 102" }, changes(s.world))
	end)

	it("does not disturb the module: it waits, and picks up where it is afterwards", function()
		local s = start({ watch = {} })
		s.enter(s.step("t:1", ".complete 101", ".complete 102"))
		assert.are.same({ "add 101", "add 102" }, changes(s.world))
		forget(s.world)
		G.SlashCmdList.SIGNPOST("tracking test")
		assert.are.equal("testing", s.ns.Tracking:Paused())
		-- a step that begins meanwhile is set when the test is done
		s.enter(s.step("t:2", ".complete 103"))
		assert.are.same({ "add 103", "remove 103" }, changes(s.world)) -- the test's own: 103 is the lowest quest untracked
		s.world.advance(2)
		assert.is_nil(s.ns.Tracking:Paused())
		assert.are.same({ 103 }, s.world.watch)
		assert.are.equal("following", mode(s))
	end)

	it("applies a setting turned off meanwhile when it is done: the earlier tracking comes back", function()
		local s = start()
		s.enter(s.step("t:1", ".complete 102"))
		assert.are.same({ 102 }, s.world.watch)
		G.SlashCmdList.SIGNPOST("tracking test")
		s.ns.Tracking:SetEnabled(false)
		assert.are.same({ 102 }, s.world.watch) -- not yet: the test is still on
		s.world.advance(2)
		assert.are.same({ 103, 104, 101 }, s.world.watch)
		assert.are.equal("idle", mode(s))
	end)

	it("lets a new /signpost probe keep what it recorded", function()
		local s = start()
		runTest(s)
		s.ns.db.probe.trackingSeen = { { what = "arrived", quest = 7 } }
		G.SlashCmdList.SIGNPOST("probe")
		assert.is_true(s.ns.db.probe.tracking.restored)
		assert.are.equal(102, s.ns.db.probe.tracking.quest)
		assert.are.equal(7, s.ns.db.probe.trackingSeen[1].quest)
		assert.is_table(s.ns.db.probe.build)
	end)
end)

describe("quest log capacity probe", function()
	it("records the client's limit, the legacy global and how full the log is", function()
		local s = start({
			log = { header("Durotar", false), 101, 102, 103 },
			setup = function()
				G.C_QuestLog.GetMaxNumQuestsCanAccept = function()
					return 40
				end
				G.MAX_QUESTLOG_QUESTS = 25
			end,
		})
		G.SlashCmdList.SIGNPOST("probe")
		assert.are.same({
			canAccept = 40,
			canAcceptKind = "function",
			legacyGlobal = 25,
			entries = 4, -- the header counts
			quests = 3,
			numQuests = 3,
		}, s.ns.db.probe.questLogMax)
		assert.is_true(
			said(s, "quest log: 3 quests now; limit per GetMaxNumQuestsCanAccept: 40, per MAX_QUESTLOG_QUESTS: 25")
		)
	end)

	it("leaves out what the client does not have, and does not fail", function()
		local s = start({ log = { header("Durotar", false), 101, header("Orgrimmar", false), 102 } })
		G.SlashCmdList.SIGNPOST("probe")
		assert.are.same({ canAcceptKind = "nil", entries = 4, quests = 2, numQuests = 2 }, s.ns.db.probe.questLogMax)
		assert.is_true(
			said(s, "quest log: 2 quests now; limit per GetMaxNumQuestsCanAccept: nil, per MAX_QUESTLOG_QUESTS: nil")
		)
		-- no quest log API at all
		G.C_QuestLog = nil
		G.SlashCmdList.SIGNPOST("probe")
		assert.are.same({ canAcceptKind = "nil" }, s.ns.db.probe.questLogMax)
	end)

	it("copes with a limit that raises or is not a number", function()
		local s = start({
			setup = function()
				G.C_QuestLog.GetMaxNumQuestsCanAccept = function()
					error("no")
				end
				G.MAX_QUESTLOG_QUESTS = "twenty-five"
			end,
		})
		G.SlashCmdList.SIGNPOST("probe")
		local max = s.ns.db.probe.questLogMax
		assert.is_nil(max.error)
		assert.is_nil(max.canAccept)
		assert.are.equal("function", max.canAcceptKind)
		assert.is_nil(max.legacyGlobal)
		assert.are.equal(4, max.quests)
	end)

	it("keeps the walk's count and the client's own count apart when a collapsed header makes them differ", function()
		local s = start({
			log = { header("Durotar", true), 101, 102, header("Orgrimmar", false), 103 },
			setup = function(world)
				world.hideCollapsed = true -- the walk misses the two quests under the collapsed header
				local entries = G.C_QuestLog.GetNumQuestLogEntries
				G.C_QuestLog.GetNumQuestLogEntries = function()
					local shown = entries()
					return shown, 3 -- the client counts every quest of the log, as Mainline's second result does
				end
			end,
		})
		G.SlashCmdList.SIGNPOST("probe")
		local max = s.ns.db.probe.questLogMax
		assert.are.equal(3, max.entries)
		assert.are.equal(1, max.quests)
		assert.are.equal(3, max.numQuests)
	end)
end)
