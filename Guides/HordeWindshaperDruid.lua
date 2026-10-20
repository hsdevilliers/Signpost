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
#include windshaper-barrens-12-20
step
  .todo "Druid forms at 14-16 (Cure Poison, Aquatic Form): the Tauren chains are not open to a Windshaper and nothing in the data says where it learns them; check with your trainer in Thunder Bluff"
#include windshaper-cat-form-20
]],
})
