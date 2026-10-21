# Engine and UI contracts

The interfaces the addon's modules code against. Wave 1 built these modules in parallel (one track each) and was
integrated on `integration/wave1` (2026-10-17): this file now records the integrated contract, including what the
tracks added. A module may add functions but must not change or drop anything listed here without updating this file
first (propose the change; the integrator or the user decides). The guide language is `docs/GUIDE-FORMAT.md`; the
architecture is PLAN §4.

## Conventions

- Every Lua file starts with `local ADDON_NAME, ns = ...`; each module is a table on `ns` (`ns.Parser`, ...). No new
  globals (CLAUDE.md); the one frame name added in Wave 1 is `SignpostItemButton` (so a binding or macro can `/click` it).
- Modules call each other **at call time** (`ns.Context:...` inside functions), never at file load; TOC order only
  matters for registration (a registry loads before the files that register into it).
- Game events through `ns.Events:Register`, internal messages through `ns.Events:RegisterMessage`/`ns.Events:Fire`
  (both already run handlers under `ns.SafeCall`, in registration order). Timer callbacks wrap their work in
  `ns.SafeCall`.
- Defaults for saved settings: call `ns.SavedVars:RegisterDefaults(scope, key, value)` at file load (`scope` is
  `"account"` for `SignpostDB` or `"char"` for `SignpostCharDB`); never edit `Core/SavedVars.lua`'s defaults table.
- The guide, chapter, class and profession registries return registration problems (a bad id, a duplicate) as
  `false, problem`, keep them in their `problems` list and record them with `ns.Errors:Record`; they never throw.
  `ns.Directives:Register` raises on a malformed def (a bug in the registering file); the registries call it under
  `ns.SafeCall`, one directive at a time.
- User-facing strings through `ns.L[...]`. Class, race, faction and profession names only in `Classes/`,
  `Professions/`, `Guides/` (tools/check_repo.py). Never arithmetic on secret values (`ns.Util.IsSecret`).
- Lua 5.1, StyLua-formatted, luacheck-clean.

## Internal messages

| Message | Fired by | Arguments |
|---|---|---|
| `DB_READY` | Core/SavedVars | — |
| `PLAYER_PROFESSIONS_CHANGED` | Core/Player | `ns.Player.professions` |
| `GUIDE_SELECTED` | Engine/Registry (`ns.Guides:Select`) | the newly selected def (or nil); Progress starts it |
| `PROFESSION_PLAN_CHANGED` | Engine/Professions | plan (synchronously, from `Decline`/`Restore` too) |
| `CONTEXT_CHANGED` | Engine/Context; Engine/Directives (`"casts"`) | what: `"quests"`, `"spells"`, `"skills"`, `"bags"`, `"level"`, `"zone"`, `"position"`, `"taxi"` (also known flight nodes), `"bind"`, `"casts"` (a `.craft` cast counted) |
| `GUIDE_LOADED` | Engine/Progress | guide |
| `STEP_CHANGED` | Engine/Progress | step, index, reason (`"load"`, `"auto"`, `"manual"`) |
| `STICKY_CHANGED` | Engine/Progress | the steps with active sticky directives (`ns.Progress:Sticky()`), after STEP_CHANGED |
| `DUNGEON_SKIP_OFFER` | Engine/Progress | chapterIndex, chapter (once per dungeon chapter, 5+ levels above it) |
| `TRANSPORT_STATE` | Engine/Travel | stepId, state (`.fly`, `.boat`, `.zeppelin`; on changes, not for the initial `"waiting"`) |

`CONTEXT_CHANGED` fires only when a refresh found a difference, never synchronously inside a query or event handler
(the earliest is the next frame), at most once per 0.2 s per `what`.

## Data shapes

```lua
guide = {
	id = "horde-troll-hunter-1-60", name = "Troll Hunter 1-60", -- name: Register's, else #guide, else the id
	def = registerTable, -- what Guides:Register received
	headers = { professions = { "skinning", ... }, guide = "...", author = "...", version = "...",
		class = { ... }, race = { ... }, faction = "..." }, -- professions is always a list
	chapters = { { id = "durotar-1-6", name = "Valley of Trials", levels = { 1, 6 }, dungeon = false, first = 1, last = 12,
		source = "durotar-1-6", line = 1, implicit = nil } }, -- the k-th #chapter of a source: id "<sourceId>#<k>"
	steps = { step, ... }, -- route order after gating and track merging
	byId = { [stepId] = step },
	skipQuests = { [questID] = reason },
	plan = plan, -- the plan the tracks were merged with
	errors = { { source = sourceId, line = 12, message = "..." } }, -- line 0: the source as a whole
}

step = {
	id = "durotar-1-6:3", -- GUIDE-FORMAT "Stable step ids"
	index = 3, -- position in guide.steps
	chapter = 1, -- index into guide.chapters (always valid; empty chapters are dropped)
	source = "durotar-1-6", line = 14,
	directives = { directive, ... }, -- in line order; never .sticky, .optional, .hub or a gate
	sticky = { directive, ... }, -- the inner directives of .sticky lines, each with sticky = true
	optional = { [questID] = true },
	hub = "razorhill", -- from .hub, or nil
	track = "skinning", anchor = { kind = "hub" | "level" | "zone", value = "orgrimmar" | 12 | 1413 }, -- track steps only
}

directive = { name = "accept", args = parsedArgs, text = "the >> text or nil", line = 15, def = directiveDef }

target = {
	map = 1411, x = 42.1, y = 68.7,
	kind = "goto" | "accept" | "turnin" | "objective" | "waypoint" | "taxi" | "dock" | "inn" | "trainer" | "vendor"
		| "fish" | "gather", -- "objective" only in a step that is not a doing step (Conditions)
	label = "text for the tooltip", radius = 10, -- yards, optional
	npc = 3143, object = nil, questID = 787, quests = { 787, ... }, -- optional; quests lists every quest of a merged pin
	objective = 2, -- the quest log objective an objective pin is for, when known
	index = 2, count = 4, next = true, reached = false, minimap = true, -- .path waypoints: only the next one is on the minimap
	sticky = true, -- a target of a sticky directive
	icon = "Profession", -- optional atlas (or a path with a slash) overriding the kind's icon
}

plan = { primary = { "skinning", "leatherworking" }, secondary = { "firstaid", "cooking", "fishing" },
	declined = { [key] = true }, -- declined and not learned
	learned = { [key] = true }, unknown = { key, ... } } -- unknown: suggestions without a profession module
```

Parsed directive arguments (what `def.parse` returns; other modules read them):

| Directive | args |
|---|---|
| `.goto`, `.fish` | `{ map, x, y, radius? }` (fish: no radius) |
| `.accept`, `.turnin`, `.optional` | `{ questID }` |
| `.complete` | `{ questID, objective? }` |
| `.reward` | `{ questID, choice }` for a value up to 10, else `{ questID, itemID }` |
| `.train` | `{ spellID }` or `{ class = true }` |
| `.trainprof` | `{ key }`; `.skill` `{ key, value }`; `.craft` `{ spellID, count }` |
| `.buy`, `.collect` | `{ itemID, count }`; `.use` `{ itemID }`; `.level` `{ level }`; `.todo` `{ reason }` |
| `.note`, `.text` | `{ text }`; `.link` `{ url }`; `.hub` `{ name }`; `.sticky` `{ directive = inner directive }` |
| `.path` | `{ points = { { map, x, y }, ... } }` (named fields) |
| `.zone` | `{ map }`; `.fp` `{ map, name }`; `.fly`, `.hs` `{ name }`; `.home` `{}` |
| `.boat`, `.zeppelin` | `{ kind, from = { map, x, y }, to = { map, x, y } }` |

## Modules

### Core/Player.lua — `ns.Player`

Existing identity fields (`className`, `classFile`, `classID`, `classBase`, `raceName`, `raceFile`, `raceID`, `faction`,
`factionName`, `level`), plus `professions = { [skillLineID] = { key = professionKey | nil, name, rank, max, primary,
slot, skillLine } }` (every value `GetProfessions` returns: 7 on Forever), refreshed at `PLAYER_LOGIN`,
`SKILL_LINES_CHANGED` and `CHAT_MSG_SKILL`; fires `PLAYER_PROFESSIONS_CHANGED` only when something changed.
`:RefreshProfessions()` → changed; `:Profession(key)` → the entry or nil. Primary or secondary: the profession module,
else the client's `isPrimaryProfession`, else the slot.

### Engine/Registry.lua — `ns.Guides`, `ns.Chapters`, `ns.Classes`

- `ns.Guides:Register(def)` (GUIDE-FORMAT "Files") → `true` or `false, problem`; `:Get(id)`; `:All()` (by name, then id).
- `ns.Guides:Compatible(def, player)` → `ok, reason, kind` (`"faction"`, `"race"`, `"class"` or `"invalid"`; `reason` is
  display text). `"*"`, a list holding `"*"`, an empty list or no value match everyone; a single token works as a list.
- `ns.Guides:Best(player)` → def or nil, by tier: race and class, class only, race only, faction only, open to
  everyone (PLAN §3.5); within a tier a named faction before `"*"`, then by id.
- `ns.Guides:Selected(player)` → `SignpostCharDB.guide` while registered and compatible, else `Best`;
  `:Select(id, player)` → `ok, reason` (refuses unknown and incompatible ids; `nil` returns to automatic selection);
  fires `GUIDE_SELECTED` when the selected guide changes. Only explicit choices are stored.
- `ns.Chapters:Register(id, text)` (ids `^[a-z0-9-]+$`); `:Get(id)` → text.
- `ns.Classes:Register(classFile, module)`; `:Get(classFile)`. A module may hold `trainerSpells = { [level] = { spellIDs } }`,
  `classQuests = { { name, level, quests = { questIDs }, offeredBy = "trainer" | npcID | nil, races = { raceFile, ... } | nil }, ... }`
  (`races`: the chain is for those races only, as Classic's druid chains differ per race; the lint skips it for other races),
  `directives = { [name] = directiveDef }` (registered into `ns.Directives` for every class, one by one, so one bad def
  does not stop the rest), `classTab`, `automation`, `onLevelUp(level)` (called by Registry at `PLAYER_LEVEL_UP` for the
  player's class, after `ns.Player.level` is updated; nothing else calls it).

### Engine/Professions.lua — `ns.Professions`

- `:Register(key, module)` — `module = { skillLine = id, primary = bool, gathering = bool, ranks = { 75, 150, 225, 300 },
  rankUpWindow = 25?, rankSpells = { spellIDs }?, directives = {...} }`; `:Get(key)`; `:ForSkillLine(id)` → key, module.
- `:RegisterTrack(key, text)`; `:Track(key)` → text.
- `:Plan(suggestions)` → plan, detected per PLAN §3.8 from `ns.Player.professions`, the guide's `#professions`
  suggestions and `SignpostCharDB.declinedProfessions` (two primary slots; learned professions always in the plan;
  plan order = suggestion order, then learned professions the guide does not suggest, by key). It never fires a
  message: it sets the baseline. `:Current()` → the last plan; `:IsDeclined(key)`.
- `:Decline(key)`, `:Restore(key)` — persist; `PROFESSION_PLAN_CHANGED` fires synchronously when primary, secondary or
  declined differ from the baseline (also on learn and unlearn, via `PLAYER_PROFESSIONS_CHANGED`).
- `:Merge(guide, plan, opts)` — inserts the plan's tracks (`ns.Parser:ParseTrack` with a copy of opts plus plan,
  player, guideId) at their anchors (GUIDE-FORMAT "Track merging"); replaces earlier track steps, so merging again is
  fine; rebuilds `index`, `byId`, chapter ranges; sets `guide.plan`; appends errors (missing track, unmatched or bad
  anchor, duplicate track step id). `@zone` reads the first `.goto`/`.path` of a route step from `args.map` or
  `args.points[1].map` (else `def.targets(args, ns.Context, {})[1].map`).

### Engine/Parser.lua — `ns.Parser`

- `:Headers(def)` → headers, read without a full parse (so the plan can be detected first); first valid one wins.
- `:ParseGuide(def, opts)` → guide. `opts = { player = ns.Player, plan = plan }`. Resolves `#include` through
  `ns.Chapters:Get` (cycles, unknown ids and a chapter included twice are errors), applies gates for `opts.player` and
  `opts.plan`, builds chapters and steps, then `ns.Professions:Merge(guide, opts.plan, opts)` when a plan is given, and
  `:Reindex` before and after it.
- `:ParseTrack(key, text, opts)` → `steps, errors`: ids `track:<key>:<n>`, `source = "track:<key>"`, `track`, `anchor`
  (`value` a number for `@level`/`@zone`), no chapter; gates with `opts.player`/`opts.plan`; `opts.guideId` reaches ctx.
- `:Reindex(guide)` — idempotent: `step.index`, `guide.byId`, each step's chapter (a step without one joins the previous
  step's chapter for an `@hub` anchor, else the next step's), chapter `first`/`last`; chapters without steps dropped.
- Directive arguments are parsed by `ns.Directives:Get(name).parse(argString, ctx)` with `ctx = { source, line,
  guideId }`, after the parser stripped `>> text` and trailing gates; an unknown directive or a parse failure becomes an
  error entry. `.sticky`, `.optional`, `.hub` and the gates are the parser's own: never looked up in `ns.Directives`. A
  `.sticky` whose inner def has `completable == false` is an error. Guide text never makes the parser throw.

### Engine/Directives.lua — `ns.Directives`

- `:Register(name, def)` (names `^%l[%l%d]*$`; sets `def.name`, defaults `kind` to `"misc"` and `completable` to
  `isSatisfied ~= nil`), `:Get(name)`, `:Names()` (sorted).
- `:Parse(name, argString, ctx)` → args, or `nil, message` (never raises); `:ParseLine(text, ctx)` → `{ name, args, text,
  line, def }` or `nil, message` for one `.name args >> text` line (gates already stripped).
- `def = { parse, isSatisfied, targets, describe, onStart, kind, completable, pin, progress, locationOnly, usage }`:
  - `parse(argString, ctx)` → args, or `nil, message`;
  - `isSatisfied(args, context, state)` → boolean (absent: not completable);
  - `targets(args, context, state)` → `{ target, ... }`;
  - `describe(args, context, state)` → string (state optional: a `.craft` count, a boarded transport);
  - `onStart(args, context, state)` — when the step becomes current (e.g. remember the skill maximum); must tolerate
    being called again on the same state, and a state restored from SavedVariables must keep working without it
    (Progress does not repeat it after a reload);
  - `kind` — `"quest"`, `"travel"`, `"profession"`, `"misc"` (icon hint; Progress reads `"quest"` for dungeon chapters);
  - `pin` — the target kind the pin of the `.goto` before the directive takes when it has no position of its own (the first
    `.goto` when none stands before it; Conditions `:Targets`). Any kind but
    `"objective"`, like `kind = "travel"`, makes the directive a *place directive* (Conditions "Step kinds");
  - `progress(args, context, state)` → extra lines under the directive's line (`.train`'s class quest line; `.complete` has
    none: the quest log shows the progress of a quest's objectives);
  - `locationOnly` — the line shows only when the step has no other line (`.goto`, `.fish`); `usage` — the syntax.
- `context` is `ns.Context`; `state` is a per-step, per-directive table owned by `ns.Progress` (plain data: it is saved).
- Registers every core directive of GUIDE-FORMAT. Travel directives come from `Engine/Travel.lua`, class and profession
  directives from their modules.
- Helpers for other modules: `ns.Directives.Pack` (every read of `ns.DB` and `SignpostDB.learned`: `Positions(kind, id)`,
  `Name`, `Side`, `QuestName`, `QuestStarters`, `QuestEnders`, `QuestObjectives`, `ItemName`, `ItemVendors`, `ItemDrops`,
  `ItemObjectDrops`, `MapName`, `ProfessionName`, `ProfessionTrainers`, `ClassTrainers`; the learned record fills in
  where the pack has nothing) and `ns.Directives.Label` (`Quest`, `Item`, `Spell`, `Map`, `Profession` display names).
  Constants `DEFAULT_GOTO_RADIUS` 10, `MAX_PINS` 6, `MAX_REWARD_CHOICE` 10, `RANK_UP_WINDOW` 25.
- `.complete` pairs the quest log's objectives with the pack's objective records (which are in the source's order, not
  the log's) by name, then by kind (GUIDE-FORMAT "Directives"). `.craft` counts the player's `UNIT_SPELLCAST_SUCCEEDED`
  casts into started states and fires `CONTEXT_CHANGED("casts")`.

### Engine/Conditions.lua — `ns.Conditions`

- `:IsComplete(step, context, states)` → `complete, detail`: `detail[i]` is a boolean per completable
  `step.directives[i]`; `detail.manual = true` when only the player's `>` can complete it. A step with nothing but
  sticky directives is complete at once. Directives about an `.optional` quest count only when nothing else does, and
  then only those of the quests in the quest log: an **optional-only step** whose quests are none of them in the log is
  complete at once (a group quest the player did not take never holds the route up; `detail[i]` stays false for its
  directives), while a quest the player took decides it like any other (GUIDE-FORMAT "Optional-only steps").
- `:OptionalOnly(step, context, states)` → `nil`, or for an optional-only step (its completable directives all belong
  to `.optional` quests; a `.goto`, `.todo` or `.note` beside them do not count) `{ quests = { questID, ... } (each once,
  in directive order), available = the quests neither in the quest log nor done, taken = one of them is in the log,
  fulfilled = every one of its optional directives is satisfied }`. The step card, the Journal and `:IsComplete` read it.
- `:Targets(step, context, states)` → targets of the step's directives (sticky ones marked `sticky = true`), without
  those of satisfied directives and without the **`.goto`s that have nothing left to ask**: a pick-up or hand-in step
  lists each NPC's `.goto` before that NPC's directives, so once every completable directive after a `.goto` (up to the
  next `.goto`) is satisfied, that place's pin goes (a marker shows where to go next, never where the player has been). A
  `.goto` with no such directive after it (a waypoint, a lone `.goto`, one beside notes) keeps its pin until the step is
  done; sticky directives belong to no `.goto`. A directive with a `pin` kind and no position (no pack) marks **the
  `.goto` before it** (the first `.goto` when none does), so a joined step (each NPC's `.goto` followed by its
  directives) has one pin and one label for each NPC, naming that NPC's quests (a finished `.goto` has no pin: a claim of
  a directive after it marks the first `.goto` pin left). An NPC/object pin within a `.goto`'s radius merges into it,
  same-NPC pins merge. A **doing step** has none: its `.goto` and `.complete` are not asked for pins (a sticky place
  directive keeps its own).
- `:IsDoingStep(step)` → boolean: the step has a `.complete` and no place directive (any directive but `.goto` and
  `.complete` that is a travel directive, `def.kind == "travel"`, or whose def has a `pin` other than `"objective"`; only
  the step's own directives count, not its sticky ones). GUIDE-FORMAT "Step kinds" has the rule and the directives.
- `:Describe(step, context, states)` → `lines, info`: the step's own lines (each followed by its progress lines), then
  the sticky ones; `info[i] = { directive = index, name = the directive's name, quest = the directive's quest or nil,
  sticky = true|nil, progress = true|nil, done = bool }`. A `.complete` line is the quest (`Complete "<quest>"`) with no
  objective lines; `done` is whether the directive is satisfied (a quest accepted, complete, handed in), for the step
  frame's done mark on `.accept`, `.complete` and `.turnin` lines; `quest` lets a pin's tooltip pick the lines of its quests.
- `:StickyComplete(step, context, states)` → done, detail; `:Start(step, context, states)` → states (every `onStart`);
  `:Kind(step)` → icon-hint kind.
- `states` is `ns.Progress:State(step.id)`: `states[i]` for `step.directives[i]`, `states.sticky[j]` for `step.sticky[j]`.

### Engine/Context.lua — `ns.Context`

Cached player state, refreshed by events (a burst costs one re-read on the next frame), cheap to query:

- `:QuestInLog(id)`, `:QuestCompleted(id)` (flagged, or turned in this session), `:QuestReady(id)` (in the log, not
  failed, objectives done or `IsComplete`), `:Objectives(id)` → `{ { text, type, finished, have, need } }` (nil when not
  in the log, `{}` without objectives), `:QuestLog()` → `{ [questID] = entry }`, `:QuestEntry(id)`;
- `:SpellKnown(spellID)` (any of `IsPlayerSpell`, `C_SpellBook.IsSpellKnown`, `IsSpellKnown`); `:Skill(skillLineID)` →
  rank, max or nil (from `ns.Player.professions`); `:ItemCount(itemID)` (bags only); `:Level()`;
- `:Position()` → `{ map, x, y, wx, wy, instance, taxi }` or nil (any field but `taxi` may be nil in instances and on
  transports); `:Map()`; `:InMap(mapID, rootMapID)` (map tree via `C_Map.GetMapInfo` parents, else the pack's maps;
  `mapID` nil = the player's); `:MapInfo(mapID)` → `{ id, parent, type, name }`; `:Continent(mapID)`;
  `:Distance(map, x, y)` → yards or nil (HereBeDragons; nil across instances); `:OnTaxi()`;
- `:BindLocation()`; `:TaxiNodeKnown(name)` → true (known; never downgraded) / false (listed as unknown) / nil (never
  seen), by full client name or the part before the comma, case-insensitive, `zz…` retired nodes ignored;
  `:NoteTaxiNodes({ { name, known, id? }, ... })` → changed (Context feeds itself at `TAXIMAP_OPENED`; Travel feeds it
  too); `:ReadTaxiMap()`; known nodes are kept per character in `SignpostCharDB.taxiNodes = { [name] = { known, id, t } }`;
- `:Now()`; `:Invalidate(what)`; `:HBD()`; `:Snapshot()` (what `/signpost context` saves to `SignpostDB.context`).
- Never reads `UnitHealth`/`UnitPower`. A 0.5 s ticker samples zone, taxi, position and bind location (the one poll PLAN
  §3.3 allows); a kind whose events the client rejects is polled every 2 s (`Context.missingEvents`).

### Engine/Travel.lua — `ns.Travel`

- Registers the travel directives (`.path`, `.zone`, `.fp`, `.fly`, `.boat`, `.zeppelin`, `.hs`, `.home`); their state
  machines run on `CONTEXT_CHANGED`, `STEP_CHANGED` and the travel events, for the current step and the sticky steps.
- Targets: `.path` gives every waypoint (`kind = "waypoint"`, `index`, `count`, `reached`, `next`, `minimap` on the next
  one only); `.boat`/`.zeppelin` one `"dock"` (departure until boarded, then arrival); `.fly` one `"taxi"` (the nearest
  usable flight master while waiting, then the node); `.fp` `"taxi"`, `.hs` `"inn"` (with `npc` when known).
- `:RegisterBorders(list)` — `Guides/Travel/Borders.lua` calls it with `{ { name, from = { map[, x, y] }, to = { map[, x,
  y] }, side, todo }, ... }` (a point is `{ map }` until the crossing is learned; `todo` says why); `:Borders(mapA, mapB)`
  → copies, the pack's learned crossings (`travel.crossings`) replacing hand entries for the same pair of zones; one map
  gives the crossings touching it, two the ones between them.
- `:TransportState(stepId)` → `"waiting"`, `"boarded"`, `"arrived"` (nil for a step without `.fly`/`.boat`/
  `.zeppelin`); fires `TRANSPORT_STATE`; `:TransitText(stepId)` → "Sailing to X..." while boarded.
- Also: `FindTaxiNode(name, mapHint, context)`, `NearestTaxiNode(context)`, `NodeKnown(name, mapHint, context)`,
  `InnTarget(name, context)`, `WaypointRadius()` (`SignpostDB.settings.waypointRadius`, default 15), `Sample(context)`,
  `Update()`; `facts` (recent loading screens, position jumps, taxi rides, hearthstone casts); the radii and windows as
  constants (`WAYPOINT_RADIUS` 15, `DOCK_RADIUS` 50, `ARRIVAL_RADIUS` 200, `NODE_RADIUS` 200, `INN_RADIUS` 300,
  `BOARD_WINDOW` 300, `JUMP_YARDS` 200, `JUMP_SPEED` 50, `GRACE` 120, `HEARTHSTONE_ITEM` 6948).
- Directive states are plain data (path `{ next }`, fly `{ since, phase, announced, flew }`, boat/zeppelin `{ since,
  phase, announced, away, dockAt, dockInstance, dockWorld, boardedAt }`, home `{ since, done }`); `GetTime()` stamps
  saved before a computer restart are dropped. Reads `travel.inns[npcID].n` (an inn's bind-location name) when present.

### Engine/Progress.lua — `ns.Progress` (and the engine's start-up)

- Start-up at `PLAYER_LOGIN` (after `ns.Player` refreshed) and on `GUIDE_SELECTED`: `ns.Guides:Selected()` →
  `ns.Parser:Headers` → `ns.Professions:Plan` → `ns.Parser:ParseGuide` → `:SetGuide` (`:Start()`). Re-parses on
  `PROFESSION_PLAN_CHANGED`, keeping the current step by id (else the next step still there).
- `:SetGuide(guide)`, `:Guide()`, `:Current()` → step, index, `:Sticky()` → the steps before the current one with an
  active sticky directive, in route order; `:ActiveSticky(stepId)` → `{ { index, directive, state } }`.
- `:Next()`, `:Back()`, `:Skip()`, `:JumpTo(index)`, `:JumpToId(stepId)` — manual moves win for the session (PLAN §3.3):
  a step chosen with `<` or a jump is held until the player moves again, completes it, or a quest event completes a
  later step that was open; behind the furthest step reached this session `>` moves one step; holds are not saved.
  Skipping a track's first `.trainprof` step declines the profession; `<` right after restores it.
- `:Evaluate()` — at most once per second, on `CONTEXT_CHANGED`: advance past completed steps, auto-skip upcoming steps
  already satisfied, keep stickies (a sticky stays active until satisfied once; skipping its step dismisses it); a step
  with no completable directive waits for `>` unless it only starts sticky directives. `:EvaluateNow(reason)`.
- `:State(stepId)` → per-directive state tables: `[i]` for `step.directives[i]`, `sticky[j]` (also `[#directives + j]`)
  for `step.sticky[j]`; `onStart` runs once per state when the step becomes current (or is passed by auto-advance).
- Dungeon chapters: `:CurrentChapter()` → index, chapter; `:ChapterSkipped(index)`; `:SetChapterSkipped(index,
  skipped)` (dungeon chapters only); a dungeon whose quest steps are all done is passed silently; a one-time chat offer
  to skip at 5+ levels above it (`DUNGEON_SKIP_OFFER`). Also `:IsDone(stepId)`, `:IsSkipped(stepId)`, `:Describe(step)`.
- Saves `SignpostCharDB.progress[guideId] = { current = stepId, skipped = { [stepId] = true }, done = { [stepId] = true },
  sticky = { [stepId] = { [directive line] = active } }, states = { [stepId] = { started, d = { [line] = state } } },
  offered = { [first step id of a dungeon chapter] = true } }` (states: the current step and steps with active stickies).
- Fires `GUIDE_LOADED`, `STEP_CHANGED`, `STICKY_CHANGED`, `DUNGEON_SKIP_OFFER`. Registers `/signpost next|back|skip
  [chapter]|step [n|id]`. With `SignpostDB.debug.chat` it prints every step change (the Phase 2 acceptance walk).

### Engine/Tracking.lua — `ns.Tracking`

The quest log's tracked quests follow the current step (user, 2026-10-20): the quest tracker and the minimap then show the
quests of the step, and the tracker shows their progress (which is why the step frame lists the quests and leaves their
objectives to the quest log).

- **When it acts:** `Tracking:Active()`: the setting is on (`Tracking:Enabled()`), a guide is active (`ns.Progress:Guide()`),
  the step card is shown and the client has not refused a step's quests this session (`Tracking.failed`). The card's flag is
  the saved one, `SignpostDB.stepFrame.shown` (`/signpost hide`, the Journal's "Show the step card"), not the hides the card
  does by itself in combat, when dead or while the Journal is open. Otherwise it does nothing at all: no client call, not even
  for a change of the quest log. Showing the card again takes effect at the next step or change of the quest log's quests.
- **A step becomes current** (`STEP_CHANGED` for another step id; `Tracking:SetEnabled(true)` forces it): the quests the step
  is about are tracked first, those of its `.complete` and `.turnin` directives (`Tracking.NamedQuests(step)`: in directive
  order, each once) that are in the quest log (`ns.Context:QuestInLog`, which also finds a quest under a collapsed header).
  Only when the client tracks at least one of them are all the other tracked quests untracked, and the step's quests a full
  tracker refused are added again. If none got tracked (AddQuestWatch raised or refused it: a full tracker looks the same) it
  changes nothing else, records one entry in the error log ("Signpost: quest tracking stopped: ...", `ns.Errors`) and stops
  until the setting is toggled either way. A step that names no quest in the log (a pick-up, a trip) changes nothing and makes
  no client call. The first successful application for the step also gives the first of its quests that is not complete to
  `C_SuperTrack.SetSuperTrackedQuestID`, unless `GetSuperTrackedQuestID` already returns one of them; later applications for
  the same step do not move the focus.
- **The same step announced again** (the engine parsed the guide again: `PROFESSION_PLAN_CHANGED`, `GUIDE_SELECTED`) is not a
  new start: when the module stayed hands off it still does, otherwise it sets the tracking again without the focus. A reload
  or login is a new session and a new start.
- **The quest log changes while the step is current** (`CONTEXT_CHANGED("quests")`): only when the *set* of quests changed (a
  quest accepted or removed; progress inside a quest, or a header collapsed or expanded, changes nothing and costs no call)
  the tracking is set again for the step, without the focus. Unless one of the quests the log already had has been tracked or
  untracked since the module last set it (by the player, or by the game tracking a quest as its progress changes: the module
  cannot tell them apart): then `Tracking.state.manual` is true and the module leaves the tracking alone until the next step,
  even if the change is put back.
- The player's earlier tracking is not remembered and not given back when the step ends or the setting is turned off (v1).
- `Tracking:Enabled()`, `Tracking:SetEnabled(on)`: `SignpostDB.settings.trackStepQuests` holds only the player's own choice
  (Journal > Settings > Quest tracker); until they choose, `Tracking.DEFAULT_ENABLED` (true, the user's choice) is the answer
  and the one place the default lives.
- Client API, all through `Util.Call` so a missing or failing function costs this feature and never the step engine.
  Retail shape: `C_QuestLog.GetNumQuestWatches()`, `GetQuestIDForQuestWatchIndex(i)`, `GetQuestWatchType(questID)` (any value
  but nil and false is tracked, `Enum.QuestWatchType.Automatic` (0) too; the watch list answers when it is missing),
  `AddQuestWatch(questID, Enum.QuestWatchType.Manual)`, `RemoveQuestWatch(questID)`; `C_SuperTrack.GetSuperTrackedQuestID()`
  and `SetSuperTrackedQuestID(questID)`. Where `C_QuestLog` lacks `AddQuestWatch` or `RemoveQuestWatch`, the Classic shape on
  quest log numbers: `AddQuestWatch(number)`, `RemoveQuestWatch(number)`, `IsQuestWatched(number)`, `GetNumQuestWatches()`,
  `GetQuestIndexForWatch(i)` (a quest's number from `C_QuestLog.GetLogIndexForQuestID`, else a walk of `C_QuestLog.GetInfo`;
  the quest at a number from `GetQuestIDForLogIndex`, else `GetInfo`). Unverified on Forever (API notes, "Open probes";
  `/signpost probe` lists which names exist). `QUEST_WATCH_LIST_CHANGED` is probed but not used: the watch list is compared when
  it matters.

### Core/Learn.lua — `ns.Learn`

Always on (cheap), recording into `SignpostDB.learned` as the player plays; never a player or a pet, no quest or gossip
text, no item data beyond the IDs a vendor sells:
`npcs[npcID]` and `objects[objectID]` = `{ n = name, map, x, y, t, c = visits }` at quest dialogs, gossip, trainers,
vendors and flight masters; `quests[questID] = { start = { npc | obj = id }, finish = {...}, t }` at accept and turn-in;
`taxi[nodeName] = { map, x, y, npc, id = nodeID, faction, t, c }`; `crossings = { { from = { map, x, y }, to = { map, x,
y }, t, c }, ... }` for zone borders walked across (not on a taxi, transport or teleport); `trainers[npcID] = { spells =
{ spellIDs }, skill = skillLineID?, t }`; `vendors[npcID] = { items = { itemIDs }, t }`. Bounded sizes (`Learn.LIMITS`;
the record seen longest ago goes). `:Get(table, key)`, `:Counts()`, `:Count(name)`, `/signpost learned`.
`tools/import_savedvars.py --merge-learned [--also DIR]` turns it into `layers/learned.json` and rebuilds the data pack:
positions override the other layers, quest/vendor/trainer links are unioned with them, vendor items only for items the
route touches.

### UI/StepFrame.lua and UI/Pins.lua — `ns.StepFrame`, `ns.Pins`

- React to `GUIDE_LOADED`, `STEP_CHANGED`, `STICKY_CHANGED` (at once), `CONTEXT_CHANGED`, `TRANSPORT_STATE` (coalesced,
  0.2 s); read `ns.Progress:Current()`/`:Sticky()`/`:ActiveSticky()`/`:State()`, `ns.Conditions:Describe`/`:Targets`
  and `ns.Travel:TransportState`.
- The step frame's body is Describe's non-sticky lines, up to ten (a step lists all of its quests); an `.accept`,
  `.complete` or `.turnin` line starts with its done mark (`ns.UI.MARK`: `[x]` done, `[ ]` not yet, the Journal's own
  marks), never with objective counters, and no other line has one; every active sticky directive (the current step's
  too) is an "Ongoing:" line; below those, up to two "Optional: <quest> (group quest)" lines name the group quests
  coming up (`StepFrame:OptionalLines(step)`: the quests of `ns.Conditions:OptionalOnly(...).available` of the next three
  steps of the route, each once; a font string of its own, not counted in the ten body lines); an in-transit line while
  boarded. A secure `SignpostItemButton` (parented to UIParent, changed only out of combat) uses the step's `.use` item
  (`args.itemID`).
- Settings via `RegisterDefaults("account", "stepFrame", { shown, locked, scale, alpha, hideInCombat, hideWhenDead,
  hideWithJournal, growUp, pos })` and `("account", "pins", { minimap, worldMap, showNext, nextCount })`.
- **Which way the card grows** (`growUp`, user 2026-10-21, for a card placed near the bottom of the screen): the card's height follows the step, so the edge it
  is anchored at stays put and the other edge moves. `growUp = false` (the default) anchors the saved `pos` at the card's top (it grows down), `true` at its bottom
  (it grows up). `pos` is `{ point, relativePoint, x, y }` as before; `StepFrame:SetGrowUp(up)` (the Journal's Settings checkbox, `/signpost grow up|down`) moves
  the saved point to the other edge without moving the card (the side of the point and the relative point stay, the vertical offset moves by the card's height; a
  centred point moves by half of it), and so does `ApplyPosition` for a position saved at the other edge (a drag hands back whatever corner the client moved).
  With no saved position the default is the top-right place for a card that grows down and the same place anchored at the bottom for one that grows up.
  `reset` keeps the direction. The item button sits beside the card's top-left corner, so it is placed again after every layout.
- `/signpost show|hide|lock [on|off]|grow [up|down]|reset|scale <n>|alpha <n>`. Pins through HereBeDragons-Pins-2.0 (minimap + world
  map, waypoint lines on zone maps); atlases per FOREVER-API-NOTES (there is no `Vendor` atlas).
- APIs: `StepFrame:Render()`, `DescribeLines(step[, quests])` (`quests = { [questID] = true }` leaves out the lines about
  other quests: a pin's tooltip lists the lines of the quests the pin names), `DescribeSticky(step)`,
  `DescribeActiveSticky(step)`, `OptionalLines(step)`, `SetShown/SetLocked/SetGrowUp/SetScale/SetAlpha/Reset`;
  `Pins:Refresh(force)`, `RequestRefresh()`, `Clear()`, `SetEnabled("minimap"|"worldMap", on)`, `Targets(step, states)`,
  `Collect()`, `IconFor(kind, override)`. Phase 4 hooks, no-ops until the journal exists: right-click →
  `ns.Journal:Toggle(step)`, world-pin click → `ns.Journal:ShowStep(step)`, `ns.Journal:IsShown()` for `hideWithJournal`.
  A step with no targets (a doing step) draws nothing, and the pins and edge arrows of the step before are cleared. A
  joined step has one pin for each of its `.goto` lines that still has something to ask (`Conditions:Targets`).

### UI/Journal.lua — `ns.Journal`

The big window (PLAN §3.2), built on `UI:CreateDialogFrame` (UI/Widgets.lua: `ButtonFrameTemplate`, movable, Esc closes it through
`UISpecialFrames`; `UIPanelWindows` is not used, to keep the panel manager untainted). A guide dropdown (`WowStyle1DropdownTemplate`, only the
guides `ns.Guides:Compatible` accepts, choosing one calls `ns.Guides:Select`), a `SearchBoxTemplate`, three `PanelTabButtonTemplate` tabs:
**Route** (a chapter list with done/total counts and the current chapter marked, the selected chapter's steps with `[x]` done, `[-]` skipped,
`>` current; a step made only of group quests (`ns.Conditions:OptionalOnly`) is tagged "(group quest)" and reads `[-]` when the route passed it
without its quest done; a click goes to the step through `Progress:JumpToId`, more than 20 steps away needs Shift; a dungeon chapter has a "Skip this
dungeon" box (`Progress:SetChapterSkipped`); a search replaces the step list with matching steps of the whole guide; a "Current step" button),
**the class tab** (the class module's `classQuests` for the character's race, each with its status from `Context:QuestTurnedIn/QuestInLog`; a
`pending` chain reads "new in Forever: quest IDs not known yet"; hidden when the class has no chains) and **Settings** (the step card and pins
settings, the data sharing consent, the card's size and opacity, the detected profession plan with a Restore button per declined profession,
"Choose the guide for me", a button for the data sharing window). Lists are plain scroll frames (`ScrollFrameTemplate`), one chapter at a time.
- API: `:Show(tab)` (`"route"`, `"class"`, `"settings"`), `:Hide()`, `:Toggle(step)`, `:IsShown()`, `:ShowStep(step)` (opens the step's chapter
  and flashes its row for 5 s), `:ShowCurrent()`, `:SelectTab(name)`, `:Refresh()`. Refreshes (coalesced, 0.2 s) on `GUIDE_LOADED`,
  `STEP_CHANGED`, `GUIDE_SELECTED`, `CONTRIBUTE_CHANGED`, `PROFESSION_PLAN_CHANGED`. Opened by `/signpost` (no argument), `/signpost journal [tab]`,
  the AddOn Compartment entry, the minimap button (LibDataBroker + LibDBIcon, registered at `DB_READY`; right-click opens Settings) and a
  right-click on the step card; a world-map pin click calls `:ShowStep`. It sets `SignpostDB.journal.tab` and `SignpostDB.minimapButton`.

### Automation/ — `ns.Automation` (PLAN §3.4; built on the mock, not yet verified in the client)

Every feature is a toggle in `SignpostCharDB.automation` (`RegisterDefaults("char", "automation", ...)`), all `false`: `quests`
(accept), `turnIn`, `gossip`, `taxi`, `trainer`, `vendor`; the modes `acceptAll`, `turnInAll`, `rewardAsk` (also `false`);
`goldReserve` (copper, default 0: the guide asks for these purchases, so they happen whenever affordable). Nothing acts on its own:
each file registers its client event through `ns.Events:Register`, asks `ns.Automation:Allowed(feature)` and then reads only the
directives of `ns.Progress:Current()` (never sticky ones, never the player's unrelated choices).

- `Core.lua`: `:Settings()`, `:Enabled(f)`, `:SetEnabled(f, on)`, `:Reserve()`; the gate `:Blocked()` (Shift held, `InCombatLockdown`,
  dead or ghost, `SettingsPanel` shown) and `:Allowed(f)`; step lookups `:Step()`, `:Directives(name)` →
  `{ { directive, args, index } }`, `:Asks(names...)`, `:GuideSkips(questID)` (`guide.skipQuests`), `:Satisfied(entry)` (the
  directive's own `isSatisfied`), `.Try(fn, ...)` (pcall, reports success). `/signpost automation [on|off|status|reserve <gold>]`
  (`on`/`off` flip the six feature toggles, not the modes).
- `Quests.lua`: `QUEST_DETAIL` → `AcceptQuest()` for a quest the step `.accept`s (`acceptAll`: any non-trivial one), never a
  `#skipquest`; `QUEST_GREETING`/`GOSSIP_SHOW` select the guide's active (to turn in) or available quest first
  (`Quests:OnGossip()` is called by Gossip.lua); `QUEST_PROGRESS` → `CompleteQuest()`; `QUEST_COMPLETE` → `GetQuestReward(idx)`:
  no choice 0, one choice 1, else the guide's `.reward` (choice index or item ID; searched in the current step, then the whole
  guide), else the highest `sellPrice × quantity`; uncached items → `C_Item.RequestLoadItemDataByID`, decided on
  `ITEM_DATA_LOAD_RESULT` or, after `Quests.WAIT_SECONDS` (2), stop and leave the window open with a chat line. It also stops
  when no choice has a vendor value, and always in `rewardAsk` mode (a `.reward` still wins). Turn-in covers the step's
  `.turnin` quests unless `turnInAll`.
- `Gossip.lua`: `GOSSIP_SHOW` → Quests first; then, during an unsatisfied `.hs`, the binder option (`BinderGossipIcon` file ID, else
  the text "inn" + "home" through `ns.L`); else a single option when the step is an NPC visit (`.accept .turnin .train .trainprof
  .buy .fly .hs`) and no quests are on offer. `CONFIRM_BINDER` (only after that, only during `.hs`) confirms at 0, 0.2 and 0.6 s
  through the popup's accept button (`StaticPopup_FindVisible`), else `C_PlayerInteractionManager.ConfirmationInteraction(
  Enum.PlayerInteractionType.Binder)`, else `ConfirmBinder()`.
- `Taxi.lua`: `TAXIMAP_OPENED` during an unsatisfied `.fly` → `ns.Context:ReadTaxiMap()`, the node by full name or the part before
  the comma, not the current or an unknown node; `TakeTaxiNode(index)` for the `NumTaxiNodes` shape, else `TakeTaxiNode(nodeID)`
  then the slot index for the `C_TaxiMap` shape. One flight per opening of the map.
- `Trainer.lua`: `TRAINER_SHOW` → `.train <id>`, `.train class` (the class module's `trainerSpells` at or below the player's level;
  empty means nothing) and `.trainprof` (the profession module's optional **`rankSpells = { spellIDs }`**: the rank and learn
  services; a module without them buys nothing) are matched by spell ID (service link, else `C_TooltipInfo.GetTrainerService`);
  only "available" services, not known spells, only while money stays at or above the reserve; bought highest index first.
- `Vendor.lua`: `MERCHANT_SHOW` → each `.buy itemID,count`: `count - C_Item.GetItemCount` missing, as bundles of the slot's stack
  size, capped by stock, by gold above the reserve and per call by `GetMerchantItemMaxStack`; extended-cost slots are skipped.
- Hearth: `UI/StepFrame.lua`'s `DesiredItem` offers item 6948 (`Travel.HEARTHSTONE_ITEM`) on a `.home` step through the same
  secure button as `.use`; nothing ever casts it.
- Settings: the Journal's Settings tab shows nine checkboxes in a second column (`def.column == 2` in `settingsList()`); the
  gold reserve is only reachable through the slash command.
- Specs: `tests/automation_spec.lua` (a scripted world of the quest, gossip, trainer, merchant and flight APIs; the step is a
  stand-in whose directives come from the real `ns.Directives:ParseLine`), `tests/ui_spec.lua` (hearth button),
  `tests/journal_spec.lua` (the toggles).

### UI/Report.lua and UI/Options.lua

- `ns.Report:Add(step?, note?)` records `{ t, guide, step, level, version, map, x, y, note }` into `SignpostDB.reports` (the current step by default;
  the note is one line of plain text, at most 300 characters; at most 200 reports, the oldest goes first), fires `REPORT_ADDED` and prints a
  thanks. `:Count()`. `/signpost report [note]` and `/signpost report count`; a "Report this step" button in the Journal's Route tab.
  Nothing is sent: the reports travel with the saved data when the player shares the file, and `/signpost export` shows them.
- `ns.Options:Register()` (at `DB_READY`) adds a "Signpost" category to Blizzard's Options > AddOns through
  `Settings.RegisterCanvasLayoutCategory` / `RegisterAddOnCategory`, only when that API exists: a short panel with an "Open the Journal" button
  (the settings themselves live in the Journal).

## TOC order (integration adds the lines; tracks never edit the TOCs)

```
Core\Init.lua, Core\Errors.lua, Libs\..., Core\Util.lua, Core\SavedVars.lua, Core\Player.lua, Data\Schema.lua,
Core\Slash.lua, Core\Debug.lua, Core\Probe.lua, Core\MapDump.lua, Core\Learn.lua,
Engine\Registry.lua, Engine\Directives.lua, Engine\Context.lua, Engine\Parser.lua, Engine\Professions.lua,
Engine\Conditions.lua, Engine\Travel.lua, Engine\Progress.lua, Engine\Tracking.lua,
Classes\*.lua, Automation\*.lua, Professions\*.lua, Guides\Travel\Borders.lua, Guides\Chapters\*.lua, Guides\Professions\*.lua,
Guides\*.lua, UI\Widgets.lua, UI\StepFrame.lua, UI\Pins.lua
```

## Wave 1 tracks and file ownership (integrated 2026-10-17)

A track created and edited only its own files. Shared files — the TOCs, `docs/PROGRESS.md`, `docs/PLAN.md`,
`CLAUDE.md`, this file, `docs/GUIDE-FORMAT.md`, `tests/wow_mock.lua`, `tests/helpers/addon.lua`,
`Core/SavedVars.lua` — belong to the integrator. `.luacheckrc`: add any missing read globals in alphabetical position.

| Track | Owns |
|---|---|
| data-questie | `tools/questie_import.py`, `tools/signpost_tools/geo.py`, their tests, `Data/Schema.lua` (field docs), the private pack (`../Signpost_Data`) |
| data-wowhead | `tools/wowhead_export.py`, `tools/wowhead_env.py`, `tools/signpost_tools/wowhead.py`, their tests |
| engine-parser | `Engine/Parser.lua`, `tests/parser_spec.lua` |
| engine-directives | `Engine/Directives.lua`, `Engine/Conditions.lua`, `tests/directives_spec.lua`, `tests/conditions_spec.lua` |
| engine-context | `Engine/Context.lua`, `tests/context_spec.lua` |
| engine-progress | `Engine/Progress.lua`, `tests/progress_spec.lua` |
| engine-travel | `Engine/Travel.lua`, `Guides/Travel/Borders.lua`, `tests/travel_spec.lua` |
| engine-registry | `Engine/Registry.lua`, `Engine/Professions.lua`, `Core/Player.lua`, `tests/registry_spec.lua`, `tests/professions_spec.lua` |
| tools-lint | `tools/guide_lint.py`, `tools/guide_travel.py`, `tools/signpost_tools/guidefile.py`, their tests |
| learn | `Core/Learn.lua`, `tests/learn_spec.lua`, `--merge-learned` in `tools/import_savedvars.py`, `tools/signpost_tools/learned.py`, their tests |
| ui | `UI/StepFrame.lua`, `UI/Pins.lua`, `tests/ui_spec.lua` |

## Testing

- busted specs in `tests/<area>_spec.lua`; every module is in the TOC now, so `addon.load()` loads them all (`extra`
  still works for files that are not). Set client globals through `addon.G`; `tests/wow_mock.lua` resets the globals the
  module mocks install at every load, so install them in `addon.load`'s `before`.
- Extra mocks in `tests/mocks/<area>.lua`; a spec may stub other modules. `tests/integration_spec.lua` runs the real
  modules together on the scripted client of `tests/mocks/context.lua` (guide, chapter, track and profession module
  registered as their files would; login; quest log, profession, level and position changes).
- Python tool tests in `tools/tests/test_<tool>.py` (unittest, standard library only).
- `pwsh -NoProfile -File tools/check.ps1` passes before a task is done (busted, luacheck, StyLua, check_repo, the tool
  tests and `guide_lint.py --strict --no-pack`).
