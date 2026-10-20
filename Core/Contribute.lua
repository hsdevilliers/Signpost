-- Contribute: whether this player agreed to let Signpost record what it sees (NPC, quest giver, flight master, trainer,
-- vendor and zone border positions: Core/Learn.lua) so the guides improve. Release builds record nothing until the
-- player says yes; dev builds (git checkouts) always record, as before. The debug event log (Core/Debug.lua) is a
-- separate, broader log that is never switched on by this choice. Nothing is sent anywhere: the data stays in
-- SavedVariables and the player hands the file over (UI/Contribute.lua says how).
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Contribute = {}
ns.Contribute = Contribute

-- asked: the window has been shown (and closed) once, so it is not shown by itself again. enabled: the checkbox.
ns.SavedVars:RegisterDefaults("account", "contribute", { asked = false, enabled = false })

-- Core/Learn.lua asks this before it records anything. Without the database, or without the answer, it is no.
function Contribute:Enabled()
	if ns.isDev then
		return true
	end
	local state = ns.db and ns.db.contribute
	return type(state) == "table" and state.enabled == true
end

function Contribute:Asked()
	local state = ns.db and ns.db.contribute
	return type(state) == "table" and state.asked == true
end

function Contribute:SetEnabled(enabled)
	local state = ns.db and ns.db.contribute
	if type(state) ~= "table" then
		return false
	end
	state.enabled = enabled and true or false
	ns.Events:Fire("CONTRIBUTE_CHANGED", state.enabled)
	return true
end

function Contribute:MarkAsked()
	local state = ns.db and ns.db.contribute
	if type(state) == "table" then
		state.asked = true
	end
end

local function printState()
	if ns.isDev then
		Util.Print(L["contribute: this is a development build and always records"])
	else
		Util.Print(L["contribute: recording is %s"], Contribute:Enabled() and L["on"] or L["off"])
	end
end

ns.Slash:Register("contribute", function(args)
	local sub = (args or ""):lower():match("^%s*(%S*)")
	if sub == "on" or sub == "off" then
		Contribute:SetEnabled(sub == "on")
		printState()
	elseif sub == "status" then
		printState()
	elseif ns.UI and ns.UI.Contribute then
		ns.UI.Contribute:Show()
	else
		printState()
	end
end, L["help improve the guides: contribute | on | off | status"])
