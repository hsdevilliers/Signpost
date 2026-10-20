# Hardcore routes (Release 1)

The Release 1 guides are hardcore routes (PLAN §2). This is how, what we know and what we do not.

## Verdict (2026-10-20)

Feasible as a **safety-leaning route**, not as a guarantee. A hardcore character can die to anything; a route can only avoid the
known killers, delay the risky content and warn at the dangerous steps. It is not a different route for every zone: the same
quests are mostly right, minus a short skip list, plus notes, plus a default of skipping dungeon chapters. RestedXP does the same: a
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

1. **Skip list** (`tools/hardcore_rules.json`): each rule has a quest ID (from the data pack), an action (`skip` becomes
   `#skipquest <id> >> <reason>`, `note` becomes a `.note` after the `.accept`), a source and a confidence. `tools/guide_draft.py
   --hardcore` applies it. Corrected from play: the contributors' deaths and notes are the best source we will get.
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
- **Group-quest and elite tags** are not in the data pack (QuestieDB's quest flags are not imported); the skip list is by quest ID.
- **Forever changes**: new or reworked quests and zones are not in any source yet; each is judged when recorded in game.
- **Death data**: a contributor's deaths (where, at what level) would improve the list far more than any article. Not built; a
  possible later addition to `Core/Learn.lua`, opt-in like the rest (docs/SHARING-DATA.md).
