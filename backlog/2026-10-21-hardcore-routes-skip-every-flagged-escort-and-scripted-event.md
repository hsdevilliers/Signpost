---
title: HARDCORE routes skip every flagged escort and scripted-event quest, except class quests and prerequisites
kind: task
status: open
priority: normal
area: planner, hardcore
source: user
raised: 2026-10-21
---

## What

The user chose (2026-10-21, answering the question in the session): a HARDCORE route **skips every escort and scripted-event quest the data flags** (`scripted` in the pack, QuestieDB `specialFlags` bit 2, 133 quests), **except class quests and quests another routed quest depends on**. Today a HARDCORE route prices them and writes a risk note; only the hand-kept list in `tools/hardcore_rules.json` (863 and 898) skips a quest.

Applied after batch 1, in the same regeneration pass as the completeness default (the user: "only add more items to this batch if really needed").

## Why

A HARDCORE character that dies is gone, and an escort is the quest type most likely to kill or strand one. docs/HARDCORE.md already says the policy is to skip escorts; the flag now makes it automatic. A normal route (the Troll Hunter) is unchanged.

## Done when

- The planner (HARDCORE only) leaves out a `scripted` quest unless it is a class quest or a prerequisite of a quest the route takes, with the skip reason `HARDCORE: escort or scripted event` in the guide's `#skipquest` lines; specs and a mutation check for the rule.
- The bit may also cover a few harmless quests (the independent tools review of batch 1 says it "may also cover exploration"): the PR body lists the quests skipped in each HARDCORE guide, in plain words, so the user can see what was caught.
- Both HARDCORE guides are regenerated (one pass with the completeness default); docs/HARDCORE.md says the rule; the question item `hardcore-routes-should-every-escort-and-event-the-data-flags` is closed with the user's answer.

## Notes

- Needs batch 1 on main (the flag and the pricing are in it) and the pack commit that carries `scripted`.
