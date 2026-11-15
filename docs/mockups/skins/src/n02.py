from sk2 import *
X,Y,W,H=40,96,1150,628
AB=['ab_vivify','ab_renew','ab_envelop','ab_essence','ab_lotus','ab_chiji','ab_tea','ab_kick','ab_roll','ab_fist','ab_shield','ab_cocoon']
NM=['Vivify','Renewing Mist','Enveloping Mist','Sheilun\'s Gift','Life Cocoon','Invoke Chi-Ji','Thunder Focus Tea','Spear Hand Strike','Roll','Rising Sun Kick','Fortifying Brew','Revival']
def sp(i,pas=False):
    g=AB[i%12]
    return f'<div style="display:flex;gap:8px;align-items:center;height:52px;{"opacity:.6" if pas else ""}">{ic(None,"#000",44,img=A+"Icons__Abilities__"+g+"_64.png",rad=22 if pas else 6)}<div><div style="font-weight:600;font-size:12px">{NM[i%12]}</div><div class="mut" style="font-size:10px">{"Passive" if pas else "Spell"}</div>'+(px('<div class="tx2" style="font-size:9.5px">Instant · 8.5s CD</div>') if i%3==0 else '')+'</div></div>'
def pagehalf(x,head,start):
    return at(x,70,f'<div style="width:500px"><div class="ph gold" style="margin-bottom:6px">{head}</div><div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:6px 10px">'+''.join(sp(start+i,pas=(start+i)%7==6) for i in range(15))+'</div></div>')
b=at(16,10,'<div class="ttab"><span class="on">Mistweaver</span><span>Monk</span><span>General</span><span>Pet</span></div>')
b+=at(W-470,8,'<div style="display:flex;gap:8px;align-items:center"><span class="ck on"></span><span class="tx2">Hide passives</span><div class="srch" style="width:240px;height:26px">⌕ Search spells</div><span class="btn" style="width:28px;padding:0">⚙</span><span class="btn g" style="width:28px;padding:0">?</span></div>')
b+=at(16,42,'<div class="card" style="padding:6px 10px;display:flex;gap:8px;align-items:center;width:420px">'+ic('eye_target','#1f6a5a',26)+'<span style="font-weight:600">Assisted Combat</span><span class="mut" style="font-size:10px">rotation highlight · drag to bar</span></div>')
b+=pagehalf(20,'Mistweaver',0)+pagehalf(590,'Mistweaver (cont.)',15)
b+='<div class="abs" style="left:575px;top:60px;bottom:50px;width:1px;background:var(--line)"></div>'
b+=at(W-220,H-74,'<div style="display:flex;gap:8px;align-items:center"><span class="mut">Page 1 / 3</span>'+btn('‹')+btn('›')+'</div>')
b+=at(16,H-74,'<span class="mut" style="font-size:10.5px">Drag a spell to an action bar · Shift-click to link · right-click for options</span>')
tip=f'<div class="tip" style="left:{X+380}px;top:{Y+250}px;width:290px;z-index:50"><b style="font-size:13px">Enveloping Mist</b><div class="mut">2 sec cast · 40 yd</div><div>Wraps the target in healing mists…</div>'+px('<div class="mut" style="font:500 10px JBM">SpellID 124682</div>')+'</div>'
w=bwin(X,Y,W,H,'Spellbook',b,icon='Icons__Modules__64__wisdom',btabs=['Specialization','Talents','Spellbook'],on=2)
w+=at(X+W-64,Y+4,'<span class="btn g" style="height:22px;width:22px;padding:0">⤢</span>',z=12)
fl=fly(X+W-260,Y+34,'Spellbook',[('Cast/CD line','<span class="tg on"></span>'),('Card size','<span class="dd" style="width:80px;height:20px">Normal</span>'),('IDs on Shift','<span class="tg on"></span>'),('Theme','<span class="dd" style="width:80px;height:20px">Ember</span>')])
page2('02_spellbook','Blizzard PlayerSpellsFrame · Spellbook tab layout · Ember',w+tip+fl)
