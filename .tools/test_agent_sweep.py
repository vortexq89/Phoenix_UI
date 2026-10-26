"""Unit tests for .tools/agent_sweep.py triage and the sweep loop (offline)."""
import os, sys, unittest
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import agent_sweep as S


class Triage(unittest.TestCase):
    def test_kind_mapping(self):
        self.assertEqual(S.triage({"kind": "error"}, {"tag": "taint"})[0], "S1")
        self.assertEqual(S.triage({"kind": "error"}, {"tag": "secret"})[0], "S1")
        self.assertEqual(S.triage({"kind": "error"}, {"tag": "error"})[0], "S2")
        self.assertEqual(S.triage({"kind": "warning"}, {"tag": "perf"})[0], "S3")

    def test_login_path_is_s0(self):
        issue = {"kind": "error", "message": "x", "stack": "Interface/AddOns/Phoenix_UI/Core/DB.lua:50: boom"}
        self.assertEqual(S.triage(issue, {"tag": "error"})[0], "S0")

    def test_addon_severity_is_a_floor(self):
        self.assertEqual(S.triage({"kind": "warning"}, {"tag": "perf", "severity": "S1"})[0], "S1")
        self.assertEqual(S.triage({"kind": "error"}, {"tag": "taint", "severity": "S3"})[0], "S1")

    def test_escalation(self):
        self.assertEqual(S.triage({"kind": "error", "installs": 5}, {"tag": "error"})[0], "S1")
        self.assertEqual(S.triage({"kind": "error", "regressed": True, "installs": 4}, {"tag": "error"})[0], "S0")
        self.assertEqual(S.triage({"kind": "error", "installs": 9}, {"tag": "taint", "severity": "S0"})[0], "S0")


class FakeApi:
    def __init__(self):
        self.dispatched = []
        self.data = {
            "new": [{"hash": "aaa", "kind": "error", "message": "taint", "installs": 1},
                    {"hash": "bbb", "kind": "warning", "message": "slow", "installs": 1}],
            "investigating": [{"hash": "ccc", "kind": "error", "message": "x", "installs": 1}],
        }
        self.metas = {"aaa": {"tag": "taint", "module": "ActionBars"}, "bbb": {"tag": "perf"}, "ccc": {"tag": "taint"}}

    def issues(self, status): return self.data.get(status, [])
    def meta(self, h): return self.metas[h]
    def dispatch(self, h): self.dispatched.append(h)


class Sweep(unittest.TestCase):
    def test_dry_run_dispatches_nothing(self):
        api = FakeApi()
        q = S.sweep(api)
        self.assertEqual(api.dispatched, [])
        self.assertEqual([i["hash"] for i in q], ["aaa", "ccc", "bbb"])

    def test_dispatch_only_new_s0_s1(self):
        api = FakeApi()
        S.sweep(api, dispatch=True)
        self.assertEqual(api.dispatched, ["aaa"])

    def test_markdown_escapes_pipes(self):
        md = S.markdown([{"severity": "S1", "module": "", "tag": "taint", "installs": 1, "status": "new",
                          "hash": "abcdef0123456789", "message": "a|b", "dispatched": False}])
        self.assertIn("a/b", md)


if __name__ == "__main__":
    unittest.main()
