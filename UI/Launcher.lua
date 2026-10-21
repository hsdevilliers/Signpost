-- The common add-on interactions (docs/INTERACTIONS.md): what a click on the minimap button, on Signpost's entry in
-- the AddOn Compartment and on the step card does, the quick menu those share, the labels of the key bindings
-- (Bindings.xml) and the minimap button's settings, in one place. The minimap button is a LibDataBroker launcher
-- drawn by LibDBIcon (both bundled in Libs/); the menu is the client's own (MenuUtil.CreateContextMenu). Nothing here
-- is protected: toggling the Journal or the step card and moving to another step work in combat too.
-- VERIFY(beta): the menu's look and behavior, the compartment's right-click and tooltip and the Key Bindings screen
-- in the real client (FOREVER-API-NOTES "Open probes"); the specs run on a mock.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Launcher = {}
ns.Launcher = Launcher

local BUTTON = "Signpost" -- the LibDataBroker object's name and the LibDBIcon button's
local BUTTON_ICON = "Interface\\AddOns\\Signpost\\Media\\icon-round"
local KEY_COLOR = "|cffffff00" -- the key of a hint line in a tooltip, as Bartender4 and other add-ons write them

-- LibDBIcon keeps the button's angle (minimapPos) in this table too; `lock` is its name for "cannot be dragged".
ns.SavedVars:RegisterDefaults("account", "minimapButton", { hide = false, lock = false })

-- Settings ----------------------------------------------------------------------------------------------------------

local function icons()
	local stub = LibStub
	return stub and stub("LibDBIcon-1.0", true) or nil
end

local function stepCardSetting(key)
	local settings = ns.db and ns.db.stepFrame
	return settings ~= nil and settings[key] == true
end

function Launcher:ButtonHidden()
	return ns.db ~= nil and ns.db.minimapButton.hide == true
end

function Launcher:ButtonLocked()
	return ns.db ~= nil and ns.db.minimapButton.lock == true
end

-- LibDBIcon's Hide and Show only act on the button; the saved flag is ours to keep (it reads it at login).
function Launcher:SetButtonHidden(hidden)
	if not ns.db then
		return
	end
	ns.db.minimapButton.hide = hidden and true or false
	local lib = icons()
	if lib then
		if hidden then
			lib:Hide(BUTTON)
		else
			lib:Show(BUTTON)
		end
	end
end

function Launcher:SetButtonLocked(locked)
	if not ns.db then
		return
	end
	local lib = icons()
	if lib then
		if locked then
			lib:Lock(BUTTON)
		else
			lib:Unlock(BUTTON)
		end
	end
	ns.db.minimapButton.lock = locked and true or false -- LibDBIcon's Unlock clears it to nil: keep a plain boolean
end

-- The menu's way of hiding the button: it also says how to get it back, as the button is the way in.
function Launcher:HideButtonWithNotice()
	self:SetButtonHidden(true)
	Util.Print(L["Minimap button hidden. To bring it back, type /signpost minimap or use the Journal's Settings tab."])
end

-- Actions -----------------------------------------------------------------------------------------------------------

function Launcher:ToggleJournal()
	local journal = ns.Journal
	if journal and journal.Toggle then
		journal:Toggle()
	end
end

-- The setting the Journal's "Show the step card" box, /signpost show and /signpost hide keep.
function Launcher:SetStepCardShown(shown)
	local card = ns.StepFrame
	if card and card.SetShown then
		card:SetShown(shown)
	end
end

function Launcher:ToggleStepCard()
	self:SetStepCardShown(not stepCardSetting("shown"))
end

function Launcher:ToggleStepCardLock()
	local card = ns.StepFrame
	if card and card.SetLocked then
		card:SetLocked(not stepCardSetting("locked"))
	end
end

function Launcher:ToggleTracking()
	local tracking = ns.Tracking
	if tracking and tracking.SetEnabled then
		tracking:SetEnabled(not tracking:Enabled())
	end
end

function Launcher:OpenSettings()
	local journal = ns.Journal
	if journal and journal.Show then
		journal:Show("settings")
	end
end

-- "Find my place" exists once the placement layer does (Engine/Placement.lua): never a hard dependency.
function Launcher:CanPlace()
	local progress = ns.Progress
	return progress ~= nil and type(progress.Place) == "function"
end

function Launcher:FindMyPlace()
	if ns.Slash.commands.place then
		ns.Slash:Run("place") -- the player's own command: the same chat line about where it landed
	elseif self:CanPlace() then
		ns.Progress:Place()
	end
end

-- Runs one of /signpost's commands as if it had been typed: the same checks, the same chat lines.
local function runCommand(name)
	return function()
		ns.Slash:Run(name)
	end
end

-- Where the player is, for a tooltip: "<chapter> · step i/N" (counted within the chapter, as the step card's header
-- does) and the step's first line; nothing without a guide.
function Launcher:Where()
	local progress = ns.Progress
	local step = progress and progress.Current and progress:Current()
	local guide = progress and progress.Guide and progress:Guide()
	if type(step) ~= "table" or type(guide) ~= "table" then
		return nil
	end
	local chapter = type(guide.chapters) == "table" and guide.chapters[step.chapter] or nil
	local name = type(chapter) == "table" and chapter.name or guide.name or ADDON_NAME
	local index = step.index
	local total = type(guide.steps) == "table" and #guide.steps or nil
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
	local header = name
	if type(index) == "number" and type(total) == "number" and total >= 1 then
		header = string.format(L["%s · step %d/%d"], name, index, total)
	end
	local card = ns.StepFrame
	local lines = card and card.DescribeLines and card.DescribeLines(step) or {}
	return header, lines[1]
end

-- Clicks ------------------------------------------------------------------------------------------------------------

-- The click map, shared by the minimap button and the compartment entry (docs/INTERACTIONS.md): left-click toggles
-- the Journal, Shift-left-click the step card, right-click opens the quick menu. Ctrl and Alt are not used and the
-- other mouse buttons do nothing.
function Launcher:Click(owner, button)
	if button == "RightButton" then
		self:OpenMenuOrSettings(owner)
	elseif button == "LeftButton" then
		if Util.Call(IsShiftKeyDown) then
			self:ToggleStepCard()
		else
			self:ToggleJournal()
		end
	end
end

-- Without the client's Menu system a right-click opens the Journal's Settings tab, what it did before the menu.
function Launcher:OpenMenuOrSettings(owner)
	if not self:OpenMenu(owner) then
		self:OpenSettings()
	end
end

-- The Compartment hands over the button's name only (left or right: it registers its entries for any click).
function Launcher:OnCompartmentClick(buttonName)
	local button = type(buttonName) == "string" and buttonName or "LeftButton"
	local owner = AddonCompartmentFrame or UIParent
	if button == "RightButton" then
		-- The compartment closes its own menu once this function has returned, which would take a menu opened now
		-- with it: open ours on the next frame. VERIFY(beta): needed, and enough.
		C_Timer.After(0, function()
			ns.SafeCall(Launcher.OpenMenuOrSettings, Launcher, owner)
		end)
	else
		self:Click(owner, button)
	end
end

-- Tooltips ----------------------------------------------------------------------------------------------------------

-- One line per click that does something: the key in yellow, what it does in white.
local function hints()
	return {
		{ L["Left-click"], L["to open or close the Journal"] },
		{ L["Shift-click"], L["to show or hide the step card"] },
		{ L["Right-click"], L["to open the quick menu"] },
	}
end

-- Fills a tooltip: the name, where the player is in the guide, what each click does. LibDBIcon (the button) and the
-- compartment's hover function both use it.
function Launcher:FillTooltip(tooltip)
	tooltip:AddLine(L["Signpost"], 1, 0.82, 0)
	local header, line = self:Where()
	if header then
		tooltip:AddLine(header, 1, 1, 1)
		if line then
			tooltip:AddLine(line, 0.8, 0.8, 0.8, true)
		end
	else
		tooltip:AddLine(L["No guide is loaded for this character."], 0.6, 0.6, 0.6, true)
	end
	tooltip:AddLine(" ")
	for _, hint in ipairs(hints()) do
		tooltip:AddLine(string.format("%s%s|r %s", KEY_COLOR, hint[1], hint[2]), 1, 1, 1)
	end
end

-- The compartment's hover functions. There is no MenuUtil.ShowTooltip (Blizzard's source has ShowTooltipEx and
-- HideTooltipEx), so the tooltip is set up as the compartment's own icon does it. VERIFY(beta): the anchor.
function Launcher:OnCompartmentEnter(buttonFrame)
	local tooltip = GameTooltip
	if not (tooltip and tooltip.SetOwner and buttonFrame) then
		return
	end
	tooltip:SetOwner(buttonFrame, "ANCHOR_LEFT")
	self:FillTooltip(tooltip)
	tooltip:Show()
end

function Launcher:OnCompartmentLeave(buttonFrame)
	local tooltip = GameTooltip
	if tooltip and tooltip.IsOwned and tooltip:IsOwned(buttonFrame) then
		tooltip:Hide()
	end
end

-- The quick menu ----------------------------------------------------------------------------------------------------

-- A menu callback that cannot take the engine down with it.
local function safely(fn)
	return function()
		ns.SafeCall(fn)
	end
end

-- A check box's state callback: the setting's value, false when reading it fails.
local function reading(fn)
	return function()
		local ok, value = ns.SafeCall(fn)
		return ok and value == true
	end
end

-- The menu's entries, in order, on `root` (a Blizzard menu description: CreateTitle, CreateButton, CreateCheckbox,
-- CreateDivider). A couple of quick options for the middle of play, not a settings panel.
function Launcher:BuildMenu(_, root)
	root:CreateTitle(L["Signpost"])
	root:CreateButton(
		L["Open the Journal"],
		safely(function()
			local journal = ns.Journal
			if journal and journal.Show then
				journal:Show()
			end
		end)
	)
	root:CreateDivider()
	root:CreateCheckbox(
		L["Show the step card"],
		reading(function()
			return stepCardSetting("shown")
		end),
		safely(function()
			Launcher:ToggleStepCard()
		end)
	)
	root:CreateCheckbox(
		L["Lock the step card"],
		reading(function()
			return stepCardSetting("locked")
		end),
		safely(function()
			Launcher:ToggleStepCardLock()
		end)
	)
	root:CreateCheckbox(
		L["Track only the current step's quests"],
		reading(function()
			return ns.Tracking ~= nil and ns.Tracking:Enabled() == true
		end),
		safely(function()
			Launcher:ToggleTracking()
		end)
	)
	root:CreateDivider()
	if self:CanPlace() then
		root:CreateButton(
			L["Find my place"],
			safely(function()
				Launcher:FindMyPlace()
			end)
		)
	end
	root:CreateButton(L["Previous step"], safely(runCommand("back")))
	root:CreateButton(L["Skip this step"], safely(runCommand("skip")))
	root:CreateDivider()
	root:CreateButton(
		L["Settings..."],
		safely(function()
			Launcher:OpenSettings()
		end)
	)
	-- With the button hidden the menu (reached from the compartment or the step card) offers the way back.
	if self:ButtonHidden() then
		root:CreateButton(
			L["Show the minimap button"],
			safely(function()
				Launcher:SetButtonHidden(false)
			end)
		)
	else
		root:CreateButton(
			L["Hide the minimap button"],
			safely(function()
				Launcher:HideButtonWithNotice()
			end)
		)
	end
end

-- Opens the quick menu at the cursor. False when this client has no Menu system: the caller then has its own fallback.
function Launcher:OpenMenu(owner)
	local menus = MenuUtil
	if type(menus) ~= "table" or type(menus.CreateContextMenu) ~= "function" then
		return false
	end
	local ok = ns.SafeCall(menus.CreateContextMenu, owner or UIParent, function(menuOwner, root)
		ns.SafeCall(Launcher.BuildMenu, Launcher, menuOwner, root)
	end)
	return ok and true or false
end

-- The minimap button ------------------------------------------------------------------------------------------------

-- Registered once the saved variables are there (DB_READY). Without the two libraries nothing is created.
function Launcher:Register()
	local stub = LibStub
	local broker = stub and stub("LibDataBroker-1.1", true)
	local lib = icons()
	if not (broker and lib and ns.db) then
		return false
	end
	local object = broker:NewDataObject(BUTTON, {
		type = "launcher",
		text = BUTTON,
		icon = BUTTON_ICON,
		OnClick = function(frame, button)
			ns.SafeCall(Launcher.Click, Launcher, frame, button)
		end,
		OnTooltipShow = function(tooltip)
			ns.SafeCall(Launcher.FillTooltip, Launcher, tooltip)
		end,
	})
	if object and not lib:IsRegistered(BUTTON) then
		lib:Register(BUTTON, object, ns.db.minimapButton)
	end
	return true
end

ns.Events:RegisterMessage("DB_READY", function()
	Launcher:Register()
end)

-- Key bindings -------------------------------------------------------------------------------------------------------

-- Bindings.xml (loaded by the client by its name) declares the actions; each runs one /signpost command, so the
-- bindings add no function of their own. The Key Bindings screen reads these labels.
-- VERIFY(beta): the screen on Forever.
BINDING_HEADER_SIGNPOST = L["Signpost"]
BINDING_NAME_SIGNPOST_JOURNAL = L["Show or hide the Journal"]
BINDING_NAME_SIGNPOST_CARD = L["Show or hide the step card"]
BINDING_NAME_SIGNPOST_BACK = L["Previous step"]
BINDING_NAME_SIGNPOST_NEXT = L["Next step"]
BINDING_NAME_SIGNPOST_SKIP = L["Skip this step"]
BINDING_NAME_SIGNPOST_PLACE = L["Find my place"]

-- Slash commands ----------------------------------------------------------------------------------------------------

ns.Slash:Register("card", function(args)
	local word = (args or ""):lower()
	if word == "on" or word == "off" then
		Launcher:SetStepCardShown(word == "on")
	elseif word == "" then
		Launcher:ToggleStepCard()
	else
		Util.Print(L["Use 'card', 'card on' or 'card off'."])
	end
end, L["show or hide the step card (card | card on | card off)"])

ns.Slash:Register("minimap", function(args)
	local word = (args or ""):lower()
	if word == "show" then
		Launcher:SetButtonHidden(false)
	elseif word == "hide" then
		Launcher:SetButtonHidden(true)
	elseif word == "lock" then
		Launcher:SetButtonLocked(true)
	elseif word == "unlock" then
		Launcher:SetButtonLocked(false)
	elseif word == "" then
		Launcher:SetButtonHidden(not Launcher:ButtonHidden())
	else
		Util.Print(L["Use 'minimap show', 'minimap hide', 'minimap lock' or 'minimap unlock'."])
		return
	end
	Util.Print(
		L["Minimap button: %s, %s."],
		Launcher:ButtonHidden() and L["hidden"] or L["shown"],
		Launcher:ButtonLocked() and L["locked"] or L["unlocked"]
	)
end, L["the minimap button: show | hide | lock | unlock (no word: show or hide it)"])
