# EllesmereUI 9.6.1 (I:\EllesmereUI + 22 module folders)

**Licence:** All rights reserved (Ellesmere). Learn from it; never copy code, textures or strings.
**Altered attribution on I:\:** TOCs read `## Author:  VortexQ8  Ellesmere`.
**Interface:** 120000–120105 + 16001 (WoW Forever).

## How it is built (what makes it "deep")
1. **Owns its frames.** Action bars are `SecureHandlerStateTemplate` containers that re-parent Blizzard's action buttons; unit/raid frames are `SecureUnitButtonTemplate` (+ `PingableUnitFrameTemplate`). Because it owns the frames, every size, spacing, row, border, text slot can be a setting. Phoenix skins Blizzard frames and lets Edit Mode own layout, which caps the depth.
2. **One shared widget kit** (`EllesmereUI_Widgets*.lua`): `W:DualRow` (two settings side by side), `W:SectionHeader`, cog popups for secondary settings, "sync" icon to apply a value to all bars/units, section-gate toggles (turning a section off greys its rows), a live preview at the top of each page, colour swatches with class/theme options, searchable dropdowns with hover preview.
3. **Per-element pages.** Each module has 2–5 pages (tabs at top), each page has a unit/bar selector and sections.
4. **Unlock mode** shared by all modules (grid, snap, nudge, per-element popups).
5. **Profiles**: Profiles / Presets / Overrides / Full export pages.

## Modules, pages and option counts (extracted controls)
| Module | Pages | Controls | Highlights |
|---|---|---:|---|
| ActionBars | Display (bar picker), XP bar, Menu/Bags/Rep, Animations | 124 | per-bar icon size 16–120, spacing −10–20, icons 1–12, rows 1–12, grow, vertical, order; bar background/border style, custom button shape, icon zoom; cooldown numbers; desaturate, range colouring, CD alpha, swipe opacity; paging (form, skyriding, arrows, modifier); keybind/macro/charge text size & position; visibility (spellbook open, drag, mouseover, opacity, click-through, toggle keybind); pushed/highlight animation types, assisted highlight |
| UnitFrames | Display, Boss, Mini frames, Aura bars | 359 | health 15–100 h / 80–400 w, reverse/vertical fill, dynamic & gradient colour, smooth; text slots left/right/center/extra with tag dropdowns, separators, prefixes; power bar; class resource; absorb, heal absorb, heal prediction, overheal; portrait 2D/3D/class, shape, rings, dragon art; indicators; cast bar with kick-ready tick and spell target; buffs/debuffs size/zoom/dispel borders/filters/growth/max/per row; ToT, focus, pet, boss |
| ResourceBars | Bar display, Class resource, Cast bar, GCD/Swing | 252 | detached health/power/class-power bars, thresholds, hash lines, per-spec |
| RaidFrames | Main, Party, Buffs, DM, ClickCast | 258 | layout per group size, sorting, role order, indicators (91 controls), dispel overlay, aura manager pages, click-casting |
| Nameplates | Display, Colors, General | 179 | size/stacking, health/cast/auras, target/focus effects, threat colours, text colouring, class power, quest icons |
| CooldownManager | Bars, Buff bars, Spell picker, Glow conditions | 152 | per-viewer rows, sizes, glow conditions, custom bars |
| MythicTimer | Timer, Targeted spell bars | 125 | |
| BlizzardSkin | Tooltips, popups, character sheet, skyriding | 123 | |
| DamageMeters | | 82 | built on C_DamageMeter |
| QoL (+BattleRes, MovementAlert, Alerts, Cursor, AutoLogging, RaidTools, Shifter, PartyMode, LoadoutManager, UpgradeCalc, Gamepad) | | ~200 | |
| Minimap | | 62 | |
| Chat | | 57 | |
| DataBars | | 55 | XP/rep/honor bars + info bar |
| AuraBuffReminders | | 54 | flask/food/rune/raid buff/talent reminders |
| Bags | | 45 | categories, columns, item level, junk |
| Fonts / Textures / Colors / Glow / General | | ~82 | global defaults every module inherits |
| QuestTracker | | 29 | skin + Forever quest tracker (uses runtime quest APIs, no NPC data) |
| Quickdraw | | 30 | radial menu on a keybind |
| ForeverEssentials (16001 only) | General, Threat, Travel, Loot, Macros | ~80 | Forever spellbook/talents, threat meter, fishing, flight timer, **map travel pins generated from DB2 TaxiNodes / AreaPOI / Map + UiMapAssignment** |
| Friends | | 9 | |
| GroupFinder | | 5 | |

Full per-control dump: `../data/eui_all.txt` (file :: section :: label (type, min–max)).

## Data shipped
Spell ID lists (interrupts, defensives, raid buffs, consumables), M+ dungeon/timer tables, Forever-only map/taxi data **generated from client DB2 with a script** (`.tools/forever-taxi-lengths.py`). No NPC spawn coordinates anywhere in the suite — EUI's QuestTracker is a skin plus runtime Blizzard APIs.

## Design and organisation lessons for Phoenix
- Settings window ~1,100×720 with left module list grouped Core / QoL / Reskin, top page tabs per module, a pinned live preview strip, two-column rows.
- Every module inherits fonts/textures/colours from global pages ("Theme default"), so per-module font rows can stay collapsed.
- Every per-element section has *Copy from* / *Apply to all* (sync icon).
- Section-gate toggle on headers removes clutter.

## Parity audit (22 Oct 2026)

Every feature of this addon now has one Phoenix owner page, a status and a stage in [../PARITY.md](../PARITY.md) (generated by `../data/parity_build.py`).
