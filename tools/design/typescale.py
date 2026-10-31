from PIL import Image, ImageDraw, ImageFont
FD='/workspace/pui_restore/Media/Fonts/Inter-'
roles=[('title','Bold',20,'Action Bars',(235,236,238)),('heading','Bold',13,'LAYOUT · POSITION · BACKDROP',(173,176,182)),
 ('body','Medium',14,'Show empty slots  ·  Keep buttons square  ·  Grow direction',(235,236,238)),
 ('desc','Regular',12,'Keep the grid visible where no action is placed. Applies at once.',(122,126,134)),
 ('number','SemiBold',13,'1,920   24.10%   38.85%   676.4   12:47',(235,236,238)),
 ('small','Medium',12,'Shift-click to link · Right-click to reset · Ctrl K search',(173,176,182)),
 ('unit','SemiBold',12,'Kael\'thas Sunstrider   106,260 / 106,260   97%',(235,236,238)),
 ('combat','Bold',16,'-12,480   +3,210 Mana   CRIT! 48,920',(255,170,60))]
W,H=1200,60+len(roles)*58+40
im=Image.new('RGB',(W,H),(21,23,27)); d=ImageDraw.Draw(im)
d.text((24,18),'Phoenix UI v3 type scale — Inter (SIL OFL 1.1), one family for every role · 1:1 pixels at pixel-perfect UI scale',font=ImageFont.truetype(FD+'SemiBold.ttf',14),fill=(255,140,60))
y=60
for role,w,sz,t,col in roles:
    d.text((24,y+4),role,font=ImageFont.truetype(FD+'SemiBold.ttf',12),fill=(255,140,60))
    d.text((110,y+4),f'Inter {w} {sz}',font=ImageFont.truetype(FD+'Regular.ttf',11),fill=(122,126,134))
    f=ImageFont.truetype(FD+w+'.ttf',sz)
    if role=='combat':
        for dx in (-1,0,1):
            for dy in (-1,0,1): d.text((260+dx,y+dy),t,font=f,fill=(0,0,0))
    d.text((260,y),t,font=f,fill=col)
    d.line([(24,y+44),(W-24,y+44)],fill=(36,39,46))
    y+=58
d.text((24,H-28),'Brand wordmark only: Cinzel Bold. Blizzard windows: the same Inter faces through the font objects (General › Text › "Use theme fonts on Blizzard UI", on by default).',font=ImageFont.truetype(FD+'Regular.ttf',11),fill=(150,150,160))
im=im.resize((W*2,H*2),Image.NEAREST); im.save('/workspace/pui_restore/docs/screenshots/v3/type_scale.png')
