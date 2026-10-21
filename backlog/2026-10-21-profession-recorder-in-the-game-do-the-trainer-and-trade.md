---
title: Profession recorder in the game: do the trainer and trade skill functions answer, do the records make sense?
kind: verify
status: open
priority: normal
area: engine, data
source: claude
raised: 2026-10-21
raised_in: branch feat/profession-recorder (batch 1, WP-G2)
---

## What

With recording on (a development build always; a release build after the box in Journal > Settings), in the real client: open the
trainer window of each profession you have and of your class, open each profession window you have (again after a skill-up), type
`/signpost probe` and `/signpost learned`, `/reload`, and read `probe.recorder`, `recorder` and `learned` with
`python tools/read_savedvars.py probe recorder learned`. Then check:

- which trainer functions exist (`C_TrainerUI.*` or the globals, and `GetTrainerServiceSkillReq`) and what `GetTrainerServiceInfo`
  answers; that a service's spell ID is read (link or `C_TooltipInfo.GetTrainerService`), its cost is copper, its level and skill
  requirement are right;
- which trade skill functions answer (the modern `C_TradeSkillUI.GetAllRecipeIDs/GetRecipeInfo/GetRecipeSchematic` or the Classic
  globals), which profession and skill value the window reports (the child skill lines 2937-2948), that a recipe's difficulty matches
  the window's colour at that skill;
- that a linked or a guild trade skill window is not read;
- `python tools/import_savedvars.py --merge-learned --pack <a copy of the pack>` files the services and recipes under the right
  profession.

## Why

`Core/LearnProfessions.lua` is written from the Mainline and the Classic API from memory and exercised on a mock only (every call
carries `VERIFY(beta)`). Until recipes, prices and difficulty colours come from play, the profession tracks (`Guides/Professions/`)
can only be notes and trainer visits.

## Done when

The "Profession recorder" probes in docs/FOREVER-API-NOTES.md "Open probes" are answered with the build number and moved to Verified,
or what differs is turned into items, and a copy of the pack holds services for the trainers visited and recipes for the windows opened.

## Notes

Design in docs/ENGINE.md, Core/Learn.lua, "Profession part". The in-game part is short: open each profession trainer and each
profession window once, then `/signpost probe`, `/signpost learned`, `/reload`.
