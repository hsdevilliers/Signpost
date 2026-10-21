---
title: Fill recipes[].skill from exact difficulty observations learned in game
kind: feature
status: open
priority: low
area: data, tools
source: claude
raised: 2026-10-21
raised_in: branch feat/profession-recorder (batch 1, WP-G2)
---

## What

Recipes in the pack carry `skill = { orange, yellow, green, grey }` when the Wowhead layer has them. The recorder stores difficulty
observations (`obs`: the lowest and highest skill seen in each difficulty) and `learned.skill_bounds(obs)` reads where each colour
starts as far as they say, but nothing writes the thresholds into `skill` when the observations pin them exactly (the last skill
of one difficulty and the first of the next are one apart).

## Why

The profession tracks and the planner would use the thresholds (how long to craft a recipe before it turns green), and the Wowhead
layer may stay unreadable for Claude Code; learned thresholds would then be the only source.

## Done when

The importer fills `recipes[].skill` from exact observations only (and never overwrites a value another layer holds unless the
observations contradict it, which it reports), with tests; consumers read `skill` as before.

## Notes

While crafting, the window updates after every craft, so skill-ups are seen one by one and exact thresholds are likely after a
play-through of a profession.
