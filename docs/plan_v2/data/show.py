import json, sys, collections
rows = json.load(open(sys.argv[1]))
pat = sys.argv[2]
SET = {"slider","toggle","dropdown","colorpicker","multiSwatch","multiswatch","input","checkbox","segmented","keybind","multi","reorder","reordercheck"}
by = collections.OrderedDict()
for r in rows:
    if pat not in r["file"] or r["type"] not in SET: continue
    by.setdefault((r["file"], r["section"]), []).append(r)
ab = {"slider":"S","toggle":"T","dropdown":"D","colorpicker":"C","multiSwatch":"C*","multiswatch":"C*","input":"I","checkbox":"T","segmented":"Seg","keybind":"K","multi":"M","reorder":"R","reordercheck":"R"}
for (f, s), rs in by.items():
    items = []
    for r in rs:
        t = ab[r["type"]]
        rng = f"[{r['min']}-{r['max']}]" if r["min"] and r["max"] else ""
        items.append(f"{r['label']}({t}{rng})")
    print(f"{f} :: {s or '-'} :: " + "; ".join(items))
