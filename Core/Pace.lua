local ADDON_NAME, ns = ...

-- Light, passive pace calibration for the route simulator (PLAN Phase 9, stage 3): at each level-up the time played is
-- recorded, a few numbers per level and no effort from the player. tools/guide_sim.py --pace reads them and fits one
-- overall pace multiplier. Kept per character (SignpostCharDB.pace). Only with the player's yes (Core/Contribute.lua;
-- dev builds always record), and only on this machine until the player shares the file.
local Pace = {}
ns.Pace = Pace

local MAX_LEVELS = 100
-- Seconds to wait for the answer before giving the chat line back.
local WAIT_SECONDS = 10

local pendingLevel
local hidden
local original

-- VERIFY(beta): RequestTimePlayed, TIME_PLAYED_MSG and the global ChatFrame_DisplayTimePlayed (the chat line the answer
-- prints) exist on Forever. Without the last one the player sees the usual "Total time played" lines at each level-up.
local function hideChatLine()
	if hidden or type(ChatFrame_DisplayTimePlayed) ~= "function" then
		return
	end
	original = ChatFrame_DisplayTimePlayed
	ChatFrame_DisplayTimePlayed = function() end
	hidden = true
end

local function showChatLine()
	if hidden then
		ChatFrame_DisplayTimePlayed = original
		original, hidden = nil, nil
	end
end

ns.SavedVars:RegisterDefaults("char", "pace", {})

local function enabled()
	return ns.char ~= nil and ns.Contribute ~= nil and ns.Contribute:Enabled()
end

-- pace[level] = { played = seconds played in all when the level was reached, at = time() }
function Pace:Record(level, played)
	if type(level) ~= "number" or type(played) ~= "number" or not ns.char then
		return false
	end
	if type(ns.char.pace) ~= "table" then
		ns.char.pace = {}
	end
	local count = 0
	for _ in pairs(ns.char.pace) do
		count = count + 1
	end
	if ns.char.pace[level] == nil and count >= MAX_LEVELS then
		return false
	end
	ns.char.pace[level] = { played = played, at = time() }
	return true
end

function Pace:OnLevelUp(level)
	if not enabled() or type(RequestTimePlayed) ~= "function" then
		return
	end
	pendingLevel = level
	hideChatLine()
	RequestTimePlayed()
	C_Timer.After(WAIT_SECONDS, function()
		if pendingLevel == level then
			pendingLevel = nil
		end
		showChatLine()
	end)
end

function Pace:OnTimePlayed(total)
	local level = pendingLevel
	pendingLevel = nil
	showChatLine()
	if not enabled() then
		return
	end
	if level then
		self:Record(level, total)
		return
	end
	-- a /played the player asked for is recorded at their current level, once per level
	level = type(UnitLevel) == "function" and UnitLevel("player")
	if level and not (type(ns.char.pace) == "table" and ns.char.pace[level]) then
		self:Record(level, total)
	end
end

ns.Events:Register("PLAYER_LEVEL_UP", function(_, level)
	ns.SafeCall(Pace.OnLevelUp, Pace, level)
end)
ns.Events:Register("TIME_PLAYED_MSG", function(_, total)
	ns.SafeCall(Pace.OnTimePlayed, Pace, total)
end)
