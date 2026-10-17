-- /signpost dumpmaps: the client's map tree (uiMapID, name, type, parent, world rectangle, rectangle on the parent map,
-- flight nodes and dungeon entrances where the client exposes them) into SignpostDB.mapDump. tools/import_savedvars.py
-- turns it into the data pack's Maps.lua; the world rectangles let tools/ convert map percent to yards.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local call = Util.Call

local MapDump = {}
ns.MapDump = MapDump

-- Maps described per frame, so a large tree never stalls the client.
local BATCH = 40
-- Enum.UIMapType values. Flight nodes are asked for on continents only: for a zone the client returns its whole
-- continent's nodes again (beta 1.60.1.70450). Dungeon entrances are asked for on both (empty on that build).
local CONTINENT, ZONE = 2, 3

local function xy(point, scale)
	if type(point) ~= "table" then
		return nil, nil
	end
	local x, y = call(point.GetXY, point)
	return Util.Round(x, 3, scale), Util.Round(y, 3, scale)
end

local function worldRect(mapID)
	if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then
		return nil
	end
	local instance, topLeft = call(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
	local _, bottomRight = call(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
	if not (topLeft and bottomRight) then
		return nil
	end
	local x0, y0 = xy(topLeft)
	local x1, y1 = xy(bottomRight)
	return { instance = instance, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

local function taxiNodes(mapID)
	local nodes = call(Util.Resolve("C_TaxiMap.GetTaxiNodesForMap"), mapID)
	if type(nodes) ~= "table" or #nodes == 0 then
		return nil
	end
	local result = {}
	for i, node in ipairs(nodes) do
		local x, y = xy(node.position, 100)
		result[i] = {
			id = node.nodeID,
			name = node.name,
			x = x,
			y = y,
			faction = node.faction,
			atlas = node.atlasName,
			state = node.state,
		}
	end
	return result
end

local function dungeonEntrances(mapID)
	local entrances = call(Util.Resolve("C_EncounterJournal.GetDungeonEntrancesForMap"), mapID)
	if type(entrances) ~= "table" or #entrances == 0 then
		return nil
	end
	local result = {}
	for i, entrance in ipairs(entrances) do
		local x, y = xy(entrance.position, 100)
		result[i] = {
			id = entrance.journalInstanceID,
			name = entrance.name,
			x = x,
			y = y,
			atlas = entrance.atlasName,
		}
	end
	return result
end

local function describe(info)
	local mapID = info.mapID
	local entry = {
		id = mapID,
		name = info.name,
		type = info.mapType,
		parent = info.parentMapID,
		flags = info.flags,
		world = worldRect(mapID),
		size = Util.Pack(call(C_Map.GetMapWorldSize, mapID)),
		group = call(C_Map.GetMapGroupID, mapID),
	}
	if info.parentMapID and info.parentMapID > 0 then
		local minX, maxX, minY, maxY = call(C_Map.GetMapRectOnMap, mapID, info.parentMapID)
		if minX then
			entry.onParent = {
				minX = Util.Round(minX, 5),
				maxX = Util.Round(maxX, 5),
				minY = Util.Round(minY, 5),
				maxY = Util.Round(maxY, 5),
			}
		end
	end
	if info.mapType == CONTINENT then
		entry.taxi = taxiNodes(mapID)
	end
	if info.mapType == CONTINENT or info.mapType == ZONE then
		entry.dungeons = dungeonEntrances(mapID)
	end
	return entry
end

-- Every map under the root(s): the top of the player's own map chain plus the conventional roots 946/947 (Cosmic and
-- Azeroth on Mainline; their meaning on Forever is part of what this dump finds out).
local function collect(chain)
	local roots = { 946, 947 }
	if #chain > 0 then
		table.insert(roots, 1, chain[#chain].id)
	end
	local queue, seen = {}, {}
	local function add(info)
		if info and info.mapID and not seen[info.mapID] then
			seen[info.mapID] = true
			queue[#queue + 1] = info
		end
	end
	for _, root in ipairs(roots) do
		add(call(C_Map.GetMapInfo, root))
		for _, child in ipairs(call(C_Map.GetMapChildrenInfo, root, nil, true) or {}) do
			add(child)
		end
	end
	return queue, roots
end

function MapDump:Run()
	if self.running then
		Util.Print(L["dumpmaps is already running."])
		return
	end
	local chain = Util.MapChain(call(C_Map.GetBestMapForUnit, "player"))
	local queue, roots = collect(chain)
	local _, build = GetBuildInfo()
	local dump = { time = time(), build = build, roots = roots, playerChain = chain, maps = {} }
	self.running = true
	Util.Print(L["dumpmaps: describing %d maps..."], #queue)

	local index = 1
	local runStep
	local function step()
		local last = math.min(index + BATCH - 1, #queue)
		for i = index, last do
			local ok, entry = pcall(describe, queue[i])
			dump.maps[#dump.maps + 1] = ok and Util.Sanitize(entry) or { id = queue[i].mapID, error = tostring(entry) }
		end
		index = last + 1
		if index <= #queue then
			C_Timer.After(0, runStep)
			return
		end
		table.sort(dump.maps, function(a, b)
			return (a.id or 0) < (b.id or 0)
		end)
		ns.db.mapDump = dump
		MapDump.running = false
		Util.Print(L["dumpmaps: saved %d maps to SignpostDB.mapDump. Type /reload to write it to disk."], #dump.maps)
	end
	-- A batch that errors is reported by SafeCall; clearing the flag lets the command be retried.
	function runStep()
		if not ns.SafeCall(step) then
			MapDump.running = false
		end
	end
	runStep()
end

ns.Slash:Register("dumpmaps", function()
	MapDump:Run()
end, L["save the client's map tree to SignpostDB.mapDump"])
