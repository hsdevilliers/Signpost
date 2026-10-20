-- ns.Conditions (Engine/Conditions.lua): step completion, pins and display lines from the step's directives, against
-- a fake ns.Context (tests/mocks/directives.lua).
local addon = dofile("tests/helpers/addon.lua")
local mocks = dofile("tests/mocks/directives.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local SKINNING = { skillLine = 393, primary = true, gathering = true, ranks = { 75, 150, 225, 300 } }

local function isComplete(ns, step, context, states)
	return (ns.Conditions:IsComplete(step, context, states or {}))
end

describe("completion", function()
	local ns, context
	before_each(function()
		ns = mocks.load({ professions = { skinning = SKINNING } })
		context = mocks.context()
	end)

	it("a .goto alone completes on arrival", function()
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7" })
		local complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_false(complete)
		assert.is_false(detail[1])
		assert.is_nil(detail.manual)
		context:Near(1411, 42.1, 68.7, 4)
		assert.is_true(isComplete(ns, step, context))
	end)

	it("a .goto beside display directives still completes on arrival", function()
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", ".note Look out for the hut.", ".hub razorhill" })
		assert.is_false(isComplete(ns, step, context))
		context:Near(1411, 42.1, 68.7, 4)
		assert.is_true(isComplete(ns, step, context))
	end)

	it("a .goto beside another completable directive only places the pin", function()
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", ".accept 787" })
		context:Near(1411, 42.1, 68.7, 4)
		local complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_false(complete)
		assert.is_true(detail[1])
		assert.is_false(detail[2])
		context:Near(1411, 42.1, 68.7, 500)
		context.log[787] = true
		assert.is_true(isComplete(ns, step, context))
	end)

	it("every counted directive must be satisfied", function()
		local step = mocks.step(ns, { ".turnin 4641", ".accept 787", ".level 2" })
		context.completed[4641], context.log[787] = true, true
		assert.is_false(isComplete(ns, step, context))
		context.level = 2
		assert.is_true(isComplete(ns, step, context))
	end)

	it("directives about an .optional quest do not block the step", function()
		local step = mocks.step(ns, {
			".goto 1411,42.1,68.7",
			".turnin 4641",
			".accept 787",
			".accept 4402 >> Cutting Teeth (if offered)",
			".optional 4402",
		})
		context.completed[4641], context.log[787] = true, true
		local complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_true(complete)
		assert.is_false(detail[4])
		assert.is_nil(detail[5]) -- .optional itself cannot be satisfied
	end)

	it("reads optional quests from step.optional when the .optional line is not among the directives", function()
		local step = mocks.step(ns, { ".accept 787", ".accept 4402" })
		step.optional = { [4402] = true }
		context.log[787] = true
		assert.is_true(isComplete(ns, step, context))
	end)

	it("a step with nothing but optional quests completes once they are done", function()
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", ".accept 4402", ".optional 4402" })
		context:Near(1411, 42.1, 68.7, 4)
		local complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_false(complete) -- the .goto is not the only completable directive
		assert.is_nil(detail.manual)
		context.log[4402] = true
		assert.is_true(isComplete(ns, step, context))
	end)

	it("note-only steps never complete by themselves", function()
		context.level, context.log[787] = 60, true
		context:Near(1411, 42.1, 68.7, 0)
		for _, lines in ipairs({
			{ ".note Only if you want the pet chain now." },
			{ ".text Kaltunk stands at the Den entrance." },
			{ ".link https://example.org/x" },
			{ ".hub razorhill" },
			{ ".note a", ".text b", ".link https://example.org/y", ".use 5070", ".reward 787,2" },
			{ ".goto 1411,42.1,68.7", ".goto 1411,50,50" }, -- two .goto lines: neither is the only one
		}) do
			local step = mocks.step(ns, lines)
			local complete, detail = ns.Conditions:IsComplete(step, context, {})
			assert.is_false(complete, lines[1])
			assert.is_true(detail.manual, lines[1])
		end
	end)

	it("a .todo beside another completable directive is only a note: the step completes on the other one", function()
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", '.todo "Position not in the data pack yet"' })
		assert.is_false(isComplete(ns, step, context)) -- not there yet
		context:Near(1411, 42.1, 68.7, 0)
		assert.is_true(isComplete(ns, step, context)) -- arrived: the todo does not hold it
	end)

	it("a step that is only a .todo still waits for the player", function()
		local step = mocks.step(ns, { '.todo "Cat Form: IDs pending"' })
		assert.is_false((ns.Conditions:IsComplete(step, context, {})))
	end)

	it("an empty step waits for the player", function()
		local complete, detail = ns.Conditions:IsComplete({ id = "x:1", directives = {} }, context, {})
		assert.is_false(complete)
		assert.is_true(detail.manual)
		assert.is_false((ns.Conditions:IsComplete(nil, context)))
	end)

	it("uses ns.Context when no context is given", function()
		local step = mocks.step(ns, { ".level 5" })
		ns.Context = mocks.context({ level = 5 })
		assert.is_true((ns.Conditions:IsComplete(step)))
	end)

	it("a directive that raises counts as unsatisfied and its error is logged", function()
		ns.Directives:Register("broken", {
			parse = function()
				return {}
			end,
			isSatisfied = function()
				error("broken directive")
			end,
		})
		local step = mocks.step(ns, { ".level 1", ".broken" })
		local complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_false(complete)
		assert.is_true(detail[1])
		assert.is_false(detail[2])
		assert.are.equal(1, #ns.db.errors)
		assert.truthy(ns.db.errors[1].msg:find("broken directive", 1, true))
	end)
end)

describe("sticky directives", function()
	local ns, context
	before_each(function()
		ns = mocks.load({ professions = { skinning = SKINNING } })
		context = mocks.context({ skills = { [393] = { 10, 75 } } })
	end)

	it("a step with nothing but sticky directives is complete at once", function()
		local step = mocks.step(ns, { ".sticky .skill skinning 50" })
		local complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_true(complete)
		assert.is_nil(detail.manual)
	end)

	it("never hold a step up", function()
		local step = mocks.step(ns, { ".accept 787", ".sticky .skill skinning 50" })
		assert.is_false(isComplete(ns, step, context))
		context.log[787] = true
		assert.is_true(isComplete(ns, step, context))
	end)

	it("StickyComplete says when a step's stickies are done", function()
		local step = mocks.step(ns, { ".accept 787", ".sticky .skill skinning 50", ".sticky .level 5" })
		local done, detail = ns.Conditions:StickyComplete(step, context, {})
		assert.is_false(done)
		assert.are.same({ false, false }, detail)
		context.skills[393], context.level = { 50, 75 }, 5
		done, detail = ns.Conditions:StickyComplete(step, context, {})
		assert.is_true(done)
		assert.are.same({ true, true }, detail)
		assert.is_true((ns.Conditions:StickyComplete(mocks.step(ns, { ".accept 787" }), context, {})))
	end)

	it("a .sticky line left wrapped among step.directives is treated the same", function()
		local step = {
			id = "x:1",
			directives = {
				assert(ns.Directives:ParseLine(".sticky .level 5 >> Reach level 5 on the way")),
				assert(ns.Directives:ParseLine(".accept 787")),
			},
		}
		context.log[787] = true
		assert.is_true(isComplete(ns, step, context))
		assert.is_false((ns.Conditions:StickyComplete(step, context, {})))
		local lines, info = ns.Conditions:Describe(step, context, {})
		assert.are.same({ 'Accept "Quest #787"', "Reach level 5 on the way" }, lines)
		assert.is_true(info[2].sticky)
		assert.are.equal(1, info[2].directive)
	end)

	it("keep their state in states.sticky", function()
		local step = mocks.step(ns, { ".accept 787", ".sticky .trainprof skinning" })
		local states = ns.Conditions:Start(step, context, {})
		assert.is_true(states.sticky[1].started)
		assert.are.equal(75, states.sticky[1].max)
		context.skills[393] = { 50, 150 }
		assert.is_true((ns.Conditions:StickyComplete(step, context, states)))
	end)
end)

describe(".craft counting", function()
	local function cast(mock, unit, spellID)
		mock.fire("UNIT_SPELLCAST_SUCCEEDED", unit, "Cast-3-0-0-0-" .. tostring(spellID), spellID)
	end

	it("counts the player's casts of the recipe since the step became current", function()
		local ns, mock = mocks.load()
		local step = mocks.step(ns, { ".craft 2152,3" })
		local context = mocks.context()
		local states = {}
		cast(mock, "player", 2152) -- before the step became current: not counted
		ns.Conditions:Start(step, context, states)
		assert.are.equal(0, states[1].count)
		assert.is_false(isComplete(ns, step, context, states))
		cast(mock, "player", 2152)
		cast(mock, "target", 2152) -- someone else's cast
		cast(mock, "player", 9999) -- another spell
		assert.are.equal(1, states[1].count)
		cast(mock, "player", 2152)
		assert.is_false(isComplete(ns, step, context, states))
		cast(mock, "player", 2152)
		assert.is_true(isComplete(ns, step, context, states))
		assert.are.same({ "Craft Spell #2152 (3/3)" }, (ns.Conditions:Describe(step, context, states)))
		assert.are.same({}, mock.errors)
	end)

	it("tells the engine to evaluate after a counted cast", function()
		local ns, mock = mocks.load()
		local seen = {}
		ns.Events:RegisterMessage("CONTEXT_CHANGED", function(_, what)
			seen[#seen + 1] = what
		end)
		local step = mocks.step(ns, { ".craft 2152,3" })
		ns.Conditions:Start(step, mocks.context(), {})
		cast(mock, "player", 9999)
		cast(mock, "player", 2152)
		assert.are.same({ "casts" }, seen)
	end)

	it("keeps the count when the step is started again", function()
		local ns, mock = mocks.load()
		local step = mocks.step(ns, { ".craft 2152,3" })
		local context, states = mocks.context(), {}
		ns.Conditions:Start(step, context, states)
		cast(mock, "player", 2152)
		ns.Conditions:Start(step, context, states)
		cast(mock, "player", 2152)
		assert.are.equal(2, states[1].count)
	end)

	it("a sticky .craft keeps counting beside later steps", function()
		local ns, mock = mocks.load()
		local step = mocks.step(ns, { ".level 1", ".sticky .craft 2152,2" })
		local context, states = mocks.context(), {}
		ns.Conditions:Start(step, context, states)
		assert.is_true(isComplete(ns, step, context, states))
		cast(mock, "player", 2152)
		assert.is_false((ns.Conditions:StickyComplete(step, context, states)))
		cast(mock, "player", 2152)
		assert.is_true((ns.Conditions:StickyComplete(step, context, states)))
	end)

	it("is not satisfied without a started state", function()
		local ns = mocks.load()
		local step = mocks.step(ns, { ".craft 2152,1" })
		assert.is_false((ns.Conditions:IsComplete(step, mocks.context())))
		assert.is_false(isComplete(ns, step, mocks.context(), {}))
	end)
end)

describe(".trainprof", function()
	it("completes when the skill maximum rises after the step became current", function()
		local ns = mocks.load({ professions = { skinning = SKINNING } })
		local step = mocks.step(ns, { ".goto 1454,40,40", ".trainprof skinning" })
		local context = mocks.context({ skills = { [393] = { 70, 75 } } })
		local states = ns.Conditions:Start(step, context, {})
		assert.is_false(isComplete(ns, step, context, states))
		context.skills[393] = { 71, 75 }
		assert.is_false(isComplete(ns, step, context, states))
		context.skills[393] = { 71, 150 }
		assert.is_true(isComplete(ns, step, context, states))
	end)

	it("completes when the profession is learned", function()
		local ns = mocks.load({ professions = { skinning = SKINNING } })
		local step = mocks.step(ns, { ".trainprof skinning" })
		local context = mocks.context()
		local states = ns.Conditions:Start(step, context, {})
		assert.is_false(isComplete(ns, step, context, states))
		context.skills[393] = { 1, 75 }
		assert.is_true(isComplete(ns, step, context, states))
	end)
end)

describe("pins", function()
	local QUEST_PACK = {
		quests = {
			[4641] = { n = "Your Place", e = { npc = { 101 } } },
			[787] = { n = "The Basics", s = { npc = { 101 } }, o = { { k = "kill", id = 201, c = 10 } } },
			[788] = { n = "Next Door", s = { npc = { 102 } } },
			[789] = { n = "Hunt", o = { { k = "kill", id = 201, c = 5 } } },
			[790] = { n = "Giver Unknown" },
		},
		npcs = {
			[101] = { n = "Giver", p = { { 1411, 42.1, 68.7 } } },
			[102] = { n = "Neighbour", p = { { 1411, 45, 70 } } },
			[201] = { n = "Boar", p = { { 1411, 50, 50 } } },
		},
	}

	it("without the data pack, quest givers are pinned at the step's .goto", function()
		local ns = mocks.load()
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", ".turnin 4641", ".accept 787" })
		local context = mocks.context()
		assert.are.same({
			{
				map = 1411,
				x = 42.1,
				y = 68.7,
				kind = "turnin",
				radius = 10,
				label = 'Turn in "Quest #4641"\nAccept "Quest #787"',
				questID = 4641,
				quests = { 4641, 787 },
			},
		}, ns.Conditions:Targets(step, context, {}))
		context.completed[4641] = true
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.equal(1, #pins)
		assert.are.equal("accept", pins[1].kind)
		assert.are.equal('Accept "Quest #787"', pins[1].label)
		assert.are.same({ 787 }, pins[1].quests)
		context.log[787] = true
		assert.are.same({
			{ map = 1411, x = 42.1, y = 68.7, kind = "goto", radius = 10, label = "Go to map 1411 42.1, 68.7" },
		}, ns.Conditions:Targets(step, context, {}))
	end)

	it("a step without a .goto and without the pack has no pins", function()
		local ns = mocks.load()
		assert.are.same({}, ns.Conditions:Targets(mocks.step(ns, { ".accept 787" }), mocks.context(), {}))
		assert.are.same({}, ns.Conditions:Targets(nil, mocks.context(), {}))
	end)

	it("one pin for a quest giver at the .goto, shared by a turn-in and an accept", function()
		local ns = mocks.load({ pack = QUEST_PACK })
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7 >> Into the den", ".turnin 4641", ".accept 787" })
		assert.are.same({
			{
				map = 1411,
				x = 42.1,
				y = 68.7,
				kind = "turnin",
				radius = 10,
				npc = 101,
				label = 'Into the den\nTurn in "Your Place" to Giver\nAccept "The Basics" from Giver',
				questID = 4641,
				quests = { 4641, 787 },
			},
		}, ns.Conditions:Targets(step, mocks.context(), {}))
	end)

	it("an NPC away from the .goto keeps a pin of its own", function()
		local ns = mocks.load({ pack = QUEST_PACK })
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", ".accept 787", ".accept 788" })
		local pins = ns.Conditions:Targets(step, mocks.context(), {})
		assert.are.equal(2, #pins)
		assert.are.same({ "accept", 101, 42.1, 10 }, { pins[1].kind, pins[1].npc, pins[1].x, pins[1].radius })
		assert.are.same({ "accept", 102, 45, 788 }, { pins[2].kind, pins[2].npc, pins[2].x, pins[2].questID })
	end)

	it("measures nearness in yards with HereBeDragons", function()
		local ns = mocks.load({ pack = QUEST_PACK })
		local yards
		G.LibStub = function(name)
			if name == "HereBeDragons-2.0" then
				return {
					GetZoneDistance = function()
						return yards
					end,
				}
			end
		end
		local step = mocks.step(ns, { ".goto 1411,40,60", ".accept 787" })
		yards = 8
		assert.are.equal(1, #ns.Conditions:Targets(step, mocks.context(), {}))
		yards = 30
		assert.are.equal(2, #ns.Conditions:Targets(step, mocks.context(), {}))
	end)

	it("spots and waypoints near a .goto keep their own pins", function()
		local ns = mocks.load()
		local step = mocks.step(ns, { ".goto 1411,55,70", ".fish 1411,55,70", ".skill skinning 10" })
		local pins = ns.Conditions:Targets(step, mocks.context(), {})
		assert.are.same({ "goto", "fish" }, { pins[1].kind, pins[2].kind })
	end)

	it("objective areas from the pack; sticky pins are marked and never take over the .goto", function()
		local ns = mocks.load({ pack = QUEST_PACK, professions = { skinning = SKINNING } })
		-- 790's giver is not in the pack: its .accept falls back to the .goto
		local step = mocks.step(ns, { ".goto 1411,30,30", ".accept 790", ".sticky .complete 789" })
		local pins = ns.Conditions:Targets(step, mocks.context(), {})
		assert.are.equal(2, #pins)
		assert.are.same({ "accept", 30, 790 }, { pins[1].kind, pins[1].x, pins[1].questID })
		assert.is_nil(pins[1].sticky)
		assert.are.same({ "objective", 201, true, 789 }, { pins[2].kind, pins[2].npc, pins[2].sticky, pins[2].questID })
		local context = mocks.context({ ready = { [789] = true } })
		pins = ns.Conditions:Targets(step, context, {})
		assert.are.equal(1, #pins) -- a satisfied sticky has no pins
	end)

	it("a directive whose targets raise loses only its own pins", function()
		local ns = mocks.load()
		ns.Directives:Register("broken", {
			parse = function()
				return {}
			end,
			targets = function()
				error("broken targets")
			end,
		})
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", ".broken" })
		local pins = ns.Conditions:Targets(step, mocks.context(), {})
		assert.are.equal(1, #pins)
		assert.are.equal("goto", pins[1].kind)
		assert.are.equal(1, #ns.db.errors)
	end)

	it("drops malformed targets", function()
		local ns = mocks.load()
		ns.Directives:Register("odd", {
			parse = function()
				return {}
			end,
			targets = function()
				return {
					{ map = "1411", x = 1, y = 2 },
					{ x = 1, y = 2 },
					"pin",
					{ map = 1411, x = 1, y = 2, kind = "dock" },
				}
			end,
		})
		local pins = ns.Conditions:Targets(mocks.step(ns, { ".odd" }), mocks.context(), {})
		assert.are.same({ { map = 1411, x = 1, y = 2, kind = "dock" } }, pins) -- no describe, no label
	end)
end)

describe("display lines", function()
	local ns, context
	before_each(function()
		ns = mocks.load({ professions = { skinning = SKINNING } })
		context = mocks.context()
	end)

	local function lines(directiveLines, states)
		return (ns.Conditions:Describe(mocks.step(ns, directiveLines), context, states))
	end

	it("a bare .goto describes itself; beside other lines it only pins", function()
		assert.are.same({ "Go to map 1411 42.1, 68.7" }, lines({ ".goto 1411,42.1,68.7" }))
		assert.are.same({ 'Accept "Quest #787"' }, lines({ ".goto 1411,42.1,68.7", ".accept 787" }))
		assert.are.same({ "Raise skinning to 75" }, lines({ ".fish 1411,55,70", ".skill skinning 75" }))
	end)

	it(">> text replaces a line's description", function()
		assert.are.same(
			{ "Run to the hut", "Talk to her" },
			lines({ ".goto 1411,42.1,68.7 >> Run to the hut", ".accept 787 >> Talk to her" })
		)
	end)

	it("takes a >> override with or without its marker", function()
		local step = mocks.step(ns, { ".accept 787", ".level 5" })
		step.directives[1].text = ">>  Talk to her  "
		step.directives[2].text = "   "
		assert.are.same({ "Talk to her", "Reach level 5" }, (ns.Conditions:Describe(step, context, {})))
	end)

	it(".text, .note and .link add lines of their own", function()
		assert.are.same(
			{ 'Accept "Quest #787"', "Up the ramp.", "Optional.", "https://example.org/x" },
			lines({ ".accept 787", ".text Up the ramp.", ".note Optional.", ".link https://example.org/x", ".hub x" })
		)
	end)

	it("objective progress follows its .complete line", function()
		context.objectives[787] = { { text = "Boar slain: 3/10", finished = false } }
		local described, info = ns.Conditions:Describe(mocks.step(ns, { ".complete 787", ".accept 788" }), context, {})
		assert.are.same({ 'Complete "Quest #787"', "- Boar slain: 3/10", 'Accept "Quest #788"' }, described)
		assert.is_true(info[2].progress)
		assert.are.equal(1, info[2].directive)
		assert.is_nil(info[1].progress)
	end)

	it("sticky lines come last and are marked", function()
		local described, info = ns.Conditions:Describe(
			mocks.step(ns, { ".sticky .skill skinning 50 >> Skin everything", ".accept 787" }),
			context,
			{}
		)
		assert.are.same({ 'Accept "Quest #787"', "Skin everything" }, described)
		assert.is_nil(info[1].sticky)
		assert.is_true(info[2].sticky)
	end)

	it("marks which lines are done", function()
		context.log[787] = true
		local _, info =
			ns.Conditions:Describe(mocks.step(ns, { ".accept 787", ".turnin 4641", ".note x" }), context, {})
		assert.are.same({ true, false }, { info[1].done, info[2].done })
		assert.is_nil(info[3].done)
	end)

	it("shows the class quest line once per step", function()
		ns = mocks.load({
			classes = {
				HUNTER = { trainerSpells = {}, classQuests = { { name = "Path", level = 1, quests = { 6061 } } } },
			},
		})
		assert.are.same(
			{ "Train your class spells", "Class quest available here: Path", "Train Spell #1494" },
			lines({ ".train class", ".train 1494" })
		)
	end)

	it("a describe that raises shows the raw directive", function()
		ns.Directives:Register("broken", {
			parse = function()
				return {}
			end,
			describe = function()
				error("broken describe")
			end,
		})
		assert.are.same({ ".broken" }, lines({ ".broken" }))
		assert.are.equal(1, #ns.db.errors)
	end)

	it("a note-only step shows its note; nothing for a nil step", function()
		assert.are.same(
			{ "Only if you want the pet chain now." },
			lines({ ".note Only if you want the pet chain now." })
		)
		assert.are.same({}, (ns.Conditions:Describe(nil, context)))
	end)
end)

describe("Start and Kind", function()
	it("Start calls every onStart and returns the states, sticky ones under states.sticky", function()
		local ns = mocks.load({ professions = { skinning = SKINNING } })
		local step = mocks.step(ns, { ".trainprof skinning", ".craft 2152,1", ".sticky .craft 2152,2" })
		local states = ns.Conditions:Start(step, mocks.context({ skills = { [393] = { 5, 75 } } }))
		assert.are.same({ started = true, learned = true, max = 75 }, states[1])
		assert.are.same({ started = true, count = 0 }, states[2])
		assert.are.same({ started = true, count = 0 }, states.sticky[1])
		assert.are.same({}, ns.Conditions:Start(nil, mocks.context()))
	end)

	it("Kind is the first completable directive's kind other than .goto", function()
		local ns = mocks.load()
		local function kind(directiveLines)
			return ns.Conditions:Kind(mocks.step(ns, directiveLines))
		end
		assert.are.equal("quest", kind({ ".goto 1411,1,1", ".accept 787" }))
		assert.are.equal("travel", kind({ ".goto 1411,1,1" }))
		assert.are.equal("profession", kind({ ".note x", ".trainprof skinning" }))
		assert.are.equal("misc", kind({ ".note x" }))
		assert.are.equal("misc", kind({}))
		assert.are.equal("misc", ns.Conditions:Kind(nil))
	end)
end)
