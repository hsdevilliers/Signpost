import contextlib
import datetime
import io
import tempfile
import unittest
from pathlib import Path

import backlog

DAY = datetime.date(2026, 10, 20)
BODY = "## What\n\nSomething is left over.\n\n## Done when\n\nIt is not."


class FormatTest(unittest.TestCase):
    def test_front_matter_round_trips_and_a_title_may_hold_colons(self):
        meta = {"title": "Steps: pick up, do, hand in", "kind": "feature", "status": "open", "priority": "normal", "source": "user",
                "raised": "2026-10-20", "area": "engine, ui"}
        text = backlog.render(meta, BODY)
        again, body = backlog.parse(text)
        self.assertEqual(again, meta)
        self.assertEqual(body, BODY)
        self.assertTrue(text.startswith("---\ntitle: Steps: pick up, do, hand in\nkind: feature\n"))  # a fixed order

    def test_empty_optional_fields_are_left_out_and_unknown_ones_are_kept(self):
        meta = {"title": "T", "kind": "task", "status": "open", "priority": "low", "source": "claude", "raised": "2026-10-20",
                "area": "", "closed": "", "colour": "red"}
        text = backlog.render(meta, BODY)
        self.assertNotIn("area:", text)
        self.assertNotIn("closed:", text)
        self.assertIn("colour: red", text)

    def test_a_malformed_front_matter_is_an_error_not_a_crash(self):
        for text, message in (
            ("no front matter\n", "start with"),
            ("---\ntitle: x\n", "closing"),
            ("---\ntitle x\n---\nbody", "key: value"),
            ("---\ntitle: a\ntitle: b\n---\nbody", "twice"),
        ):
            with self.assertRaises(ValueError, msg=text) as raised:
                backlog.parse(text)
            self.assertIn(message, str(raised.exception))

    def test_windows_line_endings_parse(self):
        meta, body = backlog.parse("---\r\ntitle: x\r\n---\r\n\r\nWords.\r\n")
        self.assertEqual((meta, body), ({"title": "x"}, "Words."))

    def test_slugs_are_short_lower_case_words(self):
        title = "Steps group by what the player does there: pick up, do, hand in"
        self.assertEqual(backlog.slugify(title), "steps-group-by-what-the-player-does-there-pick-up-do-hand-in")  # 60: it fits
        self.assertEqual(backlog.slugify(title + " and more"), "steps-group-by-what-the-player-does-there-pick-up-do-hand-in")
        self.assertEqual(backlog.slugify("Steps group by what the player does there: pick up, do, handwriting"),
                         "steps-group-by-what-the-player-does-there-pick-up-do")  # a word is never cut in half
        self.assertEqual(backlog.slugify("!!!"), "item")
        self.assertLessEqual(len(backlog.slugify("word " * 40)), backlog.SLUG_LENGTH)
        self.assertLessEqual(len(backlog.slugify("x" * 200)), backlog.SLUG_LENGTH)


class BacklogCase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.root = Path(self.dir.name) / "backlog"

    def add(self, title="A finding", **kw):
        args = dict(kind="finding", source="claude", body=BODY, date=DAY)
        args.update(kw)
        return backlog.add(self.root, title, **args)

    def run_main(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = backlog.main(["--root", str(self.root), *argv])
        return code, out.getvalue()

    def write(self, name, text):
        self.root.mkdir(parents=True, exist_ok=True)
        (self.root / name).write_text(text, encoding="utf-8")


class AddTest(BacklogCase):
    def test_an_item_is_a_dated_file_that_follows_the_rules(self):
        item = self.add("Map markers only steer", kind="feature", source="user", area="ui, engine", raised_in="the planner PR")
        self.assertEqual(item.id, "2026-10-20-map-markers-only-steer")
        self.assertTrue(item.path.is_file())
        self.assertEqual(backlog.check(self.root), [])
        loaded = backlog.load(self.root)[0]
        self.assertEqual(loaded.meta["source"], "user")
        self.assertEqual(loaded.tags, ["ui", "engine"])
        self.assertEqual(loaded.meta["raised_in"], "the planner PR")
        self.assertEqual(loaded.body, BODY)

    def test_the_same_title_on_the_same_day_gets_a_number_and_nothing_is_overwritten(self):
        first, second = self.add("Same"), self.add("Same")
        self.assertEqual((first.id, second.id), ("2026-10-20-same", "2026-10-20-same-2"))
        self.assertEqual(len(backlog.load(self.root)), 2)

    def test_a_bad_item_is_refused_before_it_is_written(self):
        with self.assertRaises(SystemExit) as raised:
            self.add("Loud", area="Engine")
        self.assertIn("lower-case tag", str(raised.exception))
        with self.assertRaises(SystemExit):
            self.add("No words", body="## What\n\n## Why")
        self.assertEqual(backlog.load(self.root), [])

    def test_the_command_line_needs_the_text(self):
        with self.assertRaises(SystemExit) as raised:
            self.run_main("add", "No text", "--kind", "task", "--source", "claude")
        self.assertIn("--body", str(raised.exception))
        body = Path(self.dir.name) / "text.md"
        body.write_text(BODY, encoding="utf-8")
        code, text = self.run_main("add", "From a file", "--kind", "task", "--source", "claude", "--body-file", str(body), "--date", "2026-10-20")
        self.assertEqual(code, 0)
        self.assertIn("added 2026-10-20-from-a-file", text)


class LifecycleTest(BacklogCase):
    def test_closing_records_the_date_and_what_was_done_and_hides_the_item(self):
        item = self.add("Fix the thing")
        backlog.close(item, "PR #36: fixed", datetime.date(2026, 10, 21))
        again = backlog.load(self.root)[0]
        self.assertEqual((again.status, again.meta["closed"], again.meta["resolution"]), ("done", "2026-10-21", "PR #36: fixed"))
        self.assertEqual(backlog.check(self.root), [])
        self.assertNotIn("fix-the-thing", self.run_main("list")[1])
        self.assertIn("fix-the-thing", self.run_main("list", "--all")[1])
        with self.assertRaises(SystemExit):
            backlog.close(again, "again")
        with self.assertRaises(SystemExit):
            backlog.set_status(again, "open")  # closed items are not reopened

    def test_an_item_the_user_raised_is_dropped_only_with_their_agreement(self):
        mine = self.add("Claude's own", source="claude")
        theirs = self.add("The user's", source="user")
        backlog.drop(mine, "no longer true", date=DAY)
        with self.assertRaises(SystemExit) as raised:
            backlog.drop(theirs, "not needed")
        self.assertIn("after they agree", str(raised.exception))
        backlog.drop(theirs, "not needed", agreed="the user, 2026-10-21: leave that one out", date=DAY)
        dropped = {i.id: i for i in backlog.load(self.root)}["2026-10-20-the-user-s"]
        self.assertTrue(dropped.meta["resolution"].startswith("the user agreed (the user, 2026-10-21"))
        self.assertEqual(backlog.check(self.root), [])

    def test_doing_and_open_are_the_only_states_to_move_between(self):
        item = self.add("Work on it")
        backlog.set_status(item, "doing")
        self.assertEqual(backlog.load(self.root)[0].status, "doing")
        self.assertIn("[doing]", self.run_main("list")[1])
        backlog.set_status(backlog.load(self.root)[0], "open")
        self.assertEqual(backlog.load(self.root)[0].status, "open")

    def test_an_item_is_found_by_any_unique_part_of_its_id(self):
        self.add("Alpha beta")
        self.add("Alpha gamma")
        items = backlog.load(self.root)
        self.assertEqual(backlog.find(items, "beta").id, "2026-10-20-alpha-beta")
        self.assertEqual(backlog.find(items, "2026-10-20-alpha-gamma").id, "2026-10-20-alpha-gamma")
        with self.assertRaises(SystemExit) as several:
            backlog.find(items, "alpha")
        self.assertIn("several", str(several.exception))
        with self.assertRaises(SystemExit) as none:
            backlog.find(items, "zeta")
        self.assertIn("no item", str(none.exception))


class ListTest(BacklogCase):
    def test_open_items_come_by_priority_and_can_be_narrowed(self):
        self.add("Low one", priority="low", kind="task", area="docs")
        self.add("High one", priority="high", kind="bug", source="user", area="ui")
        self.add("Normal one", kind="question", area="ui, planner")
        code, text = self.run_main("list")
        self.assertEqual(code, 0)
        self.assertLess(text.index("High one"), text.index("Normal one"))
        self.assertLess(text.index("Normal one"), text.index("Low one"))
        self.assertIn("3 open, 0 closed", text)
        self.assertIn("High one", self.run_main("list", "--source", "user")[1])
        self.assertNotIn("High one", self.run_main("list", "--kind", "question")[1])
        self.assertIn("Normal one", self.run_main("list", "--area", "planner")[1])
        self.assertIn("nothing here", self.run_main("list", "--area", "release")[1])

    def test_within_a_priority_what_the_user_raised_comes_first(self):
        self.add("A finding", source="claude")
        self.add("Z user note", source="user", kind="feature")
        text = self.run_main("list")[1]
        self.assertLess(text.index("Z user note"), text.index("A finding"))

    def test_no_command_lists_and_an_empty_backlog_is_not_an_error(self):
        code, text = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("0 open", text)

    def test_show_prints_the_file(self):
        self.add("Show me")
        code, text = self.run_main("show", "show-me")
        self.assertEqual(code, 0)
        self.assertIn("title: Show me", text)
        self.assertIn("Something is left over.", text)


class CheckTest(BacklogCase):
    GOOD = "---\ntitle: Fine\nkind: task\nstatus: open\npriority: normal\nsource: claude\nraised: 2026-10-20\n---\n\nWords.\n"

    def problems_of(self, name, text):
        self.write(name, text)
        return [p for p in backlog.check(self.root) if p.startswith(name)]

    def test_a_good_file_passes_and_the_readme_is_not_an_item(self):
        self.write("2026-10-20-fine.md", self.GOOD)
        self.write("README.md", "not an item")
        self.assertEqual(backlog.check(self.root), [])

    def test_each_rule_is_reported_with_the_file_name(self):
        cases = {
            "fine.md": (self.GOOD, "file name"),
            "2026-10-20-a.md": ("no front matter", "start with"),
            "2026-10-20-b.md": (self.GOOD.replace("kind: task", "kind: idea"), "kind: 'idea'"),
            "2026-10-20-c.md": (self.GOOD.replace("status: open", "status: maybe"), "status: 'maybe'"),
            "2026-10-20-d.md": (self.GOOD.replace("raised: 2026-10-20", "raised: 2026-10-21"), "does not match the date"),
            "2026-10-20-e.md": (self.GOOD.replace("raised: 2026-10-20", "raised: soon"), "not a date"),
            "2026-10-20-f.md": (self.GOOD.replace("source: claude\n", ""), "source: missing"),
            "2026-10-20-g.md": (self.GOOD.replace("kind: task\n", "kind: task\ncolour: red\n"), "colour: not a field"),
            "2026-10-20-h.md": (self.GOOD.replace("status: open", "status: done"), "closed:"),
            "2026-10-20-i.md": (self.GOOD.replace("status: open", "status: done\nclosed: 2026-10-21"), "resolution:"),
            "2026-10-20-j.md": (self.GOOD.replace("status: open", "status: open\nclosed: 2026-10-21"), "only a done or dropped"),
            "2026-10-20-k.md": (self.GOOD.replace("Words.", "## Only a heading"), "body: empty"),
            "2026-10-20-l.md": (self.GOOD.replace("title: Fine", "title: " + "long " * 30), "title: longer"),
            "2026-10-20-m.md": (self.GOOD.replace("kind: task", "kind: task\narea: Big Area"), "lower-case tag"),
            "2026-10-20-n.md": (
                self.GOOD.replace("source: claude", "source: user").replace("status: open", "status: dropped\nclosed: 2026-10-21\nresolution: nah"),
                "only with their agreement",
            ),
            "2026-10-20-o.md": (self.GOOD.replace("status: open", "status: done\nclosed: 2026-10-19\nresolution: ok"), "before it was raised"),
        }
        for name, (text, expected) in cases.items():
            found = self.problems_of(name, text)
            self.assertTrue(any(expected in p for p in found), (name, expected, found))

    def test_the_command_exits_1_on_a_problem(self):
        self.write("2026-10-20-bad.md", "nothing")
        code, text = self.run_main("check")
        self.assertEqual(code, 1)
        self.assertIn("1 problem(s)", text)


class RepositoryBacklogTest(unittest.TestCase):
    def test_the_backlog_of_this_repository_follows_its_rules(self):
        self.assertTrue((backlog.BACKLOG / "README.md").is_file())
        self.assertEqual(backlog.check(backlog.BACKLOG), [])


if __name__ == "__main__":
    unittest.main()
