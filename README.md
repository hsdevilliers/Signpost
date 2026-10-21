# Signpost

A step-by-step leveling guide for **World of Warcraft: Forever**: one small frame with the current step, the target
on the minimap and the world map, and explicit travel steps whenever the route changes zone. The engine, UI and guide
format are class-, race- and faction-agnostic; guides are plain text files.

**Status: pre-release.** The addon runs in the Forever beta client and its first guides are being tested; the guides stop at level 30
for now (the beta's cap, the range that can be checked in play). [`docs/PLAN.md`](docs/PLAN.md) has the plan and
[`docs/PROGRESS.md`](docs/PROGRESS.md) where it stands.

## Guides

| Guide | Levels now | Notes |
|---|---|---|
| Horde Troll Hunter | 1-30 | A normal route. Skinning and Leatherworking with First Aid, Cooking and Fishing as the default plan; the profession steps are a first cut with Classic's numbers, unverified in Forever |
| Horde Tauren Druid (HARDCORE) | 1-30 | Bear Form, Cat Form and the other class chains |
| Horde Skyborne (Windshaper) Druid (HARDCORE) | 1-30 | Starts on Zephras Isle and leaves it by the island story and the airship to Mulgore (from beta-era guides, unverified in the game) |

The two druid guides are built for **hardcore**: quests known to be deadly are skipped, not just flagged. A guide never changes zone
without a travel step in between (where the data does not know the way yet, the step says so in plain words), and every step has a
pin on the map. The guides are made by the Route Planner (`docs/PLANNER.md`); a quest it picks up and cannot finish on the way is left
out with a reason (`#skipquest ... not finished by this route`), never dropped silently.

## What you get

- A small step frame with the current step: a done mark on each quest, group quests coming up as a line of their own, and the choice
  to move it, lock it, scale it, let it grow upwards or hide it in combat.
- Pins on the world map and the minimap for the current target, one for each NPC of a pick-up or hand-in step.
- A journal window (`/signpost journal`) with every chapter and step, the Skip toggle for dungeon chapters, and manual moves.
- **Find my place**: start a guide at any level. Signpost reads your level and which of the guide's quests you have done and puts you
  at the right step (`/signpost place` or the Journal's button asks again; `<` takes it back). After a guide update your place is found
  again once from your quest history.
- The minimap button: left-click for the Journal, Shift-click for the step card, right-click for a quick menu (also on the step card
  and in the AddOn Compartment). The main actions are on the Key Bindings screen under Signpost.
- The quest tracker follows your step: only the quests of the current step are tracked, so the quest log's own marks show where to go
  (on by default; Journal > Settings turns it off).
- Optional automation (quest accept and turn-in, gossip, taxi, trainer, vendor), **all off by default**. Hold **Shift** while talking to
  an NPC to bypass it.
- "Report this step" for steps that are wrong or stuck; reports stay in your saved variables until you share them.
- Professions appear only as steps in the route, from per-profession tracks; the plan is detected from the professions you have learned.

## Install

Copy the `Signpost` folder into the client's `Interface\AddOns` directory (the Forever beta uses `_classic_beta_`), or install it from
CurseForge once it is published. Signpost runs standalone: guides carry their own quest IDs and coordinates.

## Commands

`/signpost` (alias `/sign`) lists them. The ones you will use: `show`, `hide`, `lock`, `grow`, `scale`, `alpha`, `journal`, `next`, `back`,
`skip`, `place`, `card`, `minimap`, `automation`, `report`, `contribute`, `status`. `/signpost tracking test` checks the client's quest
watch functions (the result is for the developers).

## Sharing data (optional)

You can let Signpost record where quest givers, enders, flight masters, innkeepers and trainers are, where boats and zeppelins dock, what
profession trainers teach and charge, your recipes and which quests you accept, so the next guide is better.
Nothing is collected until you agree in the consent window (`/signpost contribute`) and nothing leaves your machine by itself: the
recorded data sits in your saved variables. [`docs/SHARING-DATA.md`](docs/SHARING-DATA.md) explains what is recorded and how to send it.

## Development

The addon folder must be named `Signpost`. On a development machine `tools/dev_link.ps1` (Windows) or `tools/dev_link.sh` junction-links
the repository into the AddOns folder, using paths from `tools/dev.local.json` (copy `tools/dev.local.example.json`). An optional private
data pack (`Signpost_Data`) adds names, positions and validation; it is built locally with the tools and is not distributed.
Guide drafts are generated with `tools/guide_draft.py` and checked with `tools/guide_lint.py`; `tools/guide_sim.py` estimates the time
a route takes, and `tools/route_planner.py` searches for a faster one and explains what it did ([`docs/PLANNER.md`](docs/PLANNER.md): the quest
log limit `--quest-log`, required quests `--require`, finishing what a route accepts `--completeness`, the spread between grains in the report).
`docs/PLAY-CHECKLIST.md` lists the short things to do in the game that fill the gaps in the travel data.
What is left over (findings, open questions, notes) is kept in [`backlog/`](backlog/README.md); `python tools/backlog.py` lists what is open.

`tools/check.ps1` runs every check CI runs: busted, luacheck, StyLua, `tools/check_repo.py` and the Python tool tests.
One-time setup on Windows (everything except the compiler stays inside the gitignored `.venv`):

```
winget install --id BrechtSanders.WinLibs.POSIX.UCRT -e      # GCC (MinGW-w64, UCRT runtime)
python -m venv .venv
.venv\Scripts\python -m pip install hererocks
# with the WinLibs mingw64\bin folder on PATH, in a shell without NoDefaultCurrentDirectoryInExePath set:
.venv\Scripts\hererocks .venv\lua51 -l 5.1 -r latest --target mingw
# LuaRocks 3.8's Windows installer guesses wrong; in .venv\lua51\luarocks\config-5.1.lua set
#   MSVCRT = 'ucrt'   and   MAKE = [[<WinLibs>\mingw64\bin\mingw32-make.exe]]
.venv\lua51\bin\luarocks install busted
.venv\lua51\bin\luarocks install luacheck
```

StyLua 2.6.0 goes in `tools\bin\stylua.exe` (from the StyLua GitHub releases).

### Developer commands

`/signpost` (alias `/sign`) lists the commands. The developer commands `probe`, `dumpmaps` and `debug` write to
SavedVariables, which `tools/read_savedvars.py` reads after a `/reload`. Dev builds (git checkouts) record events by
themselves; `/signpost debug off` stops that for good, `/signpost debug on` turns it back on.

## License

MIT, see [LICENSE](LICENSE). The libraries in `Libs/` keep their own licenses ([Libs/README.md](Libs/README.md)).
