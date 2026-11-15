from nu import *
ev={3:('🎃','Hallow\'s End'),9:('⚔','Raid 20:00'),12:('⚔','Raid 20:00'),16:('🏆','M+ night'),22:('🎉','Guild party'),27:('⚔','Raid')}
cells=''
for i in range(42):
    d=i-3
    ok=0<d<=31
    t=f'<div style="height:66px;border:1px solid {"var(--acc)" if d==27 else "var(--line)"};border-radius:4px;padding:3px;font-size:10px;background:{"color-mix(in srgb,var(--acc) 14%,var(--bg1))" if d==27 else ("var(--bg1)" if ok else "var(--bg0)")};{"" if ok else "opacity:.4"}"><b>{d if ok else ""}</b>'
    if d in ev: t+=f'<div style="font-size:9.5px">{ev[d][0]} {ev[d][1]}</div>'
    cells+=t+'</div>'
grid='<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;width:620px">'+''.join(f'<div class="lbl" style="text-align:center">{d}</div>' for d in ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'])+cells+'</div>'
b=at(70,8,'<div style="display:flex;align-items:center;gap:10px;width:560px">'+btn('‹')+'<b style="font-size:17px;font-family:Cinzel">October 2026</b>'+btn('›')+'<span style="margin-left:auto">'+dd('Filter',90)+'</span></div>')+at(16,50,grid)
w=bwin(X,Y,659,560,'Calendar',b,icon='Icons__Modules__64__vault')
cm=card('Day menu (right-click 22)','<div>Create Event</div><div>Create Guild Event</div><div>Create Community Event</div><div class="mut">Paste Event</div>',180)
ce=card('Create event','<div style="display:flex;gap:6px">'+inp('Title: Ashen Spire',180)+dd('Raid',80)+dd('Mythic',80)+'</div><div style="margin:5px 0">'+dd('Oct 22',80)+dd('20:00',70)+ck('Lock',False)+'</div><div class="srch" style="width:350px;height:40px;align-items:flex-start">Description…</div><div class="lbl" style="margin-top:5px">Invites</div>'+rows([('Thrall','Invited'),('Jaina','Accepted')])+'<div style="margin-top:5px">'+btn('Invite')+btn('Mass Invite')+btn('Create','pri')+'</div>',370)
ve=card('View event — Raid 20:00','<div>'+btn('Accept','pri')+btn('Tentative')+btn('Decline')+'</div>'+rows([('Baine','✓ Accepted'),('Anduin','? Tentative')])+'<div style="margin-top:4px">'+btn('Remove')+btn('Class totals ▸')+'</div>',370)
hl=card('Holiday / lockout',"<div>🎃 Hallow's End · Oct 18 – Nov 1</div><div>🔒 Ashen Spire (M) · resets Tue</div>",370)
fl=fly(X+676,Y,'Calendar',[('Event colours by type','<span class="tg on"></span>'),('Week start','<span class="dd" style="width:60px;height:20px">Sun</span>')])
page2('18_calendar','Blizzard CalendarFrame (month grid, create / view event) · Ember',w+at(X+430,Y+330,cm,z=14)+fl+at(X+676,Y+130,'<div style="display:flex;flex-direction:column;gap:8px">'+ce+ve+hl+'</div>',z=12))
