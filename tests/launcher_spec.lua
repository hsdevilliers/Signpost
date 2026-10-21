-- UI/Launcher.lua and what hangs on it (docs/INTERACTIONS.md) on the real engine, Journal and step card and the
-- scripted client of tests/mocks/context.lua, with the fakes of tests/mocks/launcher.lua for LibDataBroker, LibDBIcon,
-- the Menu system, the tooltip and the AddOn Compartment: the click map of the minimap button and of the compartment,
-- the quick menu, the tooltip, hiding and locking the button, the slash commands, and the key bindings (Bindings.xml
-- is parsed and every binding's Lua body is run).
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
local launcherMock = dofile("tests/mocks/launcher.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local CHAPTERS = {
	valley = [[
#chapter 1-6 Valley
step
  .goto 1411,43.35,68.70
  .accept 4641 >> Accept the first quest
step
  .goto 1411,43.35,68.70
  .accept 787 >> Accept the second quest
step
  .turnin 4641 >> Hand in the first quest
]],
	cave = [[
#chapter 6-8 Cave
step
  .accept 800 >> Enter the cave
step
  .turnin 800 >> Leave the cave
]],
}

local GUIDE = {
	id = "test-launcher",
	name = "Launcher Test",
	faction = "*",
	races = { "*" },
	classes = { "*" },
	levels = { 1, 10 },
	text = "#include valley\n#include cave\n",
}

local DOT = " \194\183 " -- the step card's "<chapter> · step i/N" separator

local MENU = {
	"Signpost",
	"Open the Journal",
	"-",
	"Show the step card",
	"Lock the step card",
	"Track only the current step's quests",
	"-",
	"Previous step",
	"Skip this step",
	"-",
	"Settings...",
	"Hide the minimap button",
}

local sessions = {}

after_each(function()
	for _, session in ipairs(sessions) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
	sessions = {}
	contextMock.uninstall()
	launcherMock.uninstall()
end)

-- opts.guide = false: no guide for the character; opts.saved: SignpostDB from an earlier session; opts.noMenu,
-- opts.noLibs, opts.noCompartment: see the mock.
local function start(opts)
	opts = opts or {}
	local world, client
	local ns, mock = addon.load({
		login = false,
		before = function(m)
			world = contextMock.install(m)
			client = launcherMock.install(G.LibStub, opts)
			if opts.saved then
				G.SignpostDB = opts.saved
			end
		end,
	})
	if opts.guide ~= false then
		for id, text in pairs(CHAPTERS) do
			assert.is_true(ns.Chapters:Register(id, text))
		end
		assert.is_true(ns.Guides:Register(GUIDE))
	end
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	world.advance(1)
	sessions[#sessions + 1] = { ns = ns, mock = mock }
	return ns, client, world, mock
end

local function menuOf(client)
	return assert(client.lastMenu(), "no menu was opened").root
end

local function printedLine(mock, text)
	for _, line in ipairs(mock.printed) do
		if line:find(text, 1, true) then
			return line
		end
	end
end

describe("the minimap button", function()
	it("is a launcher on the saved table, registered once", function()
		local ns, client = start()
		local button = client.buttons.Signpost
		assert.is_not_nil(button)
		assert.are.equal("launcher", button.object.type)
		assert.is_string(button.object.icon)
		assert.are.equal(ns.db.minimapButton, button.db)
		assert.are.same({ hide = false, lock = false }, ns.db.minimapButton)
		-- a second registration (LibDBIcon refuses it) is skipped without an error and leaves the button as it was
		assert.is_true(ns.Launcher:Register())
		assert.are.equal(button, client.buttons.Signpost)
	end)

	it("is left alone, without a word, when the libraries are not there", function()
		local ns, client = start({ noLibs = true })
		assert.is_nil(client.buttons.Signpost)
		assert.is_false(ns.Launcher:Register())
		-- the settings still hold what the player chose, and changing them does not fail
		ns.Launcher:SetButtonHidden(true)
		ns.Launcher:SetButtonLocked(true)
		assert.is_true(ns.db.minimapButton.hide)
		assert.is_true(ns.db.minimapButton.lock)
	end)

	describe("clicks", function()
		-- button, the modifier keys held, what the click does
		local MAP = {
			{ "LeftButton", {}, "journal" },
			{ "LeftButton", { shift = true }, "card" },
			{ "LeftButton", { ctrl = true }, "journal" },
			{ "LeftButton", { alt = true }, "journal" },
			{ "LeftButton", { ctrl = true, alt = true }, "journal" },
			{ "LeftButton", { shift = true, ctrl = true }, "card" },
			{ "LeftButton", { shift = true, alt = true }, "card" },
			{ "RightButton", {}, "menu" },
			{ "RightButton", { shift = true }, "menu" },
			{ "RightButton", { ctrl = true }, "menu" },
			{ "RightButton", { alt = true }, "menu" },
			{ "MiddleButton", {}, "nothing" },
			{ "MiddleButton", { shift = true }, "nothing" },
			{ "Button4", {}, "nothing" },
			{ "Button5", { ctrl = true }, "nothing" },
		}

		for _, case in ipairs(MAP) do
			local button, modifiers, expected = case[1], case[2], case[3]
			local held = {}
			for key in pairs(modifiers) do
				held[#held + 1] = key
			end
			table.sort(held)
			it(
				string.format(
					"%s with %s does: %s",
					button,
					#held > 0 and table.concat(held, "+") or "no key",
					expected
				),
				function()
					local ns, client = start()
					client.shift, client.ctrl, client.alt = modifiers.shift, modifiers.ctrl, modifiers.alt
					client.click("Signpost", button)
					assert.are.equal(expected == "journal", ns.Journal:IsShown())
					assert.are.equal(expected ~= "card", ns.db.stepFrame.shown) -- the card is shown until a click hides it
					assert.are.equal(expected == "menu" and 1 or 0, #client.menus)
					-- nothing else happened: no other tab, the card's lock and the button stay as they were
					assert.is_false(ns.db.stepFrame.locked)
					assert.is_false(ns.db.minimapButton.hide)
				end
			)
		end

		it("toggles: a second left-click closes the Journal, a second Shift-click brings the card back", function()
			local ns, client = start()
			client.click("Signpost", "LeftButton")
			assert.is_true(ns.Journal:IsShown())
			client.click("Signpost", "LeftButton")
			assert.is_false(ns.Journal:IsShown())
			client.shift = true
			client.click("Signpost", "LeftButton")
			assert.is_false(ns.db.stepFrame.shown)
			client.click("Signpost", "LeftButton")
			assert.is_true(ns.db.stepFrame.shown)
		end)

		it("opens the menu on the button's frame", function()
			local _, client = start()
			client.click("Signpost", "RightButton")
			assert.are.equal(client.buttons.Signpost.frame, client.lastMenu().owner)
		end)

		it("falls back to the Journal's Settings tab when the client has no Menu system", function()
			local ns, client = start({ noMenu = true })
			client.click("Signpost", "RightButton")
			assert.is_true(ns.Journal:IsShown())
			assert.are.equal("settings", ns.Journal.tab)
			assert.are.equal(0, #client.menus)
		end)

		it("falls back too when the menu system fails", function()
			local ns, client, _, mock = start()
			G.MenuUtil.CreateContextMenu = function()
				error("the menu system is broken")
			end
			client.click("Signpost", "RightButton")
			assert.are.equal("settings", ns.Journal.tab)
			assert.is_true(ns.Journal:IsShown())
			assert.are.equal(1, #mock.errors) -- reported through the error handler, not thrown at the click
			wipe(mock.errors)
			wipe(ns.db.errors)
		end)

		it("keeps an error in an action from reaching the button", function()
			local ns, client, _, mock = start()
			ns.Journal.Toggle = function()
				error("the Journal is broken")
			end
			client.click("Signpost", "LeftButton")
			assert.are.equal(1, #mock.errors)
			assert.truthy(mock.errors[1]:find("the Journal is broken", 1, true))
			wipe(mock.errors)
			wipe(ns.db.errors)
		end)
	end)

	describe("the tooltip", function()
		it("names Signpost, says where the player is and what each click does", function()
			local _, client = start()
			client.hover("Signpost")
			local tip = client.tooltip
			assert.is_true(tip.shown)
			assert.are.equal(client.buttons.Signpost.frame, tip.owner)
			local texts = tip:texts()
			assert.are.equal("Signpost", texts[1])
			assert.are.equal("Valley" .. DOT .. "step 1/3", texts[2])
			assert.truthy(texts[3]:find("Accept the first quest", 1, true))
			assert.are.equal(" ", texts[4])
			assert.are.same({
				"|cffffff00Left-click|r to open or close the Journal",
				"|cffffff00Shift-click|r to show or hide the step card",
				"|cffffff00Right-click|r to open the quick menu",
			}, { texts[5], texts[6], texts[7] })
			assert.are.equal(7, #texts)
			-- the name in Blizzard's gold, the hints in white
			assert.are.same({ 1, 0.82, 0 }, { tip.lines[1].r, tip.lines[1].g, tip.lines[1].b })
			assert.are.same({ 1, 1, 1 }, { tip.lines[5].r, tip.lines[5].g, tip.lines[5].b })
		end)

		it("follows the player: the step's place counts within its chapter", function()
			local ns, client, world = start()
			ns.Progress:JumpTo(4) -- the first step of the cave, the fourth of the route
			world.advance(1.1)
			client.hover("Signpost")
			local texts = client.tooltip:texts()
			assert.are.equal("Cave" .. DOT .. "step 1/2", texts[2])
			assert.truthy(texts[3]:find("Enter the cave", 1, true))
			ns.Progress:JumpTo(2)
			world.advance(1.1)
			client.hover("Signpost")
			assert.are.equal("Valley" .. DOT .. "step 2/3", client.tooltip:texts()[2])
		end)

		it("says so when no guide is loaded, and still lists the clicks", function()
			local _, client = start({ guide = false })
			client.hover("Signpost")
			local texts = client.tooltip:texts()
			assert.are.equal("Signpost", texts[1])
			assert.are.equal("No guide is loaded for this character.", texts[2])
			assert.are.equal(6, #texts)
			assert.truthy(texts[3] == " " and texts[4]:find("Left-click", 1, true))
		end)

		-- Launcher:Where() on guides and steps of the spec's own making: the shapes the header has to cope with
		describe("where the player is", function()
			local function where(ns, guide, step)
				ns.Progress.Guide = function()
					return guide
				end
				ns.Progress.Current = function()
					return step, step.index
				end
				return ns.Launcher:Where()
			end

			it("counts in the whole guide when the chapter has no bounds", function()
				local ns = start()
				local guide = { name = "Guide", chapters = { { name = "Chapter" } }, steps = { {}, {}, {}, {}, {} } }
				assert.are.equal(
					"Chapter" .. DOT .. "step 2/5",
					(where(ns, guide, { id = "x", chapter = 1, index = 2 }))
				)
			end)

			it("counts in the whole guide when the step lies outside its chapter's bounds", function()
				local ns = start()
				local guide = {
					name = "Guide",
					chapters = { { name = "Chapter", first = 1, last = 3 } },
					steps = { {}, {}, {}, {}, {} },
				}
				assert.are.equal(
					"Chapter" .. DOT .. "step 4/5",
					(where(ns, guide, { id = "x", chapter = 1, index = 4 }))
				)
			end)

			it("counts in the whole guide when the step lies before its chapter's first step", function()
				local ns = start()
				local guide = {
					name = "Guide",
					chapters = { { name = "Chapter", first = 3, last = 5 } },
					steps = { {}, {}, {}, {}, {} },
				}
				assert.are.equal(
					"Chapter" .. DOT .. "step 2/5",
					(where(ns, guide, { id = "x", chapter = 1, index = 2 }))
				)
			end)

			it("counts the first and the last step of a chapter inside it", function()
				local ns = start()
				local guide = {
					name = "Guide",
					chapters = { { name = "Chapter", first = 3, last = 5 } },
					steps = { {}, {}, {}, {}, {}, {} },
				}
				assert.are.equal(
					"Chapter" .. DOT .. "step 1/3",
					(where(ns, guide, { id = "x", chapter = 1, index = 3 }))
				)
				assert.are.equal(
					"Chapter" .. DOT .. "step 3/3",
					(where(ns, guide, { id = "x", chapter = 1, index = 5 }))
				)
			end)

			it("names the guide when the step has no chapter", function()
				local ns = start()
				local guide = { name = "Guide", chapters = {}, steps = { {}, {}, {} } }
				assert.are.equal("Guide" .. DOT .. "step 3/3", (where(ns, guide, { id = "x", chapter = 9, index = 3 })))
			end)

			it("gives just the name when the step has no number", function()
				local ns = start()
				local guide = { name = "Guide", chapters = { { name = "Chapter" } }, steps = { {}, {} } }
				assert.are.equal("Chapter", (where(ns, guide, { id = "x", chapter = 1 })))
			end)

			it("gives just the name when the guide has no steps to count", function()
				local ns = start()
				local guide = { name = "Guide", chapters = { { name = "Chapter" } }, steps = {} }
				assert.are.equal("Chapter", (where(ns, guide, { id = "x", chapter = 1, index = 1 })))
			end)

			it("gives no first line for a step that says nothing", function()
				local ns = start()
				local guide = { name = "Guide", chapters = {}, steps = { {} } }
				local _, line = where(ns, guide, { id = "x", index = 1, directives = {} })
				assert.is_nil(line)
			end)
		end)
	end)
end)

describe("the quick menu", function()
	it("lists a couple of quick options, in this order", function()
		local _, client = start()
		client.click("Signpost", "RightButton")
		assert.are.same(MENU, menuOf(client).layout())
		local kinds = {}
		for i, entry in ipairs(menuOf(client).entries) do
			kinds[i] = entry.kind
		end
		assert.are.same({
			"title",
			"button",
			"divider",
			"checkbox",
			"checkbox",
			"checkbox",
			"divider",
			"button",
			"button",
			"divider",
			"button",
			"button",
		}, kinds)
	end)

	it("opens on the UI when it is given no owner", function()
		local ns, client = start()
		assert.is_true(ns.Launcher:OpenMenu())
		assert.are.equal(G.UIParent, client.lastMenu().owner)
	end)

	it("opens the Journal", function()
		local ns, client = start()
		client.click("Signpost", "RightButton")
		menuOf(client).entry("Open the Journal").click()
		assert.is_true(ns.Journal:IsShown())
	end)

	it("opens the Settings tab", function()
		local ns, client = start()
		client.click("Signpost", "RightButton")
		menuOf(client).entry("Settings...").click()
		assert.is_true(ns.Journal:IsShown())
		assert.are.equal("settings", ns.Journal.tab)
	end)

	describe("the check boxes", function()
		it("show the card's state and flip it", function()
			local ns, client = start()
			client.click("Signpost", "RightButton")
			local shown = menuOf(client).entry("Show the step card")
			assert.is_true(shown.selected())
			shown.click()
			assert.is_false(ns.db.stepFrame.shown)
			assert.is_false(shown.selected())
			shown.click()
			assert.is_true(ns.db.stepFrame.shown)
			assert.is_true(shown.selected())
		end)

		it("lock the card and unlock it again", function()
			local ns, client = start()
			client.click("Signpost", "RightButton")
			local lock = menuOf(client).entry("Lock the step card")
			assert.is_false(lock.selected())
			lock.click()
			assert.is_true(ns.db.stepFrame.locked)
			assert.is_true(lock.selected())
			lock.click()
			assert.is_false(ns.db.stepFrame.locked)
		end)

		it("track only the current step's quests, as the Journal's box does", function()
			local ns, client = start()
			client.click("Signpost", "RightButton")
			local tracking = menuOf(client).entry("Track only the current step's quests")
			local default = ns.Tracking.DEFAULT_ENABLED
			assert.are.equal(default, tracking.selected())
			tracking.click()
			assert.are.equal(not default, ns.db.settings.trackStepQuests)
			assert.are.equal(not default, tracking.selected())
			tracking.click()
			assert.are.equal(default, ns.db.settings.trackStepQuests)
		end)

		it("agree with the Journal's own boxes", function()
			local ns, client = start()
			client.click("Signpost", "RightButton")
			menuOf(client).entry("Lock the step card").click()
			ns.Journal:Show("settings")
			local lock
			for _, box in ipairs(ns.Journal.frame.settings.boxes) do
				if box.def.label:find("^Lock the step card") then
					lock = box
				end
			end
			assert.is_true(lock.def.get())
		end)
	end)

	describe("moving through the guide", function()
		it("goes back one step, with the chat line of /signpost back", function()
			local ns, client, world, mock = start()
			ns.Progress:Next()
			world.advance(1.1)
			assert.are.equal(2, select(2, ns.Progress:Current()))
			client.click("Signpost", "RightButton")
			menuOf(client).entry("Previous step").click()
			assert.are.equal(1, select(2, ns.Progress:Current()))
			assert.truthy(printedLine(mock, "Step 1/"))
		end)

		it("skips the current step", function()
			local ns, client, _, mock = start()
			local first = ns.Progress:Current()
			client.click("Signpost", "RightButton")
			menuOf(client).entry("Skip this step").click()
			assert.is_true(ns.Progress:IsSkipped(first.id))
			assert.are.equal(2, select(2, ns.Progress:Current()))
			assert.truthy(printedLine(mock, "Step 2/"))
		end)

		it("says so, instead of failing, when there is no guide", function()
			local _, client, _, mock = start({ guide = false })
			client.click("Signpost", "RightButton")
			menuOf(client).entry("Skip this step").click()
			menuOf(client).entry("Previous step").click()
			assert.truthy(printedLine(mock, "No guide is loaded"))
		end)
	end)

	describe("Find my place", function()
		it("is offered only once the placement layer exists", function()
			local ns, client = start()
			client.click("Signpost", "RightButton")
			assert.is_nil(menuOf(client).entry("Find my place"))
			ns.Progress.Place = function() end
			client.click("Signpost", "RightButton")
			local layout = menuOf(client).layout()
			assert.are.same({
				"Signpost",
				"Open the Journal",
				"-",
				"Show the step card",
				"Lock the step card",
				"Track only the current step's quests",
				"-",
				"Find my place",
				"Previous step",
				"Skip this step",
				"-",
				"Settings...",
				"Hide the minimap button",
			}, layout)
		end)

		it("runs the player's own command when there is one", function()
			local ns, client = start()
			local ran = {}
			ns.Progress.Place = function()
				ran[#ran + 1] = "Place"
			end
			ns.Slash:Register("place", function()
				ran[#ran + 1] = "/signpost place"
			end, "test")
			client.click("Signpost", "RightButton")
			menuOf(client).entry("Find my place").click()
			assert.are.same({ "/signpost place" }, ran)
		end)

		it("calls the engine directly when only the engine has it", function()
			local ns, client = start()
			local ran = {}
			ns.Progress.Place = function(progress)
				ran[#ran + 1] = progress
			end
			assert.is_nil(ns.Slash.commands.place)
			client.click("Signpost", "RightButton")
			menuOf(client).entry("Find my place").click()
			assert.are.same({ ns.Progress }, ran)
		end)
	end)

	describe("the minimap button entry", function()
		it("hides the button and says how to bring it back", function()
			local ns, client, _, mock = start()
			client.click("Signpost", "RightButton")
			menuOf(client).entry("Hide the minimap button").click()
			assert.is_true(ns.db.minimapButton.hide)
			assert.are.same({ "Hide", "Signpost" }, client.calls[1])
			assert.is_true(client.buttons.Signpost.hidden)
			local line = assert(printedLine(mock, "Minimap button hidden"))
			assert.truthy(line:find("/signpost minimap", 1, true))
			assert.truthy(line:find("Settings", 1, true))
		end)

		it("offers the way back once the button is hidden", function()
			local ns, client = start()
			ns.Launcher:SetButtonHidden(true)
			-- the button is gone: the menu is reached from the step card or the compartment
			local frame = { name = "the step card" }
			assert.is_true(ns.Launcher:OpenMenu(frame))
			local root = menuOf(client)
			assert.is_nil(root.entry("Hide the minimap button"))
			assert.are.equal("Show the minimap button", root.layout()[#root.layout()])
			root.entry("Show the minimap button").click()
			assert.is_false(ns.db.minimapButton.hide)
			assert.is_false(client.buttons.Signpost.hidden)
			assert.are.same({ "Hide", "Signpost" }, client.calls[1])
			assert.are.same({ "Show", "Signpost" }, client.calls[2])
		end)
	end)

	it("keeps an error in an entry from reaching the menu system", function()
		local ns, client, _, mock = start()
		client.click("Signpost", "RightButton")
		ns.Journal.Show = function()
			error("the Journal is broken")
		end
		menuOf(client).entry("Open the Journal").click()
		assert.are.equal(1, #mock.errors)
		wipe(mock.errors)
		wipe(ns.db.errors)
	end)

	it("keeps an error while reading a setting from reaching the menu system: the box reads as off", function()
		local ns, client, _, mock = start()
		ns.Tracking.Enabled = function()
			error("tracking is broken")
		end
		client.click("Signpost", "RightButton")
		local root = menuOf(client)
		assert.are.same(MENU, root.layout()) -- the menu is all there
		assert.is_false(root.entry("Track only the current step's quests").selected())
		assert.are.equal(1, #mock.errors)
		wipe(mock.errors)
		wipe(ns.db.errors)
	end)
end)

describe("the AddOn Compartment entry", function()
	local function click(button)
		G.Signpost_OnAddonCompartmentClick("Signpost", button)
	end

	it("is named by both TOCs, with its hover functions", function()
		start()
		assert.is_function(G.Signpost_OnAddonCompartmentClick)
		assert.is_function(G.Signpost_OnAddonCompartmentEnter)
		assert.is_function(G.Signpost_OnAddonCompartmentLeave)
		for _, toc in ipairs({ "Signpost.toc", "Signpost_Camelot.toc" }) do
			local lines = {}
			for line in io.lines(toc) do
				lines[#lines + 1] = line
			end
			local text = table.concat(lines, "\n")
			assert.truthy(text:find("## AddonCompartmentFunc: Signpost_OnAddonCompartmentClick", 1, true), toc)
			assert.truthy(text:find("## AddonCompartmentFuncOnEnter: Signpost_OnAddonCompartmentEnter", 1, true), toc)
			assert.truthy(text:find("## AddonCompartmentFuncOnLeave: Signpost_OnAddonCompartmentLeave", 1, true), toc)
			assert.truthy(text:find("UI\\Launcher.lua", 1, true), toc)
		end
	end)

	it("toggles the Journal on a left-click", function()
		local ns = start()
		click("LeftButton")
		assert.is_true(ns.Journal:IsShown())
		click("LeftButton")
		assert.is_false(ns.Journal:IsShown())
	end)

	it(
		"toggles the step card on a Shift-left-click (read from the keyboard: the compartment says nothing of it)",
		function()
			local ns, client = start()
			client.shift = true
			click("LeftButton")
			assert.is_false(ns.db.stepFrame.shown)
			assert.is_false(ns.Journal:IsShown())
		end
	)

	it("treats a click that names no button as a left-click", function()
		local ns = start()
		click(nil)
		assert.is_true(ns.Journal:IsShown())
	end)

	it("opens the quick menu on a right-click, on the compartment, one frame later", function()
		local _, client, world = start()
		click("RightButton")
		-- the compartment closes its own menu as this function returns: ours must not be open yet
		assert.are.equal(0, #client.menus)
		world.advance(0.1)
		assert.are.equal(1, #client.menus)
		assert.are.equal(client.compartment, client.lastMenu().owner)
		assert.are.same(MENU, menuOf(client).layout())
	end)

	it("opens the menu on the UI when the client has no compartment frame", function()
		local _, client, world = start({ noCompartment = true })
		click("RightButton")
		world.advance(0.1)
		assert.are.equal(G.UIParent, client.lastMenu().owner)
	end)

	it("opens the Settings tab on a right-click without the Menu system", function()
		local ns, _, world = start({ noMenu = true })
		click("RightButton")
		world.advance(0.1)
		assert.is_true(ns.Journal:IsShown())
		assert.are.equal("settings", ns.Journal.tab)
	end)

	it("ignores the other buttons", function()
		local ns, client, world = start()
		click("MiddleButton")
		click("Button4")
		world.advance(0.1)
		assert.is_false(ns.Journal:IsShown())
		assert.is_true(ns.db.stepFrame.shown)
		assert.are.equal(0, #client.menus)
	end)

	it("still opens the Journal when the launcher is missing", function()
		local ns = start()
		ns.Launcher = nil
		click("LeftButton")
		assert.is_true(ns.Journal:IsShown())
		G.Signpost_OnAddonCompartmentEnter("Signpost", {}) -- and the hover functions do nothing, quietly
		G.Signpost_OnAddonCompartmentLeave("Signpost", {})
	end)

	it("shows the button's tooltip on the menu entry and hides it again", function()
		local _, client = start()
		local entry = { name = "the compartment's menu entry" }
		G.Signpost_OnAddonCompartmentEnter("Signpost", entry)
		local tip = client.gameTooltip
		assert.is_true(tip.shown)
		assert.are.equal(entry, tip.owner)
		assert.are.equal("ANCHOR_LEFT", tip.anchor)
		local texts = tip:texts()
		assert.are.equal("Signpost", texts[1])
		assert.are.equal("Valley" .. DOT .. "step 1/3", texts[2])
		assert.are.equal("|cffffff00Right-click|r to open the quick menu", texts[#texts])
		G.Signpost_OnAddonCompartmentLeave("Signpost", entry)
		assert.is_false(tip.shown)
	end)

	it("leaves a tooltip another add-on owns alone", function()
		local _, client = start()
		local theirs = { name = "someone else's frame" }
		client.gameTooltip:SetOwner(theirs, "ANCHOR_TOP")
		client.gameTooltip:Show()
		G.Signpost_OnAddonCompartmentLeave("Signpost", { name = "our entry" })
		assert.is_true(client.gameTooltip.shown)
	end)
end)

describe("hiding and locking the button", function()
	it("hides and shows it through LibDBIcon and remembers the choice", function()
		local ns, client = start()
		assert.is_false(ns.Launcher:ButtonHidden())
		ns.Launcher:SetButtonHidden(true)
		assert.is_true(ns.Launcher:ButtonHidden())
		assert.is_true(ns.db.minimapButton.hide)
		assert.is_true(client.buttons.Signpost.hidden)
		ns.Launcher:SetButtonHidden(false)
		assert.is_false(ns.Launcher:ButtonHidden())
		assert.is_false(ns.db.minimapButton.hide)
		assert.is_false(client.buttons.Signpost.hidden)
		assert.are.same({ { "Hide", "Signpost" }, { "Show", "Signpost" } }, client.calls)
	end)

	it("locks and unlocks its place through LibDBIcon and remembers the choice as a plain boolean", function()
		local ns, client = start()
		assert.is_false(ns.Launcher:ButtonLocked())
		ns.Launcher:SetButtonLocked(true)
		assert.is_true(ns.Launcher:ButtonLocked())
		assert.is_true(ns.db.minimapButton.lock)
		assert.is_true(client.buttons.Signpost.locked)
		ns.Launcher:SetButtonLocked(false)
		assert.is_false(ns.Launcher:ButtonLocked())
		-- LibDBIcon's Unlock clears the field: ours is false, not nil
		assert.is_false(ns.db.minimapButton.lock)
		assert.is_false(client.buttons.Signpost.locked)
		assert.are.same({ { "Lock", "Signpost" }, { "Unlock", "Signpost" } }, client.calls)
	end)

	it("keeps the choices to the next session: LibDBIcon is handed them when the button is made", function()
		local saved = { minimapButton = { hide = true, lock = true, minimapPos = 123 } }
		local _, client = start({ saved = saved })
		assert.is_true(client.buttons.Signpost.hidden)
		assert.is_true(client.buttons.Signpost.locked)
		assert.are.equal(123, client.buttons.Signpost.db.minimapPos)
	end)
end)

describe("the slash commands", function()
	local function slash(text)
		G.SlashCmdList.SIGNPOST(text)
	end

	it("/signpost card shows or hides the step card, and says nothing", function()
		local ns = start()
		slash("card")
		assert.is_false(ns.db.stepFrame.shown)
		slash("card")
		assert.is_true(ns.db.stepFrame.shown)
		slash("card off")
		assert.is_false(ns.db.stepFrame.shown)
		slash("card off")
		assert.is_false(ns.db.stepFrame.shown)
		slash("CARD ON")
		assert.is_true(ns.db.stepFrame.shown)
	end)

	it("/signpost card with a word it does not know says what it understands", function()
		local ns, _, _, mock = start()
		slash("card sideways")
		assert.is_true(ns.db.stepFrame.shown)
		assert.truthy(printedLine(mock, "Use 'card'"))
	end)

	it("/signpost minimap shows, hides, locks and unlocks the button and reports where it stands", function()
		local ns, client, _, mock = start()
		slash("minimap hide")
		assert.is_true(ns.db.minimapButton.hide)
		assert.truthy(printedLine(mock, "Minimap button: hidden, unlocked."))
		slash("minimap lock")
		assert.is_true(ns.db.minimapButton.lock)
		assert.truthy(printedLine(mock, "Minimap button: hidden, locked."))
		slash("minimap show")
		assert.is_false(ns.db.minimapButton.hide)
		assert.truthy(printedLine(mock, "Minimap button: shown, locked."))
		slash("minimap unlock")
		assert.is_false(ns.db.minimapButton.lock)
		assert.truthy(printedLine(mock, "Minimap button: shown, unlocked."))
		assert.are.same(
			{ { "Hide", "Signpost" }, { "Lock", "Signpost" }, { "Show", "Signpost" }, { "Unlock", "Signpost" } },
			client.calls
		)
	end)

	it("/signpost minimap alone shows or hides the button", function()
		local ns = start()
		slash("minimap")
		assert.is_true(ns.db.minimapButton.hide)
		slash("minimap")
		assert.is_false(ns.db.minimapButton.hide)
	end)

	it("/signpost minimap with a word it does not know changes nothing", function()
		local ns, client, _, mock = start()
		slash("minimap sideways")
		assert.is_false(ns.db.minimapButton.hide)
		assert.are.same({}, client.calls)
		assert.truthy(printedLine(mock, "Use 'minimap show'"))
	end)

	it("are in /signpost help", function()
		local _, _, _, mock = start()
		slash("help")
		assert.truthy(printedLine(mock, "/signpost card - "))
		assert.truthy(printedLine(mock, "/signpost minimap - "))
	end)
end)

-- Bindings.xml ----------------------------------------------------------------------------------------------------

local function readBindings()
	local file = assert(io.open("Bindings.xml", "r"))
	local text = file:read("*a")
	file:close()
	text = text:gsub("<!%-%-.-%-%->", "")
	local list = {}
	for attributes, body in text:gmatch("<Binding%s+([^>]-)>(.-)</Binding>") do
		list[#list + 1] = {
			name = attributes:match('name="([^"]*)"'),
			header = attributes:match('header="([^"]*)"'),
			body = (body:gsub("^%s+", ""):gsub("%s+$", "")),
		}
	end
	return list
end

-- Runs a binding's Lua body as the client does when its key is pressed.
local function press(binding)
	local chunk = assert(loadstring(binding.body, "=" .. binding.name))
	chunk()
end

describe("the key bindings", function()
	local function binding(name)
		for _, candidate in ipairs(readBindings()) do
			if candidate.name == name then
				return candidate
			end
		end
		error("Bindings.xml has no binding " .. name)
	end

	it("are the actions a player reaches for, under Signpost's header", function()
		local names = {}
		for _, candidate in ipairs(readBindings()) do
			names[#names + 1] = candidate.name
			assert.are.equal("SIGNPOST", candidate.header, candidate.name)
		end
		assert.are.same({
			"SIGNPOST_JOURNAL",
			"SIGNPOST_CARD",
			"SIGNPOST_BACK",
			"SIGNPOST_NEXT",
			"SIGNPOST_SKIP",
			"SIGNPOST_PLACE",
		}, names)
	end)

	it("have a header and a label each on the Key Bindings screen, not the bare token", function()
		start()
		assert.are.equal("Signpost", G.BINDING_HEADER_SIGNPOST)
		local labels = {}
		for _, candidate in ipairs(readBindings()) do
			local label = G["BINDING_NAME_" .. candidate.name]
			assert.is_string(label, candidate.name)
			assert.is_true(label ~= "" and label ~= candidate.name, candidate.name)
			assert.is_nil(labels[label], "two bindings are labelled " .. label)
			labels[label] = true
		end
		assert.are.equal("Show or hide the Journal", G.BINDING_NAME_SIGNPOST_JOURNAL)
		assert.are.equal("Show or hide the step card", G.BINDING_NAME_SIGNPOST_CARD)
		assert.are.equal("Previous step", G.BINDING_NAME_SIGNPOST_BACK)
		assert.are.equal("Next step", G.BINDING_NAME_SIGNPOST_NEXT)
		assert.are.equal("Skip this step", G.BINDING_NAME_SIGNPOST_SKIP)
		assert.are.equal("Find my place", G.BINDING_NAME_SIGNPOST_PLACE)
	end)

	it("are not listed in a TOC: the client loads Bindings.xml by its name", function()
		for _, toc in ipairs({ "Signpost.toc", "Signpost_Camelot.toc" }) do
			for line in io.lines(toc) do
				assert.is_nil(line:find("Bindings", 1, true), toc)
			end
		end
	end)

	it("run one /signpost command each, which exists", function()
		local ns = start()
		-- "place" is the placement layer's command (Engine/Placement.lua): a stand-in registers it here
		ns.Slash:Register("place", function() end, "test")
		for _, candidate in ipairs(readBindings()) do
			local command = candidate.body:match('^SlashCmdList%.SIGNPOST%("([^"]*)"%)$')
			assert.is_not_nil(command, candidate.name .. " runs something else: " .. candidate.body)
			assert.is_true(command == "" or ns.Slash.commands[command] ~= nil, candidate.name)
		end
	end)

	it("show or hide the Journal", function()
		local ns = start()
		press(binding("SIGNPOST_JOURNAL"))
		assert.is_true(ns.Journal:IsShown())
		press(binding("SIGNPOST_JOURNAL"))
		assert.is_false(ns.Journal:IsShown())
	end)

	it("show or hide the step card", function()
		local ns = start()
		press(binding("SIGNPOST_CARD"))
		assert.is_false(ns.db.stepFrame.shown)
		press(binding("SIGNPOST_CARD"))
		assert.is_true(ns.db.stepFrame.shown)
	end)

	it("move through the guide: next, skip, previous", function()
		local ns = start()
		local first = ns.Progress:Current()
		press(binding("SIGNPOST_NEXT"))
		assert.is_true(ns.Progress:IsDone(first.id))
		assert.are.equal(2, select(2, ns.Progress:Current()))
		press(binding("SIGNPOST_SKIP"))
		assert.is_true(ns.Progress:IsSkipped("valley:2"))
		assert.are.equal(3, select(2, ns.Progress:Current()))
		press(binding("SIGNPOST_BACK"))
		assert.are.equal(2, select(2, ns.Progress:Current()))
	end)

	it("find my place runs /signpost place", function()
		local ns = start()
		local ran = 0
		ns.Slash:Register("place", function()
			ran = ran + 1
		end, "test")
		press(binding("SIGNPOST_PLACE"))
		assert.are.equal(1, ran)
	end)
end)
