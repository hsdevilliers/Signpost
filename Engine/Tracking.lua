-- ns.Tracking: the quest log's tracked quests follow the current step (user, 2026-10-20). The quest tracker and the
-- minimap then show the quests of the step and the tracker shows their progress, which is why the step frame lists the
-- quests and leaves their objectives to the quest log. When a step becomes current, every other tracked quest is
-- untracked and the quests the step is about are tracked: those of its `.complete` and `.turnin` directives that are in
-- the quest log. A step that names no quest in the log (a pick-up, a trip) leaves the tracking as it is.
--
-- It does not fight the player. The quest log is looked at again when its set of quests changes (a quest accepted or
-- removed) while the step is current, and only then: the new quest is untracked unless the step is about it. If one of
-- the quests the log already had has been tracked or untracked since this module last set the tracking, it stays hands
-- off until the next step (the game tracking a quest by itself as its progress changes looks the same as the player
-- doing it, and is treated alike). It acts only while a guide is active and the setting is on, and it does not give the
-- player's own tracking back afterwards (v1): what was tracked before is not remembered.
--
-- Client API, retail shape (none of it is verified on Forever: docs/FOREVER-API-NOTES.md "Open probes"):
--   C_QuestLog.GetNumQuestWatches(), C_QuestLog.GetQuestIDForQuestWatchIndex(i), C_QuestLog.GetQuestWatchType(questID),
--   C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Manual), C_QuestLog.RemoveQuestWatch(questID) and, for the
--   first unfinished quest of the step, C_SuperTrack.SetSuperTrackedQuestID(questID). Where C_QuestLog has no
--   AddQuestWatch or RemoveQuestWatch, the Classic shape on quest log indexes: AddQuestWatch(index),
--   RemoveQuestWatch(index), IsQuestWatched(index), GetNumQuestWatches(), GetQuestIndexForWatch(i). Every call runs
--   under Util.Call, so a missing or failing function costs this feature and never the step engine.
local ADDON_NAME, ns = ...
local Util = ns.Util

local Tracking = {}
ns.Tracking = Tracking

-- Whether the tracker follows the step until the player chooses. The one place the default lives: only the player's own
-- choice is saved (SignpostDB.settings.trackStepQuests), so changing this changes it for everyone who has not chosen.
Tracking.DEFAULT_ENABLED = true

-- The directives that say which quests a step is about.
local NAMED = { complete = true, turnin = true }

-- What this module did for the step in hand: { step, known = { [questID] = true } (the quests the log had when it
-- looked), left = { [questID] = true } (the tracked ones among them once it was done; nil when it changed nothing),
-- manual = true once the player changed the tracking by hand }. Replaced whenever a step becomes current.
Tracking.state = {}

-- The client's watch list -------------------------------------------------------------------------------------------

-- The number of a quest in the quest log (headers count), or nil.
local function logIndex(questID)
	local log = C_QuestLog
	if type(log) ~= "table" then
		return nil
	end
	local index = Util.Call(log.GetLogIndexForQuestID, questID)
	if type(index) == "number" and index > 0 then
		return index
	end
	local count = Util.Call(log.GetNumQuestLogEntries)
	for i = 1, type(count) == "number" and count or 0 do
		local info = Util.Call(log.GetInfo, i)
		if type(info) == "table" and not info.isHeader and info.questID == questID then
			return i
		end
	end
end

-- The quest at a number of the quest log, or nil.
local function questAt(index)
	local log = C_QuestLog
	if type(log) ~= "table" then
		return nil
	end
	local questID = Util.Call(log.GetQuestIDForLogIndex, index)
	if type(questID) ~= "number" then
		local info = Util.Call(log.GetInfo, index)
		questID = type(info) == "table" and info.questID
	end
	if type(questID) == "number" and questID > 0 then
		return questID
	end
end

-- The watch list behind one shape: { add(questID), remove(questID), watched(questID) -> boolean, list() -> { questID,
-- ... } or nil when the client cannot list it }; nil when the client has neither shape.
-- VERIFY(beta): which of these functions exist on Forever, what GetQuestWatchType returns for a quest nobody tracks,
-- and that the list reads back an AddQuestWatch or RemoveQuestWatch at once (before the event).
local function retailWatch()
	local log = C_QuestLog
	if type(log) ~= "table" or type(log.AddQuestWatch) ~= "function" or type(log.RemoveQuestWatch) ~= "function" then
		return nil
	end
	local manual = Enum and Enum.QuestWatchType and Enum.QuestWatchType.Manual
	return {
		add = function(questID)
			if manual ~= nil then
				Util.Call(log.AddQuestWatch, questID, manual)
			else
				Util.Call(log.AddQuestWatch, questID)
			end
		end,
		remove = function(questID)
			Util.Call(log.RemoveQuestWatch, questID)
		end,
		watched = function(questID)
			local watchType = Util.Call(log.GetQuestWatchType, questID)
			return watchType ~= nil and watchType ~= false
		end,
		list = function()
			local count = Util.Call(log.GetNumQuestWatches)
			if type(count) ~= "number" or type(log.GetQuestIDForQuestWatchIndex) ~= "function" then
				return nil
			end
			local ids = {}
			for i = 1, count do
				local questID = Util.Call(log.GetQuestIDForQuestWatchIndex, i)
				if type(questID) == "number" and questID > 0 then
					ids[#ids + 1] = questID
				end
			end
			return ids
		end,
	}
end

local function classicWatch()
	if type(AddQuestWatch) ~= "function" or type(RemoveQuestWatch) ~= "function" then
		return nil
	end
	return {
		add = function(questID)
			local index = logIndex(questID)
			if index then
				Util.Call(AddQuestWatch, index)
			end
		end,
		remove = function(questID)
			local index = logIndex(questID)
			if index then
				Util.Call(RemoveQuestWatch, index)
			end
		end,
		watched = function(questID)
			local index = logIndex(questID)
			return index ~= nil and Util.Call(IsQuestWatched, index) and true or false
		end,
		list = function()
			local count = Util.Call(GetNumQuestWatches)
			if type(count) ~= "number" or type(GetQuestIndexForWatch) ~= "function" then
				return nil
			end
			local ids = {}
			for i = 1, count do
				local index = Util.Call(GetQuestIndexForWatch, i)
				local questID = index and questAt(index)
				if questID then
					ids[#ids + 1] = questID
				end
			end
			return ids
		end,
	}
end

local function watchApi()
	return retailWatch() or classicWatch()
end

-- The tracked quests, as a list: the client's, or when it cannot list them, those of the quest log it says are tracked.
local function watchedQuests(api, log)
	local ids = api.list()
	if ids then
		return ids
	end
	ids = {}
	for questID in pairs(log) do
		if api.watched(questID) then
			ids[#ids + 1] = questID
		end
	end
	return ids
end

-- The tracked quests that are in the log, as a set.
local function watchedAmong(api, log)
	local set = {}
	for _, questID in ipairs(watchedQuests(api, log)) do
		if log[questID] then
			set[questID] = true
		end
	end
	return set
end

-- The step and the quest log -----------------------------------------------------------------------------------------

-- Every quest in the quest log, as a set (Engine/Context.lua), or nil without a context to ask.
local function logSet()
	local context = ns.Context
	if not (context and type(context.QuestLog) == "function") then
		return nil
	end
	local log = Util.Call(context.QuestLog, context)
	if type(log) ~= "table" then
		return nil
	end
	local set = {}
	for questID in pairs(log) do
		set[questID] = true
	end
	return set
end

local function sameSet(a, b)
	if a == nil or b == nil then
		return false
	end
	for key in pairs(a) do
		if not b[key] then
			return false
		end
	end
	for key in pairs(b) do
		if not a[key] then
			return false
		end
	end
	return true
end

-- The quests a step is about, in the order of its directives, each once (in the quest log or not).
function Tracking.NamedQuests(step)
	local quests, seen = {}, {}
	local directives = type(step) == "table" and type(step.directives) == "table" and step.directives or {}
	for _, directive in ipairs(directives) do
		local args = type(directive) == "table" and NAMED[directive.name] and directive.args
		local questID = type(args) == "table" and args.questID
		if type(questID) == "number" and not seen[questID] then
			seen[questID] = true
			quests[#quests + 1] = questID
		end
	end
	return quests
end

local function guideActive()
	local progress = ns.Progress
	return progress ~= nil and type(progress.Guide) == "function" and progress:Guide() ~= nil
end

local function currentStep()
	local progress = ns.Progress
	if guideActive() and type(progress.Current) == "function" then
		return (progress:Current())
	end
end

-- Whether the tracker follows the step: the player's choice, else the default.
function Tracking:Enabled()
	local settings = ns.db and ns.db.settings
	local chosen = type(settings) == "table" and settings.trackStepQuests
	if type(chosen) == "boolean" then
		return chosen
	end
	return Tracking.DEFAULT_ENABLED
end

-- The player's choice (Journal > Settings). Turned on, it takes effect for the current step at once; turned off, it
-- leaves the tracking as it is.
function Tracking:SetEnabled(enabled)
	if not (ns.db and type(ns.db.settings) == "table") then
		return
	end
	ns.db.settings.trackStepQuests = enabled and true or false
	if enabled then
		local step = currentStep()
		if step then
			self:Begin(step)
		end
	end
end

-- Setting the tracking -----------------------------------------------------------------------------------------------

-- Focus for the first quest that is not complete yet: where the tracker's arrow points.
-- VERIFY(beta): C_SuperTrack.SetSuperTrackedQuestID exists on Forever and does what it does on Mainline.
local function superTrack(quests)
	local super, context = C_SuperTrack, ns.Context
	if type(super) ~= "table" or type(super.SetSuperTrackedQuestID) ~= "function" then
		return
	end
	for _, questID in ipairs(quests) do
		if not (context and type(context.QuestReady) == "function" and context:QuestReady(questID)) then
			Util.Call(super.SetSuperTrackedQuestID, questID)
			return
		end
	end
end

-- Untracks every quest the step is not about and tracks those it is about (and the log has); remembers what it left.
-- `focus`: also point the tracker at the first quest of the step that is not complete.
local function follow(step, focus)
	local state = Tracking.state
	local log, api = logSet(), watchApi()
	state.known, state.left = log, nil
	if not (log and api) then
		return
	end
	local quests, wanted = {}, {}
	for _, questID in ipairs(Tracking.NamedQuests(step)) do
		if log[questID] then
			quests[#quests + 1] = questID
			wanted[questID] = true
		end
	end
	if #quests == 0 then
		return
	end
	for _, questID in ipairs(watchedQuests(api, log)) do
		if not wanted[questID] then
			api.remove(questID)
		end
	end
	for _, questID in ipairs(quests) do
		if not api.watched(questID) then
			api.add(questID)
		end
	end
	if focus then
		superTrack(quests)
	end
	state.left = watchedAmong(api, log)
end

-- A step became current (or the setting was turned on while it is): set the tracking for it.
function Tracking:Begin(step)
	Tracking.state = { step = step, manual = false }
	if self:Enabled() and guideActive() then
		ns.SafeCall(follow, step, true)
	end
end

-- Whether one of the quests the log had has been tracked or untracked since `follow` left things as they were.
function Tracking:ChangedByHand(log)
	local state = Tracking.state
	local api = watchApi()
	if not (api and log and state.known and state.left) then
		return false
	end
	local now = watchedAmong(api, log)
	for questID in pairs(state.known) do
		if log[questID] and (state.left[questID] == true) ~= (now[questID] == true) then
			return true
		end
	end
	return false
end

-- The quest log's set of quests may have changed while the step is current: a quest accepted or removed (progress
-- inside a quest changes nothing here). Sets the tracking again unless the player has taken it into their hands.
function Tracking:OnQuestLogChanged()
	local state = Tracking.state
	if not state.step or state.manual or not (self:Enabled() and guideActive()) then
		return
	end
	local log = logSet()
	if not log or sameSet(log, state.known) then
		return
	end
	if self:ChangedByHand(log) then
		state.manual = true
		return
	end
	ns.SafeCall(follow, state.step, false)
end

ns.Events:RegisterMessage("STEP_CHANGED", function(_, step)
	Tracking:Begin(step)
end)

ns.Events:RegisterMessage("CONTEXT_CHANGED", function(_, what)
	if what == "quests" then
		Tracking:OnQuestLogChanged()
	end
end)
