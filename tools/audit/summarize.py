import re,collections,json,os,sys
REF=os.environ.get("PUI_REF","/workspace/ref"); REPO=os.environ.get("PUI_REPO",os.getcwd())
lines=open(f"{REF}/luacheck_all.txt").read().splitlines()
rx=re.compile(r'^(.+?):(\d+):(\d+): \((W\d+)\) (.*)$')
defs=set(); acc=collections.defaultdict(list); fld=collections.defaultdict(list); setg=collections.defaultdict(list)
for l in lines:
    m=rx.match(l)
    if not m: continue
    f,ln,col,code,msg=m.groups()
    g=re.search(r"'([^']+)'",msg); name=g.group(1) if g else msg
    if code in("W111","W112","W121","W122"):
        defs.add(name.split(".")[0]); setg[name].append(f"{f}:{ln}")
    if code=="W113": acc[name].append(f"{f}:{ln}")
    if code=="W143":
        g2=re.findall(r"'([^']+)'",msg); fld[g2[1]+"."+g2[0]].append(f"{f}:{ln}")
for root,_,files in os.walk(REPO):
    for fn in files:
        if fn.endswith(".xml"):
            s=open(os.path.join(root,fn),errors="ignore").read()
            for m in re.finditer(r'\bname="([A-Za-z_]\w*)"',s): defs.add(m.group(1))
unk={k:v for k,v in acc.items() if k not in defs}
json.dump({"unknown":unk,"fields":fld,"set":setg,"defs":sorted(defs)},open(f"{REF}/luacheck_summary.json","w"),indent=1)
print("addon-defined global names:",len(defs), " unknown accessed:",len(unk), "refs:", sum(len(v) for v in unk.values()))
