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
Items compare case-insensitively. A gate line anywhere in a step gates the whole step (several gate lines must all
pass). A step whose directive lines are all gated away is dropped. A trailing gate (several are allowed) stands at the
very end of the line or right before `>>`; a gate anywhere else in the arguments is an error. `.hc` takes no list; with
no profession plan, `.prof` sees an empty plan.

## Directives

Arguments are comma-separated unless noted; `<map>` is a uiMapID; `x`/`y` are percent (0–100) of that map; a
`<key>` is a profession key (`skinning`, `firstaid`, ...). A step **completes** when every completable directive in it
is satisfied (directives about a quest named by `.optional` don't count). A step with no completable directive
completes only by the player's `>`.

Core directives (`Engine/Directives.lua`):

| Directive | Satisfied when | Pin |
|---|---|---|
| `.goto <map>,<x>,<y>[,<radius>]` | the player is within radius yards (default 10) — only if it is the step's only completable directive; otherwise it just places the pin | yes (none in a doing step: see "Step kinds") |
| `.accept <questID>` | the quest is in the log, or flagged completed | quest giver (data pack) or the step's `.goto` |
| `.turnin <questID>` | the quest is flagged completed | quest ender |
| `.complete <questID>[,<objective>]` | that objective (its number in the quest log, from 1) or all are finished, or the quest is complete or turned in | objective area (none in a doing step: see "Step kinds") |
| `.optional <questID>` | — (modifier: this quest's directives don't block completion) | |
| `.reward <questID>,<choice\|itemID>` | — (read by automation); a value up to 10 is a choice index, a larger one an item ID | |
| `.train <spellID>` / `.train class` | the spell is known; `class` = every spell the class module lists at or below the player's level | trainer |
| `.trainprof <key>` | the profession is learned, or its maximum skill rose since the step became current, or there is nothing to train (its top rank, or skill more than 25 below the maximum) | trainer |
| `.skill <key> <N>` | skill ≥ N | |
| `.craft <spellID>,<count>` | the player cast that recipe `count` times since the step became current | |
| `.fish <map>,<x>,<y>` | — (pin for a fishing spot; pair with `.skill`/`.collect`) | yes |
| `.buy <itemID>,<count>` / `.collect <itemID>,<count>` | at least `count` in bags | vendor / source |
| `.use <itemID>` | — (quest-item button; pair with `.complete`) | |
| `.level <N>` | player level ≥ N | |
| `.todo "<reason>"` | never by itself (the step shows the reason; the lint counts it); beside another completable directive it is only a note and the step completes on those (user decision 2026-10-20), a step that is only a `.todo` waits for `>`; the quotes are optional (the lint warns without them) | |
| `.note <text>`, `.text <text>`, `.link <url>` | — (display; `.link` is copyable in the journal) | |
| `.sticky <directive line>` | the inner directive, which must be one that can be satisfied (never a gate, `.sticky`, `.optional`, `.hub`, `.note`, ...); it stays active beside later steps until satisfied once. A step with nothing but sticky directives completes at once | per inner |
| `.hub <name>` | — (marks a visit to a town for profession tracks; one per step) | |

`.complete` pins (in a step that is not a doing step: see "Step kinds"): the data pack's objective records are
references in the source's own order, not the quest log's; each quest log objective is paired with the pack objective
whose NPC, object or item its text names, else with the next one of its kind (`monster` → kill, `item`, `object`).
Kill-credit objectives pin the creatures that give the credit, item objectives the creatures and objects the item drops
from, explore objectives their area.

A `.complete` line shows the quest and nothing else (`Complete "<quest>"`, or `Complete objective 2 of "<quest>"` for the
per-objective form): never an objective's counters ("Mottled Boar slain: 3/10"), in any step. The quest log has them.

Travel directives (`Engine/Travel.lua`):

| Directive | Satisfied when | Pin |
|---|---|---|
| `.path <map>,<x>,<y> ; <map>,<x>,<y> ; ...` | the last waypoint is reached (each within 15 yd, in order; reaching a later waypoint counts the earlier ones) | next waypoint (minimap), all (world map, with lines) |
| `.zone <map>` | the player's map is `<map>` or below it in the map tree | |
| `.fp <map>,<node name>` | the flight path is known | flight master |
| `.fly <node name>` | the player was on a taxi and has landed at the node (within 200 yd; when the node's position is unknown, any landing counts) | flight master, then the node |
| `.boat <map>,<x>,<y> > <map>,<x>,<y>` / `.zeppelin ...` | in the destination's zone, or within 200 yd of the arrival dock, after boarding (a boarding detected at the departure dock, or the player having been outside the arrival area during the step) | departure, then arrival |
| `.hs <inn name>` | `GetBindLocation()` is the inn | innkeeper |
| `.home` | the zone changed to the bind location's after the hearthstone cast | |

Class directives come from class modules (`Classes/<CLASS>.lua`): e.g. `.tame <npcID>`, `.ammo ...`. Using one in a
chapter without a `.class` gate is a lint error.

## Step kinds

A step is built around one activity, and its kind is **inferred from its directives**: there is no syntax for it. A route
is any sequence of any number of each kind (three places to pick up, five to do, one to hand in, ...). Nothing else
changes: a step completes when every completable directive in it is satisfied.

| Kind | What it holds | Done when | Markers (map pin, minimap pin, edge arrow) |
|---|---|---|---|
| **Pick up** | one area, N `.accept` (a `.goto` for each NPC when several stand in the area) | every quest is in the log (or done already) | the quest givers |
| **Doing** | N `.complete <questID>` (with `.goto`, `.use`, `.note`, ...) | every one of those quests is complete in the quest log | none |
| **Hand in** | N `.turnin` (a `.goto` for each NPC when several stand in the area) | every quest is turned in | the quest enders |
| **Hand in + pick up** | `.turnin` and `.accept` at one place | all of them | both |

The guide's markers exist to steer the player **to a place**: where to pick up, where to hand in, and travel. The quest
log already marks, on the map and the minimap, where each quest's objectives are, so the guide does not repeat it: a
**doing step** draws no markers at all. It is a step with at least one `.complete` and no *place directive*:

- A **place directive** is any directive other than `.goto` and `.complete` that sends the player somewhere: a travel
  directive (`.path`, `.zone`, `.fp`, `.fly`, `.boat`, `.zeppelin`, `.hs`, `.home`: `def.kind == "travel"`) or one whose
  def pins something other than quest objectives (`def.pin` set and not `"objective"`: `.accept`, `.turnin`, `.train`,
  `.trainprof`, `.buy`, `.collect`, `.fish`, and a class or profession module's directive by the same test).
  The directives that mark no place (`.use`, `.skill`, `.craft`, `.level`, `.todo`, `.note`, `.text`, `.link`, `.hub`,
  `.reward`, `.optional`) leave a step a doing step. Only a step's own directives decide, not its `.sticky` ones.
- In a doing step, `.complete` and `.goto` produce no pins. The `.goto` stays in the text because the authoring tools
  (the drafter, the planner, the simulator, the travel generator) read it as the step's position; the step frame shows no
  line for it (as for any step that has other lines, unless the `.goto` carries a `>> text`). The player opens the map and
  looks where the quest log marks.
- Any other step keeps its markers as they always were, including an old hand-written step that mixes a `.complete`
  with a `.turnin` or an `.accept` (its `.complete` still pins the objective area).

The step frame lists the quests of a doing step: one line per `.complete`, naming the quest, with a done mark (`[x]` or
`[ ]`) and no objective counters. A step of one quest reads like a step of five. The step completes when every
`.complete` quest in it is complete in the quest log (all its objectives finished, or the quest is ready to hand in, or it
is handed in already); the `.goto` neither holds it up nor ends it.

`.complete <questID>` is for a quest that is done within the step (all of its objectives). `.complete <questID>,<objective>`
(the objective's number in the quest log) stays for a quest whose objectives are spread over several steps: each step
names the objective it is about and completes when that one is finished. Its line says which objective of which quest, with
no counters either.

**Quest tracking follows the step** (engine behaviour, no syntax; `Engine/Tracking.lua`). When a step becomes current, the
quest log's tracker is set to the quests the step is about, the quests of its `.complete` and `.turnin` directives that are
in the quest log (a quest under a collapsed header is in it): they are tracked first, and only once the client has tracked at
least one of them is every other tracked quest untracked, so the minimap and the quest tracker show only those quests, and
the tracker shows their progress (the step frame does not). If the client tracks none of them (it raises or refuses, a full
tracker looks the same) the tracker is left as it was and the module stops until the setting is toggled. A step that names no
quest in the log (a pick-up, a trip) leaves the tracking as it is. It acts only while all of these hold: the player has not
turned it off (Journal > Settings > Quest tracker; on until they do), a guide is active, and the step card is shown (the
saved setting, `/signpost hide` and the Journal's "Show the step card"; with the card hidden it does nothing at all, while
the card's own hides in combat, when dead or with the Journal open do not count). It does not fight the player: a quest the
log already had that is tracked or untracked by hand (or by the game) during the step stays so until the step changes, even
if the change is put back, and the step announced again after the guide is parsed again keeps that. The tracker is pointed
once at the first quest of the step that is not complete, when the step begins. The player's earlier tracking is not
restored afterwards.

## Display text

Each directive generates a description (`Accept "The Basics"`; names from the data pack, else `Quest #787`). `>> text`
replaces that line's description; `.text`/`.note` add lines of their own. A `.goto` (or `.fish`) without `>> text` has a
line only when the step has no other (`Go to Razor Hill 42.1, 68.7`), so a doing step lists its quests only.

## Stable step ids

Every step gets an id that survives gate and profession-plan changes, so saved progress keeps pointing at the right step:
`<sourceId>:<n>`, where `<sourceId>` is the registered chapter id or the guide id (for steps in the guide's own text),
or `track:<key>` for track steps, and `<n>` is the 1-based position of the step in that source text **before** gating
and merging. Every `step` line counts, also one whose step is dropped as broken.

Chapter ids: the first `#chapter` of a source gets the source's id, the k-th `<sourceId>#<k>`; steps before a
guide's first `#chapter` belong to the implicit chapter (named after the `Register` name, else `#guide`, else the id),
which counts as the guide source's first chapter.

## Track merging

After `#include` resolution and gating, each profession in the plan (primaries first, then secondaries, in plan order)
merges its track's gated steps into the route, in track order, each after the insertion point of the track's previous
step:

- `@hub <name>` — right after the first route step marked `.hub <name>`;
- `@level <N>` — before the first step of the first chapter whose minimum level is ≥ N;
- `@zone <map>` — before the first route step whose first `.goto`/`.path` target is in `<map>` or below it.

Several tracks anchored at the same place keep plan order. A track step without a match is dropped with an error (the
lint reports it per guide). Each anchor is searched from the place of the track's previous step on: `@hub` from that
step's route step (the same visit or a later one), `@level` and `@zone` from its gap. A merged step takes the chapter
of the place it lands in: inside a chapter, that chapter; between two chapters, never a dungeon chapter when the other
is not (a dungeon's Skip must not skip profession steps), else the earlier chapter when a step in that gap is `@hub`,
else the later one.

## Parsing rules

What `Engine/Parser.lua` and `tools/guide_lint.py` both do where the tables above leave it open:

- `#chapter` and `#include` end the step being read (a directive line after them and before the next `step` is "outside
  a step"); `#skipquest` and the metadata headers do not. A repeated guide header is an error; the first valid one
  counts. Header lists (`#professions`, `#class`, `#race`) are trimmed, so a space after a comma is fine.
- Including the same chapter twice is an error; the second `#include` is skipped (its step ids would collide).
- A step with nothing besides gates, `.optional` and `.hub` is an error ("step has no directives") and is dropped. A step
  whose lines are all gated away is dropped silently. A step with only `.sticky` lines is kept.
- A malformed gate on its own line drops the whole step for every player (so it is never shown to the wrong class); a
  malformed trailing gate drops only its line. `>>` is not allowed on gate lines, `.optional` or `.hub`, and an empty
  `>>` text is an error.
- Text after a route step's `step` (an anchor, say) is an error and the step is kept; a track step without exactly one
  valid anchor is dropped.
- Directive names match exactly as written: `.Accept` is unknown. `.skill <key> <N>` takes a space, not a comma.
- `#skipquest` is accepted in guides and chapters only (not in profession tracks).

## Errors

The parser never throws on guide text. It records `{ source = <sourceId>, line = <n>, message = <text> }` in
`guide.errors`, skips the offending line (or step), and goes on.
