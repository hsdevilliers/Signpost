-- Signpost's entry in Blizzard's Options window (Options > AddOns): a short panel that opens the Journal, where every
-- setting lives (PLAN §3.2). Registered once the saved variables are ready, and only with the client's Settings API.
-- VERIFY(beta): Settings.RegisterCanvasLayoutCategory / RegisterAddOnCategory and the panel layout in the real client.
local ADDON_NAME, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

function Options:Register()
	local settings = Settings
	if type(settings) ~= "table" or not (settings.RegisterCanvasLayoutCategory and settings.RegisterAddOnCategory) then
		return false
	end
	if self.category then
		return true
	end
	local panel = CreateFrame("Frame")
	panel.name = "Signpost"
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	title:SetText("Signpost")
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	text:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(true)
	text:SetText(L["Every setting is in the Journal: the step card, the map pins, automation and data sharing."])
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(200, 24)
	open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
	open:SetText(L["Open the Journal"])
	open:SetScript("OnClick", function()
		ns.SafeCall(function()
			if ns.Journal and ns.Journal.Show then
				ns.Journal:Show("settings")
			end
		end)
	end)
	local category = settings.RegisterCanvasLayoutCategory(panel, "Signpost")
	settings.RegisterAddOnCategory(category)
	self.category, self.panel, self.button = category, panel, open
	return true
end

ns.Events:RegisterMessage("DB_READY", function()
	ns.SafeCall(Options.Register, Options)
end)
