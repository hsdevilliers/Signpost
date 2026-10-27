local ADDON_NAME, ns = ...

ns.Guides:Register({
	id = "horde-troll-hunter",
	name = "Troll Hunter",
	faction = "Horde",
	races = { "Troll" },
	classes = { "HUNTER" },
	levels = { 1, 30 },
	text = [[
#guide Troll Hunter
#professions skinning,leatherworking,firstaid,cooking,fishing
#skipquest 235 >> alternative to quest 6382, which is routed
#skipquest 354 >> not finished by this route: its objectives are 149 s of walking away (the route walks up to 45 s for one)
#skipquest 356 >> not finished by this route: its objectives are 67 s of walking away (the route walks up to 45 s for one)
#skipquest 358 >> not finished by this route: its objectives are 60 s of walking away (the route walks up to 45 s for one)
#skipquest 404 >> not finished by this route: its work is 22 s away and pays 0.14 XP/s against the route's 8.87 (2%); completeness is 0.60
#skipquest 446 >> not finished by this route: it is handed in 288 s of walking away and the route does not pass there
#skipquest 447 >> not finished by this route: its objectives are 109 s of walking away (the route walks up to 45 s for one)
#skipquest 539 >> not finished by this route: it could not be worked at level 23 (a level 28 quest) and the route did not come back when it could
#skipquest 742 >> alternative to quest 6382, which is routed
#skipquest 787 >> starts with Eitrigg in Orgrimmar: an intro for characters created there, not for the Valley of Trials
#skipquest 805 >> not finished by this route: it is handed in 103 s of walking away and the route does not pass there
#skipquest 843 >> not finished by this route: its objectives are 84 s of walking away (the route walks up to 45 s for one)
#skipquest 880 >> not finished by this route: its objectives are 106 s of walking away (the route walks up to 45 s for one)
#skipquest 894 >> not finished by this route: it is handed in 290 s of walking away and the route does not pass there
#skipquest 1094 >> not finished by this route: it is handed in 642 s of walking away and the route does not pass there
#skipquest 1151 >> not finished by this route: its objectives are 177 s of walking away (the route walks up to 45 s for one)
#skipquest 1153 >> not finished by this route: it could not be worked at level 25 (a level 29 quest) and the route did not come back when it could
#skipquest 3261 >> not finished by this route: it is handed in 292 s of walking away and the route does not pass there
#skipquest 4767 >> not finished by this route: its objectives are 172 s of walking away (the route walks up to 45 s for one)
#skipquest 5062 >> not finished by this route: its objectives are 82 s of walking away (the route walks up to 45 s for one)
#skipquest 5726 >> not finished by this route: its objectives are 112 s of walking away (the route walks up to 45 s for one)
#skipquest 6069 >> alternative to quest 6068, which is routed
#skipquest 6070 >> alternative to quest 6068, which is routed
#skipquest 6421 >> not finished by this route: its objectives are 138 s of walking away (the route walks up to 45 s for one)
#skipquest 8368 >> battleground (PvP) quest, not leveling content
#skipquest 8426 >> battleground (PvP) quest, not leveling content
#skipquest 65593 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 45 s for one)
#skipquest 65601 >> probably a Warlock class quest (it starts with Cazul in Orgrimmar, who gave the Orc Warlock's quests in Classic): the game should not offer it to other classes (unverified)
#skipquest 78143 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 45 s for one)
#skipquest 78145 >> not finished by this route: it could not be worked at level 16 (a level 20 quest) and the route did not come back when it could
#skipquest 78149 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 45 s for one)
#skipquest 79007 >> not finished by this route: it is handed in 857 s of walking away and the route does not pass there
#skipquest 79094 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 45 s for one)
#skipquest 79097 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 45 s for one)
#skipquest 86784 >> not finished by this route: its work is 4 s away and pays 0.51 XP/s against the route's 8.87 (6%); completeness is 0.60
#skipquest 95314 >> not finished by this route: its objectives are 324 s of walking away (the route walks up to 45 s for one)
#skipquest 96605 >> alternative to quest 96604, which is routed
#skipquest 96607 >> alternative to quest 96604, which is routed
#skipquest 96656 >> alternative to quest 96652, which is routed
#skipquest 96658 >> alternative to quest 96655, which is routed
#skipquest 96659 >> alternative to quest 96652, which is routed
#skipquest 96661 >> alternative to quest 96655, which is routed
#skipquest 96822 >> not finished by this route: its objectives are 74 s of walking away (the route walks up to 45 s for one)
#skipquest 96899 >> not finished by this route: it is handed in 292 s of walking away and the route does not pass there
#skipquest 97253 >> not finished by this route: its objectives are 87 s of walking away (the route walks up to 45 s for one)
#skipquest 97558 >> not finished by this route: its objectives are 136 s of walking away (the route walks up to 45 s for one)
#skipquest 98251 >> probably a Warlock class quest (Va'xug Firefure in Ashenvale also gives A Void Path, which ends at the Eye of Kilrogg): the game should not offer it to other classes (unverified)
#skipquest 98252 >> probably a Warlock class quest (it ends at the Eye of Kilrogg, the Warlock spell of that name in Classic): the game should not offer it to other classes (unverified)
#skipquest 99108 >> probably a Warrior class quest (it starts with Krang Stonehoof, the Tauren Warrior trainer of Bloodhoof Village): the game should not offer it to other classes (unverified)
#skipquest 99134 >> not finished by this route: its objectives are 48 s of walking away (the route walks up to 45 s for one)
#skipquest 99141 >> not finished by this route: its objectives are 114 s of walking away (the route walks up to 45 s for one)
#include troll-hunter-01-durotar
#include troll-hunter-02-orgrimmar
#include troll-hunter-03-the-barrens
#include troll-hunter-04-orgrimmar
#include troll-hunter-05-undercity
#include troll-hunter-06-silverpine-forest
#include troll-hunter-07-undercity
#include troll-hunter-08-tirisfal-glades
#include troll-hunter-09-undercity
#include troll-hunter-10-silverpine-forest
#include troll-hunter-11-hillsbrad-foothills
#include troll-hunter-12-the-barrens
#include troll-hunter-13-stonetalon-mountains
#include troll-hunter-14-ashenvale
#include troll-hunter-15-thousand-needles
#include troll-hunter-16-the-barrens
]],
})
