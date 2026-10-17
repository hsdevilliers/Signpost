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

## Commands

`/signpost` (alias `/sign`) lists the commands. The developer commands `probe`, `dumpmaps` and `debug` write to
SavedVariables, which `tools/read_savedvars.py` reads after a `/reload`.

## License

MIT, see [LICENSE](LICENSE). The libraries in `Libs/` keep their own licenses ([Libs/README.md](Libs/README.md)).
