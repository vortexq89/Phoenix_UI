import subprocess, os
RAIL=[("Home",0),("Frames",0),("Bars",0),("Combat",0),("Interface",0),("Content",0),("Phoenix",0)]
NAV={
 "Bars":[("Action Bars",.95),("Cooldown Manager",.5),("Cooldown Text",.4)],
 "Frames":[("Unit Frames",.9),("Group Frames",.6),("Nameplates",.8),("Cast Bars",.7),("Buffs & Debuffs",.6)],
 "Combat":[("Combat Text",.5),("Damage Meter",.3),("Spell History",.6)],
 "Interface":[("Chat",.5),("Minimap",.3),("Tooltips",.7),("Bags",.3),("Item Level",.4),("Data Texts",.6),("Skins",.2)],
 "Content":[("Quests",.0),("Group Finder",.0),("Mythic+",.5),("Encounters",.95),("PvP",.4),("Sim",.8)],
}
def chrome(rail_on, nav_group, nav_on, main, prev, foot="", top_extra=""):
    rail="".join(f'<div class="ri{" on" if n==rail_on else ""}"><i></i>{n}</div>' for n,_ in RAIL)
    nav=f'<h4>{nav_group}</h4>'+"".join(f'<div class="ni{" on" if n==nav_on else ""}">{n}<span class="meter"><b style="width:{int(p*100)}%"></b></span></div>' for n,p in NAV.get(nav_group,[]))
    other=[g for g in NAV if g!=nav_group][:2]
    for g in other:
        nav+=f'<h4 style="margin-top:14px">{g}</h4>'+"".join(f'<div class="ni">{n}<span class="meter"><b style="width:{int(p*100)}%"></b></span></div>' for n,p in NAV[g][:3])
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="phoenix.css"></head><body>
<div class="win">
 <div class="top"><div class="logo"></div><div class="brand">Phoenix UI<small>12.1.5 · v2 layout</small></div>
  <div class="search">⌕ Search 1,186 settings… e.g. “hotkey size”<span class="kbd">Ctrl F</span></div><div class="sp"></div>{top_extra}
  <div class="btn">Profile: <b style="color:var(--t1)">Main · Holy</b> ▾</div><div class="btn">⊞ Layout mode</div><div class="btn">▶ Test frames</div><div class="btn">✕</div></div>
 <div class="rail">{rail}</div>
 <div class="nav">{nav}</div>
 <div class="main">{main}</div>
 <div class="prev">{prev}</div>
 <div class="foot">{foot or '<b>Auto-saved</b> · changes apply live · <span>right-click any row to reset</span><span class="sp"></span><span>Pixel-perfect scale 0.71</span>'}</div>
</div></body></html>'''

def sl(label,val,pct,sync=True): return f'<div class="f"><label>{label}{"<span class=sync title=\"apply to all\">⇄</span>" if sync else ""}</label><div class="sl"><div class="tr"><b style="width:{pct}%"></b></div><div class="v">{val}</div></div></div>'
def dd(label,val): return f'<div class="f"><label>{label}</label><div class="dd">{val}</div></div>'
def tg(label,on=True): return f'<div class="tgrow">{label}<span class="tg{" on" if on else ""}"></span></div>'
def col(label,c,extra=""): return f'<div class="f"><label>{label}</label><div style="display:flex;gap:6px;align-items:center"><span class="sw" style="background:{c}"></span>{extra}</div></div>'
def seg(label,opts,on): return f'<div class="f"><label>{label}</label><div class="seg">'+"".join(f'<span class="{"on" if o==on else ""}">{o}</span>' for o in opts)+'</div></div>'
def row(a,b): return f'<div class="row">{a}{b}</div>'
def card(t,body,gate=None): 
    g=f'<span class="gate tg{" on" if gate else ""}"></span>' if gate is not None else ''
    return f'<div class="card"><h3>{t}{g}</h3>{body}</div>'

pages={}
# 1 Action bars
main=f'''<div class="hdr"><div><h1>Action Bars</h1><p>Phoenix-owned secure bars · Blizzard buttons inside · 114 settings</p></div><div class="sp"></div><div class="btn">Presets ▾</div><div class="btn">Reset module</div><span class="tg on"></span></div>
<div class="tabs"><div class="tab on">Layout</div><div class="tab">Buttons</div><div class="tab">Text</div><div class="tab">Visibility</div><div class="tab">Paging</div><div class="tab">Extra bars</div></div>
<div class="chips"><span class="chip">Bar 1</span><span class="chip on">Bar 2</span><span class="chip">Bar 3</span><span class="chip">Bar 4</span><span class="chip">Bar 5</span><span class="chip">Bar 6</span><span class="chip">Bar 7</span><span class="chip">Bar 8</span><span class="chip">Pet</span><span class="chip">Stance</span><span class="tools"><span class="btn">Copy from ▾</span><span class="btn">Apply to all</span></span></div>
<div class="grid2">
{card("Grid", row(sl("Buttons","12",100),sl("Rows","2",16))+row(sl("Button width","38 px",22),sl("Button height","38 px",22))+row(sl("Horizontal spacing","2 px",30),sl("Vertical spacing","2 px",30))+row(seg("Grow","Right Left Up Down".split(),"Right"),dd("Button order","Normal")), True)}
{card("Backdrop & border", row(dd("Button border","Pixel · 1 px"),col("Border colour","#000","<span class=pill>Class</span><span class=pill>Theme</span>"))+row(dd("Shadow","Soft · 4 px"),sl("Icon zoom","8 %",40))+row(dd("Bar backdrop","Solid"),sl("Backdrop opacity","50 %",50))+row(dd("Button shape","Square"),sl("Backdrop padding","3 px",15)), True)}
{card("Position", row(dd("Anchor","Bottom · UIParent"),dd("Strata","Medium"))+row(sl("X","0",50,False),sl("Y","96",58,False))+row(sl("Scale","100 %",33,False),tg("Click-through",False)))}
{card("Quick visibility", tg("Fade out of combat",True)+tg("Show on mouseover",True)+row(sl("Out-of-combat opacity","30 %",30,False),dd("Vehicles / pet battle","Hide"))+'<div style="color:var(--t3);font-size:11px;margin-top:4px">Full rules on the Visibility tab · custom state macro supported</div>')}
</div>'''
prev='''<h4>Live preview<span>Bar 2 · 12 × 2</span></h4><div class="states"><span class="chip on">Normal</span><span class="chip">On cooldown</span><span class="chip">Out of range</span><span class="chip">No power</span><span class="chip">Proc</span><span class="chip">Mouseover fade</span></div>
<div class="stage"><div class="ab" style="left:20px;top:110px;grid-template-columns:repeat(6,40px)">'''+"".join(f'<div class="b{c}"><span class="hk">{k}</span>{"<span class=n>4</span>" if c==" cd" else ""}{"<span class=ct>3</span>" if i==4 else ""}</div>' for i,(k,c) in enumerate([("1",""),("2"," cd"),("3",""),("4"," pr"),("5",""),("Q"," rg"),("E",""),("R",""),("F",""),("Z"," cd"),("X",""),("C","")]))+'''</div>
<div class="note" style="left:20px;top:80px">6 × 2 shown (preview wraps at panel width)</div><div class="note" style="left:20px;top:220px">hover a dropdown item → preview changes before you pick</div></div>
<div class="btn" style="justify-content:center">▶ Show this bar in the world</div>'''
pages["1_actionbars"]=chrome("Bars","Bars","Action Bars",main,prev)

# 2 Unit frames
main=f'''<div class="hdr"><div><h1>Unit Frames</h1><p>Phoenix secure frames · 150 settings · per unit with Copy / Apply to all</p></div><div class="sp"></div><div class="btn">Presets ▾</div><span class="tg on"></span></div>
<div class="tabs"><div class="tab">Frame</div><div class="tab on">Health</div><div class="tab">Power &amp; class</div><div class="tab">Text tags</div><div class="tab">Portrait</div><div class="tab">Auras</div><div class="tab">Indicators</div><div class="tab">Cast bar</div></div>
<div class="chips"><span class="chip">Player</span><span class="chip on">Target</span><span class="chip">Target of target</span><span class="chip">Focus</span><span class="chip">Pet</span><span class="chip">Boss 1–5</span><span class="chip">Arena 1–5</span><span class="tools"><span class="btn">Copy from ▾</span><span class="btn">Apply to all</span></span></div>
<div class="grid2">
{card("Health bar", row(dd("Texture","Phoenix Satin"),seg("Fill","→ ← ↑ ↓".split(),"→"))+row(dd("Colour mode","Class"),dd("Gradient","Horizontal"))+row(col("Tapped","#8C8C8C"),col("Dead / offline","#555"))+row(tg("Smooth fill",True),tg("Dark mode",False)))}
{card("Absorbs & prediction", row(dd("Absorb shield","Striped"),sl("Absorb opacity","60 %",60,False))+row(dd("Heal absorb","Overlay"),tg("Over-absorb glow",True))+row(tg("Heal prediction",True),sl("Overheal shown","10 %",20,False)), True)}
{card("Background", row(dd("Background colour","Class (dimmed)"),sl("Opacity","60 %",60,False))+row(dd("Frame border","Pixel · 1 px"),dd("Shadow","Soft · 4 px")))}
{card("Text tags (preview →)", '<div class="f"><label>Left</label><div class="tagbox"><em>[name:short]</em> <em>[classification]</em></div></div><div class="f" style="margin-top:6px"><label>Right</label><div class="tagbox"><em>[health:current]</em> | <em>[health:percent]</em></div></div><div style="margin-top:6px">'+"".join(f'<span class="pill">{t}</span>' for t in ["[name]","[level]","[health:deficit]","[power:current]","[status]","[group]","[threat]","[target]"])+'</div><div style="color:var(--t3);font-size:11px;margin-top:6px">Secret-safe: numbers go through display sinks (AbbreviateNumbers, UnitHealthPercent + colour curves) — no maths on secrets.</div>')}
</div>'''
prev='''<h4>Live preview<span>Target · 230 × 44</span></h4><div class="states"><span class="chip on">Hostile</span><span class="chip">Friendly</span><span class="chip">Tapped</span><span class="chip">Dead</span><span class="chip">Casting</span><span class="chip">Low health</span></div>
<div class="stage">
<div class="uf" style="left:60px;top:40px"><div class="hp"><b style="width:100%;background:#2a2a30"></b><b style="width:72%;background:linear-gradient(90deg,#c69b6d,#8a6a48)"></b><span class="ab2" style="left:72%;width:12%"></span><span class="t" style="left:8px">Blood Elf Warrior</span><span class="t" style="right:8px">412K | 72%</span></div><div class="pw"><b style="width:60%;background:#c22"></b></div></div>
<div class="aur" style="left:60px;top:15px"><i class="mg"></i><i class="cu"></i><i></i><i class="po"></i></div>
<div class="uf" style="left:60px;top:130px;width:200px"><div class="hp" style="height:30px"><b style="width:46%;background:linear-gradient(90deg,#d43,#b22)"></b><span class="t" style="left:8px">Voidspawn Lurker ★</span><span class="t" style="right:8px">46%</span></div><div class="pw"><b style="width:30%;background:#c9a"></b></div></div>
<div style="position:absolute;left:60px;top:174px;width:200px;height:16px;background:#222;border:1px solid #000"><div style="width:58%;height:100%;background:linear-gradient(90deg,#e0a43a,#ffcf4a)"></div><span style="position:absolute;left:6px;top:0;font-size:11px">Shadow Bolt → you</span><span style="position:absolute;right:6px;top:0;font-size:11px">1.2</span><span style="position:absolute;left:70%;top:-2px;bottom:-2px;width:2px;background:#4fc3f7"></span></div>
<div class="note" style="left:60px;top:205px">blue tick = your interrupt ready</div>
<div class="uf" style="left:60px;top:250px;width:150px"><div class="hp" style="height:22px"><b style="width:88%;background:#3fa34d"></b><span class="t" style="left:6px;font-size:11px">ToT · Aelinn</span></div></div>
</div><div class="btn" style="justify-content:center">▶ Test frames in the world (boss, arena, party)</div>'''
pages["2_unitframes"]=chrome("Frames","Frames","Unit Frames",main,prev)

# 3 Nameplates
main=f'''<div class="hdr"><div><h1>Nameplates</h1><p>Restyled Blizzard plates · 100 settings</p></div><div class="sp"></div><span class="tg on"></span></div>
<div class="tabs"><div class="tab">Size</div><div class="tab">Health</div><div class="tab on">Colours</div><div class="tab">Cast bar</div><div class="tab">Text</div><div class="tab">Auras</div><div class="tab">Mythic+</div></div>
<div class="chips"><span class="chip on">Enemy</span><span class="chip">Friendly</span><span class="chip">Personal</span></div>
<div class="grid2">
{card("Threat (role aware)", row(col("Tank · secure","#3FA34D"),col("Tank · losing","#E6B54A"))+row(col("Tank · lost","#E5534B"),col("DPS · has aggro","#E5534B"))+row(tg("Use threat colours",True),tg("Off-tank counts as secure",True)), True)}
{card("Reaction", row(col("Hostile","#D9433A"),col("Neutral","#E6C84D"))+row(col("Friendly","#3FA34D"),col("Tapped","#8C8C8C"))+row(tg("Class colour enemy players",True),col("Quest mob","#E6C84D")))}
{card("Target & focus", row(dd("Target effect","Border + arrows"),col("Target colour","#FF6A1A"))+row(dd("Focus marker","Letter F"),dd("Hover","Lighten"))+row(sl("Target scale","115 %",43,False),sl("Non-target opacity","70 %",70,False)))}
{card("Execute", row(tg("Execute colour",True),sl("Below","20 %",40,False))+row(col("Execute colour","#FF3DCB"),dd("Source","Spec default")))}
</div>'''
plates=""
for i,(y,c,w,nm,tgt) in enumerate([(40,"#3FA34D",80,"Shadowguard Sentinel",False),(110,"#E6B54A",55,"Void Ripper",True),(180,"#E5534B",35,"Lurking Horror",False),(250,"#FF3DCB",15,"Dread Acolyte",False)]):
    b='box-shadow:0 0 0 1px #FF6A1A,0 0 8px #FF6A1A;' if tgt else ''
    plates+=f'<div style="position:absolute;left:70px;top:{y}px;width:{160 if tgt else 140}px"><div style="font-size:11px;text-align:center;margin-bottom:2px">{nm}</div><div style="height:12px;background:#1a1a1a;border:1px solid #000;{b}position:relative"><div style="width:{w}%;height:100%;background:{c}"></div><span style="position:absolute;right:3px;top:-2px;font-size:10px">{w}%</span></div>{"<div style=\"height:9px;margin-top:2px;background:#222;border:1px solid #000\"><div style=\"width:40%;height:100%;background:#ffcf4a\"></div></div>" if tgt else ""}</div>'
    if tgt: plates+=f'<div style="position:absolute;left:50px;top:{y+16}px;color:#FF6A1A">▶</div><div style="position:absolute;left:238px;top:{y+16}px;color:#FF6A1A">◀</div>'
prev=f'''<h4>Live preview<span>4 sample plates</span></h4><div class="states"><span class="chip on">Tank</span><span class="chip">DPS</span><span class="chip">👁 cast</span><span class="chip">👁 auras</span><span class="chip">👁 marker</span><span class="chip">👁 forces</span></div>
<div class="stage">{plates}<div class="note" style="left:20px;top:300px">secure · losing · lost · execute — exactly what you'll see in a pull</div></div>'''
pages["3_nameplates"]=chrome("Frames","Frames","Nameplates",main,prev)

# 4 Home
tiles=""
for n,now,t in [("Action Bars",33,114),("Unit Frames",41,150),("Group Frames",18,68),("Nameplates",59,100),("Cast Bars",23,55),("Buffs & Debuffs",15,41),("Cooldown Manager",28,59),("Chat",17,51),("Minimap",5,41),("Tooltips",29,45),("Bags",6,47),("Data Texts",35,47)]:
    tiles+=f'<div class="card" style="padding:10px"><div style="display:flex;align-items:center"><b>{n}</b><span class="tg on" style="margin-left:auto"></span></div><div style="color:var(--t3);font-size:11px;margin:4px 0 6px">{now} → {t} settings</div><div class="meter" style="width:100%;margin:0"><b style="width:{int(now/t*100)}%"></b></div></div>'
main=f'''<div class="hdr"><div><h1>Welcome back, Abdulrahman</h1><p>Pick a look, then fine-tune each module. Everything previews live.</p></div></div>
<div class="grid2" style="grid-template-columns:repeat(4,1fr)">'''+"".join(f'<div class="card" style="padding:0;overflow:hidden;{"box-shadow:0 0 0 1px var(--acc)" if i==0 else ""}"><div style="height:92px;background:{bg}"></div><div style="padding:8px 10px"><b>{n}</b><div style="color:var(--t3);font-size:11px">{d}</div></div></div>' for i,(n,d,bg) in enumerate([("Phoenix Ember","Dark, ember accents","linear-gradient(135deg,#2a1a10,#ff6a1a 160%)"),("Healer","Big group frames, centre","linear-gradient(135deg,#10251a,#3fa34d 170%)"),("Tank","Threat plates, CDM centre","linear-gradient(135deg,#10182a,#3d8bff 170%)"),("Minimal","Fades, small bars","linear-gradient(135deg,#18191c,#666 200%)")]))+f'''</div>
<div style="display:flex;align-items:center;gap:10px;margin-top:4px"><b>Modules</b><span style="color:var(--t3)">bar = depth reached vs v2 target</span><span class="sp"></span><span class="chip on">Core</span><span class="chip">Interface</span><span class="chip">Content</span></div>
<div class="grid2" style="grid-template-columns:repeat(4,1fr)">{tiles}</div>'''
prev='''<h4>Health checks</h4><div class="card">'''+"".join(f'<div class="tgrow"><span>{a}</span><span style="color:{c}">{b}</span></div>' for a,b,c in [("Secret restrictions","none (open world)","var(--ok)"),("Conflicting addons","Bartender4 — bars off","var(--warn)"),("Lua errors this session","0","var(--ok)"),("Uploader","linked · sim 2 h ago","var(--ok)"),("Quest data","Midnight 1,408 quests","var(--ok)")])+'''</div>
<h4>What's new</h4><div class="card" style="color:var(--t2);font-size:12px;line-height:1.5">• Action Bars: own bars with per-bar layout<br>• Unit Frames: tags, absorbs, portraits<br>• Quests: giver &amp; turn-in pins</div>
<h4>Quick actions</h4><div class="btn">⊞ Layout mode</div><div class="btn">⇩ Import profile string</div><div class="btn">▶ Test all frames</div>'''
pages["4_home"]=chrome("Home","Frames","",main,prev)

# 5 Layout mode (in world)
html='''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="phoenix.css"><style>
.gridbg{position:absolute;inset:0;background-image:linear-gradient(rgba(255,106,26,.08) 1px,transparent 1px),linear-gradient(90deg,rgba(255,106,26,.08) 1px,transparent 1px);background-size:32px 32px}
.mv{position:absolute;border:1px dashed var(--acc);background:rgba(255,106,26,.10);color:var(--acc2);font-size:11px;display:flex;align-items:center;justify-content:center;border-radius:3px}
.mv.sel{border-style:solid;background:rgba(255,106,26,.22);box-shadow:0 0 0 1px var(--acc),0 0 16px rgba(255,106,26,.4)}
.pop{position:absolute;width:280px;background:var(--bg);border:1px solid var(--line2);border-radius:8px;box-shadow:0 12px 30px rgba(0,0,0,.6);padding:10px 12px}
.bar{position:absolute;left:50%;top:14px;transform:translateX(-50%);display:flex;gap:8px;background:var(--bg);border:1px solid var(--line2);border-radius:8px;padding:6px 10px;align-items:center}
.list{position:absolute;right:16px;top:70px;width:230px;bottom:70px;background:var(--bg);border:1px solid var(--line2);border-radius:8px;padding:10px}
</style></head><body><div class="gridbg"></div>
<div class="bar"><b style="color:var(--acc)">Layout mode</b><span class="chip on">Grid 32</span><span class="chip on">Snap</span><span class="chip">Snap to frames</span><span class="chip">Show Blizzard frames</span><span class="btn">Undo</span><span class="btn pri">Done</span></div>
<div class="mv" style="left:420px;top:780px;width:500px;height:42px">Action Bar 1</div>
<div class="mv sel" style="left:420px;top:730px;width:500px;height:42px">Action Bar 2 · 0, 96</div>
<div class="mv" style="left:930px;top:640px;width:42px;height:180px">Bar 4</div>
<div class="mv" style="left:330px;top:520px;width:230px;height:52px">Player</div>
<div class="mv" style="left:780px;top:520px;width:230px;height:52px">Target</div>
<div class="mv" style="left:1020px;top:530px;width:150px;height:30px">ToT</div>
<div class="mv" style="left:560px;top:600px;width:220px;height:22px">Player cast bar</div>
<div class="mv" style="left:20px;top:420px;width:300px;height:170px">Party / raid</div>
<div class="mv" style="left:1150px;top:80px;width:200px;height:200px">Minimap</div>
<div class="mv" style="left:20px;top:640px;width:380px;height:180px">Chat</div>
<div class="mv" style="left:1100px;top:300px;width:250px;height:300px">Objective tracker</div>
<div class="mv" style="left:520px;top:440px;width:300px;height:60px">Cooldown Manager · Essential</div>
<div class="mv" style="left:1180px;top:840px;width:200px;height:24px">Data bar</div>
<div class="pop" style="left:560px;top:560px"><div style="display:flex;align-items:center"><b>Action Bar 2</b><span class="sp"></span><span style="color:var(--t3)">✕</span></div>
<div class="row"><div class="f"><label>X</label><div class="dd">0</div></div><div class="f"><label>Y</label><div class="dd">96</div></div></div>
<div class="row"><div class="f"><label>Anchor</label><div class="dd">Bottom</div></div><div class="f"><label>Scale</label><div class="dd">100 %</div></div></div>
<div style="display:flex;gap:6px;margin-top:6px"><span class="btn">Settings…</span><span class="btn">Reset</span><span class="btn">Hide</span></div>
<div style="color:var(--t3);font-size:11px;margin-top:6px">Arrow keys nudge 1 px · Shift 10 px</div></div>
<div class="list"><b>Frames</b><div class="search" style="margin:8px 0;flex:none;width:100%">⌕ filter</div>'''+"".join(f'<div class="ni{" on" if n=="Action Bar 2" else ""}">{n}<span class="dot{"" if v else " off"}"></span></div>' for n,v in [("Action Bar 1",1),("Action Bar 2",1),("Action Bar 3",0),("Bar 4",1),("Player",1),("Target",1),("Focus",0),("Party / raid",1),("Boss frames",1),("Cast bars",1),("Minimap",1),("Chat",1),("Tracker",1),("Talking head (Blizzard)",0),("Loot window (Blizzard)",0)])+'''</div>
</body></html>'''
open("5_layout_mode.html","w").write(html)
for k,v in pages.items(): open(f"{k}.html","w").write(v)
for f in sorted(os.listdir(".")):
    if f.endswith(".html"):
        png=f[:-5]+".png"
        subprocess.run(["google-chrome","--headless=new","--no-sandbox","--disable-gpu","--hide-scrollbars","--window-size=1400,900",f"--screenshot={os.path.abspath(png)}",f"file://{os.path.abspath(f)}"],capture_output=True,timeout=60)
        print(png, os.path.exists(png))
