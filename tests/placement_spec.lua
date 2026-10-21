-- ns.Placement (Engine/Placement.lua): where a character is in a guide. The pure function over hand-built guides first,
-- then the simulation over the shipped guides (tests/helpers/placement_sim.lua), which holds the constants to the
-- accuracy they were chosen for. The same simulation prints the numbers of docs/ENGINE.md: tools/placement_report.py.
local Sim = dofile("tests/helpers/placement_sim.lua")

-- Loads the addon with the shipped guides, parsed for the characters they are for.
local ns, shipped = Sim.load()
local Placement = ns.Placement

-- A guide the way the parser builds one: chapters of steps, each step written as short words. "a1" accepts quest 1,
-- "c1" completes it, "t1" hands it in, "go" has no quest, "L9" is a .level 9 gate, "o5" marks quest 5 optional for the
-- step; "t1 a2" is one step with two directives. chapter = { levels = { lo, hi }, dungeon = bool, steps = { ... } }.
local function guide(chapters, def)
	local steps, list = {}, {}
	for c, chapter in ipairs(chapters) do
		list[c] = { name = "Chapter " .. c, levels = chapter.levels, dungeon = chapter.dungeon }
		for _, text in ipairs(chapter.steps) do
			local step = { id = "g:" .. (#steps + 1), chapter = c, directives = {}, optional = {} }
			for word in text:gmatch("%S+") do
				local kind, number = word:match("^(%a+)(%d*)$")
				number = tonumber(number)
				if kind == "a" then
					step.directives[#step.directives + 1] = { name = "accept", args = { questID = number } }
				elseif kind == "c" then
					step.directives[#step.directives + 1] = { name = "complete", args = { questID = number } }
				elseif kind == "t" then
					step.directives[#step.directives + 1] = { name = "turnin", args = { questID = number } }
				elseif kind == "L" then
					step.directives[#step.directives + 1] = { name = "level", args = { level = number } }
				elseif kind == "o" then
					step.optional[number] = true
				else
					step.directives[#step.directives + 1] = { name = "goto", args = { map = 1, x = 1, y = 1 } }
				end
			end
			steps[#steps + 1] = step
		end
	end
	return { id = "test", steps = steps, chapters = list, def = def }
end

-- accept, complete and hand in each of quests first .. last, one step each
local function questline(first, last)
	local steps = {}
	for q = first, last do
		steps[#steps + 1] = "a" .. q
		steps[#steps + 1] = "c" .. q
		steps[#steps + 1] = "t" .. q
	end
	return steps
end

-- A snapshot of the player: level, and the quests done, in the log, and ready to hand in.
local function snap(opts)
	local function set(list)
		local members = {}
		for _, id in ipairs(list or {}) do
			members[id] = true
		end
		return function(id)
			return members[id] == true
		end
	end
	return { level = opts.level, done = set(opts.done), active = set(opts.active), ready = set(opts.ready) }
end

local function range(first, last)
	local list = {}
	for q = first, last do
		list[#list + 1] = q
	end
	return list
end

local TEN = { { steps = questline(1, 10) } } -- 30 steps, no levels

describe("Placement:Find", function()
	it("has nothing to say about a guide without steps", function()
		assert.is_nil(Placement:Find({ steps = {} }, snap({ level = 5 })))
		assert.is_nil(Placement:Find(nil, snap({})))
	end)

	it("leaves a new character at the first step", function()
		local result = Placement:Find(guide(TEN), snap({ level = 1 }))
		assert.are.equal("none", result.mode)
		assert.are.equal(1, result.index)
		assert.are.equal("high", result.confidence)
		assert.are.equal(0, result.done)
		assert.are.equal(10, result.total)
	end)

	it("finds the first step the character has not done", function()
		local result = Placement:Find(guide(TEN), snap({ level = 5, done = range(1, 4) }))
		assert.are.equal("history", result.mode)
		assert.are.equal(13, result.index) -- quests 1 to 4 are steps 1 to 12
		assert.are.equal(4, result.done)
		assert.are.equal(0, result.skipped)
		assert.are.equal(0, result.ahead)
		assert.are.equal("high", result.confidence)
		for i = 1, 12 do
			assert.are.equal("done", result.labels[i])
		end
		assert.are.equal("open", result.labels[13])
	end)

	it("puts the pointer on the step where the player works when a quest is in the log", function()
		local result = Placement:Find(guide(TEN), snap({ done = range(1, 4), active = { 5 } }))
		assert.are.equal(14, result.index) -- accepted: the accept step is behind, the complete step is next
		assert.are.equal(1, result.active)
	end)

	it("takes a quest log without a single completed quest for a history of its own", function()
		-- what the client has sent when its list of completed quests has not arrived yet
		local result = Placement:Find(guide(TEN), snap({ level = 5, active = { 1, 2, 3 } }))
		assert.are.equal("history", result.mode)
		assert.are.equal(3, result.active)
		assert.are.equal(0, result.done)
		assert.are.equal(8, result.index) -- behind the three accepts, at the doing step of the last quest
		assert.are.equal(4, result.skipped) -- and the steps of quests 1 and 2 in between are not done
	end)

	it("goes on to the hand-in when the quest in the log is ready", function()
		local result = Placement:Find(guide(TEN), snap({ done = range(1, 4), active = { 5 }, ready = { 5 } }))
		assert.are.equal(15, result.index)
	end)

	it("takes a step as done only when all of its quests are", function()
		local g = guide({ { steps = { "t1 a2", "c2", "t2" } } })
		assert.are.equal(1, Placement:Find(g, snap({ done = { 1 } })).index) -- 1 is handed in, 2 is not accepted
		assert.are.equal(2, Placement:Find(g, snap({ done = { 1 }, active = { 2 } })).index)
	end)

	it("goes on to the next step when all the quests of a step are done but the next one is open", function()
		local g = guide({ { steps = { "a1", "t1 a2", "c2", "t2" } } })
		assert.are.equal(3, Placement:Find(g, snap({ done = { 1 }, active = { 2 } })).index)
	end)

	it("is not held back by one skipped quest, and counts it", function()
		-- quest 4 (steps 10 to 12) was never done, the quests after it were
		local result = Placement:Find(guide(TEN), snap({ done = { 1, 2, 3, 5, 6, 7 } }))
		assert.are.equal(22, result.index)
		assert.are.equal(3, result.skipped)
		assert.are.equal(0, result.ahead)
		assert.are.equal("open", result.labels[10])
		assert.are.equal("high", result.confidence)
	end)

	it("is not pulled far ahead by a quest done early", function()
		local result = Placement:Find(guide(TEN), snap({ done = { 1, 2, 3, 10 } }))
		assert.are.equal(10, result.index)
		assert.are.equal(3, result.ahead) -- the three steps of quest 10
	end)

	it("puts the pointer past the steps that are done already, even when the level pulls the split earlier", function()
		-- a level 2 character who has done quests 1 to 4: the level says the start of the guide, the quests say step 13
		local g = guide({ { levels = { 1, 10 }, steps = questline(1, 10) } })
		local result = Placement:Find(g, snap({ level = 2, done = range(1, 4) }))
		assert.is_true(result.split < 13)
		assert.are.equal(13, result.index)
		assert.are.equal(0, result.ahead) -- nothing done lies at or after the pointer
	end)

	it("takes a trip between the last quest done and the next one open as the place", function()
		local g = guide({ { steps = { "a1", "c1", "t1", "go", "a2", "c2", "t2" } } })
		assert.are.equal(4, Placement:Find(g, snap({ done = { 1 } })).index)
	end)

	it("takes no evidence from steps without a quest", function()
		local g = guide({ { steps = { "go", "go", "go", "go" } } })
		local result = Placement:Find(g, snap({ level = 1 }))
		assert.are.equal("none", result.mode)
		assert.are.equal(1, result.index)
		for i = 1, 4 do
			assert.are.equal("neutral", result.labels[i])
		end
	end)

	it("lets a quest marked optional count only when nothing else in the step does", function()
		local g = guide({ { steps = { "a1 a2 o2", "a3 o3", "go" } } })
		local only1 = Placement:Find(g, snap({ done = { 1 } }))
		assert.are.equal("done", only1.labels[1]) -- quest 2 is optional: not doing it holds nothing back
		local none = Placement:Find(g, snap({}))
		assert.are.equal("open", none.labels[1])
		assert.are.equal("neutral", none.labels[2]) -- nothing but an optional quest, not done: no evidence
		assert.are.equal("done", Placement:Find(g, snap({ done = { 3 } })).labels[2])
	end)

	it("survives a snapshot that knows nothing and directives without arguments", function()
		local g = guide({ { steps = { "a1", "c1" } } })
		g.steps[1].directives[#g.steps[1].directives + 1] = { name = "accept" }
		assert.is_table(Placement:Find(g, nil))
		assert.is_table(Placement:Find(g, {}))
	end)

	describe("the level", function()
		local TWO =
			{ { levels = { 1, 10 }, steps = questline(1, 10) }, { levels = { 10, 20 }, steps = questline(11, 20) } }

		local FOUR = { { levels = { 1, 5 }, steps = { "go", "go", "go", "go" } } }

		it("interpolates a chapter's levels over its steps, straight in experience", function()
			local lv, top = Placement:Levels(guide(FOUR))
			assert.are.equal(1, lv[1])
			assert.are.equal(5, lv[5])
			assert.are.equal(5, top)
			-- half the experience from level 1 to level 5 (4800 in Classic's table, 2400) is level 3.79, not 3
			assert.is_true(math.abs(lv[3] - 3.786) < 0.01)
			for i = 2, 5 do
				assert.is_true(lv[i] > lv[i - 1])
			end
		end)

		it("can draw a straight line through a chapter's levels instead", function()
			local lv, top = Placement:Levels(guide(FOUR), "linear")
			assert.are.same({ 1, 2, 3, 4, 5 }, lv)
			assert.are.equal(5, top)
		end)

		it("puts a long early chapter's levels where the experience puts them", function()
			-- levels 1 to 10 over 30 steps: the first levels come fast, so a third of the way through is level 6, not 4
			local g = guide({ { levels = { 1, 10 }, steps = questline(1, 10) } })
			local lv = Placement:Levels(g)
			local straight = Placement:Levels(g, "linear")
			assert.is_true(math.abs(straight[11] - 4) < 1e-9)
			assert.is_true(lv[11] > 6 and lv[11] < 7)
			assert.are.equal(10, lv[31])
		end)

		it("says how many levels the chapter of each step spans", function()
			local _, _, span = Placement:Levels(guide({
				{ levels = { 1, 10 }, steps = { "go", "go" } },
				{ levels = { 10, 10 }, steps = { "go" } },
				{ levels = { 15, 20 }, dungeon = true, steps = { "go" } },
				{ steps = { "go" } },
			}))
			assert.are.same({ 9, 9, 0, 0, 0, 0 }, span)
		end)

		describe("the experience", function()
			it("is the inverse of the level", function()
				for _, level in ipairs({ 1, 1.5, 2, 7.25, 30, 59.9 }) do
					assert.is_true(math.abs(Placement:LevelAt(Placement:ExperienceAt(level)) - level) < 1e-6, level)
				end
			end)

			it("stops at the first level and at the top one", function()
				assert.are.equal(0, Placement:ExperienceAt(0.5))
				assert.are.equal(1, Placement:LevelAt(-10))
				assert.are.equal(Placement:ExperienceAt(60), Placement:ExperienceAt(75))
				assert.are.equal(60, Placement:LevelAt(1e9))
			end)

			it("asks for more with each level", function()
				for level = 1, 58 do
					local now = Placement:ExperienceAt(level + 1) - Placement:ExperienceAt(level)
					local next = Placement:ExperienceAt(level + 2) - Placement:ExperienceAt(level + 1)
					assert.is_true(next > now, level)
				end
			end)
		end)

		it("never falls below a .level gate, nor below an earlier step", function()
			local lv = Placement:Levels(guide({ { levels = { 1, 5 }, steps = { "go", "L9", "go", "go" } } }))
			assert.is_true(lv[1] < 9)
			assert.are.equal(1, lv[1])
			assert.is_true(lv[3] >= 9 and lv[4] >= 9 and lv[5] >= 9)
			for i = 2, #lv do
				assert.is_true(lv[i] >= lv[i - 1])
			end
		end)

		it("does not fall back when a chapter starts below where the one before it ended", function()
			local lv = Placement:Levels(guide({
				{ levels = { 1, 10 }, steps = { "go", "go", "go" } },
				{ levels = { 8, 12 }, steps = { "go", "go", "go" } },
			}))
			for i = 2, #lv do
				assert.is_true(lv[i] >= lv[i - 1], i)
			end
			assert.is_true(lv[4] >= 10 and lv[5] >= 10) -- the second chapter's own line starts below that
			assert.are.equal(12, lv[7])
		end)

		it("takes nothing from a dungeon chapter's levels", function()
			local lv, top = Placement:Levels(guide({
				{ levels = { 1, 4 }, steps = { "go", "go" } },
				{ levels = { 15, 20 }, dungeon = true, steps = { "go", "go" } },
				{ levels = { 4, 6 }, steps = { "go", "go" } },
			}))
			assert.are.equal(4, lv[3]) -- the first chapter is done on entering the dungeon: its top level, no more
			assert.are.equal(4, lv[4])
			assert.are.equal(6, top)
		end)

		it("has no levels for a guide that gives none", function()
			local lv, top = Placement:Levels(guide(TEN))
			assert.are.equal(false, lv[1])
			assert.are.equal(false, lv[31])
			assert.is_nil(top)
		end)

		it("puts a character with no history where the guide expects its level", function()
			local result = Placement:Find(guide(TWO), snap({ level = 15 }))
			assert.are.equal("level", result.mode)
			assert.are.equal("low", result.confidence)
			assert.is_true(result.index > 30) -- in the second chapter
			assert.is_true(result.expected >= 14.5 and result.expected < 15.5)
			assert.are.equal(0, result.done)
		end)

		it("leaves the first levels alone: up to level 2 with nothing done the guide starts", function()
			assert.are.equal("none", Placement:Find(guide(TWO), snap({ level = 2 })).mode)
			assert.are.equal(1, Placement:Find(guide(TWO), snap({ level = 2 })).index)
			assert.are.equal("level", Placement:Find(guide(TWO), snap({ level = 3 })).mode)
		end)

		it("lets a level far ahead of a thin history win, and marks what lies between as skipped", function()
			local result = Placement:Find(
				guide({ { levels = { 1, 10 }, steps = questline(1, 10) } }),
				snap({ level = 9, done = { 1, 2, 3 } })
			)
			assert.are.equal("history", result.mode)
			-- a level 9 is two thirds of the way through levels 1 to 10 by experience (step 21 of 30), not eight ninths
			assert.is_true(result.index >= 19 and result.index <= 23)
			assert.is_true(result.expected + Placement.BIAS >= 9)
			assert.is_true(result.skipped >= 8)
		end)

		it("takes the straight line when told to", function()
			local g = guide({ { levels = { 1, 10 }, steps = questline(1, 10) } })
			local result = Placement:Find(g, snap({ level = 9, done = { 1, 2, 3 } }), { curve = "linear" })
			assert.is_true(result.index >= 25) -- eight ninths of the way through levels 1 to 10, not two thirds
		end)

		describe("the tolerance", function()
			-- 120 steps over 14 levels, like the island of a guide: a chapter whose line cannot be trusted to a level
			local LONG = { { levels = { 1, 15 }, steps = questline(1, 40) } }

			it("lets a clean history outweigh a level that is a little ahead of it", function()
				local g = guide(LONG)
				-- 22 quests done in a row: the pointer belongs at step 67, where the guide expects level 12.4 (12.9 with
				-- the half level) and the character has 13
				local clean = snap({ level = 13, done = range(1, 22) })
				assert.are.equal(67, Placement:Find(g, clean).index)
				-- without the tolerance the level pulls the pointer nine steps on
				assert.is_true(Placement:Find(g, clean, { tolBase = 0, tolSpan = 0 }).index >= 74)
			end)

			it("gives a long chapter more of it than a short one", function()
				local g = guide(LONG)
				local clean = snap({ level = 13, done = range(1, 22) })
				assert.is_true(Placement:Find(g, clean, { tolSpan = 0 }).index > 67)
			end)

			it("gives none to a history that is half gaps: the level decides", function()
				local g = guide(LONG)
				local odd = {}
				for q = 1, 20, 2 do
					odd[#odd + 1] = q
				end
				local thin = snap({ level = 13, done = odd }) -- every second quest of the first twenty
				local with = Placement:Find(g, thin)
				assert.are.equal(Placement:Find(g, thin, { tolBase = 0, tolSpan = 0 }).index, with.index)
				assert.is_true(with.index >= 74)
				-- the same tolerance without the gate would have kept the pointer behind, at step 62
				assert.is_true(Placement:Find(g, thin, { gateLow = 0, gateHigh = 0 }).index <= 64)
			end)

			it("holds the pointer at the end of a history of most quests done", function()
				local g = guide(LONG)
				local most = {}
				for q = 1, 20 do
					if q % 4 ~= 0 then
						most[#most + 1] = q
					end
				end
				-- three of every four quests of the first twenty: quest 20 is the first not done, at step 58
				local snapshot = snap({ level = 13, done = most })
				assert.are.equal(58, Placement:Find(g, snapshot).index)
				assert.is_true(Placement:Find(g, snapshot, { gateLow = 0, gateHigh = 0 }).index > 58)
				assert.is_true(Placement:Find(g, snapshot, { tolBase = 0, tolSpan = 0 }).index >= 74)
			end)

			it("is not given to a character with no history: the level is all there is", function()
				local g = guide(LONG)
				assert.are.equal(
					Placement:Find(g, snap({ level = 13 }), { tolBase = 0, tolSpan = 0 }).index,
					Placement:Find(g, snap({ level = 13 })).index
				)
			end)
		end)

		it("goes by the history alone when the guide says nothing about levels", function()
			local result = Placement:Find(guide(TEN), snap({ level = 40, done = range(1, 4) }))
			assert.are.equal(13, result.index)
			assert.are.equal("none", Placement:Find(guide(TEN), snap({ level = 40 })).mode)
		end)

		it("puts a character above the guide's top level at its last step", function()
			local g = guide({ { levels = { 1, 10 }, steps = questline(1, 10) } }, { levels = { 1, 10 } })
			local result = Placement:Find(g, snap({ level = 14 }))
			assert.are.equal("end", result.mode)
			assert.are.equal(30, result.index)
			assert.are.equal(31, result.split)
			assert.are.equal(10, result.top)
			assert.are.equal(14, result.level)
		end)

		it("puts a character that has done all of the guide at its last step, with confidence", function()
			local g = guide({ { levels = { 1, 10 }, steps = questline(1, 10) } })
			local result = Placement:Find(g, snap({ level = 10, done = range(1, 10) }))
			assert.are.equal("end", result.mode)
			assert.are.equal(30, result.index)
			assert.are.equal("high", result.confidence)
		end)
	end)

	describe("the confidence", function()
		it("is high where the done steps stop cleanly and low where they are mixed with open ones", function()
			assert.are.equal("high", Placement:Find(guide(TEN), snap({ done = range(1, 5) })).confidence)
			local ragged = Placement:Find(guide(TEN), snap({ done = { 1, 3, 5, 7, 9 } }))
			assert.are_not.equal("high", ragged.confidence)
			assert.is_true(ragged.sharpness < Placement.SHARP_HIGH)
		end)
	end)

	it("is the same on every call", function()
		local g = guide(TEN)
		local a = Placement:Find(g, snap({ level = 5, done = { 1, 2, 3, 5 } }))
		local b = Placement:Find(g, snap({ level = 5, done = { 1, 2, 3, 5 } }))
		assert.are.equal(a.index, b.index)
		assert.are.equal(a.skipped, b.skipped)
	end)
end)

-- The simulation: a character who followed the shipped guides up to a step, spoilt the way real play spoils it, placed
-- by the function above and compared with where it really was. The bounds are the accuracy the constants were chosen
-- for, with room for the guides to change: a regenerated guide may move the numbers a little, a broken constant moves
-- them a lot (tools/placement_report.py prints the real figures).
describe("Placement against the shipped guides", function()
	local SCENARIOS = {}
	for _, scenario in ipairs(Sim.SCENARIOS) do
		SCENARIOS[scenario.name] = scenario
	end
	local function scenarios(...)
		local list = {}
		for _, name in ipairs({ ... }) do
			list[#list + 1] = SCENARIOS[name]
		end
		return list
	end
	local results = Sim.run({
		ns = ns,
		guides = shipped,
		truth = "warp",
		seed = 11,
		stride = 5,
		replicates = 1,
		scenarios = scenarios("exact", "skip20", "early", "level1", "nolog", "mixed", "lag", "scatter", "levelonly"),
	})
	-- The same characters, placed by guides whose chapter headers are a level too wide at each end (every `#chapter 5-8`
	-- reads `4-9`): what a coarser planner would have written. A clean follower must not be dragged off by that.
	local WIDENED = { lo = -1, hi = 1 }
	local widened = Sim.run({
		ns = ns,
		guides = shipped,
		truth = "warp",
		seed = 11,
		stride = 5,
		replicates = 1,
		widen = WIDENED,
		scenarios = scenarios("exact", "skip20", "early", "mixed"),
	})
	-- Three or more levels off with all the noise together happens, rarely: the character's level is a level off, the
	-- guide's line is a level off inside a long chapter, and the quests it skipped come in runs. Measured over ten seeds
	-- and every step of every guide (3 draws each, about 9,000 runs per guide): 0.010 percent for the Tauren guide, 0.012
	-- for the Troll's and none for the Skyborne's (tools/placement_report.py). A draw the size of the others here (about
	-- 60 runs) cannot show a rate that low: one run in 60 is 1.6 percent. So this one draws every step twice.
	local tail = Sim.run({
		ns = ns,
		guides = shipped,
		truth = "warp",
		seed = 11,
		stride = 1,
		replicates = 2,
		scenarios = scenarios("mixed"),
	})
	local MIXED_TAIL = 0.003 -- thirty times the measured rate

	it("covers every shipped guide", function()
		local count = 0
		for _ in pairs(results) do
			count = count + 1
		end
		assert.are.equal(#shipped, count)
		assert.is_true(count >= 3)
	end)

	for _, entry in ipairs(shipped) do
		describe(entry.id, function()
			local function stats(name)
				return results[entry.id][name]
			end

			it("is graded against levels that its line is a level off from, in its longest chapter", function()
				-- the stress the bounds below are held to: with the truth equal to the line there would be nothing to hold
				local warp, model = Sim.truth(ns, entry, "warp"), Sim.truth(ns, entry, "model")
				local widest = 0
				for i = 1, #warp do
					widest = math.max(widest, math.abs(warp[i] - model[i]))
				end
				assert.is_true(widest >= 0.9)
			end)

			it("finds a character who followed the guide, to the step", function()
				assert.is_true(stats("exact").quests.p90 <= 2)
				assert.is_true(stats("exact").steps.max <= 6)
				assert.are.equal(0, stats("exact").catastrophic)
			end)

			it("holds up to a fifth of the quests skipped", function()
				assert.is_true(stats("skip20").quests.median <= 2)
				assert.is_true(stats("skip20").quests.p90 <= 8)
			end)

			it("holds up to quests done early, a level off and an empty quest log", function()
				assert.is_true(stats("early").quests.p90 <= 10)
				assert.is_true(stats("level1").quests.p90 <= 14)
				assert.is_true(stats("nolog").quests.p90 <= 8)
			end)

			it("is within a handful of quests with all the noise together", function()
				assert.is_true(stats("mixed").quests.median <= 6)
				assert.is_true(stats("mixed").quests.p90 <= 20)
			end)

			it("is almost never three levels off with all the noise together", function()
				assert.is_true(tail[entry.id].mixed.catastrophic <= MIXED_TAIL)
			end)

			it("is not led astray by chapter headers a level too wide at each end", function()
				local function seen(name)
					return widened[entry.id .. "/w" .. WIDENED.lo .. "," .. WIDENED.hi][name]
				end
				assert.is_true(seen("exact").quests.p90 <= 2)
				assert.is_true(seen("exact").steps.max <= 6)
				assert.is_true(seen("skip20").quests.median <= 2)
				assert.is_true(seen("skip20").quests.p90 <= 8)
				assert.is_true(seen("early").quests.p90 <= 10)
				assert.is_true(seen("mixed").quests.median <= 6)
				assert.is_true(seen("mixed").quests.p90 <= 20)
			end)

			it("is never three levels off, with no history at all", function()
				assert.are.equal(0, stats("levelonly").catastrophic)
				assert.is_true(stats("levelonly").levels.p90 <= 2.5)
			end)

			it("puts a character who did not follow the guide where its level says, give or take", function()
				assert.is_true(stats("lag").catastrophic <= 0.05)
				assert.is_true(stats("scatter").catastrophic <= 0.1)
			end)
		end)
	end

	it("widens the headers of the guide it shows the placement, and not the guide's own", function()
		local entry = shipped[1]
		local before = {}
		for c, chapter in ipairs(entry.guide.chapters) do
			before[c] = chapter.levels and { chapter.levels[1], chapter.levels[2] }
		end
		local view = Sim.view(ns, entry, { lo = -1, hi = 2 })
		assert.are.equal(entry.id .. "/w-1,2", view.id)
		assert.are.equal(entry.guide.steps, view.guide.steps)
		for c, chapter in ipairs(entry.guide.chapters) do
			local levels = view.guide.chapters[c].levels
			if chapter.levels and not chapter.dungeon then
				assert.are.equal(math.max(1, before[c][1] - 1), levels[1])
				assert.are.equal((before[c][2] or before[c][1]) + 2, levels[2])
			else
				assert.are.equal(chapter.levels, levels)
			end
			assert.are.same(before[c], chapter.levels and { chapter.levels[1], chapter.levels[2] })
		end
	end)

	it("gives the same figures again with the same seed", function()
		local again = Sim.run({
			ns = ns,
			guides = shipped,
			only = { shipped[1].id },
			truth = "warp",
			seed = 11,
			stride = 5,
			replicates = 1,
			scenarios = scenarios("mixed"),
		})
		assert.are.same(results[shipped[1].id].mixed.quests, again[shipped[1].id].mixed.quests)
	end)
end)
