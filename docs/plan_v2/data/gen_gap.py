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
    tgt=sum(w(r) for r in rows); has=sum(w(r) for r in rows if r["status"]=="has"); part=sum(w(r) for r in rows if r["status"]=="part")
    m.update(target=tgt, has=has, part=part, new=tgt-has-part)
    summary.append(m)
md=["# Phoenix UI — module gap matrix (v2)","",
"Generated from `data/spec_*.py` by `data/gen_gap.py` (2026-10-22). One row per user-facing setting. Composite controls are expanded: a font group is 5 rows (font, size, outline, shadow, colour), a border group is 3–5 rows (style, size, colour, shadow, shadow size), a backdrop is 4 rows, a position block is 5 rows.","",
"**Columns:** *Now* = Phoenix rows today (options dump, cog sub-rows included) · *Target* = full spec below · *Has / Part / New* = target rows that Phoenix already has, has in a shallower form, or lacks.","",
"**Status:** `has` = present · `part` = present but shallower (fewer choices, global instead of per-bar, etc.) · `new` = missing.  **Preview:** `live` = the pinned preview in the settings window redraws · `hover` = hovering a dropdown item previews it · `world` = shows test/unlocked frames in the game world · `none` = behaviour only.","",
"**Per-unit / per-bar rule:** groups marked *per bar* or *per unit* are one set of controls with a unit/bar switcher plus *Copy from…* and *Apply to all*; they are counted once, not ×N.","",
"## Summary","","| Module | Group | Now | Target | Has | Part | New | References | How Phoenix builds it |","|---|---|---:|---:|---:|---:|---:|---|---|"]
T=[0,0,0,0,0]
for m in summary:
    md.append(f"| {m['label']} | {m['group']} | {m['now']} | {m['target']} | {m['has']} | {m['part']} | {m['new']} | {m['refs']} | {m['kind']} |")
    for i,x in enumerate(['now','target','has','part','new']): T[i]+=m[x]
md.append(f"| **Total** | | **{T[0]}** | **{T[1]}** | **{T[2]}** | **{T[3]}** | **{T[4]}** | EllesmereUI 2,420 controls · WindTools 361 · sArena 416 · MoveAny ~150 | |")
md.append("")
for m in summary:
    md += [f"## {m['label']}  (`{m['key']}`)", "", f"*Now {m['now']} → target {m['target']}* · has {m['has']} · part {m['part']} · new {m['new']}", "", f"**How:** {m['kind']}", "", f"**References:** {m['refs']}", "",
           "| Group | Setting | Type | Range / choices | Default | Preview | Status |","|---|---|---|---|---|---|---|"]
    for r in m["rows"]:
        md.append(f"| {r['group']} | {r['name']} | {TN.get(r['type'],r['type'])} | {r['range']} | {r['default']} | {r['preview']} | {r['status']} |")
    md.append("")
open("../GAP_MATRIX.md","w").write("\n".join(md))
# compact json for the Page: only per module summary + rows (missing first)
J=[]
for m in summary:
    J.append(dict(k=m['key'],l=m['label'],g=m['group'],now=m['now'],t=m['target'],h=m['has'],p=m['part'],n=m['new'],how=m['kind'],refs=m['refs'],
      rows=[[r['group'].split(' (')[0],r['name'],TN.get(r['type'],r['type']),r['range'],r['default'],r['preview'],r['status']] for r in m['rows']]))
json.dump(J,open("gap.json","w"),ensure_ascii=False,separators=(',',':'))
print(T, len(open("gap.json").read()))
