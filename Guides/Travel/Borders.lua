-- Hand-authored zone crossings for the travel graph (PLAN §3.6): `from` is the last point in one zone, `to` the first
-- in the other; every crossing works both ways. Until a crossing is learned its points carry only the uiMapID (from the
-- client's map dump, beta 1.60.1.70450) and `todo` says why: coordinates are never invented (CLAUDE.md). Core/Learn.lua
-- records the real points at ZONE_CHANGED_NEW_AREA, `tools/import_savedvars.py --merge-learned` exports them into the
-- data pack, and ns.Travel:Borders() then prefers those over the entries here.
-- An entry with `ride` is not a crossing but a boat, zeppelin or airship between the two zones (`kind` is "boat" or
-- "zeppelin", an airship is a zeppelin; `label` what the guides call it; `wait` the seconds at the dock; `waitText`,
-- `fromText`, `toText` and `verify` are words for the player; `oneWay`: only from `from` to `to` is known). Its dock
-- positions are never made up either: the tools write a `.todo` step with these words until Core/Learn.lua has recorded
-- a ride (/signpost ride zeppelin, then ride it), when the pack's record replaces the entry and the step is a `.zeppelin`.
-- ns.Travel:Rides() lists them; Borders() does not.
-- The table is a pure literal so the offline tools (tools/guide_travel.py) can read it.
local ADDON_NAME, ns = ...

ns.Travel:RegisterBorders({
	-- VERIFY(beta): every word of this ride is from beta-era fan guides and the Warcraft Wiki, nothing seen in the game
	-- (docs/FOREVER-API-NOTES.md, "Skyborne exit"): the dock, the vehicle's name, the landing spot, and whether it runs
	-- before the island's quest chain is done. Horde only; what leaves Zephras Isle for the other faction is not in here.
	{
		name = "Zephras Isle/Mulgore airship",
		from = { 2521 },
		to = { 1412 },
		side = "Horde",
		oneWay = true,
		ride = {
			kind = "zeppelin",
			label = "airship",
			wait = 450,
			waitText = "7 to 8 minutes",
			fromText = "Valanaar's southwest dock",
			toText = "Skywatcher Plateau, beside Thunder Bluff",
			verify = {
				"the dock",
				"the airship's name",
				"the landing spot",
				"whether you can board before the quest chain asks you to",
			},
		},
		todo = "docks not recorded yet: type /signpost ride zeppelin, ride it, then tools/import_savedvars.py --merge-learned",
	},
	{
		name = "Durotar/The Barrens",
		from = { 1411 },
		to = { 1413 },
		side = "both",
		todo = "not learned yet: cross on foot with Signpost loaded, then run tools/import_savedvars.py --merge-learned",
	},
	{
		name = "The Barrens/Stonetalon Mountains",
		from = { 1413 },
		to = { 1442 },
		side = "both",
		todo = "not learned yet: cross on foot with Signpost loaded, then run tools/import_savedvars.py --merge-learned",
	},
	{
		name = "The Barrens/Ashenvale",
		from = { 1413 },
		to = { 1440 },
		side = "both",
		todo = "not learned yet: cross on foot with Signpost loaded, then run tools/import_savedvars.py --merge-learned",
	},
	{
		name = "The Barrens/Thousand Needles",
		from = { 1413 },
		to = { 1441 },
		side = "both",
		todo = "not learned yet: cross on foot with Signpost loaded, then run tools/import_savedvars.py --merge-learned",
	},
	{
		name = "The Barrens/Dustwallow Marsh",
		from = { 1413 },
		to = { 1445 },
		side = "both",
		todo = "not learned yet: cross on foot with Signpost loaded, then run tools/import_savedvars.py --merge-learned",
	},
})
