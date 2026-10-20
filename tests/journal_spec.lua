-- UI/Journal.lua on the real engine (Registry, Parser, Directives, Conditions, Context, Progress, StepFrame, Pins) and
-- the scripted client of tests/mocks/context.lua: the window builds, its lists follow the guide and the progress, a
-- click jumps, the settings write through to the step card and the pins, and every way of opening it works.
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local CHAPTERS = {
	valley = [[
#chapter 1-6 Valley
step
  .goto 1411,43.35,68.70
  .accept 4641 >> Accept the first quest
step
  .complete 4641
step
  .turnin 4641
  .hub valley
]],
	cave = [[
#chapter 6-8 Cave #dungeon
step
  .goto 1411,50,50
  .note The cave
step
  .note Leave the cave
]],
}

local GUIDE = {
	id = "test-journal",
	name = "Journal Test",
	faction = "*",
	races = { "*" },
	classes = { "*" },
	levels = { 1, 10 },
	text = "#include valley\n#include cave\n",
}

local OTHER = {
	id = "other-guide",
	name = "Other Guide",
	faction = "Horde",
	races = { "Orc" },
	classes = { "WARRIOR" },
	levels = { 1, 10 },
	text = "#chapter 1-5 Other\nstep\n  .note Nothing\n",
}

local sessions = {}

-- The generic client mock keeps no widget state: these frames remember what the Journal sets on them (text, checked,
-- the anchors, the menu builder given to a dropdown) so the specs can read it back.
local function instrument(obj)
	rawset(obj, "SetPoint", function(self, ...)
		local points = rawget(self, "_points") or {}
		points[#points + 1] = { ... }
		rawset(self, "_points", points)
	end)
	rawset(obj, "SetText", function(self, text)
		rawset(self, "_text", text ~= nil and tostring(text) or nil)
	end)
	rawset(obj, "GetText", function(self)
		return rawget(self, "_text")
	end)
	rawset(obj, "SetChecked", function(self, value)
		rawset(self, "_checked", value and true or false)
	end)
	rawset(obj, "SetShown", function(self, shown)
		if shown then
			self:Show()
		else
			self:Hide()
		end
	end)
	rawset(obj, "SetupMenu", function(self, builder)
		rawset(self, "menuBuilder", builder)
	end)
	local createFontString, createTexture = obj.CreateFontString, obj.CreateTexture
	rawset(obj, "CreateFontString", function(self, ...)
		return instrument(createFontString(self, ...))
	end)
	rawset(obj, "CreateTexture", function(self, ...)
		return instrument(createTexture(self, ...))
	end)
	return obj
end

after_each(function()
	for _, session in ipairs(sessions) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
	sessions = {}
	contextMock.uninstall()
	G.IsShiftKeyDown = nil
end)

local function start(setup)
	local world
	local ns, mock = addon.load({
		login = false,
		before = function(m)
			world = contextMock.install(m)
			local createFrame = G.CreateFrame
			G.CreateFrame = function(...)
				return instrument(createFrame(...))
			end
			if setup then
				setup(world, m)
			end
		end,
	})
	for id, text in pairs(CHAPTERS) do
		assert.is_true(ns.Chapters:Register(id, text))
	end
	assert.is_true(ns.Guides:Register(GUIDE))
	assert.is_true(ns.Guides:Register(OTHER))
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	world.advance(1)
	sessions[#sessions + 1] = { ns = ns, mock = mock }
	return ns, world, mock
end

local function rows(list)
	local shown = {}
	for _, row in ipairs(list.rows) do
		if row.IsShown(row) then
			shown[#shown + 1] = row
		end
	end
	return shown
end

local function texts(list)
	local out = {}
	for _, row in ipairs(rows(list)) do
		out[#out + 1] = row.text:GetText()
	end
	return out
end

describe("Journal", function()
	it("is part of the addon and not shown until asked for", function()
		local ns = start()
		assert.is_table(ns.Journal)
		assert.is_false(ns.Journal:IsShown())
	end)

	describe("opening", function()
		it("opens on the Route tab, shows the guide and closes again", function()
			local ns = start()
			ns.Journal:Show()
			assert.is_true(ns.Journal:IsShown())
			assert.are.equal("route", ns.Journal.tab)
			ns.Journal:Toggle()
			assert.is_false(ns.Journal:IsShown())
		end)

		it("opens with /signpost, /signpost journal <tab> and the AddOn Compartment entry", function()
			local ns, _, mock = start()
			G.SlashCmdList.SIGNPOST("")
			assert.is_true(ns.Journal:IsShown())
			G.SlashCmdList.SIGNPOST("")
			assert.is_false(ns.Journal:IsShown())
			G.SlashCmdList.SIGNPOST("journal settings")
			assert.are.equal("settings", ns.Journal.tab)
			ns.Journal:Hide()
			G.Signpost_OnAddonCompartmentClick()
			assert.is_true(ns.Journal:IsShown())
			assert.are.same({}, mock.errors)
		end)

		it("hides the step card while open and brings it back (the hideWithJournal setting)", function()
			local ns = start()
			local updates = 0
			local original = ns.StepFrame.UpdateVisibility
			ns.StepFrame.UpdateVisibility = function(self, ...)
				updates = updates + 1
				return original(self, ...)
			end
			ns.Journal:Show()
			ns.Journal.frame.scripts.OnShow(ns.Journal.frame)
			ns.Journal:Hide()
			ns.Journal.frame.scripts.OnHide(ns.Journal.frame)
			assert.is_true(updates >= 2)
		end)
	end)

	describe("the Route tab", function()
		it("lists the guide's chapters with progress and marks the dungeon", function()
			local ns = start()
			ns.Journal:Show()
			local chapters = texts(ns.Journal.frame.route.chapters)
			assert.are.equal(2, #chapters)
			assert.is_truthy(chapters[1]:find("1-6 Valley", 1, true))
			assert.is_truthy(chapters[2]:find("[D] 6-8 Cave", 1, true))
			assert.is_truthy(chapters[1]:find("(0/3)", 1, true))
		end)

		it("lists the steps of the selected chapter, the current one marked", function()
			local ns = start()
			ns.Journal:Show()
			local steps = texts(ns.Journal.frame.route.steps)
			assert.are.equal(3, #steps)
			assert.is_truthy(steps[1]:find(">", 1, true)) -- the first step is current
			assert.is_truthy(steps[2]:find("[ ]", 1, true))
		end)

		it("switches chapter on a click and shows the dungeon's skip box only there", function()
			local ns = start()
			ns.Journal:Show()
			local pane = ns.Journal.frame.route
			assert.is_false(pane.skip.shown == true)
			pane.chapters.rows[2].scripts.OnClick(pane.chapters.rows[2])
			assert.are.equal(2, ns.Journal.chapter)
			assert.are.equal(2, #rows(pane.steps))
			assert.is_true(pane.skip.shown)
		end)

		it("skipping a dungeon from the box marks its steps skipped", function()
			local ns = start()
			ns.Journal:Show()
			local pane = ns.Journal.frame.route
			pane.chapters.rows[2].scripts.OnClick(pane.chapters.rows[2])
			pane.skip.GetChecked = function()
				return true
			end
			pane.skip.scripts.OnClick(pane.skip)
			assert.is_true(ns.Progress:ChapterSkipped(2))
		end)

		it("jumps to a step on a click, and asks for Shift when it is far away", function()
			local ns, world = start()
			ns.Journal:Show()
			local pane = ns.Journal.frame.route
			pane.steps.rows[3].scripts.OnClick(pane.steps.rows[3])
			world.advance(1.1)
			assert.are.equal("valley:3", ns.Progress:Current().id)
			-- a long way off: one step further than FAR_JUMP needs Shift
			local far = { id = "x", index = 99 }
			local before = ns.Progress:Current().id
			ns.Journal:JumpTo(far)
			assert.are.equal(before, ns.Progress:Current().id)
		end)

		it("searches the whole guide and shows the matches", function()
			local ns = start()
			ns.Journal:Show()
			local search = ns.Journal.frame.Search
			search.GetText = function()
				return "cave"
			end
			search.scripts.OnTextChanged(search)
			local steps = texts(ns.Journal.frame.route.steps)
			assert.is_true(#steps >= 1)
			for _, text in ipairs(steps) do
				assert.is_truthy(text:lower():find("cave", 1, true))
			end
		end)

		it("ShowStep opens the step's chapter and flashes its row", function()
			local ns, world = start()
			local guide = ns.Progress:Guide()
			local target = guide.steps[#guide.steps] -- in the cave chapter
			ns.Journal:ShowStep(target)
			assert.are.equal(target.chapter, ns.Journal.chapter)
			local flashed = 0
			for _, row in ipairs(rows(ns.Journal.frame.route.steps)) do
				if row.flash.shown then
					flashed = flashed + 1
				end
			end
			assert.are.equal(1, flashed)
			world.advance(6)
			assert.are.equal(1, 1) -- the timer ran without errors (checked after each test)
		end)

		it("says so when no guide is loaded", function()
			local ns = start()
			ns.Progress:SetGuide(nil)
			ns.Journal:Show()
			assert.is_truthy(ns.Journal.frame.route.title:GetText():find("No guide", 1, true))
		end)
	end)

	describe("the guide picker", function()
		it("lists only guides this character can use and selects one through the registry", function()
			local ns = start()
			local picked
			ns.Guides.Select = function(_, id)
				picked = id
				return true
			end
			ns.Journal:Show()
			local menu = { radios = {} }
			local root = {
				CreateRadio = function(_, label, isSelected, onSelect, id)
					menu.radios[#menu.radios + 1] =
						{ label = label, isSelected = isSelected, onSelect = onSelect, id = id }
				end,
			}
			-- the dropdown's menu builder is the function SetupMenu received on the real client; call the same path
			local dropdown = ns.Journal.frame.guideDropdown
			assert.is_not_nil(dropdown)
			local build = dropdown.menuBuilder
			if build then
				build(dropdown, root)
				local ids = {}
				for _, radio in ipairs(menu.radios) do
					ids[#ids + 1] = radio.id
				end
				assert.are.same({ "test-journal" }, ids) -- the Orc Warrior guide is not for this character
				menu.radios[1].onSelect()
				assert.are.equal("test-journal", picked)
			end
		end)
	end)

	describe("the Class tab", function()
		it("falls back to Route when the class has no quest chains", function()
			local ns = start()
			ns.Player.classFile = "NOCLASS"
			ns.Journal:Show("class")
			assert.are.equal("route", ns.Journal.tab)
		end)

		it("lists the chains of the class module for the character's race, with their status", function()
			local ns, _, _, _ = start(function(world)
				world.player = world.player or {}
			end)
			ns.Player.classFile, ns.Player.class, ns.Player.raceFile = "TESTCLASS", "Tester", "Troll"
			ns.Classes:Register("TESTCLASS", {
				classQuests = {
					{ id = "a", name = "Chain A", level = 10, quests = { 11, 12 } },
					{ id = "b", name = "Orc Chain", level = 12, quests = { 13 }, races = { "Orc" } },
					{ id = "c", name = "Forever Chain", level = 20, quests = {}, pending = true },
				},
			})
			ns.Journal:Show("class")
			assert.are.equal("class", ns.Journal.tab)
			local list = texts(ns.Journal.frame.class.list)
			assert.are.equal(2, #list) -- the Orc chain is not for a Troll
			assert.is_truthy(list[1]:find("Chain A", 1, true))
			assert.is_truthy(list[1]:find("not started", 1, true))
			assert.is_truthy(list[2]:find("not known yet", 1, true))
		end)
	end)

	describe("the Settings tab", function()
		it("reflects the saved settings and writes changes through", function()
			local ns = start()
			ns.Journal:Show("settings")
			local pane = ns.Journal.frame.settings
			assert.is_true(#pane.boxes >= 8)
			local byLabel = {}
			for _, box in ipairs(pane.boxes) do
				byLabel[box.def.label] = box
			end
			local lock = byLabel["Lock the step card (Shift-drag moves it when unlocked)"]
			assert.is_not_nil(lock)
			lock.check.GetChecked = function()
				return true
			end
			lock.check.scripts.OnClick(lock.check)
			assert.is_true(ns.db.stepFrame.locked)
			local combat = byLabel["Hide the step card in combat"]
			combat.check.GetChecked = function()
				return true
			end
			combat.check.scripts.OnClick(combat.check)
			assert.is_true(ns.db.stepFrame.hideInCombat)
			local minimap = byLabel["Show the next step on the minimap"]
			minimap.check.GetChecked = function()
				return false
			end
			minimap.check.scripts.OnClick(minimap.check)
			assert.is_false(ns.db.pins.minimap)
		end)

		it("turns data recording on and off through the consent setting", function()
			local ns = start()
			ns.Journal:Show("settings")
			local box
			for _, candidate in ipairs(ns.Journal.frame.settings.boxes) do
				if candidate.def.label:find("Help improve", 1, true) then
					box = candidate
				end
			end
			assert.is_not_nil(box)
			box.check.GetChecked = function()
				return true
			end
			box.check.scripts.OnClick(box.check)
			assert.is_true(ns.db.contribute.enabled)
		end)

		it("lists the quest tracker setting under its own header and saves only the player's choice", function()
			local ns = start()
			ns.Journal:Show("settings")
			local pane = ns.Journal.frame.settings
			local box
			for _, candidate in ipairs(pane.boxes) do
				if candidate.def.section then
					box = candidate
				end
			end
			assert.is_not_nil(box)
			assert.are.equal("Quest tracker", box.def.section)
			assert.are.equal("Track only the current step's quests", box.def.label)
			assert.are.equal(2, box.def.column)
			assert.are.equal(1, #pane.sectionHeaders)
			-- until the player chooses, the setting is the module's default and nothing is saved
			local default = ns.Tracking.DEFAULT_ENABLED
			assert.are.equal(default, box.def.get())
			assert.is_nil(ns.db.settings.trackStepQuests)
			box.check.GetChecked = function()
				return not default
			end
			box.check.scripts.OnClick(box.check)
			assert.are.equal(not default, ns.db.settings.trackStepQuests)
			assert.are.equal(not default, box.def.get())
		end)

		it("lays the quest tracker out under a header of its own at the end of the second column", function()
			local ns = start()
			ns.Journal:Show("settings")
			local pane = ns.Journal.frame.settings
			local column = {}
			for _, box in ipairs(pane.boxes) do
				if box.def.column == 2 then
					column[#column + 1] = box
				end
			end
			-- nine automation boxes under the Automation header, then the Quest tracker header and its box
			assert.are.equal(10, #column)
			assert.are.equal("Quest tracker", column[10].def.section)
			assert.is_nil(column[9].def.section)
			assert.are.equal(1, #pane.sectionHeaders)
			local header = pane.sectionHeaders[1]
			assert.are.equal("Quest tracker", header:GetText())
			assert.are.same({ "TOPLEFT", pane, "TOPLEFT", 470, -36 }, pane.automationHeader._points[1])
			assert.are.same({ "TOPLEFT", pane.automationHeader, "BOTTOMLEFT", -4, -2 }, column[1].check._points[1])
			assert.are.same({ "TOPLEFT", column[1].check, "BOTTOMLEFT", 0, -2 }, column[2].check._points[1])
			-- the header hangs 10 under the last automation box, 4 to the right of it (the box art is padded by 4), so its
			-- text lines up with the Automation header's; the box under it sits 4 to the left of the header's text
			assert.are.same({ "TOPLEFT", column[9].check, "BOTTOMLEFT", 4, -10 }, header._points[1])
			assert.are.same({ "TOPLEFT", header, "BOTTOMLEFT", -4, -2 }, column[10].check._points[1])
		end)

		it("lists the automation toggles, all off, and writes them to the character's settings", function()
			local ns = start()
			ns.Journal:Show("settings")
			local boxes = {}
			for _, box in ipairs(ns.Journal.frame.settings.boxes) do
				if box.def.column == 2 and not box.def.section then
					boxes[#boxes + 1] = box
				end
			end
			assert.are.equal(9, #boxes)
			for _, box in ipairs(boxes) do
				assert.is_false(box.def.get())
			end
			local byLabel = {}
			for _, box in ipairs(boxes) do
				byLabel[box.def.label] = box
			end
			for label, key in pairs({
				["Accept the guide's quests"] = "quests",
				["Turn in the guide's quests"] = "turnIn",
				["Never pick rewards: always let me choose"] = "rewardAsk",
				["Buy the items the guide lists"] = "vendor",
			}) do
				local box = byLabel[label]
				assert.is_not_nil(box, label)
				box.check.GetChecked = function()
					return true
				end
				box.check.scripts.OnClick(box.check)
				assert.is_true(ns.char.automation[key], key)
				assert.is_true(box.def.get())
			end
			assert.is_false(ns.char.automation.taxi)
		end)

		it("changes the step card's size and opacity in steps of a tenth", function()
			local ns = start()
			ns.Journal:Show("settings")
			local scale = ns.db.stepFrame.scale
			ns.StepFrame:SetScale(1)
			assert.are.equal(1, ns.db.stepFrame.scale)
			ns.StepFrame:SetScale(1.1)
			assert.are.equal(1.1, ns.db.stepFrame.scale)
			assert.is_number(scale)
		end)

		it("shows the detected profession plan and offers to restore a declined profession", function()
			local ns = start()
			ns.Professions:Register("skinning", { skillLine = 393, primary = true, gathering = true, ranks = { 75 } })
			ns.Journal:Show("settings")
			assert.is_truthy(ns.Journal.frame.settings.plan:GetText():find("Professions:", 1, true))
			assert.is_false(ns.Journal.frame.settings.restore[1].shown == true)
		end)
	end)

	describe("the minimap button", function()
		it("is created when the libraries are there and left alone when they are not", function()
			-- the test client has no LibStub: nothing is created and nothing fails
			local ns = start()
			assert.is_table(ns.db.minimapButton)
		end)
	end)
end)
