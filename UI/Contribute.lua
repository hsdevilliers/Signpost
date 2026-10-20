-- The "Help improve Signpost" window: what is recorded, one checkbox (Core/Contribute.lua keeps the answer), what has
-- been recorded so far and how to hand the file over. It opens by itself once on a release build and from
-- /signpost contribute.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local UI = ns.UI

local WINDOW_NAME = "SignpostContributeWindow"
local PROMPT_DELAY = 4 -- seconds after login before the first-run window may open
local RETRY_DELAY = 15 -- seconds to wait when the player is in combat

local Window = {}
UI.Contribute = Window

local function text(parent, font, anchor, offsetY, content)
	local line = parent:CreateFontString(nil, "ARTWORK", font)
	line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
	line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
	line:SetJustifyH("LEFT")
	line:SetWordWrap(true)
	line:SetText(content)
	return line
end

-- VERIFY(beta): layout and templates in the real client (FOREVER-API-NOTES "Open probes"); specs run on a mock.
-- VERIFY(beta): layout and templates in the real client (FOREVER-API-NOTES "Open probes"); specs run on a mock.
function Window:Create()
	local frame = UI:CreateDialogFrame(WINDOW_NAME, 500, 400)
	UI:SetDialogTitle(frame, L["Help improve Signpost"])
	local host = UI:DialogHost(frame)

	local top = host:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	top:SetPoint("TOPLEFT", host, "TOPLEFT", 16, -14)
	top:SetText(L["What Signpost can learn while you play"])

	local what = text(
		host,
		"GameFontHighlight",
		top,
		-8,
		L["Where NPCs, quest givers, flight masters, trainers, vendors and zone borders are, so the guides get better. "]
			.. L["Only IDs, the names of NPCs, objects and flight nodes, and map positions are recorded. "]
			.. L["No chat and no player or pet names."]
	)

	local check = CreateFrame("CheckButton", nil, host, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", what, "BOTTOMLEFT", -4, -14)
	check:SetHitRectInsets(0, -320, 0, 0)
	local label = host:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", check, "RIGHT", 2, 1)
	label:SetText(L["Record this while I play"])
	check:SetScript("OnClick", function(button)
		ns.SafeCall(function()
			ns.Contribute:SetEnabled(button:GetChecked() and true or false)
			Window:Refresh()
		end)
	end)

	local state = text(host, "GameFontHighlightSmall", check, -10, "")
	local share = text(
		host,
		"GameFontHighlight",
		state,
		-12,
		L["Nothing leaves your computer by itself. To share what was recorded, log out, "]
			.. L["then copy the file Signpost.lua from "]
			.. L["World of Warcraft\\<game folder>\\WTF\\Account\\<your account>\\SavedVariables\\ into the shared folder. "]
			.. L["The file also holds Signpost's settings, error log and the notes you write with /signpost report."]
	)
	local change = text(
		host,
		"GameFontHighlightSmall",
		share,
		-12,
		L["You can change this at any time with /signpost contribute."]
	)

	local done = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
	done:SetSize(120, 24)
	done:SetPoint("BOTTOM", host, "BOTTOM", 0, 14)
	done:SetText(L["Done"])
	done:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame:SetScript("OnHide", function()
		ns.SafeCall(function()
			ns.Contribute:MarkAsked()
		end)
	end)

	frame.Check, frame.State, frame.Change = check, state, change
	frame:Hide()
	return frame
end

-- The checkbox and the line under it, from the saved answer and what Learn holds.
function Window:Refresh()
	local frame = self.frame
	if not frame then
		return
	end
	local enabled = ns.Contribute:Enabled()
	frame.Check:SetChecked(enabled)
	if ns.isDev then
		frame.State:SetText(L["This is a development build: it records regardless of this box."])
		return
	end
	local counts = ns.Learn and ns.Learn:Counts() or {}
	frame.State:SetText(
		string.format(
			L["Recorded so far: %d NPCs, %d objects, %d quests, %d flight nodes, %d zone crossings."],
			counts.npcs or 0,
			counts.objects or 0,
			counts.quests or 0,
			counts.taxi or 0,
			counts.crossings or 0
		)
	)
end

function Window:Show()
	self.frame = self.frame or self:Create()
	self:Refresh()
	self.frame:Show()
end

-- Once, on a release build whose player has not seen the window yet, a few seconds after login and out of combat.
local function prompt()
	if ns.isDev or not ns.db or ns.Contribute:Asked() then
		return
	end
	if Util.Call(InCombatLockdown) then
		C_Timer.After(RETRY_DELAY, function()
			ns.SafeCall(prompt)
		end)
		return
	end
	Window:Show()
end

ns.Events:Register("PLAYER_LOGIN", function()
	if ns.isDev then
		return
	end
	C_Timer.After(PROMPT_DELAY, function()
		ns.SafeCall(prompt)
	end)
end)
