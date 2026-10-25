import io
import json
import os
import shutil
import tempfile
import unittest

from sentinel_companion import core, exportstring, luasv, payload, redact
from sentinel_companion.config import Config
from sentinel_companion.state import State

HERE = os.path.dirname(__file__)
FIXTURE = os.path.join(HERE, "fixtures", "Phoenix_UI_Sentinel.lua")


def db():
    return core.read_db(FIXTURE)


class LuaTests(unittest.TestCase):
    def test_types_and_escapes(self):
        v = luasv.loads('X = { ["a"] = "q\\"\\n\\065", [1] = 2.5, [2] = -3, b = true, ["c"] = nil, [3] = 0x10, } -- end\nY = 1')
        self.assertEqual(v["X"]["a"], 'q"\nA')
        self.assertEqual(v["X"][1], 2.5)
        self.assertEqual(v["X"]["b"], True)
        self.assertEqual(v["Y"], 1)
        self.assertEqual(luasv.as_list({1: "a", 2: "b"}), ["a", "b"])

    def test_fixture(self):
        d = db()
        self.assertEqual(d["session"], 3)
        self.assertEqual(len(luasv.as_list(d["heartbeats"])), 1)

    def test_errors(self):
        with self.assertRaises(luasv.LuaParseError):
            luasv.loads("X = { ")


class PayloadTests(unittest.TestCase):
    def test_contract_v2_shape_and_stable_ids(self):
        p, why = payload.build(db())
        self.assertIsNone(why)
        self.assertEqual(p["schema"], 2)
        kinds = sorted(r["kind"] for r in p["reports"])
        self.assertEqual(kinds, ["error", "heartbeat", "taint", "test"])
        err = next(r for r in p["reports"] if r["kind"] == "error")
        self.assertEqual(err["id"], "0123456789abcdef0123456789abcdef-3-%d" % int("1a2b3c4d", 16))
        self.assertEqual(err["context"]["zone"], "Dornogal")
        hb = next(r for r in p["reports"] if r["kind"] == "heartbeat")
        self.assertEqual(hb["id"], "0123456789abcdef0123456789abcdef-2-0")
        self.assertEqual(hb["context"]["errors"], 2)
        t = next(r for r in p["reports"] if r["kind"] == "test")
        self.assertFalse(t["context"]["failed"])

    def test_opt_in_required(self):
        d = db()
        d["optIn"] = False
        p, why = payload.build(d)
        self.assertIsNone(p)
        self.assertIn("off", why)

    def test_stable_n_matches_addon(self):
        self.assertEqual(payload.stable_n("0000000a"), 10)
        self.assertLess(payload.stable_n("test-1-2"), 2 ** 32)


class RedactTests(unittest.TestCase):
    def test_rules(self):
        s = redact.text('C:\\Users\\Vorte\\x me@example.com Player#1234 ingestKey=abc', names=("VORTEACC",))
        self.assertNotIn("Vorte", s)
        self.assertNotIn("example.com", s)
        self.assertNotIn("#1234", s)
        self.assertNotIn("abc", s)
        self.assertEqual(redact.text("key = 'core.locale'"), "key = 'core.locale'")

    def test_prepare_redacts_and_attaches_taint(self):
        log = "1/1 12:00 Global variable X tainted by Phoenix_UI - Interface/AddOns/Phoenix_UI/Core/Kernel.lua:10\nunrelated\n"
        p, _ = core.prepare(db(), ("MYACCOUNT",), log)
        err = next(r for r in p["reports"] if r["kind"] == "error")
        self.assertIn("<user>", err["locals"])
        self.assertIn("<email>", err["locals"])
        tnt = next(r for r in p["reports"] if r["kind"] == "taint")
        self.assertIn("--- taint.log ---", tnt["locals"])
        self.assertIn("tainted by Phoenix_UI", tnt["locals"])


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class RunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        acct = os.path.join(self.tmp, "wow", "WTF", "Account", "MYACCOUNT", "SavedVariables")
        os.makedirs(acct)
        shutil.copy(FIXTURE, acct)
        self.cfgpath = os.path.join(self.tmp, "cfg", "config.json")
        os.makedirs(os.path.dirname(self.cfgpath))
        with open(self.cfgpath, "w") as fh:
            json.dump({"wowPath": os.path.join(self.tmp, "wow"), "endpoint": "https://example.invalid/phoenix/api/ingest", "ingestKey": "k" * 16}, fh)
        self.sent = []

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def opener(self, req, timeout=0):
        body = json.loads(req.data.decode())
        self.sent.append((req, body))
        return FakeResponse(json.dumps({"ok": True, "accepted": len(body["reports"]), "updated": 0, "duplicates": 0, "rejected": []}).encode())

    def test_once_uploads_then_dedupes_and_never_logs_the_key(self):
        logs = []
        cfg = Config(self.cfgpath)
        core.run_once(cfg, log=logs.append, opener=self.opener)
        self.assertEqual(len(self.sent), 1)
        req, body = self.sent[0]
        self.assertEqual(req.get_header("X-phoenix-key"), "k" * 16)
        self.assertEqual(body["schema"], 2)
        self.assertNotIn("MYACCOUNT", json.dumps(body))
        self.assertTrue(any("1a2b3c4d" in l for l in logs), logs)
        core.run_once(Config(self.cfgpath), log=logs.append, opener=self.opener)
        self.assertEqual(len(self.sent), 1, "nothing new -> nothing sent")
        st = State(cfg.state_path)
        st.sent["0123456789abcdef0123456789abcdef-3-%d" % int("1a2b3c4d", 16)] = 1
        st.save()
        core.run_once(Config(self.cfgpath), log=logs.append, opener=self.opener)
        self.assertEqual(len(self.sent[1][1]["reports"]), 1, "a grown count is re-sent")
        self.assertFalse(any("k" * 16 in l for l in logs))
        self.assertNotIn("k" * 16, repr(cfg))


class ExportStringTests(unittest.TestCase):
    def test_round_trip(self):
        p, _ = payload.build(db())
        for wbits in (-15, 15):
            self.assertEqual(exportstring.decode(exportstring.encode(p, wbits)), json.loads(json.dumps(p, sort_keys=True)))
        with self.assertRaises(ValueError):
            exportstring.decode("nope")


if __name__ == "__main__":
    unittest.main()
