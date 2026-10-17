-- ns.Guides, ns.Chapters and ns.Classes (docs/ENGINE.md): the registries that guide, chapter and class files register
-- into, the check of a guide against the player, and best-match guide selection (PLAN §3.5, §3.7). Class, race and
-- faction tokens come only from the registered tables and from ns.Player; nothing here names one.
local ADDON_NAME, ns = ...
local L = ns.L

local WILDCARD = "*"

-- Registration problems (a missing id, a duplicate) are kept on the registry and recorded in the error log, never
-- thrown: one broken file must not stop the others from registering.
local function report(registry, message)
	registry.problems[#registry.problems + 1] = message
	if ns.Errors then
		ns.Errors:Record(ADDON_NAME .. ": " .. message)
	end
end

-- A module's own directives ({ [name] = directiveDef }) go into the directive registry for every character, so the
-- parser knows them whichever gates a line carries. Directives.lua loads before any class module registers.
local function registerDirectives(registry, owner, directives)
	if directives == nil then
		return
	end
	local target = ns.Directives
	if type(directives) ~= "table" or not (target and target.Register) then
		report(registry, string.format(L["%s: its directives could not be registered"], owner))
		return
	end
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

-- Guides ------------------------------------------------------------------------------------------------------------

local Guides = { defs = {}, problems = {} }
ns.Guides = Guides

-- The fields a guide restricts its players by, the ns.Player field each one is matched against, and the name of the
-- requirement in Compatible's third result.
local CHECKS = {
	{ field = "faction", player = "faction", kind = "faction" },
	{ field = "races", player = "raceFile", kind = "race" },
	{ field = "classes", player = "classFile", kind = "class" },
}

-- A restriction as a set of tokens plus the tokens in the guide's order, or nil when it admits everyone: no value,
-- "*", an empty list or a list holding "*".
local function tokens(value)
	if value == nil or value == WILDCARD then
		return nil
	end
	if type(value) == "string" then
		return { [value] = true }, { value }
	end
	if type(value) ~= "table" then
		return {}, { tostring(value) }
	end
	local set, list = {}, {}
	for _, token in ipairs(value) do
		if token == WILDCARD then
			return nil
		end
		if not set[token] then
			set[token] = true
			list[#list + 1] = tostring(token)
		end
	end
	if #list == 0 then
		return nil
	end
	return set, list
end

local function validRestriction(value)
	if value == nil or type(value) == "string" then
		return true
	end
	if type(value) ~= "table" then
		return false
	end
	for _, token in ipairs(value) do
		if type(token) ~= "string" then
			return false
		end
	end
	return true
end

-- Registers a guide (docs/GUIDE-FORMAT.md "Files"). The table is kept as given: it is the guide's `def`. A second
-- guide with the same id replaces the first (and is reported). Returns true, or false and the problem.
function Guides:Register(def)
	local problem
	if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
		problem = L["A guide was registered without an id"]
	elseif type(def.text) ~= "string" then
		problem = string.format(L["Guide %s has no text"], def.id)
	else
		for _, check in ipairs(CHECKS) do
			if not validRestriction(def[check.field]) then
				problem = string.format(L['Guide %s: %s must be a token, a list of tokens or "*"'], def.id, check.field)
				break
			end
		end
	end
	if problem then
		report(self, problem)
		return false, problem
	end
	if self.defs[def.id] and self.defs[def.id] ~= def then
		report(self, string.format(L["Guide %s was registered twice; the later one is used"], def.id))
	end
	self.defs[def.id] = def
	return true
end

function Guides:Get(id)
	if id == nil then
		return nil
	end
	return self.defs[id]
end

local function displayName(def)
	return type(def.name) == "string" and def.name or def.id
end

-- Every registered guide, sorted by name, then id.
function Guides:All()
	local list = {}
	for _, def in pairs(self.defs) do
		list[#list + 1] = def
	end
	table.sort(list, function(a, b)
		local nameA, nameB = displayName(a), displayName(b)
		if nameA ~= nameB then
			return nameA < nameB
		end
		return a.id < b.id
	end)
	return list
end

local function requirement(kind, list)
	local names = table.concat(list, ", ")
	if kind == "faction" then
		return string.format(L["Requires faction: %s"], names)
	elseif kind == "race" then
		return string.format(L["Requires race: %s"], names)
	end
	return string.format(L["Requires class: %s"], names)
end

-- Whether a guide fits the player (default ns.Player): faction, then race, then class, "*" matching everyone.
-- Returns true, or false, the first unmet requirement as display text and its kind ("faction", "race", "class",
-- or "invalid" for something that is not a guide).
function Guides:Compatible(def, player)
	if type(def) ~= "table" then
		return false, L["Not a guide"], "invalid"
	end
	player = player or ns.Player or {}
	for _, check in ipairs(CHECKS) do
		local set, list = tokens(def[check.field])
		if set and not set[player[check.player]] then
			return false, requirement(check.kind, list), check.kind
		end
	end
	return true
end

-- How specific a guide is, most specific first: race and class (PLAN §3.5 "exact race + class"), class only, race
-- only, faction only, nothing.
local function tier(def)
	local races, classes = tokens(def.races) ~= nil, tokens(def.classes) ~= nil
	if races and classes then
		return 1
	elseif classes then
		return 2
	elseif races then
		return 3
	elseif tokens(def.faction) ~= nil then
		return 4
	end
	return 5
end

-- Ranks compare by tier, then a named faction before "*", then id.
local function rank(def)
	return { tier(def), tokens(def.faction) ~= nil and 0 or 1, def.id }
end

local function ranksBefore(a, b)
	for i = 1, #a do
		if a[i] ~= b[i] then
			return a[i] < b[i]
		end
	end
	return false
end

-- The most specific compatible guide for the player (default ns.Player), or nil when none fits.
function Guides:Best(player)
	local best, bestRank
	for _, def in pairs(self.defs) do
		if self:Compatible(def, player) then
			local defRank = rank(def)
			if not best or ranksBefore(defRank, bestRank) then
				best, bestRank = def, defRank
			end
		end
	end
	return best
end

-- The character's guide: the one stored by Select while it is registered and still compatible, else Best.
function Guides:Selected(player)
	local db = ns.char
	local def = db and self:Get(db.guide)
	if def and self:Compatible(def, player) then
		return def
	end
	return self:Best(player)
end

-- Stores the character's choice in SignpostCharDB.guide (nil returns to automatic selection) and fires
-- GUIDE_SELECTED(def) when that changes the selected guide. Refuses unknown and incompatible guides. Returns true, or
-- false and the reason.
function Guides:Select(id, player)
	local db = ns.char
	if not db then
		return false, L["Saved variables are not loaded yet"]
	end
	if id ~= nil then
		local def = self:Get(id)
		if not def then
			return false, string.format(L["Unknown guide: %s"], tostring(id))
		end
		local ok, reason = self:Compatible(def, player)
		if not ok then
			return false, reason
		end
	end
	local before = self:Selected(player)
	db.guide = id
	local after = self:Selected(player)
	if after ~= before then
		ns.Events:Fire("GUIDE_SELECTED", after)
	end
	return true
end

-- Chapters ----------------------------------------------------------------------------------------------------------

local Chapters = { texts = {}, problems = {} }
ns.Chapters = Chapters

local CHAPTER_ID = "^[a-z0-9%-]+$"

-- Registers a shared chapter's text under its id (lowercase letters, digits and "-"; GUIDE-FORMAT "Files"). Returns
-- true, or false and the problem.
function Chapters:Register(id, text)
	local problem
	if type(id) ~= "string" or not id:find(CHAPTER_ID) then
		problem = string.format(L["Chapter id %s is not lowercase letters, digits and '-'"], tostring(id))
	elseif type(text) ~= "string" then
		problem = string.format(L["Chapter %s has no text"], id)
	end
	if problem then
		report(self, problem)
		return false, problem
	end
	if self.texts[id] and self.texts[id] ~= text then
		report(self, string.format(L["Chapter %s was registered twice; the later one is used"], id))
	end
	self.texts[id] = text
	return true
end

function Chapters:Get(id)
	if id == nil then
		return nil
	end
	return self.texts[id]
end

-- Classes -----------------------------------------------------------------------------------------------------------

local Classes = { modules = {}, problems = {} }
ns.Classes = Classes

-- Registers a class module under its class token (PLAN §3.5: trainerSpells, classQuests, directives, classTab,
-- automation, onLevelUp); its directives go into ns.Directives. Returns true, or false and the problem.
function Classes:Register(classFile, module)
	if type(classFile) ~= "string" or classFile == "" or type(module) ~= "table" then
		local problem = L["A class module needs a class token and a table"]
		report(self, problem)
		return false, problem
	end
	if self.modules[classFile] and self.modules[classFile] ~= module then
		report(self, string.format(L["Class module %s was registered twice; the later one is used"], classFile))
	end
	self.modules[classFile] = module
	registerDirectives(self, string.format(L["Class module %s"], classFile), module.directives)
	return true
end

function Classes:Get(classFile)
	if classFile == nil then
		return nil
	end
	return self.modules[classFile]
end

-- The player's class module hears of every new level (its optional onLevelUp(level)); Core/Player.lua registered
-- first, so ns.Player.level already holds the new level.
ns.Events:Register("PLAYER_LEVEL_UP", function(_, level)
	local module = Classes:Get(ns.Player and ns.Player.classFile)
	if module and type(module.onLevelUp) == "function" then
		module.onLevelUp(level)
	end
end)
