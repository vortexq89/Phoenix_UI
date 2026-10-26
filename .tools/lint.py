#!/usr/bin/env python3
"""Phoenix UI lint (plan 1.33, G2, G15). Original tooling.

  globals  no implicit global writes (luac5.1 -l SETGLOBAL); SLASH_* names and
           test files are exempt; tag "-- lint-allow: global <reason>" on the
           line above for a deliberate one.
  timers   C_Timer.NewTicker / C_Timer.NewTimer are banned: periodic work goes
           through PUI.Ticker (G2, G33).

Every rule has a fixture in .tools/lint_fixtures/ that must fail (self-proof).
Usage: python3 .tools/lint.py [--root DIR] [--self-test]
"""
import argparse, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luascan

ALLOW_RE = re.compile(r"--\s*lint-allow:\s*(\w+)\s+\S+")
SETGLOBAL_RE = re.compile(r"\[(\d+)\]\s+SETGLOBAL\s+.*;\s*(\S+)")
TIMER_RE = re.compile(r"\bC_Timer\.(NewTicker|NewTimer)\s*\(")


def allowed(lines, ln, rule):
    for back in (1, 2):
        if ln - back >= 1:
            m = ALLOW_RE.search(lines[ln - back - 1])
            if m and m.group(1) == rule:
                return True
    return False


def lint_file(path, rel):
    out = []
    src = open(path, encoding="utf-8", errors="replace").read()
    lines = src.splitlines()
    is_test = "/Tests/" in "/" + rel.replace("\\", "/")
    if not is_test:
        res = subprocess.run(["luac5.1", "-l", "-p", path], capture_output=True, text=True)
        for m in SETGLOBAL_RE.finditer(res.stdout):
            ln, name = int(m.group(1)), m.group(2)
            if name.startswith("SLASH_") or allowed(lines, ln, "global"):
                continue
            out.append(("globals", "%s:%d" % (rel, ln), "implicit global '%s' (declare it local)" % name))
    code = luascan.strip(src)
    for ln, line in enumerate(code.splitlines(), 1):
        if TIMER_RE.search(line) and not allowed(lines, ln, "timers"):
            out.append(("timers", "%s:%d" % (rel, ln), "C_Timer tickers are banned: use PUI.Ticker"))
    return out


def run(root, files):
    problems = []
    for f in files:
        problems += lint_file(f, os.path.relpath(f, root))
    return problems


def self_test():
    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lint_fixtures")
    ok = True
    for name, rule in (("bad_global.lua", "globals"), ("bad_timer.lua", "timers")):
        found = [p for p in lint_file(os.path.join(here, name), name) if p[0] == rule]
        print("self-test %-8s %s" % (rule, "ok" if found else "FAILED (fixture not caught)"))
        ok = ok and bool(found)
    clean = lint_file(os.path.join(here, "good.lua"), "good.lua")
    print("self-test clean    %s" % ("ok" if not clean else "FAILED: %s" % clean))
    return ok and not clean


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=luascan.ROOT)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if not self_test():
        sys.exit(1)
    if a.self_test:
        return
    files = [f for f in luascan.lua_files(a.root)]
    problems = run(a.root, files)
    for rule, where, msg in problems:
        print("%-8s %s: %s" % (rule, where, msg))
    print("lint: %d files, %s" % (len(files), "PASS" if not problems else "%d problem(s)" % len(problems)))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
