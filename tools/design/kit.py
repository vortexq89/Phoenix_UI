from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, random
S=2
FD='/workspace/pui_restore/Media/Fonts/'
DF='/workspace/pui_restore/tools/design/fonts/'   # t149 default UI font: Barlow Semi Condensed (OFL)
_f={}
def F(n,w='Regular'):
    k=(n,w)
    if k not in _f: _f[k]=ImageFont.truetype(DF+f'BarlowSemiCondensed-{w}.ttf',int(round(n*1.1*S)))
    return _f[k]
C=dict(base=(21,23,27),raised=(28,31,36),sunken=(16,18,21),hover=(36,39,45),border=(44,48,56),borderS=(36,39,46),
 t1=(235,236,238),t2=(173,176,182),t3=(122,126,134),acc=(255,112,32),acc2=(255,160,60),ok=(76,201,122),warn=(240,180,60),bad=(232,80,72),info=(90,160,255))
def soft(c,a=0.10,bg=None): bg=bg or C['raised']; return tuple(int(bg[i]*(1-a)+c[i]*a) for i in range(3))
class Canvas:
    def __init__(s,w,h,bg=(10,10,12)):
        s.w,s.h=w,h; s.im=Image.new('RGB',(w*S,h*S),bg); s.d=ImageDraw.Draw(s.im)
    def R(s,x,y,w,h,fill=None,r=0,outline=None,width=1):
        s.d.rounded_rectangle([x*S,y*S,(x+w)*S-1,(y+h)*S-1],radius=r*S,fill=fill,outline=outline,width=width*S if outline else 0)
    def T(s,x,y,t,size=13,w='Regular',fill=None,anchor='la'):
        s.d.text((x*S,y*S),t,font=F(size,w),fill=fill or C['t1'],anchor=anchor)
    def tw(s,t,size=13,w='Regular'): return s.d.textlength(t,font=F(size,w))/S
    def L(s,x1,y1,x2,y2,fill,width=1): s.d.line([x1*S,y1*S,x2*S,y2*S],fill=fill,width=width*S)
    def shadow(s,x,y,w,h,r=8,blur=24,a=150):
        sh=Image.new('L',s.im.size,0); ImageDraw.Draw(sh).rounded_rectangle([x*S,(y+6)*S,(x+w)*S,(y+h+6)*S],radius=r*S,fill=a)
        sh=sh.filter(ImageFilter.GaussianBlur(blur*S/2)); black=Image.new('RGB',s.im.size,(0,0,0)); s.im=Image.composite(black,s.im,sh); s.d=ImageDraw.Draw(s.im)
    def icon(s,x,y,sz,seed,r=4,quality=None):
        random.seed(seed); h=random.random()
        import colorsys
        c1=tuple(int(v*255) for v in colorsys.hsv_to_rgb(h,0.65,0.85)); c2=tuple(int(v*255) for v in colorsys.hsv_to_rgb((h+0.08)%1,0.8,0.35))
        g=Image.new('RGB',(sz*S,sz*S));gd=ImageDraw.Draw(g)
        for i in range(sz*S):
            t=i/(sz*S); gd.line([(0,i),(sz*S,i)],fill=tuple(int(c1[k]*(1-t)+c2[k]*t) for k in range(3)))
        for _ in range(3):
            cx,cy,rr=random.uniform(.2,.8)*sz*S,random.uniform(.2,.8)*sz*S,random.uniform(.1,.3)*sz*S
            gd.ellipse([cx-rr,cy-rr,cx+rr,cy+rr],fill=tuple(min(255,int(v*1.25)) for v in c1))
        m=Image.new('L',g.size,0); ImageDraw.Draw(m).rounded_rectangle([0,0,sz*S-1,sz*S-1],radius=r*S,fill=255)
        s.im.paste(g,(x*S,y*S),m)
        if quality: s.R(x,y,sz,sz,r=r,outline=quality)
    def glyph(s,x,y,kind,col,sz=16):
        d=s.d;X,Y,Z=x*S,y*S,sz*S;w=max(2,int(1.6*S))
        if kind=='home': d.line([X+Z*.15,Y+Z*.5,X+Z*.5,Y+Z*.15,X+Z*.85,Y+Z*.5],fill=col,width=w); d.rectangle([X+Z*.27,Y+Z*.48,X+Z*.73,Y+Z*.85],outline=col,width=w)
        elif kind=='bars': [d.rectangle([X+Z*(.12+i*.28),Y+Z*.3,X+Z*(.32+i*.28),Y+Z*.7],outline=col,width=w) for i in range(3)]
        elif kind=='frames': d.rectangle([X+Z*.1,Y+Z*.25,X+Z*.9,Y+Z*.45],outline=col,width=w); d.rectangle([X+Z*.1,Y+Z*.58,X+Z*.65,Y+Z*.75],outline=col,width=w)
        elif kind=='ui': d.rounded_rectangle([X+Z*.1,Y+Z*.15,X+Z*.9,Y+Z*.85],radius=3*S,outline=col,width=w); d.line([X+Z*.1,Y+Z*.35,X+Z*.9,Y+Z*.35],fill=col,width=w)
        elif kind=='combat': d.line([X+Z*.15,Y+Z*.85,X+Z*.85,Y+Z*.15],fill=col,width=w); d.line([X+Z*.15,Y+Z*.15,X+Z*.85,Y+Z*.85],fill=col,width=w)
        elif kind=='content': d.ellipse([X+Z*.15,Y+Z*.15,X+Z*.85,Y+Z*.85],outline=col,width=w); d.line([X+Z*.5,Y+Z*.3,X+Z*.5,Y+Z*.5,X+Z*.68,Y+Z*.62],fill=col,width=w)
        elif kind=='windows': d.rectangle([X+Z*.1,Y+Z*.2,X+Z*.7,Y+Z*.7],outline=col,width=w); d.rectangle([X+Z*.3,Y+Z*.4,X+Z*.9,Y+Z*.85],outline=col,width=w)
        elif kind=='plug': d.rectangle([X+Z*.25,Y+Z*.35,X+Z*.75,Y+Z*.7],outline=col,width=w); d.line([X+Z*.38,Y+Z*.15,X+Z*.38,Y+Z*.35],fill=col,width=w); d.line([X+Z*.62,Y+Z*.15,X+Z*.62,Y+Z*.35],fill=col,width=w); d.line([X+Z*.5,Y+Z*.7,X+Z*.5,Y+Z*.9],fill=col,width=w)
        elif kind=='phoenix': d.polygon([(X+Z*.5,Y+Z*.1),(X+Z*.85,Y+Z*.6),(X+Z*.5,Y+Z*.9),(X+Z*.15,Y+Z*.6)],outline=col,width=w)
        elif kind=='search': d.ellipse([X+Z*.12,Y+Z*.12,X+Z*.68,Y+Z*.68],outline=col,width=w); d.line([X+Z*.6,Y+Z*.6,X+Z*.9,Y+Z*.9],fill=col,width=w)
        elif kind=='close': d.line([X+Z*.25,Y+Z*.25,X+Z*.75,Y+Z*.75],fill=col,width=w); d.line([X+Z*.75,Y+Z*.25,X+Z*.25,Y+Z*.75],fill=col,width=w)
        elif kind=='chev': d.line([X+Z*.3,Y+Z*.4,X+Z*.5,Y+Z*.6,X+Z*.7,Y+Z*.4],fill=col,width=w)
        elif kind=='heart': d.ellipse([X+Z*.12,Y+Z*.2,X+Z*.52,Y+Z*.6],fill=col); d.ellipse([X+Z*.48,Y+Z*.2,X+Z*.88,Y+Z*.6],fill=col); d.polygon([(X+Z*.14,Y+Z*.48),(X+Z*.86,Y+Z*.48),(X+Z*.5,Y+Z*.9)],fill=col)
        elif kind=='move': d.line([X+Z*.5,Y+Z*.1,X+Z*.5,Y+Z*.9],fill=col,width=w); d.line([X+Z*.1,Y+Z*.5,X+Z*.9,Y+Z*.5],fill=col,width=w)
    def toggle(s,x,y,on=True):
        s.R(x,y,36,20,fill=C['acc'] if on else C['hover'],r=10); s.d.ellipse([(x+(18 if on else 2))*S,(y+2)*S,(x+(34 if on else 18))*S,(y+18)*S],fill=(255,255,255) if on else C['t2'])
    def slider(s,x,y,w,v,val):
        s.R(x,y+9,w,4,fill=C['hover'],r=2); s.R(x,y+9,int(w*v),4,fill=C['acc'],r=2)
        cx=x+int(w*v); s.d.ellipse([(cx-7)*S,(y+4)*S,(cx+7)*S,(y+18)*S],fill=(255,255,255))
        s.R(x+w+10,y,52,22,fill=C['sunken'],r=4,outline=C['borderS']); s.T(x+w+36,y+11,val,12,'Medium',C['t1'],'mm')
    def select(s,x,y,w,t):
        s.R(x,y,w,28,fill=C['sunken'],r=4,outline=C['borderS']); s.T(x+10,y+14,t,13,fill=C['t1'],anchor='lm'); s.glyph(x+w-22,y+6,'chev',C['t2'],16)
    def btn(s,x,y,t,kind='secondary',h=28,icon=None):
        w=int(s.tw(t,13,'SemiBold'))+24+(20 if icon else 0)
        if kind=='primary': s.R(x,y,w,h,fill=C['acc'],r=4); col=(20,12,6)
        elif kind=='ghost': col=C['t2']
        else: s.R(x,y,w,h,fill=C['hover'],r=4,outline=C['border']); col=C['t1']
        if icon: s.glyph(x+10,y+(h-14)//2,icon,col,14)
        s.T(x+w/2+(10 if icon else 0),y+h/2,t,13,'SemiBold',col,'mm'); return w
    def badge(s,x,y,t,col):
        w=int(s.tw(t,10,'SemiBold'))+12; s.R(x,y,w,16,fill=soft(col,0.18),r=3); s.T(x+w/2,y+8,t,10,'SemiBold',col,'mm'); return w
    def save(s,p,label=None):
        im=s.im.resize((s.w,s.h),Image.LANCZOS)
        if label:
            d=ImageDraw.Draw(im); d.text((12,s.h-20),label,font=ImageFont.truetype(DF+'BarlowSemiCondensed-Medium.ttf',13),fill=(150,150,150))
        im.save(p)

# Phoenix chrome icons v4 (tools/media/gen_chrome_color.py): full colour; the tint argument now picks the state
import sys as _sys
_sys.path.insert(0, '/workspace/pui_restore/tools/media')
from gen_chrome_color import render as _render
_ic = {}
def chrome(c, x, y, name, col=None, size=20, state=None):
    state = state or ('hover' if col == C['acc'] else 'normal')
    k = (name, size, state)
    if k not in _ic: _ic[k] = _render(name, int(size * S), state)
    im = _ic[k]; c.im.paste(im, (int(x * S), int(y * S)), im); c.d = ImageDraw.Draw(c.im)
def panel_icon(c, x, y, name, size=60):
    chrome(c, x, y, name, None, size, 'normal')
