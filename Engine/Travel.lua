-- Travel: the travel directives (.path, .zone, .fp, .fly, .boat, .zeppelin, .hs, .home), the hand-authored zone
-- crossings of the travel graph, and the transport state machine (PLAN §3.6, GUIDE-FORMAT "Travel directives",
-- ENGINE.md "Engine/Travel.lua").
--
-- ns.Context says where the player is now. This module also remembers what happened recently ("facts": loading
-- screens, position jumps, lost positions, taxi rides, hearthstone casts), from its own events and from position
-- samples taken on every context change, and each stateful directive compares those times with its own state:
--   .path            waypoints count in order within the waypoint radius; reaching a later one counts the earlier ones
--   .fly             waiting (not on a taxi) -> boarded (on a taxi) -> arrived (landed at the node)
--   .boat/.zeppelin  waiting -> boarded (after being at the departure dock) -> arrived (in the destination's zone or
--                    near the arrival dock, having been somewhere else during the step)
--   .home            a hearthstone cast, then the bind location (or a teleport) reached
-- How the client reports a player on a boat, zeppelin or flight is an open probe (FOREVER-API-NOTES), so every
-- boarding signal below is an assumption marked VERIFY(beta). Directive states hold plain data only (ns.Progress may
-- save them).
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Travel = {
	borders = {}, -- hand-authored crossings from Guides/Travel/Borders.lua, in registration order
	borderErrors = {}, -- why RegisterBorders rejected an entry
	facts = {}, -- GetTime() of recent travel events: see Travel:Sample and the event handlers at the end
	taxiSeen = {}, -- client node name -> known, from the flight maps opened this session
	nodeCache = {}, -- uiMapID -> the flight nodes the client reports for that map
	mapTypes = {}, -- uiMapID -> Enum.UIMapType value
}
ns.Travel = Travel

-- Distances in yards, times in seconds.
Travel.WAYPOINT_RADIUS = 15 -- GUIDE-FORMAT; SignpostDB.settings.waypointRadius overrides it (the Phase 3 options)
Travel.DOCK_RADIUS = 50 -- the player is at the departure dock or tower
Travel.ARRIVAL_RADIUS = 200 -- GUIDE-FORMAT: a boat or zeppelin has arrived this close to the arrival dock
Travel.NODE_RADIUS = 200 -- a flight has landed this close to its node
Travel.INN_RADIUS = 300 -- .hs pins the nearest inn this close while the player is in the inn's town
Travel.BOARD_WINDOW = 300 -- a boarding signal counts this long after the player was last at the departure dock
Travel.JUMP_YARDS = 200 -- a position jump: at least this far between two samples...
Travel.JUMP_SPEED = 50 -- ...and faster than this (yards per second); no mount comes close, taxi rides are excluded
Travel.GRACE = 120 -- a flight or hearthstone cast this long before a step's state began still counts for it
Travel.HEARTHSTONE_ITEM = 6948 -- PLAN §3.4, FOREVER-API-NOTES "Hearth"; in the client's item data (probe 1.60.1.70450)

local NEVER = -math.huge

-- Small helpers ---------------------------------------------------------------------------------------------------

local function now(context)
	context = context or ns.Context
	if context and type(context.Now) == "function" then
		local t = context:Now()
		if type(t) == "number" then
			return t
		end
	end
	return GetTime()
end

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Names compared the forgiving way: case, surrounding and repeated spaces, and a leading "The" do not matter.
local function normalize(name)
	if Util.IsSecret(name) or type(name) ~= "string" then
		return nil
	end
	name = trim(name:lower()):gsub("%s+", " ")
	name = name:gsub("^the ", "")
	return name
end

function Travel.SameName(a, b)
	local left = normalize(a)
	return left ~= nil and left ~= "" and left == normalize(b)
end

-- The client names flight nodes with their zone ("Ratchet, The Barrens"); a guide may give the whole name or the part
-- before the comma.
function Travel.NodeNameMatches(guideName, nodeName)
	if Travel.SameName(guideName, nodeName) then
		return true
	end
	local short = type(nodeName) == "string" and nodeName:match("^([^,]+),")
	if short then
		return Travel.SameName(guideName, short)
	end
	return false
end

function Travel:WaypointRadius()
	local settings = ns.db and ns.db.settings
	local radius = type(settings) == "table" and tonumber(settings.waypointRadius)
	if radius and radius > 0 then
		return radius
	end
	return self.WAYPOINT_RADIUS
end

-- A coordinate as the data pack ({ map, x, y }) or a learned record ({ map = , x = , y = }) holds it.
local function point(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local map, x, y = entry.map or entry[1], entry.x or entry[2], entry.y or entry[3]
	if type(map) == "number" and type(x) == "number" and type(y) == "number" then
		return map, x, y
	end
end

-- Maps -------------------------------------------------------------------------------------------------------------

-- Enum.UIMapType (Cosmic 0, World 1, Continent 2, Zone 3, ...), with the Mainline values as fallback.
local function uiMapType(key, fallback)
	local types = Enum and Enum.UIMapType
	local value = type(types) == "table" and types[key]
	return type(value) == "number" and value or fallback
end

local function mapInfo(mapID)
	if type(mapID) == "number" then
		local info = Util.Call(C_Map and C_Map.GetMapInfo, mapID)
		if type(info) == "table" then
			return info
		end
	end
end

local function packMap(mapID)
	local maps = ns.DB and ns.DB.maps
	local entry = type(maps) == "table" and maps[mapID]
	return type(entry) == "table" and entry or nil
end

local function mapName(mapID)
	local info = mapInfo(mapID)
	if info and type(info.name) == "string" then
		return info.name
	end
	local entry = packMap(mapID)
	return entry and type(entry.n) == "string" and entry.n or nil
end

local function mapLabel(mapID)
	return mapName(mapID) or string.format(L["map %s"], tostring(mapID))
end

local function mapType(mapID)
	if type(mapID) ~= "number" then
		return nil
	end
	local cached = Travel.mapTypes[mapID]
	if cached then
		return cached
	end
	local info = mapInfo(mapID)
	local kind = info and info.mapType
	if type(kind) ~= "number" then
		local entry = packMap(mapID)
		kind = entry and entry.t
	end
	if type(kind) == "number" then
		Travel.mapTypes[mapID] = kind
		return kind
	end
end

local function continentOf(mapID)
	local continent = uiMapType("Continent", 2)
	for _, entry in ipairs(Util.MapChain(mapID)) do
		if entry.type == continent then
			return entry.id
		end
	end
end

-- Context access, tolerant of a missing function or an unknown position -------------------------------------------

local function position(context)
	local pos = context and type(context.Position) == "function" and context:Position()
	return type(pos) == "table" and pos or nil
end

-- True when the client gives the player's map position (not in instances; on transports: open probe).
local function located(pos)
	return pos ~= nil and type(pos.map) == "number" and type(pos.x) == "number" and type(pos.y) == "number"
end

local function distance(context, map, x, y)
	if context and type(context.Distance) == "function" then
		local yards = context:Distance(map, x, y)
		if type(yards) == "number" then
			return yards
		end
	end
end

-- Whether mapID is rootMapID or below it in the map tree (ns.Context:InMap with both arguments).
local function inMap(context, mapID, rootMapID)
	if type(mapID) ~= "number" or type(rootMapID) ~= "number" then
		return false
	end
	return context ~= nil and type(context.InMap) == "function" and context:InMap(mapID, rootMapID) and true or false
end

local function onTaxi(context)
	return context ~= nil and type(context.OnTaxi) == "function" and context:OnTaxi() and true or false
end

-- Factions: data pack records carry `side` (a token as UnitFactionGroup returns it, or "both"); client flight nodes a
-- number, matched through the keys of Enum.FlightPathFaction, so no faction is named in this file.
local function sideUsable(side)
	local mine = ns.Player and ns.Player.faction
	return side == nil or side == "both" or mine == nil or side == mine
end

-- VERIFY(beta): Enum.FlightPathFaction exists on Forever with the faction tokens as keys (0 neutral per the probe).
local function factionUsable(faction)
	local factions = Enum and Enum.FlightPathFaction
	if type(faction) ~= "number" or type(factions) ~= "table" then
		return true
	end
	if faction == (factions.Neutral or 0) then
		return true
	end
	local mine = ns.Player and ns.Player.faction
	local value = mine and factions[mine]
	return value == nil or faction == value
end

-- Facts ---------------------------------------------------------------------------------------------------------------

-- Samples the player's position into the facts: taxi rides (taxiAt while on one, landedAt when it ends), lost
-- positions (unavailableAt) and position jumps (jumpAt: another instance, or farther and faster than any mount
-- between two samples; never on a taxi). Runs on every context change and before every stateful directive decides.
-- Returns the position (or nil).
function Travel:Sample(context)
	context = context or ns.Context
	if not context then
		return nil
	end
	local t = now(context)
	local pos = position(context)
	local facts = self.facts
	local taxi = onTaxi(context)
	if taxi then
		facts.taxiAt = t
		self.onTaxi = true
	elseif self.onTaxi then
		facts.landedAt = t
		self.onTaxi = false
	end
	if not located(pos) then
		facts.unavailableAt = t
		return pos
	end
	local last = self.last
	if last and t > last.t and not taxi and not last.taxi then
		if last.instance ~= nil and pos.instance ~= nil and last.instance ~= pos.instance then
			facts.jumpAt = t
		else
			local yards = distance(context, last.map, last.x, last.y)
			if yards and yards >= self.JUMP_YARDS and yards / math.max(t - last.t, 1) >= self.JUMP_SPEED then
				facts.jumpAt = t
			end
		end
	end
	if not last or t > last.t or last.map ~= pos.map or last.x ~= pos.x or last.y ~= pos.y then
		self.last = { map = pos.map, x = pos.x, y = pos.y, instance = pos.instance, taxi = taxi, t = t }
	end
	return pos
end

-- The Hearthstone's spell comes from the item (6948 is in the client's item data: probe 1.60.1.70450), so no spell ID
-- is written down here. Without C_Item.GetItemSpell the spell is matched by the item's name.
-- VERIFY(beta): C_Item.GetItemSpell(6948) returns the Hearthstone's spell name and ID on Forever (the probe did not
-- check it), the spell is named like the item, and UNIT_SPELLCAST_SUCCEEDED("player", castGUID, spellID) fires when
-- the cast completes.
function Travel.IsHearthSpell(spellID)
	if Util.IsSecret(spellID) or type(spellID) ~= "number" then
		return false
	end
	if Travel.hearthSpellID then
		return spellID == Travel.hearthSpellID
	end
	-- Item data may not be loaded yet, so only an answer is remembered.
	local name, id = Util.Call(C_Item and C_Item.GetItemSpell, Travel.HEARTHSTONE_ITEM)
	if type(id) == "number" then
		Travel.hearthSpellID = id
		return id == spellID
	end
	if type(name) ~= "string" then
		name = Util.Call(C_Item and C_Item.GetItemInfo, Travel.HEARTHSTONE_ITEM)
	end
	if type(name) ~= "string" or Util.IsSecret(name) then
		return false
	end
	local info = Util.Call(C_Spell and C_Spell.GetSpellInfo, spellID)
	return type(info) == "table" and info.name == name
end

-- The player is at the bind location when a zone text or the map's name is GetBindLocation()'s name.
-- VERIFY(beta): GetBindLocation() names the inn's subzone (or city) the way GetSubZoneText/GetZoneText do.
local function atBindLocation(context)
	local bind = context and type(context.BindLocation) == "function" and context:BindLocation()
	local name = normalize(bind)
	if not name or name == "" then
		return false
	end
	if
		Travel.SameName(Util.Call(GetSubZoneText), bind)
		or Travel.SameName(Util.Call(GetZoneText), bind)
		or Travel.SameName(Util.Call(GetMinimapZoneText), bind)
		or Travel.SameName(Util.Call(GetRealZoneText), bind)
	then
		return true
	end
	local pos = position(context)
	return pos ~= nil and Travel.SameName(mapName(pos.map), bind)
end

local function hereIs(name)
	return Travel.SameName(Util.Call(GetSubZoneText), name)
		or Travel.SameName(Util.Call(GetZoneText), name)
		or Travel.SameName(Util.Call(GetMinimapZoneText), name)
end

-- Flight nodes --------------------------------------------------------------------------------------------------------

local function nodeXY(info)
	local where = info.position
	if type(where) ~= "table" then
		return nil
	end
	local x, y = where.x, where.y
	if (type(x) ~= "number" or type(y) ~= "number") and type(where.GetXY) == "function" then
		x, y = Util.Call(where.GetXY, where)
	end
	if type(x) == "number" and type(y) == "number" then
		return x, y
	end
end

local function stale(name)
	return name:find("^zz") ~= nil -- "zzOLD..." test nodes the client still lists
end

-- The flight nodes the client reports for a map, positions projected into that map in percent (verified on beta
-- 1.60.1.70450: every node of the map's continent, without visiting a flight master). Cached per map.
function Travel:ClientNodes(mapID)
	if type(mapID) ~= "number" then
		return {}
	end
	if self.nodeCache[mapID] then
		return self.nodeCache[mapID]
	end
	local list = Util.Call(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap, mapID)
	local nodes = {}
	for _, info in ipairs(type(list) == "table" and list or {}) do
		if type(info) == "table" and type(info.name) == "string" and not stale(info.name) then
			local x, y = nodeXY(info)
			if x then
				nodes[#nodes + 1] = {
					name = info.name,
					map = mapID,
					x = x * 100,
					y = y * 100,
					nodeID = info.nodeID,
					faction = info.faction,
					src = "client",
				}
			end
		end
	end
	if #nodes > 0 then
		self.nodeCache[mapID] = nodes
	end
	return nodes
end

local function byMapAndName(a, b)
	if a.map ~= b.map then
		return a.map < b.map
	end
	if a.name ~= b.name then
		return a.name < b.name
	end
	return tostring(a.npc or a.nodeID) < tostring(b.npc or b.nodeID)
end

-- The data pack's flight masters (zone coordinates, src "pack") followed by its per-continent node lists (src "map").
function Travel:PackNodes()
	local db = ns.DB
	if self.packNodes and self.packNodesFor == db then
		return self.packNodes
	end
	local masters, listed = {}, {}
	local travel = type(db) == "table" and type(db.travel) == "table" and db.travel or {}
	for npcID, master in pairs(type(travel.flightMasters) == "table" and travel.flightMasters or {}) do
		local map, x, y = point(type(master) == "table" and master.p)
		if map and type(master.node) == "string" then
			masters[#masters + 1] =
				{ name = master.node, map = map, x = x, y = y, npc = npcID, side = master.side, src = "pack" }
		end
	end
	for mapID, entry in pairs(type(db) == "table" and type(db.maps) == "table" and db.maps or {}) do
		for _, node in ipairs(type(entry) == "table" and type(entry.taxi) == "table" and entry.taxi or {}) do
			local name = type(node) == "table" and node.n
			if type(name) == "string" and not stale(name) and type(node.x) == "number" and type(node.y) == "number" then
				listed[#listed + 1] = {
					name = name,
					map = mapID,
					x = node.x,
					y = node.y,
					nodeID = node.id,
					faction = node.faction,
					src = "map",
				}
			end
		end
	end
	table.sort(masters, byMapAndName)
	table.sort(listed, byMapAndName)
	for _, node in ipairs(listed) do
		masters[#masters + 1] = node
	end
	self.packNodes, self.packNodesFor = masters, db
	return masters
end

-- Where the player stood at each flight master (Core/Learn.lua: SignpostDB.learned.taxi[nodeName]).
function Travel:LearnedNodes()
	local learned = ns.db and ns.db.learned and ns.db.learned.taxi
	local nodes = {}
	for name, entry in pairs(type(learned) == "table" and learned or {}) do
		local map, x, y = point(entry)
		if type(name) == "string" and map then
			nodes[#nodes + 1] = { name = name, map = map, x = x, y = y, npc = entry.npc, src = "learned" }
		end
	end
	table.sort(nodes, byMapAndName)
	return nodes
end

local function inside(node)
	return node.x >= 0 and node.x <= 100 and node.y >= 0 and node.y <= 100
end

local function firstMatch(nodes, name, mapID)
	for _, node in ipairs(nodes) do
		if (mapID == nil or node.map == mapID) and Travel.NodeNameMatches(name, node.name) then
			return node
		end
	end
end

local function playerMap(context)
	local pos = position(context or ns.Context)
	return pos and pos.map
end

-- Where a flight node is: learned in game, else the data pack (preferring the hinted map), else the client's list (on
-- the hinted map when the node lies on it, else on the continent). `name` is a guide's node name. Returns
-- { name, map, x, y, src, ... } or nil.
function Travel:FindTaxiNode(name, mapHint, context)
	if type(name) ~= "string" then
		return nil
	end
	local node = firstMatch(self:LearnedNodes(), name)
	if node then
		return node
	end
	local pack = self:PackNodes()
	node = (mapHint and firstMatch(pack, name, mapHint)) or firstMatch(pack, name)
	if node then
		return node
	end
	if mapHint then
		node = firstMatch(self:ClientNodes(mapHint), name)
		if node and inside(node) then
			return node
		end
	end
	local continent = continentOf(mapHint or playerMap(context))
	return continent and firstMatch(self:ClientNodes(continent), name) or nil
end

-- Every client node name a guide's node name matches, besides the name itself.
function Travel:NodeAliases(name, mapHint, context)
	local aliases, seen = {}, { [name] = true }
	local function add(nodeName)
		if not seen[nodeName] and Travel.NodeNameMatches(name, nodeName) then
			seen[nodeName] = true
			aliases[#aliases + 1] = nodeName
		end
	end
	for nodeName in pairs(self.taxiSeen) do
		add(nodeName)
	end
	for _, node in ipairs(self:LearnedNodes()) do
		add(node.name)
	end
	for _, node in ipairs(self:PackNodes()) do
		add(node.name)
	end
	local continent = continentOf(mapHint or playerMap(context))
	for _, node in ipairs(continent and self:ClientNodes(continent) or {}) do
		add(node.name)
	end
	table.sort(aliases)
	return aliases
end

-- Whether the player knows a flight node: a flight map opened this session listed it as known, or
-- ns.Context:TaxiNodeKnown says so for the guide's name or any client name it matches.
function Travel:NodeKnown(name, mapHint, context)
	context = context or ns.Context
	for nodeName, known in pairs(self.taxiSeen) do
		if known and Travel.NodeNameMatches(name, nodeName) then
			return true
		end
	end
	if not (context and type(context.TaxiNodeKnown) == "function") then
		return false
	end
	if context:TaxiNodeKnown(name) then
		return true
	end
	for _, alias in ipairs(self:NodeAliases(name, mapHint, context)) do
		if context:TaxiNodeKnown(alias) then
			return true
		end
	end
	return false
end

-- The flight master nearest to the player on the player's map that the player's faction can use.
function Travel:NearestTaxiNode(context)
	context = context or ns.Context
	local pos = position(context)
	if not located(pos) then
		return nil
	end
	local candidates = {}
	for _, node in ipairs(self:LearnedNodes()) do
		if node.map == pos.map then
			candidates[#candidates + 1] = node
		end
	end
	for _, node in ipairs(self:PackNodes()) do
		if node.map == pos.map and node.src == "pack" then
			candidates[#candidates + 1] = node
		end
	end
	for _, node in ipairs(self:ClientNodes(pos.map)) do
		if inside(node) then
			candidates[#candidates + 1] = node
		end
	end
	local best, bestDistance
	for _, node in ipairs(candidates) do
		if sideUsable(node.side) and factionUsable(node.faction) then
			local yards = distance(context, node.map, node.x, node.y)
			if yards and (not bestDistance or yards < bestDistance) then
				best, bestDistance = node, yards
			end
		end
	end
	return best
end

-- The flight map the player just opened, read in both API shapes the client has (which one a flight master uses is
-- an open probe). Returns { { name, known, current, slot?, nodeID? }, ... }, merged by name.
-- VERIFY(beta): TaxiNodeGetType returns "CURRENT"/"REACHABLE"/"NONE" and C_TaxiMap.GetAllTaxiNodes(map).state is an
-- Enum.FlightPathState (Current, Reachable, Unreachable; Unreachable taken as not known) at a Forever flight master.
local function readTaxiMap()
	local nodes, byName = {}, {}
	local function add(name, known, current, key, value)
		if type(name) ~= "string" or name == "" or stale(name) then
			return
		end
		local node = byName[name]
		if not node then
			node = { name = name, known = false, current = false }
			byName[name] = node
			nodes[#nodes + 1] = node
		end
		node.known = node.known or known
		node.current = node.current or current
		if node[key] == nil then
			node[key] = value
		end
	end
	local count = Util.Call(NumTaxiNodes)
	for slot = 1, type(count) == "number" and count or 0 do
		local kind = Util.Call(TaxiNodeGetType, slot)
		add(Util.Call(TaxiNodeName, slot), kind == "CURRENT" or kind == "REACHABLE", kind == "CURRENT", "slot", slot)
	end
	local mapID = Util.Call(C_Map and C_Map.GetBestMapForUnit, "player")
	local list = mapID and Util.Call(C_TaxiMap and C_TaxiMap.GetAllTaxiNodes, mapID)
	local states = Enum and Enum.FlightPathState
	local current = type(states) == "table" and states.Current or 0
	local unreachable = type(states) == "table" and states.Unreachable or 2
	for _, info in ipairs(type(list) == "table" and list or {}) do
		if type(info) == "table" then
			local state = info.state
			add(info.name, state ~= nil and state ~= unreachable, state == current, "nodeID", info.nodeID)
		end
	end
	return nodes
end

-- TAXIMAP_OPENED: remember which nodes are known and hand the list to ns.Context:NoteTaxiNodes.
function Travel:OnTaxiMapOpened()
	local nodes = readTaxiMap()
	if #nodes == 0 then
		return
	end
	for _, node in ipairs(nodes) do
		if node.known then
			self.taxiSeen[node.name] = true
		elseif self.taxiSeen[node.name] == nil then
			self.taxiSeen[node.name] = false
		end
	end
	local context = ns.Context
	if context and type(context.NoteTaxiNodes) == "function" then
		ns.SafeCall(context.NoteTaxiNodes, context, nodes)
	end
	self:Update()
end

-- Inns ----------------------------------------------------------------------------------------------------------------

-- The innkeeper for a .hs step, from the data pack: one in a map named like the inn (a city), or - while the player
-- is in the inn's town - the nearest one. Nil when neither applies (the step's own .goto places the pin then).
function Travel:InnTarget(name, context)
	local inns = ns.DB and ns.DB.travel and ns.DB.travel.inns
	if type(inns) ~= "table" then
		return nil
	end
	local here = hereIs(name)
	local best, bestDistance, bestNamed
	for npcID, inn in pairs(inns) do
		local map, x, y = point(type(inn) == "table" and inn.p)
		if map and sideUsable(inn.side) then
			local named = Travel.SameName(mapName(map), name) or Travel.SameName(inn.n, name)
			local yards = distance(context, map, x, y)
			if named or (here and yards and yards <= self.INN_RADIUS) then
				local far, bestFar = yards or math.huge, bestDistance or math.huge
				if
					not best
					or (named and not bestNamed)
					or (
						named == bestNamed
						and (far < bestFar or (far == bestFar and tostring(npcID) < tostring(best.npc)))
					)
				then
					best, bestDistance, bestNamed = { map = map, x = x, y = y, npc = npcID }, yards, named
				end
			end
		end
	end
	return best
end

-- Parsing -------------------------------------------------------------------------------------------------------------

-- ">> text" belongs to the parser; cut it here too in case an argument string still carries it.
local function argText(argString)
	local text = type(argString) == "string" and argString or ""
	local cut = text:find(">>", 1, true)
	if cut then
		text = text:sub(1, cut - 1)
	end
	return trim(text)
end

local function split(text, separator)
	local parts, start = {}, 1
	while true do
		local at = text:find(separator, start, true)
		if not at then
			parts[#parts + 1] = trim(text:sub(start))
			return parts
		end
		parts[#parts + 1] = trim(text:sub(start, at - 1))
		start = at + #separator
	end
end

local function parseMapID(text)
	local id = tonumber(text)
	if id and id > 0 and id == math.floor(id) then
		return id
	end
end

local function parseCoordinate(text)
	local parts = split(text, ",")
	if #parts ~= 3 then
		return nil, string.format(L["expected <map>,<x>,<y> but got '%s'"], text)
	end
	local map, x, y = parseMapID(parts[1]), tonumber(parts[2]), tonumber(parts[3])
	if not map then
		return nil, string.format(L["'%s' is not a map ID"], parts[1])
	end
	if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
		return nil, string.format(L["x and y must be percent (0-100) in '%s'"], text)
	end
	return { map = map, x = x, y = y }
end

local function parsePath(argString)
	local text = argText(argString)
	if text == "" then
		return nil, L[".path needs waypoints: <map>,<x>,<y> ; <map>,<x>,<y> ; ..."]
	end
	local points = {}
	for _, part in ipairs(split(text, ";")) do
		local waypoint, problem = parseCoordinate(part)
		if not waypoint then
			return nil, problem
		end
		points[#points + 1] = waypoint
	end
	return { points = points }
end

local function parseZone(argString)
	local text = argText(argString)
	local map = parseMapID(text)
	if not map then
		return nil, string.format(L[".zone expects a map ID but got '%s'"], text)
	end
	return { map = map }
end

local function parseFlightPath(argString)
	local text = argText(argString)
	local mapText, name = text:match("^([^,]*),(.*)$")
	local map = mapText and parseMapID(trim(mapText))
	name = name and trim(name)
	if not map or not name or name == "" then
		return nil, string.format(L[".fp expects <map>,<node name> but got '%s'"], text)
	end
	return { map = map, name = name }
end

local function nameParser(directive, what)
	return function(argString)
		local text = argText(argString)
		if text == "" then
			return nil, string.format(L["%s expects %s"], directive, what)
		end
		return { name = text }
	end
end

local function transportParser(kind)
	return function(argString)
		local text = argText(argString)
		local ends = split(text, ">")
		if #ends ~= 2 then
			return nil, string.format(L[".%s expects <map>,<x>,<y> > <map>,<x>,<y> but got '%s'"], kind, text)
		end
		local from, problem = parseCoordinate(ends[1])
		if not from then
			return nil, problem
		end
		local to, toProblem = parseCoordinate(ends[2])
		if not to then
			return nil, toProblem
		end
		return { kind = kind, from = from, to = to }
	end
end

local function parseHome(argString)
	local text = argText(argString)
	if text ~= "" then
		return nil, string.format(L[".home takes no arguments (the game knows the bind location) but got '%s'"], text)
	end
	return {}
end

-- State machines ------------------------------------------------------------------------------------------------------

local function begin(state, context)
	if state.since == nil then
		state.since = now(context)
		state.phase = state.phase or "waiting"
		state.announced = state.announced or state.phase
	end
end

-- .path: state.next is the first waypoint not reached yet (#points + 1 when all are).
local function pathUpdate(args, context, state)
	local points = args.points
	local nextIndex = state.next or 1
	if nextIndex <= #points then
		local radius = Travel:WaypointRadius()
		for index = #points, nextIndex, -1 do
			local waypoint = points[index]
			local yards = distance(context, waypoint.map, waypoint.x, waypoint.y)
			if yards and yards <= radius then
				nextIndex = index + 1
				break
			end
		end
	end
	state.next = nextIndex
end

local function arrivedAt(args, pos, context)
	local to = args.to
	local yards = distance(context, to.map, to.x, to.y)
	if yards and yards <= Travel.ARRIVAL_RADIUS then
		return true
	end
	-- The destination's zone counts, unless the departure dock lies in it too.
	return inMap(context, pos.map, to.map) and not inMap(context, args.from.map, to.map)
end

-- After the player was at the departure dock: a loading screen or position jump (crossing to another continent), the
-- position or UnitPosition going away, another instance, or a map above zone level (open sea).
local function boardingSignal(state, pos, t)
	local docked = state.dockAt
	if not docked or t - docked > Travel.BOARD_WINDOW then
		return false
	end
	local facts = Travel.facts
	if (facts.loadingAt or NEVER) >= docked or (facts.jumpAt or NEVER) > docked then
		return true
	end
	-- VERIFY(beta): the client reports no map position (or no UnitPosition) on board, or another instance.
	if not located(pos) then
		return true
	end
	if state.dockWorld and pos.wx == nil then
		return true
	end
	if state.dockInstance ~= nil and pos.instance ~= nil and pos.instance ~= state.dockInstance then
		return true
	end
	-- VERIFY(beta): over open sea the player's best map is the continent (or the world), not a zone.
	local kind = mapType(pos.map)
	return kind ~= nil and kind <= uiMapType("Continent", 2)
end

-- .boat/.zeppelin: waiting -> boarded -> arrived. Never goes back from boarded: the step still completes on arrival.
local function transportUpdate(args, context, state)
	begin(state, context)
	local pos = Travel:Sample(context)
	if state.phase == "arrived" then
		return
	end
	local t = now(context)
	local here = located(pos) and arrivedAt(args, pos, context)
	if located(pos) and not here then
		state.away = true
	end
	if here and state.away then
		state.phase = "arrived"
		return
	end
	local fromDock = located(pos) and distance(context, args.from.map, args.from.x, args.from.y)
	if fromDock and fromDock <= Travel.DOCK_RADIUS then
		state.dockAt = t
		state.dockInstance = pos.instance
		state.dockWorld = pos.wx ~= nil
		return
	end
	if state.phase == "waiting" and boardingSignal(state, pos, t) then
		state.phase = "boarded"
		state.boardedAt = t
	end
end

-- true when the player landed at the node, false when somewhere else, nil when it cannot tell yet. Without the node's
-- position only `anyLanding` decides.
local function landedAtNode(name, context, anyLanding)
	local node = Travel:FindTaxiNode(name, nil, context)
	if not node then
		return anyLanding == true
	end
	local pos = position(context)
	if not located(pos) then
		return nil
	end
	local yards = distance(context, node.map, node.x, node.y)
	if yards then
		return yards <= Travel.NODE_RADIUS
	end
	return mapType(node.map) == uiMapType("Zone", 3) and inMap(context, pos.map, node.map)
end

-- .fly: waiting -> boarded (on a taxi) -> arrived (landed at the node); landing elsewhere goes back to waiting.
-- A flight seen during this state counts on any landing when the node's position is unknown; one that ended shortly
-- before the state began (the previous step's flight, say) only when the player is at the known node.
-- VERIFY(beta): UnitOnTaxi("player") is true for the whole flight and false once landed.
local function flyUpdate(args, context, state)
	begin(state, context)
	Travel:Sample(context)
	if state.phase == "arrived" then
		return
	end
	if onTaxi(context) then
		state.phase = "boarded"
		state.flew = true
		return
	end
	local landed
	if state.flew then
		landed = landedAtNode(args.name, context, true)
	elseif (Travel.facts.taxiAt or NEVER) >= state.since - Travel.GRACE then
		landed = landedAtNode(args.name, context, false)
	end
	if landed == true then
		state.phase = "arrived"
	elseif landed == false then
		state.phase = "waiting"
		state.flew = nil
	end
end

-- .home: a hearthstone cast since the step's state began (or just before), then the bind location or a teleport.
local function homeUpdate(context, state)
	if state.since == nil then
		state.since = now(context)
	end
	Travel:Sample(context)
	if state.done then
		return
	end
	local facts = Travel.facts
	local cast = facts.hearthAt
	if not cast or cast < state.since - Travel.GRACE then
		return
	end
	if atBindLocation(context) or (facts.jumpAt or NEVER) >= cast or (facts.loadingAt or NEVER) >= cast then
		state.done = true
	end
end

-- Directives ----------------------------------------------------------------------------------------------------------

local directives = {}

directives.path = {
	kind = "travel",
	parse = parsePath,
	onStart = function(args, context, state)
		pathUpdate(args, context, state or {})
	end,
	isSatisfied = function(args, context, state)
		state = state or {}
		pathUpdate(args, context, state)
		return state.next > #args.points
	end,
	-- Every waypoint, for the world map (numbered, with lines); only the next one has minimap = true.
	targets = function(args, context, state)
		state = state or {}
		pathUpdate(args, context, state)
		local count, radius, list = #args.points, Travel:WaypointRadius(), {}
		for index, waypoint in ipairs(args.points) do
			list[index] = {
				map = waypoint.map,
				x = waypoint.x,
				y = waypoint.y,
				kind = "waypoint",
				index = index,
				count = count,
				radius = radius,
				label = string.format(L["Waypoint %d/%d"], index, count),
				reached = index < state.next,
				next = index == state.next,
				minimap = index == state.next,
			}
		end
		return list
	end,
	describe = function(args, _, state)
		local first, last = args.points[1], args.points[#args.points]
		local text = L["Follow the waypoints"]
		if last.map ~= first.map then
			text = string.format(L["Follow the waypoints to %s"], mapLabel(last.map))
		end
		local nextIndex = type(state) == "table" and state.next
		if nextIndex and nextIndex > 1 and nextIndex <= #args.points then
			text = string.format(L["%s (waypoint %d/%d)"], text, nextIndex, #args.points)
		end
		return text
	end,
}

directives.zone = {
	kind = "travel",
	parse = parseZone,
	isSatisfied = function(args, context)
		local pos = position(context)
		return pos ~= nil and inMap(context, pos.map, args.map)
	end,
	targets = function()
		return {}
	end,
	describe = function(args)
		return string.format(L["Enter %s"], mapLabel(args.map))
	end,
}

directives.fp = {
	kind = "travel",
	parse = parseFlightPath,
	isSatisfied = function(args, context)
		return Travel:NodeKnown(args.name, args.map, context)
	end,
	targets = function(args, context)
		local node = Travel:FindTaxiNode(args.name, args.map, context)
		if not node then
			return {}
		end
		local label = string.format(L["%s flight master"], args.name)
		return { { map = node.map, x = node.x, y = node.y, kind = "taxi", npc = node.npc, label = label } }
	end,
	describe = function(args)
		return string.format(L["Get the %s flight path"], args.name)
	end,
}

directives.fly = {
	kind = "travel",
	parse = nameParser(".fly", L["a flight node name"]),
	onStart = function(args, context, state)
		flyUpdate(args, context, state or {})
	end,
	isSatisfied = function(args, context, state)
		state = state or {}
		flyUpdate(args, context, state)
		return state.phase == "arrived"
	end,
	-- The nearest flight master until the player is on the taxi, then the destination.
	targets = function(args, context, state)
		state = state or {}
		flyUpdate(args, context, state)
		local node, label
		if state.phase == "waiting" then
			node, label = Travel:NearestTaxiNode(context), L["Flight master"]
		else
			node, label = Travel:FindTaxiNode(args.name, nil, context), args.name
		end
		if not node then
			return {}
		end
		return { { map = node.map, x = node.x, y = node.y, kind = "taxi", npc = node.npc, label = label } }
	end,
	describe = function(args, _, state)
		if type(state) == "table" and state.phase == "boarded" then
			return string.format(L["Flying to %s..."], args.name)
		end
		return string.format(L["Fly to %s"], args.name)
	end,
}

local TRANSPORT_TEXT = {
	boat = {
		take = L["Take the boat to %s"],
		transit = L["Sailing to %s..."],
		board = L["Board the boat here"],
		arrive = L["The boat arrives here"],
	},
	zeppelin = {
		take = L["Take the zeppelin to %s"],
		transit = L["Riding the zeppelin to %s..."],
		board = L["Board the zeppelin here"],
		arrive = L["The zeppelin arrives here"],
	},
}

local function transport(kind)
	local text = TRANSPORT_TEXT[kind]
	return {
		kind = "travel",
		parse = transportParser(kind),
		onStart = function(args, context, state)
			transportUpdate(args, context, state or {})
		end,
		isSatisfied = function(args, context, state)
			state = state or {}
			transportUpdate(args, context, state)
			return state.phase == "arrived"
		end,
		-- The departure dock until the player is on board, then the arrival dock.
		targets = function(args, context, state)
			state = state or {}
			transportUpdate(args, context, state)
			local dock, label = args.from, text.board
			if state.phase ~= "waiting" then
				dock, label = args.to, text.arrive
			end
			return { { map = dock.map, x = dock.x, y = dock.y, kind = "dock", label = label } }
		end,
		describe = function(args, _, state)
			local where = mapLabel(args.to.map)
			if type(state) == "table" and state.phase == "boarded" then
				return string.format(text.transit, where)
			end
			return string.format(text.take, where)
		end,
	}
end

directives.boat = transport("boat")
directives.zeppelin = transport("zeppelin")

directives.hs = {
	kind = "travel",
	parse = nameParser(".hs", L["an inn name"]),
	isSatisfied = function(args, context)
		return Travel.SameName(context and context.BindLocation and context:BindLocation(), args.name)
	end,
	targets = function(args, context)
		local inn = Travel:InnTarget(args.name, context)
		if not inn then
			return {}
		end
		local label = string.format(L["Innkeeper (%s)"], args.name)
		return { { map = inn.map, x = inn.x, y = inn.y, kind = "inn", npc = inn.npc, label = label } }
	end,
	describe = function(args)
		return string.format(L["Make %s your home"], args.name)
	end,
}

directives.home = {
	kind = "travel",
	parse = parseHome,
	onStart = function(_, context, state)
		homeUpdate(context, state or {})
	end,
	isSatisfied = function(_, context, state)
		state = state or {}
		homeUpdate(context, state)
		return state.done == true
	end,
	targets = function()
		return {}
	end,
	describe = function(_, context)
		local bind = context and context.BindLocation and context:BindLocation()
		if type(bind) == "string" and bind ~= "" then
			return string.format(L["Hearth to %s"], bind)
		end
		return L["Use your hearthstone"]
	end,
}

Travel.directives = directives

-- The stateful directives, brought up to date on every context change; transports also announce TRANSPORT_STATE.
local MACHINES = {
	path = pathUpdate,
	fly = flyUpdate,
	boat = transportUpdate,
	zeppelin = transportUpdate,
	home = function(_, context, state)
		homeUpdate(context, state)
	end,
}
local TRANSPORTS = { fly = true, boat = true, zeppelin = true }

-- Transport state ---------------------------------------------------------------------------------------------------

local function stepById(stepId)
	local progress = ns.Progress
	local guide = progress and type(progress.Guide) == "function" and progress:Guide()
	local byId = type(guide) == "table" and guide.byId
	return type(byId) == "table" and byId[stepId] or nil
end

-- The step's first transport directive (.fly, .boat, .zeppelin) and its state, brought up to date.
local function transportOf(stepId)
	local step = stepById(stepId)
	for index, directive in ipairs(step and step.directives or {}) do
		if TRANSPORTS[directive.name] and type(directive.args) == "table" then
			local progress = ns.Progress
			local states = type(progress.State) == "function" and progress:State(stepId)
			local state = type(states) == "table" and states[index] or nil
			if type(state) == "table" and ns.Context then
				MACHINES[directive.name](directive.args, ns.Context, state)
			end
			return directive, state
		end
	end
end

-- "waiting", "boarded" or "arrived" for a step with a .fly, .boat or .zeppelin directive; nil for any other step.
function Travel:TransportState(stepId)
	local directive, state = transportOf(stepId)
	if not directive then
		return nil
	end
	return type(state) == "table" and state.phase or "waiting"
end

-- The step frame's "in transit" line ("Sailing to Stranglethorn Vale..."), or nil when the player is not on board.
function Travel:TransitText(stepId)
	local directive, state = transportOf(stepId)
	if directive and type(state) == "table" and state.phase == "boarded" then
		return directives[directive.name].describe(directive.args, ns.Context, state)
	end
end

local function announce(state, stepId)
	if state.phase ~= nil and state.phase ~= state.announced then
		state.announced = state.phase
		ns.Events:Fire("TRANSPORT_STATE", stepId, state.phase)
	end
end

function Travel:UpdateStep(step, context)
	local progress = ns.Progress
	local states
	for index, directive in ipairs(step.directives or {}) do
		local update = MACHINES[directive.name]
		if update and type(directive.args) == "table" then
			states = states or progress:State(step.id)
			local state = type(states) == "table" and states[index] or nil
			if type(state) == "table" then
				update(directive.args, context, state)
				if TRANSPORTS[directive.name] then
					announce(state, step.id)
				end
			end
		end
	end
end

-- Samples the position and updates the current step's (and the active sticky steps') travel directives, firing
-- TRANSPORT_STATE(stepId, state) for every transport state change. Runs on CONTEXT_CHANGED, STEP_CHANGED and the
-- travel events below.
function Travel:UpdateNow()
	local context = ns.Context
	if not context then
		return
	end
	self:Sample(context)
	local progress = ns.Progress
	if not progress or type(progress.Current) ~= "function" or type(progress.State) ~= "function" then
		return
	end
	local steps = { (progress:Current()) }
	if type(progress.Sticky) == "function" then
		for _, step in ipairs(progress:Sticky() or {}) do
			steps[#steps + 1] = step
		end
	end
	for _, step in ipairs(steps) do
		if type(step) == "table" and step.id ~= nil then
			self:UpdateStep(step, context)
		end
	end
end

function Travel:Update()
	if self.updating then
		return
	end
	self.updating = true
	ns.SafeCall(self.UpdateNow, self)
	self.updating = false
end

-- Borders -------------------------------------------------------------------------------------------------------------

local function copyPoint(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local map, x, y = entry.map or entry[1], entry.x or entry[2], entry.y or entry[3]
	if type(map) ~= "number" then
		return nil
	end
	if type(x) == "number" and type(y) == "number" then
		return { map, x, y }
	end
	return { map }
end

local function copyBorder(border)
	return {
		name = border.name,
		from = copyPoint(border.from),
		to = copyPoint(border.to),
		side = border.side,
		src = border.src,
		todo = border.todo,
	}
end

-- Hand-authored crossings: { { name = "Durotar/The Barrens", from = { map, x, y }, to = { map, x, y }, side, todo },
-- ... } with from/to the last point in one zone and the first in the other. Until a crossing is learned its points are
-- just { map } and `todo` says why (CLAUDE.md: never invent coordinates). Returns the number of entries kept.
function Travel:RegisterBorders(list)
	local kept = 0
	for index, entry in ipairs(type(list) == "table" and list or {}) do
		local valid = type(entry) == "table" and type(entry.name) == "string" and entry.name ~= ""
		local from, to = valid and copyPoint(entry.from), valid and copyPoint(entry.to)
		if from and to then
			local border = { name = entry.name, from = from, to = to, side = entry.side or "both", src = "guide" }
			if type(entry.todo) == "string" and entry.todo ~= "" then
				border.todo = entry.todo
			elseif not from[2] or not to[2] then
				border.todo = L["crossing coordinates not learned yet"]
			end
			self.borders[#self.borders + 1] = border
			kept = kept + 1
		else
			self.borderErrors[#self.borderErrors + 1] =
				string.format(L["border %d: needs a name and from/to points with a map ID"], index)
		end
	end
	return kept
end

local function pairKey(a, b)
	if a > b then
		a, b = b, a
	end
	return a .. ":" .. b
end

local function connects(border, mapA, mapB)
	local from, to = border.from[1], border.to[1]
	if mapA == nil then
		return true
	end
	if mapB == nil then
		return from == mapA or to == mapA
	end
	return (from == mapA and to == mapB) or (from == mapB and to == mapA)
end

-- The crossings of the travel graph: the hand-authored ones, each replaced by the data pack's crossings for the same
-- pair of zones (learned in game and exported by tools/, PLAN §3.6), plus the pack's crossings for other pairs.
-- With mapA: only crossings touching it; with mapA and mapB: only those between the two. Returns copies.
function Travel:Borders(mapA, mapB)
	local crossings = ns.DB and ns.DB.travel and ns.DB.travel.crossings
	local better, order = {}, {}
	for _, entry in ipairs(type(crossings) == "table" and crossings or {}) do
		local from, to =
			copyPoint(type(entry) == "table" and entry.from), copyPoint(type(entry) == "table" and entry.to)
		if from and to and from[2] and to[2] then
			local key = pairKey(from[1], to[1])
			if not better[key] then
				better[key] = {}
				order[#order + 1] = key
			end
			table.insert(better[key], {
				name = type(entry.name) == "string" and entry.name or nil,
				from = from,
				to = to,
				side = entry.side or "both",
				src = entry.src or "pack",
			})
		end
	end
	local result, used = {}, {}
	local function add(border, fallbackName)
		border.name = border.name or fallbackName or (mapLabel(border.from[1]) .. "/" .. mapLabel(border.to[1]))
		if connects(border, mapA, mapB) then
			result[#result + 1] = border
		end
	end
	for _, border in ipairs(self.borders) do
		local key = pairKey(border.from[1], border.to[1])
		if better[key] then
			if not used[key] then
				used[key] = true
				for _, crossing in ipairs(better[key]) do
					add(copyBorder(crossing), border.name)
				end
			end
		else
			add(copyBorder(border))
		end
	end
	for _, key in ipairs(order) do
		if not used[key] then
			for _, crossing in ipairs(better[key]) do
				add(copyBorder(crossing))
			end
		end
	end
	return result
end

-- Events --------------------------------------------------------------------------------------------------------------

local function update()
	Travel:Update()
end

ns.Events:RegisterMessage("CONTEXT_CHANGED", update)
ns.Events:RegisterMessage("STEP_CHANGED", update)

-- A loading screen that is neither the login nor a /reload: a continent changed (a transport, a portal, a hearth).
ns.Events:Register("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
	if not isInitialLogin and not isReloadingUi then
		Travel.facts.loadingAt = now()
	end
	Travel:Update()
end)

ns.Events:Register("ZONE_CHANGED_NEW_AREA", update)

ns.Events:Register("TAXIMAP_OPENED", function()
	Travel:OnTaxiMapOpened()
end)

ns.Events:Register("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
	if unit == "player" and Travel.IsHearthSpell(spellID) then
		Travel.facts.hearthAt = now()
		Travel:Update()
	end
end)

-- Registration (ns.Directives loads before this file, ENGINE.md "TOC order").
for _, name in ipairs({ "path", "zone", "fp", "fly", "boat", "zeppelin", "hs", "home" }) do
	ns.Directives:Register(name, directives[name])
end
