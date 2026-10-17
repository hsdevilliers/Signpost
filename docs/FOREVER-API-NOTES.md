# WoW: Forever — client & API notes (living document)

Rule: three sections. **Verified** = seen in the live client or in a dated community report (cite). **Mapping** = what to use instead of
Classic-era APIs; assume true for Mainline, confirm on first use. **Open probes** = must be checked in-game with `/signpost probe` before
code depends on it; move the result to Verified with the build number.

Build at time of writing (community reports): beta `1.60.1.70338` (Oct 2026). Launch Nov 4, 2026. Beta ends Oct 21, 2026, level cap 30.
Installed on the dev machine 2026-10-17: **`1.60.1.70450`** (from `World of Warcraft\.build.info`; product `wow_classic_beta`,
flavor folder `_classic_beta_`, executable `WowB.exe`).

**How to answer the open probes:** in game, `/signpost probe` and `/signpost dumpmaps`, then `/reload`; on the dev machine,
`python tools/read_savedvars.py probe` (or `mapDump`, `errors`). Each probe result section is named in brackets below,
e.g. [build], [templates]. Event payloads (gossip, quest dialogs, trainer, vendor, taxi, transports) come from
`/signpost debug on` (+ `/signpost debug pos` for 1 s position samples) and `read_savedvars.py eventLog posLog`.

## Verified (from community reports, Sep–Oct 2026 — confirm on first beta login)
- TOC `## Interface: 16001` is the Forever beta value (Warcraft Wiki TOC table; multiple Forever addons ship it). One early report
  showed interface 120007 on build 69893; 16001 is what current addons use. → confirm with `/dump select(4, GetBuildInfo())`.
  More evidence (2026-10-17): HereBeDragons 2.18's TOC lists `11509,16001,20506,50504,120100,120105`, LibDBIcon v12.1.1's lists
  16001 among others, and the Forever addon "Zeppelin Signs" on CurseForge ships 16001.
- Flavor-specific TOC suffix is `_Camelot` (Forever's internal codename): `Addon_Camelot.toc`. Keep a plain `Addon.toc` too.
- Beta addons folder: `World of Warcraft\_classic_beta_\Interface\AddOns\`. The client only picks up new addon folders on start.
- Forever is in the **Mainline** project family: `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`; retail unit-frame templates are present.
  Consequence: Classic Era addons show "out of date" and generally need porting.
  **Contradicted (2026-10-17):** HereBeDragons 2.18 detects Forever with `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`, so Forever
  probably has its own project ID (Mainline API, separate project constant). Never branch on `WOW_PROJECT_MAINLINE`; see open probe.
- Removed: `GetSpellInfo`, `GetItemInfo` (globals). Use `C_Spell.GetSpellInfo(id)` (returns a table) and `C_Item.GetItemInfo(id)`.
- `CombatLogGetCurrentEventInfo` unavailable to addons (WeakAuras is absent on Forever for related reasons).
- "Secret values": `UnitHealth` (and possibly other combat values) return values that error on arithmetic/comparison in addon code.
- The quest log is the world map (retail-style `QuestMapFrame`); the Blizzard quest tracker exists.
- AddOn Compartment (`## AddonCompartmentFunc`) exists (Forever addons use it). Options → AddOns panel exists (`Settings` API).
- Classic-style content still present: level cap 60, flight masters/taxi, Classic dungeons (modified) plus new ones
  (Hall of Thanes 13, Ruins of Lordaeron 15, Excavation Site: Wetlands 26, City of Dalaran 28, …).
- Class content: Forever adds new class-specific quests (announced reward: large weapon upgrades); most class quests are offered by class
  trainers at level thresholds; the hunter level-10 chain still uses a taming rod on three beasts then unlocks Tame Beast. Dual spec exists (irrelevant to us — talents are out of scope).
- Travel changes vs Classic: new ship Wetlands ↔ Darkshore with a Hillsbrad stop; Stormwind Harbor open; new zones Riverglades, Shen'dralas, Zephras Isle (Skyborne start), Mount Hyjal (60).
- Known Forever-specific gotcha from UnitFramesImproved: a `#` comment line **before** `## Interface:` can make the client treat the TOC as unparseable — keep `## Interface:` as the first line.

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
| Player position | `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(uiMapID,"player")` → `:GetXY()` (nil in instances) |
| Map tree | `C_Map.GetMapInfo(id)`, `C_Map.GetMapChildrenInfo(parentID, mapType, allDescendants)`, `C_Map.GetWorldPosFromMapPos` |
| Distance/pins | HereBeDragons-2.0 (`HBD:GetPlayerZonePosition()`, `HBD:GetZoneDistance`, `HBD:GetWorldCoordinatesFromZone`, `HBD-Pins:AddMinimapIconMap/AddWorldMapIconMap`); map lines via a `Line` texture on `WorldMapFrame:GetCanvas()` positioned with `HBD-Pins`' world-map pin frames as endpoints |
| Zone changes / transit | Events `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `PLAYER_ENTERING_WORLD(isLogin, isReload)`; `UnitOnTaxi("player")`; `C_Map.GetBestMapForUnit("player")` may be nil or a transport/continent map while on a ship — see probe; `UnitPosition("player")` (world coords; nil in instances); `GetZoneText()`/`GetSubZoneText()` as last resort for dock names |
| NPC id from unit | `UnitGUID("npc")` → `"Creature-0-…-…-…-<npcID>-…"`; `select(6, strsplit("-", guid))` |
| Items in bags | `C_Item.GetItemCount(itemID)`, `C_Container.GetContainerNumSlots`, `C_Container.GetContainerItemInfo`; event `BAG_UPDATE_DELAYED` |
| Spells known | `IsPlayerSpell(spellID)` / `IsSpellKnown(spellID)`; `C_Spell.GetSpellInfo(spellID).name` |
| Professions | `GetProfessions()` → prof1, prof2, arch, fishing, cooking; `GetProfessionInfo(idx)` → name, icon, skill, maxSkill, …, skillLineID; events `SKILL_LINES_CHANGED`, `TRADE_SKILL_LIST_UPDATE`. **First Aid slot may not exist — see probes.** |
| Trainer | `TRAINER_SHOW`, `GetNumTrainerServices()`, `GetTrainerServiceInfo(i)` → name, rank, category, `GetTrainerServiceItemLink(i)`, `GetTrainerServiceCost(i)`, `BuyTrainerService(i)`, `SetTrainerServiceTypeFilter("available", true)` |
| Vendor | `MERCHANT_SHOW`, `GetMerchantNumItems()`, `GetMerchantItemInfo(i)`/`C_MerchantFrame.GetItemInfo(i)`, `GetMerchantItemLink(i)`, `BuyMerchantItem(i, qty)` |
| Taxi | Retail shape: `TAXIMAP_OPENED`, `C_TaxiMap.GetAllTaxiNodes(uiMapID)` → `{nodeID,name,state,position}`, `TakeTaxiNode(nodeID)`. Classic shape: `NumTaxiNodes()`, `TaxiNodeName(i)`, `TaxiNodeGetType(i)`, `TakeTaxiNode(i)`. Support both until probed. |
| Hearth | `GetBindLocation()`; innkeeper gossip option (icon `vendor`/binder); `CONFIRM_BINDER` popup → `ConfirmBinder()`; Hearthstone item 6948 via secure button |
| Level/XP | `UnitLevel("player")`, `UnitXP("player")`, `UnitXPMax("player")` (**check for secret values**), event `PLAYER_LEVEL_UP(level)` |
| Player identity (ns.Player only) | `UnitClassBase("player")` → classFile (`"HUNTER"`), `UnitClass("player")` → localized, `UnitRace("player")` → localized, raceFile (`"Troll"`), `UnitFactionGroup("player")` → `"Horde"`/`"Alliance"`; portraits via `GetClassAtlas(classFile)`; `C_CreatureInfo.GetClassInfo`/`GetRaceInfo` for tables |
| Pet | `UnitExists("pet")`, `UnitCreatureFamily("pet")`, `UnitGUID("pet")`; `PET_STABLE_UPDATE`, `UNIT_PET("player")` |
| Options panel | `Settings.RegisterCanvasLayoutCategory(frame, name)` + `Settings.RegisterAddOnCategory(cat)`; open with `Settings.OpenToCategory(cat:GetID())` |
| Minimap button | LibDataBroker-1.1 + LibDBIcon-1.0 (works on Mainline; `## AddonCompartmentFunc` for the compartment) |
| Scroll lists | `CreateScrollBoxListLinearView()`, `view:SetElementInitializer(template, fn)`, `ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)`, `CreateDataProvider()`; template `MinimalScrollBar` |
| Dropdown | `WowStyle1DropdownTemplate` + `dropdown:SetupMenu(function(dd, root) root:CreateButton(text, fn) end)`; fallback `UIDropDownMenuTemplate` (deprecated, may be absent) |
| Panel frame | `ButtonFrameTemplate` (portrait, title, inset, close); `ButtonFrameTemplate_HidePortrait`/`_HideButtonBar`; `UIPanelWindows[name] = {area="left", pushable=1, whileDead=1}`; `ShowUIPanel`/`HideUIPanel` |
| Tabs | `PanelTabButtonTemplate`, `PanelTemplates_SetNumTabs`, `PanelTemplates_SetTab`, `PanelTemplates_TabResize` |
| Buttons/edit | `UIPanelButtonTemplate`, `UIPanelCloseButton`, `SearchBoxTemplate`, `InputBoxTemplate` |
| Insets/backdrop | `InsetFrameTemplate3`, `BackdropTemplate` with `BACKDROP_TOOLTIP_16_16_5555` / `BACKDROP_DIALOG_32_32` presets |
| Parchment/quest art | `Interface\QuestFrame\QuestBG`, `Interface\QuestFrame\UI-QuestTitleHighlight`, `Interface\QuestFrame\UI-HorizontalBreak`; fonts `QuestFont`, `QuestTitleFont`, `GameFontNormal`, `GameFontHighlight`, `GameFontDisable` |
| Pin icons | Atlases: `QuestNormal`, `QuestTurnin`, `QuestRepeatableTurnin`, `TaxiNode_Neutral`/`_Horde`, `poi-door`, `Innkeeper`, `Vendor`, `Class` trainer icons; fallback textures `Interface\GossipFrame\AvailableQuestIcon`, `ActiveQuestIcon`, `TaxiGossipIcon`, `TrainerGossipIcon`, `VendorGossipIcon`, `BinderGossipIcon` |
| Secret guard | `if issecretvalue and issecretvalue(v) then … end` (probe existence) |
| Error isolation | `xpcall(fn, geterrorhandler())` |

## Open probes (run `/signpost probe`, paste output here with build number, then move lines to Verified)
- [ ] `select(4, GetBuildInfo())` == 16001? `WOW_PROJECT_ID`, `WOW_PROJECT_MAINLINE` values.
- [ ] Does `Addon_Camelot.toc` load, and does `Addon.toc` with `## Interface: 16001` also load without "out of date"?
- [ ] Launch client folder name (after Nov 4): `_classic_`? `_forever_`? other?
- [ ] `C_QuestLog.GetAllCompletedQuestIDs()` populated at `PLAYER_ENTERING_WORLD` or only after a `QUEST_LOG_UPDATE`?
- [ ] `GetProfessions()` return shape on Forever; where does **First Aid** show up (slot? `GetSkillLineInfo`? `C_TradeSkillUI.GetAllProfessionTradeSkillLines()`)?
- [ ] `C_TradeSkillUI.GetProfessionInfoBySkillLineID` exists? Skill line IDs for Skinning (393), Leatherworking (165), First Aid (129), Cooking (185), Fishing (356) unchanged?
- [ ] Taxi UI: `TaxiFrame` (Classic) or `FlightMapFrame` (retail)? Which `TakeTaxiNode` signature works?
- [ ] Do `UnitXP`/`UnitXPMax`/`UnitLevel` return plain numbers (not secret)? `issecretvalue` exists?
- [ ] Ammo/quivers present for hunters? (item 2516 Light Shot purchasable? quiver slot?) Pet at level 10 via "The Hunter's Path" (Thotar, Razor Hill) still the chain?
- [ ] Templates exist: `ButtonFrameTemplate`, `InsetFrameTemplate3`, `PanelTabButtonTemplate`, `SearchBoxTemplate`, `MinimalScrollBar`, `WowStyle1DropdownTemplate`, `UIDropDownMenuTemplate`, `SecureActionButtonTemplate`, `BackdropTemplate`.
- [ ] Atlases exist (`C_Texture.GetAtlasInfo`): `QuestNormal`, `QuestTurnin`, `TaxiNode_Neutral`, `Innkeeper`, `Vendor`, `poi-door`, class trainer atlases.
- [ ] `ScrollUtil`, `CreateScrollBoxListLinearView`, `CreateDataProvider` present?
- [ ] `Settings.RegisterCanvasLayoutCategory` / `Settings.OpenToCategory` present?
- [ ] HereBeDragons-2.0: loads, detects Mainline, `HBD:GetPlayerZonePosition()` returns sane values in Durotar; minimap pin rotation/zoom works with Forever's minimap.
- [ ] `C_Map.GetMapChildrenInfo` from the root (try 946 Azeroth / 947 Cosmic) returns Forever's full zone tree; record uiMapIDs for Durotar, Orgrimmar, Barrens, etc. (Classic Era values: Durotar 1411, Barrens 1413, Orgrimmar 1454 — may differ).
- [ ] `C_GossipInfo.GetOptions()` field names on this build (`gossipOptionID` vs `orderIndex`); innkeeper bind option icon/flags.
- [ ] **On a boat/zeppelin**: what do `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition`, `UnitPosition`, `GetZoneText`/`GetSubZoneText` return at (a) the dock, (b) mid-crossing, (c) arrival? Which `ZONE_CHANGED*` events fire and in what order? (Needed for the transport state machine; log from the Orgrimmar→Undercity zeppelin.)
- [ ] **On a flight**: `UnitOnTaxi` true for the whole flight? Does `ZONE_CHANGED_NEW_AREA` fire for zones flown over? Event on landing (`PLAYER_CONTROL_GAINED`)?
- [ ] Does `C_Map.GetBestMapForUnit` return a sub-zone map (e.g. Orgrimmar 1454 inside Durotar 1411) so `.zone` must check the map's parent chain via `C_Map.GetMapInfo(id).parentMapID`?
- [ ] `GetQuestReward(i)` and `AcceptQuest()` are not protected (no taint error when called from an addon event handler).
- [ ] When a class trainer also offers a class quest: does the client fire `GOSSIP_SHOW` with a mixed options/quests list, or `QUEST_GREETING`? Does `C_GossipInfo.GetAvailableQuests()` include it alongside the "I need training" option? (Needed so `.train` + `.accept` on one NPC work in one visit.)
- [ ] At `QUEST_COMPLETE`, does `C_Item.GetItemInfo(GetQuestItemLink("choice", i))` return sellPrice for all choices immediately, or is `ITEM_DATA_LOAD_RESULT` needed? Is sellPrice ever a secret value?
- [ ] `## OptionalDeps: Signpost_Data` loads the pack before us (global `Signpost_Data` non-nil at our `ADDON_LOADED`); the main addon loads cleanly with the pack folder absent.
- [ ] `C_Timer`, `EventRegistry`, `C_AddOns.GetAddOnMetadata` present (expected yes).
- [ ] `UnitClassBase`, `UnitRace` raceFile token for Troll (`"Troll"`), `UnitFactionGroup`, `GetClassAtlas("HUNTER")` all return sane values; new Forever race/class combos (e.g. Skyborne, Undead Paladin) report tokens our registries can key on.
- [ ] Memory/CPU of loading full `Data/*.lua` (target < 10 MB); if high, split per continent with `## LoadOnDemand`.

Added 2026-10-17 (Phase 0 code carries a `VERIFY(beta)` for each):
- [ ] Value of `WOW_PROJECT_ID` and every `WOW_PROJECT_*` constant, incl. `WOW_PROJECT_CAMELOT` (see Verified above). [build]
- [ ] Which TOC the client loads when both exist: our TOCs differ only in `## X-Flavor-TOC` (Camelot/generic), which also tests
  that X- metadata is readable via `C_AddOns.GetAddOnMetadata`. The data pack has **only** a plain `Signpost_Data.toc`, so it
  answers "does a plain TOC with 16001 load". [build.tocFlavor, addons.dataPackAtLoad]
- [ ] `seterrorhandler` is usable by addons (Core/Errors.lua chains it); WoW's `xpcall` passes extra arguments. [build.errorSource,
  build.xpcallPassesArgs]
- [ ] `C_XMLUtil.GetTemplateInfo` exists (template checks without creating frames). [templates.method]
- [ ] `GetFileIDFromPath` exists; `Interface\Icons\INV_Misc_Map_01` (our TOC `IconTexture`) exists. [files]
- [ ] `C_TaxiMap.GetTaxiNodesForMap(uiMapID)` returns flight masters for every zone without visiting them, and
  `C_EncounterJournal.GetDungeonEntrancesForMap(uiMapID)` returns dungeon entrances (client data for the travel graph). [mapDump]
- [ ] `C_TooltipInfo.GetTrainerService(i)` yields the spell ID of a trainer service. [eventLog TRAINER_SHOW]
- [ ] `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` fire with an `Enum.PlayerInteractionType` value at NPCs. [eventLog]
- [ ] No other addon or client command claims `/sign` or `/signpost`. [build.slashCollisions]

## Wowhead Forever data environment (fill in Phase 1)
- Base path: `TODO` (candidate `https://www.wowhead.com/forever/`).
- `dataEnv` id for `nether.wowhead.com/tooltip/...`: `TODO`.
- `?xml` endpoint availability: `TODO`.
- Zone ID ↔ uiMapID join table: `Data/Maps.lua` (generated), overrides in `tools/map_overrides.json`.
