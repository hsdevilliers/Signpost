local ADDON_NAME, ns = ...

ns.Guides:Register({
	id = "horde-tauren-druid",
	name = "Tauren Druid (hardcore)",
	faction = "Horde",
	races = { "Tauren" },
	classes = { "DRUID" },
	levels = { 1, 20 },
	text = [[
#guide Tauren Druid, hardcore route
#include mulgore-1-12
#include druid-bear-form-10
#include barrens-10-20
#include druid-forms-14-20
#skipquest 5926 >> alternative start of the same chain; 5928 (Thunder Bluff) is routed
#skipquest 5927 >> alternative start of the same chain; 5928 (Thunder Bluff) is routed
]],
})
