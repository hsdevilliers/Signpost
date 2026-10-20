# Quest availability: what the game offers, and how the tools check it

A guide is only valid if the game offers every quest where the guide says to accept it. Until 2026-10-20 nothing checked that.
The first in-game look found the Troll Hunter's first step telling a level 1 character to accept the Burning Blade Medallion
(794): the game does not offer it before Vile Familiars (792), which needs level 2. The drafter had treated the Warlock's own
Vile Familiars (1499), one of 794's two alternative prerequisites, as "done or irrelevant", so 794 looked available; the lint
did not model prerequisites at all, and its level warnings were read as noise. Since then the rules below are one module
(`tools/signpost_tools/availability.py`), used by the drafter, the simulator and the lint.

## The rules

For a character (faction, race, class, professions) at a level, with a set of quests turned in and a set in the quest log, the
game offers a quest when none of these holds. Each is a field of the pack's quest record (QuestieDB's name in brackets).

| Reason (lint code `quest-<code>`) | Field | Meaning |
|---|---|---|
| `faction`, `race`, `class` | `side`, `races` (requiredRaces), `classes` (requiredClasses), or the class sort of a class quest | who the quest is for. Forever's Skyborne races are bits 32 (Alliance) and 33 (Horde) |
| `level` | `r` (requiredLevel), `maxLevel` (requiredMaxLevel) | below the required level, or above the maximum |
| `skill` | `skill` | a profession skill line the character does not have |
| `prerequisite` | `preGroup` (preQuestGroup), `preSingle` (preQuestSingle) | all of the first, at least one of the second, turned in first. An alternative that is another race's or class's quest can never be done and does not count |
| `impossible` | the two above | every alternative is closed to this character: the quest is never offered |
| `locked` | `exclusive` (exclusiveTo) | one of the quests that exclude this one is done or in the log |
| `parent` | `parent` (parentQuest) | the parent quest must be in the log |
| `chain` | `next` (nextQuestInChain) of another quest | that quest hands this one over when it is turned in, and the game does not offer it while that quest is in the log |
| `event`, `repeatable` (warnings) | `sort`, `repeatable` | seasonal or repeatable quests do not belong in a route |
| `unknown-prerequisite` (warning) | | a prerequisite the pack does not know (it keeps Horde and neutral quests only) |
| `level-ungated` (warning) | | see "The `.level` convention" |

`chain` was learned from play: Gornek stopped offering Cutting Teeth (788) while Your Place in the World (4641) was in the log,
and handed it over as 4641 was turned in. The pack has no prerequisite on 788; only 4641's `next` says so.

## The `.level` convention

The simulator's level is an estimate, not a promise. A drafted chapter therefore asks for the level itself: before an `.accept` of
a quest above the highest level the route has asked for so far, the step gets a `.level N` line, and when nothing can be done
until the walker has levelled, a step of its own. The step frame then shows why a quest is not offered yet instead of leaving
the step stuck. The lint reports (`quest-level`) a quest above the simulated level, and warns (`quest-level-ungated`) one the
simulation has the level for but nothing in the guide asks for.

## Where it runs

- `tools/guide_draft.py` plans with it: a quest is drafted only when the rules offer it; a quest whose prerequisites the route
  never does is not routed (listed as "never available"); the quest a quest hands over waits for it.
- `python tools/guide_sim.py --check` walks every route of every guide and prints what the game would not offer, with the
  quest, the step and why. Exit 1 on an error.
- `python tools/guide_lint.py --strict` runs the same walk (needs the data pack, so CI without it skips it) as codes
  `quest-level`, `quest-prerequisite`, `quest-chain`, `quest-locked`, `quest-impossible`, `quest-race`, `quest-class`, ...
- Tests: `tools/tests/test_availability.py` has the Valley of Trials as the game offered it, including the Burning Blade
  Medallion and the Gornek sequence; `test_guide_draft.py` and `test_guide_lint.py` have the drafter and lint cases.

## What it cannot see

Reputation, known spells, items that start or unlock a quest, world events and phasing are not in the pack, and QuestieDB says
its Forever layers do not carry complete restrictions (docs/FOREVER-API-NOTES.md). The rules are checked against play:
`Core/Debug.lua` records the player's level and the quests turned in at every quest giver visit, next to what the giver offered
(`GOSSIP_SHOW`/`QUEST_GREETING` available and active lists). `tools/validate_availability.py` compares the two: a quest the
rules offer and the game did not is a data gap (the 794 kind); one the game offered and the rules do not is a wrong rule.
