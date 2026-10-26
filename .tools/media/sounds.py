# Copies the curated Kenney CC0 sound sets (ogg, unchanged) into media_out/Sounds.
# Sources: kenney.nl/assets/interface-sounds, /ui-audio, /rpg-audio (CC0 1.0).
import os,shutil,json,re
O="/workspace/media_out/Sounds"; os.makedirs(O,exist_ok=True); man=[]
def nice(n):
  b=re.sub(r'[_]?0*(\d+)$',r' \1',os.path.splitext(n)[0]); b=re.sub(r'([a-z])([A-Z])',r'\1 \2',b).replace('_',' ')
  return b.strip().title()
packs=[("is/Audio","Interface Sounds","https://kenney.nl/assets/interface-sounds",None,"KIS"),
 ("kenney_ui-audio/Audio","UI Audio","https://kenney.nl/assets/ui-audio",lambda f: not f.startswith("switch") or int(re.findall(r'\d+',f)[0])<=12,"KUI"),
 ("kenney_rpg-audio/Audio","RPG Audio","https://kenney.nl/assets/rpg-audio",lambda f: re.match(r'(book|chop|cloth1|creak1|doorOpen_1|doorClose_1|drawKnife1|handleCoins|knifeSlice\.|metalClick|metalLatch|metalPot1)',f),"KRPG")]
for d,pack,url,flt,pre in packs:
  for f in sorted(os.listdir(d)):
    if not f.endswith(".ogg") or (flt and not flt(f)): continue
    out=f"{pre}_{f}"; shutil.copy(os.path.join(d,f),os.path.join(O,out))
    man.append({"file":"Sounds/"+out,"type":"sound","name":f"{pack}: {nice(f)}","source":url,"author":"Kenney (kenney.nl)","licence":"CC0 1.0","changes":"renamed"})
json.dump(man,open("sounds_manifest.json","w"),indent=1); print(len(man))
