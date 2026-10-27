"""Builds the contract v2 upload (PUI_V2 17.3) from PhoenixUISentinelDB,
mirroring Phoenix_UI_Sentinel/Export.lua (same ids, so re-sends dedupe)."""
from . import VERSION
from .luasv import as_list

CONTRACT = 2
REPORT_KINDS = {"error", "taint", "secret", "perf", "integrity", "drift", "heartbeat", "test"}


def stable_n(h):
    try:
        if len(h) <= 8:
            return int(h, 16)
    except ValueError:
        pass
    n = 0
    for ch in h.encode("utf-8"):
        n = (n * 31 + ch) % 4294967296
    return n


def _clean(d):
    return {k: v for k, v in d.items() if v is not None}


def _plain(v):
    """Lua tables -> JSON-friendly values (arrays become lists)."""
    if isinstance(v, dict):
        if v and all(isinstance(k, int) for k in v):
            return [_plain(x) for x in as_list(v)]
        return {str(k): _plain(x) for k, x in v.items()}
    return v


def incident_report(inc, db):
    session = inc.get("lastSession") or inc.get("session") or 0
    return _clean({
        "id": "%s-%d-%d" % (db["installId"], session, stable_n(str(inc.get("hash", "")))),
        "hash": inc.get("hash"), "kind": inc.get("kind"), "message": inc.get("message"), "stack": inc.get("stack"),
        "locals": inc.get("locals"), "count": inc.get("count"), "firstSeen": inc.get("firstSeen"),
        "lastSeen": inc.get("lastSeen"), "session": session, "addonVersion": inc.get("addonVersion"),
        "interface": inc.get("interface"), "build": inc.get("build"), "locale": inc.get("locale"), "source": "sentinel",
        "module": inc.get("module"), "severity": inc.get("severity"), "track": inc.get("track"),
        "context": _plain(inc.get("context")), "extra": _plain(inc.get("extra")), "apiFamily": inc.get("apiFamily"),
    })


def build(db):
    """-> (payload, None) or (None, reason). Requires the in-game opt-in."""
    if not isinstance(db, dict) or not db.get("installId"):
        return None, "no Sentinel data yet (log in once with Phoenix UI)"
    if not db.get("optIn"):
        return None, "Share diagnostics is off in game (/pui sentinel), nothing is uploaded"
    outbox = db.get("outbox")
    if isinstance(outbox, dict) and outbox.get("reports") is not None:
        # Built in game by Export:Payload() with the privacy kit applied: the
        # exact payload the in-game Preview shows (step 9c).
        reports = [_plain(r) for r in as_list(outbox.get("reports")) if isinstance(r, dict)]
        return {"schema": CONTRACT, "installId": db["installId"], "uploader": "sentinel-companion " + VERSION, "reports": reports}, None
    reports = []
    incidents = db.get("incidents") or {}
    for h in sorted(incidents, key=str):
        inc = incidents[h]
        if isinstance(inc, dict) and inc.get("kind") in REPORT_KINDS:
            reports.append(incident_report(inc, db))
    for hb in as_list(db.get("heartbeats")):
        s = hb.get("session", 0)
        reports.append(_clean({
            "id": "%s-%d-0" % (db["installId"], s), "kind": "heartbeat", "hash": "heartbeat-%d" % s,
            "message": "session health", "count": 1, "firstSeen": hb.get("at"), "lastSeen": hb.get("at"), "session": s,
            "addonVersion": hb.get("version"), "interface": hb.get("interface"), "build": hb.get("build"),
            "source": "sentinel", "module": "Core", "track": hb.get("track"), "context": _plain(hb),
        }))
    for i, t in enumerate(as_list(db.get("tests")), 1):
        s = t.get("session", 0)
        reports.append(_clean({
            "id": "%s-%d-%d" % (db["installId"], s, t.get("at") or i), "kind": "test", "hash": "test-%d-%d" % (s, i),
            "message": t.get("summary"), "count": 1, "firstSeen": t.get("at"), "lastSeen": t.get("at"), "session": s,
            "addonVersion": t.get("version"), "build": t.get("build"), "source": "sentinel", "module": "Tests",
            "context": _plain(t),
        }))
    return {"schema": CONTRACT, "installId": db["installId"], "uploader": "sentinel-companion " + VERSION, "reports": reports}, None
