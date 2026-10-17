-- Shared helpers: chat output, defensive API calls, secret-value guards, SavedVariables-safe copies, position and
-- profession snapshots, and a JSON encoder for /signpost export.
local ADDON_NAME, ns = ...

local Util = {}
ns.Util = Util

local CHAT_PREFIX = "|cff33ff99" .. ADDON_NAME .. "|r: "

function Util.Print(text, ...)
	if select("#", ...) > 0 then
		text = string.format(text, ...)
	end
	DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. text)
end

function Util.Pack(...)
	return { n = select("#", ...), ... }
end

local function passResults(ok, ...)
	if ok then
		return ...
	end
end

-- Calls fn(...) and returns its results; returns nothing if fn is not a function or raises an error. For APIs that
-- may be missing or behave differently on this client.
function Util.Call(fn, ...)
	if type(fn) == "function" then
		return passResults(pcall(fn, ...))
	end
end

-- Looks up a dotted global name ("C_Map.GetMapInfo") without erroring on a missing namespace.
function Util.Resolve(path)
	local value = _G
	for part in string.gmatch(path, "[^%.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end
	return value
end

-- Secret values (on Forever e.g. UnitHealth and UnitPower) error on arithmetic and comparison; check before touching
-- them. issecretvalue exists on Forever (verified on beta 1.60.1.70450).
function Util.IsSecret(value)
	local check = issecretvalue
	return check ~= nil and check(value) and true or false
end

-- Rounds value * (scale or 1) to `places` decimals. Returns nil for anything that is not a plain number.
function Util.Round(value, places, scale)
	if Util.IsSecret(value) or type(value) ~= "number" then
		return nil
	end
	local mult = 10 ^ (places or 0)
	local ok, result = pcall(function()
		return math.floor(value * (scale or 1) * mult + 0.5) / mult
	end)
	if ok then
		return result
	end
end

function Util.CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and Util.CopyTable(value) or value
	end
	return copy
end

local SANITIZE_MAX_DEPTH = 8
local SANITIZE_MAX_STRING = 500

local function plainString(value)
	if #value > SANITIZE_MAX_STRING then
		return value:sub(1, SANITIZE_MAX_STRING) .. "..."
	end
	return value
end

local function plainNumber(value)
	if value ~= value or value == math.huge or value == -math.huge then
		return tostring(value)
	end
	return value
end

-- Copies a value into plain data that SavedVariables can hold: no functions, userdata, frames or secret values;
-- NaN/inf become strings; long strings are cut; tables nested deeper than SANITIZE_MAX_DEPTH are dropped.
-- Strings and numbers are handled under pcall: a secret value that IsSecret cannot detect errors there instead of
-- in the caller.
function Util.Sanitize(value, depth)
	if Util.IsSecret(value) then
		return "<secret>"
	end
	local kind = type(value)
	if kind == "string" or kind == "number" then
		local ok, plain = pcall(kind == "string" and plainString or plainNumber, value)
		if ok then
			return plain
		end
		return "<secret>"
	elseif kind == "boolean" then
		return value
	elseif kind == "table" then
		depth = depth or 0
		-- Frames are tables carrying their userdata handle at [0].
		if depth >= SANITIZE_MAX_DEPTH or type(rawget(value, 0)) == "userdata" then
			return nil
		end
		local copy = {}
		for key, item in pairs(value) do
			local keyKind = type(key)
			if (keyKind == "string" or keyKind == "number") and not Util.IsSecret(key) then
				copy[key] = Util.Sanitize(item, depth + 1)
			end
		end
		return copy
	end
	return nil
end

-- "Creature-0-1465-1-47-3100-00004F2B3C" -> 3100. Nil for players and anything without a creature/object ID.
function Util.NpcIDFromGUID(guid)
	if Util.IsSecret(guid) or type(guid) ~= "string" then
		return nil
	end
	local kind, id = Util.Call(string.match, guid, "^([^-]+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-([^-]+)")
	if kind == "Creature" or kind == "Vehicle" or kind == "Pet" or kind == "GameObject" then
		return tonumber(id)
	end
end

-- The map and its ancestors up to the root: { { id, name, type }, ... }.
function Util.MapChain(mapID)
	local chain, seen = {}, {}
	while type(mapID) == "number" and mapID > 0 and not seen[mapID] do
		seen[mapID] = true
		local info = Util.Call(C_Map and C_Map.GetMapInfo, mapID)
		if not info then
			break
		end
		chain[#chain + 1] = { id = info.mapID, name = info.name, type = info.mapType }
		mapID = info.parentMapID
	end
	return chain
end

-- Everything the client says about where the player is. Missing APIs and nil returns (instances, transports) are
-- tolerated; x/y are percent of the map, wx/wy/wz world yards.
function Util.PlayerPosition(withChain)
	local map = C_Map or {}
	local pos = { t = Util.Round(GetTime(), 1) }
	local mapID = Util.Call(map.GetBestMapForUnit, "player")
	pos.map = mapID
	if mapID then
		local point = Util.Call(map.GetPlayerMapPosition, mapID, "player")
		if point then
			local x, y = Util.Call(point.GetXY, point)
			pos.x, pos.y = Util.Round(x, 2, 100), Util.Round(y, 2, 100)
		end
	end
	local wy, wx, wz, instance = Util.Call(UnitPosition, "player")
	pos.wx, pos.wy, pos.wz, pos.instance = Util.Round(wx, 1), Util.Round(wy, 1), Util.Round(wz, 1), instance
	pos.taxi = Util.Call(UnitOnTaxi, "player")
	pos.zone = Util.Call(GetZoneText)
	pos.subzone = Util.Call(GetSubZoneText)
	pos.realZone = Util.Call(GetRealZoneText)
	pos.minimapZone = Util.Call(GetMinimapZoneText)
	pos.instanceType = select(2, Util.Call(IsInInstance))
	pos.indoors = Util.Call(IsIndoors)
	if withChain then
		pos.chain = Util.MapChain(mapID)
	end
	return pos
end

-- The professions this character has learned, as GetProfessions/GetProfessionInfo report them.
function Util.LearnedProfessions()
	local result = { slots = Util.Pack(Util.Call(GetProfessions)), info = {} }
	for i = 1, result.slots.n do
		local index = result.slots[i]
		if index then
			result.info[i] = Util.Pack(Util.Call(GetProfessionInfo, index))
		end
	end
	return result
end

-- Every profession the client defines, primary and secondary, without naming any (the profession seam, PLAN §3.8):
-- Enum.Profession -> skill line -> profession info, plus each skill line GetAllProfessionTradeSkillLines lists.
-- VERIFY(beta): C_TradeSkillUI.GetProfessionSkillLineID exists on Forever (probe: professions.byEnum).
function Util.Professions()
	local result = Util.LearnedProfessions()
	local tradeSkill = C_TradeSkillUI
	if not tradeSkill then
		return result
	end
	result.byEnum = {}
	local professions = Enum and Enum.Profession
	if type(professions) == "table" then
		for key, value in pairs(professions) do
			local skillLine = Util.Call(tradeSkill.GetProfessionSkillLineID, value)
			result.byEnum[key] = {
				enum = value,
				skillLine = skillLine,
				info = skillLine and Util.Call(tradeSkill.GetProfessionInfoBySkillLineID, skillLine),
			}
		end
	end
	result.tradeSkillLines = Util.Call(tradeSkill.GetAllProfessionTradeSkillLines)
	result.bySkillLine = {}
	if type(result.tradeSkillLines) == "table" then
		for _, skillLine in ipairs(result.tradeSkillLines) do
			result.bySkillLine[skillLine] = Util.Call(tradeSkill.GetProfessionInfoBySkillLineID, skillLine)
		end
	end
	return result
end

-- JSON ----------------------------------------------------------------------------------------------------------------

local JSON_ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function jsonString(text)
	return '"'
		.. text:gsub('[%c"\\]', function(char)
			return JSON_ESCAPES[char] or string.format("\\u%04x", char:byte())
		end)
		.. '"'
end

local function arrayLength(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	if count == #tbl then
		return count
	end
end

local MAX_JSON_DEPTH = 50

local function encode(value, indent, depth, out)
	local kind = type(value)
	if kind == "string" then
		out[#out + 1] = jsonString(value)
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			out[#out + 1] = "null"
		elseif value == math.floor(value) and math.abs(value) < 1e15 then
			out[#out + 1] = string.format("%d", value)
		else
			out[#out + 1] = string.format("%.14g", value)
		end
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "table" and depth < MAX_JSON_DEPTH then
		local inner = indent and ("\n" .. string.rep(indent, depth + 1)) or ""
		local outer = indent and ("\n" .. string.rep(indent, depth)) or ""
		local length = arrayLength(value)
		if length == 0 then
			out[#out + 1] = "[]"
		elseif length then
			out[#out + 1] = "["
			for i = 1, length do
				out[#out + 1] = (i > 1 and "," or "") .. inner
				encode(value[i], indent, depth + 1, out)
			end
			out[#out + 1] = outer .. "]"
		else
			local keys = {}
			for key in pairs(value) do
				keys[#keys + 1] = key
			end
			table.sort(keys, function(a, b)
				return tostring(a) < tostring(b)
			end)
			out[#out + 1] = "{"
			for i, key in ipairs(keys) do
				out[#out + 1] = (i > 1 and "," or "") .. inner .. jsonString(tostring(key)) .. (indent and ": " or ":")
				encode(value[key], indent, depth + 1, out)
			end
			out[#out + 1] = outer .. "}"
		end
	else
		out[#out + 1] = "null"
	end
end

-- Encodes plain data as JSON (object keys sorted). `indent` (e.g. "  ") pretty-prints.
function Util.ToJSON(value, indent)
	local out = {}
	encode(value, indent, 0, out)
	return table.concat(out)
end
