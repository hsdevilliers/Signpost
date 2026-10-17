-- Engine/Parser.lua: guide text (docs/GUIDE-FORMAT.md) -> the guide table of docs/ENGINE.md.
-- ParseGuide resolves #include through ns.Chapters, applies the parse-time gates for one player and profession plan,
-- builds chapters and steps with stable ids, lets ns.Directives parse every directive's arguments and finally has
-- ns.Professions merge the plan's tracks. ParseTrack does the same for a profession track. Guide text never makes the
-- parser throw: each problem becomes { source, line, message } in the errors list and the offending line (or step) is
-- skipped. Line numbers count from the first line of a source's text; 0 means the source as a whole.
local ADDON_NAME, ns = ...

local Parser = {}
ns.Parser = Parser

local L = ns.L

local byte, find, format, gmatch, lower, match, sub =
	string.byte, string.find, string.format, string.gmatch, string.lower, string.match, string.sub
local concat = table.concat

local BYTE_HASH, BYTE_DOT, BYTE_BANG, BYTE_AT = byte("#"), byte("."), byte("!"), byte("@")

-- Gates are resolved here, at parse time: class, race and faction against the player's tokens, prof against the
-- profession plan's keys; hc is reserved for Hardcore and never passes yet.
local GATES = { class = true, race = true, faction = true, prof = true, hc = true }

-- Step modifiers, handled here: never looked up in ns.Directives and never part of step.directives.
local STICKY, OPTIONAL, HUB = "sticky", "optional", "hub"

-- Headers that only a guide's own text may hold, with the kind of value they take. Headers() reads only these.
local GUIDE_HEADERS = {
	professions = "keys",
	guide = "text",
	author = "text",
	version = "text",
	class = "list",
	race = "list",
	faction = "text",
}
local STRUCTURE_HEADERS = { include = true, chapter = true, skipquest = true, track = true }

local CHAPTER_ID = "^[a-z0-9%-]+$"

-- Text helpers --------------------------------------------------------------------------------------------------------

local function trim(text)
	return match(text, "^%s*(.*%S)") or ""
end

local function excerpt(text)
	if #text > 40 then
		return sub(text, 1, 37) .. "..."
	end
	return text
end

local function addError(errors, source, line, message, ...)
	if select("#", ...) > 0 then
		message = format(message, ...)
	end
	errors[#errors + 1] = { source = source, line = line, message = message }
end

-- Iterates a text's statements: the line number and the line without its comment and surrounding whitespace. Blank
-- and comment-only lines are skipped. A comment starts at "--" at the start of a line or right after whitespace.
local function statements(text)
	local pos, line, length = 1, 0, #text
	return function()
		while pos <= length do
			local stop = find(text, "\n", pos, true)
			local raw
			if stop then
				raw = sub(text, pos, stop - 1)
				pos = stop + 1
			else
				raw = sub(text, pos)
				pos = length + 1
			end
			line = line + 1
			if sub(raw, 1, 2) ~= "--" then
				local comment = find(raw, "%s%-%-")
				if comment then
					raw = sub(raw, 1, comment - 1)
				end
				local statement = match(raw, "^%s*(.*%S)")
				if statement then
					return line, statement
				end
			end
		end
	end
end

-- Header values -------------------------------------------------------------------------------------------------------

-- A guide header's value: its text, or a comma-separated list (items trimmed; "keys" must also be single words).
-- Returns nil and a message when it is malformed.
local function headerValue(name, rest)
	local kind = GUIDE_HEADERS[name]
	if rest == "" then
		return nil, format(L["#%s needs a value"], name)
	end
	if kind == "text" then
		return rest
	end
	local items = {}
	for item in gmatch(rest .. ",", "([^,]*),") do
		item = trim(item)
		if item == "" or (kind == "keys" and find(item, "%s")) then
			return nil, format(L["#%s: malformed list '%s'"], name, excerpt(rest))
		end
		items[#items + 1] = item
	end
	return items
end

-- Gates ---------------------------------------------------------------------------------------------------------------

-- A gate and its list: comma-separated without spaces, "!" negates an item; items compare case-insensitively.
local function parseGate(name, list)
	if name == "hc" then
		if list ~= "" then
			return nil, L[".hc takes no list"]
		end
		return { name = name }
	end
	if list == "" then
		return nil, format(L[".%s needs a list"], name)
	end
	if find(list, "%s") then
		return nil, format(L[".%s: a list is comma-separated without spaces"], name)
	end
	local plain, negated = {}, {}
	for item in gmatch(list .. ",", "([^,]*),") do
		local into = plain
		if byte(item, 1) == BYTE_BANG then
			into, item = negated, sub(item, 2)
		end
		if item == "" or find(item, "!", 1, true) then
			return nil, format(L[".%s: malformed list '%s'"], name, excerpt(list))
		end
		into[#into + 1] = lower(item)
	end
	return { name = name, plain = plain, negated = negated }
end

-- Removes the gates at the end of `text` (" .class a,!b", " .hc") and appends them to `gates` in line order.
-- Returns the rest of the text, or nil and a message for a malformed gate.
local function takeGates(text, gates)
	local found
	while true do
		local rest, name, list = match(text, "^(.-)%s+%.(%a+)%s+(%S+)$")
		if not (rest and GATES[name]) then
			rest, name, list = match(text, "^(.-)%s+%.hc$"), "hc", ""
		end
		if not rest then
			break
		end
		local gate, message = parseGate(name, list)
		if not gate then
			return nil, message
		end
		found = found or {}
		found[#found + 1] = gate
		text = rest
	end
	if found then
		for i = #found, 1, -1 do
			gates[#gates + 1] = found[i]
		end
	end
	return text
end

-- A gate left inside the arguments: not at the end of the line, or without its list.
local function misplacedGate(text)
	for name in gmatch(text, "%s%.(%a+)") do
		if GATES[name] then
			return name
		end
	end
end

-- Splits what follows a directive's name into its argument string, its ">>" text and its trailing gates, which may
-- stand right before the ">>" or at the very end of the line. Returns nil and a message when something is malformed.
local function splitLine(rest)
	local head, text = rest, nil
	local split = find(rest, ">>", 1, true)
	if split then
		head, text = sub(rest, 1, split - 1), sub(rest, split + 2)
	end
	-- Each part is trimmed and given one leading space, so a gate at its very start or end is found as well.
	local gates = {}
	local message
	head, message = takeGates(" " .. trim(head), gates)
	if not head then
		return nil, message
	end
	if text then
		text, message = takeGates(" " .. trim(text), gates)
		if not text then
			return nil, message
		end
		text = trim(text)
		if text == "" then
			return nil, L["nothing after >>"]
		end
	end
	local misplaced = misplacedGate(head)
	if misplaced then
		return nil, format(L["misplaced or malformed gate .%s"], misplaced)
	end
	return trim(head), text, gates
end

local function gateMatches(state, name, item)
	if name == "prof" then
		return state.planKeys[item] == true
	end
	return state.tokens[name] == item
end

-- Every gate must pass: a plain item must match (when the list has any) and no negated item may.
local function gatesPass(state, gates)
	for i = 1, #gates do
		local gate = gates[i]
		local name = gate.name
		if name == "hc" then
			return false
		end
		local negated, plain = gate.negated, gate.plain
		for j = 1, #negated do
			if gateMatches(state, name, negated[j]) then
				return false
			end
		end
		if #plain > 0 then
			local matched = false
			for j = 1, #plain do
				if gateMatches(state, name, plain[j]) then
					matched = true
					break
				end
			end
			if not matched then
				return false
			end
		end
	end
	return true
end

-- Parse state ---------------------------------------------------------------------------------------------------------

local function token(value)
	return type(value) == "string" and lower(value) or false
end

local function addKeys(set, keys)
	if type(keys) == "table" then
		for _, key in ipairs(keys) do
			if type(key) == "string" then
				set[lower(key)] = true
			end
		end
	end
end

local function newState(opts, guideId)
	local player = opts.player
	if type(player) ~= "table" then
		player = type(ns.Player) == "table" and ns.Player or {}
	end
	local planKeys, plan = {}, opts.plan
	if type(plan) == "table" then
		addKeys(planKeys, plan.primary)
		addKeys(planKeys, plan.secondary)
	end
	return {
		guideId = guideId,
		player = player,
		tokens = { class = token(player.classFile), race = token(player.raceFile), faction = token(player.faction) },
		planKeys = planKeys,
		errors = {},
		steps = {},
		chapters = {},
		chapterCounts = {},
		skipQuests = {},
		headers = { professions = {} },
		headerLines = {},
		included = {},
		stack = {},
		onStack = {},
	}
end

-- Steps ---------------------------------------------------------------------------------------------------------------

local function directiveDef(name)
	local registry = ns.Directives
	if type(registry) ~= "table" or type(registry.Get) ~= "function" then
		return nil
	end
	local ok, def = pcall(registry.Get, registry, name)
	if ok and type(def) == "table" then
		return def
	end
end

-- A directive record; its arguments come from the registered def's parse(argString, ctx).
local function buildDirective(state, source, record)
	local name, line = record.name, record.line
	local def = directiveDef(name)
	if not def then
		addError(state.errors, source, line, L["unknown directive .%s"], name)
		return nil
	end
	local args = record.args
	if type(def.parse) == "function" then
		local ok, parsed, message = pcall(def.parse, args, { source = source, line = line, guideId = state.guideId })
		if not ok or parsed == nil then
			local reason = not ok and parsed or message or L["invalid arguments"]
			addError(state.errors, source, line, L[".%s: %s"], name, tostring(reason))
			return nil
		end
		args = parsed
	end
	return { name = name, args = args, text = record.text, line = line, def = def }
end

-- Ends the step being read: gates it for this player, has its directive lines parsed and appends it, or drops it.
-- Gated-away lines never reach ns.Directives, so a step for another class cannot report that class's directives.
local function closeStep(state)
	local pending = state.step
	if not pending then
		return
	end
	state.step = nil
	if pending.dropped then
		return
	end
	if pending.content == 0 then
		addError(state.errors, pending.source, pending.line, L["step has no directives"])
		return
	end
	if pending.failed or not gatesPass(state, pending.gates) then
		return
	end
	local directives, sticky, optional, hub = {}, {}, {}, nil
	local records = pending.lines
	for i = 1, #records do
		local record = records[i]
		if gatesPass(state, record.gates) then
			local kind = record.kind
			if kind == OPTIONAL then
				optional[record.value] = true
			elseif kind == HUB then
				if hub and hub ~= record.value then
					addError(state.errors, pending.source, record.line, L["a step has one .hub (%s already)"], hub)
				else
					hub = record.value
				end
			else
				local directive = buildDirective(state, pending.source, record)
				if directive and kind == STICKY then
					directive.sticky = true
					sticky[#sticky + 1] = directive
				elseif directive then
					directives[#directives + 1] = directive
				end
			end
		end
	end
	if #directives == 0 and #sticky == 0 then
		return
	end
	local steps = state.steps
	steps[#steps + 1] = {
		id = pending.source .. ":" .. pending.n,
		index = #steps + 1,
		chapter = pending.chapter,
		source = pending.source,
		line = pending.line,
		directives = directives,
		sticky = sticky,
		optional = optional,
		hub = hub,
		track = pending.track,
		anchor = pending.anchor,
	}
end

-- The k-th chapter started in a source gets the id `source` (k = 1) or `source#k`.
local function openChapter(state, source, line, name, levels, dungeon, implicit)
	local count = (state.chapterCounts[source] or 0) + 1
	state.chapterCounts[source] = count
	local chapters = state.chapters
	chapters[#chapters + 1] = {
		id = count == 1 and source or (source .. "#" .. count),
		name = name,
		levels = levels,
		dungeon = dungeon,
		source = source,
		line = line,
		implicit = implicit,
	}
	state.chapter = #chapters
end

-- Steps before any #chapter form the guide's implicit chapter: named after the guide (set once the name is known),
-- levels from the Register table.
local function openImplicitChapter(state)
	local def, levels = state.def, nil
	local given = type(def) == "table" and def.levels
	local low = type(given) == "table" and given[1]
	local high = type(given) == "table" and (given[2] or low)
	if type(low) == "number" and type(high) == "number" and high >= low then
		levels = { low, high }
	else
		addError(state.errors, state.guideId, 0, L["guide levels must be { min, max }"])
	end
	openChapter(state, state.guideId, nil, nil, levels, false, true)
end

local function parseAnchor(rest)
	local kind, value, extra = match(rest, "^@(%a+)%s+(%S+)%s*(.*)$")
	if not kind then
		return nil, L["a track step needs one anchor: @hub <name>, @level <N> or @zone <uiMapID>"]
	end
	if extra ~= "" then
		return nil, L["a track step has exactly one anchor"]
	end
	if kind == "hub" then
		return { kind = kind, value = value }
	end
	if kind == "level" or kind == "zone" then
		local number = match(value, "^%d+$") and tonumber(value)
		if not number or number < 1 then
			return nil, format(L["@%s needs a positive whole number"], kind)
		end
		return { kind = kind, value = number }
	end
	return nil, format(L["unknown anchor @%s"], kind)
end

local function scanStep(state, frame, line, rest)
	closeStep(state)
	frame.steps = frame.steps + 1
	local pending = { source = frame.source, n = frame.steps, line = line, gates = {}, lines = {}, content = 0 }
	if frame.kind == "track" then
		local anchor, message = parseAnchor(rest)
		if anchor then
			pending.anchor, pending.track = anchor, state.trackKey
		else
			pending.dropped = true
			addError(state.errors, frame.source, line, message)
		end
	else
		if not state.chapter then
			openImplicitChapter(state)
		end
		pending.chapter = state.chapter
		if rest ~= "" and byte(rest, 1) == BYTE_AT then
			addError(state.errors, frame.source, line, L["anchors (@hub, @level, @zone) belong to profession tracks"])
		elseif rest ~= "" then
			addError(state.errors, frame.source, line, L["unexpected text after step: %s"], excerpt(rest))
		end
	end
	state.step = pending
end

-- Reads a directive line into the step being read. Its arguments are parsed when the step closes, after gating.
local function scanDirective(state, line, statement)
	local errors, source, pending = state.errors, state.source, state.step
	if not pending then
		addError(errors, source, line, L["directive outside a step"])
		return
	end
	local name, rest = match(statement, "^%.([%a][%w_]*)(.*)$")
	local args, text, gates, message
	if not name then
		message = L["malformed directive line"]
	elseif rest ~= "" and not find(rest, "^%s") then
		message = format(L["expected a space after .%s"], name)
	elseif name == STICKY and GATES[match(rest, "^%s*%.(%a+)") or ""] then
		message = format(L[".%s cannot be sticky"], match(rest, "^%s*%.(%a+)"))
	else
		args, text, gates = splitLine(rest)
		if not args then
			message = text
		end
	end

	-- A gate line gates the whole step; a malformed one drops the step rather than show it to everyone.
	if name and GATES[name] then
		if not message and text then
			message = format(L[">> text is not allowed on .%s"], name)
		end
		if not message then
			local gate
			gate, message = parseGate(name, args)
			if gate then
				local list = pending.gates
				list[#list + 1] = gate
				for i = 1, #gates do
					list[#list + 1] = gates[i]
				end
			end
		end
		if message then
			pending.failed = true
			addError(errors, source, line, message)
		end
		return
	end

	local modifier = name == OPTIONAL or name == HUB
	if not modifier then
		pending.content = pending.content + 1
	end
	local kind, value = "directive", nil
	if not message and modifier then
		kind = name
		if text then
			message = format(L[">> text is not allowed on .%s"], name)
		elseif name == OPTIONAL then
			value = match(args, "^%d+$") and tonumber(args)
			if not value or value < 1 then
				message = L[".optional takes one quest ID"]
			end
		elseif match(args, "^%S+$") then
			value = args
		else
			message = L[".hub takes one name"]
		end
	elseif not message and name == STICKY then
		kind = STICKY
		local inner, innerRest = match(args, "^%.([%a][%w_]*)(.*)$")
		if not inner then
			message = L[".sticky needs a directive: .sticky .<name> <arguments>"]
		elseif inner == STICKY or inner == OPTIONAL or inner == HUB then
			message = format(L[".%s cannot be sticky"], inner)
		elseif innerRest ~= "" and not find(innerRest, "^%s") then
			message = format(L["expected a space after .%s"], inner)
		else
			name, args = inner, trim(innerRest)
		end
	end
	if message then
		addError(errors, source, line, message)
		return
	end
	local records = pending.lines
	records[#records + 1] =
		{ kind = kind, name = name, args = args, value = value, text = text, gates = gates, line = line }
end

-- Headers -------------------------------------------------------------------------------------------------------------

local processSource

local function chapterText(id)
	local chapters = ns.Chapters
	if type(chapters) ~= "table" or type(chapters.Get) ~= "function" then
		return nil
	end
	local ok, text = pcall(chapters.Get, chapters, id)
	if ok then
		return text
	end
end

local function scanInclude(state, source, line, id)
	local errors = state.errors
	if not match(id, CHAPTER_ID) then
		addError(errors, source, line, L["#include needs one chapter id (lowercase letters, digits and -)"])
		return
	end
	if state.onStack[id] then
		local stack, chain = state.stack, {}
		for i = 1, #stack do
			if stack[i] == id or #chain > 0 then
				chain[#chain + 1] = stack[i]
			end
		end
		chain[#chain + 1] = id
		addError(errors, source, line, L["include cycle: %s"], concat(chain, " -> "))
		return
	end
	local earlier = state.included[id]
	if earlier then
		addError(
			errors,
			source,
			line,
			L["chapter %s is already included (%s line %d)"],
			id,
			earlier.source,
			earlier.line
		)
		return
	end
	local text = chapterText(id)
	if type(text) ~= "string" then
		addError(errors, source, line, L["unknown chapter %s"], id)
		return
	end
	state.included[id] = { source = source, line = line }
	processSource(state, id, text, "chapter")
end

local function scanChapter(state, source, line, rest)
	local levels, name = match(rest, "^(%S+)%s+(.+)$")
	local dungeon = false
	if name then
		local base = match(name, "^(.-)%s+#dungeon$")
		if base then
			name, dungeon = base, true
		elseif name == "#dungeon" then
			name = nil
		end
	end
	if not name then
		addError(state.errors, source, line, L["expected #chapter <N or N-M> <name> [#dungeon]"])
		return
	end
	local low, high = match(levels, "^(%d+)%-(%d+)$")
	if not low then
		low = match(levels, "^%d+$")
		high = low
	end
	low, high = tonumber(low), tonumber(high)
	if not low or low < 1 or high < low then
		addError(state.errors, source, line, L["chapter levels must be N or N-M with 1 <= N <= M"])
		return
	end
	openChapter(state, source, line, name, { low, high }, dungeon)
end

local function scanSkipQuest(state, source, line, rest)
	local id, reason = match(rest, "^(%d+)%s*>>%s*(.*)$")
	id = id and tonumber(id)
	if not id or id < 1 or reason == "" then
		addError(state.errors, source, line, L["expected #skipquest <questID> >> <reason>"])
		return
	end
	if state.skipQuests[id] == nil then
		state.skipQuests[id] = reason
	end
end

local function scanHeader(state, frame, line, statement)
	local errors, source, kind = state.errors, frame.source, frame.kind
	local name, rest = match(statement, "^#(%S*)%s*(.*)$")
	if not (GUIDE_HEADERS[name] or STRUCTURE_HEADERS[name]) then
		addError(errors, source, line, L["unknown header #%s"], name)
	elseif name == "track" then
		if kind ~= "track" then
			addError(errors, source, line, L["#track is only allowed in a profession track"])
		elseif frame.count ~= 1 then
			addError(errors, source, line, L["#track must be the first statement of a track"])
		elseif rest ~= tostring(state.trackKey) then
			addError(
				errors,
				source,
				line,
				L["#track %s does not match the track key %s"],
				rest,
				tostring(state.trackKey)
			)
		end
	elseif kind == "track" then
		addError(errors, source, line, L["#%s is not allowed in a profession track"], name)
	elseif name == "include" then
		closeStep(state)
		scanInclude(state, source, line, rest)
	elseif name == "chapter" then
		closeStep(state)
		scanChapter(state, source, line, rest)
	elseif name == "skipquest" then
		scanSkipQuest(state, source, line, rest)
	elseif kind ~= "guide" then
		addError(errors, source, line, L["#%s is only allowed in a guide's own text"], name)
	else
		local value, message = headerValue(name, rest)
		if value == nil then
			addError(errors, source, line, message)
		elseif state.headerLines[name] then
			addError(errors, source, line, L["duplicate #%s (first on line %d)"], name, state.headerLines[name])
		else
			state.headers[name] = value
			state.headerLines[name] = line
		end
	end
end

-- Reads one source's text (the guide's own, a chapter's or a track's); #include recurses into the chapter's text.
-- A step never spans sources, and #chapter ends the step being read.
processSource = function(state, source, text, kind)
	local stack, outer = state.stack, state.source
	stack[#stack + 1] = source
	state.onStack[source] = true
	state.source = source
	local frame = { source = source, kind = kind, steps = 0, count = 0 }
	for line, statement in statements(text) do
		frame.count = frame.count + 1
		if kind == "track" and frame.count == 1 and not (statement == "#track" or find(statement, "^#track%s")) then
			addError(state.errors, source, line, L["a track starts with #track %s"], tostring(state.trackKey))
		end
		local first = byte(statement, 1)
		if first == BYTE_DOT then
			scanDirective(state, line, statement)
		elseif first == BYTE_HASH then
			scanHeader(state, frame, line, statement)
		else
			local rest = statement == "step" and "" or match(statement, "^step%s+(.*)$")
			if rest then
				scanStep(state, frame, line, rest)
			else
				addError(state.errors, source, line, L["not a step, directive or header: %s"], excerpt(statement))
			end
		end
	end
	closeStep(state)
	if kind == "track" and frame.count == 0 then
		addError(state.errors, source, 0, L["a track starts with #track %s"], tostring(state.trackKey))
	end
	state.source = outer
	stack[#stack] = nil
	state.onStack[source] = nil
end

-- Runs fn; an error there is a bug, not guide text: it goes to the client's error handler and into the errors list.
local function protect(errors, source, template, fn)
	local ok, message = xpcall(fn, function(err)
		local handler = geterrorhandler and geterrorhandler()
		if type(handler) == "function" then
			pcall(handler, err)
		end
		return tostring(err)
	end)
	if not ok then
		addError(errors, source, 0, template, message)
	end
	return ok
end

-- API -----------------------------------------------------------------------------------------------------------------

-- The guide's own header statements (#professions, #guide, #author, #version, #class, #race, #faction), read without
-- a full parse so the profession plan can be detected first. The first valid statement of each kind wins, as in
-- ParseGuide (which also reports the malformed and duplicate ones).
function Parser:Headers(def)
	local headers = { professions = {} }
	local text = type(def) == "table" and def.text
	if type(text) ~= "string" then
		return headers
	end
	local seen = {}
	for _, statement in statements(text) do
		if byte(statement, 1) == BYTE_HASH then
			local name, rest = match(statement, "^#(%S*)%s*(.*)$")
			if GUIDE_HEADERS[name] and not seen[name] then
				local value = headerValue(name, rest)
				if value ~= nil then
					headers[name] = value
					seen[name] = true
				end
			end
		end
	end
	return headers
end

-- Brings a guide's derived fields up to date after its step list changed (e.g. a profession merge): step.index,
-- guide.byId, every step's chapter (a step without one joins its neighbours' chapter: the previous step's for an
-- @hub anchor, else the next step's) and each chapter's first/last; chapters left without steps are dropped.
-- Idempotent; ParseGuide runs it after parsing and again after ns.Professions:Merge.
function Parser:Reindex(guide)
	local steps, chapters, errors = guide.steps, guide.chapters, guide.errors
	local count = #steps
	local following, nextChapter = {}, nil
	for i = count, 1, -1 do
		local step = steps[i]
		if chapters[step.chapter] == nil then
			step.chapter = nil
		else
			nextChapter = step.chapter
		end
		following[i] = nextChapter
	end
	local previous
	for i = 1, count do
		local step = steps[i]
		if step.chapter == nil then
			if type(step.anchor) == "table" and step.anchor.kind == "hub" then
				step.chapter = previous or following[i]
			else
				step.chapter = following[i] or previous
			end
		end
		previous = step.chapter
	end
	local used, kept, renumber = {}, {}, {}
	for i = 1, count do
		local chapter = steps[i].chapter
		if chapter then
			used[chapter] = true
		end
	end
	for i = 1, #chapters do
		if used[i] then
			local chapter = chapters[i]
			kept[#kept + 1] = chapter
			renumber[i] = #kept
			chapter.first, chapter.last = nil, nil
		end
	end
	local byId = {}
	for i = 1, count do
		local step = steps[i]
		step.index = i
		step.chapter = step.chapter and renumber[step.chapter]
		local chapter = step.chapter and kept[step.chapter]
		if chapter then
			chapter.first = chapter.first or i
			chapter.last = i
		end
		local id = step.id
		if id ~= nil and byId[id] then
			local message = format(L["duplicate step id %s"], tostring(id))
			local known = false
			for j = 1, #errors do
				known = known or errors[j].message == message
			end
			if not known then
				addError(errors, step.source or guide.id, step.line or 0, message)
			end
		elseif id ~= nil then
			byId[id] = step
		end
	end
	guide.chapters, guide.byId = kept, byId
	return guide
end

-- The guide table of docs/ENGINE.md for `def` (what ns.Guides:Register received), gated for opts.player (default
-- ns.Player) and opts.plan; with a plan, ns.Professions:Merge(guide, plan, opts) then merges the plan's tracks.
function Parser:ParseGuide(def, opts)
	opts = type(opts) == "table" and opts or {}
	local isTable = type(def) == "table"
	local id = isTable and def.id or nil
	local source = (type(id) == "string" and id ~= "") and id or "?"
	local guide = {
		id = id,
		name = source,
		def = def,
		headers = { professions = {} },
		chapters = {},
		steps = {},
		byId = {},
		skipQuests = {},
		errors = {},
	}
	local errors, state = guide.errors, nil
	protect(errors, source, L["parser failure: %s"], function()
		if source == "?" then
			addError(errors, source, 0, L["guide has no id"])
		end
		state = newState(opts, source)
		state.def, state.errors, state.steps, state.chapters = def, errors, guide.steps, guide.chapters
		state.skipQuests, state.headers = guide.skipQuests, guide.headers
		local text = isTable and def.text
		if type(text) == "string" then
			processSource(state, source, text, "guide")
		else
			addError(errors, source, 0, L["guide has no text"])
		end
	end)
	local name = isTable and def.name
	guide.name = (type(name) == "string" and name ~= "" and name) or guide.headers.guide or source
	for _, chapter in ipairs(guide.chapters) do
		if chapter.implicit then
			chapter.name = guide.name
		end
	end
	protect(errors, source, L["parser failure: %s"], function()
		self:Reindex(guide)
	end)
	if opts.plan ~= nil then
		local professions = ns.Professions
		if type(professions) == "table" and type(professions.Merge) == "function" then
			local mergeOpts = {}
			for key, value in pairs(opts) do
				mergeOpts[key] = value
			end
			mergeOpts.player = state and state.player or opts.player
			mergeOpts.guideId = mergeOpts.guideId or guide.id
			protect(errors, source, L["profession tracks not merged: %s"], function()
				professions:Merge(guide, opts.plan, mergeOpts)
			end)
			protect(errors, source, L["parser failure: %s"], function()
				self:Reindex(guide)
			end)
		else
			addError(errors, source, 0, L["profession tracks not merged: %s"], L["ns.Professions is not loaded"])
		end
	end
	return guide
end

-- A profession track's steps (ids `track:<key>:<n>`, each with track = key and its anchor; no chapter yet) and errors,
-- gated for opts.player (default ns.Player) and opts.plan. opts.guideId, when given, reaches the directive parsers.
function Parser:ParseTrack(key, text, opts)
	opts = type(opts) == "table" and opts or {}
	local source = "track:" .. tostring(key)
	local steps, errors = {}, {}
	protect(errors, source, L["parser failure: %s"], function()
		local state = newState(opts, opts.guideId)
		state.errors, state.steps, state.trackKey = errors, steps, key
		if type(text) == "string" then
			processSource(state, source, text, "track")
		else
			addError(errors, source, 0, L["track %s has no text"], tostring(key))
		end
	end)
	return steps, errors
end
