-- The step frame (PLAN §3.1): a small Blizzard-styled panel with the current step — "<chapter> · step i/N", the step's
-- lines from ns.Conditions:Describe (objective progress included), the active sticky directives, an in-transit note —
-- and < > Skip buttons. Shift-drag moves it; lock, scale, alpha and position are kept in SignpostDB.stepFrame. It hides
-- in combat and while dead (both configurable). A secure button beside it uses the step's .use item; that button is
-- parented to UIParent, not to this frame, so hiding the frame in combat never touches a protected frame, and its
-- attributes, position and visibility change only out of combat (queued until PLAYER_REGEN_ENABLED).
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local StepFrame = {}
ns.StepFrame = StepFrame

local WIDTH = 260
local PADDING = 10
local GAP = 4
local HEADER_HEIGHT = 16
local ICON_SIZE = 14
local MAX_BODY_LINES = 5 -- PLAN §3.1: about five lines, the rest is cut off
local MAX_STICKY_LINES = 2
local BUTTON_HEIGHT = 20
local ITEM_BUTTON_SIZE = 32
local RENDER_DELAY = 0.2
local SCALE_MIN, SCALE_MAX = 0.5, 2
local ALPHA_MIN, ALPHA_MAX = 0.2, 1
local NORMAL_COLOR = "|cffffd100" -- Blizzard's NORMAL_FONT_COLOR_CODE
-- Global so a key binding or macro can `/click SignpostItemButton`.
local ITEM_BUTTON_NAME = "SignpostItemButton"
-- VERIFY(beta): clear of the minimap and the objective tracker at the default UI scale.
local DEFAULT_POSITION = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -300, y = -220 }
-- The Blizzard dialog border at a size that suits a small frame.
-- VERIFY(beta): Interface\DialogFrame\UI-DialogBox-Background-Dark exists on Forever (the border file is verified).
local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
-- The Objective Tracker's module header strip. VERIFY(beta): the atlas exists on Forever (without it: no strip).
local HEADER_ATLAS = "Objective-Header"

-- `pos` (nil until the frame is first moved) holds { point, relativePoint, x, y } relative to UIParent.
local DEFAULTS = {
	shown = true,
	locked = false,
	scale = 1,
	alpha = 1,
	hideInCombat = true,
	hideWhenDead = true,
	hideWithJournal = true,
}
ns.SavedVars:RegisterDefaults("account", "stepFrame", DEFAULTS)

local function settings()
	return ns.db and ns.db.stepFrame or DEFAULTS
end

local function inCombat()
	return Util.Call(InCombatLockdown) and true or false
end

local function isDead()
	return Util.Call(UnitIsDeadOrGhost, "player") and true or false
end

local function clamp(value, low, high, default)
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.max(low, math.min(high, value))
end

-- Text --------------------------------------------------------------------------------------------------------------

local function lineText(line)
	if type(line) == "string" then
		return line
	elseif type(line) == "table" and type(line.text) == "string" then
		return line.text
	end
end

-- The step's directive states from ns.Progress (a .craft count, a .path's next waypoint), or nil.
local function statesFor(step)
	local progress = ns.Progress
	if progress and progress.State and step.id ~= nil then
		local ok, states = ns.SafeCall(progress.State, progress, step.id)
		if ok and type(states) == "table" then
			return states
		end
	end
end

-- The step's display lines from ns.Conditions:Describe, as plain strings (a line may also be a table with `text`).
-- Lines Describe marks as sticky (its second result) are left to the "Ongoing:" lines (StepFrame:StickyLines).
function StepFrame.DescribeLines(step)
	local lines, conditions = {}, ns.Conditions
	if type(step) ~= "table" or not (conditions and conditions.Describe) then
		return lines
	end
	local ok, described, info = ns.SafeCall(conditions.Describe, conditions, step, ns.Context, statesFor(step))
	if ok and type(described) == "table" then
		for i, line in ipairs(described) do
			local meta = type(info) == "table" and info[i]
			local text = lineText(line)
			if text and text ~= "" and not (type(meta) == "table" and meta.sticky) then
				lines[#lines + 1] = text
			end
		end
	end
	return lines
end

-- One sticky directive's text: its ">> text" override, else its directive's description (with its state, when known:
-- a .craft count, a boarded transport).
local function describeDirective(directive, state)
	if type(directive) ~= "table" then
		return nil
	end
	if type(directive.text) == "string" and directive.text ~= "" then
		return (directive.text:gsub("^>>%s*", ""))
	end
	local def = directive.def
	if type(def) == "table" and def.describe then
		local ok, text = ns.SafeCall(def.describe, directive.args, ns.Context, state)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	if type(directive.name) == "string" then
		return "." .. directive.name
	end
end

-- The texts of a step's .sticky directives.
function StepFrame.DescribeSticky(step)
	local texts = {}
	if type(step) == "table" and type(step.sticky) == "table" then
		for _, directive in ipairs(step.sticky) do
			local text = describeDirective(directive)
			if text then
				texts[#texts + 1] = text
			end
		end
	end
	return texts
end

-- The texts of a step's sticky directives that are still active (ns.Progress:ActiveSticky: one satisfied since stays
-- away), each described with its state; all of its .sticky directives when Progress cannot tell.
function StepFrame.DescribeActiveSticky(step)
	local progress = ns.Progress
	if not (type(step) == "table" and step.id ~= nil and progress and progress.ActiveSticky) then
		return StepFrame.DescribeSticky(step)
	end
	local ok, active = ns.SafeCall(progress.ActiveSticky, progress, step.id)
	if not (ok and type(active) == "table") then
		return StepFrame.DescribeSticky(step)
	end
	local texts = {}
	for _, entry in ipairs(active) do
		local text = type(entry) == "table" and describeDirective(entry.directive, entry.state)
		if text then
			texts[#texts + 1] = text
		end
	end
	return texts
end

-- The sticky lines beside the current step: the still active .sticky directives of the current step and of the
-- sticky steps (ns.Progress:Sticky(), ns.Progress:ActiveSticky()), each text once and none that the body already
-- shows.
function StepFrame:StickyLines(current, bodyLines)
	local steps = {}
	if type(current) == "table" and type(current.sticky) == "table" and #current.sticky > 0 then
		steps[1] = current
	end
	local progress = ns.Progress
	local active = progress and progress.Sticky and progress:Sticky()
	for _, step in ipairs(type(active) == "table" and active or {}) do
		steps[#steps + 1] = step
	end
	local lines, seenSteps, seenTexts = {}, {}, {}
	for _, text in ipairs(bodyLines) do
		seenTexts[text] = true
	end
	for _, step in ipairs(steps) do
		local id = type(step) == "table" and (step.id or step) or nil
		if id and not seenSteps[id] then
			seenSteps[id] = true
			for _, text in ipairs(StepFrame.DescribeActiveSticky(step)) do
				if not seenTexts[text] then
					seenTexts[text] = true
					lines[#lines + 1] = text
				end
			end
		end
	end
	return lines
end

-- "<chapter> · step i/N", counted within the chapter when its first/last bounds hold the step, else in the guide.
local function headerText(guide, step)
	local chapters = type(guide) == "table" and guide.chapters
	local chapter = type(chapters) == "table" and chapters[step.chapter] or nil
	local name = type(chapter) == "table" and chapter.name or (type(guide) == "table" and guide.name) or ADDON_NAME
	local index = step.index
	local total = type(guide) == "table" and type(guide.steps) == "table" and #guide.steps or nil
	if
		type(chapter) == "table"
		and type(index) == "number"
		and type(chapter.first) == "number"
		and type(chapter.last) == "number"
		and index >= chapter.first
		and index <= chapter.last
	then
		index, total = index - chapter.first + 1, chapter.last - chapter.first + 1
	end
	if type(index) ~= "number" or type(total) ~= "number" or total < 1 then
		return name
	end
	return string.format(L["%s · step %d/%d"], name, index, total)
end

-- Step type icon: the kind of the first directive that says what the step is about (a plain .goto only when nothing
-- else does). Kinds are the pin kinds of UI/Pins.lua.
local DIRECTIVE_ICONS = {
	accept = "accept",
	turnin = "turnin",
	complete = "objective",
	use = "objective",
	path = "waypoint",
	fp = "taxi",
	fly = "taxi",
	boat = "dock",
	zeppelin = "dock",
	hs = "inn",
	home = "inn",
	train = "trainer",
	trainprof = "trainer",
	buy = "vendor",
	fish = "fish",
	collect = "gather",
}
local DIRECTIVE_KIND_ICONS = { quest = "accept", travel = "goto", profession = "gather" }

local function stepIconKind(step)
	local fallback
	for _, directive in ipairs(type(step.directives) == "table" and step.directives or {}) do
		local def = type(directive.def) == "table" and directive.def or nil
		local kind = DIRECTIVE_ICONS[directive.name] or (def and DIRECTIVE_KIND_ICONS[def.kind])
		if directive.name == "goto" or directive.name == "zone" then
			fallback = fallback or "goto"
		elseif kind then
			return kind
		end
	end
	return fallback
end

-- The destination of a transport the player is on, from the step's dock/taxi target labels.
local function transitDestination(step)
	local pins = ns.Pins
	for _, target in ipairs(pins and pins:Targets(step) or {}) do
		if
			type(target) == "table"
			and (target.kind == "dock" or target.kind == "taxi")
			and type(target.label) == "string"
			and target.label ~= ""
		then
			return target.label
		end
	end
end

function StepFrame:StatusText(step)
	local travel = ns.Travel
	if not (travel and travel.TransportState) or step.id == nil then
		return nil
	end
	local ok, state = ns.SafeCall(travel.TransportState, travel, step.id)
	if not ok or state ~= "boarded" then
		return nil
	end
	local destination = transitDestination(step)
	if destination then
		return string.format(L["In transit to %s..."], destination)
	end
	return L["In transit..."]
end

-- Height of a word-wrapped font string, capped at maxLines (falls back to counting lines where text cannot be
-- measured). VERIFY(beta): GetStringHeight right after SetText gives the wrapped height, and the cap matches what
-- SetMaxLines shows (no clipped or empty last line).
local function textHeight(fontString, maxLines)
	local text = fontString:GetText()
	if type(text) ~= "string" or text == "" then
		return 0
	end
	local _, size = fontString:GetFont()
	local lineHeight = (type(size) == "number" and size > 0 and size or 12) + 2
	local height = fontString:GetStringHeight()
	if type(height) ~= "number" or height <= 0 then
		local _, breaks = text:gsub("\n", "\n")
		height = (breaks + 1) * lineHeight
	end
	return math.min(height, maxLines * lineHeight)
end

-- Frame -------------------------------------------------------------------------------------------------------------

local function showButtonTooltip(button, text)
	local tooltip = GameTooltip
	if tooltip then
		tooltip:SetOwner(button, "ANCHOR_TOP")
		tooltip:SetText(text, 1, 1, 1)
		tooltip:Show()
	end
end

local function hideTooltip(owner)
	local tooltip = GameTooltip
	if tooltip and tooltip:IsOwned(owner) then
		tooltip:Hide()
	end
end

local function progressCall(method)
	local progress = ns.Progress
	if progress and progress[method] then
		progress[method](progress)
	end
end

local function createButton(parent, text, width, method, tooltip)
	local button = ns.UI.CreateFrameFromTemplates("Button", nil, parent, { "UIPanelButtonTemplate" })
	button:SetSize(width, BUTTON_HEIGHT)
	button:SetText(text)
	-- UIPanelButtonTemplate sized down, with the small Blizzard fonts.
	-- VERIFY(beta): the template's art still looks right at 20 px high.
	if GameFontNormalSmall then
		button:SetNormalFontObject(GameFontNormalSmall)
	end
	if GameFontHighlightSmall then
		button:SetHighlightFontObject(GameFontHighlightSmall)
	end
	if GameFontDisableSmall then
		button:SetDisabledFontObject(GameFontDisableSmall)
	end
	button:SetScript("OnClick", function()
		ns.SafeCall(progressCall, method)
	end)
	button:SetScript("OnEnter", function(self)
		showButtonTooltip(self, tooltip)
	end)
	button:SetScript("OnLeave", hideTooltip)
	return button
end

function StepFrame:CreateWidgets()
	local frame = ns.UI.CreateFrameFromTemplates("Frame", nil, UIParent, { "BackdropTemplate" })
	frame:SetWidth(WIDTH)
	frame:SetHeight(80)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	if frame.SetBackdrop then
		frame:SetBackdrop(BACKDROP)
	end
	frame:SetScript("OnDragStart", function()
		ns.SafeCall(StepFrame.OnDragStart, StepFrame)
	end)
	frame:SetScript("OnDragStop", function()
		ns.SafeCall(StepFrame.OnDragStop, StepFrame)
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			ns.SafeCall(StepFrame.OnRightClick, StepFrame)
		end
	end)

	local strip = frame:CreateTexture(nil, "BORDER")
	strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
	strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	strip:SetHeight(HEADER_HEIGHT + PADDING)
	if ns.Pins and ns.Pins.AtlasExists(HEADER_ATLAS) then
		strip:SetAtlas(HEADER_ATLAS)
	else
		strip:Hide()
	end
	frame.strip = strip

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING - 1)
	frame.icon = icon

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetHeight(HEADER_HEIGHT)
	frame.title = title

	local body = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	body:SetJustifyH("LEFT")
	body:SetJustifyV("TOP")
	body:SetWordWrap(true)
	body:SetMaxLines(MAX_BODY_LINES)
	body:SetWidth(WIDTH - 2 * PADDING)
	frame.body = body

	local sticky = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sticky:SetJustifyH("LEFT")
	sticky:SetWordWrap(true)
	sticky:SetMaxLines(MAX_STICKY_LINES)
	sticky:SetWidth(WIDTH - 2 * PADDING)
	frame.sticky = sticky

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	status:SetJustifyH("LEFT")
	status:SetWordWrap(true)
	status:SetMaxLines(MAX_STICKY_LINES)
	status:SetWidth(WIDTH - 2 * PADDING)
	frame.status = status

	frame.skip = createButton(frame, L["Skip"], 44, "Skip", L["Skip this step"])
	frame.skip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING + 2, PADDING - 2)
	frame.next = createButton(frame, ">", 24, "Next", L["Next step"])
	frame.next:SetPoint("RIGHT", frame.skip, "LEFT", -2, 0)
	frame.back = createButton(frame, "<", 24, "Back", L["Previous step"])
	frame.back:SetPoint("RIGHT", frame.next, "LEFT", -2, 0)

	frame:Hide()
	return frame
end

-- Builds the frame on first use. A failure is recorded once and the frame stays unavailable for the session.
function StepFrame:Build()
	if self.frame or self.unavailable then
		return self.frame
	end
	local ok, frame = ns.SafeCall(self.CreateWidgets, self)
	if not (ok and frame) then
		self.unavailable = true
		return nil
	end
	self.frame = frame
	self.inCombat = inCombat()
	self:ApplySettings()
	return frame
end

function StepFrame:Layout()
	local frame = self.frame
	local hasIcon = frame.icon:IsShown()
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + (hasIcon and ICON_SIZE + GAP or 0), -PADDING)
	frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -PADDING)
	local y = PADDING + HEADER_HEIGHT + GAP
	frame.body:ClearAllPoints()
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -y)
	y = y + textHeight(frame.body, MAX_BODY_LINES)
	for _, fontString in ipairs({ frame.sticky, frame.status }) do
		local height = textHeight(fontString, MAX_STICKY_LINES)
		if height > 0 then
			y = y + GAP
			fontString:ClearAllPoints()
			fontString:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -y)
			fontString:Show()
			y = y + height
		else
			fontString:Hide()
		end
	end
	frame:SetHeight(y + GAP + BUTTON_HEIGHT + PADDING - 2)
end

-- Shows the current step (or hides the frame when there is none).
function StepFrame:Render()
	local progress = ns.Progress
	local step = progress and progress.Current and progress:Current()
	local guide = progress and progress.Guide and progress:Guide()
	self.step = type(step) == "table" and step or nil
	if self.step then
		local frame = self:Build()
		if frame then
			self:Fill(frame, guide, self.step)
		end
	end
	self:UpdateVisibility()
	self:UpdateItemButton()
end

function StepFrame:Fill(frame, guide, step)
	frame.title:SetText(headerText(guide, step))
	local kind = stepIconKind(step)
	if kind and ns.Pins then
		ns.Pins.ApplyIcon(frame.icon, kind)
		frame.icon:Show()
	else
		frame.icon:Hide()
	end
	local lines = StepFrame.DescribeLines(step)
	frame.body:SetText(table.concat(lines, "\n"))
	local sticky = {}
	for i, text in ipairs(self:StickyLines(step, lines)) do
		sticky[i] = string.format("%s%s|r %s", NORMAL_COLOR, L["Ongoing:"], text)
	end
	frame.sticky:SetText(table.concat(sticky, "\n"))
	frame.status:SetText(self:StatusText(step) or "")
	frame.back:SetEnabled(type(step.index) ~= "number" or step.index > 1)
	self:Layout()
end

-- Coalesces bursts of CONTEXT_CHANGED / TRANSPORT_STATE into one render.
function StepFrame:RequestRender()
	if self.renderScheduled then
		return
	end
	self.renderScheduled = true
	C_Timer.After(RENDER_DELAY, function()
		StepFrame.renderScheduled = nil
		ns.SafeCall(StepFrame.Render, StepFrame)
	end)
end

local function journalShown()
	local journal = ns.Journal
	return journal and journal.IsShown and journal:IsShown() and true or false
end

function StepFrame:ShouldShow()
	local s = settings()
	if not (s.shown and self.step) then
		return false
	end
	if (s.hideInCombat and self.inCombat) or (s.hideWhenDead and isDead()) then
		return false
	end
	return not (s.hideWithJournal and journalShown())
end

-- The step frame is not protected (nothing secure is parented or anchored to it), so this works in combat too.
function StepFrame:UpdateVisibility()
	local frame = self.frame
	if not frame then
		return
	end
	if self:ShouldShow() then
		frame:Show()
	else
		frame:Hide()
	end
end

-- Settings ------------------------------------------------------------------------------------------------------------

function StepFrame:ApplyPosition()
	local frame = self.frame
	local pos = settings().pos
	frame:ClearAllPoints()
	if
		type(pos) == "table"
		and type(pos.point) == "string"
		and type(pos.relativePoint) == "string"
		and type(pos.x) == "number"
		and type(pos.y) == "number"
	then
		frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
	else
		local default = DEFAULT_POSITION
		frame:SetPoint(default.point, UIParent, default.relativePoint, default.x, default.y)
	end
end

function StepFrame:ApplySettings()
	local frame = self.frame
	if not frame then
		return
	end
	local s = settings()
	frame:SetScale(clamp(s.scale, SCALE_MIN, SCALE_MAX, 1))
	frame:SetAlpha(clamp(s.alpha, ALPHA_MIN, ALPHA_MAX, 1))
	self:ApplyPosition()
	self:UpdateVisibility()
	self:PositionItemButton()
end

function StepFrame:OnDragStart()
	local frame = self.frame
	if not frame or settings().locked or not Util.Call(IsShiftKeyDown) then
		return
	end
	frame:StartMoving()
	self.moving = true
end

function StepFrame:OnDragStop()
	local frame = self.frame
	if not (frame and self.moving) then
		return
	end
	self.moving = nil
	frame:StopMovingOrSizing()
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	if ns.db and type(point) == "string" and type(x) == "number" and type(y) == "number" then
		ns.db.stepFrame.pos = {
			point = point,
			relativePoint = type(relativePoint) == "string" and relativePoint or point,
			x = Util.Round(x, 1),
			y = Util.Round(y, 1),
		}
	end
	self:ApplyPosition()
	self:PositionItemButton()
end

-- Right-click is reserved for the journal (PLAN §3.2, Phase 4); until it exists this does nothing.
function StepFrame:OnRightClick()
	local journal = ns.Journal
	if journal and journal.Toggle then
		journal:Toggle(self.step)
	end
end

function StepFrame:SetShown(shown)
	ns.db.stepFrame.shown = shown and true or false
	self:Render()
	if shown and not self.step then
		Util.Print(L["The step frame appears once a guide is loaded."])
	end
end

function StepFrame:SetLocked(locked)
	ns.db.stepFrame.locked = locked and true or false
end

function StepFrame:SetScale(scale)
	ns.db.stepFrame.scale = clamp(scale, SCALE_MIN, SCALE_MAX, 1)
	self:ApplySettings()
	return ns.db.stepFrame.scale
end

function StepFrame:SetAlpha(alpha)
	ns.db.stepFrame.alpha = clamp(alpha, ALPHA_MIN, ALPHA_MAX, 1)
	self:ApplySettings()
	return ns.db.stepFrame.alpha
end

-- Back to the default place, scale and alpha, and shown.
function StepFrame:Reset()
	local s = ns.db.stepFrame
	s.pos, s.scale, s.alpha, s.shown = nil, 1, 1, true
	self:ApplySettings()
	self:Render()
end

-- Quest item button -----------------------------------------------------------------------------------------------

-- The item of a .use directive. Reads directive.args.itemID; args.item, args.id, args[1] or a bare number are
-- accepted too.
local function directiveItem(directive)
	if type(directive) ~= "table" or directive.name ~= "use" then
		return nil
	end
	local args = directive.args
	local id = args
	if type(args) == "table" then
		id = args.itemID or args.item or args.id or args[1]
	end
	id = tonumber(id)
	if id and id > 0 then
		return id
	end
end

local function useItem(step)
	for _, list in ipairs({ step.directives, step.sticky }) do
		for _, directive in ipairs(type(list) == "table" and list or {}) do
			local id = directiveItem(directive)
			if id then
				return id
			end
		end
	end
end

-- A `.home` step offers the Hearthstone on the same secure button; it is only offered, never cast by the addon.
local HEARTHSTONE_ITEM = 6948

local function homeItem(step)
	for _, directive in ipairs(type(step.directives) == "table" and step.directives or {}) do
		if type(directive) == "table" and directive.name == "home" then
			return (ns.Travel and ns.Travel.HEARTHSTONE_ITEM) or HEARTHSTONE_ITEM
		end
	end
end

local function itemCount(itemID)
	local context = ns.Context
	local count
	if context and context.ItemCount then
		count = context:ItemCount(itemID)
	else
		count = Util.Call(C_Item and C_Item.GetItemCount, itemID)
	end
	if type(count) == "number" and not Util.IsSecret(count) then
		return count
	end
	return 0
end

-- The item the button should offer now: the current step's .use item (or the Hearthstone for .home) while it is in
-- the bags (and the frame is enabled and the player alive, unless hideWhenDead is off).
function StepFrame:DesiredItem()
	local s, step = settings(), self.step
	if not (step and s.shown) or (s.hideWhenDead and isDead()) then
		return nil
	end
	local itemID = useItem(step) or homeItem(step)
	if itemID and itemCount(itemID) > 0 then
		return itemID
	end
end

function StepFrame:CreateItemButton()
	local button =
		ns.UI.CreateFrameFromTemplates("Button", ITEM_BUTTON_NAME, UIParent, { "SecureActionButtonTemplate" })
	button:SetSize(ITEM_BUTTON_SIZE, ITEM_BUTTON_SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(true)
	-- VERIFY(beta): with ActionButtonUseKeyDown the secure handler acts on the down or the up click; both are registered.
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("type", "item")
	-- The look of Blizzard's quest item buttons (objective tracker): slot border, pushed and highlight textures.
	-- VERIFY(beta): these Interface\Buttons files exist on Forever.
	button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
	local normal = button:GetNormalTexture()
	if normal then
		normal:ClearAllPoints()
		normal:SetPoint("CENTER", button, "CENTER", 0, 0)
		normal:SetSize(ITEM_BUTTON_SIZE * 64 / 36, ITEM_BUTTON_SIZE * 64 / 36)
	end
	button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	button.icon = icon
	local count =
		button:CreateFontString(nil, "OVERLAY", _G.NumberFontNormal and "NumberFontNormal" or "GameFontHighlightSmall")
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	button.count = count
	-- VERIFY(beta): CooldownFrameTemplate exists (not in the probe list; without it a plain Cooldown frame is used).
	local cooldown = ns.UI.CreateFrameFromTemplates("Cooldown", nil, button, { "CooldownFrameTemplate" })
	cooldown:SetAllPoints(button)
	button.cooldown = cooldown
	button:SetScript("OnEnter", function(owner)
		local tooltip, itemID = GameTooltip, StepFrame.shownItem
		if tooltip and itemID then
			tooltip:SetOwner(owner, "ANCHOR_LEFT")
			tooltip:SetItemByID(itemID)
			tooltip:Show()
		end
	end)
	button:SetScript("OnLeave", hideTooltip)
	button:Hide()
	self.itemButton = button
	return button
end

-- Count and cooldown: plain regions and a cooldown frame, safe to update in combat.
function StepFrame:UpdateItemDisplay()
	local button, itemID = self.itemButton, self.shownItem
	if not (button and itemID) then
		return
	end
	local count = itemCount(itemID)
	button.count:SetText(count > 1 and tostring(count) or "")
	local start, duration, enable = Util.Call(C_Container and C_Container.GetItemCooldown, itemID)
	local running = type(start) == "number"
		and type(duration) == "number"
		and not Util.IsSecret(start)
		and not Util.IsSecret(duration)
		and duration > 0
		and enable ~= false
		and enable ~= 0
	if running then
		button.cooldown:SetCooldown(start, duration)
	else
		button.cooldown:Clear()
	end
end

-- Asks for the button that fits the current step; protected changes wait for the end of combat.
function StepFrame:UpdateItemButton()
	local itemID = self:DesiredItem()
	self.desiredItem = itemID
	if itemID == self.shownItem then
		self:UpdateItemDisplay()
		return
	end
	if inCombat() then
		self.secureDirty = true
		return
	end
	self:ApplyItemButton()
end

function StepFrame:ApplyItemButton()
	self.secureDirty = nil
	local itemID, button = self.desiredItem, self.itemButton
	if not itemID then
		if button then
			button:Hide()
			button:SetAttribute("item", nil)
		end
		self.shownItem = nil
		return
	end
	button = button or self:CreateItemButton()
	-- VERIFY(beta): type "item" with "item:<itemID>" uses the item from the bags, by click and by /click.
	button:SetAttribute("type", "item")
	button:SetAttribute("item", "item:" .. itemID)
	button.icon:SetTexture(
		Util.Call(C_Item and C_Item.GetItemIconByID, itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
	)
	self.shownItem = itemID
	self:PositionItemButton()
	self:UpdateItemDisplay()
	button:Show()
end

-- Beside the step frame's top-left corner, in UIParent coordinates (anchoring it to the step frame would make the
-- step frame protected in combat).
function StepFrame:PositionItemButton()
	local button, frame = self.itemButton, self.frame
	if not button then
		return
	end
	if inCombat() then
		self.positionDirty = true
		return
	end
	self.positionDirty = nil
	local left, top = frame and frame:GetLeft(), frame and frame:GetTop()
	local scale, parentScale = frame and frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
	button:ClearAllPoints()
	if
		type(left) == "number"
		and type(top) == "number"
		and type(scale) == "number"
		and type(parentScale) == "number"
		and parentScale > 0
	then
		local ratio = scale / parentScale
		button:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left * ratio - GAP, top * ratio)
	else
		button:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
	end
end

function StepFrame:FlushSecure()
	if inCombat() then
		return
	end
	if self.secureDirty then
		self:ApplyItemButton()
	elseif self.positionDirty then
		self:PositionItemButton()
	end
end

-- Events --------------------------------------------------------------------------------------------------------------

ns.Events:RegisterMessage("GUIDE_LOADED", function()
	StepFrame:Render()
end)
ns.Events:RegisterMessage("STEP_CHANGED", function()
	StepFrame:Render()
end)
-- A sticky directive started or was satisfied (Engine/Progress.lua): the "Ongoing:" lines change.
ns.Events:RegisterMessage("STICKY_CHANGED", function()
	StepFrame:Render()
end)
ns.Events:RegisterMessage("CONTEXT_CHANGED", function()
	StepFrame:RequestRender()
end)
ns.Events:RegisterMessage("TRANSPORT_STATE", function()
	StepFrame:RequestRender()
end)
ns.Events:Register("PLAYER_LOGIN", function()
	StepFrame:Render()
end)
ns.Events:Register("PLAYER_REGEN_DISABLED", function()
	StepFrame.inCombat = true
	StepFrame:UpdateVisibility()
end)
ns.Events:Register("PLAYER_REGEN_ENABLED", function()
	StepFrame.inCombat = false
	StepFrame:UpdateVisibility()
	StepFrame:FlushSecure()
end)
for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
	ns.Events:Register(event, function()
		StepFrame:UpdateVisibility()
		StepFrame:UpdateItemButton()
	end)
end
ns.Events:Register("BAG_UPDATE_COOLDOWN", function()
	StepFrame:UpdateItemDisplay()
end)

-- Slash commands ------------------------------------------------------------------------------------------------------

ns.Slash:Register("show", function()
	StepFrame:SetShown(true)
end, L["show the step frame"])

ns.Slash:Register("hide", function()
	StepFrame:SetShown(false)
end, L["hide the step frame (the map pins stay)"])

ns.Slash:Register("lock", function(args)
	local word = (args or ""):lower()
	local locked = not settings().locked
	if word == "on" then
		locked = true
	elseif word == "off" then
		locked = false
	end
	StepFrame:SetLocked(locked)
	Util.Print(locked and L["Step frame locked."] or L["Step frame unlocked: Shift-drag to move it."])
end, L["lock or unlock the step frame (on | off; unlocked, Shift-drag moves it)"])

ns.Slash:Register("reset", function()
	StepFrame:Reset()
	Util.Print(L["Step frame reset to its default position, scale and alpha."])
end, L["put the step frame back where it started, at scale 1 and full alpha"])

ns.Slash:Register("scale", function(args)
	local value = tonumber(args)
	if not value then
		Util.Print(L["Step frame scale is %.2f (0.5 to 2)."], settings().scale or 1)
		return
	end
	Util.Print(L["Step frame scale set to %.2f."], StepFrame:SetScale(value))
end, L["step frame scale, 0.5 to 2 (e.g. 'scale 1.2')"])

ns.Slash:Register("alpha", function(args)
	local value = tonumber(args)
	if not value then
		Util.Print(L["Step frame alpha is %.2f (0.2 to 1)."], settings().alpha or 1)
		return
	end
	Util.Print(L["Step frame alpha set to %.2f."], StepFrame:SetAlpha(value))
end, L["step frame opacity, 0.2 to 1 (e.g. 'alpha 0.8')"])
