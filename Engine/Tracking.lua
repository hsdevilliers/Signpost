-- ns.Tracking: the quest log's tracked quests follow the current step (user, 2026-10-20). The quest tracker and the
-- minimap then show the quests of the step and the tracker shows their progress, which is why the step frame lists the
-- quests and leaves their objectives to the quest log. When a step becomes current, the quests the step is about are
-- tracked, those of its `.complete` and `.turnin` directives that are in the quest log, and every other tracked quest
-- is untracked: in that order, and the others only once the client has tracked at least one of the step's quests. A
-- client that raises in AddQuestWatch or refuses it (a full tracker looks the same) therefore leaves the player's
-- tracker as it was; the module records that once and stops until the setting is toggled. A step that names no quest in
-- the log (a pick-up, a trip) leaves the tracking as it is.
--
-- It acts only while the setting is on, a guide is active and the step card is shown (the saved flag: /signpost hide
-- and the Journal's "Show the step card"; not the card's hides in combat, when dead or while the Journal is open). With
-- the card hidden it does nothing at all.
--
-- It does not fight the player. The quest log is looked at again when its set of quests changes (a quest accepted or
-- removed; a quest under a collapsed header is still in the log, so collapsing or expanding one changes nothing) while
-- the step is current, and only then: the new quest is untracked unless the step is about it. If one of the quests the
-- log already had has been tracked or untracked since this module last set the tracking, it stays hands off until the
-- next step (the game tracking a quest by itself as its progress changes looks the same as the player doing it, and is
-- treated alike). The same step announced again (a re-parse after a profession plan change or a guide choice) keeps
-- that decision, and otherwise sets the tracking again without moving the focus. It does not give the player's own
-- tracking back afterwards (v1): what was tracked before is not remembered.
--
-- Client API, retail shape (none of it is verified on Forever: docs/FOREVER-API-NOTES.md "Open probes"):
--   C_QuestLog.GetNumQuestWatches(), C_QuestLog.GetQuestIDForQuestWatchIndex(i), C_QuestLog.GetQuestWatchType(questID),
--   C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Manual), C_QuestLog.RemoveQuestWatch(questID) and, for the
--   first unfinished quest of the step, C_SuperTrack.GetSuperTrackedQuestID() and SetSuperTrackedQuestID(questID).
--   Where C_QuestLog has no AddQuestWatch or RemoveQuestWatch, the Classic shape on quest log numbers:
--   AddQuestWatch(number), RemoveQuestWatch(number), IsQuestWatched(number), GetNumQuestWatches(),
--   GetQuestIndexForWatch(i), with C_QuestLog.GetLogIndexForQuestID and GetQuestIDForLogIndex for the numbers. Every
--   call runs under Util.Call, so a missing or failing function costs this feature and never the step engine.
local ADDON_NAME, ns = ...
local Util = ns.Util

local Tracking = {}
ns.Tracking = Tracking

-- Whether the tracker follows the step until the player chooses. The one place the default lives: only the player's own
-- choice is saved (SignpostDB.settings.trackStepQuests), so changing this changes it for everyone who has not chosen.
Tracking.DEFAULT_ENABLED = true

-- Set when the client tracked none of a step's quests: the module does nothing until the setting is toggled.
Tracking.failed = false

-- The directives that say which quests a step is about.
local NAMED = { complete = true, turnin = true }

-- What this module did for the step in hand: { step, known = { [questID] = true } (the quests the log had when it
-- looked), left = { [questID] = true } (the tracked ones among them once it was done; nil when it changed nothing),
-- manual = true once the quests were tracked or untracked by hand, wantFocus = true until the tracker has been pointed
-- at the step's quests once }. Replaced whenever another step becomes current.
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
	if type(questID) ~= "number" or questID <= 0 then
		local info = Util.Call(log.GetInfo, index)
		questID = type(info) == "table" and info.questID
	end
	if type(questID) == "number" and questID > 0 then
		return questID
	end
end

local function contains(list, value)
	for _, item in ipairs(list or {}) do
		if item == value then
			return true
		end
	end
	return false
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
	local function list()
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
	end
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
		-- any watch type counts: Automatic (0) is the game's own tracking, still tracked
		watched = function(questID)
			if type(log.GetQuestWatchType) ~= "function" then
				return contains(list(), questID)
			end
			local watchType = Util.Call(log.GetQuestWatchType, questID)
			return watchType ~= nil and watchType ~= false
		end,
		list = list,
	}
end

local function classicWatch()
	if type(AddQuestWatch) ~= "function" or type(RemoveQuestWatch) ~= "function" then
		return nil
	end
	local function list()
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
			if type(IsQuestWatched) ~= "function" then
				return contains(list(), questID)
			end
			local index = logIndex(questID)
			return index ~= nil and Util.Call(IsQuestWatched, index) and true or false
		end,
		list = list,
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

local function inLog(questID)
	local context = ns.Context
	return context ~= nil and type(context.QuestInLog) == "function" and context:QuestInLog(questID) and true or false
end

-- Every quest in the quest log, as a set, or nil without a context to ask. A quest under a collapsed quest log header
-- is not among the ones Context walks but is still in the log (Context:QuestInLog asks the client), so the quests of
-- `known` stay in the set as long as the log still has them: collapsing or expanding a header changes nothing.
local function logSet(known)
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
	for questID in pairs(known or {}) do
		if not set[questID] and inLog(questID) then
			set[questID] = true
		end
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

-- Whether the step card is shown: the saved flag (/signpost hide, the Journal's "Show the step card"), not the hides
-- the card does by itself in combat, when dead or while the Journal is open.
local function cardShown()
	local card = ns.db and ns.db.stepFrame
	return not (type(card) == "table" and card.shown == false)
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

-- Whether the module may touch the client now: the setting is on, a guide is active, the step card is shown and the
-- client did not refuse to track a step's quests.
function Tracking:Active()
	return self:Enabled() and not Tracking.failed and guideActive() and cardShown()
end

-- The player's choice (Journal > Settings). Toggled either way it forgets that the client refused; turned on, it takes
-- effect for the current step at once (when the module may act); turned off, it leaves the tracking as it is.
function Tracking:SetEnabled(enabled)
	if not (ns.db and type(ns.db.settings) == "table") then
		return
	end
	ns.db.settings.trackStepQuests = enabled and true or false
	Tracking.failed = false
	if enabled then
		local step = currentStep()
		if step then
			self:Begin(step, true)
		end
	end
end

-- Setting the tracking -----------------------------------------------------------------------------------------------

-- Focus for the first quest that is not complete yet: where the tracker's arrow points. Left alone when it already
-- points at one of the step's quests.
-- VERIFY(beta): C_SuperTrack.GetSuperTrackedQuestID and SetSuperTrackedQuestID exist on Forever and do what they do on
-- Mainline.
local function superTrack(quests)
	local super, context = C_SuperTrack, ns.Context
	if type(super) ~= "table" or type(super.SetSuperTrackedQuestID) ~= "function" then
		return
	end
	if contains(quests, Util.Call(super.GetSuperTrackedQuestID)) then
		return
	end
	for _, questID in ipairs(quests) do
		if not (context and type(context.QuestReady) == "function" and context:QuestReady(questID)) then
			Util.Call(super.SetSuperTrackedQuestID, questID)
			return
		end
	end
end

-- The client tracked none of a step's quests: the module stops (until the setting is toggled) and says so once.
local function giveUp()
	Tracking.failed = true
	if ns.Errors and ns.Errors.Record then
		ns.Errors:Record(
			ADDON_NAME
				.. ": quest tracking stopped: the client did not track any quest of the step (AddQuestWatch raised or"
				.. " refused); the tracker was left as it was. Toggle the setting to try again."
		)
	end
end

-- Tracks the quests of the step that the log has, then, once the client has tracked at least one, untracks every other
-- quest; remembers what it left. The first application after a step began also points the tracker at the first quest of
-- the step that is not complete.
local function follow(step)
	local state = Tracking.state
	local log, api = logSet(state.known), watchApi()
	state.known, state.left = log, nil
	if not (log and api) then
		return
	end
	local quests, wanted = {}, {}
	for _, questID in ipairs(Tracking.NamedQuests(step)) do
		if inLog(questID) then
			quests[#quests + 1] = questID
			wanted[questID] = true
			log[questID] = true
		end
	end
	if #quests == 0 then
		return
	end
	for _, questID in ipairs(quests) do
		if not api.watched(questID) then
			api.add(questID)
		end
	end
	local tracked = false
	for _, questID in ipairs(quests) do
		tracked = tracked or api.watched(questID)
	end
	if not tracked then
		giveUp()
		return
	end
	for _, questID in ipairs(watchedQuests(api, log)) do
		if not wanted[questID] then
			api.remove(questID)
		end
	end
	-- a full tracker may have refused some of them before; the others are gone now
	for _, questID in ipairs(quests) do
		if not api.watched(questID) then
			api.add(questID)
		end
	end
	if state.wantFocus then
		state.wantFocus = false
		superTrack(quests)
	end
	state.left = watchedAmong(api, log)
end

local function announcedAgain(step)
	local before = Tracking.state.step
	return type(step) == "table" and step.id ~= nil and type(before) == "table" and before.id == step.id
end

-- A step became current (or the setting was turned on while it is: `force`): set the tracking for it. The same step
-- announced again (the engine parsed the guide again) is not a new start: a decision to stay hands off holds, and
-- otherwise the tracking is set again without moving the focus.
function Tracking:Begin(step, force)
	local state = Tracking.state
	if not force and announcedAgain(step) then
		state.step = step
		if state.manual then
			state.known = logSet(state.known)
		elseif self:Active() then
			ns.SafeCall(follow, step)
		end
		return
	end
	Tracking.state = { step = step, manual = false, wantFocus = true }
	if self:Active() then
		ns.SafeCall(follow, step)
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
	if not state.step or state.manual or not self:Active() then
		return
	end
	local log = logSet(state.known)
	if not log or sameSet(log, state.known) then
		return
	end
	if self:ChangedByHand(log) then
		state.manual = true
		return
	end
	ns.SafeCall(follow, state.step)
end

ns.Events:RegisterMessage("STEP_CHANGED", function(_, step)
	Tracking:Begin(step)
end)

ns.Events:RegisterMessage("CONTEXT_CHANGED", function(_, what)
	if what == "quests" then
		Tracking:OnQuestLogChanged()
	end
end)
