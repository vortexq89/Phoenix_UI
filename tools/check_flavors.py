#!/usr/bin/env python3
"""Runs every check for both games Phoenix supports and prints one line per check.

  retail   World of Warcraft: Midnight 12.1.5 (Phoenix_UI.toc)
  forever  WoW Forever 1.60.1               (Phoenix_UI_Forever.toc)

Per game: luacheck with that client's generated std (wow / wowf in .luacheckrc), check_api against that
client's reference (.luacheck/reference_*.json), check_ids against that client's ID snapshot and the smoke
harness booted as that client. check_locales is the same for both and runs once.

  python3 tools/check_flavors.py [retail|forever ...]   # exit 1 if anything fails
"""
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FLAVORS = {"retail": "lua51+wow", "forever": "lua51+wowf"}


def run(label, cmd, flavor):
    env = dict(os.environ, PUI_FLAVOR=flavor)
    r = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip().splitlines()
    tail = out[-1] if out else ""
    print(f"{'ok  ' if r.returncode == 0 else 'FAIL'} {flavor:8} {label:14} {tail}")
    if r.returncode != 0:
        for line in out[-25:-1]:
            print("     " + line)
    return r.returncode == 0


def main():
    wanted = [a for a in sys.argv[1:] if a in FLAVORS] or list(FLAVORS)
    ok = run("check_locales", [sys.executable, "tools/check_locales.py"], "retail")
    for flavor in wanted:
        ok &= run("luacheck", ["luacheck", "-q", "--std", FLAVORS[flavor], "."], flavor)
        ok &= run("check_api", [sys.executable, "tools/check_api.py"], flavor)
        ok &= run("check_ids", [sys.executable, "tools/check_ids.py"], flavor)
        ok &= run("smoke", ["lua5.1", "tools/smoke/harness.lua", ".", flavor], flavor)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
