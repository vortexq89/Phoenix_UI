#!/usr/bin/env python3
"""Build name-level reference sets for 12.1.5 mainline that luacheck cannot check:
widget/mixin method names, events, CVars, XML templates, atlases. Output: .luacheck/reference_<tag>.json (flavor.py)"""
import os, re, json
from flavor import UI, BIR, FILES, TAG, FLAVOR
DOC = f"{UI}/Interface/AddOns/Blizzard_APIDocumentationGenerated"
main = [l.strip() for l in open(FILES) if l.strip()]
methods, events, templates, cvars, atlases = set(), set(), set(), set(), set()
for fn in os.listdir(DOC):
    s = open(os.path.join(DOC, fn), errors="ignore").read()
    for m in re.finditer(r'Name = "(\w+)",\s*\n\s*Type = "Function"', s): methods.add(m.group(1))
    for m in re.finditer(r'LiteralName = "(\w+)"', s): events.add(m.group(1))
for p in main:
    if "Blizzard_Deprecated" in p: continue
    s = open(p, errors="ignore").read()
    if p.endswith(".lua"):
        for m in re.finditer(r'^\s*function\s+[\w\.]+[:.](\w+)\s*\(', s, re.M): methods.add(m.group(1))
        for m in re.finditer(r'^\s*[\w\.]+[.:](\w+)\s*=\s*function', s, re.M): methods.add(m.group(1))
    else:
        for m in re.finditer(r'<\w+\s[^>]*\bname="([\w$]+)"[^>]*\bvirtual="true"', s): templates.add(m.group(1))
        for m in re.finditer(r'<\w+\s[^>]*\bvirtual="true"[^>]*\bname="([\w$]+)"', s): templates.add(m.group(1))
        for m in re.finditer(r'<\w+\s[^>]*\bname="([A-Za-z_]\w*)"', s): templates.add(m.group(1))  # named frames usable as parents
cv = open(f"{BIR}/Resources/CVars.lua", errors="ignore").read()
for m in re.finditer(r'\["(\w+)"\]\s*=', cv): cvars.add(m.group(1))
# 12.0/12.1.5 additions documented on the wiki but newer than the BIR 12.1.0 dump
if FLAVOR == "retail":
  cvars |= {"secretCombatRestrictionsForced", "secretEncounterRestrictionsForced", "secretChallengeModeRestrictionsForced",
          "secretPvPMatchRestrictionsForced", "secretMapRestrictionsForced", "addonChatRestrictionsForced",
          "nameplateMotionSpeed", "nameplateTopInset", "nameplateBottomInset", "loadDeprecationFallbacks"}
# CVars referenced as literals by mainline FrameXML also exist
for p in main:
    if p.endswith(".lua"):
        for m in re.finditer(r'(?:GetCVar\w*|SetCVar|C_CVar\.\w+)\(\s*"(\w+)"', open(p, errors="ignore").read()): cvars.add(m.group(1))
at = open(f"{BIR}/Resources/AtlasInfo.lua", errors="ignore").read()
for m in re.finditer(r'\["([^"]+)"\]\s*=\s*\{', at): atlases.add(m.group(1))
for p in main:
    if p.endswith((".lua", ".xml")):
        for m in re.finditer(r'atlas="([^"]+)"|SetAtlas\("([^"]+)"', open(p, errors="ignore").read()):
            atlases.add(m.group(1) or m.group(2))
out = {k: sorted(v) for k, v in dict(methods=methods, events=events, templates=templates, cvars=cvars, atlases=atlases).items()}
os.makedirs(".luacheck", exist_ok=True)
json.dump(out, open(f".luacheck/reference_{TAG}.json", "w"), indent=0)
print({k: len(v) for k, v in out.items()})
