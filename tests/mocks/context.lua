-- Scriptable client state for tests/context_spec.lua: the quest log and its watch list (the tracked quests, both API
-- shapes), completed quests, spells, bags, level, position and map tree, taxi state, bind location, both flight-map API
-- shapes, a fake HereBeDragons behind a fake LibStub, and a clock that runs C_Timer callbacks in time order when a test
-- advances it.
--
--   local world = contextMock.install(mock)   -- in addon.load's `before`, after tests/wow_mock.lua installed
--   world.x = world.x + 1; world.advance(0.5)  -- move one percent east, let half a second pass
--   contextMock.uninstall()                    -- in after_each: removes the globals wow_mock does not reset
local M = {}

-- Globals defined here that tests/wow_mock.lua does not clear on install.
local OWN = {
	"AddQuestWatch",
	"C_SuperTrack",
	"GetNumQuestWatches",
	"GetQuestIndexForWatch",
	"IsQuestWatched",
	"RemoveQuestWatch",
	"UnitPosition",
	"UnitOnTaxi",
	"GetBindLocation",
	"IsPlayerSpell",
	"IsSpellKnown",
	"C_SpellBook",
	"NumTaxiNodes",
	"TaxiNodeName",
	"TaxiNodeGetType",
	"GetTaxiMapID",
	"UnitHealth",
	"UnitPower",
}

-- The verified map tree (FOREVER-API-NOTES): root 947; Orgrimmar 1454 is a sibling of Durotar 1411, not its child.
local function maps()
	return {
		[947] = { mapID = 947, name = "Azeroth", mapType = 1, parentMapID = 0 },
		[1414] = { mapID = 1414, name = "Kalimdor", mapType = 2, parentMapID = 947 },
		[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
		[1411] = { mapID = 1411, name = "Durotar", mapType = 3, parentMapID = 1414 },
		[1413] = { mapID = 1413, name = "The Barrens", mapType = 3, parentMapID = 1414 },
		[1454] = { mapID = 1454, name = "Orgrimmar", mapType = 3, parentMapID = 1414 },
		[1420] = { mapID = 1420, name = "Tirisfal Glades", mapType = 3, parentMapID = 1415 },
	}
end

-- World rectangles in the HereBeDragons convention (world x = left - width * x, y = top - height * y; x/y 0-1).
-- Durotar's size is the one HereBeDragons reported on beta 1.60.1.70450; the offsets are made up for the tests.
local function rects()
	return {
		[1411] = { width = 5287.5, height = 3525, left = 1000, top = 2000, instance = 1 },
		[1413] = { width = 10000, height = 15000, left = 6000, top = 5000, instance = 1 },
		[1454] = { width = 1700, height = 1100, left = 1500, top = 2600, instance = 1 },
		[1420] = { width = 4500, height = 3000, left = 3000, top = 1000, instance = 0 },
	}
end

local function vector(x, y)
	return {
		x = x,
		y = y,
		GetXY = function(self)
			return self.x, self.y
		end,
	}
end

local function copyObjectives(list)
	local copy = {}
	for i, objective in ipairs(list or {}) do
		copy[i] = {
			text = objective.text,
			type = objective.type,
			finished = objective.finished,
			numFulfilled = objective.numFulfilled,
			numRequired = objective.numRequired,
		}
	end
	return copy
end

-- A quest log entry: M.quest(787, { objectives = { M.objective("Boar slain", 0, 10) }, complete = false }).
function M.quest(questID, opts)
	opts = opts or {}
	return {
		questID = questID,
		title = opts.title or ("Quest " .. questID),
		level = opts.level or 1,
		objectives = opts.objectives or {},
		complete = opts.complete or false,
		failed = opts.failed or false,
	}
end

function M.header(title, collapsed)
	return { header = true, title = title, collapsed = collapsed or false }
end

function M.objective(text, have, need, kind)
	return {
		text = string.format("%s: %d/%d", text, have, need),
		type = kind or "monster",
		finished = have >= need,
		numFulfilled = have,
		numRequired = need,
	}
end

function M.install(mock)
	local world = {
		level = 1,
		map = 1411,
		x = 43.35,
		y = 68.70,
		inInstance = false,
		onTaxi = false,
		bind = "Test Inn",
		log = {}, -- quest log entries in order: M.header(...) and M.quest(...)
		hideCollapsed = false, -- true: entries under a collapsed header are left out of the walk
		completed = {}, -- what GetAllCompletedQuestIDs returns
		completedListEmpty = false, -- true: the list is still empty (the open probe's "not filled yet")
		flagged = {}, -- [questID] = true: IsQuestFlaggedCompleted also knows these
		spells = {}, -- [spellID] = true (every API), "player", "book" or "legacy" (only that API)
		items = {}, -- [itemID] = count in bags
		maps = maps(),
		rects = rects(),
		classicTaxi = {}, -- { { name = ..., type = "CURRENT" | "REACHABLE" | "DISTANT" | "NONE" }, ... }
		taxiByMap = {}, -- [uiMapID] = { TaxiNodeInfo, ... } for C_TaxiMap.GetAllTaxiNodes
		taxiMapID = nil, -- what GetTaxiMapID returns
		calls = { GetMapInfo = {}, GetAllCompletedQuestIDs = 0, secret = 0 },
	}

	-- Clock ---------------------------------------------------------------------------------------------------------
	local queue, seq = {}, 0
	local function push(at, fn, ticker)
		seq = seq + 1
		queue[#queue + 1] = { at = at, seq = seq, fn = fn, ticker = ticker }
	end
	C_Timer.After = function(delay, fn)
		push(mock.now + math.max(delay or 0, 0), fn)
	end
	C_Timer.NewTicker = function(interval, fn)
		local ticker = { interval = interval, fn = fn }
		function ticker.Cancel(self)
			self.cancelled = true
		end
		push(mock.now + interval, fn, ticker)
		return ticker
	end
	-- Lets `seconds` pass, running every timer that falls due on the way (also ones scheduled meanwhile) in order.
	function world.advance(seconds)
		local target = mock.now + (seconds or 0)
		while true do
			local best
			for i, entry in ipairs(queue) do
				if entry.at <= target then
					local current = best and queue[best]
					if not current or entry.at < current.at or (entry.at == current.at and entry.seq < current.seq) then
						best = i
					end
				end
			end
			if not best then
				break
			end
			local entry = table.remove(queue, best)
			mock.now = math.max(mock.now, entry.at)
			if not (entry.ticker and entry.ticker.cancelled) then
				entry.fn()
				if entry.ticker and not entry.ticker.cancelled then
					push(entry.at + entry.ticker.interval, entry.fn, entry.ticker)
				end
			end
		end
		mock.now = target
	end
	function world.pending()
		return #queue
	end

	-- Quest log -----------------------------------------------------------------------------------------------------
	local function visibleEntries()
		local visible, hidden = {}, false
		for _, entry in ipairs(world.log) do
			if entry.header then
				hidden = world.hideCollapsed and entry.collapsed
				visible[#visible + 1] = entry
			elseif not hidden then
				visible[#visible + 1] = entry
			end
		end
		return visible
	end
	local function findQuest(questID)
		for _, entry in ipairs(world.log) do
			if not entry.header and entry.questID == questID then
				return entry
			end
		end
	end
	local function listed(list, value)
		for _, item in ipairs(list) do
			if item == value then
				return true
			end
		end
		return false
	end
	C_QuestLog = {
		GetNumQuestLogEntries = function()
			local entries, quests = visibleEntries(), 0
			for _, entry in ipairs(entries) do
				if not entry.header then
					quests = quests + 1
				end
			end
			return #entries, quests
		end,
		GetInfo = function(index)
			local entry = visibleEntries()[index]
			if not entry then
				return nil
			end
			if entry.header then
				return { title = entry.title, isHeader = true, isCollapsed = entry.collapsed, questID = 0 }
			end
			return { title = entry.title, questID = entry.questID, level = entry.level, isHeader = false }
		end,
		GetQuestObjectives = function(questID)
			local entry = findQuest(questID)
			return entry and copyObjectives(entry.objectives) or {}
		end,
		IsComplete = function(questID)
			local entry = findQuest(questID)
			return entry ~= nil and entry.complete
		end,
		IsFailed = function(questID)
			local entry = findQuest(questID)
			return entry ~= nil and entry.failed
		end,
		IsOnQuest = function(questID)
			return findQuest(questID) ~= nil
		end,
		GetTitleForQuestID = function(questID)
			local entry = findQuest(questID)
			return entry and entry.title
		end,
		IsQuestFlaggedCompleted = function(questID)
			return world.flagged[questID] == true or listed(world.completed, questID)
		end,
		GetAllCompletedQuestIDs = function()
			world.calls.GetAllCompletedQuestIDs = world.calls.GetAllCompletedQuestIDs + 1
			if world.completedListEmpty then
				return {}
			end
			local copy = {}
			for i, questID in ipairs(world.completed) do
				copy[i] = questID
			end
			return copy
		end,
	}

	-- Quest tracking: the watch list ----------------------------------------------------------------------------------
	-- The retail shape by default: C_QuestLog.AddQuestWatch(questID[, watchType]), RemoveQuestWatch(questID),
	-- GetQuestWatchType(questID), GetNumQuestWatches(), GetQuestIDForQuestWatchIndex(i) and C_SuperTrack;
	-- useClassicWatch() swaps in the Classic shape (global functions on quest log numbers: AddQuestWatch(index),
	-- RemoveQuestWatch(index), IsQuestWatched(index), GetNumQuestWatches(), GetQuestIndexForWatch(i)).
	--   world.watch          the tracked quest IDs in order (a test plays the player by editing it)
	--   world.watchLimit     when set, a quest is not tracked beyond that many
	--   world.watchCalls     every call into the watch API, as { "FunctionName", arguments... }
	--   world.watchFails     [function name] = true: that function raises
	--   world.superTracked   the quest C_SuperTrack.SetSuperTrackedQuestID last got
	world.watch, world.watchCalls, world.watchFails = {}, {}, {}
	local function watchCall(name, ...)
		world.watchCalls[#world.watchCalls + 1] = { name, ... }
		if world.watchFails[name] then
			error("the client raised in " .. name)
		end
	end
	local function watchIndex(questID)
		for i, id in ipairs(world.watch) do
			if id == questID then
				return i
			end
		end
	end
	local function track(questID)
		if not findQuest(questID) or watchIndex(questID) or (world.watchLimit and #world.watch >= world.watchLimit) then
			return false
		end
		world.watch[#world.watch + 1] = questID
		return true
	end
	local function untrack(questID)
		local index = watchIndex(questID)
		if index then
			table.remove(world.watch, index)
		end
		return index ~= nil
	end
	local function questAtNumber(number)
		local entry = visibleEntries()[number]
		return entry and not entry.header and entry.questID or nil
	end
	local RETAIL_WATCH = {
		"AddQuestWatch",
		"RemoveQuestWatch",
		"GetQuestWatchType",
		"GetNumQuestWatches",
		"GetQuestIDForQuestWatchIndex",
	}
	function world.useRetailWatch()
		C_QuestLog.AddQuestWatch = function(questID, watchType)
			watchCall("AddQuestWatch", questID, watchType)
			return track(questID)
		end
		C_QuestLog.RemoveQuestWatch = function(questID)
			watchCall("RemoveQuestWatch", questID)
			return untrack(questID)
		end
		C_QuestLog.GetQuestWatchType = function(questID)
			watchCall("GetQuestWatchType", questID)
			if watchIndex(questID) then
				return 1
			end
		end
		C_QuestLog.GetNumQuestWatches = function()
			watchCall("GetNumQuestWatches")
			return #world.watch
		end
		C_QuestLog.GetQuestIDForQuestWatchIndex = function(index)
			watchCall("GetQuestIDForQuestWatchIndex", index)
			return world.watch[index]
		end
		C_SuperTrack = {
			SetSuperTrackedQuestID = function(questID)
				watchCall("SetSuperTrackedQuestID", questID)
				world.superTracked = questID
			end,
		}
	end
	function world.useClassicWatch()
		for _, name in ipairs(RETAIL_WATCH) do
			C_QuestLog[name] = nil
		end
		C_SuperTrack = nil
		AddQuestWatch = function(number)
			watchCall("AddQuestWatch", number)
			local questID = questAtNumber(number)
			return questID ~= nil and track(questID)
		end
		RemoveQuestWatch = function(number)
			watchCall("RemoveQuestWatch", number)
			local questID = questAtNumber(number)
			return questID ~= nil and untrack(questID)
		end
		IsQuestWatched = function(number)
			watchCall("IsQuestWatched", number)
			local questID = questAtNumber(number)
			return questID ~= nil and watchIndex(questID) ~= nil
		end
		GetNumQuestWatches = function()
			watchCall("GetNumQuestWatches")
			return #world.watch
		end
		GetQuestIndexForWatch = function(index)
			watchCall("GetQuestIndexForWatch", index)
			local questID = world.watch[index]
			for number, entry in ipairs(visibleEntries()) do
				if questID and not entry.header and entry.questID == questID then
					return number
				end
			end
		end
	end
	world.useRetailWatch()

	-- Spells and bags -----------------------------------------------------------------------------------------------
	local function knows(spellID, api)
		local value = world.spells[spellID]
		return value == true or value == api
	end
	function IsPlayerSpell(spellID)
		return knows(spellID, "player")
	end
	function IsSpellKnown(spellID)
		return knows(spellID, "legacy")
	end
	C_SpellBook = {
		IsSpellKnown = function(spellID)
			return knows(spellID, "book")
		end,
	}
	C_Item = {
		GetItemCount = function(itemID)
			return world.items[itemID] or 0
		end,
	}
	function UnitLevel()
		return world.level
	end

	-- Never to be called by Context (secret values on Forever).
	function UnitHealth()
		world.calls.secret = world.calls.secret + 1
		return 0
	end
	function UnitPower()
		world.calls.secret = world.calls.secret + 1
		return 0
	end

	-- Position, maps, taxi, bind ------------------------------------------------------------------------------------
	local function worldXY()
		local rect = world.map and world.rects[world.map]
		if world.inInstance or not rect or not world.x or not world.y then
			return nil
		end
		return rect.left - rect.width * world.x / 100, rect.top - rect.height * world.y / 100, rect.instance
	end
	C_Map = {
		GetBestMapForUnit = function(unit)
			if unit == "player" then
				return world.map
			end
		end,
		GetPlayerMapPosition = function(mapID, unit)
			if unit ~= "player" or world.inInstance or mapID ~= world.map or not world.x then
				return nil
			end
			return vector(world.x / 100, world.y / 100)
		end,
		GetMapInfo = function(mapID)
			world.calls.GetMapInfo[mapID] = (world.calls.GetMapInfo[mapID] or 0) + 1
			return world.maps[mapID]
		end,
	}
	function UnitPosition(unit)
		if unit ~= "player" then
			return nil
		end
		local wx, wy, instance = worldXY()
		if not wx then
			return nil
		end
		return wy, wx, 0, instance
	end
	function UnitOnTaxi(unit)
		return unit == "player" and world.onTaxi
	end
	function GetBindLocation()
		return world.bind
	end

	function NumTaxiNodes()
		return #world.classicTaxi
	end
	function TaxiNodeName(index)
		local node = world.classicTaxi[index]
		return node and node.name
	end
	function TaxiNodeGetType(index)
		local node = world.classicTaxi[index]
		return node and node.type
	end
	function GetTaxiMapID()
		return world.taxiMapID
	end
	C_TaxiMap = {
		GetAllTaxiNodes = function(mapID)
			return world.taxiByMap[mapID] or {}
		end,
	}
	Enum = {
		FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 },
		UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3 },
	}

	-- HereBeDragons-2.0, with the library's own formulas.
	local hbd = {}
	function hbd.GetPlayerWorldPosition()
		local y, x, _, instance = UnitPosition("player")
		if not x then
			return nil, nil, instance
		end
		return x, y, instance
	end
	function hbd.GetWorldCoordinatesFromZone(_, x, y, zone)
		local rect = world.rects[zone]
		if not rect or not x or not y then
			return nil, nil, nil
		end
		return rect.left - rect.width * x, rect.top - rect.height * y, rect.instance
	end
	world.hbd = hbd
	LibStub = setmetatable({ libs = { ["HereBeDragons-2.0"] = hbd } }, {
		__call = function(self, major, silent)
			return self:GetLibrary(major, silent)
		end,
	})
	function LibStub.GetLibrary(self, major, silent)
		local lib = self.libs[major]
		if not lib and not silent then
			error("Cannot find a library instance of " .. tostring(major), 2)
		end
		return lib, lib and 1 or nil
	end

	return world
end

function M.uninstall()
	for _, name in ipairs(OWN) do
		_G[name] = nil
	end
end

return M
