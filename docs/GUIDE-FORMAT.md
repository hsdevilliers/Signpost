# Guide format (the Signpost DSL)

The canonical specification; PLAN §5 was the first sketch. `Engine/Parser.lua` (in game) and `tools/guide_lint.py`
(offline) both implement exactly this file — change it first, then both. Module APIs are in `docs/ENGINE.md`.

## Files

A **guide** — `Guides/<Name>.lua`:

```lua
local ADDON_NAME, ns = ...

ns.Guides:Register({
	id = "horde-troll-hunter-1-60",
	name = "Troll Hunter 1-60",
	faction = "Horde", -- "Horde", "Alliance" or "*"
	races = { "Troll" }, -- raceFile tokens, or { "*" }
	classes = { "HUNTER" }, -- classFile tokens, or { "*" }
	levels = { 1, 60 },
	text = [[
#professions skinning,leatherworking,firstaid,cooking,fishing
#include durotar-1-6
...
]],
})
```

The table passed to `Register` is a **pure literal** (strings, numbers, booleans, tables; no variables or calls) so the
offline tools can read it with a literal parser. The same holds for the two other file kinds:

- a **chapter** — `Guides/Chapters/<chapterId>.lua`: `ns.Chapters:Register("durotar-1-6", [[ ... ]])`. Chapter ids are
  lowercase letters, digits and `-`.
- a **profession track** — `Guides/Professions/<key>.lua`: `ns.Professions:RegisterTrack("skinning", [[ ... ]])`.

Use `[[ ... ]]`, or `[=[ ... ]=]` when the text itself contains `]]`.

## Lines

- One statement per line. Leading whitespace is indentation for readability only. Blank lines are ignored.
- `--` at the start of a line, or ` --` (whitespace then two dashes) anywhere, starts a comment to the end of the line.
- Statements: header lines starting with `#`, `step` lines, and directive lines starting with `.`. Directive lines
  belong to the most recent `step`; a directive line before any `step` is an error.
- Anything else is an error (recorded, line skipped).

## Header statements

| Statement | Where | Meaning |
|---|---|---|
| `#professions <key>,<key>,...` | guide | profession suggestions for free slots (PLAN §3.8) |
| `#guide <text>`, `#author <text>`, `#version <text>` | guide | display metadata (the `Register` table wins for `name`) |
| `#class <list>`, `#race <list>`, `#faction <name>` | guide | informational; selection uses the `Register` table |
| `#include <chapterId>` | guide or chapter | splice that registered chapter's text here, before gating; nested includes are fine, a cycle or unknown id is an error |
| `#chapter <levels> <name> [#dungeon]` | guide or chapter | start a chapter; `<levels>` is `N` or `N-M`; `#dungeon` makes it a dungeon chapter (Skip toggle, PLAN §3.3) |
| `#skipquest <questID> >> <reason>` | guide or chapter | the class/profession quest coverage lint accepts this quest as skipped on purpose |
| `#track <key>` | track | first statement of a track file |

Steps in a guide's own text before its first `#chapter` form an implicit chapter named after the guide, levels from
`Register.levels`.

## Steps

```
step                                   -- a route step
step @hub orgrimmar                    -- a track step: exactly one anchor (track files only)
  .goto 1411,42.1,68.7                 -- a directive line
  .accept 787 >> Accept the first quest   -- ">> text" replaces this line's generated description
  .accept 4402 .class HUNTER           -- a trailing gate filters this directive line only
  .race Troll                          -- a gate on its own line filters the whole step
```

**Anchors** (track steps only): `@hub <name>`, `@level <N>`, `@zone <uiMapID>`; see Track merging.

**Gates** are resolved at parse time, never at runtime:

| Gate | Matches against |
|---|---|
| `.class <list>` | `ns.Player.classFile` |
| `.race <list>` | `ns.Player.raceFile` |
| `.faction <Horde\|Alliance>` | `ns.Player.faction` |
| `.prof <list>` | the character's detected profession plan (keys), never the learned skills alone |
| `.hc` | reserved for Hardcore; always false for now |

A list is comma-separated without spaces. An item prefixed `!` is negated. A gate passes when any plain item matches;
a list of only negated items passes when none of them matches; mixed lists need a plain match and no negated match.
A gate line anywhere in a step gates the whole step. A step whose directive lines are all gated away is dropped.

## Directives

Arguments are comma-separated unless noted; `<map>` is a uiMapID; `x`/`y` are percent (0–100) of that map; a
`<key>` is a profession key (`skinning`, `firstaid`, ...). A step **completes** when every completable directive in it
is satisfied (directives about a quest named by `.optional` don't count). A step with no completable directive
completes only by the player's `>`.

Core directives (`Engine/Directives.lua`):

| Directive | Satisfied when | Pin |
|---|---|---|
| `.goto <map>,<x>,<y>[,<radius>]` | the player is within radius yards (default 10) — only if it is the step's only completable directive; otherwise it just places the pin | yes |
| `.accept <questID>` | the quest is in the log, or flagged completed | quest giver (data pack) or the step's `.goto` |
| `.turnin <questID>` | the quest is flagged completed | quest ender |
| `.complete <questID>[,<objective>]` | that objective (or all) is finished, or the quest is complete or turned in | objective area |
| `.optional <questID>` | — (modifier: this quest's directives don't block completion) | |
| `.reward <questID>,<choice\|itemID>` | — (read by automation) | |
| `.train <spellID>` / `.train class` | the spell is known; `class` = every spell the class module lists for the current level | trainer |
| `.trainprof <key>` | the profession is learned, or its maximum skill rose since the step became current | trainer |
| `.skill <key> <N>` | skill ≥ N | |
| `.craft <spellID>,<count>` | the player cast that recipe `count` times since the step became current | |
| `.fish <map>,<x>,<y>` | — (pin for a fishing spot; pair with `.skill`/`.collect`) | yes |
| `.buy <itemID>,<count>` / `.collect <itemID>,<count>` | at least `count` in bags | vendor / source |
| `.use <itemID>` | — (quest-item button; pair with `.complete`) | |
| `.level <N>` | player level ≥ N | |
| `.todo "<reason>"` | never (the step shows the reason; the lint counts it) | |
| `.note <text>`, `.text <text>`, `.link <url>` | — (display; `.link` is copyable in the journal) | |
| `.sticky <directive line>` | the inner directive; it stays active beside later steps until satisfied | per inner |
| `.hub <name>` | — (marks a visit to a town for profession tracks) | |

Travel directives (`Engine/Travel.lua`):

| Directive | Satisfied when | Pin |
|---|---|---|
| `.path <map>,<x>,<y> ; <map>,<x>,<y> ; ...` | the last waypoint is reached (each within 15 yd, in order) | next waypoint (minimap), all (world map, with lines) |
| `.zone <map>` | the player's map is `<map>` or below it in the map tree | |
| `.fp <map>,<node name>` | the flight path is known | flight master |
| `.fly <node name>` | the player was on a taxi and has landed in the node's zone | flight master, then the node |
| `.boat <map>,<x>,<y> > <map>,<x>,<y>` / `.zeppelin ...` | in the destination's zone, or within 200 yd of the arrival dock, after boarding | departure, then arrival |
| `.hs <inn name>` | `GetBindLocation()` is the inn | innkeeper |
| `.home` | the zone changed to the bind location's after the hearthstone cast | |

Class directives come from class modules (`Classes/<CLASS>.lua`): e.g. `.tame <npcID>`, `.ammo ...`. Using one in a
chapter without a `.class` gate is a lint error.

## Display text

Each directive generates a description (`Accept "The Basics"`; names from the data pack, else `Quest #787`). `>> text`
replaces that line's description; `.text`/`.note` add lines of their own.

## Stable step ids

Every step gets an id that survives gate and profession-plan changes, so saved progress keeps pointing at the right step:
`<sourceId>:<n>`, where `<sourceId>` is the registered chapter id or the guide id (for steps in the guide's own text),
or `track:<key>` for track steps, and `<n>` is the 1-based position of the step in that source text **before** gating
and merging.

## Track merging

After `#include` resolution and gating, each profession in the plan (primaries first, then secondaries, in plan order)
merges its track's gated steps into the route, in track order, each after the insertion point of the track's previous
step:

- `@hub <name>` — right after the first route step marked `.hub <name>`;
- `@level <N>` — before the first step of the first chapter whose minimum level is ≥ N;
- `@zone <map>` — before the first route step whose first `.goto`/`.path` target is in `<map>` or below it.

Several tracks anchored at the same place keep plan order. A track step without a match is dropped with an error (the
lint reports it per guide).

## Errors

The parser never throws on guide text. It records `{ source = <sourceId>, line = <n>, message = <text> }` in
`guide.errors`, skips the offending line (or step), and goes on.
