---
title: Planned routes may grind at level gates (2h23 in one, 0h30 in the next): how much grinding is acceptable?
kind: question
status: done
priority: low
area: planner, guides
source: claude
raised: 2026-10-21
raised_in: final independent review of the beam rewrite (PR #38), 2026-10-21
closed: 2026-10-21
resolution: Answered by the user (2026-10-21): grinding at a gate is fine, and the guide may tell the player to grind an amount of experience at certain points. The planner does not charge for it. What is left is to say the amount in the step: the item 'A grind step says how much experience to grind'.
---

## What

The simulator said the first route installed in PR #38 spent 8,605 s (2h23, 14% of its 17h31) at `.level` gates, where the character has nothing
better to do than grind to the level a quest asks for (the route before it: 1,548 s). The planner prices this grinding (an edge: "reach level N
first"), and it is the cheaper choice under its model, but a player does not enjoy two and a half hours of killing nothing in particular. The route
that was installed in the end (the search compared as written, PR #38) spends 0h30 of its 17h10 there, so the problem is a property of some routes the
planner can make, not of the guide that ships. Found by the final review of PR #38.

**Question for the user: is grinding at a level gate fine, or should a route avoid it at some cost in total time?**

## Why

The planner minimises time. If the player's patience counts for more than the minutes, the search should charge grinding (the way it charges
class quests done late) or prefer quests that need no grinding. Only the user can say.

## Done when

The user has answered. If grinding should cost more: a setting (a charge per minute ground, or a cap on the share of the route) in the planner
with a flag, a report line that says how much of the route is grinding, and a test. If it is fine: this item is closed with that answer.

## Notes

- The report's time breakdown already shows "grinding for a level"; the simulator prints "level-gate grinding" per guide.
