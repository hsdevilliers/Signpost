-- ns.Tracking: the quest log's tracked quests follow the current step (user, 2026-10-20). The quest tracker and the
-- minimap then show the quests of the step and the tracker shows their progress, which is why the step frame lists the
-- quests and leaves their objectives to the quest log. When a step becomes current, the quests the step is about are
-- tracked, those of its `.complete` and `.turnin` directives that are in the quest log, and every other tracked quest
-- is untracked: in that order, and the others only once the client has tracked at least one of the step's quests. A
-- step that names no quest in the log (a pick-up, a trip) leaves the tracking as it is.
--
-- It acts only while the setting is on, a guide is active and the step card is shown (the saved flag: /signpost hide
-- and the Journal's "Show the step card"; not the card's hides in combat, when dead or while the Journal is open), and
-- not while /signpost tracking test runs. Otherwise it does nothing at all.
--
-- ONE STATE MACHINE (Tracking.state.mode, for the step in hand; the back-off and the restore point live beside it)
--
--   idle       nothing is managed: no step yet; the module could not act when the step began (setting off, no guide,
--              step card hidden); the client has no watch functions; or the tracker was just given back.
--   following  the module manages the tracker for the step: the step's quests are tracked and the others are not (a
--              step that names no quest in the log leaves the tracker alone). It sets the tracker again when the quest
--              log's set of quests changes.
--   player     backed off for the player: they tracked or untracked a quest by hand during this step. Hands off until
--              the next step. Saved (SignpostCharDB.tracking.handsOff = the step's id), so a reload keeps it.
--   client     backed off for the client: it tracked none of the step's quests (AddQuestWatch raised or refused it; a
--              full tracker looks the same, and so does a client that applies a watch late). The tracker was left as it
--              was. It tries again 5, 15, 45, 120 and 300 s after the 1st to 5th failure in a row, on a timer, and at a
--              step or a change of the quest log's quests that comes after the back-off, never earlier: it does not
--              hammer the client. A success ends the streak.
--   restoring  transient, while the player's earlier tracking is given back (Tracking:Release).
--
--   event                                      moves
--   STEP_CHANGED, another step                 any -> a new start: the "player" fact is forgotten (and its saved copy),
--                                              the tracker is set for the step: idle -> following | client
--   STEP_CHANGED, the same step again          player stays; otherwise the tracker is set again, without the focus
--                                              (the first one after a reload honours the saved "player" fact)
--   CONTEXT_CHANGED("quests"), when the        following -> player when the player changed the tracker meanwhile, else
--     SET of quests changed (accepted,         the tracker is set again; client -> following when a try succeeds
--     removed)
--   QUEST_WATCH_LIST_CHANGED (where it is)     following -> player at once when the player did it; client: a retry
--   PLAYER_LOGOUT (also a reload)              following -> player when the player changed it since the last look
--   the timer of the back-off                  client -> following when the try succeeds, else the next back-off
--   Tracking:SetEnabled(true)                  any -> a new start, back-off forgotten
--   Tracking:SetEnabled(false); GUIDE_SELECTED any -> restoring -> idle
--     with no guide active
--   the step card shown again                  any -> a new start (SetShown(true) or Reset turn its saved flag on)
--
--   SAVED (SignpostCharDB.tracking)
--   before    the quests the player had tracked when the module first changed the tracker, in tracker order, until
--             they are given back; taken once. left: what the module left tracked at its last write. handsOff: above.
--
-- WHO CHANGED THE TRACKER. The module's own writes are known: after each one it reads the tracker back and keeps that
-- as `left`. Whatever differs from `left` for a quest the log already had when the module last looked was done by
-- somebody else, and the game is told from the player in this order: the watch type (Enum.QuestWatchType.Automatic is
-- the game's own tracking, Manual is not); else, when the change is seen as it happens (QUEST_WATCH_LIST_CHANGED), a
-- quest the game accepted or advanced within GAME_WINDOW seconds before it (QUEST_ACCEPTED, QUEST_WATCH_UPDATE); else
-- it is the player's. A quest the game tracks that way is simply one of "the others" at the next application. Without
-- watch types and without that event a change by the game still looks like the player's (the old limit): the module
-- backs off, the player is never fought. A quest that arrives (accepted) is not compared: it is untracked unless the
-- step is about it.
--
-- GIVING BACK. The first time the module is about to change the tracker it remembers what the player had tracked
-- (`before`). When the setting is turned off or the guide is gone, Tracking:Release puts that back, once: what the
-- module added and the player did not untrack since is untracked, what it removed and the player did not track again
-- since is tracked again; quests the player changed after the module's last write are theirs and stay as they are; only
-- quests still in the log count, and when none of the earlier tracking is left the tracker stays as it is rather than
-- ending up empty. It says what it did in chat.
--
-- Client API, retail shape (none of it is verified on Forever: docs/FOREVER-API-NOTES.md "Open probes"; `/signpost
-- tracking test` makes the client answer):
--   C_QuestLog.GetNumQuestWatches(), C_QuestLog.GetQuestIDForQuestWatchIndex(i), C_QuestLog.GetQuestWatchType(questID),
--   C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Manual), C_QuestLog.RemoveQuestWatch(questID) and, for the
--   first unfinished quest of the step, C_SuperTrack.GetSuperTrackedQuestID() and SetSuperTrackedQuestID(questID).
--   Where C_QuestLog has no AddQuestWatch or RemoveQuestWatch, the Classic shape on quest log numbers:
--   AddQuestWatch(number), RemoveQuestWatch(number), IsQuestWatched(number), GetNumQuestWatches(),
--   GetQuestIndexForWatch(i), with C_QuestLog.GetLogIndexForQuestID and GetQuestIDForLogIndex for the numbers. Every
--   call runs under Util.Call (or pcall in the test), so a missing or failing function costs this feature and never the
--   step engine.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Tracking = {}
ns.Tracking = Tracking

-- Whether the tracker follows the step until the player chooses. The one place the default lives: only the player's own
-- choice is saved (SignpostDB.settings.trackStepQuests), so changing this changes it for everyone who has not chosen.
Tracking.DEFAULT_ENABLED = true

-- The directives that say which quests a step is about.
local NAMED = { complete = true, turnin = true }

-- Seconds to wait before the next try after the 1st, 2nd, ... failure in a row to track a step's quests; the last one
-- repeats. The first #BACKOFF failures each arm one timer; after that only a step or a change of the quest log's quests
-- that comes later than the last delay tries again.
local BACKOFF = { 5, 15, 45, 120, 300 }
local EPSILON = 0.01
-- A watch change seen this soon after the game accepted a quest or advanced one is the game's own tracking, when the
-- client cannot say by the watch type.
local GAME_WINDOW = 2
-- Watch list events that come in a bunch (the module's own writes make several) are looked at once, this long after
-- the first.
local WATCH_DELAY = 0.3
-- How many observations of the game's own tracking are kept for the developer (SignpostDB.probe.trackingSeen).
local SEEN_MAX = 12
-- /signpost tracking test: how long it waits for late events and a late read-back, and how many events it keeps.
local TEST_SETTLE = 1.5
local TEST_MAX_EVENTS = 20

-- SignpostCharDB.tracking: see the header. A plain table of numbers and one step id.
ns.SavedVars:RegisterDefaults("char", "tracking", {})

-- What this module is doing for the step in hand: { step, mode, manual (true in mode "player"), wantFocus (true until
-- the tracker has been pointed at the step's quests once), known = { [questID] = true } (the quests the log had when it
-- looked), left = { [questID] = true } (the tracked ones among them after its last write; nil when it wrote nothing
-- for this step), autoLeft = { [questID] = true } (the ones of `left` the game itself tracks) }. Replaced when another
-- step becomes current.
Tracking.state = { mode = "idle", manual = false }

-- The streak of failures to track a step's quests, across steps: { failures, nextTry (GetTime, no try before it),
-- reported (the error log has the entry for this streak) }.
Tracking.backoff = { failures = 0, nextTry = 0, reported = false }

-- When the game last accepted a quest or advanced one (GetTime), and whether /signpost tracking test is running.
Tracking.gameEventAt = nil
Tracking.testing = false

-- Saved record and small helpers --------------------------------------------------------------------------------------

-- SignpostCharDB.tracking, or nil before SavedVariables are ready.
local function record()
	local char = ns.char
	if type(char) ~= "table" then
		return nil
	end
	if type(char.tracking) ~= "table" then
		char.tracking = {}
	end
	return char.tracking
end

local function setOf(list)
	local set = {}
	if type(list) == "table" then
		for _, questID in ipairs(list) do
			if type(questID) == "number" then
				set[questID] = true
			end
		end
	end
	return set
end

local function listOf(set)
	local list = {}
	for questID in pairs(set or {}) do
		list[#list + 1] = questID
	end
	table.sort(list)
	return list
end

local function contains(list, value)
	for _, item in ipairs(list or {}) do
		if item == value then
			return true
		end
	end
	return false
end

local function joined(list)
	local parts = {}
	for i, questID in ipairs(list or {}) do
		parts[i] = tostring(questID)
	end
	return #parts > 0 and table.concat(parts, ", ") or nil
end

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

-- The watch list behind one shape: { add(questID), remove(questID), watched(questID) -> boolean, list() -> { questID,
-- ... } or nil when the client cannot list it, count() -> the number of watched quests or nil, watchType(questID) ->
-- what the client says the watch type is or nil, kind(questID) -> "auto" (the game's own tracking), "manual" or nil
-- when the client cannot say, tryAdd(questID[, watchType]) and tryRemove(questID) -> pcall's results, for the test };
-- nil when the client has neither shape.
-- VERIFY(beta): which of these functions exist on Forever, what GetQuestWatchType returns for a quest nobody tracks,
-- that Enum.QuestWatchType has Automatic and Manual, and that the list reads back an AddQuestWatch or RemoveQuestWatch
-- at once (before the event).
local function retailWatch()
	local log = C_QuestLog
	if type(log) ~= "table" or type(log.AddQuestWatch) ~= "function" or type(log.RemoveQuestWatch) ~= "function" then
		return nil
	end
	local types = Enum and Enum.QuestWatchType
	local manual = type(types) == "table" and types.Manual or nil
	local automatic = type(types) == "table" and types.Automatic or nil
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
	local function watchType(questID)
		return Util.Call(log.GetQuestWatchType, questID)
	end
	local function tryAdd(questID, withType)
		if withType == nil then
			withType = manual
		end
		if withType ~= nil then
			return pcall(log.AddQuestWatch, questID, withType)
		end
		return pcall(log.AddQuestWatch, questID)
	end
	return {
		tryAdd = tryAdd,
		tryRemove = function(questID)
			return pcall(log.RemoveQuestWatch, questID)
		end,
		add = function(questID)
			tryAdd(questID)
		end,
		remove = function(questID)
			Util.Call(log.RemoveQuestWatch, questID)
		end,
		-- any watch type counts: Automatic is the game's own tracking, still tracked
		watched = function(questID)
			if type(log.GetQuestWatchType) ~= "function" then
				return contains(list(), questID)
			end
			local kind = watchType(questID)
			return kind ~= nil and kind ~= false
		end,
		watchType = watchType,
		kind = function(questID)
			if automatic == nil or type(log.GetQuestWatchType) ~= "function" then
				return nil
			end
			local kind = watchType(questID)
			if kind == nil or kind == false then
				return nil
			end
			return kind == automatic and "auto" or "manual"
		end,
		count = function()
			local count = Util.Call(log.GetNumQuestWatches)
			return type(count) == "number" and count or nil
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
	local function tryAdd(questID)
		local index = logIndex(questID)
		if not index then
			return false, "the quest has no number in the quest log"
		end
		return pcall(AddQuestWatch, index)
	end
	local function tryRemove(questID)
		local index = logIndex(questID)
		if not index then
			return false, "the quest has no number in the quest log"
		end
		return pcall(RemoveQuestWatch, index)
	end
	return {
		tryAdd = tryAdd,
		tryRemove = tryRemove,
		add = function(questID)
			tryAdd(questID)
		end,
		remove = function(questID)
			tryRemove(questID)
		end,
		watched = function(questID)
			if type(IsQuestWatched) ~= "function" then
				return contains(list(), questID)
			end
			local index = logIndex(questID)
			return index ~= nil and Util.Call(IsQuestWatched, index) and true or false
		end,
		watchType = function()
			return nil
		end,
		kind = function()
			return nil
		end,
		count = function()
			local count = Util.Call(GetNumQuestWatches)
			return type(count) == "number" and count or nil
		end,
		list = list,
	}
end

-- The watch list, and which shape it is ("retail" or "classic").
local function watchApi()
	local api = retailWatch()
	if api then
		return api, "retail"
	end
	api = classicWatch()
	if api then
		return api, "classic"
	end
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

-- Why the module may not touch the client now, or nil: "off" (the setting), "noguide", "hidden" (the step card) or
-- "testing" (/signpost tracking test is running).
function Tracking:Paused()
	if not self:Enabled() then
		return "off"
	elseif not guideActive() then
		return "noguide"
	elseif not cardShown() then
		return "hidden"
	elseif Tracking.testing then
		return "testing"
	end
	return nil
end

-- Whether the module may touch the client now.
function Tracking:Active()
	return self:Paused() == nil
end

-- Evidence for the developer ------------------------------------------------------------------------------------------

-- The first SEEN_MAX things seen of the game's own tracking go to SignpostDB.probe.trackingSeen, which answers the open
-- probes without anybody doing anything special: does the game track a quest as it is accepted, which watch type does
-- the client report for it, and how a change that was not the module's was told apart. Plain numbers and words.
local function observe(entry)
	local db = ns.db
	if type(db) ~= "table" then
		return
	end
	if type(db.probe) ~= "table" then
		db.probe = {}
	end
	local seen = db.probe.trackingSeen
	if type(seen) ~= "table" then
		seen = {}
		db.probe.trackingSeen = seen
	end
	if #seen < SEEN_MAX then
		entry.t = time()
		seen[#seen + 1] = Util.Sanitize(entry)
	end
end

local function seenCount()
	local probe = ns.db and ns.db.probe
	local seen = type(probe) == "table" and probe.trackingSeen
	return type(seen) == "table" and #seen or 0
end

-- What the client says about each quest that arrived since the module last looked, before it writes anything.
local function observeArrivals(log, known)
	if not known or seenCount() >= SEEN_MAX then
		return
	end
	local api = watchApi()
	if not api then
		return
	end
	for questID in pairs(log) do
		if not known[questID] and seenCount() < SEEN_MAX then
			observe({
				what = "arrived",
				quest = questID,
				tracked = api.watched(questID),
				kind = api.kind(questID) or "unknown",
				watchType = api.watchType(questID),
			})
		end
	end
end

-- Back-off ------------------------------------------------------------------------------------------------------------

-- A new streak: the failures are forgotten. (A timer of the old streak that fires later only tries when a try is due.)
local function resetBackoff()
	Tracking.backoff = { failures = 0, nextTry = 0, reported = false }
end

-- Whether a try may be made now: no failure in a row, or the back-off after the last one is over.
local function due()
	local streak = Tracking.backoff
	return streak.failures == 0 or GetTime() >= streak.nextTry - EPSILON
end

local function scheduleRetry(delay)
	C_Timer.After(delay, function()
		ns.SafeCall(Tracking.OnRetry, Tracking)
	end)
end

-- The client tracked none of a step's quests: the module backs off for the client (the tracker was left as it was),
-- arms the timer of the next try and puts one entry in the error log for the streak.
local function failed()
	local streak = Tracking.backoff
	Tracking.state.mode = "client"
	streak.failures = streak.failures + 1
	local delay = BACKOFF[math.min(streak.failures, #BACKOFF)]
	streak.nextTry = GetTime() + delay
	if streak.failures <= #BACKOFF then
		scheduleRetry(delay)
	end
	if not streak.reported then
		streak.reported = true
		if ns.Errors and ns.Errors.Record then
			ns.Errors:Record(
				ADDON_NAME
					.. ": quest tracking backed off: the client did not track any quest of the step (AddQuestWatch raised or"
					.. " refused it, or a full tracker); the tracker was left as it was. It tries again shortly, and less often"
					.. " while it keeps failing."
			)
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

-- The first time the module is about to change the tracker it keeps what the player had tracked (once, until it is
-- given back), in tracker order, only the quests that are in the log.
local function rememberBefore(api, log)
	local keep = record()
	if not keep or keep.before ~= nil then
		return
	end
	local before = {}
	for _, questID in ipairs(watchedQuests(api, log)) do
		if log[questID] then
			before[#before + 1] = questID
		end
	end
	keep.before = before
end

-- The module wrote: it reads the tracker back and keeps that as what it left (in memory for the step, saved for the
-- restore), the game's own tracking among it apart, and ends a streak of failures.
local function settled(api, log)
	local state = Tracking.state
	state.left, state.autoLeft = watchedAmong(api, log), {}
	for questID in pairs(state.left) do
		if api.kind(questID) == "auto" then
			state.autoLeft[questID] = true
		end
	end
	state.mode = "following"
	local keep = record()
	if keep then
		keep.left = listOf(state.left)
	end
	if Tracking.backoff.failures > 0 then
		resetBackoff()
	end
end

-- Tracks the quests of the step that the log has, then, once the client has tracked at least one, untracks every other
-- quest; remembers what it left. The first application after a step began also points the tracker at the first quest of
-- the step that is not complete. When the client tracked none, the module backs off for the client.
local function follow(step)
	local state = Tracking.state
	local log, api = logSet(state.known), watchApi()
	state.known, state.left, state.autoLeft = log, nil, nil
	if not (log and api) then
		state.mode = "idle"
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
		state.mode = "following"
		return
	end
	rememberBefore(api, log)
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
		failed()
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
	settled(api, log)
end

-- Sets the tracking for the step, unless the client refused it lately and the back-off has not run out yet.
local function attempt(step)
	if due() then
		ns.SafeCall(follow, step)
	else
		Tracking.state.mode = "client"
	end
end

-- Who changed the tracker --------------------------------------------------------------------------------------------

-- Whether the game, not the player, tracked or untracked a quest the module had left alone. `tracked` is how the quest
-- stands now; `liveGame` is true when the change was seen as it happened and the game had just accepted or advanced a
-- quest. Returns that, the watch kind the client reported, and whether it was told by the timing alone (nothing says so
-- later, so the change is then taken into what the module expects).
local function byTheGame(api, questID, tracked, liveGame)
	local kind = api.kind(questID)
	if not tracked then
		-- the module left the game's own watch of it standing, and the game dropped it
		local autoLeft = Tracking.state.autoLeft
		return autoLeft ~= nil and autoLeft[questID] == true, kind, false
	end
	if kind == "auto" then
		return true, kind, false
	elseif kind == "manual" then
		return false, kind, false
	end
	return liveGame == true, kind, liveGame == true
end

-- Whether one of the quests the log already had has been tracked or untracked by the player since the module last wrote
-- (the game's own tracking does not count, see the header). `log` is the quest log's quests now.
function Tracking:ChangedByHand(log, liveGame)
	local state = Tracking.state
	local api = watchApi()
	if not (api and log and state.known and state.left) then
		return false
	end
	local now, byHand = watchedAmong(api, log), false
	for questID in pairs(state.known) do
		if log[questID] then
			local was, is = state.left[questID] == true, now[questID] == true
			if was ~= is then
				local game, kind, byTiming = byTheGame(api, questID, is, liveGame)
				observe({
					what = "changed",
					quest = questID,
					tracked = is,
					kind = kind or "unknown",
					by = game and "game" or "player",
					live = liveGame == true,
				})
				if game and byTiming then
					-- it is not judged again: the game did it, and the module still untracks the quest at its next
					-- application unless the step is about it
					state.left[questID] = is or nil
				end
				byHand = byHand or not game
			end
		end
	end
	return byHand
end

-- The player took the tracker in hand during this step: hands off until the next one, also after a reload.
local function markPlayer()
	local state = Tracking.state
	state.mode, state.manual = "player", true
	local keep = record()
	if keep and type(state.step) == "table" and state.step.id ~= nil then
		keep.handsOff = state.step.id
	end
end

-- Looks at whether the player changed the tracker since the module last wrote, and backs off for them if so.
function Tracking:Notice(liveGame)
	local state = Tracking.state
	if state.mode ~= "following" or not state.step or not state.left or not self:Active() then
		return
	end
	local log = logSet(state.known)
	if log and self:ChangedByHand(log, liveGame) then
		markPlayer()
	end
end

-- Steps and events ----------------------------------------------------------------------------------------------------

local function announcedAgain(step)
	local before = Tracking.state.step
	return type(step) == "table" and step.id ~= nil and type(before) == "table" and before.id == step.id
end

-- A step became current (or the setting was turned on, or the card shown again, while it is: `force`): set the
-- tracking for it. The same step announced again (the engine parsed the guide again) is not a new start: a decision to
-- stay hands off holds, and otherwise the tracking is set again without moving the focus. The first start after a
-- reload honours the saved fact that the player took the tracker in hand during this very step.
function Tracking:Begin(step, force)
	if type(step) ~= "table" then
		return
	end
	local state = Tracking.state
	if not force and announcedAgain(step) then
		state.step = step
		if state.mode == "player" then
			state.known = logSet(state.known)
		elseif self:Active() then
			attempt(step)
		end
		return
	end
	if force then
		resetBackoff()
	end
	local keep = record()
	local honoured = not force and state.step == nil and keep ~= nil and step.id ~= nil and keep.handsOff == step.id
	if keep and not honoured then
		keep.handsOff = nil
	end
	Tracking.state = { step = step, mode = honoured and "player" or "idle", manual = honoured, wantFocus = true }
	if not honoured and self:Active() then
		attempt(step)
	end
end

-- The timer of the back-off: another try for the step in hand, if the module is still backed off for the client, may
-- act, and the back-off is over.
function Tracking:OnRetry()
	local state = Tracking.state
	if state.mode == "client" and state.step and self:Active() and due() then
		ns.SafeCall(follow, state.step)
	end
end

-- The quest log's set of quests may have changed while the step is current: a quest accepted or removed (progress
-- inside a quest changes nothing here). Sets the tracking again unless the player has taken it into their hands.
function Tracking:OnQuestLogChanged()
	local state = Tracking.state
	if not state.step or state.mode == "player" or not self:Active() then
		return
	end
	local log = logSet(state.known)
	if not log or sameSet(log, state.known) then
		return
	end
	if state.mode == "following" and self:ChangedByHand(log) then
		markPlayer()
		return
	end
	observeArrivals(log, state.known)
	attempt(state.step)
end

-- QUEST_WATCH_LIST_CHANGED, a moment after the last of a bunch: a retry while backed off for the client, else a look at
-- whether the player did it. `byGame`: the game had just accepted or advanced a quest when the list changed.
function Tracking:OnWatchListChanged(byGame)
	local state = Tracking.state
	if not state.step or not self:Active() then
		return
	end
	if state.mode == "client" then
		if due() then
			ns.SafeCall(follow, state.step)
		end
	else
		self:Notice(byGame)
	end
end

local function recentGameEvent()
	local at = Tracking.gameEventAt
	return at ~= nil and GetTime() - at <= GAME_WINDOW
end

-- The player's choice (Journal > Settings). Either way it is a new start for the module (the back-off and the fact that
-- the player took the tracker in hand are forgotten); turned on, it takes effect for the current step at once (when the
-- module may act); turned off, the player's earlier tracking is given back.
function Tracking:SetEnabled(enabled)
	if not (ns.db and type(ns.db.settings) == "table") then
		return
	end
	ns.db.settings.trackStepQuests = enabled and true or false
	resetBackoff()
	local keep = record()
	if keep then
		keep.handsOff = nil
	end
	if Tracking.testing then
		return -- Tracking:AfterTest applies it
	end
	if not enabled then
		self:Release()
		return
	end
	local step = currentStep()
	if step then
		self:Begin(step, true)
	else
		Tracking.state = { mode = "idle", manual = false }
	end
end

-- Gives the player's earlier tracking back, once (see GIVING BACK in the header), and leaves the module idle. Says in
-- chat what it did. Does nothing when the module never changed the tracker.
function Tracking:Release()
	local state = Tracking.state
	local keep = record()
	local before = keep and keep.before
	Tracking.state = { step = state.step, mode = "idle", manual = false, wantFocus = true }
	resetBackoff()
	if keep then
		keep.handsOff = nil
	end
	if type(before) ~= "table" then
		return
	end
	local api = watchApi()
	local beforeSet = setOf(before)
	local leftSet = type(keep.left) == "table" and setOf(keep.left) or beforeSet
	local known = {}
	for _, set in ipairs({ beforeSet, leftSet, state.known or {} }) do
		for questID in pairs(set) do
			known[questID] = true
		end
	end
	local log = logSet(known)
	if not (api and log) then
		return -- nothing to ask: the earlier tracking is kept for the next time
	end
	local now, remaining, giveBack, takeAway = watchedAmong(api, log), 0, {}, {}
	for _, questID in ipairs(before) do
		if log[questID] then
			remaining = remaining + 1
			if not leftSet[questID] and not now[questID] then
				giveBack[#giveBack + 1] = questID
			end
		end
	end
	if remaining > 0 then
		for _, questID in ipairs(listOf(leftSet)) do
			if log[questID] and not beforeSet[questID] and now[questID] then
				takeAway[#takeAway + 1] = questID
			end
		end
	end
	Tracking.state.mode = "restoring"
	for _, questID in ipairs(takeAway) do
		api.remove(questID)
	end
	for _, questID in ipairs(giveBack) do
		api.add(questID)
	end
	Tracking.state.mode = "idle"
	keep.before, keep.left = nil, nil
	local after, tracked, untracked, refused = watchedAmong(api, log), 0, 0, 0
	for _, questID in ipairs(giveBack) do
		if after[questID] then
			tracked = tracked + 1
		else
			refused = refused + 1
		end
	end
	for _, questID in ipairs(takeAway) do
		if after[questID] then
			refused = refused + 1
		else
			untracked = untracked + 1
		end
	end
	if remaining == 0 then
		Util.Print(L["Quest tracker: the quests you were tracking before are done, so it stays as it is."])
	elseif #giveBack + #takeAway > 0 then
		Util.Print(
			L["Quest tracker: your earlier tracking is back (%d tracked again, %d untracked)."],
			tracked,
			untracked
		)
		if refused > 0 then
			Util.Print(L["Quest tracker: the client did not take %d of those changes."], refused)
		end
	end
end

-- The step card was shown again (its saved flag turned on): the module did nothing while it was hidden, so it sets the
-- tracking for the current step now, as a new start.
function Tracking:OnCardShown()
	local step = currentStep()
	if step and self:Active() then
		self:Begin(step, true)
	end
end

-- Hooks the step card's methods that can turn its saved flag on (SetShown for /signpost show and the Journal's box,
-- Reset), without touching the card's file: whichever of them leaves the flag on after it was off tells the module. A
-- method the card does not have is not hooked, and the module then waits for the next step.
local function watchCard()
	local card = ns.StepFrame
	if type(card) ~= "table" or Tracking.cardHooked then
		return
	end
	Tracking.cardHooked = true
	for _, name in ipairs({ "SetShown", "Reset" }) do
		local original = card[name]
		if type(original) == "function" then
			card[name] = function(...)
				local was = cardShown()
				local results = Util.Pack(original(...))
				if not was and cardShown() then
					ns.SafeCall(Tracking.OnCardShown, Tracking)
				end
				return unpack(results, 1, results.n)
			end
		end
	end
end

-- Whatever /signpost tracking test put off (a step, the setting) is dealt with when it is done.
function Tracking:AfterTest()
	Tracking.testing = false
	if not self:Enabled() then
		self:Release()
		return
	end
	local step = currentStep()
	if step then
		self:Begin(step)
	end
end

ns.Events:RegisterMessage("STEP_CHANGED", function(_, step)
	Tracking:Begin(step)
end)

ns.Events:RegisterMessage("CONTEXT_CHANGED", function(_, what)
	if what == "quests" then
		Tracking:OnQuestLogChanged()
	end
end)

-- A guide chosen again that leaves no guide active (Progress's own handler ran first): the tracker is given back.
ns.Events:RegisterMessage("GUIDE_SELECTED", function()
	if not guideActive() and not Tracking.testing then
		Tracking:Release()
	end
end)

ns.Events:RegisterMessage("DB_READY", watchCard)

-- The game accepted a quest or advanced one: a watch change right after it is the game's own tracking.
local function onGameEvent()
	Tracking.gameEventAt = GetTime()
end
ns.Events:Register("QUEST_ACCEPTED", onGameEvent)
ns.Events:Register("QUEST_WATCH_UPDATE", onGameEvent)

-- VERIFY(beta): QUEST_WATCH_LIST_CHANGED exists on Forever (the module works without it; with it a change by the player
-- is noticed at once and the game's accept-time tracking is told by its timing). A bunch of events is looked at once.
local watchPending, watchByGame = false, false
ns.Events:Register("QUEST_WATCH_LIST_CHANGED", function()
	watchByGame = watchByGame or recentGameEvent()
	if watchPending then
		return
	end
	watchPending = true
	C_Timer.After(WATCH_DELAY, function()
		local byGame = watchByGame
		watchPending, watchByGame = false, false
		ns.SafeCall(Tracking.OnWatchListChanged, Tracking, byGame)
	end)
end)

-- A change by the player since the last look is kept for the next session (a reload is a logout too).
ns.Events:Register("PLAYER_LOGOUT", function()
	Tracking:Notice(false)
end)

-- /signpost tracking and /signpost tracking test ----------------------------------------------------------------------

-- The functions the module relies on, by shape, and what the status and the test report about their presence.
local FUNCTIONS = {
	retail = {
		"C_QuestLog.AddQuestWatch",
		"C_QuestLog.RemoveQuestWatch",
		"C_QuestLog.GetQuestWatchType",
		"C_QuestLog.GetNumQuestWatches",
		"C_QuestLog.GetQuestIDForQuestWatchIndex",
		"C_SuperTrack.GetSuperTrackedQuestID",
		"C_SuperTrack.SetSuperTrackedQuestID",
		"Enum.QuestWatchType",
	},
	classic = {
		"AddQuestWatch",
		"RemoveQuestWatch",
		"IsQuestWatched",
		"GetNumQuestWatches",
		"GetQuestIndexForWatch",
		"C_QuestLog.GetLogIndexForQuestID",
		"C_QuestLog.GetQuestIDForLogIndex",
	},
}

-- { [name] = "function" | "table" | "nil" ... } for every name above.
local function presence()
	local found = {}
	for _, names in pairs(FUNCTIONS) do
		for _, name in ipairs(names) do
			found[name] = type(Util.Resolve(name))
		end
	end
	return found
end

local function missing(shape)
	local names = {}
	for _, name in ipairs(FUNCTIONS[shape]) do
		if Util.Resolve(name) == nil then
			names[#names + 1] = name
		end
	end
	return names
end

-- How many quests the client lets the player track, as far as it says so without filling the tracker.
local function watchLimits()
	return {
		retailConstants = Util.Resolve("Constants.QuestWatchConsts"),
		maxWatchableQuests = Util.Resolve("MAX_WATCHABLE_QUESTS"),
	}
end

local PAUSED = {
	off = "the setting is off",
	noguide = "no guide is active",
	hidden = "the step card is hidden",
	testing = "a test is running",
}

-- The lines of /signpost tracking: the setting, the state, what the module last tracked, what it keeps to give back,
-- the quests tracked now and which watch functions the client has.
function Tracking:StatusLines()
	local state, streak, keep = Tracking.state, Tracking.backoff, record() or {}
	local lines = {}
	local chosen = ns.db and ns.db.settings and ns.db.settings.trackStepQuests
	local paused = self:Paused()
	lines[#lines + 1] = string.format(
		L["Quest tracking is %s (%s). State: %s%s. Step: %s."],
		self:Enabled() and L["on"] or L["off"],
		type(chosen) == "boolean" and L["your choice"] or L["the default"],
		tostring(state.mode),
		paused and string.format(L[" (paused: %s)"], L[PAUSED[paused]]) or "",
		type(state.step) == "table" and tostring(state.step.id) or L["none yet"]
	)
	lines[#lines + 1] = string.format(
		L["Last set by the module: %s. Your earlier tracking, kept to give back: %s."],
		joined(keep.left) or L["nothing"],
		joined(keep.before) or L["nothing"]
	)
	if streak.failures > 0 then
		lines[#lines + 1] = string.format(
			L["Backed off for the client: %d failed tries in a row, the next one in %d s at the earliest."],
			streak.failures,
			math.max(0, math.ceil(streak.nextTry - GetTime()))
		)
	end
	if state.mode == "player" then
		lines[#lines + 1] =
			L["Backed off for you: you changed the tracker during this step; the next step starts again."]
	end
	local api, shape = watchApi()
	if api then
		local parts = {}
		for _, questID in ipairs(api.list() or {}) do
			local kind = api.watchType(questID)
			parts[#parts + 1] = kind ~= nil and string.format("%d (%s)", questID, tostring(kind)) or tostring(questID)
		end
		lines[#lines + 1] = string.format(
			L["Tracked now: %s. Watch functions: the %s shape; missing: %s."],
			#parts > 0 and table.concat(parts, ", ") or L["nothing"],
			shape,
			joined(missing(shape)) or L["none"]
		)
	else
		lines[#lines + 1] = string.format(
			L["This client has neither the retail nor the Classic quest watch functions (missing: %s / %s)."],
			joined(missing("retail")) or L["none"],
			joined(missing("classic")) or L["none"]
		)
	end
	local tested = type(ns.db) == "table" and type(ns.db.probe) == "table" and ns.db.probe.tracking
	lines[#lines + 1] = string.format(
		L["Recorded for the developer: %d observations of the game's own tracking; the test %s."],
		seenCount(),
		type(tested) == "table" and L["has been run (SignpostDB.probe.tracking)"]
			or L["has not been run (/signpost tracking test)"]
	)
	return lines
end

-- What the client says about the quest right now: how many quests are tracked, whether this one is (asked of the quest
-- and of the list), and its watch type.
local function readback(api, questID)
	local list = api.list()
	local read = { count = api.count(), watched = api.watched(questID), watchType = api.watchType(questID) }
	if list ~= nil then
		read.inList = contains(list, questID)
	end
	return read
end

local function yesNo(value)
	if value == nil then
		return L["unknown"]
	end
	return value and L["yes"] or L["no"]
end

-- What the test tells the player, in plain words: each call and what the client answered, the counts, and whether the
-- tracker is as it was.
local function testLines(run)
	local lines = {}
	lines[#lines + 1] = string.format(
		run.before.watched and L["Quest tracking test: I unwatched quest %d and watched it again (the %s shape)."]
			or L["Quest tracking test: I watched quest %d and unwatched it again (the %s shape)."],
		run.quest,
		run.shape
	)
	for _, call in ipairs(run.calls) do
		local answer = call.ok and string.format(L["returned %s"], tostring(call.returns and call.returns[1]))
			or string.format(L["raised: %s"], tostring(call.error))
		lines[#lines + 1] = string.format(
			L["  %s %s; read back at once: tracked %s, %s quests tracked."],
			call.call,
			answer,
			yesNo(call.readback and call.readback.watched),
			tostring(call.readback and call.readback.count)
		)
	end
	local events = {}
	for _, event in ipairs(run.events) do
		events[#events + 1] = event.event
	end
	lines[#lines + 1] = string.format(
		L["  Events seen meanwhile: %s. Quests tracked before: %s, afterwards: %s."],
		joined(events) or L["none"],
		tostring(run.before.count),
		tostring(run.later and run.later.count)
	)
	if run.restored then
		lines[#lines + 1] = run.repaired and L["  Your tracker is as it was (it took a second try)."]
			or L["  Your tracker is as it was."]
	else
		lines[#lines + 1] = string.format(
			L["  I could not put your tracker back: quest %d is still %s. Please %s it by hand."],
			run.quest,
			run.before.watched and L["untracked"] or L["tracked"],
			run.before.watched and L["track"] or L["untrack"]
		)
	end
	lines[#lines + 1] = L["  Saved to SignpostDB.probe.tracking; /reload writes it to disk."]
	return lines
end

-- Starts a frame that notes the quest watch events during the test, and returns a function that stops it.
local function captureEvents(run)
	local frame = CreateFrame("Frame")
	local started = GetTime()
	run.eventsRegistered = {}
	for _, event in ipairs({
		"QUEST_WATCH_LIST_CHANGED",
		"QUEST_WATCH_UPDATE",
		"QUEST_LOG_UPDATE",
		"UNIT_QUEST_LOG_CHANGED",
	}) do
		run.eventsRegistered[event] = pcall(frame.RegisterEvent, frame, event)
	end
	frame:SetScript("OnEvent", function(_, event, ...)
		if #run.events < TEST_MAX_EVENTS then
			run.events[#run.events + 1] =
				{ event = event, at = Util.Round(GetTime() - started, 2), args = Util.Pack(...) }
		end
	end)
	return function()
		frame:UnregisterAllEvents()
		frame:SetScript("OnEvent", nil)
	end
end

local function saveTest(run)
	if type(ns.db) ~= "table" then
		return
	end
	if type(ns.db.probe) ~= "table" then
		ns.db.probe = {}
	end
	ns.db.probe.tracking = Util.Sanitize(run)
end

local function printLines(lines)
	for _, line in ipairs(lines) do
		Util.Print("%s", line)
	end
end

-- The test proper: one quest of the log is watched and unwatched again (or the other way round when every quest is
-- tracked already), each call's answer and the tracker read back after it are noted, and after TEST_SETTLE seconds the
-- tracker is read once more and, if it is not as it was, put back once more.
local function runTest(run, api)
	local log = logSet(nil) or {}
	local ids = listOf(log)
	local questID
	for _, id in ipairs(ids) do
		if not api.watched(id) then
			questID = id
			break
		end
	end
	if not questID then
		-- every quest is tracked: the one tracked last, so that taking it off and putting it back keeps the order
		local tracked = api.list() or {}
		for i = #tracked, 1, -1 do
			if log[tracked[i]] then
				questID = tracked[i]
				break
			end
		end
		questID = questID or ids[1]
	end
	if not questID then
		run.complete, run.note = true, "the quest log is empty: accept a quest and run the test again"
		saveTest(run)
		Util.Print(L["Quest tracking test: your quest log is empty. Accept a quest and run it again."])
		Tracking:AfterTest()
		return
	end
	local wasWatched, typeBefore = api.watched(questID), api.watchType(questID)
	run.quest = questID
	run.before = { count = api.count(), list = api.list(), watched = wasWatched, watchType = typeBefore }
	local stopCapture = captureEvents(run)
	-- `fn` is one of the api's try functions: pcall's results (did it raise, what it returned or the error)
	local function call(label, fn, ...)
		local packed = Util.Pack(fn(...))
		local entry = { call = label, ok = packed[1] == true }
		if entry.ok then
			entry.returns = { n = packed.n - 1 }
			for i = 2, packed.n do
				entry.returns[i - 1] = packed[i]
			end
		else
			entry.error = tostring(packed[2])
		end
		entry.readback = readback(api, questID)
		run.calls[#run.calls + 1] = entry
	end
	local add = run.shape == "retail" and "C_QuestLog.AddQuestWatch" or "AddQuestWatch"
	local remove = run.shape == "retail" and "C_QuestLog.RemoveQuestWatch" or "RemoveQuestWatch"
	if wasWatched then
		call(remove, api.tryRemove, questID)
		call(add, api.tryAdd, questID, typeBefore)
	else
		call(add, api.tryAdd, questID)
		call(remove, api.tryRemove, questID)
	end
	saveTest(run)
	C_Timer.After(TEST_SETTLE, function()
		local ok = ns.SafeCall(function()
			run.later = readback(api, questID)
			if run.later.watched ~= wasWatched then
				-- one more try to put it back
				if wasWatched then
					api.tryAdd(questID, typeBefore)
				else
					api.tryRemove(questID)
				end
				run.later = readback(api, questID)
				run.repaired = true
			end
			run.restored = run.later.watched == wasWatched
			stopCapture()
			run.complete = true
			saveTest(run)
			printLines(testLines(run))
		end)
		if not ok then
			stopCapture()
		end
		Tracking:AfterTest()
	end)
end

-- /signpost tracking test: see the header. Out of combat only; never leaves the tracker changed (or says plainly that
-- it could not put it back); records what the client answered in SignpostDB.probe.tracking.
function Tracking:RunTest()
	if Tracking.testing then
		Util.Print(L["The quest tracking test is still running."])
		return
	end
	if Util.Call(InCombatLockdown) then
		Util.Print(L["Quest tracking test: not in combat, please. Nothing was changed."])
		return
	end
	local api, shape = watchApi()
	local run = {
		time = time(),
		complete = false,
		shape = shape or "none",
		functions = presence(),
		enum = Util.Resolve("Enum.QuestWatchType"),
		limits = watchLimits(),
		calls = {},
		events = {},
	}
	if not api then
		run.complete, run.note = true, "the client has neither the retail nor the Classic quest watch functions"
		saveTest(run)
		Util.Print(L["Quest tracking test: this client has none of the quest watch functions I know."])
		Util.Print(L["  Nothing to test; the list of functions is saved to SignpostDB.probe.tracking."])
		return
	end
	Tracking.testing = true
	local ok = ns.SafeCall(runTest, run, api)
	if not ok then
		Tracking:AfterTest()
	end
end

ns.Slash:Register("tracking", function(args)
	local word = (args or ""):lower()
	if word == "test" then
		Tracking:RunTest()
	elseif word == "" or word == "status" then
		printLines(Tracking:StatusLines())
	else
		Util.Print(L["Usage: /signpost tracking, or /signpost tracking test."])
	end
end, L["quest tracker: its state; 'tracking test' checks the client's watch functions (out of combat)"])
