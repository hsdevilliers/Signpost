# Hardcore routes (Release 1)

The Release 1 guides are hardcore routes (PLAN §2). This is how, what we know and what we do not.

## Verdict (2026-10-20)

Feasible as a **safety-leaning route**, not as a guarantee. A hardcore character can die to anything; a route can only avoid the
known killers, delay the risky content and warn at the dangerous steps. It is not a different route for every zone: the same
quests are mostly kept, minus what the data can flag (elite kills, quests far above the level) and a hand-kept skip list, plus notes, plus
a default of skipping dungeon chapters. The data cannot yet flag escorts, group quests or named elite-level targets, so the first
adversarial review of the Tauren Druid guide found several still routed (escorts, Northwatch Hold, named Kolkar leaders): they are now
on the list, and expect more until someone plays the route. RestedXP does the same: a
separate survival route and a mode switch on guide steps (our `.hc` gate).

## What the research found (web, 2026-10-20)

There is **no Forever-specific hardcore quest list** anywhere, and none for Mulgore or the Barrens. What exists is Classic
Hardcore advice, which Forever's Classic content mostly shares. The points several sources agree on:

- **Caves are death traps**: Skull Rock (Durotar), the Burning Blade caves, tight spaces that stop you running; respawns inside
  caves and a hard-hitting boss. (Blizzard forums thread 1798905, several posters; the dotesports top-10 list.)
- **Elite and group quests** are skipped, or revisited later with a group. (The hardcore druid guides.)
- **Instant-death quests**: Meet at the Grave (the quest kills the character), Scarlet Diversions flagged as notorious.
- **Druid specifics**: Bear Form (level 10) is the early survival tool and Travel Form the escape tool; Moonglade's Lunaclaw summon
  (the end of the Bear Form chain) needs full buffs and health, Entangling Roots buys distance. (joanasworld Tauren 1-12 guide.)
- **Mulgore**: the Dwarven Digging forge is hard to reach without a group (same guide).
- Mob-level notes for other zones (Fizzle in Durotar until about 14, Echo Isle trolls before 9-10, plainstriders for melee) exist but
  are single-poster claims; they are not rules yet.

Sources: [Blizzard forums thread](https://us.forums.blizzard.com/en/wow/t/advice-on-dangerous-horde-quests-to-avoid-in-hc-sf/1798905),
[dotesports top 10](https://dotesports.com/wow/news/the-top-10-quests-every-wow-classic-hardcore-player-should-avoid-at-all-costs)
(read from search results only: the page itself answered 403), [joanasworld Mulgore 1-12](https://www.joanasworld.com/horde-1-12-mulgore.php),
[RestedXP Classic Hardcore](https://shop.restedxp.com/hardcore/), [hcguides Wailing Caverns](https://www.hcguides.com/dungeons/wailing-caverns).

## The policy

0. **Data-driven criteria** (`guide_draft.py --hardcore`, no list needed): a quest that needs an **elite, rare elite or boss kill** (QuestieDB's
   NPC `rank`, now in the pack), or an item only elites drop (and no object gives), is dropped; a quest whose **level is more than 2 above
   the chapter's top level** is dropped (`--hardcore-over`). The pack has no escort, group or cave flags, so those still need the list below.
1. **Skip list** (`tools/hardcore_rules.json`): each rule has a quest ID (from the data pack), an action (`skip` becomes
   `#skipquest <id> >> <reason>`, `note` becomes a `.note` after the `.accept`), a source and a confidence. `tools/guide_draft.py
   --hardcore` applies it. Corrected from play: the contributors' deaths and notes are the best source we will get. Scope (2026-10-21): a skip
   whose reason starts with HARDCORE (escorts, elite or unknown-rank targets, dungeon quests) holds for HARDCORE guides only; any other skip
   holds for every guide, so it is for what nobody should do (a battleground quest) or it carries `class_quest_of` (a class token or a list):
   the quest belongs to that class although the data has no class mask for it (Forever's new quests have none), and the rule skips it for the
   guides of every other class and leaves it to that class's own. A rule's source says where the belief comes from (memory of Classic, a
   review, a death) and whether it was seen in game; it does not quote the data pack.
2. **Class quests stay mandatory** (the lint enforces it): a dangerous one is routed late and carries a note, or is skipped with a
   written reason, never silently dropped.
3. **Group (elite) quests are optional** (PLAN §2) and in hardcore are skipped unless the player chooses otherwise.
4. **Dungeon chapters** are auto-inserted with a Skip toggle (PLAN §2). In a hardcore guide they should default to skipped; the
   chapter header has no default-skip flag yet (open design item).
5. **Warnings, not guarantees**: the guide says "come back later", "heal first", "avoid the cave"; it does not claim safety.

## Open

- **How does the addon know a character is hardcore?** `.hc` is "always false for now" (GUIDE-FORMAT). The Forever API for the
  ruleset is unknown: an open probe (FOREVER-API-NOTES). Until it is answered the Release 1 guides are simply hardcore by
  construction (no `.hc` branching needed).
- **Escort, group and cave tags** are not in the data pack; those quests are caught only by the skip list (by quest ID) until a source
  for them exists. The Barrens draft shows the gap: unflagged named targets (Verog, Hezrul, Kuz and Nak) pass the elite rule.
- **Moonglade and Bear Form timing (design call).** Every Tauren druid class chain (Bear Form at 10, Lessons Anew at 14, Aquatic Form at
  16) runs through Moonglade (Dendrite Starblaze, Tajarri), and the travel graph has no route there. Since 2026-10-21 the Tauren route is
  the Route Planner's: it walks to Moonglade and back (22 to 25 minutes each way in its price, a `.todo` travel step each time in the
  guide) and no step assumes **Teleport: Moonglade**; the chapter notes only mention it, tagged VERIFY(beta). What the sources say:
  Classic druids have that spell from level 10 (10 s cast, no reagents); Forever guides list it as a reward of the Bear Form chain; where
  Forever druids learn it is unverified (VERIFY(beta)), and so is the way back (hearthstone, a flight path, or the spell). Open: confirm
  both in game (backlog: the question on Teleport: Moonglade), and batch the Lessons Anew and Aquatic Form legs into fewer round trips
  (the chain links alternate between Thunder Bluff and Moonglade, so a trip per link is what the data gives).
- **`.todo` never completes a step** (found by the review): a step with `.todo` and another directive (the travel steps, an objective
  step) stays current after the other directive is satisfied, until the player skips it. That is what GUIDE-FORMAT says (`.todo` is never
  satisfied), but it makes the planner's `.todo` + `.zone` steps and the drafted `.todo` + `.complete` steps need a manual skip.
  Open for the user: let a step complete on its other directives and keep `.todo` as a display marker, or keep it.
- **Forever changes**: new or reworked quests and zones are not in any source yet; each is judged when recorded in game.
- **Death data**: a contributor's deaths (where, at what level) would improve the list far more than any article. Not built; a
  possible later addition to `Core/Learn.lua`, opt-in like the rest (docs/SHARING-DATA.md).
