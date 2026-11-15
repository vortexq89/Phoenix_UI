from sk2 import *
X,Y,W,H=40,96,560,640
sc={'on':'#3DDC97','afk':'#FFC24B','dnd':'#FF5468','off':'#4a4d57'}
cls={'Warrior':'warrior','Paladin':'paladin','Warlock':'warlock','Death Knight':'deathknight','Monk':'monk'}
fr=[('Vex','#c69b6d','Warrior','Silvermoon · M+ +16','on','H'),('Lumi','#f48cba','Paladin','Arena 3v3','afk','A'),('Nyx','#8788ee','Warlock','Dornogal','dnd','H'),('Kael#2211','#9ab8e8','','Battle.net app','on',''),('Torr','#c41e3a','Death Knight','Valdrakken','on','A'),('Ishaq','#00ff98','Monk','Offline · 2 days','off','')]
def fr_row(i,r):
    n,col,c,loc,st,fc=r
    tint=f'background:linear-gradient(90deg,{"rgba(200,36,61,.14)" if fc=="H" else ("rgba(90,140,255,.14)" if fc=="A" else "transparent")},transparent 55%);'
    left=px(ic(None,'#000',30,img=A+"Icons__Classes__"+cls[c]+".png",rad=15)) if c in cls else ic('chat_bubble','#2a4a7a',30,rad=15)
    return f'<div class="row {"alt" if i%2 else ""}" style="height:46px;padding:3px 6px;{tint}{"opacity:.5" if st=="off" else ""}">{left}<div style="flex:1"><div style="font-weight:600;color:{col}">{n}</div><div class="mut" style="font-size:10px">{loc}</div></div>'+px(f'<span style="width:9px;height:9px;border-radius:50%;background:{sc[st]};display:inline-block"></span>')+f'<span class="btn" style="height:24px;width:26px;padding:0" title="travel pass invite">+</span>'+('<span class="btn" style="height:24px;padding:0 6px;font-size:10px">Summon</span>' if i==0 and c=="Warrior" else '')+'</div>'
b=at(56,6,'<div style="display:flex;gap:8px;align-items:center;width:480px"><div class="dd" style="width:120px">🟢 Available</div><div class="srch" style="flex:1;height:26px;color:var(--tx2)">Broadcast: raiding tonight 20:30</div><span class="btn" style="width:28px;padding:0">☰</span></div>')
b+=at(10,44,'<div class="ttab"><span class="on">Friends</span><span>Recent Allies</span><span>Recruit-A-Friend</span></div>')
b+=at(10,80,'<div style="width:536px">'+px('<div class="srch" style="height:24px;margin-bottom:6px">⌕ Search friends, guild, recent</div>',False)+'<div class="lbl" style="margin:4px 0">Battle.net friends · 4 online</div>'+''.join(fr_row(i,r) for i,r in enumerate(fr[:4]))+'<div class="lbl" style="margin:6px 0 4px">WoW friends · 2</div>'+''.join(fr_row(i,r) for i,r in enumerate(fr[4:]))+'</div>')
b+=at(10,H-74,'<div style="display:flex;gap:8px;width:536px">'+btn('Add Friend','p')+btn('Send Message')+'</div>')
w=bwin(X,Y,W,H,'Abdulrahman#1234',b,icon='Icons__Modules__64__friends',btabs=['Friends','Who','Raid','Quick Join'],on=0)
who=''.join(f'<div class="row {"alt" if i%2 else ""}" style="height:24px;padding:2px 6px;font-size:10.5px"><span style="width:80px;color:{c};font-weight:600">{n}</span><span style="flex:1" class="tx2">{z}</span><span class="mut" style="width:24px">90</span><span style="width:60px;color:{c}">{k}</span></div>' for i,(n,c,z,k) in enumerate([('Aelin','#3FC7EB','Dornogal','Mage'),('Brakk','#C69B6D','Hallowfall','Warrior'),('Seri','#FFF468','Azj-Kahet','Rogue')]))
wb='<div style="padding:8px"><div class="row" style="height:22px;padding:0 6px;font-size:10px"><span class="lbl" style="width:80px">Name</span><span class="lbl" style="flex:1">Zone ▾</span><span class="lbl" style="width:24px">Lvl</span><span class="lbl" style="width:60px">Class</span></div>'+who+'<div class="srch" style="height:22px;margin:6px 0;color:var(--tx)">90 z-Dornogal</div>'+btn('Who','p')+btn('Add Friend')+btn('Group Invite')+'</div>'
w2=bwin(X+W+16,Y+232,330,200,'Who',wb,cog=False,portrait=False,z=11,sub='tab 2')
rb='<div style="padding:8px;font-size:10.5px"><div class="tx2">Not in a raid.</div><div style="margin:6px 0">'+btn('Raid Info')+btn('Convert to Raid')+'</div><span class="ck on"></span> Show raid frames · Restricted: raid lockouts list</div>'
w3=bwin(X+W+16,Y+446,330,110,'Raid',rb,cog=False,portrait=False,z=11,sub='tab 3')
qj='<div style="padding:8px">'+''.join(f'<div class="row alt" style="height:30px;padding:2px 6px;margin-bottom:3px;font-size:10.5px"><span style="flex:1">{t}</span></div>' for t in ['Vex · Liberation of Undermine HC','Lumi · +15 Stonevault'])+'<div style="text-align:right">'+btn('Join Queue','p')+'</div></div>'
w4=bwin(X+W+16,Y+570,330,140,'Quick Join',qj,cog=False,portrait=False,z=11,sub='tab 4')
tip=f'<div class="tip" style="left:{X+300}px;top:{Y+180}px;width:230px;z-index:40"><b style="color:#c69b6d">Vex</b> <span class="mut">Vex#2211</span><div class="tx2">World of Warcraft · Silvermoon</div><div class="tx2">In a group · M+ +16</div>'+px('<div class="mut" style="font-size:10px">Right-click → Copy BattleTag ◆</div>')+'</div>'
fl=fly(X+W+16,Y,'Friends',[('Class icons','<span class="tg on"></span>'),('Faction tint','<span class="tg on"></span>'),('Status orb','<span class="tg on"></span>'),('Auto-accept invites','<span class="tg"></span>')],'/pui → Friends')
page2('08_friends','Blizzard FriendsFrame · Friends tab with header tabs, Who, Raid, Quick Join · Ember',w+w2+w3+w4+tip+fl)
