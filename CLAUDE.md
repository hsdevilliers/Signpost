# Signpost — Claude Code project instructions

> Name is final (chosen 2026-10-17): addon folder `Signpost`, TOCs `Signpost.toc` + `Signpost_Camelot.toc`, data pack `Signpost_Data`,
> SavedVariables `SignpostDB` / `SignpostCharDB`, slash commands `/signpost` and alias `/sign`, GitHub repos `Signpost` (public) and `Signpost_Data` (private).

## What this is
A World of Warcraft: **Forever** addon: a RestedXP-style leveling-guide **engine** whose first (and for now only) guide is a
**Horde Troll Hunter** route with **Skinning + Leatherworking** and all secondary professions (**First Aid, Cooking, Fishing**), levels 1–60.
The engine, UI, DSL and data layer are class/race/faction-agnostic so other classes and races can be added later as guide files plus a class module,
and profession-agnostic: those five professions are only that guide's default plan — any race + class guide works with any combination of
primary and secondary professions, each profession being a module plus a route track (PLAN §3.8).
Full plan: `docs/PLAN.md`. Client/API discoveries: `docs/FOREVER-API-NOTES.md`. Progress log: `docs/PROGRESS.md`.

## The user and the release target (user, 2026-10-20)
- **The user dictates their messages**, so names and terms can be mis-transcribed (e.g. "Torin" for Tauren, "dirator" for Durotar).
  When a name does not match anything in the docs or the data, say what you think it is and ask; do not build on a guess.
- **Release 1 is a CurseForge download** (public addon zip only; the data pack stays private). Minimum scope: Horde Troll Hunter with all
  professions, Tauren Druid and Horde Skyborne ("Windshaper") Druid, each as a **hardcore** route (PLAN §2, "Release 1").
- **There is no deadline tied to the beta or to launch day.** Do not push the user to do things "before the beta closes"; development
  continues after launch. The user can only play in short sessions: keep in-game requests short and say what each one is for.
- **A friend will play a druid on hardcore and run the addon in the background for data collection.** The recorder must be safe to
  hand to someone else (no player names, no chat) and the import path must take his SavedVariables.

Read `docs/PLAN.md` before doing anything. Work phase by phase; do not start a later phase until the current
phase's acceptance criteria are checked off in `docs/PROGRESS.md`. Exception (user, 2026-10-17): Phases 1–3 are built in
parallel tracks against the contracts in `docs/ENGINE.md` and `docs/GUIDE-FORMAT.md`; acceptance boxes are still ticked
in order and only with evidence.

## Hard facts about the target client (do not "correct" these from memory)
- WoW: Forever runs the **modern Mainline (retail-style) addon API**, not the Classic Era API. Interface `16001`.
  Beta install path: `World of Warcraft\_classic_beta_\Interface\AddOns\`. Launch path unknown until Nov 4, 2026.
- Removed/changed vs. what you may remember from Classic: `GetSpellInfo` → `C_Spell.GetSpellInfo`,
  `GetItemInfo` → `C_Item.GetItemInfo`, `GetItemCount` → `C_Item.GetItemCount`. Quest log is the retail-style
  `QuestMapFrame` embedded in the world map. **Combat log (`CombatLogGetCurrentEventInfo`) is unavailable to addons.**
  Some unit values (health, maybe power) are **secret values**: never do arithmetic/comparisons on them.
- Beta level cap is 30; beta closes **Oct 21, 2026**. Launch is **Nov 4, 2026**. Anything about 31–60 is unverified until launch.
- When the code and an API note disagree with what you remember, the API note wins. When nothing is written down, **probe in-game**
  (see `/signpost probe` in PLAN Phase 0) and write the result into `docs/FOREVER-API-NOTES.md` before relying on it.

## Repository layout (two repos, side by side in the AddOns folder)
```
Signpost/                 PUBLIC repo, MIT
  Signpost.toc            ## Interface: 16001 (generic); ## OptionalDeps: Signpost_Data
  Signpost_Camelot.toc    Forever-flavor TOC (same content)  — keep both in sync
  Core/        init, events, saved vars, util, slash, debug/probe, Learn (position recorder)
  Engine/      directive registry, guide/chapter registry (#include, best-match selection), DSL parser, conditions, progression,
               Travel (waypoint paths, transport state machine, travel-graph routing)
  Classes/     one module per class (HUNTER.lua first): trainer spells by level, class-only directives, Class tab builder, hooks
  Professions/ one module per profession: skill line, primary/secondary, gathering/crafting, rank caps, profession-only directives
  Data/        Schema.lua ONLY: empty tables + field docs; ns.DB = Signpost_Data or ns.EmptyDB
  Guides/      guide files (metadata + #include list + race-specific chapters), Chapters/ (shared zone/dungeon chapter library),
               Professions/ (one route track per profession, inserted into any guide at .hub anchors),
               Travel/Borders.lua (hand-authored zone crossings, overridden by learned ones)
  UI/          StepFrame (overlay), Journal (big window), Pins (map/minimap), Options
  Automation/  quest accept/turn-in, gossip, taxi, trainer, vendor, hearth
  Libs/        LibStub, CallbackHandler-1.0, HereBeDragons-2.0, LibDataBroker-1.1, LibDBIcon-1.0
  Media/       textures/fonts we own (no copied Blizzard art files; reference Blizzard paths instead)
  tools/       Python: Wowhead export (code only), map-ID bridge, SavedVariables import/merge, guide lint, data diff
  tests/       busted specs for parser/engine with a mocked WoW API (tests/wow_mock.lua)
  docs/        PLAN.md, FOREVER-API-NOTES.md, PROGRESS.md, GUIDE-FORMAT.md
  .github/     CI: luacheck, busted, guide lint, release zip (public addon only)

Signpost_Data/            PRIVATE repo — never pushed anywhere public
  Signpost_Data.toc       ## Interface: 16001; defines global table Signpost_Data
  _meta.lua Quests.lua Npcs.lua Objects.lua Items.lua Maps.lua Professions.lua Travel.lua classes/<CLASS>.lua   (GENERATED; never hand-edit)
  cache/                       raw Wowhead responses
  data-gaps.md
```
The public addon **must run without the data pack** (guides carry their own IDs and coordinates); the pack only adds names,
positions, entity links (who starts/ends a quest, chains, where things are), quest XP (for route planning), validation and learned
positions. It holds only what the
route needs: quest progress and objectives come from the in-game quest log, and items appear only when the route touches them (quest
starters, objective items with their drop sources, things a step buys or collects, profession materials) — names and sources, never
stats or prices.

**Data sources (user, 2026-10-17):** the private pack is our own database, built in layers (`Signpost_Data/layers/`, merged by
`tools/signpost_tools/datapack.py`): the client's own dumps, QuestieDB's Forever data, the Wowhead exporter, and positions learned in
game.
- **QuestieDB**: used with its maintainers' permission (Questie Discord, 2026-10-17) as an input to the private pack only. Read its files
  as data (never execute them), keep only the facts above in our schema, never copy its code, formats, corrections or text, never put
  its tables in the public repo. User decision (2026-10-20): the permission is taken to cover the quest IDs and coordinates that public
  guides carry (the guides are the product); nothing else of it may be public. The data pack itself stays private.
- **Wowhead is off-limits to Claude Code**: Wowhead's robots.txt disallows Anthropic's agents. Never fetch wowhead.com or
  nether.wowhead.com, never run `tools/wowhead_*.py` against the network, never read cached Wowhead pages. The user runs those tools;
  work from their structure-only diagnostics.

## Coding rules
- Lua 5.1 as shipped by WoW: no `goto`, no `//`, no integer division, bit ops via `bit.*`. Use `string.format` not `%q` tricks.
- One addon namespace: `local ADDON_NAME, ns = ...` at the top of every Lua file. No new globals except the
  SavedVariables tables `SignpostDB` / `SignpostCharDB` and the frame names Blizzard needs (`SignpostJournal`, etc.).
- Every event handler is wrapped so a Lua error in one module never kills the step engine: use `ns.SafeCall(fn, ...)` (xpcall + `geterrorhandler()`).
- Never call protected/secure functions from insecure code in combat. Taint-sensitive work (quest item use, hearthstone) goes
  through a `SecureActionButtonTemplate` whose attributes are only set out of combat (`PLAYER_REGEN_ENABLED` queue).
- UI must look stock-Blizzard: use Blizzard templates (`ButtonFrameTemplate`, `UIPanelButtonTemplate`, `InsetFrameTemplate3`,
  `PanelTabButtonTemplate`, `SearchBoxTemplate`, `MinimalScrollBar`, `WowStyle1DropdownTemplate`) and Blizzard fonts/textures by path.
  No Ace3 GUI. No custom skins. If a template does not exist on Forever, record it in the API notes and pick the nearest Blizzard template.
- Generated data stores IDs, names, numbers and coordinates only. **Never copy quest/NPC description text from Wowhead.**
  **Nothing Wowhead-derived (cache, generated tables, gap reports) is ever committed to the public repo**; `.gitignore` enforces it and CI fails if `tools/cache/` or `*.generated.lua` appear.
- **Class/race/faction/profession seam:** the strings `HUNTER`, `Troll`, `Horde` (and any class/race/faction token or profession
  name/key, e.g. `Skinning`, `leatherworking`) may appear only in `Classes/`, `Professions/`, `Guides/`, tests and docs. Everything else
  reads `ns.Player.*` and the detected profession plan. Class-specific behavior goes into the class module and profession-specific
  behavior into the profession module and its track, via the registries (`ns.Classes:Register`, `ns.Professions:Register`,
  `ns.Directives:Register`, `ns.Guides:Register`, `ns.Chapters:Register`). CI (`tools/check_repo.py`) greps for violations.
- **Travel is explicit:** a guide never changes zone between two steps without travel steps in between (`.path` waypoints to the
  border, `.zone`, `.fly`, `.boat`, `.zeppelin`, `.home`), each with its own pin. `guide_lint.py --strict` must report 0 uncovered
  transitions before a chapter is considered done; use `tools/guide_travel.py` to generate the steps, never hand-wave "go to X".
- Decided product behaviors (do not re-litigate): professions appear **only** as interleaved route steps (no Professions tab);
  dungeon chapters are **auto-inserted** at their level with a Skip toggle; multi-reward quests default to **highest vendor-sell value**
  when the guide has no `.reward`; Leatherworking specialization is a `.todo` step at level 40 (in the Leatherworking track);
  group (elite) quests are optional and, when skipped, offered again about 5 levels later (PLAN §2, §7 "Quest selection and order").
- **Out of scope, never add:** talent builds or talent-point reminders, Legacy-system (account-wide perk) picks or reminders, gear/BiS advice.
- **One addon, many guides, both factions:** new characters (Orc Warlock and Tauren Shaman are planned; Alliance guides later) are added as
  `Guides/<Name>.lua` + `Classes/<CLASS>.lua` in this addon. Never propose a separate addon, a core/guide split, or a cross-addon API for them.
  Nothing outside `Guides/` may assume Horde: every data record and travel node carries a faction field, and exporters take `--faction`.
- **Any profession plan for any guide, detected per character:** each character's plan (0–2 primary professions + any secondaries) is
  detected from the professions it has learned; the guide's `#professions` header only suggests professions for free slots, and skipping
  a profession's learn step declines it. There is no picker. `.prof` gates resolve at parse time against that detected plan — never
  against the learned skills alone, which would drop every "learn this profession" step on a new character.
  Profession steps come from per-profession tracks (`Guides/Professions/`) inserted at `.hub` anchors, so adding a profession never edits
  chapters or engine code. Exporters cover every profession, not only the default plan's.
- **Class quests are mandatory content:** every class quest chain for the character's class (Classic-era and Forever's new ones, e.g. the
  weapon-upgrade chains) must be routed or explicitly `#skipquest`-ed with a reason; the lint enforces it against `Classes/<CLASS>.lua:classQuests`.
- Coordinates are stored as `uiMapID, x, y` with x/y in 0–100 percent of that map. Convert to yards with HereBeDragons when needed.
- All user-facing strings go through `ns.L[...]` (enUS table) so localization is possible later.
- Default every automation feature to **off** except: auto-advance steps, pins, step frame. Holding **Shift** while
  talking to an NPC bypasses all automation (ForeverAutoQuest convention).
- Run `luacheck .` (config in `.luacheckrc`, WoW globals std) and `busted` before declaring a task done. Format with `stylua`.

## Working with the game client (dev machine)
- The Forever client is installed on this machine; paths are in `tools/dev.local.json` (gitignored — never commit it, never hardcode paths).
- The repos are junction-linked into the AddOns folder by `tools/dev_link.*`; do not copy files into the game directory.
- The only way data comes back from the game is SavedVariables, written on `/reload`/logout. Ask the user to `/reload` (and run the slash
  command you need), then read with `tools/read_savedvars.py`. Never claim to have observed in-game behavior you did not read from that file.
- Data from the play machine arrives one-way in `incoming/play-machine/`; read it with `tools/read_savedvars.py --from incoming/play-machine`.
- Never write into `WTF/`, never edit the game's own files, never automate the client (no key injection, no process control).

## Workflow rules
- Commit at the end of every task with a message `phaseN: <what>`. Update `docs/PROGRESS.md` (checkbox list mirrored from PLAN) in the same commit.
- Anything that must be verified in the live client gets a `-- VERIFY(beta): ...` or `-- VERIFY(launch): ...` comment and an
  entry in `docs/FOREVER-API-NOTES.md` under "Open probes". Clear them only with evidence (paste the `/signpost probe` output).
- Do not invent quest IDs, NPC IDs, spell IDs or coordinates. They come from `tools/` output or from an in-game dump. If data is
  missing, write the step with `.todo "reason"` so the guide lints as incomplete rather than wrong.
- Keep `tools/` idempotent and cached; never hammer Wowhead (see PLAN §6 for rate limits and constraints). Exporters always write to
  `../Signpost_Data` (flag `--out`); commit generated output in that private repo with the export date in the message.
- Ask the user (stop and report) before: changing the guide DSL in a breaking way, adding a library, or changing default automation behavior.
