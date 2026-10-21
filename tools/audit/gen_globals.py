#!/usr/bin/env python3
"""Generate a luacheck std definition of every global known to exist in the
WoW Retail 12.1.5 client (C API + FrameXML Lua + XML frames + GlobalStrings).
Sources: wow-ui-source (live 12.1.5.70448), Blizzard_APIDocumentationGenerated dump,
BlizzardInterfaceResources (12.1.0 C GlobalAPI, GlobalStrings)."""
import re, os, json, collections
import os as _os
REF = _os.environ.get("PUI_REF", "/workspace/ref")
SRC = f"{REF}/wow-ui-source/Interface"
plain = set()
fields = collections.defaultdict(set)
loose_tables = set()

def add(name):
    if "." in name:
        t, f = name.split(".", 1)
        if "." in f or ":" in f:
            loose_tables.add(t); plain.add(t); return
        fields[t].add(f)
    else:
        plain.add(name)

# 1. C API from 12.1.5 generated docs
for line in open(f"{REF}/api_dump.tsv"):
    kind, name, _ = line.rstrip("\n").split("\t")
    if kind == "func": add(name)
    elif kind == "enum": fields["Enum"].add(name.split(".",1)[1])
# 2. C GlobalAPI (12.1.0) - engine globals not in docs (CreateFrame, strsplit, ...)
for m in re.finditer(r'"([^"]+)"', open(f"{REF}/bir/Resources/GlobalAPI.lua").read()):
    add(m.group(1))
# 3. FrameXML Lua 12.1.5: top-level functions / assignments, dotted functions
SKIP=('Blizzard_Deprecated','Deprecated_PaperDoll')
rx_func = re.compile(r'^function\s+([A-Za-z_][\w]*(?:\.[A-Za-z_]\w*)?)\s*\(', re.M)
rx_asg = re.compile(r'^([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*=(?!=)', re.M)
MAIN = [l.strip() for l in open(f"{REF}/mainline_files.txt") if l.strip()]
for _one in [0]:
    for p in MAIN:
        if any(x in p for x in SKIP): continue
        fn = os.path.basename(p)
        if fn.endswith(".lua"):
            s = open(p, encoding="utf-8", errors="ignore").read()
            for m in rx_func.finditer(s): add(m.group(1))
            for m in rx_asg.finditer(s): add(m.group(1))
            for m in re.finditer(r'^\s+([A-Z][A-Z0-9_]{2,})\s*=(?!=)', s, re.M): add(m.group(1))
            for m in re.finditer(r'\b([A-Z][A-Z0-9_]*_COLOR(?:_CODE)?)\b', s): add(m.group(1))  # C_UIColor DB colours
        elif fn.endswith(".xml"):
            s = open(p, encoding="utf-8", errors="ignore").read()
            for m in re.finditer(r'^\s*([A-Z_][A-Z0-9_]*)\s*=\s*[^"\s]', s, re.M): add(m.group(1))
            for m in re.finditer(r'<(?:FontFamily|Frame|Button|CheckButton|StatusBar|ScrollFrame|EditBox|Slider|GameTooltip|MessageFrame|ScrollingMessageFrame|Cooldown|Model|PlayerModel|DressUpModel|ModelScene|SimpleHTML|ColorSelect|MovieFrame|Minimap|Texture|FontString|Font|ItemButton|DropdownButton|EventFrame|EventButton)\b[^>]*\bname="([A-Za-z_]\w*)"', s):
                add(m.group(1))
# 4. Frames / Mixins (12.1.0 dump), GlobalStrings enUS
for res in ("Frames.lua", "Mixins.lua"):
    for m in re.finditer(r'"([^"]+)"', open(f"{REF}/bir/Resources/{res}").read()):
        add(m.group(1))
for m in re.finditer(r'^\s*([A-Z_][A-Z0-9_]*)\s*=', open(f"{REF}/bir/Resources/GlobalStrings/enUS.lua").read(), re.M):
    plain.add(m.group(1))
gs = open(f"{REF}/bir/Resources/GlobalStrings/enUS.lua").read()
for m in re.finditer(r'\["?([A-Za-z_][\w]*)"?\]\s*=', gs): plain.add(m.group(1))
# Lua extras always present in WoW
plain.update("""strsplit strjoin strtrim strconcat strlenutf8 strcmputf8i strmatch strfind strsub strlen strlower strupper strrep strrev strbyte strchar format gsub gmatch
tinsert tremove tContains wipe sort foreach foreachi getn table string math bit floor ceil abs max min mod random fastrandom sqrt
debugstack debugprofilestop issecure issecurevariable securecall securecallfunction secureexecuterange forceinsecure hooksecurefunc geterrorhandler seterrorhandler
date time difftime GetTime select type pairs ipairs next unpack tostring tonumber rawget rawset rawequal setmetatable getmetatable error assert pcall xpcall
loadstring print _G Enum Constants FONT_COLOR_CODE_CLOSE scrubsecretvalues issecretvalue canaccessvalue""".split())
plain.discard("")
# Deprecated aliases removed in 12.1.5 must NOT be known (they were in 12.1.0 C/Lua dumps only via Deprecated addons)
removed_1215 = """GetCoinIcon GetCoinText GetCoinTextureString IsOnGlueScreen GetItemQualityColor GetItemInfoInstant GetItemSetInfo GetItemChildInfo DoesItemContainSpec GetItemGem
GetItemCreationContext GetItemIcon GetItemFamily GetItemSpell IsArtifactPowerItem IsCurrentItem IsUsableItem IsHelpfulItem IsHarmfulItem IsConsumableItem IsEquippableItem
IsEquippedItem IsEquippedItemType ItemHasRange IsItemInRange GetItemClassInfo GetItemInventorySlotInfo BindEnchant ActionBindsItem ReplaceEnchant ReplaceTradeEnchant
ConfirmBindOnUse ConfirmOnUse ConfirmNoRefundOnUse DropItemOnUnit EndBoundTradeable EndRefund GetItemInfo GetDetailedItemLevelInfo GetItemSpecInfo GetItemUniqueness
GetItemCount PickupItem GetItemSubClassInfo UseItemByName EquipItemByName ReplaceTradeskillEnchant GetItemCooldown IsCorruptedItem IsCosmeticItem IsDressableItem
CloseSocketInfo GetSocketItemInfo GetNumSockets GetExistingSocketInfo GetExistingSocketLink GetNewSocketInfo GetNewSocketLink ClickSocketButton AcceptSockets GetSocketTypes
GetSocketItemRefundable GetSocketItemBoundTradeable HasBoundGemProposed PetAssistMode GetPetTalentTree IsSubZonePVPPOI GetZonePVPInfo TogglePVP SetPVP PlayVocalErrorSoundID
PickupTradeMoney""".split()
for r in removed_1215: plain.discard(r)
fields["C_LFGInfo"].discard("IsPremadeGroupEnabled"); fields["C_LFGList"].discard("GetSearchResultMemberInfo")
# Is each removed name still defined anywhere in 12.1.5 source? (sanity)
dep=json.load(open(f"{REF}/deprecated_12.1.5.json"))
for k in dep:
    if '.' in k:
        t,f2=k.split('.',1); fields[t].discard(f2)
    else: plain.discard(k)
out = {"plain": sorted(plain), "fields": {k: sorted(v) for k, v in fields.items()}, "loose": sorted(loose_tables)}
json.dump(out, open(f"{REF}/wow_globals_12.1.5.json", "w"), indent=0)
# luacheck std file
with open(f"{REF}/wow_std_12.1.5.lua", "w") as f:
    f.write("-- Auto-generated by tools/audit/gen_globals.py for WoW Retail 12.1.5.70448 (TOC 120105)\nreturn {\n read_globals = {\n")
    for k, v in sorted(fields.items()):
        plain.discard(k)
        other = "true" if (not k.startswith("C_") or k in loose_tables) else "false"
        f.write(f'  ["{k}"] = {{ other_fields = {other}, fields = {{' + ",".join(f'"{x}"' for x in sorted(v)) + "} },\n")
    for k in sorted(plain):
        if re.match(r'^[A-Za-z_]\w*$', k): f.write(f'  "{k}",\n')
    f.write(" }\n}\n")
print(len(plain), "plain;", len(fields), "tables;", sum(len(v) for v in fields.values()), "fields")
