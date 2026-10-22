"""Per-flavour inputs and outputs of the API toolchain. PUI_FLAVOR=retail (default) or forever.

retail   WoW Midnight 12.1.5 (TOC 120105): wow-ui-source `live`, BlizzardInterfaceResources `live`
forever  WoW Forever 1.60.1 (TOC 16001, game type camelot/forever): the `forever` branches of both
         (clone them as worktrees: $PUI_REF/wow-ui-source-forever and $PUI_REF/bir_forever).
Both clients are the Mainline code family; Forever loads files tagged `mainline` or `camelot`, Retail
`mainline` or `standard`."""
import os

REF = os.environ.get("PUI_REF", "/workspace/ref")
FLAVOR = os.environ.get("PUI_FLAVOR", "retail")
_CFG = {
    "retail": dict(ui="wow-ui-source", bir="bir", tag="12.1.5", game="Mainline", ok=("mainline", "standard"),
                   label="WoW Retail 12.1.5.70448 (TOC 120105)"),
    "forever": dict(ui="wow-ui-source-forever", bir="bir_forever", tag="forever_1.60.1", game="Camelot",
                    ok=("mainline", "camelot", "forever"), label="WoW Forever 1.60.1.70450 (TOC 16001)"),
}
if FLAVOR not in _CFG:
    raise SystemExit(f"PUI_FLAVOR must be one of {sorted(_CFG)}")
C = _CFG[FLAVOR]
UI = f"{REF}/{C['ui']}"
BIR = f"{REF}/{C['bir']}"
TAG = C["tag"]
GAME = C["game"]
OK = C["ok"]
LABEL = C["label"]
SUFFIX = "" if FLAVOR == "retail" else f"_{FLAVOR}"
FILES = f"{REF}/mainline_files{SUFFIX}.txt"
API_DUMP = f"{REF}/api_dump{SUFFIX}.tsv"
