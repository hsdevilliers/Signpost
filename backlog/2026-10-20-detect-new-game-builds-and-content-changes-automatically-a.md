---
title: Detect new game builds and content changes automatically (a GitHub Action that opens the update issue)
kind: feature
status: open
priority: low
area: release, tools
source: user
raised: 2026-10-20
raised_in: the user, 2026-10-20, after the game-updates rule
---

## What

From the user (2026-10-20): "Isn't there some way we can automatically trigger the patching, you know, to support an update? It would be awesome
if, you know, you can just detect it somewhere online ... I don't know if there's some mechanism that you can have GitHub probe something, and
that triggers something to happen, and then we know that it's dirty, then we need to fix it." They suspected that fixing it automatically would
mean GitHub AI agents and a budget, are starting lean, and asked to discuss ("once we get budget, we can try and do stuff like that").

What the discussion of 2026-10-20 found (Claude): detection is cheap and needs no AI; the fix is where an agent would cost money.

- A scheduled GitHub Actions workflow (cron; free on standard runners for public repositories; GitHub pauses a scheduled workflow after 60 days
  without repository activity) checks a public source for a new build of the Forever product: Blizzard's patch version service (the one the
  launcher reads) or a community mirror that lists builds per product, beta included (wago.tools). The product code for Forever has to be read
  first from the install's `.build.info` (the `Product` column); then the source has to be checked for listing it.
- It compares the build and the version string with `docs/builds.json` (new, in the repository). On a change it opens an issue from the
  runbook (`docs/GAME-UPDATES.md`) and a pull request that bumps `## Interface:` in both TOCs and `docs/builds.json`, labelled "needs client
  check". The Interface number follows from the version string (major * 10000 + minor * 100 + patch: 1.60.1 is 16001, which is what the client
  reports). CI runs on that pull request. The workflow merges and releases nothing. GitHub tells the user by email or its mobile app.
- Content: a second check watches the QuestieDB repository for new commits that touch its Forever data (the public GitHub API; its data is
  read as data, as CLAUDE.md allows) and opens an issue "Forever data changed" for the import step.
- What cannot be automated: the check in the live client (`/signpost probe`, `/signpost errors`) and publishing a release (the user's go-ahead).
- Later, with budget: the Claude Code GitHub Action (it needs an Anthropic API key and runs only when something triggers it) pointed at those
  issues, to read the patch notes and API changes and draft the fix as a pull request for review. Until then Claude Code does that part when the
  user starts a session.

## Why

A patch that bumps the Interface number leaves an addon that was not updated disabled until the player allows out-of-date addons, so noticing
quickly matters, and nobody should have to watch patch notes by hand.

## Done when

- `docs/builds.json` exists and a scheduled workflow opens the issue and the TOC pull request when the build changes (tested with a faked build).
- The product code and a working public source for Forever builds are confirmed.
- The QuestieDB watcher is in, or dropped with a reason.

## Notes

- Reading `.build.info` is read-only; the game's own files are never changed (CLAUDE.md).
- Workflow files are not Lua or Python, so the repository's checks do not cover them: test the workflow by running it from a branch.
