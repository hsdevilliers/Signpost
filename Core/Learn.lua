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

local function on(event, fn)
	ns.Events:Register(event, function(...)
		if ns.db then
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

ns.Events:Register("PLAYER_LOGIN", function()
	if not Learn.ticker then
		Learn.ticker = C_Timer.NewTicker(SAMPLE_SECONDS, function()
			ns.SafeCall(Learn.Sample, Learn)
		end)
	end
end)

ns.Slash:Register("learned", function()
	local n = Learn:Counts()
	Util.Print(
		L["learned: %d NPCs, %d objects, %d quests, %d flight nodes, %d zone crossings, %d trainers, %d vendors"],
		n.npcs,
		n.objects,
		n.quests,
		n.taxi,
		n.crossings,
		n.trainers,
		n.vendors
	)
end, L["count what Learn has recorded (tools/import_savedvars.py --merge-learned folds it into the data pack)"])
