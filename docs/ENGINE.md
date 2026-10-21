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
| `STEP_CHANGED` | Engine/Progress | step, index, reason (`"load"`, `"auto"`, `"manual"`, `"place"`) |
| `GUIDE_PLACED` | Engine/Progress | the result of `ns.Placement:Find`, reason (`"first"`, `"lost"`, `"refine"`, `"manual"`); before the evaluation that follows it |
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
	fingerprint = "4d09f3e9-5d3d7c6e-1234", -- Util.Checksum of the texts it was parsed from: see below
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

`guide.fingerprint` is `ns.Util.Checksum` (an arithmetic checksum, `"<8 hex>-<8 hex>-<length>"`) of the guide's own text and of every
chapter it included, each with its id, in the order they were read. Step ids are positions in those texts, so it says which text a
step id belongs to. It is the same for every player and every profession plan (gates and tracks are applied after the texts are read
and profession tracks are separate texts), and any change to a text changes it, a comment too. Nil when the checksum could not be made.

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
  directives), while a quest the player took decides it like any other (GUIDE-FORMAT "Optional-only steps"). That holds only
  once the client has sent the quest log (`ns.Context:QuestLogLoaded()`): before that an empty log proves nothing, a quest the
  player holds may be in the log that has not arrived, and every optional directive of the step counts as in any other step (it
  waits for them, or for `>`). A context without the query counts as loaded.
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
  `:QuestLogLoaded()` → true once the client has told us about the log (a `QUEST_LOG_UPDATE` arrived, or the walk of the log
  found a quest; it stays true): before that an empty log may be a log not sent yet. The turn to loaded is a change
  (`CONTEXT_CHANGED("quests")`) even when the log is empty, and `/signpost context` saves it (`questLogLoaded`).
  VERIFY(beta): the client sends `QUEST_LOG_UPDATE` once the log is there, also for a character with an empty one.
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
  gives the crossings touching it, two the ones between them. An entry with `ride = { kind = "boat" | "zeppelin", label?,
  wait?, waitText?, fromText?, toText?, verify? }` (and `oneWay = true`) is a ride, not a crossing: a boat, zeppelin or airship
  between the two zones whose docks nobody has recorded (map IDs only). `:Borders()` leaves it out; `:Rides(mapA, mapB)` lists
  copies the same way; a ride that is no boat or zeppelin is rejected (`borderErrors`).
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

### Engine/Placement.lua — `ns.Placement`

Where in a guide a character is, from what it has already done (user, 2026-10-21: a level 32 character "decides to start using the
add-on", and the guide should "slot in at the appropriate level and place"). A pure function over a parsed guide and a snapshot of the
player; it reads no game state, so the specs and the simulation drive it directly. `ns.Progress` runs it (see "Placement" under
`Engine/Progress.lua`).

- `:Find(guide, snapshot, opts?)` → result, or nil for a guide without steps. `snapshot = { level, done(questID), active(questID),
  ready(questID)? }`: `done` is flagged completed (or turned in), `active` in the quest log, `ready` in the log with every objective
  done; a missing function knows nothing. `opts` overrides the constants (`openWeight`, `doneWeight`, `levelWeight`, `bias`) for the
  simulation. The result: `index` (the step the pointer goes on, 1 .. #steps), `split` (1 .. #steps + 1: everything before it is behind
  the character), `mode`, `confidence`, `sharpness`, `level`, `expected` (the guide's expected level at the split), `top` (the guide's
  top level), `done`, `active`, `total` (distinct quests of the guide), `skipped` (steps before the pointer that are not done), `ahead`
  (steps at or after it that are done) and `labels` (one per step).
- `:Labels(guide, snapshot)` → labels, stats; `:Levels(guide)` → lv, top; `:Fit(labels, stats, lv, top, snapshot, opts)` → result: the
  parts of `:Find`, apart so that the simulation works out the labels once and tries many constants.

**Labels.** A step is *done* when it has quest directives (`.accept`, `.turnin`, `.complete`) and the snapshot satisfies all of them by
the rules `ns.Conditions` uses (`.accept`: in the log or done; `.turnin`: done; `.complete`: done, or ready to hand in), *open* when it
has some and not all, *neutral* when it has none (a trip, a training, `.level`, `.todo`, a profession step: no evidence either way). A
quest the step marks `.optional` counts only when nothing else in the step does, and then only as evidence of progress.

**Expected levels.** `lv[i]`, i = 1 .. #steps + 1: each chapter's `levels` interpolated over its steps (its first level at its first
step, its last at the step after its last), never below an earlier step's, a `.level N` gate seen so far, or the top level of a chapter
already left. A dungeon chapter's levels say where it is on offer, not where the route is, so they add nothing. `false` where the guide
says nothing; `top` is the higher of `lv[#steps + 1]` and the guide's declared top level.

**The fit.** The split k minimises `OPEN_WEIGHT × (open steps before k) + DONE_WEIGHT × (done steps at or after k) + LEVEL_WEIGHT ×
distance(lv[k] + BIAS, [level, level + 1))` (prefix sums, O(n); ties go to the earliest k, so a trip between the last quest done and the
next one open is the step shown). It is a changepoint fit, robust to a few skipped quests and quests done early: a step skipped costs
`OPEN_WEIGHT`, a step done early `DONE_WEIGHT`, a level the guide does not expect `LEVEL_WEIGHT` per level. The pointer, `index`, is
the split moved past the steps that are done already (the engine would pass them at once, and the chat line names the step the player
sees). The *mode* says what the placement went by: `none` (no quest of the guide done or in the log and the level 2 or below, unknown, or
the guide says nothing about levels: the first step), `history` (some quest done or in the log), `level` (none, but a level above 2: a
guess from the level alone, and the quest steps before the pointer are marked skipped) and `end` (the split is #steps + 1: the character
has done the guide or is above its top level; the pointer goes on the last step). The *confidence* comes from the boundary: of the last 6
steps with a quest before the split the share that are done, and of the first 6 after it the share that are open, averaged
(`sharpness`): `high` from 0.85, `medium` from 0.7, else `low`; `level` is always `low`, `none` always `high`.

| Constant | Value | |
|---|---|---|
| `OPEN_WEIGHT` | 0.25 | a step not done before the pointer; players skip quests, in runs, and 0.5 or more drags the pointer back over them. 0 when nothing is done at all (every quest step is open then only for want of evidence) |
| `DONE_WEIGHT` | 1 | a step done at or after the pointer: it says the pointer is late |
| `LEVEL_WEIGHT` | 6 | one level between the character and the guide's expected level: a level far from the history's is not put there on the strength of a few quests, and a clean history wins over a level off by one |
| `BIAS` | 0.5 | a chapter's levels are whole levels, so the straight line runs about half a level under the level a character has at that step (found against the simulator's levels) |
| `NO_EVIDENCE_LEVEL` | 2 | up to this level a character with nothing done is at the first step |
| `SHARP_WINDOW`, `SHARP_HIGH`, `SHARP_MEDIUM` | 6, 0.85, 0.7 | the confidence |

**How the constants were chosen, and how well it works.** By simulation over the shipped guides, not by taste:
`tests/helpers/placement_sim.lua` parses each guide with the real parser, builds a character who followed it to step *t* (the quests of
the steps before *t* handed in, those accepted before and handed in after in the log, the level the guide has at *t*), spoils it the way
real play does (10 to 30 percent of the quests skipped, also in runs of six; four quests done early; the level off by one or two; the
quest log empty; no history at all; and characters who did not follow the guide: half its quests done in no order, or who stopped
following it part of the way), places it with `:Fit` and measures the error in steps, in quest steps (a trip between two quests cannot be
told from either) and in levels. The true level at each step comes from three models: the guide's own levels, the same with each
chapter's pace distorted (the default: it makes the straight line wrong inside a chapter), and the levels `tools/guide_sim.py` walks
(quest experience from the data pack: the model that found `BIAS`). `tools/placement_report.lua` prints the tables, compares sets of
constants (`--set`) and searches them (`--tune`); `python tools/placement_report.py` runs it all in one command and prints the tables
below, which `tests/placement_spec.lua` holds to bounds with fixed seeds. Tried and not kept: a band around the character's level from its
experience fraction, a dead band on the level term, and limiting the split to a window around the level; none helped on all guides.
Re-run the tool and paste its tables here after a guide is regenerated.

Quest steps from the true place, median / 90th percentile (warp truth, seed 1, 2026-10-21, `OPEN_WEIGHT 0.25, DONE_WEIGHT 1, LEVEL_WEIGHT 6`,
guides as of this commit; the two druid guides were being regenerated at the time):

| The character | Tauren Druid (HARDCORE) | Troll Hunter | Skyborne Druid (HARDCORE) |
|---|---|---|---|
| followed the guide to the step, nothing else | 0 / 0 | 0 / 0 | 0 / 0 |
| also skipped a fifth of the guide's quests | 0 / 3 | 0 / 2 | 0 / 2 |
| skipped 30 percent, in runs of about six | 0 / 7 | 0 / 4 | 0 / 6 |
| also did four quests that come later | 0 / 3 | 0 / 4 | 0 / 4 |
| its level is off by up to two | 0 / 7 | 0 / 11 | 0 / 13 |
| its quest log is empty | 1 / 4 | 1 / 3 | 1 / 3 |
| skipped a fifth in runs, did some early, level off by one, log half the time empty | 2 / 8 | 2 / 9 | 2 / 11 |
| stopped following the guide at 40 percent of the way and levelled elsewhere | 9 / 23 | 5 / 20 | 9 / 24 |
| did half the quests of the guide that its level allows, in no order | 8 / 23 | 9 / 27 | 10 / 27 |
| no quest history at all, only the level (level off by one) | 10 / 26 | 7 / 23 | 10 / 24 |

Runs ending three or more levels from the true level: none, except 0.4, 0.2 and 0.2 percent for the character who did half the quests in no
order. Against the levels the simulator walks (the same table, `--truth sim`): Troll Hunter 0 / 1 for the exact follower, 2 / 9 with all the
noise, 7 / 23 with no history; the Tauren guide, whose chapter levels are on average 1.6 levels (up to 4.6) below the simulator's, 0 / 8,
3 / 14 and 7 / 17, and 4.3 percent of its no-history runs three or more levels off. In words: with a real history the pointer is within a
handful of quest steps (the median is 0 to 2, the 90th percentile 2 to 13 depending on the noise); with none it is in the character's level or the next one (the
90th percentile is about two levels), which is 7 to 10 quest steps at the median in these guides; it puts a character in a chapter three
levels from its own only when the guide's own chapter levels are wrong. Limits: the level line is a straight line between a chapter's
levels; the player's position is not used (a possible addition for the no-history case); a quest the character abandoned looks like a
quest never taken.

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
  offered = { [first step id of a dungeon chapter] = true }, placed = { step, index, reason, mode, time },
  fingerprint = "..." }` (states: the current step and steps with active stickies; `placed`: a placement ran, see below;
  `fingerprint`: the `guide.fingerprint` of the text the record was made for, stamped when the guide loads).
- **The record belongs to one text of the guide.** A step id is a position in the guide's text, and a regenerated chapter keeps its
  ids while its steps change, so a saved place is trusted only for the text it was made for. When a guide loads (not when it is parsed
  again for a profession plan) for a character that is not new to it, `SetGuide` compares `record.fingerprint` with `guide.fingerprint`;
  when they differ, or the record has none (an older version wrote none), the record is dropped (`Progress:Forget`: the marks, the
  stickies, the saved states, the offers and the place, all keyed by step id) and the character is placed from its quest history as for a
  lost place (`reason "lost"`, with its own chat line: "Your saved place may not match this version of the guide, so it is found again
  from your quest history."). In plain words: after a guide update the add-on finds your place again from your quest history. The new
  fingerprint is stored at once, so a record for the same text keeps its place exactly as before. A guide without a fingerprint is
  trusted as before (nothing to compare).
- **Placement** (`Progress:Place(opts)`; user, 2026-10-21; the algorithm and its numbers are under `Engine/Placement.lua`): puts the
  pointer and the marks where `ns.Placement:Find` says, from the live `ns.Context` (`Level`, `QuestCompleted`, `QuestInLog`,
  `QuestReady`; a stand-in without them knows nothing, which places no one). It runs by itself in three cases, and on demand:
  - *First use* (`reason "first"`): `SetGuide` for a guide the character has never been in (`:IsFresh()`: no step done or skipped, no
    `placed`, the saved step absent or the first one; a different guide than the one loaded, never a re-parse of the same one after
    a profession plan change) places before the first evaluation, so the load is one `STEP_CHANGED("load")` on the right step. Above
    level 2 it first waits for the quest history, the completed-quest list the client fills a moment after login (`historyReady`: the
    list is loaded and not empty; a quest in the quest log does not count as the list, because the log is read separately and a
    placement by the log alone marks everything the character did before it as skipped; VERIFY(beta), FOREVER-API-NOTES "Open
    probes"). It places on the first `CONTEXT_CHANGED("quests")` that finds the list, or after 5 s by what there is (the quest log
    and the level). A placement made without the list is made once more, with `reason "refine"`, when it turns up, if the pointer is
    still on the step the first one ended on. A move by the player's hand (`>`, `<`, skip, a jump, a dungeon chapter's skip:
    `Progress:PlayerMoved`) ends either wait for good: a placement made later would move the pointer under the player and turn the
    steps they marked done into skipped ones.
  - *A lost place* (`reason "lost"`): the record has progress that matches nothing in the guide (an install changed the step ids;
    `Resume`'s second result), or it is for another text of the guide (the fingerprint above: the second chat line, and the whole
    record is dropped). The character is placed instead of sent to step 1, after a chat line that the guide was updated; the
    old ids are dropped from the record. A record where some marks still match and whose fingerprint is the guide's keeps the old rule
    (after the furthest one).
  - *On demand* (`reason "manual"`): the Journal's "Find my place" and `/signpost place`, any time. It is a manual move: `<` right
    afterwards takes it back (the pointer, the marks and the furthest step as they were); any other move drops the undo.
  - *Applying*: the steps before the pointer are marked done (their quests are, or they have none) or skipped (their quests are not
    done; a skip the player made by hand on a step with no quest of its own stays), the pointer's step and every step after it are
    cleared. The flags are set directly and never through `Skip`, which would decline a profession; the sticky directives of the
    steps marked done are started (`StartStep`, as the walk through them would have: the goal, a skill or a level to reach, is going
    beside the route unless it is met already, so a character placed at a step has the goals of one that walked to it), those of
    steps skipped are dismissed. Then `GUIDE_PLACED(result, reason)`, the evaluation (`STEP_CHANGED("place")`;
    inside `SetGuide` it is the load's) and `Settle`: the chat lines, which name the step the engine settled on (it passes steps that are
    done already), the undo, and the second look.
  - *The chat lines* (`ns.L`): "Your place: step 143/368 (The Barrens). 62 of this guide's 185 quests are done, 3 are in your quest
    log, and you are level 17.", then "N earlier steps you have not done are marked skipped." with "Wrong? Click a step in the Journal,
    or type /signpost place to try again."; for a placement by the level alone "None of this guide's quests are done yet, so this is a
    guess from your level (17)." with "Not sure about this one: ..." (also for a low `confidence`); at the end "This guide ends at level
    30 and you are level 32: your place is its last step" or "All of this guide's quests are done"; nothing at first use for a
    character with nothing to go on, "nothing to go on yet" when asked.
- `:Reset()` and `/signpost reset progress`: forgets this character's record of the guide and loads it again as for a new
  character (so it is placed again). Typed twice, at most 30 s apart: the first time it says what it will do.
- Fires `GUIDE_LOADED`, `GUIDE_PLACED`, `STEP_CHANGED`, `STICKY_CHANGED`, `DUNGEON_SKIP_OFFER`. Registers `/signpost next|back|skip
  [chapter]|step [n|id]|place|reset progress`: `Core/Slash.lua` looks a two-word command up before its first word, so `/signpost
  reset` stays the step frame's. With `SignpostDB.debug.chat` it prints every step change (the Phase 2 acceptance walk).

### Engine/Tracking.lua — `ns.Tracking`

The quest log's tracked quests follow the current step (user, 2026-10-20): the quest tracker and the minimap then show the
quests of the step, and the tracker shows their progress (which is why the step frame lists the quests and leaves their
objectives to the quest log). One state machine, written out in the comment at the top of the module (states, the events that
move between them, the saved fields); `Tracking.state.mode` is its state for the step in hand.

- **States:** `idle` (nothing is managed: no step yet, the module could not act when the step began, the client has no watch
  functions, or the tracker was just given back), `following` (the tracker is set to the step's quests, and set again when the
  quest log's set of quests changes), `player` (backed off for the player: they tracked or untracked a quest by hand during the
  step; `Tracking.state.manual` is true), `client` (backed off for the client: it tracked none of the step's quests) and
  `restoring` (transient, while the player's earlier tracking is given back).
- **When it acts:** `Tracking:Active()`, which is `Tracking:Paused() == nil`: the setting is on (`Tracking:Enabled()`), a guide is
  active (`ns.Progress:Guide()`), the step card is shown and `/signpost tracking test` is not running (`Paused()` says which
  of `"off"`, `"noguide"`, `"hidden"`, `"testing"` stops it). The card's flag is the saved one, `SignpostDB.stepFrame.shown`
  (`/signpost hide`, the Journal's "Show the step card"), not the hides the card does by itself in combat, when dead or while the
  Journal is open (so opening or closing the Journal changes nothing here). Otherwise it does nothing at all: no client call, not
  even for a change of the quest log. When the card's flag turns on again (`StepFrame:SetShown(true)`, `StepFrame:Reset()`; the
  module wraps those two methods at `DB_READY` and watches the flag, so the card's file does not know about it)
  `Tracking:OnCardShown()` sets the tracking for the current step as a new start. Hiding the card gives nothing back: it pauses
  the module.
- **A step becomes current** (`STEP_CHANGED` for another step id; `Tracking:SetEnabled(true)` and the card shown again force it):
  a new start. The quests the step is about are tracked first, those of its `.complete` and `.turnin` directives
  (`Tracking.NamedQuests(step)`: in directive order, each once) that are in the quest log (`ns.Context:QuestInLog`, which also
  finds a quest under a collapsed header). Only when the client tracks at least one of them are all the other tracked quests
  untracked, and the step's quests a full tracker refused are added again. If none got tracked the module backs off for the
  client (below). A step that names no quest in the log (a pick-up, a trip) changes nothing and makes no client call. The first
  successful application for the step also gives the first of its quests that is not complete to
  `C_SuperTrack.SetSuperTrackedQuestID`, unless `GetSuperTrackedQuestID` already returns one of them; later applications for the
  same step do not move the focus.
- **The same step announced again** (the engine parsed the guide again: `PROFESSION_PLAN_CHANGED`, `GUIDE_SELECTED`) is not a
  new start: when the module backed off for the player it still does, otherwise it sets the tracking again without the focus. A
  reload or login is a new start, except for the saved fact below.
- **The quest log changes while the step is current** (`CONTEXT_CHANGED("quests")`): only when the *set* of quests changed (a
  quest accepted or removed; progress inside a quest, or a header collapsed or expanded, changes nothing and costs no call)
  the tracking is set again for the step, without the focus, unless the player has changed the tracker meanwhile (next item).
  A quest that arrived is not compared: it is untracked unless the step is about it.
- **Who changed the tracker.** The module reads the tracker back after every write and keeps that as `left` (`state.left`; saved
  as `SignpostCharDB.tracking.left`). A quest the log already had whose tracked state differs from `left` was changed by
  somebody else, and the game is told from the player by (1) the watch type, `C_QuestLog.GetQuestWatchType` against
  `Enum.QuestWatchType` (Automatic is the game's own tracking, as when it tracks a quest as its progress changes; Manual is
  not; a watch of the game's that the step is about is left standing, and the game dropping it is not the player's doing), (2)
  when the change is seen as it happens (the event `QUEST_WATCH_LIST_CHANGED`, where the client has it; a bunch of events is
  looked at once, 0.3 s after the first), a `QUEST_ACCEPTED` or `QUEST_WATCH_UPDATE` within `GAME_WINDOW` (2 s) before it is the
  game's own tracking (and is then taken into `left`, so it is not judged again), (3) otherwise the player's: the module backs
  off, `Tracking.state.mode` is `player`, and `SignpostCharDB.tracking.handsOff` holds the step's id. Without watch types and
  without that event a change by the game still looks like the player's (documented limit: it fails safe, the player is never
  fought). The check runs at the next change of the quest log's set of quests, at the watch list event, and at `PLAYER_LOGOUT`
  (a reload is a logout too, so a change made just before a reload is remembered).
- **Backed off for the player** lasts until the next step (a new start), until the player toggles the setting, or until the step
  card is shown again. The saved fact is honoured only by the first start after a reload and only for the step it names; any
  other start forgets it.
- **Backed off for the client** (`Tracking.state.mode == "client"`): the tracker was left as it was, one entry goes to the error
  log for the streak ("Signpost: quest tracking backed off: ...", `ns.Errors`), and the module tries again: on a timer 5, 15, 45,
  120 and 300 s after the 1st to 5th failure in a row, and at a step, a change of the quest log's quests or a watch list event
  that comes after the back-off, never earlier (`BACKOFF`, `due()`: a burst of steps or quest log changes costs one try). After
  the fifth failure there is no more timer and the back-off stays 300 s. A success ends the streak; toggling the setting or the
  card shown again start over. A full tracker is recovered this way once the player frees a slot; the module does not free one
  itself (it could lose a quest of the player's).
- **Giving back** (`Tracking:Release()`): the first time the module is about to change the tracker it remembers what the player
  had tracked (`SignpostCharDB.tracking.before`, in tracker order, quests in the log only; once, until it is given back). When
  the setting is turned off (also while the card is hidden: it is the player's own act) or a guide choice leaves no guide
  active (`GUIDE_SELECTED`), it puts that back, once: what the module added and the player did not untrack since is untracked,
  what it removed and the player did not track again since is tracked again (quests the player changed after the module's last
  write are theirs, as is what the player tracked by hand), only quests still in the log count, and when none of the earlier
  tracking is left the tracker stays as it is rather than ending up empty. It says what it did in chat. A guide that reaches its
  last step keeps that step current: nothing ends and nothing is given back.
- `Tracking:Enabled()`, `Tracking:SetEnabled(on)`: `SignpostDB.settings.trackStepQuests` holds only the player's own choice
  (Journal > Settings > Quest tracker); until they choose, `Tracking.DEFAULT_ENABLED` (true, the user's choice) is the answer
  and the one place the default lives. Either way it is a new start (back-off and the saved hands-off fact forgotten); turned
  on it takes effect for the current step at once, turned off it gives the earlier tracking back.
- **`/signpost tracking`** prints the setting, the state, the step, what the module last set, what it keeps to give back, the
  back-off, the quests tracked now (with the client's watch type) and which watch functions the client has.
  **`/signpost tracking test`** (out of combat only) watches one quest of the log and unwatches it again (the quest tracked
  last when every quest is tracked: it is taken off and put back, so the order stays), reads the tracker back after each call and
  once more 1.5 s later, notes the watch events that arrive meanwhile, puts the tracker back once more if it is not as it was,
  says in chat what it did, and records it in `SignpostDB.probe.tracking` (shape, which functions exist, `Enum.QuestWatchType`,
  each call's return or error with the readback, counts before and after, events, `restored`, `limits`). The module is paused
  while it runs and picks up afterwards (a step or the setting changed meanwhile is applied then). The module also keeps the
  first twelve observations of the game's own tracking in `SignpostDB.probe.trackingSeen` (what the client says about a quest
  that arrived and how a change was told). `/signpost probe` keeps both (`Probe.keep`).
- Client API, all through `Util.Call` (pcall in the test) so a missing or failing function costs this feature and never the
  step engine. Retail shape: `C_QuestLog.GetNumQuestWatches()`, `GetQuestIDForQuestWatchIndex(i)`, `GetQuestWatchType(questID)`
  (any value but nil and false is tracked, `Enum.QuestWatchType.Automatic` (0) too; the watch list answers when it is missing),
  `AddQuestWatch(questID, Enum.QuestWatchType.Manual)`, `RemoveQuestWatch(questID)`; `C_SuperTrack.GetSuperTrackedQuestID()`
  and `SetSuperTrackedQuestID(questID)`. Where `C_QuestLog` lacks `AddQuestWatch` or `RemoveQuestWatch`, the Classic shape on
  quest log numbers: `AddQuestWatch(number)`, `RemoveQuestWatch(number)`, `IsQuestWatched(number)`, `GetNumQuestWatches()`,
  `GetQuestIndexForWatch(i)` (a quest's number from `C_QuestLog.GetLogIndexForQuestID`, else a walk of `C_QuestLog.GetInfo`;
  the quest at a number from `GetQuestIDForLogIndex`, else `GetInfo`). Unverified on Forever (API notes, "Open probes").
  `QUEST_WATCH_LIST_CHANGED`, `QUEST_ACCEPTED` and `QUEST_WATCH_UPDATE` are used as described; the module works without the
  first.
- **`Core/Probe.lua`'s quest log capacity** (`SignpostDB.probe.questLogMax = { canAccept, canAcceptKind, legacyGlobal, entries,
  quests, numQuests }`): `C_QuestLog.GetMaxNumQuestsCanAccept()`, the Classic global `MAX_QUESTLOG_QUESTS`, the entries of the
  quest log (headers too), the quests among them counted by walking the log, and the client's own count (the second result of
  `GetNumQuestLogEntries`). The quest log holds 40 quests on Forever: confirmed by the user in game, 2026-10-21; the probe records
  the client's own answer as the evidence and a cross-check. Nothing in the engine reads it yet.

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

**Profession part (`Core/LearnProfessions.lua`, `Learn.Professions`; built on the mock, none of it seen in the client).**
Same opt-in as the rest (`Learn:Recording()`: the player's yes on a release build, dev builds always), same guards (a
player or a pet is never an NPC, secret values are skipped), read-only (no window is clicked or filtered), nothing leaves
the SavedVariables file. No player name, no chat and none of the player's gold is read; `known` and the skill value are
the only things about the character, and the importer drops `known`.
- `trainers[npcID].services = { { id = spellID, item = itemID, n = name, r = rank text, cost = copper, lvl = required level,
  need = required skill, line = skill line ID, known = true }, ... }`, filed at `TRAINER_SHOW` (always) and
  `TRAINER_UPDATE` (not within a second of a read that found services). A service is one entry by spell ID, else by name and
  rank; the latest reading of a service replaces the older one, and a service the window does not list stays (the window's
  own filters hide some). Headers and rows that told nothing beyond an ID are skipped (`trainers[npcID].spells` keeps the
  IDs). Class trainers are recorded too (`line` absent). At most `LIMITS.servicesPerTrainer` (150) per trainer.
- `recipes[spellID] = { n, line = skill line ID, item = what it makes, reagents = { [itemID] = count }, obs = { { skill,
  cat }, ... }, t }`, filed from the trade skill window one `SCAN_DELAY` (0.5 s) after the last of `TRADE_SKILL_SHOW`,
  `TRADE_SKILL_LIST_UPDATE`, `TRADE_SKILL_DATA_SOURCE_CHANGED`, `TRADE_SKILL_UPDATE`. `cat` is the difficulty the game showed
  at the character's skill (`optimal` orange, `medium` yellow, `easy` green, `trivial` grey; only for recipes the character
  knows), `skill` the character's skill in that profession (the first sane value of the child profession, the modern
  `GetTradeSkillLine` rank, the Classic `GetTradeSkillLine` rank, `ns.Player.professions` and the base profession, in that
  order); of the observations only the lowest and highest skill seen in each difficulty are kept (at most eight), which is
  all the colour thresholds can be read from. A linked or guild trade skill window is never read. At most `LIMITS.recipes`
  (2000) recipes (the one seen longest ago goes), `reagentsPerRecipe` (12) reagents each. Without a skill line for the
  window nothing is filed.
- Client API, every call through `Util.Call`, both shapes tried: trainer `C_TrainerUI.<name>` else the global of the same
  name (`GetNumTrainerServices`, `GetTrainerServiceInfo` (name, rank text, type, or one table), `GetTrainerServiceCost`,
  `GetTrainerServiceLevelReq`, `GetTrainerServiceSkillLine` (an ID or the profession's name), `GetTrainerServiceSkillReq`,
  `GetTrainerServiceItemLink`, spell IDs also from `C_TooltipInfo.GetTrainerService`); trade skill the modern
  `C_TradeSkillUI.GetAllRecipeIDs/GetRecipeInfo/GetRecipeSchematic` and `GetChildProfessionInfo/GetBaseProfessionInfo/
  GetTradeSkillLine`, else (when it lists nothing) the Classic globals `GetNumTradeSkills`, `GetTradeSkillInfo`,
  `GetTradeSkillRecipeLink`, `GetTradeSkillItemLink`, `GetTradeSkillNumReagents/ReagentInfo/ReagentItemLink`,
  `GetTradeSkillLine`. Unverified: API notes, "Open probes", "Profession recorder".
- `SignpostDB.recorder = { trainer = {...}, tradeSkill = {...} }` is the last window's report (which API answered, how many
  services or recipes were read, how many had a name, a cost, a level, a skill, a skill line, an item, reagents or a
  difficulty, where the skill value came from, why a window was skipped): counts and function names only, so that the real
  client's behaviour is readable with `tools/read_savedvars.py recorder`. `/signpost probe` adds a `recorder` section (which
  functions exist in both shapes, everything the client's `C_TrainerUI` and `C_TradeSkillUI` hold, the enums) and the report.
- `/signpost learned` and the consent window count `trainer services` and `recipes` (`Learn.Professions:Counts()`).
  Size: a window holds a few dozen services or recipes at about 100 to 250 bytes each, so a play-through of the default
  professions is well under 200 KB (an estimate, not measured); the caps allow a few MB at most.
- Importer (`tools/signpost_tools/learned.py`): `professions[skillLine].services[npcID]` and `.recipes[spellID]` in the
  pack's schema (`Data/Schema.lua`). A service belongs to the profession it names, else to the trainer's one (a service that
  names none, at a trainer of several professions, is not filed); class trainers are reported in the gap report until the
  classes table takes them. Merge rules (the record's `t` orders the readings, across the sources of one import and across
  imports): the newest reading of a service replaces the older one, and for a recipe the newest reading's fields win field
  by field; the services and recipes another layer holds stay unless a learned reading replaces them; the observations of
  every reading are unioned and compacted again (`compact_observations`); `skill_bounds(obs)` reads where each colour starts
  as far as they say. Only
  the schema's fields are read: a name or text in a SavedVariables file cannot reach the archive or the pack. The reagents of
  learned recipes count as route items, so the vendors that sell them are kept.
- Specs: `tests/learn_professions_spec.lua` (the mock `tests/mocks/profession_windows.lua` scripts every API variant, present
  or absent), `tools/tests/test_learned_professions.py`, and the fixture `tests/fixtures/profession-recorder/Signpost.lua`,
  which the Lua spec writes with `SIGNPOST_WRITE_FIXTURES=1 busted tests/learn_professions_spec.lua` and fails on when the
  recorder stops writing exactly it, and which the Python test imports (the round trip).

Travel records (boat and zeppelin rides, innkeepers). `rides = { { from = { map, x, y }, to = { map, x, y }, side, kind?,
fromArea?, toArea?, secs, t, c }, ... }` (a list, up to `LIMITS.rides`): the dock the player left and the one they arrived at,
told from the one-second position samples (`:TrackTravel(pos)`, called by `:Sample()`) and not from a signal the client may not
send: at least three samples in a row of being carried (moving more than the player's own speed plus 4 yd) or without a map
position, with no flight, instance or death to explain it, then the player on the ground again. The dock is the last ground
sample before that (at most 15 s old when the position goes missing), the arrival the first of two ground samples after it.
The ride goes on through the loading screen of a zeppelin that crosses continents; it is dropped when it lasts less than 15 s or
more than 15 min, or the docks are less than 300 yd apart in one world; a loading screen with no ride under way (hearthstone,
summon, instance) forgets the dock. `side` is the rider's faction, `kind` what `/signpost ride boat|zeppelin` named (used once,
good for ten minutes), the areas are the game's own zone texts, `secs` the time it took. `inns[npcID] = { map, x, y, n?, t, c }`:
an NPC whose gossip offers to make the inn the player's home (the binder icon, or the words "inn" and "home") with the player's
position at that window; `n` is the bind location's name, stored when `GetBindLocation()` changes within two minutes of the
window. Both follow the contribute choice like the rest (a release build records nothing without the player's yes), and
`/signpost learned` counts them. The tables are made when first used. `tools/signpost_tools/learned.py` joins the rides there and
back into `travel.transports` (a ride whose kind nobody named is left out, with a problem line that says how to name it) and
writes `travel.inns`; `tools/guide_travel.py` turns them into `.boat`/`.zeppelin` steps and uses the inns for `.home`.

### UI/StepFrame.lua and UI/Pins.lua — `ns.StepFrame`, `ns.Pins`

- React to `GUIDE_LOADED`, `STEP_CHANGED`, `STICKY_CHANGED` (at once), `CONTEXT_CHANGED`, `TRANSPORT_STATE` (coalesced,
  0.2 s); read `ns.Progress:Current()`/`:Sticky()`/`:ActiveSticky()`/`:State()`, `ns.Conditions:Describe`/`:Targets`
  and `ns.Travel:TransportState`.
- The step frame's body is Describe's non-sticky lines, up to ten (a step lists all of its quests); an `.accept`,
  `.complete` or `.turnin` line starts with its done mark (`ns.UI.MARK`: `[x]` done, `[ ]` not yet, the Journal's own
  marks), never with objective counters, and no other line has one; every active sticky directive (the current step's
  too) is an "Ongoing:" line; below those, up to two "Optional: <quest> (group quest)" lines name the group quests
  coming up (`StepFrame:OptionalLines(step)`: the quests of `ns.Conditions:OptionalOnly(...).available` of the next three
  steps of the route, each once, and never a quest one of the current step's own directives names, which its body lists already;
  a font string of its own, not counted in the ten body lines); an in-transit line while
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
  `Collect()`, `IconFor(kind, override)`. Hooks into the Journal and the launcher: right-click → `ns.Launcher:OpenMenu(frame)` (the
  quick menu; without a Menu system `ns.Journal:Toggle(step)`, the Journal on the current step), world-pin click →
  `ns.Journal:ShowStep(step)`, `ns.Journal:IsShown()` for `hideWithJournal`. A step with no targets (a doing step) draws nothing, and
  the pins and edge arrows of the step before are cleared. A joined step has one pin for each of its `.goto` lines that still has
  something to ask (`Conditions:Targets`).

### UI/Journal.lua — `ns.Journal`

The big window (PLAN §3.2), built on `UI:CreateDialogFrame` (UI/Widgets.lua: `ButtonFrameTemplate`, movable, Esc closes it through
`UISpecialFrames`; `UIPanelWindows` is not used, to keep the panel manager untainted). A guide dropdown (`WowStyle1DropdownTemplate`, only the
guides `ns.Guides:Compatible` accepts, choosing one calls `ns.Guides:Select`), a `SearchBoxTemplate`, three `PanelTabButtonTemplate` tabs:
**Route** (a chapter list with done/total counts and the current chapter marked, the selected chapter's steps with `[x]` done, `[-]` skipped,
`>` current; a step made only of group quests (`ns.Conditions:OptionalOnly`) is tagged "(group quest)" and reads `[-]` when the route passed it
without its quest done; a click goes to the step through `Progress:JumpToId`, more than 20 steps away needs Shift; a dungeon chapter has a "Skip this
dungeon" box (`Progress:SetChapterSkipped`); a search replaces the step list with matching steps of the whole guide; a "Current step" button;
a "Find my place" button under the chapter list: `Progress:Place`, then `:ShowCurrent()` opens the chapter of the pointer),
**the class tab** (the class module's `classQuests` for the character's race, each with its status from `Context:QuestTurnedIn/QuestInLog`; a
`pending` chain reads "new in Forever: quest IDs not known yet"; hidden when the class has no chains) and **Settings** (the step card and pins
settings, the data sharing consent, the card's size and opacity, the detected profession plan with a Restore button per declined profession,
"Choose the guide for me", a button for the data sharing window). Lists are plain scroll frames (`ScrollFrameTemplate`), one chapter at a time.
- API: `:Show(tab)` (`"route"`, `"class"`, `"settings"`), `:Hide()`, `:Toggle(step)`, `:IsShown()`, `:ShowStep(step)` (opens the step's chapter
  and flashes its row for 5 s), `:ShowCurrent()`, `:SelectTab(name)`, `:Refresh()`. Refreshes (coalesced, 0.2 s) on `GUIDE_LOADED`,
  `STEP_CHANGED`, `GUIDE_SELECTED`, `GUIDE_PLACED`, `CONTRIBUTE_CHANGED`, `PROFESSION_PLAN_CHANGED`. Opened by `/signpost` (no argument, which toggles it),
  `/signpost journal [tab]`, the minimap button, the AddOn Compartment entry, the quick menu (also reached by a right-click on the step card)
  and a key binding (all of those: `UI/Launcher.lua`, below); a world-map pin click calls `:ShowStep`. It sets `SignpostDB.journal.tab`.
  The Settings tab's first column also holds the minimap button's two boxes ("Show the minimap button", "Lock the minimap button's
  position": `ns.Launcher:SetButtonHidden/SetButtonLocked`); its check boxes are drawn at `CHECK_SIZE` (26) so that eleven of them fit.

### UI/Launcher.lua — `ns.Launcher`

The common add-on interactions (`docs/INTERACTIONS.md` has the conventions, their sources, the map and the decisions). Loaded after
`UI/Journal.lua`; everything it calls on other modules is looked up at call time and guarded (`ns.Journal`, `ns.StepFrame`, `ns.Tracking`,
`ns.Progress`, `ns.Slash`, `MenuUtil`, `LibStub`), so a missing piece degrades instead of failing.

- **The minimap button** (`Launcher:Register()` at `DB_READY`, only with LibDataBroker-1.1 and LibDBIcon-1.0): a `type = "launcher"`
  object named `Signpost`, registered on `SignpostDB.minimapButton` (`{ hide, lock, minimapPos }`; defaults `hide = false, lock = false`).
  `OnClick(frame, button)` → `Launcher:Click(owner, button)`: **LeftButton** toggles the Journal, **Shift + LeftButton** (Shift read with
  `IsShiftKeyDown`) toggles the step card (`StepFrame:SetShown`, the saved `shown` setting), **RightButton** opens the quick menu; Ctrl and Alt
  are ignored, other buttons do nothing. `OnTooltipShow(tooltip)` → `Launcher:FillTooltip(tooltip)`: the name, `Launcher:Where()` (the
  step card's `<chapter> · step i/N` and the step's first line from `StepFrame.DescribeLines`, or "No guide is loaded for this character."),
  a blank line, then `hints()`: the three clicks, the key in `|cffffff00` yellow.
- **The quick menu**: `Launcher:OpenMenu(owner)` → `MenuUtil.CreateContextMenu(owner or UIParent, generator)`; the generator runs
  `Launcher:BuildMenu(owner, root)` (title, "Open the Journal", the check boxes "Show the step card", "Lock the step card" and "Track only the
  current step's quests", "Find my place" only when `ns.Progress.Place` is a function, "Previous step", "Skip this step", "Settings...", and
  "Hide the minimap button" or, while it is hidden, "Show the minimap button"). Returns `false` when there is no Menu system or it raised;
  `Launcher:OpenMenuOrSettings(owner)` then opens the Journal's Settings tab (what the right-click did before the menu). Callbacks run
  under `ns.SafeCall`; a state callback that fails reads as off. Previous step, Skip this step and Find my place run `/signpost back`,
  `skip` and `place` through `ns.Slash:Run` (the same chat lines); Find my place calls `ns.Progress:Place()` itself only when no `place`
  command is registered.
- **The AddOn Compartment**: `Core/Slash.lua` owns the three global functions the TOCs name (`## AddonCompartmentFunc`,
  `AddonCompartmentFuncOnEnter`, `AddonCompartmentFuncOnLeave`: `Signpost_OnAddonCompartmentClick(addonName, buttonName)`,
  `..Enter(addonName, buttonFrame)`, `..Leave(addonName, buttonFrame)`), each a guarded call into `ns.Launcher`
  (`OnCompartmentClick(buttonName)`, `OnCompartmentEnter(frame)`, `OnCompartmentLeave(frame)`); without the launcher a click still toggles the
  Journal. The click map is the button's (a click that names no button counts as a left-click); a **right-click opens the menu one frame
  later** (`C_Timer.After(0)`, owner `AddonCompartmentFrame` or `UIParent`) because the compartment closes its own menu after the function
  returns. The hover functions show and hide `GameTooltip` with the same lines, owned by the entry, anchored `ANCHOR_LEFT`.
- **Settings**: `:ButtonHidden()`, `:ButtonLocked()`, `:SetButtonHidden(hidden)` (writes `hide`, calls LibDBIcon `Hide`/`Show`: the library
  does not keep the flag), `:SetButtonLocked(locked)` (calls `Lock`/`Unlock`, then writes a plain boolean: `Unlock` clears the field),
  `:HideButtonWithNotice()` (the menu's version: also says in chat how to get the button back).
- **Actions** (the same ones the menu, the clicks and the bindings use): `:ToggleJournal()`, `:SetStepCardShown(shown)`, `:ToggleStepCard()`,
  `:ToggleStepCardLock()`, `:ToggleTracking()`, `:OpenSettings()`, `:CanPlace()`, `:FindMyPlace()`.
- **Slash commands**: `/signpost card [on|off]` (no word: toggle the step card) and `/signpost minimap [show|hide|lock|unlock]` (no word:
  show or hide; it reports hidden/shown and locked/unlocked).
- **Key bindings**: `Bindings.xml` (not in the TOC) declares `SIGNPOST_JOURNAL`, `_CARD`, `_BACK`, `_NEXT`, `_SKIP`, `_PLACE` under the header
  `SIGNPOST`, each running one `SlashCmdList.SIGNPOST("<command>")` (`""`, `card`, `back`, `next`, `skip`, `place`); the labels
  `BINDING_HEADER_SIGNPOST` and `BINDING_NAME_SIGNPOST_*` are set at file load from `ns.L`. They are the only globals this module adds,
  besides the two compartment functions. `tools/check_repo.py` guards the file and its labels.
- Specs: `tests/launcher_spec.lua` on the real engine, Journal and step card, with the fakes of `tests/mocks/launcher.lua` (LibDataBroker and
  LibDBIcon shaped after the bundled copy, `MenuUtil.CreateContextMenu` with a recording root, `GameTooltip`, the compartment frame, the
  modifier-key functions); it parses `Bindings.xml` and runs every binding's Lua body. `tests/journal_spec.lua` covers the Settings
  boxes, `tests/ui_spec.lua` the step card's right-click.

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
Engine\Conditions.lua, Engine\Travel.lua, Engine\Placement.lua, Engine\Progress.lua, Engine\Tracking.lua,
Classes\*.lua, Automation\*.lua, Professions\*.lua, Guides\Travel\Borders.lua, Guides\Chapters\*.lua, Guides\Professions\*.lua,
Guides\*.lua, UI\Widgets.lua, UI\StepFrame.lua, UI\Pins.lua, UI\Journal.lua, UI\Launcher.lua
```

`Bindings.xml` (the key bindings) sits at the add-on's root and is not in the TOC: the client loads it by its name.

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
- `tests/placement_spec.lua` (the pure function, then bounds on the placement simulation over the shipped guides) and
  `tests/progress_placement_spec.lua` (first use, late history, lost place, on demand with undo, `reset progress`, on the real
  stack and the scripted client). The simulation behind the constants is `tests/helpers/placement_sim.lua`; re-run it and print the
  tables of "Engine/Placement.lua" with `python tools/placement_report.py` after a guide is regenerated.
- Python tool tests in `tools/tests/test_<tool>.py` (unittest, standard library only).
- `pwsh -NoProfile -File tools/check.ps1` passes before a task is done (busted, luacheck, StyLua, check_repo, the tool
  tests and `guide_lint.py --strict --no-pack`).
