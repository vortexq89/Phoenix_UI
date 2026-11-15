from sk import *
L=[('visored_helm','Helm','leg','Crown of the Emberwing',678),('pin','Neck','epic','Ashen Pendant',671),('shield','Shoulder','epic','Pauldrons of Cinder',675),('hood','Back','epic','Smouldering Cloak',671),('heart_shield','Chest','epic','Breastplate of Dawn',678),('scroll_unfurled','Shirt','common','—',0),('flag_objective','Tabard','rare','Phoenix Tabard',0),('mailed_fist','Wrist','epic','Bracers of Kindling',665)]
R=[('fist','Hands','epic','Grips of the Pyre',675),('stars_stack','Waist','epic','Cinderbelt',671),('run','Legs','leg','Legplates of Rebirth',678),('sprint','Feet','epic','Ember Treads',668),('fire_ring','Ring','epic','Band of Embers',671),('fire_ring','Ring','rare','Sealed Loop',658),('crystal_ball','Trinket','epic','Phoenix Heart',678),('hourglass','Trinket','epic','Sands of Ash',671)]
def slot(s,right=False):
    g,n,q,name,il=s
    t=f'<div style="{"text-align:right;" if right else ""}flex:1;min-width:0"><div style="font-weight:600;font-size:11.5px;color:{Q[q]};white-space:nowrap;overflow:hidden">{name}</div><div class="mut" style="font-size:10px">{n}{" · <b class=gold>"+str(il)+"</b>" if il else ""}{" · <span class=ok>Enchanted</span>" if il and il>670 else ""}</div></div>'
    i=ic(g,'#5a3a90' if q=='epic' else ('#a05010' if q=='leg' else '#2a4a7a'),38,q,'')
    return f'<div class="row" style="height:46px;padding:4px 6px">{t+i if right else i+t}</div>'
body=''
body+=at(12,10,''.join(slot(s) for s in L),232)
body+=at(626,10,''.join(slot(s,True) for s in R),232)
body+=model(254,14,362,292,'Character model · Blizzard ModelScene, Phoenix lighting backdrop')
body+=at(282,24,'<div style="text-align:center;width:306px"><div class="ph" style="font-size:20px">Abdulrahman</div><div class="mut">Level 90 · <span style="color:#00ff98">Mistweaver Monk</span> · &lt;Phoenix&gt;</div></div>')
body+=at(254,314,'<div style="display:flex;gap:8px;justify-content:center;width:362px">'+''.join(f'<div style="text-align:center">{ic(g,c,40,q)}<div class="mut" style="font-size:10px;margin-top:2px">{t}</div></div>' for g,c,q,t in [('wizard_staff','#a05010','leg','Main hand'),('magic_swirl','#5a3a90','epic','Off hand')])+'</div>')
stats=[('Item level','675.4','gold'),('Health','4,812,330',''),('Mana','250,000','info'),('Intellect','41,208',''),('Stamina','192,501',''),('Critical strike','28.6%',''),('Haste','31.2%',''),('Mastery','44.1%',''),('Versatility','9.8%',''),('Leech','3.1%','')]
st='<div class="card" style="padding:10px 12px"><div class="lbl" style="margin-bottom:6px">Attributes</div>'+''.join(f'<div class="kv"><span class="tx2">{a}</span><span class="{c}">{b}</span></div>' for a,b,c in stats)+'</div>'
st+='<div class="card" style="padding:10px 12px;margin-top:8px"><div class="lbl" style="margin-bottom:6px">Durability · repairs</div>'+bar(86,'#3DDC97',8)+'<div class="mut" style="font-size:10.5px;margin-top:5px">86% · repair cost '+money(214,30,0)+'</div></div>'
body+=at(872,10,st,250)
body+=at(12,392,'<div class="card" style="padding:8px 10px;width:604px;display:flex;gap:8px;align-items:center"><span class="lbl">Equipment sets</span>'+chips(['Raid ST','M+ AoE','Arena','PvP Shuffle'],(0,))+'<span style="margin-left:auto">'+btn('Equip','p')+' '+btn('Save')+'</span></div>')
body+=at(872,392,'<div class="card" style="padding:8px 10px;width:250px;display:flex;justify-content:space-between"><span class="lbl">Missing</span><span class="err" style="font-size:11px">1 enchant · 1 gem</span></div>')
w=win(28,72,1136,500,'Character','<div></div>'+body,icon='Icons__Modules__64__unitframes',sub='Abdulrahman · Silvermoon',tabs=['Character','Reputation','Currency'],active=0)
# inspect mini + reputation card preview
rep=''.join(f'<div class="row {"alt" if i%2 else ""}" style="height:34px"><span style="width:180px;font-weight:600">{n}</span><div style="flex:1">{bar(p,c,10)}</div><span class="mut" style="width:120px;text-align:right">{t}</span></div>' for i,(n,p,c,t) in enumerate([('Council of Dornogal',72,'#5AB4FF','Renown 18'),('The Assembly of the Deeps',40,'#3DDC97','Renown 11'),('Hallowfall Arathi',100,'#F4C46A','Renown 25 · max'),('The Severed Threads',55,'#B07CFF','Renown 14')]))
w2=win(28,588,560,250,'Reputation','<div style="padding:8px">'+rep+'</div>',icon='Icons__Modules__64__general',sub='tab preview',tabs=['All','Major factions','Warband'],z=11)
cur=''.join(f'<div class="row {"alt" if i%2 else ""}" style="height:34px">{ic(g,c,24)}<span style="flex:1;font-weight:600">{n}</span><span class="money">{v}</span></div>' for i,(g,c,n,v) in enumerate([('coins','#a07a20','Resonance Crystals','4,210'),('stars_stack','#5a3a90','Gilded Crest','38 / 90'),('diamond_hard','#2a4a7a','Valorstones','1,812 / 2,000'),('trophy_cup','#a05010','Honor','12,440')]))
w3=win(604,588,560,250,'Currency','<div style="padding:8px">'+cur+'</div>',icon='Icons__Modules__64__databars',sub='tab preview · Wallet-aware',tabs=['Character','Warband transfer'],z=11)
s=side('partial','Skins pack <b>character</b>: fades NineSlice/Bg/Portrait, flat Phoenix backdrop, tabs and close button. Slots, stats, model scene, sidebar tabs and reputation/currency rows still show Blizzard art.',
 ['Slot buttons: Phoenix 1px quality border, item name + ilvl + enchant/gem flags beside each slot','Stats panel as a Phoenix card; secondary stats with %','Model scene keeps Blizzard rendering; Phoenix lighting backdrop behind it','Reputation and currency tabs: Phoenix rows, bars in theme colours'],
 ['Slots are not protected, but <b>never reparent or move them</b>: hooksecurefunc("PaperDollItemSlotButton_Update") restyles textures only','Item level and enchant flags come from C_Item / tooltip data, never written into Blizzard tables','Defer the first skin pass out of combat (CombatQueue); revert exactly on toggle-off'],
 ['Skin on/off','Accent','Ilvl on slots','Enchant/gem warnings','Quality borders','Stat order','Model backdrop','Font size'])
page('01_character','Character panel','Skins · Ember theme · items, stats, model, reputation, currency',w+w2+w3+s)
