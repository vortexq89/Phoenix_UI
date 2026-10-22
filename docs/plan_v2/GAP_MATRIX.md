# Phoenix UI — module gap matrix (v2)

Generated from `data/spec_*.py` by `data/gen_gap.py` (2026-10-22, S16 re-audit + I:\ parity audit + S17 gap rows). One row per user-facing setting. Composite controls are expanded: a font group is 5 rows (font, size, outline, shadow, colour), a border group is 3–5 rows (style, size, colour, shadow, shadow size), a backdrop is 4 rows, a position block is 5 rows.

**Columns:** *Now* = Phoenix settings today on retail (smoke harness settings count, cog sub-rows included) · *Forever* = the same count on the WoW Forever client (— = page not on Forever) · *Target* = full spec below minus link/api rows · *Has / Part / New* = target rows that Phoenix already has, has in a shallower form, or lacks · *Link / API* = rows owned by another page or Edit Mode (a link row points there) or not possible with the 12.x API; listed, not counted.

**Status:** `has` = present · `part` = present but shallower (fewer choices, global instead of per-bar, etc.) · `new` = missing · `link` = owned by another page or Edit Mode · `api` = not possible in 12.x (secret values, protected frames, no data source).  **Preview:** `live` = the pinned preview in the settings window redraws · `hover` = hovering a dropdown item previews it · `world` = shows test/unlocked frames in the game world · `none` = behaviour only.

**Source addon:** the reference addon a row comes from (for spec rows: the best match among the addons whose features this page owns in [PARITY.md](PARITY.md)). Rows grouped *Parity: <addon>* were added by the parity audit for features beyond the original spec; their *Stage* says when they are built. Encounter module coverage (BigWigs / LittleWigs vs Phoenix) is in PARITY.md.

**Per-unit / per-bar rule:** groups marked *per bar* or *per unit* are one set of controls with a unit/bar switcher plus *Copy from…* and *Apply to all*; they are counted once, not ×N.

## Summary

| Module | Group | Now | Forever | Target | Has | Part | New | Link / API | References | How Phoenix builds it |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| Action Bars | Action Bars & Cooldowns | 117 | 116 | 117 | 111 | 3 | 3 | 3 | EUI ActionBars 136 controls (BarVisibilityLayout, BarAppearance, Animations, XP/Rep, Menu/Bags) · WindTools ExtraItemBar 27 · MoveAny bar toggles | Own secure bar containers holding Blizzard's action buttons (EUI pattern); Edit Mode bars stay as fallback |
| Cooldown Text | Action Bars & Cooldowns | 15 | 15 | 12 | 12 | 0 | 0 | 0 | EUI cooldown numbers settings | Blizzard countdown numbers on all cooldown frames (C_DurationUtil text bindings) |
| Cooldown Manager | Action Bars & Cooldowns | 93 | 89 | 68 | 54 | 9 | 5 | 2 | EUI CooldownManager 152 controls (Bars, BuffBars, SpellPicker, glow conditions) · EUI AuraBuffReminders 49 | Skins and extends Blizzard's Cooldown Manager viewers (Essential, Utility, Buff icons, Buff bars); the only legal 'WeakAuras' in Midnight |
| Unit Frames | Unit Frames | 209 | 209 | 175 | 135 | 25 | 15 | 3 | EUI UnitFrames 356 controls (SharedBars, SharedAppearance, SharedCastAuras, MiniFrames, TextSlots) + ResourceBars 247 · sArena 416 (arena) · WindTools Quick Focus, Absorb, Role icon | Own secure unit frames (SecureUnitButtonTemplate) for player, target, target-of-target, focus, focus-target, pet, boss 1–5, arena 1–5; Blizzard skin kept as a 'Blizzard frames' mode |
| Group Frames | Unit Frames | 194 | 193 | 77 | 66 | 5 | 6 | 1 | EUI RaidFrames 247 controls (Frames, VisualBars, VisualIndicators, aura managers) · Blizzard compact raid frame options | Own secure party and raid headers (SecureGroupHeaderTemplate), Blizzard compact frames as fallback |
| Nameplates | Nameplates | 276 | 270 | 103 | 98 | 5 | 0 | 1 | EUI Nameplates 176 controls (General, DisplayLayout, DisplayBars, Colors, TextColoring) · WindTools friendly outline | Restyles Blizzard's nameplates (they stay Blizzard's secure frames) |
| Cast Bars | Combat | 103 | 113 | 59 | 53 | 5 | 1 | 0 | EUI ResourceBars CastBarPage 41 + UnitFrames cast section 32 + MythicTimer targeted spell bars 21 | Own cast bars for player, target, focus, pet, boss (UnitCastingInfo is secret only where restricted; text through display sinks) |
| Buffs & Debuffs | Combat | 64 | 64 | 42 | 41 | 0 | 1 | 0 | EUI PlayerAuraBars 43 + BlizzardSkin aura bits · ElvUI-style aura headers | Restyles Blizzard's player buff and debuff frames (BuffFrame/DebuffFrame); own aura bars optional |
| Combat Text | Combat | 30 | 30 | 26 | 25 | 1 | 0 | 0 | Blizzard FCT CVars · MSBT-like | Configures Blizzard floating combat text (CVars) + optional Phoenix scrolling areas |
| Damage Meter | Combat | 24 | 24 | 29 | 22 | 4 | 3 | 7 | EUI DamageMeters 82 | Restyles Blizzard's built-in damage meter (C_DamageMeter, 12.0) |
| Spell History | Combat | 13 | 13 | 15 | 12 | 2 | 1 | 0 | — | Row of recently cast spells |
| Chat | Interface | 61 | 61 | 52 | 47 | 4 | 1 | 2 | EUI Chat 57 · WindTools Social (chat bar, emotes, links) 16 · Prat-like features | Restyles Blizzard chat frames and adds tools; no chat replacement |
| Minimap | Interface | 49 | 46 | 43 | 38 | 1 | 4 | 2 | EUI Minimap 62 · WindTools Maps 29 (rectangle minimap, buttons bar, instance difficulty, world map reveal) | Restyles Blizzard's minimap cluster |
| Tooltips | Interface | 58 | 55 | 50 | 42 | 2 | 6 | 2 | EUI BlizzardSkin tooltip 23 · WindTools Tooltips 27 · idTip 27 ID kinds | Restyles GameTooltip and adds lines; IDs where idTip-style (BSD-2) |
| Bags | Interface | 56 | 55 | 48 | 38 | 9 | 1 | 5 | EUI Bags 45 · Baganator-style features | Restyles Blizzard's combined bag + bank; own sorting via C_Container |
| Item Level | Interface | 20 | 20 | 22 | 18 | 3 | 1 | 0 | EUI BlizzardSkin character sheet 30 · WindTools Item 27 (inspect, already known) | Item level on character, inspect, bags, loot frames |
| Data Texts | Interface | 77 | 76 | 51 | 39 | 12 | 0 | 0 | EUI DataBars 55 (XP/rep/honor bars) + MinimapDataText · ElvUI datatexts | Own data panels + broker (LDB) feeds |
| Skins | Interface | 36 | 34 | 37 | 24 | 9 | 4 | 0 | EUI BlizzardSkin 123 (character, popups, tooltips, skyriding, CDM, objective tracker) | Phoenix look for Blizzard windows |
| Appearance & General | Phoenix | 52 | 52 | 22 | 18 | 4 | 0 | 2 | EUI Fonts 37 + Textures + Colors + Glow + General ~90 | Theme, global fonts/textures/colours, scale, sounds; every module's 'Theme default' points here |
| Profiles | Phoenix | 15 | 11 | 8 | 6 | 2 | 0 | 1 | EUI Profiles 4 pages (Profiles, Presets, Overrides, FullExport) | Profiles, per-spec switching, import/export strings, presets |
| Layout (Movers) | Phoenix | 17 | 17 | 15 | 11 | 3 | 1 | 0 | MoveAny 150 frame toggles · EUI unlock mode (snap, grid, nudge, per-element) | Unlock mode for every Phoenix-owned frame + selected Blizzard frames (no Edit Mode conflicts) |
| Quality of life | Phoenix | 22 | 22 | 28 | 9 | 7 | 12 | 0 | EUI QoL 75 · WindTools Misc 112 | Small UI tweaks |
| Automation | Phoenix | 15 | 15 | 17 | 13 | 1 | 3 | 1 | EUI QoL 75 · WindTools Misc 112 | Small automations |
| AFK screen | Phoenix | 12 | 12 | 4 | 4 | 0 | 0 | 0 | ElvUI AFK | AFK screen |
| Bugs | Phoenix | 12 | 12 | 12 | 12 | 0 | 0 | 0 | BugSack-like · EUI none | Error catcher (being rebuilt by the other worker) |
| Quests | Content | 43 | 41 | 41 | 25 | 10 | 6 | 1 | EUI QuestTracker ~30 · WindTools Quest 41 · Questie (ARR/GPL, learn only) | NEW: quest tracker restyle + quest helper (giver/turn-in pins from ATT MIT data, DB2 QuestPOI and runtime C_QuestLine; community data later) |
| Group Finder | Content | 58 | — | 18 | 11 | 4 | 3 | 6 | PremadeGroupsFilter 105 variables (GPL-2, learn only) · EUI GroupFinder · WindTools LFG list | NEW: premade group list filters (PGF-style expressions re-implemented), sign-up helpers |
| Mythic+ | Content | 34 | — | 32 | 30 | 0 | 2 | 1 | EUI MythicTimer 125 · WindTools keystone tooltips | Own M+ timer (Blizzard Challenge APIs) + keystone tools |
| Encounters | Content | 64 | 9 | 77 | 63 | 7 | 7 | 5 | Phoenix S3 already deep · EUI none (EUI has no boss mod) | Restyles Blizzard Boss Timeline + warnings (C_EncounterTimeline), BigWigs bars style |
| PvP | Content | 10 | 10 | 5 | 4 | 0 | 1 | 4 | sArena 416 (arena frames — goes to Unit Frames › Arena) · WindTools Combat 33 | Battleground / arena helpers; arena frames live in Unit Frames |
| Sim | Content | 11 | — | 8 | 7 | 1 | 0 | 0 | simc addon (Unlicense) | Simulationcraft export + uploader results (S2) |
| Diagnostics | Phoenix | 9 | 9 | 3 | 0 | 3 | 0 | 0 | — | Status page (secret state, conflicts, versions) — exists as a page, not settings |
| Auction House | Items | 0 | 0 | 4 | 0 | 0 | 4 | 0 | Auctionator | New page (S22): shopping lists, price history from ReplicateItems, undercut and cancel lists; every search, post and cancel is your click |
| Loadouts | Profiles | 0 | 0 | 1 | 0 | 0 | 1 | 0 | EllesmereUI LoadoutManager | New page (S28): per-spec / per-instance loadouts that switch profile, talents and gear set (out of combat, your confirmation) |
| **Total** | | **1869** | **1693** | **1321** | **1088** | **141** | **92** | **49** | every addon on I:\ (see PARITY.md) | |

## Rows by source addon

| Source addon | Rows | has | part | new | link | api |
|---|---:|---:|---:|---:|---:|---:|
| EllesmereUI ActionBars | 118 | 111 | 3 | 1 | 2 | 1 |
| EllesmereUI WindTools | 112 | 82 | 16 | 12 | 1 | 1 |
| EllesmereUI ResourceBars | 91 | 74 | 11 | 5 | 0 | 1 |
| EllesmereUI Nameplates | 84 | 80 | 3 | 0 | 0 | 1 |
| BigWigs | 83 | 63 | 8 | 8 | 0 | 4 |
| EllesmereUI UnitFrames | 79 | 69 | 8 | 1 | 1 | 0 |
| EllesmereUI CooldownManager | 76 | 63 | 8 | 3 | 0 | 2 |
| EllesmereUI RaidFrames | 66 | 55 | 5 | 5 | 1 | 0 |
| EllesmereUI QoL | 58 | 43 | 4 | 10 | 0 | 1 |
| EllesmereUI BlizzardSkin | 57 | 44 | 9 | 3 | 1 | 0 |
| EllesmereUI MythicTimer | 55 | 50 | 2 | 2 | 1 | 0 |
| EllesmereUI Chat | 53 | 46 | 4 | 1 | 0 | 2 |
| EllesmereUI Bags | 51 | 37 | 8 | 1 | 5 | 0 |
| EllesmereUI (core pages) | 49 | 37 | 5 | 5 | 2 | 0 |
| EllesmereUI ForeverEssentials | 48 | 36 | 1 | 11 | 0 | 0 |
| EllesmereUI DamageMeters | 47 | 34 | 4 | 2 | 6 | 1 |
| EllesmereUI PlayerAuraBars | 42 | 41 | 0 | 1 | 0 | 0 |
| sArena Reloaded | 40 | 18 | 8 | 8 | 3 | 3 |
| EllesmereUI DataBars | 32 | 22 | 10 | 0 | 0 | 0 |
| EllesmereUI Minimap | 30 | 27 | 1 | 0 | 1 | 1 |
| MoveAny | 18 | 15 | 2 | 1 | 0 | 0 |
| EllesmereUI | 16 | 16 | 0 | 0 | 0 | 0 |
| Questie | 11 | 1 | 6 | 2 | 0 | 2 |
| PremadeGroupsFilter | 10 | 6 | 1 | 1 | 0 | 2 |
| BugGrabber + BugSack | 8 | 5 | 3 | 0 | 0 | 0 |
| Simulationcraft | 8 | 7 | 1 | 0 | 0 | 0 |
| EllesmereUI AuraBuffReminders | 6 | 4 | 2 | 0 | 0 | 0 |
| AutoQueue | 6 | 1 | 2 | 1 | 0 | 2 |
| Auctionator | 5 | 0 | 0 | 5 | 0 | 0 |
| TrufiGCD | 2 | 0 | 2 | 0 | 0 | 0 |
| EllesmereUI QuestTracker | 2 | 1 | 0 | 1 | 0 | 0 |
| LittleWigs | 2 | 0 | 1 | 0 | 0 | 1 |
| EllesmereUI Quickdraw | 1 | 0 | 0 | 1 | 0 | 0 |
| idTip | 1 | 0 | 0 | 1 | 0 | 0 |
| EllesmereUI Friends | 1 | 0 | 1 | 0 | 0 | 0 |
| QuestieTrace | 1 | 0 | 1 | 0 | 0 | 0 |
| EllesmereUI GroupFinder | 1 | 0 | 1 | 0 | 0 | 0 |

## Action Bars  (`ActionBars`)

*Now 117 (Forever 116) → target 117* · has 111 · part 3 · new 3 · link/api 3

**How:** Own secure bar containers holding Blizzard's action buttons (EUI pattern); Edit Mode bars stay as fallback

**References:** EUI ActionBars 136 controls (BarVisibilityLayout, BarAppearance, Animations, XP/Rep, Menu/Bags) · WindTools ExtraItemBar 27 · MoveAny bar toggles

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Enable bar | toggle |  | On for 1–4, pet, stance | world | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Buttons | slider | 1–12 | 12 | live | has | MoveAny |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Rows | slider | 1–12 | 1 | live | has | EllesmereUI ActionBars |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Button width | slider | 16–120 px | 40 | live | has | EllesmereUI ActionBars |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Button height | slider | 16–120 px | 40 | live | has | EllesmereUI ActionBars |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Keep square | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Horizontal spacing | slider | -10–30 px | 2 | live | has | EllesmereUI ActionBars |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Vertical spacing | slider | -10–30 px | 2 | live | has | EllesmereUI ActionBars |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Grow direction | dropdown | Right / Left / Up / Down | Right | live | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Wrap direction | dropdown | Down / Up / Left / Right | Down | live | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Button order | dropdown | Normal / Reversed | Normal | live | has | EllesmereUI ActionBars |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Show empty slots | toggle |  | Off | live | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Click-through | toggle |  | Off | none | has | EllesmereUI ActionBars |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Lock buttons (no drag) | toggle |  | Off | none | has | MoveAny |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Anchor | dropdown | 9 points + frame picker | per element | world | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | X offset | slider | -2000–2000 | per element | world | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Y offset | slider | -1200–1200 | per element | world | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | has | EllesmereUI WindTools |  |
| Bars › Layout (per bar: 1–8, pet, stance, possess, vehicle, extra, zone) | Scale | slider | 50–200 % | 100 | world | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar backdrop | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar backdrop texture | texture | Phoenix surfaces + LSM | Solid | hover | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar backdrop colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar backdrop opacity | slider | 0–100 % | 50 | live | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Backdrop padding | slider | 0–20 px | 3 | live | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | None | hover | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI ActionBars |  |
| Bars › Backdrop (per bar) | Bar border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Show in combat | toggle |  | On | world | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Show out of combat | toggle |  | On | world | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Fade out of combat | toggle |  | Off | world | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Out-of-combat opacity | slider | 0–100 % | 40 | world | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Show on mouseover | toggle |  | Off | world | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Hide in vehicles / pet battles | toggle |  | On | none | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Custom state macro | input | [combat] show; hide … |  | none | has | EllesmereUI WindTools |  |
| Bars › Visibility (per bar) | Show while dragging a spell | toggle |  | On | world | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Show while spellbook open | toggle |  | On | world | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Mouseover reveals all bars | toggle |  | Off | world | has | EllesmereUI ActionBars |  |
| Bars › Visibility (per bar) | Bar opacity | slider | 0–100 % | 100 | world | has | EllesmereUI ActionBars |  |
| Bars › Paging (bar 1) | Form/stance paging | toggle |  | On | none | has | EllesmereUI ActionBars |  |
| Bars › Paging (bar 1) | Skyriding paging | toggle |  | On | none | has | EllesmereUI ActionBars |  |
| Bars › Paging (bar 1) | Modifier paging (shift/ctrl/alt → bar) | dropdown | Off / bar 2–6 | Off | none | has | EllesmereUI ActionBars |  |
| Bars › Paging (bar 1) | Possess / override paging | toggle |  | On | none | has | EllesmereUI ActionBars |  |
| Bars › Paging (bar 1) | Paging arrows | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Button shape | dropdown | Square / Rounded / Circle / Hexagon / Blizzard | Square | hover | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Icon zoom (crop) | slider | 0–20 % | 8 | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Icon desaturate on cooldown | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Icon opacity on cooldown | slider | 0–100 % | 100 | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Icon background (empty slot) | slider | 0–100 % | 40 | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Button border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Equipped item border colour | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Buttons › Shape and icon (all bars, with per-bar override) | Item quality border | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Out-of-range tint | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Out-of-range colour | colour |  | #E64040 | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Not-enough-power tint | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Not-enough-power colour | colour |  | #4060E6 | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Unusable tint | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Unusable colour | colour |  | #666666 | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Tint target | dropdown | Icon / Hotkey text / Both | Icon | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Pushed style | dropdown | Blizzard / Accent flash / Darken / None | Accent flash | hover | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Highlight style | dropdown | Blizzard / Accent border / Glow / None | Accent border | hover | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Checked (active) style | dropdown | Blizzard / Accent border / None | Accent border | hover | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Proc glow style | dropdown | Blizzard / Pixel / Autocast / Button / None | Blizzard | hover | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Proc glow colour | colour |  | #FFD34A | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Assisted highlight (one-button assist) | dropdown | Blizzard / Accent ring / Off | Blizzard | hover | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Hide casting animation | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Cooldown swipe opacity | slider | 0–100 % | 80 | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Cooldown edge (bling) | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | GCD swipe | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Buttons › Feedback | Disable button tooltips | dropdown | Never / In combat / Always | Never | none | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Show hotkeys | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Hotkey font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Hotkey size | slider | 6–40 | 11 | live | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Hotkey outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Hotkey shadow | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Hotkey colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Hotkey anchor | dropdown | 9 points | Top right | live | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Hotkey X offset | slider | -200–200 | 0 | live | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Hotkey Y offset | slider | -200–200 | 0 | live | has | EllesmereUI ActionBars |  |
| Text › Hotkey | Short hotkey labels (S-1, C-F …) | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Text › Macro name | Show macro names | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Text › Macro name | Macro font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI ActionBars |  |
| Text › Macro name | Macro size | slider | 6–40 | 10 | live | has | EllesmereUI ActionBars |  |
| Text › Macro name | Macro outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI ActionBars |  |
| Text › Macro name | Macro shadow | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Text › Macro name | Macro colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI ActionBars |  |
| Text › Macro name | Macro anchor | dropdown | 9 points | Bottom | live | has | EllesmereUI ActionBars |  |
| Text › Macro name | Macro X offset | slider | -200–200 | 0 | live | has | EllesmereUI ActionBars |  |
| Text › Macro name | Macro Y offset | slider | -200–200 | 0 | live | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Count font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Count size | slider | 6–40 | 12 | live | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Count outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Count shadow | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Count colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Count anchor | dropdown | 9 points | Bottom right | live | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Count X offset | slider | -200–200 | 0 | live | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Count Y offset | slider | -200–200 | 0 | live | has | EllesmereUI ActionBars |  |
| Text › Count / charges | Hide charge count at 0 | toggle |  | Off | live | api | EllesmereUI ActionBars |  |
| Text › Cooldown numbers | Cooldown numbers (Blizzard countdown) | toggle |  | On | live | link | EllesmereUI ActionBars |  |
| Text › Cooldown numbers | Cooldown number size | slider | 6–30 | 14 | live | link | EllesmereUI ActionBars |  |
| Text › Cooldown numbers | Charge recharge numbers | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Extra bars | Extra action / zone ability button skin | toggle |  | On | world | has | EllesmereUI ActionBars |  |
| Extra bars | Extra button scale | slider | 50–200 % | 100 | world | has | EllesmereUI ActionBars |  |
| Extra bars | Hide extra button artwork | toggle |  | Off | world | has | EllesmereUI ActionBars |  |
| Extra bars | Vehicle exit button skin | toggle |  | On | world | has | EllesmereUI ActionBars |  |
| Extra bars | Micro menu bar (layout, size, mouseover) | dropdown | Hidden / Bar / Mouseover | Bar | world | has | EllesmereUI ActionBars |  |
| Extra bars | Bag bar (layout, size, mouseover) | dropdown | Hidden / Bar / Mouseover | Mouseover | world | has | EllesmereUI ActionBars |  |
| Extra bars | Extra item bar (quest items, consumables) | toggle |  | Off | world | has | EllesmereUI WindTools |  |
| Extra bars | Extra item bar: custom item list | list | item IDs |  | none | has | EllesmereUI WindTools |  |
| Parity: EllesmereUI ActionBars | Button press / hover / cast animations, assisted-highlight ring, interaction colours | — | Pressed/mouseover looks, assisted highlight and cast-animation hiding exist; class-coloured interaction colour and ring fit on cropped buttons do not |  | live | part | EllesmereUI ActionBars | S26 |
| Parity: EllesmereUI ActionBars | Crafted-quality rank pip on item buttons | — |  |  | live | new | EllesmereUI ActionBars | S26 |
| Parity: EllesmereUI ActionBars | Micro menu, bag bar and reputation bar layout (orientation, text, texture) | — | Phoenix shows/hides the menu and bag buttons; their layout belongs to Edit Mode. Rep bar text/texture is on Data Texts |  | live | part | EllesmereUI ActionBars | S28 |
| Parity: EllesmereUI ForeverEssentials | WoW Forever: put the highest spell rank on your bars after training | — | Out of combat only (PlaceAction is protected) |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: EllesmereUI Quickdraw | Radial / grid action menu on a key (world markers, nesting) | — | Secure buttons inside a SecureHandler; set up out of combat |  | live | new | EllesmereUI Quickdraw | S26 |
| Parity: EllesmereUI WindTools | Extra item bars (custom items, groups, visibility, texts) | — | Item bar with quest items and extra items exists; several bars, groups and blacklist do not |  | live | part | EllesmereUI WindTools | S26 |

## Cooldown Text  (`CooldownText`)

*Now 15 (Forever 15) → target 12* · has 12 · part 0 · new 0 · link/api 0

**How:** Blizzard countdown numbers on all cooldown frames (C_DurationUtil text bindings)

**References:** EUI cooldown numbers settings

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Countdown | Countdown numbers | toggle |  | On | live | has | EllesmereUI |  |
| Countdown | Countdown font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI |  |
| Countdown | Countdown size | slider | 6–40 | 14 | live | has | EllesmereUI |  |
| Countdown | Countdown outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI |  |
| Countdown | Countdown shadow | toggle |  | Off | live | has | EllesmereUI |  |
| Countdown | Countdown colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI |  |
| Countdown | Colour by remaining (expiring / seconds / minutes) | colour | 3 colours | red / yellow / white | live | has | EllesmereUI |  |
| Countdown | Expiring threshold | slider | 0–10 s | 3 | live | has | EllesmereUI |  |
| Countdown | Decimals below | slider | 0–10 s | 0 | live | has | EllesmereUI |  |
| Countdown | Minimum duration shown | slider | 0–10 s | 1.5 | none | has | EllesmereUI |  |
| Countdown | Hide on aura icons | toggle |  | Off | live | has | EllesmereUI |  |
| Countdown | Scale with icon size | toggle |  | On | live | has | EllesmereUI |  |

## Cooldown Manager  (`Tracker`)

*Now 93 (Forever 89) → target 68* · has 54 · part 9 · new 5 · link/api 2

**How:** Skins and extends Blizzard's Cooldown Manager viewers (Essential, Utility, Buff icons, Buff bars); the only legal 'WeakAuras' in Midnight

**References:** EUI CooldownManager 152 controls (Bars, BuffBars, SpellPicker, glow conditions) · EUI AuraBuffReminders 49

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Viewers › Layout (Essential / Utility / Buff icons, each) | Icon size | slider | 16–100 px | 40 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Icons per row | slider | 1–15 | 8 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Rows | slider | 1–6 | 2 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Second row icon size | slider | -20–20 px vs first | -6 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Spacing | slider | -10–20 px | 2 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Row growth | dropdown | Down / Up | Down | live | has | EllesmereUI CooldownManager |  |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Vertical orientation | toggle |  | Off | live | has | EllesmereUI CooldownManager |  |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Keep buffs in place (no shifting) | toggle |  | Off | live | has | EllesmereUI CooldownManager |  |
| Viewers › Layout (Essential / Utility / Buff icons, each) | Overflow to | dropdown | Next row / Utility viewer / Hide | Next row | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Phoenix style | toggle |  | On | live | has | MoveAny |  |
| Viewers › Icons | Square icons | toggle |  | On | live | has | MoveAny |  |
| Viewers › Icons | Icon zoom | slider | 0–20 % | 8 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Icon border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Icon border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Icon border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Icon border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Icon border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Desaturate when on cooldown | toggle |  | On | live | has | MoveAny |  |
| Viewers › Icons | Suppress GCD swipe | toggle |  | On | live | has | MoveAny |  |
| Viewers › Icons | Show keybind | toggle |  | Off | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Proc glow style | dropdown | Blizzard / Pixel / Autocast / Button | Blizzard | hover | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Glow colour / lines / speed / thickness | colour | colour + 3 sliders | gold / 8 / 4 / 2 | live | part | EllesmereUI CooldownManager | S20 |
| Viewers › Icons | Timer font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Timer size | slider | 6–40 | 14 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Timer outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Timer shadow | toggle |  | Off | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Timer colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Stacks and charges font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Stacks and charges size | slider | 6–40 | 12 | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Stacks and charges outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Stacks and charges shadow | toggle |  | Off | live | has | EllesmereUI CooldownManager |  |
| Viewers › Icons | Stacks and charges colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Bar width / height | slider | 40–800 / 8–60 px | 220 / 20 | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Buff bar texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI CooldownManager |  |
| Buff bars | Buff bar fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | part | EllesmereUI CooldownManager | S20 |
| Buff bars | Buff bar smooth fill | toggle |  | On | live | api | EllesmereUI CooldownManager |  |
| Buff bars | Buff bar gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Bar colour | colour | class / custom | class | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Bar background | toggle |  | On | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Bar background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI CooldownManager | S20 |
| Buff bars | Bar background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Bar background opacity | slider | 0–100 % | 70 | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Spell name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI CooldownManager |  |
| Buff bars | Spell name size | slider | 6–40 | 12 | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Spell name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Spell name shadow | toggle |  | Off | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Spell name colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Icon position | dropdown | Left / Right / Off | Left | live | has | EllesmereUI CooldownManager |  |
| Buff bars | Stack-based fill | toggle |  | Off | live | api | EllesmereUI CooldownManager |  |
| Visibility | Fade out of combat | toggle |  | On | world | has | EllesmereUI CooldownManager |  |
| Visibility | Opacity out of combat | slider | 0–100 % | 40 | world | has | EllesmereUI CooldownManager |  |
| Visibility | Show only with a target | toggle |  | Off | world | has | EllesmereUI CooldownManager |  |
| Reminders (out of combat) | Missing flask / food / rune / weapon oil | toggle | per type | On in instances | world | has | EllesmereUI AuraBuffReminders |  |
| Reminders (out of combat) | Missing raid buffs (class) | toggle |  | On | world | has | EllesmereUI AuraBuffReminders |  |
| Reminders (out of combat) | Missing pet / wrong pet | toggle |  | On | world | has | EllesmereUI AuraBuffReminders |  |
| Reminders (out of combat) | Healthstone / soulstone | toggle |  | On | world | has | EllesmereUI AuraBuffReminders |  |
| Reminders (out of combat) | Ready-check mana warning | toggle |  | On | world | has | EllesmereUI CooldownManager |  |
| Reminders (out of combat) | Reminder sound | dropdown | sound list with play | None | hover | has | EllesmereUI CooldownManager |  |
| Reminders (out of combat) | Reminder icon size / position | slider | 16–64 + anchor | 36 | world | has | EllesmereUI CooldownManager |  |
| Parity: EllesmereUI CooldownManager | Cooldown icon look: shape, zoom, border, duration / stack text, item count and quality, numbers-only mode | — | Numbers-only (no icon) mode and item quality on icons are missing |  | live | part | EllesmereUI CooldownManager | S20 |
| Parity: EllesmereUI CooldownManager | Viewer extras: trinkets, tooltips, keybinds, rotation helper, mirror key presses, potion swap, glows only in combat | — | Trinkets, tooltips and keybinds exist; key-press mirroring, potion swap and in-combat-only glows do not |  | live | part | EllesmereUI CooldownManager | S20 |
| Parity: EllesmereUI CooldownManager | Rotation assist icon (C_AssistedCombat) with keybind and GCD | — |  |  | live | new | EllesmereUI CooldownManager | S20 |
| Parity: EllesmereUI CooldownManager | Glow conditions: at N stacks, only in combat, by hero talent; text and background per tracked spell | — | Stack counts of tracked auras are secret in combat, so 'glow at N stacks' needs the viewer's own alert events (verify in game) |  | live | new | EllesmereUI CooldownManager | S20 |
| Parity: EllesmereUI CooldownManager | Per-spell overrides in the spell picker (duration, glow at stacks, size, colour) | — | Phoenix picks spells; per-spell overrides are missing |  | live | part | EllesmereUI CooldownManager | S20 |
| Parity: EllesmereUI CooldownManager | Buff bar groups (named groups, auto-add, global group, shift when empty) | — |  |  | live | new | EllesmereUI CooldownManager | S20 |
| Parity: EllesmereUI CooldownManager | Buff bar size, texture, texts, timer decimals, reverse fill, charge hash lines, smooth bars | — | Smooth fill and gradient are open gap rows; hash lines and partial-charge shade are missing |  | live | part | EllesmereUI CooldownManager | S20 |
| Parity: EllesmereUI AuraBuffReminders | Missing-buff reminders: custom spells, sounds, where shown, scale, cursor attach, M+ beacon, well fed / camp | — | Phoenix Reminders has flask, food, rune, raid buff, weapon oil, pet, healthstone and mana; custom spells, cursor attach and position presets are missing |  | live | part | EllesmereUI AuraBuffReminders | S20 |
| Parity: EllesmereUI AuraBuffReminders | Pet reminders (missing / passive / wrong demon), soulstone, consumables without item | — | Pet reminder exists; passive / wrong-demon and soulstone checks are missing |  | live | part | EllesmereUI AuraBuffReminders | S20 |
| Parity: EllesmereUI QoL | Movement-cooldown alert (with TTS), Time Spiral and gateway shard alerts | — | Own-spell cooldowns can be secret in combat; the alert would use the Cooldown Manager's events |  | live | new | EllesmereUI QoL | S20 |
| Parity: EllesmereUI ResourceBars | Spec helper: Arcane Soul countdown | — |  |  | live | new | EllesmereUI ResourceBars | S20 |

## Unit Frames  (`UnitFrames`)

*Now 209 (Forever 209) → target 175* · has 135 · part 25 · new 15 · link/api 3

**How:** Own secure unit frames (SecureUnitButtonTemplate) for player, target, target-of-target, focus, focus-target, pet, boss 1–5, arena 1–5; Blizzard skin kept as a 'Blizzard frames' mode

**References:** EUI UnitFrames 356 controls (SharedBars, SharedAppearance, SharedCastAuras, MiniFrames, TextSlots) + ResourceBars 247 · sArena 416 (arena) · WindTools Quick Focus, Absorb, Role icon

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Frame (per unit, with Copy from / Apply to all) | Enable frame | toggle |  | On | world | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame mode | dropdown | Phoenix frames / Blizzard frames restyled | Phoenix frames | world | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Width | slider | 60–400 px | 220 (player/target), 120 (small) | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Height | slider | 16–120 px | 44 | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Anchor | dropdown | 9 points + frame picker | per element | world | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | X offset | slider | -2000–2000 | per element | world | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Y offset | slider | -1200–1200 | per element | world | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | has | EllesmereUI ResourceBars |  |
| Frame (per unit, with Copy from / Apply to all) | Scale | slider | 50–200 % | 100 | world | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame background | toggle |  | On | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI ResourceBars | S18 |
| Frame (per unit, with Copy from / Apply to all) | Frame background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame background opacity | slider | 0–100 % | 80 | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Frame border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Hover highlight | dropdown | None / Border / Glow | Border | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Target highlight (on group/boss) | dropdown | None / Border / Glow | Border | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Out-of-range opacity | slider | 10–100 % | 55 | live | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Fade out of combat (player) | toggle |  | Off | world | has | EllesmereUI ResourceBars |  |
| Frame (per unit, with Copy from / Apply to all) | Out-of-combat opacity | slider | 0–100 % | 100 | world | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Show tooltip on hover | dropdown | Always / Out of combat / Never | Out of combat | none | has | EllesmereUI UnitFrames |  |
| Frame (per unit, with Copy from / Apply to all) | Click casting (Blizzard Click Cast bindings) | toggle |  | On | none | link | EllesmereUI UnitFrames |  |
| Health bar | Health bar height share | slider | 40–100 % | 80 | live | part | EllesmereUI ResourceBars | S18 |
| Health bar | Health texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI ResourceBars |  |
| Health bar | Health fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | has | EllesmereUI ResourceBars |  |
| Health bar | Health smooth fill | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Health bar | Health gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI ResourceBars |  |
| Health bar | Colour mode | dropdown | Class / Reaction / Fixed / Gradient by health / Class gradient | Class | hover | has | EllesmereUI ResourceBars |  |
| Health bar | Fixed colour | colour |  | #2E2E33 | live | has | EllesmereUI ResourceBars |  |
| Health bar | Gradient low/mid/high colours | colour | 3 colours | red/yellow/green | live | has | EllesmereUI ResourceBars |  |
| Health bar | Tapped colour | colour |  | #8C8C8C | live | has | EllesmereUI ResourceBars |  |
| Health bar | Disconnected / dead colour | colour |  | #555555 | live | has | EllesmereUI ResourceBars |  |
| Health bar | Dark mode (dark fill, coloured background) | toggle |  | Off | hover | has | EllesmereUI UnitFrames |  |
| Health bar | Background colour mode | dropdown | Class (dimmed) / Fixed / Same as fill | Fixed | live | has | EllesmereUI ResourceBars |  |
| Health bar | Background opacity | slider | 0–100 % | 60 | live | has | EllesmereUI ResourceBars |  |
| Health bar | Reverse fill | toggle |  | Off | live | has | EllesmereUI ResourceBars |  |
| Absorbs and heal prediction | Absorb shield | dropdown | Off / Overlay / Stacked bar / Striped | Striped | hover | has | EllesmereUI UnitFrames |  |
| Absorbs and heal prediction | Absorb opacity | slider | 5–100 % | 60 | live | has | EllesmereUI UnitFrames |  |
| Absorbs and heal prediction | Over-absorb glow line | toggle |  | On | live | part | EllesmereUI UnitFrames | S18 |
| Absorbs and heal prediction | Heal absorb | dropdown | Off / Overlay / Striped | Overlay | hover | has | EllesmereUI UnitFrames |  |
| Absorbs and heal prediction | Heal prediction | toggle |  | On | live | has | EllesmereUI UnitFrames |  |
| Absorbs and heal prediction | Overheal shown | slider | 0–50 % | 10 | live | has | EllesmereUI UnitFrames |  |
| Absorbs and heal prediction | Prediction colours (mine / others) | colour | 2 colours | green / light green | live | part | EllesmereUI UnitFrames | S18 |
| Power bar | Show power bar | dropdown | Always / Mana users / Never | Always | live | has | EllesmereUI ResourceBars |  |
| Power bar | Power bar height | slider | 0–40 px | 6 | live | has | sArena Reloaded |  |
| Power bar | Position | dropdown | Below / Above / Inside bottom / Detached | Below | live | has | EllesmereUI UnitFrames |  |
| Power bar | Detached width | slider | 0–400 px | 0 (= frame) | live | part | EllesmereUI ResourceBars | S18 |
| Power bar | Power texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI ResourceBars |  |
| Power bar | Power fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | part | EllesmereUI ResourceBars | S18 |
| Power bar | Power smooth fill | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Power bar | Power gradient | dropdown | None / Horizontal / Vertical | None | live | part | EllesmereUI UnitFrames | S18 |
| Power bar | Colour by power type | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Power bar | Custom power colours | colour | per power type | Blizzard | live | has | EllesmereUI ResourceBars |  |
| Power bar | Spell cost prediction | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Power bar | Mana regen spark | dropdown | Off / Spark / Tick | Off | live | api | EllesmereUI ResourceBars |  |
| Class power (player) | Show class power | dropdown | Off / Attached / Detached | Attached | live | has | EllesmereUI ResourceBars |  |
| Class power (player) | Pip height | slider | 2–30 px | 8 | live | has | EllesmereUI ResourceBars |  |
| Class power (player) | Pip spacing | slider | 0–10 px | 2 | live | has | EllesmereUI ResourceBars |  |
| Class power (player) | Pip shape | dropdown | Bar / Square / Round | Bar | hover | has | EllesmereUI ResourceBars |  |
| Class power (player) | Colour mode | dropdown | Class / Power type / Custom | Power type | live | has | EllesmereUI ResourceBars |  |
| Class power (player) | Charged colour | colour |  | #4FC3F7 | live | has | EllesmereUI ResourceBars |  |
| Class power (player) | Empty pip opacity | slider | 0–100 % | 25 | live | has | EllesmereUI ResourceBars |  |
| Class power (player) | Runes sorted by ready time | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Class power (player) | Stagger / Soul fragments / Ebon Might extras | toggle |  | On | live | part | EllesmereUI ResourceBars | S18 |
| Class power (player) | Fade out of combat | toggle |  | Off | world | part | EllesmereUI ResourceBars | S18 |
| Text tags (left / center / right / top) | Tag system | input | [name] [health:current] [health:percent] [power:current] [level] [classification] [status] [group] … | Left: [name]  Right: [health:percent] | live | has | sArena Reloaded |  |
| Text tags (left / center / right / top) | Health text format | dropdown | Current / Percent / Current / Percent / Deficit / Current / Max | Current | Percent | hover | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Abbreviate numbers | dropdown | Blizzard (K/M) / Full / Asian (萬/億) | Blizzard | live | has | sArena Reloaded |  |
| Text tags (left / center / right / top) | Decimals | slider | 0–2 | 1 | live | has | sArena Reloaded |  |
| Text tags (left / center / right / top) | Hide when full health | toggle |  | Off | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Name max length | slider | 0–30 chars | 16 | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name colour | dropdown | Class / Reaction / White / Custom | White | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name size | slider | 6–40 | 13 | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name shadow | toggle |  | Off | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name anchor | dropdown | 9 points | Left | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name X offset | slider | -200–200 | 0 | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Name Y offset | slider | -200–200 | 0 | live | has | EllesmereUI ForeverEssentials |  |
| Text tags (left / center / right / top) | Health text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Health text size | slider | 6–40 | 12 | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Health text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Health text shadow | toggle |  | Off | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Health text colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Health text anchor | dropdown | 9 points | Right | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Health text X offset | slider | -200–200 | 0 | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Health text Y offset | slider | -200–200 | 0 | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Power text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Power text size | slider | 6–40 | 10 | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Power text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Power text shadow | toggle |  | Off | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Power text colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Power text anchor | dropdown | 9 points | Center | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Power text X offset | slider | -200–200 | 0 | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Power text Y offset | slider | -200–200 | 0 | live | has | EllesmereUI ResourceBars |  |
| Text tags (left / center / right / top) | Level text (difficulty colour) | toggle |  | On (target) | live | part | sArena Reloaded | S18 |
| Portrait | Portrait | dropdown | Off / 3D model / 2D / Class icon | Off | hover | has | EllesmereUI UnitFrames |  |
| Portrait | Portrait position | dropdown | Left / Right / Inside bar (overlay) | Left | live | has | EllesmereUI UnitFrames |  |
| Portrait | Portrait size | slider | -50–100 % of height | 100 | live | has | EllesmereUI UnitFrames |  |
| Portrait | Portrait shape | dropdown | Square / Round | Square | hover | has | EllesmereUI UnitFrames |  |
| Portrait | 3D camera zoom | slider | 100–300 % | 100 | live | has | EllesmereUI UnitFrames |  |
| Portrait | Overlay opacity | slider | 0–100 % | 35 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Buffs | dropdown | Off / Above / Below / Left / Right | Above (target) | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Debuffs | dropdown | Off / Above / Below / Left / Right | Above (target) | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Icon size | slider | 10–70 px | 22 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Per row | slider | 1–20 | 8 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Max icons | slider | 1–40 | 16 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Spacing | slider | -1–10 px | 2 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Growth | dropdown | Right-Up / Right-Down / Left-Up / Left-Down | Right-Up | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Filter | dropdown | All / Mine only / Dispellable / Important (Blizzard flag) / Blizzard default | Blizzard default | none | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Dispel-type border colours | toggle |  | On | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Desaturate others' debuffs | toggle |  | On | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Icon zoom | slider | 0–20 % | 8 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura duration font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura duration size | slider | 6–40 | 10 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura duration outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura duration shadow | toggle |  | Off | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura duration colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks size | slider | 6–40 | 11 | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks shadow | toggle |  | Off | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Aura stacks colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI UnitFrames |  |
| Auras on frames (buffs / debuffs, per unit) | Cooldown swipe | toggle |  | On | live | has | EllesmereUI UnitFrames |  |
| Cast bar on frame (see Cast Bars for the full set) | Attach cast bar | dropdown | Off / Below / Above / Inside / Detached | Below (target, focus, boss) | world | has | EllesmereUI UnitFrames |  |
| Cast bar on frame (see Cast Bars for the full set) | Cast bar height | slider | 6–40 px | 16 | live | has | EllesmereUI UnitFrames |  |
| Indicators | Raid marker | toggle |  | On | live | has | EllesmereUI UnitFrames |  |
| Indicators | Raid marker size / position | slider | 12–48 px + anchor | 18, top | live | has | EllesmereUI UnitFrames |  |
| Indicators | Leader / assist icon | toggle |  | On | live | has | EllesmereUI UnitFrames |  |
| Indicators | Role icon | dropdown | Off / Phoenix / Blizzard | Phoenix | hover | has | EllesmereUI UnitFrames |  |
| Indicators | Combat indicator | dropdown | Off / Icon / Glow | Icon | hover | has | EllesmereUI UnitFrames |  |
| Indicators | Resting indicator | toggle |  | On | live | has | EllesmereUI UnitFrames |  |
| Indicators | PvP / prestige icon | toggle |  | Off | live | has | EllesmereUI UnitFrames |  |
| Indicators | Elite / rare dragon | dropdown | Off / Phoenix / Blizzard | Phoenix | hover | has | EllesmereUI UnitFrames |  |
| Indicators | Threat border on target | toggle |  | On | live | has | sArena Reloaded |  |
| Indicators | Threat % text | toggle |  | Off | live | part | EllesmereUI UnitFrames | S18 |
| Indicators | Ready check / summon / resurrect | toggle |  | On | live | part | EllesmereUI UnitFrames | S18 |
| Boss and arena frames | Boss frames (1–5) | toggle |  | On | world | has | MoveAny |  |
| Boss and arena frames | Arena frames (1–5) | toggle |  | On | world | has | MoveAny |  |
| Boss and arena frames | Spacing / growth | slider | 0–60 px + Up/Down | 28, Down | world | has | sArena Reloaded |  |
| Boss and arena frames | Arena: trinket / racial / DR tracker | toggle |  | On | world | part | sArena Reloaded | S18 |
| Boss and arena frames | Arena: spec icon | toggle |  | On | world | has | sArena Reloaded |  |
| Boss and arena frames | Test frames | button | show sample boss/arena frames |  | world | has | sArena Reloaded |  |
| Parity: EllesmereUI ForeverEssentials | Icon for the active stance / form / aspect | — |  |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: EllesmereUI ResourceBars | Detached resource bars: texture, backgrounds, strata, borders | — | Phoenix has no detached player resource bars |  | live | new | EllesmereUI ResourceBars | S18 |
| Parity: EllesmereUI ResourceBars | Shift / expand bars when a resource is missing, mana bar while shapeshifted | — |  |  | live | part | EllesmereUI ResourceBars | S18 |
| Parity: EllesmereUI ResourceBars | Spec bars: Ironfur, Ignore Pain, Sweeping Strikes | — |  |  | live | new | EllesmereUI ResourceBars | S18 |
| Parity: EllesmereUI ResourceBars | Class resource bar: orientation, separators, pip borders, charged colour, thresholds, text | — | Pips, borders, charged points exist; thresholds, separators and orientation do not |  | live | part | EllesmereUI ResourceBars | S18 |
| Parity: EllesmereUI ResourceBars | Detached player health and power bars (personal resource display) | — |  |  | live | new | EllesmereUI ResourceBars | S18 |
| Parity: EllesmereUI ResourceBars | Totem bar | — | GetTotemInfo is readable; destroying needs a secure button |  | live | new | EllesmereUI ResourceBars | S18 |
| Parity: EllesmereUI UnitFrames | Frame look: nicknames, fade, dark mode, borders, detached bars, threat % | — | Threat % on target and detached power / text bars are missing |  | live | part | EllesmereUI UnitFrames | S18 |
| Parity: EllesmereUI UnitFrames | Portraits: 2D / 3D / class, shape, rings, dragon art | — | 2D / class portraits exist; 3D model, rings and dragon art do not; size is an open gap row |  | live | part | EllesmereUI UnitFrames | S18 |
| Parity: EllesmereUI UnitFrames | Separate text bar strip under the frame | — |  |  | live | new | EllesmereUI UnitFrames | S18 |
| Parity: EllesmereUI UnitFrames | Power bar: position, gradient, text, cost prediction, regen spark | — | S17: cost prediction; regen spark still open |  | live | part | EllesmereUI UnitFrames | S18 |
| Parity: EllesmereUI WindTools | Click to destroy totems | — | Secure button (DestroyTotem is protected) |  | live | new | EllesmereUI WindTools | S18 |
| Parity: EllesmereUI WindTools | Modifier-click to set focus (with marker) | — | Secure attribute on frames, out of combat |  | live | new | EllesmereUI WindTools | S18 |
| Parity: sArena Reloaded | Arena frame layouts (9 presets: mirrored, sizes, power height, crop) | — | Phoenix arena frames have one layout |  | live | new | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Arena cast bars: modern look, shield, spark, colours, highlight casts on me / CC | — | Arena frames reuse Phoenix cast bars; highlight-on-me / CC colours do not exist |  | live | part | sArena Reloaded | S18 |
| Parity: sArena Reloaded | DR tracker look (borders, text, size) | — |  |  | live | new | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Diminishing returns tracking (per class / spec, reset time, 12.x DR handling) | — | 12.x sends DR state in UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED (secret payloads) and C_SpellDiminish; Phoenix can show it through display sinks or restyle Blizzard's own DR tray, never from the combat log |  | live | new | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Arena widgets: combat / healer / target / focus indicators, party ↔ arena targets | — |  |  | live | new | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Arena fonts and text placement | — |  |  | live | part | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Click actions on arena frames (spell / macro per button, Clique) | — | Secure attributes set out of combat |  | live | new | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Auras on the class icon (CC / defensive / important) and aura highlight | — | Arena unit auras are readable through C_UnitAuras with AuraUtil filters; some are secret in combat (display sinks) |  | live | new | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Arena pet frames | — |  |  | live | new | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Enemy dispel cooldown tracking | — | Enemy dispels are only visible in the combat log, which Phoenix never reads on 12.x, and spell IDs from arena units' cast events are secret in arenas |  | — | api | sArena Reloaded |  |
| Parity: sArena Reloaded | Range check on arena frames | — |  |  | live | part | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Arena frame options: layout test, colours, numbers, swipes, Masque, stealth alpha | — | Test frames, class colours and swipe exist; most per-element switches do not |  | live | part | sArena Reloaded | S18 |
| Parity: sArena Reloaded | Arena frame general (class icon, spec text, manabars, growth, scale, sizes) | — |  |  | live | part | sArena Reloaded | S18 |
| Parity: BigWigs | Alternate (encounter) power display | — | Encounter power bar on the player frame exists; the group list does not |  | live | part | BigWigs | S21 |
| Parity: MoveAny | Move class power bars | — | Class resource sits on the player frame; a detached class bar is S18 |  | live | part | MoveAny | S18 |

## Group Frames  (`GroupFrames`)

*Now 194 (Forever 193) → target 77* · has 66 · part 5 · new 6 · link/api 1

**How:** Own secure party and raid headers (SecureGroupHeaderTemplate), Blizzard compact frames as fallback

**References:** EUI RaidFrames 247 controls (Frames, VisualBars, VisualIndicators, aura managers) · Blizzard compact raid frame options

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Layout (party / raid 10–20 / raid 21–40 profiles) | Use Phoenix group frames | toggle |  | On | world | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Frame width | slider | 40–300 px | 92 | live | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Frame height | slider | 20–150 px | 48 | live | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Frame spacing | slider | -5–15 px | 2 | live | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Group spacing | slider | -5–30 px | 8 | live | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Unit growth | dropdown | Down / Up / Right / Left | Down | live | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Group growth | dropdown | Right / Left / Down / Up | Right | live | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Sort by | dropdown | Group / Role / Class / Name / Index | Role | none | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Role order | reorder | Tank, Healer, Damage | T-H-D | none | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Self position | dropdown | Normal / First / Last / Hidden | First | none | part | EllesmereUI RaidFrames | S19 |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Show when solo | toggle |  | Off | world | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Show pets | toggle |  | Off | world | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Main tank / assist group | toggle |  | Off | world | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Hide groups 5–8 in Mythic raid | toggle |  | On | none | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Anchor | dropdown | 9 points + frame picker | per element | world | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | X offset | slider | -2000–2000 | per element | world | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Y offset | slider | -1200–1200 | per element | world | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | has | EllesmereUI RaidFrames |  |
| Layout (party / raid 10–20 / raid 21–40 profiles) | Scale | slider | 50–200 % | 100 | world | has | EllesmereUI RaidFrames |  |
| Health and power | Health texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI RaidFrames |  |
| Health and power | Health fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | has | EllesmereUI RaidFrames |  |
| Health and power | Health smooth fill | toggle |  | On | live | has | EllesmereUI RaidFrames |  |
| Health and power | Health gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI RaidFrames |  |
| Health and power | Colour mode | dropdown | Class / Fixed / Gradient | Class | hover | has | EllesmereUI RaidFrames |  |
| Health and power | Background opacity | slider | 0–100 % | 60 | live | has | EllesmereUI RaidFrames |  |
| Health and power | Absorb / heal absorb / heal prediction | dropdown | per type: Off / Overlay / Striped | Striped / Overlay / On | hover | has | EllesmereUI RaidFrames |  |
| Health and power | Power bar for | dropdown | None / Healers / All | Healers | live | has | EllesmereUI RaidFrames |  |
| Health and power | Power bar height | slider | 1–20 px | 4 | live | has | EllesmereUI RaidFrames |  |
| Health and power | Frame border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI RaidFrames |  |
| Health and power | Frame border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI RaidFrames |  |
| Health and power | Frame border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI RaidFrames |  |
| Health and power | Frame border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI RaidFrames |  |
| Health and power | Frame border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI RaidFrames |  |
| Text | Name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI (core pages) |  |
| Text | Name size | slider | 6–40 | 12 | live | has | EllesmereUI (core pages) |  |
| Text | Name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI (core pages) |  |
| Text | Name shadow | toggle |  | Off | live | has | EllesmereUI (core pages) |  |
| Text | Name colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI (core pages) |  |
| Text | Name max length | slider | 0–30 | 10 | live | has | EllesmereUI (core pages) |  |
| Text | Name colour | dropdown | Class / White / Custom | Class | live | has | EllesmereUI (core pages) |  |
| Text | Name anchor | dropdown | 9 points | Center | live | has | EllesmereUI (core pages) |  |
| Text | Name X offset | slider | -200–200 | 0 | live | has | EllesmereUI (core pages) |  |
| Text | Name Y offset | slider | -200–200 | 0 | live | has | EllesmereUI (core pages) |  |
| Text | Status text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI RaidFrames |  |
| Text | Status text size | slider | 6–40 | 10 | live | has | EllesmereUI RaidFrames |  |
| Text | Status text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI RaidFrames |  |
| Text | Status text shadow | toggle |  | Off | live | has | EllesmereUI RaidFrames |  |
| Text | Status text colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI RaidFrames |  |
| Text | Health text | dropdown | Off / Percent / Deficit / Current | Off | hover | has | EllesmereUI RaidFrames |  |
| Indicators | Role icon (hide in combat option) | dropdown | Off / Phoenix / Blizzard | Phoenix | hover | has | EllesmereUI RaidFrames |  |
| Indicators | Leader icon | toggle |  | On | live | has | EllesmereUI RaidFrames |  |
| Indicators | Raid marker | toggle |  | On | live | has | EllesmereUI RaidFrames |  |
| Indicators | Ready check / summon / resurrection | toggle |  | On | live | has | EllesmereUI RaidFrames |  |
| Indicators | Dispel highlight | dropdown | Off / Border / Overlay / Gradient | Overlay | hover | has | EllesmereUI RaidFrames |  |
| Indicators | Only dispellable by me | toggle |  | On | live | has | EllesmereUI RaidFrames |  |
| Indicators | Dispel colours | colour | per type | Blizzard | live | has | EllesmereUI RaidFrames |  |
| Indicators | Aggro / threat border | slider | 0–4 px | 2 | live | has | EllesmereUI RaidFrames |  |
| Indicators | Out-of-range opacity | slider | 10–100 % | 40 | live | has | EllesmereUI RaidFrames |  |
| Indicators | Missing raid buff icon | toggle |  | Off | live | link | EllesmereUI RaidFrames |  |
| Indicators | Private aura anchor | toggle |  | On | live | has | EllesmereUI (core pages) |  |
| Auras | Buffs (mine, HoTs) | dropdown | Off / Corners / Row | Corners | live | has | EllesmereUI RaidFrames |  |
| Auras | Debuffs | dropdown | Off / Row / Center | Row | live | has | EllesmereUI RaidFrames |  |
| Auras | Buff size | slider | 8–40 px | 14 | live | has | EllesmereUI RaidFrames |  |
| Auras | Debuff size | slider | 8–40 px | 18 | live | has | EllesmereUI RaidFrames |  |
| Auras | Max debuffs | slider | 1–10 | 3 | live | has | EllesmereUI RaidFrames |  |
| Auras | Big defensive / external icon | toggle |  | On | live | has | EllesmereUI RaidFrames |  |
| Auras | Aura filter | dropdown | Blizzard default / Raid / Mine | Blizzard default | none | has | EllesmereUI RaidFrames |  |
| Auras | Test raid (5 / 20 / 40) | button |  |  | world | has | EllesmereUI RaidFrames |  |
| Parity: EllesmereUI (core pages) | Top name bar / anchor to cursor row add-ons | — |  |  | live | new | EllesmereUI (core pages) | S19 |
| Parity: EllesmereUI RaidFrames | Absorbs: overshield, glow line, absorb bar, heal absorb, max-health reduction | — | Shields and heal absorbs exist; max-health reduction style and overshield glow do not |  | live | part | EllesmereUI RaidFrames | S19 |
| Parity: EllesmereUI RaidFrames | Indicators: missing buffs, role, marker, ready check / summon / rez, status, leader, combat, group numbers, ping | — | Role, marker, leader, ready check exist; missing-buff, summon / rez, group numbers and ping markers do not |  | live | part | EllesmereUI RaidFrames | S19 |
| Parity: EllesmereUI RaidFrames | Top name bar strip | — |  |  | live | new | EllesmereUI RaidFrames | S19 |
| Parity: EllesmereUI RaidFrames | Friendly boss frames group | — |  |  | live | new | EllesmereUI RaidFrames | S19 |
| Parity: EllesmereUI RaidFrames | Range alpha, tooltips, healer mana display, names in raid, status colours, strata | — | Healer mana display is missing |  | live | part | EllesmereUI RaidFrames | S19 |
| Parity: EllesmereUI RaidFrames | Portraits on group frames | — |  |  | live | new | EllesmereUI RaidFrames | S19 |
| Parity: EllesmereUI RaidFrames | Party target frames | — |  |  | live | new | EllesmereUI RaidFrames | S19 |
| Parity: EllesmereUI RaidFrames | Assigned buff / debuff lists with custom order and placement | — |  |  | live | new | EllesmereUI RaidFrames | S19 |
| Parity: EllesmereUI RaidFrames | Buff manager: own-only, pandemic border, threshold text, dashes | — | Buff icons exist; pandemic border and threshold text do not |  | live | part | EllesmereUI RaidFrames | S19 |

## Nameplates  (`NamePlates`)

*Now 276 (Forever 270) → target 103* · has 98 · part 5 · new 0 · link/api 1

**How:** Restyles Blizzard's nameplates (they stay Blizzard's secure frames)

**References:** EUI Nameplates 176 controls (General, DisplayLayout, DisplayBars, Colors, TextColoring) · WindTools friendly outline

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Size and stacking | Enemy width | slider | 80–250 px | 140 | live | has | EllesmereUI Nameplates |  |
| Size and stacking | Enemy height | slider | 6–40 px | 12 | live | has | EllesmereUI Nameplates |  |
| Size and stacking | Friendly width / height | slider | 60–250 / 4–30 px | 110 / 8 | live | has | EllesmereUI Nameplates |  |
| Size and stacking | Friendly: name only | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Size and stacking | Stacking | dropdown | Overlap / Stacked | Stacked | none | has | EllesmereUI Nameplates |  |
| Size and stacking | Vertical spacing (stacked) | slider | 50–200 % | 100 | none | has | EllesmereUI Nameplates |  |
| Size and stacking | Clickable area width / height | slider | 50–250 % | 100 | none | has | EllesmereUI Nameplates |  |
| Size and stacking | Target scale | slider | 50–200 % | 115 | live | has | EllesmereUI Nameplates |  |
| Size and stacking | Non-target opacity | slider | 0–100 % | 70 | live | has | EllesmereUI Nameplates |  |
| Size and stacking | Max distance (CVar) | slider | 20–60 yd | 41 | none | has | EllesmereUI Nameplates |  |
| Size and stacking | Show enemy pets / totems / minions | toggle | per type | Off / On / Off | none | has | EllesmereUI Nameplates |  |
| Health bar | Health texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI Nameplates |  |
| Health bar | Health fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | has | EllesmereUI Nameplates |  |
| Health bar | Health smooth fill | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Health bar | Health gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI Nameplates |  |
| Health bar | Class colour enemy players | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Health bar | Reaction colours (hostile / neutral / friendly / tapped) | colour | 4 colours | Blizzard | live | has | EllesmereUI Nameplates |  |
| Health bar | Threat colours (tank / DPS: secure, losing, lost) | colour | 6 colours | green / orange / red | live | has | EllesmereUI Nameplates |  |
| Health bar | Colour your target | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Health bar | Colour your focus | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Health bar | Quest mob colour | colour |  | #E6C84D | live | has | EllesmereUI Nameplates |  |
| Health bar | Execute range colour + threshold | slider | 0–50 % | Off | live | has | EllesmereUI Nameplates |  |
| Health bar | Health background | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Health bar | Health background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI Nameplates | S28 |
| Health bar | Health background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI Nameplates |  |
| Health bar | Health background opacity | slider | 0–100 % | 70 | live | has | EllesmereUI Nameplates |  |
| Health bar | Plate border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI Nameplates |  |
| Health bar | Plate border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI Nameplates |  |
| Health bar | Plate border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI Nameplates |  |
| Health bar | Plate border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI Nameplates |  |
| Health bar | Plate border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI Nameplates |  |
| Health bar | Absorb on plates | dropdown | Off / Overlay / Striped | Striped | hover | has | EllesmereUI Nameplates |  |
| Target, focus and hover | Target effect | dropdown | None / Border / Glow / Arrows / Underline | Border | hover | has | EllesmereUI Nameplates |  |
| Target, focus and hover | Target effect colour | colour |  | accent | live | has | EllesmereUI Nameplates |  |
| Target, focus and hover | Focus marker | dropdown | None / Letter F / Border / Texture | Border | hover | has | EllesmereUI Nameplates |  |
| Target, focus and hover | Hover highlight | dropdown | None / Lighten / Border | Lighten | hover | has | EllesmereUI Nameplates |  |
| Cast bar | Phoenix cast bar | toggle |  | On | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Cast bar height | slider | 6–40 px | 10 | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Cast texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI CooldownManager |  |
| Cast bar | Cast fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Cast smooth fill | toggle |  | On | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Cast gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Interruptible / not / important colours | colour | 3 colours | gold / grey / red | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Kick-ready hint (my interrupt off cooldown) | dropdown | Off / Tint / Tick | Tint | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Spell icon | dropdown | Left / Right / Off | Left | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Shield icon (not interruptible) | toggle |  | On | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Spell name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI CooldownManager |  |
| Cast bar | Spell name size | slider | 6–40 | 10 | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Spell name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Spell name shadow | toggle |  | Off | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Spell name colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Spell target name | toggle |  | On | live | has | EllesmereUI CooldownManager |  |
| Cast bar | Cast timer | dropdown | Off / Remaining / Remaining/Total | Remaining | live | has | EllesmereUI CooldownManager |  |
| Text | Restyle names | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Text | Name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Nameplates |  |
| Text | Name size | slider | 6–40 | 11 | live | has | EllesmereUI Nameplates |  |
| Text | Name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Nameplates |  |
| Text | Name shadow | toggle |  | Off | live | has | EllesmereUI Nameplates |  |
| Text | Name colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Nameplates |  |
| Text | Name position | dropdown | Above / Inside / Below | Above | live | has | EllesmereUI Nameplates |  |
| Text | Health percent | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Text | Health text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Nameplates |  |
| Text | Health text size | slider | 6–40 | 10 | live | has | EllesmereUI Nameplates |  |
| Text | Health text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Nameplates |  |
| Text | Health text shadow | toggle |  | Off | live | has | EllesmereUI Nameplates |  |
| Text | Health text colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Nameplates |  |
| Text | Health text anchor | dropdown | 9 points | Right | live | has | EllesmereUI Nameplates |  |
| Text | Health text X offset | slider | -200–200 | 0 | live | has | EllesmereUI Nameplates |  |
| Text | Health text Y offset | slider | -200–200 | 0 | live | has | EllesmereUI Nameplates |  |
| Text | Level / classification badge | toggle |  | Off | live | has | EllesmereUI Nameplates |  |
| Text | NPC title / guild on friendly | toggle |  | Off | live | has | EllesmereUI Nameplates |  |
| Auras | Phoenix aura icons | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Auras | Debuffs row: mine / important / all | dropdown | Blizzard filter | Mine | none | has | EllesmereUI Nameplates |  |
| Auras | Enemy buffs (purgeable / important) | dropdown | Off / Purgeable / Blizzard | Purgeable | none | has | EllesmereUI Nameplates |  |
| Auras | Icon size / spacing / max | slider | 12–40 / 0–8 / 1–10 | 22 / 2 / 5 | live | has | EllesmereUI Nameplates |  |
| Auras | Icon zoom | slider | 0–20 % | 8 | live | has | EllesmereUI Nameplates |  |
| Auras | Aura border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI Nameplates |  |
| Auras | Aura border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI Nameplates |  |
| Auras | Aura border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI Nameplates |  |
| Auras | Aura stacks font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Nameplates |  |
| Auras | Aura stacks size | slider | 6–40 | 10 | live | has | EllesmereUI Nameplates |  |
| Auras | Aura stacks outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Nameplates |  |
| Auras | Aura stacks shadow | toggle |  | Off | live | has | EllesmereUI Nameplates |  |
| Auras | Aura stacks colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Nameplates |  |
| Auras | Aura timer font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Nameplates |  |
| Auras | Aura timer size | slider | 6–40 | 10 | live | has | EllesmereUI Nameplates |  |
| Auras | Aura timer outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Nameplates |  |
| Auras | Aura timer shadow | toggle |  | Off | live | has | EllesmereUI Nameplates |  |
| Auras | Aura timer colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Enemy forces % on plates | toggle |  | On | live | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Enemy forces font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Enemy forces size | slider | 6–40 | 10 | live | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Enemy forces outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Enemy forces shadow | toggle |  | Off | live | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Enemy forces colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Class power on target plate | toggle |  | Off | live | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Raid marker size / position | slider | 12–40 + anchor | 20, left | live | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Quest objective icon | toggle |  | On | live | has | Questie |  |
| Mythic+ and extras | Hide enemy plates out of combat | toggle |  | Off | none | has | EllesmereUI Nameplates |  |
| Mythic+ and extras | Preview eye toggles (marker, quest, target, absorb) | button |  |  | live | part | Questie | S28 |
| Parity: EllesmereUI CooldownManager | Focus interrupt reminder: text near the focus plate, focus cast sound, interrupt spell | — | Focus marker exists; the focus cast sound and reminder text do not |  | live | part | EllesmereUI CooldownManager | S20 |
| Parity: EllesmereUI Nameplates | Colour plates by your debuffs; caster / mini-boss / boss colours; threat tweaks | — | Threat colours exist; debuff-based colouring and caster / mini-boss colours (need NPC classification data) do not |  | live | part | EllesmereUI Nameplates | S28 |
| Parity: EllesmereUI Nameplates | Fade plates out of line of sight | — | No line-of-sight API for units; addons cannot test LoS in 12.x |  | — | api | EllesmereUI Nameplates |  |
| Parity: EllesmereUI Nameplates | Hash line at %, target scale, non-target opacity, focus letter, range text, scale on cast | — | Target scale, opacity and execute mark exist; range text, scale on cast and focus letter do not |  | live | part | EllesmereUI Nameplates | S28 |

## Cast Bars  (`CastBars`)

*Now 103 (Forever 113) → target 59* · has 53 · part 5 · new 1 · link/api 0

**How:** Own cast bars for player, target, focus, pet, boss (UnitCastingInfo is secret only where restricted; text through display sinks)

**References:** EUI ResourceBars CastBarPage 41 + UnitFrames cast section 32 + MythicTimer targeted spell bars 21

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Layout (per bar: player, target, focus, pet, boss) | Enable bar | toggle |  | On | world | has | EllesmereUI ResourceBars |  |
| Layout (per bar: player, target, focus, pet, boss) | Width | slider | 50–800 px | 260 | live | has | EllesmereUI ResourceBars |  |
| Layout (per bar: player, target, focus, pet, boss) | Height | slider | 6–60 px | 22 | live | has | EllesmereUI ResourceBars |  |
| Layout (per bar: player, target, focus, pet, boss) | Anchor | dropdown | 9 points + frame picker | per element | world | has | EllesmereUI ResourceBars |  |
| Layout (per bar: player, target, focus, pet, boss) | X offset | slider | -2000–2000 | per element | world | has | EllesmereUI ResourceBars |  |
| Layout (per bar: player, target, focus, pet, boss) | Y offset | slider | -1200–1200 | per element | world | has | EllesmereUI ResourceBars |  |
| Layout (per bar: player, target, focus, pet, boss) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | has | EllesmereUI ResourceBars |  |
| Layout (per bar: player, target, focus, pet, boss) | Scale | slider | 50–200 % | 100 | world | has | EllesmereUI ResourceBars |  |
| Layout (per bar: player, target, focus, pet, boss) | Attach to unit frame | toggle |  | On (target, focus) | world | has | EllesmereUI ResourceBars |  |
| Look | Cast texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI MythicTimer |  |
| Look | Cast fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | has | EllesmereUI MythicTimer |  |
| Look | Cast smooth fill | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Look | Cast gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI ResourceBars |  |
| Look | Class colour (player) | toggle |  | Off | live | has | EllesmereUI ResourceBars |  |
| Look | Colours: cast / channel / uninterruptible / interrupted / success | colour | 5 colours | theme | live | has | EllesmereUI MythicTimer |  |
| Look | Background | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Look | Background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI ResourceBars | S28 |
| Look | Background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI ResourceBars |  |
| Look | Background opacity | slider | 0–100 % | 70 | live | has | EllesmereUI ResourceBars |  |
| Look | Border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI ResourceBars |  |
| Look | Border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI ResourceBars |  |
| Look | Border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI ResourceBars |  |
| Look | Border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI ResourceBars |  |
| Look | Border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI ResourceBars |  |
| Look | Spark | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Look | Spell icon | dropdown | Left / Right / Off | Left | live | has | EllesmereUI MythicTimer |  |
| Look | Icon zoom | slider | 0–20 % | 8 | live | has | EllesmereUI ResourceBars |  |
| Look | Icon detached size | slider | 0–60 px | 0 (= height) | live | has | EllesmereUI ResourceBars |  |
| Text | Spell name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI MythicTimer |  |
| Text | Spell name size | slider | 6–40 | 12 | live | has | EllesmereUI MythicTimer |  |
| Text | Spell name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI MythicTimer |  |
| Text | Spell name shadow | toggle |  | Off | live | has | EllesmereUI MythicTimer |  |
| Text | Spell name colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI MythicTimer |  |
| Text | Spell name anchor | dropdown | 9 points | Left | live | has | EllesmereUI MythicTimer |  |
| Text | Spell name X offset | slider | -200–200 | 0 | live | has | EllesmereUI MythicTimer |  |
| Text | Spell name Y offset | slider | -200–200 | 0 | live | has | EllesmereUI MythicTimer |  |
| Text | Cast time font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI MythicTimer |  |
| Text | Cast time size | slider | 6–40 | 11 | live | has | EllesmereUI MythicTimer |  |
| Text | Cast time outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI MythicTimer |  |
| Text | Cast time shadow | toggle |  | Off | live | has | EllesmereUI MythicTimer |  |
| Text | Cast time colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI MythicTimer |  |
| Text | Time format | dropdown | Remaining / Remaining/Total / Elapsed | Remaining | live | has | EllesmereUI ResourceBars |  |
| Text | Decimals | slider | 0–2 | 1 | live | has | EllesmereUI ResourceBars |  |
| Text | Spell target name | toggle |  | On (target, focus) | live | has | EllesmereUI MythicTimer |  |
| Player extras | Latency overlay | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Player extras | Latency colour | colour |  | #FF4040 60% | live | has | EllesmereUI ResourceBars |  |
| Player extras | Channel ticks | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Player extras | Empowered stages coloured | toggle |  | On | live | has | EllesmereUI ResourceBars |  |
| Player extras | GCD bar | toggle |  | Off | world | has | EllesmereUI MythicTimer |  |
| Player extras | Swing timer (Forever: C_SwingTimer) | toggle |  | Off | world | has | EllesmereUI ResourceBars |  |
| Player extras | Hide Blizzard player cast bar | toggle |  | On | none | part | EllesmereUI MythicTimer | S28 |
| Interrupt helpers | Kick-ready tick (my interrupt off cooldown) | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Interrupt helpers | Interrupted flash | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Interrupt helpers | Targeted spell bars (casts on me) | toggle |  | Off | world | has | EllesmereUI MythicTimer |  |
| Interrupt helpers | Test casts | button |  |  | world | has | EllesmereUI MythicTimer |  |
| Parity: EllesmereUI MythicTimer | Bars for enemy casts aimed at you / your group | — | UnitSpellTargetName / Class return secrets, so the target name can be shown but Phoenix cannot filter 'aimed at me' by comparing it; S28 checks in game what UnitIsUnit allows (secret when unit comparison is restricted) and may close this as impossible |  | live | new | EllesmereUI MythicTimer | S28 |
| Parity: EllesmereUI MythicTimer | Focus / enemy cast bar extras: kick-ready hint, raid marker, interrupt range fade | — |  |  | live | part | EllesmereUI MythicTimer | S28 |
| Parity: EllesmereUI ResourceBars | GCD bar | — | GCD bar under the cast bar exists; standalone bar options do not |  | live | part | EllesmereUI ResourceBars | S18 |
| Parity: EllesmereUI ResourceBars | Swing timer | — | Swing timer exists where the client allows (feature swingTimer); weapon labels and range cues do not |  | live | part | EllesmereUI ResourceBars | S18 |

## Buffs & Debuffs  (`Auras`)

*Now 64 (Forever 64) → target 42* · has 41 · part 0 · new 1 · link/api 0

**How:** Restyles Blizzard's player buff and debuff frames (BuffFrame/DebuffFrame); own aura bars optional

**References:** EUI PlayerAuraBars 43 + BlizzardSkin aura bits · ElvUI-style aura headers

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Layout (buffs / debuffs separately) | Icon size | slider | 16–64 px | 32 | live | has | EllesmereUI PlayerAuraBars |  |
| Layout (buffs / debuffs separately) | Icons per row | slider | 1–20 | 12 | live | has | EllesmereUI PlayerAuraBars |  |
| Layout (buffs / debuffs separately) | Max rows | slider | 1–10 | 3 | live | has | EllesmereUI PlayerAuraBars |  |
| Layout (buffs / debuffs separately) | Horizontal / vertical spacing | slider | -5–20 px | 4 / 12 | live | has | EllesmereUI PlayerAuraBars |  |
| Layout (buffs / debuffs separately) | Growth | dropdown | Left-Down / Right-Down / Left-Up / Right-Up | Left-Down | live | has | EllesmereUI PlayerAuraBars |  |
| Layout (buffs / debuffs separately) | Sort | dropdown | Time left / Name / Cast order | Time left | live | has | EllesmereUI PlayerAuraBars |  |
| Layout (buffs / debuffs separately) | Sort direction | dropdown | Ascending / Descending | Ascending | live | has | EllesmereUI PlayerAuraBars |  |
| Layout (buffs / debuffs separately) | Separate my own buffs | toggle |  | Off | live | has | EllesmereUI PlayerAuraBars |  |
| Look | Phoenix style | toggle |  | On | live | has | EllesmereUI PlayerAuraBars |  |
| Look | Icon shape | dropdown | Square / Rounded | Square | hover | has | EllesmereUI PlayerAuraBars |  |
| Look | Icon zoom | slider | 0–20 % | 8 | live | has | EllesmereUI PlayerAuraBars |  |
| Look | Border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI PlayerAuraBars |  |
| Look | Border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI PlayerAuraBars |  |
| Look | Border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI PlayerAuraBars |  |
| Look | Border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI PlayerAuraBars |  |
| Look | Border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI PlayerAuraBars |  |
| Look | Debuff type border colours | toggle |  | On | live | has | EllesmereUI PlayerAuraBars |  |
| Look | Duration swipe | toggle |  | Off | live | has | EllesmereUI PlayerAuraBars |  |
| Look | Reverse swipe | toggle |  | Off | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration size | slider | 6–40 | 11 | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration shadow | toggle |  | Off | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration anchor | dropdown | 9 points | Bottom | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration X offset | slider | -200–200 | 0 | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration Y offset | slider | -200–200 | 0 | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Duration format | dropdown | Blizzard / 1m / 1:05 / seconds below N | 1m | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Precise below (minutes) | slider | 0–60 | 1 | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Colour by time left | toggle |  | On | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Stacks font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI PlayerAuraBars |  |
| Text | Stacks size | slider | 6–40 | 12 | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Stacks outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Stacks shadow | toggle |  | Off | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Stacks colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Stacks anchor | dropdown | 9 points | Bottom right | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Stacks X offset | slider | -200–200 | 0 | live | has | EllesmereUI PlayerAuraBars |  |
| Text | Stacks Y offset | slider | -200–200 | 0 | live | has | EllesmereUI PlayerAuraBars |  |
| Behaviour | Right-click to cancel (out of combat) | toggle |  | On | none | has | EllesmereUI PlayerAuraBars |  |
| Behaviour | Hide weapon enchants / consolidated | toggle |  | Off | live | has | EllesmereUI PlayerAuraBars |  |
| Behaviour | Private auras anchor size | slider | 16–64 px | 32 | world | has | EllesmereUI PlayerAuraBars |  |
| Parity: EllesmereUI PlayerAuraBars | Assigned aura lists (filters, extra spells) | — |  |  | live | new | EllesmereUI PlayerAuraBars | S19 |

## Combat Text  (`CombatText`)

*Now 30 (Forever 30) → target 26* · has 25 · part 1 · new 0 · link/api 0

**How:** Configures Blizzard floating combat text (CVars) + optional Phoenix scrolling areas

**References:** Blizzard FCT CVars · MSBT-like

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Blizzard combat text | Damage | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Periodic damage | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Pet damage | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Healing | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Self combat text | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Dodge, parry, miss | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Resistances | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Combat state | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Reactive abilities | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Low health / mana | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Auras | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Resource gains | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Honor | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Reputation | toggle |  | Blizzard | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Text scale | slider | 50–200 % | 100 | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Motion | dropdown | Up / Arc / Fountain | Up | none | has | EllesmereUI QoL |  |
| Blizzard combat text | Damage font (needs relog) | dropdown | fonts | Blizzard | hover | has | EllesmereUI QoL |  |
| Phoenix scroll areas (own events only, secret-safe) | Incoming / outgoing / notification areas | toggle | 3 toggles | Off | world | has | EllesmereUI QoL |  |
| Phoenix scroll areas (own events only, secret-safe) | Area position / size / direction | slider | + Up/Down/Arc | per area | world | part | EllesmereUI QoL | S24 |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI QoL |  |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text size | slider | 6–40 | 18 | live | has | EllesmereUI QoL |  |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI QoL |  |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text shadow | toggle |  | Off | live | has | EllesmereUI QoL |  |
| Phoenix scroll areas (own events only, secret-safe) | Scroll text colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI QoL |  |
| Phoenix scroll areas (own events only, secret-safe) | Merge rapid hits | toggle |  | On | none | has | EllesmereUI QoL |  |
| Phoenix scroll areas (own events only, secret-safe) | Crit style | dropdown | Bigger / Shake / Colour | Bigger | hover | has | EllesmereUI QoL |  |

## Damage Meter  (`DamageMeter`)

*Now 24 (Forever 24) → target 29* · has 22 · part 4 · new 3 · link/api 7

**How:** Restyles Blizzard's built-in damage meter (C_DamageMeter, 12.0)

**References:** EUI DamageMeters 82

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Window | Restyle damage meter | toggle |  | On | live | has | EllesmereUI DamageMeters |  |
| Window | Phoenix style | toggle |  | On | live | has | EllesmereUI DamageMeters |  |
| Window | Bar height / spacing | slider | 10–40 / 0–6 px | 18 / 1 | live | link | EllesmereUI DamageMeters |  |
| Window | Meter bar texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI DamageMeters |  |
| Window | Meter bar fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | part | EllesmereUI DamageMeters | S28 |
| Window | Meter bar smooth fill | toggle |  | On | live | api | EllesmereUI DamageMeters |  |
| Window | Meter bar gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI DamageMeters |  |
| Window | Class colours | toggle |  | On | live | link | EllesmereUI DamageMeters |  |
| Window | Window background | toggle |  | On | live | has | EllesmereUI DamageMeters |  |
| Window | Window background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI DamageMeters | S28 |
| Window | Window background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI DamageMeters |  |
| Window | Window background opacity | slider | 0–100 % | 70 | live | has | EllesmereUI DamageMeters |  |
| Window | Window border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI DamageMeters |  |
| Window | Window border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI DamageMeters |  |
| Window | Window border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI DamageMeters |  |
| Window | Window border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI DamageMeters |  |
| Window | Window border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI DamageMeters |  |
| Window | Name font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI DamageMeters |  |
| Window | Name size | slider | 6–40 | 12 | live | has | EllesmereUI DamageMeters |  |
| Window | Name outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI DamageMeters |  |
| Window | Name shadow | toggle |  | Off | live | has | EllesmereUI DamageMeters |  |
| Window | Name colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI DamageMeters |  |
| Window | Value font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI DamageMeters |  |
| Window | Value size | slider | 6–40 | 12 | live | has | EllesmereUI DamageMeters |  |
| Window | Value outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI DamageMeters |  |
| Window | Value shadow | toggle |  | Off | live | has | EllesmereUI DamageMeters |  |
| Window | Value colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI DamageMeters |  |
| Window | Value format | dropdown | Total (DPS) / DPS / Total / Percent | Total (DPS) | live | link | EllesmereUI DamageMeters |  |
| Window | Show rank numbers / spec icons | toggle | 2 toggles | On | live | link | EllesmereUI DamageMeters |  |
| Window | Auto-show in combat, hide after | slider | 0–60 s | Off | world | link | EllesmereUI DamageMeters |  |
| Window | Second window | toggle |  | Off | world | link | EllesmereUI DamageMeters |  |
| Parity: EllesmereUI DamageMeters | Meter window: refresh, header, always show player, reset button, spell tooltips | — | Refresh rate is the game's (C_DamageMeter); header and window styling partly exist |  | live | part | EllesmereUI DamageMeters | S28 |
| Parity: EllesmereUI DamageMeters | Meter bars and text: icons, borders, breakdown on hover, number format, rank numbers | — |  |  | live | part | EllesmereUI DamageMeters | S28 |
| Parity: EllesmereUI DamageMeters | Standalone combat timer | — |  |  | live | new | EllesmereUI DamageMeters | S28 |
| Parity: EllesmereUI ForeverEssentials | WoW Forever threat meter (bars, warning sound, threat % text) | — | UnitDetailedThreatSituation is plain on Forever |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: BigWigs | Combat timer with history | — | Same feature as the EUI standalone combat timer (one owner) |  | live | new | BigWigs | S28 |

## Spell History  (`SpellHistory`)

*Now 13 (Forever 13) → target 15* · has 12 · part 2 · new 1 · link/api 0

**How:** Row of recently cast spells

**References:** —

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Spell history | Icons | slider | 1–12 | 6 | live | has | EllesmereUI DamageMeters |  |
| Spell history | Icon size | slider | 16–64 | 32 | live | has | EllesmereUI DamageMeters |  |
| Spell history | Spacing | slider | 0–12 | 4 | live | has | EllesmereUI DamageMeters |  |
| Spell history | Direction | dropdown | Left / Right / Up / Down | Left | live | has | EllesmereUI DamageMeters |  |
| Spell history | Fade after (s) | slider | 1–30 | 8 | live | has | EllesmereUI DamageMeters |  |
| Spell history | Only in combat | toggle |  | On | world | has | EllesmereUI DamageMeters |  |
| Spell history | Icon border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI DamageMeters |  |
| Spell history | Icon border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI DamageMeters |  |
| Spell history | Icon border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI DamageMeters |  |
| Spell history | Icon border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI DamageMeters |  |
| Spell history | Icon border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI DamageMeters |  |
| Spell history | Mark interrupted / failed | toggle |  | On | live | has | EllesmereUI DamageMeters |  |
| Parity: EllesmereUI DamageMeters | Spell history as bars | — |  |  | live | new | EllesmereUI DamageMeters | S28 |
| Parity: TrufiGCD | Ability history for party, arena, target and focus (per-unit layout) | — | Other units' UNIT_SPELLCAST_SUCCEEDED spell IDs are secret in arenas and instances; possible in the open world only |  | live | part | TrufiGCD | S28 |
| Parity: TrufiGCD | Icon tooltips, stop scrolling on hover, spell ID print, blocklist, profiles, enable by zone type | — |  |  | live | part | TrufiGCD | S28 |

## Chat  (`Chat`)

*Now 61 (Forever 61) → target 52* · has 47 · part 4 · new 1 · link/api 2

**How:** Restyles Blizzard chat frames and adds tools; no chat replacement

**References:** EUI Chat 57 · WindTools Social (chat bar, emotes, links) 16 · Prat-like features

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Window | Chat background | toggle |  | On | live | has | EllesmereUI Chat |  |
| Window | Chat background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI Chat | S24 |
| Window | Chat background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI Chat |  |
| Window | Chat background opacity | slider | 0–100 % | 45 | live | has | EllesmereUI Chat |  |
| Window | Chat border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI Chat |  |
| Window | Chat border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI Chat |  |
| Window | Chat border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI Chat |  |
| Window | Chat border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI Chat |  |
| Window | Chat border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI Chat |  |
| Window | Width / height (main) | slider | 200–900 / 80–600 px | 440 / 180 | world | has | EllesmereUI Chat |  |
| Window | Fade lines after | slider | 0–600 s (0 = never) | 120 | none | has | EllesmereUI Chat |  |
| Window | Max lines kept | slider | 128–4096 | 1024 | none | has | EllesmereUI Chat |  |
| Window | Hide in combat | toggle |  | Off | world | has | EllesmereUI Chat |  |
| Window | Hide side buttons | toggle |  | On | live | has | EllesmereUI Chat |  |
| Window | Scroll to bottom button | toggle |  | On | live | has | EllesmereUI Chat |  |
| Tabs | Tab font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Chat |  |
| Tabs | Tab size | slider | 6–40 | 12 | live | has | EllesmereUI Chat |  |
| Tabs | Tab outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Chat |  |
| Tabs | Tab shadow | toggle |  | Off | live | has | EllesmereUI Chat |  |
| Tabs | Tab colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Chat |  |
| Tabs | Tab style | dropdown | Phoenix underline / Pill / Blizzard | Phoenix underline | hover | part | EllesmereUI Chat | S24 |
| Tabs | Selected tab colour | colour |  | accent | live | has | EllesmereUI Chat |  |
| Tabs | Flash new messages | toggle |  | On | live | has | EllesmereUI Chat |  |
| Tabs | Fade tabs when idle | toggle |  | On | live | has | EllesmereUI Chat |  |
| Messages | Chat font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Chat |  |
| Messages | Chat size | slider | 6–40 | 13 | live | has | EllesmereUI Chat |  |
| Messages | Chat outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Chat |  |
| Messages | Chat shadow | toggle |  | Off | live | has | EllesmereUI Chat |  |
| Messages | Chat colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Chat |  |
| Messages | Timestamps | dropdown | Off / HH:MM / HH:MM:SS / 12h | HH:MM | live | has | EllesmereUI Chat |  |
| Messages | Timestamp colour | colour |  | #808080 | live | has | EllesmereUI Chat |  |
| Messages | Short channel names ([G], [P], [1]) | toggle |  | On | live | has | EllesmereUI Chat |  |
| Messages | Class-coloured names | toggle |  | On | live | has | EllesmereUI Chat |  |
| Messages | Clickable URLs | toggle |  | On | live | has | EllesmereUI Chat |  |
| Messages | Copy chat (per-line and window) | toggle |  | On | none | has | EllesmereUI Chat |  |
| Messages | Item level in item links | toggle |  | On | live | has | EllesmereUI Chat |  |
| Messages | Icons in links (item, spell, achievement) | toggle |  | On | live | has | EllesmereUI Chat |  |
| Messages | Role icons before names | toggle |  | On | live | has | EllesmereUI Chat |  |
| Messages | Keyword highlight list | list | words | your name | live | has | EllesmereUI Chat |  |
| Messages | Keyword sound | dropdown | sound list | None | hover | has | EllesmereUI Chat |  |
| Messages | Spam throttle (repeat lines) | slider | 0–120 s | 0 | none | has | EllesmereUI Chat |  |
| Edit box | Edit box position | dropdown | Below / Above / Top of window | Below | live | has | EllesmereUI Chat |  |
| Edit box | Edit box style | dropdown | Phoenix / Blizzard | Phoenix | hover | has | EllesmereUI Chat |  |
| Edit box | Arrow keys without Alt | toggle |  | On | none | has | EllesmereUI Chat |  |
| Edit box | Remember last channel | toggle |  | On | none | api | EllesmereUI Chat |  |
| Edit box | History lines | slider | 10–200 | 50 | none | has | EllesmereUI Chat |  |
| Tools | Chat bar (channel buttons, roll, ready check) | toggle |  | Off | world | has | EllesmereUI Chat |  |
| Tools | Emote picker | toggle |  | Off | world | has | EllesmereUI WindTools |  |
| Tools | Whisper sound | dropdown | sound list | Phoenix chime | hover | has | EllesmereUI Chat |  |
| Tools | Whisper tab per person | toggle |  | Off | none | has | EllesmereUI Chat |  |
| Tools | Combat log tab hidden | toggle |  | Off | none | api | EllesmereUI Chat |  |
| Parity: EllesmereUI Chat | Chat sidebar with icon buttons (side, width, icons, free move) | — | Chat bar and side buttons exist; the sidebar layout does not |  | live | part | EllesmereUI Chat | S24 |
| Parity: EllesmereUI Chat | Tabs inside the panel, tab height / spacing / background / underline / texture | — | Tab font and colours exist; tabs-inside layout and tab textures do not |  | live | part | EllesmereUI Chat | S24 |
| Parity: EllesmereUI Chat | Restore the last chat lines after /reload | — |  |  | live | new | EllesmereUI Chat | S24 |

## Minimap  (`Minimap`)

*Now 49 (Forever 46) → target 43* · has 38 · part 1 · new 4 · link/api 2

**How:** Restyles Blizzard's minimap cluster

**References:** EUI Minimap 62 · WindTools Maps 29 (rectangle minimap, buttons bar, instance difficulty, world map reveal)

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Shape and size | Shape | dropdown | Round / Square / Rectangle | Square | hover | has | EllesmereUI Minimap |  |
| Shape and size | Size | slider | 120–400 px | 200 | live | has | EllesmereUI Minimap |  |
| Shape and size | Rectangle height (shape = rectangle) | slider | 50–100 % | 70 | live | has | EllesmereUI Minimap |  |
| Shape and size | Scale | slider | 50–200 % | 100 | world | link | EllesmereUI Minimap |  |
| Shape and size | Border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI Minimap |  |
| Shape and size | Border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI Minimap |  |
| Shape and size | Border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI Minimap |  |
| Shape and size | Border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI Minimap |  |
| Shape and size | Border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI Minimap |  |
| Shape and size | Mouse wheel zoom | toggle |  | On | none | has | EllesmereUI Minimap |  |
| Shape and size | Auto zoom out after | slider | 0–30 s | 5 | none | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Zone text | dropdown | Always / Mouseover / Hidden | Always | live | has | EllesmereUI ForeverEssentials |  |
| Elements (each: show, position, size) | Zone text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI ForeverEssentials |  |
| Elements (each: show, position, size) | Zone text size | slider | 6–40 | 12 | live | has | EllesmereUI ForeverEssentials |  |
| Elements (each: show, position, size) | Zone text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI ForeverEssentials |  |
| Elements (each: show, position, size) | Zone text shadow | toggle |  | Off | live | has | EllesmereUI ForeverEssentials |  |
| Elements (each: show, position, size) | Zone text colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI ForeverEssentials |  |
| Elements (each: show, position, size) | Zone text colour by PvP status | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Elements (each: show, position, size) | Clock | dropdown | Always / Mouseover / Hidden | Always | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Clock font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Clock size | slider | 6–40 | 11 | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Clock outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Clock shadow | toggle |  | Off | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Clock colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Coordinates | dropdown | Always / Mouseover / Hidden | Mouseover | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Coordinate decimals | slider | 0–2 | 1 | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Calendar / invites | dropdown | Icon / Hidden | Icon | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Tracking button | dropdown | Icon / Right-click menu | Right-click menu | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Mail icon | toggle |  | On | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Crafting order icon | toggle |  | On | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Instance difficulty badge | dropdown | Phoenix text / Blizzard / Hidden | Phoenix text | hover | has | EllesmereUI WindTools |  |
| Elements (each: show, position, size) | Expansion / housing button | dropdown | Icon / Hidden | Icon | live | has | EllesmereUI Minimap |  |
| Elements (each: show, position, size) | Group finder eye | toggle |  | On | live | api | EllesmereUI Minimap |  |
| Addon buttons | Collect addon buttons | dropdown | Off / Bar / Drawer / Mouseover ring | Drawer | hover | has | EllesmereUI Minimap |  |
| Addon buttons | Buttons per row | slider | 1–12 | 6 | live | has | EllesmereUI Minimap |  |
| Addon buttons | Button size | slider | 16–40 px | 24 | live | has | EllesmereUI Minimap |  |
| Addon buttons | Ignore list | list | button names |  | none | has | EllesmereUI Minimap |  |
| Map extras | Ping name display | toggle |  | On | none | has | EllesmereUI ForeverEssentials |  |
| Map extras | World map: reveal unexplored | toggle |  | Off | none | new | EllesmereUI WindTools | S25 |
| Map extras | World map: player / cursor coords | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Map extras | World map scale | slider | 50–150 % | 100 | none | has | EllesmereUI WindTools |  |
| Parity: EllesmereUI ForeverEssentials | World map: fade while moving, reveal unexplored, zone levels, map markers | — | Reveal needs WorldMapOverlay data from DB2 (generated, like quest data) |  | live | new | EllesmereUI ForeverEssentials | S25 |
| Parity: EllesmereUI ForeverEssentials | Flight timer bar and travel pins (from DB2 TaxiNodes / AreaPOI) | — | Flight times come from a build-time DB2 script, like EUI's own |  | live | new | EllesmereUI ForeverEssentials | S25 |
| Parity: EllesmereUI Minimap | Addon button bar, extra buttons, M+ portals, friends tooltip, middle-click micro menu | — | Button bin exists; M+ portal buttons, friends tooltip and middle-click menu do not |  | live | part | EllesmereUI Minimap | S25 |
| Parity: EllesmereUI WindTools | World event timer tracker | — | Needs event schedule data (DB2 / runtime C_AreaPoiInfo timers) |  | live | new | EllesmereUI WindTools | S25 |

## Tooltips  (`Tooltip`)

*Now 58 (Forever 55) → target 50* · has 42 · part 2 · new 6 · link/api 2

**How:** Restyles GameTooltip and adds lines; IDs where idTip-style (BSD-2)

**References:** EUI BlizzardSkin tooltip 23 · WindTools Tooltips 27 · idTip 27 ID kinds

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Look | Background | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Look | Background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI WindTools | S24 |
| Look | Background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI WindTools |  |
| Look | Background opacity | slider | 0–100 % | 92 | live | has | EllesmereUI WindTools |  |
| Look | Border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI WindTools |  |
| Look | Border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI WindTools |  |
| Look | Border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI WindTools |  |
| Look | Border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI WindTools |  |
| Look | Border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI WindTools |  |
| Look | Border by item quality | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Look | Border by class (players) | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Look | Header font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI WindTools |  |
| Look | Header size | slider | 6–40 | 14 | live | has | EllesmereUI WindTools |  |
| Look | Header outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI WindTools |  |
| Look | Header shadow | toggle |  | Off | live | has | EllesmereUI WindTools |  |
| Look | Header colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI WindTools |  |
| Look | Body font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI WindTools |  |
| Look | Body size | slider | 6–40 | 12 | live | has | EllesmereUI WindTools |  |
| Look | Body outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI WindTools |  |
| Look | Body shadow | toggle |  | Off | live | has | EllesmereUI WindTools |  |
| Look | Body colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI WindTools |  |
| Look | Health bar | dropdown | Off / Below / Above | Below | live | has | EllesmereUI BlizzardSkin |  |
| Look | Health bar height | slider | 2–12 px | 4 | live | has | EllesmereUI BlizzardSkin |  |
| Position | Anchor | dropdown | Default / Cursor / Cursor left / Cursor right / Fixed | Default | world | has | EllesmereUI BlizzardSkin |  |
| Position | Cursor offset X / Y | slider | -100–100 | 0 / 16 | world | has | EllesmereUI WindTools |  |
| Position | Scale | slider | 50–150 % | 100 | world | has | EllesmereUI WindTools |  |
| Position | Hide in combat | dropdown | Never / Units / All / Unless modifier held | Never | none | has | EllesmereUI WindTools |  |
| Unit info | Class-coloured names | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | Guild rank | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | Realm | dropdown | Full / Asterisk / Hidden | Asterisk | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | Target of unit | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | Targeted by (group) | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | Item level and spec (inspect) | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | Mythic+ score and best run | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | Raid progression line | toggle |  | Off | live | new | EllesmereUI WindTools | S24 |
| Unit info | Role icon | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | Mount the player is on | toggle |  | Off | live | has | EllesmereUI BlizzardSkin |  |
| Unit info | NPC: reaction-coloured, hide 'PvP' line | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| IDs and extras | Show IDs | dropdown | Off / With modifier / Always | With modifier | none | has | EllesmereUI WindTools |  |
| IDs and extras | ID kinds | list | Spell, Item, NPC, Quest, Achievement, Currency, Mount, Talent, Icon, Vignette, AreaPOI… | Spell, Item, NPC, Quest | none | has | EllesmereUI WindTools |  |
| IDs and extras | Item: count in bags / bank / warband | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| IDs and extras | Item: vendor price | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| IDs and extras | Item: already known / collected | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| IDs and extras | Keystone tooltip (affixes, depleted) | toggle |  | On | live | has | EllesmereUI WindTools |  |
| IDs and extras | Group finder entry tooltip details | toggle |  | On | live | link | EllesmereUI BlizzardSkin |  |
| Parity: EllesmereUI BlizzardSkin | Tooltip: the unit's buffs as icons | — | C_UnitAuras on other units is secret in combat; out of combat the icons can be drawn |  | live | new | EllesmereUI BlizzardSkin | S24 |
| Parity: EllesmereUI ForeverEssentials | Shorter stat lines on item tooltips | — |  |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: EllesmereUI ForeverEssentials | Gathering skill in node tooltips and minimap | — |  |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: EllesmereUI WindTools | Tooltip icons, faction / pet icons, pet ID, tier set count | — |  |  | live | part | EllesmereUI WindTools | S24 |
| Parity: Questie | Item drop rates | — | No licence-clean drop-rate data (Wowhead and Questie data are off-limits) |  | — | api | Questie |  |
| Parity: idTip | IDs in tooltips: talent, criteria, ability, artifact power, enchant, bonus, gem, macro, set, visual, source, species, icon, area POI, vignette, expansion, object, trait node / entry / definition | — | Code may be reused under BSD-2 with the notice (docs/LICENSES); NPC IDs only when UnitCreatureID is not secret |  | live | new | idTip | S26 |
| Parity: Auctionator | Auction / vendor / disenchant / mill / prospect prices in tooltips | — | Fed by the S22 price database |  | live | new | Auctionator | S22 |

## Bags  (`Bags`)

*Now 56 (Forever 55) → target 48* · has 38 · part 9 · new 1 · link/api 5

**How:** Restyles Blizzard's combined bag + bank; own sorting via C_Container

**References:** EUI Bags 45 · Baganator-style features

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Layout | Combined bags | toggle |  | On | live | has | EllesmereUI Bags |  |
| Layout | Columns | slider | 6–24 | 12 | live | has | EllesmereUI Bags |  |
| Layout | Slot size | slider | 24–56 px | 36 | live | has | EllesmereUI Bags |  |
| Layout | Slot spacing | slider | 0–8 px | 3 | live | has | EllesmereUI Bags |  |
| Layout | Category sections | dropdown | Off / Blizzard filters / Phoenix categories | Off | hover | has | EllesmereUI Bags |  |
| Layout | Category list (reorder / hide) | reorder | Equipment, Consumables, Reagents, Junk, New… | default order | live | has | EllesmereUI Bags |  |
| Layout | Bank / Warband bank same layout | toggle |  | On | live | part | EllesmereUI Bags | S23 |
| Layout | Scale | slider | 50–150 % | 100 | world | has | EllesmereUI Bags |  |
| Slots | Item level on gear | toggle |  | On | live | has | EllesmereUI Bags |  |
| Slots | Item level font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | link | EllesmereUI Bags |  |
| Slots | Item level size | slider | 6–40 | 11 | live | link | EllesmereUI Bags |  |
| Slots | Item level outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | link | EllesmereUI Bags |  |
| Slots | Item level shadow | toggle |  | Off | live | link | EllesmereUI Bags |  |
| Slots | Item level colour | colour | colour + class colour + theme token | #FFFFFF | live | link | EllesmereUI Bags |  |
| Slots | Quality border | toggle |  | On | live | has | EllesmereUI Bags |  |
| Slots | Slot border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI Bags |  |
| Slots | Slot border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI Bags |  |
| Slots | Slot border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI Bags |  |
| Slots | Slot border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI Bags |  |
| Slots | Slot border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI Bags |  |
| Slots | Junk coin icon | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Slots | New item glow | dropdown | Blizzard / Phoenix / Off | Phoenix | hover | has | EllesmereUI Bags |  |
| Slots | Upgrade arrow (better ilvl) | toggle |  | On | live | has | EllesmereUI Bags |  |
| Slots | Bind-on-equip / warbound label | toggle |  | On | live | has | EllesmereUI Bags |  |
| Slots | Cooldown on usable items | toggle |  | On | live | has | EllesmereUI Bags |  |
| Slots | Count font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI Bags |  |
| Slots | Count size | slider | 6–40 | 12 | live | has | EllesmereUI Bags |  |
| Slots | Count outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI Bags |  |
| Slots | Count shadow | toggle |  | Off | live | has | EllesmereUI Bags |  |
| Slots | Count colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI Bags |  |
| Window | Window background | toggle |  | On | live | has | EllesmereUI Bags |  |
| Window | Window background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI Bags | S23 |
| Window | Window background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI Bags |  |
| Window | Window background opacity | slider | 0–100 % | 92 | live | has | EllesmereUI Bags |  |
| Window | Window border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI Bags |  |
| Window | Window border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI Bags |  |
| Window | Window border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI Bags |  |
| Window | Window border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI Bags |  |
| Window | Window border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI Bags |  |
| Window | Search box | toggle |  | On | live | has | EllesmereUI Bags |  |
| Window | Gold, currencies footer | toggle |  | On | live | has | EllesmereUI Bags |  |
| Window | Bag bar inside window | toggle |  | On | live | has | EllesmereUI Bags |  |
| Behaviour | Sort button | toggle |  | On | none | has | EllesmereUI Bags |  |
| Behaviour | Sort direction / reverse | dropdown | Blizzard / Reverse | Blizzard | none | has | EllesmereUI Bags |  |
| Behaviour | Auto sell junk (in Automation) | toggle | see Automation |  | none | has | EllesmereUI Bags |  |
| Behaviour | Open with vendor / bank / mail / AH | toggle | 4 toggles | On | none | part | EllesmereUI Bags | S23 |
| Behaviour | Close with vendor | toggle |  | On | none | part | EllesmereUI Bags | S23 |
| Parity: EllesmereUI Bags | Grid view: item level, gear track rank, BoE / warbound label, set name | — | Item level and bind label exist; track rank and set name do not |  | live | part | EllesmereUI Bags | S23 |
| Parity: EllesmereUI Bags | List view of bags (rows with names, gold value per section) | — |  |  | live | new | EllesmereUI Bags | S23 |
| Parity: EllesmereUI Bags | Category sidebar, nest by expansion, group by category | — | Categories exist; sidebar and expansion nesting do not |  | live | part | EllesmereUI Bags | S23 |
| Parity: EllesmereUI Bags | Pinned and recent items, custom categories, empty-category hiding | — |  |  | live | part | EllesmereUI Bags | S23 |
| Parity: EllesmereUI Bags | Merge stacks, gear by slot, gold history, stack splitter, quality borders, open with character | — | Quality borders exist; merge view, gold history and splitter do not |  | live | part | EllesmereUI Bags | S23 |
| Parity: EllesmereUI ForeverEssentials | Junk window (items, prices, confirm skip, low-space trigger) | — | Sell junk exists; the junk window does not |  | live | part | EllesmereUI ForeverEssentials | S27 |

## Item Level  (`ItemLevel`)

*Now 20 (Forever 20) → target 22* · has 18 · part 3 · new 1 · link/api 0

**How:** Item level on character, inspect, bags, loot frames

**References:** EUI BlizzardSkin character sheet 30 · WindTools Item 27 (inspect, already known)

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Where | Character sheet slots | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Where | Inspect frame slots | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Where | Bags / bank (in Bags) | toggle | see Bags |  | live | has | EllesmereUI WindTools |  |
| Where | Loot / roll / great vault / merchant | toggle | 4 toggles | On | live | part | EllesmereUI BlizzardSkin | S23 |
| Where | Equipment flyout | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Look | Item level font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI BlizzardSkin |  |
| Look | Item level size | slider | 6–40 | 12 | live | has | EllesmereUI BlizzardSkin |  |
| Look | Item level outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI BlizzardSkin |  |
| Look | Item level shadow | toggle |  | Off | live | has | EllesmereUI BlizzardSkin |  |
| Look | Item level colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI BlizzardSkin |  |
| Look | Colour by quality | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Look | Item level anchor | dropdown | 9 points | Bottom | live | has | EllesmereUI BlizzardSkin |  |
| Look | Item level X offset | slider | -200–200 | 0 | live | has | EllesmereUI BlizzardSkin |  |
| Look | Item level Y offset | slider | -200–200 | 0 | live | has | EllesmereUI BlizzardSkin |  |
| Look | Missing enchant / gem warning | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Look | Enchant text on slot | toggle |  | Off | live | has | EllesmereUI BlizzardSkin |  |
| Look | Upgrade track (e.g. Hero 4/6) | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Look | Character sheet: average ilvl decimals | slider | 0–2 | 1 | live | has | EllesmereUI BlizzardSkin |  |
| Look | Character sheet: stats panel restyle | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Parity: EllesmereUI BlizzardSkin | Character and inspect sheet: stat letters, enchants, durability, crests, season panel, M+ rating, vault shortcut | — | Item level, upgrade track, enchant text and sockets exist; stats-panel restyle, durability, crests and season panel do not |  | live | part | EllesmereUI BlizzardSkin | S23 |
| Parity: EllesmereUI (core pages) | Crest upgrade calculator window | — | C_ItemUpgrade and crest currencies are readable |  | live | new | EllesmereUI (core pages) | S23 |
| Parity: EllesmereUI WindTools | Inspect: item icons, quality borders, sockets | — |  |  | live | part | EllesmereUI WindTools | S23 |

## Data Texts  (`DataTexts`)

*Now 77 (Forever 76) → target 51* · has 39 · part 12 · new 0 · link/api 0

**How:** Own data panels + broker (LDB) feeds

**References:** EUI DataBars 55 (XP/rep/honor bars) + MinimapDataText · ElvUI datatexts

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Panels (each panel) | Enable panel | toggle |  | On | world | has | EllesmereUI DataBars |  |
| Panels (each panel) | Slots | slider | 1–6 | 3 | live | has | EllesmereUI DataBars |  |
| Panels (each panel) | Width / height | slider | 60–1200 / 14–40 px | 420 / 22 | live | part | EllesmereUI DataBars | S28 |
| Panels (each panel) | Panel background | toggle |  | On | live | has | EllesmereUI DataBars |  |
| Panels (each panel) | Panel background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI DataBars | S28 |
| Panels (each panel) | Panel background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI DataBars |  |
| Panels (each panel) | Panel background opacity | slider | 0–100 % | 70 | live | has | EllesmereUI DataBars |  |
| Panels (each panel) | Panel border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI DataBars |  |
| Panels (each panel) | Panel border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI DataBars |  |
| Panels (each panel) | Panel border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI DataBars |  |
| Panels (each panel) | Panel border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI DataBars |  |
| Panels (each panel) | Panel border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI DataBars |  |
| Panels (each panel) | Mouseover only | toggle |  | Off | world | has | EllesmereUI DataBars |  |
| Panels (each panel) | Anchor | dropdown | 9 points + frame picker | per element | world | part | EllesmereUI DataBars | S28 |
| Panels (each panel) | X offset | slider | -2000–2000 | per element | world | part | EllesmereUI DataBars | S28 |
| Panels (each panel) | Y offset | slider | -1200–1200 | per element | world | part | EllesmereUI DataBars | S28 |
| Panels (each panel) | Frame strata | dropdown | BACKGROUND … TOOLTIP | MEDIUM | none | part | EllesmereUI DataBars | S28 |
| Panels (each panel) | Scale | slider | 50–200 % | 100 | world | part | EllesmereUI DataBars | S28 |
| Text | Data text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI DataBars |  |
| Text | Data text size | slider | 6–40 | 12 | live | has | EllesmereUI DataBars |  |
| Text | Data text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI DataBars |  |
| Text | Data text shadow | toggle |  | Off | live | has | EllesmereUI DataBars |  |
| Text | Data text colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI DataBars |  |
| Text | Label colour / value colour | colour | 2 colours | grey / class | live | part | EllesmereUI DataBars | S28 |
| Text | Hide labels | toggle |  | Off | live | has | EllesmereUI DataBars |  |
| Text | Combat: hide tooltips | toggle |  | On | none | has | EllesmereUI DataBars |  |
| Data sources (each slot) | Slot source | dropdown | Gold, Durability, Bags, Friends, Guild, FPS/MS, Time, Spec/Loot spec, Item level, Coords, Mythic+ score, Great Vault, Currencies, Mail, Talents loadout, Volume, LDB feeds | per slot | hover | has | EllesmereUI DataBars |  |
| Data sources (each slot) | Gold: show silver/copper | toggle |  | Off | live | has | EllesmereUI DataBars |  |
| Data sources (each slot) | Gold: account-wide totals | toggle |  | On | none | has | EllesmereUI DataBars |  |
| Data sources (each slot) | Time: 24h / local vs realm | dropdown | Local / Realm · 12h / 24h | Local 24h | live | has | EllesmereUI QoL |  |
| Data sources (each slot) | Durability: warn below | slider | 0–100 % | 25 | live | has | EllesmereUI QoL |  |
| Data sources (each slot) | Currency picker | list | currency IDs | Valorstones, crests | none | has | EllesmereUI DataBars |  |
| Experience / reputation / honor bars | Experience bar | toggle |  | On below max level | world | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Reputation bar (watched) | toggle |  | On | world | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Honor bar | toggle |  | Off | world | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Bar width / height | slider | 100–1200 / 4–30 px | 520 / 10 | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Data bar texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Data bar fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Data bar smooth fill | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Data bar gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Rested / quest XP overlay | toggle |  | On | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Bar text | dropdown | Off / Percent / Current / Remaining / Mouseover | Mouseover | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Bar text font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Bar text size | slider | 6–40 | 10 | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Bar text outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Bar text shadow | toggle |  | Off | live | has | EllesmereUI ActionBars |  |
| Experience / reputation / honor bars | Bar text colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI ActionBars |  |
| Parity: EllesmereUI ActionBars | Experience bar: dividers, 5 % lines, rested, quest-XP overlay, gain animation | — | Bar, rested and text exist; dividers, quest-XP overlay (C_QuestLog.GetQuestLogRewardXP) and gain animation do not |  | live | part | EllesmereUI ActionBars | S28 |
| Parity: EllesmereUI DataBars | Data bar blocks: currency picker, crests, M+ portals, audio channel, menu, plugins | — | S17: currency picker; crests, portals, audio, menu still open |  | live | part | EllesmereUI DataBars | S28 |
| Parity: EllesmereUI DataBars | Data bar layout: blocks, full-screen extent, snap, text, tooltips, clock, gold | — | Panels and segments exist; block layout and screen-edge bars do not |  | live | part | EllesmereUI DataBars | S28 |
| Parity: EllesmereUI WindTools | Game bar (micro buttons, time, friends, notifications) | — |  |  | live | part | EllesmereUI WindTools | S28 |

## Skins  (`Skins`)

*Now 36 (Forever 34) → target 37* · has 24 · part 9 · new 4 · link/api 0

**How:** Phoenix look for Blizzard windows

**References:** EUI BlizzardSkin 123 (character, popups, tooltips, skyriding, CDM, objective tracker)

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Windows (each toggle) | Game menu | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Windows (each toggle) | Popups (StaticPopup) | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Windows (each toggle) | Ready check | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Character / inspect | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Spellbook / talents | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Group finder | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Collections | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Professions | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Auction house | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Mail / merchant / gossip / quest | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Windows (each toggle) | Loot / rolls | toggle |  | On | live | part | EllesmereUI BlizzardSkin | S24 |
| Windows (each toggle) | Achievement / encounter journal | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Calendar / guild / communities | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Settings / addon list | toggle |  | On | live | part | EllesmereUI BlizzardSkin | S24 |
| Windows (each toggle) | Great vault / keystone | toggle |  | On | live | has | EllesmereUI ForeverEssentials |  |
| Windows (each toggle) | Alerts / toasts | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Windows (each toggle) | Skyriding vigor bar | toggle |  | On | live | new | EllesmereUI BlizzardSkin | S24 |
| Skin options | Window background | toggle |  | On | live | has | EllesmereUI BlizzardSkin |  |
| Skin options | Window background texture | texture | Phoenix surfaces + LSM | Solid | hover | part | EllesmereUI BlizzardSkin | S24 |
| Skin options | Window background colour | colour | colour + theme token | #0B0C0F | live | has | EllesmereUI BlizzardSkin |  |
| Skin options | Window background opacity | slider | 0–100 % | 94 | live | has | EllesmereUI BlizzardSkin |  |
| Skin options | Window border style | dropdown | None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset | Pixel | hover | has | EllesmereUI BlizzardSkin |  |
| Skin options | Window border size | slider | 0–4 px (pixel-perfect) | 1 | live | has | EllesmereUI BlizzardSkin |  |
| Skin options | Window border colour | colour | colour + class colour + quality + theme token | #000000 | live | has | EllesmereUI BlizzardSkin |  |
| Skin options | Window border shadow | dropdown | None / Soft / Hard / Glow | Soft | hover | has | EllesmereUI BlizzardSkin |  |
| Skin options | Window border shadow size | slider | 0–16 px | 4 | live | has | EllesmereUI BlizzardSkin |  |
| Skin options | Title bar style | dropdown | Phoenix / Minimal / Blizzard | Phoenix | hover | has | EllesmereUI BlizzardSkin |  |
| Skin options | Close button style | dropdown | Phoenix / Blizzard | Phoenix | hover | has | EllesmereUI BlizzardSkin |  |
| Parity: EllesmereUI BlizzardSkin | Widget bars, extra action button and queue pop-up skin with queue timer | — | Extra action skin exists (Action Bars); widget bars and queue timer on the LFG pop-up do not |  | live | part | EllesmereUI BlizzardSkin | S24 |
| Parity: EllesmereUI BlizzardSkin | Friends list look, sign-up roles memory, merchant list view and bulk buy, gold / loot toasts | — | Remembered sign-up roles exist on Group Finder; the rest is missing |  | live | new | EllesmereUI BlizzardSkin | S24 |
| Parity: EllesmereUI BlizzardSkin | Other Blizzard bars and buttons | — |  |  | live | part | EllesmereUI BlizzardSkin | S24 |
| Parity: EllesmereUI BlizzardSkin | Skin third-party addons | — | Details! and BigWigs are styled; a general third-party skin list is missing |  | live | part | EllesmereUI BlizzardSkin | S24 |
| Parity: EllesmereUI BlizzardSkin | Chat bubble skin (font, border, padding, speaker name) | — | Open world only: chat bubbles inside instances are forbidden frames in 12.x (C_ChatBubbles returns none, GetChildren of WorldFrame is blocked), so 'in instances' is impossible |  | live | part | EllesmereUI BlizzardSkin | S24 |
| Parity: EllesmereUI Friends | Friends list: class icons, class colours, faction banners, region icons, auto-accept friend invites | — | Accept invites from friends exists (Automation); the friends-list look does not |  | live | part | EllesmereUI Friends | S24 |
| Parity: EllesmereUI WindTools | Mail contacts (alts) | — |  |  | live | new | EllesmereUI WindTools | S24 |
| Parity: EllesmereUI WindTools | Wider merchant window | — |  |  | live | new | EllesmereUI WindTools | S24 |
| Parity: EllesmereUI WindTools | SilverDragon skin | — |  |  | live | part | EllesmereUI WindTools | S24 |

## Appearance & General  (`General`)

*Now 52 (Forever 52) → target 22* · has 18 · part 4 · new 0 · link/api 2

**How:** Theme, global fonts/textures/colours, scale, sounds; every module's 'Theme default' points here

**References:** EUI Fonts 37 + Textures + Colors + Glow + General ~90

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Theme | Theme | dropdown | Ember / Dawn / Midnight / Classic / Custom | Ember | hover | has | EllesmereUI (core pages) |  |
| Theme | Accent colour | colour |  | theme | live | has | EllesmereUI (core pages) |  |
| Theme | Accent from class colour | toggle |  | Off | live | has | EllesmereUI (core pages) |  |
| Theme | Window surface opacity | slider | 60–100 % | 96 | live | has | EllesmereUI BlizzardSkin |  |
| Theme | Reduce motion | toggle |  | Off | live | has | EllesmereUI (core pages) |  |
| Theme | UI scale (pixel perfect) | slider | auto / 0.53–1.0 | auto | live | has | EllesmereUI (core pages) |  |
| Fonts | Interface font | dropdown | Phoenix fonts + LSM | Phoenix Sans | hover | has | EllesmereUI (core pages) |  |
| Fonts | Unit / number font | dropdown | Phoenix fonts + LSM | Phoenix Numbers | hover | has | EllesmereUI (core pages) |  |
| Fonts | Font scale | slider | 80–130 % | 100 | live | has | EllesmereUI (core pages) |  |
| Fonts | Global outline | dropdown | None / Outline / Thick | Outline | live | has | EllesmereUI (core pages) |  |
| Fonts | Replace Blizzard fonts (damage, names, chat) | toggle | 4 toggles | Off | none | part | EllesmereUI (core pages) | S28 |
| Textures and borders | Default bar texture | texture |  | Phoenix Satin | hover | has | EllesmereUI (core pages) |  |
| Textures and borders | Default border style | dropdown | border styles | Pixel | hover | has | EllesmereUI (core pages) |  |
| Textures and borders | Default border colour | colour |  | #000000 | live | has | EllesmereUI (core pages) |  |
| Textures and borders | Default shadow | dropdown | None / Soft / Hard | Soft | hover | has | EllesmereUI (core pages) |  |
| Colours | Class colours override | colour | 13 classes | Blizzard | live | has | EllesmereUI (core pages) |  |
| Colours | Power colours override | colour | per type | Blizzard | live | has | EllesmereUI (core pages) |  |
| Colours | Reaction colours | colour | 4 | Blizzard | live | link | EllesmereUI (core pages) |  |
| Colours | Dispel colours | colour | 5 | Blizzard | live | link | EllesmereUI (core pages) |  |
| Glow | Default glow style | dropdown | Pixel / Autocast / Button / Proc | Pixel | hover | part | EllesmereUI (core pages) | S28 |
| Glow | Glow colour / lines / speed / thickness | colour | colour + 3 sliders | accent / 8 / 4 / 2 | live | part | EllesmereUI (core pages) | S28 |
| Sounds | Sound channel | dropdown | Master / SFX / Dialog | Master | none | has | EllesmereUI WindTools |  |
| Sounds | Mute list (sound file IDs) | list | IDs |  | none | has | EllesmereUI WindTools |  |
| Parity: EllesmereUI (core pages) | Dark mode for all frames with darkening amount | — | Per-module dark bars exist; one global dark mode does not |  | live | part | EllesmereUI (core pages) | S28 |

## Profiles  (`Profiles`)

*Now 15 (Forever 11) → target 8* · has 6 · part 2 · new 0 · link/api 1

**How:** Profiles, per-spec switching, import/export strings, presets

**References:** EUI Profiles 4 pages (Profiles, Presets, Overrides, FullExport)

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Profiles | Active profile | dropdown | profiles | Default | none | has | sArena Reloaded |  |
| Profiles | New / copy / rename / delete | button |  |  | none | has | sArena Reloaded |  |
| Profiles | Per-spec profile | toggle | + profile per spec | Off | none | has | sArena Reloaded |  |
| Profiles | Per-character overrides | toggle |  | Off | none | link | sArena Reloaded |  |
| Profiles | Export (all / selected modules) | button | string + module picker |  | none | has | sArena Reloaded |  |
| Profiles | Import with preview of changes | button |  |  | live | part | sArena Reloaded | S21 |
| Profiles | Presets (Phoenix Healer / DPS / Tank / Minimal) | button |  |  | hover | has | sArena Reloaded |  |
| Profiles | Reset module | button | per module |  | none | has | sArena Reloaded |  |
| Parity: BigWigs | Share boss settings as import strings | — | Profile export exists; per-instance encounter export does not |  | live | part | BigWigs | S21 |

## Layout (Movers)  (`Movers`)

*Now 17 (Forever 17) → target 15* · has 11 · part 3 · new 1 · link/api 0

**How:** Unlock mode for every Phoenix-owned frame + selected Blizzard frames (no Edit Mode conflicts)

**References:** MoveAny 150 frame toggles · EUI unlock mode (snap, grid, nudge, per-element)

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Unlock mode | Grid | toggle |  | On | world | has | MoveAny |  |
| Unlock mode | Grid size | slider | 8–128 px | 32 | world | has | MoveAny |  |
| Unlock mode | Snap to grid | toggle |  | On | world | has | MoveAny |  |
| Unlock mode | Snap to other frames | toggle |  | On | world | has | MoveAny |  |
| Unlock mode | Nudge with arrow keys (shift = 10 px) | toggle |  | On | world | has | MoveAny |  |
| Unlock mode | Show coordinates while dragging | toggle |  | On | world | has | EllesmereUI QoL |  |
| Unlock mode | Per-element popup (X, Y, anchor, scale, reset) | button |  |  | world | has | EllesmereUI QoL |  |
| Unlock mode | Frame list (search, show/hide, reset) | list | all movable frames |  | world | has | EllesmereUI QoL |  |
| Unlock mode | Move Blizzard frames (talking head, loot, alerts, vehicle seat, durability, widgets…) | toggle | per frame | Off | world | has | MoveAny |  |
| Unlock mode | Scale Blizzard windows | slider | 50–150 % | 100 | world | has | EllesmereUI QoL |  |
| Unlock mode | Unlock keybind | keybind |  | None | none | has | MoveAny |  |
| Parity: EllesmereUI QoL | Move Blizzard windows by dragging (with reset) | — | Window scale exists; free dragging of Blizzard windows does not |  | live | part | EllesmereUI QoL | S26 |
| Parity: EllesmereUI WindTools | Move Blizzard frames, remember positions | — |  |  | live | part | EllesmereUI WindTools | S26 |
| Parity: MoveAny | Mover behaviour: drag / scale keys, clamp, save positions | — | Grid, snap and nudge exist; per-window drag / scale keys do not |  | live | part | MoveAny | S26 |
| Parity: MoveAny | Move the remaining Blizzard frames (talking head, vehicle seat, durability, ghost, loss of control, mirror timers, queue status, loot, bonus roll, battlefield map, popups, role poll, encounter bar, archaeology, ticket, toasts) | — |  |  | live | new | MoveAny | S26 |

## Quality of life  (`Quality`)

*Now 22 (Forever 22) → target 28* · has 9 · part 7 · new 12 · link/api 0

**How:** Small UI tweaks

**References:** EUI QoL 75 · WindTools Misc 112

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Quality of life | Hide talking heads | toggle |  | On | none | has | EllesmereUI (core pages) |  |
| Quality of life | Quiet errors in combat | toggle |  | On | none | has | EllesmereUI (core pages) |  |
| Quality of life | Achievement screenshots | toggle |  | On | none | has | EllesmereUI WindTools |  |
| Quality of life | Cooldown Manager | toggle |  | On | none | has | EllesmereUI (core pages) |  |
| Quality of life | Hide boss banner / zone text / level-up | toggle | 3 toggles | Off | none | part | EllesmereUI (core pages) | S26 |
| Quality of life | Camera max distance | slider | 15–39 yd | 39 | none | has | EllesmereUI (core pages) |  |
| Quality of life | Raid markers bar | toggle |  | Off | world | has | EllesmereUI QoL |  |
| Quality of life | Mouse cursor ring / trail | toggle |  | Off | world | has | EllesmereUI QoL |  |
| Quality of life | Combat enter/leave alert | toggle |  | Off | world | has | EllesmereUI QoL |  |
| Quality of life | Already known recipe tint | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Quality of life | CVar browser (common safe CVars) | list |  |  | none | part | EllesmereUI WindTools | S26 |
| Parity: EllesmereUI (core pages) | Gamepad mode: hide action bars / cast bars | — |  |  | live | new | EllesmereUI (core pages) | S26 |
| Parity: EllesmereUI (core pages) | Party mode celebrations (bloodlust, timed key, boss kills, rated wins) | — |  |  | live | new | EllesmereUI (core pages) | S26 |
| Parity: EllesmereUI ForeverEssentials | Double-click to fish, fishing sounds | — | Needs a secure override binding set out of combat (SetOverrideBindingClick) |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: EllesmereUI ForeverEssentials | Loot feed (style, quality filter, growth) | — |  |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: EllesmereUI ForeverEssentials | Macro manager | — | EditMacro / CreateMacro are out-of-combat only |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: EllesmereUI QoL | Potion-ready and unspent-talent alerts, group deaths notice | — |  |  | live | new | EllesmereUI QoL | S26 |
| Parity: EllesmereUI QoL | Auto combat logging in chosen content | — | LoggingCombat() is allowed |  | live | new | EllesmereUI QoL | S26 |
| Parity: EllesmereUI QoL | Cursor ring, trail, GCD and cast circles, reticle | — | Ring exists; trail, GCD / cast circles and reticle do not |  | live | part | EllesmereUI QoL | S26 |
| Parity: EllesmereUI QoL | Hide item transforms, /cd command, AH current-expansion filter | — | AH filter moves to the Auction House page (S22) |  | live | new | EllesmereUI QoL | S26 |
| Parity: EllesmereUI QoL | Secondary stats on screen, guild chat privacy cover, rested indicator, target distance text | — |  |  | live | new | EllesmereUI QoL | S26 |
| Parity: EllesmereUI QoL | Character crosshair with melee-range colour | — |  |  | live | new | EllesmereUI QoL | S26 |
| Parity: EllesmereUI QoL | Raid tools window (ready check, pull, markers, world markers) | — | Raid marker bar and pull timer exist; one raid-tools window does not |  | live | part | EllesmereUI QoL | S26 |
| Parity: EllesmereUI WindTools | Raid marker bar with countdown and ready-check buttons | — | Marker bar exists; countdown / ready-check buttons and inverse mode do not |  | live | part | EllesmereUI WindTools | S26 |
| Parity: EllesmereUI WindTools | Misc tweaks (talking head, cut scenes, loot panel, chat bubble toggle) | — |  |  | live | part | EllesmereUI WindTools | S26 |
| Parity: EllesmereUI WindTools | Exit phase diving button | — |  |  | live | new | EllesmereUI WindTools | S26 |
| Parity: EllesmereUI WindTools | CVar editor (screenshots, floating text, spell queue, camera, effects) | — |  |  | live | part | EllesmereUI WindTools | S26 |
| Parity: EllesmereUI WindTools | Spell activation overlay opacity / scale | — |  |  | live | new | EllesmereUI WindTools | S26 |

## Automation  (`Automation`)

*Now 15 (Forever 15) → target 17* · has 13 · part 1 · new 3 · link/api 1

**How:** Small automations

**References:** EUI QoL 75 · WindTools Misc 112

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Automation | Auto repair | dropdown | Off / Personal / Guild first | On | none | has | EllesmereUI WindTools |  |
| Automation | Sell junk | toggle |  | On | none | has | EllesmereUI QoL |  |
| Automation | Accept invites from friends | toggle |  | On | none | has | EllesmereUI WindTools |  |
| Automation | Decline duels | toggle |  | On | none | has | EllesmereUI WindTools |  |
| Automation | Accept resurrections | toggle |  | On | none | has | EllesmereUI WindTools |  |
| Automation | Fill "DELETE" | toggle |  | On | none | has | EllesmereUI QoL |  |
| Automation | Skip cinematics | toggle |  | On | none | has | EllesmereUI QoL |  |
| Automation | Auto loot faster | toggle |  | On | none | has | EllesmereUI WindTools |  |
| Automation | Auto accept / turn in quests (in Quests) | toggle | see Quests |  | none | has | EllesmereUI WindTools |  |
| Automation | Auto gossip single option | toggle |  | Off | none | has | EllesmereUI QoL |  |
| Automation | Auto role check accept | toggle |  | On | none | link | EllesmereUI WindTools |  |
| Automation | Auto confirm BoP loot solo | toggle |  | Off | none | has | EllesmereUI WindTools |  |
| Automation | Decline pet-battle duels / guild invites | toggle | 2 | Off | none | has | EllesmereUI QoL |  |
| Automation | Combat warning sounds (low health) | toggle |  | Off | none | has | EllesmereUI WindTools |  |
| Parity: EllesmereUI ForeverEssentials | Auto-summon a favourite companion pet | — | Out of combat (C_PetJournal.SummonPetByGUID) |  | live | new | EllesmereUI ForeverEssentials | S27 |
| Parity: EllesmereUI QoL | Hide screenshot text, train all, auto unwrap, auto open containers, hold capped payouts | — | Opening containers needs a hardware event per item (C_Container.UseContainerItem is protected); a click-to-open button is possible |  | live | new | EllesmereUI QoL | S26 |
| Parity: EllesmereUI WindTools | Auto hide map / bags, accept resurrect, confirm summon | — |  |  | live | part | EllesmereUI WindTools | S26 |
| Parity: BigWigs | Invite on keyword | — | InviteUnit is allowed |  | live | new | BigWigs | S26 |

## AFK screen  (`AFK`)

*Now 12 (Forever 12) → target 4* · has 4 · part 0 · new 0 · link/api 0

**How:** AFK screen

**References:** ElvUI AFK

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| AFK | Rotate camera | toggle |  | On | none | has | EllesmereUI |  |
| AFK | AFK screen (model, name, guild, time AFK) | toggle |  | On | world | has | EllesmereUI |  |
| AFK | Show stats panel (ilvl, M+, vault) | toggle |  | On | world | has | EllesmereUI |  |
| AFK | Don't show in instances | toggle |  | On | none | has | EllesmereUI |  |

## Bugs  (`Bugs`)

*Now 12 (Forever 12) → target 12* · has 12 · part 0 · new 0 · link/api 0

**How:** Error catcher (being rebuilt by the other worker)

**References:** BugSack-like · EUI none

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Bugs (other worker is rebuilding — spec here only for counting) | Lua warnings | toggle |  |  | none | has | EllesmereUI (core pages) |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Blocked actions | toggle |  |  | none | has | EllesmereUI (core pages) |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Reports kept | slider |  |  | none | has | EllesmereUI (core pages) |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Chat notice | toggle |  |  | none | has | BugGrabber + BugSack |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Sound | dropdown |  |  | none | has | BugGrabber + BugSack |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Flash on new errors | toggle |  |  | none | has | EllesmereUI (core pages) |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Minimap indicator | dropdown |  |  | none | has | BugGrabber + BugSack |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Blizzard error window | toggle |  |  | none | has | BugGrabber + BugSack |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Send error reports to the author | toggle |  |  | none | has | BugGrabber + BugSack |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Group duplicates with count | toggle |  | On | live | has | EllesmereUI (core pages) |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Filter by addon | dropdown | addons | All | live | has | EllesmereUI (core pages) |  |
| Bugs (other worker is rebuilding — spec here only for counting) | Copy / export report | button |  |  | none | has | EllesmereUI (core pages) |  |

## Quests  (`Quests`)

*Now 43 (Forever 41) → target 41* · has 25 · part 10 · new 6 · link/api 1

**How:** NEW: quest tracker restyle + quest helper (giver/turn-in pins from ATT MIT data, DB2 QuestPOI and runtime C_QuestLine; community data later)

**References:** EUI QuestTracker ~30 · WindTools Quest 41 · Questie (ARR/GPL, learn only)

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Objective tracker | Restyle objective tracker | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Objective tracker | Width / max height | slider | 200–400 / 200–900 px | 260 / 600 | live | has | EllesmereUI WindTools |  |
| Objective tracker | Header font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI WindTools |  |
| Objective tracker | Header size | slider | 6–40 | 13 | live | has | EllesmereUI WindTools |  |
| Objective tracker | Header outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI WindTools |  |
| Objective tracker | Header shadow | toggle |  | Off | live | has | EllesmereUI WindTools |  |
| Objective tracker | Header colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI WindTools |  |
| Objective tracker | Objective font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI WindTools |  |
| Objective tracker | Objective size | slider | 6–40 | 12 | live | has | EllesmereUI WindTools |  |
| Objective tracker | Objective outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI WindTools |  |
| Objective tracker | Objective shadow | toggle |  | Off | live | has | EllesmereUI WindTools |  |
| Objective tracker | Objective colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI WindTools |  |
| Objective tracker | Progress bars style | texture |  | theme | hover | has | EllesmereUI WindTools |  |
| Objective tracker | Colour by difficulty | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Objective tracker | Auto-collapse in instances / combat | dropdown | Off / Instances / Combat / Both | Instances | none | has | EllesmereUI WindTools |  |
| Objective tracker | Show quest level / tag (daily, campaign) | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Objective tracker | Click to super-track | toggle |  | On | none | has | EllesmereUI WindTools |  |
| Quest helper | Waypoint arrow | toggle |  | On | world | has | EllesmereUI WindTools |  |
| Quest helper | Arrow style / size | dropdown | Phoenix / TomTom-like · 24–96 px | Phoenix 48 | hover | has | EllesmereUI WindTools |  |
| Quest helper | Distance + ETA text | toggle |  | On | world | has | EllesmereUI WindTools |  |
| Quest helper | Available quests on map (C_QuestLine) | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Quest helper | Turn-in / objective areas from QuestPOI (DB2) | toggle |  | On | live | part | EllesmereUI WindTools | S25 |
| Quest helper | Quest NPC pins (ATT data + community) | toggle |  | On | live | part | EllesmereUI WindTools | S25 |
| Quest helper | Hide low-level / trivial | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Quest helper | Auto accept / turn in (hold Shift to stop) | toggle |  | Off | none | has | EllesmereUI QuestTracker |  |
| Quest helper | Auto pick quest reward (highest sell / sim upgrade) | dropdown | Off / Vendor value / Sim upgrade | Off | none | has | EllesmereUI ForeverEssentials |  |
| Quest helper | Contribute positions to Phoenix data (opt-in) | toggle |  | Off | none | has | EllesmereUI WindTools |  |
| Parity: EllesmereUI QuestTracker | Sorting, filtering, auto-track zone quests, completion sounds | — | Announce progress is a scope cut |  | live | new | EllesmereUI QuestTracker | S25 |
| Parity: EllesmereUI WindTools | Super tracker: auto-track waypoints, middle-click clear, no distance limit, /way box | — | S17: /way and NPC map search; auto-track and middle-click clear still open |  | live | part | EllesmereUI WindTools | S25 |
| Parity: EllesmereUI WindTools | Tracker text tweaks (dash, colourful progress, %) | — |  |  | live | part | EllesmereUI WindTools | S25 |
| Parity: EllesmereUI WindTools | Tracker switch buttons | — |  |  | live | new | EllesmereUI WindTools | S25 |
| Parity: EllesmereUI WindTools | Prey hunt helper | — |  |  | live | new | EllesmereUI WindTools | S25 |
| Parity: EllesmereUI WindTools | Achievement tracker window | — |  |  | live | new | EllesmereUI WindTools | S25 |
| Parity: Questie | Questie tracker (sorting, minimise, fonts, sizer, TomTom) | — | Phoenix restyles Blizzard's tracker; its own sorting / sizer options do not exist |  | live | part | Questie | S25 |
| Parity: Questie | Quest and objective icons on maps by type | — | Givers, turn-ins and quest lines exist; objective icons come from the game's own map |  | live | part | Questie | S25 |
| Parity: Questie | NPC patrol paths on the map | — | No licence-clean source of NPC waypoints: DB2 has no creature spawns, Questie's data is GPL-3.0 and Wowhead forbids scraping |  | — | api | Questie |  |
| Parity: Questie | Instant quest text, map buttons, coordinates, level filters, tooltips (quests on NPCs, chains, breadcrumbs), sounds | — | Coordinates, NPC quest tooltips, level filter exist; chains, instant text and sounds do not |  | live | part | Questie | S25 |
| Parity: Questie | Auto accept by quest kind, auto complete, modifier | — | Accept / turn-in exist; per-kind filters do not |  | live | part | Questie | S25 |
| Parity: Questie | Auto reject shared quests (battlegrounds, non-friends) | — |  |  | live | new | Questie | S25 |
| Parity: Questie | Icon limits and distances, locale, reset, journey import | — |  |  | live | part | Questie | S25 |
| Parity: Questie | My Journey (quest history log) | — |  |  | live | new | Questie | S25 |
| Parity: QuestieTrace | Opt-in session recorder with privacy filter and export string | — | Phoenix S17 collector: opt-in, NPC IDs + map positions only, merged by tools/; no export string or uploader |  | live | part | QuestieTrace | S28 |

## Group Finder  (`GroupFinder`)

*Now 58 (Forever —) → target 18* · has 11 · part 4 · new 3 · link/api 6

**How:** NEW: premade group list filters (PGF-style expressions re-implemented), sign-up helpers

**References:** PremadeGroupsFilter 105 variables (GPL-2, learn only) · EUI GroupFinder · WindTools LFG list

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Filters | Filter panel next to the group list | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Filters | Min / max members, tanks, healers, damage | slider | 0–40 each | any | live | has | AutoQueue |  |
| Filters | Has Bloodlust / Battle res | toggle | 2 | Off | live | has | PremadeGroupsFilter |  |
| Filters | Min leader score / item level | slider | 0–4000 / 0–700 | 0 | live | has | EllesmereUI WindTools |  |
| Filters | Age (minutes) | slider | 0–180 | any | live | has | PremadeGroupsFilter |  |
| Filters | Dungeon / difficulty / key level | list |  | any | live | part | AutoQueue | S28 |
| Filters | Advanced expression (Phoenix syntax) | input | e.g. tanks==0 and mprating>=2000 |  | live | has | PremadeGroupsFilter |  |
| Filters | Sort | dropdown | Age / Score / Item level / Fit | Age | live | has | PremadeGroupsFilter |  |
| Helpers | One-click sign up (double click) | toggle |  | On | none | has | PremadeGroupsFilter |  |
| Helpers | Remember sign-up note | toggle |  | On | none | api | EllesmereUI QoL |  |
| Helpers | Role / class icons on list entries | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Helpers | Leader score + best key in tooltip | toggle |  | On | live | has | EllesmereUI WindTools |  |
| Helpers | Raid lockout hint | toggle |  | On | live | has | PremadeGroupsFilter |  |
| Helpers | Auto queue (role check) accept | toggle | (AutoQueue idea) | Off | none | part | AutoQueue | S26 |
| Parity: EllesmereUI GroupFinder | Applications counter bar in the group finder | — |  |  | live | part | EllesmereUI GroupFinder | S28 |
| Parity: EllesmereUI QoL | Reminder when you are not queued | — |  |  | live | new | EllesmereUI QoL | S28 |
| Parity: EllesmereUI WindTools | Auto refresh / auto join group listings | — | C_LFGList.Search is flagged HasRestrictions in the API docs (it runs from your click) and joining goes through Blizzard's Sign Up button; no automatic refresh or join |  | — | api | EllesmereUI WindTools |  |
| Parity: PremadeGroupsFilter | Skip the sign-up dialog, persistent note | — | The sign-up dialog only submits through Blizzard's Sign Up button (a click) and its note box refuses SetText from addons (S15) |  | — | api | PremadeGroupsFilter |  |
| Parity: PremadeGroupsFilter | Cancel the oldest application when full | — | Blizzard cancels applications only from its own button; Phoenix treats it as needing your click (like sign-up, S15), so it is not done on its own |  | — | api | PremadeGroupsFilter |  |
| Parity: PremadeGroupsFilter | Compact list entries | — |  |  | live | new | PremadeGroupsFilter | S28 |
| Parity: PremadeGroupsFilter | Advanced filter expressions (105 variables) | — | Phoenix grammar has 39 words |  | live | part | PremadeGroupsFilter | S28 |
| Parity: AutoQueue | Accept the dungeon-ready pop-up automatically | — | Blizzard only enters through the pop-up's Enter button (AcceptProposal), which we treat as needing your click; a timer-driven Click() is not a hardware event, so Phoenix offers a key binding instead (in-game check) |  | — | api | AutoQueue |  |
| Parity: AutoQueue | Sign up automatically when a listing is double-clicked / without the dialog | — | Signing up goes through Blizzard's own Sign Up button (Phoenix uses a secure click on it, S15); without your click or key press it is not built |  | — | api | AutoQueue |  |
| Parity: AutoQueue | Role bar (pick tank / healer / damage before queueing), minimap button, enable switch | — |  |  | live | new | AutoQueue | S28 |

## Mythic+  (`MythicPlus`)

*Now 34 (Forever —) → target 32* · has 30 · part 0 · new 2 · link/api 1

**How:** Own M+ timer (Blizzard Challenge APIs) + keystone tools

**References:** EUI MythicTimer 125 · WindTools keystone tooltips

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Timer | Run timer | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Enemy forces | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Boss splits | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Deaths | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Personal best | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Compare with your best run | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Current pull | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | +2 / +3 chest timers | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Affix icons with tooltips | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Death penalty breakdown | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Width | slider | 180–400 | 260 | live | has | EllesmereUI MythicTimer |  |
| Timer | Timer bar texture | texture | Phoenix bars + LSM, cards with samples | Phoenix Satin | hover | has | EllesmereUI MythicTimer |  |
| Timer | Timer bar fill direction | dropdown | Left→Right / Right→Left / Bottom→Top / Top→Bottom | Left→Right | live | has | EllesmereUI MythicTimer |  |
| Timer | Timer bar smooth fill | toggle |  | On | live | has | EllesmereUI MythicTimer |  |
| Timer | Timer bar gradient | dropdown | None / Horizontal / Vertical | None | live | has | EllesmereUI MythicTimer |  |
| Timer | Colours (on time / +2 / +3 / over) | colour | 4 | theme | live | has | EllesmereUI MythicTimer |  |
| Timer | Timer font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI MythicTimer |  |
| Timer | Timer size | slider | 6–40 | 22 | live | has | EllesmereUI MythicTimer |  |
| Timer | Timer outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI MythicTimer |  |
| Timer | Timer shadow | toggle |  | Off | live | has | EllesmereUI MythicTimer |  |
| Timer | Timer colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI MythicTimer |  |
| Timer | Objectives font | dropdown | Phoenix fonts + LibSharedMedia | Theme UI font | hover | has | EllesmereUI MythicTimer |  |
| Timer | Objectives size | slider | 6–40 | 12 | live | has | EllesmereUI MythicTimer |  |
| Timer | Objectives outline | dropdown | None / Outline / Thick / Monochrome | Outline | live | has | EllesmereUI MythicTimer |  |
| Timer | Objectives shadow | toggle |  | Off | live | has | EllesmereUI MythicTimer |  |
| Timer | Objectives colour | colour | colour + class colour + theme token | #FFFFFF | live | has | EllesmereUI MythicTimer |  |
| Timer | Hide Blizzard objective tracker in M+ | toggle |  | On | none | link | EllesmereUI MythicTimer |  |
| Keystone | Auto-insert keystone | toggle |  | On | none | has | EllesmereUI QoL |  |
| Keystone | Report new keystone | toggle |  | On | none | has | EllesmereUI QoL |  |
| Keystone | Share keystones with the party | toggle |  | On | none | has | EllesmereUI QoL |  |
| Keystone | Party keystones window | toggle |  | On | live | has | EllesmereUI QoL |  |
| Keystone | Teleport buttons on dungeon list | toggle |  | On | live | new | EllesmereUI QoL | S28 |
| Parity: EllesmereUI MythicTimer | Run summary window (spec, item level, score, loot, DPS, interrupts, deaths) | — | C_DamageMeter session data is readable after combat |  | live | new | EllesmereUI MythicTimer | S28 |

## Encounters  (`Encounters`)

*Now 64 (Forever 9) → target 77* · has 63 · part 7 · new 7 · link/api 5

**How:** Restyles Blizzard Boss Timeline + warnings (C_EncounterTimeline), BigWigs bars style

**References:** Phoenix S3 already deep · EUI none (EUI has no boss mod)

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Encounters (already deep; small adds) | Existing 61 settings | — | timeline bars, warnings, countdown voice, pull timers, role filters, fonts |  | live | has | BigWigs |  |
| Encounters (already deep; small adds) | Bar grow direction | dropdown | Up / Down | Down | live | has | BigWigs |  |
| Encounters (already deep; small adds) | Per-spell colour override | list | spell IDs → colour |  | live | api | BigWigs |  |
| Encounters (already deep; small adds) | Private aura sounds | list | aura → sound |  | none | api | BigWigs |  |
| Encounters (already deep; small adds) | Test encounter | button |  |  | world | has | BigWigs |  |
| Parity: EllesmereUI QoL | Battle-res charges and bloodlust / sated tracker icons | — | C_Spell.GetSpellCharges(20484) gives the shared battle-res pool in encounters |  | live | new | EllesmereUI QoL | S21 |
| Parity: BigWigs | Boss bars: style, emphasize anchor, icons, spell indicators, custom anchors, test bars | — | Phoenix bars cover size, texture, colour, emphasis; a separate emphasize anchor and spell indicators do not |  | live | part | BigWigs | S21 |
| Parity: BigWigs | Boss messages: font, icons, class colours, chat-frame copy, test | — |  |  | live | part | BigWigs | S21 |
| Parity: BigWigs | Pull timer: countdown type, sounds, combat log on pull, keybind | — | Pull timer and voice exist; pull sounds / keybind / auto log do not |  | live | part | BigWigs | S21 |
| Parity: BigWigs | Sounds per alert type (on you, under you) | — | Private aura sounds stay impossible (gap row, api since S16) |  | live | part | BigWigs | S21 |
| Parity: BigWigs | Track chosen auras on chosen players (tank indicator, emphasize) | — | Other players' auras are secret in encounters; only display sinks are possible (verify) |  | live | new | BigWigs | S21 |
| Parity: BigWigs | Boss-ability icons and text on nameplates | — |  |  | live | new | BigWigs | S21 |
| Parity: BigWigs | Proximity display | — | UnitPosition returns nil for group members inside instances since 7.1; no distance data |  | — | api | BigWigs |  |
| Parity: BigWigs | Battle-res charges display | — | Same feature as the EUI battle-res tracker (one owner) |  | live | new | BigWigs | S21 |
| Parity: BigWigs | Block boss emotes, movies, talking heads, tracker, popups, music during encounters | — | Talking heads hide exists (Quality); the rest does not |  | live | part | BigWigs | S21 |
| Parity: BigWigs | Boss kill / wipe statistics, fastest victory | — |  |  | live | new | BigWigs | S21 |
| Parity: BigWigs | Victory sound / message, wipe sound, respawn bar | — |  |  | live | new | BigWigs | S21 |
| Parity: BigWigs | Auto raid icons on boss targets | — | Needs per-boss data; SetRaidTarget is flagged HasRestrictions in the 12.x API docs, so marking is limited to what it allows (in-game check) |  | live | new | BigWigs | S21 |
| Parity: BigWigs | Per-boss modules: Midnight raids (The Voidspire, The Dreamrift, March on Quel'Danas, The Venomous Abyss, Kith'ix, Sporefall, Nymrissa) and world bosses | — | Phoenix shows every timeline event and warning the game sends; per-boss names, counts and sounds are S21. The three world bosses have no game timeline in BigWigs either |  | live | part | BigWigs | S21 |
| Parity: BigWigs | Per-boss modules: legacy raids (Classic … The War Within) | — | These modules are built on combat-log events (self:Log on SPELL_CAST_START etc.); Phoenix never reads the combat log on 12.x (Core/Events.lua refuses it) and spell IDs in it are secret in instances. BigWigs still ships them for 12.1, so whether they fire in old instances is an in-game check; if they do, this becomes a scope decision, not an API wall |  | — | api | BigWigs |  |
| Parity: LittleWigs | Per-boss modules: Midnight dungeons, delves and the current Mythic+ rotation | — | Timeline events and warnings shown generically; per-boss tuning is S21 |  | live | part | LittleWigs | S21 |
| Parity: LittleWigs | Per-boss modules: legacy dungeons (Classic … The War Within) | — | Same as the BigWigs legacy modules (combat-log based) |  | — | api | LittleWigs |  |

## PvP  (`PvP`)

*Now 10 (Forever 10) → target 5* · has 4 · part 0 · new 1 · link/api 4

**How:** Battleground / arena helpers; arena frames live in Unit Frames

**References:** sArena 416 (arena frames — goes to Unit Frames › Arena) · WindTools Combat 33

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| PvP | Safe queue | toggle |  | On | none | has | sArena Reloaded |  |
| PvP | TAB targets players | toggle |  | On | none | has | sArena Reloaded |  |
| PvP | /gg to surrender | toggle |  | On | none | has | sArena Reloaded |  |
| PvP | Auto release in battlegrounds | toggle | (moved from Automation) | On | none | has | sArena Reloaded |  |
| PvP | Battleground score on top bar | toggle |  | On | live | link | sArena Reloaded |  |
| PvP | Healer marker on enemy plates | toggle |  | On | live | api | sArena Reloaded |  |
| PvP | Arena prep: enemy specs | toggle |  | On | live | link | sArena Reloaded |  |
| PvP | Dampening display | toggle |  | On | live | api | sArena Reloaded |  |
| Parity: sArena Reloaded | Shadowsight timer and gladiator tracker | — | Dampening % stays impossible (the gap row Dampening display is api since S16) |  | live | new | sArena Reloaded | S18 |

## Sim  (`Sim`)

*Now 11 (Forever —) → target 8* · has 7 · part 1 · new 0 · link/api 0

**How:** Simulationcraft export + uploader results (S2)

**References:** simc addon (Unlicense)

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Sim | Fight style | dropdown |  |  | none | has | Simulationcraft |  |
| Sim | Targets | slider |  |  | none | has | Simulationcraft |  |
| Sim | Fight length (seconds) | slider |  |  | none | has | Simulationcraft |  |
| Sim | Use results for (days) | slider |  |  | none | has | Simulationcraft |  |
| Sim | Sim results | toggle |  |  | none | has | Simulationcraft |  |
| Sim | Arrow from sim results | toggle |  |  | none | has | Simulationcraft |  |
| Sim | Include bags / bank / vault / catalyst options | toggle | 4 | bags+vault | none | part | Simulationcraft | S28 |
| Sim | Top gear candidates list | list |  |  | live | has | Simulationcraft |  |

## Diagnostics  (`Diagnostics`)

*Now 9 (Forever 9) → target 3* · has 0 · part 3 · new 0 · link/api 0

**How:** Status page (secret state, conflicts, versions) — exists as a page, not settings

**References:** —

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Diagnostics | Conflicting addons report | button |  |  | none | part | BugGrabber + BugSack | S26 |
| Diagnostics | Secret restrictions now (combat/instance) | — | read-only |  | live | part | BugGrabber + BugSack | S26 |
| Diagnostics | Reload / reset all | button |  |  | none | part | BugGrabber + BugSack | S26 |

## Auction House  (`AuctionHouse`)

*Now 0 (Forever 0) → target 4* · has 0 · part 0 · new 4 · link/api 0

**How:** New page (S22): shopping lists, price history from ReplicateItems, undercut and cancel lists; every search, post and cancel is your click

**References:** Auctionator

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Parity: Auctionator | Auction house: auto scan and interval, small tabs, crafting info in professions | — | C_AuctionHouse.ReplicateItems scan once per 15 min; crafting costs from C_TradeSkillUI |  | live | new | Auctionator | S22 |
| Parity: Auctionator | Shopping lists and searches | — | Each search needs a hardware event (button click) |  | live | new | Auctionator | S22 |
| Parity: Auctionator | Selling: bag view, undercut rules, durations, quantities, shortcuts | — | Posting needs a hardware event per auction (C_AuctionHouse.PostItem); one click per post |  | live | new | Auctionator | S22 |
| Parity: Auctionator | Cancel undercut auctions scan | — | Each cancel needs a click |  | live | new | Auctionator | S22 |

## Loadouts  (`Loadouts`)

*Now 0 (Forever 0) → target 1* · has 0 · part 0 · new 1 · link/api 0

**How:** New page (S28): per-spec / per-instance loadouts that switch profile, talents and gear set (out of combat, your confirmation)

**References:** EllesmereUI LoadoutManager

| Group | Setting | Type | Range / choices | Default | Preview | Status | Source addon | Stage |
|---|---|---|---|---|---|---|---|---|
| Parity: EllesmereUI (core pages) | Loadout manager: talents + gear set per instance, auto-swap, warn on change | — | C_ClassTalents.LoadConfig and C_EquipmentSet.UseEquipmentSet work out of combat; swaps queue until combat ends |  | live | new | EllesmereUI (core pages) | S28 |
