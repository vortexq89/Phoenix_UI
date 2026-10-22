#!/usr/bin/env python3
"""Generate docs/audit/API_FINDINGS.md from luacheck_summary.json (unknown globals vs 12.1.5 std)."""
import json, re, collections, sys
import os as _os
REF = _os.environ.get("PUI_REF", "/workspace/ref"); OUT=sys.argv[1] if len(sys.argv)>1 else "docs/audit/API_FINDINGS.md"
S=json.load(open(f"{REF}/luacheck_summary.json")); dep=json.load(open(f"{REF}/deprecated_12.1.5.json"))
loaded=set(l.strip() for l in open(f"{REF}/loaded_files.txt"))
M={ # removed/renamed API -> 12.1.5 replacement (verified against api_dump.tsv / FrameXML)
"GetSpellInfo":"C_Spell.GetSpellInfo(id) -> SpellInfo table (name, iconID, castTime, ...)",
"SafeGetSpellInfo":"addon helper wrapping removed GetSpellInfo -> C_Spell.GetSpellInfo",
"GetSpellTexture":"C_Spell.GetSpellTexture","GetSpellCooldown":"C_Spell.GetSpellCooldown (secret in restricted states; use Duration objects)",
"GetSpellCharges":"C_Spell.GetSpellCharges","GetSpellLink":"C_Spell.GetSpellLink","GetSpellDescription":"C_Spell.GetSpellDescription",
"GetSpellCastCount":"C_Spell.GetSpellCastCount","IsSpellInRange":"C_Spell.IsSpellInRange","GetSpellBookItemInfo":"C_SpellBook.GetSpellBookItemInfo",
"SpellBook_GetSpellBookSlot":"removed with old SpellBookFrame (PlayerSpellsFrame); use C_SpellBook",
"GetItemInfo":"C_Item.GetItemInfo","GetItemIcon":"C_Item.GetItemIconByID","GetItemIconByID":"C_Item.GetItemIconByID","GetItemGem":"C_Item.GetItemGem",
"GetItemSpell":"C_Item.GetItemSpell","GetItemQualityColor":"C_Item.GetItemQualityColor / ColorManager.GetColorDataForItemQuality",
"GetDetailedItemLevelInfo":"C_Item.GetDetailedItemLevelInfo","GetMerchantItemInfo":"C_MerchantFrame.GetItemInfo",
"GetTradeSkillReagentItemLink":"C_TradeSkillUI.GetRecipeFixedReagentItemLink","GetWeaponEnchantInfo":"C_PaperDollInfo.GetTemporaryEnchantmentInfo? (shim lives in deprecated addon; verify)",
"IsAddOnLoaded":"C_AddOns.IsAddOnLoaded","LoadAddOn":"C_AddOns.LoadAddOn","UIParentLoadAddOn":"C_AddOns.LoadAddOn","GetAddOnMetadata":"C_AddOns.GetAddOnMetadata",
"GetAddOnInfo":"C_AddOns.GetAddOnInfo","DisableAddOn":"C_AddOns.DisableAddOn (do not disable other addons at all)",
"UnitAura":"C_UnitAuras.GetAuraDataByIndex / GetUnitAuras (fields secret in restricted states)","UnitBuff":"C_UnitAuras.GetBuffDataByIndex","UnitDebuff":"C_UnitAuras.GetDebuffDataByIndex",
"GetMouseFocus":"GetMouseFoci()[1]","EasyMenu":"MenuUtil.CreateContextMenu",
"InterfaceOptions_AddCategory":"Settings.RegisterCanvasLayoutCategory + Settings.RegisterAddOnCategory","InterfaceOptionsFrame_OpenToCategory":"Settings.OpenToCategory(category:GetID())",
"InterfaceOptionsFrame":"SettingsPanel","InterfaceOptionsFramePanelContainer":"SettingsPanel (canvas layout)",
"GuildRoster":"C_GuildInfo.GuildRoster","RegisterAddonMessagePrefix":"C_ChatInfo.RegisterAddonMessagePrefix","GetZonePVPInfo":"C_PvP.GetZonePVPInfo",
"getglobal":"_G[name]","MouseIsOver":"region:IsMouseOver()","Arena_LoadUI":"C_AddOns.LoadAddOn('Blizzard_ArenaUI') — arena frames are Edit Mode/CompactArenaFrame now",
"GetTalentTabInfo":"Classic API — remove (C_SpecializationInfo.GetSpecializationInfo)","GetTalentGroupRole":"Classic API — GetSpecializationRole via C_SpecializationInfo",
"GetTrackingTexture":"C_Minimap.GetTrackingInfo","C_Console":"ConsoleGetAllCommands() (C_Console never existed)","C_FriendList_IsFriend":"typo — C_FriendList.IsFriend",
"FillLocalizedClassList":"LocalizedClassList()","ActionButton_ShowGrid":"button:ShowGrid(reason) (ActionButtonMixin)","ActionButton_HideGrid":"button:HideGrid(reason)",
"CastingBarFrame":"PlayerCastingBarFrame","CastingBarFrame_ApplyAlpha":"CastingBarMixin:ApplyAlpha","CombatText_UpdateDisplayedMessages":"Blizzard_CombatText is LoD; CVars floatingCombatText*_v2",
"CompactRaidFrameManager_SetSetting":"Edit Mode raid-frame settings (EditModeManagerFrame)","CompactRaidFrameContainer_SetGroupMode":"CompactRaidFrameContainer:SetGroupMode",
"DurabilityFrame_SetAlerts":"DurabilityFrame:SetAlerts()","ShowPetActionBar":"PetActionBar:Show()/Edit Mode","UpdateCooldownFrame":"undefined — use ActionButton_ApplyCooldown / CooldownFrame_Set",
"GameMovieFinished":"MovieFrame_OnMovieFinished","SetDesaturation":"texture:SetDesaturated(bool)","AnimateTexCoords":"removed — use FlipBook animations",
"IsLevelAtEffectiveMaxLevel":"IsPlayerAtEffectiveMaxLevel()","GetMinimapShape":"optional addon-provided global (fine if guarded)",
"NUM_STANCE_SLOTS":"Constants.ActionBarConsts? verify; use StanceBar.numButtons","MAX_GLOBAL_MACROS":"MAX_ACCOUNT_MACROS","MICRO_BUTTONS":"MicroMenu:GetLayoutChildren()",
"SHOW_MULTI_ACTIONBAR_3":"Settings / Edit Mode (MultiBar visibility CVar)","DebuffTypeColor":"DEBUFF_TYPE_*_COLOR / AuraUtil; dispel colours via C_CurveUtil colour curves",
"LE_ITEM_QUALITY_POOR":"Enum.ItemQuality.Poor","LE_ITEM_QUALITY_EPIC":"Enum.ItemQuality.Epic","LE_ITEM_CLASS_ARMOR":"Enum.ItemClass.Armor","LE_ITEM_CLASS_WEAPON":"Enum.ItemClass.Weapon",
"LE_ITEM_CLASS_QUESTITEM":"Enum.ItemClass.Questitem","LE_PARTY_CATEGORY_INSTANCE":"Enum.PartyCategory? verify / LE_PARTY_CATEGORY_* removed","LE_BATTLE_PET_ALLY":"Enum.BattlePetOwner.Ally",
"GAME_LOCALE":"GetLocale()","ConsolidatedBuffs":"removed (Legion)","SmallTextTooltip":"removed","ReloadUi":"typo — ReloadUI / C_UI.Reload","SaveVariables":"not an API — SavedVariables save on logout/reload only",
"TableInsert":"undefined — table.insert / tinsert","ChatUtils":"undefined","GeneralTab_ValidateProfileName":"undefined",
"WOW_PROJECT_BURNING_CRUSADE_CLASSIC":"Classic constant — drop Classic branches","WOW_PROJECT_WRATH_CLASSIC":"Classic constant — drop","WOW_PROJECT_CATACLYSM_CLASSIC":"Classic constant — drop",
"CombatLogGetCurrentEventInfo":"NONE for addons — COMBAT_LOG_EVENT_UNFILTERED registration is forbidden in 12.x (feature must be redesigned)",
"COMBATLOG_OBJECT_TYPE_PLAYER":"CLEU-only — feature redesign","COMBATLOG_OBJECT_TYPE_NPC":"CLEU-only","COMBATLOG_OBJECT_CONTROL_PLAYER":"CLEU-only","COMBATLOG_OBJECT_AFFILIATION_PARTY":"CLEU-only",
"SendChatMessage":"C_ChatInfo.SendChatMessage (blocked during encounter/M+/PvP lockdown)","FlushSavedVariables":"NEVER DEFINED — 174 call sites; delete (SavedVariables flush on logout/reload)","FlushSettingsDB":"NEVER DEFINED — delete",
"FixRaidTaint":"undefined","Phoenix":"undefined global (typo for Phoenix_UI / addon table)","Phoenix_UIDB":"SavedVariable read before ADDON_LOADED / outside AceDB — use db object",
}
for k,v in dep.items():
    if k not in M and v[0] and not v[0].startswith("(Lua shim"): M[k]=v[0]+f"  (was in {v[1]}, removed/not loaded)"
    elif k not in M: M[k]=f"shim only in {v[1]} — use the underlying C_ API"
THIRD={"DBM","BigWigsAPI","ElvUI","ElvUF_Parent","Questie_BaseFrame","QuestieConfig","RaiderIO","Grid2","Scorpio","LeaPlusDB","BT4StatusBarTrackingManager","CUSTOM_CLASS_COLORS","PremadeRegions","SpellNotifications","MSBTScrollAreasConfigFrame"}
cats=collections.OrderedDict((c,[]) for c in ["Removed / renamed API (needs replacement)","Combat-log (cannot survive Midnight)","Undefined addon functions (runtime errors)","Undefined local / scoping bugs","Third-party addon globals (must be optional + guarded)","Removed Blizzard frames/regions (legacy skin targets)","Other unknown (verify)"])
for name,refs in sorted(S["unknown"].items()):
    if name in THIRD: c="Third-party addon globals (must be optional + guarded)"
    elif "COMBATLOG" in name or name=="CombatLogGetCurrentEventInfo": c="Combat-log (cannot survive Midnight)"
    elif name in("FlushSavedVariables","FlushSettingsDB","FixRaidTaint","TableInsert","ChatUtils","GeneralTab_ValidateProfileName","UpdateCooldownFrame","SaveVariables","ReloadUi","Phoenix","SafeGetSpellInfo","C_FriendList_IsFriend","combatDropUpdate","copyFunc","hideStatic") or name.startswith("MA"): c="Undefined addon functions (runtime errors)"
    elif name in M: c="Removed / renamed API (needs replacement)"
    elif name[0].islower() or name in("L","EL","CH"): c="Undefined local / scoping bugs"
    elif re.search(r'(Frame|Button|Bar|Texture|Inset|Tab\d|Border|Bg|Left|Right|Mid|Middle|Top|Bottom|Cap|Text|Slot\w*|\d)$',name) or re.search(r'Frame|Journal|Tooltip|Minimap|MiniMap',name): c="Removed Blizzard frames/regions (legacy skin targets)"
    else: c="Other unknown (verify)"
    cats[c].append((name,refs))
o=["# API findings — unknown globals vs. WoW 12.1.5 (build 70448)","",
"Generated by `tools/audit/gen_api_appendix.py` from luacheck 1.2.0 run with the generated `wow_std_12.1.5` std",
"(C API from Blizzard_APIDocumentationGenerated + mainline FrameXML + GlobalStrings; Blizzard_Deprecated* excluded).",
"`[dead]` = file is not loaded by any TOC/XML (dead code). Line numbers are 1-based.",""]
tot=sum(len(v) for v in S["unknown"].values())
o.append(f"Total: **{len(S['unknown'])} unknown global names, {tot} references.**\n")
o.append("| Category | Names | Refs |\n|---|---:|---:|")
for c,l in cats.items(): o.append(f"| {c} | {len(l)} | {sum(len(r) for _,r in l)} |")
def fmt(refs):
    seen=[];
    for r in refs:
        if r not in seen: seen.append(r)
    out=[]
    for r in seen[:12]:
        f=r.rsplit(":",1)[0]; out.append(f"`{r}`"+("" if f in loaded else " [dead]"))
    if len(seen)>12: out.append(f"… +{len(seen)-12} more")
    return ", ".join(out)
for c,l in cats.items():
    o.append(f"\n## {c} ({len(l)})\n")
    if c.startswith("Removed Blizzard frames"):
        byfile=collections.Counter(r.rsplit(":",1)[0] for _,refs in l for r in refs)
        o.append("These are pre-Dragonflight/Classic frame names. They come almost entirely from the legacy skin code; the rewrite skins by **mixin/parentKey** instead of global names.\n")
        o.append("| File | Refs |\n|---|---:|")
        for f,n in byfile.most_common(): o.append(f"| `{f}`{'' if f in loaded else ' [dead]'} | {n} |")
        o.append("\nNames: "+", ".join(f"`{n}`" for n,_ in l)); continue
    o.append("| Global | Refs | Replacement / note | Locations |\n|---|---:|---|---|")
    for n,refs in sorted(l,key=lambda x:-len(x[1])):
        o.append(f"| `{n}` | {len(refs)} | {M.get(n,'—')} | {fmt(refs)} |")
o.append("\n## Removed / non-existent C_ namespace fields (W143)\n")
F={"C_Scenario.GetCriteriaInfo":"C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)","C_Scenario.GetNumStages":"C_ScenarioInfo.GetScenarioInfo().numStages? (verify) — or C_Scenario.GetInfo",
"C_Scenario.GetNumCriteria":"C_ScenarioInfo.GetScenarioStepInfo().numCriteria","C_PlayerInfo.GetUnitByGUID":"UnitTokenFromGUID(guid) (GUIDs are secret in instances)",
"C_PlayerInfo.GetPlayerItemLevel":"GetAverageItemLevel() (player) / C_PaperDollInfo.GetInspectItemLevel(unit)","C_PaperDollInfo.GetUnitItemLevel":"C_PaperDollInfo.GetInspectItemLevel(unit)",
"C_PaperDollInfo.GetAverageItemLevel":"GetAverageItemLevel()","C_Item.GetInventoryItemDurability":"GetInventoryItemDurability(slot)","C_Item.GetInventoryItemQuality":"GetInventoryItemQuality(unit, slot)",
"C_DeathInfo.GetCombatResurrectionCharges":"C_Spell.GetSpellCharges(20484) (combat-res spells are whitelisted non-secret)","C_GossipInfo.GetNumOptions":"#C_GossipInfo.GetOptions()",
"C_TradeSkillUI.GetRecipeReagentItemLink":"C_TradeSkillUI.GetRecipeFixedReagentItemLink","C_ChallengeMode.GetCompletionTime":"C_ChallengeMode.GetChallengeCompletionInfo()",
"C_ChallengeMode.IsCompletionTimerActive":"C_ChallengeMode.IsChallengeModeActive() + GetWorldElapsedTime(1)","C_PetBattles.GetPetInfoBySpeciesID":"C_PetJournal.GetPetInfoBySpeciesID"}
o.append("| Field | Replacement | Locations |\n|---|---|---|")
for k,v in S["fields"].items():
    if k.startswith("module."): continue
    o.append(f"| `{k}` | {F.get(k,'verify')} | {fmt(v)} |")
o.append("\n## Writes to Blizzard / shared globals (taint & collision risk, W121/W122)\n")
o.append("| Global written | Locations |\n|---|---|")
own=set(S["defs"])
for k,v in sorted(S["set"].items(), key=lambda x:-len(x[1])):
    if k.split(".")[0] in ("Phoenix_UI","Phoenix_UIDB","Phoenix_UIPerCharDB"): continue
    o.append(f"| `{k}` | {fmt(v)} |")
open(OUT,"w").write("\n".join(o)+"\n"); print("wrote",OUT,len(o),"lines")
