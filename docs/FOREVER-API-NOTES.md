# WoW: Forever — client & API notes (living document)

Rule: three sections. **Verified** = seen in the live client or in a dated community report (cite). **Mapping** = what to use instead of
Classic-era APIs; assume true for Mainline, confirm on first use. **Open probes** = must be checked in-game with `/signpost probe` before
code depends on it; move the result to Verified with the build number.

Builds: community reports mention beta `1.60.1.70338` (Oct 2026). Installed on the dev machine 2026-10-17: **`1.60.1.70450`**
(`World of Warcraft\.build.info`; product `wow_classic_beta`, flavor folder `_classic_beta_`, executable `WowB.exe`).
Launch Nov 4, 2026. Beta ends Oct 21, 2026, level cap 30.

**How to answer the open probes:** in game, `/signpost probe` and `/signpost dumpmaps`, then `/reload`; on the dev machine,
`python tools/read_savedvars.py probe` (or `mapDump`, `errors`). Event payloads (gossip, quest dialogs, trainer, vendor, taxi,
transports) come from the event recorder — on by itself in dev builds, otherwise `/signpost debug on` — plus `/signpost debug pos`
for 1 s position samples, read with `read_savedvars.py eventLog posLog`.
Raw probe output per build is kept in `docs/probes/<build>.json` (no account, realm or character names).

## Verified in the client: beta 1.60.1.70450 (2026-10-17, `/signpost probe` — `docs/probes/1.60.1.70450.json`)

Client, TOC, addon loading
- `GetBuildInfo()` → `"1.60.1", "70450", "Oct 15 2026", 16001` (plus two more returns, `""` and `" "`).
- `WOW_PROJECT_ID` = **18** = `WOW_PROJECT_CAMELOT`; `WOW_PROJECT_MAINLINE` = 1, `WOW_PROJECT_CLASSIC` = 2. Forever runs the Mainline
  API but is **its own project**: never branch on `WOW_PROJECT_MAINLINE` (prefer feature detection).
- `GetExpansionLevel()` = 0; `GetMaxLevelForPlayerExpansion()` = 60; locale `enUS`.
- With both `Signpost.toc` and `Signpost_Camelot.toc` present the client loads **`_Camelot`**. A plain TOC alone with
  `## Interface: 16001` loads too, not flagged out of date (Signpost_Data ships only a plain TOC). `C_AddOns.IsAddonVersionCheckEnabled()`
  is true. `X-` TOC fields are readable with `C_AddOns.GetAddOnMetadata`.
- `## OptionalDeps: Signpost_Data` loads the pack first: the global `Signpost_Data` exists when Signpost's files run.
- No load errors from LibStub, CallbackHandler-1.0, HereBeDragons 2.18, LibDataBroker-1.1 or LibDBIcon-1.0.
- `seterrorhandler` works for addons (an error raised under `xpcall(fn, geterrorhandler(), ...)` arrives with its stack), and `xpcall`
  passes extra arguments to the function.
- Junctions created before the client's first start were picked up; new addon folders still need a client restart.
- Per-character SavedVariables live in `WTF\Account\<account>\<number>\<Character>-<Realm>\SavedVariables\` — an extra numeric folder
  and a combined `Character-Realm` folder, unlike Classic Era's `<Realm>\<Character>`.
- Memory after login with probe and map dump held in SavedVariables: Signpost 1.7 MB (incl. libraries), stub data pack 5 KB.

API surface (148 of the 153 names the probe checks are present; full list in the probe file)
- Missing: `GetAddOnMetadata` (use `C_AddOns.GetAddOnMetadata`), `GetNumSkillLines`/`GetSkillLineInfo` (the Classic skill-line API),
  `GetMerchantItemInfo` (use `C_MerchantFrame.GetItemInfo`), **`ConfirmBinder`** (setting the hearth needs another route; open probe).
- Absent, as expected: `GetSpellInfo`, `GetItemInfo`, `GetItemCount`, `CombatLogGetCurrentEventInfo`.
- Present, among others: **both taxi API shapes** (`C_TaxiMap.GetAllTaxiNodes`/`GetTaxiNodesForMap` and `NumTaxiNodes`/`TaxiNodeName`/
  `TaxiNodeGetType`/`TaxiNodePosition`/`TakeTaxiNode`), `C_TooltipInfo.GetTrainerService`, `GetTrainerServiceSkillLine`,
  `C_MerchantFrame.GetItemInfo`, `C_TradeSkillUI.GetProfessionInfoBySkillLineID`, `C_SpellBook.IsSpellKnown`, `C_Map.GetMapWorldSize`/
  `GetMapRectOnMap`/`GetMapGroupID`, `C_Minimap.GetViewRadius`, `C_EncounterJournal.GetDungeonEntrancesForMap`, `C_XMLUtil.GetTemplateInfo`,
  `GetFileIDFromPath`, `C_EventUtils.IsEventValid`, `issecretvalue`/`issecrettable`/`canaccesssecrets`/`canaccessvalue`/`scrubsecretvalues`,
  `Settings.RegisterCanvasLayoutCategory`/`RegisterAddOnCategory`/`OpenToCategory`, `ScrollUtil.InitScrollBoxListWithScrollBar`,
  `CreateScrollBoxListLinearView`, `CreateDataProvider`, `MenuUtil.CreateContextMenu`, `C_Timer`, `EventRegistry`.

Templates, atlases, files, events, frames
- Templates (checked with `C_XMLUtil.GetTemplateInfo`, which exists): all 21 present — `ButtonFrameTemplate`, `PortraitFrameTemplate`,
  `BasicFrameTemplateWithInset`, `InsetFrameTemplate`, `InsetFrameTemplate3`, `PanelTabButtonTemplate`, `SearchBoxTemplate`,
  `InputBoxTemplate`, `MinimalScrollBar` (EventFrame), `WowScrollBoxList`, `ScrollFrameTemplate`, `UIPanelScrollFrameTemplate`,
  **`WowStyle1DropdownTemplate` (DropdownButton) and `UIDropDownMenuTemplate`**, `UIPanelButtonTemplate`, `UIPanelCloseButton`,
  `UICheckButtonTemplate`, `SecureActionButtonTemplate`, `BackdropTemplate`, `TooltipBackdropTemplate`, `GameTooltipTemplate`.
- Atlases present: `QuestNormal`, `QuestTurnin`, `QuestRepeatableTurnin`, `QuestDaily`, `TaxiNode_Neutral`, `TaxiNode_<faction>`,
  `FlightMaster`, `Innkeeper`, `Class`, `Profession`, `poi-door`, `poi-workorders`, `Mailbox`, `Repair`, `Food`, and
  `classicon-<CLASS>` from `GetClassAtlas`. **`Vendor` is missing** — use the file `Interface\GossipFrame\VendorGossipIcon`.
- Files present (`GetFileIDFromPath`): the `Interface\GossipFrame\*GossipIcon`/`*QuestIcon` textures, `QuestBG`, `UI-QuestTitleHighlight`,
  `UI-HorizontalBreak`, `UI-DialogBox-Border`, `Interface\Minimap\Tracking\{Class,Profession,FlightMaster,Innkeeper,Repair,Food}`,
  `Interface\Icons\INV_Misc_Map_01` (our TOC icon).
- Events: all 48 checked register except `LEARNED_SPELL_IN_TAB` (use `LEARNED_SPELL_IN_SKILL_LINE`).
  `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` register (payloads still open).
- Frames at login: `TaxiFrame` exists; `FlightMapFrame` does not (`Blizzard_FlightMap` is load-on-demand and loadable);
  `ClassTrainerFrame` is load-on-demand (`Blizzard_TrainerUI`); `ObjectiveTrackerFrame`, `QuestMapFrame`, `WorldMapFrame`, `GossipFrame`,
  `QuestFrame`, `MerchantFrame`, `SettingsPanel`, `AddonCompartmentFrame`, `ScriptErrorsFrame` exist; `QuestWatchFrame` and
  `InterfaceOptionsFrame` do not.

Player, values, items, professions
- `UnitClass` → `HUNTER` (classID 3), `UnitClassBase` → `HUNTER`, `UnitRace` → `Troll` (raceID 8), `UnitFactionGroup` → `Horde`,
  `GetClassAtlas("HUNTER")` → `classicon-HUNTER` (exists).
- Classes: the nine Classic classes only — 1 WARRIOR, 2 PALADIN, 3 HUNTER, 4 ROGUE, 5 PRIEST, 7 SHAMAN, 8 MAGE, 9 WARLOCK, 11 DRUID.
- Races: `C_CreatureInfo.GetRaceInfo` carries the retail race table (many NPC-only entries); Forever's new race reports the
  clientFileString **`Skyborne`** (raceIDs 95 "High Order Skyborne", 96 "Windshaper Skyborne").
- Secret values: **`UnitHealth` and `UnitPower` are secret** (`issecretvalue` → true, arithmetic errors). `UnitHealthMax`, `UnitLevel`,
  `UnitXP`, `UnitXPMax` are plain numbers.
- Ammo and quivers exist: `GetInventorySlotInfo("AmmoSlot")` → slot 0 (`INVSLOT_AMMO` = 0); 2516 Light Shot (Projectile/Bullet,
  `INVTYPE_AMMO`), 2512 Rough Arrow (Projectile/Arrow), 2101 Light Quiver (Quiver, `INVTYPE_BAG`) are in the client's item data.
- Professions, enumerated without naming any (second probe): `C_TradeSkillUI.GetProfessionSkillLineID(Enum.Profession.X)` exists and
  maps the twelve Classic professions to their Classic skill lines — primaries Blacksmithing 164, Leatherworking 165, Alchemy 171,
  Herbalism 182, Mining 186, Tailoring 197, Engineering 202, Enchanting 333, Skinning 393; secondaries First Aid 129, Cooking 185,
  Fishing 356 (`GetProfessionInfoBySkillLineID` → `isPrimaryProfession`, `profession` = the enum value). Jewelcrafting, Inscription and
  Archaeology map to skill line 0: not on Forever. `GetAllProfessionTradeSkillLines()` lists the nine primaries, one child line per
  primary (2937–2948, `parentProfessionID` = the primary, `expansionName` = the profession's name) and two test lines named
  "Test Profession [DNT]" (2933, 2934) to filter out; it does not list the secondaries.
- `GetProfessions()` returns **7** values on Forever (retail: 5); all nil on a character without professions. Which value is
  First Aid is still open.

Maps and travel
- The map root is **947 Azeroth** (parentMapID 0); 946 does not exist. `C_Map.GetMapChildrenInfo(947, nil, true)` returns 57 maps:
  the Classic Era uiMapIDs unchanged (Durotar 1411, Mulgore 1412, The Barrens 1413, Kalimdor 1414, Eastern Kingdoms 1415, …,
  Orgrimmar 1454, Thunder Bluff 1456, Undercity 1458), battlegrounds 1459–1461, and the new zones **Mount Hyjal 2482** (Kalimdor),
  **Zephras Isle 2521** (directly under Azeroth), **Darkspear Islands 2524** (orphan map type 6 under Kalimdor), **Riverglades 2548**
  (Eastern Kingdoms) and **Shen'dralas 2652** (Kalimdor). No dungeon maps appear under the root. The dump lives in the private
  data pack as `Maps.lua` (world rectangles, rectangles on the parent map, flight nodes).
- Orgrimmar 1454, Thunder Bluff 1456 and Undercity 1458 are children of their continent, not of Durotar/Mulgore/Tirisfal: a
  `.zone 1411` (Durotar) check is not satisfied inside Orgrimmar.
- Position: `C_Map.GetBestMapForUnit` + `GetPlayerMapPosition` give zone percent (Valley of Trials: 43.35, 68.70 in 1411); `UnitPosition`
  gives world yards with instance 1 (Kalimdor); `GetSubZoneText()` → "Valley of Trials".
- `C_TaxiMap.GetTaxiNodesForMap(zoneMapID)` returns **every flight node of the zone's continent** (Kalimdor 38, Eastern Kingdoms 36), with
  positions projected into the requested map, `faction` (0 neutral, 1 Horde, 2 Alliance) and `atlasName` — without visiting a flight
  master. Stale nodes named `zzOLD…` are included (e.g. 3208 "zzOLDPowderfuse Port, Riverglades"): filter them. New nodes: Summit of
  Eternity (559) and Tainted Foothills (3242) in Mount Hyjal; Rog'mar (3203, Horde) and Farholde Keep (3276, Alliance) in Riverglades.
- `C_EncounterJournal.GetDungeonEntrancesForMap` exists but returns nothing for any zone or continent: dungeon entrances must come from
  Wowhead or Learn.
- HereBeDragons 2.18 (minor 35, Pins 17) detects Forever and `HBD:GetPlayerZonePosition()` matches `C_Map` (1411, 43.35/68.70);
  Durotar is 5287.5 × 3525 yd.
- Minimap: rotation off by default; `C_Minimap.GetViewRadius()` = 233.3 yd at zoom 0; 6 zoom levels.
- Slash commands: nothing else claims `/sign` or `/signpost`.

## Verified (from community reports, Sep–Oct 2026)
- TOC `## Interface: 16001` is the Forever beta value. **Confirmed in the client** (above); also listed by HereBeDragons 2.18,
  LibDBIcon v12.1.1 and the Forever addon "Zeppelin Signs". An early report of 120007 on build 69893 is obsolete.
- Flavor-specific TOC suffix is `_Camelot` (Forever's internal codename). **Confirmed** (the client prefers it over the plain TOC).
- Beta addons folder: `World of Warcraft\_classic_beta_\Interface\AddOns\`. **Confirmed.**
- ~~Forever is in the Mainline project family: `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`~~ — **wrong**: `WOW_PROJECT_ID` is
  `WOW_PROJECT_CAMELOT` (18). The API is Mainline-shaped (retail templates and `C_*` namespaces); Classic Era addons need porting.
- Removed: `GetSpellInfo`, `GetItemInfo` (globals). Use `C_Spell.GetSpellInfo(id)` (returns a table) and `C_Item.GetItemInfo(id)`.
  **Confirmed** (plus `GetItemCount`).
- `CombatLogGetCurrentEventInfo` unavailable to addons. **Confirmed** (the function does not exist).
- "Secret values": `UnitHealth` returns values that error on arithmetic/comparison. **Confirmed**, and `UnitPower` too.
- The quest log is the world map (retail-style `QuestMapFrame`); the Blizzard quest tracker exists. **Confirmed** (frames exist).
- AddOn Compartment (`## AddonCompartmentFunc`) exists; Options → AddOns panel exists (`Settings` API). **Confirmed** (frames/API).
- Classic-style content still present: level cap 60, flight masters/taxi, Classic dungeons (modified) plus new ones
  (Hall of Thanes 13, Ruins of Lordaeron 15, Excavation Site: Wetlands 26, City of Dalaran 28, …).
- Class content: Forever adds new class-specific quests (announced reward: large weapon upgrades); most class quests are offered by class
  trainers at level thresholds; the hunter level-10 chain still uses a taming rod on three beasts then unlocks Tame Beast. Dual spec exists
  (irrelevant to us — talents are out of scope).
- Travel changes vs Classic: new ship Wetlands ↔ Darkshore with a Hillsbrad stop; Stormwind Harbor open; new zones Riverglades,
  Shen'dralas, Zephras Isle (Skyborne start), Mount Hyjal (60). **Zones confirmed** in the map tree (IDs above).
- Known Forever-specific gotcha from UnitFramesImproved: a `#` comment line **before** `## Interface:` can make the client treat the TOC as
  unparseable — keep `## Interface:` as the first line (enforced by `tools/check_repo.py`).

## Mapping: Classic-era habit → what to write on Forever (Mainline API)

| Need | Use |
|---|---|
| Quest log iteration | `C_QuestLog.GetNumQuestLogEntries()`, `C_QuestLog.GetInfo(i)` → `{questID, title, isHeader, level, …}`; `C_QuestLog.GetLogIndexForQuestID(qid)` |
| Quest completed? | `C_QuestLog.IsQuestFlaggedCompleted(qid)`; bulk `C_QuestLog.GetAllCompletedQuestIDs()` (may be empty until first `QUEST_LOG_UPDATE`) |
| Objectives | `C_QuestLog.GetQuestObjectives(qid)` → `{ {text, type, finished, numFulfilled, numRequired}, … }`; `C_QuestLog.IsComplete(qid)` |
| Quest events | `QUEST_ACCEPTED(questID)`, `QUEST_TURNED_IN(questID, xp, money)`, `QUEST_REMOVED(questID)`, `QUEST_LOG_UPDATE`, `UNIT_QUEST_LOG_CHANGED("player")`, `QUEST_WATCH_UPDATE(questID)` |
| NPC dialogs | `QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`, `GOSSIP_SHOW`, `GOSSIP_CLOSED` |
| Gossip | `C_GossipInfo.GetOptions()` (`gossipOptionID,name,icon`), `C_GossipInfo.SelectOption(id)`, `C_GossipInfo.GetAvailableQuests()`/`SelectAvailableQuest(questID)`, `GetActiveQuests()`/`SelectActiveQuest(questID)` |
| Accept/turn-in | `AcceptQuest()`, `CompleteQuest()`, `GetNumQuestChoices()`, `GetQuestItemLink("choice", i)`, `GetQuestItemInfo("choice", i)` → name, texture, quantity, quality, isUsable, `GetQuestReward(i)`, `GetQuestID()`, `IsQuestCompletable()` |
| Reward vendor value | `select(11, C_Item.GetItemInfo(link))` = sellPrice (per unit) × quantity; uncached items → `C_Item.RequestLoadItemDataByID(id)` then `ITEM_DATA_LOAD_RESULT(itemID, success)`; or `C_Item.IsItemDataCachedByID(id)` first |
| Player position | `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(uiMapID,"player")` → `:GetXY()` (nil in instances) — verified in Durotar |
| Map tree | Root **947**. `C_Map.GetMapInfo(id)`, `C_Map.GetMapChildrenInfo(947, nil, true)`, `C_Map.GetWorldPosFromMapPos`, `C_Map.GetMapRectOnMap` |
| Distance/pins | HereBeDragons-2.0 (`HBD:GetPlayerZonePosition()`, `HBD:GetZoneDistance`, `HBD:GetWorldCoordinatesFromZone`, `HBD-Pins:AddMinimapIconMap/AddWorldMapIconMap`); map lines via a `Line` texture on `WorldMapFrame:GetCanvas()` positioned with `HBD-Pins`' world-map pin frames as endpoints |
| Zone changes / transit | Events `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `PLAYER_ENTERING_WORLD(isLogin, isReload)`; `UnitOnTaxi("player")`; `C_Map.GetBestMapForUnit("player")` may be nil or a transport/continent map while on a ship — see probe; `UnitPosition("player")` (world coords; nil in instances); `GetZoneText()`/`GetSubZoneText()` as last resort for dock names |
| NPC id from unit | `UnitGUID("npc")` → `"Creature-0-…-…-…-<npcID>-…"`; field 6 of the `-`-separated GUID (`ns.Util.NpcIDFromGUID`) |
| Items in bags | `C_Item.GetItemCount(itemID)`, `C_Container.GetContainerNumSlots`, `C_Container.GetContainerItemInfo`; event `BAG_UPDATE_DELAYED` |
| Spells known | `IsPlayerSpell(spellID)` / `IsSpellKnown(spellID)` / `C_SpellBook.IsSpellKnown`; `C_Spell.GetSpellInfo(spellID).name` |
| Professions | Learned: `GetProfessions()` (7 values on Forever — meaning still open) → `GetProfessionInfo(idx)` → skill line. All professions: iterate `Enum.Profession` → `C_TradeSkillUI.GetProfessionSkillLineID(value)` (0 = not on Forever) → `C_TradeSkillUI.GetProfessionInfoBySkillLineID(id)`. The Classic `GetSkillLineInfo` API is gone. Events `SKILL_LINES_CHANGED`, `TRADE_SKILL_LIST_UPDATE` |
| Trainer | `TRAINER_SHOW`, `GetNumTrainerServices()`, `GetTrainerServiceInfo(i)`, `GetTrainerServiceSkillLine(i)`, `GetTrainerServiceItemLink(i)`, `GetTrainerServiceCost(i)`, `BuyTrainerService(i)`, `SetTrainerServiceTypeFilter("available", true)`; spell ID via `C_TooltipInfo.GetTrainerService(i)` (open probe) |
| Vendor | `MERCHANT_SHOW`, `GetMerchantNumItems()`, **`C_MerchantFrame.GetItemInfo(i)`** (`GetMerchantItemInfo` is gone), `GetMerchantItemID(i)`, `GetMerchantItemLink(i)`, `BuyMerchantItem(i, qty)` |
| Taxi | Both shapes exist: `C_TaxiMap.GetAllTaxiNodes(uiMapID)` / `GetTaxiNodesForMap(uiMapID)` and `NumTaxiNodes()`/`TaxiNodeName(i)`/`TaxiNodeGetType(i)`/`TakeTaxiNode`. Which UI opens at a flight master and which `TakeTaxiNode` argument works: open probe |
| Hearth | `GetBindLocation()`; innkeeper gossip option; `CONFIRM_BINDER` popup — **`ConfirmBinder()` does not exist** (open probe); Hearthstone item 6948 via secure button |
| Level/XP | `UnitLevel("player")`, `UnitXP("player")`, `UnitXPMax("player")` — plain numbers (verified); event `PLAYER_LEVEL_UP(level)` |
| Player identity (ns.Player only) | `UnitClass("player")` → localized, `"HUNTER"`, classID; `UnitClassBase("player")`; `UnitRace("player")` → localized, `"Troll"`, raceID; `UnitFactionGroup("player")` → `"Horde"`/`"Alliance"`; portraits via `GetClassAtlas(classFile)` (`classicon-<CLASS>`); `C_CreatureInfo.GetClassInfo`/`GetRaceInfo` for tables — verified |
| Pet | `UnitExists("pet")`, `UnitCreatureFamily("pet")`, `UnitGUID("pet")`; `PET_STABLE_UPDATE`, `UNIT_PET("player")` |
| Options panel | `Settings.RegisterCanvasLayoutCategory(frame, name)` + `Settings.RegisterAddOnCategory(cat)`; open with `Settings.OpenToCategory(cat:GetID())` — present |
| Minimap button | LibDataBroker-1.1 + LibDBIcon-1.0 (both load; `## AddonCompartmentFunc` for the compartment). The object is `type = "launcher"` with `icon`, `OnClick(frame, mouseButton)` and `OnTooltipShow(tooltip)`; modifier keys are read with `IsShiftKeyDown()` (the LDB spec says nothing of them); `LibDBIcon:Hide/Show` act on the button only, the `hide` flag is the add-on's, `Lock`/`Unlock` keep `db.lock` |
| AddOn Compartment | TOC `## AddonCompartmentFunc` (`func(addonName, buttonName)`: **left and right clicks both arrive**, `"LeftButton"`/`"RightButton"`), `## AddonCompartmentFuncOnEnter`/`...OnLeave` (`func(addonName, buttonFrame)`); source `Blizzard_Minimap/Mainline/AddonCompartment.lua`. Since 11.0 no third frame argument. Tooltip: `GameTooltip:SetOwner(frame, "ANCHOR_LEFT")` (there is no `MenuUtil.ShowTooltip`; `ShowTooltipEx`/`HideTooltipEx` exist) |
| Context menu | `MenuUtil.CreateContextMenu(owner, function(owner, root) ... end)` opens at the cursor and closes when the owner is hidden; `root:CreateTitle(text)`, `:CreateButton(text, callback, data)` (closes the menu), `:CreateCheckbox(text, isSelected, onSelect, data)` (stays open, re-reads its state), `:CreateDivider()`. A callback gets `(data, menuInputData, menu)`; `menuInputData.buttonName` names the mouse button |
| Key bindings | `Bindings.xml` in the add-on's folder, loaded by the client by its name (not in the TOC): `<Binding name="TOKEN" header="HEADER">Lua</Binding>`; labels `BINDING_NAME_<name>`, `BINDING_HEADER_<header>`; the Lua runs insecurely; `keystate` is `"down"` (or `"up"` with `runOnUp="true"`) |
| Scroll lists | `CreateScrollBoxListLinearView()`, `view:SetElementInitializer(template, fn)`, `ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)`, `CreateDataProvider()`; template `MinimalScrollBar` — present |
| Dropdown | `WowStyle1DropdownTemplate` + `dropdown:SetupMenu(function(dd, root) root:CreateButton(text, fn) end)`; `UIDropDownMenuTemplate` also exists |
| Panel frame | `ButtonFrameTemplate` (portrait, title, inset, close); `ButtonFrameTemplate_HidePortrait`/`_HideButtonBar`; `UIPanelWindows[name] = {area="left", pushable=1, whileDead=1}`; `ShowUIPanel`/`HideUIPanel` |
| Tabs | `PanelTabButtonTemplate`, `PanelTemplates_SetNumTabs`, `PanelTemplates_SetTab`, `PanelTemplates_TabResize` |
| Buttons/edit | `UIPanelButtonTemplate`, `UIPanelCloseButton`, `SearchBoxTemplate`, `InputBoxTemplate` |
| Insets/backdrop | `InsetFrameTemplate3`, `BackdropTemplate` with `BACKDROP_TOOLTIP_16_16_5555` / `BACKDROP_DIALOG_32_32` presets |
| Parchment/quest art | `Interface\QuestFrame\QuestBG`, `Interface\QuestFrame\UI-QuestTitleHighlight`, `Interface\QuestFrame\UI-HorizontalBreak`; fonts `QuestFont`, `QuestTitleFont`, `GameFontNormal`, `GameFontHighlight`, `GameFontDisable` |
| Pin icons | Atlases `QuestNormal`, `QuestTurnin`, `QuestRepeatableTurnin`, `TaxiNode_Neutral`/`TaxiNode_<faction>`, `FlightMaster`, `poi-door`, `Innkeeper`, `Class`, `Profession`, `Repair`, `Food`; **no `Vendor` atlas** — use `Interface\GossipFrame\VendorGossipIcon`; other fallbacks `Interface\GossipFrame\AvailableQuestIcon`, `ActiveQuestIcon`, `TaxiGossipIcon`, `TrainerGossipIcon`, `BinderGossipIcon` |
| Secret guard | `issecretvalue(v)` exists; `UnitHealth`/`UnitPower` are secret |
| Error isolation | `xpcall(fn, geterrorhandler(), ...)` — extra arguments are passed (`ns.SafeCall`) |

## Skyborne / Zephras Isle (research 2026-10-20)
What exists for the Windshaper (Horde Skyborne) start, and what does not:
- **Known:** the client map dump has **Zephras Isle = uiMapID 2521** (also Riverglades 2548, Shen'dralas 2652, Mount Hyjal 2482).
  QuestieDB's area table maps 28 Zephras subzone AreaIDs to 2521 (Thendal Grove, Shen'dar Highlands and Village, Windsong Lake,
  Gustberry Lowlands, Valanaar Skydocks, Shrine of Akir, Rohashi Spires, Shadowfang Forest ...).
- **Not in QuestieDB's base tables (superseded by the update below):** its Forever quest data holds **0 quests** in those areas and no Skyborne NPCs: the area table was prepared,
  the content was not added. The pack therefore has no Zephras Isle quests, NPCs or objects.
- **Not readable:** Wowhead's Forever zone, quest and NPC pages answer 403 to the exporter (see the Wowhead section above).
- **Community descriptions (beta observations, names only, no IDs or coordinates, sources disagree):** the island is levels 1-12
  (Blizzard confirms the range and the faction split; beta players report finishing around 12-14). The Horde fork is "The Gift of
  Skysight" (Alliance: "Reading the Ley Lines"). An opening chain in Thendal Village is described as Coming of Age, Harmony in Balance,
  Infestation Investigation, The Cirrusfly Queen, Falling With Style, The Anchors of Zephras. One tier-list site also names a level-2
  Shaman class quest, Embracing the Elements. A separate site lists quests nobody else confirms; ignore it. Sources:
  [timesaver.gg](https://timesaver.gg/blog/wow-forever-skyborne-starting-zone-zephras-isle-guide),
  [wowforeverguides.com](https://wowforeverguides.com/races/skyborne),
  [Blizzard news](https://news.blizzard.com/en-us/article/24302071/wow-forever-meet-the-new-skyborne).
- **Update 2026-10-20 (QuestieDB master af56aeef17): the layers now give us part of it.** The base `data/Forever` tables are still a
  converted Era baseline with 0 Zephras quests, but QuestieDB layers real Forever content on top as correction providers
  (`src/corrections/Forever/`: generated delta-base, beta traces, authored fixes; docs/forever-delta-base.md there). `questie_import.py`
  reads them as data (`signpost_tools/lua_corrections.py`) and applies them (`forever_layers.py`). Result for the Horde pack: Zephras Isle
  (2521) **90 quests and 176 NPCs**, Shen'dralas (2652) 16 quests and 2 NPCs, Darkspear Islands (2524) 10 quests, Riverglades (2548) 10 NPCs
  and no quests, Mount Hyjal (2482) nothing. Race masks: Skyborne are **bits 32 (High Order Skyborne, Alliance, 4294967296) and 33
  (Windshaper, Horde, 8589934592)**, not raceID - 1 (raceIDs 95 and 96); QuestieDB's `ALL_HORDE` is the Classic Horde races plus bit 33
  (8589934770), `ALL_ALLIANCE` those plus bit 32. The pack's `races` therefore exceed 32 bits: never test them with WoW's 32-bit `bit.*`
  (the tools use Python integers). Starter quests the baseline lacked are in (Wayward Weapons 97279: Gornek 3143 -> 3159, level 1-2).
  Limits: QuestieDB says the delta base supplies no complete objectives, restrictions or gameplay behavior; its `LoadDynamic`
  (faction- and class-conditional) corrections are not read; category "zones" (16941 Crafting, 16611 Ruins of Lordaeron, 16919 Hall of
  Thanes, 16732, 16544) have no uiMapID, so those quests keep no `zone` and are listed in data-gaps.md.
- **Consequence (2026-10-20):** `Guides/HordeWindshaperDruid.lua` is drafted from these layers (Zephras Isle chapter `zephras-isle-1-12`, 90
  quests, race bit 8589934592) and the Windshaper's own druid chain is routed from the pack: A Student of Nature 92485, Child of Nature
  94911 (starts with Muln Earthfury in Mulgore, ends with Turak in Thunder Bluff), Moonglade 94913, The Great Ursera Spirit 94006,
  Strength and Mercy 94638. The Windshaper's Cat Form chain is in too (98340, 98341, 98404, 98738, 98362; `windshaper-cat-form-20`). Still not in the pack: what
  follows Zephras Isle after level 12, and objective counts and positions for several quests (the chapters carry `.todo` steps naming
  them). `Core/Learn.lua` remains the way to fill the gaps from play. Objective kill counts are not kept in the pack at all, so
  `tools/guide_sim.py` uses a parameter for them.

## Observed in the game (user reports)
- 2026-10-20, a level-1 Troll in the Valley of Trials: Gornek offers **Cutting Teeth** and **Wayward Weapons**, Kaltunk offers **Your Place in the
  World**. Wayward Weapons is **not in the data pack** (no quest of that name below level 60): Forever's starting zones carry quests the Classic
  baseline lacks. The first draft also wrongly started the walk in Orgrimmar ("The New Horde" starts with Eitrigg there, as an intro for characters
  created in Orgrimmar); fixed in `tools/guide_draft.py` (the walk starts where the race starts). Record the starting quests with `Core/Learn.lua`
  (accept and turn them in, `/reload`) so their IDs and positions reach the pack.

## Open probes (answer in game, record the evidence and build number, then move to Verified)
- [ ] Launch client folder name (after Nov 4): `_classic_`? `_forever_`? other?
- [ ] How does an addon tell that the character is on a Hardcore ruleset (a `C_` call, a character flag, a realm type)? The `.hc` gate
  stays false until this is answered (docs/HARDCORE.md); the user reports hardcore exists from launch day.
- [ ] The "Help improve Signpost" window (`UI/Contribute.lua`, `/signpost contribute`) in the real client: built from
  `ButtonFrameTemplate`, `UICheckButtonTemplate` and `UIPanelButtonTemplate` on specs only. Does it lay out (text not clipped, checkbox
  clickable on its label, Escape closes it, opens once by itself on a release build, not in combat)?
- [ ] **Pace recorder** (`Core/Pace.lua`): do `RequestTimePlayed()`, the `TIME_PLAYED_MSG` event (total, atLevel) and the global
  `ChatFrame_DisplayTimePlayed` exist? After a level-up: no "Total time played" chat line from Signpost's own request, a line from the
  player's own `/played`, and `SignpostCharDB.pace[level].played` written (read it with `python tools/guide_sim.py --pace`).
- [ ] The **Options entry** (`UI/Options.lua`): do `Settings.RegisterCanvasLayoutCategory(panel, name)` and `Settings.RegisterAddOnCategory(category)` exist
  and show the panel under Options > AddOns on Forever? Does the "Open the Journal" button work from there?
- [ ] The **Journal window** (`UI/Journal.lua`, `/signpost`) in the real client: `WowStyle1DropdownTemplate` as a `DropdownButton` with `SetupMenu` and
  `CreateRadio` (the menu API), `SearchBoxTemplate`, three `PanelTabButtonTemplate` tabs below the frame (`PanelTemplates_SetNumTabs/SetTab`),
  `UICheckButtonTemplate` rows, plain scroll lists, the LibDBIcon minimap button and the AddOn Compartment click. Does it lay out and work?
- [ ] **Druid forms in Forever** (sources disagree; the druid guide's Moonglade steps assume the first reading): is **Teleport: Moonglade**
  a level-10 trainer spell as in Classic, or a reward of the Bear Form chain (one Forever guide lists it as a reward)? How does a druid
  get back from Moonglade (hearthstone, a flight path, the spell)? Is **Cat Form** (level 20) a new quest chain ("The Great Cat Spirit",
  three relics in the Stormrage Barrow Dens: ForeverChanges, beta) or a trainer spell (another guide)? Does the Windshaper Skyborne druid
  have its own chain ("The Great Windborne Cat Spirit")? Record the quest IDs with `Core/Learn.lua` (docs/CLASS-QUESTS.md).
- [ ] **Positions in the guides** come from QuestieDB's converted Classic Era coordinates (Mulgore's map was re-scaled in the conversion,
  factor 0.835; the NPC and terrain world positions are assumed unchanged). Walk the first Mulgore and Durotar steps and confirm the pins.
- [ ] `C_QuestLog.GetAllCompletedQuestIDs()` populated at `PLAYER_ENTERING_WORLD` or only after a `QUEST_LOG_UPDATE`? (A new character
  has none: re-run `/signpost probe` after turning in a few quests, relog, probe again.)
- [ ] What each of the **7** `GetProfessions()` values holds once professions are learned, and which one is **First Aid** — the
  profession plan is detected from these (PLAN §3.8). (Train a primary and First Aid, then `/signpost probe` and `/reload`.)
- [ ] Taxi UI at a flight master: `TaxiFrame` or `FlightMapFrame`? Which `TakeTaxiNode` argument (index or nodeID) works? (`/signpost
  debug on`, open a flight master: the log keeps both node lists and which frame was shown.)
- [ ] Setting the hearth without `ConfirmBinder`: what does the innkeeper's gossip option do, does `CONFIRM_BINDER` fire, and what confirms
  it (`C_PlayerInteractionManager.ConfirmationInteraction`?). (`/signpost debug on` at an innkeeper.)
- [ ] Pet at level 10 via "The Hunter's Path" (Thotar, Razor Hill) still the chain? Is Light Shot purchasable from vendors (item exists)?
- [ ] HereBeDragons minimap pin rotation/zoom works with Forever's minimap (Phase 3).
- [ ] `C_GossipInfo.GetOptions()` field names on this build (`gossipOptionID` vs `orderIndex`); innkeeper bind option icon/flags.
- [ ] **On a boat/zeppelin**: what do `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition`, `UnitPosition`,
  `GetZoneText`/`GetSubZoneText` return at (a) the dock, (b) mid-crossing, (c) arrival? Which `ZONE_CHANGED*` events fire and in what order?
  (`/signpost debug on` + `/signpost debug pos` on the Orgrimmar→Undercity zeppelin.)
- [ ] **On a flight**: `UnitOnTaxi` true for the whole flight? Does `ZONE_CHANGED_NEW_AREA` fire for zones flown over? Event on landing?
- [ ] Inside Orgrimmar, does `C_Map.GetBestMapForUnit` return 1454 (a sibling of Durotar, see Verified)?
- [ ] `GetQuestReward(i)` and `AcceptQuest()` are not protected (no taint error when called from an addon event handler). (Phase 5.)
- [ ] When a class trainer also offers a class quest: does the client fire `GOSSIP_SHOW` with a mixed options/quests list, or
  `QUEST_GREETING`? Does `C_GossipInfo.GetAvailableQuests()` include it alongside the "I need training" option?
- [ ] At `QUEST_COMPLETE`, does `C_Item.GetItemInfo(GetQuestItemLink("choice", i))` return sellPrice for all choices immediately, or is
  `ITEM_DATA_LOAD_RESULT` needed? Is sellPrice ever a secret value? (`/signpost debug on` at a multi-reward turn-in.)
- [ ] `C_TooltipInfo.GetTrainerService(i)` yields the spell ID of a trainer service. (`/signpost debug on` at a trainer.)
- [ ] `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` payloads at each NPC type (`Enum.PlayerInteractionType` name is logged).
- [ ] The main addon loads cleanly with `Signpost_Data` disabled in the AddOns list.
- [ ] Memory/CPU of loading the full data pack (target < 10 MB); if high, split per continent with `## LoadOnDemand`. The Horde
  questie layer (2710 quests, 3704 NPCs, 552 objects, 2023 items) takes about 7.1 MB in desktop Lua 5.1; in the client:
  `GetAddOnMemoryUsage("Signpost_Data")` after `UpdateAddOnMemoryUsage()`, and no Lua errors from the generated files.
- [ ] Whether QuestieDB's instance uiMapIDs exist on Forever (`C_Map.GetMapInfo(279)`, say): 374 pack quests use one as
  `quests[].zone`.

Added by the Wave 1 modules (each has a matching `VERIFY(beta)`/`VERIFY(launch)` comment in the code; `/signpost context`
saves Engine/Context's view to `SignpostDB.context` for comparison):

Quests and spells (Engine/Context.lua, Engine/Directives.lua, Engine/Progress.lua)
- [ ] What `C_QuestLog.IsComplete` returns for a quest without objectives (talk-to, delivery); until known such a quest is
  "ready" only when it says so. (Accept one, `/signpost context`, `/reload`, read `context`.)
- [ ] Whether `C_QuestLog.GetInfo` lists the quests under a collapsed quest log header (`collapsedHeaders` in the snapshot).
- [ ] `C_QuestLog.GetQuestObjectives` text names the creature, item or object as the data pack does, and `type` is
  `monster`/`item`/`object` for them (`.complete` pairs the log's objectives with the pack's that way).
- [ ] Which of `IsPlayerSpell`, `C_SpellBook.IsSpellKnown`, `IsSpellKnown` report a trained spell rank, and whether a lower
  rank stays known once a higher one is learned (`.train class` checks every listed rank).
- [ ] `C_Item.GetItemNameByID` exists (`C_Item.GetItemInfo` does).
- [ ] At login on a character with turned-in quests: does auto-skip happen at once (STEP_CHANGED "load") or only at the first
  `CONTEXT_CHANGED("quests")` ("auto")? Ties to the `GetAllCompletedQuestIDs` probe above.

Professions (Core/Player.lua, Engine/Professions.lua, Engine/Directives.lua, Core/Learn.lua)
- [ ] `GetProfessionInfo` keeps the retail return order (skill line 7th); the first two `GetProfessions` values are the
  primaries; `GetProfessions` already answers at `PLAYER_LOGIN`. (Train a primary and First Aid, `/signpost probe`.)
- [ ] `SKILL_LINES_CHANGED` fires on learning, unlearning and every skill-up (rank 1 → 2), else `CHAT_MSG_SKILL` does
  (`/signpost debug on`, skin once, read `eventLog`).
- [ ] Two primary professions per character on Forever.
- [ ] `UNIT_SPELLCAST_SUCCEEDED("player", castGUID, spellID)` fires once per crafted item with the recipe's spell ID (`.craft`).
- [ ] `GetTrainerServiceSkillLine(i)` names the profession as `GetProfessionInfoBySkillLineID` does (Learn's trainer skill).
- [ ] VERIFY(launch): profession rank-up thresholds (Classic trains the next rank at max − 25: 50/75, 125/150, 200/225).

Travel (Engine/Travel.lua, Engine/Context.lua, Core/Learn.lua, tools/guide_travel.py, tools/wowhead_export.py)
- [ ] Boarding signals on a boat or zeppelin, each an assumption (with the transport probe above): the map position or
  `UnitPosition` going away on board, a continent-level best map over open sea, another instance, a loading screen or
  `PLAYER_ENTERING_WORLD(false, false)` mid-crossing; `GetUnitSpeed("player")` is 0 standing on a moving deck.
- [ ] At a flight master: `TaxiNodeGetType` values (`CURRENT`/`REACHABLE`/`DISTANT`/`NONE`), `C_TaxiMap.GetAllTaxiNodes(map)`
  `.state` (`Enum.FlightPathState`) and `isUndiscovered` for unknown nodes, whether `GetTaxiMapID` exists, which API marks
  the current node, and that node names equal the map dump's (`.fp`/`.fly` and the exporter's `node` match them).
- [ ] `Enum.FlightPathFaction` exists with the faction tokens as keys (0 neutral, as the probe shows).
- [ ] After a flight the player lands within 200 yd of the node position `C_TaxiMap.GetTaxiNodesForMap` reports.
- [ ] Hearthstone: `C_Item.GetItemSpell(6948)` returns its spell, named like the item; `GetBindLocation()` names a town inn
  (Razor Hill) and a city inn (Orgrimmar) as `GetSubZoneText`/`GetZoneText` do; `HEARTHSTONE_BOUND` exists; the cooldown
  (the travel planner assumes 60 min).
- [ ] `MERCHANT_UPDATE` registers (Learn's vendor items; `MERCHANT_SHOW` alone is enough otherwise).
- [ ] Each flight master stands in the map `guide_travel.py` picks from the taxi pin (the city map for "Orgrimmar, Durotar").

Step frame and pins (UI/StepFrame.lua, UI/Pins.lua; add the names to Core/Probe.lua's lists)
- [ ] Atlases `Waypoint-MapPin-Tracked`, `Waypoint-MapPin-Untracked`, `Objective-Header`; files
  `Interface\DialogFrame\UI-DialogBox-Background-Dark`, `Interface\Minimap\ROTATING-MINIMAPGUIDEARROW` (pointing up at
  rotation 0), `Interface\Buttons\UI-Quickslot2`, `UI-Quickslot-Depress`, `ButtonHilight-Square`; template
  `CooldownFrameTemplate`; events `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, `BAG_UPDATE_COOLDOWN`; APIs
  `C_Item.GetItemIconByID`, `C_Container.GetItemCooldown`, `GetPlayerFacing`.
- [ ] Look and placement: the frame at TOPRIGHT −300,−220 is clear of the minimap and the objective tracker; the
  `UIPanelButtonTemplate` buttons look right at 20 px; `GetStringHeight` right after `SetText` gives the wrapped height (no
  clipped last line at 5 lines); waypoint numbers readable on `TaxiNode_Neutral`; minimap pins above the minimap's layers;
  world-map lines (3 px gold) above the map art and below the pins.
- [ ] **Doing steps** (a `.complete` and nothing that sends the player to a place; user, 2026-10-20): in the real client the guide draws
  no pin, minimap pin or edge arrow for such a step while the quest log's own marks show the objectives (and the step before's pins
  are gone); the step frame lists one line per quest with a green `[x]` or a plain `[ ]` (colour escapes in the body font string)
  and no counters; up to ten lines (`MAX_BODY_LINES`) of `GameFontHighlight` at 260 px lay out without clipping a line or
  covering more than the old five did.
- [ ] **Quest tracking follows the step** (`Engine/Tracking.lua`, user 2026-10-20; built on the mock, none of it seen in the client;
  `/signpost probe` now lists the names, and the Classic ones as expected-absent): do `C_QuestLog.AddQuestWatch(questID[, watchType])`,
  `RemoveQuestWatch(questID)`, `GetQuestWatchType(questID)` (nil for a quest nobody tracks?), `GetNumQuestWatches()`,
  `GetQuestIDForQuestWatchIndex(i)`, `C_SuperTrack.GetSuperTrackedQuestID()`, `SetSuperTrackedQuestID(questID)` and
  `Enum.QuestWatchType.Manual` exist on Forever, and does `AddQuestWatch` take the watch type? Or is it the Classic shape (global
  `AddQuestWatch(logIndex)`, `IsQuestWatched`, `GetQuestIndexForWatch`, which the module falls back to, with
  `C_QuestLog.GetLogIndexForQuestID` and `GetQuestIDForLogIndex` for the numbers)? Does the watch list read back an add or a
  remove at once, before `QUEST_WATCH_LIST_CHANGED` (the module compares right after, and stops for the session if no quest of
  a step shows as tracked)? How many quests can be tracked: a full tracker refuses the add, which the module takes for a broken
  `AddQuestWatch` (it then leaves the tracker alone and stops). Does `C_QuestLog.GetInfo` list the quests under a collapsed
  header (the module asks `Context:QuestInLog` either way)? Does the game's own auto-tracking (on accept, on progress) leave the module's result
  alone (a quest accepted mid-step is untracked at the next change of the quest log's set of quests)? Do the minimap and the
  objective tracker then show only the step's quests with their progress, and does the check box under "Quest tracker" in
  Journal > Settings (second column) fit the pane?
- [ ] The quest item button (`type = "item"`, `item = "item:<id>"`) uses the item by click and by `/click SignpostItemButton`,
  with `ActionButtonUseKeyDown` on and off; a step change in combat updates it after combat without `ADDON_ACTION_BLOCKED`.

Automation (Automation/*.lua, UI/Journal.lua, UI/StepFrame.lua; all built on the mock, none seen in the client; each has a
`VERIFY(beta)` comment where the code relies on it). Test with every toggle on in `/signpost automation on`, Shift released:
- [ ] `AcceptQuest()`, `CompleteQuest()`, `GetQuestReward(i)`, `C_GossipInfo.SelectAvailableQuest/SelectActiveQuest`,
  `SelectAvailableQuest(i)`, `SelectActiveQuest(i)`, `BuyTrainerService(i)`, `BuyMerchantItem(i, n)` and `TakeTaxiNode(x)` can be
  called from an addon event handler without `ADDON_ACTION_BLOCKED` (the Phase 5 probe above covers the first and third).
- [ ] `QUEST_DETAIL`: `QuestGetAutoAccept()` is true for quests that accept themselves (the addon then does not call AcceptQuest);
  `C_QuestLog.IsQuestTrivial(questID)` exists (the wide accept mode treats a missing API as "not trivial").
- [ ] `GetAvailableQuestInfo(i)` returns `isTrivial, frequency, isRepeatable, isLegendary, questID` (the fifth is what a
  `QUEST_GREETING` selection is matched on), and `GetActiveQuestID(i)` exists; `C_GossipInfo.GetActiveQuests()` entries carry
  `questID` and `isComplete`, `GetAvailableQuests()` entries `questID` and `isTrivial`.
- [ ] Reward values: `C_Item.GetItemInfo(link)` returns `sellPrice` as the 11th value, `GetQuestItemInfo("choice", i)` the quantity
  as the 3rd; `C_Item.RequestLoadItemDataByID` is answered by `ITEM_DATA_LOAD_RESULT(itemID, success)`; the wait is 2 s.
  (Extends the "At QUEST_COMPLETE ..." probe.) `GetQuestReward(0)` is right for a quest with no choice, `1` for exactly one.
- [ ] Gossip: `C_GossipInfo.GetOptions()` entries carry `gossipOptionID` (else `orderIndex` with `SelectOptionByIndex`), `name`,
  `icon`; the innkeeper's bind option has the icon file ID of `Interface\GossipFrame\BinderGossipIcon` (or the words "inn" and
  "home" in enUS); a single-option gossip at a trainer/vendor/flight master is selected by `SelectOption`.
- [ ] Setting the hearth: after the bind option, `CONFIRM_BINDER` fires and a popup `CONFIRM_BINDER` shows; which of `StaticPopup_FindVisible`
  + its `button1:Click()`, `C_PlayerInteractionManager.ConfirmationInteraction(Enum.PlayerInteractionType.Binder)` and `ConfirmBinder`
  confirms it (the code tries them in that order at 0, 0.2 and 0.6 s). (Extends the "Setting the hearth without ConfirmBinder" probe.)
- [ ] Flights: at a flight master, which node list is filled (`NumTaxiNodes` > 0, so the index form) and that `TakeTaxiNode(index)`
  takes the flight; on the `C_TaxiMap` shape whether `TakeTaxiNode(nodeID)` or `TakeTaxiNode(slotIndex)` does. (Extends the taxi
  probes above.)
- [ ] Trainer: `GetTrainerServiceInfo(i)` returns `name, subText, serviceType` with `serviceType` "available"/"unavailable"/"used";
  `GetTrainerServiceItemLink(i)` is a `spell:` link (else `C_TooltipInfo.GetTrainerService(i).id` is the spell ID); a trainer's
  list is not hidden by a type filter ("available" shown); the spell IDs in `Classes/<CLASS>.lua` `trainerSpells` equal the
  services' (they are empty today, so `.train class` buys nothing yet); a profession's rank services' spell IDs, to fill
  `rankSpells` in the profession modules (until then `.trainprof` buys nothing).
- [ ] Vendor: `C_MerchantFrame.GetItemInfo(i)` returns a table with `price`, `stackCount`, `numAvailable` (-1 unlimited),
  `isPurchasable`, `hasExtendedCost`; `GetMerchantItemMaxStack(i)` exists; `BuyMerchantItem(i, n)` counts purchases (bundles of
  `stackCount`), not items.
- [ ] Hearth button: `type = "item"` on `SignpostItemButton` uses item 6948 on click for a `.home` step (extends the quest item
  button probe), and the Hearthstone is in the bags of a new character.
- [ ] Settings tab, second column: the nine Automation checkboxes at x = 470 neither overlap the first column's labels nor run off
  the pane at 800 x 560 (the longest first-column label ends at about x = 450).
- [ ] `InCombatLockdown` and `UnitIsDeadOrGhost("player")` are plain booleans (never secret) and `SettingsPanel` is the
  Blizzard settings frame (an open panel blocks automation).

Launcher: the minimap button, the quick menu, the AddOn Compartment and the key bindings (`UI/Launcher.lua`, `Bindings.xml`,
`docs/INTERACTIONS.md`; user 2026-10-21; built on the mock, none of it seen in the client; each has a `VERIFY(beta)` comment)
- [ ] **The quick menu** (`MenuUtil.CreateContextMenu` is verified present; `CreateTitle`, `CreateButton`, `CreateCheckbox` and `CreateDivider`
  on its root description are not yet): a right-click on the minimap button and on the step card opens it at the cursor with the title,
  the buttons, the three check boxes and the dividers laid out as in `docs/INTERACTIONS.md`; a check box click keeps the menu open and shows
  the new state; a button click closes it and does its action; "Show the step card" unchecked hides the card, which is the menu's owner (the
  menu then closes with it): is that acceptable? Opened during combat the menu and its entries raise no taint warning or
  `ADDON_ACTION_BLOCKED` (the plan's acceptance for the Journal: it must just open). Without a Menu system the fallback (Settings tab, or
  the Journal from the card) is never seen on Forever if this works.
- [ ] **The AddOn Compartment**: a right-click on Signpost's entry reaches `Signpost_OnAddonCompartmentClick("Signpost", "RightButton")` (the
  Blizzard source registers entries for any click; not seen on Forever); our menu, opened one frame later with `C_Timer.After(0, ...)`,
  appears and is not closed by the compartment (and: is the delay needed? opening it at once is the simpler code); `IsShiftKeyDown()`
  is true inside the click while Shift is held; the hover tooltip (`GameTooltip`, `ANCHOR_LEFT`) shows beside the entry and hides on
  leave; both TOCs' `AddonCompartmentFuncOnEnter`/`OnLeave` lines are read (the client loads `Signpost_Camelot.toc`).
- [ ] **The Key Bindings screen** shows the header "Signpost" with six labelled actions (Show or hide the Journal, Show or hide the step card,
  Previous step, Next step, Skip this step, Find my place), most likely under the AddOns category; a bound key runs its `/signpost`
  command, in combat too, with no `ADDON_ACTION_BLOCKED` or taint warning.
- [ ] **The minimap button** (LibDBIcon button, `Media\icon-round`): left-click shows or hides the Journal, Shift + left-click the step
  card, right-click the menu; dragging moves it and "Lock the minimap button's position" stops that; "Show the minimap button" and
  `/signpost minimap` hide and bring it back, and `hide`, `lock` and the position survive `/reload`; the tooltip reads: name, `<chapter> ·
  step i/N`, the step's first line, a blank line, three hint lines with yellow keys.
- [ ] **Settings tab, first column at 800 x 560:** its eleven check boxes, now drawn at 26 (`CHECK_SIZE`), leave the step card steppers and
  the profession line clear of the "How do I share what was recorded?" button at the bottom. If they do not, give the two minimap boxes
  `column = 2` in `settingsList()` or shrink the boxes further.

## Wowhead Forever data environment (fill in Phase 1)
Filled from the user's `python tools/wowhead_env.py` report (Claude Code never accesses Wowhead). Until that report
confirms them, the page structures `tools/wowhead_export.py` parses are assumptions:
- `zones`: a Listview with template `zone`; rows `id`, `name`, `minlevel`, `maxlevel`, `category` (0 Eastern Kingdoms,
  1 Kalimdor).
- `quests=<category>.<zoneID>`: template `quest`; rows `id`, `name`, `level`, `reqlevel`, `side` (1 Alliance, 2 Horde,
  3 both), `reqclass`/`reqrace` bitmasks (bit = ID − 1).
- `quest=<id>`: Quick Facts through `WH.markup.printHtml("…", "infobox-contents…")` with `Start:`/`End:` links
  (`/npc=`, `/object=`, `/item=`), `Level:`, `Requires level`, `Side:`; a `<table class="series">` with the quest itself in
  `<b>`; names from `WH.Gatherer.addData(1|2, env, {id: {name_enus}})`.
- `npc=<id>`, `object=<id>`: `g_mapperData = {zone: {floor: {coords, uiMapId}}}`; the `<h1>` holds the name.
- `class=<classID>`: a `spell` Listview (`id`, `level`, `cat` 7 = class ability, `source` 6 = trainer or `trainingcost`;
  fallback `spells=7.<classID>`) and an `npc` Listview whose id contains "train" (`react` [Alliance, Horde]: 1/0/−1).
- `quests=4.-<QuestSort>` lists a class's quests (HUNTER 261 is sampled; the other classes' QuestSort IDs are from memory).
- `/classic/quest=<id>`: a 404 means the quest is new in Forever; a page without Quick Facts is inconclusive.
- `skill=<skillLine>`: `spell` rows with `skill[]`, `colors[4]`, `learnedat`, `creates[item, min, max]`,
  `reagents[[item, count]]`, `source` (6 trainer, 5 vendor, 4 quest, 2 drop); fallback `spells=11.<id>` (primary) /
  `spells=9.<id>` (secondary); trainers as for classes.
- `zone=<zoneID>`: `npc` rows with `id`, `name`, `react`, `tag` (flight master, "Bat Handler", "Innkeeper", "Zeppelin
  Master", "Dockmaster", "Harbormaster").

The user's run, from the Signpost checkout (each step re-runs with `--offline` after a parser fix, without requests):
`python tools/wowhead_env.py` (paste the JSON) → `python tools/wowhead_export.py --max-level 32` →
`--stages class --class HUNTER` → `--stages professions` → `--stages travel --max-level 60` → `--stages travel --max-level
60 --offline --transport zeppelin:<npcID>,<npcID>` per route (IDs from data-gaps.md) → paste data-gaps.md's "Problems
reported by the wowhead source" → commit in `../Signpost_Data` with the export date.
- Base path: `https://www.wowhead.com/forever/` (the user's `wowhead_env.py` run, 2026-10-20: the landing page answers 200).
- **Reachability (same run, 23 requests, user agent `SignpostDataExporter/0.1`):** HTTP 200 for the landing page, the class quest
  listing (`quests=4.-261`: 1000 rows with `xp`, `reqclass`, `reqlevel`, `level`, `side`, `category`, no giver/ender), the item XML
  (`item=2516&xml`) and Wowhead's *Classic* quest pages (`/classic/quest=4641`). **HTTP 403** for every other Forever page tried: the
  zone list and zone pages, zone quest listings (`quests=1.14`), quest, NPC and object pages, skill and recipe listings, class and ability
  pages. The exporter identifies itself honestly and a 403 is treated as "not available": it is not retried and no workaround is built.
  Consequences: the pack's names, positions and links come from QuestieDB and in-game learning; Wowhead can still add quest XP from
  class quest listings and item facts from the item XML. Whether the 403s are permanent, rate-based or per path is unknown.
- `dataEnv` id for `nether.wowhead.com/tooltip/...`: `TODO`.
- `?xml` endpoint availability: `TODO`.
- Zone ID ↔ uiMapID join table: the data pack's `Maps.lua` (generated from the client dump; Wowhead zone IDs joined in Phase 1),
  overrides in `tools/map_overrides.json`.
