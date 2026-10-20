# When the game updates

A standing agreement (user, 2026-10-20), for Claude Code and for whoever maintains the addon. WoW: Forever will patch. A patch can change
three different things, and each has its own signal and its own order of work.

## What a patch can change

| Layer | What changes | How we notice | What we do |
| --- | --- | --- | --- |
| The client's version | The Interface number. An addon with an older `## Interface:` shows as "out of date" and is disabled unless the player loads out-of-date addons. | `/signpost status` prints the client build, the interface and our TOC's; the recorder stores them in the SavedVariables (`Core/SavedVars.lua`). | Bump both TOCs (`tools/check_repo.py` keeps them equal). |
| The API | A function removed, renamed or restricted; new taint or "secret value" rules; UI templates. | Lua errors (`/signpost errors`, the report button), the probe (`/signpost probe`) against `docs/FOREVER-API-NOTES.md`. | Fix it in the module that owns the call; update the notes. |
| The content | Quests, XP and level tuning, zones, class quests, the level cap (the beta stops at 30; levels 31 to 60 are unverified). | Recorded sessions (`tools/validate_availability.py`), QuestieDB updates, the user's play. | Refresh the data pack, `guide_sim.py --check`, `guide_lint.py --strict`, re-plan, install routes on purpose. |

## Who starts it

The user tells Claude that a patch (or a PTR or beta build) is out, or sends errors or a SavedVariables file. Claude does not poll the game.
When asked it can read public patch notes and API change lists (Warcraft Wiki, Blizzard's pages; never Wowhead).

## The order: compatibility first, content second

1. **Open the item.** `python tools/backlog.py add "Game update <build>" --kind task --source user ...` with this list in the body, so the
   update is tracked and nothing is left only in conversation.
2. **Confirm the client's numbers.** Ask the user for the `/signpost status` line (client build, interface). An Interface number is never
   written from memory or guessed from patch notes.
3. **Bump both TOCs** (`## Interface:`, still the first line). A list of several interface versions in one TOC only after a probe shows that
   Forever accepts the list form (`-- VERIFY(...)`, FOREVER-API-NOTES "Open probes").
4. **Probe and errors.** The user logs in, runs `/reload`, `/signpost probe` and `/signpost errors`; Claude reads the SavedVariables
   (`tools/read_savedvars.py`) and compares them with FOREVER-API-NOTES and with the public API change notes for every function the addon calls.
5. **Fix** what broke, in the module that owns it (no workaround in unrelated code), with a spec; update FOREVER-API-NOTES.
6. **Content.** If quests, XP or zones changed: refresh the data pack (from the user's exports and QuestieDB, never Wowhead), then
   `python tools/guide_sim.py --check`, `python tools/guide_lint.py --strict`, re-run the Route Planner for the affected guides and install the
   new routes on purpose. Record it in `docs/PROGRESS.md`.
7. **Release.** Bump the version, write the changelog, tag the CurseForge file with the new game version. Publishing needs the user's go-ahead
   (CLAUDE.md "Workflow rules").
8. **Close the item** with the PR and the release. What was not done becomes a new backlog item.

## Versions

`X.Y.Z`, tagged `vX.Y.Z` (CI releases on tags). Z: a compatibility fix (an Interface bump, an API fix). Y: guide content or features.
X: a breaking change of the guide DSL or of the SavedVariables layout; the user is asked first (CLAUDE.md).

## Support

Only the current live version of Forever, and the beta or PTR while that is what the user plays. Old releases stay downloadable on
CurseForge; there are no back-ports unless the user asks for one. Recorded data carries the client build, so any session can be tied to the
patch it came from.
