---
title: The recorded event log does not say which character played: a quest cannot be attributed to a guide
kind: finding
status: open
priority: low
area: engine, tools
source: claude
raised: 2026-10-21
raised_in: WP-E2, tools/audit_quests.py
---

SignpostDB.eventLog (Core/Debug.lua) is account-wide and its entries carry no character, so tools/audit_quests.py cannot tell which of the account's characters was offered or accepted a quest. It judges a quest against a guide by the guide's faction, race and class and by the zones its route visits, which works for the guides' own start zones but misattributes a quest whose pack record has no race or class limit and whose zone a guide also visits (the Skyborne start quests carry no limit). Done when the recorder stamps each entry (or each session) with the character's race, class and faction (no name: the recorder must stay safe to hand to someone else, CLAUDE.md), and the audit uses it.
