from sk2 import *
from common import GL,CL,lrow
def card(t,h,w=300,extra=''): return f'<div class="card" style="background:var(--bg1);width:{w}px;padding:8px 10px;box-shadow:0 8px 22px #000;font-size:11px;{extra}"><div class="lbl" style="margin-bottom:5px">{t}</div>{h}</div>'
def rows(l,cols=None): return ''.join(f'<div style="display:flex;justify-content:space-between;padding:3px 0;border-bottom:1px solid var(--line)">'+''.join(f'<span>{c}</span>' for c in r)+'</div>' for r in l)
def inp(t,w=200,h=22): return f'<div class="srch" style="width:{w}px;height:{h}px;color:var(--tx)">{t}</div>'
def dd(t,w=120): return f'<span class="dd" style="width:{w}px;height:22px">{t} ▾</span>'
def ck(t,on=False): return f'<span style="margin-right:8px"><span class="ck {"on" if on else ""}"></span> {t}</span>'
def rad(t,on=False): return f'<span style="margin-right:8px">{"◉" if on else "○"} {t}</span>'
X,Y=40,96
import sk as _sk
def bar(p,**k): return _sk.bar(p*100 if p<=1 else p,**k)
