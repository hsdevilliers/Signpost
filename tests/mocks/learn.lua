-- A scriptable client for the Core/Learn.lua specs: the player's position, the unit being talked to, and what the
-- trainer, merchant and taxi windows list. install(G) sets the globals Learn reads and returns the `world` table the
-- spec edits; uninstall(G) removes them again so no other spec sees them.
local M = {}

local GLOBALS = {
	"C_Map",
	"C_TaxiMap",
	"C_TooltipInfo",
	"C_TradeSkillUI",
	"Enum",
	"GetMerchantItemID",
	"GetMerchantItemLink",
	"GetMerchantNumItems",
	"GetNumTrainerServices",
	"GetQuestID",
	"GetTrainerServiceSkillLine",
	"GetUnitSpeed",
	"IsInInstance",
	"IsTradeskillTrainer",
	"NumTaxiNodes",
	"TaxiNodeGetType",
	"TaxiNodeName",
	"UnitGUID",
	"UnitName",
	"UnitOnTaxi",
	"UnitPosition",
	"issecretvalue",
}

function M.install(G)
	local world = {
		-- where the player is: map percent as the client reports it (0-1), world yards, instance, taxi, own speed
		map = 1411,
		x = 0.5,
		y = 0.5,
		wx = 0,
		wy = 0,
		instance = 1,
		instanceType = "none",
		taxi = false,
		speed = 7,
		maps = {}, -- uiMapID -> C_Map.GetMapInfo result
		units = {}, -- unit -> { guid = ..., name = ... }
		questID = 0, -- GetQuestID() in the open quest dialog
		services = {}, -- trainer services: { id = spellID, type = tooltip type, skill = skill line name } or false
		tradeskill = false,
		merchant = {}, -- merchant items: { id = itemID } or { link = itemLink }
		taxiNodes = {}, -- the taxi frame's nodes: { name = ..., type = "CURRENT" | "REACHABLE" | ... }
		flightNodes = nil, -- C_TaxiMap.GetAllTaxiNodes result
	}

	G.C_Map = {
		GetBestMapForUnit = function()
			return world.map
		end,
		GetPlayerMapPosition = function()
			if world.x then
				return {
					GetXY = function()
						return world.x, world.y
					end,
				}
			end
		end,
		GetMapInfo = function(mapID)
			return world.maps[mapID]
		end,
	}
	G.UnitPosition = function()
		if world.wx then
			return world.wy, world.wx, 0, world.instance
		end
	end
	G.UnitOnTaxi = function()
		return world.taxi
	end
	G.GetUnitSpeed = function()
		return world.speed
	end
	G.IsInInstance = function()
		return world.instanceType ~= "none", world.instanceType
	end
	G.UnitGUID = function(unit)
		local info = world.units[unit]
		return info and info.guid
	end
	G.UnitName = function(unit)
		local info = world.units[unit]
		return info and info.name
	end
	G.GetQuestID = function()
		return world.questID
	end

	G.C_TooltipInfo = {
		GetTrainerService = function(index)
			local service = world.services[index]
			if service then
				return { type = service.type or 1, id = service.id }
			end
		end,
	}
	G.GetNumTrainerServices = function()
		return #world.services
	end
	G.GetTrainerServiceSkillLine = function(index)
		local service = world.services[index]
		return service and service.skill
	end
	G.IsTradeskillTrainer = function()
		return world.tradeskill
	end

	G.GetMerchantNumItems = function()
		return #world.merchant
	end
	G.GetMerchantItemID = function(index)
		local item = world.merchant[index]
		return item and item.id
	end
	G.GetMerchantItemLink = function(index)
		local item = world.merchant[index]
		return item and item.link
	end

	G.NumTaxiNodes = function()
		return #world.taxiNodes
	end
	G.TaxiNodeName = function(index)
		local node = world.taxiNodes[index]
		return node and node.name
	end
	G.TaxiNodeGetType = function(index)
		local node = world.taxiNodes[index]
		return node and node.type
	end
	G.C_TaxiMap = {
		GetAllTaxiNodes = function()
			return world.flightNodes
		end,
	}

	G.Enum = { TooltipDataType = { Spell = 1 }, FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 } }
	return world
end

function M.uninstall(G)
	for _, name in ipairs(GLOBALS) do
		G[name] = nil
	end
end

return M
