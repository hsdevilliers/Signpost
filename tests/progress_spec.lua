local addon = dofile("tests/helpers/addon.lua")
local stubs = dofile("tests/mocks/progress.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local GUIDE_ID = "test-guide"

local function find(lines, text)
	for _, line in ipairs(lines) do
		if line:find(text, 1, true) then
			return line
		end
	end
end

-- A one-chapter guide definition.
local function route(steps)
	return {
		id = GUIDE_ID,
		name = "Test Guide",
		headers = { professions = { "skinning" } },
		chapters = { { id = "valley", name = "Valley", levels = { 1, 6 }, steps = steps } },
	}
end

-- Every session of a test; none may record a Lua error (ns.SafeCall would otherwise hide one).
local sessions = {}

after_each(function()
	for _, ns in ipairs(sessions) do
		assert.are.same({}, ns.db.errors)
	end
	sessions = {}
end)

-- One play session: loads the addon with Engine/Progress.lua, installs the stand-ins (tests/mocks/progress.lua) and
-- logs in. opts: def, plan, flags, count (the stand-ins), saved/account (SignpostCharDB/SignpostDB from an earlier
-- session), level (the player's).
local function session(opts)
	opts = opts or {}
	local ns, mock = addon.load({
		login = false,
		extra = { "Engine/Progress.lua" },
		before = function()
			G.SignpostCharDB = opts.saved
			G.SignpostDB = opts.account
			if opts.level then
				G.UnitLevel = function()
					return opts.level
				end
			end
		end,
	})
	sessions[#sessions + 1] = ns
	local world = stubs.install(ns, opts)
	local log = { steps = {}, loaded = {}, sticky = {}, offers = {} }
	ns.Events:RegisterMessage("STEP_CHANGED", function(_, step, index, reason)
		log.steps[#log.steps + 1] = { id = step.id, index = index, reason = reason }
	end)
	ns.Events:RegisterMessage("GUIDE_LOADED", function(_, guide)
		log.loaded[#log.loaded + 1] = guide
	end)
	ns.Events:RegisterMessage("STICKY_CHANGED", function(_, list)
		log.sticky[#log.sticky + 1] = list
	end)
	ns.Events:RegisterMessage("DUNGEON_SKIP_OFFER", function(_, _, chapter)
		log.offers[#log.offers + 1] = chapter.name
	end)
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	return ns, mock, world, log
end

-- The next session of the same character: SavedVariables written and read back (copied, as the client does).
local function reload(ns, opts)
	opts.saved = ns.Util.CopyTable(ns.char)
	opts.account = ns.Util.CopyTable(ns.db)
	return session(opts)
end

-- A context change a second after the previous one, so the throttle lets it through at once.
local function changed(ns, mock, what)
	mock.now = mock.now + 2
	ns.Events:Fire("CONTEXT_CHANGED", what or "quests")
end

local function current(ns)
	local step = ns.Progress:Current()
	return step and step.id
end

local function record(ns)
	return ns.char.progress[GUIDE_ID]
end

local function slash(text)
	SlashCmdList.SIGNPOST(text)
end

local FIVE = { { "quest a" }, { "quest b" }, { "quest c" }, { "note" }, { "quest d" } }

describe("engine start-up", function()
	it("parses the selected guide with the detected profession plan at login", function()
		local plan = { primary = { "skinning" }, secondary = {}, declined = {} }
		local ns, _, world, log = session({ def = route(FIVE), plan = plan })
		assert.are.same({ { "skinning" } }, world.planCalls)
		assert.are.equal(1, #world.parses)
		assert.are.equal(plan, world.parses[1].plan)
		assert.are.equal(ns.Player, world.parses[1].player)
		local guide = ns.Progress:Guide()
		assert.are.equal(GUIDE_ID, guide.id)
		assert.are.same({ guide }, log.loaded)
		assert.are.same({ { id = "valley:1", index = 1, reason = "load" } }, log.steps)
		assert.are.equal("valley:1", record(ns).current)
		assert.are.same({}, ns.db.errors)
	end)

	it("runs without a guide for the character", function()
		local ns, mock = session({})
		assert.is_nil(ns.Progress:Current())
		assert.are.same({}, ns.Progress:Sticky())
		slash("next")
		assert.truthy(find(mock.printed, "No guide is loaded for this character."))
		ns.Events:Fire("CONTEXT_CHANGED", "quests")
		assert.are.same({}, ns.db.errors)
	end)
end)

describe("auto-advance", function()
	it("moves on when the current step completes, evaluating at most once per second", function()
		local ns, mock, world, log = session({ def = route(FIVE) })
		world.flags.a = true
		changed(ns, mock)
		assert.are.equal("valley:2", current(ns))
		assert.are.same({ id = "valley:2", index = 2, reason = "auto" }, log.steps[#log.steps])
		assert.is_true(record(ns).done["valley:1"])
		assert.are.equal("valley:2", record(ns).current)

		-- within the same second the evaluation waits for a timer, and only one is scheduled
		world.flags.b = true
		ns.Events:Fire("CONTEXT_CHANGED", "quests")
		ns.Events:Fire("CONTEXT_CHANGED", "bags")
		assert.are.equal("valley:2", current(ns))
		assert.are.equal(1, #mock.timers)
		mock.runTimers()
		assert.are.equal("valley:3", current(ns))
	end)

	it("auto-skips the following steps that are already satisfied", function()
		local ns, mock, world, log = session({ def = route(FIVE) })
		world.flags.b, world.flags.c = true, true
		changed(ns, mock)
		assert.are.equal("valley:1", current(ns))
		world.flags.a = true
		changed(ns, mock)
		assert.are.equal("valley:4", current(ns))
		assert.are.equal(2, #log.steps) -- the load, then one change for the whole jump
		assert.is_true(record(ns).done["valley:2"])
		assert.is_true(record(ns).done["valley:3"])
	end)

	it("survives a condition check that raises an error", function()
		local ns, mock, world = session({ def = route(FIVE) })
		local isComplete = ns.Conditions.IsComplete
		ns.Conditions.IsComplete = function(self, step, ...)
			if step.id == "valley:2" then
				error("broken condition")
			end
			return isComplete(self, step, ...)
		end
		world.flags.a = true
		changed(ns, mock)
		assert.are.equal("valley:2", current(ns))
		assert.truthy(ns.db.errors[1].msg:find("broken condition", 1, true))
		slash("next")
		assert.are.equal("valley:3", current(ns))
		wipe(ns.db.errors) -- seen; the after_each check is for unexpected errors
	end)

	it("waits at a step without a completable directive and at a .todo step", function()
		local ns, mock = session({ def = route({ { "note" }, { "todo" }, { "quest a" } }), flags = { a = true } })
		changed(ns, mock)
		assert.are.equal("valley:1", current(ns))
		slash("next")
		assert.are.equal("valley:2", current(ns))
		changed(ns, mock)
		assert.are.equal("valley:2", current(ns))
		-- from the front, a manual move continues with auto-skip: valley:3 is satisfied and the last step
		slash("next")
		assert.are.equal("valley:3", current(ns))
		assert.is_true(record(ns).done["valley:3"])
	end)
end)

describe("auto-skip on load", function()
	it("resumes at the saved step and skips what is already done", function()
		local saved = { dbVersion = 2, progress = { [GUIDE_ID] = { current = "valley:2" } } }
		local ns, _, _, log = session({ def = route(FIVE), saved = saved, flags = { b = true, c = true } })
		assert.are.equal("valley:4", current(ns))
		assert.are.same({ { id = "valley:4", index = 4, reason = "load" } }, log.steps)
		assert.is_true(record(ns).done["valley:2"])
		assert.is_true(record(ns).done["valley:3"])
		assert.is_nil(record(ns).done["valley:1"])
	end)

	it("resumes after the furthest done step when the saved step is gone", function()
		local saved = {
			dbVersion = 2,
			progress = { [GUIDE_ID] = { current = "valley:99", done = { ["valley:1"] = true, ["valley:2"] = true } } },
		}
		local ns = session({ def = route(FIVE), saved = saved })
		assert.are.equal("valley:3", current(ns))
	end)
end)

describe("sticky directives", function()
	local STICKY = { { "quest a" }, { "quest b", "sticky flag s" }, { "quest c" }, { "quest d" } }

	it("stay active beside the later steps until satisfied, then never return", function()
		local ns, mock, world, log = session({ def = route(STICKY), flags = { a = true } })
		assert.are.equal("valley:2", current(ns))
		assert.are.same({}, ns.Progress:Sticky()) -- the current step's own sticky belongs to that step
		world.flags.b = true
		changed(ns, mock)
		assert.are.equal("valley:3", current(ns))
		local sticky = ns.Progress:Sticky()
		assert.are.equal(1, #sticky)
		assert.are.equal("valley:2", sticky[1].id)
		local active = ns.Progress:ActiveSticky("valley:2")
		assert.are.equal(1, #active)
		assert.are.equal("s", active[1].directive.args.key)

		world.flags.s = true
		changed(ns, mock, "skills")
		assert.are.same({}, ns.Progress:Sticky())
		assert.are.same({}, log.sticky[#log.sticky])
		world.flags.s = false
		changed(ns, mock, "skills")
		assert.are.same({}, ns.Progress:Sticky())
		local again = reload(ns, { def = route(STICKY), flags = world.flags })
		assert.are.same({}, again.Progress:Sticky())
	end)

	it("start when auto-skip passes their step and stay active across a reload", function()
		local flags = { a = true, b = true }
		local ns = session({ def = route(STICKY), flags = flags })
		assert.are.equal("valley:3", current(ns))
		assert.are.equal("valley:2", ns.Progress:Sticky()[1].id)
		local again = reload(ns, { def = route(STICKY), flags = flags })
		assert.are.equal("valley:3", current(again))
		assert.are.equal("valley:2", again.Progress:Sticky()[1].id)
	end)

	it("let a step that only starts them complete at once", function()
		local ns, mock, world = session({ def = route({ { "quest a" }, { "sticky flag s" }, { "quest c" } }) })
		world.flags.a = true
		changed(ns, mock)
		assert.are.equal("valley:3", current(ns))
		assert.are.equal("valley:2", ns.Progress:Sticky()[1].id)
	end)

	it("are never active when already satisfied as their step starts", function()
		local def = route({ { "quest a", "sticky flag s" }, { "quest c" } })
		local ns = session({ def = def, flags = { a = true, s = true } })
		assert.are.equal("valley:2", current(ns))
		assert.are.same({}, ns.Progress:Sticky())
	end)

	it("are dismissed when their step is skipped", function()
		local ns = session({ def = route(STICKY), flags = { a = true } })
		assert.are.equal("valley:2", current(ns))
		slash("skip")
		assert.are.equal("valley:3", current(ns))
		assert.are.same({}, ns.Progress:Sticky())
	end)
end)

describe("directive state", function()
	it("runs onStart once when the step becomes current and keeps the state across a reload", function()
		local def = route({ { "quest a" }, { "count 2" }, { "quest c" } })
		local ns, mock, world = session({ def = def, count = 5 })
		world.flags.a = true
		changed(ns, mock)
		assert.are.equal("valley:2", current(ns))
		assert.are.same({ base = 5, starts = 1 }, ns.Progress:State("valley:2")[1])

		local again, mock2, world2 = reload(ns, { def = def, flags = world.flags, count = 6 })
		assert.are.equal("valley:2", current(again))
		assert.are.same({ base = 5, starts = 1 }, again.Progress:State("valley:2")[1])
		world2.count = 7
		changed(again, mock2, "bags")
		assert.are.equal("valley:3", current(again))
		-- only the current step and steps with active stickies keep saved state
		assert.is_nil(record(again).states["valley:2"])
		assert.is_table(record(again).states["valley:3"])
	end)

	it("gives each directive its table, sticky ones also by position after the others", function()
		local ns = session({ def = route({ { "quest a", "sticky flag s" } }) })
		local states = ns.Progress:State("valley:1")
		assert.is_table(states[1])
		assert.is_table(states.sticky[1])
		assert.are.equal(states.sticky[1], states[2])
		assert.are_not.equal(states[1], states[2])
	end)
end)

describe("manual moves", function()
	it("next marks done, back clears the mark, skip marks skipped, and all of it is saved", function()
		local ns = session({ def = route(FIVE) })
		slash("next")
		assert.are.equal("valley:2", current(ns))
		assert.is_true(record(ns).done["valley:1"])
		slash("skip")
		assert.are.equal("valley:3", current(ns))
		assert.is_true(record(ns).skipped["valley:2"])
		slash("back")
		assert.are.equal("valley:2", current(ns))
		assert.is_nil(record(ns).skipped["valley:2"])
		slash("skip")
		local again = reload(ns, { def = route(FIVE) })
		assert.are.equal("valley:3", current(again))
		assert.is_true(record(again).done["valley:1"])
		assert.is_true(record(again).skipped["valley:2"])
	end)

	it("keep a step the player went back to, even when it is complete", function()
		local ns, mock = session({ def = route(FIVE), flags = { a = true, b = true } })
		assert.are.equal("valley:3", current(ns))
		slash("back")
		assert.are.equal("valley:2", current(ns))
		changed(ns, mock, "position")
		changed(ns, mock, "quests")
		assert.are.equal("valley:2", current(ns))
	end)

	it("give way when a quest event completes a later step that was still open", function()
		local ns, mock, world = session({ def = route(FIVE), flags = { a = true, b = true } })
		slash("back")
		world.flags.c = true
		changed(ns, mock, "position") -- not a quest event: the manual choice stands
		assert.are.equal("valley:2", current(ns))
		changed(ns, mock, "quests")
		assert.are.equal("valley:4", current(ns))
	end)

	it("give way when the chosen step itself gets completed", function()
		local ns, mock, world = session({ def = route(FIVE) })
		slash("next")
		slash("next")
		slash("back")
		assert.are.equal("valley:2", current(ns))
		world.flags.b = true
		changed(ns, mock, "position")
		assert.are.equal("valley:3", current(ns))
	end)

	it("go one step per press behind the furthest step reached", function()
		local ns = session({ def = route(FIVE), flags = { a = true, b = true, c = true } })
		assert.are.equal("valley:4", current(ns))
		slash("back")
		slash("back")
		assert.are.equal("valley:2", current(ns))
		slash("next")
		assert.are.equal("valley:3", current(ns))
		slash("next")
		assert.are.equal("valley:4", current(ns))
	end)

	it("win only for the session: after a reload auto-skip applies again", function()
		local flags = { a = true, b = true }
		local ns = session({ def = route(FIVE), flags = flags })
		slash("back")
		assert.are.equal("valley:2", current(ns))
		local again = reload(ns, { def = route(FIVE), flags = flags })
		assert.are.equal("valley:3", current(again))
	end)

	it("jump with /signpost step <number> or <id>, which also shows the current step", function()
		local ns, mock, _, log = session({ def = route(FIVE) })
		slash("step 4")
		assert.are.equal("valley:4", current(ns))
		assert.are.same({ id = "valley:4", index = 4, reason = "manual" }, log.steps[#log.steps])
		slash("step valley:2")
		assert.are.equal("valley:2", current(ns))
		slash("step")
		assert.truthy(find(mock.printed, "Step 2/5 (Valley, valley:2): quest b"))
		slash("step 99")
		assert.truthy(find(mock.printed, "There is no step '99' in this guide."))
		slash("back")
		slash("back")
		assert.truthy(find(mock.printed, "This is the first step."))
	end)

	it("are printed, like every step change, with debug chat on", function()
		local account = { dbVersion = 1, debug = { chat = true } }
		local ns, mock, world = session({ def = route(FIVE), account = account })
		world.flags.a = true
		changed(ns, mock)
		slash("next")
		assert.truthy(find(mock.printed, "Step 1/5 (Valley) [load]: quest a"))
		assert.truthy(find(mock.printed, "Step 2/5 (Valley) [auto]: quest b"))
		assert.truthy(find(mock.printed, "Step 3/5 (Valley) [manual]: quest c"))
	end)
end)

describe("re-parse on a profession plan change", function()
	local function tracked()
		return route({
			{ "quest a" },
			{ track = "skinning", n = 1, "trainprof skinning" },
			{ "quest b" },
			{ track = "skinning", n = 2, "sticky flag skin50" },
			{ "quest c" },
			{ "quest d" },
		})
	end
	local function withTrack()
		return { primary = { "skinning" }, secondary = {}, declined = {} }
	end

	it("keeps the current step by id and starts the stickies inserted behind it", function()
		local ns, _, world, log = session({ def = tracked(), flags = { a = true, b = true } })
		local step, index = ns.Progress:Current()
		assert.are.same({ "valley:3", 3 }, { step.id, index })
		world.plan = withTrack()
		ns.Events:Fire("PROFESSION_PLAN_CHANGED", world.plan)
		step, index = ns.Progress:Current()
		assert.are.same({ "valley:3", 5 }, { step.id, index })
		assert.are.equal(2, #log.loaded)
		assert.are.same({ id = "valley:3", index = 5, reason = "load" }, log.steps[#log.steps])
		assert.are.equal("track:skinning:2", ns.Progress:Sticky()[1].id)
	end)

	it("moves to the next remaining step when the current one leaves the route", function()
		local ns, _, world = session({ def = tracked(), plan = withTrack(), flags = { a = true } })
		assert.are.equal("track:skinning:1", current(ns))
		world.plan = { primary = {}, secondary = {}, declined = {} }
		ns.Events:Fire("PROFESSION_PLAN_CHANGED", world.plan)
		assert.are.equal("valley:2", current(ns))
	end)

	it("declines a profession whose teaching step is skipped; back right after restores it", function()
		local ns, _, world = session({ def = tracked(), plan = withTrack(), flags = { a = true } })
		assert.are.equal("track:skinning:1", current(ns))
		slash("skip")
		assert.is_true(world.plan.declined.skinning)
		assert.are.equal("valley:2", current(ns))
		assert.is_nil(ns.Progress:Guide().byId["track:skinning:1"])
		slash("back")
		assert.is_nil(world.plan.declined.skinning)
		assert.are.equal("track:skinning:1", current(ns))
		assert.is_nil(record(ns).skipped["track:skinning:1"])
	end)
end)

describe("dungeon chapters", function()
	local function withDungeon()
		return {
			id = GUIDE_ID,
			name = "Test Guide",
			headers = {},
			chapters = {
				{ id = "zone", name = "Zone", levels = { 10, 16 }, steps = { { "quest a" }, { "quest b" } } },
				{
					id = "caves",
					name = "Test Caverns",
					levels = { 17, 20 },
					dungeon = true,
					steps = { { "note" }, { "quest x" }, { "quest y" } },
				},
				{ id = "after", name = "After", levels = { 20, 25 }, steps = { { "quest c" }, { "quest d" } } },
			},
		}
	end
	local BEFORE = { a = true, b = true }

	it("skip chapter marks every step of the dungeon skipped and moves past it, saved", function()
		local ns = session({ def = withDungeon(), flags = BEFORE })
		assert.are.equal("caves:1", current(ns))
		slash("skip chapter")
		assert.are.equal("after:1", current(ns))
		for _, id in ipairs({ "caves:1", "caves:2", "caves:3" }) do
			assert.is_true(record(ns).skipped[id], id)
		end
		assert.is_true(ns.Progress:ChapterSkipped(2))
		local again = reload(ns, { def = withDungeon(), flags = BEFORE })
		assert.are.equal("after:1", current(again))
		assert.is_true(again.Progress:ChapterSkipped(2))
	end)

	it("is passed when skipped ahead of time, and the toggle turns back", function()
		local ns, mock, world = session({ def = withDungeon() })
		assert.is_true(ns.Progress:SetChapterSkipped(2, true))
		assert.are.equal("zone:1", current(ns))
		world.flags.a, world.flags.b = true, true
		changed(ns, mock)
		assert.are.equal("after:1", current(ns))
		assert.is_true(ns.Progress:SetChapterSkipped(2, false))
		assert.is_false(ns.Progress:ChapterSkipped(2))
		assert.are.equal("after:1", current(ns))
	end)

	it("is the only kind of chapter that can be skipped whole", function()
		local ns, mock = session({ def = withDungeon() })
		slash("skip chapter")
		assert.are.equal("zone:1", current(ns))
		assert.truthy(find(mock.printed, "Only dungeon chapters can be skipped as a whole."))
	end)

	it("is passed silently when all its quests are already done", function()
		local ns = session({ def = withDungeon(), flags = { a = true, b = true, x = true, y = true } })
		assert.are.equal("after:1", current(ns))
		assert.is_true(record(ns).done["caves:1"])
		assert.is_nil(record(ns).skipped["caves:1"])
	end)

	it("comes with a one-time offer to skip it 5+ levels above its maximum", function()
		local ns, mock, _, log = session({ def = withDungeon(), flags = BEFORE, level = 25 })
		assert.are.equal("caves:1", current(ns))
		assert.are.same({ "Test Caverns" }, log.offers)
		assert.truthy(find(mock.printed, "You are 5 levels above Test Caverns (up to level 20)."))
		local _, _, _, log2 = reload(ns, { def = withDungeon(), flags = BEFORE, level = 25 })
		assert.are.same({}, log2.offers)
	end)

	it("comes without the offer less than 5 levels above its maximum", function()
		local _, _, _, log = session({ def = withDungeon(), flags = BEFORE, level = 24 })
		assert.are.same({}, log.offers)
	end)
end)
