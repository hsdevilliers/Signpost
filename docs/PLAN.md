# Signpost — Implementation Plan

Status: v1 (2026-10-16). Owner: the user. Executor: Claude Code.
Companion files: `../CLAUDE.md` (rules), `FOREVER-API-NOTES.md` (client facts + open probes), `PROGRESS.md` (checkboxes, create in Phase 0).

---

## 1. One-paragraph summary

A World of Warcraft: Forever addon that walks a **Horde Troll Hunter** from 1 to 60 the way RestedXP does — an ordered list of
steps that auto-advance from quest-log events — while using **Skinning + Leatherworking** and the three secondaries
(**First Aid, Cooking, Fishing**) along the way (that guide's default profession plan; every guide works with any profession
combination, §3.8). In the default game state the addon shows exactly three things:
**(1)** a small stock-Blizzard-styled step frame with the current step, **(2)** the current step's target on the **minimap**,
**(3)** the same target on the **world map**. Everything else lives in a journal window styled like a shipped Blizzard panel
(the Dungeon Journal addon is the visual reference: it looks like Blizzard made it). The game's own quest log/tracker is used
as-is. Full RXP-style automation (auto accept/turn-in, flight paths, skill training, vendor restock, hearth) is available
behind toggles. Route data comes from a thorough offline scan of **Wowhead's WoW: Forever database**, regenerated as the
database fills in during the launch period.

## 2. Decisions already made (from the user) and assumptions (change if wrong)

| Topic | Decision | Source |
|---|---|---|
| Name | **Signpost** — folder `Signpost`, data pack `Signpost_Data`, SavedVariables `SignpostDB`/`SignpostCharDB`, slash `/signpost` (alias `/sign`), repos `Signpost` + `Signpost_Data` | user (2026-10-17) |
| Target client | WoW: Forever only (Mainline API, Interface 16001) | research, see API notes |
| Character | Horde, Troll, Hunter | user |
| Professions | **Any combination per character, for every race/class guide**: 0–2 primary professions and any of the secondary ones (§3.8). The plan is **detected from the professions the character has learned**; the guide's `#professions` (Troll Hunter: Skinning, Leatherworking, First Aid, Cooking, Fishing) only suggests professions for free slots | user (2026-10-17) |
| Data source | Wowhead WoW: Forever DB via offline export → Lua tables; re-export as DB fills in | user |
| Automation | Full: accept/turn-in, flights, train skills (plus vendor restock, hearth set) — all toggles | user |
| Testing | User has Forever beta access now (beta ends Oct 21; level cap 30) | user |
| Overlay | Step frame + minimap pin + world map pin only; nothing else on screen by default | user |
| Quest log/tracker | Use Blizzard's; do not replace or restyle | user |
| Look & feel | Stock Blizzard components everywhere (Dungeon Journal addon as the model) | user |
| Route philosophy | **Balanced**: efficient, visits all zones/dungeons/class/profession quests, "nice adventure" | user |
| Group (elite) quests | **Optional** at the recommended level, with a skip toggle; when skipped, the route offers them again about 5 levels later where it passes that town (auto-skipped if already done). Tagged from the quest type (Wowhead) or the client's quest tag | user (2026-10-17) |
| Route drafting | `tools/guide_draft.py` drafts chapters from the data pack (candidate pool, prerequisite order, town loops, simulated level, travel steps); chapters are then refined by hand and must pass `guide_lint.py --strict` | user (2026-10-17) |
| Quest XP | From QuestieDB's XP table (Classic values, with its maintainers' permission) plus the Wowhead exporter for Forever's new quests, kept as facts in the private pack for planning | user (2026-10-17) |
| Gear | Do **not** optimize for gear; user has a separate BiS-by-level addon and will farm on their own schedule | user |
| Talents & Legacy system | **Out of scope, entirely.** No talent builds, no talent-point reminders, no Legacy (account-wide perk) picks or reminders. The guide is route + quests + professions + class quests only | user |
| Class quests | **All class quest lines available to the character's class are in the route**, including Forever's new ones (trainer-offered lines, the new weapon-upgrade chains, the level-10 pet chain). The class module declares the list; the linter fails if a class quest is neither routed nor explicitly `.skipquest`-ed with a reason | user |
| Profession presentation | **Interleaved in the route only.** No Professions tab; `.skill`/`.trainprof`/`.craft` steps carry the profession info. The steps come from per-profession tracks inserted at route hubs; the character's plan is detected automatically (§3.8) | user |
| Distribution | **Open source on GitHub (MIT).** Addon code is public. Everything Wowhead-derived lives in a **private** repo as a separate dependency addon `Signpost_Data` (§6) | user |
| LW specialization | **Decide later**: a `.todo "Choose Leatherworking specialization"` step at level 40 (in the Leatherworking track, §3.8); route to 40 is specialization-neutral | user |
| Dungeon side-chapters | **Auto-inserted into the main route at the recommended level** as `#dungeon` chapters; each has a one-click skip toggle | user |
| Reward choice fallback | When a quest offers several rewards and the guide has no `.reward`, **pick the highest vendor-sell value**; stop only if item data can't be loaded | user |
| Zone transitions | **Every change of zone between consecutive steps is covered by explicit travel steps** (run-to-border waypoints, boat, zeppelin, flight, hearth), each with its own pins. The linter fails a guide with an uncovered transition; `tools/guide_travel.py` proposes the steps from a travel graph (§3.6) | user |
| Multiple characters | **One addon, one public repo, many guides.** Planned next: Orc Warlock, Tauren Shaman; **Alliance guides later.** Each is a guide file + a class module inside this addon; no per-class or per-faction addons, no cross-addon API. Per-class "lite" zips are an optional packaging script, not a design change | user (2026-10-17) |
| Faction | Nothing in engine, UI, DSL, data schema or travel graph assumes Horde. Alliance support = run the exporters with `--faction alliance`, add Alliance transports/borders to the travel data, write guides. The addon name must be faction-neutral | user (2026-10-17) |
| Release 1 | **First public release = a CurseForge download** (public addon zip only; `Signpost_Data` stays private). Minimum scope: Horde **Troll Hunter** with all professions, **Tauren Druid** and **Horde Skyborne (Windshaper) Druid** — every one a **hardcore** route. Everything else (Orc Warlock, Tauren Shaman, Alliance) comes after. No date is tied to the beta or to launch day | user (2026-10-20) |
| Hardcore routes | The Release 1 guides are **hardcore guides**: no quest the community knows to be deadly for a hardcore character is routed (each is a `#skipquest` with a reason, as for class quests); group quests are optional and offered only when safe; the `.hc` gate (already in the parser) holds hardcore-only steps. The skip list is drafted from game knowledge, marked unverified, and corrected from the friend's and the user's play | user (2026-10-20) |
| Druid first | The Druid guides (Tauren, Skyborne) come **before** the Hunter guide's polish; the engine, `guide_draft.py` and the lint are class-agnostic, so the hunter guide follows from the same tools | user (2026-10-20) |
| Friend's data | A friend will play a hardcore druid and run the addon in the background; his SavedVariables arrive through `incoming/play-machine/` and `--merge-learned --also`. The learned layer **accumulates** across imports (decided 2026-10-20), so his data and the user's are never dropped | user (2026-10-20) |
| Extensibility | **Engine, UI, DSL and data are class/race/faction-agnostic and profession-agnostic.** The Troll Hunter 1–60 route is the *first guide*, not a built-in assumption. Adding another class/race must require only a `Classes/<CLASS>.lua` module and guide files (§3.5); supporting another profession only a `Professions/<KEY>.lua` module and its track in `Guides/Professions/` (§3.8) | user |
| Libraries | Minimal — LibStub, CallbackHandler-1.0, HereBeDragons-2.0 (pins/distance), LibDataBroker-1.1 + LibDBIcon-1.0 (minimap button). No Ace3. | default, uncontested |
| TomTom/Questie | Coexist, never require. If TomTom is present, offer a "send step to TomTom" toggle (off). | default, uncontested |

## 3. Product specification

### 3.1 The three overlay elements (default state)

**Step frame** (`UI/StepFrame.lua`)
- Small, movable, lockable frame. Styling: Blizzard dialog look — `BackdropTemplate` with the standard tooltip/dialog border
  (`Interface\DialogFrame\UI-DialogBox-Border` or the `BACKDROP_TOOLTIP_*` presets), `GameFontNormal`/`GameFontHighlight`,
  header strip like the Objective Tracker's module header. No custom art.
- Content: `Chapter name · step i/N`, step text (word-wrapped, max ~5 lines, scroll of excess hidden), objective progress line
  for `.complete` steps (e.g. `Mottled Boar slain 6/10`), small icons for step type.
- Controls: `<` `>` buttons (manual back/forward), a `skip` button (marks step skipped for this character), right-click → opens journal.
  Buttons use `UIPanelButtonTemplate` sized down, or the `UIPanelSquareButton`-style arrows.
- An optional **quest-item button** (secure) appears beside the frame when the current step has `.use itemID`
  and the item is in bags. Attributes only set out of combat.
- Hidden automatically: in combat (configurable), when the journal is open (configurable), when dead.
- Shift-drag to move; position/scale/alpha saved per account.

**Minimap pin** (`UI/Pins.lua`, HereBeDragons-2.0 `Pins` module)
- Exactly one "current" pin per target in the current step (a step may have multiple targets, e.g. accept two quests from
  two NPCs 10 yards apart — all shown). Edge-of-minimap arrow behavior from HBD (`floatOnEdge = true`).
- Icon by target kind: available quest `!`, turn-in `?`, objective area (dot/circle), trainer, vendor, flight master, innkeeper,
  fishing spot, skinning/grind area. Use Blizzard atlases where they exist (`QuestNormal`, `QuestTurnin`, `TaxiNode_Neutral`,
  `poi-workorders`, etc.) — fall back to `Interface\GossipFrame\*Icon` textures. Record which atlases exist on Forever in API notes.
- Tooltip: step text + distance in yards.

**World map pin** (same module)
- Same targets on the world map (`AddWorldMapIconMap`), with the zone shown on continent views as HBD does. Click → opens journal at that step.
- Option: faintly show the next 2 steps' targets (off by default).

**Travel steps and waypoint paths** (both pins)
- A `.path` directive is an ordered list of waypoints (possibly across zones). The **minimap** shows only the next unreached
  waypoint (edge arrow when off-screen, distance in the tooltip); the **world map** shows every waypoint numbered and, on the
  zone-level map, connects consecutive ones with a line (`Line` texture on the map canvas, hidden on continent views). Reaching a
  waypoint (radius, default 15 yd) advances to the next; the final waypoint satisfies the directive.
- Boat/zeppelin/flight steps pin the departure dock/tower/flight master while you're not yet there, then the arrival point once
  you are on the transport, so the pins always say "go here next" and nothing else.

### 3.2 Journal window (`UI/Journal.lua`) — the "Dungeon Journal" look

Open with `/signpost`, minimap button (LibDBIcon), AddOn Compartment entry, or right-click on the step frame.
Register in `UIPanelWindows` (`area="left", pushable=1, whileDead=1`) so Esc closes it and it tiles with Blizzard panels.

Layout (one frame built from `ButtonFrameTemplate`, which supplies portrait, title bar, close button, inset):
```
┌───────────────────────────────────────────────────────────────────┐
│ (portrait: Hunter class icon)  Signpost — Troll Hunter 1–60       [x]│
│ [Guide dropdown ▾]            [🔍 search steps/quests]              │
│ ┌─────────────┐ ┌──────────────────────────────────────────────┐    │
│ │ Chapters    │ │  Durotar 6–10 · Sen'jin Village               │    │
│ │ ▸ 1–6 Valley│ │  ──────────────────────────────────────────── │    │
│ │ ▸ 6–10 Senj.│ │  ○ 12  Accept "Zalazane" from Master Gadrin   │    │
│ │ ● 8–12 Razor│ │  ● 13  Kill 10 Hexed Trolls … (current)       │    │
│ │ ▸ 12–20 Barr│ │  ○ 14  Turn in …                              │    │
│ │ …           │ │  ○ 15  Train Skinning (Thuwd, Orgrimmar) …    │    │
│ └─────────────┘ └──────────────────────────────────────────────┘    │
│ [Route] [Hunter] [Settings]                            ← bottom tabs │
└───────────────────────────────────────────────────────────────────┘
```
- Left list and right list are `ScrollBox` + `MinimalScrollBar` (`ScrollUtil.InitScrollBoxListWithScrollBar`), rows are
  plain `Button`s with highlight texture `Interface\QuestFrame\UI-QuestTitleHighlight`, selected row uses the same selection
  look as the Encounter Journal instance list (highlight + `GameFontHighlight`).
- Background: parchment `Interface\QuestFrame\QuestBG` in the right inset (Dungeon Journal's "parchment" feel), `InsetFrameTemplate3` borders.
- Dropdown: `WowStyle1DropdownTemplate` (new menu API) — fallback `UIDropDownMenuTemplate` if absent (probe).
- Search: `SearchBoxTemplate`; matches step text and quest names; selecting a result jumps to the chapter + highlights the row for 5 s (Dungeon Journal behavior).
- Tabs (`PanelTabButtonTemplate` + `PanelTemplates_*`):
  - **Route** — chapters/steps as above. Clicking a step sets it current (confirm if jumping > 20 steps).
    Dungeon chapters sit inline in the chapter list at their recommended level with a dungeon icon and a **Skip** checkbox
    (skipping marks all their steps skipped for this character and advances past them).
    Profession steps show a skill icon; hovering a `.skill`/`.trainprof`/`.craft` step shows current/target skill, the next
    trainer (name, zone, coords) and required materials. There is no separate professions view.
  - **Hunter** — pet quest chain at 10, ammo/quiver reminders (if Forever still has ammo — probe), trainer visits by level,
    "Train now" list of untrained ranks for current level (from spell IDs in Data).
  - **Settings** — all toggles (also registered under Options → AddOns via `Settings.RegisterCanvasLayoutCategory`), the
    character's **detected profession plan** (read-only) and the professions it declined, each with a button to restore it (§3.8).
- Step detail tooltip on hover: quest IDs, objective list, Wowhead link text (copyable via `EditBox`), "learned position" if any.

### 3.3 Step engine behavior (`Engine/`)
- Steps are ordered within chapters; chapters ordered in a guide. Current pointer saved per character.
- A step completes when **all** its completable directives are satisfied (see §5). Then auto-advance.
- **Auto-skip**: on login and after `QUEST_LOG_UPDATE`, if the next step(s) are already satisfied (quest flagged completed,
  spell known, skill ≥ target, flight path known…), skip forward (RXP "auto skip").
- **Sticky steps** (`.sticky`): remain active alongside the current step until satisfied (e.g. "skin everything until 75").
  Shown as a second line in the step frame.
- **Conditional steps**: `.class`, `.race`, `.prof`, `.hc` gates; steps for other setups are dropped at parse time (`.prof` against
  the character's detected profession plan, §3.8). A plan change (a profession learned, unlearned or declined) re-parses the guide;
  step ids are stable across plans, so progress is kept.
- **Manual override** always wins: `<`/`>`/skip never get undone by auto-skip within the same session unless a quest event proves otherwise.
- **Dungeon chapters** (`#chapter … #dungeon`) are ordinary chapters in the main sequence, placed at the recommended level.
  Their first step is a `.note` summarizing the run (quests inside, pre-quests already collected by earlier steps). A chapter-level
  **Skip** marks every step in it skipped. Auto-skip applies as usual: if all of the chapter's quests are already flagged completed, it is skipped silently.
  If the player is 5+ levels above the chapter's max level when reaching it, the step frame shows a one-time "Skip this dungeon?" prompt.
- All completion checks are event-driven + a 1 s throttled re-evaluation; no OnUpdate polling except the distance check for `.goto` (0.5 s).

### 3.4 Automation (`Automation/`), each a toggle, all off by default except where noted
- **Quest accept**: on `QUEST_DETAIL` (`AcceptQuest()`) / `QUEST_GREETING` / `GOSSIP_SHOW` (`C_GossipInfo.SelectAvailableQuest`).
  Modes: *guide quests only* (default when enabled) / *all non-trivial*. Never auto-accept quests the guide marks `.skip`.
- **Quest turn-in**: `QUEST_PROGRESS` → `CompleteQuest()`; `QUEST_COMPLETE` → `GetQuestReward(idx)` where idx is chosen as:
  1. 0 or 1 choices → the only one;
  2. guide `.reward qid,<choiceIndex|itemID>` → that one;
  3. otherwise **highest vendor-sell value**: for each choice, `GetQuestItemLink("choice", i)` → `C_Item.GetItemInfo(link)` sellPrice ×
     `select(3, GetQuestItemInfo("choice", i))` quantity. If any item's data isn't cached yet, call `C_Item.RequestLoadItemDataByID`
     and retry on `ITEM_DATA_LOAD_RESULT` for up to 2 s; if still unknown, **stop and leave the window open** with the known values
     written into the corner of each reward button (ForeverPlus-style). Setting lets the user switch rule 3 to "always stop".
- **Gossip skip**: single-option gossip auto-select; `.hs` steps select the innkeeper "Make this inn your home" option and confirm `CONFIRM_BINDER`.
- **Flight**: on `TAXIMAP_OPENED` during a `.fly Node` step, find node by name and `TakeTaxiNode`. Probe whether Forever uses
  the Classic `TaxiFrame` (`NumTaxiNodes`/`TaxiNodeName(i)`/`TakeTaxiNode(i)`) or retail `FlightMapFrame` (`C_TaxiMap.GetAllTaxiNodes`/`TakeTaxiNode(nodeID)`). Support both.
- **Trainer**: on `TRAINER_SHOW` during `.train`/`.trainprof` steps, buy only the listed spell IDs (match via `GetTrainerServiceInfo` + `GetTrainerServiceItemLink`/spell ID),
  respecting a configurable gold reserve. Never "buy all".
- **Vendor**: on `MERCHANT_SHOW` during `.buy itemID,count` steps, buy to reach `count` in bags (ammo, food for pet, fishing bait, bandage cloth is not vendor — skip).
- **Hearth**: `.home` shows the quest-item-style secure button bound to Hearthstone (item 6948); never auto-casts.
- Global bypass: **Shift held** → no automation this interaction. Also disabled while a `Settings` panel is open.

### 3.5 Extensibility seam — other classes and races later

Nothing outside `Classes/HUNTER.lua` and `Guides/` may mention HUNTER, Troll or Horde. Everything else reads `ns.Player`
(`class`, `classFile`, `race`, `raceFile`, `faction`, `level`, `professions`) populated at login.

**Guide registry** (`Engine/Registry.lua`)
- Every guide file calls `ns.Guides:Register({ id="horde-troll-hunter-1-60", name=…, faction="Horde", races={"Troll"},
  classes={"HUNTER"}, levels={1,60}, text=[[ …DSL… ]] })`. Lists may be `"*"`.
- At login the registry picks the best match for `ns.Player` (exact race+class > class-only > faction-only). The journal's
  Guide dropdown lists only compatible guides; incompatible ones are shown greyed with the reason. Switching guides keeps
  per-guide progress in `SignpostCharDB.progress[guideId]`.

**Chapter library** (`Guides/Chapters/*.lua`)
- Shared chapters are registered once (`ns.Chapters:Register("barrens-12-20", [[ …DSL… ]])`) and pulled into a guide with
  `#include barrens-12-20`. Race-specific starting zones (Durotar/Valley of Trials, Mulgore, Tirisfal) are their own chapters; a
  future Orc Hunter guide reuses every chapter from Razor Hill onward. Class-specific lines inside shared chapters are gated
  with `.class HUNTER` / `.class !HUNTER`; race lines with `.race Troll`. Profession steps do not live in chapters: chapters mark
  the towns they visit with `.hub <name>`, and profession tracks insert their steps there (§3.8).
- The parser resolves includes before gating, so the linter can report a shared chapter's unknown IDs once.

**Class modules** (`Classes/<CLASSFILE>.lua`, e.g. `Classes/HUNTER.lua`)
A class module is a table registered via `ns.Classes:Register("HUNTER", {...})` providing:
- `trainerSpells` — `{ [level] = { spellID, ... } }` used by `.train` steps written as `.train class` ("train everything due at this level") and by the Class tab's "Train now" list;
- `classQuests` — `{ { id="hunters-path", name=…, level=10, quests={6061,6062,…}, offeredBy="trainer"|npcID, newInForever=false, reward="pet" }, … }`:
  every class quest chain for this class on Forever (from the data pack's class export + Warcraft Wiki "class quests" pages). The linter requires each
  quest to be `.accept`ed and `.turnin`ed by the guide, or listed in a `.skipquest <id> >> reason` line. The Class tab lists the chains with
  live status (not started / in progress / done) and the level at which the route picks them up. Since trainers offer most class quests at
  level thresholds, the engine adds a soft check on every `.train` step: if a `classQuests` chain is available at the current level and not
  in the log or completed, the step frame appends "Class quest available here" (no auto-accept unless the route has an `.accept` for it);
- `directives` — class-only DSL directives registered into the **directive registry** (`ns.Directives:Register("tame", { parse=fn, isSatisfied=fn, targets=fn, describe=fn })`); the core only ships the generic directives from §5. `.tame`, `.ammo` live in the hunter module;
- `classTab` — a builder `fn(parentFrame)` for the journal's third tab; the tab title is the localized class name, the portrait is `GetClassAtlas(classFile)`. If a class module has no `classTab`, the tab is hidden;
- `automation` — optional hooks (e.g. hunter: vendor restock of ammo/pet food during `.buy` steps; warrior/paladin: none);
- `onLevelUp(level)` — optional reminders (e.g. "new pet skills available").

**Data pack**: `classes/<CLASSFILE>.lua` instead of a hunter-only file; `tools/wowhead_class.py --class HUNTER` is generic.
`Professions.lua` covers every profession; which ones a character follows is its profession plan (§3.8).

**Acceptance test for the seam** (Phase 6): add a throw-away `Guides/_Test_OrcWarrior.lua` (two chapters, one `#include`d from
the library, a `.class WARRIOR` line) and `Classes/WARRIOR.lua` with only `trainerSpells = {}`. On an Orc Warrior test character the
registry must select it, the Class tab must hide, and no file outside `Classes/` and `Guides/` may have changed. Delete the stub afterwards.

### 3.6 Zone transitions — explicit travel steps, pinned turn by turn

Rule: if step *n+1*'s first target is in a different zone (uiMapID) than step *n*'s last target, the guide must contain travel steps
between them. The guide never assumes the player knows the way. Travel steps are ordinary steps (they show in the step frame and
drive the pins) and use these directives:

| Directive | Means | Satisfied when | Pins |
|---|---|---|---|
| `.path m,x,y ; m,x,y ; …` | run this sequence of waypoints (may cross zones) | last waypoint reached | next waypoint on minimap; all on world map with lines |
| `.zone <uiMapID>` | you are now in zone X (usually paired with `.path`) | `C_Map.GetBestMapForUnit("player")` is X or a child of X | none by itself |
| `.fly <Node>` | take a flight to Node | arrival: on-taxi → off-taxi and zone == node's zone | flight master while not on taxi; node while flying |
| `.boat <fromM,x,y> > <toM,x,y> >> text` | board the ship at the first dock, arrive at the second | zone == destination zone (or within 200 yd of arrival dock) | departure dock until boarded; arrival dock while in transit |
| `.zeppelin <fromM,x,y> > <toM,x,y> >> text` | same for zeppelin towers | same | same |
| `.hs <Inn>` / `.home` | set hearth / use it | existing (§5) | inn / none |
| `.portal …` | reserved (future expansions) | | |

**Worked example — Durotar → Stranglethorn Vale (Horde)**
```
step
  .path 1411,52.0,43.5 ; 1411,47.8,41.0 ; 1413,61.9,54.9
  .zone 1413 >> Leave Razor Hill by the west gate and follow the road into the Barrens
step
  .path 1413,62.3,56.0 ; 1413,63.1,37.5
  .goto 1413,63.4,37.2 >> Run north-east along the road to Ratchet
step
  .fp 1413,Ratchet >> Learn the Ratchet flight path on the way
step
  .boat 1413,63.9,38.6 > 1434,27.2,77.1 >> Take the boat from Ratchet's pier to Booty Bay
step
  .fp 1434,Booty Bay
step
  .path 1434,27.5,77.6 ; 1434,31.9,70.3 ; …
  .goto 1434,32.1,29.0 >> Ride north out of Booty Bay to Grom'gol Base Camp
```
(Alternative the planner may prefer when the Orgrimmar FP is known: `.fly Orgrimmar` → `.zeppelin Orgrimmar tower > Grom'gol`.)
Coordinates above are illustrative; real ones come from the data pack + Learn.

**In transit**: while on a boat/zeppelin the player's position can be unavailable; the step frame shows "Sailing to Booty Bay…" and
the pins show the arrival dock (probe how Forever reports position on transports — API notes).

**Travel graph** (`Data` pack `Travel.lua` + hand-maintained `Guides/Travel/Borders.lua`)
- Nodes: zones, flight masters (NPC id, zone, coords), boat docks and zeppelin towers (both ends, with the transport's route), inns.
- Edges: *walk* between adjacent zones through a named crossing (two coordinates: last point in zone A, first point in zone B — e.g.
  "Durotar/Barrens west road"), *fly* between flight nodes (only usable if the guide has taught both FPs by that step), *boat*/*zeppelin*
  with a wait cost, *hearth* to the current inn.
- Border crossings are hand-authored in `Borders.lua` (small set) and **learned automatically**: `Core/Learn.lua` records, on every
  `ZONE_CHANGED_NEW_AREA`, the last position in the old zone and the first in the new one; exported crossings replace hand guesses.

**Authoring tool** (`tools/guide_travel.py`): simulates the guide step by step (current zone, FPs learned via `.fp`, hearth via `.hs`,
expected level), finds every uncovered zone change, runs a shortest-path search on the travel graph (walk cost = yards, flight cost
= fixed + distance, boat/zeppelin = wait + crossing, hearth = 0 but 60-min cooldown tracked), and prints ready-to-paste DSL steps with
`.path` waypoints along roads where `Borders.lua`/data provide them. `guide_lint.py --strict` fails on any remaining uncovered transition.

**Runtime nudge** (Phase 8, optional): if the player is 2+ zones away from the current step (logged in elsewhere, died, hearthed),
the step frame shows a "Back to route" line with the planner's suggested first hop, computed in-game from the same graph.

### 3.7 Many guides, one addon — Orc Warlock and Tauren Shaman next

Decision: additional characters are **guides inside this addon**, never separate addons. Rationale: the chapter library (zones, dungeons,
travel) is shared by every Horde route; a per-class addon split would force either duplicated chapters or a versioned cross-addon API with
load-order dependencies. Guide text is small and only the selected guide is parsed, so one addon costs nothing at runtime.

What a new character needs (and nothing else):
```
Guides/HordeOrcWarlock.lua        -- metadata + #include list; shares the troll's Durotar chapters (orcs start in Valley of Trials too)
Guides/HordeTaurenShaman.lua      -- metadata + #include list + Mulgore starting chapters (new, go into Guides/Chapters/ for future tauren guides)
Classes/WARLOCK.lua               -- trainerSpells, classQuests (imp/voidwalker/succubus/felhunter chains as Forever has them), directives if any
Classes/SHAMAN.lua                -- trainerSpells, classQuests (totem chains as Forever has them)
```
Shared chapters gain lines for the new characters' class quests, gated with `.class`, and the linter's coverage checks run per guide.
Their professions need no chapter edits at all: profession steps come from profession tracks (§3.8).

**`#professions` header = the guide's profession suggestions.** A guide declares
`#professions skinning,leatherworking,firstaid,cooking,fishing`; it fills the free slots of each character's detected plan (§3.8).
`.prof` gates resolve at **parse time against that plan** — never against the learned skills alone, because a level-1 character has
none yet and would lose every "learn this profession" step.

**Selection and progress.** The registry picks by race+class (an Orc Warlock logs in → the warlock guide), progress is per character and
per guide, and Learn data is account-wide — the second and third characters inherit every corrected coordinate from the first.

**Repos and releases stay at two.** Public `Signpost` builds one zip containing all guides. Optional later: `tools/package_lite.py --guide
horde-orc-warlock` produces a zip with only that guide's files and classes (strips other `Guides/*.lua` and `Classes/*.lua`, rewrites the TOC);
it is a packaging convenience and must never influence the layout or the code.

**Alliance later.** An Alliance guide is the same recipe: guide file(s) with `faction="Alliance"`, Alliance starting chapters in the library,
class modules reused as-is, exporters re-run with `--faction both`, Alliance borders/transports in the travel data. The registry's faction
field, `.faction` gating and per-node faction in the travel graph already exist for this; nothing else may hardcode a faction.

**Naming (decided).** **Signpost** — faction-neutral, and the metaphor is the product: Classic Azeroth's wooden road signs point you to the
next town; this addon is that signpost for the whole route. Folder `Signpost`, data pack `Signpost_Data`, slash `/signpost` (alias `/sign`;
drop the alias if a conflict is found during the probe), SavedVariables `SignpostDB`/`SignpostCharDB`, repos `Signpost` and `Signpost_Data`.
Checked 2026-10-17: no "Signpost" addon found on CurseForge in a web search — Claude Code re-checks CurseForge, Wago and WoWInterface by name in Phase 0 before creating the repos.

### 3.8 Professions are a seam too — any race + class with any profession combination

Decisions (user, 2026-10-17): every guide works with **any combination of primary professions (0–2) and any subset of the secondary
professions**, and each character's combination is **detected from the professions it has learned** — nobody picks it. A guide's
`#professions` header only suggests professions for free slots; professions are as independent of the guide as the guide is of the
faction.

**The profession plan is detected** (`Engine/Professions.lua`), on login and whenever the character learns or unlearns a profession
(`SKILL_LINES_CHANGED`; learned professions come from `GetProfessions()` → `GetProfessionInfo` → skill line → profession module):
1. every profession the character has learned, primary or secondary, is in the plan;
2. free primary slots (2 minus the learned primaries) are filled with the guide's `#professions` primaries, in header order, skipping
   learned and declined ones — a new character is routed to learn the guide's suggestions; one that learned Mining keeps a suggestion
   only for its still-free slot;
3. the guide's secondary professions stay in the plan until learned or declined;
4. **declining is automatic too**: skipping a track's step that teaches the profession (its first `.trainprof`) marks it declined for
   the character (`SignpostCharDB.declinedProfessions[key] = true`), so the next suggestion takes the slot; going back (`<`) over that
   step undoes it.
There is no picker and still no Professions tab: the journal's Settings tab shows the detected plan and the declined professions, each
with a button to restore it. A character with no free slots and nothing suggested simply gets no profession steps.

**Profession modules** (`Professions/<KEY>.lua`, registered with `ns.Professions:Register(key, {...})`, the counterpart of
`Classes/`): skill line ID, primary or secondary, gathering or crafting, rank caps (Apprentice/Journeyman/Expert/Artisan — Classic
75/150/225/300 until verified), and profession-only directives if any. Everything generic comes from the client (`Enum.Profession`,
`C_TradeSkillUI.GetProfessionInfoBySkillLineID`; `/signpost probe` lists them) and from the data pack's `Professions.lua` (recipes, skill
ranges, reagents, trainers per faction for **every** profession), so a module stays small.

**Profession tracks** (`Guides/Professions/<key>.lua`): the route steps for one profession — learn and train ranks, gathering stickies
per zone band, crafting batches with their materials, profession quests, the LW specialization `.todo` — written **once** and inserted
into any guide whose character's detected plan includes that profession:
- chapters mark every town the route passes through with `.hub <name>` on the step that is there (e.g. `.hub orgrimmar`,
  `.hub crossroads`); hubs are faction-neutral names, so the same track serves every guide that visits the town;
- a track step says where it belongs: `@hub <name>` (the first visit to that hub at or after the track's previous step), or
  `@level <n>` / `@zone <uiMapID>` (the first route step at that expected level or in that zone), optionally with a skill condition;
- the parser merges the plan's tracks into the route deterministically after `#include` and gating; track steps keep ids of their own
  (`<track>:<n>`) next to the chapter ones, so changing the plan never disturbs progress on the route;
- trainers and vendors in a track are resolved per faction from the data pack, so one track serves Horde and Alliance routes;
- the linter fails a track step that finds no anchor in a guide, a trainer visit at a hub where the data pack knows no trainer of that
  profession for the guide's faction, and a crafting step whose materials are neither gathered earlier nor bought.

**Seam rule (CI):** profession names and keys may appear only in `Professions/`, `Guides/`, tests and docs — the same rule and the
same check (`tools/check_repo.py`) as classes, races and factions. Engine and UI code read `ns.Player.professions` (learned) and the
detected plan.

**Acceptance test for the profession seam** (Phase 6): the Troll Hunter guide, unchanged, serves a character that has learned
Herbalism + Alchemy and declined the secondary professions, after adding only `Professions/HERBALISM.lua`, `Professions/ALCHEMY.lua` and
their tracks (stubs are fine): the detected plan is Herbalism + Alchemy, the merged route contains their steps at the right hubs, the
Skinning/Leatherworking/secondary steps are gone, the linter passes, and no file outside `Professions/` and `Guides/Professions/`
changed. A busted spec covers the same with a mocked `GetProfessions`. Delete the stubs afterwards unless they are real content.

## 4. Architecture

```
Core/Init.lua        ADDON_NAME, ns, version, L table, SafeCall, event frame (RegisterEvent → ns.Events:Fire)
Core/SavedVars.lua   defaults + migrations for SignpostDB (account) and SignpostCharDB (char)
Core/Slash.lua       /signpost (alias /sign) [show|hide|reset|skip|back|probe|dumpmaps|export|debug]
Core/Probe.lua       prints/stores existence of APIs, templates, atlases, enums (Phase 0; drives API notes)
Core/Learn.lua       records NPC/object positions when interacting (self-healing data)
Core/Player.lua      ns.Player: class/classFile/race/raceFile/faction/level/professions (the only place UnitClass/UnitRace are called)
Engine/Directives.lua registry: name → { parse, isSatisfied, targets, describe }; core directives registered here, class ones from Classes/
Engine/Registry.lua  ns.Guides (guide metadata + selection for ns.Player) and ns.Chapters (shared chapter library, #include)
Engine/Professions.lua ns.Professions registry (modules from Professions/), detecting the character's profession plan, merging the plan's
                     profession tracks into the parsed route at .hub/@level/@zone anchors (§3.8)
Engine/Parser.lua    DSL text → guide table (resolve #include → gate by class/race/faction/prof → chapters → steps → directives); line-numbered errors
Engine/Conditions.lua dispatches to Directives[...].isSatisfied / targets for a step
Engine/Progress.lua  current pointer per guide, auto-advance/skip, sticky set, manual override, persistence
Engine/Context.lua   cached player state: questlog (by questID), completed set, known spells, skills, taxi nodes, bags, zone, onTaxi
Engine/Travel.lua    waypoint progression for .path, transport state (not boarded / in transit / arrived), zone-subtree checks,
                     in-game shortest path over the travel graph (for the optional "Back to route" nudge)
Guides/Travel/Borders.lua  hand-authored zone crossings {fromMap,x,y, toMap,x,y, name}; replaced by learned crossings when available
Classes/HUNTER.lua   class module (trainerSpells, hunter directives .tame/.ammo, Class tab builder, vendor hooks) — see §3.5
Professions/<KEY>.lua profession module (skill line, primary/secondary, gathering/crafting, rank caps, own directives) — see §3.8
Guides/Chapters/     shared chapter library (one file per zone/dungeon chapter)
Guides/Professions/  profession tracks: one file per profession, inserted into any guide at hub anchors (§3.8)
Guides/HordeTrollHunter.lua  the first guide: metadata + #include list + race/class-specific chapters
Data/Schema.lua      PUBLIC: empty tables + field docs; ns.DB = Signpost_Data or ns.EmptyDB (addon must run without the pack)
../Signpost_Data/   PRIVATE sibling addon (own TOC, `## LoadOnDemand: 0`, listed in our `## OptionalDeps`); defines global
                     Signpost_Data = { quests[id]={n=name,l=level,r=reqLevel,s={npc=…|obj=…|item=…},e={…},o={objectives},c=chain},
                     npcs[id]={n=name,p={{map,x,y},...}}, objects, items (vendor/drop src), maps (uiMapID↔wowhead zone), professions,
                     classes, travel={flightMasters, transports(boats/zeppelins with both ends), inns, adjacency}, _meta }
                     Without the pack: guides still work (they embed IDs + coords), pins still render; only names/validation/objective text degrade.
Guides/*.lua         ns.Guides["Horde Troll Hunter 1-60"] = [[ ...DSL... ]]
UI/StepFrame.lua, UI/Journal.lua, UI/Pins.lua, UI/Options.lua, UI/Widgets.lua (shared row/tab factories)
Automation/*.lua     one file per subsystem, each registering its own events, each with a `enabled()` check
```
Data flow: events → `Context` refresh → `Progress:Evaluate()` → `Conditions` → (advance?) → `ns.Events:Fire("STEP_CHANGED")`
→ StepFrame/Pins/Journal re-render. Automation modules read `Progress:Current()` to decide what to do at NPCs.

SavedVariables:
- `SignpostDB` = `{ settings={…}, learned={ npcs={[id]={map,x,y,t}}, objects=…, taxi=… }, mapDump={…}, framePos={…} }`
- `SignpostCharDB` = `{ guide="…", step=123, skipped={[stepId]=true}, automation={…}, stickyDone={…} }`

## 5. Guide DSL (RestedXP-inspired, ours) — Phase 2 moves this section to `docs/GUIDE-FORMAT.md`

**The canonical specification is now `docs/GUIDE-FORMAT.md` (2026-10-17)**, with the module contracts in `docs/ENGINE.md`;
this section is the original sketch and yields to them where they differ.

Guides are plain text inside a Lua long string. One directive per line, `--` comments, blank lines ignored.

```
#guide   Horde Troll Hunter 1-60        -- metadata here mirrors the ns.Guides:Register table; the registry is the source of truth
#author  <user>
#version 2026.10
#class   HUNTER                         -- comma list or * ; used for gating defaults
#race    Troll                          -- comma list or *
#faction Horde
#professions skinning,leatherworking,firstaid,cooking,fishing   -- SUGGESTIONS for free profession slots; each character's plan is
                                                                -- detected from what it has learned, and .prof gates resolve
                                                                -- against that plan at parse time (§3.8)

#include durotar-1-6                    -- pull a shared chapter from Guides/Chapters/ (resolved before gating)
#chapter 1-6 Valley of Trials            -- "#chapter <levelRange> <name>"  (inline chapter; same syntax inside the library)
step
  .goto 1411,43.2,68.5                    -- uiMapID,x,y  (percent; optional ,radius in yards; default 10)
  .accept 4641                            -- questID; display text auto = 'Accept "<quest name>"' unless >> given
  .text  Kaltunk stands at the Den entrance. >> Accept Your Place In The World
step
  .goto 1411,42.1,68.7
  .turnin 4641
  .accept 787                             -- The Basics
  .accept 4402 >> Cutting Teeth? (if offered)
  .optional 4402                          -- step still completes if this quest is never taken
step
  .complete 787,1                         -- questID, objectiveIndex (omit index = all objectives)
step
  .train 1494                             -- spellID (Track Beasts); satisfied when IsPlayerSpell/IsSpellKnown
step
  .fp 1411,Razor Hill                     -- learn flight path at node (name as in TaxiNodeName)
  .hub razorhill                          -- this step is in town: profession tracks may insert their steps here (§3.8)
step
  .fly Orgrimmar                          -- take a flight to node name (automation may auto-select); satisfied on arrival in the node's zone
step
  .path 1411,52.0,43.5 ; 1411,47.8,41.0 ; 1413,61.9,54.9   -- waypoints (semicolon-separated, may change map); next one pinned on minimap
  .zone 1413 >> Follow the road west into the Barrens        -- satisfied when the player's map is 1413 or a child of it
step
  .boat 1413,63.9,38.6 > 1434,27.2,77.1 >> Take the boat from Ratchet to Booty Bay   -- departure dock > arrival dock
step
  .zeppelin 1454,51.2,12.6 > 1434,32.1,29.3 >> Zeppelin from Orgrimmar to Grom'gol
step
  .hs Razor Hill                          -- set hearth at inn (satisfied on CONFIRM_BINDER accept or GetBindLocation()==name)
step
  .home                                   -- use hearthstone (satisfied when zone changes to bind zone)
step
  .buy 2516,200                           -- itemID,count: Light Shot to 200 (vendor automation)
step
  .collect 2589,10                        -- itemID,count in bags
step
  .use 5070                               -- quest item button appears; satisfied when the quest objective it serves updates
step
  .tame 3100                              -- npcID: satisfied when UnitExists("pet") and pet creature matches family/npc
step
  .level 10                               -- grind/finish to level 10 here (satisfied by UnitLevel)
step
  .zone 1413                              -- satisfied when C_Map.GetBestMapForUnit("player") is in that map subtree
step
  .skill cooking 75                       -- satisfied when skill >= 75
step
  .craft 2152,5                           -- craft Light Armor Kit x5 (satisfied by item count delta or TradeSkill event)
step
  .fish 1411,55.0,70.0                    -- fishing spot pin; satisfied by .skill or count directive in same step
step
  .todo "Thotar's exact position not in Wowhead Forever yet"   -- lint marks guide incomplete; step shows text only

#skipquest 1234 >> Alliance-side variant of the hunter weapon chain; not available to Horde   -- guide-level: satisfies class-quest coverage lint
step
  .turnin 4402
  .reward 4402,2                          -- choice index (or an itemID); without this, automation picks highest vendor value
step
  .note Only if you want the Hunter's Path pet chain now; otherwise skip.   -- informational
  .link https://www.wowhead.com/forever/quest=6069                            -- copyable

#chapter 17 Wailing Caverns #dungeon      -- auto-inserted dungeon chapter; "#dungeon" enables the chapter Skip toggle
step
  .note Wailing Caverns run. Quests in log: Deviate Hides, Serpentbloom, Trouble at the Docks, Leaders of the Fang (if collected).
```
A profession track (`Guides/Professions/<key>.lua`, §3.8) uses the same step syntax; each step names its anchor in the route:
```
#track skinning                           -- merged into any guide whose character's detected plan includes skinning
step @hub orgrimmar                       -- at the first route step marked .hub orgrimmar (after this track's previous step)
  .trainprof skinning                     -- learn/raise profession at trainer; satisfied when skill line known / next rank learned
step @level 6                             -- at the first route step whose expected level is >= 6
  .sticky .skill skinning 50              -- sticky: stays alongside the route until Skinning >= 50
```
Rules the parser enforces:
- Every `step` has at least one completable directive **or** a `.note` (then it completes on manual `>` only).
- `.goto` without another directive completes on proximity (radius).
- Names in `>>` text are display overrides only. At **authoring/lint** time every ID must exist in the data pack or be marked `.todo`;
  at **runtime** the data pack is optional — unknown IDs fall back to the `>>` text or `Quest #1234`.
- Gating: `.class HUNTER,ROGUE`, `.class !HUNTER`, `.race Troll`, `.faction Horde` filter a step (or a single directive line when placed
  inline after it) at parse time against `ns.Player`; `.prof skinning` filters against the character's detected profession plan
  (learned professions + the guide's `#professions` suggestions for free slots − declined ones; never the learned skills alone —
  §3.8). `.hc` reserved for Hardcore (future).
- Profession steps belong in profession tracks, not in chapters; a chapter `.prof` gate is reserved for route steps that only make
  sense with a profession (e.g. a detour to a fishing quest giver). Every track step must find its anchor in each guide that uses it.
- Class-only directives (`.tame`, `.ammo`, …) exist only when that class module is loaded; using one in a shared chapter without a
  `.class` gate is a lint error.
- `tools/guide_lint.py` checks: unknown IDs, quests accepted but never turned in, turned in but never accepted, level
  requirements vs. expected level at that point, duplicate accept, chapter level ranges monotonic, `.todo` count, and
  **uncovered zone transitions** (consecutive steps whose target zones differ with no `.path`/`.zone`/`.fly`/`.boat`/`.zeppelin`/`.home`
  between them — §3.6). `.fly` to a node the guide hasn't taught with `.fp` is also an error.
- **Class-quest coverage**: every quest in the active class module's `classQuests` must be accepted and turned in by the guide or named in a
  `#skipquest` line with a reason; otherwise the lint fails. Profession quests from `Professions.lua` (e.g. Expert/Artisan unlock quests, if Forever has them) are checked the same way, per profession track.

## 6. Data pipeline — "thorough scan of Wowhead" (`tools/`)

**Decided 2026-10-17 (supersedes the single-source plan below where they differ):** the private pack is our own database in our
schema, merged from layers by `tools/signpost_tools/datapack.py` — the client's dumps, **QuestieDB's Forever data** (with its
maintainers' permission; facts only), the **Wowhead exporter run by the user** (Wowhead's robots.txt disallows Anthropic's agents,
so Claude Code never fetches it; the exporter fills gaps the other layers leave), and **positions learned in game**. Scope: only
what the route needs — names, positions and entity links; quest progress comes from the in-game quest log; items only where the
route touches them (CLAUDE.md "Data sources").

Addons cannot access the network, so Wowhead is scanned **offline** and compiled into Lua tables. Python 3.11+, `requests`,
`beautifulsoup4`, `lxml`. Everything cached on disk, re-fetched only when older than `--max-age` (default 7 days) or `--force`.
**Rate limit 1 request / 2 s, single thread, descriptive User-Agent with contact.** Store only IDs, names, numbers, coordinates;
never quest/NPC prose.

**Repo split (decided):**
- `Signpost` — **public GitHub repo, MIT.** Addon code, `Guides/` (IDs + coordinates, as every leveling addon ships), `tools/` (exporter
  *code*), `Data/Schema.lua`. `.gitignore` blocks `tools/cache/`, `*.generated.lua`, and any `Signpost_Data/` checkout.
- `Signpost_Data` — **private GitHub repo.** A sibling addon folder: `Signpost_Data.toc` + generated `Quests.lua`, `Npcs.lua`,
  `Objects.lua`, `Items.lua`, `Maps.lua`, `Professions.lua`, `Travel.lua`, `classes/<CLASS>.lua`, `_meta.lua`, plus `cache/` (raw
  Wowhead responses).
  The exporters are run with `--out ../Signpost_Data`. The main addon lists it under `## OptionalDeps` and degrades gracefully without it (§4).
- The public README explains: "the addon runs standalone; for full names/validation build the data pack locally with `tools/`".
- GitHub Actions in the public repo: luacheck + busted + guide lint + zip release of the public addon only.

Step 0 — **discover the Forever environment on Wowhead** (`tools/wowhead_env.py`):
- Confirm the Forever DB base path (other Forever addon authors refer to "Wowhead's WoW: Forever database (patch 1.60.1)" and a
  "Forever world map"). Candidates: `https://www.wowhead.com/forever/...`. Verify by loading `/forever/quests` and a known
  Forever-only quest ("Legging It" from Vel'rin Fang, Durotar — exists on Warcraft Wiki as Forever-exclusive).
- Find the tooltip JSON env id: Wowhead serves `https://nether.wowhead.com/tooltip/<type>/<id>?dataEnv=<N>&locale=0`; determine `<N>` for Forever
  from a page's embedded `WH.dataEnv`/`g_dataEnv`. Record in API notes.
- Check whether `?xml` endpoints exist for the Forever env (`/forever/item=2516?xml`). If not, parse HTML.

Step 1 — **zone & map tables** (`tools/wowhead_zones.py` + in-game bridge):
- From Wowhead: zone list for Forever (Kalimdor, Eastern Kingdoms, new zones) with Wowhead zone IDs and level ranges.
- From the game: `/signpost dumpmaps` writes `C_Map.GetMapChildrenInfo(946-or-root, nil, true)` (uiMapID, name, mapType, parent)
  into `SignpostDB.mapDump`; `tools/import_savedvars.py` reads the SavedVariables file and emits `Data/Maps.lua` with
  `wowheadZoneID ↔ uiMapID ↔ name`. Map names are the join key; hand-fix collisions in `tools/map_overrides.json`.

Step 2 — **quests** (`tools/wowhead_quests.py`):
- Enumerate all Forever quests from the zone/category list pages (embedded `new Listview({… data: [...]})` JSON): id, name,
  level, reqLevel, side (Horde/Alliance/both), category/zone, race/class masks, type (dungeon/elite/class/profession).
  `--faction horde|alliance|both` selects what to export (default `horde` for now; `both` when Alliance guides start). The schema stores
  `side` on every quest/NPC so one data pack can serve both factions.
- For each quest page: Quick Facts → start (NPC/object/item IDs), end, series/chain prev/next, objectives (kill npcIDs with counts,
  collect itemIDs with counts, interact objectIDs, explore), rewards (choices itemIDs, xp if shown), "closes/opens quests".
- Output `../Signpost_Data/Quests.lua`. Keep `_meta.lua` with export timestamp and patch string per table. (All "Output" lines below mean the private data pack.)

Step 3 — **NPCs / objects / items** (`tools/wowhead_entities.py`):
- For every ID referenced by quests or the guide: name, level, type; spawn coordinates from the page's `g_mapperData`
  (zone → list of `{x,y}` percent) — keep up to 3 clusters per zone (k-means lite, or the first 3 unique spots), plus
  "also found in" zones. Vendors: items sold (for `.buy`). Trainers: trainer type flags. Items: vendor source, drop source, "begins a quest".
- Output `Data/Npcs.lua`, `Data/Objects.lua`, `Data/Items.lua`.

Step 4 — **professions** (`tools/wowhead_professions.py`):
- **Every** profession — all primary and all secondary ones, because any plan must be routable (§3.8): recipe/spell IDs with skill
  ranges (orange/yellow/green/grey), reagents, trainer vs. vendor-recipe vs. drop, trainer NPC IDs and locations per faction, gathering
  nodes/skinnable creatures by zone and skill. 959 recipes are new in Forever, so do not reuse Classic tables.
- Output `Professions.lua` feeding the interleaved `.skill`/`.trainprof`/`.craft` steps, their hover details, and the guide linter's
  "is this recipe trainable at this skill" checks. No separate professions view is built from it.

Step 5 — **class** (`tools/wowhead_class.py --class HUNTER`): generic exporter for any class — spell ranks by level with spell IDs
  (for `.train class`), class trainers by zone, and **class quest chains**: every quest with the class in its class mask, grouped into chains via
  series/prev/next, with level, offering NPC (trainer or not), faction availability and a `newInForever` flag (quest ID not present in the
  Classic Era database, cross-checked against Warcraft Wiki's Forever-exclusive quest pages). This is what populates `classQuests` in §3.5 —
  including the new weapon-upgrade chains Blizzard announced, which must be routed once their IDs/levels are in the data. Hunter-specific
  extras (pet families and food, the level-10 "Hunter's Path" chain at Thotar/Razor Hill, ammo/quiver items if Forever has them) live behind
  `--class HUNTER` branches. Output `classes/HUNTER.lua`.

Step 6 — **travel** (`tools/wowhead_travel.py`): flight masters (NPC ids, zones, coords, faction), boats and zeppelins (transport
object/NPC ids, both docks/towers with coords, destination zones), innkeepers; zone adjacency derived from the Forever world map
plus `Guides/Travel/Borders.lua`. **Do not seed from Classic transport tables**: Forever changed routes (a Wetlands–Darkshore ship with a
Hillsbrad stop, an open Stormwind Harbor, new zones Riverglades/Shen'dralas/Zephras Isle/Mount Hyjal with their own connections). Every node
carries `faction` (Horde/Alliance/neutral) so the planner only routes through usable flight masters and transports; Alliance-only transports
(Deeprun Tram, Menethil/Auberdine/Stormwind Harbor ships) are exported from day one even though no guide uses them yet. Output `Travel.lua`.

Step 7 — **cross-check & gap report** (`tools/report_gaps.py`): quests with no start coords, NPCs with no position, recipes
without a trainer, zone pairs with no crossing coordinates. The in-game **Learn** module fills gaps as the user plays: NPC positions
on `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `GOSSIP_SHOW`, `TRAINER_SHOW`, `MERCHANT_SHOW` (via `UnitGUID("npc")` → npcID and the
player's position); flight-master and dock positions on `TAXIMAP_OPENED` and on boarding; **zone crossings** on `ZONE_CHANGED_NEW_AREA`
(last position in the old zone + first in the new one). `tools/import_savedvars.py --merge-learned` folds all of it into the data pack with `src="learned"`.

Other sources (note licenses): QuestieDB Forever branch — since 2026-10-17 a layer of the private pack (decided above:
`tools/questie_import.py`, facts only; GPL, so never copied into this public repo), wago.tools Forever client tables
(authoritative quest/spell/item IDs; no coordinates; cross-check only), Warcraft Wiki Forever quest pages (CC BY-SA; good for
new-quest discovery), ForeverChanges (change lists).

## 7. Route outline — Balanced Horde Troll Hunter 1–60 (skeleton; every chapter is `.todo` until Data confirms it)

Beta cap is 30: chapters to 30 get verified in beta; 31–60 are drafted from Wowhead Forever + Classic knowledge and marked `VERIFY(launch)`.

| Lvl | Chapter | Notes for the draft |
|---|---|---|
| 1–6 | Durotar: Valley of Trials | Starter quests; hunter trainer in the Den (Track Beasts at 1? — probe class revamp); pick up Skinning as soon as a trainer is reachable |
| 6–10 | Durotar: Sen'jin Village / Echo Isles | Troll-flavored chain; **Legging It** (new Forever quest) on the road north |
| 8–12 | Durotar: Razor Hill → Orgrimmar | **Level 10: The Hunter's Path** (Thotar, Razor Hill — taming rod on three beasts, turn in, unlock Tame Beast) → tame pet; Orgrimmar trip: Skinning (Thuwd), Leatherworking (Karolek), First Aid (Arnok), Cooking (Zamja), Fishing (Lumak) — Classic NPC names, **verify on Wowhead Forever**; set hearth; learn Orgrimmar FP |
| any | **Class quest chains** (from `classQuests`) | Inserted at the level each chain becomes available, usually at the trainer visit already in the route; Forever's new weapon-upgrade chains are placed as soon as the export yields their IDs and levels (until then a `.todo "class quest chain <name> — level/IDs pending"` sits at the trainer step nearest the announced level). Zephras Isle hunter trainer quests are Skyborne-only — `#skipquest` with reason |
| TBD | **New Forever zones**: Riverglades, Shen'dralas, Mount Hyjal (60), Zephras Isle (Skyborne start) | Level ranges and Horde access from the Wowhead Forever world map; inserted into the table above once known |
| 12–20 | The Barrens: Crossroads, Ratchet, Camp Taurajo | Skin everything (sticky to 75/100); Light Leather → armor kits; cooking from boar/raptor; fishing in Ratchet |
| 13 / 15 / 17 | Dungeon chapters: Ragefire Chasm (13), **Hall of Thanes (13, new)**, **Ruins of Lordaeron (15, new)**, Wailing Caverns (17) | Auto-inserted at these levels (`#dungeon`); pre-quests collected by the preceding zone steps; each chapter has a Skip toggle |
| 18–22 | Stonetalon Mountains | Sun Rock Retreat; skinning to ~125 |
| 20–25 | Ashenvale (Splintertree / Zoram'gar) + Shadowfang Keep (18) side-chapter | Hunter trainer visit at 20; LW 75–125 (medium leather begins ~Ashenvale/Hillsbrad) |
| 22–27 | Hillsbrad Foothills (Tarren Mill) + Alterac | Zeppelin to Undercity; First Aid 75+; Undercity profession trainers as alternative |
| 24 | Razorfen Kraul side-chapter | |
| 25–30 | Thousand Needles → Shimmering Flats | **end of beta-verifiable range** |
| 30–35 | Stranglethorn Vale (Grom'gol) + Arathi Highlands (Hammerfall) | Scarlet Monastery (30) side-chapter; Expert First Aid/Cooking/Fishing books (Classic: STV/Shimmering Flats/Booty Bay — verify Forever) |
| 33–37 | Desolace + Razorfen Downs (34) | Thick leather starts ~40; Artisan LW at 200 (Classic: Camp Mojache/Feralas — verify) |
| 36–40 | Dustwallow Marsh (Brackenwall) + Uldaman (35) | |
| 38–42 | Badlands + Swamp of Sorrows | |
| 42–46 | Tanaris + Feralas + Zul'Farrak (42) + Maraudon (42) | Artisan LW. At level 40 the Leatherworking track has `.todo "Choose LW specialization: Tribal / Dragonscale / Elemental"`; all LW steps before it are specialization-neutral |
| 45–50 | The Hinterlands (Revantusk), Searing Gorge, Sunken Temple (45) | Artisan Cooking/Fishing |
| 48–52 | Felwood + Azshara | |
| 50–55 | Un'Goro Crater + Burning Steppes + Blackrock Spire (53) | |
| 53–58 | Western/Eastern Plaguelands, Dire Maul (54), Stratholme (55), Scholomance (57) | Argent Dawn hubs |
| 55–60 | Winterspring + Silithus + **new Forever max-level zones (e.g. Mount Hyjal at 60)** | finish to 60; rugged leather to 300 |

**Quest selection and order (decided 2026-10-17; `tools/guide_draft.py` does the bookkeeping, the author the judgment):**
1. *Candidate pool* — every quest the guide's faction/race/class may take in the zones the route visits (race/class masks,
   side, level, prerequisites, chains, mutually exclusive alternatives, profession requirements), with giver/ender
   positions. Dropped automatically: other faction/class/race, seasonal-event and PvP quests, repeatables (unless a
   profession track wants them), quests behind professions the plan lacks.
2. *Kept* — always: the class's quest chains (lint-enforced), each visited zone's main storylines, dungeon pre-quests,
   breadcrumbs into the next zone. On value: XP and reward against cost (travel off the town loop, kill counts,
   escort/timed objectives, whether it is still green when reached); chains judged as a whole. *Dropped*: long detours for
   little XP, quests that go grey before the route reaches them, chains whose payoff lies in a zone the route skips.
3. *Group quests* — optional, offered again about 5 levels later (§2).
4. *Order* — zones by the level bands above; within a zone, town loops (pick up everything at the town, run the
   objectives in the shortest loop over their spawn areas, turn in, take the follow-ups), prerequisites as a dependency
   order; a simulated expected level (quest XP + kills) keeps level requirements met and places class-trainer visits,
   dungeon chapters and profession ranks; hearth set where the route returns; flight paths on first pass; explicit travel
   steps for every zone change (§3.6).
5. *Per race/class* — race-specific starting chapters, shared chapters from the first common town, class content from
   the class module and `.class` gates; restricted quests drop out through gating.

The profession notes in the table describe the Troll Hunter's default plan; chapters carry only `.hub` markers, and the profession
steps live in the tracks (§3.8). Track rules, the same for every profession: a `.skill` sticky target from the hub where the next
material tier starts; a `.trainprof` step at the first hub with a trainer once skill is within 25 of the cap for the current rank
(Journeyman 50/75, Expert 125/150, Artisan 200/225 — Classic thresholds, verify Forever); recipes chosen for leveling must be
trainer-available or already in bags; gathering professions get zone-band stickies, crafting professions batch crafts at hubs.

## 8. Phases, tasks, acceptance criteria

Create `docs/PROGRESS.md` with these as checkboxes in Phase 0.

### Phase 0 — Skeleton + beta probes (do first; beta closes Oct 21)
Tasks
- [ ] Bootstrap per §8a: `git init` both repos, `.gitignore`s, `.claude/settings.json` (additional directory `../Signpost_Data`), `gh repo create` for both remotes once the account is known.
- [ ] Public repo scaffold per CLAUDE.md layout; both TOCs (`## Interface: 16001`, `## IconTexture`, `## AddonCompartmentFunc`, `## SavedVariables`, `## SavedVariablesPerCharacter`, `## OptionalDeps: Signpost_Data`); `.luacheckrc`; `.editorconfig`; `stylua.toml`; `.pkgmeta` with the libs; `LICENSE` (MIT); `.gitignore` (cache, generated data, sibling pack); `.github/workflows/ci.yml` (luacheck, busted, guide lint, release zip).
- [ ] Private sibling repo `Signpost_Data`: `Signpost_Data.toc` (`## Interface: 16001`, defines global `Signpost_Data`), empty table files matching `Data/Schema.lua`, `cache/` directory, README with the export commands.
- [ ] `Core/Init.lua`, `SavedVars.lua`, `Slash.lua` with `/signpost`, `/signpost debug`.
- [ ] `Core/Probe.lua`: `/signpost probe` prints and stores (into `SignpostDB.probe`) the results of the **Open probes** list in `FOREVER-API-NOTES.md` (function existence, template existence via `pcall(CreateFrame, …)`, atlas existence via `C_Texture.GetAtlasInfo`, `select(4, GetBuildInfo())`, `WOW_PROJECT_ID`, `GetProfessions()` shape, taxi API shape, `issecretvalue` existence).
- [ ] `/signpost dumpmaps` → `SignpostDB.mapDump`; `/signpost export` → copyable EditBox with JSON of learned data; `/signpost debug on|off` event log to SavedVariables.
- [ ] Dev environment (§8b): `tools/dev.local.json` (gitignored) + `tools/dev_link.ps1`/`.sh` junctions into the beta AddOns folder; `tools/read_savedvars.py [--watch] [--from <dir>]`; `Core/Errors.lua` storing the last 50 Lua errors in SavedVariables.
- [ ] `tools/import_savedvars.py` (parse WoW SavedVariables Lua → JSON; `Maps.lua` from the map dump). Its `--merge-learned` mode
  moved to Phase 6 with `Core/Learn.lua`, its only data source (user, 2026-10-17).
Acceptance
- Addon loads on the beta with no "out of date" flag and no Lua errors; `/signpost probe` output read by `tools/read_savedvars.py` and pasted into API notes; `Maps.lua` generated from a real dump.
- Dev loop proven: edit a string in `Core/Slash.lua`, user types `/reload`, `tools/read_savedvars.py` shows the new value within seconds; a deliberately thrown error appears in `SignpostDB.errors`.

### Phase 1 — Wowhead export (1–30 first)
- [ ] `tools/wowhead_env.py` discovers base path + `dataEnv`; documented in API notes.
- [ ] `wowhead_zones.py`, `wowhead_quests.py` (Horde + neutral quests, zones ≤ 32), `wowhead_entities.py`, `wowhead_professions.py` (every profession, primary and secondary), `wowhead_class.py --class HUNTER` (spells, trainers, **all hunter class quest chains with `newInForever` flags**), `wowhead_travel.py`.
- [ ] Data pack generated into `../Signpost_Data/`; `tools/report_gaps.py` output committed to the **private** repo as `data-gaps.md`.
Acceptance
- Every Durotar/Barrens quest a Troll Hunter can take is in the pack's `Quests.lua` with start/end entity and ≥1 coordinate (or listed in gaps). Lua files load under `luac -p` and in-game; the main addon also loads cleanly with the pack disabled.

### Phase 2 — DSL, parser, engine
- [ ] Move §5 to `docs/GUIDE-FORMAT.md`; implement `Core/Player.lua`, `Engine/Directives.lua` (registry + core directives), `Engine/Registry.lua` (guides, chapters, `#include`, best-match selection), `Engine/Professions.lua` (profession registry, profession plan detection — learned professions + `#professions` suggestions for free slots − declined ones, recomputed on `SKILL_LINES_CHANGED` — parse-time `.prof` gating, `.hub`/`@level`/`@zone` anchors and track merging with stable step ids — §3.8), `Engine/Parser.lua` with line-numbered errors; `tools/guide_lint.py` (incl. track anchors); `tools/check_repo.py` seam tokens cover profession names.
- [ ] `Classes/HUNTER.lua` with `trainerSpells`, `classQuests` (from the export; the level-10 pet chain first), `.tame`/`.ammo` directives, the `.train class` expansion and the "class quest available here" soft check. No other file references HUNTER/Troll/Horde (lint rule in CI: grep outside `Classes/` and `Guides/`).
- [ ] `Engine/Context.lua` (quest log by questID, completed set via `C_QuestLog.GetAllCompletedQuestIDs` + `IsQuestFlaggedCompleted`, spells, skills, taxi, bags).
- [ ] `Engine/Conditions.lua` for every directive in §5; `Engine/Progress.lua` with auto-advance, auto-skip, sticky, manual override, persistence.
- [ ] `Engine/Travel.lua`: `.path` waypoint progression, `.zone` subtree check, transport state machine for `.boat`/`.zeppelin`/`.fly` (not boarded → in transit → arrived), in-transit detection per API-notes probe. `Guides/Travel/Borders.lua` seeded with the Durotar/Barrens, Barrens/Stonetalon, Barrens/Ashenvale, Barrens/Thousand Needles and Barrens/Dustwallow crossings (coords `.todo` until learned).
- [ ] `tools/guide_travel.py` (simulate guide, find uncovered transitions, propose DSL) and the lint rule for uncovered transitions.
- [ ] `tools/guide_draft.py` (§7 "Quest selection and order": draft chapters from the data pack for hand refinement); quest XP in
  the questie and wowhead layers; group-quest tags from the Wowhead quest type and the client's quest tag; a `.group <questID>`
  marker in GUIDE-FORMAT (implies `.optional`; the step frame shows it as a group quest).
- [ ] `tests/`: busted specs for parser (every directive, error cases) and progress (auto-skip, sticky) with `tests/wow_mock.lua`.
- [ ] `Guides/HordeTrollHunter.lua` chapters 1–12 (Durotar) fully written from Data, incl. hunter pet chain and first profession trainers.
Acceptance
- Walking a fresh beta troll hunter through Durotar with only chat output (`/signpost debug`) advances steps correctly without manual input, except at `.todo` steps.
- The Durotar → Barrens exit is written as `.path` + `.zone` steps and advances waypoint by waypoint; `guide_lint.py --strict` reports 0 uncovered transitions for chapters 1–12.

### Phase 3 — Step frame + pins
- [ ] `UI/StepFrame.lua` per §3.1; `UI/Pins.lua` with HBD; icon/atlas table verified via probe.
- [ ] Waypoint paths: next waypoint on the minimap with edge arrow; numbered waypoints on the world map with connecting lines on zone-level maps (hidden on continent views); transport steps swap from departure to arrival pin when boarded; "in transit" text in the step frame.
- [ ] Options: lock, scale, alpha, hide-in-combat, show-next-steps, waypoint radius; stored in `SignpostDB.settings`.
Acceptance
- Default screen shows exactly the step frame, minimap pin(s), world map pin(s). Pins update within 1 s of a step change. No errors when `C_Map.GetPlayerMapPosition` returns nil (instances, transports).
- Running Razor Hill → Barrens → Ratchet → boat → Booty Bay on the beta (if level/zone allow) is pinned turn by turn with no step that lacks a target.

### Phase 4 — Journal window
- [ ] `UI/Journal.lua` per §3.2 with Route, Class (built by the active class module; hidden if none), Settings tabs; portrait from `GetClassAtlas(ns.Player.classFile)`; guide dropdown driven by the registry; inline dungeon chapters with Skip checkbox; profession-step hover details; `UIPanelWindows` registration; LibDBIcon + compartment entry.
- [ ] Search; jump-to-step; 5 s highlight; dropdown for guide selection (single guide today, but structured for more).
Acceptance
- Side-by-side with Blizzard's Spellbook/Quest map, the window is indistinguishable in style (same borders, fonts, buttons, tabs, scrollbars). Esc closes it. No taint warnings when opened in combat (it must just open; nothing secure inside).

### Phase 5 — Automation
- [ ] Quest accept/turn-in/gossip logic per §3.4; reward selection (guide `.reward` → highest vendor-sell value → stop if unknown, with values drawn on reward buttons); Shift bypass; "guide quests only" mode.
- [ ] Taxi (both API shapes), trainer (spell-ID matched, gold reserve), vendor (`.buy`), hearth set/use (secure button).
- [ ] Settings tab + Options panel entries; every automation defaults off.
Acceptance
- A Durotar run with all toggles on requires clicking an NPC once per interaction and nothing else; multi-reward quests pick the highest vendor value (and stop only when item data isn't loaded); holding Shift disables everything.

### Phase 6 — Content 12–30 + professions + dungeons (verify in beta while it lasts; afterwards on launch)
- [ ] Barrens → Thousand Needles chapters; `#dungeon` chapters auto-inserted at level (RFC, Hall of Thanes, Ruins of Lordaeron, WC, SFK, RFK, SM) with their pre-quests placed in the preceding zone steps.
- [ ] Profession modules and tracks for the Troll Hunter's default plan (Skinning, Leatherworking, First Aid, Cooking, Fishing) to skill
  150 (§7 track rules), chapters marked with `.hub`; the detected plan and declined professions in the Settings tab; Hunter Class tab.
- [ ] Run the §3.8 profession seam test (the guide with a stub Herbalism + Alchemy plan), then delete the stubs.
- [ ] Move every zone/dungeon chapter from Razor Hill onward into `Guides/Chapters/` and `#include` them; only the troll starting chapters stay guide-specific.
- [ ] Run the §3.5 seam acceptance test (stub Orc Warrior guide + empty `Classes/WARRIOR.lua`), then delete the stub.
- [ ] Travel steps for every zone change ≤ 30 generated with `guide_travel.py`, reviewed, and pasted into the chapters (Barrens ↔ Stonetalon/Ashenvale/Thousand Needles/Dustwallow, Orgrimmar zeppelins to Undercity and Grom'gol, Ratchet ↔ Booty Bay, Thunder Bluff/Undercity elevators as `.path` waypoints with text).
- [ ] `Core/Learn.lua` self-healing positions incl. zone crossings and docks; `--merge-learned` import; gap report shrinking each session.
Acceptance
- `guide_lint.py --strict` reports 0 unknown IDs, 0 uncovered transitions and 0 unrouted class quests (every hunter chain ≤ 30 is routed or `#skipquest`-ed with a reason) for chapters ≤ 30, and lists `.todo`s with reasons; the user plays 1–30 with < 5 manual corrections per 10 levels and is never left without a pin when changing zones.
- The seam test passes with zero edits outside `Classes/` and `Guides/`; the profession seam test passes with zero edits outside
  `Professions/` and `Guides/Professions/`.

### Phase 7 — Content 31–60 (drafted now, verified from Nov 4)
- [ ] Chapters per §7, each step tagged `VERIFY(launch)` until a learned position or completed quest confirms it; travel steps for every transition (STV/Arathi/Desolace/Dustwallow/Tanaris/Feralas/Hinterlands/Searing Gorge/Felwood/Un'Goro/Plaguelands/Winterspring/Silithus + new Forever zones) generated with `guide_travel.py`, border coords `.todo` until learned.
- [ ] Route every hunter class chain 31–60 from the export (Classic-era ones such as the level-50 Petrified Leaf / Ancient Petrified Leaf lines if Forever keeps them, plus the new weapon-upgrade chains); coverage lint must pass for the full guide at launch.
- [ ] "Report this step" button → appends `{guide, step, questID, pos, note}` to `SignpostDB.reports`; `/signpost export` includes it.
- [ ] Re-run the Wowhead export weekly during the launch month (`--max-age 7`) and diff `Data/` (`tools/diff_data.py`) to catch Wowhead corrections.

### Phase 8 — Polish / packaging
- [ ] Performance pass (no OnUpdate except `.goto` distance; measure with `/signpost perf`); memory < 10 MB with all Data loaded (else split Data by zone and load lazily — `## LoadOnDemand` sub-addons per continent).
- [ ] Optional "Back to route" nudge (§3.6): in-game shortest path over the travel graph when the player is 2+ zones off the current step.
- [ ] Optional `tools/package_lite.py --guide <id>` (§3.7) for single-guide zips; only if the user asks.
- [ ] Localization table complete; README with screenshots, install steps, and "build your own data pack" instructions; tagged GitHub releases built by CI (public addon zip only).
- [ ] **CurseForge release (Release 1, user 2026-10-20).** The user creates the CurseForge project and an API token (stored as the
  `CF_API_KEY` repository secret; Claude Code never sees it); Claude Code adds `## X-Curse-Project-ID` to both TOCs, finishes `.pkgmeta`,
  and extends CI to build and upload the zip on a version tag with the BigWigs packager. First check that CurseForge offers a game
  version for WoW: Forever (Interface 16001); if it does not, release on GitHub first. The zip carries no Wowhead- or QuestieDB-derived
  tables (the existing CI guard), only the guides, which carry their own IDs and coordinates (the user covers them under QuestieDB's permission, 2026-10-20: PLAN §12).
- [ ] **Release 1 scope gate:** Troll Hunter (all professions), Tauren Druid and Windshaper Druid hardcore guides each pass
  `guide_lint --strict` for the levels they claim; the addon loads cleanly with the data pack absent; README with install steps.

### Phase 9 — Route simulator (proposed by the user, 2026-10-20; discussed, not started)

A per-guide simulation to estimate how good a route is and to compare variants, with assumptions that can be relaxed and tuned. What exists
already: `tools/guide_travel.py --simulate` (zone, flight paths, hearth, a travel clock from walking speed, flight cost, boat waits and
hearthstone cooldown) and `guide_draft.py`'s placeholder level estimate (one level per N quests). Stages:
1. **Deterministic simulator** (`tools/guide_sim.py`): walks a route as the drafter does, adding a per-objective time model (kill, loot, collect,
   escort time from spawn density and distance) and XP per quest and per kill, with the level thresholds, so level gates are met by a real estimate
   (this replaces the placeholder pacing in the drafter and gives the lint's `quest-level` warning real numbers). Output: time to each level,
   time per chapter, travel share, backtracking, over- and under-levelled quests.
2. **XP data layer**: quest XP and the XP-to-level table. QuestieDB carries Classic's (`support/Forever/QuestXP`, a Classic seed, not Forever's);
   Wowhead's class quest listing has an `xp` field but its Forever pages are blocked to us. Forever's tuning is unknown: mark it as an assumption.
3. **Light, passive calibration (optional)**: not per-quest timing (that would need many sessions; the user and one friend are the only players).
   The game already tracks time played: `Core/Learn.lua` would record `/played` (TIME_PLAYED_MSG) at each level-up, a few numbers per level and no
   effort from the player, and the importer fits ONE overall pace multiplier from it. Time per quest stays a model: a kill-and-loot time per
   objective, walking between the spawn points the pack already has (so the walking is computed), a factor for the quest's level against the
   character's, and constants for turn-ins, escorts and interactions, all named parameters in one file.
4. **What-if, sensitivity and risk**: one parameters file (speeds, kill rates, XP multipliers, rested XP) with a sensitivity report; variants
   (skip a quest, reorder hubs, add a dungeon) ranked by time; a hardcore risk score (dangerous quests, exposure above the character's level).
Caveats: the output compares routes, it does not predict a player's clock: a ranking that holds across the plausible range of every
parameter is trusted, and the sensitivity report names the cases where it flips. Forever's XP and kill rates are assumptions until measured. Suggested order: stages
1 and 2 before drafting levels 20-60 (they fix the ordering the weak estimate gets wrong), stages 3 and 4 after the first release.

## 8a. Bootstrapping — directories, repos, where Claude Code runs

**Local layout** (dev machine, Windows; repositories directory `C:\Users\StephandeVilliers\Repos`):
```
C:\Users\StephandeVilliers\Repos\
  Signpost/        public repo  — CLAUDE.md, docs/PLAN.md, docs/FOREVER-API-NOTES.md already here before the first session
  Signpost_Data/   private repo — starts empty except its own short CLAUDE.md
```
The two are siblings; every `../Signpost_Data` path in this plan depends on that.

**Starting a session**: always from the public repo, with the data repo added as a working directory:
```
cd C:\Users\StephandeVilliers\Repos\Signpost
claude --add-dir ../Signpost_Data
```
Claude Code loads `CLAUDE.md` from the working directory (and discovers subdirectory CLAUDE.md files); CLAUDE.md files inside `--add-dir`
directories are *not* loaded by default, so all rules that matter live in `Signpost/CLAUDE.md`. Phase 0 commits `.claude/settings.json` with
`Signpost_Data` listed under `permissions.additionalDirectories` so the flag becomes unnecessary (verify the exact key in the Claude Code
IAM docs, "Working directories").

**Git workflow** (solo developer):
- Both repos: `main` only; one commit per task (`phaseN: <what>`); a tag at the end of each phase (`phase0-done`, …). Feature branches only for risky refactors.
- `Signpost` `.gitignore`: `tools/cache/`, `tools/dev.local.json`, `incoming/`, `*.generated.lua`, `.luacheckcache`, `__pycache__/`, `.venv/`, `.claude/settings.local.json`.
- `Signpost_Data` `.gitignore`: `cache/` (gigabytes, reproducible — stays local; optional periodic zip backup), `__pycache__/`. Commit only generated Lua + `data-gaps.md`, one commit per export, dated.
- GitHub remotes: the user installs `gh` and runs `gh auth login` once; Claude Code then runs `gh repo create hsdevilliers/Signpost --public --source . --push`
  and `gh repo create hsdevilliers/Signpost_Data --private --source . --push` (github.com/hsdevilliers). MIT `LICENSE` in the public repo only.
- Dev machine: repos stay under `C:\Users\StephandeVilliers\Repos` and are junction-linked into the AddOns folder (§8b). Play machine: `git clone` both repos directly into
  `…\Interface\AddOns\` as `Signpost` and `Signpost_Data`; update with `git pull`. Never edit files on the play machine.

## 8b. Development environment — two machines, two jobs

**Dev machine** (repos, Claude Code, Python tools, **and** the Forever client):
- Install the Forever beta here now (launch client replaces it Nov 4). Paths live in `tools/dev.local.json` (gitignored):
  `{"wowDir": "C:\\Program Files (x86)\\World of Warcraft", "flavorDir": "_classic_beta_", "account": "<WOW_ACCOUNT>"}`.
- `tools/dev_link.ps1` / `tools/dev_link.sh`: create directory junctions (Windows `mklink /J`) or symlinks (macOS) from
  `<wowDir>\<flavorDir>\Interface\AddOns\Signpost` → the public repo and `…\Signpost_Data` → the private repo. No copy step; edit → `/reload`.
  On this machine (adjust `wowDir` if the client is elsewhere; run the terminal as Administrator once if `Program Files` refuses the junction):
  ```
  mklink /J "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\Signpost"      "C:\Users\StephandeVilliers\Repos\Signpost"
  mklink /J "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\Signpost_Data" "C:\Users\StephandeVilliers\Repos\Signpost_Data"
  ```
  The script reads these from `tools/dev.local.json`; when the launch client lands on Nov 4, change `flavorDir` and re-run it.
  `<WOW_ACCOUNT>` below is the Battle.net account folder name under `WTF\Account\` (not the GitHub account).
- `tools/read_savedvars.py [--watch]`: parses `<wowDir>\<flavorDir>\WTF\Account\<WOW_ACCOUNT>\SavedVariables\Signpost.lua` (+ the per-character
  file) into JSON and prints the sections Claude Code asked for (`probe`, `mapDump`, `eventLog`, `learned`, `reports`, `errors`). This is the
  return channel from the game to Claude Code: the user types `/reload`, Claude Code reads the file. SavedVariables are only written on
  `/reload`, logout or exit — never read them mid-session.
- In-addon error capture: `Core/Errors.lua` hooks `seterrorhandler` chain (or BugGrabber if present and working on Forever) and stores the
  last 50 Lua errors with stack traces in `SignpostDB.errors`, so errors reach Claude Code through the same file.
- Human-side helpers the user runs in-game: `/signpost probe`, `/signpost dumpmaps`, `/signpost debug on` (event log to SavedVariables),
  `/dump`, `/api`, `/fstack`, `/etrace`. The reload keystroke cannot be automated from outside the client; everything else can.

**Play machine** (long sessions, data gathering):
- Gets the addon via `git pull` of both repos (or Syncthing of the two AddOns folders, send-only from dev).
- Sends data back **one-way**: Syncthing (send-only) or a logout script copies `WTF\Account\<WOW_ACCOUNT>\SavedVariables\Signpost*.lua` into
  `<dev>\incoming\play-machine\`. Never two-way: both machines write the same account's file names. `tools/read_savedvars.py --from incoming/play-machine`
  reads that copy; `tools/import_savedvars.py --merge-learned` folds learned positions/crossings into the data pack.
- Same Battle.net account cannot be in-game on both machines at once; the split is code-testing time vs play time, not parallel use.

**Why both**: the dev machine makes the edit/reload/read loop seconds long and lets probes be answered interactively; the play machine
produces the long real-route sessions (Learn data, step reports) without interrupting development.

## 9. Beta burn-down — must happen before Oct 21, 2026 (today is Oct 17)
1. Phase 0 entirely (probe results are the single most valuable thing to capture before the client goes away).
2. `/signpost dumpmaps` for every zone the test character can reach; also `C_TaxiMap.GetAllTaxiNodes` dumps at each flight master visited.
3. Capture one of each UI event payload (`QUEST_DETAIL`, `GOSSIP_SHOW` options table, `TRAINER_SHOW` service list, `MERCHANT_SHOW` item list, `TAXIMAP_OPENED`) via `/signpost debug` logging to SavedVariables.
4. Ride one boat or zeppelin (Orgrimmar → Undercity zeppelin is reachable at any level) with `/signpost debug` logging `ZONE_CHANGED*`, `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition`, `UnitOnTaxi`, `IsInInstance` and `UnitPosition` every second, so transport detection can be designed from real data. Also log one flight.
5. Confirm: does Forever have ammo/quivers? Does `GetProfessions()` include First Aid, or is there a `GetSkillLineInfo`-style API? Which atlases/templates exist? Is `UIDropDownMenuTemplate` present? Does `UnitXP` return a secret value?
6. Walk 1–12 on a troll hunter recording learned positions and the Durotar→Barrens crossing even before the engine exists (Learn module can be pulled forward).
If the beta closes before Phase 2 is done, keep building against the captured probe data and the `tests/wow_mock.lua` harness.

## 10. Testing strategy
- Unit: `busted` for `Engine/Parser.lua`, `Engine/Conditions.lua`, `Engine/Progress.lua` against `tests/wow_mock.lua` (C_QuestLog, C_Map, UnitLevel, IsPlayerSpell, bags, taxi stubs with scriptable state). Run in CI on every commit.
- Static: `luacheck` (WoW globals std + our globals list), `luac -p` on generated Data, `tools/guide_lint.py` on every guide.
- In-game: `/signpost selftest` runs a scripted sequence (fake events through `ns.Events:Fire`) and asserts step movement; `/signpost probe` compares against API notes and flags drift after client patches.
- Manual beta/launch checklist in `docs/PROGRESS.md` per chapter.

## 11. Risks and mitigations
- **API drift during beta/launch** (Forever is 1.60.x on a 12.x codebase): isolate every Blizzard call behind `ns.API.*` wrappers so a rename is one edit; probe on login and warn once in chat if a required function is missing.
- **Wowhead Forever DB incomplete**: `.todo` steps, Learn module, weekly re-export, gap report. Never guess coordinates.
- **Secret values**: never read health/power; kill progress only from quest objective text/counts.
- **Taint**: quest-item/hearth via secure buttons set out of combat; Journal has no secure children; never call `ShowUIPanel` from a secure handler.
- **Zone/map ID mismatch** between Wowhead zones and `uiMapID`s on Forever's modified world: name-join + `map_overrides.json` + in-game dump as truth.
- **Scope creep**: gear optimization, talent builds and the Legacy system are explicitly out; Hardcore is a future gate (`.hc`). If a step
  needs a talent/Legacy choice to make sense, that is a sign the step is wrong, not that the scope should grow.

## 12. Open questions for the user
Answered 2026-10-20:
1. **Races:** "Torin" = Tauren; "Skyborne" = the new Skyborne race, Horde variant "Windshaper". Both are Druid. Web guides (icy-veins,
   talentsforever, mobalytics; unverified against the client) add that Skyborne needs the Skyborne Heroic Pack and starts on Zephras Isle
   (levels 1-12). The client's race list is the authority; the user checks it in game.
2. **Hardcore timing:** the user confirms hardcore exists **from launch day** (one web source said it comes after launch; the user's
   word wins). The friend starts his druid on launch day.
3. **Licensing:** the user considers QuestieDB's permission to cover quest IDs and coordinates in the public guides. The original wording
   (Questie Discord, 2026-10-17, as relayed) was "an input to the private pack only"; this is the user's reading of it. Only IDs and
   coordinates may ship: never its code, file formats, text, corrections or tables (CLAUDE.md "Data sources").
   **Horde races in Forever** (web guides agree: Icy Veins, Warcraft Tavern, gamer-guides, lfcarry; the client's character-creation list is
   the authority): Orc, Undead, Tauren, Troll and the Windshaper Skyborne. Druid is open to Tauren and Windshaper Skyborne only (Troll
   Hunter is in; Troll Warlock, Orc Mage and Undead Paladin are among Forever's new combinations).
4. **Data hand-over (user, 2026-10-20):** the friend shares his SavedVariables through a **shared folder**. So the helper script that
   copies a clean `Signpost.lua` into the shared folder is the main path (no size limit); the in-game export block is the fallback.
5. **CurseForge:** under the user's account; the user creates the project and the API token. Claude Code prepares the TOCs, `.pkgmeta` and
   CI, and checks whether CurseForge lists a WoW: Forever game version before the first upload (else GitHub first).

Open: none. New questions go below. Repos live under `C:\Users\StephandeVilliers\Repos`; remotes go under `github.com/hsdevilliers` (Claude Code creates them with
`gh` after the user has run `gh auth login`). New questions go here as they arise; Claude Code stops and asks rather than guessing.

Resolved: the addon name is **Signpost** (2026-10-17; web search found no WoW addon of that name — re-check CurseForge/Wago/WoWInterface
by name in Phase 0). All earlier assumptions were resolved on 2026-10-16/17 and are recorded as decisions in §2.

## 13. Suggested first prompt for Claude Code
Run from `C:\Users\StephandeVilliers\Repos\Signpost` as `claude --add-dir ../Signpost_Data`, after `gh auth login` has been done once:
> Read CLAUDE.md, docs/PLAN.md and docs/FOREVER-API-NOTES.md. Start Phase 0: bootstrap per PLAN §8a (git init both repos, .gitignores,
> .claude/settings.json, then `gh repo create` under hsdevilliers — Signpost public, Signpost_Data private), scaffold the public repo exactly as
> laid out, write both TOC files, Core/Init, SavedVars, Slash, Errors and Probe, the `/signpost probe`, `/signpost dumpmaps`, `/signpost export`
> commands, the dev-link script and `tools/read_savedvars.py`, the CI workflow, and the sibling `../Signpost_Data` stub addon. Create
> docs/PROGRESS.md from PLAN §8. Stop when both addons load in the beta with no errors and tell me exactly what to type in-game so you can
> read the probe output back with tools/read_savedvars.py.
