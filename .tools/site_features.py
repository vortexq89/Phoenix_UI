#!/usr/bin/env python3
"""Writes the website feature list (PUI_V2 17.2 /phoenix-ui/features).

The list comes from the loaded module registry and settings schema, through the
offline harness, so the site can only name modules and settings that exist in
code. Output is plain JSON for the site repo (components/phoenix/features.json).

    python3 .tools/site_features.py --out features.json [--version 3.0.0-alpha1]
"""
import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Modules that are diagnostics or setup rather than player features.
INTERNAL = {"Sentinel", "Options", "Studio", "Setup"}


def dump(root=ROOT):
    res = subprocess.run(["lua5.1", os.path.join(root, ".tools", "harness", "features_dump.lua")],
                         capture_output=True, text=True, cwd=root, env={**os.environ, "PUI_ROOT": root})
    if res.returncode != 0:
        raise SystemExit("features_dump failed:\n" + res.stderr)
    line = [l for l in res.stdout.splitlines() if l.startswith("{")][-1]
    return json.loads(line)


def build(data, version=""):
    mods = [m for m in data["modules"] if m["name"] not in INTERNAL]
    return {"version": version, "generatedFrom": "module registry + settings schema",
            "modules": [{"name": m["name"], "label": m["label"], "tooltip": m["tooltip"],
                         "settings": [{"label": s["label"], "tooltip": s["tooltip"], "mode": s["mode"]} for s in m["settings"]]}
                        for m in mods]}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--version", default="")
    a = ap.parse_args(argv)
    out = build(dump(), a.version)
    with open(a.out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, indent=1, ensure_ascii=True)
        fh.write("\n")
    print("wrote %s (%d modules)" % (a.out, len(out["modules"])))


if __name__ == "__main__":
    sys.exit(main())
