-- Shared UI pieces built from stock Blizzard templates: template-fallback frame creation and a copyable text dialog
-- (used by /signpost export).
local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

-- The marks of a list of things to do, plain text (no texture to depend on): the Journal's route list and the step
-- frame's quest lines use the same ones, so a done step and a done quest read alike.
UI.MARK = { done = "|cff40d040[x]|r", todo = "[ ]" }

local function hasTemplate(template)
	local getInfo = C_XMLUtil and C_XMLUtil.GetTemplateInfo
	if not getInfo then
		return true -- cannot tell in advance; CreateFrame decides
	end
	local ok, info = pcall(getInfo, template)
	return ok and info ~= nil
end

-- Creates a frame from the first template this client has. Every template used here exists on beta 1.60.1.70450
-- (FOREVER-API-NOTES); the fallbacks guard against later client changes. Returns the frame and the template used.
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

-- A stock Blizzard dialog: movable, in the dialog strata, closed by Escape. Returns the frame; UI:DialogHost(frame) is
-- where its content goes.
function UI:CreateDialogFrame(name, width, height)
	local frame, template = UI.CreateFrameFromTemplates(
		"Frame",
		name,
		UIParent,
		{ "ButtonFrameTemplate", "BasicFrameTemplateWithInset", "BackdropTemplate" }
	)
	frame:SetSize(width, height)
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
	tinsert(UISpecialFrames, name)
	return frame
end

function UI:DialogHost(frame)
	return type(frame.Inset) == "table" and frame.Inset or frame
end

function UI:SetDialogTitle(frame, title)
	if frame.SetTitle then
		frame:SetTitle(title)
	elseif frame.TitleText then
		frame.TitleText:SetText(title)
	end
end

function UI:CreateTextDialog()
	local frame = UI:CreateDialogFrame(DIALOG_NAME, 560, 420)

	local host = UI:DialogHost(frame)
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
	UI:SetDialogTitle(frame, title)
	frame.EditBox:SetText(text)
	frame:Show()
	frame.EditBox:SetFocus()
	frame.EditBox:HighlightText()
end
