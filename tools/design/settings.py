from kit import *
W_,H_=1900,1000; c=Canvas(W_,H_,(12,10,14))
# game-ish backdrop
for i in range(H_*S):
    t=i/(H_*S); c.d.line([(0,i),(W_*S,i)],fill=(int(40*(1-t)+14*t),int(16*(1-t)+10*t),int(22*(1-t)+16*t)))
X,Y,WW,HH=360,100,1180,780
c.shadow(X,Y,WW,HH,8,28,170)
c.R(X,Y,WW,HH,fill=C['base'],r=8,outline=C['border'])
# title bar
c.R(X+1,Y+1,WW-2,47,fill=C['raised'],r=8); c.R(X+1,Y+30,WW-2,18,fill=C['raised'])
c.L(X,Y+48,X+WW,Y+48,C['borderS'])
chrome(c,X+14,Y+13,'nav-phoenix',C['acc'],22); c.T(X+44,Y+24,'PHOENIX',15,'Bold',C['t1'],'lm'); c.badge(X+120,Y+16,'v3 · BETA',C['acc'])
c.R(X+400,Y+10,380,28,fill=C['sunken'],r=4,outline=C['borderS']); chrome(c,X+410,Y+16,'win-search',C['t3'],16); c.T(X+434,Y+24,'Search 2,472 settings',13,fill=C['t3'],anchor='lm'); c.T(X+760,Y+24,'Ctrl K',11,'Medium',C['t3'],'rm')
c.select(X+790,Y+10,150,'Profile: Default'); bx=X+950; bx+=c.btn(bx,Y+10,'Layout','secondary')+8; c.btn(bx,Y+10,'Test frames','secondary')
chrome(c,X+WW-32,Y+16,'win-close',C['t2'],16)
# rail
RY=Y+49; RH=HH-49-36
c.R(X+1,RY,64,RH,fill=C['sunken']); c.L(X+65,RY,X+65,RY+RH,C['borderS'])
items=[('nav-home','Home'),('nav-bars','Bars'),('nav-frames','Frames'),('nav-interface','Interface'),('nav-combat','Combat'),('nav-content','Content'),('nav-windows','Windows'),('nav-systems','Systems'),('nav-phoenix','Phoenix')]
for i,(g,l) in enumerate(items):
    yy=RY+10+i*60; on=g=='nav-bars'
    if on: c.R(X+6,yy,54,54,fill=soft(C['acc'],0.14,C['sunken']),r=6); c.R(X+1,yy+14,3,26,fill=C['acc'],r=1)
    col=C['acc'] if on else C['t2']; chrome(c,X+23,yy+9,g,col,20); c.T(X+33,yy+42,l,10,'SemiBold',C['t1'] if on else C['t3'],'mm')
# subnav
SX=X+66; c.R(SX,RY,200,RH,fill=C['base']); c.L(SX+200,RY,SX+200,RY+RH,C['borderS'])
c.T(SX+16,RY+22,'BARS',10,'SemiBold',C['t3'],'lm')
for i,(l,st) in enumerate([('Action Bars','on'),('Cooldown Manager','on'),('Cooldown Text','on'),('Stance & Pet','off'),('Extra Buttons','on')]):
    yy=RY+38+i*34; on=i==0
    if on: c.R(SX+8,yy,184,32,fill=soft(C['acc'],0.12,C['base']),r=4); c.R(SX+8,yy+6,2,20,fill=C['acc'])
    c.T(SX+22,yy+16,l,13,'SemiBold' if on else 'Regular',C['t1'] if on else C['t2'],'lm')
    c.d.ellipse([(SX+178)*S,(yy+13)*S,(SX+184)*S,(yy+19)*S],fill=C['ok'] if st=='on' else C['t3'])
# content
CX=SX+201; CW=X+WW-CX; cy=RY+20; m=24
c.T(CX+m,cy+2,'Action Bars',22,'Bold'); c.badge(CX+m+150,cy+6,'ENABLED',C['ok'])
c.T(CX+m,cy+44,"Phoenix's own secure bars: layout, paging, fading, shapes and keybind text.",13,fill=C['t2'],anchor='lm')
bx=CX+CW-m-36; c.toggle(bx,cy+2,True); c.btn(bx-100,cy-2,'Reset','ghost')
# tabs
ty=cy+64
tabs=[('Layout','tab-layout'),('Appearance','tab-appearance'),('Text','tab-text'),('Behaviour','tab-behaviour'),('Colours','tab-colours'),('Per bar','nav-bars')]
tx=CX+m
for i,(t,ic) in enumerate(tabs):
    w=c.tw(t,13,'Medium')+46; on=i==0
    chrome(c,tx+10,ty+6,ic,C['acc'] if on else C['t3'],16)
    c.T(tx+32,ty+14,t,13,'SemiBold' if on else 'Medium',C['t1'] if on else C['t2'],'lm')
    if on: c.R(tx+8,ty+30,w-16,2,fill=C['acc'])
    tx+=w
c.L(CX+m,ty+32,CX+CW-m,ty+32,C['borderS'])
# preview: fitted, real size
py=ty+48; pw=CW-2*m; ph=118
c.R(CX+m,py,pw,ph,fill=C['raised'],r=6,outline=C['borderS'])
c.T(CX+m+16,py+18,'PREVIEW',10,'SemiBold',C['t3'],'lm'); c.T(CX+m+80,py+18,'Bar 1 · real size (40 px)',11,fill=C['t3'],anchor='lm')
sx=CX+m+pw-16; 
for lab in ['Show in world','On cooldown','Empty slots']:
    w=c.tw(lab,11,'Medium')+18; sx-=w+6; c.R(sx,py+9,w,20,fill=C['hover'],r=10); c.T(sx+w/2,py+19,lab,11,'Medium',C['t2'],'mm')
stage=(CX+m+16,py+36,pw-32,ph-52); c.R(*stage,fill=C['sunken'],r=4)
n=12; bw=40;gap=2; tot=n*bw+(n-1)*gap; bx0=stage[0]+(stage[2]-tot)//2
for i in range(n):
    xx=bx0+i*(bw+gap); c.icon(xx,stage[1]+12,bw,i+3,r=3)
    c.R(xx,stage[1]+12,bw,bw,r=3,outline=(0,0,0))
    c.T(xx+bw-4,stage[1]+16,str((i+1)%10 if i<10 else ['-','='][i-10]),10,'SemiBold',C['t1'],'ra')
    if i in (2,7): c.R(xx,stage[1]+12,bw,bw,fill=None,r=3); c.T(xx+bw/2,stage[1]+32,'4',16,'Bold',C['t1'],'mm')
c.R(stage[0]+stage[2]-26,stage[1]+stage[3]-24,18,18,fill=C['raised'],r=3); chrome(c,stage[0]+stage[2]-23,stage[1]+stage[3]-21,'win-move',C['acc'],12)
# cards two columns
gy=py+ph+16; colw=(pw-16)//2
def card(x,y,w,title,rows):
    h=46+sum(r[0] for r in rows)+8
    c.R(x,y,w,h,fill=C['raised'],r=6,outline=C['borderS']); c.T(x+16,y+22,title,15,'SemiBold','#ECECEE','lm')
    c.L(x+16,y+40,x+w-16,y+40,C['borderS']); yy=y+50
    for hgt,fn in rows: fn(x,yy,w); yy+=hgt
    return h
def row(label,desc,ctl,badge=None):
    def f(x,y,w):
        c.T(x+16,y+4,label,13,'Medium',C['t1'])
        oy=y+22
        if badge: c.badge(x+16,oy,badge[0],badge[1]); oy+=20
        if desc: c.T(x+16,oy,desc,11,fill=C['t3'])
        ctl(x+int(w*0.6),y,int(w*0.4)-16)
    return ((58 if desc else 36)+(20 if badge else 0),f)
tg=lambda on: (lambda x,y,w: c.toggle(x+w-36,y+2,on))
sl=lambda v,t: (lambda x,y,w: c.slider(x,y,w-62,v,t))
se=lambda t: (lambda x,y,w: c.select(x,y-2,w,t))
h1=card(CX+m,gy,colw,'Bar 1 · size & grid',[row('Buttons','How many buttons this bar shows.',sl(1.0,'12')),row('Button size','Width and height in pixels.',sl(0.4,'40')),
 row('Rows','',sl(0.1,'1')),row('Spacing','Gap between buttons.',sl(0.15,'2')),row('Grow direction','',se('Right'))])
h2=card(CX+m+colw+16,gy,colw,'Behaviour',[row('Lock buttons','Shift-drag still picks up a spell.',tg(True)),row('Show empty slots','Keep the grid visible where no action is placed.',tg(False)),
 row('Click on key down','Casts on press instead of release.',tg(True)),row('Use Blizzard bars','Hand the bars back to the game.',tg(False),('RELOAD ON CHANGE',C['warn']))])
# footer
fy=Y+HH-36; c.L(X,fy,X+WW,fy,C['borderS'])
c.d.ellipse([(X+16)*S,(fy+15)*S,(X+22)*S,(fy+21)*S],fill=C['ok']); c.T(X+30,fy+18,'Changes save and apply instantly',12,fill=C['t2'],anchor='lm')
c.T(X+WW-220,fy+18,'Window scale',12,fill=C['t3'],anchor='rm'); c.slider(X+WW-210,fy+7,120,0.55,'100%')
# annotations
def note(x,y,t,tx,ty):
    w=c.tw(t,12,'Medium')+20
    if x>X: x=W_-12-w
    c.R(x,y,w,26,fill=(255,214,102),r=4); c.T(x+10,y+13,t,12,'Medium',(30,24,10),'lm'); c.L((x+w if tx>x else x), y+13, tx,ty,(255,214,102),1)
note(12,150,'Nav: Phoenix chrome icons, 10% tint when selected',X+40,RY+100)
note(12,290,'Sub-nav only when a group has 2+ pages',SX+10,RY+60)
note(1400,300,'Preview fitted, real size, only where useful',X+WW-30,py+40)
note(1400,460,'Badges on their own line, never truncating a label',X+WW-60,gy+260)
note(1400,170,'Tabs: Phoenix chrome icons + auto-width labels',X+WW-200,ty+14)
c.save('/workspace/pui_restore/docs/screenshots/v3/settings_v3.png','Phoenix UI v3 mockup (revised t148) · settings window (Phoenix\'s own GUI) with the chrome icon set · schematic render, not in-game · action icons are placeholders for game art')
