---
title: HARDCORE at levels 26 to 30: keep one level of margin, and what about the Gloomrise nest?
kind: question
status: done
priority: normal
area: planner, guides
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
closed: 2026-10-21
resolution: User answered 2026-10-21 in the session: keep the one-level margin, and keep skipping the Gloomrise nest until it has been seen in the game. No work; the four nest rules stay in tools/hardcore_rules.json.
---

## What

In plain words: a HARDCORE route only takes quests that are at most one level above you. At levels 26 to 30 the data has fewer quests of the right level for a Horde character, so a route sometimes has to stop and kill creatures for experience. You said before that grinding at a level gate is fine as long as the step says how much to grind (the planner's grind note is being built); the lead asked for numbers on whether a wider margin would help and what takes quests away at that range.

How much grinding is there? In the Tauren route first installed (generation 2) 1h05 of its 25h18 of play (4%). In the route now installed (generation 3, 807be15) 5h03 of its 27h43 (18%), in six gates at levels 15, 19, 22, 25, 29 and 30 (3, 450, 19,000, 4,600, 30,000 and 18,000 experience; 117 minutes at 29 alone); levels 27 to 30 take 67, 109, 129 and 132 minutes each. I did not find out why it grew (the thorough search's grains disagree by 11%, "The planner's search is rough"). A single default-beam run said 9h36 of grinding for generation 2's rules.

Would a wider margin help? Measured on generation 2 with the same thorough search (not repeated on generation 3), taking quests two levels above you from level 26 up gives 24h46 instead of 25h18 planned, and 19h00 instead of 19h13 simulated: about half an hour (2%), inside the search's own noise. Not worth fighting creatures two levels above you.

What takes quests away in that range? Of the 61 quests of levels 26 to 31 the planner could use for a normal route, a HARDCORE route keeps 44. The elite criterion (the data's creature ranks) removes 7 (about 42,000 experience), the Gloomrise nest rules of the Tauren review 4 (about 30,000), the two escorts 2 (5,000), quests that need one of those 3, and 1 is slower than grinding. The Skyborne worker's rules, merged since, remove 5 more (21,000).

## Question for the user

1. Keep the margin as it is (one level)? Recommendation: yes.
2. The new Gloomrise nest in northern Mulgore (four Forever quests of level 30 and 31, with a named Broodmother) is skipped because nobody knows whether its creatures are elite. Take it anyway (about 30,000 experience, a bit more than half a level at 29 to 30), or keep skipping it until someone has looked at it in the game? Recommendation: keep skipping until it has been seen.

## Done when

You answer. If the nest goes in, the rules 96241, 96259, 96260 and 96261 come out of tools/hardcore_rules.json and the Tauren route is planned again. If the margin changes, the planner's `hardcore_over` setting gets a command-line flag first (it has none).

## Notes

- Measured with scratch patches of the planner that are not in the repository: a margin of two from level 26 on (the beam and the thorough search) and the planner's pool for a normal and a HARDCORE route at quest levels 26 to 31. The results are in docs/reviews/horde-tauren-druid-walk.md.
- Related: "A grind step says how much experience to grind", "The planner's search is rough: near-identical settings differ by hours".
- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2), on the lead's instruction of 2026-10-21.
