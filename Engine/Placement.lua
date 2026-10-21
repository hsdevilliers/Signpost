-- ns.Placement: where in a guide a character is, worked out from what the character has already done. A pure function
-- over a parsed guide's steps and a snapshot of the player (level, which quests are done, which are in the quest log):
-- ns.Progress uses it the first time a guide runs for a character that has no progress in it, and for "Find my place"
-- (docs/ENGINE.md "Engine/Placement.lua" has the algorithm, the constants and how they were chosen).
--
-- Every step gets a label from its quest directives (.accept, .turnin, .complete): "done" when it has some and the
-- character satisfies all of them, "open" when it has some and not all, "neutral" when it has none (a trip, a
-- training, a .level gate, a .todo, a profession step: no evidence either way). The split k is the step the pointer
-- goes on: every step before it is behind the character. It is the k that minimises
--
--     OPEN_WEIGHT * (open steps before k) + DONE_WEIGHT * (done steps at or after k) + LEVEL_WEIGHT * (levels between
--     the character's level and the level the guide expects at step k, less a tolerance while the quests show the
--     character playing the guide)
--
-- a changepoint fit: one quest skipped, or done early, moves the cost by a constant and not the answer. Ties go to the
-- earliest k, so a trip between the last quest done and the next one open is the step shown (the engine passes it by
-- itself when the character is already there). Nothing here reads the game: the snapshot is passed in.
local ADDON_NAME, ns = ...

local Placement = {}
ns.Placement = Placement

-- Constants, chosen by the simulation over the shipped guides (tests/helpers/placement_sim.lua and
-- tools/placement_report.lua; docs/ENGINE.md has the numbers).
-- What a step the character has not done costs when it lies before the pointer ("skipped"): a player skips quests
-- all the time, and in runs, so it is cheap...
Placement.OPEN_WEIGHT = 0.25
-- ...and a step the character has done, lying at or after the pointer ("ahead"), costs more: it says the pointer is
-- late.
Placement.DONE_WEIGHT = 1
-- What one level between the character and the guide costs, in wrong steps: enough that a character far from its level
-- is not put there on the strength of a few quests, little enough that a clean history wins over a level that is a
-- level off.
Placement.LEVEL_WEIGHT = 6
-- A chapter's levels are whole levels (the level at its start, the level at its end), so the line between them runs
-- about half a level under the level a character has at that step, fraction and all (measured against the simulator's
-- levels: 0.48 in the short chapters).
Placement.BIAS = 0.5
-- The line through a chapter: "xp", straight in experience (see Experience below), or "linear", straight in level.
-- The second is the first version, kept for the simulation to compare with; it is wrong in a chapter that spans many
-- levels.
Placement.CURVE = "xp"
-- The level term's tolerance while the history shows the character playing the guide: the first TOL_BASE levels of
-- difference are free, and TOL_SPAN more for each level the chapter spans. A chapter's line can be off by a level or
-- more inside a long chapter (its quests do not give equal experience, the guide's headers are whole levels), and a
-- character who has done the quests one after the other should not be pulled to where the line says its level
-- belongs. The tolerance is whole only while nearly all the steps before the candidate are done: it falls to nothing
-- as that share falls from GATE_HIGH to GATE_LOW, because a character who scatters over the guide, or has stopped
-- playing it, is exactly the one the level is there for. With no history there is no tolerance.
Placement.TOL_BASE = 0.3
Placement.TOL_SPAN = 0.05
Placement.GATE_LOW = 0.5
Placement.GATE_HIGH = 0.8
-- At or below this level a character with none of the guide's quests done or in the log is simply at its first step.
Placement.NO_EVIDENCE_LEVEL = 2
-- The boundary at the split: how many steps with a label are looked at on each side, and the sharpness from which the
-- placement is "high" and "medium" confidence (below: "low").
Placement.SHARP_WINDOW = 6
Placement.SHARP_HIGH = 0.85
Placement.SHARP_MEDIUM = 0.7
-- A cost lower than the best by less than this is no better (floating point): the earliest of them wins.
local EPSILON = 1e-9

local EMPTY = {}
local QUEST_DIRECTIVES = { accept = true, turnin = true, complete = true }

-- Labels --------------------------------------------------------------------------------------------------------------

-- fn(questID) from snapshot[name], answered once per quest.
local function asker(snapshot, name)
	local fn = type(snapshot) == "table" and snapshot[name]
	local memo = {}
	return function(questID)
		local answer = memo[questID]
		if answer == nil then
			answer = type(fn) == "function" and fn(questID) and true or false
			memo[questID] = answer
		end
		return answer
	end
end

local function questOf(directive)
	local args = type(directive) == "table" and directive.args
	local questID = type(args) == "table" and args.questID
	if QUEST_DIRECTIVES[directive.name] and type(questID) == "number" then
		return questID
	end
end

-- Whether the snapshot satisfies a quest directive the way ns.Conditions' rules do (docs/GUIDE-FORMAT.md): .accept when
-- the quest is in the log or done, .turnin when it is done, .complete when it is done or every objective is.
local function satisfied(name, questID, done, active, ready)
	if name == "accept" then
		return active(questID) or done(questID)
	elseif name == "turnin" then
		return done(questID)
	end
	return done(questID) or ready(questID)
end

-- "done", "open" or "neutral" for a step. A quest the step marks .optional counts only when nothing else in the step
-- does, and then only as evidence of progress: not doing an optional quest says nothing.
local function labelOf(step, done, active, ready)
	local counted, countedOk, optional, optionalOk = 0, 0, 0, 0
	local marked = type(step.optional) == "table" and step.optional or EMPTY
	for _, directive in ipairs(step.directives or EMPTY) do
		local questID = questOf(directive)
		if questID then
			local ok = satisfied(directive.name, questID, done, active, ready)
			if marked[questID] then
				optional, optionalOk = optional + 1, optionalOk + (ok and 1 or 0)
			else
				counted, countedOk = counted + 1, countedOk + (ok and 1 or 0)
			end
		end
	end
	if counted > 0 then
		return countedOk == counted and "done" or "open"
	end
	if optional > 0 and optionalOk == optional then
		return "done"
	end
	return "neutral"
end

-- labels[i] for every step, and how many distinct quests of the guide are done, in the log, and there are:
-- { done = , active = , total = }.
function Placement:Labels(guide, snapshot)
	local done, active, ready = asker(snapshot, "done"), asker(snapshot, "active"), asker(snapshot, "ready")
	local labels, seen = {}, {}
	local stats = { done = 0, active = 0, total = 0 }
	for i, step in ipairs(guide.steps or EMPTY) do
		labels[i] = labelOf(step, done, active, ready)
		for _, directive in ipairs(step.directives or EMPTY) do
			local questID = questOf(directive)
			if questID and not seen[questID] then
				seen[questID] = true
				stats.total = stats.total + 1
				if done(questID) then
					stats.done = stats.done + 1
				elseif active(questID) then
					stats.active = stats.active + 1
				end
			end
		end
	end
	return labels, stats
end

-- Experience ----------------------------------------------------------------------------------------------------------

-- Experience to the next level, levels 1 to 59: Classic's table, which tools/sim_params.json assumes (VERIFY(launch):
-- Forever's). Only its shape matters here: the first levels need little experience, so a character gains them fast, and
-- the quests of a chapter that spans many levels give about the same experience each. Level is therefore not a straight
-- line over the steps of such a chapter, experience is (the simulator's levels follow it to within a level or so where
-- a straight line is off by three or four).
-- stylua: ignore
local XP_TO_NEXT = {
	400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600,
	8800, 10100, 11400, 12900, 14400, 16000, 17700, 19400, 21300, 23200,
	25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400,
	50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700,
	95800, 101000, 106300, 111800, 117500, 123200, 129100, 135100, 141200, 147500,
	153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800,
}
local XP_AT = { 0 } -- XP_AT[level]: the experience a character has on reaching that level
for level, needed in ipairs(XP_TO_NEXT) do
	XP_AT[level + 1] = XP_AT[level] + needed
end
local TOP_LEVEL = #XP_TO_NEXT + 1

-- The experience of a (fractional) level, and the level of some experience: its inverse. Within a level it is a
-- straight line; below level 1 and above the top level it stops.
function Placement:ExperienceAt(level)
	if level <= 1 then
		return 0
	elseif level >= TOP_LEVEL then
		return XP_AT[TOP_LEVEL]
	end
	local whole = math.floor(level)
	return XP_AT[whole] + (level - whole) * (XP_AT[whole + 1] - XP_AT[whole])
end

function Placement:LevelAt(experience)
	if experience <= 0 then
		return 1
	elseif experience >= XP_AT[TOP_LEVEL] then
		return TOP_LEVEL
	end
	local low, high = 1, TOP_LEVEL
	while high - low > 1 do
		local middle = math.floor((low + high) / 2)
		if XP_AT[middle] <= experience then
			low = middle
		else
			high = middle
		end
	end
	return low + (experience - XP_AT[low]) / (XP_AT[low + 1] - XP_AT[low])
end

-- Expected levels -----------------------------------------------------------------------------------------------------

-- The highest `.level N` of a step, or nil.
local function gateOf(step)
	local gate
	for _, directive in ipairs(step.directives or EMPTY) do
		local level = directive.name == "level" and type(directive.args) == "table" and directive.args.level
		if type(level) == "number" and (not gate or level > gate) then
			gate = level
		end
	end
	return gate
end

local function chapterRange(chapter)
	local levels = type(chapter) == "table" and not chapter.dungeon and chapter.levels
	local low = type(levels) == "table" and tonumber(levels[1])
	local high = type(levels) == "table" and (tonumber(levels[2]) or low)
	if low and high and high >= low then
		return low, high
	end
end

-- lv[i] for i = 1 .. #steps + 1: the level the guide expects the character to have when it starts step i (the last
-- entry: when it is done with the guide). Inside a chapter it is interpolated between the chapter's levels (its first
-- level at its first step, its last at the step after its last), along the curve `curve` (default: Placement.CURVE),
-- and it never falls below an earlier step's or below a `.level N` gate in an earlier step. A dungeon chapter's levels
-- say where it is on offer, not where the route is, so they add nothing. false where the guide says nothing. The second
-- result is the guide's top level: the higher of lv[#steps + 1] and the guide's declared levels. The third is span[i],
-- the number of levels the chapter of step i spans (0 where it has no line): the longer a chapter, the less the line
-- through it can be trusted.
function Placement:Levels(guide, curve)
	curve = curve or self.CURVE
	local steps, chapters = guide.steps or EMPTY, guide.chapters or EMPTY
	local n = #steps
	local count, before, chapterOf, current = {}, {}, {}, nil
	for i, step in ipairs(steps) do
		current = step.chapter or current
		chapterOf[i] = current
		if current then
			count[current] = (count[current] or 0) + 1
		end
	end
	local lv, span, level, gate = {}, {}, nil, nil
	local lastChapter, lastHigh
	for i = 1, n + 1 do
		local chapter = chapterOf[i] or chapterOf[n]
		local low, high = chapterRange(chapters[chapter or 0])
		span[i] = low and high - low or 0
		if i <= n and chapter ~= lastChapter then
			-- a new chapter starts, so the one before it is done and its top level reached (a dungeon chapter has no line of
			-- its own to carry it on)
			if lastHigh and (not level or lastHigh > level) then
				level = lastHigh
			end
			lastChapter, lastHigh = chapter, high
		end
		if low then
			local fraction = (before[chapter] or 0) / count[chapter]
			local raw
			if curve == "linear" then
				raw = low + (high - low) * fraction
			else
				local start = self:ExperienceAt(low)
				raw = self:LevelAt(start + (self:ExperienceAt(high) - start) * fraction)
			end
			level = (not level or raw > level) and raw or level
		end
		if gate and (not level or gate > level) then
			level = gate
		end
		lv[i] = level or false
		local step = steps[i]
		if step then
			if chapterOf[i] then
				before[chapterOf[i]] = (before[chapterOf[i]] or 0) + 1
			end
			local atLeast = gateOf(step)
			if atLeast and (not gate or atLeast > gate) then
				gate = atLeast
			end
		end
	end
	local top = lv[n + 1] or nil
	local levels = type(guide.def) == "table" and guide.def.levels
	local declared = type(levels) == "table" and tonumber(levels[2])
	if declared and (not top or declared > top) then
		top = declared
	end
	return lv, top, span
end

-- Find ----------------------------------------------------------------------------------------------------------------

-- How far `value` lies outside the span from `low` to `high`.
local function distance(value, low, high)
	if value < low then
		return low - value
	elseif value > high then
		return value - high
	end
	return 0
end

-- How sharp the boundary at the split is, 0 to 1: the share of the last `window` steps with a label before it that are
-- done, and of the first `window` after it that are open, averaged (one of them when the other side has none); nil when
-- neither side has a label.
local function sharpness(labels, split, window)
	local n = #labels
	local before, doneBefore, after, openAfter = 0, 0, 0, 0
	local i = split - 1
	while i >= 1 and before < window do
		if labels[i] ~= "neutral" then
			before = before + 1
			if labels[i] == "done" then
				doneBefore = doneBefore + 1
			end
		end
		i = i - 1
	end
	i = split
	while i <= n and after < window do
		if labels[i] ~= "neutral" then
			after = after + 1
			if labels[i] == "open" then
				openAfter = openAfter + 1
			end
		end
		i = i + 1
	end
	if before > 0 and after > 0 then
		return (doneBefore / before + openAfter / after) / 2
	elseif before > 0 then
		return doneBefore / before
	elseif after > 0 then
		return openAfter / after
	end
end

-- The fit itself, from what Labels and Levels computed (lv, top, span; the simulation calls it again and again with
-- other constants); see Find for the arguments and the result.
function Placement:Fit(labels, stats, lv, top, span, snapshot, opts)
	local n = #labels
	opts = opts or EMPTY
	local doneWeight = opts.doneWeight or self.DONE_WEIGHT
	local levelWeight = opts.levelWeight or self.LEVEL_WEIGHT
	local bias = opts.bias or self.BIAS
	local tolBase = opts.tolBase or self.TOL_BASE
	local tolSpan = opts.tolSpan or self.TOL_SPAN
	local gateLow = opts.gateLow or self.GATE_LOW
	local gateHigh = opts.gateHigh or self.GATE_HIGH
	local level = type(snapshot) == "table" and tonumber(snapshot.level)
	if level and level < 1 then
		level = nil
	end

	local evidence = stats.done + stats.active
	local mode
	if evidence > 0 then
		mode = "history"
	elseif level and level > self.NO_EVIDENCE_LEVEL and lv[n + 1] then
		mode = "level"
	else
		mode = "none"
	end
	-- With nothing done every quest step is open because there is nothing to tell, not because the character skipped it.
	local openWeight = evidence > 0 and (opts.openWeight or self.OPEN_WEIGHT) or 0

	local split = 1
	if mode ~= "none" then
		local doneTotal = 0
		for i = 1, n do
			if labels[i] == "done" then
				doneTotal = doneTotal + 1
			end
		end
		local best, open, done = math.huge, 0, 0 -- the cost; open and done steps before k
		for k = 1, n + 1 do
			local cost = openWeight * open + doneWeight * (doneTotal - done)
			if level and lv[k] then
				-- the character's level is a whole level: from `level` up to just short of the next
				local gap = distance(lv[k] + bias, level, level + 1)
				if mode == "history" and gap > 0 then
					-- the history outweighs a level that is a little off: more in a long chapter, whose line is the less
					-- certain, and only as far as the quests show the character playing the guide up to here
					local tolerance = tolBase + tolSpan * (span[k] or 0)
					local labeled = open + done
					if gateHigh > gateLow and labeled > 0 then
						local share = done / labeled
						tolerance = tolerance * math.min(1, math.max(0, (share - gateLow) / (gateHigh - gateLow)))
					end
					gap = math.max(0, gap - tolerance)
				end
				cost = cost + levelWeight * gap
			end
			if cost < best - EPSILON then
				best, split = cost, k
			end
			if labels[k] == "open" then
				open = open + 1
			elseif labels[k] == "done" then
				done = done + 1
			end
		end
		if split == n + 1 then
			mode = "end"
		end
	end

	-- The pointer: the split, past the steps that are done already (the engine would pass those at once).
	local index = math.min(split, n)
	while index < n and labels[index] == "done" do
		index = index + 1
	end
	local skipped, ahead = 0, 0
	for i = 1, n do
		if i < index and labels[i] == "open" then
			skipped = skipped + 1
		elseif i >= index and labels[i] == "done" then
			ahead = ahead + 1
		end
	end
	local sharp = mode ~= "none" and sharpness(labels, split, opts.sharpWindow or self.SHARP_WINDOW) or nil
	local confidence
	if mode == "none" then
		confidence = "high"
	elseif mode == "level" or not sharp then
		confidence = "low"
	elseif sharp >= self.SHARP_HIGH then
		confidence = "high"
	elseif sharp >= self.SHARP_MEDIUM then
		confidence = "medium"
	else
		confidence = "low"
	end
	return {
		index = index,
		split = split,
		mode = mode,
		confidence = confidence,
		sharpness = sharp,
		level = level,
		expected = lv[split] or nil,
		top = top,
		done = stats.done,
		active = stats.active,
		total = stats.total,
		skipped = skipped,
		ahead = ahead,
		labels = labels,
	}
end

-- Where the character is in `guide` (a parsed guide: steps, chapters, def), from snapshot = { level = ,
-- done = fn(questID), active = fn(questID), ready = fn(questID) (optional: in the log with every objective done) }.
-- Returns nil for a guide without steps, else
--   index       the step the pointer goes on, 1 .. #steps: the split, past the steps that are done already
--   split       the step at which everything before is behind the character, 1 .. #steps + 1 (#steps + 1: it is done
--               with the guide; the pointer then goes on the last step)
--   mode        "none" (nothing to go on: the first step), "history" (quests done or in the log), "level" (only the
--               level) or "end" (all of the guide is behind the character: it has done it, or is above its top level)
--   confidence  "high", "medium" or "low": how sharp the boundary is (`sharpness`, 0 to 1, from the labels around the
--               split); "level" is always low
--   level, expected, top   the character's level, the guide's expected level at the split, the guide's top level
--   done, active, total    distinct quests of the guide: done, in the log, in the guide
--   skipped, ahead         steps before the pointer not done ("skipped"), steps at or after it done ("ahead")
--   labels      the label of each step, "done", "open" or "neutral"
-- `opts` overrides the constants (openWeight, doneWeight, levelWeight, bias, tolBase, tolSpan, gateLow, gateHigh and
-- the curve of the levels) for the simulation that chose them.
function Placement:Find(guide, snapshot, opts)
	local steps = type(guide) == "table" and guide.steps
	if type(steps) ~= "table" or #steps == 0 then
		return nil
	end
	local labels, stats = self:Labels(guide, snapshot)
	local lv, top, span = self:Levels(guide, opts and opts.curve)
	return self:Fit(labels, stats, lv, top, span, snapshot, opts)
end
