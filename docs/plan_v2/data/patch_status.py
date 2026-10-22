from spec_lib import MOD
FIX = {
 "Tooltip": {"Guild rank":"new","Item level and spec (inspect)":"new","Item: vendor price":"new","Scale":"new","Class-coloured names":"new","Role icon":"has","Border by class (players)":"has","Health bar height":"has","Realm":"new","Target of unit":"has"},
 "Chat": {"Timestamps":"new","Short channel names ([G], [P], [1])":"new","Hide side buttons":"new","Flash new messages":"has","Arrow keys without Alt":"has","History lines":"part","Chat background":"new","Chat background colour":"new","Chat background opacity":"new","Chat font":"part","Chat size":"part"},
 "Minimap": {"Shape":"part","Size":"new","Border style":"new","Border size":"new","Border colour":"new","Mouse wheel zoom":"new","Zone text":"part","Coordinates":"part","Collect addon buttons":"has","Buttons per row":"has","Clock":"new"},
 "Bags": {"Combined bags":"has","Quality border":"has","Upgrade arrow (better ilvl)":"has","Count size":"has","Search box":"new","Sort button":"new","Slot border style":"new","Slot border size":"new","Slot border colour":"new"},
 "ItemLevel": {"Inspect frame slots":"new","Bags / bank (in Bags)":"has","Item level size":"has","Item level font":"new","Item level outline":"new","Item level shadow":"new","Item level colour":"new"},
 "DataTexts": {"Slots":"new","Mouseover only":"new"},
}
def apply():
    for m, fx in FIX.items():
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["status"] = fx[row["name"]]

TYPES = {"Sim": {"Fight style":"D","Targets":"S","Fight length (seconds)":"S","Use results for (days)":"S"},
         "Bugs": {"Reports kept":"S","Sound":"D","Minimap indicator":"D"}}
def apply2():
    for m, fx in TYPES.items():
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["type"] = fx[row["name"]]
    for row in MOD["Encounters"]["rows"]:
        row["weight"] = 61 if row["name"].startswith("Existing") else 1
