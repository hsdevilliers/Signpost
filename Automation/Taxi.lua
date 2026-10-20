-- Automation: flights (PLAN §3.4). Off by default (`taxi`). On TAXIMAP_OPENED during a `.fly <node>` step, finds the
-- node by name and takes it. Both client API shapes exist (FOREVER-API-NOTES): the index form
-- (NumTaxiNodes/TaxiNodeName(i)/TakeTaxiNode(i)) is tried first, then the node ID form (C_TaxiMap.GetAllTaxiNodes).
local ADDON_NAME, ns = ...
local Util = ns.Util
local Automation = ns.Automation

local Taxi = {}
Automation.Taxi = Taxi

local RETRY = 0.3 -- the node list can be empty in the first moment after TAXIMAP_OPENED

local function normalize(name)
	if type(name) ~= "string" or Util.IsSecret(name) then
		return nil
	end
	return (name:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

local function short(name)
	return (name:match("^([^,]+)")) or name
end

-- The open flight map's node called `wanted` (full client name, or the part before the comma), or nil. Not the node
-- we stand at, and not one the map lists as unknown.
function Taxi.FindNode(nodes, wanted)
	wanted = normalize(wanted)
	if not wanted then
		return nil
	end
	local found
	for _, node in ipairs(nodes) do
		local name = normalize(node.name)
		if name and not name:find("^zz") and not node.current and node.known ~= false then
			if name == wanted then
				return node
			end
			if not found and short(name) == short(wanted) then
				found = node
			end
		end
	end
	return found
end

-- Takes the node. Index form first (the node was read with TaxiNodeName(i): `index`), then the node ID; a node read
-- from C_TaxiMap has an ID (and a slot index) and no old-style listing.
-- VERIFY(beta): which TakeTaxiNode argument works on Forever (index or nodeID) and that it is not protected.
function Taxi.Take(node, classic)
	local attempts = {}
	if classic then
		attempts[#attempts + 1] = node.index
	else
		attempts[#attempts + 1] = node.id
		attempts[#attempts + 1] = node.index
	end
	for _, argument in ipairs(attempts) do
		if type(argument) == "number" and Automation.Try(TakeTaxiNode, argument) then
			return true
		end
	end
	return false
end

local function classicShape()
	local count = Util.Call(NumTaxiNodes)
	return type(count) == "number" and not Util.IsSecret(count) and count > 0
end

function Taxi:Run()
	if not Automation:Allowed("taxi") or not self.open then
		return false
	end
	local wanted
	for _, entry in ipairs(Automation:Directives("fly")) do
		if not Automation:Satisfied(entry) then
			wanted = entry.args.name
			break
		end
	end
	if not wanted or not ns.Context then
		return false
	end
	local nodes = ns.Context:ReadTaxiMap()
	if #nodes == 0 then
		return false
	end
	local node = Taxi.FindNode(nodes, wanted)
	if not node then
		return true -- the map is read: nothing to take here
	end
	self.open = false -- one flight per opening of the map
	Taxi.Take(node, classicShape())
	return true
end

ns.Events:Register("TAXIMAP_OPENED", function()
	Taxi.open = true
	if not Taxi:Run() and Taxi.open then
		-- an empty list: read it once more shortly (Engine/Context.lua does the same for its own reading)
		C_Timer.After(RETRY, function()
			ns.SafeCall(function()
				Taxi:Run()
			end)
		end)
	end
end)

ns.Events:Register("TAXIMAP_CLOSED", function()
	Taxi.open = false
end)
