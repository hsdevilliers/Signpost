-- ns.Conditions: a step's completion, pins and display lines, computed from its directives' defs
-- (Engine/Directives.lua; docs/GUIDE-FORMAT.md "Directives" has the rules), and whether it is a doing step, which draws
-- no pins ("Step kinds" below).
--
-- Every call into a def runs under ns.SafeCall: a broken directive (a class module's, say) loses only its own result
-- and its error goes to the error log. `states` is ns.Progress:State(step.id): states[i] belongs to step.directives[i]
-- and states.sticky[i] to step.sticky[i]; a missing state table is created on first use. A .sticky directive is found
-- either in step.sticky (wrapped or unwrapped) or, wrapped, among step.directives.
local ADDON_NAME, ns = ...

local Conditions = {}
ns.Conditions = Conditions

-- When several directives share one pin, the strongest kind names it.
-- ("goto" is quoted: it is a keyword to Lua 5.2+ tools such as luacheck and StyLua.)
local KIND_PRIORITY =
	{ turnin = 6, accept = 5, trainer = 4, vendor = 4, objective = 3, gather = 2, fish = 2, ["goto"] = 0 }
-- Without HereBeDragons, a pin within this many percent of a .goto on the same map counts as the same place.
local NEAR_PERCENT = 0.5

-- Directive entries ---------------------------------------------------------------------------------------------------

local function defOf(directive)
	if directive.def then
		return directive.def
	end
	return ns.Directives and ns.Directives:Get(directive.name)
end

local function isCompletable(def)
	if not def then
		return false
	end
	if def.completable ~= nil then
		return def.completable == true
	end
	return def.isSatisfied ~= nil
end

local function isStickyWrapper(directive)
	return directive.name == "sticky" and type(directive.args) == "table" and type(directive.args.directive) == "table"
end

-- The ">> text" override without its marker, or nil.
local function overrideText(directive)
	local text = directive.text
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("^%s*>>", ""):match("^%s*(.-)%s*$")
	if text == "" then
		return nil
	end
	return text
end

local function stateAt(states, index, sticky)
	if type(states) ~= "table" then
		return {}
	end
	local list = states
	if sticky then
		states.sticky = type(states.sticky) == "table" and states.sticky or {}
		list = states.sticky
	end
	if type(list[index]) ~= "table" then
		list[index] = {}
	end
	return list[index]
end

-- Every directive of the step, sticky ones unwrapped and last:
-- { directive, def, index (in its list), state, sticky, text (override) }.
local function entries(step, states)
	local list = {}
	local function add(directive, index, state, sticky)
		if type(directive) ~= "table" then
			return
		end
		local text = overrideText(directive)
		if isStickyWrapper(directive) then
			directive = directive.args.directive
			text = text or overrideText(directive)
			sticky = true
		end
		list[#list + 1] = {
			directive = directive,
			def = defOf(directive),
			index = index,
			state = state,
			sticky = sticky,
			text = text,
		}
	end
	for i, directive in ipairs(type(step.directives) == "table" and step.directives or {}) do
		add(directive, i, stateAt(states, i), false)
	end
	for i, directive in ipairs(type(step.sticky) == "table" and step.sticky or {}) do
		add(directive, i, stateAt(states, i, true), true)
	end
	return list
end

-- fn(...) under ns.SafeCall -> ok (false when fn raised), fn's first result.
local function call(fn, ...)
	if type(fn) ~= "function" then
		return true, nil
	end
	local ok, result = ns.SafeCall(fn, ...)
	return ok, result
end

local function satisfied(entry, context)
	local ok, result = call(entry.def.isSatisfied, entry.directive.args, context, entry.state)
	return ok and result and true or false
end

-- The directive's line: its ">>" override, else its description; ".name" when describe raised.
local function lineOf(entry, context)
	if entry.text then
		return entry.text
	end
	local def = entry.def
	if not def then
		return "." .. tostring(entry.directive.name)
	end
	local ok, line = call(def.describe, entry.directive.args, context, entry.state)
	if not ok then
		return "." .. tostring(entry.directive.name)
	end
	if type(line) == "string" and line ~= "" then
		return line
	end
end

local function questOf(directive)
	local args = directive.args
	return type(args) == "table" and args.questID or nil
end

-- step.optional plus any .optional directive left in step.directives.
local function optionalQuests(step)
	local set = {}
	if type(step.optional) == "table" then
		for questID, on in pairs(step.optional) do
			if on then
				set[questID] = true
			end
		end
	end
	for _, directive in ipairs(type(step.directives) == "table" and step.directives or {}) do
		if type(directive) == "table" and directive.name == "optional" and questOf(directive) then
			set[questOf(directive)] = true
		end
	end
	return set
end

-- Completion ----------------------------------------------------------------------------------------------------------

-- complete, detail. detail[i] is whether step.directives[i] is satisfied (nil for directives that cannot be);
-- detail.manual is true when the step can only be completed by the player's ">".
--
-- Rules (GUIDE-FORMAT): every completable directive must be satisfied; a .goto counts only as the step's only
-- completable directive (otherwise it just places the pin); directives about an .optional quest count only when
-- nothing else does; sticky directives never hold the step up, so a step with nothing but sticky ones is complete at
-- once (its stickies stay active beside later steps); a step with nothing completable (notes, text) waits for ">".
function Conditions:IsComplete(step, context, states)
	local detail = {}
	if type(step) ~= "table" then
		return false, detail
	end
	context = context or ns.Context
	local optional = optionalQuests(step)
	local completable, stickies = 0, 0
	local gotos, counted, optionals = {}, {}, {}
	local list = entries(step, states)
	-- A .todo never completes a step by itself, but beside another completable directive it is only a note: the step
	-- finishes when those are satisfied (a step that is nothing but a .todo still waits for ">").
	local others = 0
	for _, entry in ipairs(list) do
		if not entry.sticky and entry.directive.name ~= "todo" and isCompletable(entry.def) then
			others = others + 1
		end
	end
	for _, entry in ipairs(list) do
		if entry.sticky then
			stickies = stickies + 1
		elseif isCompletable(entry.def) and not (entry.directive.name == "todo" and others > 0) then
			local ok = satisfied(entry, context)
			detail[entry.index] = ok
			completable = completable + 1
			local questID = questOf(entry.directive)
			if questID ~= nil and optional[questID] then
				optionals[#optionals + 1] = ok
			elseif entry.directive.name == "goto" then
				gotos[#gotos + 1] = ok
			else
				counted[#counted + 1] = ok
			end
		end
	end
	if completable == 1 and #gotos == 1 then
		counted = gotos
	end
	local decisive = #counted > 0 and counted or optionals
	if #decisive > 0 then
		for _, ok in ipairs(decisive) do
			if not ok then
				return false, detail
			end
		end
		return true, detail
	end
	if stickies > 0 then
		return true, detail
	end
	detail.manual = true
	return false, detail
end

-- done, detail: whether every sticky directive of the step is satisfied (true for a step without any); detail[i] per
-- sticky directive in order. Progress keeps a passed step's stickies active until this is true.
function Conditions:StickyComplete(step, context, states)
	local detail = {}
	if type(step) ~= "table" then
		return true, detail
	end
	context = context or ns.Context
	local done = true
	for _, entry in ipairs(entries(step, states)) do
		if entry.sticky then
			local ok = isCompletable(entry.def) and satisfied(entry, context)
			detail[#detail + 1] = ok
			done = done and ok
		end
	end
	return done, detail
end

-- Calls every directive's onStart (sticky ones too) with its state table, creating the tables; for ns.Progress when the
-- step becomes current. The core onStart functions keep what they recorded first, so calling this again is harmless.
-- Returns `states` (a new table when nil was passed).
function Conditions:Start(step, context, states)
	states = type(states) == "table" and states or {}
	if type(step) ~= "table" then
		return states
	end
	context = context or ns.Context
	for _, entry in ipairs(entries(step, states)) do
		if entry.def and entry.def.onStart then
			call(entry.def.onStart, entry.directive.args, context, entry.state)
		end
	end
	return states
end

-- The step's icon hint: the kind of its first completable directive other than .goto, else of its first directive.
function Conditions:Kind(step)
	local fallback
	for _, entry in ipairs(type(step) == "table" and entries(step) or {}) do
		local def = entry.def
		if def then
			if not entry.sticky and isCompletable(def) and entry.directive.name ~= "goto" then
				return def.kind or "misc"
			end
			fallback = fallback or def.kind
		end
	end
	return fallback or "misc"
end

-- Step kinds ----------------------------------------------------------------------------------------------------------
-- A step's kind is inferred from its directives (docs/GUIDE-FORMAT.md "Step kinds"); the engine acts on one of them.
-- A *doing step* has a `.complete` and no place directive: it is about doing quests, and the quest log already marks
-- their objectives on the map and the minimap. The guide's markers steer the player to a place instead (where to pick
-- up, where to hand in, travel), so a doing step draws none: its `.complete` and its `.goto` produce no pins. The
-- `.goto` stays in the data (the authoring tools read it as the step's position) and, as in every step that has other
-- lines, shows no line: the step lists its quests, and the player opens the map to see where the quest log marks them.
--
-- A place directive is any directive but `.goto` and `.complete` that sends the player somewhere: a travel directive
-- (def.kind "travel": .path, .zone, .fp, .fly, .boat, .zeppelin, .hs, .home) or one whose def pins something other
-- than quest objectives (def.pin: .accept, .turnin, .train, .trainprof, .buy, .collect, .fish, and a class or
-- profession module's directive by the same test). The rest is not positional: .use, .skill, .craft, .level, .todo,
-- .note, .text, .link, .hub, .reward, .optional. Only the step's own directives decide: a .sticky directive is ongoing
-- beside later steps and not what the step is for.

local function isPlace(entry)
	local def, name = entry.def, entry.directive.name
	if not def or name == "goto" or name == "complete" then
		return false
	end
	return def.kind == "travel" or (def.pin ~= nil and def.pin ~= "objective")
end

-- Whether the entries of a step (entries()) make it a doing step.
local function isDoing(list)
	local complete = false
	for _, entry in ipairs(list) do
		if not entry.sticky then
			if entry.directive.name == "complete" then
				complete = true
			elseif isPlace(entry) then
				return false
			end
		end
	end
	return complete
end

-- Whether the step is a doing step: it has a `.complete` and no place directive (see above). Targets gives it no pins.
function Conditions:IsDoingStep(step)
	return type(step) == "table" and isDoing(entries(step))
end

-- Pins ----------------------------------------------------------------------------------------------------------------

local function priority(kind)
	return KIND_PRIORITY[kind] or 1
end

local function joinLabels(a, b)
	if not a then
		return b
	end
	if not b or ("\n" .. a .. "\n"):find("\n" .. b .. "\n", 1, true) then
		return a
	end
	return a .. "\n" .. b
end

local function addQuest(pin, questID)
	if questID == nil then
		return
	end
	pin.quests = pin.quests or {}
	for _, known in ipairs(pin.quests) do
		if known == questID then
			return
		end
	end
	pin.quests[#pin.quests + 1] = questID
end

-- Folds `from` into `into`: the stronger kind (with its quest and entity) names the pin, labels and quests add up. A
-- .goto pin's generated "Go to ..." label gives way to the first real one.
local function fold(into, from)
	if priority(from.kind) > priority(into.kind) then
		into.kind = from.kind
		into.questID = from.questID or into.questID
		into.npc, into.object = from.npc or into.npc, from.object or into.object
	end
	if into._generatedLabel then
		into.label, into._generatedLabel = from.label or into.label, nil
	else
		into.label = joinLabels(into.label, from.label)
	end
	for _, questID in ipairs(from.quests or {}) do
		addQuest(into, questID)
	end
end

local function normalize(raw, entry, def, label)
	if type(raw) ~= "table" or type(raw.map) ~= "number" or type(raw.x) ~= "number" or type(raw.y) ~= "number" then
		return nil
	end
	local pin = {}
	for key, value in pairs(raw) do
		pin[key] = value
	end
	pin.kind = pin.kind or def.pin or "goto"
	pin.label = pin.label or label
	if pin.questID == nil then
		pin.questID = questOf(entry.directive)
	end
	if pin.questID ~= nil and not pin.quests then
		pin.quests = { pin.questID }
	end
	if entry.sticky then
		pin.sticky = true
	end
	return pin
end

-- One pin per NPC or object per spot: a turn-in and an accept at the same quest giver share a pin.
local function mergeSameEntity(pins)
	local out, seen = {}, {}
	for _, pin in ipairs(pins) do
		local key
		if pin.npc ~= nil or pin.object ~= nil then
			key = table.concat({
				tostring(pin.npc),
				tostring(pin.object),
				tostring(pin.map),
				tostring(pin.x),
				tostring(pin.y),
				tostring(pin.sticky),
			}, ":")
		end
		local into = key and seen[key]
		if into then
			fold(into, pin)
		else
			out[#out + 1] = pin
			if key then
				seen[key] = pin
			end
		end
	end
	return out
end

local function hereBeDragons()
	local stub = LibStub
	if stub == nil then
		return nil
	end
	local ok, lib = pcall(stub, "HereBeDragons-2.0", true)
	if ok and type(lib) == "table" then
		return lib
	end
end

-- Whether pin b lies within `radius` yards of pin a (HereBeDragons), or, when that distance is unknown, at about the
-- same spot of the same map.
local function near(a, b, radius)
	local lib = hereBeDragons()
	if lib and type(lib.GetZoneDistance) == "function" then
		local ok, yards = pcall(lib.GetZoneDistance, lib, a.map, a.x / 100, a.y / 100, b.map, b.x / 100, b.y / 100)
		if ok and type(yards) == "number" then
			return yards <= radius
		end
	end
	return a.map == b.map and math.abs(a.x - b.x) <= NEAR_PERCENT and math.abs(a.y - b.y) <= NEAR_PERCENT
end

-- A .goto pin takes over the first NPC or object pin within its radius: one pin for "go here and talk to them".
-- Other pins (waypoints, docks, spots) keep their own.
local function absorbNear(gotoPin, pins, gotoSet)
	local radius = tonumber(gotoPin.radius) or ns.Directives.DEFAULT_GOTO_RADIUS
	for _, pin in ipairs(pins) do
		if
			not gotoSet[pin]
			and not pin._absorbed
			and not pin.sticky
			and (pin.npc ~= nil or pin.object ~= nil)
			and near(gotoPin, pin, radius)
		then
			fold(gotoPin, pin)
			pin._absorbed = true
			return
		end
	end
end

-- The step's pins, docs/ENGINE.md `target`s: its directives' targets (sticky ones marked sticky = true), without those
-- of satisfied directives (a .goto always keeps its pin). A directive with a `pin` kind that has no position (no data
-- pack, say) marks the step's first .goto pin with its kind and label instead; an NPC or object pin within a .goto's
-- radius merges into the .goto's; pins for the same NPC or object at the same spot merge. Every pin with a quest lists
-- its quests in `quests` (several after a merge). A doing step (see "Step kinds") draws none: its `.goto` and
-- `.complete` are not asked for pins at all (no other core directive of such a step has any; a sticky place directive
-- keeps its own).
function Conditions:Targets(step, context, states)
	if type(step) ~= "table" then
		return {}
	end
	context = context or ns.Context
	local pins, gotoPins, gotoSet, claims = {}, {}, {}, {}
	local list = entries(step, states)
	local doing = isDoing(list)
	for _, entry in ipairs(list) do
		local def, directive = entry.def, entry.directive
		local isGoto = directive.name == "goto"
		local quiet = doing and (isGoto or directive.name == "complete")
		if def and not quiet and not (isCompletable(def) and not isGoto and satisfied(entry, context)) then
			local label = lineOf(entry, context)
			local _, produced = call(def.targets, directive.args, context, entry.state)
			local count = 0
			for _, raw in ipairs(type(produced) == "table" and produced or {}) do
				local pin = normalize(raw, entry, def, label)
				if pin then
					count = count + 1
					pins[#pins + 1] = pin
					if isGoto and not entry.sticky then
						pin._generatedLabel = not entry.text or nil
						gotoPins[#gotoPins + 1] = pin
						gotoSet[pin] = true
					end
				end
			end
			if count == 0 and def.pin and not entry.sticky then
				local questID = questOf(directive)
				claims[#claims + 1] = { kind = def.pin, label = label, questID = questID, quests = { questID } }
			end
		end
	end
	pins = mergeSameEntity(pins)
	for _, gotoPin in ipairs(gotoPins) do
		absorbNear(gotoPin, pins, gotoSet)
	end
	if gotoPins[1] then
		for _, claim in ipairs(claims) do
			fold(gotoPins[1], claim)
		end
	end
	local out = {}
	for _, pin in ipairs(pins) do
		if not pin._absorbed then
			pin._generatedLabel = nil
			out[#out + 1] = pin
		end
	end
	return out
end

-- Display -------------------------------------------------------------------------------------------------------------

-- lines, info: the step's display lines and, per line, { directive = index in its list, name = the directive's name,
-- sticky = true|nil, progress = true|nil (extra lines such as the class quest line), done = satisfied (completable
-- directives only) }.
-- Order: the step's own lines, each followed by its progress lines, then the sticky ones. A ">>" override replaces a
-- line's description; a .goto or .fish line without one shows only when the step has no other line (so a doing step,
-- which has its quests, never shows its .goto: the player opens the map and looks where the quest log marks). A
-- `.complete` line names the quest and nothing else (the quest log has the objectives); `done` says whether that quest
-- is complete. `states` is optional (a .craft count shows 0 without it).
function Conditions:Describe(step, context, states)
	local lines, info = {}, {}
	if type(step) ~= "table" then
		return lines, info
	end
	context = context or ns.Context
	local own, sticky, places, seen = {}, {}, {}, {}
	for _, entry in ipairs(entries(step, states)) do
		local def = entry.def
		local into = entry.sticky and sticky or own
		local line = lineOf(entry, context)
		if line then
			local item = {
				text = line,
				meta = { directive = entry.index, name = entry.directive.name, sticky = entry.sticky or nil },
			}
			if isCompletable(def) then
				item.meta.done = satisfied(entry, context)
			end
			if def and def.locationOnly and not entry.text and not entry.sticky then
				places[#places + 1] = item
			else
				into[#into + 1] = item
			end
		end
		if def and def.progress then
			local _, extra = call(def.progress, entry.directive.args, context, entry.state)
			for _, text in ipairs(type(extra) == "table" and extra or {}) do
				if type(text) == "string" and text ~= "" and not seen[text] then
					seen[text] = true
					into[#into + 1] = {
						text = text,
						meta = { directive = entry.index, sticky = entry.sticky or nil, progress = true },
					}
				end
			end
		end
	end
	if #own == 0 then
		own = places
	end
	for _, list in ipairs({ own, sticky }) do
		for _, item in ipairs(list) do
			lines[#lines + 1] = item.text
			info[#info + 1] = item.meta
		end
	end
	return lines, info
end
