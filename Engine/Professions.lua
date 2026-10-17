-- ns.Professions (docs/ENGINE.md): the profession registry (modules from Professions/, tracks from
-- Guides/Professions/), the character's detected profession plan (PLAN §3.8) and the merging of the plan's tracks into
-- a parsed guide (GUIDE-FORMAT "Track merging"). Profession keys are data: nothing here names a profession.
local ADDON_NAME, ns = ...
local L = ns.L

local Professions = { modules = {}, bySkillLine = {}, tracks = {}, problems = {} }
ns.Professions = Professions

-- Primary profession slots per character, as in Classic. VERIFY(beta): Forever keeps two.
local MAX_PRIMARY = 2

local TRACK_SOURCE = "track:"

ns.SavedVars:RegisterDefaults("char", "declinedProfessions", {})

-- Registration problems are kept on the registry and recorded in the error log, never thrown (as in Registry.lua).
local function report(message)
	Professions.problems[#Professions.problems + 1] = message
	if ns.Errors then
		ns.Errors:Record(ADDON_NAME .. ": " .. message)
	end
end

local function validKey(key)
	return type(key) == "string" and key ~= ""
end

-- Registry ----------------------------------------------------------------------------------------------------------

-- Registers a profession module: { skillLine = id, primary = bool, gathering = bool, ranks = { caps }, directives }.
-- Its directives go into ns.Directives (for every character, like class directives). Returns true, or false and the
-- problem.
function Professions:Register(key, module)
	local problem
	if not validKey(key) or type(module) ~= "table" then
		problem = L["A profession module needs a key and a table"]
	elseif type(module.skillLine) ~= "number" then
		problem = string.format(L["Profession module %s has no skill line"], key)
	end
	if problem then
		report(problem)
		return false, problem
	end
	local previous = self.modules[key]
	if previous and previous ~= module then
		report(string.format(L["Profession module %s was registered twice; the later one is used"], key))
		if self.bySkillLine[previous.skillLine] == key then
			self.bySkillLine[previous.skillLine] = nil
		end
	end
	local other = self.bySkillLine[module.skillLine]
	if other and other ~= key then
		report(string.format(L["Profession modules %s and %s share skill line %d"], other, key, module.skillLine))
	end
	self.modules[key] = module
	self.bySkillLine[module.skillLine] = key

	local directives, target = module.directives, ns.Directives
	if directives ~= nil then
		if type(directives) ~= "table" or not (target and target.Register) then
			report(string.format(L["Profession module %s: its directives could not be registered"], key))
		else
			local names = {}
			for name in pairs(directives) do
				names[#names + 1] = name
			end
			table.sort(names, function(a, b)
				return tostring(a) < tostring(b)
			end)
			for _, name in ipairs(names) do
				ns.SafeCall(target.Register, target, name, directives[name])
			end
		end
	end
	return true
end

function Professions:Get(key)
	if key == nil then
		return nil
	end
	return self.modules[key]
end

-- The key and module of the profession module for a skill line, or nothing.
function Professions:ForSkillLine(skillLine)
	local key = skillLine ~= nil and self.bySkillLine[skillLine]
	if key then
		return key, self.modules[key]
	end
end

-- Registers a profession's route track (GUIDE-FORMAT "Files"). Returns true, or false and the problem.
function Professions:RegisterTrack(key, text)
	if not validKey(key) or type(text) ~= "string" then
		local problem = string.format(L["Track %s needs a key and its text"], tostring(key))
		report(problem)
		return false, problem
	end
	if self.tracks[key] and self.tracks[key] ~= text then
		report(string.format(L["Track %s was registered twice; the later one is used"], key))
	end
	self.tracks[key] = text
	return true
end

function Professions:Track(key)
	if key == nil then
		return nil
	end
	return self.tracks[key]
end

-- The profession plan (PLAN §3.8) ---------------------------------------------------------------------------------
-- plan = { primary = { key, ... }, secondary = { key, ... }, declined = { [key] = true },
--          learned = { [key] = true }, unknown = { key, ... } }
-- primary and secondary are in plan order: the guide's suggestion order, then learned professions the guide does not
-- suggest (by key). That order never depends on what is learned, so the merged route keeps its shape as the
-- character learns its professions. declined lists declined professions that are not learned; unknown lists
-- suggestions without a profession module (they cannot be routed).

-- "#professions" values: a list of keys (or a comma-separated string), trimmed, without duplicates.
local function suggestionList(suggestions)
	if type(suggestions) == "string" then
		local split = {}
		for item in suggestions:gmatch("[^,]+") do
			split[#split + 1] = item
		end
		suggestions = split
	end
	local list, seen = {}, {}
	if type(suggestions) ~= "table" then
		return list
	end
	for _, key in ipairs(suggestions) do
		if type(key) == "string" then
			key = key:match("^%s*(.-)%s*$")
			if key ~= "" and not seen[key] then
				seen[key] = true
				list[#list + 1] = key
			end
		end
	end
	return list
end

-- What the character has learned, from ns.Player.professions: { [key] = isPrimary } for professions with a module,
-- and the number of primary slots in use (a learned primary without a module still takes a slot).
local function learnedProfessions(self)
	local learned, usedPrimary = {}, 0
	local professions = ns.Player and ns.Player.professions
	if type(professions) ~= "table" then
		return learned, usedPrimary
	end
	for skillLine, entry in pairs(professions) do
		local key = entry.key
		if key == nil or not self.modules[key] then
			key = self:ForSkillLine(skillLine)
		end
		local module = key and self.modules[key]
		local primary
		if module then
			primary = module.primary == true
			learned[key] = primary
		else
			primary = entry.primary == true
		end
		if primary then
			usedPrimary = usedPrimary + 1
		end
	end
	return learned, usedPrimary
end

local function detect(self, suggestions)
	local stored = ns.char and ns.char.declinedProfessions or {}
	local learned, usedPrimary = learnedProfessions(self)
	local plan = { primary = {}, secondary = {}, declined = {}, learned = {}, unknown = {} }
	local inPlan = {}
	local function add(key, primary)
		if not inPlan[key] then
			inPlan[key] = true
			local list = primary and plan.primary or plan.secondary
			list[#list + 1] = key
		end
	end

	-- 1. learned professions are always in the plan; 2. free primary slots go to the suggested primaries in order,
	-- skipping learned and declined ones; 3. suggested secondaries stay until learned or declined.
	local freePrimary = math.max(0, MAX_PRIMARY - usedPrimary)
	local suggested = {}
	for _, key in ipairs(suggestions) do
		suggested[key] = true
		local module = self.modules[key]
		if not module then
			plan.unknown[#plan.unknown + 1] = key
		elseif learned[key] ~= nil then
			add(key, learned[key])
		elseif not stored[key] then
			if module.primary then
				if freePrimary > 0 then
					freePrimary = freePrimary - 1
					add(key, true)
				end
			else
				add(key, false)
			end
		end
	end
	local others = {}
	for key in pairs(learned) do
		plan.learned[key] = true
		if not suggested[key] then
			others[#others + 1] = key
		end
	end
	table.sort(others)
	for _, key in ipairs(others) do
		add(key, learned[key])
	end
	for key, declined in pairs(stored) do
		if declined and learned[key] == nil then
			plan.declined[key] = true
		end
	end
	return plan
end

local function sameList(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function sameSet(a, b)
	for key in pairs(a) do
		if not b[key] then
			return false
		end
	end
	for key in pairs(b) do
		if not a[key] then
			return false
		end
	end
	return true
end

-- Two plans that route the same professions; a profession turning from suggested into learned changes neither.
local function samePlan(a, b)
	return sameList(a.primary, b.primary) and sameList(a.secondary, b.secondary) and sameSet(a.declined, b.declined)
end

-- Detects the plan for a guide's "#professions" suggestions (from ns.Parser:Headers) and remembers both, so later
-- changes (a profession learned or unlearned, Decline, Restore) are measured against it. Never fires a message
-- itself: the caller is about to use the plan.
function Professions:Plan(suggestions)
	self.suggestions = suggestionList(suggestions)
	self.current = detect(self, self.suggestions)
	return self.current
end

-- The plan last detected (nil until a guide asked for one with Plan).
function Professions:Current()
	return self.current
end

-- Detects the plan again with the remembered suggestions; fires PROFESSION_PLAN_CHANGED(plan) when it routes
-- differently. Nothing happens before a guide asked for a plan.
local function recompute(self)
	if not self.suggestions then
		return
	end
	local plan = detect(self, self.suggestions)
	local previous = self.current
	self.current = plan
	if not (previous and samePlan(previous, plan)) then
		ns.Events:Fire("PROFESSION_PLAN_CHANGED", plan)
	end
end

function Professions:IsDeclined(key)
	local stored = ns.char and ns.char.declinedProfessions
	return stored ~= nil and key ~= nil and stored[key] == true
end

-- Marks a profession declined for this character (SignpostCharDB.declinedProfessions), so the next suggestion takes
-- its slot. Returns false when the key is invalid or SavedVariables are not loaded yet.
function Professions:Decline(key)
	local db = ns.char
	if not validKey(key) or not db then
		return false
	end
	db.declinedProfessions = db.declinedProfessions or {}
	if not db.declinedProfessions[key] then
		db.declinedProfessions[key] = true
		recompute(self)
	end
	return true
end

-- Undoes Decline. Returns false when the key is invalid or SavedVariables are not loaded yet.
function Professions:Restore(key)
	local db = ns.char
	if not validKey(key) or not db then
		return false
	end
	if db.declinedProfessions and db.declinedProfessions[key] then
		db.declinedProfessions[key] = nil
		recompute(self)
	end
	return true
end

ns.Events:RegisterMessage("PLAYER_PROFESSIONS_CHANGED", function()
	recompute(Professions)
end)

-- Track merging (GUIDE-FORMAT "Track merging") ------------------------------------------------------------------
-- The route is the guide's steps without track steps. A track step goes into a gap of the route: gap g is after the
-- route's g-th step (0: before the first). Each track step's anchor is searched from the gap of the track's previous
-- step on, so a track keeps its order; steps sharing a gap keep plan order, then track order.

-- Anchors that place a step after their route step; the others place it before theirs.
local AFTER_ANCHOR = { hub = true }

local TARGET_DIRECTIVES = { ["goto"] = true, path = true }
local POINT_LISTS = { "points", "waypoints", "path" }

local function addError(guide, source, line, message)
	guide.errors[#guide.errors + 1] = { source = source, line = line or 0, message = message }
end

-- The uiMapID of the first point in parsed directive arguments: { map = id, ... }, a list of points, a table holding
-- one under points/waypoints/path, or a positional { map, x, y }.
local function pointMap(args, depth)
	if type(args) ~= "table" or depth > 3 then
		return nil
	end
	local map = tonumber(args.map or args.mapID or args.uiMapID)
	if map then
		return map
	end
	for _, field in ipairs(POINT_LISTS) do
		if type(args[field]) == "table" then
			return pointMap(args[field], depth + 1)
		end
	end
	if type(args[1]) == "table" then
		return pointMap(args[1], depth + 1)
	end
	return tonumber(args[1])
end

-- The map of a route step's first .goto/.path target: read from its arguments, else from its directive's targets().
local function stepMap(step)
	for _, directive in ipairs(type(step.directives) == "table" and step.directives or {}) do
		if TARGET_DIRECTIVES[directive.name] then
			local map = pointMap(directive.args, 0)
			local def = directive.def
			if not map and type(def) == "table" and type(def.targets) == "function" then
				local ok, targets = pcall(def.targets, directive.args, ns.Context, {})
				if ok and type(targets) == "table" and type(targets[1]) == "table" then
					map = tonumber(targets[1].map)
				end
			end
			return map
		end
	end
end

-- Whether a map is the zone or below it in the map tree (a capital city's map is a sibling of its zone, not below it).
local function inZone(merge, map, zone)
	if map == zone then
		return true
	end
	local ancestors = merge.ancestors[map]
	if not ancestors then
		ancestors = {}
		for _, info in ipairs(ns.Util.MapChain(map)) do
			ancestors[info.id] = true
		end
		merge.ancestors[map] = ancestors
	end
	return ancestors[zone] == true
end

local function minLevel(levels)
	if type(levels) == "table" then
		return tonumber(levels[1])
	end
	return tonumber(levels)
end

-- Where each chapter's route steps start, in route order: { { index = routeIndex, min = minimumLevel }, ... }.
local function chapterStarts(guide, route)
	local starts, seen = {}, {}
	for i, step in ipairs(route) do
		local chapter = step.chapter
		if chapter ~= nil and not seen[chapter] then
			seen[chapter] = true
			local info = guide.chapters[chapter]
			starts[#starts + 1] = { index = i, min = info and minLevel(info.levels) }
		end
	end
	return starts
end

-- The gap for an anchor, searching from the gap of the track's previous step (cursor), or nil:
-- @hub: after the first route step marked with that hub, from the cursor's route step on (the same visit as the
-- track's previous step, or a later one); @level: before the first step of the first chapter starting at or after
-- the cursor whose minimum level is at least N; @zone: before the first route step after the cursor whose first
-- .goto/.path target is in that map or below it.
local function findGap(merge, anchor, cursor)
	local route, kind = merge.route, anchor.kind
	if kind == "hub" then
		local hub = anchor.value
		if hub == nil then
			return nil
		end
		for i = math.max(cursor, 1), #route do
			if route[i].hub == hub then
				return i
			end
		end
	elseif kind == "level" then
		local level = tonumber(anchor.value)
		if not level then
			return nil
		end
		for _, start in ipairs(merge.starts) do
			if start.index - 1 >= cursor and start.min and start.min >= level then
				return start.index - 1
			end
		end
	elseif kind == "zone" then
		local zone = tonumber(anchor.value)
		if not zone then
			return nil
		end
		for i = cursor + 1, #route do
			local map = stepMap(route[i])
			if map and inZone(merge, map, zone) then
				return i - 1
			end
		end
	end
end

local function missMessage(anchor)
	if type(anchor) ~= "table" or anchor.kind == nil then
		return L["Track step without an anchor"]
	elseif anchor.kind ~= "hub" and anchor.kind ~= "level" and anchor.kind ~= "zone" then
		return string.format(L["Unknown anchor @%s"], tostring(anchor.kind))
	end
	return string.format(L["No route step matches @%s %s"], anchor.kind, tostring(anchor.value))
end

local function isDungeon(guide, chapter)
	local info = chapter ~= nil and guide.chapters[chapter]
	return type(info) == "table" and info.dungeon == true
end

-- The chapter of the track steps in a gap. Inside a chapter: that chapter. Between two chapters: never a dungeon
-- chapter when the other one is not (a dungeon's Skip must not skip profession steps), else the earlier chapter when
-- a step in the gap is anchored after its route step (@hub), else the later one (@level, @zone).
local function gapChapter(merge, gap, steps)
	local before, after = merge.route[gap], merge.route[gap + 1]
	if not before or not after then
		local neighbour = before or after
		return neighbour and neighbour.chapter
	end
	if before.chapter == after.chapter then
		return before.chapter
	end
	local guide = merge.guide
	local beforeDungeon, afterDungeon = isDungeon(guide, before.chapter), isDungeon(guide, after.chapter)
	if beforeDungeon ~= afterDungeon then
		return beforeDungeon and after.chapter or before.chapter
	end
	for _, step in ipairs(steps) do
		if AFTER_ANCHOR[step.anchor.kind] then
			return before.chapter
		end
	end
	return after.chapter
end

-- The plan's keys in merge order: primaries, then secondaries, each in plan order.
local function planKeys(plan)
	local keys, seen = {}, {}
	if type(plan) ~= "table" then
		return keys
	end
	for _, field in ipairs({ "primary", "secondary" }) do
		for _, key in ipairs(type(plan[field]) == "table" and plan[field] or {}) do
			if validKey(key) and not seen[key] then
				seen[key] = true
				keys[#keys + 1] = key
			end
		end
	end
	return keys
end

-- ParseTrack's options: the caller's, with the plan being merged and (by default) ns.Player for the gates.
local function trackOptions(guide, plan, opts)
	local copy = {}
	if type(opts) == "table" then
		for field, value in pairs(opts) do
			copy[field] = value
		end
	end
	copy.plan = plan
	copy.player = copy.player or ns.Player
	copy.guideId = copy.guideId or guide.id
	return copy
end

-- The gated steps of one track, via ns.Parser:ParseTrack (its errors go into the guide's), or nil.
local function trackSteps(self, merge, key, plan, opts)
	local guide, source = merge.guide, TRACK_SOURCE .. key
	local text = self.tracks[key]
	if not text then
		addError(guide, source, 0, string.format(L["No track is registered for profession %s"], key))
		return nil
	end
	local parser = ns.Parser
	if not (parser and parser.ParseTrack) then
		addError(guide, source, 0, L["No parser is loaded for profession tracks"])
		return nil
	end
	local ok, steps, errors = ns.SafeCall(parser.ParseTrack, parser, key, text, trackOptions(guide, plan, opts))
	if not ok then
		addError(guide, source, 0, string.format(L["Track %s could not be parsed"], key))
		return nil
	end
	for _, entry in ipairs(type(errors) == "table" and errors or {}) do
		guide.errors[#guide.errors + 1] = entry
	end
	return type(steps) == "table" and steps or nil
end

local function mergeTrack(self, merge, key, plan, opts)
	local steps = trackSteps(self, merge, key, plan, opts)
	local source, cursor = TRACK_SOURCE .. key, 0
	for n, step in ipairs(steps or {}) do
		step.track = step.track or key
		step.source = step.source or source
		step.id = step.id or string.format("%s:%s", step.source, tostring(step.line or n))
		local gap = type(step.anchor) == "table" and findGap(merge, step.anchor, cursor)
		if gap then
			local list = merge.gaps[gap] or {}
			list[#list + 1] = step
			merge.gaps[gap] = list
			cursor = gap
		else
			addError(merge.guide, step.source, step.line, missMessage(step.anchor))
		end
	end
end

-- Renumbers step.index and rebuilds guide.byId; a track step whose id is taken is reported (route ids are the
-- parser's to check).
local function renumber(guide, steps)
	local byId = {}
	for i, step in ipairs(steps) do
		step.index = i
		if step.id ~= nil then
			if byId[step.id] == nil then
				byId[step.id] = step
			elseif step.track then
				addError(guide, step.source, step.line, string.format(L["Duplicate step id %s"], tostring(step.id)))
			end
		end
	end
	guide.steps, guide.byId = steps, byId
end

-- chapter.first/last from the steps' chapters; a chapter left without steps keeps an empty range in its place (or
-- none, if it had none).
local function updateChapterRanges(guide)
	local first, last = {}, {}
	for i, step in ipairs(guide.steps) do
		local chapter = step.chapter
		if chapter ~= nil then
			first[chapter] = first[chapter] or i
			last[chapter] = i
		end
	end
	local nextIndex = 1
	for index, chapter in ipairs(guide.chapters) do
		if first[index] then
			chapter.first, chapter.last = first[index], last[index]
			nextIndex = last[index] + 1
		elseif chapter.first ~= nil or chapter.last ~= nil then
			chapter.first, chapter.last = nextIndex, nextIndex - 1
		end
	end
end

-- Inserts the plan's tracks into a parsed guide: each plan profession's gated track steps (ns.Parser:ParseTrack with
-- opts plus the plan), at their anchors. Track steps keep their own ids (track:<key>:<n>), so a plan change never
-- moves progress on the route. Earlier track steps are replaced, so merging again with another plan is fine.
-- Re-numbers step.index, rebuilds guide.byId and the chapter ranges, appends errors, sets guide.plan. Returns guide.
function Professions:Merge(guide, plan, opts)
	if type(guide) ~= "table" then
		return guide
	end
	guide.errors = type(guide.errors) == "table" and guide.errors or {}
	guide.chapters = type(guide.chapters) == "table" and guide.chapters or {}
	local route = {}
	for _, step in ipairs(type(guide.steps) == "table" and guide.steps or {}) do
		if not step.track then
			route[#route + 1] = step
		end
	end
	local merge = { guide = guide, route = route, starts = chapterStarts(guide, route), ancestors = {}, gaps = {} }
	for _, key in ipairs(planKeys(plan)) do
		mergeTrack(self, merge, key, plan, opts)
	end

	local merged = {}
	local function place(gap)
		local list = merge.gaps[gap]
		if list then
			local chapter = gapChapter(merge, gap, list)
			for _, step in ipairs(list) do
				step.chapter = chapter
				merged[#merged + 1] = step
			end
		end
	end
	place(0)
	for i, step in ipairs(route) do
		merged[#merged + 1] = step
		place(i)
	end
	renumber(guide, merged)
	updateChapterRanges(guide)
	guide.plan = plan
	return guide
end
