from sk import *
GL=['dragon_head','wolf_head','eagle_emblem','ghost','flame','sun','moon','snowflake_1','rose','crown','castle','tower_flag','compass','world','treasure_map','key']
CL=['#a05010','#5a3a90','#2a4a7a','#1f6a5a','#8a2a30','#6a6a20','#3a5a8a','#5a2a6a']
def lrow(i,g,name,sub,right='',hl=False,dim=False,fav=False,sz=34):
    return f'<div class="row{" hl" if hl else (" alt" if i%2 else "")}" style="height:{sz+10}px">{ic(g,CL[i%8],sz,dim=dim)}<div style="flex:1;min-width:0"><div style="font-weight:600;{"color:#7d808b" if dim else ""}">{name}{" <span class=gold>★</span>" if fav else ""}</div><div class="mut" style="font-size:10.5px">{sub}</div></div>{right}</div>'
def filt(ph,ch,on=(0,)): return f'<div style="display:flex;gap:8px;align-items:center;padding:10px 12px"><div class="srch" style="width:260px">⌕ {ph}</div>{chips(ch,on)}<span class="dd" style="width:140px;margin-left:auto">Sort: Name</span></div>'
T=['Mounts','Pet Journal','Toy Box','Heirlooms','Appearances','Campsites','Warband scenes']
