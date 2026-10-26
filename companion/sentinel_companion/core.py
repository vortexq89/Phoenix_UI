"""One check: read every Phoenix_UI_Sentinel.lua, build, redact, dedupe, upload."""
import os

from . import luasv, payload as payload_mod, redact, taint
from .state import State
from .upload import send


def read_db(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return luasv.loads(fh.read()).get("PhoenixUISentinelDB")


def prepare(db, names=(), taint_text=""):
    """-> (payload, reason). Payload is redacted with the taint section attached."""
    p, why = payload_mod.build(db)
    if not p:
        return None, why
    taint.attach(p, taint_text)
    p["reports"] = [redact.deep(r, names) for r in p["reports"]]
    return p, None


def account_names(sv_path):
    """The account folder name is personal: redact it from every text field."""
    parts = os.path.normpath(sv_path).split(os.sep)
    try:
        return (parts[parts.index("Account") + 1],)
    except (ValueError, IndexError):
        return ()


def run_once(cfg, log=print, opener=None, dry_run=False):
    files = cfg.saved_variables()
    if not files:
        log("no %s under %s (set wowPath)" % ("Phoenix_UI_Sentinel.lua", cfg.wow_path or "<unset>"))
        return []
    state = State(cfg.state_path)
    taint_text = taint.read_tail(cfg.taint_log())
    results = []
    for path in files:
        p, why = prepare(read_db(path), account_names(path), taint_text)
        if not p:
            log("%s: %s" % (os.path.basename(os.path.dirname(os.path.dirname(path))), why))
            continue
        todo = state.pending(p["reports"])
        if not todo:
            continue
        if dry_run:
            log("would send %d report(s)" % len(todo))
            results.append({"pending": len(todo)})
            continue
        if cfg.key_status() != "set":
            log("ingest key missing: set ingestKey in %s or PHOENIX_INGEST_KEY" % cfg.path)
            return results
        r = send(cfg.endpoint, cfg.ingest_key, dict(p, reports=todo), opener=opener)
        rejected = {x.get("id") for x in r["rejected"]}
        state.mark([x for x in todo if x["id"] not in rejected])
        state.save()
        incidents = sorted({x["hash"] for x in todo if x["kind"] not in ("heartbeat", "test")})
        log("sent %d report(s): %d new, %d updated, %d rejected%s" % (
            len(todo), r["accepted"], r["updated"], len(r["rejected"]),
            ("; incident ids: " + ", ".join(incidents)) if incidents else ""))
        results.append(r)
    return results
