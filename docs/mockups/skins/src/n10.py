from sk2 import *
from common import GL,CL
import random; random.seed(7)
QS=['common','unc','rare','epic','common','unc','rare','poor','leg']
def slots(n,cols,sz=34,gap=4,empty=0.15):
    h=f'<div style="display:grid;grid-template-columns:repeat({cols},{sz}px);gap:{gap}px">'
    for i in range(n):
        if random.random()<empty: h+=f'<span style="width:{sz}px;height:{sz}px;border-radius:6px;background:var(--bg0);border:1px solid var(--line);display:inline-block"></span>'
        else: h+=ic(random.choice(GL+['potion_ball','health_potion','gold_bar','anvil']),random.choice(CL),sz,q=random.choice(QS),n=random.choice(['','','5','20']))
    return h+'</div>'
X,Y=40,96
cb='<div style="padding:8px 10px"><div style="display:flex;gap:6px;margin-bottom:8px"><div class="srch" style="flex:1;height:26px">⌕ Search</div><span class="btn" style="width:30px;padding:0">⇅</span></div>'+slots(64,10)+'<div style="display:flex;justify-content:space-between;align-items:center;margin-top:8px">'+''.join(ic(g,'#5a3a90',20) for g in ['stars_stack','diamond_hard','trophy_cup'])+'<span class="mut" style="font-size:10px">watched currencies</span><span style="margin-left:auto">'+money(284512,40,12)+'</span></div></div>'
w=bwin(X,Y,410,420,'Combined Backpack',cb,icon='Icons__Modules__64__vault')
menu=at(X+60,Y+120,'<div class="card" style="background:var(--bg1);width:200px;padding:8px;box-shadow:0 10px 26px #000;font-size:11px"><div class="lbl">Assign to</div>'+''.join(f'<div><span class="ck {"on" if i==1 else ""}"></span> {t}</div>' for i,t in enumerate(['Equipment','Consumables','Profession goods','Reagents','Junk']))+'<div class="lbl" style="margin-top:6px">Other</div><div><span class="ck"></span> Ignore clean up</div><div><span class="ck on"></span> Show junk</div></div>',z=30)
bk='<div style="padding:8px 10px"><div style="display:flex;gap:6px;margin-bottom:8px"><div class="srch" style="width:260px;height:26px">⌕ Search bank</div><span class="btn" style="width:30px;padding:0">⇅</span><span class="btn">Deposit settings ▾</span><span style="margin-left:auto">'+btn('Deposit All Reagents')+'</span></div>'+slots(98,14,32,3,0.25)+'<div style="display:flex;gap:8px;align-items:center;margin-top:8px"><span class="ck on"></span><span class="tx2">Include reagents</span><span style="margin-left:auto">'+btn('Deposit')+btn('Withdraw')+'</span>'+money(52000)+'</div></div>'
w2=bwin(X+426,Y,600,362,'Warband Bank',bk,icon='Icons__Modules__64__vault',btabs=['Bank','Warband'],on=1)
w2+=at(X+426+600,Y+40,'<div class="rtab">'+''.join(f'<span class="{"on" if i==0 else ""}">{ic(g,"#2a4a7a",28)}</span>' for i,g in enumerate(['backpack','gold_bar','potion_ball','anvil','scroll_unfurled']))+'<span style="font-size:18px;color:var(--acc)">+</span></div>',z=12)
w2+=at(X+426+460,Y+372,'<div class="card" style="width:150px;padding:6px;font-size:10px;box-shadow:0 8px 20px #000"><b>Tab settings</b><div class="srch" style="height:20px;margin:4px 0;color:var(--tx)">Raid mats</div><span class="mut">Icon · deposit filters</span></div>',z=13)
gb='<div style="padding:8px 10px">'+slots(49,14,30,3,0.3)+'<div style="display:flex;gap:6px;margin-top:8px">'+btn('Deposit')+btn('Withdraw')+'<span class="mut" style="margin-left:auto;font-size:10px">Remaining today: 40 · '+money(1200000)+'</span></div></div>'
w3=bwin(X,Y+470,560,240,'Guild Bank',gb,icon='Icons__Modules__64__vault',btabs=['Guild Bank','Log','Money Log','Info'],on=0,z=11)
w3+=at(X+560,Y+510,'<div class="rtab">'+''.join(f'<span class="{"on" if i==0 else ""}">{ic(g,"#5a3a90",26)}</span>' for i,g in enumerate(['flame','potion_ball','anvil','crown']))+'</div>',z=12)
va=at(X+640,Y+560,'<div class="card" style="width:400px;padding:10px 12px">'+px('<div><b class="acc">Phoenix Vault (optional)</b><div class="tx2" style="font-size:11px;margin-top:4px">When the Vault module is on it replaces these bag windows with one Phoenix window (category / grid / list, junk overlay, new items, gold history), using the same Blizzard secure item buttons. With Vault off, the Blizzard layout above is skinned.</div></div>',False)+'</div>')
fl=fly(X+426+200,Y+372,'Bags & bank',[('Quality borders','<span class="tg on"></span>'),('Junk overlay','<span class="tg on"></span>'),('Slot size','<span class="dd" style="width:70px;height:20px">34</span>'),('Use Vault','<span class="tg"></span>')],'/pui → Vault')
page2('10_bags_bank','Blizzard combined bags, BankFrame (Bank / Warband), GuildBankFrame · Ember',w+menu+w2+w3+va+fl)
