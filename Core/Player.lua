-- ns.Player: the only place the player's class, race, faction and learned professions are read. Everything else uses
-- these fields, so no module outside Classes/, Professions/ and Guides/ ever names a class, race, faction or
-- profession.
local ADDON_NAME, ns = ...

-- professions = { [skillLineID] = { key, name, rank, max, primary, slot, skillLine } }: key is the profession module's
-- key (ns.Professions:ForSkillLine) or nil when no module covers the skill line; slot is the GetProfessions position.
local Player = { professions = {} }
ns.Player = Player

-- GetProfessions' first slots hold the primary professions on retail.
local PRIMARY_SLOTS = 2

function Player:Refresh()
	self.className, self.classFile, self.classID = UnitClass("player")
	self.classBase = UnitClassBase and UnitClassBase("player")
	self.raceName, self.raceFile, self.raceID = UnitRace("player")
	self.faction, self.factionName = UnitFactionGroup("player")
	self.level = UnitLevel("player")
	self:RefreshProfessions()
end

-- Professions -------------------------------------------------------------------------------------------------------

local function plain(value, kind)
	if not ns.Util.IsSecret(value) and type(value) == kind then
		return value
	end
end

-- Primary or secondary: the profession module says so; else the client (GetProfessionInfoBySkillLineID reports
-- isPrimaryProfession for every profession, verified on beta 1.60.1.70450); else the slot.
local function isPrimary(skillLine, slot, module)
	if module then
		return module.primary == true
	end
	local tradeSkill = C_TradeSkillUI
	local info = ns.Util.Call(tradeSkill and tradeSkill.GetProfessionInfoBySkillLineID, skillLine)
	if type(info) == "table" and info.isPrimaryProfession ~= nil then
		return info.isPrimaryProfession == true
	end
	-- VERIFY(beta): GetProfessions' first two values are the primary professions on Forever too.
	return slot <= PRIMARY_SLOTS
end

local FIELDS = { "key", "name", "rank", "max", "primary", "slot" }

local function sameProfessions(a, b)
	for skillLine, entry in pairs(a) do
		local other = b[skillLine]
		if not other then
			return false
		end
		for _, field in ipairs(FIELDS) do
			if entry[field] ~= other[field] then
				return false
			end
		end
	end
	for skillLine in pairs(b) do
		if not a[skillLine] then
			return false
		end
	end
	return true
end

-- Reads the learned professions and fires PLAYER_PROFESSIONS_CHANGED(professions) when anything about them changed
-- (learned, unlearned, a skill-up). GetProfessions() returns one profession index per slot, nil for an empty one: 5
-- values on retail, 7 on Forever (beta 1.60.1.70450), so every value it returns is read, whatever the count.
-- VERIFY(beta): what each of the 7 values holds once professions are learned (FOREVER-API-NOTES, Open probes).
-- Returns whether anything changed.
function Player:RefreshProfessions()
	local Util = ns.Util
	local registry = ns.Professions
	local slots = Util.Pack(Util.Call(GetProfessions))
	local professions = {}
	for slot = 1, slots.n do
		local index = slots[slot]
		if index ~= nil and not Util.IsSecret(index) then
			-- VERIFY(beta): GetProfessionInfo keeps the retail order (name, icon, rank, max, spells, spell offset,
			-- skill line, ...); the probe character had no professions to show it.
			local name, _, rank, max, _, _, skillLine = Util.Call(GetProfessionInfo, index)
			skillLine = plain(skillLine, "number")
			if skillLine and not professions[skillLine] then
				local key, module
				if registry and registry.ForSkillLine then
					key, module = registry:ForSkillLine(skillLine)
				end
				professions[skillLine] = {
					key = key,
					name = plain(name, "string"),
					rank = plain(rank, "number"),
					max = plain(max, "number"),
					primary = isPrimary(skillLine, slot, module),
					slot = slot,
					skillLine = skillLine,
				}
			end
		end
	end
	local changed = not sameProfessions(self.professions, professions)
	self.professions = professions
	if changed then
		ns.Events:Fire("PLAYER_PROFESSIONS_CHANGED", professions)
	end
	return changed
end

-- The learned profession with this profession key, or nil.
function Player:Profession(key)
	if key == nil then
		return nil
	end
	for _, entry in pairs(self.professions) do
		if entry.key == key then
			return entry
		end
	end
end

-- VERIFY(beta): GetProfessions already answers at PLAYER_LOGIN (if not, the next SKILL_LINES_CHANGED fills the list
-- and the plan is detected again).
ns.Events:Register("PLAYER_LOGIN", function()
	Player:Refresh()
end)

ns.Events:Register("PLAYER_LEVEL_UP", function(_, level)
	Player.level = level
end)

-- VERIFY(beta): SKILL_LINES_CHANGED fires when a profession is learned or unlearned, and CHAT_MSG_SKILL at each
-- skill-up (on retail SKILL_LINES_CHANGED misses plain rank increases).
local function refreshProfessions()
	Player:RefreshProfessions()
end
ns.Events:Register("SKILL_LINES_CHANGED", refreshProfessions)
ns.Events:Register("CHAT_MSG_SKILL", refreshProfessions)
