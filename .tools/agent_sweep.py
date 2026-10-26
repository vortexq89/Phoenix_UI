#!/usr/bin/env python3
"""Daily agent sweep over open Sentinel incidents (PUI_V2 16.6 step 1, 16.11).

Reads open issues from the vq8s.com Phoenix API, triages each to S0-S3 and
writes a queue (JSON + Markdown) for the review loop. With --dispatch it hands
S0/S1 issues that are still `new` to POST /phoenix/api/agent/dispatch, which
records an audited hand-off; nothing else is written.

  PHOENIX_READ_TOKEN=... python3 .tools/agent_sweep.py [--base URL] [--dispatch] [--out DIR]

Severity (16.6): S0 login-breaking or data loss, S1 module unusable or taint in
combat, S2 wrong behaviour, S3 cosmetic/perf. The addon's own severity is a
floor; many affected installs or a regression raise it one level.
"""
import argparse, json, os, re, sys, urllib.parse, urllib.request

LEVELS = ["S0", "S1", "S2", "S3"]
TAG_SEVERITY = {"taint": "S1", "secret": "S1", "error": "S2", "integrity": "S2", "drift": "S2", "warning": "S3", "perf": "S3"}
# Errors raised while loading, logging in or touching saved variables break login or lose data.
S0_PATTERN = re.compile(r"Core/(ClientGate|Kernel|DB|Schema)\.lua|PhoenixUIDB|SavedVariables|ADDON_LOADED|PLAYER_LOGIN")
WIDE_INSTALLS = 3


def raise_one(level):
    return LEVELS[max(0, LEVELS.index(level) - 1)]


def worst(*levels):
    return min((l for l in levels if l in LEVELS), key=LEVELS.index, default="S3")


def triage(issue, meta):
    """Returns (severity, reasons) for one issue (list item) and its meta."""
    meta = meta or {}
    tag = meta.get("tag") or issue.get("kind") or "error"
    reasons = []
    level = TAG_SEVERITY.get(tag, "S2")
    reasons.append("kind %s -> %s" % (tag, level))
    text = "%s\n%s" % (issue.get("message") or "", issue.get("stack") or "")
    if tag in ("error", "integrity") and S0_PATTERN.search(text):
        level = "S0"
        reasons.append("load/login/saved-variables path -> S0")
    addon = meta.get("severity") or ""
    if addon in LEVELS and worst(addon, level) == addon and addon != level:
        level = addon
        reasons.append("addon severity %s" % addon)
    if int(issue.get("installs") or 0) >= WIDE_INSTALLS:
        level = raise_one(level)
        reasons.append("%s installs -> +1" % issue.get("installs"))
    if issue.get("regressed"):
        level = raise_one(level)
        reasons.append("regression -> +1")
    return level, reasons


class Api:
    def __init__(self, base, token):
        self.base = base.rstrip("/")
        self.token = token

    def _req(self, method, path, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(self.base + path, data=data, method=method)
        req.add_header("Authorization", "Bearer " + self.token)
        req.add_header("Accept", "application/json")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(req, timeout=30) as res:
            return json.loads(res.read().decode())

    def issues(self, status):
        q = urllib.parse.urlencode({"status": status, "sort": "last", "full": "1", "limit": "200"})
        return self._req("GET", "/phoenix/api/reports?" + q).get("issues", [])

    def meta(self, h):
        return self._req("GET", "/phoenix/api/reports/" + urllib.parse.quote(h) + "?limit=1").get("meta", {})

    def dispatch(self, h):
        return self._req("POST", "/phoenix/api/agent/dispatch", {"hash": h})


def sweep(api, dispatch=False, limit=100):
    queue = []
    for status in ("new", "investigating"):
        for issue in api.issues(status)[:limit]:
            meta = api.meta(issue["hash"])
            level, reasons = triage(issue, meta)
            item = {"hash": issue["hash"], "status": status, "severity": level, "reasons": reasons,
                    "module": meta.get("module", ""), "tag": meta.get("tag", issue.get("kind", "")),
                    "message": (issue.get("message") or "")[:200], "installs": issue.get("installs", 0),
                    "total": issue.get("total", 0), "lastVersion": issue.get("lastVersion", ""), "dispatched": False}
            if dispatch and status == "new" and level in ("S0", "S1"):
                api.dispatch(issue["hash"])
                item["dispatched"] = True
            queue.append(item)
    queue.sort(key=lambda i: (LEVELS.index(i["severity"]), -int(i["installs"] or 0)))
    return queue


def markdown(queue):
    lines = ["# Phoenix agent sweep", "", "| Sev | Module | Kind | Installs | Status | Issue | Dispatched |", "|---|---|---|---|---|---|---|"]
    for i in queue:
        msg = i["message"].replace("|", "/").replace("\n", " ")[:90]
        lines.append("| %s | %s | %s | %s | %s | `%s` %s | %s |" % (i["severity"], i["module"] or "-", i["tag"], i["installs"],
                                                               i["status"], i["hash"][:12], msg, "yes" if i["dispatched"] else ""))
    if not queue:
        lines.append("| - | - | - | - | - | no open incidents | |")
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", default=os.environ.get("PHOENIX_BASE", "https://www.vq8s.com"))
    ap.add_argument("--dispatch", action="store_true", help="hand new S0/S1 issues to the review loop")
    ap.add_argument("--out", default="sweep-out")
    args = ap.parse_args(argv)
    token = os.environ.get("PHOENIX_READ_TOKEN", "")
    if not token:
        print("PHOENIX_READ_TOKEN is not set", file=sys.stderr)
        return 2
    queue = sweep(Api(args.base, token), dispatch=args.dispatch)
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "queue.json"), "w", encoding="utf-8") as fh:
        json.dump(queue, fh, indent=2)
    md = markdown(queue)
    with open(os.path.join(args.out, "queue.md"), "w", encoding="utf-8") as fh:
        fh.write(md)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(md)
    counts = {l: sum(1 for i in queue if i["severity"] == l) for l in LEVELS}
    print("sweep: %d open (%s), %d dispatched" % (len(queue), ", ".join("%s %d" % kv for kv in counts.items()),
                                                  sum(1 for i in queue if i["dispatched"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
