import dataclasses
import unittest

import guide_travel
import planner as engine
from signpost_tools import availability
from tests.guide_fixtures import MAPS, TRAVEL, TempProject, write_pack
from tests.test_guide_draft import HOME, NPCS, QUESTS, START

ITEMS = {9999: {"n": "Thing"}, 9998: {"n": "Elite Drop", "drops": [3002]}, 9997: {"n": "Stone", "drops": [3002], "objDrops": [1]}}
HORDE = availability.Character("Horde", availability.race_bit("Orc", "Horde"), availability.class_bit("HUNTER"))


class PlannerCase(TempProject):
    def planner(self, quests=None, character=HORDE, mandatory=(), **settings):
        base = dict(cap=6, skip_unprofitable=False, hub_radius=150.0)
        base.update(settings)
        pack_dir = write_pack(self.pack_dir, {"maps": MAPS, "quests": quests or QUESTS, "npcs": NPCS, "travel": TRAVEL, "items": ITEMS})
        pack = guide_travel.load_pack(pack_dir)
        world = guide_travel.World(pack, [], "Horde")
        return engine.Planner.build(pack, world, character, engine.Settings(**base), mandatory=mandatory)

    def start(self, pl):
        return engine.start_hub_for(pl)


class BuildTest(PlannerCase):
    def test_only_what_this_character_may_take_is_routed_and_the_rest_is_accounted_for(self):
        pl = self.planner()
        for qid, reason in (
            (204, "other class"),
            (205, "repeatable"),
            (206, "seasonal or event"),
            (207, "other race"),
            (208, "needs a profession skill"),
            (209, "above the level cap"),
            (214, "other faction"),
        ):
            self.assertNotIn(qid, pl.quests, qid)
            self.assertIn(qid, pl.dropped.get(reason, []), (qid, reason))
        self.assertTrue({201, 202, 203} <= set(pl.quests))

    def test_a_quest_whose_prerequisite_cannot_be_routed_is_out_with_it(self):
        pl = self.planner(quests={**QUESTS, 240: {"n": "After A Warlock Quest", "r": 1, "l": 1, "preSingle": [204], **HOME}})
        self.assertNotIn(240, pl.quests)  # 204 is a hunter's own class quest here? it is another class's: 240 is never offered
        self.assertTrue(any(240 in ids for ids in pl.dropped.values()))

    def test_hardcore_leaves_out_elite_quests_and_a_normal_route_tags_them_optional(self):
        normal = self.planner()
        self.assertTrue(normal.quests[220].optional)
        hardcore = self.planner(hardcore=True)
        self.assertNotIn(220, hardcore.quests)
        self.assertIn(220, hardcore.dropped["HARDCORE: needs an elite or boss kill"])

    def test_hubs_group_places_within_the_radius_and_have_names(self):
        pl = self.planner(hub_radius=150.0)
        first = pl.quests[201].start_hubs
        self.assertEqual(len(first), 1)
        self.assertTrue(pl.hubs[first[0]].label)
        wide = self.planner(hub_radius=5000.0)  # the whole map in one hub
        self.assertLess(len(wide.hubs), len(pl.hubs))

    def test_a_class_quest_is_never_left_out_for_being_slow(self):
        pl = self.planner(skip_unprofitable=True, profit_threshold=1000.0, mandatory=(217,))
        self.assertTrue(pl.quests[217].kept)
        self.assertFalse(pl.quests[203].kept and pl.quests[203].rate >= 1000.0)


class RulesTest(PlannerCase):
    def test_the_game_rules_hold_on_every_edge(self):
        pl = self.planner()
        hub = pl.quests[201].start_hubs[0]
        st = pl.start(hub)
        offered = {q.id for q in pl.window if pl.offered(q, st.level, st.done, st.active, st.gone)}
        self.assertIn(201, offered)
        self.assertNotIn(202, offered)  # needs 201
        self.assertNotIn(223, offered)  # level 9 against a character of level 1
        child = pl.visit(st, hub)
        self.assertIsNotNone(child)
        actions = [(a.kind, a.quest) for a in child.visit.actions]
        self.assertIn(("accept", 201), actions)
        # 202 follows 201: it is accepted only after 201 has been turned in (the same NPC, so in the same visit)
        self.assertLess(actions.index(("turnin", 201)), actions.index(("accept", 202)))

    def test_a_quest_handed_over_by_another_is_not_accepted_while_that_one_is_in_the_log(self):
        quests = {
            **QUESTS,
            243: {"n": "Lead In", "r": 1, "l": 1, "next": 244, **HOME},
            244: {"n": "Handed Over", "r": 1, "l": 1, **HOME},
        }
        pl = self.planner(quests=quests)
        hub = pl.quests[243].start_hubs[0]
        st = pl.start(hub)
        self.assertFalse(pl.offered(pl.quests[244], 1, st.done, st.active, st.gone))  # follows 243 in this route
        self.assertFalse(pl.offered(pl.quests[244], 1, frozenset(), {243: frozenset()}, frozenset()))
        self.assertTrue(pl.offered(pl.quests[244], 1, frozenset({243}), {}, frozenset()))

    def test_hardcore_quests_far_above_the_character_are_not_accepted(self):
        hardcore = self.planner(hardcore=True)
        normal = self.planner()
        q = 223  # a level 9 quest
        self.assertFalse(hardcore.offered(hardcore.quests[q], 5, frozenset(), {}, frozenset()))
        self.assertFalse(normal.offered(normal.quests[q], 3, frozenset(), {}, frozenset()))  # 9 > 3 + 5
        self.assertTrue(normal.offered(normal.quests[q], 4, frozenset(), {}, frozenset()))


class SearchTest(PlannerCase):
    def test_every_technique_reaches_the_cap_and_no_quest_is_left_in_the_log(self):
        pl = self.planner()
        hub = self.start(pl)
        for preset in ("greedy", "lookahead", "beam"):
            plan = pl.plan(preset, hub)
            self.assertTrue(plan.complete, preset)
            self.assertGreaterEqual(plan.final.level, 6, preset)
            self.assertEqual(dict(plan.final.active), {}, preset)  # tidied: nothing accepted and never finished
            accepts = {a.quest for v in plan.visits for a in v.actions if a.kind == "accept"}
            turnins = {a.quest for v in plan.visits for a in v.actions if a.kind == "turnin"}
            self.assertEqual(accepts - turnins, set(), preset)

    def test_the_beam_is_never_slower_than_greedy(self):
        pl = self.planner(width=20, branch=6)
        hub = self.start(pl)
        greedy = pl.plan("greedy", hub)
        beam = pl.plan("beam", hub)
        self.assertLessEqual(beam.seconds + beam.penalty, greedy.seconds + greedy.penalty + 1e-6)
        self.assertGreater(beam.stats["nodes"], greedy.stats["nodes"])

    def test_plans_are_repeatable(self):
        a = self.planner()
        b = self.planner()
        hub = self.start(a)
        self.assertEqual([v.seconds for v in a.plan("beam", hub).visits], [v.seconds for v in b.plan("beam", hub).visits])

    def test_the_cost_to_go_falls_as_the_character_levels(self):
        pl = self.planner()
        hub = self.start(pl)
        pl.calibrate(pl.plan("greedy", hub))
        low, high = pl.start(hub, 1), pl.start(hub, 4)
        self.assertGreater(pl.to_go(low), pl.to_go(high))
        self.assertEqual(pl.to_go(pl.start(hub, 6)), 0.0)

    def test_grinding_is_offered_when_nothing_pays_and_the_cap_is_ground_to_at_the_end(self):
        pl = self.planner(cap=8, skip_unprofitable=False)
        hub = self.start(pl)
        plan = pl.plan("greedy", hub)
        self.assertTrue(plan.complete)
        self.assertEqual(plan.final.level, 8)
        self.assertTrue(any(v.hub is None for v in plan.visits))  # no quest gets a level 6 character to 8
        voluntary = pl.grind(pl.start(hub), voluntary=True)
        self.assertEqual(voluntary.level, 2)
        self.assertGreater(voluntary.clock, 0)

    def test_a_mandatory_class_quest_is_done_before_the_route_ends(self):
        pl = self.planner(mandatory=(217,))
        plan = pl.plan("greedy", self.start(pl))
        self.assertIn(217, plan.final.done)
        self.assertTrue(plan.complete)

    def test_the_level_each_quest_was_turned_in_at_follows_the_route(self):
        pl = self.planner()
        plan = pl.plan("greedy", self.start(pl))
        levels = plan.levels_done()
        self.assertEqual(set(levels), set(plan.final.done))
        self.assertTrue(all(1 <= n <= plan.final.level for n in levels.values()))
        self.assertLessEqual(levels[201], levels[202])  # 202 follows 201

    def test_a_class_quest_the_route_cannot_do_is_accounted_for_with_a_skipquest(self):
        pl = self.planner(mandatory=(204,))  # another class's quest: not routable
        plan = pl.plan("greedy", self.start(pl))
        self.assertIn(204, pl.skipquests(plan))
        self.assertIn("could not route", pl.skipquests(plan)[204])

    def test_zone_changes_cost_the_planner_a_penalty_that_is_not_play_time(self):
        pl = self.planner(zone_friction=300.0)
        plan = pl.plan("greedy", self.start(pl))
        changes = sum(1 for v in plan.visits if v.zone_change)
        self.assertEqual(plan.penalty, changes * 300.0)
        self.assertAlmostEqual(plan.seconds, sum(v.seconds for v in plan.visits))

    def test_decisions_name_the_zones_the_search_chose_between(self):
        pl = self.planner(width=30, branch=8)
        plan = pl.plan("beam", self.start(pl))
        for d in plan.decisions:
            self.assertNotEqual(d["from_zone"], d["to_zone"])
            for score, zone, level, clock in d["alternatives"]:
                self.assertNotEqual(zone, d["to_zone"])


class CapTest(PlannerCase):
    def test_at_the_cap_only_the_class_quests_and_what_they_need_are_worth_the_walk(self):
        pl = self.planner(cap=6, mandatory=(217,))
        self.assertIn(217, pl.core)
        self.assertNotIn(203, pl.core)
        none = (frozenset(), {}, frozenset())
        self.assertTrue(pl.offered(pl.quests[203], 5, *none))
        self.assertFalse(pl.offered(pl.quests[203], 6, *none))  # a quest that would still pay below the cap
        self.assertTrue(pl.offered(pl.quests[217], 6, *none))
        capped = pl.start(self.start(pl), 6)
        self.assertTrue(set(pl.options(capped)) <= set(pl.quests[217].start_hubs))

    def test_a_route_is_over_when_the_cap_is_reached_and_the_class_quests_are_done(self):
        pl = self.planner(cap=6, mandatory=(217,))
        plan = pl.plan("beam", self.start(pl))
        self.assertTrue(plan.complete)
        self.assertEqual(plan.final.level, 6)  # no quest past the cap adds experience the route does not need
        self.assertIn(217, plan.final.done)


class TidyTest(PlannerCase):
    def test_a_replay_walks_the_grinds_again_or_the_levels_that_open_quests_are_missed(self):
        pl = self.planner(cap=8)
        hub = self.start(pl)
        raw = pl._finish(pl.rollout(pl.start(hub)))
        self.assertTrue(any(v.hub is None for v in raw.visits))  # no quest gets a level 6 character to 8
        raw.final.active = {203: frozenset({1})}  # as if a quest had been accepted and never finished
        grinds, before_rollout = [], []
        grind_to, rollout = pl._grind_to, pl.rollout
        pl._grind_to = lambda st, target: (grinds.append(target), grind_to(st, target))[1]
        pl.rollout = lambda st, steps=None: (before_rollout.append(len(grinds)), rollout(st, steps))[1]
        tidy = pl.tidy(raw, hub)
        self.assertGreater(before_rollout[0], 0)  # the replay itself ground to the levels the route had ground to
        self.assertTrue(tidy.complete)
        self.assertEqual(tidy.final.active, {})
        self.assertNotIn(203, tidy.final.done)
        self.assertIn(203, tidy.stats["removed"])


class EmitTest(PlannerCase):
    def test_the_route_is_written_as_steps_one_npc_each_with_level_lines_and_optional_tags(self):
        pl = self.planner(quests={**QUESTS, 250: {"n": "Needs Three", "r": 3, "l": 3, **HOME}})
        plan = pl.plan("greedy", self.start(pl))
        chapters = pl.emit(plan, "HUNTER")
        text = "\n".join(c.text("West") for c in chapters)
        self.assertIn("#chapter 1-", text)
        for step in text.split("step\n")[1:]:
            coords = {line.strip() for line in step.splitlines() if line.strip().startswith(".goto")}
            self.assertLessEqual(len(coords), 1, step)
        # a quest above the last level asked for gets a .level line before its .accept (in the same step)
        self.assertIn(250, plan.final.done)
        step = next(step for step in text.split("step\n") if ".accept 250" in step)
        self.assertLess(step.index(".level 3"), step.index(".accept 250"))
        if 220 in plan.final.done:
            self.assertRegex(text, r"\.optional 220 -- group quest")

    def test_the_skipquest_lines_account_for_exclusive_alternatives(self):
        pl = self.planner()
        plan = pl.plan("greedy", self.start(pl))
        skips = pl.skipquests(plan)
        chosen = {212, 213} & plan.final.done
        if chosen:
            other = ({212, 213} - chosen).pop()
            self.assertIn(other, skips)
            self.assertIn("alternative to quest", skips[other])


class SettingsTest(unittest.TestCase):
    def test_settings_are_frozen_and_replaceable(self):
        s = engine.Settings()
        self.assertEqual((s.cap, s.hub_radius, s.zone_friction), (30, 150.0, 180.0))
        self.assertEqual(dataclasses.replace(s, cap=20).cap, 20)
        with self.assertRaises(dataclasses.FrozenInstanceError):
            s.cap = 5  # type: ignore[misc]

    def test_slug(self):
        self.assertEqual(engine.slug("Stonetalon Mountains"), "stonetalon-mountains")
        self.assertEqual(engine.slug("Shen'dralas"), "shen-dralas")


if __name__ == "__main__":
    unittest.main()
