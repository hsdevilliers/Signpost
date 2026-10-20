-- Automation: quest accept and turn-in (PLAN §3.4). Off by default (`quests`, `turnIn`); only quests the current guide
-- step asks for (`.accept`, `.turnin`) unless the player chose the wider modes; never a quest the guide `#skipquest`s.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local Automation = ns.Automation

local Quests = {}
Automation.Quests = Quests

Quests.WAIT_SECONDS = 2 -- how long an uncached reward item may take before we stop and let the player choose

local function plain(value)
	if type(value) == "number" and not Util.IsSecret(value) and value == value then
		return value
	end
end

local function itemIDFromLink(link)
	if type(link) == "string" and not Util.IsSecret(link) then
		return tonumber(link:match("item:(%d+)"))
	end
end

-- What the current step asks for -------------------------------------------------------------------------------------

local function questSet(name)
	local set = {}
	for _, entry in ipairs(Automation:Directives(name)) do
		local questID = plain(entry.args.questID)
		if questID then
			set[questID] = true
		end
	end
	return set
end

-- VERIFY(beta): C_QuestLog.IsQuestTrivial exists; unknown counts as not trivial (the wide mode is opt-in).
local function isTrivial(questID)
	local api = C_QuestLog and C_QuestLog.IsQuestTrivial
	if api then
		return Util.Call(api, questID) == true
	end
	return false
end

function Quests:ShouldAccept(questID, trivial)
	if not plain(questID) or Automation:GuideSkips(questID) then
		return false
	end
	if questSet("accept")[questID] then
		return true
	end
	return Automation:Settings().acceptAll == true and not trivial
end

function Quests:ShouldTurnIn(questID)
	if not plain(questID) then
		return false
	end
	return questSet("turnin")[questID] == true or Automation:Settings().turnInAll == true
end

local function questReady(questID)
	local api = C_QuestLog and C_QuestLog.IsComplete
	if api then
		return Util.Call(api, questID) == true
	end
	return ns.Context ~= nil and ns.Context:QuestReady(questID) == true
end

-- Accept -------------------------------------------------------------------------------------------------------------

-- QUEST_DETAIL: the quest's own window.
function Quests:OnDetail()
	if not Automation:Allowed("quests") then
		return
	end
	-- VERIFY(beta): a quest that auto-accepts (QuestGetAutoAccept) needs no AcceptQuest.
	if Util.Call(QuestGetAutoAccept) == true then
		return
	end
	local questID = plain(Util.Call(GetQuestID))
	if questID and self:ShouldAccept(questID, isTrivial(questID)) then
		-- VERIFY(beta): AcceptQuest() from an addon event handler is not protected (open probe, FOREVER-API-NOTES).
		Util.Call(AcceptQuest)
	end
end

-- Chooses among the open NPC's quests (the old greeting frame: indexes; the gossip frame: quest IDs). Turning in
-- comes first (it frees the log), then accepting. Returns true when it selected one.
function Quests:OnGreeting()
	if Automation:Enabled("turnIn") and not Automation:Blocked() then
		for index = 1, plain(Util.Call(GetNumActiveQuests)) or 0 do
			local questID = plain(Util.Call(GetActiveQuestID, index))
			if questID and self:ShouldTurnIn(questID) and questReady(questID) then
				Util.Call(SelectActiveQuest, index)
				return true
			end
		end
	end
	if Automation:Allowed("quests") then
		for index = 1, plain(Util.Call(GetNumAvailableQuests)) or 0 do
			-- GetAvailableQuestInfo: isTrivial, frequency, isRepeatable, isLegendary, questID (VERIFY(beta): the fifth value).
			local info = Util.Pack(Util.Call(GetAvailableQuestInfo, index))
			local questID = plain(info[5])
			if questID and self:ShouldAccept(questID, info[1] == true) then
				Util.Call(SelectAvailableQuest, index)
				return true
			end
		end
	end
	return false
end

-- GOSSIP_SHOW's quest lists; Gossip.lua calls this first and does its own work only when nothing was selected.
function Quests:OnGossip()
	local gossip = C_GossipInfo
	if not gossip then
		return false
	end
	if Automation:Enabled("turnIn") and not Automation:Blocked() then
		for _, quest in ipairs(Util.Call(gossip.GetActiveQuests) or {}) do
			local questID = type(quest) == "table" and plain(quest.questID)
			-- VERIFY(beta): the entries carry questID and isComplete.
			if questID and self:ShouldTurnIn(questID) and (quest.isComplete == true or questReady(questID)) then
				Util.Call(gossip.SelectActiveQuest, questID)
				return true
			end
		end
	end
	if Automation:Allowed("quests") then
		for _, quest in ipairs(Util.Call(gossip.GetAvailableQuests) or {}) do
			local questID = type(quest) == "table" and plain(quest.questID)
			if questID and self:ShouldAccept(questID, quest.isTrivial == true) then
				Util.Call(gossip.SelectAvailableQuest, questID)
				return true
			end
		end
	end
	return false
end

-- Turn-in ------------------------------------------------------------------------------------------------------------

-- QUEST_PROGRESS: complete the quest when it can be.
function Quests:OnProgress()
	if not Automation:Allowed("turnIn") then
		return
	end
	local questID = plain(Util.Call(GetQuestID))
	if questID and self:ShouldTurnIn(questID) and Util.Call(IsQuestCompletable) == true then
		Util.Call(CompleteQuest)
	end
end

-- The guide's `.reward` for the quest (the current step first, then the whole guide): a choice index, or an item ID
-- looked up among the offered choices. nil when the guide says nothing usable.
function Quests:GuideReward(questID, choices)
	local rewards = {}
	for _, entry in ipairs(Automation:Directives("reward")) do
		rewards[#rewards + 1] = entry.args
	end
	local progress = ns.Progress
	local guide = type(progress) == "table" and type(progress.Guide) == "function" and progress:Guide() or nil
	for _, step in ipairs(guide and guide.steps or {}) do
		for _, directive in ipairs(step.directives or {}) do
			if directive.name == "reward" then
				rewards[#rewards + 1] = directive.args
			end
		end
	end
	for _, args in ipairs(rewards) do
		if type(args) == "table" and args.questID == questID then
			if args.choice and args.choice >= 1 and args.choice <= choices then
				return args.choice
			end
			if args.itemID then
				for index = 1, choices do
					if itemIDFromLink(Util.Call(GetQuestItemLink, "choice", index)) == args.itemID then
						return index
					end
				end
			end
		end
	end
end

-- The offered choices' vendor values: best (index), or unknown (a list of item IDs, false entries for a missing
-- link) when any value is not available yet. Value = sell price of one × the quantity offered.
-- VERIFY(beta): C_Item.GetItemInfo(link) returns sellPrice as its 11th value without a wait, and never as a secret.
function Quests:ChoiceValues(choices)
	local best, bestValue, unknown = nil, -1, {}
	for index = 1, choices do
		local link = Util.Call(GetQuestItemLink, "choice", index)
		local info = link and Util.Pack(Util.Call(C_Item and C_Item.GetItemInfo, link)) or { n = 0 }
		local sell = plain(info[11])
		if sell then
			local quantity = plain(select(3, Util.Call(GetQuestItemInfo, "choice", index))) or 1
			if sell * quantity > bestValue then
				best, bestValue = index, sell * quantity
			end
		else
			unknown[#unknown + 1] = itemIDFromLink(link) or false
		end
	end
	return best, bestValue, unknown
end

local function say(text)
	Util.Print(text)
end

-- Turns the open quest in. `final`: the wait for item data is over, so an unknown value means stop.
function Quests:TurnInReward(final)
	if not Automation:Allowed("turnIn") then
		return
	end
	local questID = plain(Util.Call(GetQuestID))
	if not questID or not self:ShouldTurnIn(questID) then
		return
	end
	local choices = plain(Util.Call(GetNumQuestChoices)) or 0
	if choices <= 1 then
		-- 0 when there is no choice, else the only one
		Util.Call(GetQuestReward, choices == 1 and 1 or 0)
		return
	end
	local index = self:GuideReward(questID, choices)
	if not index then
		if Automation:Settings().rewardAsk then
			return -- the player chose "always let me choose"
		end
		local best, value, unknown = self:ChoiceValues(choices)
		if #unknown > 0 then
			if final then
				say(L["Some reward values are not known yet: choose the reward yourself."])
				return
			end
			self:WaitForItems(questID, unknown)
			return
		end
		if value <= 0 then
			say(L["None of the rewards has a vendor value: choose the reward yourself."])
			return
		end
		index = best
	end
	-- VERIFY(beta): GetQuestReward(index) from an addon event handler is not protected (open probe).
	Util.Call(GetQuestReward, index)
end

-- Asks for the uncached items and tries again when they arrive, or once WAIT_SECONDS have passed (the last time).
function Quests:WaitForItems(questID, itemIDs)
	if self.pending and self.pending.questID == questID then
		return -- already waiting: the timer below ends it
	end
	local pending = { questID = questID, ids = {} }
	self.pending = pending
	for _, itemID in ipairs(itemIDs) do
		if itemID then
			pending.ids[itemID] = true
			-- VERIFY(beta): C_Item.RequestLoadItemDataByID answers with ITEM_DATA_LOAD_RESULT(itemID, success).
			Util.Call(C_Item and C_Item.RequestLoadItemDataByID, itemID)
		end
	end
	C_Timer.After(Quests.WAIT_SECONDS, function()
		ns.SafeCall(function()
			if Quests.pending ~= pending then
				return
			end
			Quests.pending = nil
			if plain(Util.Call(GetQuestID)) == questID then
				Quests:TurnInReward(true)
			end
		end)
	end)
end

local function onItemDataLoaded(_, itemID)
	local pending = Quests.pending
	if not (pending and pending.ids[itemID]) then
		return
	end
	if plain(Util.Call(GetQuestID)) ~= pending.questID then
		Quests.pending = nil
		return
	end
	pending.ids[itemID] = nil
	-- another item still missing: keep waiting; otherwise decide now (an unknown value left means stop)
	if next(pending.ids) == nil then
		Quests.pending = nil
		Quests:TurnInReward(true)
	end
end

local function onFinished()
	Quests.pending = nil
end

ns.Events:Register("QUEST_DETAIL", function()
	Quests:OnDetail()
end)
ns.Events:Register("QUEST_GREETING", function()
	Quests:OnGreeting()
end)
ns.Events:Register("QUEST_PROGRESS", function()
	Quests:OnProgress()
end)
ns.Events:Register("QUEST_COMPLETE", function()
	Quests.pending = nil
	Quests:TurnInReward(false)
end)
ns.Events:Register("QUEST_FINISHED", onFinished)
ns.Events:Register("ITEM_DATA_LOAD_RESULT", onItemDataLoaded)
