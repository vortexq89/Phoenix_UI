from sk2 import *
from common import GL,CL
X,Y,W,H=40,96,808,690
TABS=['Mounts','Pets','Toy Box','Heirlooms','Appearances','Campsites']
def head(t,extra=''): return at(170,6,f'<div style="display:flex;gap:10px;align-items:center;width:{W-200}px"><div style="flex:1">{bar(80,"#3DDC97",10)}<div class="mut" style="font-size:10px;margin-top:2px">{t}</div></div>{extra}<div class="srch" style="width:180px;height:26px">⌕ Search</div><span class="btn">Filter ▾</span></div>')
# Appearances (main) Blizzard Wardrobe: slot row top, weapon dropdown, 3x6 grid, paging
slots=''.join(ic(g,CL[i%8],34,q='epic' if i==3 else None) for i,g in enumerate(['visored_helm','shield','hood','heart_shield','scroll_unfurled','flag_objective','mailed_fist','fist','stars_stack','run','sprint','wizard_staff','magic_swirl']))
b=at(56,10,'<div class="ttab"><span class="on">Items</span><span>Sets</span></div>')
b+=head('Chest · 412 / 618 appearances')
b+=at(16,52,f'<div style="display:flex;gap:5px;align-items:center">{slots}<div class="dd" style="width:150px;margin-left:8px">Weapon: Staves</div></div>')
grid='<div style="display:grid;grid-template-columns:repeat(6,1fr);gap:10px;width:770px">'+''.join(f'<div class="card" style="height:150px;position:relative;{"border-color:var(--acc)" if i==2 else ""}"><div class="model" style="inset:6px;border:0"><div class="fig" style="width:50%"></div></div>'+(px(f'<span class="chip" style="position:absolute;right:4px;top:4px">{"✓" if i%4!=3 else "✕"}</span>') if i<6 else '')+'</div>' for i in range(18))+'</div>'
b+=at(16,100,grid)
b+=at(W-220,H-70,'<div style="display:flex;gap:8px;align-items:center"><span class="mut">Page 1 / 12</span>'+btn('‹')+btn('›')+'</div>')
b+=at(16,H-70,'<span class="btn">◎ Track appearance</span>')
w=bwin(X,Y,W,H,'Collections',b,icon='Icons__Modules__64__vault',btabs=TABS,on=4)
# toys / heirlooms / sets / campsites compact
toy='<div style="padding:8px"><div style="display:flex;gap:5px;margin-bottom:6px"><div class="srch" style="flex:1;height:22px">⌕</div><span class="btn" style="height:22px">Filter</span></div><div style="display:grid;grid-template-columns:repeat(6,1fr);gap:6px">'+''.join(ic(GL[i%16],CL[i%8],40,q='rare',dim=i in (4,9)) for i in range(18))+f'</div><div style="display:flex;justify-content:space-between;margin-top:6px"><span style="width:160px">{bar(81,"#3DDC97",8)}</span><span class="mut">1/9 ‹ ›</span></div></div>'
w2=bwin(X+W+16,Y+232,330,250,'Toy Box',toy,cog=False,portrait=False,z=11,sub='18 / page')
hl='<div style="padding:8px"><div style="display:flex;gap:5px;margin-bottom:6px"><div class="dd" style="width:110px;height:22px">Monk</div><div class="srch" style="flex:1;height:22px">⌕</div></div><div style="display:grid;grid-template-columns:repeat(6,1fr);gap:6px">'+''.join(f'<div style="position:relative">{ic(GL[i+3],CL[i%8],40,q="heir")}'+(px(f'<span style="position:absolute;left:2px;bottom:0;font:700 9px Inter;color:#00ccff">{i%4+1}/4</span>') if i<4 else '')+'</div>' for i in range(12))+'</div></div>'
w3=bwin(X+W+16,Y+500,330,170,'Heirlooms',hl,cog=False,portrait=False,z=11,sub='class dropdown · upgrade level')
st=bwin(X,Y+H+44,560,150,'Sets',at(10,8,'<div style="display:flex;gap:10px;width:540px"><div style="width:200px">'+''.join(f'<div class="row {"hl" if i==0 else "alt"}" style="height:24px;padding:2px 6px;margin-bottom:2px;font-size:11px">{n}</div>' for i,n in enumerate(['Ember Raider (4/9)','Monastery Garb (9/9)','Gladiator\'s Silks (2/9)']))+'</div><div class="model" style="position:relative;width:120px;height:100px"></div><div><div class="dd" style="width:160px">Variant: Mythic</div><div class="mut" style="font-size:10px;margin-top:6px">Sets tab: list left, model + variant dropdown right</div></div></div>'),cog=False,portrait=False,z=11,sub='Appearances › Sets')
cp=bwin(X+576,Y+H+44,330,150,'Warband Campsites',at(10,8,'<div style="display:flex;gap:8px">'+''.join(f'<div class="card" style="width:96px;height:96px;padding:4px"><div class="model" style="position:relative;width:86px;height:64px"></div><div style="font-size:9.5px">{n}</div></div>' for n in ['Ember Camp','Ash Grove','Dawn Rise'])+'</div>'),cog=False,portrait=False,z=11,sub='tab 6')
fl=fly(X+W+16,Y,'Collections',[('Grey uncollected','<span class="tg on"></span>'),('Collected chips','<span class="tg on"></span>'),('Upgrade pips','<span class="tg on"></span>'),('Theme','<span class="dd" style="width:80px;height:20px">Ember</span>')])
page2('05_collections_toys_heirlooms_appearances','Blizzard CollectionsJournal · Appearances tab (+ Toys, Heirlooms, Sets, Campsites) · Ember',w+w2+w3+st+cp+fl)
