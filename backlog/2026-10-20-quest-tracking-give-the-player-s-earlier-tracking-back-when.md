---
title: Quest tracking: give the player's earlier tracking back when the setting is turned off or the guide ends
kind: feature
status: open
priority: low
area: engine, ui
source: claude
raised: 2026-10-20
raised_in: PR feat/step-ui (quest tracking)
---

## What

Quest tracking follows the step (`Engine/Tracking.lua`) does not remember which quests the player tracked before it first changed the
list, so turning the setting off, or leaving the guide, keeps the last step's tracking. Version 1 does not give the player's tracking
back (decided for version 1, 2026-10-20).

## Why

A player who turns the setting off to get back to their own tracking has to track their quests again by hand.

## Done when

The module keeps the list it found at its first change and restores it when the setting is turned off or the guide is unloaded (and
says so in chat), or the user says it is not wanted.

## Notes

The step's own quests would still have to be told from the player's: only what the module added or removed is its to put back.
