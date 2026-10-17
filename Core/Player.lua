-- ns.Player: the only place the player's class, race and faction are read. Everything else uses these fields, so
-- no module outside Classes/ and Guides/ ever names a class, race or faction.
-- Phase 2 adds professions and the guide's profession-mismatch notice.
local ADDON_NAME, ns = ...

local Player = {}
ns.Player = Player

function Player:Refresh()
	self.className, self.classFile, self.classID = UnitClass("player")
	self.classBase = UnitClassBase and UnitClassBase("player")
	self.raceName, self.raceFile, self.raceID = UnitRace("player")
	self.faction, self.factionName = UnitFactionGroup("player")
	self.level = UnitLevel("player")
end

ns.Events:Register("PLAYER_LOGIN", function()
	Player:Refresh()
end)

ns.Events:Register("PLAYER_LEVEL_UP", function(_, level)
	Player.level = level
end)
