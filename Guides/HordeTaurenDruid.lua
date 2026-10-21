local ADDON_NAME, ns = ...

ns.Guides:Register({
	id = "horde-tauren-druid",
	name = "Tauren Druid (HARDCORE)",
	faction = "Horde",
	races = { "Tauren" },
	classes = { "DRUID" },
	levels = { 1, 30 },
	text = [[
#guide Tauren Druid (HARDCORE)
#skipquest 235 >> alternative to quest 6382, which is routed
#skipquest 435 >> HARDCORE: escort quest (Deathstalker Erland is attacked on the way); the data has no objective for it, so the planner took it for a delivery
#skipquest 742 >> alternative to quest 6382, which is routed
#skipquest 746 >> HARDCORE: the forge is hard to reach without a group
#skipquest 765 >> not finished by this route: its objectives are 104 s of walking away (the route walks up to 30 s for one)
#skipquest 771 >> not finished by this route: its objectives are 60 s of walking away (the route walks up to 30 s for one)
#skipquest 827 >> HARDCORE: cave with respawning enemies and a hard-hitting boss; kills a large share of players
#skipquest 850 >> HARDCORE: kills the named Kolkar leader Barak Kodobane, a target the data does not flag as elite
#skipquest 851 >> HARDCORE: named Kolkar target with no position or elite flag in the data
#skipquest 852 >> HARDCORE: named Burning Blade target with no elite flag in the data
#skipquest 863 >> HARDCORE: escort quest (Wizzlecrank's Shredder); two goblins spawn near the end
#skipquest 879 >> HARDCORE: kills the named Kuz, Nak and Lok Orcbane, targets the data does not flag as elite
#skipquest 891 >> HARDCORE: kills Captain Fairmount and two cannoneers inside Northwatch Hold; the data carries no elite flag for them
#skipquest 898 >> HARDCORE: escort quest (Gilthares); clear Northwatch's mobs first and two goblins spawn near the end
#skipquest 1013 >> HARDCORE: dungeon quest (Shadowfang Keep): the book lies inside the dungeon
#skipquest 1150 >> HARDCORE: kills the named Grenka Bloodscreech, a target with no position and no elite flag in the data
#skipquest 1486 >> HARDCORE: Wailing Caverns quest: the hides drop from elite Deviate creatures (Coiler, Stinglash, Creeper)
#skipquest 1491 >> HARDCORE: Wailing Caverns quest: the Wailing Essence drops from elite ectoplasms
#skipquest 3376 >> not finished by this route: its objectives are 148 s of walking away (the route walks up to 30 s for one)
#skipquest 3923 >> not finished by this route: it is handed in 383 s of walking away and the route does not pass there
#skipquest 4021 >> HARDCORE: the banner is guarded by Warlord Krom'zar, an elite the data does not link to the quest
#skipquest 4770 >> HARDCORE: escort quest (Pao'ka Swiftmountain, Thousand Needles)
#skipquest 4904 >> HARDCORE: escort quest (Lakota Windsong, Thousand Needles)
#skipquest 5147 >> HARDCORE: bounty on Arnak Grimtotem, a named Grimtotem in his camp, a target the data does not flag as elite
#skipquest 5726 >> HARDCORE: the Lieutenant's Insignia drops from the Burning Blade at Skull Rock (near 53,9); the chain goes on into Ragefire Chasm to kill two elites (5728)
#skipquest 5927 >> alternative to quest 5926, which is routed
#skipquest 5928 >> alternative to quest 5926, which is routed
#skipquest 6482 >> HARDCORE: escort quest (Ruul Snowhoof, Ashenvale)
#skipquest 6523 >> HARDCORE: escort quest (Kaya Flathoof, Stonetalon Mountains)
#skipquest 6544 >> HARDCORE: probably an escort (Torek's assault on Silverwing Outpost, Ashenvale)
#skipquest 6562 >> HARDCORE: leads only to The Essence of Aku'Mai, a Blackfathom Deeps dungeon quest
#skipquest 6563 >> HARDCORE: dungeon quest (the Sapphires of Aku'Mai lie inside Blackfathom Deeps)
#skipquest 6621 >> HARDCORE: kills Chief Murgut, a named furbolg chief the data places nowhere and does not flag as elite
#skipquest 6641 >> HARDCORE: escort quest (Muglash walks to Vorsha through Ashenvale and enemies attack on the way)
#skipquest 6921 >> HARDCORE: dungeon quest (Blackfathom Deeps): the Fathom Core lies inside the dungeon
#skipquest 7820 >> no known source for the cloth; not worth a detour
#skipquest 8368 >> battleground (PvP) quest, not leveling content
#skipquest 8426 >> battleground (PvP) quest, not leveling content
#skipquest 65601 >> probably a Warlock class quest (it starts with Cazul in Orgrimmar, who gave the Orc Warlock's quests in Classic): the game should not offer it to other classes (unverified)
#skipquest 76240 >> no known source for the cloth; not worth a detour
#skipquest 79007 >> not finished by this route: it is handed in 857 s of walking away and the route does not pass there
#skipquest 79094 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 79096 >> not finished by this route: its objectives are 266 s of walking away (the route walks up to 30 s for one)
#skipquest 92422 >> HARDCORE: kills Rath'mael, a named creature new in Forever (Tirisfal Glades); whether it is elite is not known
#skipquest 92706 >> HARDCORE: bounty on Bruuz, a named creature new in Forever (The Barrens); whether it is elite is not known
#skipquest 96241 >> HARDCORE: collects toxin samples at the entrance of the new Gloomrise nest in northern Mulgore (a level 30 quest); whether the creatures there are elite is not known
#skipquest 96259 >> HARDCORE: kills Gloomrise creatures in the new Gloomrise nest in northern Mulgore (a level 30 quest); whether they are elite is not known
#skipquest 96260 >> HARDCORE: needs silk from Gloomrise spinners in the new Gloomrise nest in northern Mulgore (a level 30 quest); whether they are elite is not known
#skipquest 96261 >> HARDCORE: kills Broodmother Valraxx, the named boss of the new Gloomrise nest in northern Mulgore (a level 31 quest); whether she is elite is not known
#skipquest 96604 >> alternative to quest 96605, which is routed
#skipquest 96607 >> alternative to quest 96605, which is routed
#skipquest 96652 >> alternative to quest 96659, which is routed
#skipquest 96655 >> alternative to quest 96661, which is routed
#skipquest 96656 >> alternative to quest 96659, which is routed
#skipquest 96658 >> alternative to quest 96661, which is routed
#skipquest 96825 >> not finished by this route: its objectives are 32 s of walking away (the route walks up to 30 s for one)
#skipquest 97003 >> HARDCORE: kills Chol'aruk the Ravener, a named creature new in Forever (The Barrens); whether it is elite is not known
#skipquest 98251 >> probably a Warlock class quest (Va'xug Firefure in Ashenvale also gives A Void Path, which ends at the Eye of Kilrogg): the game should not offer it to other classes (unverified)
#skipquest 98252 >> probably a Warlock class quest (it ends at the Eye of Kilrogg, the Warlock spell of that name in Classic): the game should not offer it to other classes (unverified)
#skipquest 99080 >> not finished by this route: its objectives are 144 s of walking away (the route walks up to 30 s for one)
#skipquest 99108 >> probably a Warrior class quest (it starts with Krang Stonehoof, the Tauren Warrior trainer of Bloodhoof Village): the game should not offer it to other classes (unverified)
#include tauren-druid-01-mulgore
#include tauren-druid-02-thunder-bluff
#include tauren-druid-03-mulgore
#include tauren-druid-04-thunder-bluff
#include tauren-druid-05-the-barrens
#include tauren-druid-06-orgrimmar
#include tauren-druid-07-durotar
#include tauren-druid-08-the-barrens
#include tauren-druid-09-undercity
#include tauren-druid-10-the-barrens
#include tauren-druid-11-stonetalon-mountains
#include tauren-druid-12-moonglade
#include tauren-druid-13-stonetalon-mountains
#include tauren-druid-14-silverpine-forest
#include tauren-druid-15-undercity
#include tauren-druid-16-hillsbrad-foothills
#include tauren-druid-17-the-barrens
#include tauren-druid-18-thunder-bluff
#include tauren-druid-19-stonetalon-mountains
#include tauren-druid-20-ashenvale
#include tauren-druid-21-the-barrens
#include tauren-druid-22-thousand-needles
#include tauren-druid-23-the-barrens
]],
})
