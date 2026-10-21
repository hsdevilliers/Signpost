-- Prints how well ns.Placement finds a character in each shipped guide, and searches its constants. Run it from the
-- repository root (tools/placement_report.py does that, finds the Lua and adds the simulator's levels), with the Lua of
-- the test toolchain or any Lua 5.1:
--
--   lua tools/placement_report.lua                                  every guide, every scenario, one table each
--   lua tools/placement_report.lua --docs                           the compact Markdown tables of docs/ENGINE.md
--   lua tools/placement_report.lua --guide horde-troll-hunter --scenario mixed --scenario levelonly
--   lua tools/placement_report.lua --truth sim --levels plans/placement_levels.lua     the simulator's levels as truth
--   lua tools/placement_report.lua --open 0.5 --done 1 --level 8    other constants
--   lua tools/placement_report.lua --set 0.25,1,6 --set 0.5,1,6     several sets side by side (open,done,level[,bias])
--   lua tools/placement_report.lua --tune                           a grid search over the constants
--   lua tools/placement_report.lua --scenarios                      what each scenario does
--
-- The method and the numbers it gave are in docs/ENGINE.md ("Engine/Placement.lua"); tests/helpers/placement_sim.lua is
-- the simulation. --truth says what level a character really has at a step: "warp" (the default: each chapter's levels
-- reached on a curve, so the straight line the placement assumes is wrong inside a chapter), "model" (the placement's
-- own levels) or "sim" (the levels tools/guide_sim.py walks, from the private data pack: tools/placement_levels.py
-- writes them to a Lua file, which is passed as --levels). --also-sim <guide id> adds that guide under the simulator's
-- levels to any run, reported as "<guide id>/sim". Everything is deterministic for a given --seed.
local Sim = dofile("tests/helpers/placement_sim.lua")

local options = { truth = "warp", seed = 1, stride = 2, replicates = 3 }
local find = {}
local index = 1
local function value()
	index = index + 1
	return arg[index]
end
while arg[index] do
	local name = arg[index]
	if name == "--truth" then
		options.truth = value()
	elseif name == "--levels" then
		options.levelsFile = value()
	elseif name == "--also-sim" then
		options.alsoSim = options.alsoSim or {}
		options.alsoSim[#options.alsoSim + 1] = value()
	elseif name == "--guide" then
		options.only = options.only or {}
		options.only[#options.only + 1] = value()
	elseif name == "--seed" then
		options.seed = tonumber(value())
	elseif name == "--stride" then
		options.stride = tonumber(value())
	elseif name == "--replicates" then
		options.replicates = tonumber(value())
	elseif name == "--open" then
		find.openWeight = tonumber(value())
	elseif name == "--done" then
		find.doneWeight = tonumber(value())
	elseif name == "--level" then
		find.levelWeight = tonumber(value())
	elseif name == "--bias" then
		find.bias = tonumber(value())
	elseif name == "--set" then
		local parts = {}
		for item in (value() .. ","):gmatch("([^,]*),") do
			parts[#parts + 1] = tonumber(item)
		end
		options.sets = options.sets or {}
		options.sets[#options.sets + 1] = {
			openWeight = parts[1],
			doneWeight = parts[2],
			levelWeight = parts[3],
			bias = parts[4],
		}
	elseif name == "--scenario" then
		options.scenarioNames = options.scenarioNames or {}
		options.scenarioNames[#options.scenarioNames + 1] = value()
	elseif name == "--tune" then
		options.tune = true
	elseif name == "--docs" then
		options.docs = true
	elseif name == "--top" then
		options.top = tonumber(value())
	elseif name == "--scenarios" then
		options.list = true
	else
		io.stderr:write("unknown option " .. tostring(name) .. "\n")
		os.exit(2)
	end
	index = index + 1
end

if options.list then
	for _, scenario in ipairs(Sim.SCENARIOS) do
		local parts = {}
		for key, item in pairs(scenario) do
			if key ~= "name" then
				parts[#parts + 1] = key .. "=" .. tostring(item)
			end
		end
		table.sort(parts)
		print(string.format("%-12s %s", scenario.name, table.concat(parts, " ")))
	end
	return
end

local ns, guides = Sim.load()
local scenarios = Sim.SCENARIOS
if options.scenarioNames then
	scenarios = {}
	for _, wanted in ipairs(options.scenarioNames) do
		for _, scenario in ipairs(Sim.SCENARIOS) do
			if scenario.name == wanted then
				scenarios[#scenarios + 1] = scenario
			end
		end
	end
end
local simLevels = Sim.loadSimLevels(options.levelsFile)
if (options.truth == "sim" or options.alsoSim) and not simLevels then
	io.stderr:write("the simulator's levels are needed: --levels <file> (tools/placement_levels.py writes it)\n")
	os.exit(2)
end

-- The characters are made once: trying other constants only places them again.
local populations
local function population(only, truth, suffix)
	return {
		suffix = suffix,
		population = Sim.population({
			ns = ns,
			guides = guides,
			only = only,
			truth = truth,
			simLevels = simLevels,
			seed = options.seed,
			stride = options.stride,
			replicates = options.replicates,
			scenarios = scenarios,
		}),
	}
end

-- { [guide id, or "<guide id>/sim"] = { [scenario name] = stats } } for the constants (nil: the defaults).
local function run(constants)
	constants = constants or {}
	if not populations then
		populations = { population(options.only, options.truth, "") }
		if options.alsoSim then
			populations[2] = population(options.alsoSim, "sim", "/sim")
		end
	end
	for _, key in ipairs({ "bias", "openWeight", "doneWeight", "levelWeight" }) do
		if constants[key] == nil then
			constants[key] = find[key]
		end
	end
	local merged = {}
	for _, item in ipairs(populations) do
		for id, byScenario in pairs(Sim.evaluate(ns, item.population, constants)) do
			merged[id .. item.suffix] = byScenario
		end
	end
	return merged
end

local function constantsText(constants)
	local P = ns.Placement
	return string.format(
		"open %s, done %s, level %s, bias %s",
		tostring(constants.openWeight or P.OPEN_WEIGHT),
		tostring(constants.doneWeight or P.DONE_WEIGHT),
		tostring(constants.levelWeight or P.LEVEL_WEIGHT),
		tostring(constants.bias or P.BIAS)
	)
end

local groupOf = {}
for group, names in pairs(Sim.GROUPS) do
	for _, name in ipairs(names) do
		groupOf[name] = group
	end
end

local function mean(list)
	local sum = 0
	for _, item in ipairs(list) do
		sum = sum + item
	end
	return #list > 0 and sum / #list or 0
end

-- The figures that matter, averaged over everything the run covers: for characters that followed the guide the 90th
-- percentile and the median of the error in quest steps; for characters that did not, the 90th percentile of the error
-- in levels and the share 3 or more levels off; for characters with no history the median error in quest steps.
local function digest(results)
	local follow, followMedian, otherLevels, otherBad, levelOnly = {}, {}, {}, {}, {}
	for _, byScenario in pairs(results) do
		for name, stats in pairs(byScenario) do
			local group = groupOf[name]
			if group == "follow" then
				follow[#follow + 1] = stats.quests.p90
				followMedian[#followMedian + 1] = stats.quests.median
			elseif group == "other" then
				otherLevels[#otherLevels + 1] = stats.levels.p90
				otherBad[#otherBad + 1] = stats.catastrophic
			elseif group == "level" then
				levelOnly[#levelOnly + 1] = stats.quests.median
			end
		end
	end
	return {
		follow = mean(follow),
		median = mean(followMedian),
		otherLevels = mean(otherLevels),
		otherBad = mean(otherBad),
		levelOnly = mean(levelOnly),
	}
end

local function guideEntry(id)
	local plain = id:gsub("/sim$", "")
	for _, candidate in ipairs(guides) do
		if candidate.id == plain then
			return candidate
		end
	end
end

local function sortedIds(results)
	local ids = {}
	for id in pairs(results) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

-- --set: several sets of constants side by side, the figures of Sim.GROUPS averaged over the guides.
if options.sets then
	local columns = {
		{ "follow", "p90", "follow" },
		{ "mixed", "p90", "mixed" },
		{ "level2", "p90", "level2" },
		{ "runs30", "p90", "skip30runs" },
		{ "sparse15", "p90", "sparse15" },
		{ "scatter50", "p90", "scatter50" },
		{ "lag cat%", "cat", "lag" },
		{ "lag70 cat%", "cat", "lag70" },
		{ "sc50 cat%", "cat", "scatter50" },
		{ "lvlonly", "median", "levelonly" },
	}
	local header = { string.format("%-34s", "open done level bias") }
	for _, column in ipairs(columns) do
		header[#header + 1] = string.format("%10s", column[1])
	end
	print(table.concat(header, " "))
	for _, constants in ipairs(options.sets) do
		local results = run(constants)
		local label =
			constantsText(constants):gsub("open ", ""):gsub(", done", ""):gsub(", level", ""):gsub(", bias", "")
		local row = { string.format("%-34s", label) }
		for _, column in ipairs(columns) do
			local name, kind = column[3], column[2]
			local values = {}
			for _, byScenario in pairs(results) do
				for _, scenarioName in ipairs(name == "follow" and Sim.GROUPS.follow or { name }) do
					local stats = byScenario[scenarioName]
					if stats then
						if kind == "cat" then
							values[#values + 1] = stats.catastrophic * 100
						elseif kind == "p90" then
							values[#values + 1] = stats.quests.p90
						else
							values[#values + 1] = stats.quests.median
						end
					end
				end
			end
			row[#row + 1] = string.format("%10.1f", mean(values))
		end
		print(table.concat(row, " "))
	end
	return
end

-- --tune: a grid over the constants, best first.
if options.tune then
	local rows = {}
	for _, open in ipairs({ 0.1, 0.25, 0.5, 1 }) do
		for _, levelWeight in ipairs({ 2, 3, 4, 6, 8, 12, 16 }) do
			local constants = { openWeight = open, doneWeight = 1, levelWeight = levelWeight }
			local row = digest(run(constants))
			row.constants = constants
			-- a catastrophic placement (3 or more levels off) weighs 60 steps
			row.score = row.follow + 3 * row.otherLevels + 60 * row.otherBad
			rows[#rows + 1] = row
		end
	end
	table.sort(rows, function(a, b)
		return a.score < b.score
	end)
	for rank, row in ipairs(rows) do
		if rank <= (options.top or 20) then
			print(
				string.format(
					"%2d. score %5.2f | follow p90 %5.2f median %4.2f | others: p90 levels %4.2f, 3+ levels off %4.1f%%"
						.. " | no history: median %4.1f | %s",
					rank,
					row.score,
					row.follow,
					row.median,
					row.otherLevels,
					row.otherBad * 100,
					row.levelOnly,
					constantsText(row.constants)
				)
			)
		end
	end
	return
end

local results = run(find)

-- --docs: the tables of docs/ENGINE.md. The error is in quest steps: a trip between two quests cannot be told from
-- either.
if options.docs then
	local DOC_ROWS = {
		{ "exact", "followed the guide to the step, nothing else" },
		{ "skip20", "also skipped a fifth of the guide's quests" },
		{ "skip30runs", "skipped 30 percent, in runs of about six" },
		{ "early", "also did four quests that come later" },
		{ "level2", "its level is off by up to two" },
		{ "nolog", "its quest log is empty" },
		{ "mixed", "skipped a fifth in runs, did some early, level off by one, log half the time empty" },
		{ "lag", "stopped following the guide at 40 percent of the way and levelled elsewhere" },
		{ "scatter50", "did half the quests of the guide that its level allows, in no order" },
		{ "levelonly", "no quest history at all, only the level (level off by one)" },
	}
	local ids = sortedIds(results)
	local function names()
		local list = {}
		for _, id in ipairs(ids) do
			local entry = guideEntry(id)
			list[#list + 1] = (entry and entry.def.name or id) .. (id:find("/sim$") and " (simulator levels)" or "")
		end
		return list
	end
	print(
		string.format(
			"Quest steps from the true place, median / 90th percentile (truth: %s; seed %d; %s):",
			options.truth,
			options.seed,
			constantsText(find)
		)
	)
	print("")
	print("| The character | " .. table.concat(names(), " | ") .. " |")
	print("|---|" .. string.rep("---|", #ids))
	for _, row in ipairs(DOC_ROWS) do
		local cells = {}
		for _, id in ipairs(ids) do
			local stats = results[id][row[1]]
			cells[#cells + 1] = stats and string.format("%.0f / %.0f", stats.quests.median, stats.quests.p90) or "-"
		end
		print("| " .. row[2] .. " | " .. table.concat(cells, " | ") .. " |")
	end
	print("")
	print("Runs ending three or more levels from the true level:")
	print("")
	print("| The character | " .. table.concat(names(), " | ") .. " |")
	print("|---|" .. string.rep("---|", #ids))
	for _, name in ipairs({ "mixed", "levelonly", "lag", "scatter50" }) do
		local label
		for _, row in ipairs(DOC_ROWS) do
			label = row[1] == name and row[2] or label
		end
		local cells = {}
		for _, id in ipairs(ids) do
			local stats = results[id][name]
			cells[#cells + 1] = stats and string.format("%.1f%%", stats.catastrophic * 100) or "-"
		end
		print("| " .. label .. " | " .. table.concat(cells, " | ") .. " |")
	end
	return
end

print(
	string.format(
		"truth: %s; seed %d; every %d. step, %d draws each; %s",
		options.truth,
		options.seed,
		options.stride,
		options.replicates,
		constantsText(find)
	)
)
for _, id in ipairs(sortedIds(results)) do
	local entry = guideEntry(id)
	print(string.format("\n%s (%d steps, %d quests)", id, #entry.guide.steps, #entry.order))
	print(
		"  scenario       runs | steps: median  p90  max | quest steps: median  p90 within5"
			.. " | levels: median  p90  max | >=3 levels"
	)
	for _, scenario in ipairs(scenarios) do
		local stats = results[id][scenario.name]
		print(
			string.format(
				"  %-12s %6d | %12.1f %4.0f %4.0f | %18.1f %4.0f %6.0f%% | %15.2f %4.1f %4.1f | %5.1f%%",
				scenario.name,
				stats.steps.count,
				stats.steps.median,
				stats.steps.p90,
				stats.steps.max,
				stats.quests.median,
				stats.quests.p90,
				stats.quests.within * 100,
				stats.levels.median,
				stats.levels.p90,
				stats.levels.max,
				stats.catastrophic * 100
			)
		)
	end
end
local overall = digest(results)
print(
	string.format(
		"\noverall: followed the guide: p90 %.1f quest steps, median %.2f | did not: p90 %.2f levels, %.1f%% three or more"
			.. " levels off | no history: median %.1f quest steps",
		overall.follow,
		overall.median,
		overall.otherLevels,
		overall.otherBad * 100,
		overall.levelOnly
	)
)
