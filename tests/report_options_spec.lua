-- UI/Report.lua ("Report this step") and UI/Options.lua (the entry in Blizzard's Options window) on the real engine
-- and the scripted client of tests/mocks/context.lua.
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local GUIDE = {
	id = "test-report",
	name = "Report Test",
	faction = "*",
	races = { "*" },
	classes = { "*" },
	levels = { 1, 10 },
	text = "#chapter 1-6 Valley\nstep\n  .goto 1411,43.35,68.70\n  .accept 4641\nstep\n  .note Second\n",
}

local sessions = {}

after_each(function()
	for _, session in ipairs(sessions) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
	sessions = {}
	contextMock.uninstall()
	G.Settings = nil
end)

local function start(setup)
	local world
	local ns, mock = addon.load({
		login = false,
		before = function(m)
			world = contextMock.install(m)
			if setup then
				setup(world, m)
			end
		end,
	})
	assert.is_true(ns.Guides:Register(GUIDE))
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	world.advance(1)
	sessions[#sessions + 1] = { ns = ns, mock = mock }
	return ns, world, mock
end

describe("Report this step", function()
	it("records the guide, the step, the level and a cleaned note", function()
		local ns = start()
		local entry = ns.Report:Add(nil, "  the quest\nis not   here\t!  ")
		assert.are.equal("test-report", entry.guide)
		assert.are.equal(ns.Progress:Current().id, entry.step)
		assert.are.equal("the quest is not here !", entry.note)
		assert.are.equal(1, #ns.db.reports)
		assert.are.equal(1, ns.Report:Count())
	end)

	it("keeps no note when there is none and caps a long one", function()
		local ns = start()
		assert.is_nil(ns.Report:Add(nil, "   ").note)
		local long = ns.Report:Add(nil, string.rep("x", 1000))
		assert.are.equal(ns.Report.MAX_NOTE, #long.note)
	end)

	it("keeps the newest 200 reports", function()
		local ns = start()
		for i = 1, ns.Report.MAX_REPORTS + 5 do
			ns.Report:Add(nil, "n" .. i)
		end
		assert.are.equal(ns.Report.MAX_REPORTS, #ns.db.reports)
		assert.are.equal("n6", ns.db.reports[1].note)
		assert.are.equal("n205", ns.db.reports[#ns.db.reports].note)
	end)

	it("says so and records nothing when there is no step", function()
		local ns, _, mock = start()
		ns.Progress:SetGuide(nil)
		assert.is_nil(ns.Report:Add())
		assert.are.equal(0, #ns.db.reports)
		assert.is_truthy(mock.printed[#mock.printed]:find("no current step", 1, true))
	end)

	it("is reachable as /signpost report [note] and /signpost report count", function()
		local ns, _, mock = start()
		G.SlashCmdList.SIGNPOST("report wrong place")
		assert.are.equal("wrong place", ns.db.reports[1].note)
		G.SlashCmdList.SIGNPOST("report count")
		assert.is_truthy(mock.printed[#mock.printed]:find("1 step reports", 1, true))
		assert.are.equal(1, #ns.db.reports) -- "count" does not add one
	end)

	it("fires REPORT_ADDED and is a button in the Journal's Route tab", function()
		local ns = start()
		local seen
		ns.Events:RegisterMessage("REPORT_ADDED", function(_, entry)
			seen = entry
		end)
		ns.Journal:Show("route")
		local button = ns.Journal.frame.route.report
		assert.is_not_nil(button)
		button.scripts.OnClick(button)
		assert.is_not_nil(seen)
		assert.are.equal(1, #ns.db.reports)
	end)

	it("is part of the data /signpost export shows", function()
		local ns = start()
		ns.Report:Add(nil, "export me")
		local shown
		ns.UI.ShowTextDialog = function(_, _, text)
			shown = text
		end
		G.SlashCmdList.SIGNPOST("export")
		assert.is_truthy(shown and shown:find("export me", 1, true))
	end)
end)

describe("the Options entry", function()
	it("registers a panel with a button that opens the Journal's Settings tab", function()
		local registered
		local ns = start(function()
			G.Settings = {
				RegisterCanvasLayoutCategory = function(panel, name)
					return { panel = panel, name = name }
				end,
				RegisterAddOnCategory = function(category)
					registered = category
				end,
			}
		end)
		assert.is_not_nil(registered)
		assert.are.equal("Signpost", registered.name)
		local button = ns.Options.button
		button.scripts.OnClick(button)
		assert.is_true(ns.Journal:IsShown())
		assert.are.equal("settings", ns.Journal.tab)
	end)

	it("is left out quietly when the client has no Settings API", function()
		local ns = start()
		assert.is_false(ns.Options:Register())
		assert.is_nil(ns.Options.category)
	end)

	it("registers only once", function()
		local count = 0
		local ns = start(function()
			G.Settings = {
				RegisterCanvasLayoutCategory = function()
					return {}
				end,
				RegisterAddOnCategory = function()
					count = count + 1
				end,
			}
		end)
		assert.is_true(ns.Options:Register())
		assert.are.equal(1, count)
	end)
end)
