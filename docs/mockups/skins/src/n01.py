from sk2 import *
S=1.55
def u(v): return int(v*S)
X,Y=40,92
L=['visored_helm','pin','shield','hood','heart_shield','scroll_unfurled','flag_objective','mailed_fist'];R=['fist','stars_stack','run','sprint','fire_ring','fire_ring','crystal_ball','hourglass']
QL=['leg','epic','epic','epic','epic','common','rare','epic'];QR=['epic','epic','leg','epic','epic','rare','epic','epic']
IL=[678,671,675,671,678,'','',665];IR=[675,671,678,668,671,658,678,671]
def slot(g,q,il,ex=''):
    b=ic(g,'#5a3a90' if q=='epic' else ('#a05010' if q=='leg' else '#2a4a7a'),u(37),q)
    if il: b+=f'<span class="px" style="position:absolute;left:2px;bottom:1px;font:700 10px Inter;color:#F4C46A;text-shadow:0 0 3px #000;outline-offset:0">{il}</span>'
    return f'<div style="position:relative;width:{u(37)}px;height:{u(37)}px;margin-bottom:{u(4)}px">{b}{ex}</div>'
body=''
body+=at(u(14),u(42),''.join(slot(g,q,il,('<span class=abs style="inset:0;border-radius:6px;background:rgba(255,40,40,.28)"></span>' if i==7 else '')) for i,(g,q,il) in enumerate(zip(L,QL,IL))))
body+=at(u(287),u(42),''.join(slot(g,q,il) for g,q,il in zip(R,QR,IR)))
body+=model(u(60),u(40),u(220),u(300),'Character model · drag to rotate, wheel to zoom (Blizzard)')
body+=at(u(60),u(14),f'<div style="width:{u(220)}px;text-align:center" class="tx2">Level 90 <span style="color:#00ff98">Mistweaver Monk</span></div>')
body+=at(u(110),u(348),'<div style="display:flex;gap:10px">'+slot('wizard_staff','leg',678)+slot('magic_swirl','epic',675)+'</div>')
# flyout from a slot (Blizzard popout)
body+=at(u(14)+u(37)+8,u(42)+u(41)*2,'<div class="card" style="padding:5px;display:flex;gap:4px;box-shadow:0 8px 20px #000">'+''.join(ic('shield',c,u(30),q) for c,q in [('#5a3a90','epic'),('#2a4a7a','rare'),('#2a4a7a','rare')])+'<span class="mut" style="font-size:9.5px;align-self:center;margin-left:4px">Alt · slot flyout</span></div>',z=30)
# stats pane (sidebar) x 338..540
sx=u(340)
side_tabs='<div style="display:flex;gap:6px;margin-bottom:8px">'+''.join(f'<span class="ic" style="width:34px;height:34px;display:grid;place-items:center;border:1px solid {"var(--acc)" if i==0 else "var(--line2)"};background:var(--bg2)"><img src="{A}Icons__{g}.png" style="width:20px;filter:{"none" if i==0 else "opacity(.6)"}"></span>' for i,g in enumerate(['stars_stack','crown','gears']))+'<span class="mut" style="font-size:10px;align-self:center">Stats · Titles · Equipment Manager</span></div>'
st=''.join(f'<div class="kv"><span class="tx2">{a}</span><span>{b}</span></div>' for a,b in [('Health','4,812,330'),('Mana','250,000'),('Intellect','41,208'),('Stamina','192,501'),('Armor','18,240')])
en=''.join(f'<div class="kv"><span class="tx2">{a}</span><span>{b}</span></div>' for a,b in [('Critical Strike','28.6%'),('Haste','31.2%'),('Mastery','44.1%'),('Versatility','9.8%/4.9%'),('Leech','3.1%'),('Speed','6.0%')])
pane=f'<div style="width:{u(190)}px">{side_tabs}<div class="card" style="padding:8px 10px;text-align:center;margin-bottom:6px"><div class="lbl">Item level</div><div style="font:700 24px Rajdhani;color:#a335ee">675.4 <span class="mut" style="font-size:13px">/ 678</span></div></div><div class="lbl" style="margin:6px 0 3px">Attributes</div>{st}<div class="lbl" style="margin:8px 0 3px">Enhancements</div>{en}'+px('<div class="card" style="padding:6px 8px;margin-top:8px;font-size:10.5px"><span class="err">1 missing enchant · 1 empty socket</span><br><span class="tx2">Durability 86% · repair</span> '+money(214,30)+'</div>',False)+'</div>'
body+=at(sx,u(10),pane)
body+=at(u(318),u(180),'<span class="btn" style="height:24px;width:22px;padding:0" title="collapse">‹</span>')
w=bwin(X,Y,u(540),u(424),'Abdulrahman',body,icon='Icons__Modules__64__unitframes',btabs=['Character','Reputation','Currency'])
fl=fly(X+u(540)+14,Y,'Character',[('Item level on slots','<span class="tg on"></span>'),('Enchant/gem flags','<span class="tg on"></span>'),('Durability tint','<span class="tg on"></span>'),('Stat %','<span class="tg on"></span>'),('Model light','<span class="dd" style="width:80px;height:20px">Ember</span>'),('Theme','<span class="dd" style="width:80px;height:20px">Ember</span>')])
# Reputation + currency tab thumbnails (Blizzard layout, smaller)
rp=''.join(f'<div class="row {"alt" if i%2 else ""}" style="height:26px;padding:3px 6px"><span style="width:12px" class="mut">{"▾" if h else ""}</span><span style="width:118px;font-size:10.5px;font-weight:{700 if h else 500};{"color:var(--gold)" if h else ""}">{n}</span><div style="flex:1">{"" if h else bar(p,c,9)}</div>{"<span class=gold style=margin-left:4px>◈</span>" if i==3 else ""}</div>' for i,(n,p,c,h) in enumerate([('The War Within',0,'',1),('Council of Dornogal',72,'#5AB4FF',0),('Assembly of the Deeps',40,'#3DDC97',0),('Hallowfall Arathi',100,'#F4C46A',0),('Guild',0,'',1),('Phoenix',60,'#3DDC97',0)]))
rph='<div style="padding:8px 10px"><div style="display:flex;gap:6px;margin-bottom:6px"><div class="dd" style="width:120px;height:22px">All</div></div>'+rp+'<div class="card" style="margin-top:6px;padding:6px 8px;font-size:10px"><b>Hallowfall Arathi</b><br><span class="ck on"></span> Watch <span class="ck"></span> At war <span class="ck"></span> Inactive '+btn('View Renown')+'</div></div>'
w2=bwin(X+u(540)+14,Y+232,316,270,'Reputation',rph,icon='Icons__Modules__64__general',cog=False,portrait=False,z=11,sub='tab')
cu=''.join(f'<div class="row {"alt" if i%2 else ""}" style="height:26px;padding:3px 6px">{ic(g,"#2a4a7a",18) if g else ""}<span style="flex:1;{"color:var(--gold);font-weight:700" if not g else ""}">{n}</span><span class="money">{v}</span></div>' for i,(g,n,v) in enumerate([(None,'Dungeon and Raid',''),('stars_stack','Gilded Crest','38'),('diamond_hard','Valorstones','1,812'),(None,'Player vs. Player',''),('trophy_cup','Honor','12,440')]))
cuh='<div style="padding:8px 10px"><div style="display:flex;gap:6px;margin-bottom:6px"><div class="dd" style="width:120px;height:22px">All currencies</div>'+btn('Transfer')+btn('Log','g')+'</div>'+cu+'</div>'
w3=bwin(X+u(540)+14,Y+520,316,200,'Currency',cuh,icon='Icons__Modules__64__databars',cog=False,portrait=False,z=11,sub='tab')

ty=Y+u(424)+44
tl='<div style="padding:8px 10px"><div class="srch" style="height:24px;margin-bottom:6px">⌕ Search titles</div>'+''.join(f'<div class="row {"hl" if i==1 else ("alt" if i%2 else "")}" style="height:22px;padding:2px 6px">{t}</div>' for i,t in enumerate(['No title','the Ashbringer','Keystone Hero','Gladiator']))+'</div>'
w4=bwin(X,ty,300,170,'Titles',tl,cog=False,portrait=False,z=11,sub='sidebar tab 2')
em='<div style="padding:8px 10px;display:flex;gap:10px"><div style="flex:1">'+''.join(f'<div class="row {"hl" if i==0 else "alt"}" style="height:26px;padding:2px 6px;margin-bottom:3px">{ic(None if g.startswith("ab_") else g,"#5a3a90",18,img=(A+"Icons__Abilities__"+g+"_64.png") if g.startswith("ab_") else None)}<span style="flex:1">{n}</span>{"<span class=mut>⚙</span>" if i==0 else ""}</div>' for i,(g,n) in enumerate([("ab_vivify","Raid ST"),("crossed_swords","M+ AoE"),("shield","Arena")]))+'<div class=row style="height:26px;padding:2px 6px;color:var(--acc)">+ New Set</div></div><div style="display:flex;flex-direction:column;gap:6px">'+btn('Equip','p')+btn('Save')+btn('Delete','d')+'</div></div>'
w5=bwin(X+316,ty,360,170,'Equipment Manager',em,cog=False,portrait=False,z=11,sub='sidebar tab 3 · icon picker on ⚙')
page2('01_character','Blizzard CharacterFrame layout (expanded) · Ember theme · Phoenix extras marked ◆',w+fl+w2+w3+w4+w5)
