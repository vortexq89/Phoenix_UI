import os, json, urllib.request, io
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
OUT="/workspace/media_out/Fonts"; os.makedirs(OUT,exist_ok=True)
RAW="https://raw.githubusercontent.com/google/fonts/main/ofl/%s/%s"
# (display name, dir, source file, axis values or None, out file, script coverage)
F=[
("Roboto","roboto","Roboto[wdth,wght].ttf",{"wght":400,"wdth":100},"Roboto-Regular.ttf","Latin, Cyrillic, Greek"),
("Roboto Bold","roboto","Roboto[wdth,wght].ttf",{"wght":700,"wdth":100},"Roboto-Bold.ttf","Latin, Cyrillic, Greek"),
("Roboto Condensed","robotocondensed","RobotoCondensed[wght].ttf",{"wght":400},"RobotoCondensed-Regular.ttf","Latin, Cyrillic, Greek"),
("Roboto Condensed Bold","robotocondensed","RobotoCondensed[wght].ttf",{"wght":700},"RobotoCondensed-Bold.ttf","Latin, Cyrillic, Greek"),
("Inter","inter","Inter[opsz,wght].ttf",{"wght":400,"opsz":14},"Inter-Regular.ttf","Latin, Cyrillic, Greek"),
("Inter SemiBold","inter","Inter[opsz,wght].ttf",{"wght":600,"opsz":14},"Inter-SemiBold.ttf","Latin, Cyrillic, Greek"),
("Open Sans","opensans","OpenSans[wdth,wght].ttf",{"wght":400,"wdth":100},"OpenSans-Regular.ttf","Latin, Cyrillic, Greek, Hebrew"),
("Open Sans Bold","opensans","OpenSans[wdth,wght].ttf",{"wght":700,"wdth":100},"OpenSans-Bold.ttf","Latin, Cyrillic, Greek, Hebrew"),
("Lato","lato","Lato-Regular.ttf",None,"Lato-Regular.ttf","Latin"),
("Lato Black","lato","Lato-Black.ttf",None,"Lato-Black.ttf","Latin"),
("Montserrat","montserrat","Montserrat[wght].ttf",{"wght":500},"Montserrat-Medium.ttf","Latin, Cyrillic"),
("Montserrat Bold","montserrat","Montserrat[wght].ttf",{"wght":700},"Montserrat-Bold.ttf","Latin, Cyrillic"),
("Oswald","oswald","Oswald[wght].ttf",{"wght":500},"Oswald-Medium.ttf","Latin, Cyrillic"),
("Poppins","poppins","Poppins-Medium.ttf",None,"Poppins-Medium.ttf","Latin, Devanagari"),
("Poppins Bold","poppins","Poppins-Bold.ttf",None,"Poppins-Bold.ttf","Latin, Devanagari"),
("Exo 2","exo2","Exo2[wght].ttf",{"wght":600},"Exo2-SemiBold.ttf","Latin, Cyrillic"),
("Rajdhani","rajdhani","Rajdhani-SemiBold.ttf",None,"Rajdhani-SemiBold.ttf","Latin, Devanagari"),
("Teko","teko","Teko[wght].ttf",{"wght":500},"Teko-Medium.ttf","Latin, Devanagari"),
("Bebas Neue","bebasneue","BebasNeue-Regular.ttf",None,"BebasNeue-Regular.ttf","Latin"),
("Barlow Condensed","barlowcondensed","BarlowCondensed-SemiBold.ttf",None,"BarlowCondensed-SemiBold.ttf","Latin"),
("Source Sans 3","sourcesans3","SourceSans3[wght].ttf",{"wght":400},"SourceSans3-Regular.ttf","Latin, Cyrillic, Greek"),
("Noto Sans","notosans","NotoSans[wdth,wght].ttf",{"wght":400,"wdth":100},"NotoSans-Regular.ttf","Latin, Cyrillic, Greek"),
("Noto Sans Bold","notosans","NotoSans[wdth,wght].ttf",{"wght":700,"wdth":100},"NotoSans-Bold.ttf","Latin, Cyrillic, Greek"),
("Noto Sans Arabic","notosansarabic","NotoSansArabic[wdth,wght].ttf",{"wght":400,"wdth":100},"NotoSansArabic-Regular.ttf","Arabic"),
("Cairo","cairo","Cairo[slnt,wght].ttf",{"wght":500,"slnt":0},"Cairo-Medium.ttf","Arabic, Latin"),
("Tajawal","tajawal","Tajawal-Medium.ttf",None,"Tajawal-Medium.ttf","Arabic, Latin"),
("Noto Sans SC","notosanssc","NotoSansSC[wght].ttf",{"wght":400},"NotoSansSC-Regular.ttf","Simplified Chinese, Latin, Cyrillic"),
("Noto Sans KR","notosanskr","NotoSansKR[wght].ttf",{"wght":400},"NotoSansKR-Regular.ttf","Korean, Latin, Cyrillic"),
("Noto Sans JP","notosansjp","NotoSansJP[wght].ttf",{"wght":400},"NotoSansJP-Regular.ttf","Japanese, Latin, Cyrillic"),
("PT Sans","ptsans","PT_Sans-Web-Regular.ttf",None,"PTSans-Regular.ttf","Latin, Cyrillic"),
("PT Sans Bold","ptsans","PT_Sans-Web-Bold.ttf",None,"PTSans-Bold.ttf","Latin, Cyrillic"),
("Fira Sans","firasans","FiraSans-Medium.ttf",None,"FiraSans-Medium.ttf","Latin, Cyrillic, Greek"),
("Nunito","nunito","Nunito[wght].ttf",{"wght":600},"Nunito-SemiBold.ttf","Latin, Cyrillic"),
("Chakra Petch","chakrapetch","ChakraPetch-SemiBold.ttf",None,"ChakraPetch-SemiBold.ttf","Latin, Thai"),
("Orbitron","orbitron","Orbitron[wght].ttf",{"wght":600},"Orbitron-SemiBold.ttf","Latin"),
("Russo One","russoone","RussoOne-Regular.ttf",None,"RussoOne-Regular.ttf","Latin, Cyrillic"),
("Black Ops One","blackopsone","BlackOpsOne-Regular.ttf",None,"BlackOpsOne-Regular.ttf","Latin"),
("Cinzel","cinzel","Cinzel[wght].ttf",{"wght":600},"Cinzel-SemiBold.ttf","Latin"),
("Marcellus","marcellus","Marcellus-Regular.ttf",None,"Marcellus-Regular.ttf","Latin"),
("Roboto Mono","robotomono","RobotoMono[wght].ttf",{"wght":500},"RobotoMono-Medium.ttf","Latin, Cyrillic, Greek"),
("JetBrains Mono","jetbrainsmono","JetBrainsMono[wght].ttf",{"wght":500},"JetBrainsMono-Medium.ttf","Latin, Cyrillic, Greek"),
("Press Start 2P","pressstart2p","PressStart2P-Regular.ttf",None,"PressStart2P-Regular.ttf","Latin, Cyrillic"),
("Bangers","bangers","Bangers-Regular.ttf",None,"Bangers-Regular.ttf","Latin"),
]
cache="/workspace/media_src/fonts"; man=[]; lic={}
def get(d,f):
  p=os.path.join(cache,d+"__"+f)
  if not os.path.exists(p):
    urllib.request.urlretrieve(RAW%(d,urllib.request.quote(f)),p)
  return p
for name,d,f,ax,out,cov in F:
  src=get(d,f); lic[d]=get(d,"OFL.txt")
  font=TTFont(src)
  if ax:
    font=instancer.instantiateVariableFont(font,ax,updateFontNames=False)
  for t in ("STAT","MVAR","HVAR","avar","fvar","gvar"):
    if t in font: del font[t]
  font.save(os.path.join(OUT,out))
  author=TTFont(src)["name"].getDebugName(0) or ""
  man.append({"file":"Fonts/"+out,"type":"font","name":name,"coverage":cov,"source":"https://github.com/google/fonts/tree/main/ofl/"+d,"author":author.strip(),"licence":"SIL OFL 1.1","changes":("static instance "+json.dumps(ax)) if ax else "none"})
os.makedirs("/workspace/media_out/Licenses/fonts",exist_ok=True)
import shutil
for d,p in lic.items(): shutil.copy(p,"/workspace/media_out/Licenses/fonts/%s-OFL.txt"%d)
json.dump(man,open("/workspace/media_src/fonts_manifest.json","w"),indent=1)
print(len(man))
