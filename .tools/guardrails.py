#!/usr/bin/env python3
"""Phoenix UI guardrails (PUI_V2 Sections 3, 12, 20.2, Appendix A).

Checks every Lua file and TOC in the repository:
  compile      Lua 5.1 syntax (luac5.1 -p)
  limits       <=150 locals and <=50 upvalues per function (luac5.1 -l listing)
  gate         Core/ClientGate.lua first in Phoenix_UI.toc; every other file starts with the line-1 guard
  deprecated   forbidden/removed globals from Appendix A
  onupdate     SetScript("OnUpdate") only in Core/Ticker.lua; no HookScript("OnUpdate")
  regen        PLAYER_REGEN_ENABLED only in Core/CombatQueue.lua (use PUI.CombatQueue.Defer)
  blizzfields  no field writes to Blizzard globals (X.y = ...) outside an allow-list
  pcall        pcall/xpcall need a dated exception tag with approver on the line above
  api          C_* calls exist in Data/ApiCatalog.json for live; Forever-missing ones must be IS_FOREVER-gated
  media        every Interface/AddOns/Phoenix_UI* media path exists
  ascii        ASCII only outside Locales/
  toc          Interface 120100/120105/16001, Author VortexQ8, listed files exist

Exception tag: "-- guardrails-allow: <check> YYYY-MM-DD approver=<name> reason=<text>" on the line above.
Usage: python3 .tools/guardrails.py [--root DIR]
"""
import argparse, json, os, re, shutil, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luascan

GUARD = "local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end"
MAX_LOCALS, MAX_UPVALUES = 150, 50
DEPRECATED = [
    "GetSpellInfo", "GetSpellTexture", "GetSpellCooldown", "GetSpellCharges", "GetItemInfo", "GetItemIcon",
    "GetItemCount", "GetSpecialization", "GetSpecializationInfo", "UnitAura", "UnitBuff", "UnitDebuff",
    "C_Scenario.GetStepInfo", "C_Scenario.GetCriteriaInfo", "TargetFrame_UpdateBuffAnchor", "secretunwrap",
    "CombatLogGetCurrentEventInfo", "GetAddOnMetadata", "GetAddOnInfo", "GetNumAddOns", "IsAddOnLoaded",
    "LoadAddOn", "EnableAddOn", "DisableAddOn", "UnitPosition", "GetContainerItemInfo", "GetContainerNumSlots",
]
DEPRECATED_TOKENS = ["COMBAT_LOG_EVENT_UNFILTERED"]
FIELD_ALLOW = {"SlashCmdList", "PUI", "_G"}
TAG_RE = re.compile(r"--\s*guardrails-allow:\s*(\w+)\s+(\d{4}-\d{2}-\d{2})\s+approver=(\S+)\s+reason=\S+")


class Report:
    def __init__(self):
        self.fail = []
        self.counts = {}

    def add(self, check, where, msg):
        self.fail.append((check, where, msg))

    def ran(self, check):
        self.counts.setdefault(check, 0)


def allowed(lines, ln, check):
    for back in (1, 2):
        if ln - back >= 1:
            m = TAG_RE.search(lines[ln - back - 1])
            if m and m.group(1) == check:
                return True
    return False


def luac():
    for name in ("luac5.1", "luac51"):
        if shutil.which(name):
            return name
    return None


def check_compile_and_limits(root, files, rep):
    exe = luac()
    rep.ran("compile"); rep.ran("limits")
    if not exe:
        rep.add("compile", "-", "luac5.1 not found")
        return
    hdr = re.compile(r"^(?:main|function) <([^:>]+):(\d+)(?:,\d+)?>")
    cnt = re.compile(r"(\d+) upvalues?, (\d+) locals?")
    for f in files:
        r = subprocess.run([exe, "-p", "-l", f], capture_output=True, text=True)
        if r.returncode != 0:
            rep.add("compile", luascan.rel(f, root), r.stderr.strip())
            continue
        where = None
        for line in r.stdout.splitlines():
            m = hdr.match(line)
            if m:
                where = "%s:%s" % (luascan.rel(f, root), m.group(2))
                continue
            m = cnt.search(line)
            if m and where:
                up, loc = int(m.group(1)), int(m.group(2))
                if loc > MAX_LOCALS:
                    rep.add("limits", where, "%d locals (max %d)" % (loc, MAX_LOCALS))
                if up > MAX_UPVALUES:
                    rep.add("limits", where, "%d upvalues (max %d)" % (up, MAX_UPVALUES))
                where = None


def toc_files(root):
    tocs = []
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in luascan.SKIP_DIRS]
        tocs += [os.path.join(dp, f) for f in fns if f.endswith(".toc")]
    return sorted(tocs)


def check_toc(root, rep):
    rep.ran("toc"); rep.ran("gate")
    for toc in toc_files(root):
        r = luascan.rel(toc, root)
        text = open(toc, encoding="utf-8").read()
        m = re.search(r"^## Interface:\s*(.+)$", text, re.M)
        versions = {v.strip() for v in m.group(1).split(",")} if m else set()
        if not {"120100", "120105", "16001"} <= versions:
            rep.add("toc", r, "Interface must list 120100, 120105, 16001")
        if not re.search(r"^## Author: VortexQ8\s*$", text, re.M):
            rep.add("toc", r, "Author must be VortexQ8")
        listed = [l.strip() for l in text.splitlines() if l.strip() and not l.startswith("#")]
        base = os.path.dirname(toc)
        for item in listed:
            if not os.path.exists(os.path.join(base, item.replace("\\", os.sep))):
                rep.add("toc", r, "listed file missing: " + item)
        if os.path.basename(toc) == "Phoenix_UI.toc" and (not listed or listed[0] != "Core\\ClientGate.lua"):
            rep.add("gate", r, "Core\\ClientGate.lua must be the first file")


def check_files(root, files, rep, catalog):
    apis = catalog["apis"] if catalog else None
    dep_re = re.compile(r"(?<![\w.:])(%s)\s*\(" % "|".join(re.escape(d) for d in DEPRECATED))
    ns_re = re.compile(r"(?<![\w.:])(C_\w+\.\w+)\s*\(")
    field_re = re.compile(r"^\s*([A-Z_]\w*)\.(\w+)\s*=[^=]")
    media_re = re.compile(r"Interface[\\/]+AddOns[\\/]+(Phoenix_UI\w*[\\/]+Media[\\/][^\"']+)")
    for check in ("deprecated", "onupdate", "regen", "blizzfields", "pcall", "api", "media", "ascii"):
        rep.ran(check)
    for f in files:
        r = luascan.rel(f, root)
        raw = open(f, "rb").read()
        src = raw.decode("utf-8", "replace")
        lines = src.splitlines()
        code = luascan.strip(src)
        strs = luascan.strip(src, keep_strings=True)
        code_lines, str_lines = code.splitlines(), strs.splitlines()
        if r != "Core/ClientGate.lua":
            if not lines or lines[0] != GUARD:
                rep.add("gate", r, "line 1 must be the client-gate guard")
        elif not lines or not lines[0].startswith("-- PUI-GATE"):
            rep.add("gate", r, "ClientGate.lua must start with the PUI-GATE marker")
        if "/Locales/" not in "/" + r and any(b > 127 for b in raw):
            rep.add("ascii", r, "non-ASCII bytes outside Locales/")
        locals_ = set()
        for m in re.finditer(r"\blocal\s+(?:function\s+)?([A-Za-z_][\w\s,]*)", code):
            locals_.update(x.strip() for x in m.group(1).split(",") if x.strip())
        for ln, (cl, sl) in enumerate(zip(code_lines, str_lines), 1):
            where = "%s:%d" % (r, ln)
            for m in dep_re.finditer(cl):
                if m.group(1) not in locals_ and not allowed(lines, ln, "deprecated"):
                    rep.add("deprecated", where, m.group(1) + " is removed/deprecated (Appendix A)")
            for tok in DEPRECATED_TOKENS:
                if tok in sl and not allowed(lines, ln, "deprecated"):
                    rep.add("deprecated", where, tok + " is unavailable to addons")
            if re.search(r"SetScript\(\s*[\"']OnUpdate[\"']", sl) and r != "Core/Ticker.lua" and not allowed(lines, ln, "onupdate"):
                rep.add("onupdate", where, "SetScript(\"OnUpdate\") outside Core/Ticker.lua: use PUI.Ticker")
            if re.search(r"HookScript\(\s*[\"']OnUpdate[\"']", sl) and not allowed(lines, ln, "onupdate"):
                rep.add("onupdate", where, "HookScript(\"OnUpdate\") is not allowed: use PUI.Ticker")
            if "PLAYER_REGEN_ENABLED" in sl and r != "Core/CombatQueue.lua" and not allowed(lines, ln, "regen"):
                rep.add("regen", where, "PLAYER_REGEN_ENABLED outside Core/CombatQueue.lua: use PUI.CombatQueue.Defer")
            m = field_re.match(cl)
            if m and m.group(1) not in locals_ and m.group(1) not in FIELD_ALLOW and not allowed(lines, ln, "blizzfields"):
                rep.add("blizzfields", where, "field write to global %s.%s" % (m.group(1), m.group(2)))
            if re.search(r"(?<![\w.:])x?pcall\s*\(", cl) and not allowed(lines, ln, "pcall") and not allowed(lines, ln, "xpcall"):
                rep.add("pcall", where, "pcall/xpcall without an exception tag (R-ERRORS)")
            if apis is not None:
                for m in ns_re.finditer(cl):
                    name = m.group(1)
                    e = apis.get(name)
                    if not e or "live" not in e["in"]:
                        rep.add("api", where, name + " is not in the live API catalog")
                    elif "forever" not in e["in"]:
                        ctx = "\n".join(code_lines[max(0, ln - 5):ln])
                        if "IS_FOREVER" not in ctx and not allowed(lines, ln, "api"):
                            rep.add("api", where, name + " is missing on Forever: gate with PUI.IS_FOREVER")
            for m in media_re.finditer(sl):
                p = m.group(1).replace("\\\\", "/").replace("\\", "/")
                head, rest = p.split("/", 1)
                cand = os.path.join(root, rest) if head == "Phoenix_UI" else os.path.join(root, head, rest)
                if not any(os.path.exists(cand + ext) for ext in ("", ".tga", ".blp", ".ttf", ".ogg", ".mp3")):
                    rep.add("media", where, "media path does not exist: " + m.group(1))
    # dated tags must be well-formed wherever they appear
    for f in files:
        for ln, line in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
            if "guardrails-allow" in line and not TAG_RE.search(line):
                rep.add("pcall", "%s:%d" % (luascan.rel(f, root), ln), "malformed exception tag (needs check, date, approver, reason)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=luascan.ROOT)
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    files = list(luascan.lua_files(root))
    cat_path = os.path.join(root, "Data", "ApiCatalog.json")
    catalog = json.load(open(cat_path, encoding="ascii")) if os.path.exists(cat_path) else None
    rep = Report()
    check_compile_and_limits(root, files, rep)
    check_toc(root, rep)
    check_files(root, files, rep, catalog)
    if catalog is None and files:
        rep.add("api", "Data/ApiCatalog.json", "missing (run .tools/api_catalog.py)")
    by = {}
    for c, w, m in rep.fail:
        by.setdefault(c, []).append((w, m))
    print("guardrails: %d Lua files, %d TOC files, catalog %s" % (
        len(files), len(toc_files(root)), (catalog or {}).get("sources", {}).get("live", {}).get("build", "absent")))
    for check in sorted(rep.counts):
        items = by.get(check, [])
        print("  %-12s %s" % (check, "ok" if not items else "%d problem(s)" % len(items)))
        for w, m in items:
            print("      %s: %s" % (w, m))
    print("guardrails: " + ("PASS" if not rep.fail else "FAIL (%d)" % len(rep.fail)))
    return 1 if rep.fail else 0


if __name__ == "__main__":
    sys.exit(main())
