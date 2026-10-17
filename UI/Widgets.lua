-- Shared UI pieces built from stock Blizzard templates: template-fallback frame creation and a copyable text dialog
-- (used by /signpost export).
local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

local function hasTemplate(template)
	local getInfo = C_XMLUtil and C_XMLUtil.GetTemplateInfo
	if not getInfo then
		return true -- cannot tell in advance; CreateFrame decides
	end
	local ok, info = pcall(getInfo, template)
	return ok and info ~= nil
end

-- Creates a frame from the first template this client has. Template availability on Forever is probed, not assumed
-- (FOREVER-API-NOTES "Open probes"). Returns the frame and the template used (nil for a bare frame).
function UI.CreateFrameFromTemplates(frameType, name, parent, templates)
	for _, template in ipairs(templates) do
		if hasTemplate(template) then
			local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
			if ok and frame then
				return frame, template
			end
		end
	end
	return CreateFrame(frameType, name, parent), nil
end

local DIALOG_NAME = "SignpostTextDialog"

function UI:CreateTextDialog()
	local frame, template = UI.CreateFrameFromTemplates(
		"Frame",
		DIALOG_NAME,
		UIParent,
		{ "ButtonFrameTemplate", "BasicFrameTemplateWithInset", "BackdropTemplate" }
	)
	frame:SetSize(560, 420)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if template == "ButtonFrameTemplate" then
		if ButtonFrameTemplate_HidePortrait then
			ButtonFrameTemplate_HidePortrait(frame)
		end
		if ButtonFrameTemplate_HideButtonBar then
			ButtonFrameTemplate_HideButtonBar(frame)
		end
	elseif template == "BackdropTemplate" and BACKDROP_DIALOG_32_32 then
		frame:SetBackdrop(BACKDROP_DIALOG_32_32)
	end
	-- Escape closes it, like Blizzard's own dialogs.
	tinsert(UISpecialFrames, DIALOG_NAME)

	local host = frame.Inset or frame
	local scroll =
		UI.CreateFrameFromTemplates("ScrollFrame", nil, host, { "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" })
	scroll:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -28, 8)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	edit:SetWidth(500)
	edit:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(edit)
	scroll:SetScript("OnSizeChanged", function(_, width)
		edit:SetWidth(width)
	end)

	frame.EditBox = edit
	frame:Hide()
	return frame
end

function UI:ShowTextDialog(title, text)
	self.textDialog = self.textDialog or self:CreateTextDialog()
	local frame = self.textDialog
	if frame.SetTitle then
		frame:SetTitle(title)
	elseif frame.TitleText then
		frame.TitleText:SetText(title)
	end
	frame.EditBox:SetText(text)
	frame:Show()
	frame.EditBox:SetFocus()
	frame.EditBox:HighlightText()
end
