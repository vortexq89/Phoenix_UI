from sk2 import *
from common import GL,CL
X,Y,W,H=40,96,808,690
TABS=['Mounts','Pets','Toy Box','Heirlooms','Appearances','Campsites']
rows=''.join(f'<div class="row{" hl" if i==0 else (" alt" if i%2 else "")}" style="height:44px;padding:3px 6px;{"opacity:.45" if i in (5,7) else ""}">{ic(GL[i],CL[i%8],36)}<div style="flex:1"><div style="font-weight:600;font-size:11.5px;{"color:#ff8a98" if i==6 else ""}">{n}</div>'+(px('<div class="mut" style="font-size:9.5px">Drop · Ashen Spire</div>') if i<3 else '')+f'</div>{"<span class=gold>★</span>" if i in (0,2) else ""}</div>' for i,n in enumerate(['Emberwing Phoenix','Ashen Courser','Cinder Drake','Obsidian Wolf','Dawnfire Hawk','Spectral Stag','Storm Gryphon (unusable)','Molten Basilisk','Sand Strider','Iron Ram','Frost Wyrm','Coral Seahorse']))
b=at(56,8,'<div class="card" style="padding:4px 10px;display:inline-flex;gap:6px;align-items:baseline"><b style="font:700 18px Rajdhani">1,042</b><span class="mut">Mounts</span></div>')
b+=at(200,8,'<div style="display:flex;gap:6px">'+btn('⇅ Skyriding mode')+btn('Skyriding skills')+'</div>')
b+=at(W-208,4,'<div style="display:flex;gap:6px;align-items:center">'+ic('dragon_head','#a05010',36)+'<span class="tx2" style="font-size:10px;width:120px">Summon random favourite (drag to bar)</span></div>')
b+=at(10,52,'<div style="width:270px"><div style="display:flex;gap:6px;margin-bottom:6px"><div class="srch" style="flex:1;height:26px">⌕ Search</div><span class="btn">Filter ▾</span></div>'+rows+'</div>')
b+=at(292,52,'<div style="width:500px"><div class="ph" style="font-size:18px">Emberwing Phoenix</div><div class="mut" style="font-size:11px">Drop: Sovereign Pyre, Ashen Spire (Mythic)</div></div>')
b+=model(292,100,504,440,'Mount model · Blizzard ModelScene, Phoenix backdrop')
b+=at(300,550,'<div style="display:flex;gap:6px">'+btn('⟲')+btn('⟳')+'</div>')
b+=at(292,590,'<div style="display:flex;gap:10px;align-items:center;width:504px">'+ic('anvil','#2a4a7a',38,q='rare')+'<div><div style="font-size:11px">Mount equipment</div><div class="mut" style="font-size:10px"><span class="ck"></span> Suppress in this zone</div></div><span style="margin-left:auto">'+btn('Mount','p')+'</span></div>')
b+=at(W-36,8+4,'',)
w=bwin(X,Y,W,H,'Collections',b,icon='Icons__Modules__64__vault',btabs=TABS,on=0)
w+=at(X+W-90,Y+4,'<span class="btn g" style="height:22px;width:22px;padding:0">?</span>',z=12)
w+=at(X+W-262,Y+36,'<div style="width:42px;height:42px;border-radius:50%;border:2px solid #F4C46A;display:grid;place-items:center;font:700 13px Rajdhani;background:var(--bg1)">18k</div>',z=12)
# pets compact window
pl=''.join(f'<div class="row {"alt" if i%2 else ""}" style="height:30px;padding:2px 5px">{ic(GL[i+4],CL[i],22)}<span style="flex:1;font-size:11px">{n}</span><span class="mut" style="font-size:10px">25</span></div>' for i,n in enumerate(['Ember Whelp','Ashling','Cinder Moth','Glow Beetle']))
slots=''.join(f'<div class="card" style="padding:5px;display:flex;gap:5px;align-items:center;margin-bottom:4px">{ic(GL[i+4],CL[i],30)}<div style="flex:1"><div style="font-size:10.5px;font-weight:600">{n}</div>{bar(hp,"#3DDC97",5)}{bar(70,"#B07CFF",4)}</div>'+''.join(ic(None,"#000",18,img=A+"Icons__Abilities__"+a+"_64.png") for a in ['ab_kick','ab_fist','ab_shield'])+'</div>' for i,(n,hp) in enumerate([('Ember Whelp',100),('Ashling',64),('Cinder Moth',88)]))
pb='<div style="padding:8px"><div style="display:flex;gap:5px;margin-bottom:5px"><div class="srch" style="flex:1;height:24px">⌕ Search</div><span class="btn" style="height:24px">Filter</span></div><div style="display:flex;gap:8px"><div style="width:140px">'+pl+'<div style="margin-top:6px;display:flex;gap:4px">'+ic('heart_plus','#1f6a5a',28)+btn('Summon')+'</div></div><div style="flex:1">'+slots+'<div style="display:flex;gap:4px">'+btn('Find Battle','p')+btn('?','g')+'</div></div></div></div>'
w2=bwin(X+W+16,Y+232,330,330,'Pets',pb,cog=False,portrait=False,z=11,sub='tab 2 · 3 slots × 3 abilities')
fl=fly(X+W+16,Y,'Collections',[('Source line','<span class="tg on"></span>'),('Dim uncollected','<span class="tg on"></span>'),('Model light','<span class="dd" style="width:80px;height:20px">Ember</span>'),('Theme','<span class="dd" style="width:80px;height:20px">Ember</span>')])
page2('04_collections_mounts_pets','Blizzard CollectionsJournal · Mounts tab (+ Pets) · Ember',w+w2+fl)
