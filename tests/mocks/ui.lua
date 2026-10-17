-- UI behaviour on top of tests/wow_mock.lua for the step frame and pin specs: frames and regions that keep points,
-- sizes, scale, alpha, text, textures and attributes; secure frames that refuse protected calls in combat the way the
-- client does (also on frames they are parented or anchored to); GameTooltip, Minimap and a WorldMapFrame with data
-- providers; HereBeDragons-2.0 and HereBeDragons-Pins-2.0 stand-ins that record pins.
--
-- Install from addon.load's `before` hook (after wow_mock.install, before the addon files load):
--   ui = uiMock.install(mock)                 -- the full UI mock; `ui` is the switchboard specs read and set
--   ui = uiMock.install(mock, { noLibs = true }) -- without LibStub/HereBeDragons
--   ui = uiMock.install(mock, { bare = true })   -- only region constructors on wow_mock's generic frames
-- and call uiMock.uninstall() after each test: it restores every global install replaced.
--
-- Like the client, a decorated object answers nil for unknown lowercase fields; unknown methods are no-ops.
local M = {}

local function noop() end

local GLOBALS = {
	"CreateFrame",
	"InCombatLockdown",
	"UnitAffectingCombat",
	"UnitIsDeadOrGhost",
	"IsShiftKeyDown",
	"GetPlayerFacing",
	"GetFileIDFromPath",
	"C_Texture",
	"C_Map",
	"C_CVar",
	"C_Container",
	"C_Item",
	"GameFontNormal",
	"GameFontHighlight",
	"GameFontNormalSmall",
	"GameFontHighlightSmall",
	"GameFontDisableSmall",
	"NumberFontNormal",
	"GameTooltip",
	"Minimap",
	"WorldMapFrame",
	"MapCanvasDataProviderMixin",
	"CreateFromMixins",
	"Mixin",
	"LibStub",
	"SignpostItemButton",
}

local saved -- the globals as they were before install

function M.uninstall()
	if not saved then
		return
	end
	for _, name in ipairs(GLOBALS) do
		_G[name] = saved[name]
	end
	saved = nil
end

-- Atlases and files as the beta probe found them (docs/probes/1.60.1.70450.json), plus the minimap edge arrow.
local VERIFIED_ATLASES = {
	"Class",
	"FlightMaster",
	"Food",
	"Innkeeper",
	"Mailbox",
	"Profession",
	"QuestDaily",
	"QuestNormal",
	"QuestRepeatableTurnin",
	"QuestTurnin",
	"Repair",
	"TaxiNode_Horde",
	"TaxiNode_Neutral",
	"poi-door",
	"poi-workorders",
}

local FILES = {
	"Interface\\DialogFrame\\UI-DialogBox-Border",
	"Interface\\GossipFrame\\ActiveQuestIcon",
	"Interface\\GossipFrame\\AvailableQuestIcon",
	"Interface\\GossipFrame\\BinderGossipIcon",
	"Interface\\GossipFrame\\TaxiGossipIcon",
	"Interface\\GossipFrame\\TrainerGossipIcon",
	"Interface\\GossipFrame\\VendorGossipIcon",
	"Interface\\Icons\\INV_Misc_Map_01",
	"Interface\\Minimap\\Tracking\\Profession",
	"Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW",
}

-- A small map tree: Azeroth > Kalimdor > Durotar, The Barrens, Orgrimmar; Eastern Kingdoms > Stranglethorn Vale.
-- `world` places a map in world yards (x0/y0 + fraction * 1000) on a continent instance.
local function maps()
	return {
		[947] = { name = "Azeroth", mapType = 1, parent = 0 },
		[1414] = { name = "Kalimdor", mapType = 2, parent = 947, world = { instance = 1, x0 = 0, y0 = 0 } },
		[1411] = { name = "Durotar", mapType = 3, parent = 1414, world = { instance = 1, x0 = 1000, y0 = 2000 } },
		[1413] = { name = "The Barrens", mapType = 3, parent = 1414, world = { instance = 1, x0 = 0, y0 = 3000 } },
		[1454] = { name = "Orgrimmar", mapType = 3, parent = 1414, world = { instance = 1, x0 = 1200, y0 = 1800 } },
		[1415] = { name = "Eastern Kingdoms", mapType = 2, parent = 947, world = { instance = 0, x0 = 0, y0 = 0 } },
		[1434] = {
			name = "Stranglethorn Vale",
			mapType = 3,
			parent = 1415,
			world = { instance = 0, x0 = 5000, y0 = 5000 },
		},
	}
end

-- Objects ------------------------------------------------------------------------------------------------------------

local state = setmetatable({}, { __mode = "k" })
local methods = {}
local ui -- the switchboard of the current install

local function S(obj)
	return state[obj]
end
M.state = S

local function wrapIndex(baseIndex)
	return function(obj, key)
		if type(key) == "string" and key:find("^%u") then
			local method = methods[key]
			if method then
				return method
			end
			if type(baseIndex) == "function" then
				return baseIndex(obj, key)
			elseif type(baseIndex) == "table" and baseIndex[key] ~= nil then
				return baseIndex[key]
			end
			return noop
		end
	end
end

local function decorate(obj, kind, parent)
	local meta = getmetatable(obj)
	setmetatable(obj, { __index = wrapIndex(meta and meta.__index) })
	state[obj] = {
		kind = kind,
		parent = parent,
		points = {},
		shown = true,
		scale = 1,
		alpha = 1,
		width = 0,
		height = 0,
		attributes = {},
		protectedChildren = 0,
		protectedAnchors = 0,
		enabled = true,
	}
	return obj
end

local function newRegion(kind, parent)
	return decorate({}, kind, parent)
end

local function restricted(s)
	return s.protected or s.protectedChildren > 0 or s.protectedAnchors > 0
end

-- The client refuses these on protected frames (and the frames they hang on) during combat lockdown.
local function guard(obj, method, explicitOnly)
	local s = S(obj)
	if ui and ui.combat and s and (s.protected or (not explicitOnly and restricted(s))) then
		ui.blocked[#ui.blocked + 1] = method
		error("ADDON_ACTION_BLOCKED: " .. method .. " on a protected frame in combat", 3)
	end
end

-- Points, size, scale, alpha, visibility, parent

function methods.SetPoint(obj, point, relativeTo, relativePoint, x, y)
	guard(obj, "SetPoint")
	local s = S(obj)
	if type(relativeTo) == "number" then
		relativeTo, relativePoint, x, y = nil, nil, relativeTo, relativePoint
	elseif type(relativePoint) == "number" then
		relativePoint, x, y = nil, relativePoint, x
	end
	relativeTo = relativeTo or s.parent
	if s.protected and type(relativeTo) == "table" and S(relativeTo) then
		local target = S(relativeTo)
		target.protectedAnchors = target.protectedAnchors + 1
	end
	for i, existing in ipairs(s.points) do
		if existing[1] == point then
			table.remove(s.points, i)
			break
		end
	end
	s.points[#s.points + 1] = { point, relativeTo, relativePoint or point, x or 0, y or 0 }
end

function methods.ClearAllPoints(obj)
	guard(obj, "ClearAllPoints")
	S(obj).points = {}
end

function methods.SetAllPoints(obj, relativeTo)
	guard(obj, "SetAllPoints")
	local s = S(obj)
	relativeTo = relativeTo or s.parent
	s.points = { { "TOPLEFT", relativeTo, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0 } }
end

function methods.GetPoint(obj, index)
	local point = S(obj).points[index or 1]
	if point then
		return point[1], point[2], point[3], point[4], point[5]
	end
end

function methods.GetNumPoints(obj)
	return #S(obj).points
end

-- Screen edges: anchored objects report a rectangle from their first point's offsets (enough for placement checks).
function methods.GetLeft(obj)
	local point = S(obj).points[1]
	return point and 100 + point[4] or nil
end

function methods.GetTop(obj)
	local point = S(obj).points[1]
	return point and 700 + point[5] or nil
end

function methods.GetRight(obj)
	local left = methods.GetLeft(obj)
	return left and left + S(obj).width or nil
end

function methods.GetBottom(obj)
	local top = methods.GetTop(obj)
	return top and top - S(obj).height or nil
end

function methods.SetSize(obj, width, height)
	guard(obj, "SetSize", true)
	local s = S(obj)
	s.width, s.height = width or 0, height or 0
end

function methods.SetWidth(obj, width)
	S(obj).width = width or 0
end

function methods.SetHeight(obj, height)
	S(obj).height = height or 0
end

function methods.GetWidth(obj)
	return S(obj).width
end

function methods.GetHeight(obj)
	return S(obj).height
end

function methods.GetSize(obj)
	return S(obj).width, S(obj).height
end

function methods.SetScale(obj, scale)
	guard(obj, "SetScale", true)
	S(obj).scale = scale
end

function methods.GetScale(obj)
	return S(obj).scale
end

function methods.GetEffectiveScale(obj)
	local s = S(obj)
	local parent = s.parent
	local parentScale = (type(parent) == "table" and S(parent)) and methods.GetEffectiveScale(parent) or 1
	return s.scale * parentScale
end

function methods.SetAlpha(obj, alpha)
	S(obj).alpha = alpha
end

function methods.GetAlpha(obj)
	return S(obj).alpha
end

function methods.Show(obj)
	guard(obj, "Show")
	S(obj).shown = true
end

function methods.Hide(obj)
	guard(obj, "Hide")
	S(obj).shown = false
end

function methods.SetShown(obj, shown)
	if shown then
		obj:Show()
	else
		obj:Hide()
	end
end

function methods.IsShown(obj)
	return S(obj).shown
end

function methods.IsVisible(obj)
	local s = S(obj)
	if not s.shown then
		return false
	end
	local parent = s.parent
	if type(parent) == "table" and S(parent) then
		return methods.IsVisible(parent)
	end
	return true
end

function methods.SetParent(obj, parent)
	guard(obj, "SetParent")
	local s = S(obj)
	if s.protected and type(parent) == "table" and S(parent) then
		local target = S(parent)
		target.protectedChildren = target.protectedChildren + 1
	end
	s.parent = parent
end

function methods.GetParent(obj)
	return S(obj).parent
end

function methods.SetFrameStrata(obj, strata)
	S(obj).strata = strata
end

function methods.GetFrameStrata(obj)
	return S(obj).strata or "MEDIUM"
end

function methods.SetFrameLevel(obj, level)
	S(obj).level = level
end

function methods.GetFrameLevel(obj)
	local s = S(obj)
	if s.level then
		return s.level
	end
	local parent = s.parent
	return (type(parent) == "table" and S(parent)) and methods.GetFrameLevel(parent) + 1 or 1
end

-- Text

function methods.SetText(obj, text)
	S(obj).text = text ~= nil and tostring(text) or nil
end

function methods.GetText(obj)
	return S(obj).text
end

function methods.SetFormattedText(obj, format, ...)
	S(obj).text = string.format(format, ...)
end

function methods.SetFontObject(obj, font)
	S(obj).font = font
end

function methods.GetFontObject(obj)
	return S(obj).font
end

function methods.GetFont()
	return "Fonts\\FRIZQT__.TTF", 12, ""
end

function methods.SetJustifyH(obj, justify)
	S(obj).justifyH = justify
end

function methods.SetJustifyV(obj, justify)
	S(obj).justifyV = justify
end

function methods.SetWordWrap(obj, wrap)
	S(obj).wordWrap = wrap
end

function methods.GetWordWrap(obj)
	return S(obj).wordWrap
end

function methods.SetMaxLines(obj, lines)
	S(obj).maxLines = lines
end

function methods.GetMaxLines(obj)
	return S(obj).maxLines or 0
end

-- One rendered line per "\n" (no word wrap in the mock), 14 pixels each.
local function lineCount(text)
	if type(text) ~= "string" or text == "" then
		return 0
	end
	local _, breaks = text:gsub("\n", "\n")
	return breaks + 1
end

function methods.GetStringHeight(obj)
	return lineCount(S(obj).text) * 14
end

function methods.GetNumLines(obj)
	local s = S(obj)
	local count = lineCount(s.text)
	return s.maxLines and s.maxLines > 0 and math.min(count, s.maxLines) or count
end

function methods.GetStringWidth(obj)
	return #(S(obj).text or "") * 6
end

function methods.SetTextColor(obj, r, g, b, a)
	S(obj).textColor = { r, g, b, a }
end

-- Textures and lines

function methods.SetTexture(obj, texture)
	local s = S(obj)
	s.texture, s.atlas, s.color = texture, nil, nil
end

function methods.GetTexture(obj)
	return S(obj).texture
end

function methods.SetAtlas(obj, atlas)
	local s = S(obj)
	s.atlas, s.texture, s.color = atlas, nil, nil
	s.texCoord = { "atlas", atlas }
end

function methods.GetAtlas(obj)
	return S(obj).atlas
end

function methods.SetTexCoord(obj, ...)
	S(obj).texCoord = { ... }
end

function methods.SetColorTexture(obj, r, g, b, a)
	local s = S(obj)
	s.color, s.texture, s.atlas = { r, g, b, a }, nil, nil
end

function methods.SetDesaturated(obj, desaturated)
	S(obj).desaturated = desaturated and true or false
end

function methods.IsDesaturated(obj)
	return S(obj).desaturated == true
end

function methods.SetRotation(obj, radians)
	S(obj).rotation = radians
end

function methods.GetRotation(obj)
	return S(obj).rotation or 0
end

function methods.SetStartPoint(obj, relativePoint, relativeTo, x, y)
	S(obj).start = { relativePoint, relativeTo, x or 0, y or 0 }
end

function methods.GetStartPoint(obj)
	local point = S(obj).start
	if point then
		return point[1], point[2], point[3], point[4]
	end
end

function methods.SetEndPoint(obj, relativePoint, relativeTo, x, y)
	S(obj).finish = { relativePoint, relativeTo, x or 0, y or 0 }
end

function methods.GetEndPoint(obj)
	local point = S(obj).finish
	if point then
		return point[1], point[2], point[3], point[4]
	end
end

function methods.SetThickness(obj, thickness)
	S(obj).thickness = thickness
end

function methods.GetThickness(obj)
	return S(obj).thickness
end

-- Child regions

function methods.CreateFontString(obj, _, layer, template)
	local region = newRegion("FontString", obj)
	S(region).layer, S(region).template = layer, template
	return region
end

function methods.CreateTexture(obj, _, layer)
	local region = newRegion("Texture", obj)
	S(region).layer = layer
	return region
end

function methods.CreateLine(obj, _, layer)
	local region = newRegion("Line", obj)
	S(region).layer = layer
	return region
end

-- Attributes, mouse, movement, backdrop

function methods.SetAttribute(obj, name, value)
	guard(obj, "SetAttribute", true)
	S(obj).attributes[name] = value
end

function methods.GetAttribute(obj, name)
	return S(obj).attributes[name]
end

function methods.EnableMouse(obj, enabled)
	S(obj).mouse = enabled and true or false
end

function methods.RegisterForDrag(obj, ...)
	S(obj).drag = { ... }
end

function methods.RegisterForClicks(obj, ...)
	S(obj).clicks = { ... }
end

function methods.SetMovable(obj, movable)
	S(obj).movable = movable and true or false
end

function methods.IsMovable(obj)
	return S(obj).movable == true
end

function methods.StartMoving(obj)
	S(obj).moving = true
	ui.moves = ui.moves + 1
end

-- The spec sets ui.dragTo = { point, relativeTo, relativePoint, x, y } to say where the drag ends.
function methods.StopMovingOrSizing(obj)
	local s = S(obj)
	s.moving = false
	if ui.dragTo then
		s.points = { { unpack(ui.dragTo, 1, 5) } }
	end
end

function methods.SetBackdrop(obj, backdrop)
	S(obj).backdrop = backdrop
end

function methods.GetBackdrop(obj)
	return S(obj).backdrop
end

-- Buttons and cooldowns

function methods.Enable(obj)
	S(obj).enabled = true
end

function methods.Disable(obj)
	S(obj).enabled = false
end

function methods.SetEnabled(obj, enabled)
	S(obj).enabled = enabled and true or false
end

function methods.IsEnabled(obj)
	return S(obj).enabled
end

function methods.Click(obj, button)
	local script = obj:GetScript("OnClick")
	if S(obj).enabled and script then
		script(obj, button or "LeftButton", false)
	end
end

local function buttonTexture(obj, slot, texture)
	local s = S(obj)
	s[slot] = s[slot] or newRegion("Texture", obj)
	S(s[slot]).texture = texture
	return s[slot]
end

function methods.SetNormalTexture(obj, texture)
	buttonTexture(obj, "normal", texture)
end

function methods.GetNormalTexture(obj)
	return S(obj).normal
end

function methods.SetPushedTexture(obj, texture)
	buttonTexture(obj, "pushed", texture)
end

function methods.SetHighlightTexture(obj, texture)
	buttonTexture(obj, "highlight", texture)
end

function methods.SetNormalFontObject(obj, font)
	S(obj).normalFont = font
end

function methods.SetCooldown(obj, start, duration)
	S(obj).cooldown = { start, duration }
end

function methods.Clear(obj)
	S(obj).cooldown = nil
end

-- Installs -----------------------------------------------------------------------------------------------------------

local function installBare()
	local base = CreateFrame
	local function region()
		return setmetatable({}, {
			__index = function()
				return noop
			end,
		})
	end
	local function withRegions(frame)
		rawset(frame, "CreateFontString", region)
		rawset(frame, "CreateTexture", region)
		rawset(frame, "CreateLine", region)
		return frame
	end
	CreateFrame = function(...)
		return withRegions(base(...))
	end
	withRegions(UIParent)
	ui = { bare = true, blocked = {}, moves = 0 }
	return ui
end

local function hereBeDragons()
	local hbd = {}
	function hbd.GetWorldCoordinatesFromZone(_, x, y, zone)
		local map = ui.maps[zone]
		if not (map and map.world) or type(x) ~= "number" or type(y) ~= "number" then
			return nil, nil, nil
		end
		return map.world.x0 + x * 1000, map.world.y0 + y * 1000, map.world.instance
	end
	function hbd.GetPlayerWorldPosition()
		local player = ui.player
		if player then
			return player.x, player.y, player.instance
		end
		return nil, nil, nil
	end

	local pins = {}
	local function check(name, ref, icon, ...)
		if not ref then
			error(name .. ": 'ref' must not be nil", 3)
		end
		if type(icon) ~= "table" or not icon.SetPoint then
			error(name .. ": 'icon' must be a frame", 3)
		end
		for i = 1, select("#", ...) do
			if type((select(i, ...))) ~= "number" then
				error(name .. ": coordinates must be numbers", 3)
			end
		end
	end
	function pins.AddMinimapIconWorld(_, ref, icon, instance, x, y, floatOnEdge)
		check("AddMinimapIconWorld", ref, icon, instance, x, y)
		ui.minimap[icon] = { ref = ref, instance = instance, x = x, y = y, floatOnEdge = floatOnEdge }
		icon:SetParent(Minimap)
		return true
	end
	function pins.AddWorldMapIconMap(_, ref, icon, map, x, y, showFlag)
		check("AddWorldMapIconMap", ref, icon, map, x, y)
		if not hbd:GetWorldCoordinatesFromZone(x, y, map) then
			return false
		end
		ui.world[icon] = { ref = ref, map = map, x = x, y = y, flag = showFlag or 0 }
		icon:SetParent(WorldMapFrame:GetCanvas())
		icon:Show()
		return true
	end
	function pins.RemoveAllMinimapIcons(_, ref)
		for icon, record in pairs(ui.minimap) do
			if record.ref == ref then
				ui.minimap[icon] = nil
				icon:Hide()
			end
		end
	end
	function pins.RemoveAllWorldMapIcons(_, ref)
		for icon, record in pairs(ui.world) do
			if record.ref == ref then
				ui.world[icon] = nil
				icon:Hide()
			end
		end
	end
	function pins.IsMinimapIconOnEdge(_, icon)
		if not ui.minimap[icon] then
			return nil
		end
		return ui.onEdge[icon] == true
	end
	function pins.GetVectorToIcon(_, icon)
		if not (ui.minimap[icon] or ui.world[icon]) or not ui.player or not ui.vector then
			return nil, nil
		end
		return ui.vector[1], ui.vector[2]
	end
	return hbd, pins
end

local function installGlobals(opts)
	local base = CreateFrame
	CreateFrame = function(frameType, name, parent, template, ...)
		local frame = base(frameType, name, parent, template, ...)
		decorate(frame, frameType, parent)
		local s = S(frame)
		s.template = template
		if type(template) == "string" and template:find("SecureActionButtonTemplate", 1, true) then
			s.protected = true
			if type(parent) == "table" and S(parent) then
				S(parent).protectedChildren = S(parent).protectedChildren + 1
			end
		end
		return frame
	end
	decorate(UIParent, "Frame", nil)

	function InCombatLockdown()
		return ui.combat
	end
	function UnitAffectingCombat()
		return ui.combat
	end
	function UnitIsDeadOrGhost()
		return ui.dead
	end
	function IsShiftKeyDown()
		return ui.shift
	end
	function GetPlayerFacing()
		return ui.facing
	end
	function GetFileIDFromPath(path)
		return ui.files[path]
	end
	C_Texture = {
		GetAtlasInfo = function(name)
			if ui.atlases[name] then
				return { width = 16, height = 16 }
			end
		end,
	}
	C_Map = {
		GetMapInfo = function(id)
			local map = ui.maps[id]
			if map then
				return { mapID = id, name = map.name, mapType = map.mapType, parentMapID = map.parent or 0 }
			end
		end,
	}
	C_CVar = {
		GetCVar = function(name)
			return ui.cvars[name]
		end,
	}
	C_Container = {
		GetItemCooldown = function(itemID)
			local cooldown = ui.cooldowns[itemID]
			if cooldown then
				return cooldown[1], cooldown[2], cooldown[3]
			end
			return 0, 0, true
		end,
	}
	C_Item = {
		GetItemIconByID = function(itemID)
			return 100000 + itemID
		end,
		GetItemCount = function(itemID)
			return ui.items[itemID] or 0
		end,
	}
	for _, font in ipairs({
		"GameFontNormal",
		"GameFontHighlight",
		"GameFontNormalSmall",
		"GameFontHighlightSmall",
		"GameFontDisableSmall",
		"NumberFontNormal",
	}) do
		_G[font] = { name = font }
	end

	local tooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
	tooltip.lines = {}
	function tooltip.SetOwner(self, owner, anchor)
		S(self).owner, S(self).anchor = owner, anchor
		self.lines = {}
	end
	function tooltip.IsOwned(self, frame)
		return S(self).owner == frame
	end
	function tooltip.SetText(self, text)
		self.lines = { text }
	end
	function tooltip.AddLine(self, text)
		self.lines[#self.lines + 1] = text
	end
	function tooltip.SetItemByID(self, itemID)
		self.lines[#self.lines + 1] = "item:" .. itemID
	end
	function tooltip.Hide(self)
		S(self).shown, S(self).owner = false, nil
	end

	CreateFrame("Minimap", "Minimap", UIParent)

	local worldMap = CreateFrame("Frame", "WorldMapFrame", UIParent)
	local canvas = CreateFrame("Frame", nil, worldMap)
	S(canvas).level = 10
	function worldMap.GetCanvas()
		return canvas
	end
	function worldMap.GetMapID()
		return ui.worldMapID
	end
	function worldMap.AddDataProvider(self, provider)
		ui.providers[#ui.providers + 1] = provider
		provider:OnAdded(self)
	end
	function ui.setWorldMap(mapID)
		ui.worldMapID = mapID
		for _, provider in ipairs(ui.providers) do
			provider:OnMapChanged()
		end
	end

	MapCanvasDataProviderMixin = {
		OnAdded = function(self, map)
			self.owningMap = map
		end,
		GetMap = function(self)
			return self.owningMap
		end,
		OnMapChanged = function(self)
			self:RefreshAllData()
		end,
		RefreshAllData = noop,
		RemoveAllData = noop,
		OnShow = noop,
		OnHide = noop,
	}
	local function mixInto(object, ...)
		for i = 1, select("#", ...) do
			for key, value in pairs((select(i, ...))) do
				object[key] = value
			end
		end
		return object
	end
	function CreateFromMixins(...)
		return mixInto({}, ...)
	end
	Mixin = mixInto

	if not opts.noLibs then
		local hbd, pins = hereBeDragons()
		ui.hbd, ui.hbdPins = hbd, pins
		local libs = { ["HereBeDragons-2.0"] = hbd, ["HereBeDragons-Pins-2.0"] = pins }
		LibStub = setmetatable({}, {
			__call = function(_, name, silent)
				if not libs[name] and not silent then
					error("Cannot find a library instance of " .. tostring(name), 2)
				end
				return libs[name]
			end,
		})
	end
end

-- Records C_Timer.After delays and NewTicker tickers of the mock clock.
local function watchTimers()
	local after, newTicker = C_Timer.After, C_Timer.NewTicker
	C_Timer.After = function(delay, fn)
		ui.delays[#ui.delays + 1] = delay
		return after(delay, fn)
	end
	C_Timer.NewTicker = function(interval, fn)
		local ticker = newTicker(interval, fn)
		ticker.interval = interval
		ui.tickers[#ui.tickers + 1] = ticker
		return ticker
	end
end

function M.install(_, opts)
	M.uninstall()
	opts = opts or {}
	saved = {}
	for _, name in ipairs(GLOBALS) do
		saved[name] = _G[name]
	end
	if opts.bare then
		return installBare()
	end
	ui = {
		combat = false,
		dead = false,
		shift = false,
		facing = 0,
		moves = 0,
		blocked = {},
		delays = {},
		tickers = {},
		providers = {},
		minimap = {}, -- HereBeDragons minimap icons: icon -> { ref, instance, x, y, floatOnEdge }
		world = {}, -- HereBeDragons world map icons: icon -> { ref, map, x, y, flag }
		onEdge = {},
		cooldowns = {},
		items = {},
		cvars = { rotateMinimap = "0" },
		atlases = {},
		files = {},
		maps = maps(),
	}
	for _, atlas in ipairs(VERIFIED_ATLASES) do
		ui.atlases[atlas] = true
	end
	for i, path in ipairs(FILES) do
		ui.files[path] = i
	end
	installGlobals(opts)
	watchTimers()
	return ui
end

return M
