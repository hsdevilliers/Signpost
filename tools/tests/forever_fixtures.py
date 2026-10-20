"""A synthetic QuestieDB checkout with Forever correction layers, for the lua_corrections, forever_layers and importer tests.

Every name, ID and coordinate is made up. The files only mirror the formats the reader must handle: symbolic keys
(`questKeys.name`), `+` expressions of named constants, `_add` / `_remove` operation keys, positional groups with nil
holes, comments (and URLs in them), an unresolvable constant, a function value, a call, a runtime `LoadDynamic`.
"""

from pathlib import Path

from tests.test_questie_import import NPCS, QUEST_LAYOUT, keys_text, make_checkout

# The data file's part positions are QuestieDB's canonical ones here (the layers' group operands rely on it).
CANONICAL_PARTS = {
    "startedBy": ["creatureStart", "objectStart", "itemStart"],
    "finishedBy": ["creatureEnd", "objectEnd"],
    "objectives": [
        "creatureObjective", "objectObjective", "itemObjective", "reputationObjective", "killCreditObjective",
        "spellObjective",
    ],
}  # fmt: skip

LAYER_QUESTS = {
    1: {  # a Horde zone quest the layers will change
        "name": '"Boar Cull"', "zoneOrSort": "501", "questLevel": "2", "requiredLevel": "1", "requiredRaces": "178",
        "startedBy": "{{100}}", "finishedBy": "{{100}}", "preQuestSingle": "{40}", "objectivesText": '{"Kill 8 boars"}',
    },
    2: {
        "name": '"Orc Lessons"', "zoneOrSort": "501", "questLevel": "3", "requiredLevel": "3", "requiredRaces": "2",
        "startedBy": "{{102}}", "finishedBy": "{{102}}",
    },
    3: {
        "name": '"Horde Errand"', "zoneOrSort": "502", "requiredRaces": "178", "startedBy": "{{100}}",
        "finishedBy": "{{100}}",
    },
}

ENUM = {
    "constants.lua": "local _, LibQuestieDB = ...\nlocal constants = {}\n",
    "zones.lua": """local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

constants.zoneIDs = {
  -- zones
  ZONE_A = 501,
  ZONE_B = 502,
  ZEPHYR = 507, -- a zone the baseline lacks
}
""",
    "quests.lua": """local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

constants.specialFlags = { NONE = 0, REPEATABLE = 1 }
constants.sortKeys = {
  EPIC = -1,
  HUNTER = -261,
}
""",
    "icons.lua": """local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

constants.iconTypes = { ICON_TYPE_TALK = 5 }
""",
    "expansions.lua": """local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

constants.raceMaskById = {
  [1] = 1,
  [2] = 2,
  [3] = 4,
  [5] = 16,
  [6] = 32,
  [8] = 128,
  [95] = 4294967296, -- SKYBORNE_ALLIANCE
  [96] = 8589934592, -- SKYBORNE_HORDE
}
local raceMaskById = constants.raceMaskById
local classicHorde = raceMaskById[2] + raceMaskById[5] + raceMaskById[6] + raceMaskById[8]
local classicAlliance = raceMaskById[1] + raceMaskById[3]

constants.byExpansion = {
  Classic = {
    classKeys = { NONE = 0, WARRIOR = 1, HUNTER = 4 },
    npcFlags = { NONE = 0, VENDOR = 4 },
    raceKeys = { NONE = 0, ORC = raceMaskById[2] },
  },
  Forever = {
    npcFlags = { NONE = 0, QUEST_GIVER = 2, VENDOR = 4 },
    raceKeys = {
      NONE = 0,
      ORC = raceMaskById[2],
      TROLL = raceMaskById[8],
      SKYBORNE_ALLIANCE = raceMaskById[95],
      ALL_ALLIANCE = classicAlliance + raceMaskById[95],
      SKYBORNE_HORDE = raceMaskById[96],
      ALL_HORDE = classicHorde + raceMaskById[96],
    },
  },
}
""",
}

# Meta files: the field names (positions differ from the data files' on purpose) and the table shapes.
META = {
    "quest": ("Quest", [
        "name", "startedBy", "finishedBy", "requiredLevel", "questLevel", "requiredRaces", "requiredClasses",
        "objectivesText", "triggerEnd", "objectives", "sourceItemId", "preQuestGroup", "preQuestSingle", "childQuests",
        "inGroupWith", "exclusiveTo", "zoneOrSort", "requiredSkill",
    ], {"startedBy": "questgivers", "finishedBy": "questgivers", "objectives": "objectives", "preQuestSingle": "idarray",
        "requiredSkill": "pair", "objectivesText": "stringarray", "triggerEnd": "trigger"}),
    "npc": ("Npc", ["name", "rank", "spawns", "zoneID", "questStarts", "questEnds", "friendlyToFaction", "npcFlags"],
            {"spawns": "spawnlist", "questStarts": "idarray", "questEnds": "idarray"}),
    "object": ("Object", ["name", "questStarts", "questEnds", "spawns", "zoneID"],
               {"spawns": "spawnlist", "questStarts": "idarray"}),
    "item": ("Item", ["name", "npcDrops", "objectDrops", "startQuest", "vendors"],
             {"npcDrops": "idarray", "objectDrops": "idarray", "vendors": "idarray"}),
}  # fmt: skip


def meta_text(entity: str, names: list[str], shapes: dict[str, str]) -> str:
    keys = "\n".join(f"    ['{name}'] = {index}," for index, name in enumerate(names, 1))
    structures = ", ".join(f"[{names.index(name) + 1}]='{shape}'" for name, shape in shapes.items())
    return (
        "local _, LibQuestieDB = ...\n\nlocal meta = {\n"
        f"  entity = '{entity}',\n  keys = {{\n{keys}\n  }},\n  structures = {{\n{structures}\n  }},\n}}\n\n"
        f"if LibQuestieDB then\n  LibQuestieDB.Meta['{entity}'] = meta\nend\n\nreturn meta\n"
    )


def provider(module: str, aliases: str, records: str, extra: str = "", head: str = "") -> str:
    return (
        f"{head}local {module} = QuestieLoader:CreateModule(\"{module}\")\n"
        'local QuestieDB = QuestieLoader:ImportModule("QuestieDB")\n'
        'local ZoneDB = QuestieLoader:ImportModule("ZoneDB")\n'
        f"function {module}:Load()\n{aliases}\n    return {{\n{records}\n    }}\nend\n{extra}"
    )


QUEST_ALIASES = """    local questKeys = QuestieDB.questKeys
    local raceIDs = QuestieDB.raceKeys
    local zoneIDs = ZoneDB.zoneIDs"""

DELTA_QUEST = """        [50] = { -- Windshaper Start : https://wowhead.com/forever/quest=50/windshaper-start
            [questKeys.name] = "Windshaper Start",
            [questKeys.startedBy] = {{120}},
            [questKeys.finishedBy] = {{120}},
            [questKeys.requiredLevel] = 1,
            [questKeys.questLevel] = 2,
            [questKeys.requiredRaces] = raceIDs.ALL_HORDE,
            [questKeys.objectivesText] = {"Never kept text."},
            [questKeys.objectives] = {nil, nil, {{300}}},
            [questKeys.zoneOrSort] = zoneIDs.ZEPHYR,
        },
        [51] = { -- an Alliance Skyborne quest
            [questKeys.name] = "Highborne Start",
            [questKeys.startedBy] = {{109}},
            [questKeys.finishedBy] = {{109}},
            [questKeys.requiredRaces] = raceIDs.SKYBORNE_ALLIANCE,
            [questKeys.zoneOrSort] = zoneIDs.ZONE_B,
        },
        [52] = { -- Windshaper only
            [questKeys.name] = "Windshaper Errand",
            [questKeys.startedBy] = {{100}},
            [questKeys.finishedBy] = {{100}},
            [questKeys.requiredRaces] = raceIDs.SKYBORNE_HORDE,
            [questKeys.zoneOrSort] = zoneIDs.ZONE_A,
        },
        [53] = { -- a race bit that is neither Classic nor Skyborne
            [questKeys.name] = "Odd Race",
            [questKeys.startedBy] = {{100}},
            [questKeys.finishedBy] = {{100}},
            [questKeys.requiredRaces] = 256,
            [questKeys.zoneOrSort] = zoneIDs.ZONE_A,
        },
        [1] = { -- changes a level
            [questKeys.questLevel] = 5,
        },"""

TRACE_QUEST = """        [1] = {
            [questKeys.finishedBy_add] = {{102}},
            [questKeys.startedBy_add] = {{100}}, -- already there: no change
        },
        [2] = {
            [questKeys.startedBy_add] = {nil,{200}},
        },"""

AUTHORED_QUEST = """        [2] = { -- Orc Lessons
            [questKeys.requiredLevel] = 9,
            [questKeys.requiredRaces] = raceIDs.ORC + raceIDs.TROLL,
        },
        [1] = {
            [questKeys.preQuestSingle_remove] = {40},
            [questKeys.objectivesText] = {Questie.UNKNOWN_TEXT},
        },
        [3] = {
            [questKeys.zoneOrSort] = zoneIDs.NO_SUCH_ZONE,
            [questKeys.name] = string.format("%s", "x"),
            [questKeys.objectives] = {{{259377,nil,Questie.ICON_TYPE_TALK}}},
            [questKeys.sourceItemId] = function() return 1 end,
            [questKeys.requiredLevel] = 1 .. 2,
            [questKeys.noSuchField] = 1,
            [questKeys.startedBy] = {{109}, @@@},
        },"""

AUTHORED_EXTRA = """
-- Dynamic Corrections: selected from character facts at runtime.
function ForeverQuestFixes:LoadDynamic()
    local questKeys = QuestieDB.questKeys
    if UnitFactionGroup("Player") == "Horde" then
        return { [1] = { [questKeys.questLevel] = 40 } }
    end
    return {}
end
"""

NPC_ALIASES = """    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs
    local npcFlags = QuestieDB.npcFlags"""

DELTA_NPC = """        [120] = { -- Windshaper Elder
            [npcKeys.name] = "Windshaper Elder",
            [npcKeys.spawns] = {[zoneIDs.ZEPHYR] = {{10.5, 20.5}}},
            [npcKeys.friendlyToFaction] = "H",
            [npcKeys.npcFlags] = npcFlags.QUEST_GIVER + npcFlags.VENDOR,
        },"""

OBJECT_ALIASES = """    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs"""

ITEM_ALIASES = "    local itemKeys = QuestieDB.itemKeys"


def add_forever_layers(root: Path) -> Path:
    """Add the enum, meta and provider files to a checkout made by make_checkout (with canonical part positions)."""
    enum = root / "src" / "corrections" / "enum"
    enum.mkdir(parents=True)
    for name, text in ENUM.items():
        (enum / name).write_text(text, encoding="utf-8")
    meta = root / "src" / "meta"
    meta.mkdir(parents=True)
    for kind, (entity, names, shapes) in META.items():
        (meta / f"{kind}Meta.lua").write_text(meta_text(entity, names, shapes), encoding="utf-8")
    forever = root / "src" / "corrections" / "Forever"
    (forever / "generated").mkdir(parents=True)
    (forever / "traces").mkdir()
    files = {
        "generated/foreverBaseQuest.lua": provider("ForeverBaseQuest", QUEST_ALIASES, DELTA_QUEST),
        "generated/foreverBaseNpc.lua": provider("ForeverBaseNpc", NPC_ALIASES, DELTA_NPC),
        "generated/foreverBaseObject.lua": provider("ForeverBaseObject", OBJECT_ALIASES, ""),
        "generated/foreverBaseItem.lua": provider("ForeverBaseItem", ITEM_ALIASES, ""),
        "traces/foreverQuestTraces.lua": provider("ForeverQuestTraces", QUEST_ALIASES, TRACE_QUEST),
        "traces/foreverNpcTraces.lua": provider("ForeverNpcTraces", NPC_ALIASES, ""),
        "traces/foreverObjectTraces.lua": provider("ForeverObjectTraces", OBJECT_ALIASES, ""),
        "traces/foreverItemTraces.lua": provider("ForeverItemTraces", ITEM_ALIASES, ""),
        "foreverQuestFixes.lua": provider(
            "ForeverQuestFixes",
            QUEST_ALIASES,
            AUTHORED_QUEST,
            AUTHORED_EXTRA,
            head="QuestieCorrections.itemObjectiveFirst[91317] = true\n",
        ),
        "foreverNPCFixes.lua": provider("ForeverNpcFixes", NPC_ALIASES, ""),
        "foreverObjectFixes.lua": provider("ForeverObjectFixes", OBJECT_ALIASES, ""),
        "foreverItemFixes.lua": provider("ForeverItemFixes", ITEM_ALIASES, ""),
    }
    for name, text in files.items():
        (forever / name).write_text(text, encoding="utf-8")
    zones = root / "support" / "Forever" / "Zones" / "areaIdToUiMapId.lua"
    zones.write_text(zones.read_text(encoding="utf-8").replace("[505] = 1411,", "[505] = 1411,\n    [507] = 2521,"), encoding="utf-8")
    return root


def make_layered_checkout(root: Path) -> Path:
    """make_checkout with canonical part positions, a few quests of its own and the Forever layers on top."""
    keys = keys_text("quest", QUEST_LAYOUT, CANONICAL_PARTS)
    make_checkout(root, quests=LAYER_QUESTS, quest_keys=keys)
    return add_forever_layers(root)


__all__ = ["NPCS", "add_forever_layers", "make_layered_checkout"]
