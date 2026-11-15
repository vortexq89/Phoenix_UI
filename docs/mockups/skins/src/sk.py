# Phoenix UI - Skins mockups (Ember design system v1). Original CSS art + Phoenix's own
# media (original Phoenix set, game-icons.net CC BY 3.0 glyphs, OFL fonts). No Blizzard art.
import os, subprocess
HERE=os.path.dirname(os.path.abspath(__file__)); A='assets/'
FONTS=[('Rajdhani','Rajdhani-SemiBold',600),('Rajdhani','Rajdhani-Bold',700),('Inter','Inter-Regular',400),('Inter','Inter-SemiBold',600),('Inter','Inter-Bold',700),('JBM','JetBrainsMono-Medium',500),('Cinzel','Cinzel-SemiBold',600),('Marcellus','Marcellus-Regular',400),('Barlow','BarlowCondensed-SemiBold',600)]
FF=''.join(f"@font-face{{font-family:'{f}';src:url('{A}fonts/{n}.ttf');font-weight:{w}}}" for f,n,w in FONTS)
Q={'poor':'#9d9d9d','common':'#e8e8e8','unc':'#1eff00','rare':'#0070dd','epic':'#a335ee','leg':'#ff8000','heir':'#00ccff','art':'#e6cc80'}
CSS=FF+"""
:root{--bg0:#0A0B0E;--bg1:#101217;--bg2:#161820;--bg3:#1D2029;--line:#2A2C33;--line2:#34363E;--tx:#ECE8E2;--tx2:#B9B6B0;--mut:#7D808B;--acc:#FF7A1A;--acc2:#FFA94D;--gold:#F4C46A;--ok:#3DDC97;--warn:#FFC24B;--err:#FF5468;--info:#5AB4FF}
*{box-sizing:border-box;margin:0;padding:0}
body{width:1600px;height:1000px;overflow:hidden;position:relative;font-family:Inter,sans-serif;font-size:12px;color:var(--tx);
 background:radial-gradient(ellipse 900px 600px at 38% 40%,#1d2a2a 0,#111518 55%,#07080a 100%)}
body:before{content:'';position:absolute;inset:0;background:radial-gradient(circle at 20% 85%,rgba(255,122,26,.07),transparent 40%),radial-gradient(circle at 70% 10%,rgba(90,180,255,.05),transparent 35%);pointer-events:none}
.abs{position:absolute}
.hd{position:absolute;left:28px;top:18px;display:flex;align-items:center;gap:12px;z-index:5}
.hd img{width:40px;height:40px}.hd h1{font-family:Rajdhani;font-weight:700;font-size:26px;letter-spacing:.3px}
.hd p{color:var(--mut);font-size:12px;margin-top:-2px}
.stamp{position:absolute;right:18px;bottom:10px;font:700 10px Inter;letter-spacing:2px;color:#ff8d6b;opacity:.8}
.win{position:absolute;border-radius:10px;background:linear-gradient(180deg,rgba(24,26,34,.97),rgba(13,14,19,.97));border:1px solid var(--line2);
 box-shadow:0 18px 50px rgba(0,0,0,.65),0 0 0 1px rgba(0,0,0,.7),inset 0 1px 0 rgba(255,255,255,.04);overflow:hidden}
.win:before{content:'';position:absolute;left:0;right:0;top:0;height:1px;background:linear-gradient(90deg,transparent,var(--acc) 30%,var(--acc2) 50%,var(--acc) 70%,transparent);opacity:.85}
.tb{height:38px;display:flex;align-items:center;gap:9px;padding:0 10px 0 12px;border-bottom:1px solid var(--line);background:linear-gradient(180deg,rgba(255,122,26,.06),transparent)}
.tb .ti{font:700 16px Rajdhani;letter-spacing:.4px}.tb .sub{color:var(--mut);font-size:11px}
.tb .sp{flex:1}.x{width:24px;height:24px;border-radius:6px;border:1px solid var(--line2);display:grid;place-items:center;color:var(--tx2);font-size:14px;background:var(--bg2)}
.tabs{display:flex;gap:2px;padding:0 10px;border-bottom:1px solid var(--line);height:32px;align-items:flex-end}
.tab{padding:7px 12px 8px;font:600 12px Inter;color:var(--tx2);border-bottom:2px solid transparent}
.tab.on{color:var(--tx);border-color:var(--acc);background:linear-gradient(0deg,rgba(255,122,26,.12),transparent)}
.btabs{position:absolute;left:12px;bottom:-1px;display:flex;gap:4px}
.card{background:rgba(22,24,32,.82);border:1px solid var(--line);border-radius:8px}
.inset{position:absolute;background:rgba(10,11,14,.72);border:1px solid var(--line);border-radius:8px}
.lbl{font:700 10px Inter;letter-spacing:1.4px;color:var(--mut);text-transform:uppercase}
.btn{display:inline-flex;align-items:center;justify-content:center;height:26px;padding:0 12px;border-radius:6px;font:600 11.5px Inter;border:1px solid var(--line2);background:var(--bg3);color:var(--tx)}
.btn.p{background:linear-gradient(180deg,#ff8a30,#e5650e);border-color:#ff9a4a;color:#1a0c02;box-shadow:0 0 12px rgba(255,122,26,.35)}
.btn.g{background:transparent;border-color:transparent;color:var(--tx2)}.btn.d{background:rgba(255,84,104,.12);border-color:#7a2a35;color:#ff8a98}
.btn.dis{opacity:.4}.btn.hv{border-color:var(--acc);box-shadow:0 0 0 1px rgba(255,122,26,.4)}
.chip{white-space:nowrap;display:inline-flex;align-items:center;height:20px;padding:0 8px;border-radius:10px;font:600 10.5px Inter;background:var(--bg3);border:1px solid var(--line2);color:var(--tx2);margin:0 3px 3px 0}
.chip.on{background:rgba(255,122,26,.16);border-color:var(--acc);color:#ffd2ad}
.srch{height:28px;border-radius:7px;background:var(--bg0);border:1px solid var(--line2);display:flex;align-items:center;padding:0 9px;gap:7px;color:var(--mut);font-size:11.5px}
.srch b{margin-left:auto;font:500 10px JBM;color:var(--mut);border:1px solid var(--line2);border-radius:4px;padding:1px 5px}
.dd{height:26px;border-radius:6px;background:var(--bg1);border:1px solid var(--line2);display:flex;align-items:center;padding:0 9px;font-size:11.5px;gap:6px}
.dd:after{content:'⌄';margin-left:auto;color:var(--mut)}
.tg{display:inline-block;width:30px;height:16px;border-radius:8px;background:#2c2f38;position:relative;vertical-align:middle}
.tg:after{content:'';position:absolute;left:2px;top:2px;width:12px;height:12px;border-radius:50%;background:#8a8d96}
.tg.on{background:var(--acc)}.tg.on:after{left:16px;background:#fff}
.ck{display:inline-block;width:14px;height:14px;border-radius:4px;border:1px solid var(--line2);background:var(--bg0);vertical-align:middle}
.ck.on{background:var(--acc);border-color:var(--acc2);box-shadow:inset 0 0 0 2px #241000}
.ic{position:relative;display:inline-block;border-radius:6px;overflow:hidden;flex:none;box-shadow:0 0 0 1px #000,inset 0 0 0 1px rgba(255,255,255,.08)}
.ic i{position:absolute;inset:14%;background:#fff;-webkit-mask-size:contain;-webkit-mask-repeat:no-repeat;-webkit-mask-position:center;filter:drop-shadow(0 1px 1px #000)}
.ic .q{position:absolute;inset:0;border-radius:6px;box-shadow:inset 0 0 0 1.5px var(--qc)}
.ic .n{position:absolute;right:3px;bottom:1px;font:700 10px Inter;text-shadow:0 0 2px #000,1px 1px 0 #000}
.bar{position:relative;height:8px;border-radius:4px;background:#0a0b0e;border:1px solid #000;overflow:hidden}
.bar span{position:absolute;left:0;top:0;bottom:0;border-radius:3px}
.row{display:flex;align-items:center;gap:9px;padding:6px 9px;border-radius:7px;border:1px solid transparent}
.row.hl{background:rgba(255,122,26,.09);border-color:rgba(255,122,26,.45)}
.row.alt{background:rgba(255,255,255,.025)}
.mut{color:var(--mut)}.tx2{color:var(--tx2)}.acc{color:var(--acc)}.gold{color:var(--gold)}.ok{color:var(--ok)}.err{color:var(--err)}
.sb{position:absolute;right:4px;width:4px;border-radius:2px;background:#22252d}.sb:after{content:'';position:absolute;left:0;right:0;top:10%;height:28%;border-radius:2px;background:#4a4d57}
.model{position:absolute;border-radius:8px;overflow:hidden;background:radial-gradient(ellipse at 50% 70%,rgba(255,122,26,.16),transparent 60%),radial-gradient(ellipse at 50% 30%,#232733,#0c0d11 75%);border:1px solid var(--line)}
.model .fig{position:absolute;left:50%;bottom:9%;transform:translateX(-50%);width:42%;height:78%}
.model .fig:before{content:'';position:absolute;left:36%;top:0;width:28%;height:17%;border-radius:50%;background:linear-gradient(#3a3f4d,#1b1e26)}
.model .fig:after{content:'';position:absolute;left:12%;top:16%;width:76%;height:84%;border-radius:40% 40% 12% 12%/30% 30% 8% 8%;background:linear-gradient(#353a48,#15171d);box-shadow:inset 0 0 18px rgba(255,140,60,.15)}
.model .cap{position:absolute;left:8px;bottom:6px;font-size:9.5px;color:var(--mut)}
.side{position:absolute;right:22px;top:70px;width:372px;display:flex;flex-direction:column;gap:10px;z-index:20}
.side .card{padding:10px 12px}.side h3{font:700 13px Rajdhani;letter-spacing:.6px;text-transform:uppercase;color:var(--gold);margin-bottom:6px;display:flex;align-items:center;gap:7px}
.side ul{list-style:none}.side li{font-size:11px;line-height:1.42;color:var(--tx2);padding-left:11px;position:relative;margin-bottom:2px}
.side li:before{content:'';position:absolute;left:0;top:6px;width:5px;height:5px;border-radius:50%;background:var(--acc)}
.side li b{color:var(--tx);font-weight:600}
.cov{display:inline-flex;font:700 10px Inter;letter-spacing:1px;padding:3px 8px;border-radius:5px;text-transform:uppercase}
.cov.full{background:rgba(61,220,151,.14);color:var(--ok);border:1px solid #1f7a55}.cov.part{background:rgba(255,194,75,.12);color:var(--warn);border:1px solid #7a5c1f}.cov.none{background:rgba(255,84,104,.12);color:var(--err);border:1px solid #7a2a35}
.kv{display:flex;justify-content:space-between;font-size:11.5px;padding:3px 0;border-bottom:1px dashed #23262e}
.kv:last-child{border:0}.kv span:last-child{font-weight:600}
.tip{position:absolute;z-index:40;border-radius:8px;padding:9px 11px;background:linear-gradient(180deg,rgba(20,22,29,.98),rgba(11,12,16,.98));border:1px solid var(--line2);box-shadow:0 10px 30px rgba(0,0,0,.7);font-size:11.5px;line-height:1.5}
.tip:before{content:'';position:absolute;left:10px;right:10px;top:0;height:1px;background:linear-gradient(90deg,transparent,var(--qc,var(--acc)),transparent)}
.grid{display:grid}
.money{font:600 11.5px JBM}.money .g{color:#f4c46a}.money .s{color:#c9ccd4}.money .c{color:#d08a55}
.ph{font:700 14px Rajdhani;letter-spacing:.4px}
"""
def G(name): return f"{A}Icons__{name}.png"
def ic(g='shield',col='#ff7a1a',sz=36,q=None,n='',rad=6,dim=False,img=None):
    if img and ('Abilities' in img or 'Classes' in img or 'Roles' in img or 'Emoji' in img):
        qq=f'<span class="q" style="--qc:{Q.get(q,q)}"></span>' if q else ''
        return f'<span class="ic" style="width:{sz}px;height:{sz}px;border-radius:{rad}px;background:#000 url({img}) center/cover;{"filter:grayscale(1) brightness(.5);" if dim else ""}">{qq}<span class="n">{n}</span></span>'
    src=img or G(g)
    qq=f'<span class="q" style="--qc:{Q.get(q,q)}"></span>' if q else ''
    return (f'<span class="ic" style="width:{sz}px;height:{sz}px;border-radius:{rad}px;background:radial-gradient(circle at 35% 30%,{col},#14161c 85%);{"filter:grayscale(1) brightness(.55);" if dim else ""}">'
            f'<i style="-webkit-mask-image:url({src})"></i>{qq}<span class="n">{n}</span></span>')
def btn(t,k=''): return f'<span class="btn {k}">{t}</span>'
def chip(t,on=False): return f'<span class="chip{" on" if on else ""}">{t}</span>'
def chips(l,on=()): return ''.join(chip(s,i in on or s in on) for i,s in enumerate(l))
def bar(p,c='var(--acc)',h=8,w='100%',txt=''):
    return f'<div class="bar" style="height:{h}px;width:{w}"><span style="width:{p}%;background:linear-gradient(90deg,{c},{c}cc)"></span>{txt}</div>'
def at(x,y,html,w=None,h=None,z=None,extra=''):
    s=f'left:{x}px;top:{y}px;'+(f'width:{w}px;' if w else '')+(f'height:{h}px;' if h else '')+(f'z-index:{z};' if z else '')
    return f'<div class="abs" style="{s}{extra}">{html}</div>'
def win(x,y,w,h,title,body,icon='Icons__Modules__64__skins',sub='',tabs=None,active=0,right='',z=10,btabs=None):
    t=''
    if tabs: t='<div class="tabs">'+''.join(f'<span class="tab{" on" if i==active else ""}">{s}</span>' for i,s in enumerate(tabs))+'</div>'
    bt=''
    if btabs: bt='<div class="abs" style="left:14px;bottom:8px;display:flex;gap:4px">'+''.join(f'<span class="chip{" on" if i==0 else ""}" style="height:24px;padding:0 12px">{s}</span>' for i,s in enumerate(btabs))+'</div>'
    return (f'<div class="win" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;z-index:{z}"><div class="tb"><img src="{A}{icon}.png" style="width:20px;height:20px;opacity:.95">'
            f'<span class="ti">{title}</span><span class="sub">{sub}</span><span class="sp"></span>{right}<span class="x">×</span></div>{t}<div class="abs" style="left:0;right:0;top:{38+(32 if tabs else 0)}px;bottom:0">{body}</div>{bt}</div>')
def model(x,y,w,h,cap='3D model (Blizzard renders it) · Phoenix backdrop + light'):
    return f'<div class="model" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><div class="fig"></div><div class="cap">{cap}</div></div>'
def side(cov,covtxt,restyle,restrict,settings,extra=''):
    c={'full':'full','partial':'part','none':'none'}[cov]
    return (f'<div class="side"><div class="card"><h3>Coverage today <span class="cov {c}" style="margin-left:auto">{cov}</span></h3><ul><li>{covtxt}</li></ul></div>'
            f'<div class="card"><h3>Phoenix restyle (this design)</h3><ul>'+''.join(f'<li>{s}</li>' for s in restyle)+'</ul></div>'
            f'<div class="card"><h3>Restriction → workaround</h3><ul>'+''.join(f'<li>{s}</li>' for s in restrict)+'</ul></div>'
            f'<div class="card"><h3>Settings · Simple / Advanced · live</h3><div>'+''.join(chip(s,i<2) for i,s in enumerate(settings))+'</div></div>'+extra+'</div>')
def money(g,s=0,c=0): return f'<span class="money"><span class="g">{g:,}g</span> <span class="s">{s}s</span> <span class="c">{c}c</span></span>'
def page(fname,title,sub,body):
    html=f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body><div class="hd"><img src="{A}Textures__Logo__PhoenixUI_Icon_128.png"><div><h1>{title}</h1><p>{sub}</p></div></div>{body}<div class="stamp">PHOENIX UI · SKINS MOCKUP · EMBER THEME · NOT FINAL ART</div></body></html>'
    p=os.path.join(HERE,fname+'.html'); open(p,'w').write(html)
    subprocess.run(['google-chrome','--headless=new','--no-sandbox','--disable-gpu','--hide-scrollbars','--allow-file-access-from-files','--force-device-scale-factor=1','--window-size=1600,1000',f'--screenshot={os.path.join(HERE,"..",fname+".png")}','file://'+p],capture_output=True)
