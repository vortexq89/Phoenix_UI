from sk import *
# 02 Spellbook
sp=[('ab_vivify','Vivify','Instant · 30 yd'),('ab_renew','Renewing Mist','Instant · 8.5s CD'),('ab_envelop','Enveloping Mist','Cast 2s'),('ab_essence','Essence Font','Channel'),('ab_lotus','Life Cocoon','2 min CD'),('ab_chiji','Invoke Chi-Ji','1 min CD'),('ab_tea','Thunder Focus Tea','30s CD'),('ab_kick','Spear Hand Strike','15s · interrupt'),('ab_roll','Roll','2 charges'),('ab_fist','Rising Sun Kick','12s CD'),('ab_shield','Fortifying Brew','6 min CD'),('ab_cocoon','Revival','3 min CD')]
def card(i,a):
    g,n,t=a; hl=' hl' if i==2 else ''
    return f'<div class="row{hl}" style="height:58px;background:rgba(22,24,32,.7);border:1px solid {"rgba(255,122,26,.5)" if hl else "var(--line)"}">{ic(None,"#1FC8B0",42,img=A+"Icons__Abilities__"+g+"_64.png")}<div><div style="font-weight:600">{n}</div><div class="mut" style="font-size:10.5px">{t}</div></div>{"<span class=chip style=margin-left:auto>Passive</span>" if i==11 else ""}</div>'
grid='<div class="grid" style="grid-template-columns:1fr 1fr 1fr;gap:8px;padding:12px">'+''.join(card(i,a) for i,a in enumerate(sp))+'</div>'
head='<div style="display:flex;gap:8px;align-items:center;padding:10px 12px 0"><div class="srch" style="width:300px">⌕ Search spells, passives, talents…<b>Ctrl F</b></div>'+chips(['Mistweaver','Monk','General','Pet'],(0,))+'<span style="margin-left:auto" class="mut">Hide passives</span> <span class="tg on"></span></div>'
pg='<div class="abs" style="left:12px;right:12px;bottom:12px;display:flex;justify-content:space-between;align-items:center"><span class="mut">Page 1 / 3</span><span>'+btn('‹ Prev','g')+btn('Next ›')+'</span></div>'
w=win(28,72,1136,470,'Spellbook',head+grid+pg,icon='Icons__Modules__64__wisdom',sub='Talents & Spellbook · PlayerSpellsFrame',tabs=['Specialization','Talents','Spellbook'],active=2)
tip=f'<div class="tip" style="left:640px;top:310px;width:300px"><div style="display:flex;gap:8px;align-items:center">{ic(None,"#1FC8B0",30,img=A+"Icons__Abilities__ab_envelop_64.png")}<div><b style="font-size:13px">Enveloping Mist</b><div class="mut">Rank 1 · Mistweaver</div></div></div><div style="margin-top:6px" class="tx2">5.2% base mana · 40 yd · 2 sec cast</div><div style="margin-top:4px">Wraps the target in healing mists, healing for <span class="ok">912,405</span> over 6 sec.</div><div class="mut" style="margin-top:6px;font:500 10px JBM">SpellID 124682 · Shift for IDs</div></div>'
spec=''.join(f'<div class="card" style="padding:12px;width:262px;{"border-color:var(--acc);box-shadow:0 0 18px rgba(255,122,26,.25)" if i==1 else ""}">{ic(None,c,48,img=A+"Icons__Roles__"+r+".png")}<div class="ph" style="margin-top:8px">{n}</div><div class="mut" style="font-size:10.5px;margin:4px 0 8px">{d}</div>{btn("Active","p") if i==1 else btn("Activate")}</div>' for i,(n,r,c,d) in enumerate([('Brewmaster','tank','#a07a20','Tank · staggers damage'),('Mistweaver','healer','#1FC8B0','Healer · mists and fistweaving'),('Windwalker','damager','#c8243d','Melee damage · combos')]))
w2=win(28,560,900,280,'Specialization','<div style="display:flex;gap:14px;padding:14px">'+spec+'</div>',icon='Icons__Modules__64__loadouts',sub='tab preview',z=11)
s=side('partial','Skins pack <b>spellbook</b> (PlayerSpellsFrame): window shell, tabs, title font only. Spell cards, search box, page buttons, spec cards keep Blizzard art.',
 ['Spell cards: Phoenix tiles with icon, name, cast/CD line; passive chip','Search box in Phoenix style, Ctrl F focus, hide-passives toggle','Spec cards with role icons and accent glow on the active spec','Tooltip in Phoenix tooltip skin, IDs on Shift (HUD Tooltip IDs)'],
 ['Spell buttons are <b>secure</b> (drag/cast): no reparent, no OnClick hooks, no SetAttribute; texture + font restyle only via hooksecurefunc on the paged list\'s element initializer','Spec switching is protected: Phoenix never calls it; only skins the button','Talent/spell frames are taint-sensitive: nothing is written into Blizzard tables (weak side tables only)'],
 ['Skin on/off','Card size','Show cast line','Hide passives','Font','Accent glow'])
page('02_spellbook','Spellbook & specialization','Skins · Ember theme · PlayerSpellsFrame (12.x)',w+tip+w2+s)

# 03 Talents
def node(x,y,st,g,ch=False):
    col={'on':'#FF7A1A','part':'#F4C46A','off':'#3a3d46','avail':'#3DDC97'}[st]
    shp='border-radius:50%' if not ch else 'border-radius:10px;transform:rotate(45deg)'
    inner=f'<div style="position:absolute;inset:4px;{shp};overflow:hidden">{ic(None,"#1d2a2a" if st=="off" else "#205a50",36,img=A+"Icons__Abilities__"+g+"_64.png",rad=18,dim=st=="off")}</div>'
    return f'<div class="abs" style="left:{x}px;top:{y}px;width:44px;height:44px;{shp};border:2px solid {col};box-shadow:0 0 {12 if st=="on" else 0}px {col}88;background:#0a0b0e">{inner}</div><div class="abs" style="left:{x+30}px;top:{y+30}px;font:700 9px Inter;background:#0a0b0e;border:1px solid {col};border-radius:4px;padding:0 3px;color:{col}">{"1/1" if st=="on" else ("1/2" if st=="part" else "0/1")}</div>'
abs_=['ab_vivify','ab_renew','ab_envelop','ab_essence','ab_lotus','ab_chiji','ab_tea','ab_kick','ab_roll','ab_fist','ab_shield','ab_cocoon']
import random; random.seed(3)
def tree(ox,oy,cols,rows):
    h='';pts=[]
    for r in range(rows):
        if oy+r*58>420: break
        for c in range(cols):
            if (r+c)%3==2 and r>0: continue
            st=random.choice(['on','on','part','avail','off','off']) if r<rows-2 else random.choice(['off','avail'])
            x,y=ox+c*62,oy+r*58; pts.append((x,y,st)); h+=node(x,y,st,random.choice(abs_),ch=(r+c)%4==1)
    ln=''
    for x,y,st in pts:
        ln+=f'<div class="abs" style="left:{x+21}px;top:{y+44}px;width:2px;height:18px;background:{"#FF7A1A" if st=="on" else "#2a2c33"}"></div>'
    return ln+h
t='<div class="abs" style="left:14px;top:10px" ><span class="lbl">Monk · 31 points left</span></div><div class="abs" style="left:400px;top:10px"><span class="lbl">Conduit of the Celestials · hero</span></div><div class="abs" style="left:660px;top:10px"><span class="lbl">Mistweaver · 2 points left</span></div>'
t+=tree(20,40,6,7)+tree(410,70,3,4)+tree(640,40,7,7)
t+='<div class="abs" style="left:12px;right:12px;bottom:10px;display:flex;gap:8px;align-items:center"><div class="dd" style="width:220px">Loadout: Raid ST</div>'+btn('Share')+btn('Import')+'<div class="srch" style="width:240px">⌕ Search talents</div><span style="margin-left:auto">'+btn('Undo','g')+btn('Apply changes','p')+'</span></div>'
w=win(28,72,1136,580,'Talents',t,icon='Icons__Modules__64__loadouts',sub='Class · Hero · Spec trees',tabs=['Specialization','Talents','Spellbook'],active=1)
leg='<div class="card" style="padding:10px 12px;position:absolute;left:28px;top:668px;width:1136px;display:flex;gap:22px;align-items:center"><span class="lbl">Node states</span>'+''.join(f'<span style="display:flex;gap:6px;align-items:center"><span style="width:14px;height:14px;border-radius:50%;border:2px solid {c}"></span>{n}</span>' for n,c in [('Selected','#FF7A1A'),('Partially ranked','#F4C46A'),('Available','#3DDC97'),('Locked','#3a3d46')])+'<span class="mut" style="margin-left:auto">Square = choice node · circle = passive/active · lines lit in accent when the path is taken</span></div>'
s=side('partial','Same pack as the spellbook (PlayerSpellsFrame). Tree nodes, edges, hero panel, loadout dropdown and apply bar keep Blizzard art.',
 ['Nodes: Phoenix ring borders by state, accent glow on selected, rank badge','Edges lit in accent along the taken path','Bottom bar: Phoenix dropdown, search, Apply as primary button','Loadouts module (Phoenix) feeds the dropdown; spec auto-swap profiles'],
 ['<b>Most taint-sensitive window in the game</b>: talent commits are protected. Only textures/fonts on node buttons via hooksecurefunc on the node pool Acquire; never call ClassTalentFrame methods','Never skin during combat or while Apply is pending; CombatQueue defers','If a skin error is caught (securecallfunction), the pack reverts itself and Sentinel logs it'],
 ['Skin on/off','Node style','Edge glow','Rank badges','Compact tree','Hero tree position'])
page('03_talents','Talents','Skins · Ember theme · class, hero and spec trees',w+leg+s)
