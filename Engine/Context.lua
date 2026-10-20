-- ns.Context: the player state the step engine asks about, kept in caches that game events refresh, so a query is a
-- table lookup (docs/ENGINE.md "Engine/Context.lua"): the quest log by questID with objectives, completed quests,
-- known spells, profession skills (read from ns.Player.professions), bag counts, level, position and the map tree,
-- the taxi state, the bind location and the flight nodes this character knows.
--
-- CONTEXT_CHANGED(what) fires only when a refresh found a difference, at most once per THROTTLE seconds per `what`.
-- An event marks a cache stale; it is re-read on the next frame (so a burst of QUEST_LOG_UPDATE costs one re-read)
-- or earlier by the first query that needs it. Zone, position, taxi state and bind location are also sampled every
-- TICK seconds: that is the one polled check PLAN §3.3 allows (the .goto distance check), and it covers changes the
-- client sends no event for. A kind whose events this client rejects is re-read every POLL_TICKS ticks instead.
--
-- Additions to the ENGINE.md contract: :QuestLog(), :Map(), :MapInfo(mapID), :Continent(mapID), :ReadTaxiMap(),
-- :Invalidate(what), :Snapshot(), `/signpost context`, and SignpostCharDB.taxiNodes (known flight nodes survive a
-- reload, because the client lists them only while a flight map is open).
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util
local call = Util.Call

local Context = {}
ns.Context = Context

local THROTTLE = 0.2 -- seconds between two CONTEXT_CHANGED of the same kind
local TICK = 0.5 -- seconds between position, zone, taxi and bind samples
local POLL_TICKS = 4 -- ticks between re-reads of a kind that has no working event on this client
local MOVE_YARDS = 1 -- a smaller move does not count as a new position
local MOVE_PERCENT = 0.02 -- the same, in map percent, when the client gives no world position
local MAX_MAP_DEPTH = 16 -- map tree walks stop here, whatever the client returns
local CONTINENT = 2 -- Enum.UIMapType.Continent
local TAXI_RETRY = 0.3 -- seconds before reading an empty flight map once more

local KINDS = { "quests", "spells", "skills", "bags", "level", "zone", "position", "taxi", "bind" }
-- Sampled every tick, in this order: a position sample carries the taxi state just read.
local LIVE = { "zone", "taxi", "position", "bind" }
local IS_LIVE = { zone = true, position = true, taxi = true, bind = true }

Context.questLog = {} -- [questID] = { id, title, level, objectives, complete, failed, ready }
Context.collapsedHeaders = false
Context.completed = {} -- [questID] = true
Context.completedCount = 0
Context.completedSeen = {} -- turned in, or confirmed by IsQuestFlaggedCompleted, this session
Context.completedStale = true
Context.spells = {} -- [spellID] = known, for every spell asked about
Context.items = {} -- [itemID] = count in the bags, for every item asked about
Context.skillSnapshot = {} -- [skillLineID] = "rank/max", to notice skill changes
Context.mapInfo = {} -- [uiMapID] = { id, parent, type, name }, or false when nothing knows the map
Context.taxiFull = {} -- normalized full node name -> stored node name
Context.taxiShort = {} -- normalized name before the comma ("ratchet") -> { stored node names }
Context.taxiSession = {} -- nodes noted before SavedVariables were ready
Context.dirty = {} -- [what] = true: the cache must be re-read before it is used
Context.owed = {} -- [what] = true: a change was found and not signalled yet
Context.lastFired = {} -- [what] = GetTime() of the last CONTEXT_CHANGED
Context.scheduled = {} -- [what] = true while a flush timer is pending
Context.sources = {} -- [what] = number of events and messages that refresh it
Context.missingEvents = {} -- events this client rejected
Context.ticks = 0
for _, what in ipairs(KINDS) do
	Context.dirty[what] = true
end

-- Values from the client ----------------------------------------------------------------------------------------------

-- Secret values (FOREVER-API-NOTES: UnitHealth, UnitPower) error on comparison and arithmetic, so every value read
-- from the client goes through one of these before it is compared. This module never reads health or power.
local function plain(value)
	if type(value) == "number" and not Util.IsSecret(value) and value == value then
		return value
	end
end

local function plainString(value)
	if type(value) == "string" and not Util.IsSecret(value) then
		return value
	end
end

local function flag(value)
	if Util.IsSecret(value) then
		return false
	end
	return value and true or false
end

-- Signals -------------------------------------------------------------------------------------------------------------

local refreshers = {}

-- Re-reads the cache of `what` now; a difference is owed as a CONTEXT_CHANGED. A refresher that fails (say, on a
-- secret table or an API shape a client patch changed) keeps the old cache and records the error, instead of
-- breaking the query or event that asked.
function Context:Refresh(what)
	self.dirty[what] = nil
	local refresh = refreshers[what]
	if not refresh then
		return
	end
	local ok, changed = ns.SafeCall(refresh, self)
	if ok and changed then
		self.owed[what] = true
	end
end

-- Arranges a flush of `what` on a later frame, no sooner than THROTTLE after its last CONTEXT_CHANGED. Never fires
-- synchronously, so a query made inside a CONTEXT_CHANGED handler cannot re-enter the handlers.
function Context:Schedule(what)
	if self.scheduled[what] then
		return
	end
	self.scheduled[what] = true
	local last = self.lastFired[what]
	local delay = last and math.max(0, last + THROTTLE - GetTime()) or 0
	C_Timer.After(delay, function()
		ns.SafeCall(Context.Flush, Context, what)
	end)
end

function Context:Flush(what)
	self.scheduled[what] = nil
	if self.dirty[what] then
		self:Refresh(what)
	end
	if self.owed[what] then
		self.owed[what] = nil
		self.lastFired[what] = GetTime()
		ns.Events:Fire("CONTEXT_CHANGED", what)
	end
end

-- The cache of `what` is stale: it is re-read by the next query or flush, whichever comes first.
function Context:Invalidate(what)
	self.dirty[what] = true
	self:Schedule(what)
end

function Context:InvalidateAll()
	for _, what in ipairs(KINDS) do
		self:Invalidate(what)
	end
end

-- Queries call this first, so they never answer from a stale cache.
function Context:Ensure(what)
	if self.dirty[what] then
		self:Refresh(what)
		if self.owed[what] then
			self:Schedule(what)
		end
	end
end

-- Re-reads `what` now and signals it (throttled) if it changed.
function Context:Poll(what)
	self:Refresh(what)
	if self.owed[what] then
		self:Schedule(what)
	end
end

-- A change found outside a refresh (a learned spell, a flight node).
function Context:Changed(what)
	self.owed[what] = true
	self:Schedule(what)
end

function Context:Now()
	return GetTime()
end

-- Quests --------------------------------------------------------------------------------------------------------------

local function readObjectives(questID)
	local objectives = {}
	local questLog = C_QuestLog or {}
	local list = call(questLog.GetQuestObjectives, questID)
	if type(list) ~= "table" then
		return objectives
	end
	for _, objective in ipairs(list) do
		if type(objective) == "table" then
			objectives[#objectives + 1] = {
				text = plainString(objective.text),
				type = plainString(objective.type),
				finished = flag(objective.finished),
				have = plain(objective.numFulfilled),
				need = plain(objective.numRequired),
			}
		end
	end
	return objectives
end

-- `info` is the quest log entry when the quest was found by walking the log.
local function readQuest(questID, info)
	local questLog = C_QuestLog or {}
	local objectives = readObjectives(questID)
	-- VERIFY(beta): what C_QuestLog.IsComplete returns for a quest without objectives (talk-to and delivery quests);
	-- until then such a quest counts as ready only when IsComplete says so.
	local done = #objectives > 0
	for _, objective in ipairs(objectives) do
		if not objective.finished then
			done = false
			break
		end
	end
	local complete = flag(call(questLog.IsComplete, questID))
	local failed = flag(call(questLog.IsFailed, questID))
	local title = info and plainString(info.title) or plainString(call(questLog.GetTitleForQuestID, questID))
	return {
		id = questID,
		title = title,
		level = info and plain(info.level) or nil,
		objectives = objectives,
		complete = complete,
		failed = failed,
		ready = not failed and (complete or done),
	}
end

local function readQuestLog()
	local log, collapsed = {}, false
	local questLog = C_QuestLog
	if not questLog then
		return log, collapsed
	end
	local count = plain(call(questLog.GetNumQuestLogEntries)) or 0
	for index = 1, count do
		local info = call(questLog.GetInfo, index)
		if type(info) == "table" then
			if info.isHeader then
				collapsed = collapsed or flag(info.isCollapsed)
			else
				local questID = plain(info.questID)
				if questID and questID > 0 then
					log[questID] = readQuest(questID, info)
				end
			end
		end
	end
	return log, collapsed
end

local function sameQuest(a, b)
	if a.ready ~= b.ready or a.complete ~= b.complete or a.failed ~= b.failed then
		return false
	end
	if #a.objectives ~= #b.objectives then
		return false
	end
	for i, objective in ipairs(a.objectives) do
		local other = b.objectives[i]
		if
			objective.finished ~= other.finished
			or objective.have ~= other.have
			or objective.need ~= other.need
			or objective.text ~= other.text
		then
			return false
		end
	end
	return true
end

local function sameLog(old, new)
	for questID, entry in pairs(new) do
		if not old[questID] or not sameQuest(old[questID], entry) then
			return false
		end
	end
	for questID in pairs(old) do
		if not new[questID] then
			return false
		end
	end
	return true
end

-- Replaces the completed set with the client's list plus this session's turn-ins. Returns true if it grew or changed.
function Context:LoadCompleted()
	self.completedStale = false
	local list = call(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
	if type(list) ~= "table" then
		return false
	end
	local set, count = {}, 0
	for _, questID in ipairs(list) do
		questID = plain(questID)
		if questID and not set[questID] then
			set[questID] = true
			count = count + 1
		end
	end
	-- VERIFY(beta): whether the list is filled at PLAYER_ENTERING_WORLD or only after the first QUEST_LOG_UPDATE
	-- (FOREVER-API-NOTES open probe). While it is empty, every QUEST_LOG_UPDATE reads it again.
	self.completedEmpty = count == 0
	for questID in pairs(self.completedSeen) do
		if not set[questID] then
			set[questID] = true
			count = count + 1
		end
	end
	local changed = count ~= self.completedCount
	if not changed then
		for questID in pairs(set) do
			if not self.completed[questID] then
				changed = true
				break
			end
		end
	end
	self.completed, self.completedCount = set, count
	return changed
end

refreshers.quests = function(self)
	local log, collapsed = readQuestLog()
	local changed = not sameLog(self.questLog, log)
	self.questLog, self.collapsedHeaders = log, collapsed
	if self.completedStale and self:LoadCompleted() then
		changed = true
	end
	return changed
end

function Context:QuestTurnedIn(questID)
	questID = plain(questID)
	if questID then
		self.completedSeen[questID] = true
		if not self.completed[questID] then
			self.completed[questID] = true
			self.completedCount = self.completedCount + 1
			self.owed.quests = true
		end
	end
	-- Read the client's list again: a turn-in can flag other quests too.
	self.completedStale = true
	self:Invalidate("quests")
end

-- The cached entry of a quest in the log, or nil.
function Context:QuestEntry(questID)
	questID = plain(questID)
	if not questID then
		return nil
	end
	self:Ensure("quests")
	local entry = self.questLog[questID]
	if entry or not self.collapsedHeaders then
		return entry
	end
	-- VERIFY(beta): does C_QuestLog.GetInfo list the quests under a collapsed quest log header? While a header is
	-- collapsed, a quest the walk did not find is asked about directly.
	if flag(call(C_QuestLog and C_QuestLog.IsOnQuest, questID)) then
		return readQuest(questID)
	end
	return nil
end

function Context:QuestInLog(questID)
	return self:QuestEntry(questID) ~= nil
end

-- In the log with every objective done (or the client says it is complete), and not failed.
function Context:QuestReady(questID)
	local entry = self:QuestEntry(questID)
	return entry ~= nil and entry.ready
end

-- { { text, type, finished, have, need }, ... } for a quest in the log (empty if it has no objectives), else nil.
function Context:Objectives(questID)
	local entry = self:QuestEntry(questID)
	return entry and entry.objectives
end

-- Flagged completed by the client, or turned in this session.
function Context:QuestCompleted(questID)
	questID = plain(questID)
	if not questID then
		return false
	end
	self:Ensure("quests")
	if self.completed[questID] then
		return true
	end
	if flag(call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, questID)) then
		self.completed[questID] = true
		self.completedSeen[questID] = true
		self.completedCount = self.completedCount + 1
		return true
	end
	return false
end

-- Every quest in the log: { [questID] = entry }. Read-only.
function Context:QuestLog()
	self:Ensure("quests")
	return self.questLog
end

-- Spells, skills, bags, level -----------------------------------------------------------------------------------------

-- VERIFY(beta): which of these reports a trained spell rank as known on Forever; any one of them counts.
local function spellKnown(spellID)
	if flag(call(IsPlayerSpell, spellID)) then
		return true
	end
	if flag(call(C_SpellBook and C_SpellBook.IsSpellKnown, spellID)) then
		return true
	end
	return flag(call(IsSpellKnown, spellID))
end

refreshers.spells = function(self)
	local changed = false
	for spellID, known in pairs(self.spells) do
		local now = spellKnown(spellID)
		if now ~= known then
			self.spells[spellID] = now
			changed = true
		end
	end
	return changed
end

function Context:SpellKnown(spellID)
	spellID = plain(spellID)
	if not spellID then
		return false
	end
	self:Ensure("spells")
	local known = self.spells[spellID]
	if known == nil then
		known = spellKnown(spellID)
		self.spells[spellID] = known
	end
	return known
end

local function skillSnapshot()
	local snapshot = {}
	local professions = ns.Player and ns.Player.professions
	if type(professions) == "table" then
		for skillLine, info in pairs(professions) do
			if type(info) == "table" then
				snapshot[skillLine] = tostring(plain(info.rank)) .. "/" .. tostring(plain(info.max))
			end
		end
	end
	return snapshot
end

local function sameStrings(a, b)
	for key, value in pairs(b) do
		if a[key] ~= value then
			return false
		end
	end
	for key in pairs(a) do
		if b[key] == nil then
			return false
		end
	end
	return true
end

refreshers.skills = function(self)
	local snapshot = skillSnapshot()
	local changed = not sameStrings(self.skillSnapshot, snapshot)
	self.skillSnapshot = snapshot
	return changed
end

-- rank, max of a learned skill line (ns.Player.professions), or nil.
function Context:Skill(skillLineID)
	local professions = ns.Player and ns.Player.professions
	local info = type(professions) == "table" and professions[skillLineID]
	if type(info) == "table" then
		return plain(info.rank), plain(info.max)
	end
	return nil
end

local function itemCount(itemID)
	return plain(call(C_Item and C_Item.GetItemCount, itemID)) or 0
end

refreshers.bags = function(self)
	local changed = false
	for itemID, count in pairs(self.items) do
		local now = itemCount(itemID)
		if now ~= count then
			self.items[itemID] = now
			changed = true
		end
	end
	return changed
end

-- How many the bags hold (bank excluded).
function Context:ItemCount(itemID)
	itemID = plain(itemID)
	if not itemID then
		return 0
	end
	self:Ensure("bags")
	local count = self.items[itemID]
	if count == nil then
		count = itemCount(itemID)
		self.items[itemID] = count
	end
	return count
end

refreshers.level = function(self)
	local level = plain(call(UnitLevel, "player"))
	-- PLAYER_LEVEL_UP carries the new level; UnitLevel can still report the old one for a moment.
	local pending = self.pendingLevel
	if pending and (not level or level < pending) then
		level = pending
	else
		self.pendingLevel = nil
	end
	local changed = level ~= self.level
	self.level = level
	return changed
end

function Context:Level()
	self:Ensure("level")
	return self.level
end

-- Position and maps ---------------------------------------------------------------------------------------------------

function Context:HBD()
	if not self.hbd and LibStub then
		self.hbd = call(LibStub.GetLibrary, LibStub, "HereBeDragons-2.0", true)
	end
	return self.hbd
end

-- Map percent from C_Map, world yards and instance from HereBeDragons (UnitPosition when it is missing).
local function samplePosition()
	local mapApi = C_Map or {}
	local mapID = plain(call(mapApi.GetBestMapForUnit, "player"))
	local x, y
	if mapID then
		local point = call(mapApi.GetPlayerMapPosition, mapID, "player")
		if point then
			local px, py = call(point.GetXY, point)
			px, py = plain(px), plain(py)
			if px and py then
				x, y = px * 100, py * 100
			end
		end
	end
	local wx, wy, instance
	local hbd = Context:HBD()
	if hbd then
		wx, wy, instance = call(hbd.GetPlayerWorldPosition, hbd)
	else
		local uy, ux, _, uInstance = call(UnitPosition, "player")
		wx, wy, instance = ux, uy, uInstance
	end
	wx, wy, instance = plain(wx), plain(wy), plain(instance)
	if not wx or not wy then
		wx, wy = nil, nil
	end
	if not mapID and not wx then
		return nil
	end
	-- The taxi state comes from the same cache as :OnTaxi(), so the two never disagree.
	return { map = mapID, x = x, y = y, wx = wx, wy = wy, instance = instance, taxi = Context:OnTaxi() }
end

-- { map, x, y, wx, wy, instance, taxi } (read-only; x/y percent of `map`, wx/wy world yards; any of them may be nil
-- in instances or on transports), or nil when the client knows neither a map nor a world position. One sample per
-- frame.
function Context:Position()
	local now = GetTime()
	if self.positionAt ~= now then
		self.position, self.positionAt = samplePosition(), now
	end
	return self.position
end

-- The player's current uiMapID, or nil.
function Context:Map()
	local position = self:Position()
	return position and position.map
end

local function near(a, b, limit)
	if a == nil or b == nil then
		return a == b
	end
	return math.abs(a - b) < limit
end

local function samePosition(a, b)
	if a == nil or b == nil then
		return a == b
	end
	if a.map ~= b.map or a.instance ~= b.instance or a.taxi ~= b.taxi then
		return false
	end
	if (a.wx == nil) ~= (b.wx == nil) or (a.x == nil) ~= (b.x == nil) then
		return false
	end
	if a.wx then
		return near(a.wx, b.wx, MOVE_YARDS) and near(a.wy, b.wy, MOVE_YARDS)
	end
	return near(a.x, b.x, MOVE_PERCENT) and near(a.y, b.y, MOVE_PERCENT)
end

refreshers.position = function(self)
	local position = samplePosition()
	self.position, self.positionAt = position, GetTime()
	if samePosition(self.lastPosition, position) then
		return false
	end
	self.lastPosition = position
	return true
end

refreshers.zone = function(self)
	local mapID = plain(call(C_Map and C_Map.GetBestMapForUnit, "player"))
	if mapID == self.zoneMap then
		return false
	end
	self.zoneMap = mapID
	self.positionAt = nil
	return true
end

local function mapEntry(mapID, parent, mapType, name)
	return { id = mapID, parent = plain(parent), type = plain(mapType), name = plainString(name) }
end

-- { id, parent, type, name } of a map: from C_Map.GetMapInfo, else the data pack's maps table; cached for the session.
function Context:MapInfo(mapID)
	mapID = plain(mapID)
	if not mapID then
		return nil
	end
	local info = self.mapInfo[mapID]
	if info == nil then
		local raw = call(C_Map and C_Map.GetMapInfo, mapID)
		local pack = ns.DB and ns.DB.maps
		pack = type(pack) == "table" and pack[mapID]
		if type(raw) == "table" then
			info = mapEntry(mapID, raw.parentMapID, raw.mapType, raw.name)
		elseif type(pack) == "table" then
			info = mapEntry(mapID, pack.parent, pack.t, pack.n)
		else
			info = false
		end
		self.mapInfo[mapID] = info
	end
	return info or nil
end

-- True when mapID is rootMapID or lies below it in the map tree (mapID nil: the player's map). Cities are not inside
-- the zone around them: Orgrimmar 1454 is a sibling of Durotar 1411 under Kalimdor (FOREVER-API-NOTES).
function Context:InMap(mapID, rootMapID)
	if mapID == nil then
		mapID = self:Map()
	end
	mapID, rootMapID = plain(mapID), plain(rootMapID)
	if not mapID or not rootMapID then
		return false
	end
	for _ = 1, MAX_MAP_DEPTH do
		if mapID == rootMapID then
			return true
		end
		local info = self:MapInfo(mapID)
		mapID = info and info.parent
		if not mapID or mapID <= 0 then
			return false
		end
	end
	return false
end

-- The continent above (or at) a map (mapID nil: the player's map), or nil.
function Context:Continent(mapID)
	if mapID == nil then
		mapID = self:Map()
	end
	for _ = 1, MAX_MAP_DEPTH do
		local info = self:MapInfo(mapID)
		if not info then
			return nil
		end
		if info.type == CONTINENT then
			return info.id
		end
		mapID = info.parent
	end
	return nil
end

-- Yards from the player to x, y (percent) of a map, or nil: no position, another continent, a map HereBeDragons does
-- not know.
function Context:Distance(mapID, x, y)
	mapID, x, y = plain(mapID), plain(x), plain(y)
	local hbd = self:HBD()
	local position = self:Position()
	if not (mapID and x and y and hbd and position and position.wx) then
		return nil
	end
	local tx, ty, instance = call(hbd.GetWorldCoordinatesFromZone, hbd, x / 100, y / 100, mapID)
	tx, ty, instance = plain(tx), plain(ty), plain(instance)
	if not (tx and ty) or instance ~= position.instance then
		return nil
	end
	local dx, dy = tx - position.wx, ty - position.wy
	return math.sqrt(dx * dx + dy * dy)
end

-- Taxi and bind location ----------------------------------------------------------------------------------------------

refreshers.taxi = function(self)
	-- VERIFY(beta): UnitOnTaxi stays true for the whole flight (FOREVER-API-NOTES open probe).
	local onTaxi = flag(call(UnitOnTaxi, "player"))
	if onTaxi == self.onTaxi then
		return false
	end
	self.onTaxi = onTaxi
	self.positionAt = nil
	return true
end

function Context:OnTaxi()
	self:Ensure("taxi")
	return self.onTaxi == true
end

refreshers.bind = function(self)
	local bind = plainString(call(GetBindLocation))
	if bind == self.bind then
		return false
	end
	self.bind = bind
	return true
end

-- The hearthstone's bind location as GetBindLocation names it, or nil.
function Context:BindLocation()
	self:Ensure("bind")
	return self.bind
end

local function nodeKey(name)
	return (name:lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- Blizzard keeps retired nodes with a "zz" prefix (e.g. "zzOLD..." on beta 1.60.1.70450).
local function retiredNode(name)
	return nodeKey(name):find("^zz") ~= nil
end

-- Nodes are stored under the client's full name ("Ratchet, The Barrens") and found by it or by the part before the
-- comma ("Ratchet"), ignoring case.
function Context:IndexTaxiNode(name)
	local key = nodeKey(name)
	self.taxiFull[key] = name
	local short = key:match("^([^,]+),")
	if short then
		short = short:gsub(" $", "")
		local list = self.taxiShort[short]
		if not list then
			list = {}
			self.taxiShort[short] = list
		end
		list[#list + 1] = name
	end
end

function Context:TaxiStore()
	local char = ns.char
	if type(char) == "table" and type(char.taxiNodes) == "table" then
		return char.taxiNodes
	end
	return self.taxiSession
end

-- Known stays known: a flight path is never unlearned, and a later list that leaves the node out or reports it
-- unknown (another continent's flight map) must not undo it.
local function noteNode(self, store, name, known, nodeID)
	local entry = store[name]
	local changed = false
	if type(entry) ~= "table" then
		entry = {}
		store[name] = entry
		self:IndexTaxiNode(name)
		changed = true
	end
	if known == true and entry.known ~= true then
		entry.known = true
		changed = true
	elseif known == false and entry.known == nil then
		entry.known = false
		changed = true
	end
	if nodeID then
		entry.id = nodeID
	end
	if changed then
		entry.t = time()
	end
	return changed
end

-- SavedVariables are ready: index the stored nodes and keep anything noted before.
function Context:LoadTaxiNodes()
	local store = self:TaxiStore()
	local session = self.taxiSession
	self.taxiFull, self.taxiShort = {}, {}
	for name in pairs(store) do
		if type(name) == "string" then
			self:IndexTaxiNode(name)
		end
	end
	if store ~= session then
		self.taxiSession = {}
		for name, entry in pairs(session) do
			noteNode(self, store, name, entry.known, entry.id)
		end
	end
end

-- nodes = { { name = "Ratchet, The Barrens", known = true | false | nil, id = nodeID }, ... }, as :ReadTaxiMap returns
-- them (Travel's reader names the field nodeID instead; either is stored as id).
-- them. Returns true when something changed (and signals "taxi").
function Context:NoteTaxiNodes(nodes)
	if type(nodes) ~= "table" then
		return false
	end
	local store, changed = self:TaxiStore(), false
	for _, node in ipairs(nodes) do
		local name = type(node) == "table" and plainString(node.name)
		if name and name ~= "" and not retiredNode(name) then
			local known = node.known
			if known ~= true and known ~= false then
				known = nil
			end
			if noteNode(self, store, name, known, plain(node.id ~= nil and node.id or node.nodeID)) then
				changed = true
			end
		end
	end
	if changed then
		self:Changed("taxi")
	end
	return changed
end

-- true: known; false: a flight map listed it as unknown; nil: never seen (or the client gave no state for it).
-- A short name shared by several nodes is known when any of them is.
function Context:TaxiNodeKnown(name)
	name = plainString(name)
	if not name then
		return nil
	end
	local store, key = self:TaxiStore(), nodeKey(name)
	local full = self.taxiFull[key]
	if full and type(store[full]) == "table" then
		return store[full].known
	end
	local result
	for _, stored in ipairs(self.taxiShort[key] or {}) do
		local entry = store[stored]
		if type(entry) == "table" then
			if entry.known then
				return true
			elseif entry.known == false then
				result = false
			end
		end
	end
	return result
end

local function addUnique(list, value)
	if value == nil then
		return
	end
	for _, existing in ipairs(list) do
		if existing == value then
			return
		end
	end
	list[#list + 1] = value
end

-- The open flight map's nodes: { { name, known, current, id, index }, ... }. Forever has both API shapes
-- (FOREVER-API-NOTES); the classic one feeds TaxiFrame, the C_TaxiMap one FlightMapFrame.
-- VERIFY(beta): which one a flight master opens, and what TaxiNodeGetType / the node `state` and `isUndiscovered`
-- fields report for nodes the character does not know (open probe "Taxi UI at a flight master").
function Context:ReadTaxiMap()
	local nodes = {}
	for index = 1, plain(call(NumTaxiNodes)) or 0 do
		local name = plainString(call(TaxiNodeName, index))
		if name then
			local kind = plainString(call(TaxiNodeGetType, index))
			local known
			if kind == "CURRENT" or kind == "REACHABLE" or kind == "DISTANT" then
				known = true
			elseif kind == "NONE" then
				known = false
			end
			nodes[#nodes + 1] = { name = name, known = known, current = kind == "CURRENT", index = index }
		end
	end
	local getAll = C_TaxiMap and C_TaxiMap.GetAllTaxiNodes
	if #nodes > 0 or not getAll then
		return nodes
	end
	local states = Enum and Enum.FlightPathState or {}
	local current, reachable = states.Current or 0, states.Reachable or 1
	local candidates = {}
	addUnique(candidates, plain(call(Util.Resolve("GetTaxiMapID"))))
	local mapID = self:Map()
	addUnique(candidates, self:Continent(mapID))
	addUnique(candidates, mapID)
	for _, candidate in ipairs(candidates) do
		local list = call(getAll, candidate)
		if type(list) == "table" and #list > 0 then
			for _, info in ipairs(list) do
				local name = type(info) == "table" and plainString(info.name)
				if name then
					local state, known = plain(info.state), nil
					if type(info.isUndiscovered) == "boolean" then
						known = not info.isUndiscovered
					elseif state == current or state == reachable then
						known = true
					end
					nodes[#nodes + 1] = {
						name = name,
						known = known,
						current = state == current,
						id = plain(info.nodeID),
						index = plain(info.slotIndex),
					}
				end
			end
			return nodes
		end
	end
	return nodes
end

function Context:TaxiMapOpened(retried)
	local nodes = self:ReadTaxiMap()
	if #nodes > 0 then
		self:NoteTaxiNodes(nodes)
	elseif not retried then
		C_Timer.After(TAXI_RETRY, function()
			ns.SafeCall(Context.TaxiMapOpened, Context, true)
		end)
	end
end

-- Start-up and sampling ---------------------------------------------------------------------------------------------

function Context:Tick()
	self.ticks = self.ticks + 1
	for _, what in ipairs(LIVE) do
		self:Poll(what)
	end
	if self.ticks % POLL_TICKS == 0 then
		for _, what in ipairs(KINDS) do
			if not IS_LIVE[what] and not self.sources[what] then
				self:Invalidate(what)
			end
		end
	end
end

function Context:Start()
	if not self.ticker then
		self.ticker = C_Timer.NewTicker(TICK, function()
			ns.SafeCall(Context.Tick, Context)
		end)
	end
	self.completedStale = true
	self.positionAt = nil
	self:InvalidateAll()
end

-- What /signpost context saves, so the cached state can be checked against the client through SavedVariables.
function Context:Snapshot()
	local quests = {}
	for _, entry in pairs(self:QuestLog()) do
		quests[#quests + 1] = entry
	end
	table.sort(quests, function(a, b)
		return a.id < b.id
	end)
	local store, known = self:TaxiStore(), 0
	for _, entry in pairs(store) do
		if type(entry) == "table" and entry.known then
			known = known + 1
		end
	end
	local position = self:Position()
	return {
		time = time(),
		now = self:Now(),
		level = self:Level(),
		position = position,
		mapChain = Util.MapChain(position and position.map),
		onTaxi = self:OnTaxi(),
		bind = self:BindLocation(),
		quests = quests,
		completed = self.completedCount,
		collapsedHeaders = self.collapsedHeaders,
		spells = self.spells,
		items = self.items,
		skills = self.skillSnapshot,
		taxiNodes = store,
		knownTaxiNodes = known,
		missingEvents = self.missingEvents,
	}
end

-- Events --------------------------------------------------------------------------------------------------------------

-- Registers a game event that refreshes `kinds` (a list), or runs handler(Context, ...) instead. An event the client
-- rejects is listed in Context.missingEvents; a kind left without any event is polled by Tick.
local function listen(event, kinds, handler)
	local ok = ns.Events:Register(event, function(_, ...)
		if handler then
			handler(Context, ...)
			return
		end
		for _, what in ipairs(kinds) do
			Context:Invalidate(what)
		end
	end)
	if not ok then
		Context.missingEvents[#Context.missingEvents + 1] = event
		return false
	end
	for _, what in ipairs(kinds or {}) do
		Context.sources[what] = (Context.sources[what] or 0) + 1
	end
	return true
end

ns.SavedVars:RegisterDefaults("char", "taxiNodes", {})

listen("QUEST_LOG_UPDATE", { "quests" }, function(self)
	if self.completedEmpty then
		self.completedStale = true
	end
	self:Invalidate("quests")
end)
listen("QUEST_ACCEPTED", { "quests" })
listen("QUEST_REMOVED", { "quests" })
listen("QUEST_WATCH_UPDATE", { "quests" })
listen("UNIT_QUEST_LOG_CHANGED", { "quests" }, function(self, unit)
	if unit == "player" then
		self:Invalidate("quests")
	end
end)
listen("QUEST_TURNED_IN", { "quests" }, function(self, questID)
	self:QuestTurnedIn(questID)
end)

local function learnedSpell(self)
	self.owed.spells = true
	self:Invalidate("spells")
end
listen("SPELLS_CHANGED", { "spells" })
listen("LEARNED_SPELL_IN_SKILL_LINE", { "spells" }, learnedSpell)
-- Absent on Forever (FOREVER-API-NOTES); kept for clients that still send it.
listen("LEARNED_SPELL_IN_TAB", { "spells" }, learnedSpell)

-- ns.Player refreshes its professions on the same event; the re-read happens a frame later, after it.
-- VERIFY(beta): SKILL_LINES_CHANGED fires on every skill-up (rank 1 -> 2), not only when a skill line is learned.
listen("SKILL_LINES_CHANGED", { "skills" })
ns.Events:RegisterMessage("PLAYER_PROFESSIONS_CHANGED", function()
	Context:Invalidate("skills")
end)
Context.sources.skills = (Context.sources.skills or 0) + 1

listen("BAG_UPDATE_DELAYED", { "bags" })

listen("PLAYER_LEVEL_UP", { "level" }, function(self, level)
	self.pendingLevel = plain(level)
	self:Invalidate("level")
end)

local function zoneChanged(self)
	self.positionAt = nil
	self:Invalidate("zone")
	self:Invalidate("position")
end
listen("ZONE_CHANGED_NEW_AREA", { "zone", "position" }, zoneChanged)
listen("ZONE_CHANGED", { "zone", "position" }, zoneChanged)
listen("ZONE_CHANGED_INDOORS", { "zone", "position" }, zoneChanged)

listen("PLAYER_CONTROL_LOST", { "taxi" })
listen("PLAYER_CONTROL_GAINED", { "taxi" })
listen("TAXIMAP_OPENED", { "taxi" }, function(self)
	self:TaxiMapOpened()
end)
listen("TAXIMAP_CLOSED", { "taxi" })

-- VERIFY(beta): HEARTHSTONE_BOUND exists on Forever (not probed yet). The bind location is sampled every tick anyway.
listen("HEARTHSTONE_BOUND", { "bind" })

listen("PLAYER_ENTERING_WORLD", nil, function(self, isLogin, isReload)
	if isLogin or isReload then
		self.completedStale = true
	end
	self.positionAt = nil
	self:InvalidateAll()
end)
listen("PLAYER_LOGIN", nil, function(self)
	self:Start()
end)

ns.Events:RegisterMessage("DB_READY", function()
	Context:LoadTaxiNodes()
end)

ns.Slash:Register("context", function()
	local snapshot = Context:Snapshot()
	ns.db.context = Util.Sanitize(snapshot)
	local position = snapshot.position or {}
	local ready = 0
	for _, entry in ipairs(snapshot.quests) do
		if entry.ready then
			ready = ready + 1
		end
	end
	Util.Print(
		L["context: level %s, map %s at %s, %s, on a taxi %s, bind location %s"],
		tostring(snapshot.level),
		tostring(position.map),
		tostring(Util.Round(position.x, 2)),
		tostring(Util.Round(position.y, 2)),
		tostring(snapshot.onTaxi),
		tostring(snapshot.bind)
	)
	Util.Print(
		L["  quests in the log %d (%d ready), completed %d, known flight nodes %d; events this client lacks: %s"],
		#snapshot.quests,
		ready,
		snapshot.completed,
		snapshot.knownTaxiNodes,
		#snapshot.missingEvents > 0 and table.concat(snapshot.missingEvents, ", ") or L["none"]
	)
	Util.Print(L["Saved to SignpostDB.context. Type /reload to write it to disk."])
end, L["the step engine's cached player state (quests, position, taxi, bind location); saves to SignpostDB.context"])
