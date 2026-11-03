# 01 · EllesmereUI (core + 20 modules)

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\EllesmereUI*` (core, Options and 20 module folders, including WindTools with 326 Lua files). Licence: all rights reserved, so this is a **look and behaviour reference only**. The measurements are in ELLESMERE_REBUILD_MAP.md and AUDIT_T213.md.

## Parity by module
| EUI module | Phoenix home | Status | Note |
|---|---|---|---|
| Options window (rail, header tabs, footer) | Phoenix_UI_Options | have | specs/001 and 002 shipped the 295 rail, 40 tab bar, 50 px rows and global pages |
| UnitFrames | UnitFrames (257 rows) | partial | The previews are **empty** (screenshot), and the tag help line overflows |
| RaidFrames | GroupFrames (193) | partial | The preview is empty; there is a RELOAD badge |
| Nameplates | NamePlates (140) | have | — |
| ActionBars (+XP/rep bars) | ActionBars (113) | have | — |
| CooldownManager | **Phoenix_UI_Tracker** (107) | partial | The folder name "Tracker" is misleading (it is the CDM); the header text is truncated and the bottom rows are cut by the footer |
| ResourceBars | UnitFrames › Resources | partial | It lives inside UnitFrames rather than on its own page; decide in spec 004 |
| AuraBuffReminders | Auras (57) | **missing** | There are no buff reminders (missing flask, food, rune or class buff) |
| Bags | Bags (39) | have | The Home "Bags" card is clipped |
| Chat | Chat (56) | have | — |
| DamageMeters | DamageMeter (86) | have | — |
| DataBars | Data / DataTexts (70) | partial | The bar is crowded and overlaps the action bar and chat (screenshot) |
| Friends | Skins › Phoenix friends window | partial | Friends is buried under Skins |
| GroupFinder | GroupFinder (59) | have | See 07 |
| Minimap | Minimap (56) | have | — |
| MythicTimer | MythicPlus (36) | have | — |
| QoL | Automation (102) + QoL | partial | "Combat" text is clipped in the preview; Automation and QoL overlap (see INDEX) |
| QuestTracker | Quests › Objective tracker | have | — |
| BlizzardSkin | Skins (69) | partial | Skins also moves windows, which duplicates Movers (see 04) |
| Quickdraw (macro/keybind helper) | — | **missing** | — |
| ForeverEssentials | Forever-specific modules | partial | Check row by row in spec 004 |
| WindTools (326 files) | partly spread around | partial | Pick the useful features (see the REBUILD_MAP list) |

## Where Phoenix must be *better*, not equal
1. **Live previews** on every frame page (EUI shows real frames; ours are empty or grey placeholders).
2. **No RELOAD badges.** Constitution IV says "every setting live", but the Buffs, Cast Bars and Group Frames "drawn by" rows still carry them. Make them live or move them to an explicit swap action.
3. **Search plus the cog for advanced rows** (FoldAdvanced) on every page; EUI has no search across pages.
4. **One layout model** (INDEX §2); EUI also mixes its unlock mode with Edit Mode.
5. **Onboarding:** first-run module picker, What's new (built) and a Home that fits at 100 % scale.

## Fixes found (screenshots)
See 15-gui-screenshots.md (H1–H6, S1–S2, P1–P4).
