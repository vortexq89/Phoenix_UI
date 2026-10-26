#!/usr/bin/env python3
"""Builds releases.json and the release record for the Phoenix site (PUI_V2 17.2).

releases.json keeps the latest stable and canary entries plus a short history;
the same entry is what release.yml posts to /phoenix/api/release when (and only
when) a manual run asks to publish. Supported game builds come from the
## Interface line of Phoenix_UI.toc.

    python3 .tools/releases.py --version 3.0.0-alpha1 --track canary --repo vortexq89/Phoenix_UI \
        [--in releases.json] --out releases.json --record release-record.json
"""
import argparse
import datetime
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:-[A-Za-z0-9.]+)?$")
BUILD_NAMES = {"120100": "12.1.0", "120105": "12.1.5", "16001": "Forever"}


def interfaces(root=ROOT):
    with open(os.path.join(root, "Phoenix_UI.toc"), encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("## Interface:"):
                return [v.strip() for v in line.split(":", 1)[1].split(",") if v.strip()]
    return []


def record(version, track, repo, date):
    if not VERSION_RE.match(version):
        raise ValueError("version must look like 3.0.0 or 3.0.0-alpha1")
    if track not in ("canary", "stable"):
        raise ValueError("track must be canary or stable")
    tag = "v" + version
    base = "https://github.com/%s/releases" % repo
    return {
        "version": version, "track": track, "build": ",".join(interfaces()), "publishedAt": date,
        "changelogUrl": "%s/tag/%s" % (base, tag),
        "downloadUrls": {"github": "%s/download/%s/Phoenix_UI-%s.zip" % (base, tag, tag)},
    }


def merge(existing, rec):
    data = existing if isinstance(existing, dict) else {}
    latest = dict(data.get("latest") or {})
    latest[rec["track"]] = rec
    history = [r for r in (data.get("releases") or []) if not (r.get("version") == rec["version"] and r.get("track") == rec["track"])]
    history.insert(0, {k: rec[k] for k in ("version", "track", "build", "publishedAt")})
    return {"latest": latest, "releases": history[:50],
            "builds": [{"interface": i, "name": BUILD_NAMES.get(i, i)} for i in interfaces()]}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--track", required=True)
    ap.add_argument("--repo", default="vortexq89/Phoenix_UI")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--in", dest="inp")
    ap.add_argument("--out", required=True)
    ap.add_argument("--record", required=True)
    a = ap.parse_args(argv)
    try:
        rec = record(a.version, a.track, a.repo, a.date)
    except ValueError as e:
        print("releases: " + str(e), file=sys.stderr)
        return 1
    existing = {}
    if a.inp and os.path.exists(a.inp):
        with open(a.inp, encoding="utf-8") as fh:
            existing = json.load(fh)
    for path, obj in ((a.out, merge(existing, rec)), (a.record, rec)):
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(obj, fh, indent=1)
            fh.write("\n")
    print("releases: %s %s" % (a.track, a.version))
    return 0


if __name__ == "__main__":
    sys.exit(main())
