-- Core/Contribute.lua and UI/Contribute.lua: nothing is recorded on a release build until the player says yes.
local addon = dofile("tests/helpers/addon.lua")
local mocks = dofile("tests/mocks/learn.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local GORNEK = "Creature-0-1465-1-47-3143-00004F2B3C"

-- A release build reports a real version; a git checkout (the mock's default) reports "dev".
local function load(release, before)
	local world
	local ns, mock = addon.load({
		before = function(m)
			world = mocks.install(G)
			if release then
				m.metadata.Version = "1.0.0"
			end
			if before then
				before(m, world)
			end
		end,
	})
	return ns, mock, world
end

local function talkToGornek(world, mock)
	world.units.npc = { guid = GORNEK, name = "Gornek" }
	mock.fire("GOSSIP_SHOW")
end

local function say(mock, text)
	G.SlashCmdList.SIGNPOST(text)
	return mock.printed[#mock.printed]
end

describe("Contribute", function()
	describe("recording", function()
		it("records nothing on a release build before the player agrees", function()
			local ns, mock, world = load(true)
			assert.is_false(ns.isDev)
			assert.is_false(ns.Contribute:Enabled())
			talkToGornek(world, mock)
			assert.are.equal(0, ns.Learn:Counts().npcs)
		end)

		it("records after the player agrees and stops when they take it back", function()
			local ns, mock, world = load(true)
			assert.is_true(ns.Contribute:SetEnabled(true))
			talkToGornek(world, mock)
			assert.are.equal(1, ns.Learn:Counts().npcs)
			ns.Contribute:SetEnabled(false)
			world.units.npc = { guid = "Creature-0-1465-1-47-3144-00004F2B3C", name = "Other" }
			mock.fire("GOSSIP_SHOW")
			assert.are.equal(1, ns.Learn:Counts().npcs)
		end)

		it("always records on a development build", function()
			local ns, mock, world = load(false)
			assert.is_true(ns.isDev)
			assert.is_true(ns.Contribute:Enabled())
			talkToGornek(world, mock)
			assert.are.equal(1, ns.Learn:Counts().npcs)
		end)

		it("keeps the answer in SavedVariables and answers no without a database", function()
			local ns = load(true)
			ns.Contribute:SetEnabled(true)
			assert.is_true(ns.db.contribute.enabled)
			local db = ns.db
			ns.db = nil
			assert.is_false(ns.Contribute:Enabled())
			assert.is_false(ns.Contribute:SetEnabled(true))
			ns.db = db
		end)

		it("does not switch on the debug event log", function()
			local ns = load(true)
			ns.Contribute:SetEnabled(true)
			assert.is_false(ns.db.debug.enabled)
		end)
	end)

	describe("/signpost contribute", function()
		it("turns recording on and off and reports it", function()
			local ns, mock = load(true)
			assert.is_truthy(say(mock, "contribute on"):find("recording is on", 1, true))
			assert.is_true(ns.Contribute:Enabled())
			assert.is_truthy(say(mock, "contribute off"):find("recording is off", 1, true))
			assert.is_false(ns.Contribute:Enabled())
			assert.is_truthy(say(mock, "contribute status"):find("recording is off", 1, true))
		end)

		it("opens the window without a word", function()
			local ns, mock = load(true)
			say(mock, "contribute")
			assert.is_true(ns.UI.Contribute.frame:IsShown())
		end)
	end)

	describe("the window", function()
		it("opens by itself once on a release build, after a delay", function()
			local ns, mock = load(true)
			assert.is_nil(ns.UI.Contribute.frame)
			mock.runTimers()
			assert.is_true(ns.UI.Contribute.frame:IsShown())
			assert.are.same({}, mock.errors)
		end)

		it("is not shown again once it has been closed, whatever the answer", function()
			local ns, mock = load(true)
			mock.runTimers()
			local frame = ns.UI.Contribute.frame
			frame.scripts.OnHide(frame)
			assert.is_true(ns.Contribute:Asked())
			assert.is_false(ns.Contribute:Enabled())
			ns.UI.Contribute.frame = nil
			mock.fire("PLAYER_LOGIN")
			mock.runTimers()
			assert.is_nil(ns.UI.Contribute.frame)
		end)

		it("never opens by itself on a development build", function()
			local ns, mock = load(false)
			mock.runTimers()
			assert.is_nil(ns.UI.Contribute.frame)
		end)

		it("waits out combat", function()
			local ns, mock = load(true, function()
				G.InCombatLockdown = function()
					return true
				end
			end)
			assert.is_nil(ns.UI.Contribute.frame)
			-- the first-run timer fires once in combat and queues a retry
			local timers = mock.timers
			mock.timers = {}
			for _, fn in ipairs(timers) do
				fn()
			end
			assert.is_nil(ns.UI.Contribute.frame)
			G.InCombatLockdown = function()
				return false
			end
			mock.runTimers()
			assert.is_true(ns.UI.Contribute.frame:IsShown())
			G.InCombatLockdown = nil
		end)

		-- The consent text must name everything the recorder keeps about the player (docs/SHARING-DATA.md has the same
		-- list), or the yes is not an informed one (R-engine-2 #6). The generic client mock keeps no text, so this
		-- records what the window sets on its font strings.
		describe("says in plain words what it records", function()
			local function textOfTheWindow()
				local texts = {}
				local ns = load(true, function()
					local createFrame = G.CreateFrame
					G.CreateFrame = function(...)
						local frame = createFrame(...)
						local createFontString = frame.CreateFontString
						rawset(frame, "CreateFontString", function(self, ...)
							local region = createFontString(self, ...)
							rawset(region, "SetText", function(field, text)
								rawset(field, "text", text)
								texts[#texts + 1] = text
							end)
							return region
						end)
						return frame
					end
				end)
				ns.UI.Contribute:Show()
				return table.concat(texts, "\n"), ns
			end

			it("each thing it keeps about the player", function()
				local text = textOfTheWindow()
				for _, phrase in ipairs({
					"your skill in a profession next to each recipe",
					"whether you already know a service a trainer offers",
					"how long a boat or zeppelin ride took",
					"and your faction",
				}) do
					assert.is_truthy(text:find(phrase, 1, true), phrase)
				end
			end)

			it("and what it never keeps: chat, gold, the names of players and pets", function()
				local text = textOfTheWindow()
				assert.is_truthy(text:find("No chat, none of your gold and no player or pet names.", 1, true))
			end)

			it("in the one block of text under the title, which the window keeps as frame.What", function()
				local _, ns = textOfTheWindow()
				local what = ns.UI.Contribute.frame.What.text
				assert.is_truthy(what:find("Where NPCs, quest givers", 1, true))
				assert.is_truthy(what:find("your faction", 1, true))
				assert.is_truthy(what:find("none of your gold", 1, true))
			end)
		end)

		it("the checkbox saves the answer", function()
			local ns, mock = load(true)
			say(mock, "contribute")
			local check = ns.UI.Contribute.frame.Check
			check.GetChecked = function()
				return true
			end
			check.scripts.OnClick(check)
			assert.is_true(ns.Contribute:Enabled())
			check.GetChecked = function()
				return false
			end
			check.scripts.OnClick(check)
			assert.is_false(ns.Contribute:Enabled())
			assert.are.same({}, mock.errors)
		end)
	end)
end)
