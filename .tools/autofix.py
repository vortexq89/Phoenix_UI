#!/usr/bin/env python3
"""Patch-watcher auto-fix (repo side). Run after Data/ApiCatalog.json changes:

  1. regenerate Data/ApiManifest.lua and Data/SchemaIndex.lua (manifest.py)
  2. regenerate Phoenix_UI_Locales/keys.txt (locales.py)
  3. add offline-harness stubs for every manifest API the harness does not
     define, inside the generated block of .tools/harness/wow_stub.lua, so
     Sentinel's drift check completes in CI (the failure mode of 2026-10-28)
  4. run the full local CI set (guardrails, lint, both harness flavours,
     locale and manifest checks)

  python3 .tools/autofix.py            # fix and verify; exit 1 if a check fails
  python3 .tools/autofix.py --stubs    # only list the stubs it would add

The api-watch workflow runs it before opening its PR, so the PR carries the
regenerated files and is green, or states which check still fails.
"""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
STUB = os.path.join(ROOT, ".tools", "harness", "wow_stub.lua")
BEGIN = "-- autofix: generated stubs (python3 .tools/autofix.py); do not edit by hand"
END = "-- autofix: end"

PROBE = r'''
local H = dofile(".tools/harness/wow_stub.lua")
H.loadAddon("Phoenix_UI")
local mt = getmetatable(_G); setmetatable(_G, nil)
for api, info in pairs(PhoenixUI.ApiManifest.apis) do
  if not info.foreverOnly then
    local node, ok = _G, true
    for part in api:gmatch("[^%.]+") do
      if type(node) ~= "table" then ok = false break end
      node = rawget(node, part)
      if node == nil then ok = false break end
    end
    if not ok then io.stdout:write(api, "\n") end
  end
end
setmetatable(_G, mt)
'''


def missing():
    env = dict(os.environ, PUI_ROOT=ROOT, PUI_FLAVOR="retail")
    out = subprocess.run(["lua5.1", "-e", PROBE], cwd=ROOT, env=env, capture_output=True, text=True, check=True).stdout
    return sorted(set(l.strip() for l in out.splitlines() if l.strip()))


def stub_lines(apis):
    lines, spaces = [], set()
    for api in apis:
        parts = api.split(".")
        if len(parts) == 2 and parts[0] not in spaces:
            spaces.add(parts[0])
            lines.append('%s = rawget(_G, "%s") or {}' % (parts[0], parts[0]))
        if len(parts) == 1:
            lines.append('%s = rawget(_G, "%s") or function() return nil end' % (api, api))
        elif len(parts) == 2:
            lines.append("%s = %s or function() return nil end" % (api, api))
    return lines


def write_stubs(new):
    src = open(STUB, encoding="utf-8").read()
    old = []
    m = re.search(re.escape(BEGIN) + r"\n(.*?)" + re.escape(END) + r"\n", src, re.S)
    if m:
        old = [l for l in m.group(1).splitlines() if l.strip()]
        src = src[:m.start()] + src[m.end():]
    body = old + [l for l in new if l not in old]
    if not body:
        return 0
    block = BEGIN + "\n" + "\n".join(body) + "\n" + END + "\n"
    i = src.rindex("return H")
    open(STUB, "w", encoding="utf-8").write(src[:i] + block + src[i:])
    return len(body) - len(old)


def run(cmd, env=None):
    e = dict(os.environ, **(env or {}))
    r = subprocess.run(cmd, cwd=ROOT, env=e, capture_output=True, text=True)
    return r.returncode == 0


def main():
    if "--stubs" in sys.argv:
        for l in stub_lines(missing()):
            print(l)
        return 0
    run(["python3", ".tools/manifest.py"])
    run(["python3", ".tools/locales.py"])
    added = write_stubs(stub_lines(missing()))
    print("autofix: %d harness stub line(s) added" % added)
    checks = [
        ("guardrails", ["python3", ".tools/guardrails.py"], None),
        ("lint", ["python3", ".tools/lint.py"], None),
        ("tests retail", ["lua5.1", ".tools/harness/run_tests.lua"], None),
        ("tests forever", ["lua5.1", ".tools/harness/run_tests.lua"], {"PUI_FLAVOR": "forever"}),
        ("locales", ["python3", ".tools/locales.py", "--check"], None),
        ("manifest", ["python3", ".tools/manifest.py", "--check"], None),
    ]
    bad = [name for name, cmd, env in checks if not run(cmd, env)]
    print("autofix: " + ("all checks pass" if not bad else "still failing: " + ", ".join(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
