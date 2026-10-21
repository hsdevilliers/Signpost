import dataclasses
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



class AreaTest(PlannerCase):
    """A quest picked up with all its work near is done on the spot (user, 2026-10-21): a quest offered where the player stands, with its
    objectives in the area of the step in hand, should be taken. The unit fixture's map is 1000 yards wide and 2000 tall: 1% of x is 10 yards, 1% of y
    is 20 yards."""

    CAMP = {1010: {"n": "Camp Boar", "p": [[10, 40, 52]], "side": "none"}}  # 240 yards south of the giver at 40,40: another hub, inside the area
    FAR = {1011: {"n": "Far Boar", "p": [[10, 40, 70]], "side": "none"}}  # 600 yards south: outside it
    ELITE = {1012: {"n": "Camp Chief", "p": [[10, 42, 52]], "side": "none", "rank": 1}}

    def quests(self):
        return {
            **QUESTS,
            300: {"n": "Camp Cleanup", "r": 1, "l": 1, "o": [{"id": 1010, "k": "kill"}], **HOME},
            301: {"n": "Far Hunt", "r": 1, "l": 1, "o": [{"id": 1011, "k": "kill"}], **HOME},
            302: {"n": "Camp Report", "r": 1, "l": 1, "preSingle": [300], **HOME},  # offered by the hand-in of 300, at the same NPC
            303: {"n": "Camp Chief", "r": 1, "l": 1, "o": [{"id": 1012, "k": "kill"}], **HOME},  # an elite: a group quest in a normal route
        }

    def area(self, yards=350.0, **settings):
        return self.planner(quests=self.quests(), npcs={**NPCS, **self.CAMP, **self.FAR, **self.ELITE}, area_yards=yards, **settings)

    def first_visit(self, pl):
        hub = pl.quests[300].start_hubs[0]
        return hub, pl.visit(pl.start(hub), hub)

    @staticmethod
    def acts(child, *quests):
        return [(a.kind, a.quest) for a in child.visit.actions if a.quest in quests]

    def test_the_default_is_on_and_the_area_is_a_minutes_walk(self):
        self.assertEqual(engine.Settings().area_yards, 350.0)

    def test_a_quest_picked_up_with_all_its_work_near_is_worked_and_handed_in_before_the_visit_ends(self):
        pl = self.area()
        hub, child = self.first_visit(pl)
        self.assertEqual(
            self.acts(child, 300, 302),
            [("accept", 300), ("complete", 300), ("turnin", 300), ("accept", 302), ("turnin", 302)],  # 302 is offered by the hand-in, and has no work
        )
        work = next(a for a in child.visit.actions if a.kind == "complete" and a.quest == 300)
        self.assertEqual((work.index, work.place.map, work.place.y), (1, 10, 52.0))  # worked at the camp, a hub of its own
        self.assertNotEqual(pl.hub_of[(work.place.map, work.place.x, work.place.y)], hub)
        self.assertNotIn(300, child.active)  # nothing is left in the log for tidy to drop
        self.assertIn(300, child.done)

    def test_without_the_rule_the_quest_is_only_picked_up_and_stays_in_the_log(self):
        pl = self.area(0.0)
        _, child = self.first_visit(pl)
        self.assertEqual(self.acts(child, 300, 302), [("accept", 300)])
        self.assertIn(300, child.active)

    def test_work_beyond_the_area_is_left_for_a_later_visit(self):
        pl = self.area()
        _, child = self.first_visit(pl)
        self.assertEqual(self.acts(child, 301), [("accept", 301)])  # 600 yards from the giver: picked up, not done on the spot
        self.assertIn(301, child.active)
        wide = self.area(700.0)
        self.assertEqual(self.acts(self.first_visit(wide)[1], 301), [("accept", 301), ("complete", 301), ("turnin", 301)])

    def test_a_group_quest_is_not_asked_for_on_the_spot(self):
        pl = self.area()
        self.assertTrue(pl.quests[303].optional)
        self.assertEqual(pl.quests[303].bundle, {})
        self.assertNotIn(303, pl.bundles(350.0)[0])
        _, child = self.first_visit(pl)
        self.assertEqual(self.acts(child, 303), [("accept", 303)])

    def test_the_walk_to_the_camp_and_back_is_priced_by_the_map(self):
        on, off = self.first_visit(self.area())[1], self.first_visit(self.area(0.0))[1]
        extra = on.visit.travel_seconds - off.visit.travel_seconds
        self.assertAlmostEqual(extra, 2 * 240 / guide_travel.WALK_SPEED)  # there and back, 240 yards each way: the map's distance, not a flat local_walk
        self.assertGreater(on.clock, off.clock)  # the visit takes longer: the work is done in it
        self.assertGreater(on.xp, off.xp)  # and it has levelled the character

    def test_the_bundles_say_where_the_work_is_and_how_near(self):
        pl = self.area()
        by_quest, by_hub = pl.bundles(350.0)
        giver = (10, 40.0, 40.0)
        bundle = by_quest[300][giver]
        self.assertEqual([(c.x, c.y) for c in bundle.ends], [(40.0, 40.0)])
        self.assertEqual([(index, [(c.x, c.y) for c in spots]) for index, spots in bundle.works], [(1, [(40.0, 52.0)])])
        self.assertIn(pl.quests[300], by_hub[pl.hub_of[giver]])
        self.assertNotIn(301, by_quest)  # 600 yards
        self.assertNotIn(300, pl.bundles(200.0)[0])  # 240 yards is outside a smaller area
        self.assertEqual(pl.quests[300].bundle, by_quest[300])  # what the visits use is the setting's radius
        self.assertEqual(self.area(0.0).quests[300].bundle, {})

    def test_a_quest_the_search_picked_up_and_never_finished_is_not_dropped_when_the_route_is_written(self):
        # the Skyborne gap: the beam picks up a free quest, never goes back for its work, and tidy takes it out as 'never finished'
        off, on = self.area(0.0), self.area()
        hub = off.quests[300].start_hubs[0]
        written_off = off.tidy(off._finish(off.visit(off.start(hub), hub)), hub)
        self.assertNotIn(300, written_off.final.done)  # accepted by the search, left in the log, taken out
        self.assertIn(300, written_off.stats["removed"])
        self.assertIn(300, [qid for qid, _hub, _level in off.area_misses(written_off, 350.0)])  # and the audit names it
        written_on = on.tidy(on._finish(on.visit(on.start(hub), hub)), hub)
        self.assertIn(300, written_on.final.done)
        self.assertIn(302, written_on.final.done)
        self.assertNotIn(300, written_on.stats["removed"])
        self.assertEqual([qid for qid, _hub, _level in on.area_misses(written_on) if qid in (300, 302)], [])

    def test_every_search_takes_the_free_quests_and_the_audit_finds_none_left(self):
        pl = self.area(width=10, branch=6)
        hub = self.start(pl)
        for preset in ("greedy", "lookahead", "beam"):
            plan = pl.plan(preset, hub)
            self.assertTrue(plan.complete, preset)
            self.assertTrue({300, 302} <= plan.final.done, preset)
            self.assertEqual(pl.area_misses(plan), [], preset)

    def test_the_audit_lists_what_a_route_without_the_rule_left_out_with_the_hub_and_level(self):
        pl = self.area(0.0)
        hub = pl.quests[300].start_hubs[0]
        written = pl.tidy(pl._finish(pl.visit(pl.start(hub), hub)), hub)
        missed = {qid: (h, level) for qid, h, level in pl.area_misses(written, 350.0)}
        self.assertEqual(missed[300][0], hub)
        self.assertGreaterEqual(missed[300][1], 1)
        self.assertNotIn(301, missed)  # its work is too far to count
        self.assertEqual(len([m for m in pl.area_misses(written, 350.0) if m[0] == 300]), 1)  # named once
        self.assertEqual(pl.area_misses(written, 100.0), [m for m in pl.area_misses(written, 100.0) if m[0] != 300])  # with a smaller area it is not named

    def test_the_written_steps_pick_up_work_and_hand_in_in_that_order(self):
        pl = self.area(width=10, branch=6)
        plan = pl.plan("greedy", self.start(pl))
        text = "\n".join(c.text("West") for c in pl.emit(plan, "HUNTER"))
        accept, work, turnin = (text.index(f".{kind} 300") for kind in ("accept", "complete", "turnin"))
        self.assertLess(accept, work)
        self.assertLess(work, turnin)
        self.assertIn(".goto 10,40.0,52.0", text[accept:work])  # the camp has a step of its own, with its place


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
