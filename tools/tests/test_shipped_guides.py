"""The shipped guides agree with the shipped rules.

A guide the Route Planner made (tools/drafts.json says "planned") is generated: the rules in tools/hardcore_rules.json and the
chapters are two files that drift apart whenever a rule is added and the guide is not made again. This reads both and fails
when a planned guide still accepts a quest the rules skip for it, and says which command makes the guide again. No data pack is
needed: it reads the repository only (the guide file, its chapters, the manifest and the rules).
"""

import json
import re
import unittest
from pathlib import Path

import guide_draft

ROOT = Path(__file__).resolve().parents[2]
ACCEPT = re.compile(r"^\s*\.accept\s+(\d+)", re.M)
INCLUDE = re.compile(r"^#include\s+(\S+)", re.M)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def guide_text(guide_id: str) -> str | None:
    """The text block of the guide file that registers `guide_id`."""
    for path in sorted((ROOT / "Guides").glob("*.lua")):
        text = read(path)
        if re.search(r'\bid\s*=\s*"%s"' % re.escape(guide_id), text):
            block = re.search(r"\btext\s*=\s*\[\[\n(.*?)\]\],", text, re.S)
            return block.group(1) if block else None
    return None


def accepted(guide_id: str) -> dict[int, str]:
    """Every quest the guide's chapters accept, with the chapter that does."""
    found: dict[int, str] = {}
    text = guide_text(guide_id) or ""
    for chapter in INCLUDE.findall(text):
        path = ROOT / "Guides" / "Chapters" / f"{chapter}.lua"
        if path.exists():
            for quest in ACCEPT.findall(read(path)):
                found.setdefault(int(quest), chapter)
    return found


def guide_class(guide_id: str) -> str | None:
    """The class token of the guide's registration (`classes = { "DRUID" }`), which tells a rule's `class_quest_of` whose guide this is."""
    for path in sorted((ROOT / "Guides").glob("*.lua")):
        text = read(path)
        if re.search(r'\bid\s*=\s*"%s"' % re.escape(guide_id), text):
            found = re.search(r'\bclasses\s*=\s*\{\s*"(\w+)"', text)
            return found.group(1) if found else None
    return None


def skipped(rules: list, hardcore: bool, class_token: str | None = None) -> dict[int, dict]:
    """The quests the rules skip for a route of this kind and class: a reason that is not about HARDCORE holds for every route, and a rule
    with `class_quest_of` holds for the guides of every other class (guide_draft.rule_applies, the drafter's own test)."""
    return {
        rule["id"]: rule
        for rule in rules
        if rule.get("action") == "skip"
        and (hardcore or not str(rule.get("reason", "")).startswith("HARDCORE"))
        and (class_token is None or guide_draft.rule_applies(rule, class_token))
    }


class ShippedGuidesTest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(read(ROOT / "tools" / "drafts.json"))
        self.rules = json.loads(read(ROOT / "tools" / "hardcore_rules.json"))["rules"]
        self.planned = [entry for entry in self.manifest["guides"] if entry.get("planned")]

    def test_the_manifest_names_planned_guides_with_chapters(self):
        # guards the test below: without a planned guide or its chapters it would check nothing
        self.assertTrue(self.planned)
        for entry in self.planned:
            self.assertTrue(accepted(entry["guide"]), f"{entry['guide']} accepts no quest in its chapters")

    def test_each_planned_guide_names_its_class(self):
        # guards the class-scoped rules: without a class every `class_quest_of` rule would be applied as if it were for another class
        for entry in self.planned:
            self.assertTrue(guide_class(entry["guide"]), f"{entry['guide']} registers no classes = {{ ... }}")

    def test_a_class_scoped_rule_is_left_to_the_guide_of_that_class(self):
        rule = {"id": 1, "action": "skip", "reason": "x", "class_quest_of": "WARLOCK"}
        self.assertIn(1, skipped([rule], False, "HUNTER"))
        self.assertNotIn(1, skipped([rule], False, "WARLOCK"))

    def test_the_rules_skip_something_for_each_planned_guide(self):
        # guards the test below the other way: rules that were read as empty would let it pass without checking anything
        for entry in self.planned:
            self.assertTrue(
                skipped(self.rules, bool(entry.get("hardcore")), guide_class(entry["guide"])),
                f"no rule skips a quest for {entry['guide']}",
            )

    def test_a_planned_guide_accepts_no_quest_the_rules_skip(self):
        problems = []
        for entry in self.planned:
            quests = accepted(entry["guide"])
            for qid, rule in skipped(self.rules, bool(entry.get("hardcore")), guide_class(entry["guide"])).items():
                if qid in quests:
                    problems.append(
                        f"{entry['guide']} accepts quest {qid} ({rule.get('name')}) in {quests[qid]}, which tools/hardcore_rules.json skips: "
                        f"{rule.get('reason')} -- make the guide again: {entry['planned'].split(': ', 1)[-1]}"
                    )
        self.assertEqual(problems, [], "\n" + "\n".join(problems))


if __name__ == "__main__":
    unittest.main()
