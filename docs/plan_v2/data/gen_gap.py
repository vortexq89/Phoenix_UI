import sys, json; sys.path.insert(0,'.')
import spec_core, spec_ui, spec_rest, patch_status
from spec_lib import MOD
patch_status.apply(); patch_status.apply2()
ORDER = ["ActionBars","CooldownText","Tracker","UnitFrames","GroupFrames","NamePlates","CastBars","Auras","CombatText","DamageMeter","SpellHistory",
         "Chat","Minimap","Tooltip","Bags","ItemLevel","DataTexts","Skins","General","Profiles","Movers","Quality","Automation","AFK","Bugs",
         "Quests","GroupFinder","MythicPlus","Encounters","PvP","Sim","Diagnostics"]
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
"Generated from `data/spec_*.py` by `data/gen_gap.py` (2026-10-22, S16 re-audit). One row per user-facing setting. Composite controls are expanded: a font group is 5 rows (font, size, outline, shadow, colour), a border group is 3–5 rows (style, size, colour, shadow, shadow size), a backdrop is 4 rows, a position block is 5 rows.","",
"**Columns:** *Now* = Phoenix settings today on retail (smoke harness settings count, cog sub-rows included) · *Forever* = the same count on the WoW Forever client (— = page not on Forever) · *Target* = full spec below minus link/api rows · *Has / Part / New* = target rows that Phoenix already has, has in a shallower form, or lacks · *Link / API* = rows owned by another page or Edit Mode (a link row points there) or not possible with the 12.x API; listed, not counted.","",
"**Status:** `has` = present · `part` = present but shallower (fewer choices, global instead of per-bar, etc.) · `new` = missing · `link` = owned by another page or Edit Mode · `api` = not possible in 12.x (secret values, protected frames, no data source).  **Preview:** `live` = the pinned preview in the settings window redraws · `hover` = hovering a dropdown item previews it · `world` = shows test/unlocked frames in the game world · `none` = behaviour only.","",
"**Per-unit / per-bar rule:** groups marked *per bar* or *per unit* are one set of controls with a unit/bar switcher plus *Copy from…* and *Apply to all*; they are counted once, not ×N.","",
"## Summary","","| Module | Group | Now | Forever | Target | Has | Part | New | Link / API | References | How Phoenix builds it |","|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|"]
T=[0,0,0,0,0,0,0]
for m in summary:
    nf = m['nowF'] if m['nowF'] is not None else "—"
    md.append(f"| {m['label']} | {m['group']} | {m['now']} | {nf} | {m['target']} | {m['has']} | {m['part']} | {m['new']} | {m['ext']} | {m['refs']} | {m['kind']} |")
    for i,x in enumerate(['now','nowF','target','has','part','new','ext']): T[i]+=m[x] or 0
md.append(f"| **Total** | | **{T[0]}** | **{T[1]}** | **{T[2]}** | **{T[3]}** | **{T[4]}** | **{T[5]}** | **{T[6]}** | EllesmereUI 2,420 controls · WindTools 361 · sArena 416 · MoveAny ~150 | |")
md.append("")
for m in summary:
    md += [f"## {m['label']}  (`{m['key']}`)", "", f"*Now {m['now']} (Forever {m['nowF'] if m['nowF'] is not None else '—'}) → target {m['target']}* · has {m['has']} · part {m['part']} · new {m['new']} · link/api {m['ext']}", "", f"**How:** {m['kind']}", "", f"**References:** {m['refs']}", "",
           "| Group | Setting | Type | Range / choices | Default | Preview | Status |","|---|---|---|---|---|---|---|"]
    for r in m["rows"]:
        md.append(f"| {r['group']} | {r['name']} | {TN.get(r['type'],r['type'])} | {r['range']} | {r['default']} | {r['preview']} | {r['status']} |")
    md.append("")
open("../GAP_MATRIX.md","w").write("\n".join(md))
# compact json for the Page: only per module summary + rows (missing first)
J=[]
for m in summary:
    J.append(dict(k=m['key'],l=m['label'],g=m['group'],now=m['now'],nf=m['nowF'],t=m['target'],h=m['has'],p=m['part'],n=m['new'],x=m['ext'],how=m['kind'],refs=m['refs'],
      rows=[[r['group'].split(' (')[0],r['name'],TN.get(r['type'],r['type']),r['range'],r['default'],r['preview'],r['status']] for r in m['rows']]))
json.dump(J,open("gap.json","w"),ensure_ascii=False,separators=(',',':'))
print(T, len(open("gap.json").read()))
