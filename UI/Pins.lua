-- Minimap and world map pins for the current step's targets and the active sticky steps (PLAN §3.1, §3.6). Every
-- target gets a minimap pin that floats on the minimap edge (with an arrow towards it) and a world map pin; a .path
-- shows only its next waypoint on the minimap, while the world map numbers every waypoint and joins them with lines on
-- zone maps (not on continent maps). Pins are HereBeDragons-Pins-2.0 icons; targets come from ns.Conditions:Targets
-- (docs/ENGINE.md "Data shapes"). Missing coordinates or positions (instances, transports) just mean fewer pins. A step
-- with no targets draws nothing and clears the pins and the edge arrows of the one before: a doing step (Engine/
-- Conditions.lua "Step kinds") is left to the quest log's own marks on the map and the minimap.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Pins = {
	minimap = {}, -- active minimap pin -> entry
	world = {}, -- active world map pin -> entry
	pools = { minimap = {}, world = {} },
	lines = {}, -- { line = Line, from = entry, to = entry }
	linePool = {},
}
ns.Pins = Pins

local REF = ADDON_NAME -- HereBeDragons-Pins keeps our pins under this reference
local REFRESH_DELAY = 0.2 -- seconds; pins must follow CONTEXT_CHANGED and TRANSPORT_STATE within 1 s
local ARROW_INTERVAL = 0.2
local FAINT_ALPHA, STICKY_ALPHA = 0.5, 0.8
local LINE_THICKNESS = 3
-- HBD_PINS_WORLDMAP_SHOW_PARENT and HBD_PINS_WORLDMAP_SHOW_CONTINENT (HereBeDragons-Pins-2.0).
local SHOW_PARENT, SHOW_CONTINENT = 1, 2
-- Enum.UIMapType Zone, Dungeon, Micro and Orphan: the map levels that get waypoint lines.
local ZONE_MAP_TYPES = { [3] = true, [4] = true, [5] = true, [6] = true }
-- Blizzard's arrow for points of interest beyond the minimap edge.
-- VERIFY(beta): the file exists on Forever and points up at rotation 0.
local ARROW_TEXTURE = "Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW"
local ARROW_SIZE = 24

local DEFAULTS = {
	minimap = true,
	worldMap = true,
	showNext = false, -- faintly show the next steps' targets on the world map (PLAN §3.1, off by default)
	nextCount = 2,
}
ns.SavedVars:RegisterDefaults("account", "pins", DEFAULTS)

local function settings()
	return ns.db and ns.db.pins or DEFAULTS
end

local function libraries()
	local stub = LibStub
	if not stub then
		return nil
	end
	local hbd, hbdPins = stub("HereBeDragons-2.0", true), stub("HereBeDragons-Pins-2.0", true)
	if hbd and hbdPins then
		return hbd, hbdPins
	end
end

-- Icons ---------------------------------------------------------------------------------------------------------------
-- Target kind -> the first atlas this client has, else the file. All atlases and files here are in FOREVER-API-NOTES
-- "Verified" (beta 1.60.1.70450) except the Waypoint-MapPin ones; there is no "Vendor" atlas.

local MAP_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local ICONS = {
	-- VERIFY(beta): Waypoint-MapPin-Tracked and Waypoint-MapPin-Untracked exist on Forever (not in the probe list yet).
	["goto"] = { atlases = { "Waypoint-MapPin-Tracked", "TaxiNode_Neutral" }, file = MAP_ICON },
	waypoint = { atlases = { "TaxiNode_Neutral" }, file = MAP_ICON },
	accept = { atlases = { "QuestNormal" }, file = "Interface\\GossipFrame\\AvailableQuestIcon" },
	turnin = { atlases = { "QuestTurnin" }, file = "Interface\\GossipFrame\\ActiveQuestIcon" },
	objective = { atlases = { "Waypoint-MapPin-Untracked" }, file = "Interface\\GossipFrame\\ActiveQuestIcon" },
	taxi = { atlases = { "FlightMaster" }, file = "Interface\\GossipFrame\\TaxiGossipIcon" },
	dock = { faction = true, atlases = { "TaxiNode_Neutral" }, file = MAP_ICON },
	inn = { atlases = { "Innkeeper" }, file = "Interface\\GossipFrame\\BinderGossipIcon" },
	trainer = { atlases = { "Class" }, file = "Interface\\GossipFrame\\TrainerGossipIcon" },
	vendor = { file = "Interface\\GossipFrame\\VendorGossipIcon" },
	fish = { atlases = { "Profession" }, file = "Interface\\Minimap\\Tracking\\Profession" },
	gather = { atlases = { "poi-workorders", "Profession" }, file = "Interface\\Minimap\\Tracking\\Profession" },
}

local atlasCache = {}

function Pins.AtlasExists(name)
	if atlasCache[name] == nil then
		local getInfo = C_Texture and C_Texture.GetAtlasInfo
		if getInfo then
			atlasCache[name] = Util.Call(getInfo, name) ~= nil
		else
			atlasCache[name] = true -- cannot tell in advance; the client decides
		end
	end
	return atlasCache[name]
end

local function fileExists(path)
	if not GetFileIDFromPath then
		return true
	end
	return Util.Call(GetFileIDFromPath, path) ~= nil
end

-- Returns atlas, file for a target kind; `override` (a target's optional `icon`) is an atlas name or a texture path.
function Pins.IconFor(kind, override)
	if type(override) == "string" and override ~= "" then
		if override:find("[\\/]") then
			return nil, override
		end
		if Pins.AtlasExists(override) then
			return override
		end
	end
	local spec = ICONS[kind] or ICONS["goto"]
	local faction = spec.faction and ns.Player and ns.Player.faction
	if faction and Pins.AtlasExists("TaxiNode_" .. faction) then
		return "TaxiNode_" .. faction
	end
	for _, atlas in ipairs(spec.atlases or {}) do
		if Pins.AtlasExists(atlas) then
			return atlas
		end
	end
	return nil, spec.file
end

function Pins.ApplyIcon(texture, kind, override)
	local atlas, file = Pins.IconFor(kind, override)
	if atlas then
		texture:SetAtlas(atlas)
	else
		texture:SetTexture(file)
		-- SetTexture keeps the texture coordinates a previous SetAtlas left behind.
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

local KIND_TITLES = {
	["goto"] = L["Go here"],
	waypoint = L["Waypoint"],
	accept = L["Accept quest"],
	turnin = L["Turn in quest"],
	objective = L["Quest objective"],
	taxi = L["Flight master"],
	dock = L["Transport"],
	inn = L["Innkeeper"],
	trainer = L["Trainer"],
	vendor = L["Vendor"],
	fish = L["Fish here"],
	gather = L["Gather here"],
}

-- Targets ---------------------------------------------------------------------------------------------------------

local function validCoordinate(value)
	return type(value) == "number" and not Util.IsSecret(value) and value >= 0 and value <= 100
end

local function validTarget(target)
	return type(target) == "table"
		and type(target.map) == "number"
		and validCoordinate(target.x)
		and validCoordinate(target.y)
end

local function statesFor(step)
	local progress = ns.Progress
	if progress and progress.State and step.id then
		local ok, states = ns.SafeCall(progress.State, progress, step.id)
		if ok and type(states) == "table" then
			return states
		end
	end
	return {}
end

-- States for a step that is not current yet: an empty state table per directive, so no onStart runs early.
local function scratchStates()
	return setmetatable({}, {
		__index = function(states, index)
			local state = {}
			rawset(states, index, state)
			return state
		end,
	})
end

-- The step's targets ({ target, ... }, possibly empty) with its progress states.
function Pins:Targets(step, states)
	local conditions = ns.Conditions
	if type(step) ~= "table" or not (conditions and conditions.Targets) then
		return {}
	end
	local ok, targets = ns.SafeCall(conditions.Targets, conditions, step, ns.Context, states or statesFor(step))
	return ok and type(targets) == "table" and targets or {}
end

-- Adds the step's pinnable targets; a target already pinned at the same spot (same kind, place and number) is skipped,
-- so earlier entries win: the current step, then the stickies, then the faint next steps.
local function addEntries(entries, seen, step, onlySticky, faint, states)
	for _, target in ipairs(Pins:Targets(step, states)) do
		if validTarget(target) and (target.sticky or not onlySticky) then
			local key =
				table.concat({ tostring(target.kind), target.map, target.x, target.y, tostring(target.index) }, "|")
			if not seen[key] then
				seen[key] = true
				entries[#entries + 1] =
					{ target = target, step = step, sticky = target.sticky and true or false, faint = faint }
			end
		end
	end
end

-- Everything to pin: the current step's targets, the sticky targets of the active sticky steps and, with showNext,
-- the targets of the next steps (faint, world map only).
function Pins:Collect()
	local entries, seen = {}, {}
	local progress = ns.Progress
	if not (progress and progress.Current) then
		return entries
	end
	local current, index = progress:Current()
	if type(current) == "table" then
		index = index or current.index
		addEntries(entries, seen, current, false, false)
	end
	if progress.Sticky then
		local active = progress:Sticky()
		for _, step in ipairs(type(active) == "table" and active or {}) do
			if type(step) == "table" and step ~= current and (not current or step.id ~= current.id) then
				addEntries(entries, seen, step, true, false)
			end
		end
	end
	local s = settings()
	local guide = s.showNext and progress.Guide and progress:Guide()
	if type(guide) == "table" and type(guide.steps) == "table" and type(index) == "number" then
		local count = type(s.nextCount) == "number" and s.nextCount or DEFAULTS.nextCount
		for i = index + 1, math.min(index + count, #guide.steps) do
			addEntries(entries, seen, guide.steps[i], false, true, scratchStates())
		end
	end
	return entries
end

local function signature(entries)
	local parts = {}
	for i, entry in ipairs(entries) do
		local target = entry.target
		parts[i] = table.concat({
			tostring(entry.step and entry.step.id),
			tostring(target.kind),
			target.map,
			target.x,
			target.y,
			tostring(target.index),
			tostring(target.next),
			tostring(target.reached),
			tostring(target.label),
			tostring(target.icon),
			tostring(entry.sticky),
			tostring(entry.faint),
		}, "|")
	end
	return table.concat(parts, "\n")
end

-- A waypoint's place in its path: target.next marks the next unreached waypoint; without it, the lowest-numbered
-- waypoint that is not marked reached comes next.
local function waypointRank(entry)
	local target = entry.target
	if target.next then
		return -1
	elseif target.reached then
		return math.huge
	end
	return type(target.index) == "number" and target.index or 1e9
end

-- The set of entries that are the next waypoint of their step's path.
local function nextWaypoints(entries)
	local best = {}
	for _, entry in ipairs(entries) do
		if entry.target.kind == "waypoint" and not entry.faint then
			local group = entry.step or false
			if not best[group] or waypointRank(entry) < waypointRank(best[group]) then
				best[group] = entry
			end
		end
	end
	local set = {}
	for _, entry in pairs(best) do
		set[entry] = true
	end
	return set
end

-- Pin frames ------------------------------------------------------------------------------------------------------

local function createPin(where)
	local pin = CreateFrame("Button", nil, where == "minimap" and Minimap or UIParent)
	pin.where = where
	pin:EnableMouse(true)
	pin.texture = pin:CreateTexture(nil, "ARTWORK")
	pin.texture:SetAllPoints(pin)
	-- Waypoint number. VERIFY(beta): readable on top of the TaxiNode_Neutral icon.
	pin.number = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pin.number:SetPoint("CENTER", pin, "CENTER", 0, 0)
	pin.arrow = false
	if where == "minimap" then
		-- VERIFY(beta): above the minimap's own layers (HereBeDragons only parents the pin to Minimap).
		if Minimap then
			pin:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 5)
		end
		pin.arrow = pin:CreateTexture(nil, "OVERLAY")
		pin.arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
		pin.arrow:SetPoint("CENTER", pin, "CENTER", 0, 0)
		pin.arrow:SetTexture(ARROW_TEXTURE)
		pin.arrow:Hide()
	else
		pin:RegisterForClicks("LeftButtonUp")
		pin:SetScript("OnClick", function(self)
			ns.SafeCall(Pins.OnClick, Pins, self)
		end)
	end
	pin:SetScript("OnEnter", function(self)
		ns.SafeCall(Pins.ShowTooltip, Pins, self)
	end)
	pin:SetScript("OnLeave", function(self)
		ns.SafeCall(Pins.HideTooltip, Pins, self)
	end)
	pin:Hide()
	return pin
end

local function setupPin(pin, entry)
	local target = entry.target
	local waypoint = target.kind == "waypoint"
	local size = pin.where == "minimap" and (waypoint and 14 or 16) or (waypoint and 18 or 20)
	pin:SetSize(size, size)
	Pins.ApplyIcon(pin.texture, target.kind, target.icon)
	pin.texture:SetDesaturated(target.reached and true or false)
	pin.texture:Show()
	pin.number:SetText(waypoint and type(target.index) == "number" and tostring(target.index) or "")
	pin:SetAlpha(entry.faint and FAINT_ALPHA or entry.sticky and STICKY_ALPHA or 1)
	if pin.arrow then
		pin.arrow:Hide()
	end
end

local function acquire(where)
	return table.remove(Pins.pools[where]) or createPin(where)
end

local function release(pin)
	if Pins.hovered == pin then
		Pins:HideTooltip(pin)
	end
	pin:Hide()
	if pin.arrow then
		pin.arrow:Hide()
	end
	local pool = Pins.pools[pin.where]
	pool[#pool + 1] = pin
end

function Pins:AddMinimapPin(hbd, hbdPins, entry)
	local target = entry.target
	local x, y, instance = hbd:GetWorldCoordinatesFromZone(target.x / 100, target.y / 100, target.map)
	if not (x and y and instance) then
		return nil
	end
	local pin = acquire("minimap")
	setupPin(pin, entry)
	-- World coordinates, so a target in the next zone still shows (on the edge) before the player crosses over.
	if hbdPins:AddMinimapIconWorld(REF, pin, instance, x, y, true) then
		self.minimap[pin] = entry
		return pin
	end
	release(pin)
end

function Pins:AddWorldPin(hbdPins, entry, showFlag)
	local target = entry.target
	local pin = acquire("world")
	setupPin(pin, entry)
	if hbdPins:AddWorldMapIconMap(REF, pin, target.map, target.x / 100, target.y / 100, showFlag) then
		self.world[pin] = entry
		return pin
	end
	release(pin)
end

-- Waypoint lines ----------------------------------------------------------------------------------------------------
-- Line regions on our own layer over the world map canvas, anchored to the waypoint pins so they follow pan and zoom.

local function lineLayer()
	if Pins.lineLayer then
		return Pins.lineLayer
	end
	local map = WorldMapFrame
	local canvas = map and map.GetCanvas and map:GetCanvas()
	if not canvas then
		return nil
	end
	local layer = CreateFrame("Frame", nil, canvas)
	layer:SetAllPoints(canvas)
	-- VERIFY(beta): above the map art (child frames of the canvas) and below the pins.
	layer:SetFrameLevel((canvas:GetFrameLevel() or 0) + 2)
	Pins.lineLayer = layer
	return layer
end

-- VERIFY(beta): a 3 px gold line reads well on the zone maps at every zoom level.
local function acquireLine(layer)
	local line = table.remove(Pins.linePool) or layer:CreateLine(nil, "ARTWORK")
	line:SetThickness(LINE_THICKNESS)
	line:SetColorTexture(1, 0.82, 0, 1) -- the gold of GameFontNormal
	return line
end

local function mapType(mapID)
	local info = Util.Call(C_Map and C_Map.GetMapInfo, mapID)
	return type(info) == "table" and info.mapType or nil
end

-- Whether HereBeDragons shows a waypoint of `map` on the world map's `mapID` (its own map, or a zone-level map above
-- it in the map tree).
local function displayedOn(map, mapID)
	if map == mapID then
		return true
	end
	for i, entry in ipairs(Util.MapChain(map)) do
		if i > 1 and entry.id == mapID then
			return ZONE_MAP_TYPES[entry.type] or false
		end
	end
	return false
end

function Pins:BuildLines(entries, worldPins)
	local groups, order = {}, {}
	for _, entry in ipairs(entries) do
		local target = entry.target
		if target.kind == "waypoint" and not entry.faint and worldPins[entry] and type(target.index) == "number" then
			local group = entry.step or false
			if not groups[group] then
				groups[group] = {}
				order[#order + 1] = group
			end
			table.insert(groups[group], entry)
		end
	end
	if #order == 0 then
		return
	end
	local layer = lineLayer()
	if not layer then
		return
	end
	for _, group in ipairs(order) do
		local list = groups[group]
		table.sort(list, function(a, b)
			return a.target.index < b.target.index
		end)
		for i = 2, #list do
			local line = acquireLine(layer)
			local from, to = worldPins[list[i - 1]], worldPins[list[i]]
			line:SetStartPoint("CENTER", from, 0, 0)
			line:SetEndPoint("CENTER", to, 0, 0)
			line:SetAlpha(list[i].target.reached and 0.35 or 0.8)
			self.lines[#self.lines + 1] = { line = line, from = list[i - 1], to = list[i], fromPin = from, toPin = to }
		end
	end
end

-- Lines show on zone-level maps only, and only between two waypoints both drawn on the map being viewed (the pins
-- are shown by HereBeDragons only while they are on the map).
function Pins:UpdateLines()
	local map = WorldMapFrame
	local mapID = map and Util.Call(map.GetMapID, map)
	local zoneMap = type(mapID) == "number" and ZONE_MAP_TYPES[mapType(mapID)] or false
	for _, record in ipairs(self.lines) do
		local shown = zoneMap
			and displayedOn(record.from.target.map, mapID)
			and displayedOn(record.to.target.map, mapID)
			and record.fromPin:IsShown()
			and record.toPin:IsShown()
		if shown then
			record.line:Show()
		else
			record.line:Hide()
		end
	end
end

-- Runs UpdateLines on the next frame, once every map data provider (HereBeDragons' among them, in no fixed order) has
-- placed its pins for the new map.
function Pins:RequestLineUpdate()
	if self.linesScheduled then
		return
	end
	self.linesScheduled = true
	C_Timer.After(0, function()
		Pins.linesScheduled = false
		ns.SafeCall(Pins.UpdateLines, Pins)
	end)
end

-- Our world map data provider: the map calls RefreshAllData when it opens and OnMapChanged when it changes maps.
local function ensureMapProvider()
	if Pins.provider ~= nil then
		return
	end
	local map = WorldMapFrame
	if not (map and map.AddDataProvider and CreateFromMixins and MapCanvasDataProviderMixin) then
		Pins.provider = false
		return
	end
	local provider = CreateFromMixins(MapCanvasDataProviderMixin)
	function provider.RefreshAllData()
		Pins:RequestLineUpdate()
	end
	function provider:OnMapChanged()
		self:RefreshAllData()
	end
	function provider.RemoveAllData() end
	map:AddDataProvider(provider)
	Pins.provider = provider
end

-- Refresh -------------------------------------------------------------------------------------------------------------

function Pins:Clear()
	local _, hbdPins = libraries()
	if hbdPins then
		hbdPins:RemoveAllMinimapIcons(REF)
		hbdPins:RemoveAllWorldMapIcons(REF)
	end
	for pin in pairs(self.minimap) do
		release(pin)
	end
	for pin in pairs(self.world) do
		release(pin)
	end
	wipe(self.minimap)
	wipe(self.world)
	for _, record in ipairs(self.lines) do
		record.line:Hide()
		self.linePool[#self.linePool + 1] = record.line
	end
	wipe(self.lines)
	self.signature = nil
	self:UpdateArrowTicker()
end

-- Rebuilds the pins when what they show has changed (or always, with force).
function Pins:Refresh(force)
	local hbd, hbdPins = libraries()
	if not hbdPins then
		return
	end
	local s = settings()
	local entries = self:Collect()
	local key = signature(entries) .. "|" .. tostring(s.minimap ~= false) .. tostring(s.worldMap ~= false)
	if key == self.signature and not force then
		return
	end
	self:Clear()
	self.signature = key
	ensureMapProvider()
	local nextOf = nextWaypoints(entries)
	local worldPins = {}
	for _, entry in ipairs(entries) do
		local waypoint = entry.target.kind == "waypoint"
		local isNext = nextOf[entry] == true
		if s.minimap ~= false and not entry.faint and (not waypoint or isNext) then
			self:AddMinimapPin(hbd, hbdPins, entry)
		end
		if s.worldMap ~= false then
			local flag = (entry.faint or (waypoint and not isNext)) and SHOW_PARENT or SHOW_CONTINENT
			worldPins[entry] = self:AddWorldPin(hbdPins, entry, flag)
		end
	end
	self:BuildLines(entries, worldPins)
	self:UpdateLines()
	self:UpdateArrowTicker()
end

-- Coalesces bursts of CONTEXT_CHANGED / TRANSPORT_STATE into one refresh, REFRESH_DELAY later.
function Pins:RequestRefresh()
	if self.scheduled then
		return
	end
	self.scheduled = true
	C_Timer.After(REFRESH_DELAY, function()
		Pins.scheduled = false
		ns.SafeCall(Pins.Refresh, Pins)
	end)
end

function Pins:SetEnabled(where, enabled)
	if ns.db and (where == "minimap" or where == "worldMap") then
		ns.db.pins[where] = enabled and true or false
		self:Refresh(true)
	end
end

-- Edge arrows -----------------------------------------------------------------------------------------------------
-- HereBeDragons floats an off-range pin on the minimap edge; there it turns into an arrow towards the target.

local function minimapFacing()
	local rotating = Util.Call(C_CVar and C_CVar.GetCVar, "rotateMinimap") == "1"
	if not rotating then
		return 0
	end
	local facing = Util.Call(GetPlayerFacing)
	if type(facing) == "number" and not Util.IsSecret(facing) then
		return facing
	end
end

function Pins:UpdateArrows()
	local _, hbdPins = libraries()
	if not hbdPins then
		return
	end
	local facing = minimapFacing()
	for pin in pairs(self.minimap) do
		local angle = hbdPins:IsMinimapIconOnEdge(pin) and facing and hbdPins:GetVectorToIcon(pin)
		if type(angle) == "number" and not Util.IsSecret(angle) and pin.arrow then
			pin.arrow:SetRotation(angle - facing)
			pin.arrow:Show()
			pin.texture:Hide()
			pin.number:Hide()
		else
			if pin.arrow then
				pin.arrow:Hide()
			end
			pin.texture:Show()
			pin.number:Show()
		end
	end
end

function Pins:UpdateArrowTicker()
	local wanted = next(self.minimap) ~= nil and fileExists(ARROW_TEXTURE)
	if wanted and not self.arrowTicker then
		self.arrowTicker = C_Timer.NewTicker(ARROW_INTERVAL, function()
			ns.SafeCall(Pins.UpdateArrows, Pins)
		end)
	elseif not wanted and self.arrowTicker then
		self.arrowTicker:Cancel()
		self.arrowTicker = nil
	end
end

-- Tooltips and clicks -----------------------------------------------------------------------------------------------

local function distanceTo(target)
	local context = ns.Context
	if not (context and context.Distance) then
		return nil
	end
	local ok, yards = pcall(context.Distance, context, target.map, target.x, target.y)
	if ok and type(yards) == "number" and not Util.IsSecret(yards) then
		return math.floor(yards + 0.5)
	end
end

local function tooltipTitle(target)
	if type(target.label) == "string" and target.label ~= "" then
		return target.label
	elseif target.kind == "waypoint" and type(target.index) == "number" then
		return string.format(L["Waypoint %d"], target.index)
	end
	return KIND_TITLES[target.kind] or KIND_TITLES["goto"]
end

-- The text under a pin: the step's lines, or for a sticky target its sticky directives.
local function tooltipLines(entry)
	local stepFrame = ns.StepFrame
	if not stepFrame then
		return {}
	end
	if entry.sticky then
		return (stepFrame.DescribeActiveSticky or stepFrame.DescribeSticky)(entry.step)
	end
	return stepFrame.DescribeLines(entry.step)
end

-- Tooltip: the target, the step's text and the distance in yards.
function Pins:ShowTooltip(pin)
	local tooltip = GameTooltip
	local entry = self.minimap[pin] or self.world[pin]
	if not (tooltip and entry) then
		return
	end
	self.hovered = pin
	-- The minimap sits in the top-right corner; its tooltips open towards the screen.
	tooltip:SetOwner(pin, pin.where == "minimap" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
	tooltip:SetText(tooltipTitle(entry.target), 1, 0.82, 0)
	for _, line in ipairs(tooltipLines(entry)) do
		tooltip:AddLine(line, 1, 1, 1, true)
	end
	local yards = distanceTo(entry.target)
	if yards then
		tooltip:AddLine(string.format(L["%d yards"], yards), 0.75, 0.75, 0.75)
	end
	tooltip:Show()
end

function Pins:HideTooltip(pin)
	local tooltip = GameTooltip
	if tooltip and tooltip:IsOwned(pin) then
		tooltip:Hide()
	end
	if self.hovered == pin then
		self.hovered = nil
	end
end

-- Keeps the distance in an open pin tooltip current as the player moves.
function Pins:RefreshTooltip()
	local pin, tooltip = self.hovered, GameTooltip
	if pin and tooltip and tooltip:IsOwned(pin) then
		self:ShowTooltip(pin)
	end
end

-- A click on a world map pin opens the journal at that step (PLAN §3.1; the journal arrives in Phase 4).
function Pins:OnClick(pin)
	local entry = self.world[pin]
	local journal = ns.Journal
	if entry and journal and journal.ShowStep then
		journal:ShowStep(entry.step)
	end
end

function Pins:OnContextChanged(what)
	self:RequestRefresh()
	if what == "position" then
		self:RefreshTooltip()
	end
end

-- Events --------------------------------------------------------------------------------------------------------------

ns.Events:RegisterMessage("GUIDE_LOADED", function()
	Pins:Refresh(true)
end)
ns.Events:RegisterMessage("STEP_CHANGED", function()
	Pins:Refresh()
end)
-- The sticky set changed (Engine/Progress.lua): their targets come or go.
ns.Events:RegisterMessage("STICKY_CHANGED", function()
	Pins:Refresh()
end)
ns.Events:RegisterMessage("CONTEXT_CHANGED", function(_, what)
	Pins:OnContextChanged(what)
end)
ns.Events:RegisterMessage("TRANSPORT_STATE", function()
	Pins:RequestRefresh()
end)
ns.Events:Register("PLAYER_LOGIN", function()
	Pins:RequestRefresh()
end)
ns.Events:Register("PLAYER_ENTERING_WORLD", function()
	Pins:RequestRefresh()
end)
