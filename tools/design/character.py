from kit import *
W_,H_=1500,900; c=Canvas(W_,H_)
for i in range(H_*S):
    t=i/(H_*S); c.d.line([(0,i),(W_*S,i)],fill=(int(34*(1-t)+12*t),int(18*(1-t)+10*t),int(26*(1-t)+14*t)))
X,Y,WW,HH=150,90,1100,640
c.shadow(X,Y,WW,HH); c.R(X,Y,WW,HH,fill=C['base'],r=8,outline=C['border'])
c.R(X+1,Y+1,WW-2,44,fill=C['raised'],r=8); c.R(X+1,Y+30,WW-2,15,fill=C['raised']); c.L(X,Y+45,X+WW,Y+45,C['borderS'])
c.glyph(X+14,Y+13,'frames',C['acc'],18); c.T(X+40,Y+23,'Character',15,'SemiBold',anchor='lm'); c.T(X+128,Y+23,'Bmr · Level 90 Warlock · Destruction',12,fill=C['t3'],anchor='lm')
c.glyph(X+WW-30,Y+14,'close',C['t2'],16); c.glyph(X+WW-56,Y+14,'move',C['t3'],16)
# tabs auto width
tx=X+16; ty=Y+56
for i,t in enumerate(['Character','Reputation','Currency','Titles','Equipment sets']):
    w=c.tw(t,13,'Medium')+28; on=i==0
    c.T(tx+14,ty+14,t,13,'SemiBold' if on else 'Medium',C['t1'] if on else C['t2'],'lm')
    if on: c.R(tx+8,ty+30,w-16,2,fill=C['acc'])
    tx+=w
c.L(X+16,ty+32,X+WW-16,ty+32,C['borderS'])
# paper doll
PX,PY=X+20,ty+48; SL=46; G=8
Lslots=['Head','Neck','Shoulder','Back','Chest','Shirt','Tabard','Wrist']; Rslots=['Hands','Waist','Legs','Feet','Ring','Ring','Trinket','Trinket']
qual=[(163,53,238),(0,112,221),(163,53,238),(163,53,238),(255,128,0),None,None,(163,53,238)]
ilv=['678','671','678','675','684','','','672']
MW=300
c.R(PX+SL+12,PY,MW,8*(SL+G)-G,fill=C['sunken'],r=6)
# model silhouette with rim light
mx=PX+SL+12+MW//2; my=PY+40
from PIL import Image as _I, ImageDraw as _D, ImageFilter as _F
lay=_I.new('RGBA',c.im.size,(0,0,0,0)); ld=_D.Draw(lay)
ld.ellipse([(mx-120)*S,(my+40)*S,(mx+120)*S,(my+300)*S],fill=(150,90,255,90))
lay=lay.filter(_F.GaussianBlur(40*S)); c.im.paste(lay,(0,0),lay); c.d=ImageDraw.Draw(c.im)
fig=[(0,0,22,'head')]
body=(54,40,90)
c.d.ellipse([(mx-20)*S,(my+30)*S,(mx+20)*S,(my+74)*S],fill=(72,56,110))
c.d.polygon([((mx-22)*S,(my+80)*S),((mx+22)*S,(my+80)*S),((mx+58)*S,(my+100)*S),((mx+64)*S,(my+200)*S),((mx+40)*S,(my+210)*S),
 ((mx+52)*S,(my+380)*S),((mx-52)*S,(my+380)*S),((mx-40)*S,(my+210)*S),((mx-64)*S,(my+200)*S),((mx-58)*S,(my+100)*S)],fill=(72,56,110))
c.d.polygon([((mx-58)*S,(my+100)*S),((mx-82)*S,(my+96)*S),((mx-74)*S,(my+120)*S)],fill=(120,90,170))
c.d.polygon([((mx+58)*S,(my+100)*S),((mx+82)*S,(my+96)*S),((mx+74)*S,(my+120)*S)],fill=(120,90,170))
c.d.line([(mx*S,(my+80)*S),(mx*S,(my+380)*S)],fill=(98,76,146),width=2*S)
c.d.ellipse([(mx-90)*S,(my+368)*S,(mx+90)*S,(my+392)*S],outline=(255,140,60),width=2*S)
c.T(mx,PY+16,'Player model · drag to rotate · scroll to zoom',11,fill=C['t3'],anchor='mm')
for i,n in enumerate(Lslots):
    y=PY+i*(SL+G)
    if qual[i]: c.icon(PX,y,SL,i*7+1,r=4,quality=qual[i]); c.R(PX+SL-30,y+SL-15,28,13,fill=(0,0,0),r=2); c.T(PX+SL-3,y+SL-9,ilv[i],10,'SemiBold',C['t1'],'rm')
    else: c.R(PX,y,SL,SL,fill=C['raised'],r=4,outline=C['border']); c.T(PX+SL/2,y+SL/2,n,9,'SemiBold',C['t3'],'mm')
rq=[(163,53,238),(163,53,238),(255,128,0),(163,53,238),(0,112,221),(163,53,238),(163,53,238),(255,128,0)]
for i,n in enumerate(Rslots):
    y=PY+i*(SL+G); x=PX+SL+12+MW+12
    c.icon(x,y,SL,i*11+5,r=4,quality=rq[i]); c.R(x+SL-30,y+SL-15,28,13,fill=(0,0,0),r=2); c.T(x+SL-3,y+SL-9,str(670+i),10,'SemiBold',C['t1'],'rm')
wy=PY+8*(SL+G)+8
for j in range(2): c.icon(mx-SL-6+j*(SL+12),wy,SL,90+j,r=4,quality=(255,128,0))
# stats
SX=PX+2*SL+MW+48; SW=X+WW-20-SX
c.R(SX,PY,SW,88,fill=C['raised'],r=6,outline=C['borderS'])
c.T(SX+16,PY+22,'ITEM LEVEL',10,'SemiBold',C['t3'],'lm'); c.T(SX+16,PY+56,'676.4',30,'Bold',(198,120,255),'lm'); c.T(SX+120,PY+62,'/ 678 equipped max',12,fill=C['t3'],anchor='lm')
c.T(SX+SW-16,PY+22,'Health 106,260',12,'Medium',C['ok'],'rm'); c.T(SX+SW-16,PY+42,'Mana 250,000',12,'Medium',C['info'],'rm')
def stat_card(y,title,rows,bars=False):
    h=44+len(rows)*(34 if bars else 28)+8
    c.R(SX,y,SW,h,fill=C['raised'],r=6,outline=C['borderS']); c.T(SX+16,y+22,title,13,'SemiBold',anchor='lm')
    yy=y+44
    for lab,val,frac,col in rows:
        c.T(SX+16,yy+8,lab,13,fill=C['t2'],anchor='lm'); c.T(SX+SW-16,yy+8,val,13,'SemiBold',C['t1'],'rm')
        if bars: c.R(SX+16,yy+20,SW-32,4,fill=C['hover'],r=2); c.R(SX+16,yy+20,int((SW-32)*frac),4,fill=col,r=2)
        yy+=34 if bars else 28
    return h
y2=PY+100
y2+=stat_card(y2,'Attributes',[('Intellect','16,480',0,None),('Stamina','151,800',0,None),('Armor','4,120',0,None)])+12
stat_card(y2,'Enhancements',[('Critical Strike','24.10%  ·  1,920',0.48,(240,96,80)),('Haste','18.42%  ·  1,310',0.37,(250,200,70)),('Mastery','38.85%  ·  1,540',0.6,(90,160,255)),('Versatility','6.20%  ·  640',0.15,(110,210,140)),('Leech','2.00%',0.05,(200,120,255))],True)
c.save('/workspace/pui_restore/docs/screenshots/v3/character_v3.png','Phoenix UI v3 mockup · character window · schematic render, not in-game · item icons and model are placeholders for game art')
