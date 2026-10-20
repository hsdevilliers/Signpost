local ADDON_NAME, ns = ...

ns.Guides:Register({
	id = "horde-windshaper-druid",
	name = "Windshaper Druid (hardcore)",
	faction = "Horde",
	races = { "Skyborne" },
	classes = { "DRUID" },
	levels = { 1, 20 },
	text = [[
#guide Windshaper Druid, hardcore route
#include zephras-isle-1-12
#include windshaper-bear-form-10
step
  .todo "After Zephras Isle: where a Windshaper levels from 12 to 20 is not in the data yet; do the quests that suit your level, then go on at the Cat Form chain at 20"
#include windshaper-cat-form-20
]],
})
