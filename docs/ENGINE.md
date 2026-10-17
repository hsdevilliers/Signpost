# Engine and UI contracts

The interfaces the addon's modules code against. Wave 1 builds these modules in parallel (one track each), so a
module may add functions but must not change or drop anything listed here without updating this file first (tracks
propose changes in their report; the integrator decides). The guide language is `docs/GUIDE-FORMAT.md`; the
architecture is PLAN §4.

## Conventions

- Every Lua file starts with `local ADDON_NAME, ns = ...`; each module is a table on `ns` (`ns.Parser`, ...). No new
  globals (CLAUDE.md).
- Modules call each other **at call time** (`ns.Context:...` inside functions), never at file load; TOC order only
  matters for registration (a registry loads before the files that register into it).
- Game events through `ns.Events:Register`, internal messages through `ns.Events:RegisterMessage`/`ns.Events:Fire`
  (both already run handlers under `ns.SafeCall`). Timer callbacks wrap their work in `ns.SafeCall`.
- Defaults for saved settings: call `ns.SavedVars:RegisterDefaults(scope, key, value)` at file load (`scope` is
  `"account"` for `SignpostDB` or `"char"` for `SignpostCharDB`); never edit `Core/SavedVars.lua`'s defaults table.
- User-facing strings through `ns.L[...]`. Class, race, faction and profession names only in `Classes/`,
  `Professions/`, `Guides/` (tools/check_repo.py). Never arithmetic on secret values (`ns.Util.IsSecret`).
- Lua 5.1, StyLua-formatted, luacheck-clean.

## Internal messages

| Message | Fired by | Arguments |
|---|---|---|
| `DB_READY` | Core/SavedVars | — |
| `PLAYER_PROFESSIONS_CHANGED` | Core/Player | `ns.Player.professions` |
| `PROFESSION_PLAN_CHANGED` | Engine/Professions | plan |
| `CONTEXT_CHANGED` | Engine/Context | what: `"quests"`, `"spells"`, `"skills"`, `"bags"`, `"level"`, `"zone"`, `"position"`, `"taxi"`, `"bind"` |
| `GUIDE_LOADED` | Engine/Progress | guide |
| `STEP_CHANGED` | Engine/Progress | step, index, reason (`"load"`, `"auto"`, `"manual"`) |
| `TRANSPORT_STATE` | Engine/Travel | stepId, state |

## Data shapes

```lua
guide = {
	id = "horde-troll-hunter-1-60", name = "Troll Hunter 1-60",
	def = registerTable, -- what Guides:Register received
	headers = { professions = { "skinning", ... }, author = "...", version = "..." },
	chapters = { { id = sourceId, name = "Valley of Trials", levels = { 1, 6 }, dungeon = false, first = 1, last = 12 } },
	steps = { step, ... }, -- route order after gating and track merging
	byId = { [stepId] = step },
	skipQuests = { [questID] = reason },
	errors = { { source = sourceId, line = 12, message = "..." } },
}

step = {
	id = "durotar-1-6:3", -- GUIDE-FORMAT "Stable step ids"
	index = 3, -- position in guide.steps
	chapter = 1, -- index into guide.chapters
	source = "durotar-1-6", line = 14,
	directives = { directive, ... }, -- in line order, without the sticky ones
	sticky = { directive, ... }, -- from .sticky lines
	optional = { [questID] = true },
	hub = "razorhill", -- from .hub, or nil
	track = "skinning", anchor = { kind = "hub" | "level" | "zone", value = "orgrimmar" }, -- track steps only
}

directive = { name = "accept", args = parsedArgs, text = ">> override or nil", line = 15, def = directiveDef }

target = {
	map = 1411, x = 42.1, y = 68.7,
	kind = "goto" | "accept" | "turnin" | "objective" | "waypoint" | "taxi" | "dock" | "inn" | "trainer" | "vendor"
		| "fish" | "gather",
	label = "text for the tooltip", radius = 10, -- yards, optional
	index = 2, -- waypoint number, optional
	npc = 3143, object = nil, questID = 787, -- optional
}

plan = { primary = { "skinning", "leatherworking" }, secondary = { "firstaid", "cooking", "fishing" }, declined = { [key] = true } }
```

## Modules

### Core/Player.lua — `ns.Player`

Existing identity fields (`className`, `classFile`, `classID`, `classBase`, `raceName`, `raceFile`, `raceID`, `faction`,
`factionName`, `level`), plus `professions = { [skillLineID] = { key = professionKey | nil, name, rank, max } }`,
refreshed at `PLAYER_LOGIN` and `SKILL_LINES_CHANGED`; fires `PLAYER_PROFESSIONS_CHANGED` when it changes.

### Engine/Registry.lua — `ns.Guides`, `ns.Chapters`, `ns.Classes`

- `ns.Guides:Register(def)` (GUIDE-FORMAT "Files"); `:Get(id)`; `:All()` (sorted by name).
- `ns.Guides:Compatible(def, player)` → `ok, reason` (faction, race, class; `"*"` matches all).
- `ns.Guides:Best(player)` → def or nil: exact race + class, then class only, then faction only (PLAN §3.5); ties by id.
- `ns.Guides:Selected()` → `SignpostCharDB.guide` when still compatible, else `Best`; `:Select(id)` stores the choice.
- `ns.Chapters:Register(id, text)`; `:Get(id)` → text.
- `ns.Classes:Register(classFile, module)`; `:Get(classFile)`. A module may hold `trainerSpells = { [level] = { spellIDs } }`,
  `classQuests`, `directives = { [name] = directiveDef }` (registered into `ns.Directives`), `classTab`, `automation`,
  `onLevelUp`.

### Engine/Professions.lua — `ns.Professions`

- `:Register(key, module)` — `module = { skillLine = id, primary = bool, gathering = bool, ranks = { 75, 150, 225, 300 },
  directives = {...} }`; `:Get(key)`; `:ForSkillLine(id)` → key, module.
- `:RegisterTrack(key, text)`; `:Track(key)` → text.
- `:Plan(suggestions)` → plan, detected per PLAN §3.8 from `ns.Player.professions`, the guide's `#professions`
  suggestions and `SignpostCharDB.declinedProfessions`.
- `:Decline(key)`, `:Restore(key)` — persist; fire `PROFESSION_PLAN_CHANGED`.
- `:Merge(guide, plan, opts)` — inserts the plan's tracks into a parsed guide (GUIDE-FORMAT "Track merging"), using
  `ns.Parser:ParseTrack`; re-numbers `step.index`, rebuilds `guide.byId`, appends errors.
- Fires `PROFESSION_PLAN_CHANGED(plan)` whenever the detected plan changes.

### Engine/Parser.lua — `ns.Parser`

- `:Headers(def)` → headers, read without a full parse (so the plan can be detected first).
- `:ParseGuide(def, opts)` → guide. `opts = { player = ns.Player, plan = plan }`. Resolves `#include` through
  `ns.Chapters:Get`, applies gates, builds chapters and steps, then `ns.Professions:Merge(guide, opts.plan)` when a
  plan is given.
- `:ParseTrack(key, text, opts)` → `steps, errors` (with `anchor`; gates applied with `opts.player`/`opts.plan`).
- Directive arguments are parsed by `ns.Directives:Get(name).parse(argString, ctx)` with
  `ctx = { source, line, guideId }`; an unknown directive or a parse failure becomes an error entry.

### Engine/Directives.lua — `ns.Directives`

- `:Register(name, def)`, `:Get(name)`, `:Names()`.
- `def = { parse, isSatisfied, targets, describe, onStart, kind, completable }`:
  - `parse(argString, ctx)` → args, or `nil, message`;
  - `isSatisfied(args, context, state)` → boolean (absent: not completable);
  - `targets(args, context, state)` → `{ target, ... }`;
  - `describe(args, context)` → string;
  - `onStart(args, context, state)` — when the step becomes current (e.g. remember the skill maximum);
  - `kind` — `"quest"`, `"travel"`, `"profession"`, `"misc"` (icon hint); `completable` defaults to `isSatisfied ~= nil`.
- `context` is `ns.Context`; `state` is a per-step, per-directive table owned by `ns.Progress`.
- Registers every core directive of GUIDE-FORMAT. Travel directives come from `Engine/Travel.lua`, class and profession
  directives from their modules.

### Engine/Conditions.lua — `ns.Conditions`

- `:IsComplete(step, context, states)` → `complete, detail` (`detail[i]` per directive).
- `:Targets(step, context, states)` → targets of the step's directives (sticky ones included, marked `sticky = true`).
- `:Describe(step, context)` → `{ line, ... }` (descriptions, `>>` overrides, `.text`/`.note`, objective progress).
- `states` maps directive index → state table (from `ns.Progress:State(step.id)`).

### Engine/Context.lua — `ns.Context`

Cached player state, refreshed by events, cheap to query:

- `:QuestInLog(id)`, `:QuestCompleted(id)` (flagged), `:QuestReady(id)` (in log, objectives done), `:Objectives(id)` →
  `{ { text, type, finished, have, need } }`;
- `:SpellKnown(spellID)`; `:Skill(skillLineID)` → rank, max; `:ItemCount(itemID)`; `:Level()`;
- `:Position()` → `{ map, x, y, wx, wy, instance, taxi }` or nil; `:InMap(mapID, rootMapID)` (map tree via
  `C_Map.GetMapInfo` parents, cached); `:Distance(map, x, y)` → yards or nil (HereBeDragons); `:OnTaxi()`;
- `:BindLocation()`; `:TaxiNodeKnown(name)` → true/false/nil; `:NoteTaxiNodes(nodes)` (fed at `TAXIMAP_OPENED`);
- `:Now()`.
- Fires `CONTEXT_CHANGED(what)`, at most once per 0.2 s per `what`.

### Engine/Travel.lua — `ns.Travel`

- Registers the travel directives (`.path`, `.zone`, `.fp`, `.fly`, `.boat`, `.zeppelin`, `.hs`, `.home`).
- `:RegisterBorders(list)` — `Guides/Travel/Borders.lua` calls it with
  `{ { name = "Durotar/The Barrens west road", from = { map, x, y }, to = { map, x, y } }, ... }`; `:Borders()`.
- `:TransportState(stepId)` → `"waiting"`, `"boarded"`, `"arrived"`; fires `TRANSPORT_STATE`.

### Engine/Progress.lua — `ns.Progress` (and the engine's start-up)

- Start-up at `PLAYER_LOGIN` (after `ns.Player` refreshed): `ns.Guides:Selected()` → `ns.Parser:Headers` →
  `ns.Professions:Plan` → `ns.Parser:ParseGuide` → `:SetGuide`. Re-parses on `PROFESSION_PLAN_CHANGED`.
- `:SetGuide(guide)`, `:Guide()`, `:Current()` → step, index, `:Sticky()` → active sticky steps.
- `:Next()`, `:Back()`, `:Skip()`, `:JumpTo(index)` — manual moves win for the session (PLAN §3.3).
- `:Evaluate()` — at most once per second, on `CONTEXT_CHANGED`: advance past completed steps, auto-skip upcoming steps
  already satisfied, keep stickies.
- `:State(stepId)` → per-directive state tables (calls `def.onStart` when a step becomes current).
- Saves `SignpostCharDB.progress[guideId] = { current = stepId, skipped = { [stepId] = true }, done = { [stepId] = true } }`.
- Fires `GUIDE_LOADED`, `STEP_CHANGED`. Registers `/signpost next|back|skip|step`. With `SignpostDB.debug.chat` it
  prints every step change (the Phase 2 acceptance walk).

### Core/Learn.lua — `ns.Learn`

Always on (cheap), recording into `SignpostDB.learned` as the player plays:
`npcs[npcID]` and `objects[objectID]` = `{ n = name, map, x, y, t, c = timesSeen }` at quest dialogs, gossip, trainers,
vendors and flight masters; `quests[questID] = { start = { npc | obj = id }, finish = {...}, t }` at accept and turn-in;
`taxi[nodeName] = { map, x, y, npc, t }`; `crossings = { { from = { map, x, y }, to = { map, x, y }, t }, ... }` at
`ZONE_CHANGED_NEW_AREA`; `trainers[npcID] = { spells }`; `vendors[npcID] = { itemIDs }`. Bounded sizes.
`tools/import_savedvars.py --merge-learned` turns it into `layers/learned.json` and rebuilds the data pack.

### UI/StepFrame.lua and UI/Pins.lua — `ns.StepFrame`, `ns.Pins`

- React to `GUIDE_LOADED`, `STEP_CHANGED`, `CONTEXT_CHANGED`, `TRANSPORT_STATE`; read `ns.Progress:Current()`/`:Sticky()`
  and `ns.Conditions:Describe`/`:Targets`.
- Settings via `RegisterDefaults("account", "stepFrame", ...)` and `("account", "pins", ...)`.
- `/signpost show|hide|lock|reset`. Pins through HereBeDragons-Pins-2.0 (minimap + world map, waypoint lines);
  atlases per FOREVER-API-NOTES (there is no `Vendor` atlas).

## TOC order (integration adds the lines; tracks never edit the TOCs)

```
Core\Init.lua, Core\Errors.lua, Libs\..., Core\Util.lua, Core\SavedVars.lua, Core\Player.lua, Data\Schema.lua,
Core\Slash.lua, Core\Debug.lua, Core\Probe.lua, Core\MapDump.lua, Core\Learn.lua,
Engine\Registry.lua, Engine\Directives.lua, Engine\Context.lua, Engine\Parser.lua, Engine\Professions.lua,
Engine\Conditions.lua, Engine\Travel.lua, Engine\Progress.lua,
Classes\*.lua, Professions\*.lua, Guides\Travel\Borders.lua, Guides\Chapters\*.lua, Guides\Professions\*.lua,
Guides\*.lua, UI\Widgets.lua, UI\StepFrame.lua, UI\Pins.lua
```

## Wave 1 tracks and file ownership

A track creates and edits only its own files. Shared files — the TOCs, `docs/PROGRESS.md`, `docs/PLAN.md`,
`CLAUDE.md`, this file, `docs/GUIDE-FORMAT.md`, `tests/wow_mock.lua`, `tests/helpers/addon.lua`,
`Core/SavedVars.lua` — belong to the integrator: put what you need from them in your report. `.luacheckrc`: add any
missing read globals in alphabetical position (the integrator resolves merges).

| Track | Owns |
|---|---|
| data-questie | `tools/questie_import.py`, its tests, `Data/Schema.lua` (field docs), the private pack (`../Signpost_Data`) |
| data-wowhead | `tools/wowhead_export.py`, `tools/wowhead_env.py`, `tools/signpost_tools/wowhead.py`, their tests |
| engine-parser | `Engine/Parser.lua`, `tests/parser_spec.lua` |
| engine-directives | `Engine/Directives.lua`, `Engine/Conditions.lua`, `tests/directives_spec.lua`, `tests/conditions_spec.lua` |
| engine-context | `Engine/Context.lua`, `tests/context_spec.lua` |
| engine-progress | `Engine/Progress.lua`, `tests/progress_spec.lua` |
| engine-travel | `Engine/Travel.lua`, `Guides/Travel/Borders.lua`, `tests/travel_spec.lua` |
| engine-registry | `Engine/Registry.lua`, `Engine/Professions.lua`, `Core/Player.lua`, `tests/registry_spec.lua`, `tests/professions_spec.lua` |
| tools-lint | `tools/guide_lint.py`, `tools/guide_travel.py`, `tools/signpost_tools/guidefile.py`, their tests |
| learn | `Core/Learn.lua`, `tests/learn_spec.lua`, `--merge-learned` in `tools/import_savedvars.py`, its tests |
| ui | `UI/StepFrame.lua`, `UI/Pins.lua`, `tests/ui_spec.lua` |

## Testing

- busted specs in `tests/<area>_spec.lua`. Load modules that are not in the TOC yet with
  `addon.load({ extra = { "Engine/Parser.lua", ... } })`; set client globals through `addon.G`.
- Extra mocks go in your own `tests/mocks/<area>.lua`. Other modules a spec needs can be stubbed in the spec (each track
  is built in parallel; integration then runs everything together).
- Python tool tests in `tools/tests/test_<tool>.py` (unittest, standard library only).
- `pwsh -NoProfile -File tools/check.ps1` passes in your worktree before you finish.
