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

	it("a doing step completes when every one of its quests is complete, wherever the player stands", function()
		local step = mocks.step(ns, { ".goto 1411,43.2,71.7", ".complete 787", ".complete 788", ".complete 789" })
		context.log[787], context.log[788] = true, true
		context.objectives[787] = { { text = "Boar slain: 10/10", finished = true } }
		context.objectives[788] = { { text = "Scorpids slain: 3/5", finished = false } }
		local complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_false(complete)
		assert.are.same({ false, true, false, false }, { detail[1], detail[2], detail[3], detail[4] })
		context.ready[788] = true -- the quest log says it can be handed in
		assert.is_false(isComplete(ns, step, context)) -- 789 is not even in the log yet
		context.completed[789] = true -- or it was handed in already
		complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_true(complete)
		assert.is_false(detail[1]) -- the player never went near the .goto: it does not hold the step or end it
	end)

	it(".complete <quest>,<objective> is satisfied by that one objective alone", function()
		local step = mocks.step(ns, { ".goto 1411,43.2,71.7", ".complete 787,2" })
		context.log[787] = true
		context.objectives[787] =
			{ { text = "Boars: 0/10", finished = false }, { text = "Hides: 5/5", finished = true } }
		assert.is_true(isComplete(ns, step, context))
		context.objectives[787][2].finished = false
		assert.is_false(isComplete(ns, step, context))
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

	it("a step with nothing but optional quests never holds the player up: see 'optional-only steps' below", function()
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", ".accept 4402", ".optional 4402" })
		context:Near(1411, 42.1, 68.7, 4)
		local complete, detail = ns.Conditions:IsComplete(step, context, {})
		assert.is_true(complete) -- the quest is not in the log: nothing in the step waits for the player
		assert.is_nil(detail.manual)
		assert.is_false(detail[2]) -- its accept is not satisfied, though, and its line stays unmarked
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

-- A step whose completable directives all belong to `.optional` quests is how the planner writes a group quest of a
-- normal route (docs/GUIDE-FORMAT.md "Optional-only steps"): it never holds the player up, unless the player took the
-- quest, and then the quest is not skipped under their feet.
describe("optional-only steps (group quests)", function()
	local ns, context
	before_each(function()
		ns = mocks.load({
			pack = { quests = { [442] = { n = "Assault on Fenris Isle" }, [443] = { n = "Second Hunt" } } },
		})
		context = mocks.context()
	end)

	-- The three shapes the planner writes for one group quest: go and take it, do it, hand it in (and all in one).
	local ACCEPT = { ".goto 1421,65.7,23.7", ".accept 442", ".optional 442" }
	local DOING = { ".goto 1421,65.7,23.7", ".complete 442", ".optional 442" }
	local HAND_IN = { ".goto 1421,43.4,40.9", ".turnin 442", ".optional 442" }
	local ALL_IN_ONE = {
		".goto 1421,65.7,23.7",
		".accept 442",
		'.todo "Assault on Fenris Isle: objective 1 has no position in the pack"',
		".complete 442,1",
		".complete 442,2",
		".turnin 442",
		".optional 442",
	}

	it("never holds the player up while none of its quests is in the quest log", function()
		for _, lines in ipairs({ ACCEPT, DOING, HAND_IN, ALL_IN_ONE }) do
			local complete, detail = ns.Conditions:IsComplete(mocks.step(ns, lines), context, {})
			assert.is_true(complete, lines[2])
			assert.is_nil(detail.manual, lines[2])
		end
		-- the directives themselves are not satisfied: their lines stay unmarked
		local _, detail = ns.Conditions:IsComplete(mocks.step(ns, DOING), context, {})
		assert.is_false(detail[2])
	end)

	it("is the same for the parser's shape: no .optional line among the directives, step.optional instead", function()
		local step = mocks.step(ns, { ".goto 1421,65.7,23.7", ".complete 442", ".optional 442" })
		table.remove(step.directives) -- Engine/Parser.lua keeps .optional out of step.directives
		assert.is_true(isComplete(ns, step, context))
		context.log[442] = true
		context.objectives[442] = { { text = "Fenris Keep: 0/1", finished = false } }
		assert.is_false(isComplete(ns, step, context))
	end)

	it("is the same wherever the player stands: a .goto beside the quests places the pin and nothing else", function()
		local step = mocks.step(ns, DOING)
		context:Near(1421, 65.7, 23.7, 4000)
		assert.is_true(isComplete(ns, step, context))
		context.log[442] = true
		context.objectives[442] = { { text = "Fenris Keep: 0/1", finished = false } }
		context:Near(1421, 65.7, 23.7, 3) -- at the .goto, the quest still open: the .goto does not end the step
		assert.is_false(isComplete(ns, step, context))
	end)

	it("a quest the player took decides the step, as in any step: it is not skipped under their feet", function()
		context.log[442] = true
		-- accepted: the accept line is satisfied
		assert.is_true(isComplete(ns, mocks.step(ns, ACCEPT), context))
		-- done step: the quest's objectives
		context.objectives[442] = { { text = "Fenris Keep: 0/1", finished = false } }
		assert.is_false(isComplete(ns, mocks.step(ns, DOING), context))
		context.objectives[442][1].finished = true
		assert.is_true(isComplete(ns, mocks.step(ns, DOING), context))
		context.objectives[442][1].finished = false
		context.ready[442] = true -- or the quest log says it can be handed in
		assert.is_true(isComplete(ns, mocks.step(ns, DOING), context))
		-- hand-in step: only the turn-in ends it
		assert.is_false(isComplete(ns, mocks.step(ns, HAND_IN), context))
		context.log[442], context.completed[442] = nil, true
		assert.is_true(isComplete(ns, mocks.step(ns, HAND_IN), context))
	end)

	it("a step that does it all waits for every one of its lines once the quest is taken", function()
		local step = mocks.step(ns, ALL_IN_ONE)
		assert.is_true(isComplete(ns, step, context)) -- not taken: passed
		context.log[442] = true
		context.objectives[442] = { { text = "One: 0/1", finished = false }, { text = "Two: 0/1", finished = false } }
		assert.is_false(isComplete(ns, step, context))
		context.objectives[442][1].finished, context.objectives[442][2].finished = true, true
		context.ready[442] = true
		assert.is_false(isComplete(ns, step, context)) -- the turn-in is left
		context.log[442], context.completed[442] = nil, true
		assert.is_true(isComplete(ns, step, context))
	end)

	it("a quest the player has handed in already never holds it either", function()
		context.completed[442] = true
		for _, lines in ipairs({ ACCEPT, DOING, HAND_IN, ALL_IN_ONE }) do
			assert.is_true(isComplete(ns, mocks.step(ns, lines), context), lines[2])
		end
	end)

	it("of two optional quests only the one the player took decides", function()
		local step = mocks.step(
			ns,
			{ ".goto 1421,65.7,23.7", ".complete 442", ".complete 443", ".optional 442", ".optional 443" }
		)
		assert.is_true(isComplete(ns, step, context)) -- neither taken
		context.log[442] = true
		context.objectives[442] = { { text = "One: 0/1", finished = false } }
		assert.is_false(isComplete(ns, step, context)) -- 442 is open; 443 never mattered
		context.objectives[442][1].finished = true
		assert.is_true(isComplete(ns, step, context)) -- done with the one taken, the other left alone
		context.log[443] = true -- and taking the other one as well makes it count too
		context.objectives[443] = { { text = "Two: 0/1", finished = false } }
		assert.is_false(isComplete(ns, step, context))
	end)

	it("an optional quest beside a directive that counts still does not count", function()
		local step = mocks.step(ns, { ".goto 1421,43.4,40.9", ".turnin 446", ".accept 442", ".optional 442" })
		assert.is_false(isComplete(ns, step, context))
		context.completed[446] = true
		assert.is_true(isComplete(ns, step, context)) -- the old rule: the group quest never mattered
		assert.is_nil(ns.Conditions:OptionalOnly(step, context))
	end)

	it("a step with any other completable directive is not an optional-only step", function()
		for _, line in ipairs({ ".level 5", ".skill skinning 5", ".train class", ".buy 401,5", ".craft 2152,1" }) do
			local step = mocks.step(ns, { ".goto 1421,65.7,23.7", ".accept 442", line, ".optional 442" })
			assert.is_nil(ns.Conditions:OptionalOnly(step, context), line)
			assert.is_false(isComplete(ns, step, context), line) -- the other directive decides
		end
	end)

	it(
		"a .todo or a .note beside the optional quests does not change that, and an .optional alone is not one",
		function()
			local step =
				mocks.step(ns, { ".goto 1421,65.7,23.7", ".accept 442", ".note Bring a friend.", ".optional 442" })
			assert.is_true(isComplete(ns, step, context))
			assert.is_table(ns.Conditions:OptionalOnly(step, context))
			-- no directive of the quest at all: a lone .goto decides, and the step is not an optional-only one
			local lone = mocks.step(ns, { ".goto 1421,65.7,23.7", ".optional 442" })
			assert.is_false(isComplete(ns, lone, context))
			assert.is_nil(ns.Conditions:OptionalOnly(lone, context))
			-- a step that is only a .todo and an .optional line waits for the player, as ever
			local todo = mocks.step(ns, { '.todo "Group quest: IDs pending"', ".optional 442" })
			assert.is_false(isComplete(ns, todo, context))
			assert.is_nil(ns.Conditions:OptionalOnly(todo, context))
		end
	)

	it("sticky directives beside it never hold it up either", function()
		local step = mocks.step(ns, { ".accept 442", ".optional 442", ".sticky .level 5" })
		assert.is_true(isComplete(ns, step, context))
		assert.is_table(ns.Conditions:OptionalOnly(step, context))
	end)

	describe("OptionalOnly", function()
		it("is nil for any step that is not one", function()
			local conditions = ns.Conditions
			assert.is_nil(conditions:OptionalOnly(nil, context))
			assert.is_nil(conditions:OptionalOnly(mocks.step(ns, { ".goto 1421,1,1", ".accept 442" }), context))
			assert.is_nil(conditions:OptionalOnly(mocks.step(ns, { ".note Only a note." }), context))
			assert.is_nil(
				conditions:OptionalOnly(mocks.step(ns, { ".accept 787", ".accept 442", ".optional 442" }), context)
			)
		end)

		it(
			"names the quests, once each in directive order, and which of them are still there for the taking",
			function()
				local step = mocks.step(ns, {
					".goto 1421,65.7,23.7",
					".accept 443",
					".accept 442",
					".complete 443",
					".optional 442",
					".optional 443",
				})
				local found = ns.Conditions:OptionalOnly(step, context)
				assert.are.same({ 443, 442 }, found.quests)
				assert.are.same({ 443, 442 }, found.available)
				assert.is_false(found.taken)
				assert.is_false(found.fulfilled)
				context.log[443] = true -- in the log: no longer there for the taking
				context.completed[442] = true -- handed in: done
				found = ns.Conditions:OptionalOnly(step, context)
				assert.are.same({}, found.available)
				assert.is_true(found.taken)
				assert.is_false(found.fulfilled) -- 443 is not complete yet
				context.completed[443] = true
				assert.is_true(ns.Conditions:OptionalOnly(step, context).fulfilled)
			end
		)

		it("reads the quests from step.optional too, and takes the step's states, which it never needs", function()
			local step = mocks.step(ns, { ".accept 442" })
			step.optional = { [442] = true }
			assert.are.same({ 442 }, ns.Conditions:OptionalOnly(step, context).quests)
			assert.are.same({ 442 }, ns.Conditions:OptionalOnly(step, context, {}).available)
		end)
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
		-- everything to do at this place is done: no marker is left behind (the player's rule: a marker shows where to go
		-- next, never where they have been)
		assert.are.same({}, ns.Conditions:Targets(step, context, {}))
	end)

	describe("a step of several places", function()
		local function xs(pins)
			local out = {}
			for _, pin in ipairs(pins) do
				out[#out + 1] = pin.x
			end
			table.sort(out)
			return out
		end

		it("keeps a pin for each place still to do and drops the others as the quests there are done", function()
			local ns = mocks.load()
			local step =
				mocks.step(ns, { ".goto 1411,40,40", ".accept 787", ".goto 1411,42,42", ".turnin 787", ".accept 788" })
			local context = mocks.context()
			assert.are.same({ 40, 42 }, xs(ns.Conditions:Targets(step, context, {})))
			context.log[787] = true -- picked up at the first place: its pin goes, the second place is where to go next
			local pins = ns.Conditions:Targets(step, context, {})
			assert.are.same({ 42 }, xs(pins))
			assert.are.equal("turnin", pins[1].kind)
			context.completed[787] = true -- handed in at the second place, whose next quest is not yet in the log
			assert.are.same({ 42 }, xs(ns.Conditions:Targets(step, context, {})))
			context.log[788] = true
			assert.are.same({}, xs(ns.Conditions:Targets(step, context, {})))
		end)

		it("keeps the pin of a place while any of its quests is still to do", function()
			local ns = mocks.load()
			local step =
				mocks.step(ns, { ".goto 1411,40,40", ".accept 787", ".accept 788", ".goto 1411,42,42", ".accept 789" })
			local context = mocks.context({ log = { [787] = true, [789] = true } })
			assert.are.same({ 40 }, xs(ns.Conditions:Targets(step, context, {}))) -- 788 is not picked up yet
			context.log[788] = true
			assert.are.same({}, xs(ns.Conditions:Targets(step, context, {})))
		end)

		it("keeps the pin of a .goto that has nothing to finish: a waypoint, a lone .goto, one beside notes", function()
			local ns = mocks.load()
			local context = mocks.context({ log = { [787] = true } })
			local waypoint = mocks.step(ns, { ".goto 1411,10,10", ".goto 1411,40,40", ".accept 787" })
			assert.are.same({ 10 }, xs(ns.Conditions:Targets(waypoint, context, {})))
			local lone = mocks.step(ns, { ".goto 1411,10,10", ".note Careful here" })
			assert.are.same({ 10 }, xs(ns.Conditions:Targets(lone, context, {})))
		end)

		it("is not held open by a note, which can never complete", function()
			local ns = mocks.load()
			local step = mocks.step(ns, { ".goto 1411,40,40", ".accept 787", ".note Careful here" })
			local context = mocks.context({ log = { [787] = true } })
			assert.are.same({}, xs(ns.Conditions:Targets(step, context, {})))
		end)

		it("is not held open by a sticky directive, which belongs to no place", function()
			local ns = mocks.load({ professions = { skinning = SKINNING } })
			local step = mocks.step(ns, { ".goto 1411,40,40", ".accept 787", ".sticky .skill skinning 10" })
			local context = mocks.context({ log = { [787] = true } })
			assert.are.same({}, xs(ns.Conditions:Targets(step, context, {})))
		end)
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

-- A pick-up or hand-in step of several NPCs of an area: each NPC's .goto is followed by its directives, and each NPC
-- has one pin with its own quests (docs/GUIDE-FORMAT.md "Step kinds", docs/ENGINE.md Conditions :Targets).
describe("pins of a joined step", function()
	-- Test data, not real: three quest givers a little over a percent apart (more than NEAR_PERCENT), each with a quest.
	local PACK = {
		quests = {
			[787] = { n = "The Basics", s = { npc = { 101 } }, e = { npc = { 101 } } },
			[788] = { n = "Next Door", s = { npc = { 102 } }, e = { npc = { 102 } } },
			[789] = { n = "Third House", s = { npc = { 103 } }, e = { npc = { 103 } } },
		},
		npcs = {
			[101] = { n = "Giver One", p = { { 1411, 43.29, 68.53 } } },
			[102] = { n = "Giver Two", p = { { 1411, 42.06, 68.33 } } },
			[103] = { n = "Giver Three", p = { { 1411, 40.47, 68.0 } } },
		},
	}
	local THREE = {
		".goto 1411,43.29,68.53",
		".accept 787",
		".goto 1411,42.06,68.33",
		".accept 788",
		".goto 1411,40.47,68.0",
		".accept 789",
	}

	-- { kind, quests... } of each pin, and where it stands
	local function summary(pins)
		local out = {}
		for i, pin in ipairs(pins) do
			out[i] = { pin.kind, pin.x, unpack(pin.quests or {}) }
		end
		return out
	end

	it("without the data pack each pin names its own NPC's quests, and goes when they are done", function()
		local ns = mocks.load()
		local step, context = mocks.step(ns, THREE), mocks.context()
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "accept", 43.29, 787 }, { "accept", 42.06, 788 }, { "accept", 40.47, 789 } }, summary(pins))
		assert.are.same(
			{ 'Accept "Quest #787"', 'Accept "Quest #788"', 'Accept "Quest #789"' },
			{ pins[1].label, pins[2].label, pins[3].label }
		)
		assert.are.same({ 787, 788, 789 }, { pins[1].questID, pins[2].questID, pins[3].questID })
		-- one accepted: its pin is gone and the others do not name it
		context.log[787] = true
		pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "accept", 42.06, 788 }, { "accept", 40.47, 789 } }, summary(pins))
		assert.are.same({ 'Accept "Quest #788"', 'Accept "Quest #789"' }, { pins[1].label, pins[2].label })
		-- another one handed in already counts the same
		context.completed[789] = true
		assert.are.same({ { "accept", 42.06, 788 } }, summary(ns.Conditions:Targets(step, context, {})))
		context.log[788] = true
		assert.are.same({}, ns.Conditions:Targets(step, context, {})) -- nothing left to visit
		assert.are.same({}, ns.db.errors)
	end)

	it("with the data pack each NPC's pin is the NPC, and it goes when its quests are done", function()
		local ns = mocks.load({ pack = PACK })
		local step, context = mocks.step(ns, THREE), mocks.context()
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "accept", 43.29, 787 }, { "accept", 42.06, 788 }, { "accept", 40.47, 789 } }, summary(pins))
		assert.are.same({ 101, 102, 103 }, { pins[1].npc, pins[2].npc, pins[3].npc })
		assert.are.equal('Accept "The Basics" from Giver One', pins[1].label)
		assert.are.equal('Accept "Third House" from Giver Three', pins[3].label)
		context.log[787] = true
		pins = ns.Conditions:Targets(step, context, {})
		-- not a generic "Go to" pin where the finished NPC stands: nothing is drawn there
		assert.are.same({ { "accept", 42.06, 788 }, { "accept", 40.47, 789 } }, summary(pins))
		assert.are.same({ 102, 103 }, { pins[1].npc, pins[2].npc })
		context.log[788], context.log[789] = true, true
		assert.are.same({}, ns.Conditions:Targets(step, context, {}))
	end)

	it("a turn-in and a pick-up at one NPC share its pin, whatever the other NPCs do", function()
		local ns = mocks.load()
		local step = mocks.step(ns, {
			".goto 1411,43.29,68.53",
			".turnin 787",
			".accept 788",
			".goto 1411,42.06,68.33",
			".accept 789",
		})
		local context = mocks.context()
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "turnin", 43.29, 787, 788 }, { "accept", 42.06, 789 } }, summary(pins))
		assert.are.equal('Turn in "Quest #787"\nAccept "Quest #788"', pins[1].label)
		context.completed[787] = true
		pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "accept", 43.29, 788 }, { "accept", 42.06, 789 } }, summary(pins))
	end)

	it("a directive before the first .goto marks the first .goto", function()
		local ns = mocks.load()
		local step =
			mocks.step(ns, { ".accept 787", ".goto 1411,43.29,68.53", ".goto 1411,42.06,68.33", ".accept 788" })
		local pins = ns.Conditions:Targets(step, mocks.context(), {})
		assert.are.same({ { "accept", 43.29, 787 }, { "accept", 42.06, 788 } }, summary(pins))
	end)

	it("keeps the .goto's own '>>' text and adds the quests under it", function()
		local ns = mocks.load()
		local step = mocks.step(
			ns,
			{ ".goto 1411,43.29,68.53 >> Talk to the first", ".accept 787", ".goto 1411,42.06,68.33", ".accept 788" }
		)
		local pins = ns.Conditions:Targets(step, mocks.context(), {})
		assert.are.equal('Talk to the first\nAccept "Quest #787"', pins[1].label)
		assert.are.equal('Accept "Quest #788"', pins[2].label)
	end)

	it("a finished .goto does not take the pin of an NPC still to visit", function()
		-- the two givers stand within the nearness limit of both .goto lines: the first .goto would take the second
		-- giver's pin once its own giver's pin is gone, if it still drew
		local ns = mocks.load({
			pack = {
				quests = {
					[787] = { n = "The Basics", s = { npc = { 101 } } },
					[788] = { n = "Next Door", s = { npc = { 102 } } },
				},
				npcs = {
					[101] = { n = "Giver One", p = { { 1411, 43.0, 68.5 } } },
					[102] = { n = "Giver Two", p = { { 1411, 43.2, 68.6 } } },
				},
			},
		})
		local step = mocks.step(ns, { ".goto 1411,43.0,68.5", ".accept 787", ".goto 1411,43.2,68.6", ".accept 788" })
		local context = mocks.context()
		assert.are.equal(2, #ns.Conditions:Targets(step, context, {}))
		context.log[787] = true
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.equal(1, #pins)
		assert.are.same({ "accept", 102, 43.2, 788 }, { pins[1].kind, pins[1].npc, pins[1].x, pins[1].questID })
		assert.are.equal('Accept "Next Door" from Giver Two', pins[1].label)
	end)

	it("a .goto-only step is unchanged: each .goto keeps its pin and its 'Go to' label", function()
		local ns = mocks.load()
		local context = mocks.context()
		context:Near(1411, 43.29, 68.53, 0) -- standing on it changes nothing
		local pins = ns.Conditions:Targets(mocks.step(ns, { ".goto 1411,43.29,68.53" }), context, {})
		assert.are.same({ { "goto", 43.29 } }, summary(pins))
		assert.are.equal("Go to map 1411 43.3, 68.5", pins[1].label)
		-- two .goto lines and no directive at all
		pins =
			ns.Conditions:Targets(mocks.step(ns, { ".goto 1411,43.29,68.53", ".goto 1411,42.06,68.33" }), context, {})
		assert.are.same({ { "goto", 43.29 }, { "goto", 42.06 } }, summary(pins))
		-- a .note behind a .goto names no quest and asks nothing; a .level not reached keeps its place open
		pins = ns.Conditions:Targets(
			mocks.step(ns, { ".goto 1411,43.29,68.53", ".note Wait here.", ".goto 1411,42.06,68.33", ".level 3" }),
			context,
			{}
		)
		assert.are.same({ { "goto", 43.29 }, { "goto", 42.06 } }, summary(pins))
	end)

	it("the pin of a single-.goto step names its quests, and keeps a bare 'Go to' while its place is open", function()
		local ns = mocks.load()
		local step = mocks.step(ns, { ".goto 1411,43.29,68.53", ".accept 787", ".accept 788", ".level 5" })
		local context = mocks.context()
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "accept", 43.29, 787, 788 } }, summary(pins))
		context.log[787], context.log[788] = true, true -- the .level is open: something is left to do at this place
		pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "goto", 43.29 } }, summary(pins))
		assert.are.equal("Go to map 1411 43.3, 68.5", pins[1].label)
		context.level = 5 -- nothing is left to ask at this place
		assert.are.same({}, ns.Conditions:Targets(step, context, {}))
	end)

	it(
		"the last place of a joined step names none of the quests done, and goes when its other lines are done",
		function()
			local ns = mocks.load()
			local step = mocks.step(
				ns,
				{ ".goto 1411,43.29,68.53", ".accept 787", ".goto 1411,42.06,68.33", ".accept 788", ".level 5" }
			)
			local context = mocks.context({ log = { [787] = true, [788] = true } })
			-- the first place is done with; the second still has the .level to ask, and no quest is named on it
			local pins = ns.Conditions:Targets(step, context, {})
			assert.are.same({ { "goto", 42.06 } }, summary(pins))
			assert.are.equal("Go to map 1411 42.1, 68.3", pins[1].label)
			assert.is_false(isComplete(ns, step, context))
			context.level = 5
			assert.are.same({}, ns.Conditions:Targets(step, context, {}))
			assert.is_true(isComplete(ns, step, context))
		end
	)

	it("a sticky .goto is no place of the step: it keeps its own pin and takes no claim", function()
		local ns = mocks.load()
		local step = mocks.step(ns, {
			".goto 1411,43.29,68.53",
			".accept 787",
			".sticky .goto 1411,50,50",
			".goto 1411,42.06,68.33",
			".accept 788",
		})
		local context = mocks.context()
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "accept", 43.29, 787 }, { "accept", 42.06, 788 }, { "goto", 50 } }, summary(pins))
		assert.is_true(pins[3].sticky)
		-- a place is done with whatever a sticky .goto does: only the sticky pin is left
		context.log[787], context.log[788] = true, true
		pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ { "goto", 50 } }, summary(pins))
		assert.is_true(pins[1].sticky)
	end)
end)

-- A doing step (a .complete and no place directive) draws no markers: the quest log marks the objectives, the guide's
-- markers steer the player to a place (docs/GUIDE-FORMAT.md "Step kinds").
describe("step kinds", function()
	-- Test data, not real: 787 and 789 are hunted around the Boar and Scorpid spawns, 788 is the neighbour's.
	local function pack()
		return {
			quests = {
				[787] = {
					n = "Boar Hunt",
					s = { npc = { 101 } },
					e = { npc = { 101 } },
					o = { { k = "kill", id = 201, c = 10 } },
				},
				[788] = { n = "Next Door", s = { npc = { 102 } }, e = { npc = { 102 } } },
				[789] = { n = "Scorpid Hunt", s = { npc = { 101 } }, o = { { k = "kill", id = 202, c = 5 } } },
			},
			npcs = {
				[101] = { n = "Camp Boss", p = { { 1411, 42.1, 68.7 } } },
				[102] = { n = "Neighbour", p = { { 1411, 45, 70 } } },
				[201] = { n = "Boar", p = { { 1411, 50, 50 } } },
				[202] = { n = "Scorpid", p = { { 1411, 60, 60 } } },
				[501] = { n = "Vendor", side = "both", p = { { 1411, 44, 66 } } },
			},
			items = { [401] = { n = "Pack Item", vendors = { 501 }, drops = { 202 } } },
		}
	end

	-- One sample line per registered directive. The places are what sends the player somewhere: every travel directive
	-- and every directive whose def pins anything but quest objectives.
	local PLACES = {
		accept = ".accept 788",
		turnin = ".turnin 788",
		train = ".train class",
		trainprof = ".trainprof skinning",
		buy = ".buy 401,5",
		collect = ".collect 401,5",
		fish = ".fish 1411,55,70",
		path = ".path 1411,52,43.5 ; 1411,47.8,41",
		zone = ".zone 1413",
		fp = ".fp 1413,Ratchet",
		fly = ".fly Orgrimmar",
		boat = ".boat 1413,63.9,38.6 > 1434,27.2,77.1",
		zeppelin = ".zeppelin 1454,51.2,12.6 > 1434,32.1,29.3",
		hs = ".hs Razor Hill",
		home = ".home",
	}
	local NOT_PLACES = {
		["goto"] = ".goto 1411,10,10",
		complete = ".complete 789",
		optional = ".optional 789",
		reward = ".reward 787,2",
		skill = ".skill skinning 50",
		craft = ".craft 2152,3",
		use = ".use 5070",
		level = ".level 5",
		todo = '.todo "reason"',
		note = ".note a note",
		text = ".text some text",
		link = ".link https://example.org/x",
		hub = ".hub razorhill",
		sticky = ".sticky .level 5",
	}

	local ns, context
	before_each(function()
		ns = mocks.load({ pack = pack(), professions = { skinning = SKINNING } })
		context = mocks.context({ log = { [787] = true }, position = { map = 1411 } })
		context.objectives[787] = { { text = "Boar slain: 3/10", finished = false } }
	end)

	local function kinds(pins)
		local set = {}
		for _, pin in ipairs(pins) do
			set[pin.kind] = (set[pin.kind] or 0) + 1
		end
		return set
	end

	it("every registered directive is classified, as a place or not: decide when a new one comes", function()
		for _, name in ipairs(ns.Directives:Names()) do
			assert.is_true(PLACES[name] ~= nil or NOT_PLACES[name] ~= nil, "is ." .. name .. " a place directive?")
		end
	end)

	it("a step with a .complete and a place directive is not a doing step", function()
		for name, line in pairs(PLACES) do
			local step = mocks.step(ns, { ".goto 1411,10,10", ".complete 787", line })
			assert.is_false(ns.Conditions:IsDoingStep(step), name)
		end
	end)

	it("the directives that send the player nowhere leave it a doing step", function()
		for name, line in pairs(NOT_PLACES) do
			local step = mocks.step(ns, { ".goto 1411,10,10", ".complete 787", line })
			assert.is_true(ns.Conditions:IsDoingStep(step), name)
		end
	end)

	it("a step needs a .complete of its own to be a doing step", function()
		for _, directiveLines in ipairs({
			{},
			{ ".goto 1411,1,1" },
			{ ".goto 1411,1,1", ".use 5070", ".note x" },
			{ ".goto 1411,1,1", ".sticky .complete 787" }, -- ongoing beside later steps, not what the step is for
		}) do
			assert.is_false(
				ns.Conditions:IsDoingStep(mocks.step(ns, directiveLines)),
				table.concat(directiveLines, " ")
			)
		end
		assert.is_false(ns.Conditions:IsDoingStep(nil))
		assert.is_true(ns.Conditions:IsDoingStep(mocks.step(ns, { ".complete 787" })))
	end)

	it("a class or profession directive is a place when it travels or pins anything but objectives", function()
		local function register(name, def)
			def.parse = function()
				return {}
			end
			ns.Directives:Register(name, def)
		end
		register("herd", { kind = "quest", pin = "gather" })
		register("ride", { kind = "travel" })
		register("mark", { kind = "quest", pin = "objective" })
		register("count", { kind = "misc" })
		local function doing(line)
			return ns.Conditions:IsDoingStep(mocks.step(ns, { ".goto 1411,1,1", ".complete 787", line }))
		end
		assert.is_false(doing(".herd"))
		assert.is_false(doing(".ride"))
		assert.is_true(doing(".mark"))
		assert.is_true(doing(".count"))
	end)

	it("a doing step draws no markers: neither its .goto nor its .complete quests are pinned", function()
		local step = mocks.step(ns, { ".goto 1411,50,50", ".complete 787", ".complete 789", ".use 5070" })
		context.log[789] = true
		assert.is_true(ns.Conditions:IsDoingStep(step))
		assert.are.same({}, ns.Conditions:Targets(step, context, {}))
		-- before the quests are in the log it is the pack's own objective list that could pin them: still nothing
		assert.are.same({}, ns.Conditions:Targets(step, mocks.context({ position = { map = 1411 } }), {}))
		-- and a step with a .complete alone, in the same spot as its objectives
		assert.are.same({}, ns.Conditions:Targets(mocks.step(ns, { ".complete 787" }), context, {}))
		assert.are.same({}, ns.db.errors)
	end)

	it("a doing step draws nothing without the data pack either", function()
		ns = mocks.load()
		local step = mocks.step(ns, { ".goto 1411,50,50", ".complete 787" })
		assert.are.same({}, ns.Conditions:Targets(step, mocks.context(), {}))
	end)

	it("a step that sends the player somewhere keeps all its markers, the objective ones too", function()
		for name, line in pairs(PLACES) do
			local step = mocks.step(ns, { ".goto 1411,10,10", ".complete 787", line })
			local pins = ns.Conditions:Targets(step, context, {})
			-- the quest's objective area, and the .goto's pin (which a directive without a position of its own, such
			-- as a trainer the pack does not know, takes over: it keeps its place)
			assert.are.equal(1, kinds(pins).objective, name)
			assert.is_true(#pins >= 2, name)
		end
	end)

	it("an old step that mixes a .turnin or an .accept with a .complete pins them all", function()
		local step = mocks.step(ns, { ".goto 1411,42.1,68.7", ".turnin 787", ".complete 787", ".accept 788" })
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.same({ accept = 1, objective = 1, turnin = 1 }, kinds(pins))
		-- the turn-in at the .goto's own spot takes it over; the objective area and the other giver keep theirs
		assert.are.same({ "turnin", 101 }, { pins[1].kind, pins[1].npc })
	end)

	it("a step with an .accept or a .turnin and a .goto still pins", function()
		for _, line in ipairs({ ".accept 788", ".turnin 788" }) do
			local pins = ns.Conditions:Targets(mocks.step(ns, { ".goto 1411,10,10", line }), context, {})
			assert.are.same({ ["goto"] = 1, [line:match("^%.(%a+)")] = 1 }, kinds(pins), line)
		end
	end)

	it("sticky directives do not decide the kind and keep what they pin", function()
		-- a sticky place directive keeps its pin beside a doing step
		local step = mocks.step(ns, { ".goto 1411,50,50", ".complete 787", ".sticky .accept 788" })
		assert.is_true(ns.Conditions:IsDoingStep(step))
		local pins = ns.Conditions:Targets(step, context, {})
		assert.are.equal(1, #pins)
		assert.are.same({ "accept", true, 788 }, { pins[1].kind, pins[1].sticky, pins[1].questID })
		-- a sticky .complete in a doing step is as quiet as its own
		step = mocks.step(ns, { ".goto 1411,50,50", ".complete 787", ".sticky .complete 789" })
		assert.are.same({}, ns.Conditions:Targets(step, context, {}))
		-- without a .complete of its own the step is not a doing one: the .goto and the sticky objective area pin
		step = mocks.step(ns, { ".goto 1411,50,50", ".sticky .complete 789" })
		assert.are.same({ ["goto"] = 1, objective = 1 }, kinds(ns.Conditions:Targets(step, context, {})))
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
		assert.are.same({ 'Turn in "Quest #4641"' }, lines({ ".goto 1411,42.1,68.7", ".turnin 4641" }))
		assert.are.same({ "Raise skinning to 75" }, lines({ ".fish 1411,55,70", ".skill skinning 75" }))
		-- an old step that mixes a turn-in with a .complete reads the same way
		assert.are.same(
			{ 'Turn in "Quest #4641"', 'Complete "Quest #787"' },
			lines({ ".goto 1411,42.1,68.7", ".turnin 4641", ".complete 787" })
		)
	end)

	it("a doing step lists its quests and names no place: not its .goto, not the objectives' progress", function()
		context.log[787] = true
		context.objectives[787] =
			{ { text = "Boar slain: 3/10", finished = false }, { text = "Hides: 1/4", finished = false } }
		local described, info = ns.Conditions:Describe(
			mocks.step(ns, { ".goto 1411,43.2,71.7", ".complete 787", ".complete 788,2", ".use 5070" }),
			context,
			{}
		)
		assert.are.same(
			{ 'Complete "Quest #787"', 'Complete objective 2 of "Quest #788"', "Use Item #5070" },
			described
		)
		for i = 1, 2 do
			assert.are.equal("complete", info[i].name)
			assert.is_nil(info[i].progress)
		end
		assert.are.equal("use", info[3].name)
		-- a step of one quest reads like a step of five
		assert.are.same({ 'Complete "Quest #787"' }, lines({ ".goto 1411,43.2,71.7", ".complete 787" }))
	end)

	it("says which quest each line is about, for a pin's tooltip", function()
		local _, info = ns.Conditions:Describe(
			mocks.step(ns, {
				".goto 1411,43.29,68.53",
				".accept 787",
				".complete 788,2",
				".turnin 789",
				".level 5",
				".note Up the ramp.",
				".sticky .complete 790",
			}),
			context,
			{}
		)
		assert.are.same(
			{ "accept", "complete", "turnin", "level", "note", "complete" },
			{ info[1].name, info[2].name, info[3].name, info[4].name, info[5].name, info[6].name }
		)
		assert.are.same({ 787, 788, 789 }, { info[1].quest, info[2].quest, info[3].quest })
		assert.is_nil(info[4].quest) -- a .level and a .note are about no quest
		assert.is_nil(info[5].quest)
		assert.are.equal(790, info[6].quest) -- the sticky line comes last
		assert.is_true(info[6].sticky)
	end)

	it("marks which quests of a doing step are done", function()
		context.log[787], context.log[789] = true, true
		context.ready[787] = true
		context.objectives[789] = { { text = "Scorpids slain: 1/5", finished = false } }
		local _, info = ns.Conditions:Describe(
			mocks.step(ns, { ".goto 1411,1,1", ".complete 787", ".complete 789", ".complete 790" }),
			context,
			{}
		)
		assert.are.same({ true, false, false }, { info[1].done, info[2].done, info[3].done })
		context.completed[790] = true -- handed in: complete too
		_, info = ns.Conditions:Describe(mocks.step(ns, { ".complete 790" }), context, {})
		assert.is_true(info[1].done)
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

	it("a .complete line names its quest and nothing else: the quest log has the objectives", function()
		context.objectives[787] = { { text = "Boar slain: 3/10", finished = false } }
		local described, info = ns.Conditions:Describe(mocks.step(ns, { ".complete 787", ".accept 788" }), context, {})
		assert.are.same({ 'Complete "Quest #787"', 'Accept "Quest #788"' }, described)
		assert.are.same({ "complete", "accept" }, { info[1].name, info[2].name })
		assert.are.same({ 1, 2 }, { info[1].directive, info[2].directive })
		assert.is_nil(info[1].progress)
		assert.is_nil(info[2].progress)
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
