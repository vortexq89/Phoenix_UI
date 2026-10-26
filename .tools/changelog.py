#!/usr/bin/env python3
"""Builds a CHANGELOG.md section from merged pull requests (PUI_V2 20.6).

Input is the JSON of `gh pr list --state merged --json number,title,labels,body`.
A pull request contributes one line when its title starts with a change type:

    feat(Vault): search box in the bag window
    fix(Chat): timestamps no longer doubled
    perf: / data: / api: / docs:

The scope must be a module that exists in Data/SchemaIndex.lua (or "Core");
an unknown scope fails the run, so the changelog can never name a module that
is not in code. Lines are grouped by module, one line each, with linked
incident IDs ("Incident: <hash>" lines in the PR body). Canary writes an
"Unreleased (canary)" section; stable replaces it with the dated version.

    python3 .tools/changelog.py --prs prs.json --version 3.0.0 --track stable [--date 2026-11-01] [--file CHANGELOG.md]
"""
import argparse
import datetime
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TYPES = {"feat": "New", "fix": "Fixed", "perf": "Faster", "data": "Data", "api": "API", "docs": "Docs"}
LABEL_TYPES = {"feature": "feat", "bug": "fix", "performance": "perf", "data": "data", "api": "api", "documentation": "docs"}
TITLE_RE = re.compile(r"^(?P<type>[a-z]+)(?:\((?P<scope>[A-Za-z]+)\))?!?:\s*(?P<text>.+)$")
INCIDENT_RE = re.compile(r"^\s*Incident:\s*([A-Za-z0-9._:-]{6,128})\s*$", re.M)
UNRELEASED = "## Unreleased (canary)"


class ChangelogError(Exception):
    pass


def known_modules(root=ROOT):
    path = os.path.join(root, "Data", "SchemaIndex.lua")
    with open(path, encoding="utf-8") as fh:
        mods = set(re.findall(r'module = "([A-Za-z]+)"', fh.read()))
    mods.add("Core")
    return mods


def entry(pr, modules):
    title = (pr.get("title") or "").strip()
    m = TITLE_RE.match(title)
    kind = m.group("type") if m else None
    if kind not in TYPES:
        for label in pr.get("labels") or []:
            name = label.get("name") if isinstance(label, dict) else label
            if name in LABEL_TYPES:
                kind = LABEL_TYPES[name]
                break
    if kind not in TYPES:
        return None
    scope = (m.group("scope") if m else None) or "Core"
    if scope not in modules:
        raise ChangelogError("PR #%s names module '%s', which is not in Data/SchemaIndex.lua" % (pr.get("number"), scope))
    text = m.group("text") if m else title
    text = text[0].upper() + text[1:] if text else text
    incidents = INCIDENT_RE.findall(pr.get("body") or "")
    line = "- %s: %s" % (TYPES[kind], text.rstrip("."))
    if incidents:
        line += " (incident %s)" % ", ".join(incidents)
    line += " (#%s)" % pr.get("number")
    return scope, line


def section(prs, modules, header):
    groups = {}
    for pr in sorted(prs, key=lambda p: p.get("number") or 0):
        e = entry(pr, modules)
        if e:
            groups.setdefault(e[0], []).append(e[1])
    out = [header, ""]
    if not groups:
        out += ["- No player-facing changes.", ""]
    for mod in sorted(groups, key=lambda m: (m != "Core", m)):
        out += ["### " + mod] + groups[mod] + [""]
    return "\n".join(out)


def merge(existing, new_section):
    """Replaces an Unreleased section (if any) and puts the new one on top."""
    text = existing or "# Phoenix UI changelog\n"
    lines = text.split("\n")
    head, body = lines[0], "\n".join(lines[1:])
    if UNRELEASED in body:
        start = body.index(UNRELEASED)
        nxt = body.find("\n## ", start + len(UNRELEASED))
        body = body[:start] + (body[nxt + 1:] if nxt != -1 else "")
    return head + "\n\n" + new_section.rstrip() + "\n\n" + body.strip() + ("\n" if body.strip() else "")


def build(prs, version, track, date, existing="", modules=None):
    modules = modules or known_modules()
    header = UNRELEASED + " - " + version if track == "canary" else "## %s (%s)" % (version, date)
    return merge(existing, section(prs, modules, header))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--prs", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--track", choices=["canary", "stable"], required=True)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--file", default=os.path.join(ROOT, "CHANGELOG.md"))
    a = ap.parse_args(argv)
    with open(a.prs, encoding="utf-8") as fh:
        prs = json.load(fh)
    existing = open(a.file, encoding="utf-8").read() if os.path.exists(a.file) else ""
    try:
        text = build(prs, a.version, a.track, a.date, existing)
    except ChangelogError as e:
        print("changelog: " + str(e), file=sys.stderr)
        return 1
    with open(a.file, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("changelog: wrote %s section to %s" % (a.version, a.file))
    return 0


if __name__ == "__main__":
    sys.exit(main())
