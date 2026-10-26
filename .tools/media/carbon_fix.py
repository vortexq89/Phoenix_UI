# Carbon v2: real 2x2 twill weave (8px cells, alternating fibre direction) so it
# reads as carbon when tinted, clearly unlike Smooth's plain gradient.
import numpy as np
from PIL import Image
H,W=64,512; C=8
yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
cx=(xx//C).astype(int); cy=(yy//C).astype(int)
fx=(xx%C+.5)/C; fy=(yy%C+.5)/C
horiz=((cx+cy)%2==0)
along=np.where(horiz,fy,fx)            # position across the fibre bundle
v=.52+.38*np.sin(np.pi*along)**1.5     # rounded bundle
v*=np.where(horiz,1.0,.80)             # bundles facing light vs away
v*=.90+.10*np.cos(np.pi*np.where(horiz,fx,fy)*2)*0+.10  # flat along fibre
v*=(.92+.10*(1-(yy+.5)/H))             # gentle top light
a=np.zeros((H,W,4),np.float32); a[...,:3]=np.clip(v,0,1)[...,None]; a[...,3]=1
import sys
Image.fromarray((a*255).round().astype(np.uint8),"RGBA").save(sys.argv[1])
