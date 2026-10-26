#!/usr/bin/env python3
"""Offline tests for changelog.py and releases.py."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import changelog  # noqa: E402
import releases  # noqa: E402

MODS = {"Vault", "Chat", "Core"}


class ChangelogTests(unittest.TestCase):
    def test_lines_grouped_by_module_with_incidents(self):
        prs = [
            {"number": 12, "title": "feat(Vault): search box in the bag window", "body": ""},
            {"number": 10, "title": "fix(Chat): timestamps no longer doubled", "body": "Incident: abc123def\n"},
            {"number": 11, "title": "chore: bump", "body": ""},
            {"number": 13, "title": "Tidy tooltip code", "labels": [{"name": "bug"}], "body": ""},
        ]
        text = changelog.build(prs, "3.0.0", "stable", "2026-11-01", modules=MODS)
        self.assertIn("## 3.0.0 (2026-11-01)", text)
        self.assertIn("### Chat\n- Fixed: Timestamps no longer doubled (incident abc123def) (#10)", text)
        self.assertIn("### Vault\n- New: Search box in the bag window (#12)", text)
        self.assertIn("### Core\n- Fixed: Tidy tooltip code (#13)", text)
        self.assertNotIn("bump", text)

    def test_unknown_module_fails(self):
        with self.assertRaises(changelog.ChangelogError):
            changelog.build([{"number": 1, "title": "feat(Embers): meter", "body": ""}], "3.0.0", "canary", "x", modules=MODS)

    def test_canary_then_stable_replaces_unreleased(self):
        prs = [{"number": 1, "title": "feat(Vault): sort", "body": ""}]
        canary = changelog.build(prs, "3.0.0-alpha1", "canary", "x", "", MODS)
        self.assertIn(changelog.UNRELEASED, canary)
        stable = changelog.build(prs, "3.0.0", "stable", "2026-11-01", canary, MODS)
        self.assertNotIn(changelog.UNRELEASED, stable)
        self.assertEqual(stable.count("## 3.0.0 (2026-11-01)"), 1)

    def test_real_modules_from_schema_index(self):
        mods = changelog.known_modules()
        self.assertIn("Vault", mods)
        self.assertIn("Core", mods)


class ReleasesTests(unittest.TestCase):
    def test_record_and_merge(self):
        rec = releases.record("3.0.0-alpha1", "canary", "vortexq89/Phoenix_UI", "2026-11-01")
        self.assertEqual(rec["downloadUrls"]["github"],
                         "https://github.com/vortexq89/Phoenix_UI/releases/download/v3.0.0-alpha1/Phoenix_UI-v3.0.0-alpha1.zip")
        self.assertIn("120105", rec["build"])
        data = releases.merge({}, rec)
        self.assertEqual(data["latest"]["canary"]["version"], "3.0.0-alpha1")
        data = releases.merge(data, releases.record("3.0.0", "stable", "vortexq89/Phoenix_UI", "2026-11-02"))
        self.assertEqual(set(data["latest"]), {"canary", "stable"})
        self.assertEqual(len(data["releases"]), 2)
        self.assertIn({"interface": "16001", "name": "Forever"}, data["builds"])

    def test_bad_version(self):
        with self.assertRaises(ValueError):
            releases.record("v3", "canary", "r", "d")


if __name__ == "__main__":
    unittest.main()
