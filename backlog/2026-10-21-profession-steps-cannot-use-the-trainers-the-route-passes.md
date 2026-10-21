---
title: Profession steps cannot use the trainers the route passes earlier: the planned chapters carry no .hub lines
kind: task
status: open
priority: normal
area: planner, guides
source: claude
raised: 2026-10-21
raised_in: profession tracks, first cut (feat/profession-tracks)
---

## What

The five profession tracks (`Guides/Professions/`) anchor with `@zone` and `@level` because the planned chapters carry no `.hub` lines. So every learn
step sits at the first Orgrimmar visit (level 10, chapter "Orgrimmar 10-11"), and the rank steps at the first visit to Undercity and Thunder Bluff.

The shipped route passes closer trainers much earlier: Razor Hill (a First Aid Trainer, Rawrk; Cook Torka's "Camping 101: Cooking" is already in
the route), the Valley of Trials (a "Junior Skinning Trainer", Kagil, which only Forever's layer of the pack has) and Sen'jin Village (a Fisherman
who trains Fishing, Lau'Tiki), all at levels 1 to 9. A step cannot anchor in the middle of a planned chapter without a marker.

## Why

PLAN §7 says "pick up Skinning as soon as a trainer is reachable", and PLAN §3.8 puts the marker in the chapters (`.hub <name>` on the step that is in a
town). Learning at level 10 loses nine levels of skins, bandages and fish, and it leaves the first aid and fishing "Camping 101" quests (level 6,
good experience at level 4 or 5) out of reach for the route.

## Done when

- The planner (`tools/planner.py`, `tools/route_install.py`) writes `.hub <name>` on the first step of each town it visits, with faction-neutral names
  (`valley`, `razorhill`, `senjin`, `orgrimmar`, `crossroads`, `undercity`, `thunderbluff`, ...), at least for the towns that have a profession trainer
  in the pack. `docs/PLANNER.md` and `docs/GUIDE-FORMAT.md` say so, with a test on a fixture.
- The tracks gain `@hub` steps for the early trainers (gated `.race Troll`, `.trainprof` first so a skip still declines), and the Orgrimmar learn
  steps stay as the fallback for a character that did not learn earlier (the learn step passes by itself for one who did).
- `guide_lint --strict` is clean with the pack, for every guide.

## Notes

- Do not make a track require a hub that a regenerated route may lack: an `@hub` step with no matching `.hub` is an `unmatched-anchor` error.
- Only the Troll route is in question today; the hub names must serve the Orc and Tauren routes too (PLAN §3.8).
