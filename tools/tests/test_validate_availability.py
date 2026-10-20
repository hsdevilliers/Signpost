import unittest

import validate_availability as validate
from signpost_tools.availability import CLASS_BITS, Character, Rules, race_bit
from tests.test_availability import QUESTS


def rules():
    return Rules(QUESTS, Character("Horde", race_bit("Troll", "Horde"), CLASS_BITS["HUNTER"]))


def gossip(npc, available, active=(), level=None, completed=None):
    state = {
        "npc": {"id": npc, "name": f"NPC {npc}"},
        "available": [{"questID": q} for q in available],
        "active": [{"questID": q} for q in active],
    }
    if level is not None or completed is not None:
        state["standing"] = {"level": level, "completed": completed}
    return {"e": "GOSSIP_SHOW", "s": state, "time": 1}


def accepted(quest):
    return {"e": "QUEST_ACCEPTED", "a": {"1": quest, "n": 1}}


def turned_in(quest):
    return {"e": "QUEST_TURNED_IN", "a": {"1": quest, "n": 3}}


class ReplayTest(unittest.TestCase):
    def test_the_session_recorded_at_gornek_agrees_with_the_rules(self):
        events = [
            gossip(3143, [788, 97279]),  # first visit, nothing done
            accepted(4641),
            gossip(3143, [97279], active=[4641]),  # Cutting Teeth is not offered while Your Place in the World is in the log
            turned_in(4641),
            gossip(3143, [788, 97279]),  # handed over with the turn-in
        ]
        visits = validate.replay(events, rules())
        self.assertEqual([v.agrees for v in visits], [True, True, True])
        self.assertEqual([v.done for v in visits], [0, 0, 1])

    def test_a_quest_the_rules_offer_and_the_game_did_not_is_a_data_gap(self):
        # the rules without the Vile Familiars prerequisite would offer the Medallion at level 1
        quests = {**QUESTS, 794: {**QUESTS[794], "preSingle": []}}
        visits = validate.replay([gossip(3145, [])], Rules(quests, rules().me))
        self.assertEqual(visits[0].missing, {794})
        self.assertFalse(visits[0].agrees)
        self.assertIn("the rules offer", "\n".join(validate.report(visits, quests, "x")))

    def test_a_quest_the_game_offered_and_the_rules_do_not_is_a_wrong_rule(self):
        visits = validate.replay([gossip(3145, [792], level=1)], rules())  # 792 needs level 2 in the pack
        self.assertEqual(visits[0].extra, {792})
        self.assertEqual(visits[0].missing, set())

    def test_the_recorded_level_and_completed_quests_win_over_the_replay(self):
        events = [gossip(3145, [792, 794], level=2, completed=[792])]  # 792 done: the game offers the Medallion only
        events[0]["s"]["available"] = [{"questID": 794}]
        visits = validate.replay(events, rules())
        self.assertTrue(visits[0].agrees)
        self.assertEqual((visits[0].level, visits[0].done), (2, 1))
        self.assertEqual(visits[0].notes, [])

    def test_levels_come_from_level_ups_in_an_older_log(self):
        events = [{"e": "PLAYER_LEVEL_UP", "a": {"1": 2, "n": 1}}, gossip(3145, [792])]
        visits = validate.replay(events, rules())
        self.assertTrue(visits[0].agrees)
        self.assertEqual(visits[0].level, 2)

    def test_a_greeting_lists_its_quests_in_the_info_values(self):
        event = {
            "e": "QUEST_GREETING",
            "s": {"npc": {"id": 3143, "name": "Gornek"}, "available": [{"title": "Cutting Teeth", "info": [False, 0, False, False, 788]}], "active": []},
        }
        self.assertEqual(validate.replay([event], rules())[0].observed, {788})

    def test_events_without_an_npc_or_of_other_kinds_are_ignored(self):
        events = [{"e": "ZONE_CHANGED"}, {"e": "GOSSIP_SHOW", "s": {"npc": {"pos": {}}}}, "junk", {"e": "GOSSIP_SHOW"}]
        self.assertEqual(validate.replay(events, rules()), [])


if __name__ == "__main__":
    unittest.main()
