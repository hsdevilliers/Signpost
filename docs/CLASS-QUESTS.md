# Class quests in WoW: Forever: what is new, what is known (research 2026-10-20)

The data pack is Classic-only (QuestieDB), so Forever's **new class quests** (the user, 2026-10-20: class-specific quests that are not in
Classic, in the manner of Season of Discovery, e.g. a level 24 group quest for a rogue's poisons) are not in it and not in any class
module's `classQuests`. CLAUDE.md makes every class quest mandatory content: until a quest has an ID (from play: `Core/Learn.lua` records the
quest IDs a character accepts and turns in, with the NPC positions), the guides carry a `.todo` step at the right level and this file lists
what is known. Nothing here has IDs or coordinates; every line is a third-party description of the beta and the sources disagree in places.

Sources are fan and guide sites (none official; Blizzard has published no class quest list): worstguidesever.com (druid and hunter class quest
guides), foreverchanges.pro (druid Cat Form; hunter quest table), wowforevercodex.com (hunter quests), buyboost.com (quest weapons at 20-30).
Two of them (leprestore.com, boosting-ground.com) answered 403 and were not read.

## Druid

| Level | Chain | Forever status | Notes |
|---|---|---|---|
| 10 | Bear Form: Heeding the Call, Moonglade, Great Bear Spirit, Back to Thunder Bluff, Body and Heart | Classic (in the pack) | solo; ends by killing Lunaclaw; rewards Bear Form, **Teleport: Moonglade** (one source; where the spell is learned is unverified) |
| 14 | Cure Poison: Lessons Anew ... Power over Poison | Classic (in the pack) | solo |
| 16 | Aquatic Form: A Lesson to Learn ... Aquatic Form | Classic (in the pack) | solo |
| **20** | **Cat Form: "The Great Cat Spirit" (x3), "Blessings of the Great Cat Spirit", "To Thunder Bluff"** | **new quest chain in the Forever beta**; in the pack since 2026-10-20 (QuestieDB's Forever layers: 98340, 98405, 98342, 98739, 98362) | starts with the trainer (Turak Runetotem for a Tauren), Moonglade, three relics (Fang, Claw, Silent Shadow) in the Stormrage Barrow Dens (spirits attack on sight; a statue at the door grants a stealth blessing); relics are party loot; XP 390/780/780/780/155 |
| 20 (Skyborne) | The Great Cat Spirit 98340 (shared), The Great Windborne Cat Spirit 98341 and 98404 (the three relics), Blessings of the Great Windborne Cat Spirit 98738, To Thunder Bluff 98362 (shared) | Skyborne variant, in the pack; the same shape as the Tauren chain with the Avatar of Saeyleenan (Moonglade 43.92, 73.44) in place of the Great Cat Spirit | the pack has no chain links for these: the guide orders them with `guide_draft.py --chain` from each quest's start and end NPC |
| 10 (Skyborne) | Windshaper Bear Form: Child of Nature 94911, Moonglade 94913, The Great Ursera Spirit 94006, Strength and Mercy 94638 (after A Student of Nature 92485 at 2) | new, in the pack | 94911 starts in Mulgore (Muln Earthfury), the rest on Zephras Isle and Thunder Bluff; routed in `windshaper-bear-form-10` and `zephras-isle-1-12` |
| 30 | Travel Form | trained, no quest (two sources) | |
| 50 (quest level 52) | Sunken Temple: Torwa Pathfinder, Bloodpetal Poison, Toxic Test, A Better Ingredient | Classic (in the pack) | the last step is a dungeon (5 players): hardcore skip |
| 60 | set and weapon chains | not drafted | |

## Hunter

| Level | Chain | Forever status | Notes |
|---|---|---|---|
| 1 | Etched Tablet / Parchment / Note (Troll, Orc, Tauren) | Classic (in the pack) | |
| 10 | The Hunter's Path (Jen'shan, Durotar) + Taming the Beast (Thotar, Razor Hill) + Training the Beast (Ormak Grimshot, Orgrimmar) for Orc and Troll | Classic (in the pack) | tame a Dire Mottled Boar in Durotar; Tauren: Kary Thunderhorn / Yaw Sharpmane / Holt Thunderhorn |
| 2 or 22 | "The Way of the Hunter" | **new** (sources disagree on the level: Zephras Isle start, Rorian the Dayseeker, vs a level 22 entry) | |
| 10 (Skyborne, Alliance) | new Taming the Beast / Training the Beast chains (Zephras Isle: Elayaa Easewind, Quel'ana Quickgale; Elwynn: Josephine Carson) | new | |
| 29 | Quilboar Blaster ("A Vengeful Fate" for Horde: Auld Stonespire in Thunder Bluff, then Charlga Razorflank in Razorfen Kraul) | new quest weapon (one source) | a dungeon quest: hardcore skip |
| 50 (quest level 52) | The Hunter's Charm, Courser Antlers, Wavethrashing, The Green Drake (Ogtinc, Azshara) | Classic (in the pack) | the last step clears the Temple of Atal'Hakkar: hardcore skip |
| 58-60 | Beastmaster set, Rhok'delar chain, paragons | Classic | raid and dungeon: not drafted |

The Codex says 10 hunter quests are new in Forever without listing them; ForeverChanges counts 54 hunter quests, the Codex 74.

## Other classes and weapon quests

A level 20-30 band of class **weapon quests** is described for several classes (buyboost.com: a druid two-handed mace "Heavehammer" at 24
from the Wetlands Titan relic route, Horde "Earthen Echo"; Quilboar Blaster for hunters; a rogue dagger route from 24). The user saw a level 24
rogue group quest for poisons. None of these has a verified description or IDs; they are the first things to capture from play.

## What the guides do about it

- `.todo` steps at the matching level in the Tauren Druid guide (Cat Form) and, when it exists, the Troll Hunter guide; each names the chain.
- The recorder (`Core/Learn.lua`) is the source of IDs and positions; the guide steps are rewritten from a play session's data.
- Group and dungeon chains are skipped in the hardcore routes with a written reason (`#skipquest`), never silently.
