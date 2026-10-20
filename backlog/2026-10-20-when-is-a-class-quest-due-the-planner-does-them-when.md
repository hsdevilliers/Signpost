---
title: When is a class quest due? The planner does them when cheapest, hours after they open
kind: question
status: done
priority: normal
area: planner
source: claude
raised: 2026-10-20
raised_in: Route Planner runs, PR #35
closed: 2026-10-21
resolution: The user answered (2026-10-20: no deadline, a soft push): implemented in PR #38. A class quest costs --class-push (default 20 min) for each level it is undone past the level it opens at (up to 6); while undone the search ranks a route by the level the character will have when it gets there; the report lists the late ones. With the beam that compares routes by how far they have got the druids' Cat Form chains come at 21 and 22 (they open at 20) and the forms at 18 to 22, not at 30. What is left: the druid guides and the search's roughness have items of their own.
---

## What

The Route Planner (docs/PLANNER.md) treats the class quests as mandatory (each is done, or accounted for with a `#skipquest`) but gives them
no due time, so it does each one whenever that costs least. In the first runs that is the end of the route. The Tauren Druid's quests that
open at 10, 14, 16 and 20 (Moonglade, Great Bear Spirit, Aquatic Form, The Great Cat Spirit and the rest) are all done at level 30, and so
are the Skyborne Druid's (Child of Nature, Moonglade, the Cat Form chain). The Troll Hunter's Hunter's Path (opens at 10) is done at 10 to 12.
A player wants Bear Form at 10 and Cat Form at 20, and the drafted chapters put them there.

**Question for the user: when is a class quest due?**

## Why

A planned route that does the forms at level 30 is not a route anyone would play, so planner routes cannot replace the drafted chapters
(PROGRESS, "install a planned route") until this is settled. The report already says how many class quests come more than 5 levels after
they open.

## Done when

The user has answered. The planner has the answer as a setting (with a flag), the search obeys it, the report lists the class quests that are
late under it, and a test pins it.

## Notes

Claude's recommendation: a class quest is due when the character is 2 levels above the level it opens at (the forms are worth most early,
and two levels leaves room to finish the zone one is in), enforced as a hard rule in the search (a route past the due level with the quest
undone is not extended) so the output needs no explaining. Other choices: a penalty per level overdue (softer, harder to read); due exactly
when it opens (simple, more detours); no rule (today).
