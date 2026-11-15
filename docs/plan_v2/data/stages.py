STAGES = [
 ("S6","Foundation v2: settings shell + widget kit + style library",9,[
   ("Settings window v2: 1280×800, icon rail + module list + page tabs + element chips + pinned preview dock + footer","2.5"),
   ("Widget kit: dual rows, section gate toggle, cog popups, ⇄ apply-to-all, Copy from…, per-row right-click reset, hover-preview dropdowns","2"),
   ("Pickers: font cards, texture cards, border/shadow style picker, colour swatch with Class/Theme tokens, sound list with ▶","1.5"),
   ("Shared style library (Core/Style): border styles (Pixel, Thin, Thick, Glow, Ember, Inset), shadows (Soft/Hard/Glow), backdrops — used by every module","1"),
   ("Search index over all 1,186 settings (labels, groups, synonyms) with jump-and-flash","0.5"),
   ("Profiles page: per-spec profile, per-character overrides, export by module, import with change preview, presets","1"),
   ("Appearance & General v2 (global fonts/borders/colours/glow every module inherits)","0.5")]),
 ("S7","Action Bars v2 (own secure bars) + Cooldown Text",8,[
   ("Secure bar containers (SecureHandlerStateTemplate) re-parenting Blizzard ActionButtons; Edit Mode bars hidden; fallback to Blizzard bars","3"),
   ("Per-bar layout (buttons, rows, size, spacing, grow, order, backdrop, border) + paging + state-driver visibility","2"),
   ("Buttons: shape, feedback tints (range / power / unusable via C_ActionBar), pushed/highlight/proc/assist styles, swipe","1.5"),
   ("Text: hotkey/macro/count/cooldown fonts & positions; short hotkeys; Cooldown Text module depth","1"),
   ("Extra bars: extra action, zone ability, vehicle exit, micro menu, bag bar, extra item bar","0.5")]),
 ("S8","Unit Frames v2 (own frames) incl. boss and arena",12,[
   ("Secure unit buttons for player, target, ToT, focus, focus-target, pet, boss1–5, arena1–5; Blizzard-frame mode kept","3"),
   ("Health: colour modes, gradient via C_CurveUtil colour curves, dark mode, absorbs / heal absorb / prediction (CreateUnitHealPredictionCalculator)","2"),
   ("Power bar + class power (pips, runes, stagger, soul fragments, Ebon Might), detached option","2"),
   ("Tag engine (secret-safe sinks: AbbreviateNumbers, UnitHealthPercent+curves, C_StringUtil) + text slots","2"),
   ("Portraits, indicators, threat, auras on frames (filters via Blizzard aura flags)","1.5"),
   ("Arena: trinket/racial/DR/spec + test frames","1.5")]),
 ("S9","Cast Bars v2 + Buffs & Debuffs v2",5,[
   ("Cast bars for player/target/focus/pet/boss: colours by state, spark, ticks, empower stages, latency, kick-ready tick, spell target, GCD + swing (Forever)","3"),
   ("Player buffs/debuffs: layout, sort, separate own, duration formats, colour by time, private aura anchor","2")]),
 ("S10","Nameplates depth",5,[
   ("Size/stacking CVars, target scale, non-target alpha, clickable area","1"),
   ("Colours: role-aware threat, reaction, quest, execute; target/focus/hover effects","1.5"),
   ("Cast bar (kick-ready, target, shield), auras rows, text layouts, class power on target, preview eye toggles","2.5")]),
 ("S11","Group Frames v2 (own party/raid headers)",8,[
   ("SecureGroupHeaderTemplate party/raid with 3 size profiles, sorting, role order, pets, MT/MA","3"),
   ("Indicators: dispel highlight (only mine), aggro, range, role/leader/ready/summon/res, private aura anchor","2"),
   ("Auras: HoT corners, debuff row, big defensive, filters; test raid 5/20/40","2"),
   ("Click casting via Blizzard Click Cast bindings","1")]),
 ("S12","Cooldown Manager depth + reminders",4,[
   ("Per-viewer rows/sizes/overflow, keep-in-place, glow styles, keybinds, buff bars","2.5"),
   ("Out-of-combat reminders (consumables, raid buffs, pet, healthstone)","1.5")]),
 ("S13","Interface modules to full depth",13,[
   ("Chat: window/backdrop/border, tabs, timestamps, class names, keyword highlight, edit box, chat bar, emotes","2.5"),
   ("Minimap: shapes incl. rectangle, elements (zone, clock, coords, difficulty…), button drawer, world map coords","2"),
   ("Tooltips: realm, guild rank, targeted-by, inspect ilvl/spec, raid progression, item counts, ID kinds","1.5"),
   ("Bags: columns, slot size, categories, slot extras, window, open/close rules","3"),
   ("Item Level: inspect, loot/vault/merchant, enchant/gem warnings, upgrade track","1"),
   ("Data Texts: per-panel layout, more sources, XP/rep/honor bars","1.5"),
   ("Skins: 14 more Blizzard windows","1.5")]),
 ("S14","Quests + Phoenix_UI_Data",9,[
   ("tools/build_questdata.py: ATT (MIT) + DB2 QuestPOI/TaxiNodes/AreaPOI → packed per-map data; separate load-on-demand Phoenix_UI_Data addon with LICENSE files","3"),
   ("Objective tracker restyle (fonts, widths, colours, auto-collapse)","1.5"),
   ("Quest helper: waypoint arrow, map pins for available quests (C_QuestLine), turn-ins (QuestPOI), quest NPC pins (ATT data), auto accept/turn-in, reward picker","4"),
   ("Opt-in contribution toggle (UI only; collector ships when backend approved)","0.5")]),
 ("S15","Group Finder",4,[
   ("Filter panel + Phoenix expression syntax (re-implemented, not PGF code)","2.5"),
   ("Helpers: one-click sign up, remember note, role/class icons, score tooltip, lockout hint, role-check accept","1.5")]),
 ("S16","Remaining modules",11,[
   ("Damage Meter restyle depth (bars, fonts, formats, second window)","2"),
   ("Combat Text: Phoenix scroll areas for own events","1.5"),
   ("Mythic+: chest timers, affixes, death breakdown, party keys window, teleports","2"),
   ("Movers: Blizzard frame list (move/scale) + snap to frames, nudge, unlock keybind","2"),
   ("QoL + Automation adds (banners, camera, markers bar, cursor, CVar browser, auto loot, gossip, role check)","1.5"),
   ("PvP adds, AFK screen, Spell History border/fail marks, Sim inclusion toggles, Encounters adds","2")]),
 ("S17","Community NPC data collector (needs approval)",4,[
   ("In-game collector (secret-safe, opt-in) + uploader channel + Cloudflare aggregation + CC0 publish into Phoenix_UI_Data","4")]),
]
