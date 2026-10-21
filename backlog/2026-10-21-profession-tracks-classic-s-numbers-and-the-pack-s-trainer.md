---
title: Profession tracks: Classic's numbers and the pack's trainer positions, to be verified in play
kind: verify
status: open
priority: normal
area: guides, data
source: claude
raised: 2026-10-21
raised_in: profession tracks, first cut (feat/profession-tracks)
---

## What

Every number in the five profession tracks is Classic's, and the trainers come from the pack's NPC titles and converted Classic coordinates. Nothing in
them has been seen in the Forever client. In play, at the Orgrimmar trainers of a Troll Hunter (Thuwd, Kamari, Karolek, Arnok, Zamja, Lumak):

- which ranks each trainer offers, and what each rank asks (Classic: Journeyman level 10 and skill 50, Expert level 20 and skill 125, Artisan level 35
  and skill 200; caps 75, 150, 225, 300);
- whether the titles in the pack ("Journeyman Leatherworker", "Expert Leatherworker", "Skinning Trainer", ...) mean what they did in Classic;
- that the pins stand on the trainers (Orgrimmar, Undercity, Thunder Bluff), and that a learn step passes by itself for a profession already known;
- where Expert First Aid, Cooking and Fishing are taught, who sells a fishing pole, and whether Forever's Cooking quest "Camping 101: Cooking" teaches
  Cooking (the learn step is safe either way).

## Why

A guide that sends the player to the wrong trainer or asks for the wrong level costs minutes and trust; the tracks say "Classic's numbers, unverified
in Forever" until this is checked.

## Done when

- A session with `/signpost debug on` at those trainers is read with `tools/read_savedvars.py`; the tracks' notes and numbers are corrected to what it
  shows (or confirmed), and the "Profession tracks" entries of docs/FOREVER-API-NOTES.md "Open probes" are ticked with the evidence.
- The recorded trainer services fill the pack's profession table (the recorder of the profession work package), so `.trainprof` pins by itself.

## Notes

- Nothing here is urgent: the route works without it, with Classic's numbers flagged in every note.
