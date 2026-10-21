import dataclasses
import json
import unittest

import guide_travel
import planner as engine
from signpost_tools import availability, steps
from tests.guide_fixtures import MAPS, TRAVEL, TempProject, write_pack
from tests.test_guide_draft import HOME, NPCS, QUESTS, START

ITEMS = {9999: {"n": "Thing"}, 9998: {"n": "Elite Drop", "drops": [3002]}, 9997: {"n": "Stone", "drops": [3002], "objDrops": [1]}}
HORDE = availability.Character("Horde", availability.race_bit("Orc", "Horde"), availability.class_bit("HUNTER"))


class PlannerCase(TempProject):
    def planner(self, quests=None, character=HORDE, mandatory=(), npcs=None, **settings):
        base = dict(cap=6, skip_unprofitable=False, hub_radius=150.0, instant_quests=True)  # the fixtures' quests have no objectives
        base.update(settings)
        pack_dir = write_pack(self.pack_dir, {"maps": MAPS, "quests": quests or QUESTS, "npcs": npcs or NPCS, "travel": TRAVEL, "items": ITEMS})
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
        self.assertLessEqual(beam.total, greedy.total + 1e-6)
        self.assertGreater(beam.stats["nodes"], greedy.stats["nodes"])
        self.assertGreater(beam.stats["finals"], 0)  # it finished routes of its own, it did not fall back on the greedy one

    def test_the_beam_compares_routes_by_how_far_they_have_got(self):
        pl = self.planner()
        hub = self.start(pl)
        start = pl.start(hub, 3)
        self.assertEqual(pl._bucket(start, 2), 6)  # level 3, nothing of the next
        start.xp = pl.model.to_next(3) * 0.6
        self.assertEqual(pl._bucket(start, 2), 7)  # past the half of level 3
        self.assertEqual(pl._bucket(start, 4), 14)  # a finer grain: 0.6 of the way is the third quarter
        self.assertEqual(pl._bucket(pl.start(hub, 6), 2), pl._bucket(pl.start(hub, 9), 2))  # the cap and beyond is one bucket
        starts = [pl.start(hub, n) for n in range(1, 6)]
        self.assertEqual([pl._bucket(s, 3) for s in starts], sorted(pl._bucket(s, 3) for s in starts))  # never goes down as the level rises

    def test_a_beam_run_for_each_grain_of_progress_and_the_best_route_of_them_all(self):
        pl = self.planner(parts=(1, 2, 4), width=10, branch=6)
        plan = pl.plan("beam", self.start(pl))
        self.assertEqual(plan.stats["runs"], 3)
        self.assertTrue(plan.complete)
        self.assertLessEqual(plan.total, pl.plan("greedy", self.start(pl)).total + 1e-6)

    def test_class_quests_waiting_rank_a_route_but_never_make_it_hopeless(self):
        # the regression: a pending charge above the margin against a finished route's real charges emptied the beam (finals == 0)
        chain = {n: {"n": f"Chain {n}", "r": 1, "l": 1, "classes": 4, "o": [{"id": 3001, "k": "kill"}], **HOME} for n in (251, 252, 253)}
        pl = self.planner(quests={**QUESTS, **chain}, mandatory=(217, 251, 252, 253), class_push=100000.0)
        st = pl.start(self.start(pl), 5)
        self.assertGreater(pl.pending_charge(st), 0.5 * (st.total + pl.to_go(st)))  # the four quests, long open, are charged heavily
        finished = (st.total + pl.to_go(st)) * 1.01  # a finished route that is only a little slower than the work still to do
        self.assertGreaterEqual(pl.score(st), finished * pl.s.prune)  # the ranking alone would have thrown the route away
        self.assertFalse(pl.hopeless(st, finished))  # the bound does not
        self.assertTrue(pl.hopeless(st, (st.total + pl.to_go(st)) / pl.s.prune))  # a route that cannot win still is

    def test_many_class_quests_waiting_do_not_stop_the_beam_from_finishing(self):
        chain = {n: {"n": f"Chain {n}", "r": 1, "l": 1, "classes": 4, "o": [{"id": 3001, "k": "kill"}], **HOME} for n in (251, 252, 253)}
        pl = self.planner(quests={**QUESTS, **chain}, mandatory=(217, 251, 252, 253), class_push=1200.0, width=20, branch=6)
        hub = self.start(pl)
        greedy = pl.plan("greedy", hub)
        beam = pl.plan("beam", hub)
        self.assertGreater(beam.stats["finals"], 0)
        self.assertTrue(beam.complete)
        self.assertLessEqual(beam.total, greedy.total + 1e-6)
        self.assertTrue({217, 251, 252, 253} <= set(beam.final.done))

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


class BeamTest(PlannerCase):
    """What the beam keeps and reports, on a fixture whose class quest is in the other zone (the route has to change zone)."""

    def two_zones(self, **settings):
        east = {n: {"n": f"East {n}", "r": 1, "l": 2, "s": {"npc": [1002]}, "e": {"npc": [1002]}, "side": "Horde", "races": 178} for n in range(281, 287)}
        east[290] = {"n": "Far Hunter Quest", "r": 1, "l": 1, "classes": 4, "s": {"npc": [1002]}, "e": {"npc": [1002]}, "side": "Horde", "races": 178}
        settings.setdefault("width", 20)
        settings.setdefault("branch", 6)
        return self.planner(quests={**QUESTS, **east}, mandatory=(290,), **settings)

    def test_decisions_name_the_zones_the_search_chose_between_and_the_ones_it_held(self):
        pl = self.two_zones()
        plan = pl.plan("beam", self.start(pl))
        changes = [v for v in plan.visits if v.zone_change]
        self.assertTrue(changes)  # the class quest is in the other zone
        self.assertEqual(len(plan.decisions), len(changes))
        for d in plan.decisions:
            self.assertNotEqual(d["from_zone"], d["to_zone"])
            for score, zone, level, clock in d["alternatives"]:
                self.assertNotEqual(zone, d["to_zone"])
        self.assertTrue(any(d["alternatives"] for d in plan.decisions))  # the beam held routes that stayed in a zone

    def test_the_route_is_never_slower_than_the_greedy_one_as_it_would_be_written(self):
        pl = self.two_zones()
        hub = self.start(pl)
        greedy = pl.plan("greedy", hub)
        beam = pl.plan("beam", hub)
        self.assertEqual(beam.stats["baseline_seconds"], greedy.total)  # the greedy route tidied, as the route is
        self.assertLessEqual(beam.total, greedy.total + 1e-6)
        self.assertEqual(beam.stats["chosen"], "beam" if beam.total < greedy.total else "greedy")

    def test_two_routes_to_the_same_situation_keep_the_better_one(self):
        pl = self.two_zones()
        hub = self.start(pl)
        slow, quick = pl.start(hub, 2), pl.start(hub, 2)  # the same quests done, the same bucket of progress, one sooner
        slow.clock, quick.clock = 900.0, 600.0
        pl.children = lambda st, limit: [slow, quick] if st.level == 1 else []
        run = pl._layers(hub, 2, float("inf"), None)
        self.assertEqual([(n, e) for level, n, e in run.trace if level == 2.0], [(1, pl.score(quick))])

    def test_a_route_the_greedy_one_beats_once_written_is_not_the_result(self):
        pl = self.two_zones()
        hub = self.start(pl)
        real, calls = pl.tidy, []

        def tidy(plan, start_hub):  # every route the beam finished turns out slow when written; the greedy one (the first tidied) does not
            out = real(plan, start_hub)
            calls.append(plan)
            if len(calls) > 1 and not plan.stats:
                out.penalty += 1e7
            return out

        pl.tidy = tidy
        plan = pl.plan("beam", hub)
        self.assertGreater(len(calls), 2)  # the beam's finalists were tidied after the greedy route
        self.assertEqual(plan.stats["chosen"], "greedy")
        self.assertLess(plan.total, 1e7)

    def test_finished_routes_are_compared_after_tidy_not_before(self):
        pl = self.two_zones()
        hub = self.start(pl)
        run = pl._layers(hub, 2, float("inf"), None)
        best_before = min(run.finished, key=lambda f: f.total)
        real = pl.tidy

        def tidy(plan, start_hub):  # as if the best route turned out slow once its unfinished quests were taken out
            out = real(plan, start_hub)
            if plan.final is not None and abs(plan.final.total - best_before.total) < 1e-9:
                out.penalty += 1e7
            return out

        pl.tidy = tidy
        plan = pl.plan("beam", hub)
        self.assertLess(plan.total, 1e7)  # another route (or the greedy one) won once the first was written out

    def test_every_grain_of_progress_starts_from_the_greedy_route_never_from_another_grain(self):
        pl = self.two_zones(parts=(2, 4, 1))
        hub = self.start(pl)
        bounds = []
        real = pl._layers
        pl._layers = lambda start_hub, parts, best_time, progress: (bounds.append(best_time), real(start_hub, parts, best_time, progress))[1]
        pl.plan("beam", hub)
        greedy = pl._finish(pl.rollout(pl.start(hub))).final.total
        self.assertEqual(bounds, [greedy, greedy, greedy])  # what an earlier grain found never prunes a later one

    def test_a_bucket_keeps_at_most_width_routes_and_a_run_stops_at_the_depth_limit(self):
        pl = self.two_zones(width=3)
        hub = self.start(pl)
        run = pl._layers(hub, 2, float("inf"), None)
        kept = [n for _, n, _ in run.trace]
        self.assertEqual(max(kept), 3)  # the fixture fills a bucket, and no bucket holds more
        levels = [level for level, _, _ in run.trace]
        self.assertEqual(levels, sorted(levels))  # the buckets are worked in order of progress
        self.assertGreater(run.finals, 0)
        shallow = self.two_zones(max_depth=2)
        self.assertEqual(shallow._layers(hub, 2, float("inf"), None).finals, 0)  # no route is that short

    def test_a_route_that_cannot_beat_the_one_to_beat_is_dropped_as_hopeless(self):
        pl = self.two_zones()
        run = pl._layers(self.start(pl), 2, 1.0, None)  # a route to beat that takes one second: nothing can
        self.assertEqual(run.finals, 0)
        self.assertGreater(run.pruned, 0)

    def test_routes_are_ranked_by_what_the_class_quests_waiting_will_cost(self):
        pl = self.two_zones()
        pl.pending_charge = lambda st: 1e6
        run = pl._layers(self.start(pl), 2, float("inf"), None)
        self.assertTrue(run.trace)
        self.assertTrue(all(estimate >= 1e6 for _, _, estimate in run.trace))  # every estimate has the charge in it

    def test_the_best_few_finished_routes_are_kept_to_compare_and_the_trace_is_reported(self):
        pl = self.two_zones()
        plan = pl.plan("beam", self.start(pl))
        self.assertTrue(plan.trace)
        self.assertTrue(plan.alternatives)
        for other in plan.alternatives:
            self.assertTrue(other.complete)
            self.assertGreaterEqual(other.total, plan.total - 1e-6)
        self.assertGreater(plan.stats["finals"], len(plan.alternatives))

    def test_every_grain_reports_its_own_best_route_as_it_is_written(self):
        pl = self.two_zones(parts=(1, 2, 4))
        plan = pl.plan("beam", self.start(pl))
        grains = plan.stats["grains"]
        self.assertEqual([g["parts"] for g in grains], [1, 2, 4])
        for g in grains:
            self.assertGreater(g["finals"], 0)
            self.assertIsNotNone(g["total"])  # each grain has a route of its own to show, whatever the others found
            self.assertGreaterEqual(g["seconds"], 0.0)
        self.assertEqual(sum(g["finals"] for g in grains), plan.stats["finals"])
        # the route chosen is the best of everything written: no grain's best is shorter than it
        self.assertAlmostEqual(plan.total, min([g["total"] for g in grains] + [plan.stats["baseline_seconds"]]))

    def test_a_grain_is_judged_by_its_route_after_it_is_written_not_by_the_search_estimate(self):
        pl = self.two_zones(parts=(2, 4))
        real, calls = pl.tidy, []

        def tidy(plan, start_hub):  # every route the beam finished turns out slow when written; the greedy one (the first tidied) does not
            out = real(plan, start_hub)
            calls.append(plan)
            if len(calls) > 1 and not plan.stats:
                out.penalty += 1e7
            return out

        pl.tidy = tidy
        plan = pl.plan("beam", self.start(pl))
        self.assertEqual(len(plan.stats["grains"]), 2)
        for g in plan.stats["grains"]:
            self.assertGreater(g["total"], 1e7)  # what a grain says is its route as written
        self.assertEqual(plan.stats["chosen"], "greedy")

    def test_a_grain_whose_routes_look_like_another_grains_still_has_its_own_best(self):
        pl = self.two_zones(parts=(2, 4, 8))
        pl.signature = lambda final: ("one order of zones",)  # every route counts as the same one, so the pool of the best routes keeps a single one...
        plan = pl.plan("beam", self.start(pl))
        self.assertTrue(all(g["total"] is not None for g in plan.stats["grains"]))  # ...but each grain still reports the best of its own
        self.assertEqual(len(plan.alternatives), 2)  # and each is a finalist too: the other two grains' best routes


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
        before = list(tidy.stats["removed"])
        self.assertEqual(before, [203])
        again = pl.tidy(tidy, hub)  # a plan the search tidied is tidied once more by plan(): what was taken out is still said
        self.assertEqual(again.stats["removed"], before)


class ClassQuestTest(PlannerCase):
    def test_a_class_quest_costs_for_each_level_it_is_undone_up_to_a_limit(self):
        pl = self.planner(mandatory=(217,), class_push=600.0, class_grace=1, class_levels=4)
        quest = pl.quests[217]  # opens at level 1
        self.assertEqual([pl.lateness(quest, n) for n in (1, 2, 3, 4, 30)], [0.0, 0.0, 600.0, 1200.0, 2400.0])
        self.assertEqual(pl.lateness(pl.quests[203], 30), 0.0)  # only a class quest is pushed

    def test_the_search_sees_a_waiting_class_quest_and_the_plan_adds_up(self):
        pl = self.planner(mandatory=(217,), class_push=600.0)
        hub = self.start(pl)
        waiting = pl.start(hub, 3)
        self.assertEqual(pl.score(waiting) - pl.to_go(waiting), 1200.0)  # level 3, opens at 1: two levels late
        plan = pl.plan("greedy", hub)
        self.assertIn(217, plan.final.done)
        # what the route was charged is what the quest cost at the level it was handed in at: a number to check, not a bound
        expected = pl.lateness(pl.quests[217], plan.levels_done()[217])
        self.assertEqual(plan.late, expected)
        self.assertEqual(plan.total, plan.seconds + plan.penalty + plan.late)

    def test_a_quest_that_opens_later_costs_nothing_until_it_has_opened_and_a_far_one_costs_for_the_trip(self):
        pl = self.planner(mandatory=(217,), class_push=600.0)
        quest = pl.quests[217]
        quest.req = 3  # as if it opened at level 3
        giver = quest.start_hubs[0]
        elsewhere = next(h.id for h in pl.hubs if h.id != giver)
        pl.calibrate(pl.plan("greedy", giver))
        low, there, away = pl.start(giver, 2), pl.start(giver, 5), pl.start(elsewhere, 5)
        self.assertEqual(pl.pending_charge(low), 0.0)  # level 2: it has not opened
        self.assertEqual(pl.pending_charge(there), 2 * 600.0)  # level 5, opens at 3, standing at the giver
        self.assertGreater(pl.pending_charge(away), pl.pending_charge(there))  # the trip to it takes levels too

    def test_a_class_quest_is_worked_where_its_next_step_is(self):
        pl = self.planner(mandatory=(217,))
        st = pl.start(self.start(pl), 1)
        second, boars = pl.quests[202], pl.quests[203]
        self.assertEqual(pl._next_hubs(second, st), second.start_hubs)  # not accepted: its giver
        st.active = {202: frozenset()}
        self.assertEqual(pl._next_hubs(second, st), second.end_hubs)  # accepted, nothing left to do: its ender
        self.assertNotEqual(second.start_hubs, second.end_hubs)
        st.active = {203: frozenset({1})}
        self.assertEqual(pl._next_hubs(boars, st), boars.objectives[0].hubs)  # an objective open: where it is done
        self.assertNotEqual(boars.objectives[0].hubs, boars.start_hubs)

    def test_the_charge_for_a_waiting_class_quest_stops_growing(self):
        pl = self.planner(mandatory=(217,), class_push=600.0, class_levels=1)
        quest = pl.quests[217]
        quest.req = 1
        st = pl.start(quest.start_hubs[0], 5)  # four levels past the one it opens at, standing at its giver
        self.assertEqual(pl.pending_charge(st), 600.0)  # one level's worth, the limit

    def test_the_hubs_of_a_class_quest_past_its_level_are_always_tried(self):
        # a second giver whose own quest makes its hub the one the ranking tries first when standing there
        other = {"n": "Second Errand", "r": 1, "l": 1, "s": {"npc": [1003]}, "e": {"npc": [1003]}, "side": "Horde", "races": 178}
        pl = self.planner(quests={**QUESTS, 250: other}, mandatory=(217,))
        giver = pl.quests[217].start_hubs[0]
        elsewhere = pl.quests[250].start_hubs[0]
        self.assertNotEqual(giver, elsewhere)
        st = pl.start(elsewhere, 3)
        self.assertEqual(pl.rank(st, pl.options(st), 1), [elsewhere])  # the precondition: the ranking alone would try this hub only
        self.assertEqual(pl.overdue_hubs(pl.start(elsewhere, 3)), [giver])  # level 3, it opens at 1
        self.assertEqual(pl.overdue_hubs(pl.start(elsewhere, 1)), [])  # not late yet
        self.assertEqual(pl.overdue_hubs(pl.start(giver, 3)), [])  # already there
        tried = [child.hub for child in pl.children(pl.start(elsewhere, 3), 1)]
        self.assertIn(giver, tried)  # added to the one hub the ranking tried


class ActivityStepsTest(PlannerCase):
    NEIGHBOUR = {1004: {"n": "Neighbour", "p": [[10, 41, 40]], "side": "Horde"}}

    def text(self, **settings):
        plain = {n: {"n": f"Plain {n}", "r": 1, "l": 1, **HOME} for n in range(270, 274)}  # a zone needs a few quests to count as theirs
        quests = {**plain, 260: {"n": "Next Door", "r": 1, "l": 1, "s": {"npc": [1004]}, "e": {"npc": [1004]}, "side": "Horde", "races": 178}}
        pl = self.planner(quests=quests, npcs={**NPCS, **self.NEIGHBOUR}, **settings)
        plan = pl.plan("greedy", self.start(pl))
        return "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))

    def test_quest_givers_in_one_area_are_one_pick_up_step_and_the_steps_are_fewer(self):
        grouped, apart = self.text(), self.text(group_yards=0.0)
        self.assertLess(grouped.count("step\n"), apart.count("step\n"))
        step = next(s for s in grouped.split("step\n") if ".accept 260" in s)
        self.assertIn(".accept 270", step)  # the neighbour and the giver at the hub
        self.assertNotIn(".accept 270", next(s for s in apart.split("step\n") if ".accept 260" in s))

    def test_the_seam_for_marks_writes_its_lines_on_every_step_and_a_step_with_a_hub_line_is_not_joined(self):
        plain = {n: {"n": f"Plain {n}", "r": 1, "l": 1, **HOME} for n in range(270, 274)}
        quests = {**plain, 260: {"n": "Next Door", "r": 1, "l": 1, "s": {"npc": [1004]}, "e": {"npc": [1004]}, "side": "Horde", "races": 178}}
        pl = self.planner(quests=quests, npcs={**NPCS, **self.NEIGHBOUR})
        plan = pl.plan("greedy", self.start(pl))
        self.assertEqual(pl.step_marks(0, None), [])  # nothing marks a step yet
        joined = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        pl.step_marks = lambda hub, place: ["  .hub Orgrimmar"]
        marked = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        self.assertEqual(marked.count(".hub Orgrimmar"), marked.count("step\n"))  # every step has its line, after its quest lines
        self.assertGreater(marked.count("step\n"), joined.count("step\n"))  # and none is joined with its neighbour: a step has one `.hub`

    BOARS = {3101: {"n": "Boar One", "p": [[10, 60, 20]], "side": "none"}, 3102: {"n": "Boar Two", "p": [[10, 63, 21]], "side": "none"}}  # 60 yards apart

    def steps_of(self, extra=None, **settings):
        plain = {n: {"n": f"Plain {n}", "r": 1, "l": 1, **HOME} for n in range(270, 274)}
        near_door = {260: {"n": "Next Door", "r": 1, "l": 1, "s": {"npc": [1004]}, "e": {"npc": [1004]}, "side": "Horde", "races": 178}}
        pl = self.planner(quests={**plain, **near_door, **(extra or {})}, npcs={**NPCS, **self.NEIGHBOUR, **self.BOARS}, **settings)
        plan = pl.plan("greedy", self.start(pl))
        text = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        return [[line for line in block.splitlines() if line.strip()] for block in text.split("step\n")[1:]]

    def boar_quests(self):
        return {
            300: {"n": "Boars One", "r": 1, "l": 2, "o": [{"id": 3101, "k": "kill"}], **HOME},
            301: {"n": "Boars Two", "r": 1, "l": 2, "o": [{"id": 3102, "k": "kill"}], **HOME},
        }

    def test_quests_whose_objectives_are_near_each_other_are_one_doing_step_with_one_position(self):
        doing = [s for s in self.steps_of(self.boar_quests()) if steps.kind(s) == steps.DO]
        both = [s for s in doing if any(".complete 300" in line for line in s)]
        self.assertEqual(len(both), 1)
        self.assertTrue(any(".complete 301" in line for line in both[0]), both[0])
        self.assertEqual(len([line for line in both[0] if line.strip().startswith(".goto")]), 1)  # no markers: one position for the tools
        alone = [s for s in self.steps_of(self.boar_quests(), group_yards=0.0) if steps.kind(s) == steps.DO]
        self.assertGreater(len(alone), len(doing))  # the same quests, a step for each when nothing is joined

    def test_a_doing_step_holds_nothing_that_sends_the_player_anywhere(self):
        found = [s for s in self.steps_of(self.boar_quests()) if steps.kind(s) == steps.DO]
        self.assertTrue(found)  # the fixture has doing steps to look at
        for step in found:
            self.assertFalse(steps.names(step) & {"accept", "turnin", "level", "todo", "zone", "path"}, step)

    def test_every_position_of_a_joined_pick_up_step_is_kept(self):
        # the givers of one area are one step; without the data pack each one's goto is its pin, so none may be lost
        grouped = [s for s in self.steps_of() if steps.kind(s) == steps.PLACE]
        apart = [s for s in self.steps_of(group_yards=0.0) if steps.kind(s) == steps.PLACE]
        places = lambda found: {line.strip() for s in found for line in s if line.strip().startswith(".goto")}
        self.assertLess(len(grouped), len(apart))
        self.assertEqual(places(grouped), places(apart))  # fewer steps, the same places
        self.assertTrue(any(len([line for line in s if line.strip().startswith(".goto")]) > 1 for s in grouped))  # and some step has several


class DataQualityTest(PlannerCase):
    """What the pack does not say must not become free experience."""

    BINDER = {
        1005: {"n": "Binder", "p": [[10, 45, 45]], "side": "Horde"},
        1006: {"n": "Nowhere", "side": "Horde"},  # no position
        1007: {"n": "Pact Master", "p": [[10, 48, 48]], "side": "Horde"},
    }

    def quests(self):
        lock = {"s": {"npc": [1005]}, "e": {"npc": [1005]}, "side": "Horde", "races": 178}
        pact = {"s": {"npc": [1007]}, "e": {"npc": [1007]}, "side": "Horde", "races": 178}
        return {
            **QUESTS,
            280: {"n": "The Binding", "r": 1, "l": 1, "classes": 256, **lock},  # a warlock's
            281: {"n": "The Binding", "r": 1, "l": 1, **lock},  # the same name from the same giver, no mask: its Forever copy
            282: {"n": "Second Pact", "r": 1, "l": 1, "classes": 256, **pact},
            283: {"n": "Third Pact", "r": 1, "l": 1, "classes": 256, **pact},
            284: {"n": "Fourth Pact", "r": 1, "l": 1, "classes": 256, **pact},
            285: {"n": "Unmasked Other", "r": 1, "l": 1, **pact},  # all the giver's other quests are the warlock's
            286: {"n": "General Errand", "r": 1, "l": 2, "o": [{"id": 3001, "k": "kill"}], **HOME},  # a giver whose quests are of every class
            290: {"n": "Look Around", "r": 1, "l": 2, "o": [{"k": "explore", "p": [[10, 55, 55]]}], **HOME},
            292: {"n": "Ends Nowhere", "r": 1, "l": 1, "s": START, "e": {"npc": [1006]}, "side": "Horde", "races": 178},
            293: {"n": "Class Ends Nowhere", "r": 1, "l": 1, "classes": 4, "s": START, "e": {"npc": [1006]}, "side": "Horde", "races": 178},
            294: {"n": "Talk To Yourself", "r": 1, "l": 1, **HOME},  # no objective, handed in where it was accepted
            295: {"n": "Needed First", "r": 1, "l": 1, **HOME},
            296: {"n": "After Needed", "r": 1, "l": 1, "preSingle": [295], **HOME},
            297: {"n": "Taming", "r": 1, "l": 1, "classes": 4, **HOME},  # a class quest with no objective
        }

    def planner(self, **kw):
        kw.setdefault("instant_quests", False)
        return super().planner(quests=self.quests(), npcs={**NPCS, **self.BINDER}, **kw)

    def test_a_quest_with_no_mask_is_another_classs_when_its_giver_says_so(self):
        pl = self.planner()
        dropped = pl.dropped["probably another class's quest (the quests of its giver are)"]
        self.assertEqual(sorted(dropped), [281, 285])
        self.assertIn(286, list(pl.quests))

    def test_an_explore_objective_is_an_area_to_reach(self):
        pl = self.planner()
        objective = pl.quests[290].objectives[0]
        self.assertEqual((objective.kind, [(c.map, c.x, c.y) for c in objective.spots]), ("explore", [(10, 55.0, 55.0)]))
        plan = pl.plan("greedy", self.start(pl))
        text = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        self.assertIn(".complete 290", text)

    def test_a_quest_whose_objective_is_only_where_the_route_does_not_go_is_left_out(self):
        pl = self.planner()
        self.assertIn(228, pl.dropped["an objective only where the route does not go"])  # the far rats are in a zone nobody quests in
        self.assertNotIn(228, pl.quests)

    def test_a_turn_in_with_no_position_is_left_out_but_a_class_quest_keeps_a_todo(self):
        pl = self.planner(mandatory=(293,))
        self.assertIn(292, pl.dropped["no turn-in position in the data"])
        self.assertTrue(pl.quests[293].end_unknown)
        plan = pl.plan("greedy", self.start(pl))
        text = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        self.assertRegex(text, r'\.todo "Class Ends Nowhere: the turn-in has no position in the pack"\n  \.turnin 293')

    def test_a_quest_with_no_objective_handed_in_where_it_was_accepted_is_left_out_unless_needed(self):
        pl = self.planner()
        self.assertIn(294, pl.dropped["no objective in the data (accepted and handed in at one NPC)"])
        self.assertIn(295, list(pl.quests))  # another quest needs it first
        self.assertIn(296, pl.dropped["no objective in the data (accepted and handed in at one NPC)"])  # nothing needs this one
        kept = self.planner(instant_quests=True)
        self.assertIn(294, list(kept.quests))

    def test_a_class_quest_with_no_objective_gets_time_and_a_todo(self):
        pl = self.planner(mandatory=(297,))
        self.assertTrue(pl.quests[297].unknown_work)
        plan = pl.plan("greedy", self.start(pl))
        text = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        self.assertIn('.todo "Taming: the pack has no objective for it', text)
        self.assertGreaterEqual(sum(v.objective_seconds for v in plan.visits), pl.s.unknown_work)

    def test_a_quest_of_a_zone_that_is_not_leveling_content_is_left_out(self):
        reason = "battleground (PvP) quest, not leveling content"
        pl = engine_build(self, {}, skip_zones={20: reason})  # quest 210 belongs to zone 20
        self.assertIn(210, pl.dropped[reason])
        self.assertNotIn(210, list(pl.quests))
        self.assertIn(210, list(engine_build(self, {}).quests))

    def test_what_is_left_out_on_purpose_is_named_in_the_skip_lines(self):
        pl = engine_build(self, {211: "battleground (PvP) quest, not leveling content"})
        plan = pl.plan("greedy", self.start(pl))
        self.assertNotIn(211, pl.quests)
        self.assertEqual(pl.skipquests(plan).get(211), "battleground (PvP) quest, not leveling content")


def engine_build(case, exclude, **kw):
    pack_dir = write_pack(case.pack_dir, {"maps": MAPS, "quests": QUESTS, "npcs": NPCS, "travel": TRAVEL, "items": ITEMS})
    pack = guide_travel.load_pack(pack_dir)
    settings = engine.Settings(cap=6, skip_unprofitable=False, instant_quests=True)
    return engine.Planner.build(pack, guide_travel.World(pack, [], "Horde"), HORDE, settings, exclude=exclude, **kw)


class EmitTest(PlannerCase):
    def test_the_route_is_written_as_steps_one_npc_each_with_level_lines_and_optional_tags(self):
        pl = self.planner(quests={**QUESTS, 250: {"n": "Needs Three", "r": 3, "l": 3, **HOME}}, group_yards=0.0)  # as written, before joining
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


class QuestLogTest(PlannerCase):
    """The quest log holds a fixed number of quests (Settings.quest_log_limit): nothing is accepted while it is full, in every search."""

    def test_a_full_log_offers_nothing_and_a_free_place_offers_again(self):
        three = {q: frozenset() for q in (203, 216, 220)}
        full, roomy = self.planner(quest_log_limit=3), self.planner(quest_log_limit=4)
        self.assertFalse(full.offered(full.quests[201], 1, frozenset(), three, frozenset()))  # three held, three allowed
        self.assertTrue(roomy.offered(roomy.quests[201], 1, frozenset(), three, frozenset()))  # one more place and it is offered
        self.assertTrue(full.offered(full.quests[201], 1, frozenset(), {203: frozenset(), 216: frozenset()}, frozenset()))

    def test_a_visit_never_holds_more_than_the_log_takes_and_goes_on_when_a_quest_is_handed_in(self):
        limit = 3
        full, free = self.planner(quest_log_limit=limit), self.planner()
        hub = full.quests[201].start_hubs[0]
        child = full.visit(full.start(hub), hub)
        self.assertLessEqual(engine.Plan(visits=[child.visit]).log_peak()[0], limit)
        self.assertLessEqual(len(child.active), limit)
        first = free.visit(free.start(hub), hub)
        self.assertGreater(engine.Plan(visits=[first.visit]).log_peak()[0], limit)  # given room the same visit takes in a dozen: the limit is what stops it
        accepts = [a.quest for a in child.visit.actions if a.kind == "accept"]
        turnins = [a.quest for a in child.visit.actions if a.kind == "turnin"]
        self.assertGreater(len(accepts), limit)  # the places freed by hand-ins are used again within the visit
        self.assertTrue(turnins)

    def test_every_search_keeps_the_log_within_the_limit_to_the_end(self):
        full, free = self.planner(quest_log_limit=4), self.planner()
        hub = self.start(full)
        for preset in ("greedy", "lookahead", "beam"):
            plan = full.plan(preset, hub)
            self.assertTrue(plan.complete, preset)
            self.assertLessEqual(plan.log_peak()[0], 4, preset)
        self.assertGreater(free.plan("greedy", hub).log_peak()[0], 4)  # without the limit this fixture holds more: the limit is what keeps it down

    def test_a_tidied_route_is_walked_again_within_the_limit(self):
        free = self.planner(cap=8)
        hub = self.start(free)
        raw = free._finish(free.rollout(free.start(hub)))
        self.assertGreater(raw.log_peak()[0], 3)
        raw.final.active = {203: frozenset({1})}  # as if a quest had been accepted and never finished: the replay walks the hubs again
        tight = self.planner(cap=8, quest_log_limit=3)
        self.assertLessEqual(tight.tidy(raw, hub).log_peak()[0], 3)

    def test_a_full_log_does_not_wait_for_a_level_that_would_open_a_quest_it_cannot_take(self):
        def ground_to(limit):
            pl = self.planner(quest_log_limit=limit)
            st = pl.start(self.start(pl), 1)
            st.active = {203: frozenset({1})}  # one quest held, its objective open and in reach
            return pl.grind(st).level

        self.assertLess(ground_to(40), 6)  # with room, quests that wait for level 4 are what it grinds for
        self.assertEqual(ground_to(1), 6)  # the log is full: no quest can be taken at any level, so it grinds on to the cap

    def test_the_peak_is_counted_action_by_action_with_the_level_and_the_clock_it_was_reached_at(self):
        def visit(*actions, level=1, seconds=60.0):
            return engine.Visit(0, [engine.Action(kind, quest, None, None) for kind, quest in actions], seconds, 0.0, False, level)

        plan = engine.Plan(
            visits=[
                visit(("accept", 1), ("accept", 2), ("turnin", 1), ("accept", 3), level=2),  # two at most
                visit(("accept", 4), ("accept", 5), ("turnin", 2), ("accept", 6), level=3, seconds=90.0),  # 2 + 2 = four, then one out and one in
                visit(("turnin", 3), ("turnin", 4), ("turnin", 5), ("turnin", 6), level=3),
            ]
        )
        self.assertEqual(plan.log_peak(), (4, 2, 60.0))  # the second visit began at level 2, a minute in
        self.assertEqual(engine.Plan().log_peak(), (0, 1, 0.0))


class GrindStepTest(PlannerCase):
    """A grind is a `.level N` line with a note that says how much there is to grind (user, 2026-10-21: grinding at a gate is fine)."""

    def test_numbers_are_rounded_to_two_figures(self):
        self.assertEqual(
            [engine.approx(x) for x in (2437, 2450, 555, 54.6, 8.4, 99.6, 1000, 14213.4, 0.2)], [2400, 2500, 560, 55, 8, 100, 1000, 14000, 0]
        )

    def test_the_note_says_how_much_experience_and_how_many_kills_that_is_as_an_estimate(self):
        pl = self.planner()
        self.assertEqual(
            pl.grind_note(2437.0, 54.6), "Grind about 2,400 experience before you go on: about 55 kills of creatures near your level (an estimate)"
        )
        self.assertEqual(
            pl.grind_note(30.0, 0.4), "Grind about 30 experience before you go on: about 1 kill of creatures near your level (an estimate)"
        )

    def test_the_kills_follow_the_experience_bar_of_each_level_the_grind_climbs_through(self):
        pl = self.planner()
        # a kill of a creature of the character's own level is worth 45 + 5 * level; level 4 takes 2,100 experience, level 5 takes 2,800
        self.assertAlmostEqual(pl.grind_kills(4, 5, 1300.0), 1300 / 65)  # 800 of level 4 are already earned
        self.assertAlmostEqual(pl.grind_kills(4, 6, 1300.0 + 2800.0), 1300 / 65 + 2800 / 70)

    def test_a_grind_is_two_lines_on_the_step_before_it_not_a_step_of_its_own(self):
        pl = self.planner(cap=8)  # no quest gets a level 4 character to 8: it grinds 10,913 experience at the end
        plan = pl.plan("greedy", self.start(pl))
        grind = next(v for v in plan.visits if v.hub is None)
        self.assertEqual(round(grind.xp), 10913)
        text = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        self.assertIn(
            "  .level 8 -- reach it first: kill or grind on the way\n"
            "  .note Grind about 11,000 experience before you go on: about 140 kills of creatures near your level (an estimate)\n",
            text,
        )  # 13 + 2800 + 3600 + 4500 experience of levels 4 to 7 at 65, 70, 75 and 80 each: 144 kills, said as 140
        self.assertRegex(text, r"\.turnin 215 -- After A Dropped One\n  \.level 8 -- reach it first")  # after the step's own work, in the step
        for step in text.split("step\n")[1:]:
            self.assertTrue(steps.names(step.splitlines()) - {"level", "note"}, step)  # no step is only a level line and a note

    def test_the_level_line_is_still_the_gate_so_the_quests_after_it_ask_for_nothing_more(self):
        pl = self.planner(cap=8, quests={**QUESTS, 250: {"n": "Needs Six", "r": 6, "l": 6, **HOME}})
        plan = pl.plan("greedy", self.start(pl))
        self.assertIn(250, plan.final.done)
        text = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        self.assertEqual(text.count(".level 6"), 1)  # the grind to level 6 gates the quest that needs it: the quest's step does not repeat the line
        self.assertLess(text.index(".level 6"), text.index(".accept 250"))

    def test_a_grind_that_comes_first_goes_on_the_step_after_it_and_two_in_a_row_are_one(self):
        pl = self.planner()
        hub = self.start(pl)
        first = pl._grind_to(pl.start(hub), 3)  # level 1 to 3: 1,300 experience, 400 / 50 + 900 / 55 kills
        plan = pl._finish(pl.visit(first, hub))
        step = pl.emit(plan, "HUNTER")[0].steps[0]
        self.assertEqual(step[0], "  .goto 10,40.0,40.0")  # the step's own position stays first
        self.assertEqual(step[1], "  .level 3 -- reach it first: kill or grind on the way")
        self.assertIn("Grind about 1,300 experience before you go on: about 24 kills", step[2])
        twice = pl._grind_to(pl._grind_to(pl.start(hub), 2), 4)  # 400, then 900 + 1,400: 2,700 experience
        text = "\n".join(c.text("West") for c in pl.emit(pl._finish(pl.visit(twice, hub)), "HUNTER"))
        self.assertEqual(text.count("reach it first"), 1)
        self.assertIn(".level 4 -- reach it first", text)
        self.assertIn("Grind about 2,700 experience before you go on: about 48 kills", text)  # 8 + 900 / 55 + 1,400 / 60 kills

    def test_a_route_of_nothing_but_a_grind_is_still_written(self):
        pl = self.planner()
        plan = engine.Plan(visits=[pl._grind_to(pl.start(self.start(pl)), 2).visit])
        chapters = pl.emit(plan, "HUNTER")
        self.assertEqual(len(chapters), 1)
        self.assertEqual(len(chapters[0].steps), 1)
        self.assertIn(".level 2 -- reach it first", "\n".join(chapters[0].steps[0]))


class ChapterTest(PlannerCase):
    """Chapters are cut where the route goes to another zone for a while and are named after the zone most of their steps are in."""

    WEST, EAST = 10, 20  # the fixture's zones: Westland and Eastland
    FAR = [(10, 10), (10, 90), (90, 10), (90, 90), (50, 50), (30, 70)]  # places a few hundred yards apart or more: a step each

    def test_a_change_of_zone_starts_a_chapter_only_when_the_new_zone_lasts(self):
        a, b, c = "A", "B", "C"
        cut = engine.split_chapters
        self.assertEqual(cut([a] * 5 + [b] * 3, 3), [(0, 4, a), (5, 7, b)])
        self.assertEqual(cut([a] * 5 + [b] * 2 + [a] * 4, 3), [(0, 10, a)])  # a stay of two steps is a detour, and the return goes on with the chapter
        self.assertEqual(cut([a] * 4 + [b] * 4 + [a] * 4, 3), [(0, 3, a), (4, 7, b), (8, 11, a)])  # a stay of four is not
        self.assertEqual(cut([b] + [a] * 4, 3), [(0, 4, a)])  # a short first stay is in the chapter that follows, which is named after what most of it is
        self.assertEqual(cut([a] * 3 + [b] * 2, 3), [(0, 4, a)])  # and a short last one in the chapter before
        self.assertEqual(cut([a, b, a, b, a, b], 3), [(0, 5, a)])  # nothing lasts: one chapter, named after the zone it began in on a tie
        self.assertEqual(cut([a] * 3 + [b] * 2 + [c] + [b] * 2 + [c] + [b] * 2, 3), [(0, 10, b)])  # named after the zone most of its steps are in
        self.assertEqual(cut([a, b], 1), [(0, 0, a), (1, 1, b)])  # one step is enough when asked for
        self.assertEqual(cut([a, b], 0), [(0, 0, a), (1, 1, b)])
        self.assertEqual(cut([a] * 3, 100), [(0, 2, a)])
        self.assertEqual(cut([], 3), [])

    def two_zones(self, west, east, **settings):
        """A quest giver at each of the `west` and `east` places (Westland and Eastland), each with a quest of its own that it gives and takes
        back (the first with more, so that a zone has the four quests of the character's side it needs to count as theirs)."""
        npcs, quests = dict(NPCS), {}
        for zone, places, first in ((self.WEST, west, 400), (self.EAST, east, 500)):
            for n, (x, y) in enumerate(places):
                npc = first + n
                npcs[npc] = {"n": f"Giver {npc}", "p": [[zone, x, y]], "side": "Horde"}
                for extra in range(1 + (max(0, 4 - len(places)) if n == 0 else 0)):
                    quests[npc * 10 + extra] = {
                        "n": f"Errand {npc}.{extra}", "r": 1, "l": 3, "s": {"npc": [npc]}, "e": {"npc": [npc]}, "side": "Horde", "races": 178
                    }
        pl = self.planner(quests=quests, npcs=npcs, cap=3, **settings)
        return pl, pl.plan("greedy", engine.start_hub_for(pl))

    def summary(self, pl, plan):
        return [(c.zone, len(c.steps)) for c in pl.emit(plan, "HUNTER")]

    def test_a_chapter_is_named_after_the_zone_most_of_its_steps_are_in(self):
        pl, plan = self.two_zones(self.FAR[:2], self.FAR[:4])  # two steps in Westland, then four in Eastland: the first hub's zone named it before
        self.assertEqual(self.summary(pl, plan), [(self.EAST, 6)])
        pl, plan = self.two_zones(self.FAR[:4], self.FAR[:4])
        self.assertEqual(self.summary(pl, plan), [(self.WEST, 4), (self.EAST, 4)])  # two stays of four steps: two chapters

    def test_the_chapters_follow_the_route_and_each_one_starts_at_the_level_the_one_before_ended_at(self):
        pl, plan = self.two_zones(self.FAR[:4], self.FAR[:4])
        first, second = pl.emit(plan, "HUNTER")
        self.assertEqual(first.level_in, 1)
        self.assertEqual(first.level_out, second.level_in)
        self.assertEqual(second.level_out, plan.final.level)
        self.assertEqual((first.level_out, plan.final.level), (2, 3))  # four quests of level 3 make level 2; the eight are short of the cap: the last step grinds
        self.assertTrue(first.text("Westland").startswith("#chapter 1-2 Westland\nstep\n"))
        self.assertTrue(second.text("Eastland").startswith("#chapter 2-3 Eastland\nstep\n"))
        self.assertTrue(all(any(line.strip().startswith(".goto 10,") for line in s) for s in first.steps))  # Westland's steps first...
        self.assertTrue(all(any(line.strip().startswith(".goto 20,") for line in s) for s in second.steps))  # ...then Eastland's
        self.assertIn(".level 3 -- reach it first", "\n".join(second.steps[-1]))  # the grind is on the last step of the route, not a step of its own

    def test_steps_are_counted_once_they_are_joined(self):
        near = [(10, 10), (90, 10), (50, 50), (52, 50)]  # the last two are forty yards apart: one pick-up and hand-in step
        pl, plan = self.two_zones(self.FAR[:4], near, chapter_min_steps=3)
        self.assertEqual(self.summary(pl, plan), [(self.WEST, 4), (self.EAST, 3)])  # four places, three steps: a stay of three
        pl, plan = self.two_zones(self.FAR[:4], near, chapter_min_steps=4)
        self.assertEqual(self.summary(pl, plan), [(self.WEST, 7)])  # counted before joining it would have been four, and a chapter

    def test_the_setting_decides_how_long_a_stay_has_to_be(self):
        for asked, expected in ((1, [self.WEST, self.EAST]), (3, [self.WEST, self.EAST]), (4, [self.WEST]), (100, [self.WEST])):
            pl, plan = self.two_zones(self.FAR[:4], self.FAR[:3], chapter_min_steps=asked)
            self.assertEqual([c.zone for c in pl.emit(plan, "HUNTER")], expected, asked)  # three steps in Eastland are a detour when four are asked for



class CompletenessTest(PlannerCase):
    """A quest the search picks up on the way and never goes back for (the Skyborne gap, 2026-10-21): the search accepts it at the first chance (an
    accept costs it nothing), its only objective spots are in another hub about 20 s of walking away, the trip pays slightly less than the route's
    pace, so it never goes; tidy then takes the quest out of the written route. The unit fixture's map is 1000 yards wide and 2000 tall: 1% of x is 10
    yards, 1% of y is 20 yards, and a walk of 7 yards a second."""

    CAMP = {1010: {"n": "Camp Boar", "p": [[10, 40, 48]], "side": "none"}}  # 160 yards south of the giver at 40,40 (23 s): a hub of its own
    FAR = {1011: {"n": "Far Boar", "p": [[10, 40, 70]], "side": "none"}}  # 600 yards south (86 s)
    QA = 300

    def quests(self, **extra):
        return {
            **QUESTS,
            self.QA: {"n": "Camp Cleanup", "r": 1, "l": 2, "o": [{"id": 1010, "k": "kill"}], **HOME},
            301: {"n": "Far Hunt", "r": 1, "l": 2, "o": [{"id": 1011, "k": "kill"}], **HOME},
            302: {"n": "Too Early", "r": 1, "l": 6, "o": [{"id": 1010, "k": "kill"}], **HOME},  # six levels above a level 1 character: not to be worked yet
            303: {"n": "Far Ender", "r": 1, "l": 2, "o": [{"id": 1010, "k": "kill"}], "s": START, "e": {"npc": [1003]}, "side": "Horde"},  # the camp, handed in 96 s away
            304: {"n": "Find The Thing", "r": 1, "l": 2, "o": [{"id": 9999, "k": "item"}], "s": START, "e": {"npc": [1003]}, "side": "Horde"},  # no position
            305: {"n": "Two Camps", "r": 1, "l": 2, "o": [{"id": 1011, "k": "kill"}, {"id": 1010, "k": "kill"}], **HOME},  # the far boar (86 s) and the camp
            **extra,
        }

    def camp(self, **settings):
        return self.planner(quests=self.quests(), npcs={**NPCS, **self.CAMP, **self.FAR}, **settings)

    def hubs(self, pl):
        return pl.quests[self.QA].start_hubs[0], pl.quests[self.QA].objectives[0].hubs[0], pl.quests[202].end_hubs[0]

    def raw(self, pl, ratio=0.8):
        """The route as the search wrote it: the giver's hub (it accepts everything offered there), then hub 202 ends in; the camp is never visited.
        The route's pace at the level the character has by then is set so that the quest pays `ratio` of it."""
        giver, camp, away = self.hubs(pl)
        st = pl.visit(pl.start(giver), giver)
        away_state = pl.visit(st, away)
        raw = pl._finish(away_state or st)
        level = raw.visits[0].level
        pl.rate_curve[level] = pl._quest_rate(pl.quests[self.QA], level) / ratio
        pl._ratio.clear()
        return raw

    def raw_at_giver(self, pl):
        """The route as the search wrote it when it never left the giver's hub: everything offered there is accepted and nothing is worked elsewhere."""
        giver = self.hubs(pl)[0]
        return pl._finish(pl.visit(pl.start(giver), giver))

    def record(self, plan, quest=None):
        return next(r for r in plan.stats["left_out"] if r["quest"] == (quest or self.QA))

    def test_the_fixture_has_the_shape_of_the_case(self):
        pl = self.camp()
        giver, camp, _away = self.hubs(pl)
        self.assertNotEqual(giver, camp)  # the quest is picked up in one hub and worked in another
        q = pl.quests[self.QA]
        far, stops, end_seconds, end_hub = pl.trip(q, q.start_places[0])
        self.assertAlmostEqual(far, 160 / guide_travel.WALK_SPEED)  # 23 s of walking
        self.assertEqual((stops, end_seconds, end_hub), ([camp], 0.0, giver))
        raw = self.raw(pl)
        self.assertIn(self.QA, raw.final.active)  # picked up for nothing and never worked
        self.assertNotIn(camp, [v.hub for v in raw.visits])
        self.assertAlmostEqual(pl.finish_ratio(q, raw.visits[0].level), 0.8)

    def test_tidy_takes_it_out_and_says_why_with_the_numbers(self):
        pl = self.camp()
        written = pl.tidy(self.raw(pl), self.hubs(pl)[0])
        self.assertNotIn(self.QA, written.final.done)
        self.assertEqual(written.final.active, {})
        self.assertIn(self.QA, written.stats["removed"])
        self.assertEqual(written.stats["completed"], [])
        r = self.record(written)
        self.assertEqual((r["code"], r["quest"], r["level"]), ("price", self.QA, 2))
        self.assertEqual(r["picked_level"], written.visits[0].level)  # where and when it was picked up
        self.assertIn("Giver", r["hub"])
        self.assertAlmostEqual(r["trip"], 160 / guide_travel.WALK_SPEED, places=1)
        self.assertAlmostEqual(r["ratio"], 0.8, places=2)
        self.assertGreater(r["rate"], 0.0)
        self.assertGreater(r["pace"], r["rate"])  # the route's pace is above what the quest pays
        self.assertIn("its work is 23 s away", r["why"])
        self.assertIn("(80%)", r["why"])
        self.assertIn("completeness 0.80 or less would finish it", r["why"])

    def test_with_completeness_the_route_stops_at_the_objectives_after_the_pick_up_and_finishes_the_quest(self):
        pl = self.camp(completeness=0.6)
        giver, camp, away = self.hubs(pl)
        plain = self.camp()
        before = plain.tidy(self.raw(plain), giver)
        written = pl.tidy(self.raw(pl), giver)
        self.assertIn(self.QA, written.final.done)
        self.assertEqual(written.final.active, {})
        self.assertEqual(written.stats["completed"], [self.QA, 303])  # (303 is worked in the same stop, and handed in where the route goes on to)
        self.assertNotIn(self.QA, written.stats["removed"])
        hubs = [v.hub for v in written.visits]
        self.assertEqual(hubs[:3], [giver, camp, giver])  # picked up, the objectives right after, back to hand it in (the route does not pass there again)
        picked = next(i for i, v in enumerate(written.visits) if any(a.kind == "accept" and a.quest == self.QA for a in v.actions))
        worked = next(i for i, v in enumerate(written.visits) if any(a.kind == "complete" and a.quest == self.QA for a in v.actions))
        handed = next(i for i, v in enumerate(written.visits) if any(a.kind == "turnin" and a.quest == self.QA for a in v.actions))
        self.assertEqual((picked, worked, handed), (0, 1, 2))
        self.assertGreaterEqual(written.visits[1].seconds, 160 / guide_travel.WALK_SPEED)  # the trip is in the route's time: the walk to the camp
        self.assertEqual([r["quest"] for r in written.stats["left_out"] if r["quest"] == self.QA], [])  # and it is not left out any more
        self.assertNotIn(self.QA, before.final.done)  # (what the same route does without)
        self.assertEqual(pl.tidy(written, giver).stats["completed"], [self.QA, 303])  # a plan tidied again still says what it saved

    def test_completeness_off_changes_nothing(self):
        pl = self.camp()
        giver, camp, _away = self.hubs(pl)
        written = pl.tidy(self.raw(pl), giver)
        self.assertNotIn(camp, [v.hub for v in written.visits])
        self.assertEqual(written.stats["completed"], [])

    def test_a_quest_that_pays_less_than_asked_is_taken_out_and_the_record_says_what_was_asked(self):
        pl = self.camp(completeness=0.9)
        written = pl.tidy(self.raw(pl), self.hubs(pl)[0])
        self.assertNotIn(self.QA, written.final.done)
        r = self.record(written)
        self.assertEqual(r["code"], "price")
        self.assertIn("completeness is 0.90", r["why"])

    def test_a_quest_that_pays_exactly_what_is_asked_is_finished(self):
        pl = self.camp(completeness=0.5)
        written = pl.tidy(self.raw(pl, ratio=0.5), self.hubs(pl)[0])  # (half is exact in floating point: the pace is twice the quest's rate)
        self.assertEqual(pl.finish_ratio(pl.quests[self.QA], 1), 0.5)
        self.assertIn(self.QA, written.final.done)  # the lowest rate at which a quest picked up on the route is still finished
        just_under = self.camp(completeness=0.5)
        self.assertNotIn(self.QA, just_under.tidy(self.raw(just_under, ratio=0.49), self.hubs(just_under)[0]).final.done)

    def test_a_walk_longer_than_the_tolerance_is_not_made(self):
        pl = self.camp(completeness=0.6, completeness_trip=20.0)
        written = pl.tidy(self.raw(pl), self.hubs(pl)[0])
        self.assertNotIn(self.QA, written.final.done)
        r = self.record(written)
        self.assertEqual(r["code"], "far")
        self.assertIn("23 s of walking away", r["why"])
        self.assertIn("up to 20 s", r["why"])
        wide = self.camp(completeness=0.6, completeness_trip=23.0)
        self.assertIn(self.QA, wide.tidy(self.raw(wide), self.hubs(wide)[0]).final.done)  # 22.9 s is within 23

    def test_a_walk_exactly_as_long_as_the_tolerance_is_made(self):
        far = self.camp().trip(self.camp().quests[self.QA], self.camp().quests[self.QA].start_places[0])[0]
        exact = self.camp(completeness=0.6, completeness_trip=far)
        self.assertIn(self.QA, exact.tidy(self.raw(exact), self.hubs(exact)[0]).final.done)
        under = self.camp(completeness=0.6, completeness_trip=far - 0.01)
        self.assertNotIn(self.QA, under.tidy(self.raw(under), self.hubs(under)[0]).final.done)

    def test_objectives_far_away_stay_out_even_when_asked_for_everything(self):
        pl = self.camp(completeness=0.01)
        written = pl.tidy(self.raw(pl), self.hubs(pl)[0])
        self.assertNotIn(301, written.final.done)  # its kills are 86 s away
        self.assertEqual(self.record(written, 301)["code"], "far")
        self.assertIn(self.QA, written.final.done)  # the near one is finished

    def test_a_quest_that_cannot_be_worked_yet_is_not_tried(self):
        pl = self.camp(completeness=0.01)
        written = pl.tidy(self.raw(pl), self.hubs(pl)[0])
        self.assertNotIn(302, written.final.done)
        r = self.record(written, 302)
        self.assertEqual(r["code"], "level")
        self.assertIn("could not be worked at level", r["why"])

    def test_the_hand_in_stop_is_left_out_when_the_route_passes_there_later(self):
        pl = self.camp(completeness=0.6)
        giver, camp, away = self.hubs(pl)
        raw = self.raw(pl)
        self.assertEqual([v.hub for v in raw.visits], [giver, away])
        lifts, stops = pl._finishable(raw, {self.QA})
        self.assertEqual((lifts, stops), ({0: {self.QA}}, {0: [camp, giver]}))  # the route never comes back to the giver: a stop to hand it in
        passing = engine.Plan(final=raw.final, visits=raw.visits + [engine.Visit(giver, [], 1.0, 0.0, False, raw.final.level)])  # one that does
        self.assertEqual(pl._finishable(passing, {self.QA}), ({0: {self.QA}}, {0: [camp]}))  # the hand-in is left to that visit

    def test_a_stop_that_does_not_finish_the_quest_drops_it_for_good_and_says_so(self):
        pl = self.camp(completeness=0.6)
        giver, camp, away = self.hubs(pl)
        raw = self.raw(pl)
        pl._finishable = lambda plan, candidates: ({0: {self.QA}}, {0: [away]}) if self.QA in candidates else ({}, {})  # a stop that is no use
        pl.rollout = lambda st, steps=None: st  # (and the walk that follows does not happen to pass the camp)
        written = pl.tidy(raw, giver)
        self.assertNotIn(self.QA, written.final.done)
        self.assertEqual(written.final.active, {})  # nothing is left in the log of the written route
        r = self.record(written)
        self.assertEqual(r["code"], "unfinished")
        self.assertIn("still did not finish it", r["why"])

    def test_the_walk_to_hand_a_quest_in_counts_unless_the_route_goes_there_anyway(self):
        pl = self.camp(completeness=0.01)
        giver, camp, away = self.hubs(pl)
        alone = pl.tidy(self.raw_at_giver(pl), giver)  # never goes to the hub where 303 is handed in, 96 s away
        self.assertNotIn(303, alone.final.done)
        r = self.record(alone, 303)
        self.assertEqual(r["code"], "handin")
        self.assertIn("handed in 96 s of walking away and the route does not pass there", r["why"])
        passing = self.camp(completeness=0.01)  # this one goes on to that hub: the hand-in costs nothing
        written = passing.tidy(self.raw(passing), giver)
        self.assertIn(303, written.final.done)
        self.assertEqual([v.hub for v in written.visits].count(away), 1)  # (no stop of its own there)
        wide = self.camp(completeness=0.01, completeness_trip=100.0)
        self.assertIn(303, wide.tidy(self.raw_at_giver(wide), giver).final.done)  # a trip of 100 s covers it, with a stop at the hand-in

    def test_an_objective_with_no_position_is_unplaced_and_the_records_and_the_count_say_so(self):
        pl = self.camp(completeness=0.01, completeness_trip=120.0)
        giver = self.hubs(pl)[0]
        self.assertTrue(pl.unplaced(304))
        self.assertTrue(pl.unplaced(216))
        for placed in (self.QA, 201, 99999):  # an objective with a position, none at all, a quest nobody routes
            self.assertFalse(pl.unplaced(placed), placed)
        written = pl.tidy(self.raw_at_giver(pl), giver)
        self.assertIn(304, written.stats["completed"])  # worked where it is picked up, handed in 96 s away: a stop for that
        self.assertEqual(written.stats["completed_unplaced"], [304])  # and counted, because its work was planned with no walk at all
        short = self.camp(completeness=0.01)
        left = short.tidy(self.raw_at_giver(short), giver)
        r = self.record(left, 304)
        self.assertEqual((r["code"], r["unplaced"]), ("handin", True))
        self.assertIn("an objective of it has no position in the data", r["why"])
        self.assertFalse(self.record(left, 303)["unplaced"])
        self.assertNotIn("no position", self.record(left, 303)["why"])

    def test_a_quest_with_two_objectives_is_walked_to_the_farthest_and_the_stops_go_nearest_first(self):
        pl = self.camp()
        giver, camp, _away = self.hubs(pl)
        q = pl.quests[305]
        far_hub = pl.quests[301].objectives[0].hubs[0]
        far, stops, _end_seconds, end_hub = pl.trip(q, q.start_places[0])
        self.assertAlmostEqual(far, 600 / guide_travel.WALK_SPEED)  # the far boar, 86 s
        self.assertEqual((stops, end_hub), ([camp, far_hub], giver))
        self.assertEqual(pl.trip(pl.quests[201], pl.quests[201].start_places[0])[:2], (0.0, []))  # no objective: nothing to walk to

    def test_a_quest_picked_up_at_the_cap_is_not_finished(self):
        pl = self.camp(completeness=0.01)
        raw = self.raw(pl)
        self.assertEqual(pl._finishable(raw, {self.QA})[0], {0: {self.QA}})
        pl.s = dataclasses.replace(pl.s, cap=raw.visits[0].level)
        self.assertEqual(pl._finishable(raw, {self.QA}), ({}, {}))  # at the cap nothing that is not a class quest pays

    def test_a_calibration_forgets_the_ratios_it_made_before(self):
        pl = self.camp()
        plan = pl.plan("greedy", self.hubs(pl)[0])
        pl._ratio[(self.QA, 1)] = 123.0
        pl.calibrate(plan)
        self.assertEqual(pl._ratio, {})

    def test_nothing_is_dropped_silently(self):
        pl = self.camp()
        written = pl.tidy(self.raw(pl), self.hubs(pl)[0])
        records = written.stats["left_out"]
        self.assertTrue(written.stats["removed"])
        self.assertEqual({r["quest"] for r in records}, set(written.stats["removed"]))  # a record for each quest taken out, and no other
        self.assertTrue(all(r["why"] and r["code"] and r["name"] for r in records))
        json.dumps(records)  # (plan.json carries them)
        skips = pl.skipquests(written)
        for r in records:
            self.assertIn(r["quest"], skips)  # and a #skipquest line, with the reason
            self.assertIn(r["why"], skips[r["quest"]])
        twice = pl.tidy(written, self.hubs(pl)[0])  # a plan tidied twice still says what was taken out
        self.assertEqual({r["quest"] for r in twice.stats["left_out"]}, {r["quest"] for r in records})

    def test_the_pace_is_the_greedy_walks_once_calibrated_and_grinding_before(self):
        pl = self.camp()
        grind = pl.model.grind_xp_per_second(3)
        self.assertEqual(pl.xp_pace(3), grind)
        pl.calibrate(pl.plan("greedy", self.hubs(pl)[0]))
        self.assertGreaterEqual(pl.xp_pace(3), grind)  # no level is paced slower than grinding
        q = pl.quests[self.QA]
        self.assertAlmostEqual(pl.finish_ratio(q, 3), pl._quest_rate(q, 3) / pl.xp_pace(3))


class SettingsTest(unittest.TestCase):
    def test_settings_are_frozen_and_replaceable(self):
        s = engine.Settings()
        self.assertEqual((s.cap, s.hub_radius, s.zone_friction), (30, 150.0, 180.0))
        self.assertEqual((s.completeness, s.completeness_trip), (0.0, 30.0))  # completeness is off until the user has chosen a value
        self.assertEqual(dataclasses.replace(s, cap=20).cap, 20)
        with self.assertRaises(dataclasses.FrozenInstanceError):
            s.cap = 5  # type: ignore[misc]

    def test_slug(self):
        self.assertEqual(engine.slug("Stonetalon Mountains"), "stonetalon-mountains")
        self.assertEqual(engine.slug("Shen'dralas"), "shen-dralas")


if __name__ == "__main__":
    unittest.main()
