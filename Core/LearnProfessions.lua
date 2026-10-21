-- Learn, the profession part (PLAN §6 step 7): what trainers teach and charge, and the recipes the trade skill window
-- lists, recorded into SignpostDB.learned as the player plays. It follows the rules of Core/Learn.lua: nothing is
-- recorded without the player's yes on a release build, never a player or a pet, and only game data (IDs, the names of
-- spells, recipes and items, what a trainer charges, the level and skill a service needs, and the skill value a
-- recipe's difficulty was read at). Nothing is sent anywhere; no chat, no player name, no gold of the player is read.
--   trainers[npcID].services = { { id = spellID, item = itemID, n = name, r = rank text, cost = copper,
--       lvl = required level, line = skill line ID, need = required skill, known = true }, ... }
--       what the trainer's window listed: each service once (by spell ID, else by name and rank), the latest reading of
--       it. A window filtered to some of the services never takes the others away. At most
--       Learn.LIMITS.servicesPerTrainer. Class trainers are recorded the same way (they name no skill line).
--   recipes[spellID] = { n = name, line = skill line ID, item = the item it makes, reagents = { [itemID] = count },
--       obs = { { skill = n, cat = "optimal" | "medium" | "easy" | "trivial" }, ... }, t }
--       what the trade skill window listed. obs is how hard the recipe was at that skill value (orange, yellow, green,
--       grey): only the lowest and highest skill seen in each category are kept, which is all that the colour
--       thresholds can be read from (tools/signpost_tools/learned.py, skill_bounds).
-- SignpostDB.recorder = { trainer = {...}, tradeSkill = {...} }: which client functions answered at the last window and
-- how much of each service or recipe they filled in (counts and function names only), so what the real client does is
-- readable from SavedVariables without asking the player for more than opening the windows.
-- Every client function used here is unverified on Forever (docs/FOREVER-API-NOTES.md, "Open probes"): each goes
-- through Util.Call, and both the modern shape (C_TrainerUI, C_TradeSkillUI) and the Classic shape (global functions)
-- are read, whichever answers.
local ADDON_NAME, ns = ...
local Util = ns.Util
local call = Util.Call
local Learn = ns.Learn

local Professions = { report = {} }
Learn.Professions = Professions

local Plain = Learn.Plain
local plainNumber, plainID, plainString = Plain.number, Plain.id, Plain.string

Learn.LIMITS.servicesPerTrainer = 150
Learn.LIMITS.recipes = 2000
Learn.LIMITS.reagentsPerRecipe = 12

local MAX_SCAN = 500 -- trainer services and Classic-shape trade skill entries read per window
local MAX_RECIPES = 1000 -- recipes read per trade skill window
local MAX_SKILL = 1000 -- no profession skill is above this
local MAX_COPPER = 2 ^ 31
local MAX_TEXT = 100 -- bytes: a spell, recipe or rank name is shorter
local SCAN_DELAY = 0.5 -- seconds a trade skill window is left alone before it is read (it fires updates as it loads)
local UPDATE_SECONDS = 1 -- trainer updates closer together than this are not read again once a window has been read

-- Values --------------------------------------------------------------------------------------------------------------

local function plainCount(value, max)
	value = plainNumber(value)
	if value and value >= 0 and value == math.floor(value) and value <= max then
		return value
	end
end

local function plainText(value)
	value = plainString(value)
	if value and #value <= MAX_TEXT then
		return value
	end
end

local function scanCount(value)
	value = plainNumber(value)
	return value and math.max(0, math.min(math.floor(value), MAX_SCAN)) or 0
end

-- The first of the named fields a table has.
local function pick(tbl, ...)
	for i = 1, select("#", ...) do
		local value = tbl[(select(i, ...))]
		if value ~= nil then
			return value
		end
	end
end

-- The ID in a link of one kind ("spell:2018", "enchant:7766", "item:2589"), else nil.
local function linkID(link, kind)
	link = plainString(link)
	return link and plainID(tonumber(link:match(kind .. ":(%d+)")))
end

-- Skill lines ---------------------------------------------------------------------------------------------------------
-- A trainer or a window names its profession; the client's own profession list turns the name into the skill line ID
-- (so no profession is named here), and a child skill line into the profession it belongs to.

local lines

local function professionLines()
	if not lines or (next(lines.byName) == nil and next(lines.parent) == nil) then
		lines = { byName = {}, parent = {} }
		local known = Util.Professions()
		for _, entry in pairs(known.byEnum or {}) do
			local name = type(entry.info) == "table" and plainString(entry.info.professionName)
			if name and plainID(entry.skillLine) then
				lines.byName[name] = entry.skillLine
			end
		end
		for line, info in pairs(known.bySkillLine or {}) do
			local parent = type(info) == "table" and plainID(info.parentProfessionID)
			if parent and parent ~= line then
				lines.parent[line] = parent
			end
		end
	end
	return lines
end

-- A skill line ID, or a profession's name (a trainer service answers with the name), as the profession's own line.
local function lineOf(value, known)
	local line = plainID(value)
	if not line then
		line = known.byName[plainString(value) or ""]
	end
	return line and (known.parent[line] or line) or nil
end

-- Difficulty ----------------------------------------------------------------------------------------------------------

local CATEGORIES = { "optimal", "medium", "easy", "trivial" } -- orange, yellow, green, grey
local CATEGORY_BY_NAME = {
	optimal = "optimal",
	medium = "medium",
	easy = "easy",
	trivial = "trivial",
	orange = "optimal",
	yellow = "medium",
	green = "easy",
	gray = "trivial",
	grey = "trivial",
}
-- Enum.TradeskillRelativeDifficulty on the Mainline API
local CATEGORY_BY_NUMBER = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }

-- "optimal" | "medium" | "easy" | "trivial" for what the client calls a recipe's difficulty (the Classic shape names
-- it, the modern one numbers it), else nil.
-- VERIFY(beta): Enum.TradeskillRelativeDifficulty exists with Optimal, Medium, Easy, Trivial.
local function category(value)
	if type(value) == "string" then
		local name = plainString(value)
		return name and CATEGORY_BY_NAME[name:lower()] or nil
	end
	value = plainNumber(value)
	if value == nil then
		return nil
	end
	local enum = Util.Resolve("Enum.TradeskillRelativeDifficulty")
	if type(enum) == "table" then
		for name, number in pairs(enum) do
			if number == value then
				return type(name) == "string" and CATEGORY_BY_NAME[name:lower()] or nil
			end
		end
		return nil
	end
	return CATEGORY_BY_NUMBER[value]
end

-- The observations of a recipe with one more: one entry per skill value (the newest wins), then only the lowest and
-- the highest skill seen in each category, which is all that the colour thresholds can be read from.
local function mergeObservation(stored, skill, cat)
	local bySkill = {}
	for _, entry in ipairs(type(stored) == "table" and stored or {}) do
		local value = type(entry) == "table" and plainCount(entry.skill, MAX_SKILL)
		if value and value > 0 and CATEGORY_BY_NAME[entry.cat] == entry.cat then
			bySkill[value] = entry.cat
		end
	end
	if skill and cat then
		bySkill[skill] = cat
	end
	local low, high = {}, {}
	for value, name in pairs(bySkill) do
		if low[name] == nil or value < low[name] then
			low[name] = value
		end
		if high[name] == nil or value > high[name] then
			high[name] = value
		end
	end
	local kept, result = {}, {}
	for _, name in ipairs(CATEGORIES) do
		if low[name] then
			kept[low[name]] = true
			kept[high[name]] = true
		end
	end
	for value in pairs(kept) do
		result[#result + 1] = { skill = value, cat = bySkill[value] }
	end
	table.sort(result, function(a, b)
		return a.skill < b.skill
	end)
	return result
end

-- Reports -------------------------------------------------------------------------------------------------------------

local function saveReport(kind, report)
	report.t = time()
	Professions.report[kind] = report
	if ns.db then
		if type(ns.db.recorder) ~= "table" then
			ns.db.recorder = {}
		end
		ns.db.recorder[kind] = report
	end
end

local function tally(report, field)
	report[field] = (report[field] or 0) + 1
end

-- Trainer windows -----------------------------------------------------------------------------------------------------

-- VERIFY(beta): which of C_TrainerUI.<name> and the global <name> exist (the globals do on beta 1.60.1.70450,
-- C_TrainerUI was not probed), what GetTrainerServiceInfo answers (name, rank text, type as in Classic, or one table),
-- and that GetTrainerServiceSkillReq exists (it was not probed).
local TRAINER_FUNCTIONS = {
	count = "GetNumTrainerServices",
	info = "GetTrainerServiceInfo",
	cost = "GetTrainerServiceCost",
	level = "GetTrainerServiceLevelReq",
	skillLine = "GetTrainerServiceSkillLine",
	skillReq = "GetTrainerServiceSkillReq",
	link = "GetTrainerServiceItemLink",
}
local SERVICE_TYPES = { available = true, unavailable = true, used = true, header = true }
-- the report counts how many services each field was read for
local SERVICE_FIELDS = {
	id = "ids",
	n = "names",
	cost = "costs",
	lvl = "levels",
	need = "skills",
	line = "lines",
	known = "known",
}

local function trainerFunctions()
	local fns = {}
	for field, name in pairs(TRAINER_FUNCTIONS) do
		fns[field] = Util.Resolve("C_TrainerUI." .. name) or Util.Resolve(name)
	end
	return fns
end

-- The spell a service teaches: from its link, else from the tooltip data (as Automation/Trainer.lua reads it).
-- VERIFY(beta): GetTrainerServiceItemLink(i) is a spell link and C_TooltipInfo.GetTrainerService(i).id the spell ID.
local function serviceSpell(index, link)
	local id = linkID(link, "spell") or linkID(link, "enchant")
	if id then
		return id
	end
	local getData = Util.Resolve("C_TooltipInfo.GetTrainerService")
	local data = getData and call(getData, index)
	if type(data) == "table" then
		local spellType = Util.Resolve("Enum.TooltipDataType.Spell")
		if spellType == nil or data.type == nil or data.type == spellType then
			return plainID(data.id) or plainID(data.spellID)
		end
	end
end

-- What GetTrainerServiceInfo answered: the Classic shape is name, rank text, type, ...; the modern one may be a table.
local function serviceInfo(info)
	local first = info[1]
	if type(first) == "table" then
		return {
			name = pick(first, "name", "serviceName", "spellName"),
			rank = pick(first, "subText", "subtext", "rank", "serviceSubText"),
			kind = pick(first, "serviceType", "type", "state", "category"),
			spell = pick(first, "spellID", "spellId", "serviceID"),
			cost = pick(first, "cost", "moneyCost", "price"),
			level = pick(first, "requiredLevel", "levelReq", "reqLevel"),
		}
	end
	local result = { name = first }
	for i = 2, 4 do
		local value = plainString(info[i])
		if value and SERVICE_TYPES[value] then
			result.kind = result.kind or value
		elseif value and i == 2 then
			result.rank = value
		end
	end
	return result
end

-- One service of the open trainer window as the pack keeps it, or nil for a header and for a row the client told us
-- nothing about beyond its ID (Core/Learn.lua already keeps the IDs of what a trainer teaches).
local function readService(index, fns, known, report)
	local reading = serviceInfo(Util.Pack(call(fns.info, index)))
	local kind = plainString(reading.kind)
	if kind == "header" then
		return nil
	end
	local service = { n = plainText(reading.name), r = plainText(reading.rank) }
	local link = fns.link and call(fns.link, index)
	service.item = linkID(link, "item")
	service.id = serviceSpell(index, link) or plainID(reading.spell)
	service.cost = plainCount((call(fns.cost, index)), MAX_COPPER) or plainCount(reading.cost, MAX_COPPER)
	local level = plainCount((call(fns.level, index)), 200) or plainCount(reading.level, 200)
	service.lvl = level and level > 0 and level or nil
	local requiredName, requiredRank = call(fns.skillReq, index)
	local need = plainCount(requiredRank, MAX_SKILL)
	service.need = need and need > 0 and need or nil
	service.line = lineOf(call(fns.skillLine, index), known) or lineOf(requiredName, known)
	service.known = kind == "used" or nil
	if not (service.n or service.cost or service.lvl or service.need or service.r) then
		return nil
	end
	tally(report, "services")
	for field, label in pairs(SERVICE_FIELDS) do
		if service[field] ~= nil then
			tally(report, label)
		end
	end
	return service
end

-- A service the module can compare: a table whose spell ID is a number and whose name and rank are text. Anything else
-- in the saved variables (a hand-edited or damaged file) is dropped instead of raising an error at the next window.
local function validService(service)
	return type(service) == "table"
		and (service.id == nil or type(service.id) == "number")
		and (service.n == nil or type(service.n) == "string")
		and (service.r == nil or type(service.r) == "string")
end

local function serviceKey(service)
	if service.id then
		return "s" .. service.id
	end
	return "n:" .. (service.n or "") .. "|" .. (service.r or "")
end

local function serviceOrder(a, b)
	if (a.id or 0) ~= (b.id or 0) then
		return (a.id or 0) < (b.id or 0)
	end
	return serviceKey(a) < serviceKey(b)
end

-- The services stored for a trainer with a fresh reading: each service once, the fresh one where both have it; the
-- stored ones the reading does not show stay (a window filtered to some services does not list the others).
local function mergeServices(stored, fresh, cap)
	local seen, result = {}, {}
	local function add(list)
		for _, service in ipairs(list) do
			local key = validService(service) and serviceKey(service)
			if key and not seen[key] and #result < cap then
				seen[key] = true
				result[#result + 1] = service
			end
		end
	end
	add(fresh)
	add(type(stored) == "table" and stored or {})
	table.sort(result, serviceOrder)
	return result
end

-- The services of the open trainer window, and a report of what the client answered.
local function readTrainer()
	local fns = trainerFunctions()
	local report = { api = Util.Resolve("C_TrainerUI.GetNumTrainerServices") and "C_TrainerUI" or nil }
	local services = {}
	if not (fns.count and fns.info) then
		return services, report
	end
	report.api = report.api or "global"
	local known = professionLines()
	for index = 1, scanCount(call(fns.count)) do
		local service = readService(index, fns, known, report)
		if service then
			services[#services + 1] = service
		end
	end
	return services, report
end

-- TRAINER_SHOW and TRAINER_UPDATE: the services this trainer's window lists, filed with the trainer's record.
function Professions:OnTrainer(force)
	local now = GetTime()
	if not force and self.trainerRead and now - self.trainerRead < UPDATE_SECONDS then
		return
	end
	local who = Learn.Entity("npc")
	if not (who and who.table == "npcs") then
		return
	end
	local services, report = readTrainer()
	saveReport("trainer", report)
	if #services == 0 then
		return
	end
	self.trainerRead = now
	local record = Learn:Record("trainers", who.id)
	record.services = mergeServices(record.services, services, Learn.LIMITS.servicesPerTrainer)
	record.t = time()
end

-- Trade skill windows -------------------------------------------------------------------------------------------------

-- A trade skill window that is not the player's own (another player's, linked in chat, or the guild's) must never be
-- read: its recipes and skill are someone else's.
-- VERIFY(beta): these functions exist; the window of a linked or guild trade skill reports true.
local FOREIGN_WINDOW = {
	"C_TradeSkillUI.IsTradeSkillLinked",
	"C_TradeSkillUI.IsTradeSkillGuild",
	"IsTradeSkillLinked",
	"IsTradeSkillGuild",
}

local function foreignWindow()
	for _, name in ipairs(FOREIGN_WINDOW) do
		local value = call(Util.Resolve(name))
		if value ~= nil and (Util.IsSecret(value) or value) then
			return name
		end
	end
end

-- The profession the window shows: its skill line, and the skill values the client gives for it (child and base
-- profession info of the modern API, the Classic window's own line, the learned professions of Core/Player.lua).
-- VERIFY(beta): GetChildProfessionInfo/GetBaseProfessionInfo answer { professionID, parentProfessionID, skillLevel,
-- maxSkillLevel }; C_TradeSkillUI.GetTradeSkillLine answers the skill line ID first; the global GetTradeSkillLine
-- answers name, rank, max; and the skill values they and GetProfessionInfo give agree.
local function readWindow(known, report)
	local window, skills = {}, {}
	local function infoTable(source, info)
		if type(info) == "table" then
			window.line = window.line or lineOf(info.parentProfessionID, known) or lineOf(info.professionID, known)
			window.max = window.max or plainCount(info.maxSkillLevel, MAX_SKILL)
			skills[source] = plainCount(info.skillLevel, MAX_SKILL)
		end
	end
	infoTable("child", call(Util.Resolve("C_TradeSkillUI.GetChildProfessionInfo")))
	infoTable("base", call(Util.Resolve("C_TradeSkillUI.GetBaseProfessionInfo")))
	-- C_TradeSkillUI.GetTradeSkillLine(): skill line ID, name, rank, max rank, modifier, parent skill line ID
	local lineID, _, lineRank, lineMax, _, parentID = call(Util.Resolve("C_TradeSkillUI.GetTradeSkillLine"))
	if plainID(lineID) then
		window.line = window.line or lineOf(parentID, known) or lineOf(lineID, known)
		window.max = window.max or plainCount(lineMax, MAX_SKILL)
		skills.line = plainCount(lineRank, MAX_SKILL)
	end
	-- the Classic global: name, rank, max rank
	local name, rank, max = call(Util.Resolve("GetTradeSkillLine"))
	if plainString(name) then
		window.line = window.line or lineOf(name, known)
		window.max = window.max or plainCount(max, MAX_SKILL)
		skills.classic = plainCount(rank, MAX_SKILL)
	end
	local learned = window.line and ns.Player and ns.Player.professions and ns.Player.professions[window.line]
	skills.player = type(learned) == "table" and plainCount(learned.rank, MAX_SKILL) or nil
	for _, source in ipairs({ "child", "line", "classic", "player", "base" }) do
		local value = skills[source]
		if value and value > 0 and (window.max == nil or value <= window.max) then
			window.skill, report.skillFrom = value, source
			break
		end
	end
	report.line, report.skill, report.skills = window.line, window.skill, skills
	return window
end

-- Reagents as { [itemID] = count }: an item named twice adds up; at most LIMITS.reagentsPerRecipe items are kept.
local function addReagent(bag, item, quantity)
	if item and quantity and quantity > 0 and (bag.items[item] or bag.count < Learn.LIMITS.reagentsPerRecipe) then
		if not bag.items[item] then
			bag.count = bag.count + 1
		end
		bag.items[item] = (bag.items[item] or 0) + quantity
	end
end

-- The reagents of a modern-shape recipe schematic.
-- VERIFY(beta): GetRecipeSchematic(recipeID, false) answers { outputItemID, reagentSlotSchematics = { { reagentType,
-- reagents = { { itemID } }, quantityRequired } } } and Enum.CraftingReagentType.Basic marks the plain reagents.
local function schematicReagents(schematic)
	local bag = { items = {}, count = 0 }
	local basic = Util.Resolve("Enum.CraftingReagentType.Basic") or 1
	local slots = type(schematic.reagentSlotSchematics) == "table" and schematic.reagentSlotSchematics or {}
	for _, slot in ipairs(slots) do
		if type(slot) == "table" and (slot.reagentType == nil or slot.reagentType == basic) then
			local first = type(slot.reagents) == "table" and slot.reagents[1]
			addReagent(bag, type(first) == "table" and plainID(first.itemID), plainCount(slot.quantityRequired, 1000))
		end
	end
	return next(bag.items) and bag.items or nil
end

-- The recipes of the modern shape: nil when the client has no such functions, else a list (empty while the window
-- loads).
-- VERIFY(beta): C_TradeSkillUI.GetAllRecipeIDs, GetRecipeInfo (name, learned, relativeDifficulty), GetRecipeSchematic.
local function readModern()
	local getIDs = Util.Resolve("C_TradeSkillUI.GetAllRecipeIDs")
	local getInfo = Util.Resolve("C_TradeSkillUI.GetRecipeInfo")
	if not (getIDs and getInfo) then
		return nil
	end
	local getSchematic = Util.Resolve("C_TradeSkillUI.GetRecipeSchematic")
	local ids = call(getIDs)
	local recipes = {}
	for i = 1, type(ids) == "table" and math.min(#ids, MAX_RECIPES) or 0 do
		local id = plainID(ids[i])
		local info = id and call(getInfo, id)
		if type(info) == "table" then
			local recipe = { id = id, n = plainText(info.name), known = info.learned ~= false }
			recipe.cat = recipe.known and category(info.relativeDifficulty) or nil
			local schematic = getSchematic and call(getSchematic, id, false)
			if type(schematic) == "table" then
				recipe.n = recipe.n or plainText(schematic.name)
				recipe.item = plainID(schematic.outputItemID)
				recipe.reagents = schematicReagents(schematic)
			end
			recipes[#recipes + 1] = recipe
		end
	end
	return recipes
end

-- The recipes of the Classic shape: nil when the client has no such functions.
-- VERIFY(beta): GetNumTradeSkills, GetTradeSkillInfo (name, type), GetTradeSkillRecipeLink, GetTradeSkillItemLink,
-- GetTradeSkillNumReagents, GetTradeSkillReagentInfo and GetTradeSkillReagentItemLink.
local function readClassic()
	local getCount = Util.Resolve("GetNumTradeSkills")
	local getInfo = Util.Resolve("GetTradeSkillInfo")
	if not (getCount and getInfo) then
		return nil
	end
	local getRecipeLink = Util.Resolve("GetTradeSkillRecipeLink")
	local getItemLink = Util.Resolve("GetTradeSkillItemLink")
	local getNumReagents = Util.Resolve("GetTradeSkillNumReagents")
	local getReagentInfo = Util.Resolve("GetTradeSkillReagentInfo")
	local getReagentLink = Util.Resolve("GetTradeSkillReagentItemLink")
	local recipes = {}
	for index = 1, math.min(scanCount(call(getCount)), MAX_RECIPES) do
		local name, kind = call(getInfo, index)
		kind = plainString(kind)
		if kind and kind ~= "header" and kind ~= "subheader" then
			local recipeLink = getRecipeLink and call(getRecipeLink, index)
			local id = linkID(recipeLink, "enchant") or linkID(recipeLink, "spell")
			if id then
				local recipe = { id = id, n = plainText(name), known = true, cat = category(kind) }
				recipe.item = linkID(getItemLink and call(getItemLink, index), "item")
				local bag = { items = {}, count = 0 }
				for reagent = 1, getNumReagents and scanCount(call(getNumReagents, index)) or 0 do
					local _, _, quantity = call(getReagentInfo, index, reagent)
					local link = getReagentLink and call(getReagentLink, index, reagent)
					addReagent(bag, linkID(link, "item"), plainCount(quantity, 1000))
				end
				recipe.reagents = next(bag.items) and bag.items or nil
				recipes[#recipes + 1] = recipe
			end
		end
	end
	return recipes
end

-- Files one recipe: what the window said replaces what was stored (the client's word is the latest), the observation
-- of its difficulty at the character's skill is added.
local function writeRecipe(recipe, window)
	local record = Learn:Record("recipes", recipe.id)
	record.n = recipe.n or record.n
	record.line = window.line
	record.item = recipe.item or record.item
	record.reagents = recipe.reagents or record.reagents
	if recipe.cat and window.skill then
		record.obs = mergeObservation(record.obs, window.skill, recipe.cat)
	end
	record.t = time()
end

-- The open trade skill window's recipes, filed under the profession's skill line.
function Professions:CaptureTradeSkill(event)
	if not Learn:Recording() then
		return
	end
	local report = { event = event }
	local skipped = foreignWindow()
	if skipped then
		report.skipped = skipped
		saveReport("tradeSkill", report)
		return
	end
	local window = readWindow(professionLines(), report)
	local recipes = readModern()
	report.api = recipes and "C_TradeSkillUI" or nil
	if not recipes or #recipes == 0 then
		local classic = readClassic()
		if classic and (#classic > 0 or not recipes) then
			recipes, report.api = classic, "global"
		end
	end
	report.recipes = recipes and #recipes or 0
	if not window.line then
		report.skipped = "no skill line"
		saveReport("tradeSkill", report)
		return
	end
	local written = 0
	for _, recipe in ipairs(recipes or {}) do
		if recipe.n or recipe.item or recipe.reagents then
			writeRecipe(recipe, window)
			written = written + 1
			if recipe.item then
				tally(report, "items")
			end
			if recipe.reagents then
				tally(report, "reagents")
			end
			if recipe.cat and window.skill then
				tally(report, "difficulties")
			end
		end
	end
	report.written = written
	saveReport("tradeSkill", report)
end

-- The window fires several updates as it loads and after every craft: one read, a moment after the last of them.
local generation = 0

local function onTradeSkillEvent(event)
	if not Learn:Recording() then
		return
	end
	generation = generation + 1
	local mine = generation
	C_Timer.After(SCAN_DELAY, function()
		if mine == generation then
			ns.SafeCall(Professions.CaptureTradeSkill, Professions, event)
		end
	end)
end

-- Counts for /signpost learned and the contribute window.
function Professions:Counts()
	local services = 0
	for _, record in pairs(Learn:Table("trainers")) do
		if type(record) == "table" and type(record.services) == "table" then
			services = services + #record.services
		end
	end
	return { services = services, recipes = Learn:Count("recipes") }
end

-- Exposed for the specs.
Professions.MergeObservation = mergeObservation
Professions.Category = category

-- Events --------------------------------------------------------------------------------------------------------------

ns.Events:Register("TRAINER_SHOW", function()
	if Learn:Recording() then
		Professions:OnTrainer(true)
	end
end)
ns.Events:Register("TRAINER_UPDATE", function()
	if Learn:Recording() then
		Professions:OnTrainer(false)
	end
end)
-- VERIFY(beta): which of these the client fires for a trade skill window (TRADE_SKILL_LIST_UPDATE is known to register;
-- the others are skipped when the client rejects them).
for _, event in ipairs({
	"TRADE_SKILL_SHOW",
	"TRADE_SKILL_LIST_UPDATE",
	"TRADE_SKILL_DATA_SOURCE_CHANGED",
	"TRADE_SKILL_UPDATE",
}) do
	ns.Events:Register(event, onTradeSkillEvent)
end
