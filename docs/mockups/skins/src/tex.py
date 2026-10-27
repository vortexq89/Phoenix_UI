# Original procedural textures proposed for the Skins set (Phoenix UI original work). PNG for preview + TGA for the client.
import os, random, math
from PIL import Image, ImageDraw, ImageFilter
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','media','textures'); os.makedirs(OUT,exist_ok=True)
def save(im,n): im.save(f'{OUT}/{n}.png'); im.save(f'{OUT}/{n}.tga')
random.seed(11)
# 1 ember glass panel (256): vertical gradient + faint noise + top sheen
im=Image.new('RGBA',(256,256))
px=im.load()
for y in range(256):
    for x in range(256):
        t=y/255; n=random.randint(-3,3)
        r=int(24-10*t+n); g=int(26-11*t+n); b=int(34-14*t+n)
        px[x,y]=(max(r,0),max(g,0),max(b,0),246)
save(im,'Skin_Panel_EmberGlass')
# 2 title bar (256x32): ember wash fading down
im=Image.new('RGBA',(256,32)); d=ImageDraw.Draw(im)
for y in range(32): d.line([(0,y),(255,y)],fill=(255,122,26,int(26*(1-y/31))))
d.line([(0,0),(255,0)],fill=(255,150,70,200)); save(im,'Skin_TitleBar_Ember')
# 3 nine-slice border 64 (radius 10, 1px line + accent hairline top) - white so it can be tinted
im=Image.new('RGBA',(64,64),(0,0,0,0)); d=ImageDraw.Draw(im)
d.rounded_rectangle([0,0,63,63],10,outline=(255,255,255,255),width=1); save(im,'Skin_Border_R10_1px')
# 4 soft shadow 128
im=Image.new('RGBA',(128,128),(0,0,0,0)); d=ImageDraw.Draw(im); d.rounded_rectangle([24,24,103,103],12,fill=(0,0,0,200)); im=im.filter(ImageFilter.GaussianBlur(10)); save(im,'Skin_Shadow_Soft')
# 5 slot frame 64: rounded square outline + inner glow (white, tinted by quality)
im=Image.new('RGBA',(64,64),(0,0,0,0)); g=Image.new('RGBA',(64,64),(0,0,0,0)); dg=ImageDraw.Draw(g); dg.rounded_rectangle([3,3,60,60],8,outline=(255,255,255,160),width=4); g=g.filter(ImageFilter.GaussianBlur(3))
im.alpha_composite(g); ImageDraw.Draw(im).rounded_rectangle([1,1,62,62],8,outline=(255,255,255,255),width=2); save(im,'Skin_Slot_QualityFrame')
# 6 slot empty 64
im=Image.new('RGBA',(64,64),(0,0,0,0)); d=ImageDraw.Draw(im); d.rounded_rectangle([1,1,62,62],8,fill=(11,12,16,230),outline=(35,38,46,255),width=1); save(im,'Skin_Slot_Empty')
# 7 button states 128x32
def button(n,top,bot,line,glow=0,alpha=255):
    im=Image.new('RGBA',(128,32),(0,0,0,0)); m=Image.new('L',(128,32),0); ImageDraw.Draw(m).rounded_rectangle([0,0,127,31],6,fill=255)
    gr=Image.new('RGBA',(128,32)); dg=ImageDraw.Draw(gr)
    for y in range(32):
        t=y/31; dg.line([(0,y),(127,y)],fill=tuple(int(top[i]*(1-t)+bot[i]*t) for i in range(3))+(alpha,))
    im.paste(gr,(0,0),m); ImageDraw.Draw(im).rounded_rectangle([0,0,127,31],6,outline=line,width=1)
    if glow:
        g=Image.new('RGBA',(128,32),(0,0,0,0)); ImageDraw.Draw(g).rounded_rectangle([1,1,126,30],6,outline=(255,122,26,140),width=2); im.alpha_composite(g.filter(ImageFilter.GaussianBlur(1.5)))
    save(im,n)
button('Skin_Button_Primary',(255,138,48),(229,101,14),(255,154,74,255))
button('Skin_Button_Normal',(33,36,46),(26,28,36),(52,54,62,255))
button('Skin_Button_Hover',(40,43,54),(30,32,41),(255,122,26,255),glow=1)
button('Skin_Button_Pressed',(20,22,28),(28,30,38),(255,122,26,200))
button('Skin_Button_Disabled',(28,30,36),(24,26,32),(42,44,51,255),alpha=120)
button('Skin_Button_Danger',(60,22,28),(42,16,20),(122,42,53,255))
# 8 tab underline 64x4 accent gradient
im=Image.new('RGBA',(64,4)); d=ImageDraw.Draw(im)
for x in range(64): a=int(255*math.sin(math.pi*x/63)); d.line([(x,0),(x,3)],fill=(255,122,26,a))
save(im,'Skin_Tab_Underline')
# 9 hairline (256x1) for window top accent
im=Image.new('RGBA',(256,2))
for x in range(256):
    a=int(230*math.sin(math.pi*x/255)**0.7)
    for y in range(2): im.putpixel((x,y),(255,int(122+47*math.sin(math.pi*x/255)),26+int(50*math.sin(math.pi*x/255)),a if y==0 else a//3))
save(im,'Skin_Hairline_Ember')
# 10 scroll thumb 8x64
im=Image.new('RGBA',(8,64),(0,0,0,0)); ImageDraw.Draw(im).rounded_rectangle([0,0,7,63],3,fill=(74,77,87,255)); save(im,'Skin_Scroll_Thumb')
# 11 toast glow 256x64 (left ember wash)
im=Image.new('RGBA',(256,64),(0,0,0,0)); d=ImageDraw.Draw(im)
for x in range(256): d.line([(x,0),(x,63)],fill=(255,122,26,int(40*(1-x/255)**2)))
save(im,'Skin_Toast_Wash')
# 12 ember backdrop 512 (scene behind model frames): radial glow + soft vignette
im=Image.new('RGBA',(512,512)); px=im.load()
for y in range(512):
    for x in range(512):
        dx,dy=(x-256)/256,(y-360)/256; r=math.sqrt(dx*dx+dy*dy)
        e=max(0,1-r*1.4); v=max(0,1-math.sqrt(((x-256)/256)**2+((y-200)/300)**2))
        px[x,y]=(int(12+26*v+60*e*e),int(13+28*v+26*e*e),int(17+34*v+8*e*e),255)
save(im,'Skin_ModelBackdrop_Ember')
# 13 divider 256x8 with centre diamond
im=Image.new('RGBA',(256,8),(0,0,0,0)); d=ImageDraw.Draw(im)
for x in range(256): d.point((x,4),fill=(244,196,106,int(160*math.sin(math.pi*x/255))))
d.polygon([(128,0),(132,4),(128,8),(124,4)],fill=(255,122,26,255)); save(im,'Skin_Divider_Ember')
# 14 check / radio / toggle (white tintable)
im=Image.new('RGBA',(32,32),(0,0,0,0)); d=ImageDraw.Draw(im); d.rounded_rectangle([1,1,30,30],7,outline=(255,255,255,255),width=2); save(im,'Skin_Check_Box')
im=Image.new('RGBA',(32,32),(0,0,0,0)); d=ImageDraw.Draw(im); d.line([(8,16),(14,22),(24,10)],fill=(255,255,255,255),width=4); save(im,'Skin_Check_Mark')
im=Image.new('RGBA',(32,32),(0,0,0,0)); d=ImageDraw.Draw(im); d.ellipse([2,2,29,29],outline=(255,255,255,255),width=2); d.ellipse([10,10,21,21],fill=(255,255,255,255)); save(im,'Skin_Radio')
# 15 status orb 32
im=Image.new('RGBA',(32,32),(0,0,0,0)); g=Image.new('RGBA',(32,32),(0,0,0,0)); ImageDraw.Draw(g).ellipse([6,6,25,25],fill=(255,255,255,180)); g=g.filter(ImageFilter.GaussianBlur(3)); im.alpha_composite(g); ImageDraw.Draw(im).ellipse([10,10,21,21],fill=(255,255,255,255)); save(im,'Skin_StatusOrb')
print(len(os.listdir(OUT))//2)
