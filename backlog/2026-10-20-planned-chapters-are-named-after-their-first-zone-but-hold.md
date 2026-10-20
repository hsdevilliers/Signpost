---
title: Planned chapters are named after their first zone but hold steps of others; lone level steps have no place
kind: finding
status: open
priority: low
area: planner
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
---

## What

The planner names a chapter after the zone of its first hub and splits a chapter at a change of zone only once it has ten steps, so some
chapters hold steps of another zone (chapter 5 "Durotar" has 6 of 8 positions in the Barrens, chapter 9 "Undercity" 4 of 7 in Silverpine). Six
lone `.level N -- reach it first` steps have no place at all. The ten-step rule counts the steps as the planner wrote them (one place each), before
neighbouring ones are joined, so a finished chapter can hold fewer than ten (found by the algorithm review, 2026-10-21).

## Why

The Journal's chapter list shows the wrong zone for part of the route.

## Done when

A chapter is named after the zone most of its steps are in, or is split at every change of zone; a lone level step joins its neighbour.
