-- Learn: records where things are as the player plays (PLAN §6 step 7) into SignpostDB.learned:
--   npcs[npcID], objects[objectID] = { n = name, map, x, y, t, c }   at quest dialogs, gossip, trainers, vendors and
--                                         flight masters (the player's position stands for theirs: it is within
--                                         interaction range)
--   quests[questID] = { start = { npc | obj = id }, finish = { npc | obj = id }, t }   at accept and turn-in
--   taxi[nodeName] = { map, x, y, npc, id, faction, t, c }   the node whose flight master opened the taxi map
--   crossings = { { from = { map, x, y }, to = { map, x, y }, t, c }, ... }   zone borders walked across
--   trainers[npcID] = { spells = { spellIDs }, skill = skillLineID, t }   vendors[npcID] = { items = { itemIDs }, t }
-- x/y are percent of the map with two decimals, t is time() when last seen, c how often it was seen (a crossing each
-- time it is walked; NPCs, objects and flight nodes once per visit, visits being a minute or more apart).
-- Only IDs, the names of NPCs, objects and flight nodes, numbers and coordinates: no quest or gossip text, nothing
-- about items beyond the IDs a vendor sells, and never a player or a pet (whose name a player chose). Always on and
-- cheap: work happens at NPC windows and zone changes, plus one position sample a second for the crossings. Every
-- table is capped (Learn.LIMITS); a new entry in a full table replaces the one seen longest ago.
-- tools/import_savedvars.py --merge-learned turns all of it into the data pack's learned layer.
-- What trainers teach and charge, and the recipes of the trade skill windows: Core/LearnProfessions.lua.
-- Travel (the "Boat and zeppelin rides" and "Innkeepers" sections below): also recorded, on the same terms,
--   rides = { { from = { map, x, y }, to = { map, x, y }, side, kind?, fromArea?, toArea?, secs, t, c }, ... }
--                                         the dock a boat or zeppelin left and the one it arrived at; side: the rider's
--                                         faction; kind: what /signpost ride named; the areas: the game's zone texts
--   inns[npcID] = { map, x, y, n?, t, c }   innkeepers (their gossip offers to make the inn the player's home); n: the
--                                         bind location's name once the player did make it their home there
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local call = Util.Call

local Learn = { counts = setmetatable({}, { __mode = "k" }) }
ns.Learn = Learn

Learn.LIMITS = {
	npcs = 4000,
	objects = 1000,
	quests = 4000,
	taxi = 300,
	crossings = 500,
	trainers = 200,
	vendors = 400,
	spellsPerTrainer = 200,
	itemsPerVendor = 100,
}

local TABLES = { "npcs", "objects", "quests", "taxi", "crossings", "trainers", "vendors" }

ns.SavedVars:RegisterDefaults("account", "learned", {
	npcs = {},
	objects = {},
	quests = {},
	taxi = {},
	crossings = {},
	trainers = {},
	vendors = {},
})

local SAMPLE_SECONDS = 1 -- position samples for the crossings
local VISIT_SECONDS = 60 -- sightings closer together than this are one visit
local SAME_SPOT = 1 -- map percent: sightings this close are one spot (about 50 yd in a zone, 15 in a city)
local MAX_WEIGHT = 9 -- a new visit moves an averaged position at least a tenth of the way towards it
local PENDING_SECONDS = 300 -- how long a quest dialog's NPC is kept for the accept or turn-in that follows
local PENDING_MAX = 20
local MAX_SCAN = 500 -- trainer services and merchant items read per window
local CROSSING_MAX_AGE = 5 -- seconds: the last position in the old zone must be this recent
local MAX_GROUND_SPEED = 16 -- yards a second; more is a flight, a transport, a teleport or a loading screen
local CARRIED_SLACK = 10 -- yards moved beyond the player's own speed that mean a boat or zeppelin carried them
local CONTINENT = 2 -- Enum.UIMapType: 0 cosmic, 1 world, 2 continent; crossings are between maps below that
local FLIGHT_PATH_CURRENT = 0 -- Enum.FlightPathState.Current, for a client without the enum

-- Values ------------------------------------------------------------------------------------------------------------

local function plainNumber(value)
	if type(value) == "number" and not Util.IsSecret(value) then
		return value
	end
end

local function plainID(value)
	value = plainNumber(value)
	if value and value > 0 and value == math.floor(value) then
		return value
	end
end

local function plainString(value)
	if type(value) == "string" and not Util.IsSecret(value) and value ~= "" then
		return value
	end
end

local function scanCount(value)
	value = plainNumber(value)
	return value and math.max(0, math.min(math.floor(value), MAX_SCAN)) or 0
end

local function seenAt(record)
	return type(record) == "table" and tonumber(record.t) or 0
end

-- Stored ID lists stay sorted and hold at most `cap` IDs; the ones already stored keep their place.
local function mergeIDs(stored, ids, cap)
	local seen, result = {}, {}
	local function add(list)
		for _, id in ipairs(list) do
			if plainID(id) and not seen[id] and #result < cap then
				seen[id] = true
				result[#result + 1] = id
			end
		end
	end
	add(type(stored) == "table" and stored or {})
	add(ids)
	table.sort(result)
	return result
end

-- Tables ------------------------------------------------------------------------------------------------------------

function Learn:Table(name)
	local db = ns.db
	if type(db.learned) ~= "table" then
		db.learned = {}
	end
	local tbl = db.learned[name]
	if type(tbl) ~= "table" then
		tbl = {}
		db.learned[name] = tbl
	end
	return tbl
end

function Learn:Count(name)
	local tbl = self:Table(name)
	if name == "crossings" then
		return #tbl
	end
	local n = self.counts[tbl]
	if not n then
		n = 0
		for _ in pairs(tbl) do
			n = n + 1
		end
		self.counts[tbl] = n
	end
	return n
end

function Learn:Counts()
	local counts = {}
	for _, name in ipairs(TABLES) do
		counts[name] = self:Count(name)
	end
	return counts
end

-- A learned record (an NPC or object by ID, a flight node by name), or nil. For reading only.
function Learn:Get(name, key)
	local learned = ns.db and ns.db.learned
	local tbl = type(learned) == "table" and learned[name]
	local record = type(tbl) == "table" and tbl[key]
	return type(record) == "table" and record or nil
end

local function dropOldest(tbl)
	local oldestKey, oldestTime
	for key, record in pairs(tbl) do
		local t = seenAt(record)
		if oldestTime == nil or t < oldestTime then
			oldestKey, oldestTime = key, t
		end
	end
	if oldestKey ~= nil then
		tbl[oldestKey] = nil
		return true
	end
end

-- The record at tbl[key] for writing: the stored one, or a new one (in a full table after dropping the record seen
-- longest ago).
function Learn:Record(name, key)
	local tbl = self:Table(name)
	local record = tbl[key]
	if type(record) == "table" then
		return record
	end
	if record == nil then
		local n = self:Count(name)
		if n >= self.LIMITS[name] and dropOldest(tbl) then
			n = n - 1
		end
		self.counts[tbl] = n + 1
	end
	record = {}
	tbl[key] = record
	return record
end

-- Positions ---------------------------------------------------------------------------------------------------------

local function here()
	local pos = Util.PlayerPosition()
	if plainID(pos.map) and pos.x and pos.y then
		return pos
	end
end

-- Map-percent distance between two points on the same map, else nil.
local function apart(a, b)
	if a.map ~= b.map or type(a.x) ~= "number" or type(a.y) ~= "number" then
		return nil
	end
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

local function blend(point, pos, weight)
	point.x = Util.Round((point.x * weight + pos.x) / (weight + 1), 2)
	point.y = Util.Round((point.y * weight + pos.y) / (weight + 1), 2)
end

-- A sighting at pos: the same spot again refines the averaged position (once per visit); another spot replaces it.
local function place(record, pos, now)
	local distance = apart(record, pos)
	if distance and distance <= SAME_SPOT then
		if now - seenAt(record) >= VISIT_SECONDS then
			local seen = tonumber(record.c) or 1
			blend(record, pos, math.min(seen, MAX_WEIGHT))
			record.c = seen + 1
		end
	else
		record.map, record.x, record.y, record.c = pos.map, pos.x, pos.y, 1
	end
	record.t = now
end

-- NPCs and objects --------------------------------------------------------------------------------------------------

-- GUID kinds that name a world entity. Players and pets are never recorded, so their names are never read.
local ENTITY_TABLES = { Creature = "npcs", Vehicle = "npcs", GameObject = "objects" }
local LINK_KEYS = { npcs = "npc", objects = "obj" }

local function entity(unit)
	local guid = plainString(call(UnitGUID, unit))
	local tableName = guid and ENTITY_TABLES[guid:match("^(%a+)%-") or ""]
	local id = tableName and plainID(Util.NpcIDFromGUID(guid))
	if not id then
		return nil
	end
	local name = plainString((call(UnitName, unit)))
	if name == UNKNOWNOBJECT then
		name = nil
	end
	return { table = tableName, id = id, name = name }
end

-- Records where the unit is and returns it; nil for anything that is not an NPC or a game object.
local function sight(unit)
	local who = entity(unit)
	local pos = who and here()
	if pos then
		local record = Learn:Record(who.table, who.id)
		record.n = who.name or record.n
		place(record, pos, time())
	end
	return who
end

-- Shared with Core/LearnProfessions.lua, which records the trainer and trade skill windows under the same guards.
Learn.Plain = { number = plainNumber, id = plainID, string = plainString }
Learn.Entity = entity

-- Quests ------------------------------------------------------------------------------------------------------------
-- The dialog says who offers (QUEST_DETAIL) or takes back (QUEST_PROGRESS, QUEST_COMPLETE) a quest; the dialog may be
-- gone, or showing the next quest of a chain, by the time QUEST_ACCEPTED or QUEST_TURNED_IN arrives, so each quest's
-- NPC is kept by quest ID until then.

local pendingStart, pendingFinish = {}, {}

local function remember(pending, who)
	local questID = plainID(call(GetQuestID))
	if not (who and questID) then
		return
	end
	local now, kept = GetTime(), 0
	for id, entry in pairs(pending) do
		if now - entry.at > PENDING_SECONDS then
			pending[id] = nil
		else
			kept = kept + 1
		end
	end
	if kept >= PENDING_MAX then
		wipe(pending)
	end
	pending[questID] = { kind = LINK_KEYS[who.table], id = who.id, at = now }
end

local function link(pending, questID, part)
	questID = plainID(questID)
	local entry = questID and pending[questID]
	if not entry then
		return
	end
	pending[questID] = nil
	if GetTime() - entry.at <= PENDING_SECONDS then
		local record = Learn:Record("quests", questID)
		record[part] = { [entry.kind] = entry.id }
		record.t = time()
	end
end

-- QUEST_ACCEPTED passes (questID) on the Mainline API and (logIndex, questID) on older clients.
local function lastArgument(...)
	local n = select("#", ...)
	if n > 0 then
		return (select(n, ...))
	end
end

-- Trainers ----------------------------------------------------------------------------------------------------------

local function serviceSpells()
	local spells = {}
	local getService = Util.Resolve("C_TooltipInfo.GetTrainerService")
	if not getService then
		return spells
	end
	local spellType = Util.Resolve("Enum.TooltipDataType.Spell")
	for i = 1, scanCount(call(GetNumTrainerServices)) do
		-- VERIFY(beta): a trainer service's tooltip data carries the spell it teaches (type Spell, id = spell ID).
		local data = call(getService, i)
		local id = type(data) == "table"
			and (spellType == nil or data.type == nil or data.type == spellType)
			and plainID(data.id)
		if id then
			spells[#spells + 1] = id
		end
	end
	return spells
end

-- A profession trainer names its profession per service; the client's own profession list turns that name into the
-- skill line ID, so no profession is named here (the profession seam).
local skillLineByName

local function professionSkillLine()
	if not call(IsTradeskillTrainer) then
		return nil
	end
	if not skillLineByName or next(skillLineByName) == nil then
		skillLineByName = {}
		for _, entry in pairs(Util.Professions().byEnum or {}) do
			local name = type(entry.info) == "table" and plainString(entry.info.professionName)
			if name and plainID(entry.skillLine) then
				skillLineByName[name] = entry.skillLine
			end
		end
	end
	for i = 1, scanCount(call(GetNumTrainerServices)) do
		-- VERIFY(beta): GetTrainerServiceSkillLine(i) spells the profession as GetProfessionInfoBySkillLineID does.
		local skill = skillLineByName[plainString((call(GetTrainerServiceSkillLine, i))) or ""]
		if skill then
			return skill
		end
	end
end

local function onTrainer(event)
	local who = event == "TRAINER_SHOW" and sight("npc") or entity("npc")
	if not (who and who.table == "npcs") then
		return
	end
	local spells, skill = serviceSpells(), professionSkillLine()
	if #spells == 0 and not skill then
		return
	end
	local record = Learn:Record("trainers", who.id)
	record.spells = mergeIDs(record.spells, spells, Learn.LIMITS.spellsPerTrainer)
	record.skill = skill or record.skill
	record.t = time()
end

-- Vendors -----------------------------------------------------------------------------------------------------------

local function merchantItems()
	local items = {}
	for i = 1, scanCount(call(GetMerchantNumItems)) do
		local id = plainID(call(GetMerchantItemID, i))
		if not id then
			local itemLink = plainString(call(GetMerchantItemLink, i))
			id = itemLink and plainID(tonumber(itemLink:match("item:(%d+)")))
		end
		if id then
			items[#items + 1] = id
		end
	end
	return items
end

local function onMerchant(event)
	local who = event == "MERCHANT_SHOW" and sight("npc") or entity("npc")
	if not (who and who.table == "npcs") then
		return
	end
	local items = merchantItems()
	if #items == 0 then
		return
	end
	local record = Learn:Record("vendors", who.id)
	record.items = mergeIDs(record.items, items, Learn.LIMITS.itemsPerVendor)
	record.t = time()
end

-- Flight masters ----------------------------------------------------------------------------------------------------

-- The node the taxi map was opened at: its name, plus node ID and faction where the flight map API reports them.
-- VERIFY(beta): which of the two taxi APIs marks the current node at a flight master (open probe "Taxi UI").
local function currentTaxiNode(mapID)
	local current = Util.Resolve("Enum.FlightPathState.Current") or FLIGHT_PATH_CURRENT
	local byName, found = {}, nil
	local nodes = call(Util.Resolve("C_TaxiMap.GetAllTaxiNodes"), mapID)
	for _, node in ipairs(type(nodes) == "table" and nodes or {}) do
		local name = type(node) == "table" and plainString(node.name)
		if name then
			byName[name] = { name = name, id = plainID(node.nodeID), faction = plainNumber(node.faction) }
			if node.state == current then
				found = byName[name]
			end
		end
	end
	if not found then
		for i = 1, scanCount(call(NumTaxiNodes)) do
			if call(TaxiNodeGetType, i) == "CURRENT" then
				local name = plainString((call(TaxiNodeName, i)))
				found = name and (byName[name] or { name = name })
				break
			end
		end
	end
	return found or nil
end

local function onTaxiMap()
	local who = sight("npc")
	local pos = here()
	local node = pos and currentTaxiNode(pos.map)
	if not node then
		return
	end
	local record = Learn:Record("taxi", node.name)
	place(record, pos, time())
	record.npc = who and who.table == "npcs" and who.id or record.npc
	record.id = node.id or record.id
	record.faction = node.faction or record.faction
end

-- Zone crossings ----------------------------------------------------------------------------------------------------
-- A one-second position cache keeps the last position in the old zone; at ZONE_CHANGED_NEW_AREA it and the first
-- position in the new zone make a crossing, if the border was walked (or ridden or swum) across.

local function openWorld(pos)
	return pos.instanceType == nil or pos.instanceType == "none"
end

local function zoneLike(mapID)
	local info = call(C_Map and C_Map.GetMapInfo, mapID)
	return not (type(info) == "table" and plainNumber(info.mapType) and info.mapType <= CONTINENT)
end

-- World yards (UnitPosition, else HereBeDragons from the map position) and the world instance.
local function worldPoint(pos)
	if plainNumber(pos.wx) and plainNumber(pos.wy) then
		return pos.wx, pos.wy, pos.instance
	end
	local hbd = LibStub and LibStub("HereBeDragons-2.0", true)
	if hbd then
		local x, y, instance = call(hbd.GetWorldCoordinatesFromZone, hbd, pos.x / 100, pos.y / 100, pos.map)
		if plainNumber(x) and plainNumber(y) then
			return x, y, instance
		end
	end
end

-- Walked: the last position in the old zone is recent, in the same world and close enough to have been reached on
-- foot or mount, and the player was neither on a taxi nor carried by a boat or zeppelin.
function Learn:IsWalked(from, to)
	if not (from and to and from.map ~= to.map and from.x and from.y and to.x and to.y) then
		return false
	end
	if from.taxi or to.taxi or not (openWorld(from) and openWorld(to)) then
		return false
	end
	local elapsed = (tonumber(to.t) or 0) - (tonumber(from.t) or 0)
	if elapsed < 0 or elapsed > CROSSING_MAX_AGE then
		return false
	end
	local ax, ay, aWorld = worldPoint(from)
	local bx, by, bWorld = worldPoint(to)
	if not (ax and bx) or aWorld ~= bWorld then
		return false
	end
	local dx, dy = bx - ax, by - ay
	local moved, window = math.sqrt(dx * dx + dy * dy), math.max(elapsed, SAMPLE_SECONDS)
	if moved > MAX_GROUND_SPEED * window then
		return false
	end
	-- VERIFY(beta): GetUnitSpeed is the player's own speed, 0 while standing on a moving boat or zeppelin.
	local speed = plainNumber(call(GetUnitSpeed, "player"))
	if speed and moved > speed * window + CARRIED_SLACK then
		return false
	end
	return zoneLike(from.map) and zoneLike(to.map)
end

-- Adds a crossing, or counts and refines the one already learned at the same two spots.
function Learn:AddCrossing(from, to)
	local list, now = self:Table("crossings"), time()
	for _, crossing in ipairs(list) do
		if type(crossing) == "table" and type(crossing.from) == "table" and type(crossing.to) == "table" then
			local a, b = apart(crossing.from, from), apart(crossing.to, to)
			if a and b and a <= SAME_SPOT and b <= SAME_SPOT then
				local seen = tonumber(crossing.c) or 1
				blend(crossing.from, from, math.min(seen, MAX_WEIGHT))
				blend(crossing.to, to, math.min(seen, MAX_WEIGHT))
				crossing.c, crossing.t = seen + 1, now
				return crossing
			end
		end
	end
	local crossing = {
		from = { map = from.map, x = from.x, y = from.y },
		to = { map = to.map, x = to.x, y = to.y },
		t = now,
		c = 1,
	}
	list[#list + 1] = crossing
	if #list > self.LIMITS.crossings then
		local oldest = 1
		for i = 2, #list do
			if seenAt(list[i]) < seenAt(list[oldest]) then
				oldest = i
			end
		end
		table.remove(list, oldest)
	end
	return crossing
end

function Learn:Forget()
	self.lastSample, self.beforeMapChange = nil, nil
end

-- The position cache: the latest sample, and the last one on the previous map in case a sample already saw the new
-- zone before ZONE_CHANGED_NEW_AREA arrived.
function Learn:Sample()
	if self.loading then
		return
	end
	local pos = here()
	self:TrackTravel(pos)
	if not pos then
		self:Forget()
		return
	end
	local last = self.lastSample
	if last and last.map ~= pos.map then
		self.beforeMapChange = last
	end
	self.lastSample = pos
end

function Learn:OnNewArea()
	if self.loading then
		return
	end
	local now = here()
	if not now then
		self:Forget()
		return
	end
	local from = self.lastSample
	if from and from.map == now.map then
		from = self.beforeMapChange
	end
	if self:IsWalked(from, now) then
		self:AddCrossing(from, now)
	end
	self.lastSample, self.beforeMapChange = now, nil
end

-- Events ------------------------------------------------------------------------------------------------------------

-- Nothing is recorded without the player's yes on a release build (Core/Contribute.lua; dev builds always record).
function Learn:Recording()
	return ns.db ~= nil and ns.Contribute ~= nil and ns.Contribute:Enabled()
end

local function on(event, fn)
	ns.Events:Register(event, function(...)
		if Learn:Recording() then
			fn(...)
		end
	end)
end

on("GOSSIP_SHOW", function()
	sight("npc")
end)
on("QUEST_GREETING", function()
	sight("npc")
end)
on("QUEST_DETAIL", function()
	remember(pendingStart, sight("npc"))
end)
on("QUEST_PROGRESS", function()
	remember(pendingFinish, sight("npc"))
end)
on("QUEST_COMPLETE", function()
	remember(pendingFinish, sight("npc"))
end)
on("QUEST_ACCEPTED", function(_, ...)
	link(pendingStart, lastArgument(...), "start")
end)
on("QUEST_TURNED_IN", function(_, questID)
	link(pendingFinish, questID, "finish")
end)
on("TRAINER_SHOW", onTrainer)
on("TRAINER_UPDATE", onTrainer)
on("MERCHANT_SHOW", onMerchant)
-- VERIFY(beta): MERCHANT_UPDATE registers on Forever (it was not among the probed events); unknown events are skipped.
on("MERCHANT_UPDATE", onMerchant)
on("TAXIMAP_OPENED", onTaxiMap)
on("ZONE_CHANGED_NEW_AREA", function()
	Learn:OnNewArea()
end)
-- Nothing is a crossing across a loading screen.
on("LOADING_SCREEN_ENABLED", function()
	Learn.loading = true
	Learn:Forget()
end)
on("LOADING_SCREEN_DISABLED", function()
	Learn.loading = false
end)
on("PLAYER_ENTERING_WORLD", function()
	Learn.loading = false
	Learn:Forget()
end)

-- Boat and zeppelin rides -------------------------------------------------------------------------------------------
-- How the client reports a player on a boat or zeppelin is an open probe (FOREVER-API-NOTES), so a ride is told by what
-- it does to the one-second position samples and not by a signal: the player is carried (moves faster than their own
-- speed) or has no map position, with no flight, instance or death to explain it. The dock is the last sample on the
-- ground before that and the arrival the first samples on the ground after it. A hearthstone, a teleport, a summon or
-- a flight leaves neither stretch, so none of them is a ride. Stored: two positions, the game's own text for the areas
-- they are in, the player's faction, how long it took and the kind they named with /signpost ride. Nothing else.

Learn.LIMITS.rides = 100
Learn.LIMITS.inns = 200

local RIDE_RUN = 3 -- samples in a row of being carried, or without a position, before it counts as a ride
local RIDE_SETTLED = 2 -- samples in a row on the ground that end a ride
local RIDE_MIN_SECONDS = 15 -- a shorter stretch is a stumble, not a ride
local RIDE_MAX_SECONDS = 900 -- a ride that goes on longer than this was never one
local RIDE_MAX_IDLE = 60 -- samples a ride may go on without telling whether the player is carried
local RIDE_MIN_YARDS = 300 -- the docks are at least this far apart, or in another world
local RIDE_SLACK = 4 -- yards a sample may differ from the player's own speed before something is carrying them
local MAX_CARRIED_SPEED = 60 -- yards a second; more is a teleport
local DOCK_MAX_AGE = 15 -- seconds a ground sample stays the dock when the map position goes missing
local DOCK_SPOT = 2 -- map percent: rides between docks this close are one route
local KIND_SECONDS = 600 -- how long /signpost ride <kind> waits for its ride
local INN_SECONDS = 120 -- how long after an innkeeper's window a changed bind location is that inn's name

-- A plain true from a client call; a secret or a missing answer is false.
local function flag(fn, ...)
	local value = call(fn, ...)
	return not Util.IsSecret(value) and value and true or false
end

-- A flight, an instance, a battleground or death explains a moving or a missing position better than a ride does.
local function rideExplained(pos)
	if pos and (pos.taxi or not openWorld(pos)) then
		return true
	end
	-- VERIFY(beta): IsInInstance() and UnitIsDeadOrGhost("player") answer plain booleans on Forever (never secret).
	return flag(UnitOnTaxi, "player") or flag(IsInInstance) or flag(UnitIsDeadOrGhost, "player")
end

-- Whether the player was carried between two samples: true, false, or nil when it cannot be told (another world, no
-- world coordinates, a jump too big for a ride, no reading of the player's own speed).
local function carriedBetween(a, b)
	local ax, ay, aWorld = worldPoint(a)
	local bx, by, bWorld = worldPoint(b)
	if not (ax and bx) or aWorld ~= bWorld then
		return nil
	end
	local elapsed = math.max((tonumber(b.t) or 0) - (tonumber(a.t) or 0), SAMPLE_SECONDS)
	local dx, dy = bx - ax, by - ay
	local moved = math.sqrt(dx * dx + dy * dy)
	if moved > MAX_CARRIED_SPEED * elapsed then
		return nil
	end
	-- VERIFY(beta): GetUnitSpeed is the player's own speed, 0 while standing on a moving boat or zeppelin, and
	-- UnitPosition keeps following the deck (else the missing map position is what shows a ride).
	local speed = plainNumber(call(GetUnitSpeed, "player"))
	if not speed then
		return nil
	end
	return moved > speed * elapsed + RIDE_SLACK
end

local function farApart(a, b)
	local ax, ay, aWorld = worldPoint(a)
	local bx, by, bWorld = worldPoint(b)
	if ax and bx then
		if aWorld ~= bWorld then
			return true
		end
		local dx, dy = bx - ax, by - ay
		return math.sqrt(dx * dx + dy * dy) >= RIDE_MIN_YARDS
	end
	return a.map ~= b.map
end

-- The game's own text for where a position is: the subzone, else the minimap's, else the zone's.
local function areaOf(pos)
	return plainString(pos.subzone) or plainString(pos.minimapZone) or plainString(pos.zone)
end

-- One more sample of being carried, or of no position: starts a ride at the dock, or goes on with it.
function Learn:RideEvidence(now)
	local ride = self.ride
	if not ride then
		local dock = self.dock
		if not (dock and now - dock.at <= DOCK_MAX_AGE) then
			return
		end
		ride = { dock = dock, run = 0, settled = 0, idle = 0, since = now }
		self.ride = ride
	end
	ride.run, ride.settled, ride.idle, ride.arrival = ride.run + 1, 0, 0, nil
	if ride.run >= RIDE_RUN then
		ride.confirmed = true
	end
end

-- The player is on the ground again; the first such sample is the arrival once enough of them agree.
function Learn:RideSettled(pos, now)
	local ride = self.ride
	ride.run, ride.idle = 0, 0
	ride.settled = ride.settled + 1
	ride.arrival = ride.arrival or { pos = pos, at = now }
	if ride.settled >= RIDE_SETTLED then
		self:FinishRide()
	end
end

function Learn:FinishRide()
	local ride = self.ride
	self.ride, self.dock = nil, ride.arrival
	if not ride.confirmed then
		return
	end
	local from, to = ride.dock.pos, ride.arrival.pos
	local seconds = ride.arrival.at - ride.since
	if seconds >= RIDE_MIN_SECONDS and farApart(from, to) and zoneLike(from.map) and zoneLike(to.map) then
		self:AddRide(from, to, seconds)
	end
end

-- The kind the player named with /signpost ride, once, if they named it recently.
function Learn:TakeRideKind()
	local named = self.rideKind
	self.rideKind = nil
	if named and GetTime() - named.at <= KIND_SECONDS then
		return named.kind
	end
end

-- Adds a ride, or counts and refines the one already learned between the same two docks.
function Learn:AddRide(from, to, seconds)
	local list, now, kind = self:Table("rides"), time(), self:TakeRideKind()
	local secs = Util.Round(seconds)
	for _, ride in ipairs(list) do
		if type(ride) == "table" and type(ride.from) == "table" and type(ride.to) == "table" then
			local a, b = apart(ride.from, from), apart(ride.to, to)
			if a and b and a <= DOCK_SPOT and b <= DOCK_SPOT then
				local seen = tonumber(ride.c) or 1
				blend(ride.from, from, math.min(seen, MAX_WEIGHT))
				blend(ride.to, to, math.min(seen, MAX_WEIGHT))
				ride.secs = Util.Round(((tonumber(ride.secs) or secs) * seen + secs) / (seen + 1))
				ride.kind = kind or ride.kind
				ride.c, ride.t = seen + 1, now
				return ride
			end
		end
	end
	local ride = {
		from = { map = from.map, x = from.x, y = from.y },
		to = { map = to.map, x = to.x, y = to.y },
		side = ns.Player and plainString(ns.Player.faction),
		kind = kind,
		fromArea = areaOf(from),
		toArea = areaOf(to),
		secs = secs,
		t = now,
		c = 1,
	}
	list[#list + 1] = ride
	if #list > self.LIMITS.rides then
		local oldest = 1
		for i = 2, #list do
			if seenAt(list[i]) < seenAt(list[oldest]) then
				oldest = i
			end
		end
		table.remove(list, oldest)
	end
	return ride
end

-- A loading screen outside a ride is a hearthstone, a teleport or an instance: the dock is gone. Inside one it is the
-- zeppelin crossing to another continent: the ride goes on.
function Learn:OnRideLoading()
	self.rideLast = nil
	if not self.ride then
		self.dock = nil
	end
end

-- Called with every position sample; pos is nil when the client gives no map position.
function Learn:TrackTravel(pos)
	if not (ns.db and ns.Contribute and ns.Contribute:Enabled()) then
		self.dock, self.ride, self.rideLast, self.bind, self.innkeeper = nil, nil, nil, nil, nil
		return
	end
	self:TrackBind()
	local now, ride = GetTime(), self.ride
	if rideExplained(pos) or (ride and now - ride.since > RIDE_MAX_SECONDS) then
		self.dock, self.ride, self.rideLast = nil, nil, nil
		return
	end
	if not pos then
		-- No map position and nothing to explain it: a deck, perhaps. It counts beside a dock and inside a ride.
		self.rideLast = nil
		self:RideEvidence(now)
		return
	end
	local carried = self.rideLast and carriedBetween(self.rideLast, pos)
	self.rideLast = pos
	if carried then
		self:RideEvidence(now)
	elseif carried == false then
		if ride then
			self:RideSettled(pos, now)
		else
			self.dock = { pos = pos, at = now }
		end
	elseif ride then
		ride.idle = ride.idle + 1
		if ride.idle > RIDE_MAX_IDLE then
			self.dock, self.ride = nil, nil
		end
	end
end

-- Innkeepers --------------------------------------------------------------------------------------------------------
-- The gossip of an innkeeper offers to make the inn the player's home. That NPC and the player's position at the
-- window are an innkeeper's place (inns[npcID], recorded like npcs); `n` is the bind location's name from the time
-- the player really made it their home there, seen as a change of GetBindLocation() soon after the window.

local BINDER_ICON = "Interface\\GossipFrame\\BinderGossipIcon"

-- The option that makes the inn the player's home: the binder icon (file ID or path), else the words "inn" and "home".
-- VERIFY(beta): the option carries that icon, or text with those words (open probe: the innkeeper's bind option).
local function binderOption(option)
	if type(option) ~= "table" then
		return false
	end
	local icon = option.icon
	if icon ~= nil and not Util.IsSecret(icon) then
		if
			icon == BINDER_ICON
			or (type(icon) == "number" and icon == plainNumber(call(GetFileIDFromPath, BINDER_ICON)))
		then
			return true
		end
	end
	local name = plainString(option.name)
	name = name and name:lower()
	return name ~= nil and name:find(L["inn"], 1, true) ~= nil and name:find(L["home"], 1, true) ~= nil
end

-- GOSSIP_SHOW
function Learn:OnInnkeeper()
	local who = entity("npc")
	if not (who and who.table == "npcs") then
		return
	end
	local gossip = C_GossipInfo
	local options = gossip and call(gossip.GetOptions)
	local binder = false
	for _, option in ipairs(type(options) == "table" and options or {}) do
		if binderOption(option) then
			binder = true
			break
		end
	end
	local pos = binder and here()
	if pos then
		place(self:Record("inns", who.id), pos, time())
		self.innkeeper = { id = who.id, at = GetTime() }
	end
end

-- The bind location's name, when the player made the inn they just talked to their home.
-- VERIFY(beta): GetBindLocation() names the inn's town (or the city) within seconds of making it the home.
function Learn:TrackBind()
	local name = plainString((call(GetBindLocation)))
	if not name then
		return
	end
	local before, inn = self.bind, self.innkeeper
	self.bind = name
	if before and before ~= name and inn and GetTime() - inn.at <= INN_SECONDS then
		local record = self:Get("inns", inn.id)
		if record then
			record.n = name
		end
		self.innkeeper = nil
	end
end

function Learn:TravelCounts()
	return { rides = #self:Table("rides"), inns = self:Count("inns") }
end

on("GOSSIP_SHOW", function()
	Learn:OnInnkeeper()
end)
on("LOADING_SCREEN_ENABLED", function()
	Learn:OnRideLoading()
end)
on("LOADING_SCREEN_DISABLED", function()
	Learn.rideLast = nil
end)
on("PLAYER_ENTERING_WORLD", function()
	Learn.rideLast = nil
end)

ns.Slash:Register("ride", function(args)
	local kind = (args or ""):lower():match("^%s*(%S*)")
	if not (ns.Contribute and ns.Contribute:Enabled()) then
		Util.Print(L["ride: nothing is recorded until you agree in /signpost contribute"])
	elseif kind == "boat" then
		Learn.rideKind = { kind = "boat", at = GetTime() }
		Util.Print(L["ride: the next ride you finish is recorded as a boat"])
	elseif kind == "zeppelin" then
		Learn.rideKind = { kind = "zeppelin", at = GetTime() }
		Util.Print(L["ride: the next ride you finish is recorded as a zeppelin"])
	elseif kind == "clear" then
		Learn.rideKind = nil
		Util.Print(L["ride: forgotten"])
	else
		Util.Print(L["ride: say what you are about to ride: /signpost ride boat or /signpost ride zeppelin"])
	end
end, L["name the boat or zeppelin you are about to ride so that it is recorded as one: boat | zeppelin | clear"])

ns.Events:Register("PLAYER_LOGIN", function()
	if not Learn.ticker then
		Learn.ticker = C_Timer.NewTicker(SAMPLE_SECONDS, function()
			ns.SafeCall(Learn.Sample, Learn)
		end)
	end
end)

ns.Slash:Register("learned", function()
	local travel = Learn:TravelCounts()
	Util.Print(L["learned: %d boat or zeppelin rides, %d innkeepers"], travel.rides, travel.inns)
	local n = Learn:Counts()
	local professions = Learn.Professions and Learn.Professions:Counts() or { services = 0, recipes = 0 }
	Util.Print(
		L["learned: %d NPCs, %d objects, %d quests, %d flight nodes, %d zone crossings, %d trainers, %d vendors, "]
			.. L["%d trainer services, %d recipes"],
		n.npcs,
		n.objects,
		n.quests,
		n.taxi,
		n.crossings,
		n.trainers,
		n.vendors,
		professions.services,
		professions.recipes
	)
end, L["count what Learn has recorded (tools/import_savedvars.py --merge-learned folds it into the data pack)"])
