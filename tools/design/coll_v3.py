from kit import *
from PIL import Image as _I, ImageDraw as _D, ImageFilter as _F
W_,H_=1500,900; c=Canvas(W_,H_)
for i in range(H_*S):
    t=i/(H_*S); c.d.line([(0,i),(W_*S,i)],fill=(int(30*(1-t)+12*t),int(18*(1-t)+10*t),int(26*(1-t)+14*t)))
X,Y,WW,HH=130,70,1240,740
c.shadow(X,Y,WW,HH); c.R(X,Y,WW,HH,fill=C['base'],r=8,outline=C['border'])
c.R(X+1,Y+1,WW-2,44,fill=C['raised'],r=8); c.R(X+1,Y+30,WW-2,15,fill=C['raised']); c.L(X,Y+45,X+WW,Y+45,C['borderS'])
c.glyph(X+14,Y+13,'content',C['acc'],18); c.T(X+40,Y+23,'Collections',15,'SemiBold',anchor='lm')
c.glyph(X+WW-30,Y+14,'close',C['t2'],16); c.glyph(X+WW-56,Y+14,'move',C['t3'],16)
tx=X+16; ty=Y+56
for i,(t,n) in enumerate([('Mounts','612'),('Pets','1,104'),('Toys','498'),('Heirlooms','131'),('Appearances','18,420'),('Campsites','12')]):
    w=c.tw(t,13,'Medium')+c.tw(n,11)+40; on=i==0
    c.T(tx+14,ty+14,t,13,'SemiBold' if on else 'Medium',C['t1'] if on else C['t2'],'lm')
    c.T(tx+20+c.tw(t,13,'Medium'),ty+14,n,11,'Medium',C['acc'] if on else C['t3'],'lm')
    if on: c.R(tx+8,ty+30,w-16,2,fill=C['acc'])
    tx+=w
c.L(X+16,ty+32,X+WW-16,ty+32,C['borderS'])
# list column
LX,LY,LW=X+16,ty+46,400
c.R(LX,LY,LW-80,30,fill=C['sunken'],r=4,outline=C['borderS']); c.glyph(LX+8,LY+7,'search',C['t3'],16); c.T(LX+30,LY+15,'Search mounts',13,fill=C['t3'],anchor='lm')
c.btn(LX+LW-72,LY+1,'Filter','secondary')
chips=['All','Collected','Flying','Ground','Aquatic','Favorites']; cx=LX
for i,ch in enumerate(chips):
    w=c.tw(ch,11,'Medium')+18; on=i==0; c.R(cx,LY+40,w,22,fill=soft(C['acc'],0.2,C['base']) if on else C['hover'],r=11); c.T(cx+w/2,LY+51,ch,11,'Medium',C['acc'] if on else C['t2'],'mm'); cx+=w+6
names=[('Ashes of Al\'ar','Drop: Kael\'thas Sunstrider',True,True),('Invincible','Drop: The Lich King (25H)',True,False),('Mimiron\'s Head','Drop: Yogg-Saron (25)',True,False),
 ('Armored Bloodwing','Achievement: Shadowlands',True,False),('Blue Wind Rider','Vendor: Thunder Bluff',True,False),('Swift Spectral Tiger','TCG',False,False),
 ('Reins of the Onyxian Drake','Drop: Onyxia',True,True),('Felsteel Annihilator','Achievement: Glory',False,False),('Sandstone Drake','Profession: Alchemy',True,False),('Astral Cloud Serpent','Drop: Elegon',True,False),('Grand Expedition Yak','Vendor: Kun-Lai Summit',True,False)]
ry=LY+74
for i,(n,src,have,fav) in enumerate(names):
    on=i==0; h=46
    if on: c.R(LX,ry,LW,h,fill=soft(C['acc'],0.12,C['base']),r=4); c.R(LX,ry+8,2,h-16,fill=C['acc'])
    elif i%2: c.R(LX,ry,LW,h,fill=(24,26,30),r=4)
    c.icon(LX+10,ry+7,32,i*13+2,r=4)
    if not have:
        ov=_I.new('RGBA',c.im.size,(0,0,0,0)); _D.Draw(ov).rectangle([(LX+10)*S,(ry+7)*S,(LX+42)*S,(ry+39)*S],fill=(16,18,21,170)); c.im.paste(ov,(0,0),ov); c.d=ImageDraw.Draw(c.im)
    c.T(LX+54,ry+15,n,13,'SemiBold' if on else 'Medium',C['t1'] if have else C['t3'],'lm'); c.T(LX+54,ry+32,src,11,fill=C['t3'],anchor='lm')
    if fav: c.glyph(LX+LW-26,ry+15,'heart',C['acc'],14)
    ry+=h+2
# scrollbar
c.R(LX+LW+6,LY+74,4,ry-LY-74,fill=C['hover'],r=2); c.R(LX+LW+6,LY+74,4,90,fill=C['t3'],r=2)
# detail
DX=LX+LW+28; DW=X+WW-16-DX; DY=LY
c.R(DX,DY,DW,370,fill=C['sunken'],r=6)
lay=_I.new('RGBA',c.im.size,(0,0,0,0)); ld=_D.Draw(lay)
ld.ellipse([(DX+DW/2-220)*S,(DY+40)*S,(DX+DW/2+220)*S,(DY+340)*S],fill=(255,110,30,110)); lay=lay.filter(_F.GaussianBlur(50*S)); c.im.paste(lay,(0,0),lay); c.d=ImageDraw.Draw(c.im)
# stylised phoenix mount silhouette
mx,my=DX+DW/2,DY+190
c.d.polygon([((mx-230)*S,(my-60)*S),((mx-60)*S,(my-10)*S),((mx-10)*S,(my-90)*S),((mx+20)*S,(my-30)*S),((mx+230)*S,(my-80)*S),((mx+60)*S,(my+30)*S),((mx+20)*S,(my+120)*S),((mx-20)*S,(my+40)*S)],fill=(255,150,60))
c.d.polygon([((mx-200)*S,(my-48)*S),((mx-60)*S,(my)*S),((mx-20)*S,(my+30)*S),((mx-140)*S,(my-10)*S)],fill=(255,200,110))
c.d.polygon([((mx+200)*S,(my-68)*S),((mx+60)*S,(my+15)*S),((mx+30)*S,(my+40)*S),((mx+150)*S,(my-20)*S)],fill=(255,200,110))
c.T(DX+16,DY+20,'3D model · drag to rotate',11,fill=C['t3'],anchor='lm')
c.R(DX+DW-120,DY+332,104,26,fill=C['raised'],r=13); c.T(DX+DW-68,DY+345,'Show rider',11,'Medium',C['t2'],'mm')
iy=DY+386
c.T(DX,iy+12,'Ashes of Al\'ar',22,'Bold'); c.badge(DX+c.tw("Ashes of Al'ar",22,'Bold')+12,iy+5,'COLLECTED',C['ok']); c.badge(DX+c.tw("Ashes of Al'ar",22,'Bold')+96,iy+5,'FLYING',C['info'])
c.T(DX,iy+42,'Al\'ar was the beloved pet of Kael\'thas Sunstrider, who often boasted that death would never claim it.',13,fill=C['t2'])
c.R(DX,iy+70,DW,62,fill=C['raised'],r=6,outline=C['borderS'])
for j,(k,v) in enumerate([('Source','Drop: Kael\'thas Sunstrider'),('Zone','The Eye, Tempest Keep'),('Speed','Skyriding · 310%')]):
    xx=DX+16+j*(DW//3); c.T(xx,iy+88,k.upper(),10,'SemiBold',C['t3'],'lm'); c.T(xx,iy+110,v,13,'Medium',C['t1'],'lm')
by=iy+148; bx=DX; bx+=c.btn(bx,by,'Summon','primary',36)+8; bx+=c.btn(bx,by,'Favorite','secondary',36,'heart')+8; c.btn(bx,by,'Link in chat','ghost',36)
c.L(X,Y+HH-34,X+WW,Y+HH-34,C['borderS']); c.T(X+16,Y+HH-17,'612 of 1,034 mounts collected · 59%',12,fill=C['t2'],anchor='lm')
c.R(X+300,Y+HH-20,200,6,fill=C['hover'],r=3); c.R(X+300,Y+HH-20,118,6,fill=C['acc'],r=3)
c.T(X+WW-16,Y+HH-17,'Window remembers its position · right-click title to reset',11,fill=C['t3'],anchor='rm')
c.save('/workspace/pui_restore/docs/screenshots/v3/collections_v3.png','Phoenix UI v3 mockup · Collections (Mounts) · schematic render, not in-game · icons and the model are placeholders for game art')
