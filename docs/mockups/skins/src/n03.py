from sk2 import *
import random; random.seed(3)
X,Y,W,H=40,96,1150,628
AB=['ab_vivify','ab_renew','ab_envelop','ab_essence','ab_lotus','ab_chiji','ab_tea','ab_kick','ab_roll','ab_fist','ab_shield','ab_cocoon']
def node(x,y,st,ch=False):
    col={'on':'var(--acc)','part':'#F4C46A','off':'#3a3d46','avail':'#3DDC97'}[st]
    shp='clip-path:polygon(30% 0,70% 0,100% 30%,100% 70%,70% 100%,30% 100%,0 70%,0 30%)' if ch else 'border-radius:50%'
    return f'<div class="abs" style="left:{x}px;top:{y}px;width:40px;height:40px;{shp};background:{col};padding:2px"><div style="width:36px;height:36px;{shp};background:#000 url({A}Icons__Abilities__{random.choice(AB)}_64.png) center/cover;{"filter:grayscale(1) brightness(.5)" if st=="off" else ""}"></div></div>'
def tree(ox,oy,cols,rows,gate=None):
    h=''
    for r in range(rows):
        for c in range(cols):
            if (r*3+c)%4==3: continue
            st='on' if r<3 and random.random()<.7 else random.choice(['avail','off','off','part'])
            h+=f'<div class="abs" style="left:{ox+c*54+19}px;top:{oy+r*54+40}px;width:2px;height:14px;background:{"var(--acc)" if st=="on" else "#2a2c33"}"></div>' if r<rows-1 else ''
            h+=node(ox+c*54,oy+r*54,st,ch=(r+c)%5==2)
        if gate and r==gate: h+=f'<div class="abs" style="left:{ox-30}px;top:{oy+r*54+46}px;font:700 9px Inter;color:#ffd27a">🔒 8</div>'
    return h
b=at(64,8,'<span class="lbl">Monk · 31 points</span>')+at(470,8,'<span class="lbl">Conduit of the Celestials</span>')+at(760,8,'<span class="lbl">Mistweaver · 2 points</span>')
b+=tree(40,34,7,9,gate=3)+tree(480,90,3,5)+tree(760,34,7,9,gate=4)
b+=at(470,40,'<div class="card" style="padding:4px 8px;display:flex;gap:6px;align-items:center;width:200px"><span class="btn" style="height:22px">Hero spec ▾</span><span class="mut" style="font-size:10px">choose hero tree</span></div>')
b+=at(16,H-76,'<div style="display:flex;gap:8px;align-items:center;width:1110px"><div class="dd" style="width:200px">Loadout: Raid ST</div>'+px(btn('Share ▸ Phoenix Loadouts'))+'<div class="srch" style="width:200px;height:26px">⌕ Search talents</div><span class="btn">PvP talents</span><span class="btn g">War Mode</span><span class="ck"></span><span class="mut" style="font-size:10px">Starter build</span><span style="margin-left:auto">'+btn('Reset','g')+btn('Undo','g')+btn('Apply Changes','p')+'</span></div>')
tip=f'<div class="tip" style="left:{X+300}px;top:{Y+190}px;width:250px;z-index:50"><b>Celestial Harmony</b><div class="mut">Rank 1/2 · choice node</div><div>Increases healing of Yu\'lon and Chi-Ji…</div><div class="ok" style="font-size:10.5px">Click to learn</div></div>'
w=bwin(X,Y,W,H,'Talents',b,icon='Icons__Modules__64__loadouts',btabs=['Specialization','Talents','Spellbook'],on=1)
dlg=bwin(X+W-430,Y+H+44,430,140,'Edit loadout',at(12,10,'<div style="width:400px"><div class="srch" style="height:24px;color:var(--tx)">Raid ST</div><div style="margin-top:8px"><span class="ck on"></span> Uses shared action bars</div><div style="margin-top:8px">'+btn('Delete','d')+' '+btn('Cancel','g')+' '+btn('Accept','p')+'</div></div>'),cog=False,portrait=False,z=11,sub='ClassTalentLoadoutEditDialog')
ins=at(X,Y+H+44,'<div class="card" style="padding:8px 10px;width:680px;font-size:11px"><b>Inspect mode:</b> same tree read-only + <span class="btn" style="height:22px">Copy loadout</span> · Phoenix ◆ node style, lit edges and rank badges follow the theme; nothing is written to the talent frame.</div>')
fl=fly(X+W-260,Y+34,'Talents',[('Node rings','<span class="tg on"></span>'),('Lit edges','<span class="tg on"></span>'),('Compact tree','<span class="tg"></span>'),('Theme','<span class="dd" style="width:80px;height:20px">Ember</span>')])
page2('03_talents','Blizzard PlayerSpellsFrame · Talents tab layout (class · hero · spec) · Ember',w+tip+dlg+ins+fl)
