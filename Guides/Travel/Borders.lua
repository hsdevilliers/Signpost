-- Hand-authored zone crossings for the travel graph (PLAN §3.6): `from` is the last point in one zone, `to` the first
-- in the other; every crossing works both ways. Until a crossing is learned its points carry only the uiMapID (from the
-- client's map dump, beta 1.60.1.70450) and `todo` says why: coordinates are never invented (CLAUDE.md). Core/Learn.lua
-- records the real points at ZONE_CHANGED_NEW_AREA, `tools/import_savedvars.py --merge-learned` exports them into the
-- data pack, and ns.Travel:Borders() then prefers those over the entries here.
-- The table is a pure literal so the offline tools (tools/guide_travel.py) can read it.
local ADDON_NAME, ns = ...

ns.Travel:RegisterBorders({
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
