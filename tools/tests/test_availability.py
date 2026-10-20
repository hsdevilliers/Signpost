import unittest

from signpost_tools import availability
from signpost_tools.availability import CLASS_BITS, Character, Rules, race_bit

HORDE = 8589934770  # every Horde race, Skyborne included

# The Valley of Trials as the pack and the game's own offers describe it: Gornek (3143) offers Cutting Teeth and Wayward
# Weapons at once, stops offering Cutting Teeth while Your Place in the World is in the log and hands it over when that
# is turned in (recorded in play, 2026-10-20); Zureetha (3145) offers Vile Familiars from level 2, and the Burning Blade
# Medallion only after it (the Warlock has its own Vile Familiars, 1499).
QUESTS = {
    4641: {"n": "Your Place In The World", "r": 1, "l": 1, "races": 130, "next": 788, "side": "Horde", "s": {"npc": [10176]}, "e": {"npc": [3143]}},
    788: {"n": "Cutting Teeth", "r": 1, "l": 2, "races": HORDE, "side": "Horde", "s": {"npc": [3143]}, "e": {"npc": [3143]}},
    789: {"n": "Sting of the Scorpid", "r": 1, "l": 3, "races": HORDE, "side": "Horde", "preSingle": [788], "s": {"npc": [3143]}},
    97279: {"n": "Wayward Weapons", "r": 1, "l": 2, "races": HORDE, "side": "Horde", "s": {"npc": [3143]}},
    792: {"n": "Vile Familiars", "r": 2, "l": 4, "races": HORDE, "classes": 1247, "side": "Horde", "next": 794, "s": {"npc": [3145]}},
    1499: {"n": "Vile Familiars", "r": 1, "l": 4, "races": HORDE, "classes": 256, "side": "Horde", "next": 794, "preSingle": [1485], "s": {"npc": [5765]}},
    1485: {"n": "Warlock Beginnings", "r": 1, "l": 1, "races": HORDE, "classes": 256, "side": "Horde", "s": {"npc": [5765]}},
    794: {"n": "Burning Blade Medallion", "r": 1, "l": 5, "races": HORDE, "side": "Horde", "preSingle": [792, 1499], "s": {"npc": [3145]}},
    235: {"n": "Either", "r": 5, "exclusive": [742], "side": "Horde", "races": HORDE},
    742: {"n": "Or", "r": 5, "exclusive": [235], "side": "Horde", "races": HORDE},
    208: {"n": "All Three", "r": 1, "preGroup": [188, 193], "side": "Horde", "races": HORDE},
    188: {"n": "First", "r": 1, "side": "Horde", "races": HORDE},
    193: {"n": "Second", "r": 1, "side": "Horde", "races": HORDE},
    339: {"n": "Sub Quest", "r": 1, "parent": 338, "side": "Horde", "races": HORDE},
    338: {"n": "Parent", "r": 1, "side": "Horde", "races": HORDE},
    500: {"n": "Alliance Only", "r": 1, "side": "Alliance", "races": 77},
    501: {"n": "After Alliance", "r": 1, "preSingle": [500], "side": "Horde", "races": HORDE},
    502: {"n": "Needs Anvil", "r": 1, "skill": [164, 1], "side": "Horde", "races": HORDE},
    503: {"n": "Festival", "r": 1, "sort": 366, "side": "Horde", "races": HORDE},
    504: {"n": "Daily", "r": 1, "repeatable": True, "side": "Horde", "races": HORDE},
    505: {"n": "Needs A Stranger", "r": 1, "preSingle": [9999], "side": "Horde", "races": HORDE},
    506: {"n": "Hunter Chain", "r": 1, "sort": 261, "side": "Horde", "races": HORDE},
    507: {"n": "Retired", "r": 1, "maxLevel": 5, "side": "Horde", "races": HORDE},
}


def troll_hunter():
    return Rules(QUESTS, Character("Horde", race_bit("Troll", "Horde"), CLASS_BITS["HUNTER"]))


def codes(rules, qid, level, done=(), active=()):
    return [reason.code for reason in rules.unmet(qid, level, done, active)]


class WhoTest(unittest.TestCase):
    def test_race_and_class_bits(self):
        self.assertEqual(race_bit("Troll", "Horde"), 128)
        self.assertEqual(race_bit("Skyborne", "Horde"), 1 << 33)
        self.assertEqual(race_bit("Skyborne", "Alliance"), 1 << 32)
        self.assertIsNone(race_bit("Pandaren", "Horde"))
        self.assertIsNone(race_bit(None, "Horde"))
        self.assertEqual(availability.class_bit("druid"), 1024)

    def test_faction_race_and_class_close_a_quest(self):
        rules = troll_hunter()
        self.assertEqual(codes(rules, 500, 1), ["faction"])  # the first reason who-it-is gives
        self.assertEqual(codes(rules, 4641, 1), [])  # Orc and Troll
        orc_only = Rules(QUESTS, Character("Horde", race_bit("Tauren", "Horde"), CLASS_BITS["DRUID"]))
        self.assertEqual(codes(orc_only, 4641, 1), ["race"])
        self.assertEqual(codes(rules, 792, 2), [])  # everyone but the Warlock
        warlock = Rules(QUESTS, Character("Horde", 128, CLASS_BITS["WARLOCK"]))
        self.assertEqual(codes(warlock, 792, 2), ["class"])

    def test_a_class_quest_without_a_mask_is_filed_under_its_class_sort(self):
        rules = troll_hunter()
        self.assertEqual(codes(rules, 506, 1), [])
        druid = Rules(QUESTS, Character("Horde", 128, CLASS_BITS["DRUID"]))
        self.assertEqual(codes(druid, 506, 1), ["class"])

    def test_an_unknown_race_is_not_checked(self):
        rules = Rules(QUESTS, Character("Horde", None, None))
        self.assertEqual(codes(rules, 4641, 1), [])


class PrerequisiteTest(unittest.TestCase):
    def test_another_class_alternative_does_not_satisfy_a_prerequisite(self):
        # the first-step bug: 1499 is the Warlock's Vile Familiars; it must not make the Medallion available at level 1
        rules = troll_hunter()
        self.assertIsNotNone(rules.never(1499))
        self.assertIsNone(rules.never(794))
        self.assertEqual(codes(rules, 794, 1), ["prerequisite"])
        reason = rules.unmet(794, 1)[0]
        self.assertEqual(reason.quests, (792,))  # only the alternative this character can do is named

    def test_the_valley_of_trials_at_zureetha(self):
        rules = troll_hunter()
        self.assertEqual(codes(rules, 792, 1), ["level"])
        self.assertEqual(codes(rules, 792, 2), [])
        self.assertEqual(codes(rules, 794, 2), ["prerequisite"])
        self.assertEqual(codes(rules, 794, 2, done={792}), [])

    def test_the_warlock_takes_its_own_chain(self):
        warlock = Rules(QUESTS, Character("Horde", 128, CLASS_BITS["WARLOCK"]))
        self.assertEqual(codes(warlock, 794, 5), ["prerequisite"])
        self.assertEqual(codes(warlock, 794, 5, done={1499}), [])
        self.assertEqual(codes(warlock, 1499, 1), ["prerequisite"])
        self.assertEqual(codes(warlock, 1499, 1, done={1485}), [])

    def test_a_quest_every_alternative_of_which_is_closed_is_impossible(self):
        rules = troll_hunter()
        self.assertEqual(rules.never(501).code, "impossible")  # its only prerequisite is an Alliance quest
        self.assertEqual(codes(rules, 501, 1), ["impossible"])
        self.assertEqual(rules.never(500).code, "faction")

    def test_all_of_a_group_are_needed(self):
        rules = troll_hunter()
        self.assertEqual(codes(rules, 208, 1, done={188}), ["prerequisite"])
        self.assertEqual(codes(rules, 208, 1, done={188, 193}), [])

    def test_a_prerequisite_the_data_does_not_know_is_a_warning(self):
        rules = troll_hunter()
        reasons = rules.unmet(505, 1)
        self.assertEqual([r.code for r in reasons], ["unknown-prerequisite"])
        self.assertEqual(reasons[0].severity, "warning")
        self.assertIsNone(rules.never(505))
        self.assertTrue(rules.offered(505, 1))  # a warning does not close the quest

    def test_chain_and_cycles(self):
        quests = {1: {"n": "A", "preSingle": [2], "side": "Horde"}, 2: {"n": "B", "preSingle": [1], "side": "Horde"}}
        rules = Rules(quests, Character("Horde"))
        self.assertIsNone(rules.never(1))  # a cycle is not called impossible, and does not loop


class ChainTest(unittest.TestCase):
    def test_gornek_offers_what_the_game_offered(self):
        rules = troll_hunter()
        # first visit, nothing done: Cutting Teeth and Wayward Weapons (Sting of the Scorpid needs Cutting Teeth)
        offered = [q for q in (788, 789, 97279) if rules.offered(q, 1)]
        self.assertEqual(offered, [788, 97279])
        # Your Place in the World in the log: Gornek offers only Wayward Weapons
        offered = [q for q in (788, 789, 97279) if rules.offered(q, 1, active={4641})]
        self.assertEqual(offered, [97279])
        self.assertEqual(codes(rules, 788, 1, active={4641}), ["chain"])
        # turned in: Cutting Teeth is handed over
        offered = [q for q in (788, 789, 97279) if rules.offered(q, 1, done={4641})]
        self.assertEqual(offered, [788, 97279])

    def test_exclusive_quests_close_each_other(self):
        rules = troll_hunter()
        self.assertEqual(codes(rules, 742, 5), [])
        self.assertEqual(codes(rules, 742, 5, done={235}), ["locked"])
        self.assertEqual(codes(rules, 742, 5, active={235}), ["locked"])

    def test_a_sub_quest_needs_its_parent_in_the_log(self):
        rules = troll_hunter()
        self.assertEqual(codes(rules, 339, 1), ["parent"])
        self.assertEqual(codes(rules, 339, 1, active={338}), [])


class OtherTest(unittest.TestCase):
    def test_levels(self):
        rules = troll_hunter()
        self.assertEqual(codes(rules, 235, 4), ["level"])
        self.assertEqual(codes(rules, 235, 5), [])
        self.assertEqual(codes(rules, 507, 6), ["level"])  # not offered above level 5
        self.assertEqual(codes(rules, 507, 5), [])

    def test_skill_event_repeatable_and_unknown(self):
        rules = troll_hunter()
        self.assertEqual(codes(rules, 502, 1), ["skill"])
        self.assertEqual([r.code for r in rules.unmet(502, 1, skills={164})], [])
        self.assertEqual(codes(rules, 503, 1), ["event"])
        self.assertEqual(codes(rules, 504, 1), ["repeatable"])
        self.assertEqual(codes(rules, 123456, 1), ["unknown"])
        mine = Rules(QUESTS, Character("Horde", 128, 4, frozenset({164})))
        self.assertEqual(codes(mine, 502, 1), [])

    def test_the_real_pack_agrees_with_the_game_when_it_is_there(self):
        # skipped without the private pack (CI)
        from pathlib import Path

        import guide_travel
        from signpost_tools import datapack

        pack = guide_travel.default_pack_dir(Path(__file__).resolve().parents[2])
        if pack is None:
            self.skipTest("no data pack next to the checkout")
        quests = datapack.read_table(pack, "quests")
        rules = Rules(quests, Character("Horde", race_bit("Troll", "Horde"), CLASS_BITS["HUNTER"]))
        gornek = [q for q, r in quests.items() if 3143 in (r.get("s") or {}).get("npc", [])]
        self.assertEqual([q for q in gornek if rules.offered(q, 1)], sorted(q for q in gornek if rules.offered(q, 1)))
        for quest in (788, 97279):
            self.assertTrue(rules.offered(quest, 1), quest)
        self.assertFalse(rules.offered(794, 1))
        self.assertFalse(rules.offered(789, 1))  # needs Cutting Teeth


if __name__ == "__main__":
    unittest.main()
