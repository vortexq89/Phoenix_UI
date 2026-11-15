# v2 kit: Blizzard window structure, Ember restyle, Phoenix extras marked (◆), cog flyout, theme variants.
from sk import *
import sk, re, os, subprocess
from feats import F
CSS2="""
.bw{position:absolute;border-radius:10px;background:linear-gradient(180deg,var(--w1),var(--w2));border:1px solid var(--line2);box-shadow:0 18px 50px rgba(0,0,0,.65),0 0 0 1px rgba(0,0,0,.7)}
.bw:before{content:'';position:absolute;left:0;right:0;top:0;height:1px;background:linear-gradient(90deg,transparent,var(--acc) 30%,var(--acc2) 50%,var(--acc) 70%,transparent)}
.bw .tbar{position:absolute;left:0;right:0;top:0;height:30px;border-bottom:1px solid var(--line);background:linear-gradient(180deg,color-mix(in srgb,var(--acc) 7%,transparent),transparent);border-radius:10px 10px 0 0}
.bw .ttl2{position:absolute;left:0;right:0;top:6px;text-align:center;font:700 15px Rajdhani;letter-spacing:.4px}
.bw .por{position:absolute;left:-14px;top:-14px;width:62px;height:62px;border-radius:14px;background:radial-gradient(circle at 35% 30%,color-mix(in srgb,var(--acc) 55%,#222),var(--bg1) 80%);border:1px solid var(--acc);box-shadow:0 0 16px color-mix(in srgb,var(--acc) 35%,transparent),0 6px 16px #000;display:grid;place-items:center;z-index:3}
.bw .por img{width:40px;height:40px}
.bw .cl{position:absolute;right:6px;top:4px;width:22px;height:22px;border-radius:6px;border:1px solid var(--line2);display:grid;place-items:center;color:var(--tx2);font-size:13px;background:var(--bg2)}
.bw .cog{position:absolute;right:32px;top:4px;width:22px;height:22px;border-radius:6px;border:1px solid var(--acc);display:grid;place-items:center;color:var(--acc);font-size:13px;background:color-mix(in srgb,var(--acc) 14%,var(--bg2))}
.btab{position:absolute;display:flex;gap:3px}
.btab span{padding:6px 12px 7px;font:600 11.5px Inter;color:var(--tx2);background:var(--bg2);border:1px solid var(--line2);border-top:0;border-radius:0 0 7px 7px}
.btab span.on{color:var(--tx);background:linear-gradient(0deg,color-mix(in srgb,var(--acc) 18%,var(--bg2)),var(--bg2));border-color:var(--acc);box-shadow:0 3px 10px color-mix(in srgb,var(--acc) 25%,transparent)}
.ttab{display:flex;gap:2px}.ttab span{padding:5px 11px;font:600 11px Inter;color:var(--tx2);border-bottom:2px solid transparent}.ttab span.on{color:var(--tx);border-color:var(--acc)}
.rtab{position:absolute;display:flex;flex-direction:column;gap:4px}.rtab span{width:38px;height:38px;border-radius:0 8px 8px 0;background:var(--bg2);border:1px solid var(--line2);border-left:0;display:grid;place-items:center}.rtab span.on{border-color:var(--acc);background:color-mix(in srgb,var(--acc) 16%,var(--bg2))}
.px{position:relative;outline:1px dashed var(--acc);outline-offset:2px;border-radius:5px}
.px:after{content:'◆';position:absolute;right:-7px;top:-8px;font-size:9px;color:var(--acc);text-shadow:0 0 4px #000}
.fly{position:absolute;z-index:60;width:230px;border-radius:9px;background:linear-gradient(180deg,var(--w1),var(--w2));border:1px solid var(--acc);box-shadow:0 14px 34px #000;padding:9px 10px;font-size:11px}
.fly h5{font:700 12px Rajdhani;letter-spacing:.5px;color:var(--acc);margin-bottom:5px;text-transform:uppercase}
.fly .kv{font-size:11px}
.lg{position:absolute;right:16px;top:64px;width:376px;z-index:20;display:flex;flex-direction:column;gap:8px}
.lg .card{padding:9px 11px}.lg h3{font:700 12.5px Rajdhani;letter-spacing:.6px;text-transform:uppercase;color:var(--gold);margin-bottom:5px;display:flex;gap:6px;align-items:center}
.fi{display:flex;gap:6px;font-size:10.3px;line-height:1.32;color:var(--tx2);margin-bottom:2px}.fi b{flex:none;width:14px;color:var(--ok)}
.fi em{flex:none;font-style:normal;font:700 8.5px Inter;padding:0 4px;border-radius:3px;height:13px;line-height:13px}
.fi em.M{background:rgba(255,84,104,.16);color:#ff8a98}.fi em.A{background:rgba(255,194,75,.14);color:#ffd27a}.fi em.P{background:rgba(61,220,151,.12);color:#7fe8b8}
.ex{font-size:10.3px;line-height:1.35;color:var(--tx2);margin-bottom:3px}.ex b{color:var(--acc)}
.dim{opacity:.5}
"""
THEMES={'ember':{},'midnight':{'--bg0':'#05060A','--bg1':'#090B11','--bg2':'#0F121A','--bg3':'#151924','--line':'#202432','--line2':'#2a2f3e','--w1':'rgba(16,18,26,.98)','--w2':'rgba(7,8,13,.98)'},
 'horde':{'--bg0':'#0F0707','--bg1':'#170B0B','--bg2':'#1F1010','--bg3':'#2A1414','--line':'#3A1C1C','--line2':'#4a2626','--acc':'#C8243D','--acc2':'#E04848','--w1':'rgba(34,16,16,.98)','--w2':'rgba(18,8,8,.98)'},
 'alliance':{'--bg0':'#070A12','--bg1':'#0B101B','--bg2':'#101826','--bg3':'#162034','--line':'#1E2C46','--line2':'#2a3a5a','--acc':'#3A78FF','--acc2':'#F4C46A','--w1':'rgba(18,26,44,.98)','--w2':'rgba(9,13,24,.98)'}}
BASEV=':root{--w1:rgba(24,26,34,.97);--w2:rgba(13,14,19,.97)}'
def themed(html,t):
    v=THEMES[t]
    if not v: return html
    css=':root{'+';'.join(f'{k}:{val}' for k,val in v.items())+'}'
    css+='.win,.card,.tip{background:linear-gradient(180deg,var(--w1),var(--w2))!important}.inset{background:var(--bg0)!important}'
    html=re.sub(r'#FF7A1A|#ff7a1a','var(--acc)',html)
    html=re.sub(r'rgba\(255,\s*122,\s*26,\s*(\.?\d+)\)',lambda m:f'color-mix(in srgb,var(--acc) {int(float(m.group(1))*100)}%,transparent)',html)
    return html.replace('</style>',css+'</style>',1)
def bwin(x,y,w,h,title,body,icon='Icons__Modules__64__skins',btabs=None,on=0,cog=True,portrait=True,z=10,sub=''):
    p=f'<div class="por"><img src="{A}{icon}.png"></div>' if portrait else ''
    bt=''
    if btabs: bt=f'<div class="btab" style="left:{x+14}px;top:{y+h-1}px;z-index:{z}">'+''.join(f'<span class="{"on" if i==on else ""}">{s}</span>' for i,s in enumerate(btabs))+'</div>'
    cg='<span class="cog px">⚙</span>' if cog else ''
    return (f'<div class="bw" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;z-index:{z}">{p}<div class="tbar"></div><div class="ttl2">{title}{(" <span class=\"mut\" style=\"font:400 11px Inter\">"+sub+"</span>") if sub else ""}</div>{cg}<span class="cl">×</span>'
            f'<div class="abs" style="left:0;right:0;top:30px;bottom:0">{body}</div></div>{bt}')
def px(html,inline=True): return f'<span class="px" style="display:{"inline-block" if inline else "block"}">{html}</span>'
def fly(x,y,title,rows,link='/pui → Skins'):
    r=''.join(f'<div class="kv"><span class="tx2">{a}</span><span>{b}</span></div>' for a,b in rows)
    return f'<div class="fly" style="left:{x}px;top:{y}px"><h5>⚙ Phoenix · {title}</h5>{r}<div style="margin-top:6px;font-size:10.5px" class="acc">Full settings: {link} ›</div></div>'
def legend(k):
    f=F[k];n=len(f['feats']);miss=sum(1 for _,s in f['feats'] if s=='M');alt=sum(1 for _,s in f['feats'] if s=='A')
    fl=''.join(f'<div class="fi"><b>✓</b><em class="{s}">{"v1 ok" if s=="P" else ("v1 missing" if s=="M" else "v1 altered")}</em><span>{a}</span></div>' for a,s in f['feats'])
    ex=''.join(f'<div class="ex"><b>◆</b> {a} <span class="mut">→ {b}</span></div>' for a,b in f['extras'])
    return (f'<div class="lg"><div class="card"><h3>Blizzard layout <span class="cov full" style="margin-left:auto">{n}/{n} present</span></h3><div class="mut" style="font-size:10px;margin-bottom:5px">Source: {f["src"]} · native size {f["size"]} · v1: {miss} missing, {alt} altered</div>{fl}</div>'
            f'<div class="card"><h3>Phoenix extras ◆</h3>{ex}<div class="ex"><b>⚙</b> Title-bar cog opens the inline flyout; every option is also on the full Skins page (simple / advanced, live)</div></div></div>')
def page2(k,sub,body):
    html=f'<!doctype html><html><head><meta charset="utf-8"><style>{sk.CSS}{CSS2}{BASEV}</style></head><body><div class="hd"><img src="{A}Textures__Logo__PhoenixUI_Icon_128.png"><div><h1>{F[k]["title"]}</h1><p>{sub}</p></div></div>{body}{legend(k)}<div class="stamp">PHOENIX UI · SKINS v2 · BLIZZARD LAYOUT, PHOENIX THEME · MOCKUP</div></body></html>'
    os.makedirs(os.path.join(HERE,'..','variants'),exist_ok=True)
    for t in THEMES:
        p=os.path.join(HERE,f'{k}__{t}.html'); open(p,'w').write(themed(html,t))
        out=os.path.join(HERE,'..',k+'.png') if t=='ember' else os.path.join(HERE,'..','variants',f'{k}_{t}.png')
        subprocess.run(['google-chrome','--headless=new','--no-sandbox','--disable-gpu','--hide-scrollbars','--allow-file-access-from-files','--window-size=1600,1000',f'--screenshot={out}','file://'+p],capture_output=True)
