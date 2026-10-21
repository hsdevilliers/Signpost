-- The simulation behind the constants of Engine/Placement.lua: for each shipped guide (the real parser, as the client
-- runs it) a character who followed the guide up to step t is built (the quests of the steps before t turned in, the
-- quests accepted before t and handed in after it in the log, the level the guide has at t), spoilt with the noise real
-- players bring, and handed to ns.Placement:Find. The error is how far from t it puts the pointer, in steps, in quest
-- steps (a trip between two quests cannot be told from either) and in levels.
--
--   tests/placement_spec.lua      asserts bounds on the numbers, with fixed seeds
--   tools/placement_report.lua    prints them, and searches the constants (docs/ENGINE.md "Engine/Placement.lua")
--
-- Everything is deterministic: its own random generator, quests visited in ID order. Run from the repository root.
local addon = dofile("tests/helpers/addon.lua")

local Sim = {}

-- The noise. skip: the share of quests the character did not do although the guide has them before t (iid, or in runs of
-- `runs` quests on average); early: quests after t done already; level: the character's level is off by up to this many
-- levels (a random one in -level .. level); log: the share of runs with the quest log empty; history = false: the
-- completed-quest list is unavailable (nothing done, nothing in the log: only the level is known). Characters that did not
-- follow the guide: scatter = every quest of the guide that the character's level allows (up to two levels above it),
-- before t or after, done with this probability (it levelled on other quests: the true position is the one the level
-- says); lag = the character did the guide's quests only up to this share of t (it stopped following the guide and went
-- on levelling elsewhere).
Sim.SCENARIOS = {
	{ name = "exact" },
	{ name = "skip10", skip = 0.1 },
	{ name = "skip20", skip = 0.2 },
	{ name = "skip30", skip = 0.3 },
	{ name = "skip30runs", skip = 0.3, runs = 6 },
	{ name = "early", early = 4 },
	{ name = "level1", level = 1 },
	{ name = "level2", level = 2 },
	{ name = "nolog", log = 1 },
	{ name = "mixed", skip = 0.2, runs = 3, early = 3, level = 1, log = 0.5 },
	{ name = "sparse15", skip = 0.85 },
	{ name = "sparse40", skip = 0.6, level = 1 },
	{ name = "scatter", scatter = 0.2 },
	{ name = "scatter50", scatter = 0.5, level = 1 },
	{ name = "lag", lag = 0.4 },
	{ name = "lag70", lag = 0.7, level = 1 },
	{ name = "levelonly", history = false, level = 1 },
}

-- The scenarios by kind: "follow" (a character that followed the guide, with noise), "other" (one that did not: the position is
-- the one its level says) and "level" (the history is unavailable).
Sim.GROUPS = {
	follow = { "exact", "skip10", "skip20", "skip30", "skip30runs", "early", "level1", "level2", "nolog", "mixed" },
	other = { "sparse15", "sparse40", "scatter", "scatter50", "lag", "lag70" },
	level = { "levelonly" },
}

-- Random numbers ------------------------------------------------------------------------------------------------------

-- A number from a name, so a scenario draws the same noise whichever others run beside it.
function Sim.hash(text)
	local value = 7
	for i = 1, #text do
		value = (value * 31 + text:byte(i)) % 1000003
	end
	return value
end

-- Park-Miller: the same sequence on every machine and Lua.
function Sim.rng(seed)
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state = state + 2147483646
	end
	local generator = {}
	function generator:next()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	-- a whole number from 1 to n
	function generator:int(n)
		return 1 + math.floor(self:next() * n)
	end
	return generator
end

-- The shipped guides ------------------------------------------------------------------------------------------------

local function shippedFiles()
	local files = {}
	for line in io.lines("Signpost.toc") do
		line = line:gsub("\r$", "")
		if line:find("^Guides\\") and not line:find("^Guides\\Travel\\") then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	return files
end

local function first(list, default)
	if type(list) == "table" and type(list[1]) == "string" and list[1] ~= "*" then
		return list[1]
	end
	return default
end

local QUEST = { accept = true, turnin = true, complete = true }

-- Per quest: the first and last step that mention it, and the steps that `.complete` it.
local function questIndex(guide)
	local quests, order = {}, {}
	for i, step in ipairs(guide.steps) do
		for _, directive in ipairs(step.directives) do
			local questID = QUEST[directive.name] and directive.args.questID
			if questID then
				local entry = quests[questID]
				if not entry then
					entry = { id = questID, first = i, last = i, completes = {} }
					quests[questID] = entry
					order[#order + 1] = entry
				end
				entry.last = i
				if directive.name == "complete" then
					entry.completes[#entry.completes + 1] = i
				end
			end
		end
	end
	local byPosition = {}
	for i, entry in ipairs(order) do
		byPosition[i] = entry
	end
	table.sort(order, function(a, b)
		return a.id < b.id
	end)
	table.sort(byPosition, function(a, b)
		if a.first ~= b.first then
			return a.first < b.first
		end
		return a.id < b.id
	end)
	return quests, order, byPosition
end

-- quest-bearing steps before step i, for i = 1 .. n + 1
local function questStepCounts(guide)
	local counts, total = { 0 }, 0
	for i, step in ipairs(guide.steps) do
		for _, directive in ipairs(step.directives) do
			if QUEST[directive.name] and directive.args.questID then
				total = total + 1
				break
			end
		end
		counts[i + 1] = total
	end
	return counts
end

-- Loads the addon with the shipped guides and parses each for the character it is for. Returns ns and a list of
-- { id, def, guide, quests, order (by quest ID), byPosition (by first step), questSteps }.
function Sim.load()
	local ns = addon.load({ extra = shippedFiles(), login = false })
	local list = {}
	for _, def in ipairs(ns.Guides:All()) do
		local player = {
			class = first(def.classes, "Hunter"),
			classFile = first(def.classes, "HUNTER"),
			race = first(def.races, "Troll"),
			raceFile = first(def.races, "Troll"),
			faction = def.faction == "*" and "Horde" or def.faction,
			level = 1,
			professions = {},
		}
		local guide = ns.Parser:ParseGuide(def, { player = player })
		local quests, order, byPosition = questIndex(guide)
		list[#list + 1] = {
			id = def.id,
			def = def,
			guide = guide,
			quests = quests,
			order = order,
			byPosition = byPosition,
			questSteps = questStepCounts(guide),
		}
	end
	return ns, list
end

-- Truth levels -------------------------------------------------------------------------------------------------------

-- The level the character really has when it starts step i, i = 1 .. n + 1, by three models:
--   "model"  the guide's own expected levels (ns.Placement:Levels): the placement is graded by its own yardstick;
--   "warp"   the same chapter by chapter, but each chapter's levels are reached on a curve (fast in some chapters, slow in
--            others), so the straight line the placement draws between a chapter's levels is wrong by up to a level;
--   "sim"    the levels tools/guide_sim.py walks (quest experience from the private pack): a table
--            { [guide id] = { start = level, steps = { [step id] = level after the step } } } from a Lua file.
function Sim.truth(ns, entry, kind, simLevels)
	local guide, n = entry.guide, #entry.guide.steps
	local lv = ns.Placement:Levels(guide)
	local levels = {}
	if kind == "sim" then
		local sim = simLevels and simLevels[entry.id]
		assert(sim, "no simulated levels for " .. entry.id)
		local previous = sim.start or 1
		for i = 1, n + 1 do
			levels[i] = previous
			local step = guide.steps[i]
			previous = step and sim.steps[step.id] or previous
		end
		return levels
	end
	-- The chapters' levels are whole levels: the level a character has, fraction included, is on average half a level above.
	if kind == "model" then
		local value = 1
		for i = 1, n + 1 do
			value = lv[i] or value
			levels[i] = value + 0.5
		end
		return levels
	end
	-- warp: chapter by chapter
	local count, before, chapterOf, current = {}, {}, {}, nil
	for i, step in ipairs(guide.steps) do
		current = step.chapter or current
		chapterOf[i] = current
		count[current] = (count[current] or 0) + 1
	end
	local value, gate = 1, 0
	for i = 1, n + 1 do
		local chapter = chapterOf[i] or chapterOf[n]
		local info = guide.chapters[chapter]
		if info and not info.dungeon and info.levels then
			local low, high = info.levels[1], info.levels[2] or info.levels[1]
			local gamma = chapter % 2 == 0 and 0.6 or 1.6
			local raw = low + (high - low) * ((before[chapter] or 0) / count[chapter]) ^ gamma
			value = math.max(value, raw)
		end
		value = math.max(value, gate)
		levels[i] = value + 0.5
		local step = guide.steps[i]
		if step then
			before[chapterOf[i]] = (before[chapterOf[i]] or 0) + 1
			for _, directive in ipairs(step.directives) do
				if directive.name == "level" then
					gate = math.max(gate, directive.args.level)
				end
			end
		end
	end
	return levels
end

-- Players ------------------------------------------------------------------------------------------------------------

-- A character that followed the guide up to step t (t = n + 1: all of it), as a Placement snapshot, with the scenario's
-- noise. levels[i] is the true level at step i.
function Sim.player(entry, levels, t, scenario, rng)
	local done, active, ready = {}, {}, {}
	-- Skipped quests come one by one, or in runs of consecutive quests (a two-state chain: the share skipped is `skip`, a
	-- run is `runs` quests long on average).
	local skipping = false
	local runLength = scenario.runs or 1
	local skip = scenario.skip or 0
	local endRun = 1 / runLength
	local startRun = skip > 0 and skip < 1 and endRun * skip / (1 - skip) or 0
	local clearLog = (scenario.log or 0) > 0 and rng:next() < scenario.log
	for _, quest in ipairs(entry.byPosition) do
		local state
		if scenario.scatter then
			local allowed = levels[quest.first] <= levels[t] + 2
			state = rng:next() < scenario.scatter and allowed and "done" or nil
		elseif scenario.lag then
			if quest.last < t * scenario.lag then
				state = "done"
			end
		elseif quest.last < t then
			state = "done"
		elseif quest.first < t then
			state = "active"
		end
		if skip > 0 then
			if runLength == 1 then
				skipping = rng:next() < skip
			elseif skipping then
				skipping = rng:next() >= endRun
			else
				skipping = rng:next() < startRun
			end
		end
		if state and not skipping then
			if state == "done" then
				done[quest.id] = true
			elseif not clearLog then
				active[quest.id] = true
				local all = true
				for _, step in ipairs(quest.completes) do
					if step >= t then
						all = false
					end
				end
				ready[quest.id] = all and #quest.completes > 0 or nil
			end
		end
	end
	-- a few quests after t that the character did anyway
	local ahead = {}
	for _, quest in ipairs(entry.order) do
		if quest.first >= t then
			ahead[#ahead + 1] = quest
		end
	end
	for _ = 1, scenario.scatter and 0 or math.min(scenario.early or 0, #ahead) do
		done[ahead[rng:int(#ahead)].id] = true
	end
	if scenario.history == false then
		done, active, ready = {}, {}, {}
	end
	local level = math.floor(levels[t] + 1e-9)
	if (scenario.level or 0) > 0 then
		level = math.max(1, level + rng:int(2 * scenario.level + 1) - scenario.level - 1)
	end
	return {
		level = level,
		done = function(questID)
			return done[questID] == true
		end,
		active = function(questID)
			return active[questID] == true
		end,
		ready = function(questID)
			return ready[questID] == true
		end,
	}
end

-- Statistics -----------------------------------------------------------------------------------------------------------

function Sim.percentile(sorted, fraction)
	if #sorted == 0 then
		return 0
	end
	local position = 1 + (#sorted - 1) * fraction
	local low = math.floor(position)
	local high = math.min(low + 1, #sorted)
	return sorted[low] + (sorted[high] - sorted[low]) * (position - low)
end

-- { count, median, p75, p90, max, mean, within (the share <= within) } of a list of numbers.
function Sim.summary(values, within)
	local sorted = {}
	local sum, near = 0, 0
	for i, value in ipairs(values) do
		sorted[i] = value
		sum = sum + value
		if value <= (within or 5) then
			near = near + 1
		end
	end
	table.sort(sorted)
	return {
		count = #sorted,
		median = Sim.percentile(sorted, 0.5),
		p75 = Sim.percentile(sorted, 0.75),
		p90 = Sim.percentile(sorted, 0.9),
		max = sorted[#sorted] or 0,
		mean = #sorted > 0 and sum / #sorted or 0,
		within = #sorted > 0 and near / #sorted or 0,
	}
end

-- Runs ----------------------------------------------------------------------------------------------------------------

-- The characters to place: opts.ns, guides (the list from Sim.load), truth ("warp", "model" or "sim"), simLevels, seed,
-- stride (every stride-th step is a true position t, and the last), replicates (noise draws per t), scenarios (default
-- Sim.SCENARIOS), only (a list of guide ids), cut (a function(entry, t) -> false to leave a position out). Returns a list
-- of { entry, scenario, t, levels (the true level at each step), snapshot, labels, stats }; the labels are worked out once,
-- so the constants can be tried over and over (Sim.evaluate).
function Sim.population(opts)
	local ns = opts.ns
	local population = {}
	local scenarios = opts.scenarios or Sim.SCENARIOS
	for _, entry in ipairs(opts.guides) do
		local wanted = not opts.only
		for _, id in ipairs(opts.only or {}) do
			wanted = wanted or id == entry.id
		end
		if wanted then
			local n = #entry.guide.steps
			entry.lv, entry.top = ns.Placement:Levels(entry.guide)
			local levels = Sim.truth(ns, entry, opts.truth or "warp", opts.simLevels)
			for _, scenario in ipairs(scenarios) do
				local rng = Sim.rng((opts.seed or 1) * 100003 + Sim.hash(scenario.name))
				local ts = {}
				for t = 1, n, opts.stride or 2 do
					ts[#ts + 1] = t
				end
				ts[#ts + 1] = n + 1
				for _, t in ipairs(ts) do
					for _ = 1, opts.replicates or 3 do
						if not opts.cut or opts.cut(entry, t) ~= false then
							local snapshot = Sim.player(entry, levels, t, scenario, rng)
							local labels, stats = ns.Placement:Labels(entry.guide, snapshot)
							population[#population + 1] = {
								entry = entry,
								scenario = scenario,
								t = t,
								levels = levels,
								snapshot = snapshot,
								labels = labels,
								stats = stats,
							}
						end
					end
				end
			end
		end
	end
	return population
end

-- Places every character of a population with the constants `find` (Placement:Fit's opts) and grades the answers:
-- { [guide id] = { [scenario name] = { runs = { { t, split, mode, steps, quests, levels, level, result } }, steps = summary,
-- quests = summary, levels = summary, catastrophic = share } } }. A summary is Sim.summary of the errors in steps, in quest
-- steps and in levels; catastrophic is the share of runs 3 or more levels off.
function Sim.evaluate(ns, population, find)
	local results, collected = {}, {}
	for _, item in ipairs(population) do
		local entry, scenario, t = item.entry, item.scenario, item.t
		local result = ns.Placement:Fit(item.labels, item.stats, entry.lv, entry.top, item.snapshot, find)
		local run = {
			t = t,
			split = result.split,
			mode = result.mode,
			steps = math.abs(result.split - t),
			quests = math.abs(entry.questSteps[result.split] - entry.questSteps[t]),
			levels = math.abs(item.levels[result.split] - item.levels[t]),
			level = item.snapshot.level,
			result = result,
		}
		local byScenario = results[entry.id]
		if not byScenario then
			byScenario = {}
			results[entry.id] = byScenario
		end
		local bucket = byScenario[scenario.name]
		if not bucket then
			bucket = { runs = {} }
			byScenario[scenario.name] = bucket
			collected[bucket] = { steps = {}, quests = {}, levels = {}, bad = 0 }
		end
		bucket.runs[#bucket.runs + 1] = run
		local lists = collected[bucket]
		lists.steps[#lists.steps + 1] = run.steps
		lists.quests[#lists.quests + 1] = run.quests
		lists.levels[#lists.levels + 1] = run.levels
		if run.levels >= 3 then
			lists.bad = lists.bad + 1
		end
	end
	for bucket, lists in pairs(collected) do
		bucket.steps = Sim.summary(lists.steps, 5)
		bucket.quests = Sim.summary(lists.quests, 5)
		bucket.levels = Sim.summary(lists.levels, 1)
		bucket.catastrophic = #bucket.runs > 0 and lists.bad / #bucket.runs or 0
	end
	return results
end

-- Population and evaluation in one go.
function Sim.run(opts)
	return Sim.evaluate(opts.ns, Sim.population(opts), opts.find)
end

-- Loads a file of simulated levels (tools/guide_sim.py's, exported to Lua), or nil.
function Sim.loadSimLevels(path)
	if not path then
		return nil
	end
	return dofile(path)
end

return Sim
