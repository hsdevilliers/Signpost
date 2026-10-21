import contextlib
import io
import unittest
from pathlib import Path

import audit_quests as audit
import guide_travel
from signpost_tools import guidefile, svfiles
from signpost_tools.luawriter import write_lua
from tests.guide_fixtures import MAPS, NPCS, TRAVEL, TempProject, guide_lua, write_pack

NPC_FILE = {
    **NPCS,
    1003: {"n": "Islander", "p": [[40, 50, 50]]},  # on the Isle, a zone the guide never visits
}


def quest(name, zone=10, **fields):
    record = {"n": name, "l": 1, "r": 1, "side": "Horde", "s": {"npc": [1001]}, "e": {"npc": [1001]}, **fields}
    if zone is not None:  # a quest filed under a class or profession sort has no zone: it belongs where its giver stands
        record["zone"] = zone
    return record


# 101 is in the route, 103 is #skipquest-ed; the rest show every other way a quest can be absent from it.
QUESTS = {
    101: quest("First Steps"),
    102: quest("Left Out", l=2),
    103: quest("Skipped Quest"),
    104: quest("Daily Chore", repeatable=True),
    105: quest("Too High", l=25, r=25),
    106: quest("Orc Only", races=2),
    107: quest("Far Away", zone=40, s={"npc": [1003]}, e={"npc": [1003]}),
    108: quest("Needs Skill", skill=[393, 1]),
    109: quest("Lunar Fest", zone=None, sort=366),
    110: quest("Needs The Orc", preSingle=[106]),
    111: quest("Far Away By Its Giver", zone=None, s={"npc": [1003]}, e={"npc": [1003]}),
}

GUIDE = "#chapter 1-10 West\n#skipquest 103 >> not on this route\nstep\n  .goto 10,40,40\n  .accept 101\nstep\n  .goto 10,40,40\n  .turnin 101\n"


def gossip(npc, available, active=(), name=None):
    state = {
        "npc": {"id": npc, "name": name or f"NPC {npc}", "pos": {"map": 10, "x": 40.5, "y": 41.25}},
        "available": [{"questID": q, "title": QUESTS.get(q, {}).get("n", f"Quest {q}")} for q in available],
        "active": [{"questID": q, "title": QUESTS.get(q, {}).get("n")} for q in active],
    }
    return {"e": "GOSSIP_SHOW", "s": state, "time": 1}


# The recorder packs an event's arguments as { n = count, [1] = first }: integer keys in a real file.
def accepted(quest_id, title=None, npc=None):
    state = {"npc": npc or {"pos": {"map": 10, "x": 40.5, "y": 41.25}}}
    if title:
        state["quest"] = {"info": {"title": title}}
    return {"e": "QUEST_ACCEPTED", "a": {1: quest_id, "n": 1}, "s": state}


def turned_in(quest_id):
    return {"e": "QUEST_TURNED_IN", "a": {1: quest_id, 2: 40, 3: 0, "n": 3}, "s": {"npc": {"id": 1001, "name": "Questgiver"}}}


def detail(quest_id, title, npc=None):
    return {"e": "QUEST_DETAIL", "a": {1: 0, "n": 1}, "s": {"questID": quest_id, "title": title, "npc": npc or {}}}


EVENTS = [
    gossip(1001, [101, 102, 104], active=[103], name="Questgiver"),
    detail(106, "Orc Only", {"id": 1001, "name": "Questgiver"}),
    accepted(101, "First Steps"),
    {
        "e": "QUEST_GREETING",
        "s": {"npc": {"id": 1001, "name": "Questgiver"}, "available": [{"title": "Too High", "info": [False, 0, False, False, 105]}], "active": []},
    },
    turned_in(101),
    detail(999, "Brand New", {"id": 1005, "name": "Newcomer", "pos": {"map": 10, "x": 41.5, "y": 42.1}}),
    accepted(108),
    accepted(109),
    accepted(110),
    accepted(107),
    accepted(111),
    {"e": "ZONE_CHANGED"},
    "junk",
]
LEARNED = {
    "quests": {101: {"start": {"npc": 1001}, "finish": {"npc": 1001}, "t": 5}, 888: {"start": {"obj": 77}, "t": 6}},
    "npcs": {1001: {"n": "Questgiver", "map": 10, "x": 40.5, "y": 41.25}},
}


class CollectTest(unittest.TestCase):
    def setUp(self):
        self.seen = audit.collect(EVENTS, LEARNED)

    def test_every_kind_of_record_is_read_with_how_it_was_seen(self):
        self.assertEqual(sorted(self.seen), [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 888, 999])
        self.assertEqual(self.seen[101].how, {"offered", "accepted", "turned in", "learned"})
        self.assertEqual(self.seen[102].how, {"offered"})
        self.assertEqual(self.seen[103].how, {"in the log"})  # listed as already in the log at a visit
        self.assertEqual(self.seen[105].how, {"offered"})  # a greeting's info values carry the quest ID
        self.assertEqual(self.seen[106].how, {"opened"})
        self.assertEqual(self.seen[110].how, {"accepted"})

    def test_titles_givers_and_places(self):
        self.assertEqual(self.seen[101].titles, {"First Steps"})
        self.assertEqual(self.seen[101].givers, {"Questgiver (1001)"})
        self.assertEqual(self.seen[999].title, "Brand New")
        self.assertEqual(self.seen[999].givers, {"Newcomer (1005)"})
        self.assertEqual(self.seen[999].spot, (10, 41.5, 42.1))
        self.assertEqual(self.seen[888].givers, {"object 77"})  # a quest only the learned records know
        self.assertEqual(self.seen[110].spot, (10, 40.5, 41.25))  # an accept with no dialog still knows where the player stood

    def test_the_first_place_a_quest_was_seen_is_kept(self):
        first = {"id": 1, "name": "A", "pos": {"map": 10, "x": 1.0, "y": 2.0}}
        events = [detail(500, "Seen Twice", first), accepted(500, npc={"pos": {"map": 20, "x": 3.0, "y": 4.0}})]
        self.assertEqual(audit.collect(events)[500].spot, (10, 1.0, 2.0))
        # a position without a map or a coordinate is no position
        self.assertIsNone(audit.collect([detail(501, "Nowhere", {"id": 1, "pos": {"map": 10}})])[501].spot)

    def test_the_arguments_of_a_json_copy_have_string_keys_and_work_too(self):
        event = {"e": "QUEST_ACCEPTED", "a": {"1": 4641, "n": 1}}
        self.assertEqual(sorted(audit.collect([event])), [4641])

    def test_nothing_recorded_is_nothing_seen(self):
        self.assertEqual(audit.collect([], None), {})
        self.assertEqual(audit.collect([{"e": "QUEST_ACCEPTED", "a": {"n": 0}}, {"e": "QUEST_DETAIL", "s": {"questID": 0}}], {"quests": {}}), {})
        self.assertEqual(sorted(audit.collect([], {"quests": [{"start": {"npc": 5}}]})), [1])  # a table keyed exactly 1..n parses as a list


class AuditCase(TempProject):
    def setUp(self):
        super().setUp()
        self.files({"Guides/Test.lua": guide_lua(GUIDE, levels=(1, 20))})  # registered to 20, but its last chapter ends at 10
        write_pack(self.pack_dir, {"maps": MAPS, "quests": QUESTS, "npcs": NPC_FILE, "travel": TRAVEL})
        self.pack = guide_travel.load_pack(self.pack_dir)
        self.project = guidefile.load_project(self.root)

    def run_audit(self, events=EVENTS, learned=LEARNED, guides=None):
        return audit.audit(events, learned, self.project, self.pack, guides)


class AuditTest(AuditCase):
    def test_a_quest_the_pack_does_not_know_is_a_data_gap(self):
        result = self.run_audit()
        self.assertEqual(result.data_gaps, [888, 999])
        self.assertEqual(result.events, len(EVENTS))
        self.assertEqual(result.learned, 2)

    def test_a_guide_sorts_the_quests_its_character_can_take(self):
        (guide,) = self.run_audit().guides
        self.assertEqual(guide.covered, [101])
        self.assertEqual(guide.skipped, {103: "not on this route"})
        self.assertEqual(
            guide.out_of_scope,
            {
                104: "repeatable (a daily or a repeat)",
                105: "needs level 25; the guide's last chapter is level 10",
                108: "needs a profession skill",
                109: "a seasonal or world event",
                110: "a prerequisite is closed to this character",
            },
        )
        self.assertEqual(guide.others, [106])  # an Orc's quest, and the guide is a Troll's
        self.assertEqual(guide.elsewhere, [107, 111])  # the route never goes to the Isle (by the quest's zone, or by where its giver stands)
        self.assertEqual(guide.missing, [102])  # nothing explains it
        self.assertEqual((guide.top, guide.guide), (10, "test-guide"))

    def test_a_quest_in_a_zone_the_route_visits_is_missing_and_not_elsewhere(self):
        quests = {**QUESTS, 107: {**QUESTS[107], "s": {"npc": [1001]}, "zone": 10}}
        write_pack(self.pack_dir, {"maps": MAPS, "quests": quests, "npcs": NPC_FILE, "travel": TRAVEL})
        self.pack = guide_travel.load_pack(self.pack_dir)
        (guide,) = self.run_audit().guides
        self.assertIn(107, guide.missing)  # now in a zone the route visits, and not in it
        self.assertNotIn(107, guide.elsewhere)

    def test_only_the_guides_asked_for_are_audited(self):
        self.files({"Guides/Other.lua": guide_lua(GUIDE, gid="other-guide")})
        self.project = guidefile.load_project(self.root)
        self.assertEqual([g.guide for g in self.run_audit().guides], ["other-guide", "test-guide"])
        self.assertEqual([g.guide for g in self.run_audit(guides=["other-guide"]).guides], ["other-guide"])

    def test_the_report_names_each_group_and_each_gap(self):
        result = self.run_audit()
        text = "\n".join(audit.report(result, self.pack.table("quests")))
        self.assertIn("== 13 distinct quest(s) seen in 13 recorded event(s) and 2 learned record(s)", text)
        self.assertIn("== data gaps: 2 of them are not in the data pack", text)
        self.assertIn('999 "Brand New": opened, given by Newcomer (1005) at map 10 41.5,42.1', text)
        self.assertIn("888: learned, given by object 77", text)
        self.assertIn("1 in the route, 1 skipped on purpose, 5 out of scope, 1 NOT in the route; 1 are other characters' and 2 are in zones", text)
        self.assertIn('NOT ROUTED   102 "Left Out" (level 2): offered; left out by the planner or the drafter', text)
        self.assertIn('skipped      103 "Skipped Quest" (level 1): not on this route', text)
        self.assertIn('out of scope 104 "Daily Chore" (level 1): repeatable (a daily or a repeat)', text)
        self.assertNotIn("Orc Only", text)  # another character's quest is counted, not listed
        self.assertNotIn("Far Away", text)  # nor is one in a zone the route never visits


class CommandLineTest(AuditCase):
    def write_saved_variables(self, db):
        folder = Path(self.pack_dir).parent / "copied"
        folder.mkdir(exist_ok=True)
        write_lua(folder / svfiles.FILE_NAME, ["test"], [(svfiles.ACCOUNT_VAR, db)])
        return folder

    def run_main(self, folder, *extra):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = audit.main(["--root", str(self.root), "--pack", str(self.pack_dir), "--from", str(folder), *extra])
        return code, out.getvalue()

    def test_a_copied_saved_variables_folder_is_read_and_reported(self):
        folder = self.write_saved_variables({"eventLog": EVENTS, "learned": LEARNED})
        code, text = self.run_main(folder)
        self.assertEqual(code, 0)
        self.assertIn("== data gaps: 2 of them are not in the data pack", text)
        self.assertIn("NOT ROUTED   102", text)
        code, text = self.run_main(folder, "--strict")
        self.assertEqual(code, 1)  # the pack lacks a quest the game offered
        code, text = self.run_main(folder, "--guide", "test-guide", "--strict")
        self.assertEqual(code, 1)
        self.assertEqual(self.run_main(folder, "--guide", "no-such-guide")[0], 1)

    def test_a_pack_that_knows_everything_is_strict_clean(self):
        folder = self.write_saved_variables({"eventLog": [gossip(1001, [101, 102])], "learned": {"quests": {}}})
        code, text = self.run_main(folder, "--strict")
        self.assertEqual(code, 0)
        self.assertIn("== data gaps: 0 of them are not in the data pack", text)

    def test_nothing_recorded_says_how_to_record(self):
        folder = self.write_saved_variables({"ping": {"text": "pong"}})
        code, text = self.run_main(folder)
        self.assertEqual(code, 0)
        self.assertIn("no quests recorded", text)

    def test_no_pack_is_an_error(self):
        folder = self.write_saved_variables({"eventLog": [gossip(1001, [101])]})
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = audit.main(["--root", str(self.root), "--pack", str(Path(self.pack_dir).parent / "nowhere"), "--from", str(folder)])
        self.assertEqual(code, 1)
        self.assertIn("audit_quests needs the data pack", out.getvalue())


if __name__ == "__main__":
    unittest.main()
