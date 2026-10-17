-- ns.Directives: the directive registry and every core directive of docs/GUIDE-FORMAT.md ("Directives"). Travel
-- directives come from Engine/Travel.lua, class and profession directives from their modules; all register here.
--
-- A def (docs/ENGINE.md) is { parse, isSatisfied, targets, describe, onStart, kind, completable }. describe also gets
-- the directive's state as a third argument. Optional fields Engine/Conditions.lua reads:
--   pin           the target kind of the directive's pins; when the data pack gives it none, the step's first .goto
--                 pin takes this kind instead (a quest giver is pinned at the step's .goto without the pack);
--   progress      fn(args, context, state) -> { line, ... }, shown under the directive's line (objective progress);
--   locationOnly  the line is shown only when the step has no other line (a bare .goto reads "Go to ...");
--   usage         the syntax, for messages.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Directives = { defs = {} }
ns.Directives = Directives

-- Yards (GUIDE-FORMAT's default for .goto).
Directives.DEFAULT_GOTO_RADIUS = 10
-- Pins one directive may take from the data pack (an NPC can have several spawn clusters).
Directives.MAX_PINS = 6
-- A .reward value up to this is a choice index; a larger one is an item ID.
Directives.MAX_REWARD_CHOICE = 10
-- A learned profession can train its next rank once its skill is this close to the rank's maximum (Classic: 50/75,
-- 125/150, 200/225); a profession module may set rankUpWindow. VERIFY(launch): the thresholds on Forever.
Directives.RANK_UP_WINDOW = 25

-- Registry ------------------------------------------------------------------------------------------------------------

-- Registers (or replaces) a directive. Errors on a malformed def: that is a bug in the registering file.
function Directives:Register(name, def)
	if type(name) ~= "string" or not name:match("^%l[%l%d]*$") then
		error("Directives:Register: a directive name is lowercase letters and digits, got " .. tostring(name), 2)
	end
	if type(def) ~= "table" or type(def.parse) ~= "function" then
		error("Directives:Register: ." .. name .. " needs a def table with a parse function", 2)
	end
	def.name = name
	def.kind = def.kind or "misc"
	if def.completable == nil then
		def.completable = def.isSatisfied ~= nil
	end
	self.defs[name] = def
	return def
end

function Directives:Get(name)
	return self.defs[name]
end

function Directives:Names()
	local names = {}
	for name in pairs(self.defs) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

local function trim(text)
	return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

-- Parses one directive's arguments and never raises: an unknown name, a parse failure or an error inside a module's
-- parse function all come back as nil and a message.
function Directives:Parse(name, argString, ctx)
	local def = self.defs[name]
	if not def then
		return nil, string.format(L["unknown directive .%s"], tostring(name))
	end
	local ok, args, message = pcall(def.parse, argString or "", type(ctx) == "table" and ctx or {})
	if not ok then
		return nil, string.format(L[".%s failed to parse: %s"], name, tostring(args))
	end
	if type(args) ~= "table" then
		return nil, message or string.format(L["invalid arguments for .%s"], name)
	end
	return args
end

-- ".accept 787 >> text" -> { name, args, text, line, def } (docs/ENGINE.md's directive), or nil and a message. A
-- trailing ">> text" becomes `text`; gates are the parser's business and must already be stripped.
function Directives:ParseLine(text, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	text = tostring(text or "")
	local override
	local cut = text:find(">>", 1, true)
	if cut then
		override = trim(text:sub(cut + 2))
		text = text:sub(1, cut - 1)
		if override == "" then
			override = nil
		end
	end
	local name, rest = text:match("^%s*%.(%S+)(.*)$")
	if not name then
		return nil, L["expected a directive line such as .accept <questID>"]
	end
	local args, message = self:Parse(name, rest, ctx)
	if not args then
		return nil, message
	end
	return { name = name, args = args, text = override, line = ctx.line, def = self.defs[name] }
end

-- Arguments -----------------------------------------------------------------------------------------------------------

-- "a, b,c" -> { "a", "b", "c" }; "" -> {}.
local function fields(text)
	local list = {}
	text = trim(text)
	if text ~= "" then
		for field in (text .. ","):gmatch("([^,]*),") do
			list[#list + 1] = trim(field)
		end
	end
	return list
end

-- A positive integer written with digits only.
local function wholeNumber(text)
	if type(text) == "string" and text:match("^%d+$") then
		local value = tonumber(text)
		if value and value > 0 then
			return value
		end
	end
end

-- A non-negative decimal number.
local function decimalNumber(text)
	if type(text) == "string" and (text:match("^%d+%.?%d*$") or text:match("^%.%d+$")) then
		return tonumber(text)
	end
end

local function expected(usage)
	return nil, string.format(L["expected %s"], usage)
end

-- "<map>,<x>,<y>" fields -> map, x, y; or nil and a message.
local function mapPoint(mapText, xText, yText)
	local map = wholeNumber(mapText)
	if not map then
		return nil, string.format(L['"%s" is not a map ID'], tostring(mapText))
	end
	local x, y = decimalNumber(xText), decimalNumber(yText)
	if not x or not y or x > 100 or y > 100 then
		return nil, L["x and y are percent of the map, from 0 to 100"]
	end
	return map, x, y
end

-- Profession keys: lowercase letters and digits.
local KEY_PATTERN = "^%l[%l%d]*$"

-- Data pack and learned data ------------------------------------------------------------------------------------------
-- Every read of ns.DB (Data/Schema.lua) and of SignpostDB.learned (Core/Learn.lua) goes through Pack, so a field
-- rename is one edit here. Both may be empty: guides carry their own IDs and coordinates.

local Pack = {}
Directives.Pack = Pack

local function record(tableName, id)
	local db = ns.DB
	local tbl = type(db) == "table" and db[tableName]
	local entry = type(tbl) == "table" and id ~= nil and tbl[id]
	return type(entry) == "table" and entry or nil
end

local function learnedRecord(tableName, id)
	local db = ns.db
	local learned = type(db) == "table" and db.learned
	local tbl = type(learned) == "table" and learned[tableName]
	local entry = type(tbl) == "table" and id ~= nil and tbl[id]
	return type(entry) == "table" and entry or nil
end

-- An ID or a list of IDs -> a new list of IDs.
local function idList(value)
	local list = {}
	if type(value) == "number" then
		list[1] = value
	elseif type(value) == "table" then
		for _, id in ipairs(value) do
			if type(id) == "number" then
				list[#list + 1] = id
			end
		end
	end
	return list
end

-- { uiMapID, x, y } (the pack) or { map = , x = , y = } (learned) -> map, x, y.
local function coordinate(value)
	if type(value) ~= "table" then
		return nil
	end
	local map, x, y = value[1] or value.map, value[2] or value.x, value[3] or value.y
	if type(map) == "number" and type(x) == "number" and type(y) == "number" then
		return map, x, y
	end
end

local function nonEmpty(value)
	if type(value) == "string" and not Util.IsSecret(value) and value ~= "" then
		return value
	end
end

local ENTITY_TABLES = { npc = "npcs", object = "objects" }

-- Positions of an NPC or an object (kind "npc" | "object"): the pack's, else the one learned in game.
function Pack.Positions(kind, id)
	local tableName = ENTITY_TABLES[kind]
	local list = {}
	local entry = record(tableName, id)
	local positions = entry and entry.p
	if type(positions) == "table" then
		if coordinate(positions) then
			positions = { positions }
		end
		for _, value in ipairs(positions) do
			local map, x, y = coordinate(value)
			if map then
				list[#list + 1] = { map = map, x = x, y = y }
			end
		end
	end
	if #list == 0 then
		local map, x, y = coordinate(learnedRecord(tableName, id))
		if map then
			list[1] = { map = map, x = x, y = y }
		end
	end
	return list
end

function Pack.Name(kind, id)
	local tableName = ENTITY_TABLES[kind]
	local entry = record(tableName, id)
	return nonEmpty(entry and entry.n) or nonEmpty((learnedRecord(tableName, id) or {}).n)
end

-- The faction token a record carries (Data/Schema.lua `side`), or nil.
function Pack.Side(kind, id)
	local entry = record(ENTITY_TABLES[kind], id)
	return entry and entry.side
end

function Pack.QuestName(questID)
	local quest = record("quests", questID)
	return nonEmpty(quest and quest.n)
end

-- Who starts (field "s") or ends ("e") a quest: { npcs = { ids }, objects = { ids } }; the learned quest record
-- (`start` / `finish`) fills in when the pack has neither.
local function questEntities(questID, field, learnedField)
	local quest = record("quests", questID)
	local who = quest and quest[field]
	local result = { npcs = {}, objects = {} }
	if type(who) == "table" then
		result.npcs, result.objects = idList(who.npc), idList(who.obj)
	end
	if #result.npcs == 0 and #result.objects == 0 then
		local learned = learnedRecord("quests", questID)
		local seen = learned and learned[learnedField]
		if type(seen) == "table" then
			result.npcs, result.objects = idList(seen.npc), idList(seen.obj)
		end
	end
	return result
end

function Pack.QuestStarters(questID)
	return questEntities(questID, "s", "start")
end

function Pack.QuestEnders(questID)
	return questEntities(questID, "e", "finish")
end

-- The pack's objective `index` of a quest: kind ("kill" | "item" | "object" | "explore") and entity ID.
-- VERIFY(beta): the pack's objective order matches C_QuestLog.GetQuestObjectives (the .complete <questID>,<n> index).
function Pack.QuestObjective(questID, index)
	local quest = record("quests", questID)
	local objectives = quest and quest.o
	local objective = type(objectives) == "table" and objectives[index]
	if type(objective) == "table" then
		return objective.k, objective.id
	end
end

function Pack.QuestObjectiveCount(questID)
	local quest = record("quests", questID)
	return quest and type(quest.o) == "table" and #quest.o or 0
end

function Pack.ItemName(itemID)
	local item = record("items", itemID)
	return nonEmpty(item and item.n)
end

function Pack.ItemVendors(itemID)
	local item = record("items", itemID)
	return idList(item and item.vendors)
end

function Pack.ItemDrops(itemID)
	local item = record("items", itemID)
	return idList(item and item.drops)
end

function Pack.MapName(mapID)
	local map = record("maps", mapID)
	return nonEmpty(map and map.n)
end

function Pack.ProfessionName(skillLine)
	local profession = record("professions", skillLine)
	return nonEmpty(profession and profession.n)
end

function Pack.ProfessionTrainers(skillLine)
	local profession = record("professions", skillLine)
	return idList(profession and profession.trainers)
end

function Pack.ClassTrainers(classFile)
	local class = record("classes", classFile)
	return idList(class and class.trainers)
end

-- Registry lookups (other modules, called at call time) ---------------------------------------------------------------

local function moduleFrom(registry, key)
	if type(registry) ~= "table" or type(registry.Get) ~= "function" or key == nil then
		return nil
	end
	local ok, module = ns.SafeCall(registry.Get, registry, key)
	if ok and type(module) == "table" then
		return module
	end
end

local function classModule()
	return moduleFrom(ns.Classes, ns.Player and ns.Player.classFile)
end

local function professionModule(key)
	return moduleFrom(ns.Professions, key)
end

-- A profession's rank and maximum when the character has learned it; nil, nil otherwise. Third result: its module.
local function professionSkill(key, context)
	local module = professionModule(key)
	local skillLine = module and module.skillLine
	if type(skillLine) ~= "number" then
		return nil, nil, module
	end
	local rank, max = context:Skill(skillLine)
	if type(rank) ~= "number" or rank <= 0 then
		return nil, nil, module
	end
	return rank, type(max) == "number" and max or nil, module
end

-- Display names -------------------------------------------------------------------------------------------------------
-- The data pack first where it is the reference (quests, NPCs), the client first where it knows better (items, spells,
-- maps, professions: localized and always current), then placeholders such as "Quest #787".

local Label = {}
Directives.Label = Label

function Label.Quest(questID)
	return Pack.QuestName(questID)
		or nonEmpty(Util.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, questID))
		or string.format(L["Quest #%d"], questID)
end

-- VERIFY(beta): C_Item.GetItemNameByID exists on Forever (C_Item.GetItemInfo does).
function Label.Item(itemID)
	local item = C_Item or {}
	local name = nonEmpty(Util.Call(item.GetItemNameByID, itemID)) or nonEmpty(Util.Call(item.GetItemInfo, itemID))
	if not name then
		-- not in the client's cache yet: ask for it, so the next description has the name
		Util.Call(item.RequestLoadItemDataByID, itemID)
	end
	return name or Pack.ItemName(itemID) or string.format(L["Item #%d"], itemID)
end

function Label.Spell(spellID)
	local info = Util.Call(C_Spell and C_Spell.GetSpellInfo, spellID)
	local name = type(info) == "table" and nonEmpty(info.name) or nonEmpty(info)
	return name or string.format(L["Spell #%d"], spellID)
end

function Label.Map(mapID)
	local info = Util.Call(C_Map and C_Map.GetMapInfo, mapID)
	return (type(info) == "table" and nonEmpty(info.name)) or Pack.MapName(mapID) or string.format(L["map %d"], mapID)
end

-- A profession's display name from its key: the client, the character's learned list, the pack, else the key itself.
function Label.Profession(key)
	local module = professionModule(key)
	local skillLine = module and module.skillLine
	if type(skillLine) == "number" then
		local info = Util.Call(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
		local learned = ns.Player and type(ns.Player.professions) == "table" and ns.Player.professions[skillLine]
		local name = (type(info) == "table" and nonEmpty(info.professionName))
			or (type(learned) == "table" and nonEmpty(learned.name))
			or Pack.ProfessionName(skillLine)
		if name then
			return name
		end
	end
	return key
end

-- The name of the one NPC or object in `who`, if it is exactly one and its name is known.
local function soleName(who)
	if #who.npcs + #who.objects ~= 1 then
		return nil
	end
	if who.npcs[1] then
		return Pack.Name("npc", who.npcs[1])
	end
	return Pack.Name("object", who.objects[1])
end

-- Pins ----------------------------------------------------------------------------------------------------------------

local function playerMap(context)
	local position = context:Position()
	return type(position) == "table" and position.map or nil
end

local function sideMatches(side)
	local faction = ns.Player and ns.Player.faction
	return side == nil or side == "both" or faction == nil or side == faction
end

-- Pins for the NPCs and objects of `who` (a quest giver, an objective): those on the player's map first, at most
-- MAX_PINS.
local function entityPins(who, kind, context)
	local here, elsewhere = {}, {}
	local map = playerMap(context)
	local function add(entityKind, id)
		for _, position in ipairs(Pack.Positions(entityKind, id)) do
			local pin = { map = position.map, x = position.x, y = position.y, kind = kind }
			pin[entityKind] = id
			local list = position.map == map and here or elsewhere
			list[#list + 1] = pin
		end
	end
	for _, id in ipairs(who.npcs or {}) do
		add("npc", id)
	end
	for _, id in ipairs(who.objects or {}) do
		add("object", id)
	end
	local pins = {}
	for _, list in ipairs({ here, elsewhere }) do
		for _, pin in ipairs(list) do
			if #pins < Directives.MAX_PINS then
				pins[#pins + 1] = pin
			end
		end
	end
	return pins
end

-- Pins for interchangeable NPCs (trainers, vendors): only those on the player's map that serve the player's faction.
local function nearbyNpcPins(npcIDs, kind, context)
	local map = playerMap(context)
	local pins = {}
	if not map then
		return pins
	end
	for _, npcID in ipairs(npcIDs) do
		if sideMatches(Pack.Side("npc", npcID)) then
			for _, position in ipairs(Pack.Positions("npc", npcID)) do
				if position.map == map and #pins < Directives.MAX_PINS then
					pins[#pins + 1] = { map = map, x = position.x, y = position.y, kind = kind, npc = npcID }
				end
			end
		end
	end
	return pins
end

local function appendPins(pins, more)
	for _, pin in ipairs(more) do
		if #pins < Directives.MAX_PINS then
			pins[#pins + 1] = pin
		end
	end
	return pins
end

-- Core directives -----------------------------------------------------------------------------------------------------

local function questParser(usage)
	return function(text)
		local list = fields(text)
		local questID = #list == 1 and wholeNumber(list[1])
		if not questID then
			return expected(usage)
		end
		return { questID = questID }
	end
end

local GOTO_USAGE = ".goto <map>,<x>,<y>[,<radius>]"

Directives:Register("goto", {
	kind = "travel",
	pin = "goto",
	locationOnly = true,
	usage = GOTO_USAGE,
	parse = function(text)
		local list = fields(text)
		if #list ~= 3 and #list ~= 4 then
			return expected(GOTO_USAGE)
		end
		local map, x, y = mapPoint(list[1], list[2], list[3])
		if not map then
			return nil, x -- x holds the message
		end
		local radius
		if list[4] then
			radius = decimalNumber(list[4])
			if not radius or radius <= 0 then
				return nil, L["the radius is a number of yards above 0"]
			end
		end
		return { map = map, x = x, y = y, radius = radius }
	end,
	isSatisfied = function(args, context)
		local yards = context:Distance(args.map, args.x, args.y)
		return type(yards) == "number" and yards <= (args.radius or Directives.DEFAULT_GOTO_RADIUS)
	end,
	targets = function(args)
		local radius = args.radius or Directives.DEFAULT_GOTO_RADIUS
		return { { map = args.map, x = args.x, y = args.y, kind = "goto", radius = radius } }
	end,
	describe = function(args)
		return string.format(L["Go to %s %.1f, %.1f"], Label.Map(args.map), args.x, args.y)
	end,
})

Directives:Register("accept", {
	kind = "quest",
	pin = "accept",
	usage = ".accept <questID>",
	parse = questParser(".accept <questID>"),
	isSatisfied = function(args, context)
		return (context:QuestInLog(args.questID) or context:QuestCompleted(args.questID)) and true or false
	end,
	targets = function(args, context)
		return entityPins(Pack.QuestStarters(args.questID), "accept", context)
	end,
	describe = function(args)
		local giver = soleName(Pack.QuestStarters(args.questID))
		if giver then
			return string.format(L['Accept "%s" from %s'], Label.Quest(args.questID), giver)
		end
		return string.format(L['Accept "%s"'], Label.Quest(args.questID))
	end,
})

Directives:Register("turnin", {
	kind = "quest",
	pin = "turnin",
	usage = ".turnin <questID>",
	parse = questParser(".turnin <questID>"),
	isSatisfied = function(args, context)
		return context:QuestCompleted(args.questID) and true or false
	end,
	targets = function(args, context)
		return entityPins(Pack.QuestEnders(args.questID), "turnin", context)
	end,
	describe = function(args)
		local ender = soleName(Pack.QuestEnders(args.questID))
		if ender then
			return string.format(L['Turn in "%s" to %s'], Label.Quest(args.questID), ender)
		end
		return string.format(L['Turn in "%s"'], Label.Quest(args.questID))
	end,
})

local COMPLETE_USAGE = ".complete <questID>[,<objective>]"

local function objectiveText(objective)
	local text = nonEmpty(objective.text)
	if text then
		return text
	end
	if type(objective.have) == "number" and type(objective.need) == "number" then
		return string.format("%d/%d", objective.have, objective.need)
	end
	return L["objective"]
end

local function objectiveList(context, questID)
	local objectives = context:Objectives(questID)
	return type(objectives) == "table" and objectives or {}
end

-- An objective's area from the pack: kill -> the NPC, object -> the object, item -> the NPCs that drop it.
local function objectivePins(questID, index, context, label)
	local kind, id = Pack.QuestObjective(questID, index)
	local who = { npcs = {}, objects = {} }
	if type(id) == "number" then
		if kind == "kill" then
			who.npcs = { id }
		elseif kind == "object" then
			who.objects = { id }
		elseif kind == "item" then
			who.npcs = Pack.ItemDrops(id)
		end
	end
	local pins = entityPins(who, "objective", context)
	for _, pin in ipairs(pins) do
		pin.label, pin.objective = label, index
	end
	return pins
end

Directives:Register("complete", {
	kind = "quest",
	pin = "objective",
	usage = COMPLETE_USAGE,
	parse = function(text)
		local list = fields(text)
		local questID = (#list == 1 or #list == 2) and wholeNumber(list[1])
		if not questID then
			return expected(COMPLETE_USAGE)
		end
		local objective
		if list[2] then
			objective = wholeNumber(list[2])
			if not objective then
				return nil, L["the objective is its number in the quest log, from 1"]
			end
		end
		return { questID = questID, objective = objective }
	end,
	isSatisfied = function(args, context)
		local questID = args.questID
		if context:QuestCompleted(questID) or context:QuestReady(questID) then
			return true
		end
		if not context:QuestInLog(questID) then
			return false
		end
		local objectives = objectiveList(context, questID)
		if args.objective then
			local objective = objectives[args.objective]
			return type(objective) == "table" and objective.finished and true or false
		end
		if #objectives == 0 then
			return false
		end
		for _, objective in ipairs(objectives) do
			if not (type(objective) == "table" and objective.finished) then
				return false
			end
		end
		return true
	end,
	-- the areas of the objectives still open
	targets = function(args, context)
		local questID = args.questID
		local objectives = objectiveList(context, questID)
		local first, last = 1, math.max(Pack.QuestObjectiveCount(questID), #objectives)
		if args.objective then
			first, last = args.objective, args.objective
		end
		local pins = {}
		for index = first, last do
			local objective = objectives[index]
			if not (type(objective) == "table" and objective.finished) then
				local label = type(objective) == "table" and objectiveText(objective) or nil
				appendPins(pins, objectivePins(questID, index, context, label))
			end
		end
		return pins
	end,
	describe = function(args)
		if args.objective then
			return string.format(L['Complete objective %d of "%s"'], args.objective, Label.Quest(args.questID))
		end
		return string.format(L['Complete "%s"'], Label.Quest(args.questID))
	end,
	-- the quest log's objective lines ("- Mottled Boar slain: 3/10")
	progress = function(args, context)
		local lines = {}
		for index, objective in ipairs(objectiveList(context, args.questID)) do
			if type(objective) == "table" and (not args.objective or args.objective == index) then
				lines[#lines + 1] = "- " .. objectiveText(objective)
			end
		end
		return lines
	end,
})

-- A modifier: the parser lists the quest in step.optional and its directives stop blocking the step.
Directives:Register("optional", {
	kind = "quest",
	usage = ".optional <questID>",
	parse = questParser(".optional <questID>"),
})

local REWARD_USAGE = ".reward <questID>,<choice|itemID>"

-- Read by the turn-in automation; shown so the choice is known when automation is off.
Directives:Register("reward", {
	kind = "quest",
	usage = REWARD_USAGE,
	parse = function(text)
		local list = fields(text)
		local questID, value = #list == 2 and wholeNumber(list[1]), wholeNumber(list[2])
		if not questID or not value then
			return expected(REWARD_USAGE)
		end
		if value <= Directives.MAX_REWARD_CHOICE then
			return { questID = questID, choice = value }
		end
		return { questID = questID, itemID = value }
	end,
	describe = function(args)
		if args.itemID then
			return string.format(L["Choose %s as the reward"], Label.Item(args.itemID))
		end
		return string.format(L["Choose reward %d"], args.choice)
	end,
})

local TRAIN_USAGE = ".train <spellID> | .train class"

-- The spells the class module lists for the player's level and below, sorted; nil without a class module.
-- VERIFY(beta): a lower rank stays known (IsPlayerSpell) once a higher rank is learned; .train class checks each rank.
local function dueClassSpells(context)
	local module = classModule()
	local byLevel = module and module.trainerSpells
	if type(byLevel) ~= "table" then
		return nil
	end
	local level = tonumber(context:Level()) or 0
	local spells, seen = {}, {}
	for spellLevel, list in pairs(byLevel) do
		if type(spellLevel) == "number" and spellLevel <= level and type(list) == "table" then
			for _, spellID in ipairs(list) do
				if type(spellID) == "number" and not seen[spellID] then
					seen[spellID] = true
					spells[#spells + 1] = spellID
				end
			end
		end
	end
	table.sort(spells)
	return spells
end

local function unknownSpellCount(spells, context)
	local count = 0
	for _, spellID in ipairs(spells) do
		if not context:SpellKnown(spellID) then
			count = count + 1
		end
	end
	return count
end

local function guideSkips(questID)
	local progress = ns.Progress
	if type(progress) ~= "table" or type(progress.Guide) ~= "function" then
		return false
	end
	local ok, guide = ns.SafeCall(progress.Guide, progress)
	local skips = ok and type(guide) == "table" and guide.skipQuests
	return type(skips) == "table" and skips[questID] ~= nil
end

local function chainStarted(chain, context)
	for _, questID in ipairs(chain.quests) do
		if context:QuestInLog(questID) or context:QuestCompleted(questID) then
			return true
		end
	end
	return false
end

-- PLAN §3.5's soft check: a class quest chain the trainer offers at the player's level that is neither started nor
-- done (and that the guide does not #skipquest), or nil. Reads the class module's classQuests entries
-- { name, level, quests = { questIDs }, offeredBy = "trainer" | npcID }.
local function offeredClassQuest(context)
	local module = classModule()
	local chains = module and module.classQuests
	if type(chains) ~= "table" then
		return nil
	end
	local level = tonumber(context:Level()) or 0
	for _, chain in ipairs(chains) do
		local quests = type(chain) == "table" and chain.quests
		if
			type(quests) == "table"
			and type(quests[1]) == "number"
			and (chain.offeredBy == nil or chain.offeredBy == "trainer")
			and (tonumber(chain.level) or math.huge) <= level
			and not guideSkips(quests[1])
			and not chainStarted(chain, context)
		then
			return chain
		end
	end
end

Directives:Register("train", {
	kind = "misc",
	pin = "trainer",
	usage = TRAIN_USAGE,
	parse = function(text)
		text = trim(text)
		if text == "class" then
			return { class = true }
		end
		local spellID = wholeNumber(text)
		if not spellID then
			return expected(TRAIN_USAGE)
		end
		return { spellID = spellID }
	end,
	isSatisfied = function(args, context)
		if args.spellID then
			return context:SpellKnown(args.spellID) and true or false
		end
		local spells = dueClassSpells(context)
		return spells ~= nil and unknownSpellCount(spells, context) == 0
	end,
	targets = function(_, context)
		return nearbyNpcPins(Pack.ClassTrainers(ns.Player and ns.Player.classFile), "trainer", context)
	end,
	describe = function(args, context)
		if args.spellID then
			return string.format(L["Train %s"], Label.Spell(args.spellID))
		end
		local spells = dueClassSpells(context)
		local missing = spells and unknownSpellCount(spells, context) or 0
		if missing > 0 then
			return string.format(L["Train your class spells (%d to learn)"], missing)
		end
		return L["Train your class spells"]
	end,
	progress = function(_, context)
		local chain = offeredClassQuest(context)
		if not chain then
			return nil
		end
		local name = nonEmpty(chain.name)
		return { name and string.format(L["Class quest available here: %s"], name) or L["Class quest available here"] }
	end,
})

-- Whether a learned profession has nothing to train right now: it is at its top rank, or its skill is still too far
-- below the maximum for the next rank. Lets a .trainprof step pass for a character that trained it earlier.
local function nothingToTrain(module, rank, max)
	if not max then
		return false
	end
	local ranks = type(module.ranks) == "table" and module.ranks or {}
	local top = ranks[#ranks]
	if type(top) == "number" and max >= top then
		return true
	end
	return rank < max - (tonumber(module.rankUpWindow) or Directives.RANK_UP_WINDOW)
end

-- Satisfied once the profession is learned (when it was not as the step became current) or its maximum skill rose since
-- then (the next rank was trained); also when there is nothing to train.
Directives:Register("trainprof", {
	kind = "profession",
	pin = "trainer",
	usage = ".trainprof <key>",
	parse = function(text)
		text = trim(text)
		if not text:match(KEY_PATTERN) then
			return expected(".trainprof <key>")
		end
		return { key = text }
	end,
	onStart = function(args, context, state)
		if state.started then
			return
		end
		local rank, max = professionSkill(args.key, context)
		state.started, state.learned, state.max = true, rank ~= nil, max
	end,
	isSatisfied = function(args, context, state)
		local rank, max, module = professionSkill(args.key, context)
		if not rank then
			return false
		end
		if type(state) == "table" and state.started then
			if not state.learned then
				return true
			end
			if max and state.max and max > state.max then
				return true
			end
		end
		return nothingToTrain(module, rank, max)
	end,
	targets = function(args, context)
		local module = professionModule(args.key)
		local skillLine = module and module.skillLine
		if type(skillLine) ~= "number" then
			return {}
		end
		return nearbyNpcPins(Pack.ProfessionTrainers(skillLine), "trainer", context)
	end,
	describe = function(args)
		return string.format(L["Train %s"], Label.Profession(args.key))
	end,
})

local SKILL_USAGE = ".skill <key> <N>"

Directives:Register("skill", {
	kind = "profession",
	usage = SKILL_USAGE,
	parse = function(text)
		local key, value = trim(text):match("^(%S+)%s+(%S+)$")
		value = wholeNumber(value)
		if not key or not key:match(KEY_PATTERN) or not value then
			return expected(SKILL_USAGE)
		end
		return { key = key, value = value }
	end,
	isSatisfied = function(args, context)
		local rank = professionSkill(args.key, context)
		return rank ~= nil and rank >= args.value
	end,
	describe = function(args, context)
		local rank = professionSkill(args.key, context)
		if rank then
			return string.format(L["Raise %s to %d (now %d)"], Label.Profession(args.key), args.value, rank)
		end
		return string.format(L["Raise %s to %d"], Label.Profession(args.key), args.value)
	end,
})

-- .craft counting: every player cast of a recipe (UNIT_SPELLCAST_SUCCEEDED) counts into each started .craft state for
-- that spell. Weak keys: a state Progress lets go of stops counting. The count lives in the state table, so it lasts
-- as long as Progress keeps that table.
-- VERIFY(beta): the event fires once per crafted item, with the recipe's spell ID.
local craftWatchers = {}
local castsRegistered = false

local function onSpellcast(_, unit, _, spellID)
	if unit ~= "player" or Util.IsSecret(spellID) or spellID == nil then
		return
	end
	local watchers = craftWatchers[spellID]
	if not watchers then
		return
	end
	local counted = false
	for state in pairs(watchers) do
		state.count = (state.count or 0) + 1
		counted = true
	end
	if counted then
		-- a cast need not change bags or skills, so tell the engine to evaluate
		ns.Events:Fire("CONTEXT_CHANGED", "casts")
	end
end

local function watchCasts(spellID, state)
	if not castsRegistered then
		castsRegistered = ns.Events:Register("UNIT_SPELLCAST_SUCCEEDED", onSpellcast)
	end
	local watchers = craftWatchers[spellID]
	if not watchers then
		watchers = setmetatable({}, { __mode = "k" })
		craftWatchers[spellID] = watchers
	end
	watchers[state] = true
end

local CRAFT_USAGE = ".craft <spellID>,<count>"

Directives:Register("craft", {
	kind = "profession",
	usage = CRAFT_USAGE,
	parse = function(text)
		local list = fields(text)
		local spellID, count = #list == 2 and wholeNumber(list[1]), wholeNumber(list[2])
		if not spellID or not count then
			return expected(CRAFT_USAGE)
		end
		return { spellID = spellID, count = count }
	end,
	onStart = function(args, _, state)
		if not state.started then
			state.started = true
			state.count = state.count or 0
		end
		watchCasts(args.spellID, state)
	end,
	isSatisfied = function(args, _, state)
		return type(state) == "table" and (state.count or 0) >= args.count
	end,
	describe = function(args, _, state)
		local done = type(state) == "table" and state.count or 0
		return string.format(L["Craft %s (%d/%d)"], Label.Spell(args.spellID), math.min(done, args.count), args.count)
	end,
})

local FISH_USAGE = ".fish <map>,<x>,<y>"

-- A pin for a spot to fish; the step's .skill or .collect line says what for.
Directives:Register("fish", {
	kind = "profession",
	pin = "fish",
	locationOnly = true,
	usage = FISH_USAGE,
	parse = function(text)
		local list = fields(text)
		if #list ~= 3 then
			return expected(FISH_USAGE)
		end
		local map, x, y = mapPoint(list[1], list[2], list[3])
		if not map then
			return nil, x -- x holds the message
		end
		return { map = map, x = x, y = y }
	end,
	targets = function(args)
		return { { map = args.map, x = args.x, y = args.y, kind = "fish" } }
	end,
	describe = function(args)
		return string.format(L["Fish at %s %.1f, %.1f"], Label.Map(args.map), args.x, args.y)
	end,
})

local function itemCountParser(usage)
	return function(text)
		local list = fields(text)
		local itemID, count = #list == 2 and wholeNumber(list[1]), wholeNumber(list[2])
		if not itemID or not count then
			return expected(usage)
		end
		return { itemID = itemID, count = count }
	end
end

local function itemsInBags(args, context)
	return tonumber(context:ItemCount(args.itemID)) or 0
end

local function haveEnough(args, context)
	return itemsInBags(args, context) >= args.count
end

local function itemCountLine(format, args, context)
	local have = math.min(itemsInBags(args, context), args.count)
	return string.format(format, Label.Item(args.itemID), have, args.count)
end

Directives:Register("buy", {
	kind = "misc",
	pin = "vendor",
	usage = ".buy <itemID>,<count>",
	parse = itemCountParser(".buy <itemID>,<count>"),
	isSatisfied = haveEnough,
	targets = function(args, context)
		return nearbyNpcPins(Pack.ItemVendors(args.itemID), "vendor", context)
	end,
	describe = function(args, context)
		return itemCountLine(L["Buy %s (%d/%d)"], args, context)
	end,
})

Directives:Register("collect", {
	kind = "misc",
	pin = "gather",
	usage = ".collect <itemID>,<count>",
	parse = itemCountParser(".collect <itemID>,<count>"),
	isSatisfied = haveEnough,
	-- nearby vendors, then the NPCs that drop it
	targets = function(args, context)
		local pins = nearbyNpcPins(Pack.ItemVendors(args.itemID), "vendor", context)
		return appendPins(pins, entityPins({ npcs = Pack.ItemDrops(args.itemID) }, "gather", context))
	end,
	describe = function(args, context)
		return itemCountLine(L["Collect %s (%d/%d)"], args, context)
	end,
})

-- The step frame's quest-item button reads args.itemID.
Directives:Register("use", {
	kind = "quest",
	usage = ".use <itemID>",
	parse = function(text)
		local list = fields(text)
		local itemID = #list == 1 and wholeNumber(list[1])
		if not itemID then
			return expected(".use <itemID>")
		end
		return { itemID = itemID }
	end,
	describe = function(args)
		return string.format(L["Use %s"], Label.Item(args.itemID))
	end,
})

Directives:Register("level", {
	kind = "misc",
	usage = ".level <N>",
	parse = function(text)
		local level = wholeNumber(trim(text))
		if not level then
			return expected(".level <N>")
		end
		return { level = level }
	end,
	isSatisfied = function(args, context)
		return (tonumber(context:Level()) or 0) >= args.level
	end,
	describe = function(args)
		return string.format(L["Reach level %d"], args.level)
	end,
})

local TODO_USAGE = '.todo "<reason>"'

Directives:Register("todo", {
	kind = "misc",
	usage = TODO_USAGE,
	parse = function(text)
		local reason = trim(text)
		reason = trim(reason:match('^"(.*)"$') or reason)
		if reason == "" then
			return expected(TODO_USAGE)
		end
		return { reason = reason }
	end,
	-- never: the step waits for the player's ">" and the lint counts it
	isSatisfied = function()
		return false
	end,
	describe = function(args)
		return string.format(L["To do: %s"], args.reason)
	end,
})

local function textDirective(usage)
	return {
		kind = "misc",
		usage = usage,
		parse = function(text)
			text = trim(text)
			if text == "" then
				return expected(usage)
			end
			return { text = text }
		end,
		describe = function(args)
			return args.text
		end,
	}
end

Directives:Register("note", textDirective(".note <text>"))
Directives:Register("text", textDirective(".text <text>"))

-- Copyable in the journal.
Directives:Register("link", {
	kind = "misc",
	usage = ".link <url>",
	parse = function(text)
		local url = trim(text)
		if url == "" or url:find("%s") then
			return expected(".link <url>")
		end
		return { url = url }
	end,
	describe = function(args)
		return args.url
	end,
})

-- Marks a visit to a town; profession tracks anchor their steps here (GUIDE-FORMAT "Track merging").
Directives:Register("hub", {
	kind = "misc",
	usage = ".hub <name>",
	parse = function(text)
		local name = trim(text)
		if name == "" or name:find("%s") then
			return expected(".hub <name>")
		end
		return { name = name }
	end,
})

local STICKY_USAGE = ".sticky <directive line>"

-- args.directive is the inner directive; every function hands over to it. The parser keeps .sticky lines in
-- step.sticky (unwrapped or not: Engine/Conditions.lua takes both).
Directives:Register("sticky", {
	kind = "misc",
	usage = STICKY_USAGE,
	parse = function(text, ctx)
		if trim(text) == "" then
			return expected(STICKY_USAGE)
		end
		local directive, message = Directives:ParseLine(text, ctx)
		if not directive then
			return nil, message
		end
		if directive.name == "sticky" then
			return nil, L[".sticky cannot hold another .sticky"]
		end
		if not directive.def.completable then
			return nil, string.format(L[".sticky needs a directive that can be satisfied, not .%s"], directive.name)
		end
		return { directive = directive }
	end,
	isSatisfied = function(args, context, state)
		local inner = args.directive
		return inner.def.isSatisfied(inner.args, context, state) and true or false
	end,
	targets = function(args, context, state)
		local inner = args.directive
		return inner.def.targets and inner.def.targets(inner.args, context, state) or {}
	end,
	describe = function(args, context, state)
		local inner = args.directive
		return inner.text or (inner.def.describe and inner.def.describe(inner.args, context, state))
	end,
	onStart = function(args, context, state)
		local inner = args.directive
		if inner.def.onStart then
			inner.def.onStart(inner.args, context, state)
		end
	end,
	progress = function(args, context, state)
		local inner = args.directive
		return inner.def.progress and inner.def.progress(inner.args, context, state)
	end,
})
