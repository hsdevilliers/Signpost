local addon = dofile("tests/helpers/addon.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local function find(list, predicate)
	for _, item in ipairs(list) do
		if predicate(item) then
			return item
		end
	end
end

describe("loading", function()
	it("loads every TOC file without the data pack and without errors", function()
		local ns, mock = addon.load()
		assert.are.same({}, mock.errors)
		assert.are.same({}, ns.db.errors)
		assert.is_false(ns.dataPackAtLoad)
		assert.are.equal(ns.EmptyDB, ns.DB)
		assert.are.equal("dev", ns.version)
		assert.are.equal("test", ns.tocFlavor)
	end)

	it("announces a dev build at login", function()
		local _, mock = addon.load()
		assert.truthy(find(mock.printed, function(line)
			return line:find("(dev) loaded", 1, true) ~= nil
		end))
	end)

	it("knows the player only through ns.Player", function()
		local ns = addon.load()
		assert.are.equal("HUNTER", ns.Player.classFile)
		assert.are.equal("Troll", ns.Player.raceFile)
		assert.are.equal("Horde", ns.Player.faction)
		assert.are.equal(1, ns.Player.level)
	end)
end)

describe("ns.SafeCall", function()
	it("returns true and the function's results", function()
		local ns = addon.load()
		assert.are.same({ true, 3, "x" }, { ns.SafeCall(function(a, b)
			return a + b, "x"
		end, 1, 2) })
	end)

	it("passes nil arguments through", function()
		local ns = addon.load()
		assert.are.same({ true, 3 }, { ns.SafeCall(select, "#", nil, nil, nil) })
	end)

	it("sends an error to the error handler, records it and returns false", function()
		local ns, mock = addon.load()
		local ok = ns.SafeCall(function()
			error("boom")
		end)
		assert.is_false(ok)
		assert.are.equal(1, #ns.db.errors)
		assert.truthy(ns.db.errors[1].msg:find("boom", 1, true))
		-- the previous handler (Blizzard's, in the client) still sees it
		assert.are.equal(1, #mock.errors)
	end)
end)

describe("ns.Events", function()
	it("dispatches game events and internal messages", function()
		local ns, mock = addon.load()
		local seen = {}
		ns.Events:Register("QUEST_ACCEPTED", function(event, questID)
			seen[#seen + 1] = event .. ":" .. questID
		end)
		ns.Events:RegisterMessage("STEP_CHANGED", function(message, step)
			seen[#seen + 1] = message .. ":" .. step
		end)
		mock.fire("QUEST_ACCEPTED", 787)
		ns.Events:Fire("STEP_CHANGED", 2)
		assert.are.same({ "QUEST_ACCEPTED:787", "STEP_CHANGED:2" }, seen)
	end)

	it("returns false for an event the client rejects", function()
		local ns = addon.load()
		assert.is_false(ns.Events:Register("NOT_A_REAL_EVENT", function() end))
	end)

	it("keeps dispatching when one handler errors or unregisters itself", function()
		local ns, mock = addon.load()
		local calls = {}
		local function once(event)
			calls[#calls + 1] = "once"
			ns.Events:Unregister(event, once)
		end
		ns.Events:Register("QUEST_REMOVED", once)
		ns.Events:Register("QUEST_REMOVED", function()
			error("handler failure")
		end)
		ns.Events:Register("QUEST_REMOVED", function()
			calls[#calls + 1] = "last"
		end)
		mock.fire("QUEST_REMOVED", 1)
		mock.fire("QUEST_REMOVED", 1)
		assert.are.same({ "once", "last", "last" }, calls)
		assert.are.equal(1, #ns.db.errors)
		assert.are.equal(2, ns.db.errors[1].count)
	end)
end)

describe("SavedVariables", function()
	it("creates both tables with defaults at ADDON_LOADED", function()
		local ns = addon.load()
		assert.are.equal(SignpostDB, ns.db)
		assert.are.equal(SignpostCharDB, ns.char)
		assert.are.equal(1, ns.db.dbVersion)
		assert.are.same({ npcs = {}, objects = {}, taxi = {}, crossings = {} }, ns.db.learned)
		assert.are.same({}, ns.char.progress)
		assert.are.same(
			{ time = 1790000000, version = "dev", toc = "test", client = "1.60.1", build = "70450", interface = 16001 },
			ns.db.lastLoad
		)
	end)

	it("keeps stored values and fills in only what is missing", function()
		local ns = addon.load({
			before = function()
				G.SignpostDB = { dbVersion = 1, settings = { scale = 2 }, debug = { chat = true } }
			end,
		})
		assert.are.equal(2, ns.db.settings.scale)
		assert.is_true(ns.db.debug.chat)
		assert.is_false(ns.db.debug.enabled)
		assert.are.same({}, ns.db.debug.counts)
	end)

	it("runs the migrations newer than the stored version, in order", function()
		local ns = addon.load()
		local order = {}
		local db = { dbVersion = 1 }
		ns.SavedVars.Upgrade(db, {
			[1] = function()
				order[#order + 1] = 1
			end,
			[2] = function()
				order[#order + 1] = 2
			end,
			[3] = function()
				order[#order + 1] = 3
			end,
		}, 3)
		assert.are.same({ 2, 3 }, order)
		assert.are.equal(3, db.dbVersion)
	end)

	it("does not migrate a brand-new table", function()
		local ns = addon.load()
		local db = {}
		ns.SavedVars.Upgrade(db, {
			[1] = function()
				error("must not run")
			end,
		}, 1)
		assert.are.same({ dbVersion = 1 }, db)
	end)
end)

describe("error log", function()
	it("keeps errors raised before SavedVariables load", function()
		local ns, mock = addon.load({ login = false })
		ns.SafeCall(function()
			error("too early")
		end)
		mock.fire("ADDON_LOADED", "Signpost")
		assert.are.equal(1, #ns.db.errors)
		assert.truthy(ns.db.errors[1].msg:find("too early", 1, true))
	end)

	it("counts repeats and keeps the 50 most recently seen errors", function()
		local ns = addon.load()
		for i = 1, 60 do
			ns.Errors:Record("error " .. i)
		end
		ns.Errors:Record("error 30")
		local list = ns.db.errors
		assert.are.equal(50, #list)
		assert.are.equal("error 11", list[1].msg)
		assert.are.equal("error 30", list[50].msg)
		assert.are.equal(2, list[50].count)
	end)

	it("marks errors that mention Signpost as ours", function()
		local ns = addon.load()
		assert.is_true(ns.Errors:Record("Interface/AddOns/Signpost/Core/Util.lua:1: x").ours)
		assert.is_false(ns.Errors:Record("Interface/AddOns/Other/Other.lua:1: y").ours)
	end)
end)

describe("Util", function()
	local ns
	before_each(function()
		ns = addon.load()
	end)

	it("encodes JSON with sorted keys, arrays and escapes", function()
		local json = ns.Util.ToJSON({ b = { 1, 2.5, true }, a = 'say "hi"\n', c = {}, d = { [3] = "x" } })
		assert.are.equal('{"a":"say \\"hi\\"\\n","b":[1,2.5,true],"c":[],"d":{"3":"x"}}', json)
	end)

	it("pretty-prints JSON", function()
		assert.are.equal('{\n  "a": [\n    1\n  ]\n}', ns.Util.ToJSON({ a = { 1 } }, "  "))
	end)

	it("sanitizes values for SavedVariables", function()
		local frame = CreateFrame("Frame")
		frame[0] = newproxy and newproxy() or nil
		local clean = ns.Util.Sanitize({
			text = string.rep("x", 600),
			fn = print,
			nan = 0 / 0,
			nested = { ok = true, frame = frame[0] and frame or nil },
		})
		assert.are.equal(503, #clean.text)
		assert.is_nil(clean.fn)
		assert.are.equal("string", type(clean.nan))
		assert.is_true(clean.nested.ok)
		assert.is_nil(clean.nested.frame)
	end)

	it("replaces secret values when the client can identify them", function()
		G.issecretvalue = function(value)
			return value == "SECRET"
		end
		assert.are.same({ a = "<secret>", b = 1 }, ns.Util.Sanitize({ a = "SECRET", b = 1 }))
		assert.is_nil(ns.Util.Round("SECRET"))
	end)

	it("extracts NPC IDs from GUIDs", function()
		assert.are.equal(3100, ns.Util.NpcIDFromGUID("Creature-0-1465-1-47-3100-00004F2B3C"))
		assert.are.equal(1617, ns.Util.NpcIDFromGUID("GameObject-0-1465-1-47-1617-00004F2B3C"))
		assert.is_nil(ns.Util.NpcIDFromGUID("Player-1465-0A1B2C3D"))
		assert.is_nil(ns.Util.NpcIDFromGUID(nil))
	end)

	it("rounds with a scale", function()
		assert.are.equal(42.13, ns.Util.Round(0.421349, 2, 100))
		assert.is_nil(ns.Util.Round(nil))
	end)
end)

describe("slash commands", function()
	it("registers /signpost and /sign", function()
		addon.load()
		assert.are.equal("/signpost", SLASH_SIGNPOST1)
		assert.are.equal("/sign", SLASH_SIGNPOST2)
		assert.is_function(SlashCmdList.SIGNPOST)
		assert.is_function(Signpost_OnAddonCompartmentClick)
	end)

	it("stores the ping marker", function()
		local ns = addon.load()
		SlashCmdList.SIGNPOST("ping")
		-- the text itself changes with every dev-loop check, so only its shape is pinned here
		assert.are.equal("string", type(ns.db.ping.text))
		assert.is_true(#ns.db.ping.text > 0)
		assert.are.equal(1790000000, ns.db.ping.time)
		assert.are.equal("dev", ns.db.ping.version)
	end)

	it("answers an unknown command with the command list", function()
		local _, mock = addon.load()
		SlashCmdList.SIGNPOST("nonsense")
		assert.truthy(find(mock.printed, function(line)
			return line:find("Unknown command 'nonsense'", 1, true) ~= nil
		end))
		assert.truthy(find(mock.printed, function(line)
			return line:find("/signpost probe", 1, true) ~= nil
		end))
	end)

	it("records the deliberate error from debug throw", function()
		local ns = addon.load()
		SlashCmdList.SIGNPOST("debug throw")
		assert.are.equal(1, #ns.db.errors)
		assert.truthy(ns.db.errors[1].msg:find("Deliberate test error", 1, true))
	end)
end)

describe("data pack", function()
	it("uses a compatible pack without modifying it", function()
		local pack =
			{ _meta = { schema = 1, source = "stub", generated = "2026-10-17" }, quests = { [1] = { n = "Q" } } }
		local ns = addon.load({
			before = function()
				G.Signpost_Data = pack
			end,
		})
		assert.is_true(ns.dataPackAtLoad)
		assert.are.equal(pack.quests, ns.DB.quests)
		assert.are.same({}, ns.DB.npcs)
		assert.is_nil(pack.npcs)
		assert.truthy(ns.Data:Describe():find("2026-10-17", 1, true))
	end)

	it("runs without a pack whose schema differs", function()
		local ns = addon.load({
			before = function()
				G.Signpost_Data = { _meta = { schema = 99 } }
			end,
		})
		assert.are.equal(ns.EmptyDB, ns.DB)
		assert.truthy(ns.Data:Describe():find("schema 99", 1, true))
	end)
end)

describe("debug log", function()
	it("logs events with position snapshots and coalesces identical repeats", function()
		local ns, mock = addon.load()
		SlashCmdList.SIGNPOST("debug on")
		mock.fire("ZONE_CHANGED")
		mock.fire("UI_INFO_MESSAGE", 1, "Boar slain: 1/10")
		mock.fire("UI_INFO_MESSAGE", 1, "Boar slain: 1/10")
		mock.fire("UI_INFO_MESSAGE", 1, "Boar slain: 2/10")
		local log = ns.db.eventLog
		assert.are.equal(3, #log)
		assert.are.equal("ZONE_CHANGED", log[1].e)
		assert.is_table(log[1].s.pos)
		assert.are.equal(2, log[2].count)
		assert.are.same({ n = 2, 1, "Boar slain: 2/10" }, log[3].a)
	end)

	it("only counts the frequent events", function()
		local ns, mock = addon.load()
		SlashCmdList.SIGNPOST("debug on")
		mock.fire("QUEST_LOG_UPDATE")
		mock.fire("QUEST_LOG_UPDATE")
		assert.are.equal(0, #ns.db.eventLog)
		assert.are.equal(2, ns.db.debug.counts.QUEST_LOG_UPDATE)
	end)

	it("stays on across a reload", function()
		addon.load()
		SlashCmdList.SIGNPOST("debug on")
		local saved = SignpostDB
		local ns, mock = addon.load({
			before = function()
				G.SignpostDB = saved
			end,
		})
		mock.fire("ZONE_CHANGED_NEW_AREA")
		assert.are.equal("ZONE_CHANGED_NEW_AREA", ns.db.eventLog[#ns.db.eventLog].e)
	end)

	it("records nothing while off", function()
		local ns, mock = addon.load()
		mock.fire("ZONE_CHANGED")
		assert.are.equal(0, #ns.db.eventLog)
	end)
end)

describe("probe", function()
	it("completes every section on a client that lacks most APIs", function()
		local ns = addon.load()
		SlashCmdList.SIGNPOST("probe")
		local probe = ns.db.probe
		for _, name in ipairs({ "build", "addons", "apis", "templates", "atlases", "files", "events", "frames" }) do
			assert.is_table(probe[name], name)
			assert.is_nil(probe[name].error, name)
		end
		for _, name in ipairs({ "quests", "professions", "player", "values", "ammo", "map", "libraries", "minimap" }) do
			assert.is_table(probe[name], name)
			assert.is_nil(probe[name].error, name)
		end
		assert.are.equal(16001, probe.build.interface)
		assert.are.equal("Horde", probe.player.faction)
		assert.is_true(probe.atlases.TaxiNode_Horde == false)
		assert.are.same({}, probe.build.slashCollisions)
	end)

	it("reports a slash command that collides with ours", function()
		local ns = addon.load()
		G.SLASH_SOMEONEELSE1 = "/sign"
		SlashCmdList.SIGNPOST("probe")
		G.SLASH_SOMEONEELSE1 = nil
		assert.are.same({ SLASH_SOMEONEELSE1 = "/sign" }, ns.db.probe.build.slashCollisions)
	end)
end)

describe("dumpmaps", function()
	it("walks the map tree from the player's root and saves it sorted", function()
		local maps = {
			[946] = { mapID = 946, name = "Cosmic", mapType = 0, parentMapID = 0 },
			[1] = { mapID = 1, name = "World", mapType = 1, parentMapID = 946 },
			[3] = { mapID = 3, name = "Zone", mapType = 3, parentMapID = 1 },
		}
		local ns, mock = addon.load({
			before = function()
				G.C_Map = {
					GetBestMapForUnit = function()
						return 3
					end,
					GetMapInfo = function(id)
						return maps[id]
					end,
					GetMapChildrenInfo = function(id)
						if id == 946 then
							return { maps[1], maps[3] }
						end
						return {}
					end,
				}
			end,
		})
		SlashCmdList.SIGNPOST("dumpmaps")
		mock.runTimers()
		local ids = {}
		for i, entry in ipairs(ns.db.mapDump.maps) do
			ids[i] = entry.id
		end
		assert.are.same({ 1, 3, 946 }, ids)
		assert.are.same({ 946, 1, 3 }, { ns.db.mapDump.playerChain[3].id, ns.db.mapDump.playerChain[2].id, 3 })
		assert.is_false(ns.MapDump.running == true)
	end)
end)
