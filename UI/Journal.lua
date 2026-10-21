-- The Journal: the big window (PLAN §3.2). A guide picker, a search box and three tabs: Route (the chapters and their
-- steps, click one to jump to it), the class tab (the class's quest chains and how far along they are) and Settings
-- (the step card, the pins, data sharing, the detected profession plan). Opened with /signpost, a click on the minimap
-- button or the AddOn Compartment entry, the quick menu (also reached by a right-click on the step card) or a key
-- binding: all of those are UI/Launcher.lua. Stock Blizzard templates only (ButtonFrameTemplate,
-- PanelTabButtonTemplate, SearchBoxTemplate, WowStyle1DropdownTemplate, UICheckButtonTemplate, UIPanelButtonTemplate,
-- the scroll frame templates).
-- VERIFY(beta): layout and templates in the real client (FOREVER-API-NOTES "Open probes"); the specs run on a mock.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local UI = ns.UI

local Journal = {}
ns.Journal = Journal

local NAME = "SignpostJournal"
local WIDTH, HEIGHT = 800, 560
local LEFT_WIDTH = 210
local ROW = 22
local AUTOMATION_X = 470 -- the Settings tab's second column, in pane coordinates
-- The Settings tab's check boxes. UICheckButtonTemplate is 32 square; eleven of them in the first column (two more
-- came with the minimap button's settings) would have pushed the card steppers and the plan text over the buttons at
-- the bottom of the pane, so the boxes are drawn smaller: eleven rows take what nine took.
-- VERIFY(beta): the column fits the pane (FOREVER-API-NOTES "Open probes").
local CHECK_SIZE = 26
local FAR_JUMP = 20 -- a click on a step further away than this needs Shift
local HIGHLIGHT_SECONDS = 5
local TABS = { "route", "class", "settings" }

ns.SavedVars:RegisterDefaults("account", "journal", { tab = "route" })

local function progress()
	return ns.Progress
end

local function guide()
	local p = progress()
	return p and p.Guide and p:Guide() or nil
end

local function currentIndex()
	local p = progress()
	if p and p.Current then
		local _, index = p:Current()
		return index
	end
end

-- The index of the chapter the current step is in (Progress:CurrentChapter returns index, chapter), or nil.
local function currentChapterIndex()
	local p = progress()
	if p and p.CurrentChapter then
		return (p:CurrentChapter())
	end
end

local function describe(step)
	local p = progress()
	if p and p.Describe then
		local ok, text = ns.SafeCall(p.Describe, p, step)
		if ok and type(text) == "string" then
			return text
		end
	end
	return tostring(step.id)
end

-- Scroll lists ----------------------------------------------------------------------------------------------------
-- A list of buttons in a scroll frame. The route lists hold one chapter at a time (tens of rows), so no virtualisation.

local function newList(parent, width)
	local scroll =
		UI.CreateFrameFromTemplates("ScrollFrame", nil, parent, { "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" })
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(width, 1)
	scroll:SetScrollChild(child)
	return { scroll = scroll, child = child, rows = {}, width = width }
end

local function listRow(list, index, onClick, onEnter)
	local row = list.rows[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, list.child)
	row:SetSize(list.width, ROW)
	row:SetPoint("TOPLEFT", list.child, "TOPLEFT", 0, -(index - 1) * ROW)
	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(row)
	highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	highlight:SetBlendMode("ADD")
	row.flash = row:CreateTexture(nil, "BACKGROUND")
	row.flash:SetAllPoints(row)
	row.flash:SetColorTexture(1, 0.82, 0, 0.25)
	row.flash:Hide()
	row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
	row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	row.text:SetJustifyH("LEFT")
	row.text:SetWordWrap(false)
	row:SetScript("OnClick", function(self, button)
		ns.SafeCall(onClick, self, button)
	end)
	row:SetScript("OnEnter", function(self)
		if onEnter then
			ns.SafeCall(onEnter, self)
		end
	end)
	row:SetScript("OnLeave", function()
		if GameTooltip and GameTooltip.Hide then
			GameTooltip:Hide()
		end
	end)
	list.rows[index] = row
	return row
end

-- Fills the list: item i is shown on row i through apply(row, item, i); the other rows are hidden.
local function fillList(list, items, onClick, onEnter, apply)
	for i, item in ipairs(items) do
		local row = listRow(list, i, onClick, onEnter)
		row.item = item
		row:Show()
		apply(row, item, i)
	end
	for i = #items + 1, #list.rows do
		list.rows[i].item = nil
		list.rows[i]:Hide()
	end
	list.child:SetHeight(math.max(1, #items * ROW))
end

local function scrollTo(list, index)
	local y = math.max(0, (index - 3) * ROW)
	if list.scroll.SetVerticalScroll then
		list.scroll:SetVerticalScroll(y)
	end
end

-- Route tab -------------------------------------------------------------------------------------------------------

local MARK = { done = UI.MARK.done, skipped = "|cff909090[-]|r", current = "|cffffd100>|r", todo = UI.MARK.todo }

local function stepMark(step, current)
	local p = progress()
	if step.index == current then
		return MARK.current
	elseif p and p:IsDone(step.id) then
		return MARK.done
	elseif p and p:IsSkipped(step.id) then
		return MARK.skipped
	end
	return MARK.todo
end

local function chapterCounts(g, chapter)
	local p, done, total = progress(), 0, 0
	for i = chapter.first or 1, chapter.last or 0 do
		local step = g.steps[i]
		if step then
			total = total + 1
			if p and (p:IsDone(step.id) or p:IsSkipped(step.id)) then
				done = done + 1
			end
		end
	end
	return done, total
end

local function chapterLabel(chapter)
	local levels = chapter.levels
	local range = type(levels) == "table" and levels[1] and string.format("%d-%d ", levels[1], levels[2] or levels[1])
		or ""
	return (chapter.dungeon and "[D] " or "") .. range .. tostring(chapter.name or "?")
end

function Journal:ChapterOfStep(step)
	return step and step.chapter or nil
end

function Journal:StepsToShow()
	local g = guide()
	if not g then
		return {}
	end
	local query = (self.query or ""):lower()
	local steps = {}
	if query ~= "" then
		for _, step in ipairs(g.steps) do
			if describe(step):lower():find(query, 1, true) then
				steps[#steps + 1] = step
				if #steps >= 200 then
					break
				end
			end
		end
		return steps, true
	end
	local chapter = g.chapters[self.chapter or 0]
	if chapter then
		for i = chapter.first or 1, chapter.last or 0 do
			if g.steps[i] then
				steps[#steps + 1] = g.steps[i]
			end
		end
	end
	return steps, false
end

function Journal:SelectChapter(index)
	self.chapter = index
	self.query = nil
	if self.frame and self.frame.Search then
		self.frame.Search:SetText("")
	end
	self:Refresh()
end

function Journal:JumpTo(step)
	local p = progress()
	if not (p and p.JumpToId and step) then
		return
	end
	local current = currentIndex() or step.index
	if math.abs(step.index - current) > FAR_JUMP and not Util.Call(IsShiftKeyDown) then
		Util.Print(L["That step is more than %d steps away: hold Shift and click to jump there."], FAR_JUMP)
		return
	end
	p:JumpToId(step.id)
end

function Journal:RefreshRoute()
	local frame = self.frame
	local g = guide()
	local pane = frame.route
	if not g then
		pane.title:SetText(L["No guide is loaded for this character yet."])
		fillList(pane.chapters, {}, function() end, nil, function() end)
		fillList(pane.steps, {}, function() end, nil, function() end)
		pane.skip:Hide()
		return
	end
	local chapter = g.chapters[self.chapter or 0]
	if not chapter then
		self.chapter = currentChapterIndex() or 1
		chapter = g.chapters[self.chapter]
	end
	local currentChapter = currentChapterIndex()
	fillList(
		pane.chapters,
		g.chapters,
		function(row)
			Journal:SelectChapter(row.index)
		end,
		nil,
		function(row, item, i)
			row.index = i
			local done, total = chapterCounts(g, item)
			local mark = (i == currentChapter and "|cffffd100>|r " or "")
			local color = i == self.chapter and "|cffffffff" or "|cffc8c8c8"
			row.text:SetText(
				string.format("%s%s%s|r |cff909090(%d/%d)|r", mark, color, chapterLabel(item), done, total)
			)
		end
	)
	local steps, searching = self:StepsToShow()
	local current = currentIndex()
	local title = searching and string.format(L["Search: %d steps"], #steps)
		or (chapter and chapterLabel(chapter))
		or ""
	pane.title:SetText(title)
	fillList(pane.steps, steps, function(row)
		Journal:JumpTo(row.item)
	end, function(row)
		if GameTooltip and GameTooltip.SetOwner then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(string.format(L["Step %d"], row.item.index), 1, 0.82, 0)
			for part in describe(row.item):gmatch("[^/]+") do
				GameTooltip:AddLine((part:gsub("^%s+", ""):gsub("%s+$", "")), 1, 1, 1, true)
			end
			GameTooltip:AddLine(L["Click to go to this step."], 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end
	end, function(row, step)
		local text = describe(step)
		row.text:SetText(string.format("%s |cff909090%d|r  %s", stepMark(step, current), step.index, text))
		local flashing = self.highlightStep == step.id and (GetTime() < (self.highlightUntil or 0))
		if flashing then
			row.flash:Show()
		else
			row.flash:Hide()
		end
	end)
	if chapter and chapter.dungeon and not searching then
		pane.skip:Show()
		pane.skip:SetChecked(progress():ChapterSkipped(self.chapter) and true or false)
	else
		pane.skip:Hide()
	end
end

local function buildRoute(frame, host)
	local pane = CreateFrame("Frame", nil, host)
	pane:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -44)
	pane:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 8)
	local leftHost = CreateFrame("Frame", nil, pane)
	leftHost:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
	leftHost:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
	leftHost:SetWidth(LEFT_WIDTH)
	pane.chapters = newList(leftHost, LEFT_WIDTH - 24)
	pane.chapters.scroll:SetPoint("TOPLEFT", leftHost, "TOPLEFT", 0, 0)
	pane.chapters.scroll:SetPoint("BOTTOMRIGHT", leftHost, "BOTTOMRIGHT", -22, 0)
	local rightHost = CreateFrame("Frame", nil, pane)
	rightHost:SetPoint("TOPLEFT", leftHost, "TOPRIGHT", 10, 0)
	rightHost:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
	pane.title = rightHost:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	pane.title:SetPoint("TOPLEFT", rightHost, "TOPLEFT", 4, 0)
	pane.title:SetJustifyH("LEFT")
	pane.skip = CreateFrame("CheckButton", nil, rightHost, "UICheckButtonTemplate")
	-- left of the two buttons (110 + 130 wide), its label to the left of the box, so nothing overlaps
	pane.skip:SetPoint("TOPRIGHT", rightHost, "TOPRIGHT", -262, 6)
	pane.skipLabel = rightHost:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	pane.skipLabel:SetPoint("RIGHT", pane.skip, "LEFT", -2, 1)
	pane.skipLabel:SetText(L["Skip this dungeon"])
	pane.skip:SetScript("OnClick", function(button)
		ns.SafeCall(function()
			local p = progress()
			if p and p.SetChapterSkipped and Journal.chapter then
				p:SetChapterSkipped(Journal.chapter, button:GetChecked() and true or false)
				Journal:Refresh()
			end
		end)
	end)
	local now = CreateFrame("Button", nil, rightHost, "UIPanelButtonTemplate")
	now:SetSize(110, 22)
	now:SetPoint("TOPRIGHT", rightHost, "TOPRIGHT", -4, 0)
	now:SetText(L["Current step"])
	now:SetScript("OnClick", function()
		ns.SafeCall(function()
			Journal:ShowCurrent()
		end)
	end)
	local report = CreateFrame("Button", nil, rightHost, "UIPanelButtonTemplate")
	report:SetSize(130, 22)
	report:SetPoint("TOPRIGHT", rightHost, "TOPRIGHT", -118, 0)
	report:SetText(L["Report this step"])
	report:SetScript("OnClick", function()
		ns.SafeCall(function()
			if ns.Report then
				ns.Report:Add()
			end
		end)
	end)
	pane.report = report
	pane.steps = newList(rightHost, 800 - LEFT_WIDTH - 70)
	pane.steps.scroll:SetPoint("TOPLEFT", rightHost, "TOPLEFT", 0, -30)
	pane.steps.scroll:SetPoint("BOTTOMRIGHT", rightHost, "BOTTOMRIGHT", -22, 0)
	frame.route = pane
	return pane
end

-- Class tab -------------------------------------------------------------------------------------------------------

function Journal:ClassChains()
	local player = ns.Player or {}
	local module = ns.Classes and ns.Classes.Get and ns.Classes:Get(player.classFile)
	local chains = {}
	for _, chain in ipairs(module and module.classQuests or {}) do
		local races = chain.races
		local mine = type(races) ~= "table" or #races == 0
		for _, race in ipairs(type(races) == "table" and races or {}) do
			if race == "*" or race == player.raceFile then
				mine = true
			end
		end
		if mine then
			chains[#chains + 1] = chain
		end
	end
	return chains
end

local function chainStatus(chain)
	if chain.pending then
		return L["new in Forever: quest IDs not known yet"]
	end
	local context = ns.Context
	local done, active, total = 0, 0, #(chain.quests or {})
	for _, id in ipairs(chain.quests or {}) do
		if context and context.QuestTurnedIn and context:QuestTurnedIn(id) then
			done = done + 1
		elseif context and context.QuestInLog and context:QuestInLog(id) then
			active = active + 1
		end
	end
	if total > 0 and done == total then
		return L["done"]
	elseif done > 0 or active > 0 then
		return string.format(L["in progress (%d of %d quests turned in)"], done, total)
	end
	return L["not started"]
end

function Journal:RefreshClass()
	local pane = self.frame.class
	local chains = self:ClassChains()
	pane.title:SetText(string.format(L["%s class quests"], tostring((ns.Player or {}).class or "")))
	fillList(pane.list, chains, function() end, nil, function(row, chain)
		local level = chain.level and string.format(L["level %d"], chain.level) or ""
		row.text:SetText(string.format("%s |cff909090(%s)|r: %s", tostring(chain.name), level, chainStatus(chain)))
	end)
end

local function buildClass(frame, host)
	local pane = CreateFrame("Frame", nil, host)
	pane:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -44)
	pane:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 8)
	pane.title = pane:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	pane.title:SetPoint("TOPLEFT", pane, "TOPLEFT", 4, 0)
	pane.note = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	pane.note:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -6)
	pane.note:SetPoint("RIGHT", pane, "RIGHT", -8, 0)
	pane.note:SetJustifyH("LEFT")
	pane.note:SetWordWrap(true)
	pane.note:SetText(
		L["The chains the route follows. Forever's own class quests are marked: "]
			.. L["they are added once their quest IDs are recorded."]
	)
	pane.list = newList(pane, 800 - 70)
	pane.list.scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -56)
	pane.list.scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -22, 0)
	frame.class = pane
	return pane
end

-- Settings tab ----------------------------------------------------------------------------------------------------

local function stepFrameSetting(key)
	return ns.db and ns.db.stepFrame and ns.db.stepFrame[key]
end

local function plainSetting(table, key, after)
	return function(value)
		if ns.db and ns.db[table] then
			ns.db[table][key] = value and true or false
		end
		if after then
			after()
		end
	end
end

local function settingsList()
	local stepFrame = function()
		return ns.StepFrame
	end
	local pins = function()
		return ns.Pins
	end
	local function refreshStepFrame()
		local s = stepFrame()
		if s and s.ApplySettings then
			s:ApplySettings()
		end
		if s and s.Render then
			s:Render()
		end
	end
	local function refreshPins()
		local p = pins()
		if p and p.Refresh then
			p:Refresh(true)
		end
	end
	-- Automation (Automation/*.lua): every toggle off by default, kept per character; shown in the second column.
	local function automation(label, key)
		return {
			label = label,
			column = 2,
			get = function()
				return ns.Automation ~= nil and ns.Automation:Settings()[key] == true
			end,
			set = function(value)
				if ns.char and type(ns.char.automation) == "table" then
					ns.char.automation[key] = value and true or false
				end
			end,
		}
	end
	return {
		{
			label = L["Show the step card"],
			get = function()
				return stepFrameSetting("shown")
			end,
			set = function(value)
				stepFrame():SetShown(value)
			end,
		},
		{
			label = L["Lock the step card (Shift-drag moves it when unlocked)"],
			get = function()
				return stepFrameSetting("locked")
			end,
			set = function(value)
				stepFrame():SetLocked(value)
			end,
		},
		{
			label = L["Grow the step card upwards (its bottom edge stays where it is)"],
			get = function()
				return stepFrameSetting("growUp")
			end,
			set = function(value)
				stepFrame():SetGrowUp(value)
			end,
		},
		{
			label = L["Hide the step card in combat"],
			get = function()
				return stepFrameSetting("hideInCombat")
			end,
			set = plainSetting("stepFrame", "hideInCombat", refreshStepFrame),
		},
		{
			label = L["Hide the step card while this window is open"],
			get = function()
				return stepFrameSetting("hideWithJournal")
			end,
			set = plainSetting("stepFrame", "hideWithJournal", refreshStepFrame),
		},
		{
			label = L["Show the next step on the minimap"],
			get = function()
				return ns.db and ns.db.pins and ns.db.pins.minimap
			end,
			set = function(value)
				pins():SetEnabled("minimap", value)
			end,
		},
		{
			label = L["Show the next step on the world map"],
			get = function()
				return ns.db and ns.db.pins and ns.db.pins.worldMap
			end,
			set = function(value)
				pins():SetEnabled("worldMap", value)
			end,
		},
		{
			label = L["Also show the steps after the next one"],
			get = function()
				return ns.db and ns.db.pins and ns.db.pins.showNext
			end,
			set = plainSetting("pins", "showNext", refreshPins),
		},
		{
			label = L["Show the minimap button"],
			get = function()
				return ns.Launcher ~= nil and not ns.Launcher:ButtonHidden()
			end,
			set = function(value)
				ns.Launcher:SetButtonHidden(not value)
			end,
		},
		{
			label = L["Lock the minimap button's position"],
			get = function()
				return ns.Launcher ~= nil and ns.Launcher:ButtonLocked()
			end,
			set = function(value)
				ns.Launcher:SetButtonLocked(value)
			end,
		},
		{
			label = L["Help improve the guides: record where NPCs and quests are while I play"],
			get = function()
				return ns.Contribute and ns.Contribute:Enabled()
			end,
			set = function(value)
				if ns.Contribute then
					ns.Contribute:SetEnabled(value)
				end
			end,
		},
		automation(L["Accept the guide's quests"], "quests"),
		automation(L["Accept every non-trivial quest too"], "acceptAll"),
		automation(L["Turn in the guide's quests"], "turnIn"),
		automation(L["Turn in every completable quest too"], "turnInAll"),
		automation(L["Never pick rewards: always let me choose"], "rewardAsk"),
		automation(L["Gossip: single option, set the hearth"], "gossip"),
		automation(L["Take the flights the guide asks for"], "taxi"),
		automation(L["Train the spells the guide lists"], "trainer"),
		automation(L["Buy the items the guide lists"], "vendor"),
		-- The quest tracker (Engine/Tracking.lua), under a header of its own in the second column. Its default is
		-- Tracking.DEFAULT_ENABLED; only a choice made here is saved.
		{
			section = L["Quest tracker"],
			label = L["Track only the current step's quests"],
			column = 2,
			get = function()
				return ns.Tracking ~= nil and ns.Tracking:Enabled()
			end,
			set = function(value)
				if ns.Tracking then
					ns.Tracking:SetEnabled(value)
				end
			end,
		},
	}
end

function Journal:RefreshSettings()
	local pane = self.frame.settings
	for _, box in ipairs(pane.boxes) do
		box.check:SetChecked(box.def.get() and true or false)
	end
	local s = ns.db and ns.db.stepFrame or {}
	pane.scaleValue:SetText(string.format("%.1f", s.scale or 1))
	pane.alphaValue:SetText(string.format("%.1f", s.alpha or 1))
	pane.plan:SetText(self:PlanText())
	local selected = ns.Guides and ns.Guides.Selected and ns.Guides:Selected(ns.Player)
	local g = guide()
	pane.guideInfo:SetText(
		string.format(L["Guide: %s"], tostring((g and g.name) or (selected and selected.name) or L["none"]))
	)
	local declined = {}
	local plan = ns.Professions and ns.Professions.Current and ns.Professions:Current() or nil
	for key in pairs(plan and plan.declined or {}) do
		declined[#declined + 1] = key
	end
	table.sort(declined)
	for i, button in ipairs(pane.restore) do
		local key = declined[i]
		button.key = key
		if key then
			button:SetText(string.format(L["Restore %s"], key))
			button:Show()
		else
			button:Hide()
		end
	end
	if ns.isDev then
		pane.dev:SetText(L["This is a development build: it records whatever the box says."])
	else
		pane.dev:SetText("")
	end
end

function Journal:PlanText()
	local plan = ns.Professions and ns.Professions.Current and ns.Professions:Current() or nil
	if not plan then
		return L["Professions: not detected yet."]
	end
	local function list(keys)
		return (keys and #keys > 0) and table.concat(keys, ", ") or L["none"]
	end
	return string.format(
		L["Professions: primary %s; secondary %s (detected from what this character has learned)."],
		list(plan.primary),
		list(plan.secondary)
	)
end

local function stepper(parent, anchor, label, change)
	local text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
	text:SetText(label)
	local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	minus:SetSize(24, 22)
	minus:SetPoint("LEFT", text, "RIGHT", 12, 0)
	minus:SetText("-")
	local value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("LEFT", minus, "RIGHT", 8, 0)
	value:SetWidth(34)
	local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	plus:SetSize(24, 22)
	plus:SetPoint("LEFT", value, "RIGHT", 8, 0)
	plus:SetText("+")
	minus:SetScript("OnClick", function()
		ns.SafeCall(change, -0.1)
		Journal:Refresh()
	end)
	plus:SetScript("OnClick", function()
		ns.SafeCall(change, 0.1)
		Journal:Refresh()
	end)
	return text, value
end

local function buildSettings(frame, host)
	local pane = CreateFrame("Frame", nil, host)
	pane:SetPoint("TOPLEFT", host, "TOPLEFT", 14, -44)
	pane:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -14, 8)
	pane.guideInfo = pane:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	pane.guideInfo:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
	pane.guideInfo:SetJustifyH("LEFT")
	local auto = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	auto:SetSize(190, 22)
	auto:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 2)
	auto:SetText(L["Choose the guide for me"])
	auto:SetScript("OnClick", function()
		ns.SafeCall(function()
			ns.Guides:Select(nil, ns.Player)
			Journal:Refresh()
		end)
	end)
	pane.boxes, pane.sectionHeaders = {}, {}
	local anchor = pane.guideInfo
	-- The second column: Automation, to the right of the step card and pin settings (the pane is not tall enough for one).
	pane.automationHeader = pane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	pane.automationHeader:SetPoint("TOPLEFT", pane, "TOPLEFT", AUTOMATION_X, -36)
	pane.automationHeader:SetText(L["Automation (off by default; Shift skips it)"])
	local anchor2 = pane.automationHeader
	for _, def in ipairs(settingsList()) do
		local check = CreateFrame("CheckButton", nil, pane, "UICheckButtonTemplate")
		check:SetSize(CHECK_SIZE, CHECK_SIZE)
		if def.column == 2 then
			-- A box with a `section` starts a small header of its own in the column; the check box right under a header
			-- sits 4 to its left, as under the Automation header (the box's art has that much padding).
			local underHeader = anchor2 == pane.automationHeader
			if def.section then
				local header = pane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
				header:SetPoint("TOPLEFT", anchor2, "BOTTOMLEFT", underHeader and 0 or 4, -10)
				header:SetText(def.section)
				pane.sectionHeaders[#pane.sectionHeaders + 1] = header
				anchor2, underHeader = header, true
			end
			check:SetPoint("TOPLEFT", anchor2, "BOTTOMLEFT", underHeader and -4 or 0, -2)
			anchor2 = check
		else
			check:SetPoint(
				"TOPLEFT",
				anchor,
				"BOTTOMLEFT",
				anchor == pane.guideInfo and -4 or 0,
				anchor == pane.guideInfo and -12 or -2
			)
		end
		local label = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		label:SetPoint("LEFT", check, "RIGHT", 2, 1)
		label:SetText(def.label)
		check:SetScript("OnClick", function(button)
			ns.SafeCall(function()
				def.set(button:GetChecked() and true or false)
				Journal:Refresh()
			end)
		end)
		pane.boxes[#pane.boxes + 1] = { check = check, def = def }
		if def.column ~= 2 then
			anchor = check
		end
	end
	local scaleLabel
	scaleLabel, pane.scaleValue = stepper(pane, anchor, L["Step card size"], function(delta)
		local s = ns.StepFrame
		s:SetScale(((ns.db.stepFrame.scale or 1) * 10 + delta * 10 + 0.5) / 10)
	end)
	pane.alphaLabel, pane.alphaValue = stepper(pane, scaleLabel, L["Step card opacity"], function(delta)
		local s = ns.StepFrame
		s:SetAlpha(((ns.db.stepFrame.alpha or 1) * 10 + delta * 10 + 0.5) / 10)
	end)
	pane.plan = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	pane.plan:SetPoint("TOPLEFT", pane.alphaLabel, "BOTTOMLEFT", 0, -18)
	pane.plan:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
	pane.plan:SetJustifyH("LEFT")
	pane.plan:SetWordWrap(true)
	pane.restore = {}
	local previous = pane.plan
	for i = 1, 4 do
		local button = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
		button:SetSize(190, 22)
		button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -6)
		button:SetScript("OnClick", function(self)
			ns.SafeCall(function()
				if self.key and ns.Professions and ns.Professions.Restore then
					ns.Professions:Restore(self.key)
					Journal:Refresh()
				end
			end)
		end)
		button:Hide()
		pane.restore[i] = button
		previous = button
	end
	pane.dev = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	pane.dev:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 34)
	local share = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	share:SetSize(260, 24)
	share:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 4)
	share:SetText(L["How do I share what was recorded?"])
	share:SetScript("OnClick", function()
		ns.SafeCall(function()
			if ns.UI and ns.UI.Contribute then
				ns.UI.Contribute:Show()
			end
		end)
	end)
	frame.settings = pane
	return pane
end

-- The window ------------------------------------------------------------------------------------------------------

function Journal:SelectTab(name)
	local frame = self.frame
	if not frame then
		return
	end
	local index
	for i, tab in ipairs(TABS) do
		if tab == name then
			index = i
		end
	end
	if not index or (name == "class" and #self:ClassChains() == 0) then
		name, index = "route", 1
	end
	self.tab = name
	if ns.db and ns.db.journal then
		ns.db.journal.tab = name
	end
	for _, tab in ipairs(TABS) do
		frame[tab]:SetShown(tab == name)
	end
	if PanelTemplates_SetTab and frame.tabButtons then
		pcall(PanelTemplates_SetTab, frame, index)
	end
	frame.Search:SetShown(name == "route")
	self:Refresh()
end

function Journal:Refresh()
	local frame = self.frame
	if not (frame and frame:IsShown()) then
		return
	end
	local g = guide()
	UI:SetDialogTitle(frame, g and string.format("Signpost - %s", tostring(g.name)) or "Signpost")
	if frame.guideDropdown and frame.guideDropdown.GenerateMenu then
		pcall(frame.guideDropdown.GenerateMenu, frame.guideDropdown)
	end
	if self.tab == "route" then
		self:RefreshRoute()
	elseif self.tab == "class" then
		self:RefreshClass()
	else
		self:RefreshSettings()
	end
end

local function buildGuideMenu(_, root)
	for _, def in ipairs(ns.Guides:All()) do
		if ns.Guides:Compatible(def, ns.Player) then
			root:CreateRadio(def.name or def.id, function()
				local current = ns.Guides:Selected(ns.Player)
				return current and current.id == def.id
			end, function()
				ns.SafeCall(function()
					ns.Guides:Select(def.id, ns.Player)
				end)
			end, def.id)
		end
	end
end

function Journal:Create()
	local frame = UI:CreateDialogFrame(NAME, WIDTH, HEIGHT)
	UI:SetDialogTitle(frame, "Signpost")
	local host = UI:DialogHost(frame)

	local dropdown
	local ok, created = pcall(CreateFrame, "DropdownButton", nil, host, "WowStyle1DropdownTemplate")
	if ok and created then
		dropdown = created
		dropdown:SetWidth(260)
		dropdown:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -10)
		if dropdown.SetupMenu then
			dropdown:SetupMenu(function(menu, root)
				ns.SafeCall(buildGuideMenu, menu, root)
			end)
		end
	end
	frame.guideDropdown = dropdown

	local search = CreateFrame("EditBox", nil, host, "SearchBoxTemplate")
	search:SetSize(220, 20)
	search:SetPoint("TOPRIGHT", host, "TOPRIGHT", -14, -12)
	search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function(box)
		ns.SafeCall(function()
			local text = box:GetText()
			if text ~= (Journal.query or "") then
				Journal.query = text
				Journal:Refresh()
			end
		end)
	end)
	frame.Search = search

	buildRoute(frame, host)
	buildClass(frame, host)
	buildSettings(frame, host)

	frame.tabButtons = {}
	local titles =
		{ route = L["Route"], class = tostring((ns.Player or {}).class or L["Class"]), settings = L["Settings"] }
	for i, name in ipairs(TABS) do
		local tab = CreateFrame("Button", NAME .. "Tab" .. i, frame, "PanelTabButtonTemplate")
		tab:SetID(i)
		tab:SetText(titles[name])
		if i == 1 then
			tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 14, 2)
		else
			tab:SetPoint("LEFT", frame.tabButtons[i - 1], "RIGHT", -14, 0)
		end
		tab:SetScript("OnClick", function()
			ns.SafeCall(function()
				Journal:SelectTab(name)
			end)
		end)
		frame.tabButtons[i] = tab
	end
	frame.numTabs = #TABS
	if PanelTemplates_SetNumTabs then
		pcall(PanelTemplates_SetNumTabs, frame, #TABS)
	end

	frame:SetScript("OnShow", function()
		ns.SafeCall(function()
			Journal:AfterVisibility()
		end)
	end)
	frame:SetScript("OnHide", function()
		ns.SafeCall(function()
			Journal:AfterVisibility()
		end)
	end)
	frame:Hide()
	return frame
end

-- The step card hides while this window is open (its hideWithJournal setting): tell it.
function Journal:AfterVisibility()
	local stepFrame = ns.StepFrame
	if stepFrame and stepFrame.UpdateVisibility then
		stepFrame:UpdateVisibility()
	end
end

function Journal:IsShown()
	return self.frame ~= nil and self.frame:IsShown() and true or false
end

function Journal:Show(tab)
	self.frame = self.frame or self:Create()
	self.frame:Show()
	self:SelectTab(tab or (ns.db and ns.db.journal and ns.db.journal.tab) or "route")
	if not self.chapter then
		self.chapter = currentChapterIndex()
	end
	self:Refresh()
end

function Journal:Hide()
	if self.frame then
		self.frame:Hide()
	end
end

function Journal:Toggle(step)
	if self:IsShown() and not step then
		self:Hide()
	elseif step then
		self:ShowStep(step)
	else
		self:Show()
	end
end

-- Opens the Route tab on a step's chapter and flashes the row for a few seconds.
function Journal:ShowStep(step)
	self:Show("route")
	if not step then
		return
	end
	self.query = nil
	if self.frame.Search then
		self.frame.Search:SetText("")
	end
	self.chapter = step.chapter or self.chapter
	self.highlightStep, self.highlightUntil = step.id, GetTime() + HIGHLIGHT_SECONDS
	self:Refresh()
	local steps = self:StepsToShow()
	for i, candidate in ipairs(steps) do
		if candidate.id == step.id then
			scrollTo(self.frame.route.steps, i)
		end
	end
	C_Timer.After(HIGHLIGHT_SECONDS + 0.1, function()
		ns.SafeCall(function()
			Journal:Refresh()
		end)
	end)
end

function Journal:ShowCurrent()
	local p = progress()
	local step = p and p.Current and p:Current()
	self:ShowStep(step)
end

-- Refresh while open, coalesced.
local function requestRefresh()
	if not Journal:IsShown() or Journal.refreshScheduled then
		return
	end
	Journal.refreshScheduled = true
	C_Timer.After(0.2, function()
		Journal.refreshScheduled = nil
		ns.SafeCall(Journal.Refresh, Journal)
	end)
end

for _, message in ipairs({
	"GUIDE_LOADED",
	"STEP_CHANGED",
	"CONTRIBUTE_CHANGED",
	"PROFESSION_PLAN_CHANGED",
	"GUIDE_SELECTED",
}) do
	ns.Events:RegisterMessage(message, requestRefresh)
end

-- Escape closes the window like Blizzard's own (UISpecialFrames is set by UI:CreateDialogFrame); /signpost opens it.
ns.Slash:Register("journal", function(args)
	local tab = (args or ""):lower():match("^%s*(%S*)")
	Journal:Show(tab ~= "" and tab or nil)
end, L["open the Journal: journal | route | class | settings"])

-- The minimap button, the AddOn Compartment entry, the quick menu and the key bindings are UI/Launcher.lua.
