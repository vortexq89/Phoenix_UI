"""Feature-parity audit (2026-10-22): every user-facing feature of every addon on the user's I:\\ drive, mapped to
the one Phoenix page that owns it. Source of truth for docs/plan_v2/PARITY.md and the 'source addon' column of
GAP_MATRIX.md / gap.json (gen_gap.py imports this file).

F(addon, keys, feature, owner, status, note="", stage=None, n=None)
  addon   source addon (folder family on I:\\)
  keys    inventory keys "<file stem>::<section>" from the box-only option dump (tools: audit extractor), each
          optionally "~regex" to take only matching option labels; n is counted from the dump and frozen in
          parity.json, or given by hand for addons whose options are not in table form
  feature our own wording (no third-party strings are copied)
  owner   Phoenix page key (module) that owns the feature; one owner per feature
  status  done · part (Phoenix has a shallower form) · miss (not built) · imp (not possible in 12.x / 1.60, the
          note gives the exact API reason) · skip (decided not to build: scope cut or addon-internal tooling)
  stage   plan stage that builds a part/miss row (S17 = current, S18+ = PLAN_V2 §5b)
"""
FEATURES = []


def F(addon, keys, feature, owner, status, note="", stage=None, n=None):
    if isinstance(keys, str):
        keys = [keys] if keys else []
    FEATURES.append(dict(addon=addon, keys=keys, feature=feature, owner=owner, status=status, note=note,
                         stage=stage, n=n))


A = "EllesmereUI ActionBars"
F(A, "AnimationsPage::", "Button press / hover / cast animations, assisted-highlight ring, interaction colours", "ActionBars", "part",
  "Pressed/mouseover looks, assisted highlight and cast-animation hiding exist; class-coloured interaction colour and ring fit on cropped buttons do not", "S26")
F(A, "BarAppearance::BAR BACKGROUND", "Bar backdrop, border, custom button shape, icon zoom, cooldown numbers per bar", "ActionBars", "done")
F(A, "BarAppearance::ICON EFFECTS~Hide Charge", "Hide the charge count at zero charges", "ActionBars", "imp",
  "Action charge counts are secret values in combat (C_Spell.GetSpellCharges returns secrets); Phoenix can only pass them to a FontString, not compare them with 0")
F(A, "BarAppearance::ICON EFFECTS~Item Rank", "Crafted-quality rank pip on item buttons", "ActionBars", "miss", "", "S26")
F(A, "BarAppearance::ICON EFFECTS", "Desaturate on cooldown, range colouring, alpha on cooldown, swipe opacity, equipped border, tooltips", "ActionBars", "done")
F(A, "BarAppearance::PAGING", "Form / skyriding / modifier paging, page arrows, keybind / macro / charge text", "ActionBars", "done")
F(A, "BarVisibilityLayout::", "Per-bar layout (icons, rows, size, spacing, growth, order) and visibility (spellbook, drag, mouseover, click-through)", "ActionBars", "done")
F(A, "MenuBagsRepPage::", "Micro menu, bag bar and reputation bar layout (orientation, text, texture)", "ActionBars", "part",
  "Phoenix shows/hides the menu and bag buttons; their layout belongs to Edit Mode. Rep bar text/texture is on Data Texts", "S28")
F(A, "XPBarPage::", "Experience bar: dividers, 5 % lines, rested, quest-XP overlay, gain animation", "DataTexts", "part",
  "Bar, rested and text exist; dividers, quest-XP overlay (C_QuestLog.GetQuestLogRewardXP) and gain animation do not", "S28")
F(A, "EUI_ActionBars::", "Action bar art and its size / offsets", "ActionBars", "done")
F(A, "EllesmereUI::", "Global action-button skin: modern styling, keybind text, scale, combat / zone visibility", "ActionBars", "done")

A = "EllesmereUI CooldownManager"
F(A, ["BarsPage::BAR LAYOUT", "BarsPage::ADDITIONAL BAR OFFSET"], "Cooldown viewer rows, base / second row sizes, overflow, fade, keep places", "Tracker", "done")
F(A, "BarsPage::ICON DISPLAY", "Cooldown icon look: shape, zoom, border, duration / stack text, item count and quality, numbers-only mode", "Tracker", "part",
  "Numbers-only (no icon) mode and item quality on icons are missing", "S20")
F(A, "BarsPage::EXTRAS", "Viewer extras: trinkets, tooltips, keybinds, rotation helper, mirror key presses, potion swap, glows only in combat", "Tracker", "part",
  "Trinkets, tooltips and keybinds exist; key-press mirroring, potion swap and in-combat-only glows do not", "S20")
F(A, "BarsPage::FocusKick Options", "Focus interrupt reminder: text near the focus plate, focus cast sound, interrupt spell", "NamePlates", "part",
  "Focus marker exists; the focus cast sound and reminder text do not", "S20")
F(A, "EUI_CooldownManager::ROTATION ASSIST ICON", "Rotation assist icon (C_AssistedCombat) with keybind and GCD", "Tracker", "miss", "", "S20")
F(A, ["EUI_CooldownManager::", "EUI_CooldownManager_BarGlowConditions::"], "Glow conditions: at N stacks, only in combat, by hero talent; text and background per tracked spell", "Tracker", "miss",
  "Stack counts of tracked auras are secret in combat, so 'glow at N stacks' needs the viewer's own alert events (verify in game)", "S20")
F(A, "SpellPicker::", "Per-spell overrides in the spell picker (duration, glow at stacks, size, colour)", "Tracker", "part",
  "Phoenix picks spells; per-spell overrides are missing", "S20")
F(A, "BuffBarsPage::GROUP SETTINGS", "Buff bar groups (named groups, auto-add, global group, shift when empty)", "Tracker", "miss", "", "S20")
F(A, "BuffBarsPage::BAR LAYOUT", "Buff bar size, texture, texts, timer decimals, reverse fill, charge hash lines, smooth bars", "Tracker", "part",
  "Smooth fill and gradient are open gap rows; hash lines and partial-charge shade are missing", "S20")
F(A, "BuffBarsPage::Display", "Buff bar icon, opacity, colours, spark, border", "Tracker", "done")
F(A, "BuffBarsPage::EXTRAS", "Stack-based bar fill with max / threshold", "Tracker", "miss",
  "Needs plain stack counts; the viewer's aura applications are secret in restricted content, so this may end as api after the in-game check", "S17")

A = "EllesmereUI AuraBuffReminders"
F(A, "EUI_AuraBuffReminders::", "Missing-buff reminders: custom spells, sounds, where shown, scale, cursor attach, M+ beacon, well fed / camp", "Tracker", "part",
  "Phoenix Reminders has flask, food, rune, raid buff, weapon oil, pet, healthstone and mana; custom spells, cursor attach and position presets are missing", "S20")
F(A, "EUI_AuraBuffReminders::PETS", "Pet reminders (missing / passive / wrong demon), soulstone, consumables without item", "Tracker", "part",
  "Pet reminder exists; passive / wrong-demon and soulstone checks are missing", "S20")

A = "EllesmereUI Bags"
F(A, ["EUI_Bags::LAYOUT", "EUI_Bags::DISPLAY"], "Bag window style, scale, strata, auto size, bank display", "Bags", "done")
F(A, "EUI_Bags::DISPLAY (GRID / COMPACT)", "Grid view: item level, gear track rank, BoE / warbound label, set name", "Bags", "part",
  "Item level and bind label exist; track rank and set name do not", "S23")
F(A, "EUI_Bags::DISPLAY (LIST)", "List view of bags (rows with names, gold value per section)", "Bags", "miss", "", "S23")
F(A, ["EUI_Bags::SIDEBAR", "EUI_Bags::GROUPING"], "Category sidebar, nest by expansion, group by category", "Bags", "part", "Categories exist; sidebar and expansion nesting do not", "S23")
F(A, "EUI_Bags::CATEGORIES", "Pinned and recent items, custom categories, empty-category hiding", "Bags", "part", "", "S23")
F(A, "EUI_Bags::EXTRAS", "Merge stacks, gear by slot, gold history, stack splitter, quality borders, open with character", "Bags", "part",
  "Quality borders exist; merge view, gold history and splitter do not", "S23")

A = "EllesmereUI BlizzardSkin"
F(A, ["EUI_BlizzardSkin::BLIZZARD POPUPS & GAME MENU", "EUI_BlizzardSkin::"], "Popups and game menu reskin, resurrect-accept glow", "Skins", "done")
F(A, "EUI_BlizzardSkin::BLIZZARD TOOLTIP~Player Buffs|Icon Size|Icons Per Row", "Tooltip: the unit's buffs as icons", "Tooltip", "miss",
  "C_UnitAuras on other units is secret in combat; out of combat the icons can be drawn", "S24")
F(A, "EUI_BlizzardSkin::BLIZZARD TOOLTIP", "Tooltip reskin, anchor, modifier peek, IDs, max stack, health strip", "Tooltip", "done")
F(A, "EUI_BlizzardSkin::BLIZZARD BARS, POPUPS & BUTTONS~Widget|Extra Action|Queue|Minimum|Bar Height|Text Offset|Icon Zoom", "Widget bars, extra action button and queue pop-up skin with queue timer", "Skins", "part",
  "Extra action skin exists (Action Bars); widget bars and queue timer on the LFG pop-up do not", "S24")
F(A, "EUI_BlizzardSkin::BLIZZARD BARS, POPUPS & BUTTONS~Rating|Socket|Stat|Enchant|Durability|Season|Location|Label|Vault|Item Level|Tertiary|Flyout|Diminishing|Mana|Crests|UI Color|Secondary|Inspect|Upgrade", "Character and inspect sheet: stat letters, enchants, durability, crests, season panel, M+ rating, vault shortcut", "ItemLevel", "part",
  "Item level, upgrade track, enchant text and sockets exist; stats-panel restyle, durability, crests and season panel do not", "S23")
F(A, "EUI_BlizzardSkin::BLIZZARD BARS, POPUPS & BUTTONS~Sign-Up|Class Icon|Friend|Guildmates|List|Row Height|Bulk|Quality Strip|Gold Toast|Toast", "Friends list look, sign-up roles memory, merchant list view and bulk buy, gold / loot toasts", "Skins", "miss",
  "Remembered sign-up roles exist on Group Finder; the rest is missing", "S24")
F(A, "EUI_BlizzardSkin::BLIZZARD BARS, POPUPS & BUTTONS", "Other Blizzard bars and buttons", "Skins", "part", "", "S24")
F(A, "EUI_BlizzardSkin::THIRD-PARTY ADDONS", "Skin third-party addons", "Skins", "part", "Details! and BigWigs are styled; a general third-party skin list is missing", "S24")
F(A, "EUI_BlizzardSkin::GLOBAL OPTIONS", "Accent bar, bar fill opacity, link colour", "General", "done")
F(A, ["EUI_BlizzardSkin::DISPLAY", "EUI_BlizzardSkin::APPEARANCE"], "Chat bubble skin (font, border, padding, speaker name)", "Skins", "part",
  "Open world only: chat bubbles inside instances are forbidden frames in 12.x (C_ChatBubbles returns none, GetChildren of WorldFrame is blocked), so 'in instances' is impossible", "S24")
F(A, ["EUI_BlizzardSkin::GENERAL", "EUI_BlizzardSkin::LAYOUT", "EUI_BlizzardSkin::SPEED BAR"], "Skyriding vigor and speed bar (charges, second wind, whirling surge, thrill colour, sound on full)", "Skins", "miss", "", "S17")

A = "EllesmereUI Chat"
F(A, ["EUI_Chat::DISPLAY", "EUI_Chat::TYPOGRAPHY", "EUI_Chat::BORDER", "EUI_Chat::INPUT FIELD"], "Chat panel look, fonts, border, edit box", "Chat", "done")
F(A, "EUI_Chat::IDLE FADE", "Idle fade of the chat panel", "Chat", "done")
F(A, ["EUI_Chat::SIDEBAR", "EUI_Chat::ICONS"], "Chat sidebar with icon buttons (side, width, icons, free move)", "Chat", "part", "Chat bar and side buttons exist; the sidebar layout does not", "S24")
F(A, ["EUI_Chat::LAYOUT", "EUI_Chat::APPEARANCE"], "Tabs inside the panel, tab height / spacing / background / underline / texture", "Chat", "part", "Tab font and colours exist; tabs-inside layout and tab textures do not", "S24")
F(A, "EUI_Chat::EXTRAS~Remember Last", "Restore the last chat lines after /reload", "Chat", "miss", "", "S24")
F(A, "EUI_Chat::EXTRAS", "Max lines, hide borders, whisper sound, timestamps, short channels, class colours", "Chat", "done")

A = "EllesmereUI (core pages)"
F(A, "EUI_Colors::DARK MODE", "Dark mode for all frames with darkening amount", "General", "part", "Per-module dark bars exist; one global dark mode does not", "S28")
F(A, ["EUI_Fonts::", "EUI_Fonts::GLOBAL FONT"], "Global and per-module fonts", "General", "done")
F(A, "EUI_Textures::", "Global and per-module textures", "General", "done")
F(A, ["EllesmereUI_GlowOptions::", "EUI_Glows::"], "Glow type and parameters (lines, thickness, speed)", "General", "part", "Glow colour exists; glow type parameters are an open gap row", "S28")
F(A, "EUI__General::DISPLAY", "UI accent colour, UI scale, options theme / language", "General", "done")
F(A, "EUI__General::COMBAT", "Camera distance, image quality, cast on key down, lag tolerance, combat text font", "Quality", "done")
F(A, "EUI__General::DEVELOPER", "Suppress Lua errors, spell IDs", "Bugs", "done")
F(A, ["EllesmereUI_Widgets::", "EllesmereUI_Widgets_CogPopup::", "EllesmereUI_Widgets_Color::", "EllesmereUI_Widgets_PageParts::",
      "EllesmereUI_Widgets_Rows::", "EllesmereUI_Widgets_Visibility::", "EllesmereUI_UICore::", "EllesmereUI_RoundedCorners::", "EUI_Style::"],
  "Shared widget kit rows (cog pop-ups, colour, visibility, rounded corners)", "General", "done", "Phoenix's own options kit covers these patterns")
F(A, "EllesmereUI_Widgets_RowAddons::", "Top name bar / anchor to cursor row add-ons", "GroupFrames", "miss", "", "S19")
F(A, "EUI_SimpleLootCouncil::", "Simple loot council", "Quality", "skip", "Raid-leading tool that needs group addon comms; out of Phoenix's scope")
F(A, "EUI_Gamepad::", "Gamepad mode: hide action bars / cast bars", "Quality", "miss", "", "S26")
F(A, "EUI_UpgradeCalc::", "Crest upgrade calculator window", "ItemLevel", "miss", "C_ItemUpgrade and crest currencies are readable", "S23")
F(A, ["EUI_LoadoutManager::GENERAL", "EUI_LoadoutManager::SELECTED LOADOUT", "EUI_LoadoutManager::INSTANCES"], "Loadout manager: talents + gear set per instance, auto-swap, warn on change", "Loadouts", "miss",
  "C_ClassTalents.LoadConfig and C_EquipmentSet.UseEquipmentSet work out of combat; swaps queue until combat ends", "S28")
F(A, ["EUI_PartyMode::PARTY MODE", "EUI_PartyMode::CELEBRATION TRIGGERS"], "Party mode celebrations (bloodlust, timed key, boss kills, rated wins)", "Quality", "miss", "", "S26")

A = "EllesmereUI DamageMeters"
F(A, ["EUI_DamageMeters::DISPLAY", "EUI_DamageMeters::HEADER", "EUI_DamageMeters::EXTRAS"], "Meter window: refresh, header, always show player, reset button, spell tooltips", "DamageMeter", "part",
  "Refresh rate is the game's (C_DamageMeter); header and window styling partly exist", "S28")
F(A, ["EUI_DamageMeters::BARS", "EUI_DamageMeters::BAR TEXT"], "Meter bars and text: icons, borders, breakdown on hover, number format, rank numbers", "DamageMeter", "part", "", "S28")
F(A, "EUI_DamageMeters::STANDALONE COMBAT TIMER", "Standalone combat timer", "DamageMeter", "miss", "", "S28")
F(A, "EUI_DamageMeters::ICON HISTORY", "Spell icon history", "SpellHistory", "done")
F(A, "EUI_DamageMeters::BAR HISTORY", "Spell history as bars", "SpellHistory", "miss", "", "S28")

A = "EllesmereUI ForeverEssentials"
F(A, "EUI_ForeverEssentials_General::SPELL RANKS", "WoW Forever: put the highest spell rank on your bars after training", "ActionBars", "miss", "Out of combat only (PlaceAction is protected)", "S27")
F(A, "EUI_ForeverEssentials_General::WORLD MAP", "World map: fade while moving, reveal unexplored, zone levels, map markers", "Minimap", "miss",
  "Reveal needs WorldMapOverlay data from DB2 (generated, like quest data)", "S25")
F(A, "EUI_ForeverEssentials_General::CLASSIC WINDOWS", "WoW Forever: classic-style spellbook and talent windows", "Skins", "skip", "A replacement for Blizzard's protected spellbook / talent windows; too large and taint-prone for a skin layer")
F(A, "EUI_ForeverEssentials_General::SIMPLIFIED STATS", "Shorter stat lines on item tooltips", "Tooltip", "miss", "", "S27")
F(A, "EUI_ForeverEssentials_General::QUEST REWARDS", "Pick the most valuable quest reward", "Quests", "done")
F(A, "EUI_ForeverEssentials_General::COMPANION PETS", "Auto-summon a favourite companion pet", "Automation", "miss", "Out of combat (C_PetJournal.SummonPetByGUID)", "S27")
F(A, "EUI_ForeverEssentials_General::ACTIVE STANCE, FORM, ASPECT & AURA", "Icon for the active stance / form / aspect", "UnitFrames", "miss", "", "S27")
F(A, "EUI_ForeverEssentials_General::NAME FORMAT", "Name format", "UnitFrames", "done")
F(A, "EUI_ForeverEssentials_General::GATHERING", "Gathering skill in node tooltips and minimap", "Tooltip", "miss", "", "S27")
F(A, "EUI_ForeverEssentials_General::JUNK ITEMS", "Junk window (items, prices, confirm skip, low-space trigger)", "Bags", "part", "Sell junk exists; the junk window does not", "S27")
F(A, "EUI_ForeverEssentials_General::FISHING", "Double-click to fish, fishing sounds", "Quality", "miss", "Needs a secure override binding set out of combat (SetOverrideBindingClick)", "S27")
F(A, ["EUI_ForeverEssentials_Loot::", "EUI_ForeverEssentials_Loot::LOOT FEED", "EUI_ForeverEssentials_Loot::ITEMS",
      "EUI_ForeverEssentials_Loot::LAYOUT", "EUI_ForeverEssentials_Loot::DISPLAY"], "Loot feed (style, quality filter, growth)", "Quality", "miss", "", "S27")
F(A, ["EUI_ForeverEssentials_Macros::", "EUI_ForeverEssentials_Macros::LINES", "EUI_ForeverEssentials_Macros::MACRO"], "Macro manager", "Quality", "miss",
  "EditMacro / CreateMacro are out-of-combat only", "S27")
F(A, ["EUI_ForeverEssentials_Threat::", "EUI_ForeverEssentials_Threat::THREAT METER", "EUI_ForeverEssentials_Threat::WARNING",
      "EUI_ForeverEssentials_Threat::THREAT % TEXT", "EUI_ForeverEssentials_Threat::BARS", "EUI_ForeverEssentials_Threat::HEADER",
      "EUI_ForeverEssentials_Threat::COLORS", "EUI_ForeverEssentials_Threat::BAR TEXT", "EUI_ForeverEssentials_Threat::WINDOW & BORDERS"],
  "WoW Forever threat meter (bars, warning sound, threat % text)", "DamageMeter", "miss", "UnitDetailedThreatSituation is plain on Forever", "S27")
F(A, ["EUI_ForeverEssentials_Travel::", "EUI_ForeverEssentials_Travel::FLIGHT TIMER", "EUI_ForeverEssentials_Travel::LAYOUT",
      "EUI_ForeverEssentials_Travel::DISPLAY"], "Flight timer bar and travel pins (from DB2 TaxiNodes / AreaPOI)", "Minimap", "miss",
  "Flight times come from a build-time DB2 script, like EUI's own", "S25")

A = "EllesmereUI Friends"
F(A, "EUI_Friends::DISPLAY", "Friends list: class icons, class colours, faction banners, region icons, auto-accept friend invites", "Skins", "part",
  "Accept invites from friends exists (Automation); the friends-list look does not", "S24")

A = "EllesmereUI GroupFinder"
F(A, ["EUI_GroupFinder::GROUP FINDER", "EUI_GroupFinder::APPLICATIONS"], "Applications counter bar in the group finder", "GroupFinder", "part", "", "S28")

A = "EllesmereUI Minimap"
F(A, "EUI_Minimap::", "Minimap shape, size, border, zoom reset, rotate", "Minimap", "done")
F(A, "EUI_Minimap::MINIMAP & QOL BUTTONS", "Addon button bar, extra buttons, M+ portals, friends tooltip, middle-click micro menu", "Minimap", "part",
  "Button bin exists; M+ portal buttons, friends tooltip and middle-click menu do not", "S25")
F(A, "EUI_Minimap::BLIZZARD ELEMENTS", "Blizzard minimap elements: compartment, mail, folio, scroll zoom", "Minimap", "done")
F(A, "EUI_Minimap::TEXT", "Clock, zone, coordinates, FPS / MS and difficulty text on the minimap", "Minimap", "done")

A = "EllesmereUI MythicTimer"
F(A, ["EUI_MythicTimer::DISPLAY", "EUI_MythicTimer::TITLE AND AFFIXES", "EUI_MythicTimer::TIMER", "EUI_MythicTimer::TIMER BAR",
      "EUI_MythicTimer::THRESHOLDS", "EUI_MythicTimer::FORCES", "EUI_MythicTimer::BOSS OBJECTIVES"], "Mythic+ timer: title, affixes, timer bar, chest thresholds, forces, boss splits", "MythicPlus", "done")
F(A, "EUI_MythicTimer::TARGETED SPELL BARS", "Bars for enemy casts aimed at you / your group", "CastBars", "miss",
  "UnitSpellTargetName / Class return secrets, so the target name can be shown but Phoenix cannot filter 'aimed at me' by comparing it; S28 checks in game what UnitIsUnit allows (secret when unit comparison is restricted) and may close this as impossible", "S28")
F(A, ["EUI_MythicTimer::INTERRUPT AND VISIBILITY", "EUI_MythicTimer::CAST COLORS AND EFFECTS"], "Focus / enemy cast bar extras: kick-ready hint, raid marker, interrupt range fade", "CastBars", "part", "", "S28")
F(A, ["EUI_MythicTimer::RUN SUMMARY", "EUI_MythicTimer::COLUMNS"], "Run summary window (spec, item level, score, loot, DPS, interrupts, deaths)", "MythicPlus", "miss",
  "C_DamageMeter session data is readable after combat", "S28")

A = "EllesmereUI Nameplates"
F(A, "ColorsPage::DEBUFF BASED NAMEPLATE COLORING", "Colour plates by your debuffs; caster / mini-boss / boss colours; threat tweaks", "NamePlates", "part",
  "Threat colours exist; debuff-based colouring and caster / mini-boss colours (need NPC classification data) do not", "S28")
F(A, ["ColorsPage::", "CoreTextColoring::CORE TEXT COLORING"], "Threat text and name / level colouring", "NamePlates", "done")
F(A, ["DisplayBars::HEALTH AND CAST BAR", "DisplayBars::TARGET, FOCUS & HOVER EFFECTS", "DisplayBars::GENERAL TEXT"], "Plate health and cast bar, target / focus / hover effects, text", "NamePlates", "done")
F(A, "DisplayBars::CLASS RESOURCE", "Class resource on the target plate (shape, colours)", "NamePlates", "done")
F(A, ["DisplayLayout::STYLE", "DisplayLayout::CORE POSITIONS", "DisplayLayout::CORE TEXT POSITIONS"], "Plate style (border, corners, separators, level box) and element positions", "NamePlates", "done")
F(A, "GeneralPage::~NPC Title|Title Size|Title Color|Subtitle|Guild", "NPC titles and guild text on friendly plates", "NamePlates", "miss", "Open gap row (friendly NPC titles)", "S17")
F(A, "GeneralPage::", "Friendly name-only plates, stacking, hitbox, max debuffs, enemy pets", "NamePlates", "done")
F(A, "GeneralPage::TARGET AND FOCUS EFFECTS~Line of Sight", "Fade plates out of line of sight", "NamePlates", "imp",
  "No line-of-sight API for units; addons cannot test LoS in 12.x")
F(A, "GeneralPage::TARGET AND FOCUS EFFECTS", "Hash line at %, target scale, non-target opacity, focus letter, range text, scale on cast", "NamePlates", "part",
  "Target scale, opacity and execute mark exist; range text, scale on cast and focus letter do not", "S28")
F(A, "EUI_Nameplates::", "Aura type colour (magic / enrage), textured background", "NamePlates", "done")

A = "EllesmereUI PlayerAuraBars"
F(A, ["EUI_PlayerAuraBars_ManagerPages::CORE", "EUI_PlayerAuraBars_ManagerPages::DISPLAY", "EUI_PlayerAuraBars_ManagerPages::DEBUFF DISPLAY",
      "EUI_PlayerAuraBars_ManagerPages::ICON EFFECTS"], "Player buff / debuff grid: size, growth, sort, wrap, timers, cancel", "Auras", "done")
F(A, ["EUI_PlayerAuraBars_ManagerPages::ASSIGNED BUFFS", "EUI_PlayerAuraBars_ManagerPages::ASSIGNED DEBUFFS"], "Assigned aura lists (filters, extra spells)", "Auras", "miss", "", "S19")

A = "EllesmereUI QoL"
F(A, ["EUI_QoL_Alerts::", "EUI_QoL_Alerts::ALERTS~Combat|Text|Color|Enter|Leave|Sound"], "Combat enter / leave alert", "Quality", "done")
F(A, "EUI_QoL_Alerts::ALERTS", "Potion-ready and unspent-talent alerts, group deaths notice", "Quality", "miss", "", "S26")
F(A, "EUI_QoL_AutoLogging::AUTO COMBAT LOGGING", "Auto combat logging in chosen content", "Quality", "miss", "LoggingCombat() is allowed", "S26")
F(A, "EUI_QoL_AutoLogging::KEYSTONE CHECK POPUP", "/keys pop-up of party keystones", "MythicPlus", "done")
F(A, "EUI_QoL_AutoLogging::LFG REMINDER", "Reminder when you are not queued", "GroupFinder", "miss", "", "S28")
F(A, "EUI_QoL_AutoLogging::WAYPOINT COMMAND", "/way command and arrival with hand-placed pins", "Quests", "miss", "Builds on the S17 NPC search and the S14 arrow", "S17")
F(A, ["EUI_QoL_BattleRes::", "EUI_QoL_BattleRes::BATTLE RES", "EUI_QoL_BattleRes::BLOODLUST TRACKER"], "Battle-res charges and bloodlust / sated tracker icons", "Encounters", "miss",
  "C_Spell.GetSpellCharges(20484) gives the shared battle-res pool in encounters", "S21")
F(A, "EUI_QoL_Cursor::", "Cursor ring, trail, GCD and cast circles, reticle", "Quality", "part", "Ring exists; trail, GCD / cast circles and reticle do not", "S26")
F(A, ["EUI_QoL_MovementAlert::MOVEMENT COOLDOWN ALERT", "EUI_QoL_MovementAlert::EXTRA TRACKING"], "Movement-cooldown alert (with TTS), Time Spiral and gateway shard alerts", "Tracker", "miss",
  "Own-spell cooldowns can be secret in combat; the alert would use the Cooldown Manager's events", "S20")
F(A, "EUI_QoL::SELF COMBAT TEXT", "Self combat text", "CombatText", "done")
F(A, "EUI_QoL::GENERAL~Item Transforms|/cd|AH Current", "Hide item transforms, /cd command, AH current-expansion filter", "Quality", "miss",
  "AH filter moves to the Auction House page (S22)", "S26")
F(A, "EUI_QoL::GENERAL", "Skip cinematics, quick loot, delete fill, repair (guild funds), sell junk, single gossip", "Automation", "done")
F(A, "EUI_QoL::EXTRAS~FPS|MS|Local|World|Interval|Durability|Coordinates", "FPS / latency counters, low durability warning, map coordinates", "DataTexts", "done")
F(A, "EUI_QoL::EXTRAS", "Secondary stats on screen, guild chat privacy cover, rested indicator, target distance text", "Quality", "miss", "", "S26")
F(A, "EUI_QoL::CROSSHAIR", "Character crosshair with melee-range colour", "Quality", "miss", "", "S26")
F(A, "EUI_QoL::GROUP FINDER~Persistent", "Persistent sign-up note", "GroupFinder", "imp",
  "Blizzard's sign-up note box refuses SetText from addons (verified in S15, docs/GROUP_FINDER.md)")
F(A, "EUI_QoL::GROUP FINDER~Announce", "Announce instance reset", "Automation", "skip", "Chat announcements are a recorded scope cut")
F(A, "EUI_QoL::GROUP FINDER", "Auto-insert keystone, quick sign-up", "MythicPlus", "done")
F(A, "EUI_QoL::UI", "Hide screenshot text, train all, auto unwrap, auto open containers, hold capped payouts", "Automation", "miss",
  "Opening containers needs a hardware event per item (C_Container.UseContainerItem is protected); a click-to-open button is possible", "S26")
F(A, ["EUI_QoL_RaidTools::GENERAL", "EUI_QoL_RaidTools::QUICK FIRE", "EUI_QoL_RaidTools::GROUP BUTTONS", "EUI_QoL_RaidTools::PULL TIMER"], "Raid tools window (ready check, pull, markers, world markers)", "Quality", "part",
  "Raid marker bar and pull timer exist; one raid-tools window does not", "S26")
F(A, ["EUI_QoL_Shifter::SHIFTER", "EUI_QoL_Shifter::LOOT WINDOWS", "EUI_QoL_Shifter::BLIZZARD TOP BAR EVENT TEXT"], "Move Blizzard windows by dragging (with reset)", "Movers", "part", "Window scale exists; free dragging of Blizzard windows does not", "S26")

A = "EllesmereUI QuestTracker"
F(A, ["EUI_QuestTracker::DISPLAY", "EUI_QuestTracker::COLORS"], "Tracker look: fonts, colours, background, hide in raid", "Quests", "done")
F(A, "EUI_QuestTracker::TRACKING", "Sorting, filtering, auto-track zone quests, completion sounds", "Quests", "miss", "Announce progress is a scope cut", "S25")
F(A, "EUI_QuestTracker::EXTRAS", "Auto accept / turn in with shift skip, ignore low level / old expansion", "Quests", "done")

A = "EllesmereUI Quickdraw"
F(A, ["EUI_Quickdraw::GENERAL", "EUI_Quickdraw::ACTION MENU SETUP", "EUI_Quickdraw::LAYOUT", "EUI_Quickdraw::APPEARANCE"], "Radial / grid action menu on a key (world markers, nesting)", "ActionBars", "miss",
  "Secure buttons inside a SecureHandler; set up out of combat", "S26")

A = "EllesmereUI RaidFrames"
F(A, ["FramesPages::FRAME SIZES", "FramesPages::FRAME DISPLAY", "FramesPages::LAYOUT", "FramesPages::FRAME STYLE",
      "FramesPages::RAID SYNC AND SOLO", "FramesPages::FRAMES"], "Party / raid layouts per size, sorting, growth, solo, spacing", "GroupFrames", "done")
F(A, ["VisualBars::HEALTH BAR", "VisualBars::POWER BAR", "VisualBars::TEXT DISPLAY"], "Group health / power bars and texts", "GroupFrames", "done")
F(A, "VisualBars::ABSORBS", "Absorbs: overshield, glow line, absorb bar, heal absorb, max-health reduction", "GroupFrames", "part",
  "Shields and heal absorbs exist; max-health reduction style and overshield glow do not", "S19")
F(A, "VisualIndicators::INDICATORS", "Indicators: missing buffs, role, marker, ready check / summon / rez, status, leader, combat, group numbers, ping", "GroupFrames", "part",
  "Role, marker, leader, ready check exist; missing-buff, summon / rez, group numbers and ping markers do not", "S19")
F(A, "VisualIndicators::DISPELS", "Dispel overlay, type icon, per-type dispel colours", "GroupFrames", "part", "Open gap row (dispel colours)", "S17")
F(A, ["VisualIndicators::TOP NAME BAR"], "Top name bar strip", "GroupFrames", "miss", "", "S19")
F(A, "VisualIndicators::FRIENDLY BOSS FRAMES", "Friendly boss frames group", "GroupFrames", "miss", "", "S19")
F(A, ["VisualIndicators::EXTRA FRAMES", "VisualIndicators::PET FRAMES"], "Tank / extra group and pet frames", "GroupFrames", "done")
F(A, "VisualIndicators::EXTRAS", "Range alpha, tooltips, healer mana display, names in raid, status colours, strata", "GroupFrames", "part", "Healer mana display is missing", "S19")
F(A, "EUI_RaidFrames::PORTRAIT", "Portraits on group frames", "GroupFrames", "miss", "", "S19")
F(A, "EUI_RaidFrames::PARTY TARGETS", "Party target frames", "GroupFrames", "miss", "", "S19")
F(A, ["EUI_RaidFrames_ManagerPages::CORE", "EUI_RaidFrames_ManagerPages::DISPLAY", "EUI_RaidFrames_ManagerPages::ICON EFFECTS",
      "EUI_RaidFrames_ManagerPages::EFFECT"], "Debuff manager on group frames (size, position, growth, duration, filters)", "GroupFrames", "done")
F(A, ["EUI_RaidFrames_ManagerPages::ASSIGNED BUFFS", "EUI_RaidFrames_ManagerPages::ASSIGNED DEBUFFS"], "Assigned buff / debuff lists with custom order and placement", "GroupFrames", "miss", "", "S19")
F(A, ["EUI_RaidFrames_BuffManager::", "EUI_RaidFrames_BuffManager::CORE", "EUI_RaidFrames_BuffManager::DISPLAY",
      "EUI_RaidFrames_BuffManager::THRESHOLD TEXT"], "Buff manager: own-only, pandemic border, threshold text, dashes", "GroupFrames", "part", "Buff icons exist; pandemic border and threshold text do not", "S19")

A = "EllesmereUI ResourceBars"
F(A, "BarDisplayPage::BAR DISPLAY", "Detached resource bars: texture, backgrounds, strata, borders", "UnitFrames", "miss", "Phoenix has no detached player resource bars", "S18")
F(A, "BarDisplayPage::BAR SHIFTING~Mana Regen", "Mana regen spark", "UnitFrames", "imp", "Retail has no five-second rule or mana tick to mark, and GetManaRegen is secret while unit stats are restricted; the open gap row closes as api")
F(A, "BarDisplayPage::BAR SHIFTING~Spell Cost", "Spell cost prediction on the power bar", "UnitFrames", "miss",
  "UNIT_SPELLCAST_START + C_Spell.GetSpellPowerCost for the player; power values may be secret in combat (verify)", "S17")
F(A, "BarDisplayPage::BAR SHIFTING", "Shift / expand bars when a resource is missing, mana bar while shapeshifted", "UnitFrames", "part", "", "S18")
F(A, "BarDisplayPage::ARCANE SOUL (SUNFURY)", "Spec helper: Arcane Soul countdown", "Tracker", "miss", "", "S20")
F(A, "CastBarPage::", "Player cast bar: layout, gradient, ticks, latency, empowered stages", "CastBars", "done")
F(A, "ClassResourceSection::CLASS RESOURCE BAR~Ironfur|Ignore Pain|Sweeping", "Spec bars: Ironfur, Ignore Pain, Sweeping Strikes", "UnitFrames", "miss", "", "S18")
F(A, "ClassResourceSection::CLASS RESOURCE BAR", "Class resource bar: orientation, separators, pip borders, charged colour, thresholds, text", "UnitFrames", "part",
  "Pips, borders, charged points exist; thresholds, separators and orientation do not", "S18")
F(A, ["GCDBarPage::LAYOUT", "GCDBarPage::DISPLAY"], "GCD bar", "CastBars", "part", "GCD bar under the cast bar exists; standalone bar options do not", "S18")
F(A, ["HealthSection::HEALTH BAR", "PowerSection::POWER BAR"], "Detached player health and power bars (personal resource display)", "UnitFrames", "miss", "", "S18")
F(A, ["SwingTimerPage::LAYOUT", "SwingTimerPage::DISPLAY"], "Swing timer", "CastBars", "part", "Swing timer exists where the client allows (feature swingTimer); weapon labels and range cues do not", "S18")
F(A, "TotemBarPage::", "Totem bar", "UnitFrames", "miss", "GetTotemInfo is readable; destroying needs a secure button", "S18")
F(A, ["EUI_ResourceBars::", "EUI_ResourceBars::POSITIONING", "EUI_ResourceBars::RESET"], "Resource bar positioning / reset", "Movers", "done")

A = "EllesmereUI UnitFrames"
F(A, ["MiniFrames::DISPLAY", "MiniFrames::HEALTH BAR", "MiniFrames::POWER BAR", "MiniFrames::BUFFS AND DEBUFFS"], "Target-of-target, focus, pet and boss frames with their bars, auras and cast bars", "UnitFrames", "done")
F(A, "SharedAppearance::DISPLAY", "Frame look: nicknames, fade, dark mode, borders, detached bars, threat %", "UnitFrames", "part", "Threat % on target and detached power / text bars are missing", "S18")
F(A, "SharedAppearance::PORTRAIT", "Portraits: 2D / 3D / class, shape, rings, dragon art", "UnitFrames", "part", "2D / class portraits exist; 3D model, rings and dragon art do not; size is an open gap row", "S18")
F(A, "SharedAppearance::TEXT BAR", "Separate text bar strip under the frame", "UnitFrames", "miss", "", "S18")
F(A, "SharedAppearance::EXTRAS", "Combat, marker, leader, elite, faction and PvP indicators", "UnitFrames", "done")
F(A, ["SharedBars::HEALTH BAR", "SharedBars::CLASS RESOURCE"], "Health bar and class resource on frames", "UnitFrames", "done")
F(A, "SharedBars::POWER BAR", "Power bar: position, gradient, text, cost prediction, regen spark", "UnitFrames", "part", "Cost prediction / regen spark are open gap rows", "S17")
F(A, "SharedBars::ABSORBS AND HEALS", "Absorbs and heals: overshield, glow line, heal prediction, overheal", "UnitFrames", "part", "Overheal is an open gap row", "S17")
F(A, ["SharedCastAuras::CAST BAR", "SharedCastAuras::BUFFS AND DEBUFFS"], "Cast bar and auras on unit frames", "UnitFrames", "done")
F(A, ["EUI_UnitFrames::", "TextSlots::"], "Name format, borders, corners, text slots", "UnitFrames", "done")

A = "EllesmereUI DataBars"
F(A, "EllesmereUIDataBars::BAR SETTINGS~Currency|Crests|Portals|Audio|Menu|Plugin", "Data bar blocks: currency picker, crests, M+ portals, audio channel, menu, plugins", "DataTexts", "miss", "Currency picker is an open gap row", "S17")
F(A, "EllesmereUIDataBars::BAR SETTINGS", "Data bar layout: blocks, full-screen extent, snap, text, tooltips, clock, gold", "DataTexts", "part", "Panels and segments exist; block layout and screen-edge bars do not", "S28")

A = "EllesmereUI WindTools"
F(A, ["Advanced::Core", "Advanced::Game Fix", "Advanced::Developer", "Core::", "Misc::"], "Addon internals (login message, changelog, developer, fonts)", "General", "skip", "Tooling of the addon itself")
F(A, ["Announcement::General", "Announcement::Quest", "Announcement::Utility", "Announcement::Goodbye", "Announcement::Reset Instance",
      "Announcement::Keystone"], "Chat announcements (quests, interrupts, goodbye, reset, keystone)", "Automation", "skip", "Chat announcements are a recorded scope cut (spam risk)")
F(A, "Combat::Raid Markers", "Raid marker bar with countdown and ready-check buttons", "Quality", "part", "Marker bar exists; countdown / ready-check buttons and inverse mode do not", "S26")
F(A, "Combat::Combat Alert", "Combat alert animation", "Quality", "done")
F(A, "Combat::Destroy Totem", "Click to destroy totems", "UnitFrames", "miss", "Secure button (DestroyTotem is protected)", "S18")
F(A, "Combat::Quick Keystone", "Quick keystone insert", "MythicPlus", "done")
F(A, "Combat::Damage Meter Layout", "Damage meter layout tweaks", "DamageMeter", "done")
F(A, ["ExtraItemBar::General", "ExtraItemBar::Layout", "ExtraItemBar::Visibility", "ExtraItemBar::Text & Fonts"], "Extra item bars (custom items, groups, visibility, texts)", "ActionBars", "part",
  "Item bar with quest items and extra items exists; several bars, groups and blacklist do not", "S26")
F(A, "Item::Delete Item", "Fill DELETE", "Automation", "done")
F(A, "Item::Fast Loot", "Fast loot", "Automation", "done")
F(A, "Item::Trade", "Trade thanks button", "Automation", "skip", "Sends chat; scope cut")
F(A, "Item::Already Known", "Already-known tint", "Quality", "done")
F(A, "Item::Contacts", "Mail contacts (alts)", "Skins", "miss", "", "S24")
F(A, "Item::Inspect", "Inspect: item icons, quality borders, sockets", "ItemLevel", "part", "", "S23")
F(A, "Item::Item Level", "Item level on items", "ItemLevel", "done")
F(A, "Item::Extend Merchant Pages", "Wider merchant window", "Skins", "miss", "", "S24")
F(A, "Maps::Super Tracker", "Super tracker: auto-track waypoints, middle-click clear, no distance limit, /way box", "Quests", "part", "Super-track on click and the arrow exist; /way box is S17", "S17")
F(A, "Maps::Rectangle Minimap", "Rectangle minimap", "Minimap", "done")
F(A, "Maps::Minimap Buttons", "Minimap button bar", "Minimap", "done")
F(A, "Maps::World Map", "World map reveal with coloured fog, map scale", "Minimap", "miss", "Open gap rows (reveal, scale)", "S17")
F(A, "Maps::Instance Difficulty", "Instance difficulty text", "Minimap", "done")
F(A, "Maps::Event Tracker", "World event timer tracker", "Minimap", "miss", "Needs event schedule data (DB2 / runtime C_AreaPoiInfo timers)", "S25")
F(A, "Misc::General", "Misc tweaks (talking head, cut scenes, loot panel, chat bubble toggle)", "Quality", "part", "", "S26")
F(A, "Misc::Automation~Combat Resurrect", "Accept combat resurrections automatically", "Automation", "skip",
  "Phoenix accepts resurrections only out of combat (InCombatLockdown guard in Automation); accepting a combat res for you mid-fight is left to your click")
F(A, "Misc::Automation", "Auto hide map / bags, accept resurrect, confirm summon", "Automation", "part", "", "S26")
F(A, "Misc::Exit Phase Diving", "Exit phase diving button", "Quality", "miss", "", "S26")
F(A, "Misc::CVars Editor", "CVar editor (screenshots, floating text, spell queue, camera, effects)", "Quality", "part", "", "S26")
F(A, "Misc::Move Frames", "Move Blizzard frames, remember positions", "Movers", "part", "", "S26")
F(A, "Misc::Mute", "Mute specific sounds", "General", "done")
F(A, "Misc::Game Bar", "Game bar (micro buttons, time, friends, notifications)", "DataTexts", "part", "", "S28")
F(A, "Misc::LFG List~Auto Refresh|Auto Join", "Auto refresh / auto join group listings", "GroupFinder", "imp",
  "C_LFGList.Search is flagged HasRestrictions in the API docs (it runs from your click) and joining goes through Blizzard's Sign Up button; no automatic refresh or join")
F(A, "Misc::LFG List", "Group list look: leader, role icons, description shortening, filter tooltip", "GroupFinder", "done")
F(A, "Misc::Spell Activation Alert", "Spell activation overlay opacity / scale", "Quality", "miss", "", "S26")
F(A, "Misc::Keybind Alias", "Short keybind names", "ActionBars", "done")
F(A, "Quest::Objective Tracker", "Tracker text tweaks (dash, colourful progress, %)", "Quests", "part", "", "S25")
F(A, "Quest::Auto Collapse", "Auto-collapse tracker by situation", "Quests", "done")
F(A, "Quest::Switch Buttons", "Tracker switch buttons", "Quests", "miss", "", "S25")
F(A, "Quest::Progress", "Quest progress chat messages", "Quests", "skip", "Chat announcements are a scope cut")
F(A, "Quest::Turn In", "Auto turn-in with modes", "Quests", "done")
F(A, "Quest::Prey Hunt", "Prey hunt helper", "Quests", "miss", "", "S25")
F(A, "Quest::Achievement Screenshot", "Achievement screenshots", "Quality", "done")
F(A, "Quest::Achievement Tracker", "Achievement tracker window", "Quests", "miss", "", "S25")
F(A, "Social::", "Chat bar, smart tab, emote picker", "Chat", "part", "Chat bar exists; emote picker is an open gap row", "S17")
F(A, "Tooltips::General", "Tooltip icons, faction / pet icons, pet ID, tier set count", "Tooltip", "part", "", "S24")
F(A, "Tooltips::Progression", "Raid / M+ progression in tooltips", "Tooltip", "part", "Mythic+ rating exists; raid progression is an open gap row", "S17")
F(A, "Tooltips::Keystone", "Keystone tooltip (affixes)", "Tooltip", "miss", "Open gap row", "S17")
F(A, "Tooltips::Group Info", "Group info in tooltips", "GroupFinder", "done")
F(A, "Tooltips::ElvUI Tooltip Tweaks", "ElvUI tooltip tweaks", "Tooltip", "skip", "ElvUI-only")
F(A, "Tooltips::Objective Progress", "Objective progress in tooltips", "Quests", "done")
F(A, "UnitFrames::Quick Focus", "Modifier-click to set focus (with marker)", "UnitFrames", "miss", "Secure attribute on frames, out of combat", "S18")
F(A, "UnitFrames::Friendly Nameplate Outline", "Friendly plate outline", "NamePlates", "done")
F(A, "UnitFrames::Absorb", "Absorb texture", "UnitFrames", "done")
F(A, "UnitFrames::Role Icon", "Role icon set", "UnitFrames", "done")
F(A, "SilverDragon::", "SilverDragon skin", "Skins", "part", "", "S24")

A = "sArena Reloaded"
F(A, ["BlizzArena::", "BlizzCompact::", "BlizzRaid::", "BlizzRetail::", "BlizzTarget::", "BlizzTourney::", "Gladiuish::", "Pixelated::", "Xaryu::"],
  "Arena frame layouts (9 presets: mirrored, sizes, power height, crop)", "UnitFrames", "miss", "Phoenix arena frames have one layout", "S18")
F(A, "Config::~^Castbar_", "Arena cast bars: modern look, shield, spark, colours, highlight casts on me / CC", "UnitFrames", "part", "Arena frames reuse Phoenix cast bars; highlight-on-me / CC colours do not exist", "S18")
F(A, "Config::~^DR_|DRPixel", "DR tracker look (borders, text, size)", "UnitFrames", "miss", "", "S18")
F(A, "Config::Category_PetFrames~^Option_DR|Option_HideDRs|Option_OnlyTriggerable|Option_PerClass|Option_PerSpec|Option_EnableStatic|Option_NewMidnight|Option_ShowDecimalsOnDR|Option_ColorDR|Option_DisableInstantDR",
  "Diminishing returns tracking (per class / spec, reset time, 12.x DR handling)", "UnitFrames", "miss",
  "12.x sends DR state in UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED (secret payloads) and C_SpellDiminish; Phoenix can show it through display sinks or restyle Blizzard's own DR tray, never from the combat log", "S18")
F(A, "Config::~^Widget_", "Arena widgets: combat / healer / target / focus indicators, party ↔ arena targets", "UnitFrames", "miss", "", "S18")
F(A, "Config::~^Text_", "Arena fonts and text placement", "UnitFrames", "part", "", "S18")
F(A, "Config::Category_PetFrames~^Racial_|Trinket|Racial", "Trinket and racial tracking", "UnitFrames", "part", "PvP trinket exists; racials and swap rules do not", "S18")
F(A, "Config::Category_PetFrames~^ClickAction_", "Click actions on arena frames (spell / macro per button, Clique)", "UnitFrames", "miss", "Secure attributes set out of combat", "S18")
F(A, "Config::Category_PetFrames~^AuraHighlight_|AuraSort|OnlyShowCCAuras|HideClassIconShowAuras|DisableAurasOnClassIcon", "Auras on the class icon (CC / defensive / important) and aura highlight", "UnitFrames", "miss",
  "Arena unit auras are readable through C_UnitAuras with AuraUtil filters; some are secret in combat (display sinks)", "S18")
F(A, "Config::Category_PetFrames~^Option_Pet|PetEnabled|PetClass|PetCustom|ShowPetName|ShowPetNumber|PetNumberIdOnly|PetBorder", "Arena pet frames", "UnitFrames", "miss", "", "S18")
F(A, "Config::Category_PetFrames~ShowDispels|DesaturateDispel", "Enemy dispel cooldown tracking", "UnitFrames", "imp",
  "Enemy dispels are only visible in the combat log, which Phoenix never reads on 12.x, and spell IDs from arena units' cast events are secret in arenas")
F(A, "Config::Category_PetFrames~ShadowsightTimer|Dampening|GladTracker", "Shadowsight timer and gladiator tracker", "PvP", "miss", "Dampening % stays impossible (the gap row Dampening display is api since S16)", "S18")
F(A, "Config::Category_PetFrames~RangeCheck", "Range check on arena frames", "UnitFrames", "part", "", "S18")
F(A, "Config::Category_PetFrames", "Arena frame options: layout test, colours, numbers, swipes, Masque, stealth alpha", "UnitFrames", "part",
  "Test frames, class colours and swipe exist; most per-element switches do not", "S18")
F(A, "Config::", "Arena frame general (class icon, spec text, manabars, growth, scale, sizes)", "UnitFrames", "part", "", "S18")
F(A, ["AceDBOptions-3.0::", "Profiles::", "SettingsSearch::", "Functions::"], "Profiles, settings search, reload", "Profiles", "done")

A = "BigWigs"
F(A, "Bars::", "Boss bars: style, emphasize anchor, icons, spell indicators, custom anchors, test bars", "Encounters", "part",
  "Phoenix bars cover size, texture, colour, emphasis; a separate emphasize anchor and spell indicators do not", "S21")
F(A, "Messages::", "Boss messages: font, icons, class colours, chat-frame copy, test", "Encounters", "part", "", "S21")
F(A, ["Countdown::", "Countdown::countdownAudioHeader", "Countdown::countdownTextHeader"], "Countdown voice and text", "Encounters", "done")
F(A, "Pull::", "Pull timer: countdown type, sounds, combat log on pull, keybind", "Encounters", "part", "Pull timer and voice exist; pull sounds / keybind / auto log do not", "S21")
F(A, "Colors::", "Per-ability bar / message colours", "Encounters", "imp", "A colour has to be keyed by spell, and spell IDs are secret during encounters (gap row Per-spell colour override, api since S16); Phoenix colours by the timeline's severity instead")
F(A, ["Sound::", "Sound::oldSounds"], "Sounds per alert type (on you, under you)", "Encounters", "part", "Private aura sounds stay impossible (gap row, api since S16)", "S21")
F(A, ["Auras::", "Auras::emphasize"], "Track chosen auras on chosen players (tank indicator, emphasize)", "Encounters", "miss",
  "Other players' auras are secret in encounters; only display sinks are possible (verify)", "S21")
F(A, ["Nameplates::", "Nameplates::anchoring", "Nameplates::emphasize", "Nameplates::font", "Nameplates::headerIconPositionOthers",
      "Nameplates::headerIconPositionTarget", "Nameplates::headerIconSizeOthers", "Nameplates::headerIconSizeTarget"], "Boss-ability icons and text on nameplates", "Encounters", "miss", "", "S21")
F(A, "Proximity::", "Proximity display", "Encounters", "imp", "UnitPosition returns nil for group members inside instances since 7.1; no distance data")
F(A, ["AltPower::", "AltPower::general", "AltPower::yourPowerBar"], "Alternate (encounter) power display", "UnitFrames", "part", "Encounter power bar on the player frame exists; the group list does not", "S21")
F(A, ["BattleRes::", "BattleRes::battleResHasCharges", "BattleRes::battleResNoCharges", "BattleRes::battleResPlaySound",
      "BattleRes::cooldown", "BattleRes::emphasize"], "Battle-res charges display", "Encounters", "miss", "Same feature as the EUI battle-res tracker (one owner)", "S21")
F(A, "BossBlock::", "Block boss emotes, movies, talking heads, tracker, popups, music during encounters", "Encounters", "part", "Talking heads hide exists (Quality); the rest does not", "S21")
F(A, "Statistics::", "Boss kill / wipe statistics, fastest victory", "Encounters", "miss", "", "S21")
F(A, ["Victory::", "Wipe::"], "Victory sound / message, wipe sound, respawn bar", "Encounters", "miss", "", "S21")
F(A, "RaidIcon::", "Auto raid icons on boss targets", "Encounters", "miss", "Needs per-boss data; SetRaidTarget is flagged HasRestrictions in the 12.x API docs, so marking is limited to what it allows (in-game check)", "S21")
F(A, "AutoReply::", "Auto-reply to whispers in combat", "Automation", "skip", "Sends chat; scope cut")
F(A, "Timeline::", "Bars vs Blizzard timeline", "Encounters", "done")
F(A, ["Keystones::", "Keystones::font", "Keystones::settingsForCurrentTarget", "Keystones::settingsForOtherTargets"], "Party keystones viewer, key countdown, auto slot", "MythicPlus", "done")
F(A, "CombatTimer::", "Combat timer with history", "DamageMeter", "miss", "Same feature as the EUI standalone combat timer (one owner)", "S28")
F(A, "AutoInvite::", "Invite on keyword", "Automation", "miss", "InviteUnit is allowed", "S26")
F(A, "LFGTimer::", "LFG proposal timer sound", "PvP", "done")
F(A, "Options::", "Minimap icon, compartment, zone messages, links", "Encounters", "done")
F(A, ["Sharing::", "InstanceSharing::"], "Share boss settings as import strings", "Profiles", "part", "Profile export exists; per-instance encounter export does not", "S21")
F(A, "", "Per-boss modules: Midnight raids (The Voidspire, The Dreamrift, March on Quel'Danas, The Venomous Abyss, Kith'ix, Sporefall, Nymrissa) and world bosses",
  "Encounters", "part", "Phoenix shows every timeline event and warning the game sends; per-boss names, counts and sounds are S21. The three world bosses have no game timeline in BigWigs either", "S21", n=23)
F(A, "", "Per-boss modules: legacy raids (Classic … The War Within)", "Encounters", "imp",
  "These modules are built on combat-log events (self:Log on SPELL_CAST_START etc.); Phoenix never reads the combat log on 12.x (Core/Events.lua refuses it) and spell IDs in it are secret in instances. BigWigs still ships them for 12.1, so whether they fire in old instances is an in-game check; if they do, this becomes a scope decision, not an API wall", n=558)

A = "LittleWigs"
F(A, "", "Per-boss modules: Midnight dungeons, delves and the current Mythic+ rotation", "Encounters", "part",
  "Timeline events and warnings shown generically; per-boss tuning is S21", "S21", n=58)
F(A, "", "Per-boss modules: legacy dungeons (Classic … The War Within)", "Encounters", "imp", "Same as the BigWigs legacy modules (combat-log based)", n=700)

A = "Questie"
F(A, "QuestieOptionsTracker::Tracker Options", "Questie tracker (sorting, minimise, fonts, sizer, TomTom)", "Quests", "part", "Phoenix restyles Blizzard's tracker; its own sorting / sizer options do not exist", "S25")
F(A, ["QuestieOptionsIcons::Icon Options", "QuestieOptionsIcons::Quests", "QuestieOptionsIcons::Objectives"], "Quest and objective icons on maps by type", "Quests", "part",
  "Givers, turn-ins and quest lines exist; objective icons come from the game's own map", "S25")
F(A, "QuestieOptionsIcons::Other Icons", "Townsfolk, trainer and vendor icons; icon glow, fade, minimap", "Quests", "miss", "S17 NPC data (vendors / trainers from ATT) feeds this", "S17")
F(A, "QuestieOptionsIcons::Season of Discovery Runes", "Season of Discovery runes", "Quests", "skip", "Classic Season of Discovery only")
F(A, "QuestieOptionsMap::Waypoints", "NPC patrol paths on the map", "Quests", "imp", "No licence-clean source of NPC waypoints: DB2 has no creature spawns, Questie's data is GPL-3.0 and Wowhead forbids scraping")
F(A, ["QuestieOptionsNameplate::Nameplate Icon Options", "QuestieOptionsNameplate::Target Frame Icon Options"], "Quest-objective icons on plates and target frame", "NamePlates", "done")
F(A, "QuestieOptionsGeneral::General Options~Announce|ShutUp|Channels|Share quest|party members|Accepted|abandoned|Objective completed|Quest completed|Incomplete", "Party quest sharing and announcements", "Quests", "skip", "Chat announcements are a scope cut; party progress sharing needs addon comms")
F(A, "QuestieOptionsGeneral::General Options~drop rates", "Item drop rates", "Tooltip", "imp", "No licence-clean drop-rate data (Wowhead and Questie data are off-limits)")
F(A, "QuestieOptionsGeneral::General Options", "Instant quest text, map buttons, coordinates, level filters, tooltips (quests on NPCs, chains, breadcrumbs), sounds", "Quests", "part",
  "Coordinates, NPC quest tooltips, level filter exist; chains, instant text and sounds do not", "S25")
F(A, ["QuestieOptionsAuto::", "QuestieOptionsAuto::Auto Accept", "QuestieOptionsAuto::Auto Complete"], "Auto accept by quest kind, auto complete, modifier", "Quests", "part", "Accept / turn-in exist; per-kind filters do not", "S25")
F(A, "QuestieOptionsAuto::Auto Reject", "Auto reject shared quests (battlegrounds, non-friends)", "Quests", "miss", "", "S25")
F(A, ["QuestieOptionsAdvanced::Advanced Settings", "QuestieOptionsAdvanced::Localization Settings", "QuestieOptionsAdvanced::Reset Questie"], "Icon limits and distances, locale, reset, journey import", "Quests", "part", "", "S25")
F(A, "QuestieOptionsAdvanced::Developer Options", "Developer IDs in tooltips", "Tooltip", "done")
F(A, ["QuestieOptionsDBM::DBM HUD", "QuestieOptionsDBM::Size & Scale Options", "QuestieOptionsDBM::Filter Options"], "DBM HUD quest icons", "Quests", "skip", "Needs DBM's HUD")
F(A, "", "My Journey (quest history log)", "Quests", "miss", "", "S25", n=1)
F("QuestieDB", "", "Shared quest / NPC / object database library", "Quests", "skip",
  "Classic-era data under ARR/GPL-3; Phoenix uses ATT (MIT) + DB2 + runtime APIs (docs/QUEST_DATA.md)", n=1)
F("QuestieTrace", "", "Opt-in session recorder with privacy filter and export string", "Quests", "part",
  "Phoenix S17 collector: opt-in, NPC IDs + map positions only, merged by tools/; no uploader yet", "S17", n=1)

A = "PremadeGroupsFilter"
F(A, "Settings::~oneClick|signupOnEnter|signUpDeclined", "One-click / Enter sign-up, declined dimming", "GroupFinder", "done")
F(A, "Settings::~skipSignUp|persistSignUp", "Skip the sign-up dialog, persistent note", "GroupFinder", "imp",
  "The sign-up dialog only submits through Blizzard's Sign Up button (a click) and its note box refuses SetText from addons (S15)")
F(A, "Settings::~cancelOldest", "Cancel the oldest application when full", "GroupFinder", "imp", "Blizzard cancels applications only from its own button; Phoenix treats it as needing your click (like sign-up, S15), so it is not done on its own")
F(A, "Settings::~compact", "Compact list entries", "GroupFinder", "miss", "", "S28")
F(A, "Settings::", "Group list extras: class names, coloured texts, age, rating info, spec icons, class circles / bar, leader crown, missing roles, movable dialog", "GroupFinder", "done")
F(A, "", "Advanced filter expressions (105 variables)", "GroupFinder", "part", "Phoenix grammar has 39 words", "S28", n=105)

A = "MoveAny"
F(A, "settings::checkbox~^(SHOWTIPS|SHOWMINIMAPBUTTON|MOVEFRAMES|CLAMPWINDOWTOSCREEN|SAVEFRAMEPOSITION|FRAMESKEYDRAG|SCALEFRAMES|SAVEFRAMESCALE|FRAMESKEYSCALE|FRAMESKEYRESET|DISABLEMOVEMENT)$",
  "Mover behaviour: drag / scale keys, clamp, save positions", "Movers", "part", "Grid, snap and nudge exist; per-window drag / scale keys do not", "S26")
F(A, "settings::checkbox~^(ACTIONBAR|ACTIONBARS|ACTIONBAR\\d+|PETBAR|STANCEBARANCHOR|POSSESSBAR|OVERRIDEACTIONBAR|LEAVEVEHICLE|EXTRAABILITYCONTAINER|ExtraActionBarFrame|ExtraActionButton1|MICROMENU|BAGS|ENDCAPS|BLIZZARDACTIONBUTTONSART|ZONEABILITYFRAME)$",
  "Move action bars, extra / zone buttons, micro menu, bags", "ActionBars", "done", "Phoenix bars have their own movers; Blizzard's go through Edit Mode")
F(A, "settings::checkbox~^(PLAYERFRAME|PLAYERFRAMEGROUPINDICATOR|PLAYERFRAMEBACKGROUND|PLAYERLEVELTEXT|MAPETFRAME|PETFRAMEHAPPINESS|TARGETFRAME|TARGETFRAMEBUFFMOVER|TARGETFRAMEDEBUFFMOVER|TARGETFRAMESPELLBAR|TargetFrameNumericalThreat|TARGETFRAMENAMEBACKGROUND|TARGETOFTARGETFRAME|TARGETFRAMETOT\\w+|FOCUSFRAME\\w*|TARGETOFFOCUSFRAME|FOCUSFRAMETOT\\w+|PARTYFRAME|PARTYMEMBERFRAMES|COMPACTRAIDFRAMECONTAINER|COMPACTRAIDFRAMEMANAGER|BOSSTARGETFRAMECONTAINER|ARENAENEMYFRAMESCONTAINER|ARENAENEMYFRAMES|ARENAPREPFRAMES|COMPACTARENAFRAME)$",
  "Move unit, party, raid, boss and arena frames", "UnitFrames", "done", "Phoenix frames have movers; Blizzard's are Edit Mode")
F(A, "settings::checkbox~^(RUNEFRAME|TOTEMBAR|TOTEMFRAME|WARLOCKPOWERFRAME|SHARDBARFRAME|MONKHARMONYBARFRAME|MONKSTAGGERBAR|MAGEARCANECHARGESFRAME|PRIESTBARFRAME|COMBOPOINTPLAYERFRAME|COMBOFRAME|EclipseBarFrame|ESSENCEPLAYERFRAME|PALADINPOWERBARFRAME|PALADINPOWERBAR|POWERBAR)$",
  "Move class power bars", "UnitFrames", "part", "Class resource sits on the player frame; a detached class bar is S18", "S18")
F(A, "settings::checkbox~^(EssentialCooldownViewer|BuffIconCooldownViewer|BuffBarCooldownViewer|UtilityCooldownViewer)$", "Move Cooldown Manager viewers", "Tracker", "done")
F(A, "settings::checkbox~^(BUFFS|DEBUFFS|CASTINGBAR|CASTINGBARTIMER|GAMETOOLTIP|GAMETOOLTIP_ONCURSOR|GAMETOOLTIP_ONCURSOR_NOTINCOMBAT|CHAT|CHATBUTTONFRAME|CHATEDITBOX|CHATTAB|CHATQUICKJOIN|MINIMAP|MINIMAPZONETEXT|MINIMAPFLAG|MINIMAPLFGFRAME|LFGMINIMAPFRAME|MINIMAPTRACKINGBUTTON|MINIMAPTRACKING|ExpansionLandingPageMinimapButton|QUESTTRACKER|QUESTITEMSANCHOR|MainStatusTrackingBarContainer|SecondaryStatusTrackingBarContainer|STATUSTRACKINGBARMANAGER|MAINMENUEXPBAR|REPUTATIONWATCHBAR|MAFPSFrame)$",
  "Move auras, cast bar, tooltip, chat, minimap and its buttons, tracker, status bars", "Movers", "done", "Owned by the matching Phoenix page or Edit Mode")
F(A, "settings::checkbox~^(UIWIDGETTOPCENTER|UIWIDGETBELOWMINIMAP|UIWIDGETPOWERBAR|ZONETEXTFRAME|UIERRORSFRAME|RAIDBOSSEMOTEFRAME|BOSSBANNER|ALERTFRAME|EventToastManagerFrame|READYCHECKLISTENERFRAME|OBJECTIVETRACKERBONUSBANNERFRAME)$",
  "Move widgets, zone / error / emote text, banners, alerts, toasts, ready check", "Movers", "done")
F(A, "settings::checkbox", "Move the remaining Blizzard frames (talking head, vehicle seat, durability, ghost, loss of control, mirror timers, queue status, loot, bonus roll, battlefield map, popups, role poll, encounter bar, archaeology, ticket, toasts)",
  "Movers", "miss", "", "S26")
F(A, "D4UISlider::slider", "Frame scale slider", "Movers", "done")

A = "idTip"
F(A, "", "IDs in tooltips: spell, item, NPC, quest, achievement, currency, mount, aura", "Tooltip", "done", n=8)
F(A, "", "IDs in tooltips: talent, criteria, ability, artifact power, enchant, bonus, gem, macro, set, visual, source, species, icon, area POI, vignette, expansion, object, trait node / entry / definition", "Tooltip", "miss",
  "Code may be reused under BSD-2 with the notice (docs/LICENSES); NPC IDs only when UnitCreatureID is not secret", "S26", n=19)

A = "AutoQueue"
F(A, "", "Accept role checks", "GroupFinder", "part",
  "Phoenix accepts with a key you press (secure click). AutoQueue calls CompleteLFGRoleCheck straight from the pop-up's OnShow, and our API reference lists no restriction on it, so an opt-in automatic mode looks possible (verify in game); it was left out by the S15 brief", "S26", n=2)
F(A, "", "Accept the dungeon-ready pop-up automatically", "GroupFinder", "imp",
  "Blizzard only enters through the pop-up's Enter button (AcceptProposal), which we treat as needing your click; a timer-driven Click() is not a hardware event, so Phoenix offers a key binding instead (in-game check)", n=1)
F(A, "", "Sign up automatically when a listing is double-clicked / without the dialog", "GroupFinder", "imp",
  "Signing up goes through Blizzard's own Sign Up button (Phoenix uses a secure click on it, S15); without your click or key press it is not built", n=2)
F(A, "", "Role bar (pick tank / healer / damage before queueing), minimap button, enable switch", "GroupFinder", "miss", "", "S28", n=5)

A = "Simulationcraft"
F(A, "", "/simc export with bags, bank, vault and catalyst", "Sim", "done", n=4)

A = "TrufiGCD"
F(A, "", "Ability history for the player", "SpellHistory", "done", n=8)
F(A, "", "Ability history for party, arena, target and focus (per-unit layout)", "SpellHistory", "part",
  "Other units' UNIT_SPELLCAST_SUCCEEDED spell IDs are secret in arenas and instances; possible in the open world only", "S28", n=24)
F(A, "", "Icon tooltips, stop scrolling on hover, spell ID print, blocklist, profiles, enable by zone type", "SpellHistory", "part", "", "S28", n=12)

A = "BugGrabber + BugSack"
F(A, "", "Error capture, viewer, chat notice, sound, minimap icon, font size, wipe", "Bugs", "done", n=11)

A = "Auctionator"
F(A, "BasicOptions::BasicOptions", "Auction house: auto scan and interval, small tabs, crafting info in professions", "AuctionHouse", "miss",
  "C_AuctionHouse.ReplicateItems scan once per 15 min; crafting costs from C_TradeSkillUI", "S22")
F(A, ["Shopping::Shopping", "ShoppingAlt::ShoppingAlt"], "Shopping lists and searches", "AuctionHouse", "miss", "Each search needs a hardware event (button click)", "S22")
F(A, ["Selling::Selling", "SellingAllItems::SellingAllItems", "Quantities::Quantities", "SellingShortcuts::SellingShortcuts"], "Selling: bag view, undercut rules, durations, quantities, shortcuts", "AuctionHouse", "miss",
  "Posting needs a hardware event per auction (C_AuctionHouse.PostItem); one click per post", "S22")
F(A, "Cancelling::Cancelling", "Cancel undercut auctions scan", "AuctionHouse", "miss", "Each cancel needs a click", "S22")
F(A, "Tooltips::Tooltips", "Auction / vendor / disenchant / mill / prospect prices in tooltips", "Tooltip", "miss", "Fed by the S22 price database", "S22")
F(A, ["Profile::Profile", "Advanced::Advanced"], "Auctionator profile and debug", "AuctionHouse", "skip", "Addon internals")

A = "WoW-API-main"
F(A, "", "API reference (documentation only, no user features)", "General", "skip", "Used as an API reference like /workspace/ref", n=0)
A = "EllesmereUI Locales"
F(A, "", "Locale strings (10 languages)", "General", "done", "Phoenix ships its own 10 locales", n=0)
