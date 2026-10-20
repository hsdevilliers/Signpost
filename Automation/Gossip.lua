-- Automation: gossip (PLAN §3.4). Off by default (`gossip`). GOSSIP_SHOW first lets the quest automation select a quest
-- the guide wants; otherwise a single-option gossip is selected when the current step is an NPC visit, and during a
-- `.hs` step the innkeeper's "make this inn your home" option is selected and the CONFIRM_BINDER popup confirmed.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local Automation = ns.Automation

local Gossip = {}
Automation.Gossip = Gossip

-- Steps that are visits to an NPC: a single gossip option is only auto-selected on these (never on a step that
-- merely walks past, so the player's own browsing is left alone).
local VISIT = { "accept", "turnin", "train", "trainprof", "buy", "fly", "hs" }

-- The home binder's gossip icon (FOREVER-API-NOTES: the file exists on Forever).
local BINDER_ICON = "Interface\\GossipFrame\\BinderGossipIcon"
local CONFIRM_RETRY = { 0, 0.2, 0.6 } -- seconds after the option was selected; the popup may show a frame later

local function plain(value)
	if type(value) == "number" and not Util.IsSecret(value) then
		return value
	end
end

local function options()
	local list = C_GossipInfo and Util.Call(C_GossipInfo.GetOptions)
	return type(list) == "table" and list or {}
end

local function quests()
	local gossip = C_GossipInfo
	local count = 0
	for _, getter in ipairs({ gossip and gossip.GetAvailableQuests, gossip and gossip.GetActiveQuests }) do
		local list = Util.Call(getter)
		count = count + (type(list) == "table" and #list or 0)
	end
	return count
end

-- Selects one option. VERIFY(beta): the field names of C_GossipInfo.GetOptions() entries (gossipOptionID, orderIndex)
-- and C_GossipInfo.SelectOption / SelectOptionByIndex (open probe).
local function select_(option)
	local gossip = C_GossipInfo
	local id = plain(option.gossipOptionID)
	if id and Automation.Try(gossip.SelectOption, id) then
		return true
	end
	local index = plain(option.orderIndex)
	if index and gossip.SelectOptionByIndex then
		return Automation.Try(gossip.SelectOptionByIndex, index)
	end
	return false
end

local function binderIconID()
	return plain(Util.Call(GetFileIDFromPath, BINDER_ICON))
end

-- true for the innkeeper's option that sets the hearth: the binder icon, else the text ("Make this inn your home.").
function Gossip.IsBinderOption(option)
	local icon = option.icon
	if icon ~= nil and (icon == BINDER_ICON or (plain(icon) and icon == binderIconID())) then
		return true
	end
	local name = type(option.name) == "string" and not Util.IsSecret(option.name) and option.name:lower() or ""
	return name:find(L["inn"], 1, true) ~= nil and name:find(L["home"], 1, true) ~= nil
end

-- The `.hs` directive of the current step that is not done yet.
local function pendingHearth()
	for _, entry in ipairs(Automation:Directives("hs")) do
		if not Automation:Satisfied(entry) then
			return entry
		end
	end
end

-- Confirms the "make this inn your home" popup. The notes say ConfirmBinder() does not exist on this client, so the
-- popup's own accept button is clicked (what the player would do), then the interaction manager, then ConfirmBinder
-- should a build have it.
-- VERIFY(beta): which of these works on Forever (open probe "Setting the hearth without ConfirmBinder").
function Gossip.ConfirmBinder()
	local find = Util.Resolve("StaticPopup_FindVisible")
	local popup = find and Util.Call(find, "CONFIRM_BINDER")
	if type(popup) == "table" then
		local button = popup.button1 or (popup.GetName and _G[tostring(popup:GetName()) .. "Button1"])
		if type(button) == "table" and Automation.Try(button.Click, button) then
			return "popup"
		end
	end
	local manager, enum = C_PlayerInteractionManager, Enum and Enum.PlayerInteractionType
	if manager and manager.ConfirmationInteraction and enum and enum.Binder then
		if Automation.Try(manager.ConfirmationInteraction, enum.Binder) then
			return "manager"
		end
	end
	local legacy = Util.Resolve("ConfirmBinder")
	if legacy and Automation.Try(legacy) then
		return "legacy"
	end
	return nil
end

-- GOSSIP_SHOW
function Gossip:OnShow()
	if not Automation:Enabled("gossip") and not Automation:Enabled("quests") and not Automation:Enabled("turnIn") then
		return
	end
	if Automation:Blocked() then
		return
	end
	-- the quest automation has its own toggles and goes first
	if Automation.Quests and Automation.Quests:OnGossip() then
		return
	end
	if not Automation:Enabled("gossip") then
		return
	end
	local list = options()
	local hearth = pendingHearth()
	if hearth then
		for _, option in ipairs(list) do
			if type(option) == "table" and Gossip.IsBinderOption(option) and select_(option) then
				return
			end
		end
	end
	-- a lone option, with no quests to pick, on a step that is a visit to an NPC
	if #list == 1 and quests() == 0 and Automation:Asks(unpack(VISIT)) and type(list[1]) == "table" then
		select_(list[1])
	end
end

-- CONFIRM_BINDER: only for the home we just asked for, only during a `.hs` step.
function Gossip:OnConfirmBinder()
	if not (Automation:Allowed("gossip") and pendingHearth()) then
		return
	end
	Gossip.confirmed = nil
	for _, delay in ipairs(CONFIRM_RETRY) do
		C_Timer.After(delay, function()
			ns.SafeCall(function()
				if Gossip.confirmed or not Automation:Allowed("gossip") or not pendingHearth() then
					return
				end
				if Gossip.ConfirmBinder() then
					Gossip.confirmed = true
				end
			end)
		end)
	end
end

ns.Events:Register("GOSSIP_SHOW", function()
	Gossip:OnShow()
end)
ns.Events:Register("CONFIRM_BINDER", function()
	Gossip:OnConfirmBinder()
end)
