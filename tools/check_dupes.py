#!/usr/bin/env python3
"""Duplicate settings scan (GUI polish plan §3): finds the same game option or the same setting offered on more than
one settings page, so each has one owner and every other place becomes a link row.

Reads Phoenix_UI_Options/Options/*.lua (the settings schemas) and the module code:
  cvar     the same game CVar set from two settings pages
  concept  the same specific label (not a generic one like Scale or Font) with the same row type on two pages:
           usually the same idea set separately per frame family (unit frames, group frames, nameplates). These
           are kept apart on purpose but must read and behave the same (order, wording, ranges): a review list,
           not an error
Rows that already are links (`link = { key = ... }`) and the global pages that list every module's row on purpose
(Fonts, Textures, Glows) are left out.

    python3 tools/check_dupes.py [--md out.md] [--strict]
      --strict  exit 1 when a game option is set from two places"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OPT = os.path.join(ROOT, 'Phoenix_UI_Options', 'Options')
GLOBAL_PAGES = {'Fonts', 'Textures', 'Glows'}
GENERIC_PAGES = 4  # a label on more pages than this is a generic word (Scale, Font, Width …), not one setting

ROW = re.compile(r'\{\s*type\s*=\s*"(?P<type>\w+)"(?P<body>[^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', re.S)
LABEL = re.compile(r'\blabel\s*=\s*"(?P<label>[A-Z0-9_]+)"')
KEY = re.compile(r'\bkey\s*=\s*"(?P<key>[^"]+)"')
NUM = {k: re.compile(r'\b%s\s*=\s*(-?[0-9.]+)' % k) for k in ('min', 'max', 'step')}
# SetCVar / GetCVar and the schema helpers (cvar, cvarRow, cvarToggle, CVar, CVarAccessors) all name the CVar first
CVAR = re.compile(r'(?:SetCVar|GetCVar|GetCVarBool|C_CVar\.SetCVar|C_CVar\.GetCVar|C_CVar\.GetCVarBool|\bcvar|cvarRow'
                  r'|cvarToggle|\bCVar|CVarAccessors|CVarSet|CVarInfo|CVarReset)\s*\(\s*"(?P<cvar>\w+)"')
CVAR_FIELD = re.compile(r'\bcvar\s*=\s*"(?P<cvar>\w+)"')


def page_of(path):
    return os.path.splitext(os.path.basename(path))[0]


def enus():
    out = {}
    for line in open(os.path.join(ROOT, 'Locales', 'enUS.lua'), encoding='utf-8'):
        m = re.match(r'\s*([A-Z0-9_]+)\s*=\s*"(.*)",\s*$', line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def main():
    L = enus()
    labels = collections.defaultdict(list)   # (label, type) -> [(page, key)]
    pages_of_label = collections.defaultdict(set)
    cvars = collections.defaultdict(set)     # cvar -> {page}
    for path in sorted(glob.glob(os.path.join(OPT, '*.lua'))):
        page = page_of(path)
        src = open(path, encoding='utf-8').read()
        for m in CVAR.finditer(src):
            cvars[m.group('cvar')].add(page)
        for m in CVAR_FIELD.finditer(src):
            cvars[m.group('cvar')].add(page)
        if page in GLOBAL_PAGES:
            continue
        for m in ROW.finditer(src):
            t, body = m.group('type'), m.group('body')
            if t in ('header', 'tab', 'preview', 'scope', 'description') or 'link =' in body:
                continue
            lm, km = LABEL.search(body), KEY.search(body)
            if not lm:
                continue
            rng = tuple((NUM[k].search(body).group(1) if NUM[k].search(body) else '') for k in ('min', 'max', 'step'))
            labels[(lm.group('label'), t)].append((page, km.group('key') if km else '?', rng if t == 'range' else None))
            pages_of_label[lm.group('label')].add(page)
    # module code that sets CVars for a page (Modules/<X>, Phoenix_UI_<X>)
    for path in glob.glob(os.path.join(ROOT, 'Modules', '*', '*.lua')) + glob.glob(os.path.join(ROOT, 'Phoenix_UI_*', '*.lua')):
        if os.sep + 'Phoenix_UI_Options' + os.sep in path:
            continue
        owner = os.path.basename(os.path.dirname(path)).replace('Phoenix_UI_', '')
        for m in CVAR.finditer(open(path, encoding='utf-8', errors='ignore').read()):
            cvars[m.group('cvar')].add(owner)

    found = []
    for cvar, pages in sorted(cvars.items()):
        if len(pages) > 1:
            found.append(('cvar', cvar, sorted(pages)))
    for (label, t), rows in sorted(labels.items()):
        pages = sorted({p for p, _, _ in rows})
        if len(pages) > 1 and len(pages_of_label[label]) <= GENERIC_PAGES:
            found.append(('concept', '%s (%s, "%s")' % (label, t, L.get(label, '?')),
                          ['%s:%s' % (p, k) for p, k, _ in sorted(set(rows), key=str)]))
            # the same idea should move in the same steps over the same range on every page
            ranges = {r for _, _, r in rows if r and all(r)}
            if len(ranges) > 1:
                found.append(('range', '%s ("%s")' % (label, L.get(label, '?')),
                              ['%s:%s %s..%s step %s' % (p, k, *r) for p, k, r in sorted(set(rows), key=str) if r and all(r)]))

    lines = ['# Duplicate settings scan', '', 'Generated by tools/check_dupes.py. One owner per setting; the others become '
             'link rows (GUI polish plan §3).', '', '| Kind | What | Where |', '|---|---|---|']
    for kind, what, where in found:
        lines.append('| %s | %s | %s |' % (kind, what, ', '.join(where)))
    lines.append('')
    lines.append('%d findings: %d game options set from several places, %d concepts set per frame family, '
                 '%d of them with different ranges.' % (len(found), sum(1 for f in found if f[0] == 'cvar'),
                 sum(1 for f in found if f[0] == 'concept'), sum(1 for f in found if f[0] == 'range')))
    text = '\n'.join(lines)
    if '--md' in sys.argv:
        open(sys.argv[sys.argv.index('--md') + 1], 'w', encoding='utf-8').write(text + '\n')
    print(text if '--md' not in sys.argv else lines[-1])
    if '--strict' in sys.argv and any(f[0] == 'cvar' for f in found):
        sys.exit(1)


if __name__ == '__main__':
    main()
