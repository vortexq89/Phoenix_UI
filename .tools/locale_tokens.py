#!/usr/bin/env python3
"""Locale token parity (translations): every translated string must keep the
English string's machine tokens, or the game would print garbage or error:
  * format specs (%s, %d, %.1f, %5.2f, %%) in the same order and number
    (positional %1$s forms are accepted when their numbers match);
  * escape sequences: | pipes, |c..|r colour codes, |T..|t textures,
    |A..|a atlases, |H..|h links, |n; line breaks;
  * slash commands (/pui ...), which the player types literally.
Usage: python3 .tools/locale_tokens.py [--quiet]. Exit 1 on any mismatch."""
import os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LOC_DIR = os.path.join(ROOT, "Phoenix_UI_Locales", "Locales")
PAIR_RE = re.compile(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"')
SPEC_RE = re.compile(r'%(?:(\d+)\$)?([-+ #0]*\d*(?:\.\d+)?[sdifgxXcq%])')
ESC_RE = re.compile(r'\|(?:c[0-9a-fA-F]{8}|r|T[^|]*\|t|A[^|]*\|a|H[^|]*\|h|n)')
SLASH_RE = re.compile(r'(?<![\w/])/[a-z][a-z0-9]*')


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def specs(s):
    out = []
    for pos, body in SPEC_RE.findall(s):
        out.append((int(pos) if pos else None, body))
    if any(p for p, _ in out):
        named = sorted((p, b) for p, b in out if p)
        return [b for _, b in named] + [b for p, b in out if not p]
    return [b for _, b in out]


def tokens(s):
    return {
        "specs": specs(s),
        "pipes": s.count("|"),
        "escapes": sorted(ESC_RE.findall(s)),
        "newlines": s.count("\n"),
        "slash": sorted(SLASH_RE.findall(s)),
    }


def compare(en, tr):
    a, b = tokens(en), tokens(tr)
    return [k for k in a if a[k] != b[k]]


def check_file(path):
    src = open(path, encoding="utf-8").read()
    bad = []
    for k, v in PAIR_RE.findall(src):
        en, tr = unescape(k), unescape(v)
        diff = compare(en, tr)
        if diff:
            bad.append((en, tr, diff))
    return bad


def main():
    quiet = "--quiet" in sys.argv
    total = 0
    for name in sorted(os.listdir(LOC_DIR)):
        if not name.endswith(".lua"):
            continue
        bad = check_file(os.path.join(LOC_DIR, name))
        for en, tr, diff in bad:
            print("locale tokens: %s %s differ: %r -> %r" % (name, "/".join(diff), en[:80], tr[:80]))
        total += len(bad)
    if not quiet or total:
        print("locale tokens: %s" % ("FAIL (%d)" % total if total else "ok"))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
