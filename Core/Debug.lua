-- /signpost debug: records game events plus a snapshot of the state the guide engine will depend on (gossip options,
-- quest dialogs and rewards, trainer and vendor lists, taxi nodes, positions around zone changes and transports) in
-- SignpostDB.eventLog, and with `debug pos` the player's position every second in SignpostDB.posLog. This is the
-- beta burn-down recorder of PLAN §9.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local call = Util.Call

local Debug = {}
ns.Debug = Debug

local MAX_EVENTS = 2000
local MAX_POSITIONS = 3600
local COALESCE_SECONDS = 1

local EVENTS = {
	"PLAYER_ENTERING_WORLD",
	"LOADING_SCREEN_ENABLED",
	"LOADING_SCREEN_DISABLED",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
	"PLAYER_CONTROL_LOST",
	"PLAYER_CONTROL_GAINED",
	"TAXIMAP_OPENED",
	"TAXIMAP_CLOSED",
	"GOSSIP_SHOW",
	"GOSSIP_CLOSED",
	"QUEST_GREETING",
	"QUEST_DETAIL",
	"QUEST_PROGRESS",
	"QUEST_COMPLETE",
	"QUEST_FINISHED",
	"QUEST_ACCEPTED",
	"QUEST_TURNED_IN",
	"QUEST_REMOVED",
	"QUEST_WATCH_UPDATE",
	"TRAINER_SHOW",
	"TRAINER_CLOSED",
	"MERCHANT_SHOW",
	"MERCHANT_CLOSED",
	"CONFIRM_BINDER",
	"PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
	"PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
	"PLAYER_LEVEL_UP",
	"SKILL_LINES_CHANGED",
	"LEARNED_SPELL_IN_SKILL_LINE",
	"LEARNED_SPELL_IN_TAB",
	"UNIT_PET",
	"ITEM_DATA_LOAD_RESULT",
	"UI_INFO_MESSAGE",
	"CHAT_MSG_SKILL",
	"QUEST_LOG_UPDATE",
	"BAG_UPDATE_DELAYED",
	"PLAYER_XP_UPDATE",
	"UNIT_QUEST_LOG_CHANGED",
	"SPELLS_CHANGED",
}

-- Frequent events are only counted (SignpostDB.debug.counts), not logged.
local COUNT_ONLY = {
	QUEST_LOG_UPDATE = true,
	BAG_UPDATE_DELAYED = true,
	PLAYER_XP_UPDATE = true,
	UNIT_QUEST_LOG_CHANGED = true,
	SPELLS_CHANGED = true,
}

-- Events whose snapshot is just the player's position (with the map chain).
local POSITION_EVENTS = {
	PLAYER_ENTERING_WORLD = true,
	LOADING_SCREEN_DISABLED = true,
	ZONE_CHANGED = true,
	ZONE_CHANGED_INDOORS = true,
	ZONE_CHANGED_NEW_AREA = true,
	PLAYER_CONTROL_LOST = true,
	PLAYER_CONTROL_GAINED = true,
}

-- Snapshots ---------------------------------------------------------------------------------------------------------

local function npc()
	local guid = call(UnitGUID, "npc")
	return { id = Util.NpcIDFromGUID(guid), name = call(UnitName, "npc"), guid = guid, pos = Util.PlayerPosition() }
end

local function questInfo(questID)
	local questLog = C_QuestLog
	if not (questID and questLog) then
		return nil
	end
	local index = call(questLog.GetLogIndexForQuestID, questID)
	return {
		index = index,
		info = index and call(questLog.GetInfo, index),
		objectives = call(questLog.GetQuestObjectives, questID),
		complete = call(questLog.IsComplete, questID),
	}
end

local function itemIDFromLink(link)
	return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local snapshots = {}

snapshots.QUEST_DETAIL = function()
	return {
		npc = npc(),
		questID = call(GetQuestID),
		title = call(GetTitleText),
		autoAccept = call(QuestGetAutoAccept),
		areaTrigger = call(QuestIsFromAreaTrigger),
		choices = call(GetNumQuestChoices),
		rewards = call(GetNumQuestRewards),
	}
end

snapshots.QUEST_GREETING = function()
	local result = { npc = npc(), available = {}, active = {} }
	for i = 1, call(GetNumAvailableQuests) or 0 do
		result.available[i] = {
			title = call(GetAvailableTitle, i),
			info = Util.Pack(call(GetAvailableQuestInfo, i)),
		}
	end
	for i = 1, call(GetNumActiveQuests) or 0 do
		result.active[i] = { title = call(GetActiveTitle, i), questID = call(GetActiveQuestID, i) }
	end
	return result
end

snapshots.GOSSIP_SHOW = function()
	local gossip = C_GossipInfo or {}
	return {
		npc = npc(),
		options = call(gossip.GetOptions),
		available = call(gossip.GetAvailableQuests),
		active = call(gossip.GetActiveQuests),
	}
end

snapshots.QUEST_PROGRESS = function()
	return {
		npc = npc(),
		questID = call(GetQuestID),
		completable = call(IsQuestCompletable),
		items = call(GetNumQuestItems),
	}
end

snapshots.QUEST_COMPLETE = function()
	local result = {
		npc = npc(),
		questID = call(GetQuestID),
		money = call(GetRewardMoney),
		xp = call(GetRewardXP),
		choices = {},
	}
	local item = C_Item or {}
	for i = 1, call(GetNumQuestChoices) or 0 do
		local link = call(GetQuestItemLink, "choice", i)
		local itemID = itemIDFromLink(link)
		local info = link and Util.Pack(call(item.GetItemInfo, link))
		result.choices[i] = {
			link = link,
			itemID = itemID,
			reward = Util.Pack(call(GetQuestItemInfo, "choice", i)),
			cached = itemID and call(item.IsItemDataCachedByID, itemID),
			sellPrice = info and info[11],
		}
	end
	return result
end

snapshots.QUEST_ACCEPTED = function(questID)
	return { npc = npc(), quest = questInfo(questID) }
end

snapshots.QUEST_TURNED_IN = function()
	return { npc = npc() }
end

snapshots.QUEST_WATCH_UPDATE = function(questID)
	return { quest = questInfo(questID) }
end

snapshots.TRAINER_SHOW = function()
	local tooltipInfo = C_TooltipInfo or {}
	local result = {
		npc = npc(),
		tradeskill = call(IsTradeskillTrainer),
		filters = {
			available = call(GetTrainerServiceTypeFilter, "available"),
			unavailable = call(GetTrainerServiceTypeFilter, "unavailable"),
			used = call(GetTrainerServiceTypeFilter, "used"),
		},
		services = {},
	}
	for i = 1, call(GetNumTrainerServices) or 0 do
		local tooltip = call(tooltipInfo.GetTrainerService, i)
		result.services[i] = {
			info = Util.Pack(call(GetTrainerServiceInfo, i)),
			cost = call(GetTrainerServiceCost, i),
			level = call(GetTrainerServiceLevelReq, i),
			skillLine = call(GetTrainerServiceSkillLine, i),
			link = call(GetTrainerServiceItemLink, i),
			tooltipType = type(tooltip) == "table" and tooltip.type or nil,
			tooltipID = type(tooltip) == "table" and tooltip.id or nil,
		}
	end
	return result
end

snapshots.MERCHANT_SHOW = function()
	local merchant = C_MerchantFrame or {}
	local result = { npc = npc(), items = {} }
	for i = 1, call(GetMerchantNumItems) or 0 do
		result.items[i] = {
			id = call(GetMerchantItemID, i),
			link = call(GetMerchantItemLink, i),
			info = call(merchant.GetItemInfo, i) or Util.Pack(call(GetMerchantItemInfo, i)),
		}
	end
	return result
end

snapshots.TAXIMAP_OPENED = function()
	local mapID = call(C_Map and C_Map.GetBestMapForUnit, "player")
	local result = {
		npc = npc(),
		map = mapID,
		nodes = mapID and call(C_TaxiMap and C_TaxiMap.GetAllTaxiNodes, mapID),
		classic = {},
	}
	for i = 1, call(NumTaxiNodes) or 0 do
		result.classic[i] = {
			name = call(TaxiNodeName, i),
			type = call(TaxiNodeGetType, i),
			pos = Util.Pack(call(TaxiNodePosition, i)),
			cost = call(TaxiNodeCost, i),
		}
	end
	return result
end

snapshots.CONFIRM_BINDER = function()
	return { npc = npc(), bind = call(GetBindLocation) }
end

snapshots.UNIT_PET = function(unit)
	if unit ~= "player" then
		return nil
	end
	local guid = call(UnitGUID, "pet")
	return {
		exists = call(UnitExists, "pet"),
		family = call(UnitCreatureFamily, "pet"),
		npcID = Util.NpcIDFromGUID(guid),
		level = call(UnitLevel, "pet"),
	}
end

snapshots.PLAYER_LEVEL_UP = function()
	return { xp = call(UnitXP, "player"), xpMax = call(UnitXPMax, "player") }
end

snapshots.SKILL_LINES_CHANGED = function()
	return { professions = Util.Professions() }
end

local function learnedSpell(spellID)
	return { spell = call(C_Spell and C_Spell.GetSpellInfo, spellID) }
end
snapshots.LEARNED_SPELL_IN_SKILL_LINE = learnedSpell
snapshots.LEARNED_SPELL_IN_TAB = learnedSpell

local function interactionName(kind)
	local types = Enum and Enum.PlayerInteractionType
	if type(types) == "table" then
		for name, value in pairs(types) do
			if value == kind then
				return { type = name }
			end
		end
	end
end
snapshots.PLAYER_INTERACTION_MANAGER_FRAME_SHOW = interactionName
snapshots.PLAYER_INTERACTION_MANAGER_FRAME_HIDE = interactionName

-- Logging -----------------------------------------------------------------------------------------------------------

local function sameArgs(a, b)
	if a.n ~= b.n then
		return false
	end
	for i = 1, a.n do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function append(list, entry, max)
	list[#list + 1] = entry
	if #list > max then
		table.remove(list, 1)
	end
end

function Debug:Log(event, args, snapshot)
	local db = ns.db
	args = Util.Sanitize(args or { n = 0 })
	local now = GetTime()
	local last = db.eventLog[#db.eventLog]
	if
		last
		and not snapshot
		and not last.s
		and last.e == event
		and now - last.t <= COALESCE_SECONDS
		and sameArgs(last.a, args)
	then
		last.count = (last.count or 1) + 1
		last.t = now
		return
	end
	append(db.eventLog, { e = event, t = now, time = time(), a = args, s = Util.Sanitize(snapshot) }, MAX_EVENTS)
	if db.debug.chat then
		Util.Print("|cff999999%s|r %s", event, Util.ToJSON(args))
	end
end

function Debug:OnEvent(event, ...)
	local db = ns.db
	if COUNT_ONLY[event] then
		db.debug.counts[event] = (db.debug.counts[event] or 0) + 1
		return
	end
	local snapshot
	if POSITION_EVENTS[event] then
		snapshot = { pos = Util.PlayerPosition(true) }
		if event == "ZONE_CHANGED_NEW_AREA" then
			snapshot.prev = self.lastPos
		end
		self.lastPos = snapshot.pos
	elseif snapshots[event] then
		snapshot = snapshots[event](...)
	end
	self:Log(event, Util.Pack(...), snapshot)
	if event == "TAXIMAP_OPENED" then
		-- Which taxi UI is this client using? The frame is shown by Blizzard's own handler for the same event.
		C_Timer.After(0.3, function()
			ns.SafeCall(Debug.Log, Debug, "TAXI_FRAMES", nil, {
				taxiFrame = TaxiFrame and call(TaxiFrame.IsShown, TaxiFrame),
				flightMapFrame = FlightMapFrame and call(FlightMapFrame.IsShown, FlightMapFrame),
			})
		end)
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
	ns.SafeCall(Debug.OnEvent, Debug, event, ...)
end)

-- Every second while debugging: remember the position (the "before" of the next zone change) and, with
-- `debug pos`, sample it into posLog.
function Debug:Tick()
	local pos = Util.PlayerPosition()
	self.lastPos = pos
	if self.trackPositions then
		append(ns.db.posLog, Util.Sanitize(pos), MAX_POSITIONS)
	end
end

function Debug:SetEnabled(enabled)
	ns.db.debug.enabled = enabled and true or false
	frame:UnregisterAllEvents()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
	self.trackPositions = false
	if not enabled then
		return
	end
	self.unknownEvents = {}
	for _, event in ipairs(EVENTS) do
		local ok
		if event:find("^UNIT_") and frame.RegisterUnitEvent then
			ok = pcall(frame.RegisterUnitEvent, frame, event, "player")
		else
			ok = pcall(frame.RegisterEvent, frame, event)
		end
		if not ok then
			self.unknownEvents[#self.unknownEvents + 1] = event
		end
	end
	ns.db.debug.unknownEvents = self.unknownEvents
	self.ticker = C_Timer.NewTicker(1, function()
		ns.SafeCall(Debug.Tick, Debug)
	end)
end

function Debug:PrintStatus()
	local db = ns.db
	Util.Print(
		L["debug log %s: %d events, %d positions (position sampling %s, chat echo %s)"],
		db.debug.enabled and L["on"] or L["off"],
		#db.eventLog,
		#db.posLog,
		self.trackPositions and L["on"] or L["off"],
		db.debug.chat and L["on"] or L["off"]
	)
end

ns.Slash:Register("debug", function(args)
	local db = ns.db
	local sub = (args or ""):lower()
	if sub == "on" then
		Debug:SetEnabled(true)
	elseif sub == "off" then
		Debug:SetEnabled(false)
	elseif sub == "pos" then
		if not db.debug.enabled then
			Debug:SetEnabled(true)
		end
		Debug.trackPositions = not Debug.trackPositions
	elseif sub == "chat" then
		db.debug.chat = not db.debug.chat
	elseif sub == "clear" then
		wipe(db.eventLog)
		wipe(db.posLog)
		wipe(db.debug.counts)
	elseif sub == "throw" then
		ns.SafeCall(function()
			error(L["Deliberate test error from /signpost debug throw"])
		end)
	end
	Debug:PrintStatus()
end, L["event log to SavedVariables: on | off | pos | chat | clear | throw"])

-- Logging survives /reload; position sampling does not (it is meant for one transport ride or crossing at a time).
ns.Events:RegisterMessage("DB_READY", function()
	if ns.db.debug.enabled then
		Debug:SetEnabled(true)
	end
end)
