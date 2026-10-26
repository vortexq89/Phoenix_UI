"""Small Lua 5.1 source helpers shared by guardrails.py and manifest.py.

strip(src) blanks out comments and string literals (keeping line breaks and
string delimiters) so regexes only see code. Original implementation for
Phoenix UI tooling.
"""
import os, re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SKIP_DIRS = {".git", ".github", ".tools", "docs", "Libs", "node_modules", "companion"}  # companion: desktop app, not addon code


def lua_files(root=ROOT):
    for dp, dns, fns in os.walk(root):
        dns[:] = sorted(d for d in dns if d not in SKIP_DIRS)
        for fn in sorted(fns):
            if fn.endswith(".lua"):
                yield os.path.join(dp, fn)


def rel(path, root=ROOT):
    return os.path.relpath(path, root).replace(os.sep, "/")


def owner_of(relpath):
    first = relpath.split("/")[0]
    if first.startswith("Phoenix_UI_"):
        return first[len("Phoenix_UI_"):]
    if first in ("Core", "Data"):
        return "Core"
    return first


def _long_bracket(src, i):
    m = re.match(r"\[(=*)\[", src[i:])
    return m.group(1) if m else None


def strip(src, keep_strings=False):
    out, i, n = [], 0, len(src)
    blank = lambda s: re.sub(r"[^\n]", " ", s)
    while i < n:
        c = src[i]
        if src.startswith("--", i):
            eq = _long_bracket(src, i + 2)
            if eq is not None:
                end = src.find("]" + eq + "]", i)
                end = n if end < 0 else end + len(eq) + 2
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            out.append(blank(src[i:end]))
            i = end
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                elif src[j] == "\n":
                    break
                j += 1
            body = src[i + 1:j]
            out.append(c + (body if keep_strings else blank(body)) + c)
            i = j + 1
        elif c == "[" and _long_bracket(src, i) is not None:
            eq = _long_bracket(src, i)
            end = src.find("]" + eq + "]", i)
            end = n if end < 0 else end + len(eq) + 2
            out.append(blank(src[i:end]) if not keep_strings else src[i:end])
            i = end
        else:
            out.append(c)
            i += 1
    return "".join(out)


def comments_only(src):
    """Return {line_number: comment_text} for every line comment."""
    res = {}
    code = strip(src, keep_strings=True)
    for ln, (a, b) in enumerate(zip(src.splitlines(), code.splitlines()), 1):
        if a != b:
            idx = next((k for k in range(min(len(a), len(b))) if a[k] != b[k]), None)
            if idx is not None and a[idx:].startswith("--"):
                res[ln] = a[idx:]
    return res
