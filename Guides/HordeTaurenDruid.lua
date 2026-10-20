local ADDON_NAME, ns = ...

ns.Guides:Register({
	id = "horde-tauren-druid",
	name = "Tauren Druid (hardcore)",
	faction = "Horde",
	races = { "Tauren" },
	classes = { "DRUID" },
	levels = { 1, 12 },
	text = [[
#guide Tauren Druid, hardcore route
#include mulgore-1-12
#skipquest 5926 >> alternative start of the same chain; 5928 (Thunder Bluff) is routed
#skipquest 5927 >> alternative start of the same chain; 5928 (Thunder Bluff) is routed
#skipquest 5922 >> Moonglade is a long trip from Mulgore: routed in a later chapter once the route passes there (VERIFY)
#skipquest 5930 >> part of the Moonglade trip, see 5922
#skipquest 5932 >> part of the Moonglade trip, see 5922
#skipquest 6002 >> end of the Moonglade chain (summons Lunaclaw), see 5922
]],
})
