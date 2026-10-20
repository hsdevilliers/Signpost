-- Minimal stand-ins for the WoW client so addon files load and run under stock Lua 5.1 with busted. Only what the
-- specs exercise is modelled; any other frame method is a no-op returning nil.
local M = {}

local function noop() end

-- Globals a spec may define for one test; install() clears them so tests stay independent.
local RESET = {
	"SignpostDB",
	"SignpostCharDB",
	"Signpost_Data",
	"SLASH_SIGNPOST1",
	"SLASH_SIGNPOST2",
	"Signpost_OnAddonCompartmentClick",
	"SignpostTextDialog",
	"SignpostContributeWindow",
	"BugGrabber",
	"LibStub",
	"C_Map",
	"C_QuestLog",
	"C_GossipInfo",
	"C_Item",
	"C_TaxiMap",
	"C_XMLUtil",
	"C_TradeSkillUI",
	"Enum",
	"issecretvalue",
	-- client functions the Wave 1 module mocks install (tests/mocks/*.lua remove them too)
	"C_SpellBook",
	"C_SuperTrack",
	"AddQuestWatch",
	"GetNumQuestWatches",
	"GetQuestIndexForWatch",
	"IsQuestWatched",
	"RemoveQuestWatch",
	"GetBindLocation",
	"GetProfessionInfo",
	"GetProfessions",
	"GetTaxiMapID",
	"IsPlayerSpell",
	"IsSpellKnown",
	"NumTaxiNodes",
	"TaxiNodeGetType",
	"TaxiNodeName",
	"UnitHealth",
	"UnitOnTaxi",
	"UnitPosition",
	"UnitPower",
}

function M.install()
	for _, name in ipairs(RESET) do
		_G[name] = nil
	end

	local mock = {
		frames = {},
		printed = {},
		errors = {},
		timers = {},
		now = 100.5,
		clock = 1790000000,
		metadata = { Version = "@project-version@", ["X-Flavor-TOC"] = "test" },
		unknownEvents = { NOT_A_REAL_EVENT = true },
	}

	local methods = {}
	local frameMeta = {
		__index = function(_, key)
			return methods[key] or noop
		end,
	}
	function methods.RegisterEvent(frame, event)
		if mock.unknownEvents[event] then
			error('Attempt to register unknown event "' .. event .. '"', 2)
		end
		frame.events[event] = true
	end
	methods.RegisterUnitEvent = methods.RegisterEvent
	function methods.UnregisterEvent(frame, event)
		frame.events[event] = nil
	end
	function methods.UnregisterAllEvents(frame)
		frame.events = {}
	end
	function methods.IsEventRegistered(frame, event)
		return frame.events[event] == true
	end
	function methods.SetScript(frame, script, fn)
		frame.scripts[script] = fn
	end
	function methods.GetScript(frame, script)
		return frame.scripts[script]
	end
	function methods.Show(frame)
		frame.shown = true
	end
	function methods.Hide(frame)
		frame.shown = false
	end
	function methods.IsShown(frame)
		return frame.shown == true
	end
	-- A frame's font strings, textures and lines get the same generic methods, so UI code can build its widgets.
	local function newRegion(kind)
		return setmetatable({ frameType = kind, events = {}, scripts = {} }, frameMeta)
	end
	function methods.CreateFontString()
		return newRegion("FontString")
	end
	function methods.CreateTexture()
		return newRegion("Texture")
	end
	function methods.CreateLine()
		return newRegion("Line")
	end

	function CreateFrame(frameType, name, _, template)
		local frame = setmetatable({
			frameType = frameType,
			name = name,
			template = template,
			events = {},
			scripts = {},
		}, frameMeta)
		mock.frames[#mock.frames + 1] = frame
		if name then
			_G[name] = frame
		end
		return frame
	end

	-- Delivers a game event to every frame registered for it, as the client does.
	function mock.fire(event, ...)
		for _, frame in ipairs(mock.frames) do
			if frame.events[event] and frame.scripts.OnEvent then
				frame.scripts.OnEvent(frame, event, ...)
			end
		end
	end

	-- Runs C_Timer.After callbacks until none are left.
	function mock.runTimers()
		while #mock.timers > 0 do
			local pending = mock.timers
			mock.timers = {}
			for _, fn in ipairs(pending) do
				fn()
			end
		end
	end

	local handler = function(err)
		mock.errors[#mock.errors + 1] = tostring(err)
	end
	function geterrorhandler()
		return handler
	end
	function seterrorhandler(fn)
		handler = fn
	end
	function debugstack()
		return "(mock stack)"
	end

	function GetTime()
		return mock.now
	end
	function time()
		return mock.clock
	end
	function wipe(tbl)
		for key in pairs(tbl) do
			tbl[key] = nil
		end
		return tbl
	end
	tinsert = table.insert
	function GetBuildInfo()
		return "1.60.1", "70450", "Oct 1 2026", 16001
	end
	C_AddOns = {
		GetAddOnMetadata = function(_, field)
			return mock.metadata[field]
		end,
	}
	C_Timer = {
		After = function(_, fn)
			mock.timers[#mock.timers + 1] = fn
		end,
		NewTicker = function(_, fn)
			local ticker = { fn = fn }
			function ticker.Cancel(self)
				self.cancelled = true
			end
			return ticker
		end,
	}
	DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, text)
			mock.printed[#mock.printed + 1] = text
		end,
	}
	SlashCmdList = {}
	UISpecialFrames = {}
	UIParent = CreateFrame("Frame", "UIParent")
	function UnitClass()
		return "Hunter", "HUNTER", 3
	end
	function UnitRace()
		return "Troll", "Troll", 8
	end
	function UnitFactionGroup()
		return "Horde", "Horde"
	end
	function UnitLevel()
		return 1
	end

	WowMock = mock
	return mock
end

return M
