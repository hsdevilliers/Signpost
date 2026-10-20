---
title: Game updates: what we do when Forever patches (Interface number, API changes, content)
kind: question
status: done
priority: normal
area: release, docs
source: user
raised: 2026-10-20
raised_in: the user, 2026-10-20
closed: 2026-10-20
resolution: docs/GAME-UPDATES.md (the runbook) and a standing rule in CLAUDE.md, written 2026-10-20 in the PR that adds this item
---

## What

From the user (2026-10-20): "what we plan to do, or how do we treat updates in the game, or updates to the game that will require us to update
our add-on ... If the answer is straightforward, then we can just write it up as a rule for the repo or a standing agreement or something of the
sort."

The answer was straightforward, so it is written down: `docs/GAME-UPDATES.md` is the runbook and CLAUDE.md carries the standing rule. In short:
a patch changes the Interface number (bump both TOCs after the client confirms the number), the API (errors and the probe, fixed in the owning
module) or the content (refresh the data pack, simulate, lint, re-plan, install on purpose). The user tells Claude when a patch is out; Claude
opens a backlog item from the runbook, works compatibility first and content second, and never publishes without the user's go-ahead.

## Why

A patch that bumps the Interface number disables an addon that was not updated, so the response has to be quick, ordered and checked in the
client, and it must not depend on anyone remembering what to do.

## Done when

The runbook and the standing rule are in the repository (this change). Changes the user wants to the rule are a new item that points to this one.
