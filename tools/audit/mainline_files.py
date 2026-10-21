#!/usr/bin/env python3
"""Resolve the set of Blizzard UI files actually loaded by the Retail (mainline) client
from wow-ui-source TOCs + XML includes. Writes /workspace/ref/mainline_files.txt"""
import os, re
REF = os.environ.get("PUI_REF", "/workspace/ref")
SRC = f"{REF}/wow-ui-source/Interface/AddOns"
OK = ("mainline", "standard")
idx = {}
for r, _, fs in os.walk(SRC):
    for f in fs:
        p = os.path.join(r, f); idx[p.lower()] = p
def allowed(tag):
    m = re.search(r'\[AllowLoadGameType\s+([^\]]+)\]', tag)
    if not m: return True
    return any(x.strip() in OK for x in m.group(1).split(","))
files = set()
def visit(p):
    real = idx.get(os.path.normpath(p).lower())
    if not real or real in files: return
    files.add(real)
    if real.endswith(".xml"):
        s = re.sub(r'<!--.*?-->', '', open(real, errors="ignore").read(), flags=re.S)
        for m in re.finditer(r'<(?:Include|Script)\s+file\s*=\s*"([^"]+)"', s):
            visit(os.path.join(os.path.dirname(real), m.group(1).replace("\\", "/")))
for addon in sorted(os.listdir(SRC)):
    d = os.path.join(SRC, addon)
    if not os.path.isdir(d): continue
    tocs = [f for f in os.listdir(d) if f.endswith(".toc")]
    pick = None
    for cand in (f"{addon}_Mainline.toc", f"{addon}.toc"):
        if cand in tocs: pick = cand; break
    if not pick: continue
    lines = open(os.path.join(d, pick), errors="ignore").read().splitlines()
    gt = [l for l in lines if l.startswith("## AllowLoadGameType:")]
    if gt and not any(x.strip() in OK for x in gt[0].split(":", 1)[1].split(",")): continue
    for l in lines:
        l = l.strip()
        if not l or l.startswith("#"): continue
        if not allowed(l): continue
        f = re.sub(r'(\s+\[[^\]]*\])+\s*$', '', l).replace("[Family]", "Mainline").replace("[Game]", "Mainline").replace("\\", "/")
        visit(os.path.join(d, f))
open(f"{REF}/mainline_files.txt", "w").write("\n".join(sorted(files)))
print(len(files), "mainline files")
