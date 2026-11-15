"""Fixed-in list -> "!PUI_SEN" string for Sentinel's /pui sentinel fixed.

Input is JSON: either a list of {"hash", "fixedIn"} rows, or the dashboard's
issue list (rows with "status": "fixed" and a "fixedIn"/"fixed_in"/"version"
field); anything else is skipped. The same limits as the addon apply, so a
string this builds is never refused in game.
"""
import re

from . import exportstring

KIND = "fixed-in"
MAX = 500
_HASH = re.compile(r"^[0-9a-fA-F]{8,64}$")
_VER = re.compile(r"^[\w.\-]{1,32}$")


def rows(data):
    if isinstance(data, dict):
        data = data.get("issues") or data.get("fixed") or []
    out, seen = [], set()
    for r in data if isinstance(data, list) else []:
        if not isinstance(r, dict):
            continue
        if "status" in r and r.get("status") != "fixed":
            continue
        h = r.get("hash")
        v = r.get("fixedIn") or r.get("fixed_in") or r.get("version")
        if isinstance(h, str) and isinstance(v, str) and _HASH.match(h) and _VER.match(v) and "_" not in v and h.lower() not in seen:
            seen.add(h.lower())
            out.append({"hash": h.lower(), "fixedIn": v})
    return out


def build(data):
    fixed = rows(data)
    if not fixed:
        raise ValueError("no fixed rows with a hash and a version")
    if len(fixed) > MAX:
        raise ValueError("too many rows (max %d)" % MAX)
    return exportstring.encode({"kind": KIND, "schema": 1, "fixed": fixed})
