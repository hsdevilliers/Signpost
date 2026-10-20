-- Automation: trainers (PLAN §3.4). Off by default (`trainer`). On TRAINER_SHOW during a `.train` / `.trainprof` step,
-- buys ONLY what the step lists: the spell IDs of `.train <spellID>`, the class module's trainerSpells at or below the
-- player's level for `.train class` (none listed: nothing is bought), the profession module's `rankSpells` (the spell
-- IDs of its rank and learn services; a module without them buys nothing) for `.trainprof <key>`. Never "buy all";
-- never spends below the gold reserve (default 0, /signpost automation reserve).
local ADDON_NAME, ns = ...
local Util = ns.Util
local Automation = ns.Automation

local Trainer = {}
Automation.Trainer = Trainer

local TYPES = { available = true, unavailable = true, used = true }

local function plain(value)
	if type(value) == "number" and not Util.IsSecret(value) then
		return value
	end
end

-- What the current step wants: the set of spell IDs it lists (nil when the step has no training directive).
function Trainer:Wanted()
	local wanted, any = {}, false
	for _, entry in ipairs(Automation:Directives("train")) do
		if entry.args.spellID then
			wanted[entry.args.spellID] = true
			any = true
		elseif entry.args.class then
			any = true
			local player = ns.Player or {}
			local module = ns.Classes and ns.Classes:Get(player.classFile)
			local level = tonumber(ns.Context and ns.Context:Level() or player.level) or 0
			for spellLevel, list in
				pairs(module and type(module.trainerSpells) == "table" and module.trainerSpells or {})
			do
				if type(spellLevel) == "number" and spellLevel <= level and type(list) == "table" then
					for _, spellID in ipairs(list) do
						wanted[spellID] = true
					end
				end
			end
		end
	end
	for _, entry in ipairs(Automation:Directives("trainprof")) do
		local module = ns.Professions and ns.Professions:Get(entry.args.key)
		any = true
		for _, spellID in ipairs(module and type(module.rankSpells) == "table" and module.rankSpells or {}) do
			wanted[spellID] = true
		end
	end
	return any and wanted or nil
end

-- The spell ID of service i: the link's spell (or item), else the tooltip data's id.
-- VERIFY(beta): GetTrainerServiceItemLink(i) is a spell link, and C_TooltipInfo.GetTrainerService(i).id the spell ID
-- (open probe); a service whose ID cannot be read is never bought.
local function serviceSpellID(index)
	local link = Util.Call(GetTrainerServiceItemLink, index)
	if type(link) == "string" and not Util.IsSecret(link) then
		local id = tonumber(link:match("spell:(%d+)")) or tonumber(link:match("item:(%d+)"))
		if id then
			return id
		end
	end
	local api = C_TooltipInfo and C_TooltipInfo.GetTrainerService
	local data = api and Util.Call(api, index)
	if type(data) == "table" then
		return plain(data.id) or plain(data.spellID)
	end
end

-- "available", "unavailable" or "used": the client returns name, subText/rank, serviceType (VERIFY(beta): the order).
local function serviceType(info)
	for i = 1, 4 do
		if type(info[i]) == "string" and TYPES[info[i]] then
			return info[i]
		end
	end
end

-- Services to buy now, in list order: { { index, cost, spellID } }.
function Trainer:Plan(wanted)
	local plan, money, reserve = {}, plain(Util.Call(GetMoney)) or 0, Automation:Reserve()
	for index = 1, plain(Util.Call(GetNumTrainerServices)) or 0 do
		local info = Util.Pack(Util.Call(GetTrainerServiceInfo, index))
		if serviceType(info) == "available" then
			local spellID = serviceSpellID(index)
			local match = spellID and wanted[spellID] and not (ns.Context and ns.Context:SpellKnown(spellID))
			local cost = plain((Util.Call(GetTrainerServiceCost, index))) or 0
			if match and money - cost >= reserve then
				money = money - cost
				plan[#plan + 1] = { index = index, cost = cost, spellID = spellID }
			end
		end
	end
	return plan
end

function Trainer:OnShow()
	if not Automation:Allowed("trainer") then
		return
	end
	local wanted = self:Wanted()
	if not wanted then
		return
	end
	local plan = self:Plan(wanted)
	-- highest index first: buying may shift the entries behind a bought one when the list is filtered
	for i = #plan, 1, -1 do
		Util.Call(BuyTrainerService, plan[i].index)
	end
end

ns.Events:Register("TRAINER_SHOW", function()
	Trainer:OnShow()
end)
