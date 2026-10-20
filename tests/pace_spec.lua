-- Core/Pace.lua: the time played at each level-up, recorded per character, only with the player's yes.
local addon = dofile("tests/helpers/addon.lua")
local G = addon.G

local function load(release)
	return addon.load({
		before = function(mock)
			if release then
				mock.metadata.Version = "1.0.0"
			end
			G.requested = 0
			G.RequestTimePlayed = function()
				G.requested = G.requested + 1
			end
			G.shown = 0
			G.ChatFrame_DisplayTimePlayed = function()
				G.shown = G.shown + 1
			end
		end,
	})
end

describe("Pace", function()
	local original

	before_each(function()
		original = G.ChatFrame_DisplayTimePlayed
	end)

	after_each(function()
		G.RequestTimePlayed, G.ChatFrame_DisplayTimePlayed, G.requested, G.shown = nil, original, nil, nil
	end)

	it("asks for the time played at a level-up and records the answer under the new level", function()
		local ns, mock = load(false)
		mock.fire("PLAYER_LEVEL_UP", 5)
		assert.are.equal(1, G.requested)
		mock.fire("TIME_PLAYED_MSG", 3600, 600)
		assert.are.equal(3600, ns.char.pace[5].played)
		assert.is_number(ns.char.pace[5].at)
	end)

	it("keeps the chat line away from the player's own request only", function()
		local _, mock = load(false)
		mock.fire("PLAYER_LEVEL_UP", 5)
		G.ChatFrame_DisplayTimePlayed()
		assert.are.equal(0, G.shown) -- hidden while Signpost's request is out
		mock.fire("TIME_PLAYED_MSG", 3600, 600)
		G.ChatFrame_DisplayTimePlayed()
		assert.are.equal(1, G.shown) -- given back after the answer
	end)

	it("gives the chat line back when no answer comes", function()
		local _, mock = load(false)
		mock.fire("PLAYER_LEVEL_UP", 5)
		mock.runTimers()
		G.ChatFrame_DisplayTimePlayed()
		assert.are.equal(1, G.shown)
	end)

	it("records nothing on a release build before the player agrees", function()
		local ns, mock = load(true)
		mock.fire("PLAYER_LEVEL_UP", 5)
		assert.are.equal(0, G.requested)
		mock.fire("TIME_PLAYED_MSG", 3600, 600)
		assert.is_nil(ns.char.pace[5])
		ns.Contribute:SetEnabled(true)
		mock.fire("PLAYER_LEVEL_UP", 6)
		mock.fire("TIME_PLAYED_MSG", 4000, 400)
		assert.are.equal(4000, ns.char.pace[6].played)
	end)

	it("records a /played the player asked for at their level, once", function()
		local ns, mock = load(false)
		G.UnitLevel = function()
			return 7
		end
		mock.fire("TIME_PLAYED_MSG", 5000, 100)
		mock.fire("TIME_PLAYED_MSG", 5600, 700)
		assert.are.equal(5000, ns.char.pace[7].played)
		assert.are.equal(0, G.requested)
	end)

	it("bounds the table and ignores bad values", function()
		local ns = load(false)
		assert.is_false(ns.Pace:Record("5", 100))
		assert.is_false(ns.Pace:Record(5, "x"))
		for level = 1, 100 do
			assert.is_true(ns.Pace:Record(level, level * 10))
		end
		assert.is_false(ns.Pace:Record(101, 1))
		assert.is_true(ns.Pace:Record(50, 999)) -- an existing level may be replaced
	end)
end)
