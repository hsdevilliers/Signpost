-- /signpost probe: answers the "Open probes" of docs/FOREVER-API-NOTES.md from inside the client and stores the
-- result in SignpostDB.probe for tools/read_savedvars.py. Read-only: it never changes game state. Each section runs
-- under pcall, so one surprise produces { error = ... } for that section and the rest still report.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local call = Util.Call

local Probe = { early = {} }
ns.Probe = Probe

-- Dotted names resolve through _G. EXPECTED_ABSENT were removed on the Mainline API: finding one is the surprise.
local APIS = {
	-- client, addons, errors, secrets
	"GetBuildInfo",
	"GetAddOnMetadata",
	"C_AddOns.GetAddOnMetadata",
	"C_AddOns.GetAddOnInfo",
	"C_AddOns.IsAddOnLoaded",
	"C_AddOns.LoadAddOn",
	"C_AddOns.IsAddonVersionCheckEnabled",
	"C_Timer.After",
	"C_Timer.NewTicker",
	"EventRegistry",
	"C_EventUtils.IsEventValid",
	"C_XMLUtil.GetTemplateInfo",
	"C_Texture.GetAtlasInfo",
	"GetFileIDFromPath",
	"seterrorhandler",
	"geterrorhandler",
	"debugstack",
	"debuglocals",
	"hooksecurefunc",
	"InCombatLockdown",
	"issecretvalue",
	"issecrettable",
	"canaccesssecrets",
	"canaccessvalue",
	"scrubsecretvalues",
	"UpdateAddOnMemoryUsage",
	"GetAddOnMemoryUsage",
	-- quests and NPC dialogs
	"C_QuestLog.GetNumQuestLogEntries",
	"C_QuestLog.GetInfo",
	"C_QuestLog.GetLogIndexForQuestID",
	"C_QuestLog.GetQuestIDForLogIndex",
	"C_QuestLog.IsQuestFlaggedCompleted",
	"C_QuestLog.GetAllCompletedQuestIDs",
	"C_QuestLog.GetQuestObjectives",
	"C_QuestLog.IsComplete",
	"C_QuestLog.IsOnQuest",
	"C_QuestLog.GetTitleForQuestID",
	-- the tracked quests (Engine/Tracking.lua)
	"C_QuestLog.AddQuestWatch",
	"C_QuestLog.RemoveQuestWatch",
	"C_QuestLog.GetQuestWatchType",
	"C_QuestLog.GetNumQuestWatches",
	"C_QuestLog.GetQuestIDForQuestWatchIndex",
	"C_SuperTrack.SetSuperTrackedQuestID",
	"C_SuperTrack.GetSuperTrackedQuestID",
	"Enum.QuestWatchType",
	"GetQuestID",
	"AcceptQuest",
	"CompleteQuest",
	"GetQuestReward",
	"GetNumQuestChoices",
	"GetQuestItemLink",
	"GetQuestItemInfo",
	"IsQuestCompletable",
	"QuestGetAutoAccept",
	"GetNumAvailableQuests",
	"GetNumActiveQuests",
	"GetAvailableQuestInfo",
	"GetActiveQuestID",
	"SelectAvailableQuest",
	"SelectActiveQuest",
	"C_GossipInfo.GetOptions",
	"C_GossipInfo.SelectOption",
	"C_GossipInfo.GetAvailableQuests",
	"C_GossipInfo.SelectAvailableQuest",
	"C_GossipInfo.GetActiveQuests",
	"C_GossipInfo.SelectActiveQuest",
	"C_GossipInfo.CloseGossip",
	-- items, bags, spells
	"C_Item.GetItemInfo",
	"C_Item.GetItemInfoInstant",
	"C_Item.GetItemCount",
	"C_Item.RequestLoadItemDataByID",
	"C_Item.IsItemDataCachedByID",
	"C_Container.GetContainerNumSlots",
	"C_Container.GetContainerItemInfo",
	"C_Spell.GetSpellInfo",
	"C_SpellBook.IsSpellKnown",
	"IsPlayerSpell",
	"IsSpellKnown",
	"GetInventorySlotInfo",
	-- professions, trainers, vendors
	"GetProfessions",
	"GetProfessionInfo",
	"GetNumSkillLines",
	"GetSkillLineInfo",
	"C_TradeSkillUI.GetAllProfessionTradeSkillLines",
	"C_TradeSkillUI.GetProfessionInfoBySkillLineID",
	"C_TradeSkillUI.GetProfessionSkillLineID",
	"GetNumTrainerServices",
	"GetTrainerServiceInfo",
	"GetTrainerServiceItemLink",
	"GetTrainerServiceCost",
	"GetTrainerServiceLevelReq",
	"GetTrainerServiceSkillLine",
	"GetTrainerServiceTypeFilter",
	"SetTrainerServiceTypeFilter",
	"BuyTrainerService",
	"IsTradeskillTrainer",
	"C_TooltipInfo.GetTrainerService",
	"GetMerchantNumItems",
	"GetMerchantItemInfo",
	"C_MerchantFrame.GetItemInfo",
	"GetMerchantItemID",
	"GetMerchantItemLink",
	"BuyMerchantItem",
	-- maps, travel, position
	"C_Map.GetBestMapForUnit",
	"C_Map.GetPlayerMapPosition",
	"C_Map.GetMapInfo",
	"C_Map.GetMapChildrenInfo",
	"C_Map.GetWorldPosFromMapPos",
	"C_Map.GetMapWorldSize",
	"C_Map.GetMapRectOnMap",
	"C_Map.GetMapGroupID",
	"CreateVector2D",
	"UnitPosition",
	"UnitOnTaxi",
	"IsInInstance",
	"GetZoneText",
	"GetSubZoneText",
	"GetRealZoneText",
	"GetMinimapZoneText",
	"C_TaxiMap.GetAllTaxiNodes",
	"C_TaxiMap.GetTaxiNodesForMap",
	"NumTaxiNodes",
	"TaxiNodeName",
	"TaxiNodeGetType",
	"TaxiNodePosition",
	"TakeTaxiNode",
	"GetBindLocation",
	"ConfirmBinder",
	"C_EncounterJournal.GetDungeonEntrancesForMap",
	"C_Minimap.GetViewRadius",
	-- units and identity
	"UnitGUID",
	"UnitName",
	"UnitLevel",
	"UnitXP",
	"UnitXPMax",
	"UnitClass",
	"UnitClassBase",
	"UnitRace",
	"UnitFactionGroup",
	"UnitExists",
	"UnitCreatureFamily",
	"GetClassAtlas",
	"GetNumClasses",
	"C_CreatureInfo.GetClassInfo",
	"C_CreatureInfo.GetRaceInfo",
	-- UI construction
	"CreateFrame",
	"ScrollUtil.InitScrollBoxListWithScrollBar",
	"CreateScrollBoxListLinearView",
	"CreateDataProvider",
	"MenuUtil.CreateContextMenu",
	"Settings.RegisterCanvasLayoutCategory",
	"Settings.RegisterAddOnCategory",
	"Settings.OpenToCategory",
	"ButtonFrameTemplate_HidePortrait",
	"ButtonFrameTemplate_HideButtonBar",
	"PanelTemplates_SetNumTabs",
	"PanelTemplates_SetTab",
	"PanelTemplates_TabResize",
	"ShowUIPanel",
	"HideUIPanel",
	"UIPanelWindows",
	"UISpecialFrames",
	-- expected absent on the Mainline API
	"GetSpellInfo",
	"GetItemInfo",
	"GetItemCount",
	"CombatLogGetCurrentEventInfo",
	-- the Classic shape of the quest watch list, Engine/Tracking.lua's fallback: finding these means the fallback runs
	"AddQuestWatch",
	"RemoveQuestWatch",
	"IsQuestWatched",
	"GetNumQuestWatches",
	"GetQuestIndexForWatch",
}

local EXPECTED_ABSENT = {
	GetSpellInfo = true,
	GetItemInfo = true,
	GetItemCount = true,
	CombatLogGetCurrentEventInfo = true,
	AddQuestWatch = true,
	RemoveQuestWatch = true,
	IsQuestWatched = true,
	GetNumQuestWatches = true,
	GetQuestIndexForWatch = true,
}

-- Template name -> frame type, used only when C_XMLUtil.GetTemplateInfo is unavailable.
local TEMPLATES = {
	ButtonFrameTemplate = "Frame",
	PortraitFrameTemplate = "Frame",
	BasicFrameTemplateWithInset = "Frame",
	InsetFrameTemplate = "Frame",
	InsetFrameTemplate3 = "Frame",
	PanelTabButtonTemplate = "Button",
	SearchBoxTemplate = "EditBox",
	InputBoxTemplate = "EditBox",
	MinimalScrollBar = "EventFrame",
	WowScrollBoxList = "Frame",
	ScrollFrameTemplate = "ScrollFrame",
	UIPanelScrollFrameTemplate = "ScrollFrame",
	WowStyle1DropdownTemplate = "DropdownButton",
	UIDropDownMenuTemplate = "Frame",
	UIPanelButtonTemplate = "Button",
	UIPanelCloseButton = "Button",
	UICheckButtonTemplate = "CheckButton",
	SecureActionButtonTemplate = "Button",
	BackdropTemplate = "Frame",
	TooltipBackdropTemplate = "Frame",
	GameTooltipTemplate = "GameTooltip",
}

-- "TaxiNode_<player faction>" is added at run time.
local ATLASES = {
	"QuestNormal",
	"QuestTurnin",
	"QuestRepeatableTurnin",
	"QuestDaily",
	"TaxiNode_Neutral",
	"FlightMaster",
	"Innkeeper",
	"Vendor",
	"Class",
	"Profession",
	"poi-door",
	"poi-workorders",
	"Mailbox",
	"Repair",
	"Food",
}

local FILES = {
	"Interface\\Icons\\INV_Misc_Map_01",
	"Interface\\GossipFrame\\AvailableQuestIcon",
	"Interface\\GossipFrame\\ActiveQuestIcon",
	"Interface\\GossipFrame\\TaxiGossipIcon",
	"Interface\\GossipFrame\\TrainerGossipIcon",
	"Interface\\GossipFrame\\VendorGossipIcon",
	"Interface\\GossipFrame\\BinderGossipIcon",
	"Interface\\QuestFrame\\QuestBG",
	"Interface\\QuestFrame\\UI-QuestTitleHighlight",
	"Interface\\QuestFrame\\UI-HorizontalBreak",
	"Interface\\DialogFrame\\UI-DialogBox-Border",
	"Interface\\Minimap\\Tracking\\Class",
	"Interface\\Minimap\\Tracking\\Profession",
	"Interface\\Minimap\\Tracking\\FlightMaster",
	"Interface\\Minimap\\Tracking\\Innkeeper",
	"Interface\\Minimap\\Tracking\\Repair",
	"Interface\\Minimap\\Tracking\\Food",
}

local EVENTS = {
	"QUEST_ACCEPTED",
	"QUEST_TURNED_IN",
	"QUEST_REMOVED",
	"QUEST_LOG_UPDATE",
	"QUEST_WATCH_UPDATE",
	"QUEST_WATCH_LIST_CHANGED",
	"UNIT_QUEST_LOG_CHANGED",
	"QUEST_DETAIL",
	"QUEST_GREETING",
	"QUEST_PROGRESS",
	"QUEST_COMPLETE",
	"QUEST_FINISHED",
	"QUEST_ACCEPT_CONFIRM",
	"GOSSIP_SHOW",
	"GOSSIP_CLOSED",
	"TRAINER_SHOW",
	"TRAINER_UPDATE",
	"TRAINER_CLOSED",
	"MERCHANT_SHOW",
	"MERCHANT_CLOSED",
	"TAXIMAP_OPENED",
	"TAXIMAP_CLOSED",
	"CONFIRM_BINDER",
	"PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
	"PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
	"LOADING_SCREEN_ENABLED",
	"LOADING_SCREEN_DISABLED",
	"PLAYER_CONTROL_LOST",
	"PLAYER_CONTROL_GAINED",
	"PLAYER_LEVEL_UP",
	"PLAYER_XP_UPDATE",
	"SKILL_LINES_CHANGED",
	"TRADE_SKILL_LIST_UPDATE",
	-- the trade skill events the profession recorder listens to (Core/LearnProfessions.lua)
	"TRADE_SKILL_SHOW",
	"TRADE_SKILL_DATA_SOURCE_CHANGED",
	"TRADE_SKILL_UPDATE",
	"NEW_RECIPE_LEARNED",
	"LEARNED_SPELL_IN_SKILL_LINE",
	"LEARNED_SPELL_IN_TAB",
	"SPELLS_CHANGED",
	"BAG_UPDATE_DELAYED",
	"ITEM_DATA_LOAD_RESULT",
	"GET_ITEM_INFO_RECEIVED",
	"UNIT_PET",
	"PET_STABLE_UPDATE",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED",
	"UI_INFO_MESSAGE",
	"CHAT_MSG_SKILL",
}

local FRAMES = {
	"WorldMapFrame",
	"QuestMapFrame",
	"ObjectiveTrackerFrame",
	"QuestWatchFrame",
	"GossipFrame",
	"QuestFrame",
	"TaxiFrame",
	"FlightMapFrame",
	"ClassTrainerFrame",
	"MerchantFrame",
	"AddonCompartmentFrame",
	"SettingsPanel",
	"InterfaceOptionsFrame",
	"Minimap",
	"ScriptErrorsFrame",
}

-- Light Shot, Rough Arrow, Light Quiver, Hearthstone.
local ITEMS = { 2516, 2512, 2101, 6948 }

local function countCompleted()
	local ids = call(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
	return type(ids) == "table" and #ids or nil
end

-- Sections ----------------------------------------------------------------------------------------------------------

local sections = {}
local function section(name, fn)
	sections[#sections + 1] = { name = name, fn = fn }
end

section("build", function()
	local version, build, date, interface = GetBuildInfo()
	local result = {
		version = version,
		build = build,
		date = date,
		interface = interface,
		all = Util.Pack(GetBuildInfo()),
		projectID = WOW_PROJECT_ID,
		projects = {},
		expansion = call(GetExpansionLevel),
		maxLevel = call(GetMaxLevelForPlayerExpansion) or call(GetMaxPlayerLevel),
		locale = call(GetLocale),
		tocFlavor = ns.tocFlavor,
		addonVersion = ns.version,
		xpcallPassesArgs = select(
			2,
			xpcall(function(...)
				return select("#", ...)
			end, function() end, true)
		) == 1,
		errorSource = ns.Errors.source,
	}
	-- Every WOW_PROJECT_* constant, and any other command claiming our slash words (one pass over _G).
	local collisions = {}
	for key, value in pairs(_G) do
		if type(key) == "string" then
			if key:find("^WOW_PROJECT_") then
				result.projects[key] = value
			elseif
				type(value) == "string"
				and (value:lower() == "/signpost" or value:lower() == "/sign")
				and (key:find("^SLASH_") or key:find("^EMOTE%d+_CMD%d+$"))
				and not key:find("^SLASH_SIGNPOST%d+$")
			then
				collisions[key] = value
			end
		end
	end
	result.slashCollisions = collisions
	return result
end)

section("addons", function()
	local addOns = C_AddOns or {}
	local result = {
		dataPackAtLoad = ns.dataPackAtLoad,
		dataPackGlobal = type(Signpost_Data),
		dataPack = ns.Data:Describe(),
		versionCheck = call(addOns.IsAddonVersionCheckEnabled),
		info = {},
	}
	for _, name in ipairs({ ADDON_NAME, "Signpost_Data", "Blizzard_FlightMap", "Blizzard_TrainerUI" }) do
		result.info[name] = {
			info = Util.Pack(call(addOns.GetAddOnInfo, name)),
			loaded = Util.Pack(call(addOns.IsAddOnLoaded, name)),
		}
	end
	call(UpdateAddOnMemoryUsage)
	result.memoryKB = {
		[ADDON_NAME] = call(GetAddOnMemoryUsage, ADDON_NAME),
		Signpost_Data = call(GetAddOnMemoryUsage, "Signpost_Data"),
	}
	return result
end)

section("apis", function()
	local types, missing, unexpected = {}, {}, {}
	local wanted = 0
	for _, name in ipairs(APIS) do
		local kind = type(Util.Resolve(name))
		types[name] = kind
		if EXPECTED_ABSENT[name] then
			if kind ~= "nil" then
				unexpected[#unexpected + 1] = name
			end
		else
			wanted = wanted + 1
			if kind == "nil" then
				missing[#missing + 1] = name
			end
		end
	end
	return { types = types, missing = missing, unexpectedlyPresent = unexpected, wanted = wanted }
end)

section("templates", function()
	local getInfo = Util.Resolve("C_XMLUtil.GetTemplateInfo")
	local result = { method = getInfo and "C_XMLUtil.GetTemplateInfo" or "CreateFrame", found = {} }
	for name, frameType in pairs(TEMPLATES) do
		local found
		if getInfo then
			-- The template's frame type when known, else true; false when the client has no such template.
			local info = call(getInfo, name)
			found = type(info) == "table" and (info.type or true) or info ~= nil
		else
			local ok, frame = pcall(CreateFrame, frameType, nil, UIParent, name)
			if ok and frame then
				frame:Hide()
			end
			found = ok
		end
		result.found[name] = found
	end
	return result
end)

section("atlases", function()
	local names = { unpack(ATLASES) }
	if ns.Player.faction then
		names[#names + 1] = "TaxiNode_" .. ns.Player.faction
	end
	local getAtlasInfo = Util.Resolve("C_Texture.GetAtlasInfo")
	local result = {}
	for _, name in ipairs(names) do
		result[name] = call(getAtlasInfo, name) ~= nil
	end
	return result
end)

section("files", function()
	local result = {}
	for _, path in ipairs(FILES) do
		result[path] = call(GetFileIDFromPath, path) or false
	end
	return result
end)

section("events", function()
	local frame = CreateFrame("Frame")
	local result = {}
	for _, event in ipairs(EVENTS) do
		result[event] = pcall(frame.RegisterEvent, frame, event)
	end
	frame:UnregisterAllEvents()
	return result
end)

section("frames", function()
	local result = {}
	for _, name in ipairs(FRAMES) do
		result[name] = type(_G[name])
	end
	return result
end)

section("quests", function()
	return {
		early = Probe.early,
		completedNow = countCompleted(),
		logEntries = call(C_QuestLog and C_QuestLog.GetNumQuestLogEntries),
	}
end)

section("professions", function()
	return Util.Professions()
end)

-- The functions the profession recorder (Core/LearnProfessions.lua) reads, in both shapes: the modern one
-- (C_TrainerUI, C_TradeSkillUI) and the Classic one (globals). Neither shape is "expected absent", so they are listed
-- here, apart from the APIs above, and not counted as missing in the summary.
local RECORDER_APIS = {
	-- trainer window: the globals exist on beta 1.60.1.70450; C_TrainerUI and GetTrainerServiceSkillReq were not probed
	"C_TrainerUI.GetNumTrainerServices",
	"C_TrainerUI.GetTrainerServiceInfo",
	"C_TrainerUI.GetTrainerServiceCost",
	"C_TrainerUI.GetTrainerServiceLevelReq",
	"C_TrainerUI.GetTrainerServiceSkillLine",
	"C_TrainerUI.GetTrainerServiceSkillReq",
	"C_TrainerUI.GetTrainerServiceItemLink",
	"GetNumTrainerServices",
	"GetTrainerServiceInfo",
	"GetTrainerServiceCost",
	"GetTrainerServiceLevelReq",
	"GetTrainerServiceSkillLine",
	"GetTrainerServiceSkillReq",
	"GetTrainerServiceItemLink",
	"C_TooltipInfo.GetTrainerService",
	-- trade skill window, modern shape
	"C_TradeSkillUI.GetAllRecipeIDs",
	"C_TradeSkillUI.GetRecipeInfo",
	"C_TradeSkillUI.GetRecipeSchematic",
	"C_TradeSkillUI.GetBaseProfessionInfo",
	"C_TradeSkillUI.GetChildProfessionInfo",
	"C_TradeSkillUI.GetTradeSkillLine",
	"C_TradeSkillUI.IsTradeSkillLinked",
	"C_TradeSkillUI.IsTradeSkillGuild",
	-- trade skill window, Classic shape
	"GetTradeSkillLine",
	"GetNumTradeSkills",
	"GetTradeSkillInfo",
	"GetTradeSkillRecipeLink",
	"GetTradeSkillItemLink",
	"GetTradeSkillNumReagents",
	"GetTradeSkillReagentInfo",
	"GetTradeSkillReagentItemLink",
	"IsTradeSkillLinked",
	"IsTradeSkillGuild",
}
local RECORDER_NAMESPACES = { "C_TrainerUI", "C_TradeSkillUI" }
local RECORDER_ENUMS = { "Enum.TradeskillRelativeDifficulty", "Enum.CraftingReagentType", "Enum.TooltipDataType" }

-- types: what each name is (nil: the client lacks it). namespaces: every function the client's own C_TrainerUI and
-- C_TradeSkillUI hold, so a name nobody thought of shows up. enums: the values of the enums the recorder reads.
-- last: what the last trainer and trade skill windows answered (the recorder's own report, this session).
section("recorder", function()
	local result = { types = {}, namespaces = {}, enums = {}, last = {} }
	for _, name in ipairs(RECORDER_APIS) do
		result.types[name] = type(Util.Resolve(name))
	end
	for _, name in ipairs(RECORDER_NAMESPACES) do
		local namespace = Util.Resolve(name)
		if type(namespace) == "table" then
			local names = {}
			for key, value in pairs(namespace) do
				if type(key) == "string" and type(value) == "function" then
					names[#names + 1] = key
				end
			end
			table.sort(names)
			result.namespaces[name] = names
		end
	end
	for _, name in ipairs(RECORDER_ENUMS) do
		local enum = Util.Resolve(name)
		if type(enum) == "table" then
			result.enums[name:match("[^%.]+$")] = enum
		end
	end
	local recorder = ns.Learn and ns.Learn.Professions
	result.last = recorder and recorder.report or {}
	return result
end)

section("player", function()
	local player = ns.Player
	local creatureInfo = C_CreatureInfo or {}
	local atlas = player.classFile and call(GetClassAtlas, player.classFile)
	local result = {
		classFile = player.classFile,
		classBase = player.classBase,
		classID = player.classID,
		raceFile = player.raceFile,
		raceID = player.raceID,
		faction = player.faction,
		level = player.level,
		classAtlas = atlas,
		classAtlasExists = atlas and call(Util.Resolve("C_Texture.GetAtlasInfo"), atlas) ~= nil or false,
		-- Every class and race the client knows, so new Forever combinations have tokens to key registries on.
		classes = {},
		races = {},
	}
	for id = 1, math.max(call(GetNumClasses) or 0, 20) do
		result.classes[id] = call(creatureInfo.GetClassInfo, id)
	end
	for id = 1, 100 do
		result.races[id] = call(creatureInfo.GetRaceInfo, id)
	end
	return result
end)

section("values", function()
	-- Secret values (PLAN §11): which unit values may we do arithmetic on?
	local result = {}
	for _, name in ipairs({ "UnitLevel", "UnitXP", "UnitXPMax", "UnitHealth", "UnitHealthMax", "UnitPower" }) do
		local value = call(_G[name], "player")
		local arithmetic = pcall(function()
			return value + 0
		end)
		result[name] = {
			type = type(value),
			secret = Util.IsSecret(value),
			arithmetic = arithmetic,
			-- Kept only when arithmetic worked, so a secret value never reaches SavedVariables.
			value = arithmetic and value or nil,
		}
	end
	return result
end)

section("ammo", function()
	local result = {
		ammoSlot = Util.Pack(pcall(GetInventorySlotInfo, "AmmoSlot")),
		rangedSlot = Util.Pack(pcall(GetInventorySlotInfo, "RangedSlot")),
		invslotAmmo = Util.Resolve("INVSLOT_AMMO"),
		items = {},
	}
	for _, itemID in ipairs(ITEMS) do
		result.items[itemID] = Util.Pack(call(Util.Resolve("C_Item.GetItemInfoInstant"), itemID))
	end
	return result
end)

section("map", function()
	local mapID = call(C_Map and C_Map.GetBestMapForUnit, "player")
	local getMapInfo = C_Map and C_Map.GetMapInfo
	return {
		position = Util.PlayerPosition(true),
		chain = Util.MapChain(mapID),
		roots = { [946] = call(getMapInfo, 946), [947] = call(getMapInfo, 947) },
	}
end)

section("libraries", function()
	if not LibStub then
		return { LibStub = false }
	end
	local result = { LibStub = LibStub.minor }
	for _, major in ipairs({
		"CallbackHandler-1.0",
		"HereBeDragons-2.0",
		"HereBeDragons-Pins-2.0",
		"LibDataBroker-1.1",
		"LibDBIcon-1.0",
	}) do
		local lib, minor = LibStub:GetLibrary(major, true)
		result[major] = lib and minor or false
	end
	local hbd = LibStub:GetLibrary("HereBeDragons-2.0", true)
	if hbd then
		local x, y, mapID, mapType = hbd:GetPlayerZonePosition()
		local wx, wy, instance = hbd:GetPlayerWorldPosition()
		result.hbd = {
			zone = { x = Util.Round(x, 2, 100), y = Util.Round(y, 2, 100), map = mapID, mapType = mapType },
			world = { x = Util.Round(wx, 1), y = Util.Round(wy, 1), instance = instance },
			zoneSize = mapID and Util.Pack(hbd:GetZoneSize(mapID)),
		}
	end
	return result
end)

section("minimap", function()
	return {
		rotate = call(C_CVar and C_CVar.GetCVar, "rotateMinimap"),
		zoom = Minimap and call(Minimap.GetZoom, Minimap),
		zoomLevels = Minimap and call(Minimap.GetZoomLevels, Minimap),
		viewRadius = call(Util.Resolve("C_Minimap.GetViewRadius")),
		shape = call(GetMinimapShape),
	}
end)

-- Run ---------------------------------------------------------------------------------------------------------------

local function countTrue(tbl)
	local yes, total = 0, 0
	for _, value in pairs(tbl or {}) do
		total = total + 1
		if value then
			yes = yes + 1
		end
	end
	return yes, total
end

local function falseKeys(tbl)
	local names = {}
	for name, value in pairs(tbl or {}) do
		if not value then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return table.concat(names, ", ")
end

function Probe:Run()
	local result = { time = time(), version = ns.version }
	local failed = {}
	for _, entry in ipairs(sections) do
		local ok, data = pcall(function()
			return Util.Sanitize(entry.fn())
		end)
		if ok then
			result[entry.name] = data
		else
			result[entry.name] = { error = tostring(data) }
			failed[#failed + 1] = entry.name
		end
	end
	ns.db.probe = result
	self:PrintSummary(result, failed)
	return result
end

function Probe:PrintSummary(result, failed)
	local build = result.build or {}
	Util.Print(
		L["probe: client %s build %s, interface %s, WOW_PROJECT_ID %s, TOC %s"],
		tostring(build.version),
		tostring(build.build),
		tostring(build.interface),
		tostring(build.projectID),
		tostring(build.tocFlavor)
	)
	local apis = result.apis or {}
	local missing = apis.missing or {}
	Util.Print(
		L["  APIs: %d of %d present; missing: %s"],
		(apis.wanted or 0) - #missing,
		apis.wanted or 0,
		#missing > 0 and table.concat(missing, ", ") or L["none"]
	)
	local templates = result.templates and result.templates.found
	local yes, total = countTrue(templates)
	Util.Print(L["  templates: %d of %d; missing: %s"], yes, total, falseKeys(templates))
	yes, total = countTrue(result.atlases)
	Util.Print(L["  atlases: %d of %d; missing: %s"], yes, total, falseKeys(result.atlases))
	yes, total = countTrue(result.events)
	Util.Print(L["  events: %d of %d; unknown: %s"], yes, total, falseKeys(result.events))
	local libraries = result.libraries or {}
	local hbd = libraries.hbd
	Util.Print(
		L["  HereBeDragons: %s; data pack: %s"],
		hbd and string.format("map %s at %s, %s", tostring(hbd.zone.map), tostring(hbd.zone.x), tostring(hbd.zone.y))
			or L["not loaded"],
		tostring(result.addons and result.addons.dataPack)
	)
	if #failed > 0 then
		Util.Print(L["  sections that raised errors: %s"], table.concat(failed, ", "))
	end
	Util.Print(L["Saved to SignpostDB.probe. Type /reload to write it to disk."])
end

ns.Slash:Register("probe", function()
	Probe:Run()
end, L["check this client's API, templates, atlases and events; saves to SignpostDB.probe"])

-- Early observations for the quests section: is the completed-quest list filled at login or only after the first
-- QUEST_LOG_UPDATE? (Only meaningful on a character that has completed quests.)
ns.Events:RegisterMessage("DB_READY", function()
	Probe.early.addonLoaded = { t = GetTime(), completed = countCompleted() }
end)

ns.Events:Register("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
	if not Probe.early.enteringWorld then
		Probe.early.enteringWorld = {
			t = GetTime(),
			completed = countCompleted(),
			isLogin = isLogin,
			isReload = isReload,
		}
	end
end)

local function onFirstQuestLogUpdate(event)
	Probe.early.firstQuestLogUpdate = { t = GetTime(), completed = countCompleted() }
	ns.Events:Unregister(event, onFirstQuestLogUpdate)
end
ns.Events:Register("QUEST_LOG_UPDATE", onFirstQuestLogUpdate)
