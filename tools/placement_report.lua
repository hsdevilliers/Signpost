-- Prints how well ns.Placement finds a character in each shipped guide, and searches its constants. Run it from the
-- repository root with the Lua of the test toolchain (the busted install's lua), or any Lua 5.1:
--
--   .venv\lua51\bin\lua.exe tools\placement_report.lua                  every guide, every scenario
--   ... tools\placement_report.lua --guide horde-troll-hunter --truth model
--   ... tools\placement_report.lua --truth sim --levels <file>          levels from tools/guide_sim.py (see below)
--   ... tools\placement_report.lua --open 1 --done 1 --level 8          try other constants
--   ... tools\placement_report.lua --tune                               grid search over the constants
--   ... tools\placement_report.lua --scenarios                          what each scenario does
--
-- The method and the numbers it gave are in docs/ENGINE.md ("Engine/Placement.lua"); tests/helpers/placement_sim.lua is the
-- simulation. --truth says what level a character really has at a step: "warp" (the default: the guide's chapter levels
-- reached on a curve, so the straight line the placement assumes is wrong inside a chapter), "model" (the placement's own
-- levels) or "sim" (the levels tools/guide_sim.py walks, from the private data pack: export them with
-- tools/placement_levels.py, then pass the Lua file it writes as --levels).
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
	elseif name == "--scenario" then
		options.scenarioNames = options.scenarioNames or {}
		options.scenarioNames[#options.scenarioNames + 1] = value()
	elseif name == "--tune" then
		options.tune = true
	elseif name == "--scenarios" then
		options.list = true
	elseif name == "--set" then
		-- open,done,level,bias
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
	elseif name == "--also-sim" then
		options.alsoSim = options.alsoSim or {}
		options.alsoSim[#options.alsoSim + 1] = value()
	elseif name == "--bias" then
		find.bias = tonumber(value())
	elseif name == "--top" then
		options.top = tonumber(value())

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

-- The characters are made once (trying other constants only places them again). --also-sim adds the guides it names under the
-- simulator's levels (--levels), reported as "<guide>/sim".
local populations
local function run(constants)
	if not populations then
		populations = {
			{
				suffix = "",
				population = Sim.population({
					ns = ns,
					guides = guides,
					only = options.only,
					truth = options.truth,
					simLevels = simLevels,
					seed = options.seed,
					stride = options.stride,
					replicates = options.replicates,
					scenarios = scenarios,
				}),
			},
		}
		if options.alsoSim then
			populations[2] = {
				suffix = "/sim",
				population = Sim.population({
					ns = ns,
					guides = guides,
					only = options.alsoSim,
					truth = "sim",
					simLevels = simLevels,
					seed = options.seed,
					stride = options.stride,
					replicates = options.replicates,
					scenarios = scenarios,
				}),
			}
		end
	end
	local merged = {}
	constants = constants or {}
	for _, key in ipairs({ "bias", "band" }) do
		if constants[key] == nil then
			constants[key] = find[key]
		end
	end
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
		"open %s, done %s, level %s, band %s",
		tostring(constants.openWeight or P.OPEN_WEIGHT),
		tostring(constants.doneWeight or P.DONE_WEIGHT),
		tostring(constants.levelWeight or P.LEVEL_WEIGHT),
		tostring(constants.band or P.BAND)
	)
end

if options.sets then
	-- Several sets of constants side by side: averages over the guides of the figures that matter.
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
		{ "lvlxp", "median", "levelonlyxp" },
	}
	local header = { string.format("%-34s", "open done level slack window band") }
	for _, column in ipairs(columns) do
		header[#header + 1] = string.format("%10s", column[1])
	end
	print(table.concat(header, " "))
	for _, constants in ipairs(options.sets) do
		local results = run(constants)
		local function mean(name, kind)
			local sum, count = 0, 0
			for _, byScenario in pairs(results) do
				local names = name == "follow" and Sim.GROUPS.follow or { name }
				for _, scenarioName in ipairs(names) do
					local stats = byScenario[scenarioName]
					if stats then
						count = count + 1
						if kind == "cat" then
							sum = sum + stats.catastrophic * 100
						elseif kind == "p90" then
							sum = sum + stats.quests.p90
						else
							sum = sum + stats.quests.median
						end
					end
				end
			end
			return count > 0 and sum / count or 0
		end
		local row = {
			string.format(
				"%-34s",
				string.format(
					"%s %s %s %s %s %s",
					tostring(constants.openWeight),
					tostring(constants.doneWeight),
					tostring(constants.levelWeight),
					tostring(constants.slack or 0),
					tostring(constants.window or "-"),
					tostring(constants.band or "")
				)
			),
		}
		for _, column in ipairs(columns) do
			row[#row + 1] = string.format("%10.1f", mean(column[3], column[2]))
		end
		print(table.concat(row, " "))
	end
	return
end

if options.tune then
	-- A grid over the constants. For each: the average, over every guide, of the 90th percentile of the error in quest steps
	-- for characters that followed the guide ("follow"), and, for characters that did not ("other": their true position is
	-- the one their level says) the error in levels and the share 3 or more levels off.
	local groupOf = {}
	for group, names in pairs(Sim.GROUPS) do
		for _, name in ipairs(names) do
			groupOf[name] = group
		end
	end
	local rows = {}
	local function try(constants)
		local results = run(constants)
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
		local function mean(list)
			local sum = 0
			for _, value in ipairs(list) do
				sum = sum + value
			end
			return #list > 0 and sum / #list or 0
		end
		local row = {
			constants = constants,
			follow = mean(follow),
			median = mean(followMedian),
			otherLevels = mean(otherLevels),
			otherBad = mean(otherBad),
			levelOnly = mean(levelOnly),
		}
		row.score = row.follow + 3 * row.otherLevels + 60 * row.otherBad
		rows[#rows + 1] = row
	end
	for _, open in ipairs({ 0.25, 0.5 }) do
		for _, levelWeight in ipairs({ 3, 4, 6, 8, 12 }) do
			for _, slack in ipairs({ 0, 0.5, 1 }) do
				for _, window in ipairs({ 0, 3, 4, 5 }) do
					try({
						openWeight = open,
						doneWeight = 1,
						levelWeight = levelWeight,
						slack = slack,
						window = window > 0 and window or nil,
					})
				end
			end
		end
	end
	table.sort(rows, function(a, b)
		return a.score < b.score
	end)
	for rank, row in ipairs(rows) do
		if rank <= (options.top or 25) then
			print(
				string.format(
					"%2d. score %5.2f | follow p90 %5.2f median %4.2f | other: p90 levels %4.2f, >=3 levels %4.1f%% | level-only median %4.1f | %s",
					rank,
					row.score,
					row.follow,
					row.median,
					row.otherLevels,
					row.otherBad * 100,
					row.levelOnly,
					string.format(
						"open %s level %s slack %s window %s",
						tostring(row.constants.openWeight),
						tostring(row.constants.levelWeight),
						tostring(row.constants.slack),
						tostring(row.constants.window)
					)
				)
			)
		end
	end
	return
end

local results = run(find)
print(string.format("truth: %s; seed %d; every %d. step, %d draws each; %s", options.truth, options.seed, options.stride, options.replicates, constantsText(find)))
local ids = {}
for id in pairs(results) do
	ids[#ids + 1] = id
end
table.sort(ids)
for _, id in ipairs(ids) do
	local entry
	for _, candidate in ipairs(guides) do
		if candidate.id == id:gsub("/sim$", "") then
			entry = candidate
		end
	end
	print(string.format("\n%s (%d steps, %d quests)", id, #entry.guide.steps, #entry.order))
	print("  scenario       runs | steps: median  p90  max | quest steps: median  p90 within5 | levels: median  p90  max | >=3 levels")
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
