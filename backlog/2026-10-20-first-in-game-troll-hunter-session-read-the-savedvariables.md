---
title: First in-game Troll Hunter session: read the SavedVariables, check offered quests against the rules
kind: verify
status: done
priority: normal
area: tools, guides
source: claude
raised: 2026-10-20
raised_in: the first look at the Troll Hunter guide, 2026-10-20
closed: 2026-10-21
resolution: Read in batch 1: tools/validate_availability.py replays the recorded visits against the rules and agrees with the game on 7 of 7 visits (a bug that ignored accepts, turn-ins and level-ups because real logs key arguments by integer was found and fixed on the way); the one /signpost report was the old Medallion step. tools/audit_quests.py (a run on the same session) finds no data gap.
---

## What

The user was given the steps for a first in-game session with the Troll Hunter (Volduun-Raptortusk) and is to say "done" after a `/reload`.
Then: read the SavedVariables (`python tools/read_savedvars.py`), run `python tools/validate_availability.py`, compare the quests the game
offered with what the availability rules predict (docs/AVAILABILITY.md), and read what `/signpost report` collected.

## Why

The step 1 failure (accepting the Burning Blade Medallion at level 1) was found only by playing. The rules have been checked against the game
only at the quest givers the recorder has seen so far (3 of 3 visits agreed).

## Done when

- The session's SavedVariables are read; every visit agrees with the rules, or the disagreement is explained and fixed (a rule, or a gap in
  the data); anything reported with `/signpost report` is answered.
- Or the user says they will not do that session, and this item is dropped.
