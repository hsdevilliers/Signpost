-- Automation (PLAN §3.4): settings, the gate every automatic action passes, and the lookup of what the current guide
-- step asks for. Every feature is a toggle and every toggle is off by default. Nothing here acts by itself: the
-- feature files (Quests, Gossip, Taxi, Trainer, Vendor) call Automation:Allowed(feature) at their own events and then
-- act only on directives of the CURRENT step (ns.Progress:Current()), never on the player's unrelated choices.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Automation = {}
ns.Automation = Automation

-- The features, in the order /signpost automation lists them. `quests` is quest accept, `turnIn` quest turn-in.
Automation.FEATURES = { "quests", "turnIn", "gossip", "taxi", "trainer", "vendor" }

Automation.LABELS = {
	quests = L["accept quests"],
	turnIn = L["turn in quests"],
	gossip = L["gossip (single option, set the hearth)"],
	taxi = L["take flights"],
	trainer = L["train spells"],
	vendor = L["buy from vendors"],
}

-- Character settings (SignpostCharDB.automation). The three mode flags are toggles too, in the Journal's style:
-- acceptAll    false: only quests the current step `.accept`s;  true: every non-trivial quest the guide keeps
-- turnInAll    false: only quests of the current step;         true: every completable quest
-- rewardAsk    false: `.reward`, else the highest value;       true: always stop and let the player choose
-- goldReserve  copper the automation never spends below (trainer and vendor). Default 0: the guide asks for these
--              purchases, so they happen whenever the player can pay for them; raise it with
--              `/signpost automation reserve <gold>` to keep money back for something else.
Automation.DEFAULTS = {
	quests = false,
	turnIn = false,
	gossip = false,
	taxi = false,
	trainer = false,
	vendor = false,
	acceptAll = false,
	turnInAll = false,
	rewardAsk = false,
	goldReserve = 0,
}

ns.SavedVars:RegisterDefaults("char", "automation", Automation.DEFAULTS)

-- The saved table, or the defaults before SavedVariables are ready (everything off).
function Automation:Settings()
	local saved = ns.char and ns.char.automation
	if type(saved) == "table" then
		return saved
	end
	return Automation.DEFAULTS
end

function Automation:Enabled(feature)
	return self:Settings()[feature] == true
end

function Automation:SetEnabled(feature, on)
	local saved = ns.char and ns.char.automation
	if type(saved) == "table" and Automation.DEFAULTS[feature] ~= nil then
		saved[feature] = on and true or false
	end
end

-- Gold reserve in copper; a bad saved value counts as none.
function Automation:Reserve()
	local reserve = tonumber(self:Settings().goldReserve)
	if reserve and reserve > 0 then
		return reserve
	end
	return 0
end

-- The gate ---------------------------------------------------------------------------------------------------------

local function flag(fn, ...)
	local value = Util.Call(fn, ...)
	if Util.IsSecret(value) then
		return true -- unreadable: do nothing rather than guess
	end
	return value and true or false
end

-- true when the player (not the guide) says "hands off" right now: Shift held (ForeverAutoQuest's convention), combat
-- (nothing protected in combat), dead or a ghost, or the Settings panel open (PLAN §3.4).
function Automation:Blocked()
	if flag(IsShiftKeyDown) or flag(InCombatLockdown) or flag(UnitIsDeadOrGhost, "player") then
		return true
	end
	local panel = Util.Resolve("SettingsPanel")
	if type(panel) == "table" and flag(panel.IsShown, panel) then
		return true
	end
	return false
end

-- May this feature act now? The one question every handler asks first.
function Automation:Allowed(feature)
	return self:Enabled(feature) and not self:Blocked()
end

-- The current step ---------------------------------------------------------------------------------------------------

function Automation:Step()
	local progress = ns.Progress
	if type(progress) == "table" and type(progress.Current) == "function" then
		return (progress:Current())
	end
end

-- The current step's directives named `name`: { { directive = d, args = d.args, index = i }, ... } (empty without a
-- step). Sticky directives belong to earlier steps and are not read.
function Automation:Directives(name)
	local found, step = {}, self:Step()
	for index, directive in ipairs(step and step.directives or {}) do
		if type(directive) == "table" and directive.name == name then
			found[#found + 1] = { directive = directive, args = directive.args or {}, index = index }
		end
	end
	return found
end

-- true when the current step has any directive of the given names.
function Automation:Asks(...)
	local step = self:Step()
	for _, directive in ipairs(step and step.directives or {}) do
		for i = 1, select("#", ...) do
			if type(directive) == "table" and directive.name == (select(i, ...)) then
				return true
			end
		end
	end
	return false
end

-- true when the guide marks the quest `#skipquest`.
function Automation:GuideSkips(questID)
	local progress = ns.Progress
	if type(progress) ~= "table" or type(progress.Guide) ~= "function" then
		return false
	end
	local guide = progress:Guide()
	return type(guide) == "table" and type(guide.skipQuests) == "table" and guide.skipQuests[questID] ~= nil
end

-- true when a directive of the current step is already satisfied (so the NPC visit has nothing left to do).
function Automation:Satisfied(entry)
	local def = entry.directive.def
	local progress, step = ns.Progress, self:Step()
	if type(def) ~= "table" or type(def.isSatisfied) ~= "function" or not ns.Context then
		return false
	end
	local states = type(progress.State) == "function" and step and progress:State(step.id) or nil
	local ok, done = ns.SafeCall(def.isSatisfied, entry.args, ns.Context, states and states[entry.index] or {})
	return ok and done == true
end

-- Calls fn(...) and reports whether it ran without an error (Util.Call hides that).
function Automation.Try(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return (pcall(fn, ...))
end

-- /signpost automation [on|off|status|reserve <gold>] -----------------------------------------------------------------

local function status()
	local settings = Automation:Settings()
	for _, feature in ipairs(Automation.FEATURES) do
		Util.Print("  %s: %s", Automation.LABELS[feature], Automation:Enabled(feature) and L["on"] or L["off"])
	end
	Util.Print(
		L["  accept: %s; turn in: %s; rewards: %s; gold reserve: %s"],
		settings.acceptAll and L["every non-trivial quest"] or L["the guide's quests"],
		settings.turnInAll and L["every completable quest"] or L["the guide's quests"],
		settings.rewardAsk and L["always ask me"] or L["highest vendor value"],
		string.format(
			"%d g %d s %d c",
			math.floor(Automation:Reserve() / 10000),
			math.floor(Automation:Reserve() / 100) % 100,
			Automation:Reserve() % 100
		)
	)
end

ns.Slash:Register("automation", function(args)
	local word, rest = (args or ""):match("^(%S*)%s*(.-)$")
	word = word:lower()
	if word == "on" or word == "off" then
		for _, feature in ipairs(Automation.FEATURES) do
			Automation:SetEnabled(feature, word == "on")
		end
		Util.Print(word == "on" and L["Automation is on (hold Shift at an NPC to skip it)."] or L["Automation is off."])
	elseif word == "reserve" then
		local gold = tonumber(rest)
		if not gold or gold < 0 or not (ns.char and type(ns.char.automation) == "table") then
			Util.Print(L["Usage: /signpost automation reserve <gold>"])
			return
		end
		ns.char.automation.goldReserve = math.floor(gold * 10000 + 0.5)
		Util.Print(L["Automation keeps %s gold in reserve."], tostring(gold))
	elseif word ~= "" and word ~= "status" then
		Util.Print(L["Usage: /signpost automation [on|off|status|reserve <gold>]"])
		return
	end
	status()
end, L["automatic quests, trainers, vendors and flights: on, off, status, reserve <gold>"])
