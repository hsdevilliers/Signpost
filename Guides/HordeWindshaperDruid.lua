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
  .note Leaving Zephras Isle (VERIFY(beta): from the quest data and fan guides, nothing seen in the game): this route finishes the island story first. It ends with the finale at the Shrine of Akir (a scripted boss fight: go in healed and buffed), then The Fate of Zephras, What Comes Next and The Earthen Ring from Ayessa Dawnsinger, and you leave by airship from Valanaar's southwest dock (a wait of about 7 to 8 minutes) for Skywatcher Plateau beside Thunder Bluff. If the airship is not where this says, trust what you see.
  .note Not in the data: where a Windshaper learns Cure Poison (14) and Aquatic Form (16), because the Tauren quest chains are not open to a Skyborne (ask your druid trainer), and how to reach Moonglade (the Cat Form quests open at level 20; this route goes there once, near level 25).
#skipquest 235 >> alternative to quest 6382, which is routed
#skipquest 354 >> not finished by this route: its objectives are 149 s of walking away (the route walks up to 30 s for one)
#skipquest 358 >> not finished by this route: its objectives are 60 s of walking away (the route walks up to 30 s for one)
#skipquest 421 >> not finished by this route: its objectives are 74 s of walking away (the route walks up to 30 s for one)
#skipquest 428 >> not finished by this route: it is handed in 125 s of walking away and the route does not pass there
#skipquest 435 >> HARDCORE: escort quest (Deathstalker Erland is attacked on the way); the data has no objective for it, so the planner took it for a delivery
#skipquest 444 >> not finished by this route: it is handed in 288 s of walking away and the route does not pass there
#skipquest 447 >> not finished by this route: its objectives are 109 s of walking away (the route walks up to 30 s for one)
#skipquest 742 >> alternative to quest 6382, which is routed
#skipquest 744 >> not finished by this route: its objectives are 54 s of walking away (the route walks up to 30 s for one)
#skipquest 746 >> HARDCORE: the forge is hard to reach without a group
#skipquest 747 >> not finished by this route: its objectives are 42 s of walking away (the route walks up to 30 s for one)
#skipquest 752 >> not finished by this route: it is handed in 50 s of walking away and the route does not pass there
#skipquest 827 >> HARDCORE: cave with respawning enemies and a hard-hitting boss; kills a large share of players
#skipquest 850 >> HARDCORE: kills the named Kolkar leader Barak Kodobane, a target the data does not flag as elite
#skipquest 851 >> HARDCORE: named Kolkar target with no position or elite flag in the data
#skipquest 852 >> HARDCORE: named Burning Blade target with no elite flag in the data
#skipquest 863 >> HARDCORE: escort quest (Wizzlecrank's Shredder); two goblins spawn near the end
#skipquest 875 >> not finished by this route: its objectives are 232 s of walking away (the route walks up to 30 s for one)
#skipquest 879 >> HARDCORE: kills the named Kuz, Nak and Lok Orcbane, targets the data does not flag as elite
#skipquest 891 >> HARDCORE: kills Captain Fairmount and two cannoneers inside Northwatch Hold; the data carries no elite flag for them
#skipquest 894 >> not finished by this route: it is handed in 290 s of walking away and the route does not pass there
#skipquest 898 >> HARDCORE: escort quest (Gilthares); clear Northwatch's mobs first and two goblins spawn near the end
#skipquest 1013 >> HARDCORE: dungeon quest (Shadowfang Keep): the book lies inside the dungeon
#skipquest 1150 >> HARDCORE: kills the named Grenka Bloodscreech, a target with no position and no elite flag in the data
#skipquest 1486 >> HARDCORE: Wailing Caverns quest: the hides drop from elite Deviate creatures (Coiler, Stinglash, Creeper)
#skipquest 1491 >> HARDCORE: Wailing Caverns quest: the Wailing Essence drops from elite ectoplasms
#skipquest 4021 >> HARDCORE: the banner is guarded by Warlord Krom'zar, an elite the data does not link to the quest
#skipquest 4770 >> HARDCORE: escort quest (Pao'ka Swiftmountain, Thousand Needles)
#skipquest 4904 >> HARDCORE: escort quest (Lakota Windsong, Thousand Needles)
#skipquest 5147 >> HARDCORE: bounty on Arnak Grimtotem, a named Grimtotem in his camp, a target the data does not flag as elite
#skipquest 5726 >> HARDCORE: the Lieutenant's Insignia drops from the Burning Blade at Skull Rock (near 53,9); the chain goes on into Ragefire Chasm to kill two elites (5728)
#skipquest 6482 >> HARDCORE: escort quest (Ruul Snowhoof, Ashenvale)
#skipquest 6523 >> HARDCORE: escort quest (Kaya Flathoof, Stonetalon Mountains)
#skipquest 6544 >> HARDCORE: probably an escort (Torek's assault on Silverwing Outpost, Ashenvale)
#skipquest 6562 >> HARDCORE: leads only to The Essence of Aku'Mai, a Blackfathom Deeps dungeon quest
#skipquest 6563 >> HARDCORE: dungeon quest (the Sapphires of Aku'Mai lie inside Blackfathom Deeps)
#skipquest 6621 >> HARDCORE: kills Chief Murgut, a named furbolg chief the data places nowhere and does not flag as elite
#skipquest 6641 >> HARDCORE: escort quest (Muglash walks to Vorsha through Ashenvale and enemies attack on the way)
#skipquest 6921 >> HARDCORE: dungeon quest (Blackfathom Deeps): the Fathom Core lies inside the dungeon
#skipquest 8368 >> battleground (PvP) quest, not leveling content
#skipquest 8426 >> battleground (PvP) quest, not leveling content
#skipquest 65601 >> probably a Warlock class quest (it starts with Cazul in Orgrimmar, who gave the Orc Warlock's quests in Classic): the game should not offer it to other classes (unverified)
#skipquest 76156 >> not finished by this route: its objectives are 183 s of walking away (the route walks up to 30 s for one)
#skipquest 78149 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 79007 >> not finished by this route: it is handed in 857 s of walking away and the route does not pass there
#skipquest 79094 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 91921 >> not finished by this route: it is handed in 130 s of walking away and the route does not pass there
#skipquest 92422 >> HARDCORE: kills Rath'mael, a named creature new in Forever (Tirisfal Glades); whether it is elite is not known
#skipquest 92462 >> not finished by this route: its work is 20 s away and pays 2.07 XP/s against the route's 2.93 (71%); completeness 0.71 or less would finish it
#skipquest 92515 >> not finished by this route: its objectives are 33 s of walking away (the route walks up to 30 s for one)
#skipquest 92516 >> not finished by this route: its objectives are 104 s of walking away (the route walks up to 30 s for one)
#skipquest 92553 >> not finished by this route: its objectives are 35 s of walking away (the route walks up to 30 s for one)
#skipquest 92598 >> not finished by this route: its objectives are 49 s of walking away (the route walks up to 30 s for one)
#skipquest 92679 >> not finished by this route: its objectives are 131 s of walking away (the route walks up to 30 s for one)
#skipquest 92706 >> HARDCORE: bounty on Bruuz, a named creature new in Forever (The Barrens); whether it is elite is not known
#skipquest 93318 >> not finished by this route: its objectives are 37 s of walking away (the route walks up to 30 s for one)
#skipquest 93951 >> not finished by this route: its objectives are 72 s of walking away (the route walks up to 30 s for one)
#skipquest 94493 >> alternative to quest 94484, which is routed
#skipquest 95314 >> not finished by this route: its objectives are 324 s of walking away (the route walks up to 30 s for one)
#skipquest 96101 >> alternative to quest 96605, which is routed
#skipquest 96241 >> HARDCORE: collects toxin samples at the entrance of the new Gloomrise nest in northern Mulgore (a level 30 quest); whether the creatures there are elite is not known
#skipquest 96259 >> HARDCORE: kills Gloomrise creatures in the new Gloomrise nest in northern Mulgore (a level 30 quest); whether they are elite is not known
#skipquest 96260 >> HARDCORE: needs silk from Gloomrise spinners in the new Gloomrise nest in northern Mulgore (a level 30 quest); whether they are elite is not known
#skipquest 96261 >> HARDCORE: kills Broodmother Valraxx, the named boss of the new Gloomrise nest in northern Mulgore (a level 31 quest); whether she is elite is not known
#skipquest 96604 >> alternative to quest 96605, which is routed
#skipquest 96607 >> alternative to quest 96605, which is routed
#skipquest 96646 >> alternative to quest 96661, which is routed
#skipquest 96652 >> alternative to quest 96638, which is routed
#skipquest 96655 >> alternative to quest 96661, which is routed
#skipquest 96656 >> alternative to quest 96638, which is routed
#skipquest 96658 >> alternative to quest 96661, which is routed
#skipquest 96659 >> alternative to quest 96638, which is routed
#skipquest 96895 >> not finished by this route: it is handed in 44 s of walking away and the route does not pass there
#skipquest 97003 >> HARDCORE: kills Chol'aruk the Ravener, a named creature new in Forever (The Barrens); whether it is elite is not known
#skipquest 97253 >> not finished by this route: its objectives are 87 s of walking away (the route walks up to 30 s for one)
#skipquest 98251 >> probably a Warlock class quest (Va'xug Firefure in Ashenvale also gives A Void Path, which ends at the Eye of Kilrogg): the game should not offer it to other classes (unverified)
#skipquest 98252 >> probably a Warlock class quest (it ends at the Eye of Kilrogg, the Warlock spell of that name in Classic): the game should not offer it to other classes (unverified)
#skipquest 98430 >> not finished by this route: its objectives are 36 s of walking away (the route walks up to 30 s for one)
#skipquest 99080 >> not finished by this route: its objectives are 144 s of walking away (the route walks up to 30 s for one)
#skipquest 99108 >> probably a Warrior class quest (it starts with Krang Stonehoof, the Tauren Warrior trainer of Bloodhoof Village): the game should not offer it to other classes (unverified)
#skipquest 99134 >> not finished by this route: its objectives are 48 s of walking away (the route walks up to 30 s for one)
#skipquest 99141 >> not finished by this route: its objectives are 114 s of walking away (the route walks up to 30 s for one)
#include windshaper-druid-01-zephras-isle
#include windshaper-druid-02-thunder-bluff
#include windshaper-druid-03-orgrimmar
#include windshaper-druid-04-the-barrens
#include windshaper-druid-05-undercity
#include windshaper-druid-06-silverpine-forest
#include windshaper-druid-07-hillsbrad-foothills
#include windshaper-druid-08-ashenvale
#include windshaper-druid-09-stonetalon-mountains
#include windshaper-druid-10-thunder-bluff
#include windshaper-druid-11-moonglade
#include windshaper-druid-12-the-barrens
#include windshaper-druid-13-thousand-needles
#include windshaper-druid-14-the-barrens
#include windshaper-druid-15-stonetalon-mountains
#include windshaper-druid-16-ashenvale
#include windshaper-druid-17-mulgore
#include windshaper-druid-18-the-barrens
#include windshaper-druid-19-thousand-needles
]],
})
