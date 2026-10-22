from spec_lib import MOD
FIX = {
 "Tooltip": {"Guild rank":"new","Item level and spec (inspect)":"new","Item: vendor price":"new","Scale":"new","Class-coloured names":"new","Role icon":"has","Border by class (players)":"has","Health bar height":"has","Realm":"new","Target of unit":"has"},
 "Chat": {"Timestamps":"new","Short channel names ([G], [P], [1])":"new","Hide side buttons":"new","Flash new messages":"has","Arrow keys without Alt":"has","History lines":"part","Chat background":"new","Chat background colour":"new","Chat background opacity":"new","Chat font":"part","Chat size":"part"},
 "Minimap": {"Shape":"part","Size":"new","Border style":"new","Border size":"new","Border colour":"new","Mouse wheel zoom":"new","Zone text":"part","Coordinates":"part","Collect addon buttons":"has","Buttons per row":"has","Clock":"new"},
 "Bags": {"Combined bags":"has","Quality border":"has","Upgrade arrow (better ilvl)":"has","Count size":"has","Search box":"new","Sort button":"new","Slot border style":"new","Slot border size":"new","Slot border colour":"new"},
 "ItemLevel": {"Inspect frame slots":"new","Bags / bank (in Bags)":"has","Item level size":"has","Item level font":"new","Item level outline":"new","Item level shadow":"new","Item level colour":"new"},
 "DataTexts": {"Slots":"new","Mouseover only":"new"},
}
# S13a/S13b (2026-10-22): statuses checked against the shipped option pages; Now = smoke "settings" counts (retail).
BG = {"{0} background":"has","{0} background texture":"part","{0} background colour":"has","{0} background opacity":"has",
      "{0} border style":"has","{0} border size":"has","{0} border colour":"has","{0} border shadow":"has","{0} border shadow size":"new"}
def look(prefix): return {k.format(prefix): v for k, v in BG.items()}
S13 = {
 "Chat": dict(look("Chat"), **{"Width / height (main)":"has","Fade lines after":"has","Max lines kept":"has","Hide in combat":"has",
   "Hide side buttons":"has","Scroll to bottom button":"has","Tab style":"part","Selected tab colour":"has","Fade tabs when idle":"has",
   "Chat font":"has","Chat size":"has","Timestamps":"has","Timestamp colour":"new","Short channel names ([G], [P], [1])":"has",
   "Class-coloured names":"has","Item level in item links":"has","Icons in links (item, spell, achievement)":"has",
   "Role icons before names":"has","Keyword highlight list":"has","Keyword sound":"has","Spam throttle (repeat lines)":"has",
   "Edit box position":"has","Edit box style":"has","Remember last channel":"new","History lines":"has",
   "Chat bar (channel buttons, roll, ready check)":"has","Emote picker":"new","Whisper sound":"has","Whisper tab per person":"has",
   "Combat log tab hidden":"new"}),
 "Minimap": {"Shape":"has","Size":"has","Rectangle height (shape = rectangle)":"has","Scale":"new","Border style":"has","Border size":"has",
   "Border colour":"has","Border shadow":"has","Border shadow size":"new","Mouse wheel zoom":"has","Auto zoom out after":"has",
   "Zone text":"has","Zone text font":"has","Zone text size":"has","Zone text outline":"has","Zone text shadow":"has","Zone text colour":"has",
   "Zone text colour by PvP status":"has","Clock":"has","Clock font":"has","Clock size":"has","Clock outline":"has","Clock shadow":"has",
   "Clock colour":"has","Coordinates":"has","Coordinate decimals":"has","Calendar / invites":"has","Tracking button":"has","Mail icon":"has",
   "Crafting order icon":"has","Instance difficulty badge":"has","Expansion / housing button":"has","Group finder eye":"new",
   "Button size":"has","Ignore list":"has","Ping name display":"has","World map: reveal unexplored":"new",
   "World map: player / cursor coords":"has","World map scale":"new"},
 "Tooltip": {"Background texture":"part","Border shadow":"has","Border shadow size":"new","Cursor offset X / Y":"has","Scale":"has",
   "Class-coloured names":"has","Guild rank":"has","Realm":"has","Targeted by (group)":"has","Item level and spec (inspect)":"has",
   "Raid progression line":"new","Mount the player is on":"has","NPC: reaction-coloured, hide 'PvP' line":"has","Show IDs":"has",
   "ID kinds":"has","Item: count in bags / bank / warband":"has","Item: vendor price":"new","Item: already known / collected":"new",
   "Keystone tooltip (affixes, depleted)":"new","Group finder entry tooltip details":"new"},
 "Bags": dict(look("Window"), **{"Combined bags":"has","Columns":"has","Slot size":"has","Slot spacing":"has","Category sections":"has",
   "Category list (reorder / hide)":"has","Bank / Warband bank same layout":"part","Scale":"has","Item level on gear":"has",
   "Item level font":"new","Item level size":"part","Item level outline":"new","Item level shadow":"new","Item level colour":"new",
   "Quality border":"has","Slot border style":"has","Slot border size":"has","Slot border colour":"has","Slot border shadow":"has",
   "Slot border shadow size":"new","Junk coin icon":"has","New item glow":"has","Upgrade arrow (better ilvl)":"has",
   "Bind-on-equip / warbound label":"has","Cooldown on usable items":"has","Count font":"has","Count size":"has","Count outline":"has",
   "Count shadow":"has","Count colour":"has","Search box":"has","Gold, currencies footer":"has","Bag bar inside window":"new",
   "Sort button":"has","Sort direction / reverse":"has","Auto sell junk (in Automation)":"has",
   "Open with vendor / bank / mail / AH":"part","Close with vendor":"part"}),
 "DataTexts": dict(look("Panel"), **{"Enable panel":"has","Slots":"has","Width / height":"part","Mouseover only":"has",
   "Anchor":"part","X offset":"part","Y offset":"part","Frame strata":"part","Scale":"part","Label colour / value colour":"part",
   "Hide labels":"has","Combat: hide tooltips":"has","Slot source":"has","Gold: show silver/copper":"has",
   "Gold: account-wide totals":"has","Time: 24h / local vs realm":"has","Durability: warn below":"has","Currency picker":"new",
   "Experience bar":"has","Reputation bar (watched)":"has","Honor bar":"new","Bar width / height":"has","Data bar texture":"new",
   "Data bar fill direction":"new","Data bar smooth fill":"new","Data bar gradient":"new","Rested / quest XP overlay":"has",
   "Bar text":"has","Bar text font":"has","Bar text size":"has","Bar text outline":"has","Bar text shadow":"has","Bar text colour":"has"}),
 "Skins": dict(look("Window"), **{"Character / inspect":"has","Spellbook / talents":"has","Group finder":"has","Collections":"has",
   "Professions":"has","Auction house":"has","Mail / merchant / gossip / quest":"has","Loot / rolls":"part",
   "Achievement / encounter journal":"has","Calendar / guild / communities":"has","Settings / addon list":"part",
   "Great vault / keystone":"has","Alerts / toasts":"new","Skyriding vigor bar":"new","Title bar style":"has","Close button style":"has"}),
}
# S14 (2026-10-22): the Quests page. Objective areas stay Blizzard's (turn-ins only); community positions come with S17.
S14 = {"Quests": {"Restyle objective tracker":"has", "Width / max height":"has", "Header font":"has", "Header size":"has", "Header outline":"has", "Header shadow":"has", "Header colour":"has", "Objective font":"has", "Objective size":"has", "Objective outline":"has", "Objective shadow":"has", "Objective colour":"has", "Progress bars style":"has", "Colour by difficulty":"has", "Auto-collapse in instances / combat":"has", "Show quest level / tag (daily, campaign)":"has", "Click to super-track":"has", "Waypoint arrow":"has", "Arrow style / size":"has", "Distance + ETA text":"has", "Available quests on map (C_QuestLine)":"has", "Turn-in / objective areas from QuestPOI (DB2)":"part", "Quest NPC pins (ATT data + community)":"part", "Hide low-level / trivial":"has", "Auto accept / turn in (hold Shift to stop)":"has", "Auto pick quest reward (highest sell / sim upgrade)":"has", "Contribute positions to Phoenix data (opt-in)":"has"},
       "Automation": {"Auto accept / turn in quests (in Quests)":"has"}}
NOW = {"Chat": 58, "Minimap": 47, "Tooltip": 54, "Bags": 53, "DataTexts": 67, "Skins": 34, "Quests": 38}

def apply():
    for m, fx in FIX.items():
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["status"] = fx[row["name"]]
    for m, fx in list(S13.items()) + list(S14.items()):
        names = {row["name"] for row in MOD[m]["rows"]}
        assert set(fx) <= names, (m, set(fx) - names)
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["status"] = fx[row["name"]]
    for m, n in NOW.items(): MOD[m]["now"] = n

TYPES = {"Sim": {"Fight style":"D","Targets":"S","Fight length (seconds)":"S","Use results for (days)":"S"},
         "Bugs": {"Reports kept":"S","Sound":"D","Minimap indicator":"D"}}
def apply2():
    for m, fx in TYPES.items():
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["type"] = fx[row["name"]]
    for row in MOD["Encounters"]["rows"]:
        row["weight"] = 61 if row["name"].startswith("Existing") else 1
