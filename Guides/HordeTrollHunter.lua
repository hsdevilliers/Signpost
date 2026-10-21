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
#skipquest 356 >> not finished by this route: its objectives are 67 s of walking away (the route walks up to 30 s for one)
#skipquest 421 >> not finished by this route: its objectives are 74 s of walking away (the route walks up to 30 s for one)
#skipquest 429 >> not finished by this route: its objectives are 30 s of walking away (the route walks up to 30 s for one)
#skipquest 440 >> not finished by this route: it is handed in 320 s of walking away and the route does not pass there
#skipquest 447 >> not finished by this route: its objectives are 109 s of walking away (the route walks up to 30 s for one)
#skipquest 529 >> not finished by this route: it could not be worked at level 22 (a level 26 quest) and the route did not come back when it could
#skipquest 742 >> alternative to quest 6382, which is routed
#skipquest 784 >> not finished by this route: its objectives are 95 s of walking away (the route walks up to 30 s for one)
#skipquest 787 >> starts with Eitrigg in Orgrimmar: an intro for characters created there, not for the Valley of Trials
#skipquest 808 >> not finished by this route: its objectives are 109 s of walking away (the route walks up to 30 s for one)
#skipquest 826 >> not finished by this route: its objectives are 100 s of walking away (the route walks up to 30 s for one)
#skipquest 865 >> not finished by this route: its objectives are 171 s of walking away (the route walks up to 30 s for one)
#skipquest 872 >> not finished by this route: its objectives are 121 s of walking away (the route walks up to 30 s for one)
#skipquest 875 >> not finished by this route: its objectives are 232 s of walking away (the route walks up to 30 s for one)
#skipquest 879 >> not finished by this route: its objectives are 232 s of walking away (the route walks up to 30 s for one)
#skipquest 880 >> not finished by this route: its objectives are 106 s of walking away (the route walks up to 30 s for one)
#skipquest 894 >> not finished by this route: it is handed in 290 s of walking away and the route does not pass there
#skipquest 1014 >> not finished by this route: it could not be worked at level 22 (a level 27 quest) and the route did not come back when it could; an objective of it has no position in the data, so the planner works it where the quest is picked up, with no walk
#skipquest 1153 >> not finished by this route: its objectives are 329 s of walking away (the route walks up to 30 s for one)
#skipquest 5041 >> not finished by this route: its objectives are 113 s of walking away (the route walks up to 30 s for one)
#skipquest 5062 >> not finished by this route: its objectives are 82 s of walking away (the route walks up to 30 s for one)
#skipquest 6069 >> alternative to quest 6068, which is routed
#skipquest 6070 >> alternative to quest 6068, which is routed
#skipquest 6384 >> not finished by this route: it is handed in 396 s of walking away and the route does not pass there
#skipquest 6421 >> not finished by this route: its objectives are 138 s of walking away (the route walks up to 30 s for one)
#skipquest 6504 >> not finished by this route: it could not be worked at level 26 (a level 30 quest) and the route did not come back when it could; an objective of it has no position in the data, so the planner works it where the quest is picked up, with no walk
#skipquest 8368 >> battleground (PvP) quest, not leveling content
#skipquest 8426 >> battleground (PvP) quest, not leveling content
#skipquest 65593 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 65601 >> probably a Warlock class quest (it starts with Cazul in Orgrimmar, who gave the Orc Warlock's quests in Classic): the game should not offer it to other classes (unverified)
#skipquest 76156 >> not finished by this route: its objectives are 183 s of walking away (the route walks up to 30 s for one)
#skipquest 78143 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 78145 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 78149 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 79007 >> not finished by this route: it is handed in 857 s of walking away and the route does not pass there
#skipquest 79094 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 79097 >> not finished by this route: its objectives are 857 s of walking away (the route walks up to 30 s for one)
#skipquest 91920 >> not finished by this route: its objectives are 41 s of walking away (the route walks up to 30 s for one)
#skipquest 96605 >> alternative to quest 96604, which is routed
#skipquest 96607 >> alternative to quest 96604, which is routed
#skipquest 96656 >> alternative to quest 96652, which is routed
#skipquest 96658 >> alternative to quest 96655, which is routed
#skipquest 96659 >> alternative to quest 96652, which is routed
#skipquest 96661 >> alternative to quest 96655, which is routed
#skipquest 96822 >> not finished by this route: its objectives are 74 s of walking away (the route walks up to 30 s for one)
#skipquest 97003 >> not finished by this route: it could not be worked at level 16 (a level 21 quest) and the route did not come back when it could
#skipquest 97253 >> not finished by this route: its objectives are 87 s of walking away (the route walks up to 30 s for one)
#skipquest 97538 >> not finished by this route: its objectives are 418 s of walking away (the route walks up to 30 s for one)
#skipquest 97558 >> not finished by this route: its objectives are 136 s of walking away (the route walks up to 30 s for one)
#skipquest 98251 >> probably a Warlock class quest (Va'xug Firefure in Ashenvale also gives A Void Path, which ends at the Eye of Kilrogg): the game should not offer it to other classes (unverified)
#skipquest 98252 >> probably a Warlock class quest (it ends at the Eye of Kilrogg, the Warlock spell of that name in Classic): the game should not offer it to other classes (unverified)
#skipquest 99108 >> probably a Warrior class quest (it starts with Krang Stonehoof, the Tauren Warrior trainer of Bloodhoof Village): the game should not offer it to other classes (unverified)
#include troll-hunter-01-durotar
#include troll-hunter-02-orgrimmar
#include troll-hunter-03-durotar
#include troll-hunter-04-orgrimmar
#include troll-hunter-05-the-barrens
#include troll-hunter-06-undercity
#include troll-hunter-07-silverpine-forest
#include troll-hunter-08-undercity
#include troll-hunter-09-silverpine-forest
#include troll-hunter-10-undercity
#include troll-hunter-11-silverpine-forest
#include troll-hunter-12-hillsbrad-foothills
#include troll-hunter-13-silverpine-forest
#include troll-hunter-14-the-barrens
#include troll-hunter-15-thunder-bluff
#include troll-hunter-16-stonetalon-mountains
#include troll-hunter-17-ashenvale
#include troll-hunter-18-the-barrens
#include troll-hunter-19-mulgore
#include troll-hunter-20-stonetalon-mountains
#include troll-hunter-21-thousand-needles
]],
})
