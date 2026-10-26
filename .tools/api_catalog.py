#!/usr/bin/env python3
"""Build Data/ApiCatalog.json from Blizzard's UI source (Gethe/wow-ui-source).

Source of truth: Interface/AddOns/Blizzard_APIDocumentationGenerated on the
`live`, `ptr` and `forever` branches. Each documentation file is loaded by
.tools/apidoc_dump.lua (plain Lua tables) and flattened.

"since" is derived from git history of the live (and forever) branch: the build
in the subject line of the first commit whose documentation contains the API.
The generated documentation only exists in that repository from 10.0.0
(46293) onwards, so an API present in the very first documented commit is
reported as {"atOrBefore": "<that build>"} rather than an exact build. APIs
that the engine exposes without generated documentation (Lua core globals,
CreateFrame, hooksecurefunc, ...) are not in the catalog; guardrails keeps a
separate, explicit list for them.

Usage:
  python3 .tools/api_catalog.py --src <wow-ui-source clone> [--out Data/ApiCatalog.json] [--no-history]
The clone may be partial (--filter=blob:none); refs used: live, origin/ptr, origin/forever.
"""
import argparse, json, os, subprocess, sys, tempfile, re

DOC = "Interface/AddOns/Blizzard_APIDocumentationGenerated"
HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = os.path.join(HERE, "apidoc_dump.lua")
LUA = os.environ.get("LUA51", "lua5.1")


def git(src, *args, binary=False):
    out = subprocess.run(["git", "-C", src, *args], check=True, capture_output=True)
    return out.stdout if binary else out.stdout.decode("utf-8", "replace")


def resolve(src, names):
    for n in names:
        r = subprocess.run(["git", "-C", src, "rev-parse", "--verify", "-q", n], capture_output=True)
        if r.returncode == 0:
            return n
    return None


def dump_ref(src, ref):
    """Return {key: entry} for the docs at a ref. key = 'Name' or 'event:NAME'."""
    with tempfile.TemporaryDirectory() as tmp:
        tar = git(src, "archive", ref, DOC, binary=True)
        subprocess.run(["tar", "-x", "-C", tmp], input=tar, check=True)
        d = os.path.join(tmp, DOC)
        files = sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith(".lua"))
        out = subprocess.run([LUA, DUMP, *files], check=True, capture_output=True).stdout.decode()
    res = {}
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        kind, name, args, rets, system = parts[:5]
        key = name if kind == "function" else "event:" + name
        res[key] = {
            "type": kind,
            "args": [a for a in args.split(",") if a],
            "returns": [a for a in rets.split(",") if a],
            "system": system,
        }
    return res


def build_of(subject):
    m = re.match(r"\s*([\d.]+\s*\(\d+\))", subject)
    return m.group(1) if m else subject.strip()


def history(src, ref):
    """{key: since-record} from oldest to newest documented commit of ref."""
    commits = git(src, "log", "--reverse", "--format=%H\t%s\t%cs", ref, "--", DOC).splitlines()
    since = {}
    first = True
    for i, line in enumerate(commits):
        sha, subj, date = line.split("\t")
        try:
            keys = dump_ref(src, sha)
        except subprocess.CalledProcessError:
            continue  # commit removed the folder (path change); nothing to read
        for k in keys:
            if k not in since:
                b = build_of(subj)
                since[k] = {"atOrBefore": b, "date": date} if first else {"build": b, "date": date}
        first = False
        print(f"  history {ref} {i + 1}/{len(commits)} {build_of(subj)}", file=sys.stderr)
    return since


def head_info(src, ref):
    sha, subj, date = git(src, "log", "-1", "--format=%H\t%s\t%cs", ref).strip().split("\t")
    return {"ref": ref, "commit": sha, "build": build_of(subj), "date": date}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", default=os.path.join(HERE, "..", "Data", "ApiCatalog.json"))
    ap.add_argument("--no-history", action="store_true")
    a = ap.parse_args()
    refs = {
        "live": resolve(a.src, ["origin/live", "live"]),
        "ptr": resolve(a.src, ["origin/ptr", "ptr"]),
        "forever": resolve(a.src, ["origin/forever", "forever"]),
    }
    sources, sets = {}, {}
    for track, ref in refs.items():
        if not ref:
            print(f"warning: ref for {track} not found", file=sys.stderr)
            continue
        sources[track] = head_info(a.src, ref)
        sets[track] = dump_ref(a.src, ref)
    hist = {}
    if not a.no_history:
        for track in ("live", "forever"):
            if refs.get(track):
                hist[track] = history(a.src, refs[track])
    apis = {}
    for track, entries in sets.items():
        for k, e in entries.items():
            rec = apis.setdefault(k, {"type": e["type"], "args": e["args"], "returns": e["returns"],
                                      "system": e["system"], "in": []})
            rec["in"].append(track)
    for k, rec in apis.items():
        rec["since"] = {t: hist[t].get(k) for t in hist if k in hist[t]} or None
    cat = {
        "generator": ".tools/api_catalog.py",
        "note": "since = first documented commit containing the API; generated docs start at 10.0.0 (46293), "
                "so entries present then are 'atOrBefore'. Undocumented engine globals are not listed.",
        "sources": sources,
        "count": len(apis),
        "apis": dict(sorted(apis.items())),
    }
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="ascii") as fh:
        json.dump(cat, fh, indent=1, sort_keys=False, ensure_ascii=True)
        fh.write("\n")
    print(f"wrote {a.out}: {len(apis)} entries; sources={ {t: s['build'] for t, s in sources.items()} }")


if __name__ == "__main__":
    main()
