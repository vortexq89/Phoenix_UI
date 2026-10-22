#!/usr/bin/env python3
"""Writes the WoW Forever TOCs from the retail ones (docs/research/wow-forever.md).

The client picks AddOnName_Forever.toc on WoW Forever (game type "forever", alias "camelot") and falls back to
AddOnName.toc everywhere else, so each addon ships both. The file lists are the same: retail-only features
switch themselves off at run time (ns:Supports, Core/Flavor.lua). Only the interface number differs, so the
Forever TOCs are generated and never edited by hand.

  python3 tools/gen_tocs.py          # rewrite the Forever TOCs
  python3 tools/gen_tocs.py --check  # exit 1 if they are out of date (check_api runs this)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FOREVER_INTERFACE = "16001"  # WoW Forever 1.60.1 (warcraft.wiki.gg/wiki/TOC_format; GetBuildInfo on the client)
TOCS = [ROOT / "Phoenix_UI.toc", ROOT / "Phoenix_UI_Options" / "Phoenix_UI_Options.toc"]


def forever_path(toc):
    return toc.with_name(toc.stem + "_Forever.toc")


def render(toc):
    text = toc.read_text(encoding="utf-8")
    out, n = re.subn(r"^## Interface:.*$", "## Interface: " + FOREVER_INTERFACE, text, count=1, flags=re.M)
    if n != 1:
        raise SystemExit(f"{toc.name}: no '## Interface:' line")
    note = f"# WoW Forever. Generated from {toc.name} by tools/gen_tocs.py; edit that file instead.\n"
    return note + out


def main():
    check = "--check" in sys.argv
    stale = []
    for toc in TOCS:
        want, path = render(toc), forever_path(toc)
        have = path.read_text(encoding="utf-8") if path.exists() else None
        if have == want:
            continue
        if check:
            stale.append(path.relative_to(ROOT))
        else:
            path.write_text(want, encoding="utf-8", newline="\n")
            print(f"wrote {path.relative_to(ROOT)}")
    for p in stale:
        print(f"{p}: out of date (run python3 tools/gen_tocs.py)")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
