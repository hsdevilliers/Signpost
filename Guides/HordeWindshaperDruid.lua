local ADDON_NAME, ns = ...

ns.Guides:Register({
	id = "horde-windshaper-druid",
	name = "Skyborne Druid (HARDCORE)",
	faction = "Horde",
	races = { "Skyborne" },
	classes = { "DRUID" },
	levels = { 1, 30 },
	text = [[
#guide Skyborne Druid (HARDCORE)
#chapter 1 Read this first
step
  .note HARDCORE route made from quest data (QuestieDB's Classic baseline plus its Forever layers), not yet from play. It leaves out dungeons, group quests, escorts and elite or named targets the data can show, but it cannot know every danger: heal up, keep an escape ready and skip a step that looks too hard.
  .note Leaving Zephras Isle is unverified. In the quest data the island story ends with What Comes Next and The Earthen Ring (it starts with Ayessa Dawnsinger on the island and ends with Alaana Stormwalker in Mulgore), and this route leaves the island at level 12 without them. If you cannot leave, finish that chain first.
  .note Not in the data: where a Windshaper learns Cure Poison (14) and Aquatic Form (16), because the Tauren quest chains are not open to a Skyborne (ask your druid trainer), and how to reach Moonglade for Cat Form at level 20.
#skipquest 235 >> alternative to quest 6382, which is routed
#skipquest 742 >> alternative to quest 6382, which is routed
#skipquest 746 >> HARDCORE: the forge is hard to reach without a group
#skipquest 827 >> HARDCORE: cave with respawning enemies and a hard-hitting boss; kills a large share of players
#skipquest 851 >> HARDCORE: named Kolkar target with no position or elite flag in the data
#skipquest 852 >> HARDCORE: named Burning Blade target with no elite flag in the data
#skipquest 863 >> HARDCORE: escort quest (Wizzlecrank's Shredder); two goblins spawn near the end
#skipquest 891 >> HARDCORE: kills Captain Fairmount and two cannoneers inside Northwatch Hold; the data carries no elite flag for them
#skipquest 898 >> HARDCORE: escort quest (Gilthares); clear Northwatch's mobs first and two goblins spawn near the end
#skipquest 4021 >> HARDCORE: the banner is guarded by Warlord Krom'zar, an elite the data does not link to the quest
#skipquest 8368 >> battleground (PvP) quest, not leveling content
#skipquest 8426 >> battleground (PvP) quest, not leveling content
#skipquest 94493 >> alternative to quest 94484, which is routed
#skipquest 96652 >> alternative to quest 96638, which is routed
#skipquest 96656 >> alternative to quest 96638, which is routed
#skipquest 96659 >> alternative to quest 96638, which is routed
#include windshaper-druid-01-zephras-isle
#include windshaper-druid-02-mulgore
#include windshaper-druid-03-thunder-bluff
#include windshaper-druid-04-mulgore
#include windshaper-druid-05-the-barrens
#include windshaper-druid-06-orgrimmar
#include windshaper-druid-07-the-barrens
#include windshaper-druid-08-undercity
#include windshaper-druid-09-the-barrens
#include windshaper-druid-10-moonglade
#include windshaper-druid-11-stonetalon-mountains
#include windshaper-druid-12-the-barrens
#include windshaper-druid-13-stonetalon-mountains
#include windshaper-druid-14-ashenvale
#include windshaper-druid-15-silverpine-forest
#include windshaper-druid-16-hillsbrad-foothills
#include windshaper-druid-17-tirisfal-glades
#include windshaper-druid-18-stonetalon-mountains
#include windshaper-druid-19-thunder-bluff
#include windshaper-druid-20-the-barrens
#include windshaper-druid-21-thousand-needles
#include windshaper-druid-22-the-barrens
#include windshaper-druid-23-ashenvale
]],
})
