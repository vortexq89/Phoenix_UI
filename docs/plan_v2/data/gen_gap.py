import sys, json; sys.path.insert(0,'.')
import re, collections
import spec_core, spec_ui, spec_rest, patch_status, parity
from spec_lib import MOD, mod
patch_status.apply(); patch_status.apply2()

# --- S17 parity audit: new pages, a source addon per row, and rows for audit features beyond the spec ---
mod("AuctionHouse", "Auction House", "Items", "New page (S22): shopping lists, price history from ReplicateItems, undercut and cancel lists; every search, post and cancel is your click", 0, "Auctionator")
mod("Loadouts", "Loadouts", "Profiles", "New page (S28): per-spec / per-instance loadouts that switch profile, talents and gear set (out of combat, your confirmation)", 0, "EllesmereUI LoadoutManager")
STOP = set("with from that this your their when only show shows hide the and for into per bar bars text icon icons size colour color frame frames options option".split())
def toks(*xs): return {t for x in xs for t in re.findall(r"[a-z]{4,}", str(x).lower())} - STOP
OWNED = collections.defaultdict(list)
for f in parity.FEATURES:
    OWNED[f["owner"]].append(f)
PRIMARY = {}
for k, fs in OWNED.items():
    c = collections.Counter()
    for f in fs:
        c[f["addon"]] += (f["n"] or 1) if f["keys"] else 1
    PRIMARY[k] = c.most_common(1)[0][0]
PRIMARY.update({"AFK": "EllesmereUI", "CooldownText": "EllesmereUI", "Diagnostics": "BugGrabber + BugSack"})
def source_of(key, row):
    t = toks(row["group"], row["name"]); best, score = None, 0
    for f in OWNED.get(key, []):
        sc = len(t & toks(f["feature"], " ".join(f["keys"])))
        if sc > score: best, score = f["addon"], sc
    return best or PRIMARY.get(key, "Phoenix")
STMAP = {"part": "part", "miss": "new", "imp": "api"}
# parity features that are the same setting as an existing spec row: no second row; the spec row takes the source
# addon, and its status where the audit settled it (impossible ones become api)
DUP = {
    ("ActionBars", "Hide the charge count at zero charges"): "Hide charge count at 0",
    ("Tracker", "Stack-based bar fill with max / threshold"): "Stack-based fill",
    ("Skins", "Skyriding vigor and speed bar"): "Skyriding vigor bar",
    ("General", "Glow type and parameters"): "Glow colour / lines / speed / thickness",
    ("Minimap", "World map reveal with coloured fog, map scale"): "World map: reveal unexplored",
    ("GroupFinder", "Persistent sign-up note"): "Remember sign-up note",
    ("UnitFrames", "Mana regen spark"): "Mana regen spark",
    ("Tooltip", "Raid / M+ progression in tooltips"): "Raid progression line",
    ("UnitFrames", "Trinket and racial tracking"): "Arena: trinket / racial / DR tracker",
    ("GroupFinder", "Accept role checks"): "Auto queue (role check) accept",
    ("Encounters", "Per-ability bar / message colours"): "Per-spell colour override",
}
FOLDED = 0
def fold(f):
    global FOLDED
    for (own, feat), name in DUP.items():
        if own == f["owner"] and f["feature"].startswith(feat):
            row = next(r for r in MOD[own]["rows"] if r["name"] == name)
            row["source"] = f["addon"]
            if f["status"] == "imp":
                row["status"] = "api"
            elif row["status"] != "new" and f["stage"]:
                row["stage"] = f["stage"]
            FOLDED += 1
            return True
    return False
PARITY_ROWS = 0
for f in parity.FEATURES:
    if f["status"] in STMAP and fold(f):
        continue
    if f["status"] in STMAP and f["stage"] != "S17":
        m = MOD[f["owner"]]
        m["rows"].append(dict(group=f"Parity: {f['addon']}", name=f["feature"], type="—", range=f["note"], default="",
                              preview=("—" if f["status"] == "imp" else "live"), status=STMAP[f["status"]],
                              stage=f["stage"] or "", source=f["addon"]))
        PARITY_ROWS += 1
LATER = {k: collections.Counter(f["stage"] for f in fs if f["stage"] and f["stage"] != "S17").most_common(1) for k, fs in OWNED.items()}
for k, m in MOD.items():
    for row in m["rows"]:
        row.setdefault("source", source_of(k, row))
        # open spec rows: missing ones are S17's job, shallow ones go with the page's later stage
        later = LATER.get(k) or [({"CombatText": "S24", "Sim": "S28", "Diagnostics": "S26"}.get(k, "S28"), 0)]
        row.setdefault("stage", {"new": "S17", "part": later[0][0]}.get(row["status"], ""))
ORDER = ["ActionBars","CooldownText","Tracker","UnitFrames","GroupFrames","NamePlates","CastBars","Auras","CombatText","DamageMeter","SpellHistory",
         "Chat","Minimap","Tooltip","Bags","ItemLevel","DataTexts","Skins","General","Profiles","Movers","Quality","Automation","AFK","Bugs",
         "Quests","GroupFinder","MythicPlus","Encounters","PvP","Sim","Diagnostics","AuctionHouse","Loadouts"]
assert set(ORDER)==set(MOD), set(MOD)^set(ORDER)
TN = {"T":"toggle","S":"slider","D":"dropdown","C":"colour","X":"texture","I":"input","B":"button","L":"list","K":"keybind","R":"reorder","—":"—"}
def w(r): return r.get("weight",1)
summary=[]; out=[]
for k in ORDER:
    m=MOD[k]; rows=m["rows"]
    OUT={"link","api"}  # owned by another page / impossible in 12.x: listed, not counted in the target
    tgt=sum(w(r) for r in rows if r["status"] not in OUT); has=sum(w(r) for r in rows if r["status"]=="has")
    part=sum(w(r) for r in rows if r["status"]=="part"); ext=sum(w(r) for r in rows if r["status"] in OUT)
    m.update(target=tgt, has=has, part=part, new=tgt-has-part, ext=ext)
    m.setdefault("nowF", m["now"])
    summary.append(m)
md=["# Phoenix UI — module gap matrix (v2)","",
"Generated from `data/spec_*.py` by `data/gen_gap.py` (2026-10-22, S16 re-audit + I:\\ parity audit + S17 gap rows). One row per user-facing setting. Composite controls are expanded: a font group is 5 rows (font, size, outline, shadow, colour), a border group is 3–5 rows (style, size, colour, shadow, shadow size), a backdrop is 4 rows, a position block is 5 rows.","",
"**Columns:** *Now* = Phoenix settings today on retail (smoke harness settings count, cog sub-rows included) · *Forever* = the same count on the WoW Forever client (— = page not on Forever) · *Target* = full spec below minus link/api rows · *Has / Part / New* = target rows that Phoenix already has, has in a shallower form, or lacks · *Link / API* = rows owned by another page or Edit Mode (a link row points there) or not possible with the 12.x API; listed, not counted.","",
"**Status:** `has` = present · `part` = present but shallower (fewer choices, global instead of per-bar, etc.) · `new` = missing · `link` = owned by another page or Edit Mode · `api` = not possible in 12.x (secret values, protected frames, no data source).  **Preview:** `live` = the pinned preview in the settings window redraws · `hover` = hovering a dropdown item previews it · `world` = shows test/unlocked frames in the game world · `none` = behaviour only.","",
"**Source addon:** the reference addon a row comes from (for spec rows: the best match among the addons whose features this page owns in [PARITY.md](PARITY.md)). Rows grouped *Parity: <addon>* were added by the parity audit for features beyond the original spec; their *Stage* says when they are built. Encounter module coverage (BigWigs / LittleWigs vs Phoenix) is in PARITY.md.","",
"**Per-unit / per-bar rule:** groups marked *per bar* or *per unit* are one set of controls with a unit/bar switcher plus *Copy from…* and *Apply to all*; they are counted once, not ×N.","",
"## Summary","","| Module | Group | Now | Forever | Target | Has | Part | New | Link / API | References | How Phoenix builds it |","|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|"]
T=[0,0,0,0,0,0,0]
for m in summary:
    nf = m['nowF'] if m['nowF'] is not None else "—"
    md.append(f"| {m['label']} | {m['group']} | {m['now']} | {nf} | {m['target']} | {m['has']} | {m['part']} | {m['new']} | {m['ext']} | {m['refs']} | {m['kind']} |")
    for i,x in enumerate(['now','nowF','target','has','part','new','ext']): T[i]+=m[x] or 0
md.append(f"| **Total** | | **{T[0]}** | **{T[1]}** | **{T[2]}** | **{T[3]}** | **{T[4]}** | **{T[5]}** | **{T[6]}** | every addon on I:\\ (see PARITY.md) | |")
md.append("")
SRC = collections.OrderedDict()
for m in summary:
    for row in m["rows"]:
        e = SRC.setdefault(row["source"], collections.Counter()); e[row["status"]] += w(row)
md += ["## Rows by source addon", "", "| Source addon | Rows | has | part | new | link | api |", "|---|---:|---:|---:|---:|---:|---:|"]
for a, c in sorted(SRC.items(), key=lambda x: -sum(x[1].values())):
    md.append(f"| {a} | {sum(c.values())} | {c['has']} | {c['part']} | {c['new']} | {c['link']} | {c['api']} |")
md.append("")
for m in summary:
    md += [f"## {m['label']}  (`{m['key']}`)", "", f"*Now {m['now']} (Forever {m['nowF'] if m['nowF'] is not None else '—'}) → target {m['target']}* · has {m['has']} · part {m['part']} · new {m['new']} · link/api {m['ext']}", "", f"**How:** {m['kind']}", "", f"**References:** {m['refs']}", "",
           "| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |","|---|---|---|---|---|---|---|---|---|"]
    for r in m["rows"]:
        md.append(f"| {r['group']} | {r['name']} | {TN.get(r['type'],r['type'])} | {str(r['range']).replace('|', '/')} | {r['default']} | {r['preview']} | {r['status']} | {r['source']} | {r['stage']} |")
    md.append("")
open("../GAP_MATRIX.md","w").write("\n".join(md))
# compact json for the Page: only per module summary + rows (missing first)
J=[]
for m in summary:
    J.append(dict(k=m['key'],l=m['label'],g=m['group'],now=m['now'],nf=m['nowF'],t=m['target'],h=m['has'],p=m['part'],n=m['new'],x=m['ext'],how=m['kind'],refs=m['refs'],
      rows=[[r['group'].split(' (')[0],r['name'],TN.get(r['type'],r['type']),r['range'],r['default'],r['preview'],r['status'],r['source'],r['stage']] for r in m['rows']]))
json.dump(J,open("gap.json","w"),ensure_ascii=False,separators=(',',':'))
print(T, len(open("gap.json").read()), "parity rows", PARITY_ROWS, "folded", FOLDED)
assert FOLDED == len(DUP), "a DUP entry matched nothing"
