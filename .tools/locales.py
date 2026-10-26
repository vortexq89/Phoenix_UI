#!/usr/bin/env python3
"""Locale key check (PUI_V2 5.17, 12): harvests every English string Phoenix
renders (schema labels/tooltips, Studio element labels) through the offline
harness, writes Phoenix_UI_Locales/keys.txt, and fails when a locale file
holds a key that no longer exists (stale translation). Prints coverage."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LOC_DIR = os.path.join(ROOT, "Phoenix_UI_Locales", "Locales")
KEYS = os.path.join(ROOT, "Phoenix_UI_Locales", "keys.txt")
KEY_RE = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=', re.M)

HARVEST = r'''
local H = dofile(".tools/harness/wow_stub.lua")
H.loadAddon("Phoenix_UI")
for line in io.lines(".tools/harness/run_tests.lua") do
  local list = line:match("^for _, child in ipairs%(%{(.*)%}%) do")
  if list then for c in list:gmatch('"([^"]+)"') do H.loadAddon(c) end end
end
H.loadAddon("Phoenix_UI_Options")
for _, s in ipairs(PhoenixUI.Locale:Harvest()) do io.stdout:write(s, "\0") end
'''


def harvest():
    env = dict(os.environ, PUI_ROOT=ROOT, PUI_FLAVOR="retail")
    out = subprocess.run(["lua5.1", "-e", HARVEST], cwd=ROOT, env=env, capture_output=True, check=True).stdout
    return [s.decode("utf-8") for s in out.split(b"\0") if s]


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def main():
    check = "--check" in sys.argv
    keys = harvest()
    text = "\n".join(keys) + "\n"
    if check:
        cur = open(KEYS, encoding="utf-8").read() if os.path.exists(KEYS) else ""
        if cur != text:
            print("locales: Phoenix_UI_Locales/keys.txt is out of date (run python3 .tools/locales.py)")
            return 1
    else:
        open(KEYS, "w", encoding="utf-8").write(text)
    known, bad = set(keys), 0
    for name in sorted(os.listdir(LOC_DIR)):
        src = open(os.path.join(LOC_DIR, name), encoding="utf-8").read()
        found = [unescape(k) for k in KEY_RE.findall(src)]
        stale = [k for k in found if k not in known]
        for k in stale:
            print("locales: %s has a stale key: %r" % (name, k))
        bad += len(stale)
        print("locales: %-9s %4d of %d strings (%.1f%%)" % (name[:-4], len(found) - len(stale), len(keys), 100.0 * (len(found) - len(stale)) / max(1, len(keys))))
    print("locales: %s" % ("FAIL" if bad else "ok"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
