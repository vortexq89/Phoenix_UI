# Phoenix UI — module gap matrix (v2)

Generated from `data/spec_*.py` by `data/gen_gap.py` (2026-10-22). One row per user-facing setting. Composite controls are expanded: a font group is 5 rows (font, size, outline, shadow, colour), a border group is 3–5 rows (style, size, colour, shadow, shadow size), a backdrop is 4 rows, a position block is 5 rows.

**Columns:** *Now* = Phoenix rows today (options dump, cog sub-rows included) · *Target* = full spec below · *Has / Part / New* = target rows that Phoenix already has, has in a shallower form, or lacks.

**Status:** `has` = present · `part` = present but shallower (fewer choices, global instead of per-bar, etc.) · `new` = missing.  **Preview:** `live` = the pinned preview in the settings window redraws · `hover` = hovering a dropdown item previews it · `world` = shows test/unlocked frames in the game world · `none` = behaviour only.

**Per-unit / per-bar rule:** groups marked *per bar* or *per unit* are one set of controls with a unit/bar switcher plus *Copy from…* and *Apply to all*; they are counted once, not ×N.

## Summary

| Module | Group | Now | Target | Has | Part | New | References | How Phoenix builds it |
|---|---|---:|---:|---:|---:|---:|---|---|
| Action Bars | Action Bars & Cooldowns | 33 | 114 | 32 | 2 | 80 | EUI ActionBars 136 controls (BarVisibilityLayout, BarAppearance, Animations, XP/Rep, Menu/Bags) · WindTools ExtraItemBar 27 · MoveAny bar toggles | Own secure bar containers holding Blizzard's action buttons (EUI pattern); Edit Mode bars stay as fallback |
| Cooldown Text | Action Bars & Cooldowns | 3 | 12 | 1 | 5 | 6 | EUI cooldown numbers settings | Blizzard countdown numbers on all cooldown frames (C_DurationUtil text bindings) |
| Cooldown Manager | Action Bars & Cooldowns | 28 | 59 | 28 | 0 | 31 | EUI CooldownManager 152 controls (Bars, BuffBars, SpellPicker, glow conditions) · EUI AuraBuffReminders 49 | Skins and extends Blizzard's Cooldown Manager viewers (Essential, Utility, Buff icons, Buff bars); the only legal 'WeakAuras' in Midnight |
| Unit Frames | Unit Frames | 41 | 150 | 29 | 13 | 108 | EUI UnitFrames 356 controls (SharedBars, SharedAppearance, SharedCastAuras, MiniFrames, TextSlots) + ResourceBars 247 · sArena 416 (arena) · WindTools Quick Focus, Absorb, Role icon | Own secure unit frames (SecureUnitButtonTemplate) for player, target, target-of-target, focus, focus-target, pet, boss 1–5, arena 1–5; Blizzard skin kept as a 'Blizzard frames' mode |
| Group Frames | Unit Frames | 18 | 68 | 15 | 0 | 53 | EUI RaidFrames 247 controls (Frames, VisualBars, VisualIndicators, aura managers) · Blizzard compact raid frame options | Own secure party and raid headers (SecureGroupHeaderTemplate), Blizzard compact frames as fallback |
| Nameplates | Nameplates | 59 | 100 | 52 | 2 | 46 | EUI Nameplates 176 controls (General, DisplayLayout, DisplayBars, Colors, TextColoring) · WindTools friendly outline | Restyles Blizzard's nameplates (they stay Blizzard's secure frames) |
| Cast Bars | Combat | 23 | 55 | 20 | 4 | 31 | EUI ResourceBars CastBarPage 41 + UnitFrames cast section 32 + MythicTimer targeted spell bars 21 | Own cast bars for player, target, focus, pet, boss (UnitCastingInfo is secret only where restricted; text through display sinks) |
| Buffs & Debuffs | Combat | 15 | 41 | 15 | 0 | 26 | EUI PlayerAuraBars 43 + BlizzardSkin aura bits · ElvUI-style aura headers | Restyles Blizzard's player buff and debuff frames (BuffFrame/DebuffFrame); own aura bars optional |
| Combat Text | Combat | 16 | 26 | 16 | 0 | 10 | Blizzard FCT CVars · MSBT-like | Configures Blizzard floating combat text (CVars) + optional Phoenix scrolling areas |
| Damage Meter | Combat | 2 | 31 | 2 | 0 | 29 | EUI DamageMeters 82 | Restyles Blizzard's built-in damage meter (C_DamageMeter, 12.0) |
| Spell History | Combat | 6 | 12 | 6 | 0 | 6 | — | Row of recently cast spells |
| Chat | Interface | 17 | 51 | 12 | 8 | 31 | EUI Chat 57 · WindTools Social (chat bar, emotes, links) 16 · Prat-like features | Restyles Blizzard chat frames and adds tools; no chat replacement |
| Minimap | Interface | 5 | 41 | 2 | 3 | 36 | EUI Minimap 62 · WindTools Maps 29 (rectangle minimap, buttons bar, instance difficulty, world map reveal) | Restyles Blizzard's minimap cluster |
| Tooltips | Interface | 29 | 45 | 25 | 1 | 19 | EUI BlizzardSkin tooltip 23 · WindTools Tooltips 27 · idTip 27 ID kinds | Restyles GameTooltip and adds lines; IDs where idTip-style (BSD-2) |
| Bags | Interface | 6 | 47 | 5 | 0 | 42 | EUI Bags 45 · Baganator-style features | Restyles Blizzard's combined bag + bank; own sorting via C_Container |
| Item Level | Interface | 4 | 19 | 4 | 0 | 15 | EUI BlizzardSkin character sheet 30 · WindTools Item 27 (inspect, already known) | Item level on character, inspect, bags, loot frames |
| Data Texts | Interface | 35 | 47 | 14 | 7 | 26 | EUI DataBars 55 (XP/rep/honor bars) + MinimapDataText · ElvUI datatexts | Own data panels + broker (LDB) feeds |
| Skins | Interface | 3 | 28 | 3 | 0 | 25 | EUI BlizzardSkin 123 (character, popups, tooltips, skyriding, CDM, objective tracker) | Phoenix look for Blizzard windows |
| Appearance & General | Phoenix | 7 | 23 | 7 | 0 | 16 | EUI Fonts 37 + Textures + Colors + Glow + General ~90 | Theme, global fonts/textures/colours, scale, sounds; every module's 'Theme default' points here |
| Profiles | Phoenix | 0 | 8 | 0 | 1 | 7 | EUI Profiles 4 pages (Profiles, Presets, Overrides, FullExport) | Profiles, per-spec switching, import/export strings, presets |
| Layout (Movers) | Phoenix | 3 | 11 | 3 | 0 | 8 | MoveAny 150 frame toggles · EUI unlock mode (snap, grid, nudge, per-element) | Unlock mode for every Phoenix-owned frame + selected Blizzard frames (no Edit Mode conflicts) |
| Quality of life | Phoenix | 4 | 11 | 4 | 0 | 7 | EUI QoL 75 · WindTools Misc 112 | Small UI tweaks |
| Automation | Phoenix | 8 | 14 | 7 | 0 | 7 | EUI QoL 75 · WindTools Misc 112 | Small automations |
| AFK screen | Phoenix | 1 | 4 | 1 | 0 | 3 | ElvUI AFK | AFK screen |
| Bugs | Phoenix | 9 | 12 | 9 | 0 | 3 | BugSack-like · EUI none | Error catcher (being rebuilt by the other worker) |
| Quests | Content | 0 | 27 | 0 | 0 | 27 | EUI QuestTracker ~30 · WindTools Quest 41 · Questie (ARR/GPL, learn only) | NEW: quest tracker restyle + quest helper (giver/turn-in pins from ATT MIT data, DB2 QuestPOI and runtime C_QuestLine; community data later) |
| Group Finder | Content | 0 | 14 | 0 | 0 | 14 | PremadeGroupsFilter 105 variables (GPL-2, learn only) · EUI GroupFinder · WindTools LFG list | NEW: premade group list filters (PGF-style expressions re-implemented), sign-up helpers |
| Mythic+ | Content | 10 | 32 | 10 | 0 | 22 | EUI MythicTimer 125 · WindTools keystone tooltips | Own M+ timer (Blizzard Challenge APIs) + keystone tools |
| Encounters | Content | 61 | 65 | 61 | 0 | 4 | Phoenix S3 already deep · EUI none (EUI has no boss mod) | Restyles Blizzard Boss Timeline + warnings (C_EncounterTimeline), BigWigs bars style |
| PvP | Content | 3 | 8 | 4 | 0 | 4 | sArena 416 (arena frames — goes to Unit Frames › Arena) · WindTools Combat 33 | Battleground / arena helpers; arena frames live in Unit Frames |
| Sim | Content | 6 | 8 | 6 | 0 | 2 | simc addon (Unlicense) | Simulationcraft export + uploader results (S2) |
| Diagnostics | Phoenix | 0 | 3 | 0 | 3 | 0 | — | Status page (secret state, conflicts, versions) — exists as a page, not settings |
| **Total** | | **455** | **1186** | **393** | **49** | **744** | EllesmereUI 2,420 controls · WindTools 361 · sArena 416 · MoveAny ~150 | |

## Action Bars  (`ActionBars`)

*Now 33 → target 114* · has 32 · part 2 · new 80

**How:** Own secure bar containers holding Blizzard's action buttons (EUI pattern); Edit Mode bars stay as fallback

**References:** EUI ActionBars 136 controls (BarVisibilityLayout, BarAppearance, Animations, XP/Rep, Menu/Bags) · WindTools ExtraItemBar 27 · MoveAny bar toggles

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Enable bar | toggle |  | On for 1–4, pet, stance | world | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Buttons | slider | 1–12 | 12 | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Rows | slider | 1–12 | 1 | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Button width | slider | 16–120 px | 40 | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Button height | slider | 16–120 px | 40 | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Keep square | toggle |  | On | live | part |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Horizontal spacing | slider | -10–30 px | 2 | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Vertical spacing | slider | -10–30 px | 2 | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Grow direction | dropdown | Right / Left / Up / Down | Right | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Wrap direction | dropdown | Down / Up / Left / Right | Down | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Button order | dropdown | Normal / Reversed | Normal | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Show empty slots | toggle |  | Off | live | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Click-through | toggle |  | Off | none | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Lock buttons (no drag) | toggle |  | Off | none | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Anchor | dropdown | 9 points + frame picker | per element | world | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | X offset | slider | -2000–2000 | per element | world | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Y offset | slider | -1200–1200 | per element | world | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | new |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Scale | slider | 50–200 % | 100 | world | new |
| Bars › Backdrop (per bar) | Bar backdrop | toggle |  | Off | live | new |
| Bars › Backdrop (per bar) | Bar backdrop texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Bars › Backdrop (per bar) | Bar backdrop colour | colour | colour + theme token | #0B0C0F | live | new |
| Bars › Backdrop (per bar) | Bar backdrop opacity | slider | 0–100 % | 50 | live | new |
| Bars › Backdrop (per bar) | Backdrop padding | slider | 0–20 px | 3 | live | new |
| Bars › Backdrop (per bar) | Bar border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | None | hover | new |
| Bars › Backdrop (per bar) | Bar border size | slider | 0–4 px (pixel-perfect) | 1 | live | new |
| Bars › Backdrop (per bar) | Bar border colour | colour | colour + class colour + quality + theme token | #000000 | live | new |
| Bars › Backdrop (per bar) | Bar border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Bars › Backdrop (per bar) | Bar border shadow size | slider | 0–16 px | 4 | live | new |
| Bars › Visibility (per bar) | Show in combat | toggle |  | On | world | new |
| Bars › Visibility (per bar) | Show out of combat | toggle |  | On | world | new |
| Bars › Visibility (per bar) | Fade out of combat | toggle |  | Off | world | new |
| Bars › Visibility (per bar) | Out-of-combat opacity | slider | 0–100 % | 40 | world | new |
| Bars › Visibility (per bar) | Show on mouseover | toggle |  | Off | world | new |
| Bars › Visibility (per bar) | Hide in vehicles / pet battles | toggle |  | On | none | new |
| Bars › Visibility (per bar) | Custom state macro | input | [combat] show; hide … |  | none | new |
| Bars › Visibility (per bar) | Show while dragging a spell | toggle |  | On | world | new |
| Bars › Visibility (per bar) | Show while spellbook open | toggle |  | On | world | new |
| Bars › Visibility (per bar) | Mouseover reveals all bars | toggle |  | Off | world | new |
| Bars › Visibility (per bar) | Bar opacity | slider | 0–100 % | 100 | world | new |
| Bars › Paging (bar 1) | Form/stance paging | toggle |  | On | none | new |
| Bars › Paging (bar 1) | Skyriding paging | toggle |  | On | none | new |
| Bars › Paging (bar 1) | Modifier paging (shift/ctrl/alt → bar) | dropdown | Off / bar 2–6 | Off | none | new |
| Bars › Paging (bar 1) | Possess / override paging | toggle |  | On | none | new |
| Bars › Paging (bar 1) | Paging arrows | toggle |  | Off | live | new |
| Buttons › Shape and icon (all bars, with per-bar override) | Button shape | dropdown | Square / Rounded / Circle / Hexagon / Blizzard | Square | hover | part |
| Buttons › Shape and icon (all bars, with per-bar override) | Icon zoom (crop) | slider | 0–20 % | 8 | live | has |
| Buttons › Shape and icon (all bars, with per-bar override) | Icon desaturate on cooldown | toggle |  | Off | live | new |
| Buttons › Shape and icon (all bars, with per-bar override) | Icon opacity on cooldown | slider | 0–100 % | 100 | live | new |
| Buttons › Shape and icon (all bars, with per-bar override) | Icon background (empty slot) | slider | 0–100 % | 40 | live | new |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border shadow size | slider | 0–16 px | 4 | live | new |
| Buttons › Shape and icon (all bars, with per-bar override) | Equipped item border colour | toggle |  | On | live | new |
| Buttons › Shape and icon (all bars, with per-bar override) | Item quality border | toggle |  | Off | live | new |
| Buttons › Feedback | Out-of-range tint | toggle |  | On | live | has |
| Buttons › Feedback | Out-of-range colour | colour |  | #E64040 | live | has |
| Buttons › Feedback | Not-enough-power tint | toggle |  | On | live | new |
| Buttons › Feedback | Not-enough-power colour | colour |  | #4060E6 | live | new |
| Buttons › Feedback | Unusable tint | toggle |  | On | live | new |
| Buttons › Feedback | Unusable colour | colour |  | #666666 | live | new |
| Buttons › Feedback | Tint target | dropdown | Icon / Hotkey text / Both | Icon | live | new |
| Buttons › Feedback | Pushed style | dropdown | Blizzard / Accent flash / Darken / None | Accent flash | hover | new |
| Buttons › Feedback | Highlight style | dropdown | Blizzard / Accent border / Glow / None | Accent border | hover | new |
| Buttons › Feedback | Checked (active) style | dropdown | Blizzard / Accent border / None | Accent border | hover | new |
| Buttons › Feedback | Proc glow style | dropdown | Blizzard / Pixel / Autocast / Button / None | Blizzard | hover | new |
| Buttons › Feedback | Proc glow colour | colour |  | #FFD34A | live | new |
| Buttons › Feedback | Assisted highlight (one-button assist) | dropdown | Blizzard / Accent ring / Off | Blizzard | hover | new |
| Buttons › Feedback | Hide casting animation | toggle |  | Off | live | new |
| Buttons › Feedback | Cooldown swipe opacity | slider | 0–100 % | 80 | live | new |
| Buttons › Feedback | Cooldown edge (bling) | toggle |  | On | live | new |
| Buttons › Feedback | GCD swipe | toggle |  | On | live | new |
| Buttons › Feedback | Disable button tooltips | dropdown | Never / In combat / Always | Never | none | new |
| Text › Hotkey | Show hotkeys | toggle |  | On | live | has |
| Text › Hotkey | Hotkey font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text › Hotkey | Hotkey size | slider | 6–40 | 11 | live | has |
| Text › Hotkey | Hotkey outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text › Hotkey | Hotkey shadow | toggle |  | Off | live | has |
| Text › Hotkey | Hotkey colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text › Hotkey | Hotkey anchor | dropdown | 9 points | Top right | live | has |
| Text › Hotkey | Hotkey X offset | slider | -200–200 | 0 | live | has |
| Text › Hotkey | Hotkey Y offset | slider | -200–200 | 0 | live | has |
| Text › Hotkey | Short hotkey labels (S-1, C-F …) | toggle |  | On | live | new |
| Text › Macro name | Show macro names | toggle |  | Off | live | has |
| Text › Macro name | Macro font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text › Macro name | Macro size | slider | 6–40 | 10 | live | has |
| Text › Macro name | Macro outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text › Macro name | Macro shadow | toggle |  | Off | live | has |
| Text › Macro name | Macro colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text › Macro name | Macro anchor | dropdown | 9 points | Bottom | live | has |
| Text › Macro name | Macro X offset | slider | -200–200 | 0 | live | has |
| Text › Macro name | Macro Y offset | slider | -200–200 | 0 | live | has |
| Text › Count / charges | Count font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text › Count / charges | Count size | slider | 6–40 | 12 | live | has |
| Text › Count / charges | Count outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text › Count / charges | Count shadow | toggle |  | Off | live | has |
| Text › Count / charges | Count colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text › Count / charges | Count anchor | dropdown | 9 points | Bottom right | live | has |
| Text › Count / charges | Count X offset | slider | -200–200 | 0 | live | has |
| Text › Count / charges | Count Y offset | slider | -200–200 | 0 | live | has |
| Text › Count / charges | Hide charge count at 0 | toggle |  | Off | live | new |
| Text › Cooldown numbers | Cooldown numbers (Blizzard countdown) | toggle |  | On | live | new |
| Text › Cooldown numbers | Cooldown number size | slider | 6–30 | 14 | live | new |
| Text › Cooldown numbers | Charge recharge numbers | toggle |  | On | live | new |
| Extra bars | Extra action / zone ability button skin | toggle |  | On | world | new |
| Extra bars | Extra button scale | slider | 50–200 % | 100 | world | new |
| Extra bars | Hide extra button artwork | toggle |  | Off | world | new |
| Extra bars | Vehicle exit button skin | toggle |  | On | world | new |
| Extra bars | Micro menu bar (layout, size, mouseover) | dropdown | Hidden / Bar / Mouseover | Bar | world | new |
| Extra bars | Bag bar (layout, size, mouseover) | dropdown | Hidden / Bar / Mouseover | Mouseover | world | new |
| Extra bars | Extra item bar (quest items, consumables) | toggle |  | Off | world | new |
| Extra bars | Extra item bar: custom item list | list | item IDs |  | none | new |

## Cooldown Text  (`CooldownText`)

*Now 3 → target 12* · has 1 · part 5 · new 6

**How:** Blizzard countdown numbers on all cooldown frames (C_DurationUtil text bindings)

**References:** EUI cooldown numbers settings

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Countdown | Countdown numbers | toggle |  | On | live | has |
| Countdown | Countdown font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | part |
| Countdown | Countdown size | slider | 6–40 | 14 | live | part |
| Countdown | Countdown outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | part |
| Countdown | Countdown shadow | toggle |  | Off | live | part |
| Countdown | Countdown colour | colour | colour + class colour + theme token | #FFFFFF | live | part |
| Countdown | Colour by remaining (expiring / seconds / minutes) | colour | 3 colours | red / yellow / white | live | new |
| Countdown | Expiring threshold | slider | 0–10 s | 3 | live | new |
| Countdown | Decimals below | slider | 0–10 s | 0 | live | new |
| Countdown | Minimum duration shown | slider | 0–10 s | 1.5 | none | new |
| Countdown | Hide on aura icons | toggle |  | Off | live | new |
| Countdown | Scale with icon size | toggle |  | On | live | new |

## Cooldown Manager  (`Tracker`)

*Now 28 → target 59* · has 28 · part 0 · new 31

**How:** Skins and extends Blizzard's Cooldown Manager viewers (Essential, Utility, Buff icons, Buff bars); the only legal 'WeakAuras' in Midnight

**References:** EUI CooldownManager 152 controls (Bars, BuffBars, SpellPicker, glow conditions) · EUI AuraBuffReminders 49

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Viewers › Layout (Essential / Utility / Buff icons, each) | Icon size | slider | 16–100 px | 40 | live | new |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Icons per row | slider | 1–15 | 8 | live | new |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Rows | slider | 1–6 | 2 | live | new |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Second row icon size | slider | -20–20 px vs first | -6 | live | new |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Spacing | slider | -10–20 px | 2 | live | new |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Row growth | dropdown | Down / Up | Down | live | new |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Vertical orientation | toggle |  | Off | live | new |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Keep buffs in place (no shifting) | toggle |  | Off | live | new |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Overflow to | dropdown | Next row / Utility viewer / Hide | Next row | live | new |
| Viewers › Icons | Phoenix style | toggle |  | On | live | has |
| Viewers › Icons | Square icons | toggle |  | On | live | has |
| Viewers › Icons | Icon zoom | slider | 0–20 % | 8 | live | has |
| Viewers › Icons | Icon border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Viewers › Icons | Icon border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Viewers › Icons | Icon border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Viewers › Icons | Icon border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Viewers › Icons | Icon border shadow size | slider | 0–16 px | 4 | live | new |
| Viewers › Icons | Desaturate when on cooldown | toggle |  | On | live | new |
| Viewers › Icons | Suppress GCD swipe | toggle |  | On | live | new |
| Viewers › Icons | Show keybind | toggle |  | Off | live | new |
| Viewers › Icons | Proc glow style | dropdown | Blizzard / Pixel / Autocast / Button | Blizzard | hover | new |
| Viewers › Icons | Glow colour / lines / speed / thickness | colour | colour + 3 sliders | gold / 8 / 4 / 2 | live | new |
| Viewers › Icons | Timer font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Viewers › Icons | Timer size | slider | 6–40 | 14 | live | has |
| Viewers › Icons | Timer outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Viewers › Icons | Timer shadow | toggle |  | Off | live | has |
| Viewers › Icons | Timer colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Viewers › Icons | Stacks and charges font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Viewers › Icons | Stacks and charges size | slider | 6–40 | 12 | live | has |
| Viewers › Icons | Stacks and charges outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Viewers › Icons | Stacks and charges shadow | toggle |  | Off | live | has |
| Viewers › Icons | Stacks and charges colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Buff bars | Bar width / height | slider | 40–800 / 8–60 px | 220 / 20 | live | new |
| Buff bars | Buff bar texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has |
| Buff bars | Buff bar fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Buff bars | Buff bar smooth fill | toggle |  | On | live | new |
| Buff bars | Buff bar gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Buff bars | Bar colour | colour | class / custom | class | live | has |
| Buff bars | Bar background | toggle |  | On | live | has |
| Buff bars | Bar background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Buff bars | Bar background colour | colour | colour + theme token | #0B0C0F | live | has |
| Buff bars | Bar background opacity | slider | 0–100 % | 70 | live | has |
| Buff bars | Spell name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Buff bars | Spell name size | slider | 6–40 | 12 | live | has |
| Buff bars | Spell name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Buff bars | Spell name shadow | toggle |  | Off | live | has |
| Buff bars | Spell name colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Buff bars | Icon position | dropdown | Left / Right / Off | Left | live | new |
| Buff bars | Stack-based fill | toggle |  | Off | live | new |
| Visibility | Fade out of combat | toggle |  | On | world | has |
| Visibility | Opacity out of combat | slider | 0–100 % | 40 | world | has |
| Visibility | Show only with a target | toggle |  | Off | world | new |
| Reminders (out of combat) | Missing flask / food / rune / weapon oil | toggle | per type | On in instances | world | new |
| Reminders (out of combat) | Missing raid buffs (class) | toggle |  | On | world | new |
| Reminders (out of combat) | Missing pet / wrong pet | toggle |  | On | world | new |
| Reminders (out of combat) | Healthstone / soulstone | toggle |  | On | world | new |
| Reminders (out of combat) | Ready-check mana warning | toggle |  | On | world | new |
| Reminders (out of combat) | Reminder sound | dropdown | sound list with play | None | hover | new |
| Reminders (out of combat) | Reminder icon size / position | slider | 16–64 + anchor | 36 | world | new |

## Unit Frames  (`UnitFrames`)

*Now 41 → target 150* · has 29 · part 13 · new 108

**How:** Own secure unit frames (SecureUnitButtonTemplate) for player, target, target-of-target, focus, focus-target, pet, boss 1–5, arena 1–5; Blizzard skin kept as a 'Blizzard frames' mode

**References:** EUI UnitFrames 356 controls (SharedBars, SharedAppearance, SharedCastAuras, MiniFrames, TextSlots) + ResourceBars 247 · sArena 416 (arena) · WindTools Quick Focus, Absorb, Role icon

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Frame (per unit, with Copy from / Apply to all) | Enable frame | toggle |  | On | world | new |
| Frame (per unit, with Copy from / Apply to all) | Frame mode | dropdown | Phoenix frames / Blizzard frames restyled | Phoenix frames | world | new |
| Frame (per unit, with Copy from / Apply to all) | Width | slider | 60–400 px | 220 (player/target), 120 (small) | live | new |
| Frame (per unit, with Copy from / Apply to all) | Height | slider | 16–120 px | 44 | live | new |
| Frame (per unit, with Copy from / Apply to all) | Anchor | dropdown | 9 points + frame picker | per element | world | new |
| Frame (per unit, with Copy from / Apply to all) | X offset | slider | -2000–2000 | per element | world | new |
| Frame (per unit, with Copy from / Apply to all) | Y offset | slider | -1200–1200 | per element | world | new |
| Frame (per unit, with Copy from / Apply to all) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | new |
| Frame (per unit, with Copy from / Apply to all) | Scale | slider | 50–200 % | 100 | world | new |
| Frame (per unit, with Copy from / Apply to all) | Frame background | toggle |  | On | live | new |
| Frame (per unit, with Copy from / Apply to all) | Frame background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Frame (per unit, with Copy from / Apply to all) | Frame background colour | colour | colour + theme token | #0B0C0F | live | new |
| Frame (per unit, with Copy from / Apply to all) | Frame background opacity | slider | 0–100 % | 80 | live | new |
| Frame (per unit, with Copy from / Apply to all) | Frame border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | part |
| Frame (per unit, with Copy from / Apply to all) | Frame border size | slider | 0–4 px (pixel-perfect) | 1 | live | part |
| Frame (per unit, with Copy from / Apply to all) | Frame border colour | colour | colour + class colour + quality + theme token | #000000 | live | part |
| Frame (per unit, with Copy from / Apply to all) | Frame border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Frame (per unit, with Copy from / Apply to all) | Frame border shadow size | slider | 0–16 px | 4 | live | new |
| Frame (per unit, with Copy from / Apply to all) | Hover highlight | dropdown | None / Border / Glow | Border | live | new |
| Frame (per unit, with Copy from / Apply to all) | Target highlight (on group/boss) | dropdown | None / Border / Glow | Border | live | new |
| Frame (per unit, with Copy from / Apply to all) | Out-of-range opacity | slider | 10–100 % | 55 | live | part |
| Frame (per unit, with Copy from / Apply to all) | Fade out of combat (player) | toggle |  | Off | world | new |
| Frame (per unit, with Copy from / Apply to all) | Out-of-combat opacity | slider | 0–100 % | 100 | world | new |
| Frame (per unit, with Copy from / Apply to all) | Show tooltip on hover | dropdown | Always / Out of combat / Never | Out of combat | none | new |
| Frame (per unit, with Copy from / Apply to all) | Click casting (Blizzard Click Cast bindings) | toggle |  | On | none | new |
| Health bar | Health bar height share | slider | 40–100 % | 80 | live | new |
| Health bar | Health texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | part |
| Health bar | Health fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Health bar | Health smooth fill | toggle |  | On | live | new |
| Health bar | Health gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Health bar | Colour mode | dropdown | Class / Reaction / Fixed / Gradient by health / Class gradient | Class | hover | part |
| Health bar | Fixed colour | colour |  | #2E2E33 | live | new |
| Health bar | Gradient low/mid/high colours | colour | 3 colours | red/yellow/green | live | new |
| Health bar | Tapped colour | colour |  | #8C8C8C | live | new |
| Health bar | Disconnected / dead colour | colour |  | #555555 | live | new |
| Health bar | Dark mode (dark fill, coloured background) | toggle |  | Off | hover | new |
| Health bar | Background colour mode | dropdown | Class (dimmed) / Fixed / Same as fill | Fixed | live | part |
| Health bar | Background opacity | slider | 0–100 % | 60 | live | has |
| Health bar | Reverse fill | toggle |  | Off | live | new |
| Absorbs and heal prediction | Absorb shield | dropdown | Off / Overlay / Stacked bar / Striped | Striped | hover | new |
| Absorbs and heal prediction | Absorb opacity | slider | 5–100 % | 60 | live | new |
| Absorbs and heal prediction | Over-absorb glow line | toggle |  | On | live | new |
| Absorbs and heal prediction | Heal absorb | dropdown | Off / Overlay / Striped | Overlay | hover | new |
| Absorbs and heal prediction | Heal prediction | toggle |  | On | live | new |
| Absorbs and heal prediction | Overheal shown | slider | 0–50 % | 10 | live | new |
| Absorbs and heal prediction | Prediction colours (mine / others) | colour | 2 colours | green / light green | live | new |
| Power bar | Show power bar | dropdown | Always / Mana users / Never | Always | live | part |
| Power bar | Power bar height | slider | 0–40 px | 6 | live | new |
| Power bar | Position | dropdown | Below / Above / Inside bottom / Detached | Below | live | new |
| Power bar | Detached width | slider | 0–400 px | 0 (= frame) | live | new |
| Power bar | Power texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | new |
| Power bar | Power fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Power bar | Power smooth fill | toggle |  | On | live | new |
| Power bar | Power gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Power bar | Colour by power type | toggle |  | On | live | has |
| Power bar | Custom power colours | colour | per power type | Blizzard | live | new |
| Power bar | Spell cost prediction | toggle |  | On | live | new |
| Power bar | Mana regen spark | dropdown | Off / Spark / Tick | Off | live | new |
| Class power (player) | Show class power | dropdown | Off / Attached / Detached | Attached | live | new |
| Class power (player) | Pip height | slider | 2–30 px | 8 | live | new |
| Class power (player) | Pip spacing | slider | 0–10 px | 2 | live | new |
| Class power (player) | Pip shape | dropdown | Bar / Square / Round | Bar | hover | new |
| Class power (player) | Colour mode | dropdown | Class / Power type / Custom | Power type | live | new |
| Class power (player) | Charged colour | colour |  | #4FC3F7 | live | new |
| Class power (player) | Empty pip opacity | slider | 0–100 % | 25 | live | new |
| Class power (player) | Runes sorted by ready time | toggle |  | On | live | new |
| Class power (player) | Stagger / Soul fragments / Ebon Might extras | toggle |  | On | live | new |
| Class power (player) | Fade out of combat | toggle |  | Off | world | new |
| Text tags (left / center / right / top) | Tag system | input | [name] [health:current] [health:percent] [power:current] [level] [classification] [status] [group] … | Left: [name]  Right: [health:percent] | live | new |
| Text tags (left / center / right / top) | Health text format | dropdown | Current / Percent / Current | Percent / Deficit / Current / Max | Current | Percent | hover | part |
| Text tags (left / center / right / top) | Abbreviate numbers | dropdown | Blizzard (K/M) / Full / Asian (萬/億) | Blizzard | live | new |
| Text tags (left / center / right / top) | Decimals | slider | 0–2 | 1 | live | new |
| Text tags (left / center / right / top) | Hide when full health | toggle |  | Off | live | new |
| Text tags (left / center / right / top) | Name max length | slider | 0–30 chars | 16 | live | new |
| Text tags (left / center / right / top) | Name colour | dropdown | Class / Reaction / White / Custom | White | live | part |
| Text tags (left / center / right / top) | Name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text tags (left / center / right / top) | Name size | slider | 6–40 | 13 | live | has |
| Text tags (left / center / right / top) | Name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text tags (left / center / right / top) | Name shadow | toggle |  | Off | live | has |
| Text tags (left / center / right / top) | Name colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text tags (left / center / right / top) | Name anchor | dropdown | 9 points | Left | live | new |
| Text tags (left / center / right / top) | Name X offset | slider | -200–200 | 0 | live | new |
| Text tags (left / center / right / top) | Name Y offset | slider | -200–200 | 0 | live | new |
| Text tags (left / center / right / top) | Health text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text tags (left / center / right / top) | Health text size | slider | 6–40 | 12 | live | has |
| Text tags (left / center / right / top) | Health text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text tags (left / center / right / top) | Health text shadow | toggle |  | Off | live | has |
| Text tags (left / center / right / top) | Health text colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text tags (left / center / right / top) | Health text anchor | dropdown | 9 points | Right | live | new |
| Text tags (left / center / right / top) | Health text X offset | slider | -200–200 | 0 | live | new |
| Text tags (left / center / right / top) | Health text Y offset | slider | -200–200 | 0 | live | new |
| Text tags (left / center / right / top) | Power text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text tags (left / center / right / top) | Power text size | slider | 6–40 | 10 | live | has |
| Text tags (left / center / right / top) | Power text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text tags (left / center / right / top) | Power text shadow | toggle |  | Off | live | has |
| Text tags (left / center / right / top) | Power text colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text tags (left / center / right / top) | Power text anchor | dropdown | 9 points | Center | live | new |
| Text tags (left / center / right / top) | Power text X offset | slider | -200–200 | 0 | live | new |
| Text tags (left / center / right / top) | Power text Y offset | slider | -200–200 | 0 | live | new |
| Text tags (left / center / right / top) | Level text (difficulty colour) | toggle |  | On (target) | live | new |
| Portrait | Portrait | dropdown | Off / 3D model / 2D / Class icon | Off | hover | part |
| Portrait | Portrait position | dropdown | Left / Right / Inside bar (overlay) | Left | live | new |
| Portrait | Portrait size | slider | -50–100 % of height | 100 | live | new |
| Portrait | Portrait shape | dropdown | Square / Round | Square | hover | new |
| Portrait | 3D camera zoom | slider | 100–300 % | 100 | live | new |
| Portrait | Overlay opacity | slider | 0–100 % | 35 | live | new |
| Auras on frames (buffs / debuffs, per unit) | Buffs | dropdown | Off / Above / Below / Left / Right | Above (target) | live | part |
| Auras on frames (buffs / debuffs, per unit) | Debuffs | dropdown | Off / Above / Below / Left / Right | Above (target) | live | part |
| Auras on frames (buffs / debuffs, per unit) | Icon size | slider | 10–70 px | 22 | live | new |
| Auras on frames (buffs / debuffs, per unit) | Per row | slider | 1–20 | 8 | live | new |
| Auras on frames (buffs / debuffs, per unit) | Max icons | slider | 1–40 | 16 | live | new |
| Auras on frames (buffs / debuffs, per unit) | Spacing | slider | -1–10 px | 2 | live | new |
| Auras on frames (buffs / debuffs, per unit) | Growth | dropdown | Right-Up / Right-Down / Left-Up / Left-Down | Right-Up | live | new |
| Auras on frames (buffs / debuffs, per unit) | Filter | dropdown | All / Mine only / Dispellable / Important (Blizzard flag) / Blizzard default | Blizzard default | none | new |
| Auras on frames (buffs / debuffs, per unit) | Dispel-type border colours | toggle |  | On | live | new |
| Auras on frames (buffs / debuffs, per unit) | Desaturate others' debuffs | toggle |  | On | live | new |
| Auras on frames (buffs / debuffs, per unit) | Icon zoom | slider | 0–20 % | 8 | live | has |
| Auras on frames (buffs / debuffs, per unit) | Aura border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Auras on frames (buffs / debuffs, per unit) | Aura border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Auras on frames (buffs / debuffs, per unit) | Aura border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Auras on frames (buffs / debuffs, per unit) | Aura duration font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Auras on frames (buffs / debuffs, per unit) | Aura duration size | slider | 6–40 | 10 | live | new |
| Auras on frames (buffs / debuffs, per unit) | Aura duration outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Auras on frames (buffs / debuffs, per unit) | Aura duration shadow | toggle |  | Off | live | new |
| Auras on frames (buffs / debuffs, per unit) | Aura duration colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks size | slider | 6–40 | 11 | live | has |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks shadow | toggle |  | Off | live | has |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Auras on frames (buffs / debuffs, per unit) | Cooldown swipe | toggle |  | On | live | new |
| Cast bar on frame (see Cast Bars for the full set) | Attach cast bar | dropdown | Off / Below / Above / Inside / Detached | Below (target, focus, boss) | world | new |
| Cast bar on frame (see Cast Bars for the full set) | Cast bar height | slider | 6–40 px | 16 | live | new |
| Indicators | Raid marker | toggle |  | On | live | has |
| Indicators | Raid marker size / position | slider | 12–48 px + anchor | 18, top | live | new |
| Indicators | Leader / assist icon | toggle |  | On | live | has |
| Indicators | Role icon | dropdown | Off / Phoenix / Blizzard | Phoenix | hover | new |
| Indicators | Combat indicator | dropdown | Off / Icon / Glow | Icon | hover | new |
| Indicators | Resting indicator | toggle |  | On | live | new |
| Indicators | PvP / prestige icon | toggle |  | Off | live | has |
| Indicators | Elite / rare dragon | dropdown | Off / Phoenix / Blizzard | Phoenix | hover | new |
| Indicators | Threat border on target | toggle |  | On | live | new |
| Indicators | Threat % text | toggle |  | Off | live | new |
| Indicators | Ready check / summon / resurrect | toggle |  | On | live | new |
| Boss and arena frames | Boss frames (1–5) | toggle |  | On | world | new |
| Boss and arena frames | Arena frames (1–5) | toggle |  | On | world | new |
| Boss and arena frames | Spacing / growth | slider | 0–60 px + Up/Down | 28, Down | world | new |
| Boss and arena frames | Arena: trinket / racial / DR tracker | toggle |  | On | world | new |
| Boss and arena frames | Arena: spec icon | toggle |  | On | world | new |
| Boss and arena frames | Test frames | button | show sample boss/arena frames |  | world | new |

## Group Frames  (`GroupFrames`)

*Now 18 → target 68* · has 15 · part 0 · new 53

**How:** Own secure party and raid headers (SecureGroupHeaderTemplate), Blizzard compact frames as fallback

**References:** EUI RaidFrames 247 controls (Frames, VisualBars, VisualIndicators, aura managers) · Blizzard compact raid frame options

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Layout (party / raid 10–20 / raid 21–40 profiles) | Use Phoenix group frames | toggle |  | On | world | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Frame width | slider | 40–300 px | 92 | live | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Frame height | slider | 20–150 px | 48 | live | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Frame spacing | slider | -5–15 px | 2 | live | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Group spacing | slider | -5–30 px | 8 | live | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Unit growth | dropdown | Down / Up / Right / Left | Down | live | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Group growth | dropdown | Right / Left / Down / Up | Right | live | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Sort by | dropdown | Group / Role / Class / Name / Index | Role | none | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Role order | reorder | Tank, Healer, Damage | T-H-D | none | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Self position | dropdown | Normal / First / Last / Hidden | First | none | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Show when solo | toggle |  | Off | world | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Show pets | toggle |  | Off | world | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Main tank / assist group | toggle |  | Off | world | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Hide groups 5–8 in Mythic raid | toggle |  | On | none | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Anchor | dropdown | 9 points + frame picker | per element | world | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | X offset | slider | -2000–2000 | per element | world | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Y offset | slider | -1200–1200 | per element | world | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | new |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Scale | slider | 50–200 % | 100 | world | new |
| Health and power | Health texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has |
| Health and power | Health fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Health and power | Health smooth fill | toggle |  | On | live | new |
| Health and power | Health gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Health and power | Colour mode | dropdown | Class / Fixed / Gradient | Class | hover | new |
| Health and power | Background opacity | slider | 0–100 % | 60 | live | has |
| Health and power | Absorb / heal absorb / heal prediction | dropdown | per type: Off / Overlay / Striped | Striped / Overlay / On | hover | new |
| Health and power | Power bar for | dropdown | None / Healers / All | Healers | live | new |
| Health and power | Power bar height | slider | 1–20 px | 4 | live | new |
| Health and power | Frame border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Health and power | Frame border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Health and power | Frame border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Health and power | Frame border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Health and power | Frame border shadow size | slider | 0–16 px | 4 | live | new |
| Text | Name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Name size | slider | 6–40 | 12 | live | has |
| Text | Name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Name shadow | toggle |  | Off | live | has |
| Text | Name colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Name max length | slider | 0–30 | 10 | live | new |
| Text | Name colour | dropdown | Class / White / Custom | Class | live | new |
| Text | Name anchor | dropdown | 9 points | Center | live | new |
| Text | Name X offset | slider | -200–200 | 0 | live | new |
| Text | Name Y offset | slider | -200–200 | 0 | live | new |
| Text | Status text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Status text size | slider | 6–40 | 10 | live | has |
| Text | Status text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Status text shadow | toggle |  | Off | live | has |
| Text | Status text colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Health text | dropdown | Off / Percent / Deficit / Current | Off | hover | new |
| Indicators | Role icon (hide in combat option) | dropdown | Off / Phoenix / Blizzard | Phoenix | hover | new |
| Indicators | Leader icon | toggle |  | On | live | new |
| Indicators | Raid marker | toggle |  | On | live | new |
| Indicators | Ready check / summon / resurrection | toggle |  | On | live | new |
| Indicators | Dispel highlight | dropdown | Off / Border / Overlay / Gradient | Overlay | hover | new |
| Indicators | Only dispellable by me | toggle |  | On | live | new |
| Indicators | Dispel colours | colour | per type | Blizzard | live | new |
| Indicators | Aggro / threat border | slider | 0–4 px | 2 | live | new |
| Indicators | Out-of-range opacity | slider | 10–100 % | 40 | live | new |
| Indicators | Missing raid buff icon | toggle |  | Off | live | new |
| Indicators | Private aura anchor | toggle |  | On | live | new |
| Auras | Buffs (mine, HoTs) | dropdown | Off / Corners / Row | Corners | live | new |
| Auras | Debuffs | dropdown | Off / Row / Center | Row | live | new |
| Auras | Buff size | slider | 8–40 px | 14 | live | new |
| Auras | Debuff size | slider | 8–40 px | 18 | live | new |
| Auras | Max debuffs | slider | 1–10 | 3 | live | new |
| Auras | Big defensive / external icon | toggle |  | On | live | new |
| Auras | Aura filter | dropdown | Blizzard default / Raid / Mine | Blizzard default | none | new |
| Auras | Test raid (5 / 20 / 40) | button |  |  | world | new |

## Nameplates  (`NamePlates`)

*Now 59 → target 100* · has 52 · part 2 · new 46

**How:** Restyles Blizzard's nameplates (they stay Blizzard's secure frames)

**References:** EUI Nameplates 176 controls (General, DisplayLayout, DisplayBars, Colors, TextColoring) · WindTools friendly outline

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Size and stacking | Enemy width | slider | 80–250 px | 140 | live | new |
| Size and stacking | Enemy height | slider | 6–40 px | 12 | live | new |
| Size and stacking | Friendly width / height | slider | 60–250 / 4–30 px | 110 / 8 | live | new |
| Size and stacking | Friendly: name only | toggle |  | On | live | new |
| Size and stacking | Stacking | dropdown | Overlap / Stacked | Stacked | none | new |
| Size and stacking | Vertical spacing (stacked) | slider | 50–200 % | 100 | none | new |
| Size and stacking | Clickable area width / height | slider | 50–250 % | 100 | none | new |
| Size and stacking | Target scale | slider | 50–200 % | 115 | live | new |
| Size and stacking | Non-target opacity | slider | 0–100 % | 70 | live | new |
| Size and stacking | Max distance (CVar) | slider | 20–60 yd | 41 | none | new |
| Size and stacking | Show enemy pets / totems / minions | toggle | per type | Off / On / Off | none | new |
| Health bar | Health texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has |
| Health bar | Health fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Health bar | Health smooth fill | toggle |  | On | live | new |
| Health bar | Health gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Health bar | Class colour enemy players | toggle |  | On | live | new |
| Health bar | Reaction colours (hostile / neutral / friendly / tapped) | colour | 4 colours | Blizzard | live | new |
| Health bar | Threat colours (tank / DPS: secure, losing, lost) | colour | 6 colours | green / orange / red | live | part |
| Health bar | Colour your target | toggle |  | On | live | has |
| Health bar | Colour your focus | toggle |  | On | live | has |
| Health bar | Quest mob colour | colour |  | #E6C84D | live | new |
| Health bar | Execute range colour + threshold | slider | 0–50 % | Off | live | new |
| Health bar | Health background | toggle |  | On | live | has |
| Health bar | Health background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Health bar | Health background colour | colour | colour + theme token | #0B0C0F | live | has |
| Health bar | Health background opacity | slider | 0–100 % | 70 | live | has |
| Health bar | Plate border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Health bar | Plate border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Health bar | Plate border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Health bar | Plate border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Health bar | Plate border shadow size | slider | 0–16 px | 4 | live | new |
| Health bar | Absorb on plates | dropdown | Off / Overlay / Striped | Striped | hover | new |
| Target, focus and hover | Target effect | dropdown | None / Border / Glow / Arrows / Underline | Border | hover | new |
| Target, focus and hover | Target effect colour | colour |  | accent | live | new |
| Target, focus and hover | Focus marker | dropdown | None / Letter F / Border / Texture | Border | hover | new |
| Target, focus and hover | Hover highlight | dropdown | None / Lighten / Border | Lighten | hover | new |
| Cast bar | Phoenix cast bar | toggle |  | On | live | has |
| Cast bar | Cast bar height | slider | 6–40 px | 10 | live | new |
| Cast bar | Cast texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has |
| Cast bar | Cast fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Cast bar | Cast smooth fill | toggle |  | On | live | new |
| Cast bar | Cast gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Cast bar | Interruptible / not / important colours | colour | 3 colours | gold / grey / red | live | part |
| Cast bar | Kick-ready hint (my interrupt off cooldown) | dropdown | Off / Tint / Tick | Tint | live | new |
| Cast bar | Spell icon | dropdown | Left / Right / Off | Left | live | new |
| Cast bar | Shield icon (not interruptible) | toggle |  | On | live | new |
| Cast bar | Spell name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Cast bar | Spell name size | slider | 6–40 | 10 | live | has |
| Cast bar | Spell name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Cast bar | Spell name shadow | toggle |  | Off | live | has |
| Cast bar | Spell name colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Cast bar | Spell target name | toggle |  | On | live | new |
| Cast bar | Cast timer | dropdown | Off / Remaining / Remaining/Total | Remaining | live | new |
| Text | Restyle names | toggle |  | On | live | has |
| Text | Name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Name size | slider | 6–40 | 11 | live | has |
| Text | Name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Name shadow | toggle |  | Off | live | has |
| Text | Name colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Name position | dropdown | Above / Inside / Below | Above | live | new |
| Text | Health percent | toggle |  | On | live | has |
| Text | Health text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Health text size | slider | 6–40 | 10 | live | has |
| Text | Health text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Health text shadow | toggle |  | Off | live | has |
| Text | Health text colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Health text anchor | dropdown | 9 points | Right | live | has |
| Text | Health text X offset | slider | -200–200 | 0 | live | has |
| Text | Health text Y offset | slider | -200–200 | 0 | live | has |
| Text | Level / classification badge | toggle |  | Off | live | new |
| Text | NPC title / guild on friendly | toggle |  | Off | live | new |
| Auras | Phoenix aura icons | toggle |  | On | live | has |
| Auras | Debuffs row: mine / important / all | dropdown | Blizzard filter | Mine | none | new |
| Auras | Enemy buffs (purgeable / important) | dropdown | Off / Purgeable / Blizzard | Purgeable | none | new |
| Auras | Icon size / spacing / max | slider | 12–40 / 0–8 / 1–10 | 22 / 2 / 5 | live | new |
| Auras | Icon zoom | slider | 0–20 % | 8 | live | has |
| Auras | Aura border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Auras | Aura border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Auras | Aura border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Auras | Aura stacks font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Auras | Aura stacks size | slider | 6–40 | 10 | live | has |
| Auras | Aura stacks outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Auras | Aura stacks shadow | toggle |  | Off | live | has |
| Auras | Aura stacks colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Auras | Aura timer font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Auras | Aura timer size | slider | 6–40 | 10 | live | has |
| Auras | Aura timer outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Auras | Aura timer shadow | toggle |  | Off | live | has |
| Auras | Aura timer colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Mythic+ and extras | Enemy forces % on plates | toggle |  | On | live | has |
| Mythic+ and extras | Enemy forces font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Mythic+ and extras | Enemy forces size | slider | 6–40 | 10 | live | has |
| Mythic+ and extras | Enemy forces outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Mythic+ and extras | Enemy forces shadow | toggle |  | Off | live | has |
| Mythic+ and extras | Enemy forces colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Mythic+ and extras | Class power on target plate | toggle |  | Off | live | new |
| Mythic+ and extras | Raid marker size / position | slider | 12–40 + anchor | 20, left | live | new |
| Mythic+ and extras | Quest objective icon | toggle |  | On | live | new |
| Mythic+ and extras | Hide enemy plates out of combat | toggle |  | Off | none | new |
| Mythic+ and extras | Preview eye toggles (marker, quest, target, absorb) | button |  |  | live | new |

## Cast Bars  (`CastBars`)

*Now 23 → target 55* · has 20 · part 4 · new 31

**How:** Own cast bars for player, target, focus, pet, boss (UnitCastingInfo is secret only where restricted; text through display sinks)

**References:** EUI ResourceBars CastBarPage 41 + UnitFrames cast section 32 + MythicTimer targeted spell bars 21

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Layout (per bar: player, target, focus, pet, boss) | Enable bar | toggle |  | On | world | part |
| Layout (per bar: player, target, focus, pet, boss) | Width | slider | 50–800 px | 260 | live | new |
| Layout (per bar: player, target, focus, pet, boss) | Height | slider | 6–60 px | 22 | live | new |
| Layout (per bar: player, target, focus, pet, boss) | Anchor | dropdown | 9 points + frame picker | per element | world | new |
| Layout (per bar: player, target, focus, pet, boss) | X offset | slider | -2000–2000 | per element | world | new |
| Layout (per bar: player, target, focus, pet, boss) | Y offset | slider | -1200–1200 | per element | world | new |
| Layout (per bar: player, target, focus, pet, boss) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | new |
| Layout (per bar: player, target, focus, pet, boss) | Scale | slider | 50–200 % | 100 | world | new |
| Layout (per bar: player, target, focus, pet, boss) | Attach to unit frame | toggle |  | On (target, focus) | world | new |
| Look | Cast texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has |
| Look | Cast fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Look | Cast smooth fill | toggle |  | On | live | new |
| Look | Cast gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Look | Class colour (player) | toggle |  | Off | live | has |
| Look | Colours: cast / channel / uninterruptible / interrupted / success | colour | 5 colours | theme | live | part |
| Look | Background | toggle |  | On | live | has |
| Look | Background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Look | Background colour | colour | colour + theme token | #0B0C0F | live | has |
| Look | Background opacity | slider | 0–100 % | 70 | live | has |
| Look | Border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Look | Border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Look | Border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Look | Border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Look | Border shadow size | slider | 0–16 px | 4 | live | new |
| Look | Spark | toggle |  | On | live | new |
| Look | Spell icon | dropdown | Left / Right / Off | Left | live | part |
| Look | Icon zoom | slider | 0–20 % | 8 | live | has |
| Look | Icon detached size | slider | 0–60 px | 0 (= height) | live | new |
| Text | Spell name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Spell name size | slider | 6–40 | 12 | live | has |
| Text | Spell name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Spell name shadow | toggle |  | Off | live | has |
| Text | Spell name colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Spell name anchor | dropdown | 9 points | Left | live | new |
| Text | Spell name X offset | slider | -200–200 | 0 | live | new |
| Text | Spell name Y offset | slider | -200–200 | 0 | live | new |
| Text | Cast time font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Cast time size | slider | 6–40 | 11 | live | has |
| Text | Cast time outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Cast time shadow | toggle |  | Off | live | has |
| Text | Cast time colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Time format | dropdown | Remaining / Remaining/Total / Elapsed | Remaining | live | part |
| Text | Decimals | slider | 0–2 | 1 | live | new |
| Text | Spell target name | toggle |  | On (target, focus) | live | new |
| Player extras | Latency overlay | toggle |  | On | live | has |
| Player extras | Latency colour | colour |  | #FF4040 60% | live | new |
| Player extras | Channel ticks | toggle |  | On | live | new |
| Player extras | Empowered stages coloured | toggle |  | On | live | new |
| Player extras | GCD bar | toggle |  | Off | world | new |
| Player extras | Swing timer (Forever: C_SwingTimer) | toggle |  | Off | world | new |
| Player extras | Hide Blizzard player cast bar | toggle |  | On | none | new |
| Interrupt helpers | Kick-ready tick (my interrupt off cooldown) | toggle |  | On | live | new |
| Interrupt helpers | Interrupted flash | toggle |  | On | live | new |
| Interrupt helpers | Targeted spell bars (casts on me) | toggle |  | Off | world | new |
| Interrupt helpers | Test casts | button |  |  | world | new |

## Buffs & Debuffs  (`Auras`)

*Now 15 → target 41* · has 15 · part 0 · new 26

**How:** Restyles Blizzard's player buff and debuff frames (BuffFrame/DebuffFrame); own aura bars optional

**References:** EUI PlayerAuraBars 43 + BlizzardSkin aura bits · ElvUI-style aura headers

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Layout (buffs / debuffs separately) | Icon size | slider | 16–64 px | 32 | live | new |
| Layout (buffs / debuffs separately) | Icons per row | slider | 1–20 | 12 | live | new |
| Layout (buffs / debuffs separately) | Max rows | slider | 1–10 | 3 | live | new |
| Layout (buffs / debuffs separately) | Horizontal / vertical spacing | slider | -5–20 px | 4 / 12 | live | new |
| Layout (buffs / debuffs separately) | Growth | dropdown | Left-Down / Right-Down / Left-Up / Right-Up | Left-Down | live | new |
| Layout (buffs / debuffs separately) | Sort | dropdown | Time left / Name / Cast order | Time left | live | new |
| Layout (buffs / debuffs separately) | Sort direction | dropdown | Ascending / Descending | Ascending | live | new |
| Layout (buffs / debuffs separately) | Separate my own buffs | toggle |  | Off | live | new |
| Look | Phoenix style | toggle |  | On | live | has |
| Look | Icon shape | dropdown | Square / Rounded | Square | hover | new |
| Look | Icon zoom | slider | 0–20 % | 8 | live | has |
| Look | Border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Look | Border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Look | Border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Look | Border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Look | Border shadow size | slider | 0–16 px | 4 | live | new |
| Look | Debuff type border colours | toggle |  | On | live | new |
| Look | Duration swipe | toggle |  | Off | live | new |
| Look | Reverse swipe | toggle |  | Off | live | new |
| Text | Duration font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Duration size | slider | 6–40 | 11 | live | has |
| Text | Duration outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Duration shadow | toggle |  | Off | live | has |
| Text | Duration colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Duration anchor | dropdown | 9 points | Bottom | live | new |
| Text | Duration X offset | slider | -200–200 | 0 | live | new |
| Text | Duration Y offset | slider | -200–200 | 0 | live | new |
| Text | Duration format | dropdown | Blizzard / 1m / 1:05 / seconds below N | 1m | live | new |
| Text | Precise below (minutes) | slider | 0–60 | 1 | live | new |
| Text | Colour by time left | toggle |  | On | live | new |
| Text | Stacks font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Stacks size | slider | 6–40 | 12 | live | has |
| Text | Stacks outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Stacks shadow | toggle |  | Off | live | has |
| Text | Stacks colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Stacks anchor | dropdown | 9 points | Bottom right | live | new |
| Text | Stacks X offset | slider | -200–200 | 0 | live | new |
| Text | Stacks Y offset | slider | -200–200 | 0 | live | new |
| Behaviour | Right-click to cancel (out of combat) | toggle |  | On | none | new |
| Behaviour | Hide weapon enchants / consolidated | toggle |  | Off | live | new |
| Behaviour | Private auras anchor size | slider | 16–64 px | 32 | world | new |

## Combat Text  (`CombatText`)

*Now 16 → target 26* · has 16 · part 0 · new 10

**How:** Configures Blizzard floating combat text (CVars) + optional Phoenix scrolling areas

**References:** Blizzard FCT CVars · MSBT-like

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Blizzard combat text | Damage | toggle |  | Blizzard | none | has |
| Blizzard combat text | Periodic damage | toggle |  | Blizzard | none | has |
| Blizzard combat text | Pet damage | toggle |  | Blizzard | none | has |
| Blizzard combat text | Healing | toggle |  | Blizzard | none | has |
| Blizzard combat text | Self combat text | toggle |  | Blizzard | none | has |
| Blizzard combat text | Dodge, parry, miss | toggle |  | Blizzard | none | has |
| Blizzard combat text | Resistances | toggle |  | Blizzard | none | has |
| Blizzard combat text | Combat state | toggle |  | Blizzard | none | has |
| Blizzard combat text | Reactive abilities | toggle |  | Blizzard | none | has |
| Blizzard combat text | Low health / mana | toggle |  | Blizzard | none | has |
| Blizzard combat text | Auras | toggle |  | Blizzard | none | has |
| Blizzard combat text | Resource gains | toggle |  | Blizzard | none | has |
| Blizzard combat text | Honor | toggle |  | Blizzard | none | has |
| Blizzard combat text | Reputation | toggle |  | Blizzard | none | has |
| Blizzard combat text | Text scale | slider | 50–200 % | 100 | none | has |
| Blizzard combat text | Motion | dropdown | Up / Arc / Fountain | Up | none | has |
| Blizzard combat text | Damage font (needs relog) | dropdown | fonts | Blizzard | hover | new |
| Phoenix scroll areas (own events only, secret-safe) | Incoming / outgoing / notification areas | toggle | 3 toggles | Off | world | new |
| Phoenix scroll areas (own events only, secret-safe) | Area position / size / direction | slider | + Up/Down/Arc | per area | world | new |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text size | slider | 6–40 | 18 | live | new |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text shadow | toggle |  | Off | live | new |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Phoenix scroll areas (own events only, secret-safe) | Merge rapid hits | toggle |  | On | none | new |
| Phoenix scroll areas (own events only, secret-safe) | Crit style | dropdown | Bigger / Shake / Colour | Bigger | hover | new |

## Damage Meter  (`DamageMeter`)

*Now 2 → target 31* · has 2 · part 0 · new 29

**How:** Restyles Blizzard's built-in damage meter (C_DamageMeter, 12.0)

**References:** EUI DamageMeters 82

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Window | Restyle damage meter | toggle |  | On | live | has |
| Window | Phoenix style | toggle |  | On | live | has |
| Window | Bar height / spacing | slider | 10–40 / 0–6 px | 18 / 1 | live | new |
| Window | Meter bar texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | new |
| Window | Meter bar fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Window | Meter bar smooth fill | toggle |  | On | live | new |
| Window | Meter bar gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Window | Class colours | toggle |  | On | live | new |
| Window | Window background | toggle |  | On | live | new |
| Window | Window background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Window | Window background colour | colour | colour + theme token | #0B0C0F | live | new |
| Window | Window background opacity | slider | 0–100 % | 70 | live | new |
| Window | Window border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | new |
| Window | Window border size | slider | 0–4 px (pixel-perfect) | 1 | live | new |
| Window | Window border colour | colour | colour + class colour + quality + theme token | #000000 | live | new |
| Window | Window border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Window | Window border shadow size | slider | 0–16 px | 4 | live | new |
| Window | Name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Window | Name size | slider | 6–40 | 12 | live | new |
| Window | Name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Window | Name shadow | toggle |  | Off | live | new |
| Window | Name colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Window | Value font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Window | Value size | slider | 6–40 | 12 | live | new |
| Window | Value outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Window | Value shadow | toggle |  | Off | live | new |
| Window | Value colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Window | Value format | dropdown | Total (DPS) / DPS / Total / Percent | Total (DPS) | live | new |
| Window | Show rank numbers / spec icons | toggle | 2 toggles | On | live | new |
| Window | Auto-show in combat, hide after | slider | 0–60 s | Off | world | new |
| Window | Second window | toggle |  | Off | world | new |

## Spell History  (`SpellHistory`)

*Now 6 → target 12* · has 6 · part 0 · new 6

**How:** Row of recently cast spells

**References:** —

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Spell history | Icons | slider | 1–12 | 6 | live | has |
| Spell history | Icon size | slider | 16–64 | 32 | live | has |
| Spell history | Spacing | slider | 0–12 | 4 | live | has |
| Spell history | Direction | dropdown | Left / Right / Up / Down | Left | live | has |
| Spell history | Fade after (s) | slider | 1–30 | 8 | live | has |
| Spell history | Only in combat | toggle |  | On | world | has |
| Spell history | Icon border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | new |
| Spell history | Icon border size | slider | 0–4 px (pixel-perfect) | 1 | live | new |
| Spell history | Icon border colour | colour | colour + class colour + quality + theme token | #000000 | live | new |
| Spell history | Icon border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Spell history | Icon border shadow size | slider | 0–16 px | 4 | live | new |
| Spell history | Mark interrupted / failed | toggle |  | On | live | new |

## Chat  (`Chat`)

*Now 17 → target 51* · has 12 · part 8 · new 31

**How:** Restyles Blizzard chat frames and adds tools; no chat replacement

**References:** EUI Chat 57 · WindTools Social (chat bar, emotes, links) 16 · Prat-like features

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Window | Chat background | toggle |  | On | live | new |
| Window | Chat background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Window | Chat background colour | colour | colour + theme token | #0B0C0F | live | new |
| Window | Chat background opacity | slider | 0–100 % | 45 | live | new |
| Window | Chat border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | part |
| Window | Chat border size | slider | 0–4 px (pixel-perfect) | 1 | live | part |
| Window | Chat border colour | colour | colour + class colour + quality + theme token | #000000 | live | part |
| Window | Chat border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Window | Chat border shadow size | slider | 0–16 px | 4 | live | new |
| Window | Width / height (main) | slider | 200–900 / 80–600 px | 440 / 180 | world | new |
| Window | Fade lines after | slider | 0–600 s (0 = never) | 120 | none | new |
| Window | Max lines kept | slider | 128–4096 | 1024 | none | new |
| Window | Hide in combat | toggle |  | Off | world | new |
| Window | Hide side buttons | toggle |  | On | live | new |
| Window | Scroll to bottom button | toggle |  | On | live | new |
| Tabs | Tab font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Tabs | Tab size | slider | 6–40 | 12 | live | has |
| Tabs | Tab outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Tabs | Tab shadow | toggle |  | Off | live | has |
| Tabs | Tab colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Tabs | Tab style | dropdown | Phoenix underline / Pill / Blizzard | Phoenix underline | hover | part |
| Tabs | Selected tab colour | colour |  | accent | live | new |
| Tabs | Flash new messages | toggle |  | On | live | has |
| Tabs | Fade tabs when idle | toggle |  | On | live | new |
| Messages | Chat font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | part |
| Messages | Chat size | slider | 6–40 | 13 | live | part |
| Messages | Chat outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Messages | Chat shadow | toggle |  | Off | live | has |
| Messages | Chat colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Messages | Timestamps | dropdown | Off / HH:MM / HH:MM:SS / 12h | HH:MM | live | new |
| Messages | Timestamp colour | colour |  | #808080 | live | new |
| Messages | Short channel names ([G], [P], [1]) | toggle |  | On | live | new |
| Messages | Class-coloured names | toggle |  | On | live | new |
| Messages | Clickable URLs | toggle |  | On | live | has |
| Messages | Copy chat (per-line and window) | toggle |  | On | none | has |
| Messages | Item level in item links | toggle |  | On | live | new |
| Messages | Icons in links (item, spell, achievement) | toggle |  | On | live | new |
| Messages | Role icons before names | toggle |  | On | live | new |
| Messages | Keyword highlight list | list | words | your name | live | new |
| Messages | Keyword sound | dropdown | sound list | None | hover | new |
| Messages | Spam throttle (repeat lines) | slider | 0–120 s | 0 | none | new |
| Edit box | Edit box position | dropdown | Below / Above / Top of window | Below | live | new |
| Edit box | Edit box style | dropdown | Phoenix / Blizzard | Phoenix | hover | part |
| Edit box | Arrow keys without Alt | toggle |  | On | none | has |
| Edit box | Remember last channel | toggle |  | On | none | new |
| Edit box | History lines | slider | 10–200 | 50 | none | part |
| Tools | Chat bar (channel buttons, roll, ready check) | toggle |  | Off | world | new |
| Tools | Emote picker | toggle |  | Off | world | new |
| Tools | Whisper sound | dropdown | sound list | Phoenix chime | hover | new |
| Tools | Whisper tab per person | toggle |  | Off | none | new |
| Tools | Combat log tab hidden | toggle |  | Off | none | new |

## Minimap  (`Minimap`)

*Now 5 → target 41* · has 2 · part 3 · new 36

**How:** Restyles Blizzard's minimap cluster

**References:** EUI Minimap 62 · WindTools Maps 29 (rectangle minimap, buttons bar, instance difficulty, world map reveal)

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Shape and size | Shape | dropdown | Round / Square / Rectangle | Square | hover | part |
| Shape and size | Size | slider | 120–400 px | 200 | live | new |
| Shape and size | Rectangle height (shape = rectangle) | slider | 50–100 % | 70 | live | new |
| Shape and size | Scale | slider | 50–200 % | 100 | world | new |
| Shape and size | Border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | new |
| Shape and size | Border size | slider | 0–4 px (pixel-perfect) | 1 | live | new |
| Shape and size | Border colour | colour | colour + class colour + quality + theme token | #000000 | live | new |
| Shape and size | Border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Shape and size | Border shadow size | slider | 0–16 px | 4 | live | new |
| Shape and size | Mouse wheel zoom | toggle |  | On | none | new |
| Shape and size | Auto zoom out after | slider | 0–30 s | 5 | none | new |
| Elements (each: show, position, size) | Zone text | dropdown | Always / Mouseover / Hidden | Always | live | part |
| Elements (each: show, position, size) | Zone text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Elements (each: show, position, size) | Zone text size | slider | 6–40 | 12 | live | new |
| Elements (each: show, position, size) | Zone text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Elements (each: show, position, size) | Zone text shadow | toggle |  | Off | live | new |
| Elements (each: show, position, size) | Zone text colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Elements (each: show, position, size) | Zone text colour by PvP status | toggle |  | On | live | new |
| Elements (each: show, position, size) | Clock | dropdown | Always / Mouseover / Hidden | Always | live | new |
| Elements (each: show, position, size) | Clock font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Elements (each: show, position, size) | Clock size | slider | 6–40 | 11 | live | new |
| Elements (each: show, position, size) | Clock outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Elements (each: show, position, size) | Clock shadow | toggle |  | Off | live | new |
| Elements (each: show, position, size) | Clock colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Elements (each: show, position, size) | Coordinates | dropdown | Always / Mouseover / Hidden | Mouseover | live | part |
| Elements (each: show, position, size) | Coordinate decimals | slider | 0–2 | 1 | live | new |
| Elements (each: show, position, size) | Calendar / invites | dropdown | Icon / Hidden | Icon | live | new |
| Elements (each: show, position, size) | Tracking button | dropdown | Icon / Right-click menu | Right-click menu | live | new |
| Elements (each: show, position, size) | Mail icon | toggle |  | On | live | new |
| Elements (each: show, position, size) | Crafting order icon | toggle |  | On | live | new |
| Elements (each: show, position, size) | Instance difficulty badge | dropdown | Phoenix text / Blizzard / Hidden | Phoenix text | hover | new |
| Elements (each: show, position, size) | Expansion / housing button | dropdown | Icon / Hidden | Icon | live | new |
| Elements (each: show, position, size) | Group finder eye | toggle |  | On | live | new |
| Addon buttons | Collect addon buttons | dropdown | Off / Bar / Drawer / Mouseover ring | Drawer | hover | has |
| Addon buttons | Buttons per row | slider | 1–12 | 6 | live | has |
| Addon buttons | Button size | slider | 16–40 px | 24 | live | new |
| Addon buttons | Ignore list | list | button names |  | none | new |
| Map extras | Ping name display | toggle |  | On | none | new |
| Map extras | World map: reveal unexplored | toggle |  | Off | none | new |
| Map extras | World map: player / cursor coords | toggle |  | On | live | new |
| Map extras | World map scale | slider | 50–150 % | 100 | none | new |

## Tooltips  (`Tooltip`)

*Now 29 → target 45* · has 25 · part 1 · new 19

**How:** Restyles GameTooltip and adds lines; IDs where idTip-style (BSD-2)

**References:** EUI BlizzardSkin tooltip 23 · WindTools Tooltips 27 · idTip 27 ID kinds

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Look | Background | toggle |  | On | live | has |
| Look | Background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Look | Background colour | colour | colour + theme token | #0B0C0F | live | has |
| Look | Background opacity | slider | 0–100 % | 92 | live | has |
| Look | Border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Look | Border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Look | Border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Look | Border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Look | Border shadow size | slider | 0–16 px | 4 | live | new |
| Look | Border by item quality | toggle |  | On | live | has |
| Look | Border by class (players) | toggle |  | On | live | has |
| Look | Header font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Look | Header size | slider | 6–40 | 14 | live | has |
| Look | Header outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Look | Header shadow | toggle |  | Off | live | has |
| Look | Header colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Look | Body font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Look | Body size | slider | 6–40 | 12 | live | has |
| Look | Body outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Look | Body shadow | toggle |  | Off | live | has |
| Look | Body colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Look | Health bar | dropdown | Off / Below / Above | Below | live | has |
| Look | Health bar height | slider | 2–12 px | 4 | live | has |
| Position | Anchor | dropdown | Default / Cursor / Cursor left / Cursor right / Fixed | Default | world | has |
| Position | Cursor offset X / Y | slider | -100–100 | 0 / 16 | world | new |
| Position | Scale | slider | 50–150 % | 100 | world | new |
| Position | Hide in combat | dropdown | Never / Units / All / Unless modifier held | Never | none | has |
| Unit info | Class-coloured names | toggle |  | On | live | new |
| Unit info | Guild rank | toggle |  | On | live | new |
| Unit info | Realm | dropdown | Full / Asterisk / Hidden | Asterisk | live | new |
| Unit info | Target of unit | toggle |  | On | live | has |
| Unit info | Targeted by (group) | toggle |  | On | live | new |
| Unit info | Item level and spec (inspect) | toggle |  | On | live | new |
| Unit info | Mythic+ score and best run | toggle |  | On | live | has |
| Unit info | Raid progression line | toggle |  | Off | live | new |
| Unit info | Role icon | toggle |  | On | live | has |
| Unit info | Mount the player is on | toggle |  | Off | live | new |
| Unit info | NPC: reaction-coloured, hide 'PvP' line | toggle |  | On | live | new |
| IDs and extras | Show IDs | dropdown | Off / With modifier / Always | With modifier | none | part |
| IDs and extras | ID kinds | list | Spell, Item, NPC, Quest, Achievement, Currency, Mount, Talent, Icon, Vignette, AreaPOI… | Spell, Item, NPC, Quest | none | new |
| IDs and extras | Item: count in bags / bank / warband | toggle |  | On | live | new |
| IDs and extras | Item: vendor price | toggle |  | On | live | new |
| IDs and extras | Item: already known / collected | toggle |  | On | live | new |
| IDs and extras | Keystone tooltip (affixes, depleted) | toggle |  | On | live | new |
| IDs and extras | Group finder entry tooltip details | toggle |  | On | live | new |

## Bags  (`Bags`)

*Now 6 → target 47* · has 5 · part 0 · new 42

**How:** Restyles Blizzard's combined bag + bank; own sorting via C_Container

**References:** EUI Bags 45 · Baganator-style features

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Layout | Combined bags | toggle |  | On | live | has |
| Layout | Columns | slider | 6–24 | 12 | live | new |
| Layout | Slot size | slider | 24–56 px | 36 | live | new |
| Layout | Slot spacing | slider | 0–8 px | 3 | live | new |
| Layout | Category sections | dropdown | Off / Blizzard filters / Phoenix categories | Off | hover | new |
| Layout | Category list (reorder / hide) | reorder | Equipment, Consumables, Reagents, Junk, New… | default order | live | new |
| Layout | Bank / Warband bank same layout | toggle |  | On | live | new |
| Layout | Scale | slider | 50–150 % | 100 | world | new |
| Slots | Item level on gear | toggle |  | On | live | has |
| Slots | Item level font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Slots | Item level size | slider | 6–40 | 11 | live | new |
| Slots | Item level outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Slots | Item level shadow | toggle |  | Off | live | new |
| Slots | Item level colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Slots | Quality border | toggle |  | On | live | has |
| Slots | Slot border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | new |
| Slots | Slot border size | slider | 0–4 px (pixel-perfect) | 1 | live | new |
| Slots | Slot border colour | colour | colour + class colour + quality + theme token | #000000 | live | new |
| Slots | Slot border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Slots | Slot border shadow size | slider | 0–16 px | 4 | live | new |
| Slots | Junk coin icon | toggle |  | On | live | new |
| Slots | New item glow | dropdown | Blizzard / Phoenix / Off | Phoenix | hover | new |
| Slots | Upgrade arrow (better ilvl) | toggle |  | On | live | has |
| Slots | Bind-on-equip / warbound label | toggle |  | On | live | new |
| Slots | Cooldown on usable items | toggle |  | On | live | new |
| Slots | Count font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Slots | Count size | slider | 6–40 | 12 | live | has |
| Slots | Count outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Slots | Count shadow | toggle |  | Off | live | new |
| Slots | Count colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Window | Window background | toggle |  | On | live | new |
| Window | Window background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Window | Window background colour | colour | colour + theme token | #0B0C0F | live | new |
| Window | Window background opacity | slider | 0–100 % | 92 | live | new |
| Window | Window border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | new |
| Window | Window border size | slider | 0–4 px (pixel-perfect) | 1 | live | new |
| Window | Window border colour | colour | colour + class colour + quality + theme token | #000000 | live | new |
| Window | Window border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Window | Window border shadow size | slider | 0–16 px | 4 | live | new |
| Window | Search box | toggle |  | On | live | new |
| Window | Gold, currencies footer | toggle |  | On | live | new |
| Window | Bag bar inside window | toggle |  | On | live | new |
| Behaviour | Sort button | toggle |  | On | none | new |
| Behaviour | Sort direction / reverse | dropdown | Blizzard / Reverse | Blizzard | none | new |
| Behaviour | Auto sell junk (in Automation) | toggle | see Automation |  | none | new |
| Behaviour | Open with vendor / bank / mail / AH | toggle | 4 toggles | On | none | new |
| Behaviour | Close with vendor | toggle |  | On | none | new |

## Item Level  (`ItemLevel`)

*Now 4 → target 19* · has 4 · part 0 · new 15

**How:** Item level on character, inspect, bags, loot frames

**References:** EUI BlizzardSkin character sheet 30 · WindTools Item 27 (inspect, already known)

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Where | Character sheet slots | toggle |  | On | live | has |
| Where | Inspect frame slots | toggle |  | On | live | new |
| Where | Bags / bank (in Bags) | toggle | see Bags |  | live | has |
| Where | Loot / roll / great vault / merchant | toggle | 4 toggles | On | live | new |
| Where | Equipment flyout | toggle |  | On | live | new |
| Look | Item level font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Look | Item level size | slider | 6–40 | 12 | live | has |
| Look | Item level outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Look | Item level shadow | toggle |  | Off | live | new |
| Look | Item level colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Look | Colour by quality | toggle |  | On | live | has |
| Look | Item level anchor | dropdown | 9 points | Bottom | live | new |
| Look | Item level X offset | slider | -200–200 | 0 | live | new |
| Look | Item level Y offset | slider | -200–200 | 0 | live | new |
| Look | Missing enchant / gem warning | toggle |  | On | live | new |
| Look | Enchant text on slot | toggle |  | Off | live | new |
| Look | Upgrade track (e.g. Hero 4/6) | toggle |  | On | live | new |
| Look | Character sheet: average ilvl decimals | slider | 0–2 | 1 | live | new |
| Look | Character sheet: stats panel restyle | toggle |  | On | live | new |

## Data Texts  (`DataTexts`)

*Now 35 → target 47* · has 14 · part 7 · new 26

**How:** Own data panels + broker (LDB) feeds

**References:** EUI DataBars 55 (XP/rep/honor bars) + MinimapDataText · ElvUI datatexts

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Panels (each panel) | Enable panel | toggle |  | On | world | has |
| Panels (each panel) | Slots | slider | 1–6 | 3 | live | new |
| Panels (each panel) | Width / height | slider | 60–1200 / 14–40 px | 420 / 22 | live | part |
| Panels (each panel) | Panel background | toggle |  | On | live | has |
| Panels (each panel) | Panel background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Panels (each panel) | Panel background colour | colour | colour + theme token | #0B0C0F | live | has |
| Panels (each panel) | Panel background opacity | slider | 0–100 % | 70 | live | has |
| Panels (each panel) | Panel border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has |
| Panels (each panel) | Panel border size | slider | 0–4 px (pixel-perfect) | 1 | live | has |
| Panels (each panel) | Panel border colour | colour | colour + class colour + quality + theme token | #000000 | live | has |
| Panels (each panel) | Panel border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Panels (each panel) | Panel border shadow size | slider | 0–16 px | 4 | live | new |
| Panels (each panel) | Mouseover only | toggle |  | Off | world | new |
| Panels (each panel) | Anchor | dropdown | 9 points + frame picker | per element | world | part |
| Panels (each panel) | X offset | slider | -2000–2000 | per element | world | part |
| Panels (each panel) | Y offset | slider | -1200–1200 | per element | world | part |
| Panels (each panel) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | part |
| Panels (each panel) | Scale | slider | 50–200 % | 100 | world | part |
| Text | Data text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has |
| Text | Data text size | slider | 6–40 | 12 | live | has |
| Text | Data text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has |
| Text | Data text shadow | toggle |  | Off | live | has |
| Text | Data text colour | colour | colour + class colour + theme token | #FFFFFF | live | has |
| Text | Label colour / value colour | colour | 2 colours | grey / class | live | part |
| Text | Hide labels | toggle |  | Off | live | has |
| Text | Combat: hide tooltips | toggle |  | On | none | new |
| Data sources (each slot) | Slot source | dropdown | Gold, Durability, Bags, Friends, Guild, FPS/MS, Time, Spec/Loot spec, Item level, Coords, Mythic+ score, Great Vault, Currencies, Mail, Talents loadout, Volume, LDB feeds | per slot | hover | has |
| Data sources (each slot) | Gold: show silver/copper | toggle |  | Off | live | new |
| Data sources (each slot) | Gold: account-wide totals | toggle |  | On | none | new |
| Data sources (each slot) | Time: 24h / local vs realm | dropdown | Local / Realm · 12h / 24h | Local 24h | live | new |
| Data sources (each slot) | Durability: warn below | slider | 0–100 % | 25 | live | new |
| Data sources (each slot) | Currency picker | list | currency IDs | Valorstones, crests | none | new |
| Experience / reputation / honor bars | Experience bar | toggle |  | On below max level | world | new |
| Experience / reputation / honor bars | Reputation bar (watched) | toggle |  | On | world | new |
| Experience / reputation / honor bars | Honor bar | toggle |  | Off | world | new |
| Experience / reputation / honor bars | Bar width / height | slider | 100–1200 / 4–30 px | 520 / 10 | live | new |
| Experience / reputation / honor bars | Data bar texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | new |
| Experience / reputation / honor bars | Data bar fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Experience / reputation / honor bars | Data bar smooth fill | toggle |  | On | live | new |
| Experience / reputation / honor bars | Data bar gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Experience / reputation / honor bars | Rested / quest XP overlay | toggle |  | On | live | new |
| Experience / reputation / honor bars | Bar text | dropdown | Off / Percent / Current / Remaining / Mouseover | Mouseover | live | new |
| Experience / reputation / honor bars | Bar text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Experience / reputation / honor bars | Bar text size | slider | 6–40 | 10 | live | new |
| Experience / reputation / honor bars | Bar text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Experience / reputation / honor bars | Bar text shadow | toggle |  | Off | live | new |
| Experience / reputation / honor bars | Bar text colour | colour | colour + class colour + theme token | #FFFFFF | live | new |

## Skins  (`Skins`)

*Now 3 → target 28* · has 3 · part 0 · new 25

**How:** Phoenix look for Blizzard windows

**References:** EUI BlizzardSkin 123 (character, popups, tooltips, skyriding, CDM, objective tracker)

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Windows (each toggle) | Game menu | toggle |  | On | live | has |
| Windows (each toggle) | Popups (StaticPopup) | toggle |  | On | live | has |
| Windows (each toggle) | Ready check | toggle |  | On | live | has |
| Windows (each toggle) | Character / inspect | toggle |  | On | live | new |
| Windows (each toggle) | Spellbook / talents | toggle |  | On | live | new |
| Windows (each toggle) | Group finder | toggle |  | On | live | new |
| Windows (each toggle) | Collections | toggle |  | On | live | new |
| Windows (each toggle) | Professions | toggle |  | On | live | new |
| Windows (each toggle) | Auction house | toggle |  | On | live | new |
| Windows (each toggle) | Mail / merchant / gossip / quest | toggle |  | On | live | new |
| Windows (each toggle) | Loot / rolls | toggle |  | On | live | new |
| Windows (each toggle) | Achievement / encounter journal | toggle |  | On | live | new |
| Windows (each toggle) | Calendar / guild / communities | toggle |  | On | live | new |
| Windows (each toggle) | Settings / addon list | toggle |  | On | live | new |
| Windows (each toggle) | Great vault / keystone | toggle |  | On | live | new |
| Windows (each toggle) | Alerts / toasts | toggle |  | On | live | new |
| Windows (each toggle) | Skyriding vigor bar | toggle |  | On | live | new |
| Skin options | Window background | toggle |  | On | live | new |
| Skin options | Window background texture | texture | Phoenix surfaces + LSM | Solid | hover | new |
| Skin options | Window background colour | colour | colour + theme token | #0B0C0F | live | new |
| Skin options | Window background opacity | slider | 0–100 % | 94 | live | new |
| Skin options | Window border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | new |
| Skin options | Window border size | slider | 0–4 px (pixel-perfect) | 1 | live | new |
| Skin options | Window border colour | colour | colour + class colour + quality + theme token | #000000 | live | new |
| Skin options | Window border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | new |
| Skin options | Window border shadow size | slider | 0–16 px | 4 | live | new |
| Skin options | Title bar style | dropdown | Phoenix / Minimal / Blizzard | Phoenix | hover | new |
| Skin options | Close button style | dropdown | Phoenix / Blizzard | Phoenix | hover | new |

## Appearance & General  (`General`)

*Now 7 → target 23* · has 7 · part 0 · new 16

**How:** Theme, global fonts/textures/colours, scale, sounds; every module's 'Theme default' points here

**References:** EUI Fonts 37 + Textures + Colors + Glow + General ~90

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Theme | Theme | dropdown | Ember / Dawn / Midnight / Classic / Custom | Ember | hover | has |
| Theme | Accent colour | colour |  | theme | live | has |
| Theme | Accent from class colour | toggle |  | Off | live | new |
| Theme | Window surface opacity | slider | 60–100 % | 96 | live | new |
| Theme | Reduce motion | toggle |  | Off | live | has |
| Theme | UI scale (pixel perfect) | slider | auto / 0.53–1.0 | auto | live | new |
| Fonts | Interface font | dropdown | Phoenix fonts + LSM | Phoenix Sans | hover | has |
| Fonts | Unit / number font | dropdown | Phoenix fonts + LSM | Phoenix Numbers | hover | has |
| Fonts | Font scale | slider | 80–130 % | 100 | live | has |
| Fonts | Global outline | dropdown | None / Outline / Thick | Outline | live | new |
| Fonts | Replace Blizzard fonts (damage, names, chat) | toggle | 4 toggles | Off | none | new |
| Textures and borders | Default bar texture | texture |  | Phoenix Satin | hover | has |
| Textures and borders | Default border style | dropdown | border styles | Pixel | hover | new |
| Textures and borders | Default border colour | colour |  | #000000 | live | new |
| Textures and borders | Default shadow | dropdown | None / Soft / Hard | Soft | hover | new |
| Colours | Class colours override | colour | 13 classes | Blizzard | live | new |
| Colours | Power colours override | colour | per type | Blizzard | live | new |
| Colours | Reaction colours | colour | 4 | Blizzard | live | new |
| Colours | Dispel colours | colour | 5 | Blizzard | live | new |
| Glow | Default glow style | dropdown | Pixel / Autocast / Button / Proc | Pixel | hover | new |
| Glow | Glow colour / lines / speed / thickness | colour | colour + 3 sliders | accent / 8 / 4 / 2 | live | new |
| Sounds | Sound channel | dropdown | Master / SFX / Dialog | Master | none | new |
| Sounds | Mute list (sound file IDs) | list | IDs |  | none | new |

## Profiles  (`Profiles`)

*Now 0 → target 8* · has 0 · part 1 · new 7

**How:** Profiles, per-spec switching, import/export strings, presets

**References:** EUI Profiles 4 pages (Profiles, Presets, Overrides, FullExport)

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Profiles | Active profile | dropdown | profiles | Default | none | part |
| Profiles | New / copy / rename / delete | button |  |  | none | new |
| Profiles | Per-spec profile | toggle | + profile per spec | Off | none | new |
| Profiles | Per-character overrides | toggle |  | Off | none | new |
| Profiles | Export (all / selected modules) | button | string + module picker |  | none | new |
| Profiles | Import with preview of changes | button |  |  | live | new |
| Profiles | Presets (Phoenix Healer / DPS / Tank / Minimal) | button |  |  | hover | new |
| Profiles | Reset module | button | per module |  | none | new |

## Layout (Movers)  (`Movers`)

*Now 3 → target 11* · has 3 · part 0 · new 8

**How:** Unlock mode for every Phoenix-owned frame + selected Blizzard frames (no Edit Mode conflicts)

**References:** MoveAny 150 frame toggles · EUI unlock mode (snap, grid, nudge, per-element)

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Unlock mode | Grid | toggle |  | On | world | has |
| Unlock mode | Grid size | slider | 8–128 px | 32 | world | has |
| Unlock mode | Snap to grid | toggle |  | On | world | has |
| Unlock mode | Snap to other frames | toggle |  | On | world | new |
| Unlock mode | Nudge with arrow keys (shift = 10 px) | toggle |  | On | world | new |
| Unlock mode | Show coordinates while dragging | toggle |  | On | world | new |
| Unlock mode | Per-element popup (X, Y, anchor, scale, reset) | button |  |  | world | new |
| Unlock mode | Frame list (search, show/hide, reset) | list | all movable frames |  | world | new |
| Unlock mode | Move Blizzard frames (talking head, loot, alerts, vehicle seat, durability, widgets…) | toggle | per frame | Off | world | new |
| Unlock mode | Scale Blizzard windows | slider | 50–150 % | 100 | world | new |
| Unlock mode | Unlock keybind | keybind |  | None | none | new |

## Quality of life  (`Quality`)

*Now 4 → target 11* · has 4 · part 0 · new 7

**How:** Small UI tweaks

**References:** EUI QoL 75 · WindTools Misc 112

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Quality of life | Hide talking heads | toggle |  | On | none | has |
| Quality of life | Quiet errors in combat | toggle |  | On | none | has |
| Quality of life | Achievement screenshots | toggle |  | On | none | has |
| Quality of life | Cooldown Manager | toggle |  | On | none | has |
| Quality of life | Hide boss banner / zone text / level-up | toggle | 3 toggles | Off | none | new |
| Quality of life | Camera max distance | slider | 15–39 yd | 39 | none | new |
| Quality of life | Raid markers bar | toggle |  | Off | world | new |
| Quality of life | Mouse cursor ring / trail | toggle |  | Off | world | new |
| Quality of life | Combat enter/leave alert | toggle |  | Off | world | new |
| Quality of life | Already known recipe tint | toggle |  | On | live | new |
| Quality of life | CVar browser (common safe CVars) | list |  |  | none | new |

## Automation  (`Automation`)

*Now 8 → target 14* · has 7 · part 0 · new 7

**How:** Small automations

**References:** EUI QoL 75 · WindTools Misc 112

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Automation | Auto repair | dropdown | Off / Personal / Guild first | On | none | has |
| Automation | Sell junk | toggle |  | On | none | has |
| Automation | Accept invites from friends | toggle |  | On | none | has |
| Automation | Decline duels | toggle |  | On | none | has |
| Automation | Accept resurrections | toggle |  | On | none | has |
| Automation | Fill "DELETE" | toggle |  | On | none | has |
| Automation | Skip cinematics | toggle |  | On | none | has |
| Automation | Auto loot faster | toggle |  | On | none | new |
| Automation | Auto accept / turn in quests (in Quests) | toggle | see Quests |  | none | new |
| Automation | Auto gossip single option | toggle |  | Off | none | new |
| Automation | Auto role check accept | toggle |  | On | none | new |
| Automation | Auto confirm BoP loot solo | toggle |  | Off | none | new |
| Automation | Decline pet-battle duels / guild invites | toggle | 2 | Off | none | new |
| Automation | Combat warning sounds (low health) | toggle |  | Off | none | new |

## AFK screen  (`AFK`)

*Now 1 → target 4* · has 1 · part 0 · new 3

**How:** AFK screen

**References:** ElvUI AFK

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| AFK | Rotate camera | toggle |  | On | none | has |
| AFK | AFK screen (model, name, guild, time AFK) | toggle |  | On | world | new |
| AFK | Show stats panel (ilvl, M+, vault) | toggle |  | On | world | new |
| AFK | Don't show in instances | toggle |  | On | none | new |

## Bugs  (`Bugs`)

*Now 9 → target 12* · has 9 · part 0 · new 3

**How:** Error catcher (being rebuilt by the other worker)

**References:** BugSack-like · EUI none

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Bugs (other worker is rebuilding — spec here only for counting) | Lua warnings | toggle |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Blocked actions | toggle |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Reports kept | slider |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Chat notice | toggle |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Sound | dropdown |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Flash on new errors | toggle |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Minimap indicator | dropdown |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Blizzard error window | toggle |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Send error reports to the author | toggle |  |  | none | has |
| Bugs (other worker is rebuilding — spec here only for counting) | Group duplicates with count | toggle |  | On | live | new |
| Bugs (other worker is rebuilding — spec here only for counting) | Filter by addon | dropdown | addons | All | live | new |
| Bugs (other worker is rebuilding — spec here only for counting) | Copy / export report | button |  |  | none | new |

## Quests  (`Quests`)

*Now 0 → target 27* · has 0 · part 0 · new 27

**How:** NEW: quest tracker restyle + quest helper (giver/turn-in pins from ATT MIT data, DB2 QuestPOI and runtime C_QuestLine; community data later)

**References:** EUI QuestTracker ~30 · WindTools Quest 41 · Questie (ARR/GPL, learn only)

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Objective tracker | Restyle objective tracker | toggle |  | On | live | new |
| Objective tracker | Width / max height | slider | 200–400 / 200–900 px | 260 / 600 | live | new |
| Objective tracker | Header font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Objective tracker | Header size | slider | 6–40 | 13 | live | new |
| Objective tracker | Header outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Objective tracker | Header shadow | toggle |  | Off | live | new |
| Objective tracker | Header colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Objective tracker | Objective font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Objective tracker | Objective size | slider | 6–40 | 12 | live | new |
| Objective tracker | Objective outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Objective tracker | Objective shadow | toggle |  | Off | live | new |
| Objective tracker | Objective colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Objective tracker | Progress bars style | texture |  | theme | hover | new |
| Objective tracker | Colour by difficulty | toggle |  | On | live | new |
| Objective tracker | Auto-collapse in instances / combat | dropdown | Off / Instances / Combat / Both | Instances | none | new |
| Objective tracker | Show quest level / tag (daily, campaign) | toggle |  | On | live | new |
| Objective tracker | Click to super-track | toggle |  | On | none | new |
| Quest helper | Waypoint arrow | toggle |  | On | world | new |
| Quest helper | Arrow style / size | dropdown | Phoenix / TomTom-like · 24–96 px | Phoenix 48 | hover | new |
| Quest helper | Distance + ETA text | toggle |  | On | world | new |
| Quest helper | Available quests on map (C_QuestLine) | toggle |  | On | live | new |
| Quest helper | Turn-in / objective areas from QuestPOI (DB2) | toggle |  | On | live | new |
| Quest helper | Quest NPC pins (ATT data + community) | toggle |  | On | live | new |
| Quest helper | Hide low-level / trivial | toggle |  | On | live | new |
| Quest helper | Auto accept / turn in (hold Shift to stop) | toggle |  | Off | none | new |
| Quest helper | Auto pick quest reward (highest sell / sim upgrade) | dropdown | Off / Vendor value / Sim upgrade | Off | none | new |
| Quest helper | Contribute positions to Phoenix data (opt-in) | toggle |  | Off | none | new |

## Group Finder  (`GroupFinder`)

*Now 0 → target 14* · has 0 · part 0 · new 14

**How:** NEW: premade group list filters (PGF-style expressions re-implemented), sign-up helpers

**References:** PremadeGroupsFilter 105 variables (GPL-2, learn only) · EUI GroupFinder · WindTools LFG list

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Filters | Filter panel next to the group list | toggle |  | On | live | new |
| Filters | Min / max members, tanks, healers, damage | slider | 0–40 each | any | live | new |
| Filters | Has Bloodlust / Battle res | toggle | 2 | Off | live | new |
| Filters | Min leader score / item level | slider | 0–4000 / 0–700 | 0 | live | new |
| Filters | Age (minutes) | slider | 0–180 | any | live | new |
| Filters | Dungeon / difficulty / key level | list |  | any | live | new |
| Filters | Advanced expression (Phoenix syntax) | input | e.g. tanks==0 and mprating>=2000 |  | live | new |
| Filters | Sort | dropdown | Age / Score / Item level / Fit | Age | live | new |
| Helpers | One-click sign up (double click) | toggle |  | On | none | new |
| Helpers | Remember sign-up note | toggle |  | On | none | new |
| Helpers | Role / class icons on list entries | toggle |  | On | live | new |
| Helpers | Leader score + best key in tooltip | toggle |  | On | live | new |
| Helpers | Raid lockout hint | toggle |  | On | live | new |
| Helpers | Auto queue (role check) accept | toggle | (AutoQueue idea) | Off | none | new |

## Mythic+  (`MythicPlus`)

*Now 10 → target 32* · has 10 · part 0 · new 22

**How:** Own M+ timer (Blizzard Challenge APIs) + keystone tools

**References:** EUI MythicTimer 125 · WindTools keystone tooltips

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Timer | Run timer | toggle |  | On | live | has |
| Timer | Enemy forces | toggle |  | On | live | has |
| Timer | Boss splits | toggle |  | On | live | has |
| Timer | Deaths | toggle |  | On | live | has |
| Timer | Personal best | toggle |  | On | live | has |
| Timer | Compare with your best run | toggle |  | On | live | has |
| Timer | Current pull | toggle |  | On | live | has |
| Timer | +2 / +3 chest timers | toggle |  | On | live | new |
| Timer | Affix icons with tooltips | toggle |  | On | live | new |
| Timer | Death penalty breakdown | toggle |  | On | live | new |
| Timer | Width | slider | 180–400 | 260 | live | new |
| Timer | Timer bar texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | new |
| Timer | Timer bar fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | new |
| Timer | Timer bar smooth fill | toggle |  | On | live | new |
| Timer | Timer bar gradient | dropdown | None / Horizontal / Vertical | None | live | new |
| Timer | Colours (on time / +2 / +3 / over) | colour | 4 | theme | live | new |
| Timer | Timer font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Timer | Timer size | slider | 6–40 | 22 | live | new |
| Timer | Timer outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Timer | Timer shadow | toggle |  | Off | live | new |
| Timer | Timer colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Timer | Objectives font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | new |
| Timer | Objectives size | slider | 6–40 | 12 | live | new |
| Timer | Objectives outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | new |
| Timer | Objectives shadow | toggle |  | Off | live | new |
| Timer | Objectives colour | colour | colour + class colour + theme token | #FFFFFF | live | new |
| Timer | Hide Blizzard objective tracker in M+ | toggle |  | On | none | new |
| Keystone | Auto-insert keystone | toggle |  | On | none | has |
| Keystone | Report new keystone | toggle |  | On | none | has |
| Keystone | Share keystones with the party | toggle |  | On | none | has |
| Keystone | Party keystones window | toggle |  | On | live | new |
| Keystone | Teleport buttons on dungeon list | toggle |  | On | live | new |

## Encounters  (`Encounters`)

*Now 61 → target 65* · has 61 · part 0 · new 4

**How:** Restyles Blizzard Boss Timeline + warnings (C_EncounterTimeline), BigWigs bars style

**References:** Phoenix S3 already deep · EUI none (EUI has no boss mod)

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Encounters (already deep; small adds) | Existing 61 settings | — | timeline bars, warnings, countdown voice, pull timers, role filters, fonts |  | live | has |
| Encounters (already deep; small adds) | Bar grow direction | dropdown | Up / Down | Down | live | new |
| Encounters (already deep; small adds) | Per-spell colour override | list | spell IDs → colour |  | live | new |
| Encounters (already deep; small adds) | Private aura sounds | list | aura → sound |  | none | new |
| Encounters (already deep; small adds) | Test encounter | button |  |  | world | new |

## PvP  (`PvP`)

*Now 3 → target 8* · has 4 · part 0 · new 4

**How:** Battleground / arena helpers; arena frames live in Unit Frames

**References:** sArena 416 (arena frames — goes to Unit Frames › Arena) · WindTools Combat 33

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| PvP | Safe queue | toggle |  | On | none | has |
| PvP | TAB targets players | toggle |  | On | none | has |
| PvP | /gg to surrender | toggle |  | On | none | has |
| PvP | Auto release in battlegrounds | toggle | (moved from Automation) | On | none | has |
| PvP | Battleground score on top bar | toggle |  | On | live | new |
| PvP | Healer marker on enemy plates | toggle |  | On | live | new |
| PvP | Arena prep: enemy specs | toggle |  | On | live | new |
| PvP | Dampening display | toggle |  | On | live | new |

## Sim  (`Sim`)

*Now 6 → target 8* · has 6 · part 0 · new 2

**How:** Simulationcraft export + uploader results (S2)

**References:** simc addon (Unlicense)

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Sim | Fight style | dropdown |  |  | none | has |
| Sim | Targets | slider |  |  | none | has |
| Sim | Fight length (seconds) | slider |  |  | none | has |
| Sim | Use results for (days) | slider |  |  | none | has |
| Sim | Sim results | toggle |  |  | none | has |
| Sim | Arrow from sim results | toggle |  |  | none | has |
| Sim | Include bags / bank / vault / catalyst options | toggle | 4 | bags+vault | none | new |
| Sim | Top gear candidates list | list |  |  | live | new |

## Diagnostics  (`Diagnostics`)

*Now 0 → target 3* · has 0 · part 3 · new 0

**How:** Status page (secret state, conflicts, versions) — exists as a page, not settings

**References:** —

| Group | Setting | Type | Range / choices | Default | Preview | Status |
|---|---|---|---|---|---|---|
| Diagnostics | Conflicting addons report | button |  |  | none | part |
| Diagnostics | Secret restrictions now (combat/instance) | — | read-only |  | live | part |
| Diagnostics | Reload / reset all | button |  |  | none | part |
