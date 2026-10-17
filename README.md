# Signpost

A step-by-step leveling guide for **World of Warcraft: Forever**: one small frame with the current step, the target
on the minimap and the world map, and explicit travel steps whenever the route changes zone. The engine, UI and guide
format are class-, race- and faction-agnostic; guides are plain text files.

**Status: pre-alpha (Phase 0: skeleton and client probes).** Nothing here is playable yet. See
[`docs/PLAN.md`](docs/PLAN.md) for the plan and [`docs/PROGRESS.md`](docs/PROGRESS.md) for where it stands.

## Install (development)

The addon folder must be named `Signpost` inside the client's `Interface\AddOns` directory. A plain `git clone`
works; on a development machine, `tools/dev_link.ps1` (Windows) or `tools/dev_link.sh` junction-links the repository
instead, using paths from `tools/dev.local.json` (copy `tools/dev.local.example.json`).

Signpost runs standalone: guides carry their own quest IDs and coordinates. An optional data pack (`Signpost_Data`)
adds names, objective text and validation; it is built locally with the exporters in `tools/` and is not distributed.

## Development

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

## Commands

`/signpost` (alias `/sign`) lists the commands. The developer commands `probe`, `dumpmaps` and `debug` write to
SavedVariables, which `tools/read_savedvars.py` reads after a `/reload`. Dev builds (git checkouts) record events by
themselves; `/signpost debug off` stops that for good, `/signpost debug on` turns it back on.

## License

MIT, see [LICENSE](LICENSE). The libraries in `Libs/` keep their own licenses ([Libs/README.md](Libs/README.md)).
