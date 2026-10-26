import os,glob,json,re,io,cairosvg
from PIL import Image
O="/workspace/media_out/Icons"; os.makedirs(O,exist_ok=True); man=[]; miss=[]
NAMES="crossed-swords shield heart-plus skull lightning-bolt fire-ring snowflake-1 poison-bottle crown hourglass stopwatch alarm-clock trophy-cup sword-wound bleeding-wound health-potion magic-swirl sun moon stars-stack eye-target target-arrows radar-sweep cog gears padlock open-book scroll-unfurled treasure-map compass flag-objective checked-shield broken-shield halt chat-bubble speaker music-spell bell-shield beer-stein potion-ball crystal-ball diamond-hard gold-bar coins backpack anvil hammer-drop bow-arrow wizard-staff dragon-head wolf-head eagle-emblem phoenix-head flame dripping-sword run sprint person cancel check-mark plus-flat-symbol minus info question-mark exclamation-mark arrow-dunk pin aura bolt-shield spell-book heart-shield fist mailed-fist ninja-mask hood archer pointy-hat wizard-face hooded-assassin knight-helmet visored-helm rose skull-crossed-bones death-skull ghost key locked-chest map world castle tower-flag campfire hearts".split()
for n in NAMES:
  fs=[p for p in sorted(glob.glob(f"gi/*/{n}.svg")) if p.split("/")[1] not in ("badges","lucasms","various-artists")]
  if not fs: miss.append(n); continue
  f=fs[0]; author=f.split("/")[1]
  svg=open(f).read()
  # game-icons SVGs: black background path + white glyph; drop the background, keep white glyph.
  svg=re.sub(r'<path d="M0 0h512v512H0z"/>','',svg)
  svg=svg.replace('fill="#000"','fill="#fff"').replace("<svg ",'<svg fill="#fff" ',1)
  png=cairosvg.svg2png(bytestring=svg.encode(),output_width=64,output_height=64)
  im=Image.open(io.BytesIO(png)).convert("RGBA")
  out=n.replace("-","_")+".tga"; im.save(os.path.join(O,out))
  man.append({"file":"Icons/"+out,"type":"icon","name":n.replace("-"," ").title(),"source":f"https://game-icons.net/1x1/{author}/{n}.html","author":author,"licence":("CC0 1.0" if author=="zeromancer" else "CC BY 3.0"),"changes":"rendered white on transparent, 64x64 TGA"})
json.dump(man,open("icons_manifest.json","w"),indent=1); print(len(man),"missing",miss)
