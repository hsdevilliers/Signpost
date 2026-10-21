---
title: Release 1 goes to GitHub first (zip for the friend); CurseForge when the project and token exist
kind: task
status: open
priority: normal
area: release
source: user
raised: 2026-10-21
---

## What

The user said (2026-10-21, asked whether the CurseForge project and API token exist): "Not yet, GitHub first". Release 1 therefore goes out as a tagged **GitHub release** (the addon zip built by CI, no Wowhead- or QuestieDB-derived tables) for the user's friend and for testing; CurseForge follows when the user has created the project and the `CF_API_KEY` secret (docs/PLAN.md, "CurseForge release", stays unchecked).

## Why

The friend who plays a HARDCORE druid for data collection needs a build to install, and the release is the minimum viable product. The user cannot create the CurseForge project today.

## Done when

- After batch 1 and the regeneration PR are on main: Claude prepares the version number and the release notes, runs the release checks, and asks the user for the go-ahead (publishing is never done without it); on a yes, the tag builds the zip on GitHub and the friend gets the link.
- docs/PLAN.md's CurseForge entry notes that Release 1 went to GitHub first; the CurseForge steps stay for later (project, `CF_API_KEY`, `## X-Curse-Project-ID` in both TOCs, the packager in CI).

## Notes

- The user's standing rule: tags and publishing need their go-ahead each time (CLAUDE.md, standing merge agreement).
- The user's in-game checks of the batch's features are planned for launch day (Nov 4), so the first release may go out with those verify items still open; the release notes say so.
