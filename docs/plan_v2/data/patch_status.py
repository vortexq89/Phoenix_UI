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
# S15 (2026-10-22): the Group Finder page (retail). The sign-up note cannot be remembered (Blizzard's note box refuses
# SetText from addons); role checks are accepted by a key press only; key level = the leader's best key there.
S15 = {"GroupFinder": {"Filter panel next to the group list":"has", "Min / max members, tanks, healers, damage":"has",
       "Has Bloodlust / Battle res":"has", "Min leader score / item level":"has", "Age (minutes)":"has",
       "Dungeon / difficulty / key level":"part", "Advanced expression (Phoenix syntax)":"has", "Sort":"has",
       "One-click sign up (double click)":"has", "Role / class icons on list entries":"has",
       "Leader score + best key in tooltip":"has", "Raid lockout hint":"has", "Auto queue (role check) accept":"part"}}
# S16 (2026-10-22): every module re-audited against the shipped option pages (tools/smoke/harness.lua PUI_LABELS_OUT
# dump). Per module: the status for rows not yet "has" (None = keep), then per-row overrides. Two new statuses leave
# the target: "link" = owned by another Phoenix page or Edit Mode (a link row points there), "api" = not possible
# with the 12.x API (secret values, protected frames, no data source).
S16 = {
 "ActionBars": ("has", {"Hide charge count at 0":"new", "Cooldown numbers (Blizzard countdown)":"link",
   "Cooldown number size":"link"}),
 "CooldownText": ("has", {}),
 "Tracker": ("has", {"Glow colour / lines / speed / thickness":"part", "Buff bar fill direction":"part",
   "Bar background texture":"part", "Buff bar smooth fill":"new", "Buff bar gradient":"new", "Stack-based fill":"new"}),
 "UnitFrames": ("has", {"Frame background texture":"part", "Click casting (Blizzard Click Cast bindings)":"new",
   "Health bar height share":"part", "Over-absorb glow line":"part", "Overheal shown":"new",
   "Prediction colours (mine / others)":"part", "Detached width":"part", "Power fill direction":"part",
   "Power gradient":"part", "Spell cost prediction":"new", "Mana regen spark":"new", "Pip shape":"new",
   "Stagger / Soul fragments / Ebon Might extras":"part", "Fade out of combat":"part",
   "Level text (difficulty colour)":"part", "Portrait size":"new", "Threat % text":"part",
   "Ready check / summon / resurrect":"part", "Arena: trinket / racial / DR tracker":"part"}),
 "GroupFrames": ("has", {"Self position":"part", "Dispel colours":"new", "Missing raid buff icon":"link"}),
 "NamePlates": ("has", {"Health background texture":"part", "NPC title / guild on friendly":"new",
   "Preview eye toggles (marker, quest, target, absorb)":"part"}),
 "CastBars": ("has", {"Background texture":"part", "Hide Blizzard player cast bar":"part"}),
 "Auras": ("has", {}),
 "CombatText": ("has", {"Area position / size / direction":"part"}),
 "DamageMeter": ("has", {"Bar height / spacing":"link", "Class colours":"link", "Value format":"link",
   "Show rank numbers / spec icons":"link", "Auto-show in combat, hide after":"link", "Second window":"link",
   "Meter bar smooth fill":"api", "Meter bar fill direction":"part", "Window background texture":"part"}),
 "SpellHistory": ("has", {}),
 "ItemLevel": ("has", {"Loot / roll / great vault / merchant":"part", "Character sheet: stats panel restyle":"new"}),
 "General": ("has", {"Replace Blizzard fonts (damage, names, chat)":"part", "Default glow style":"part",
   "Glow colour / lines / speed / thickness":"part", "Reaction colours":"link", "Dispel colours":"link",
   "Power colours override":"new"}),
 "Profiles": ("has", {"Per-character overrides":"new", "Import with preview of changes":"part"}),
 "Movers": ("has", {}),
 "Quality": ("has", {"Hide boss banner / zone text / level-up":"part", "CVar browser (common safe CVars)":"part"}),
 "Automation": ("has", {"Auto role check accept":"link"}),
 "AFK": ("has", {}),
 "Bugs": ("has", {}),
 "MythicPlus": ("has", {"Hide Blizzard objective tracker in M+":"link", "Teleport buttons on dungeon list":"new"}),
 "Encounters": ("has", {"Per-spell colour override":"api", "Private aura sounds":"api"}),
 "PvP": ("has", {"Battleground score on top bar":"link", "Healer marker on enemy plates":"api",
   "Arena prep: enemy specs":"link", "Dampening display":"api"}),
 "Sim": ("has", {"Include bags / bank / vault / catalyst options":"part"}),
 "Chat": (None, {"Chat border shadow size":"has"}),
 "Minimap": (None, {"Border shadow size":"has"}),
 "Tooltip": (None, {"Border shadow size":"has"}),
 "Bags": (None, {"Slot border shadow size":"has", "Window border shadow size":"has", "Item level font":"link",
   "Item level size":"link", "Item level outline":"link", "Item level shadow":"link", "Item level colour":"link"}),
 "DataTexts": (None, {"Panel border shadow size":"has"}),
 "Skins": (None, {"Window border shadow size":"has"}),
 "GroupFinder": (None, {"Remember sign-up note":"api"}),
}

# S17 (2026-10-22): the 36 open gap rows. Per row: status, or (status, stage) for rows that stay open and move on.
# link = owned by another page or Edit Mode; api = not possible with the 12.x API (see PLAN_V2 S17 note).
S17 = {
 "Tracker": {"Buff bar smooth fill":"api", "Buff bar gradient":"has", "Stack-based fill":"api"},
 "UnitFrames": {"Click casting (Blizzard Click Cast bindings)":"link", "Overheal shown":"has", "Spell cost prediction":"has",
   "Pip shape":"has", "Portrait size":"has"},
 "GroupFrames": {"Dispel colours":"has"},
 "NamePlates": {"NPC title / guild on friendly":"has"},
 "Chat": {"Timestamp colour":"has", "Remember last channel":"api", "Emote picker":"has", "Combat log tab hidden":"api"},
 "Minimap": {"Scale":"link", "Group finder eye":"api", "World map: reveal unexplored":("new", "S25"), "World map scale":"has"},
 "Tooltip": {"Raid progression line":("new", "S24"), "Item: vendor price":"has", "Item: already known / collected":"has",
   "Keystone tooltip (affixes, depleted)":"has", "Group finder entry tooltip details":"link"},
 "Bags": {"Bag bar inside window":"has"},
 "ItemLevel": {"Character sheet: stats panel restyle":"has"},
 "DataTexts": {"Currency picker":"has", "Honor bar":"has", "Data bar texture":"has", "Data bar fill direction":"has",
   "Data bar smooth fill":"has", "Data bar gradient":"has"},
 "Skins": {"Alerts / toasts":"has", "Skyriding vigor bar":("new", "S24")},
 "General": {"Power colours override":"has"},
 "Profiles": {"Per-character overrides":"link"},
 "MythicPlus": {"Teleport buttons on dungeon list":("new", "S28")},
}

S18 = {
 "UnitFrames": {"Frame background texture":"has", "Health bar height share":"has", "Over-absorb glow line":("part", "S19"),
   "Prediction colours (mine / others)":"has", "Detached width":"has", "Power fill direction":"has", "Power gradient":"has",
   "Stagger / Soul fragments / Ebon Might extras":"has", "Fade out of combat":"has", "Level text (difficulty colour)":"has",
   "Threat % text":"has", "Ready check / summon / resurrect":"has", "Arena: trinket / racial / DR tracker":"has"},
}

NOW = {"ActionBars": 117, "CooldownText": 15, "Tracker": 93, "UnitFrames": 359, "GroupFrames": 194, "NamePlates": 276, "CastBars": 105, "Auras": 64, "CombatText": 30, "DamageMeter": 24, "SpellHistory": 13, "Chat": 61, "Minimap": 49, "Tooltip": 58, "Bags": 56, "ItemLevel": 20, "DataTexts": 77, "Skins": 36, "General": 52, "Profiles": 15, "Movers": 17, "Quality": 22, "Automation": 15, "AFK": 12, "Bugs": 12, "Quests": 43, "GroupFinder": 58, "MythicPlus": 34, "Encounters": 64, "PvP": 18, "Sim": 11, "Diagnostics": 9}
NOW_FOREVER = {"ActionBars": 116, "CooldownText": 15, "Tracker": 89, "UnitFrames": 314, "GroupFrames": 193, "NamePlates": 270, "CastBars": 115, "Auras": 64, "CombatText": 30, "DamageMeter": 24, "SpellHistory": 13, "Chat": 61, "Minimap": 46, "Tooltip": 55, "Bags": 55, "ItemLevel": 20, "DataTexts": 76, "Skins": 34, "General": 52, "Profiles": 11, "Movers": 17, "Quality": 22, "Automation": 15, "AFK": 12, "Bugs": 12, "Quests": 41, "GroupFinder": None, "MythicPlus": None, "Encounters": 9, "PvP": 10, "Sim": None, "Diagnostics": 9}

def apply():
    for m, fx in FIX.items():
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["status"] = fx[row["name"]]
    for m, fx in list(S13.items()) + list(S14.items()) + list(S15.items()):
        names = {row["name"] for row in MOD[m]["rows"]}
        assert set(fx) <= names, (m, set(fx) - names)
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["status"] = fx[row["name"]]
    for m, (default, fx) in S16.items():
        names = {row["name"] for row in MOD[m]["rows"]}
        assert set(fx) <= names, (m, set(fx) - names)
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["status"] = fx[row["name"]]
            elif default and row["status"] != "has": row["status"] = default
    for m, fx in list(S17.items()) + list(S18.items()):
        names = {row["name"] for row in MOD[m]["rows"]}
        assert set(fx) <= names, (m, set(fx) - names)
        for row in MOD[m]["rows"]:
            if row["name"] in fx:
                v = fx[row["name"]]
                row["status"], stage = (v, None) if isinstance(v, str) else v
                if stage: row["stage"] = stage
    for m, n in NOW.items(): MOD[m]["now"] = n
    for m, n in NOW_FOREVER.items(): MOD[m]["nowF"] = n

TYPES = {"Sim": {"Fight style":"D","Targets":"S","Fight length (seconds)":"S","Use results for (days)":"S"},
         "Bugs": {"Reports kept":"S","Sound":"D","Minimap indicator":"D"}}
def apply2():
    for m, fx in TYPES.items():
        for row in MOD[m]["rows"]:
            if row["name"] in fx: row["type"] = fx[row["name"]]
    for row in MOD["Encounters"]["rows"]:
        row["weight"] = 61 if row["name"].startswith("Existing") else 1
