---
title: guide_sim --params without escort_seconds or event_seconds crashes on the first scripted quest
kind: bug
status: open
priority: low
area: tools
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-tools
---

## What

A `--params` file for `tools/guide_sim.py` that lacks `escort_seconds` or `event_seconds` raises a KeyError at `guide_sim.py` about line 211 on the first quest the pack flags `scripted`. The
defaults live in `tools/sim_params.json`, which a custom file replaces instead of overriding. Found by the independent review R-tools (batch 1), confirmed.

## Done when

- A params file overrides the defaults key by key (or the missing keys fall back to them), with a test that omits both keys.
