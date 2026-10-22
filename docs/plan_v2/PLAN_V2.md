# Phoenix UI — Plan v2 (2026-10-22)

Written by the research worker. Docs only — no code changed; another worker owns code in /workspace/Phoenix_UI (bug fixes + Bugs rebuild).

Companion files: `GAP_MATRIX.md` (every setting: type, range, default, preview, status), `research/` (one note per I:\ addon + NPC_DATA.md), `mockups/` (5 rendered screens), `data/` (extractors, spec source, counts).

## 1. Why Phoenix feels ~1% complete

- **It skins Blizzard frames instead of owning them.** Edit Mode owns size, rows, spacing and position of action bars and unit frames, so Phoenix can only change fonts, borders and colours. EllesmereUI owns its frames (secure bar containers that hold Blizzard buttons; `SecureUnitButtonTemplate` unit frames), and that is what unlocks per-bar size/rows/spacing, text slots, absorbs, class power, portraits and indicators.
- **Depth today vs target:** Phoenix has **455** settings. The v2 target is **1,186** (EllesmereUI has 2,420 controls across more modules). Of the target rows, 393 already exist, 49 exist only in a shallower form and 744 are missing.
- **The settings window is flat.** It has one page per module and no per-element switcher, no copy/apply-to-all, and no section gates. Its preview is not tied to states such as cooldown, range or combat.

## 2. Settings now vs target (per module)

| Module | Now | Target | Missing | Has % |
|---|---:|---:|---:|---:|
| Action Bars | 33 | 114 | 82 | 28% |
| Cooldown Text | 3 | 12 | 11 | 8% |
| Cooldown Manager | 28 | 59 | 31 | 47% |
| Unit Frames | 41 | 150 | 121 | 19% |
| Group Frames | 18 | 68 | 53 | 22% |
| Nameplates | 59 | 100 | 48 | 52% |
| Cast Bars | 23 | 55 | 35 | 36% |
| Buffs & Debuffs | 15 | 41 | 26 | 37% |
| Combat Text | 16 | 26 | 10 | 62% |
| Damage Meter | 2 | 31 | 29 | 6% |
| Spell History | 6 | 12 | 6 | 50% |
| Chat | 17 | 51 | 39 | 24% |
| Minimap | 5 | 41 | 39 | 5% |
| Tooltips | 29 | 45 | 20 | 56% |
| Bags | 6 | 47 | 42 | 11% |
| Item Level | 4 | 19 | 15 | 21% |
| Data Texts | 35 | 47 | 33 | 30% |
| Skins | 3 | 28 | 25 | 11% |
| Appearance & General | 7 | 23 | 16 | 30% |
| Profiles | 0 | 8 | 8 | 0% |
| Layout (Movers) | 3 | 11 | 8 | 27% |
| Quality of life | 4 | 11 | 7 | 36% |
| Automation | 8 | 14 | 7 | 50% |
| AFK screen | 1 | 4 | 3 | 25% |
| Bugs | 9 | 12 | 3 | 75% |
| Quests | 0 | 27 | 27 | 0% |
| Group Finder | 0 | 14 | 14 | 0% |
| Mythic+ | 10 | 32 | 22 | 31% |
| Encounters | 61 | 65 | 4 | 94% |
| PvP | 3 | 8 | 4 | 50% |
| Sim | 6 | 8 | 2 | 75% |
| Diagnostics | 0 | 3 | 3 | 0% |
| **Total** | **455** | **1186** | **793** | **33%** |

*Missing* = new + partial rows. Counts expand composite controls (a font group = 5 rows). Per-bar and per-unit groups are counted once.

## 3. Architecture decision (needs the user)

**Recommended:** Phoenix-owned frames for Action Bars, Unit Frames and Group Frames, with a *Blizzard frames* mode kept as a fallback toggle.
- **Action Bars:** `SecureHandlerStateTemplate` containers re-parent `ActionButton1–12`, `MultiBar*Button*` (allowed; that is how Bartender and EllesmereUI work). Paging and visibility use `RegisterStateDriver`. Layout changes are queued out of combat (`InCombatLockdown`).
- **Unit Frames:** `SecureUnitButtonTemplate` + `PingableUnitFrameTemplate`. All values reach the screen through secret-safe sinks: StatusBar `SetValue`/`SetMinMaxValues`, `AbbreviateNumbers`, `UnitHealthPercent` with `C_CurveUtil.CreateColorCurve` for gradients, `CreateUnitHealPredictionCalculator` for absorbs/prediction, and `C_CurveUtil.EvaluateColorValueFromBoolean` for range fade (`UnitInRange` is secret). No arithmetic or comparisons on secrets.
- **Group Frames:** `SecureGroupHeaderTemplate`.
- **Nameplates, tooltips, chat, minimap, bags** stay restyles of Blizzard frames. They are already deep enough that way, and that is how EllesmereUI handles them too.

## 4. Settings window redesign (mockups in `mockups/`)

| Mockup | Shows |
|---|---|
| `1_actionbars.png` | Module page: page tabs (Layout · Buttons · Text · Visibility · Paging · Extra bars), element chips (Bar 1–8, Pet, Stance) with Copy from / Apply to all, two-column cards with section gates, ⇄ apply-to-all icons, pinned preview with state chips (Normal / On cooldown / Out of range / No power / Proc / Mouseover fade) |
| `2_unitframes.png` | Unit chips (Player … Arena), Health tab, absorbs card, text-tag editor with tag pills, preview with target + enemy + cast bar + kick tick + ToT, state chips (Hostile / Friendly / Tapped / Dead / Casting / Low health) |
| `3_nameplates.png` | Colours tab, role-aware threat colours, preview of four plates in secure / losing / lost / execute states with eye toggles |
| `4_home.png` | Home: look presets, module tiles with a depth meter (now → target), health checks, what's new, quick actions |
| `5_layout_mode.png` | In-world Layout mode: grid + snap, every Phoenix frame outlined, selected-element popup (X, Y, anchor, scale, settings, reset, hide), searchable frame list incl. Blizzard frames |

**Window shape.** Default 1280×800, resizable, position remembered. Layout from left to right:
1. Icon rail (64 px) with 7 groups: Home, Frames, Bars, Combat, Interface, Content, Phoenix.
2. Module list (212 px) with depth meters and on/off dots.
3. Content area.
4. Preview dock (380 px). On windows narrower than 1100 px it collapses to a strip above the content.
5. Top bar with global search (Ctrl F), profile switcher, Layout mode, Test frames, close.
6. Footer with save state and pixel-perfect scale.

**Per-tab structure.** Every module follows the same layout:
- Header: title, one-line 'how it's built', setting count, Presets, Reset module, enable switch.
- Page tabs.
- Optional element chips (bars, units, plate types) with Copy from / Apply to all.
- Cards in two columns. Each card has a section gate toggle in its header and two settings per row. Secondary settings sit behind cog popups.

**Preview behaviour.**
- The dock redraws on every setting change.
- Hovering a dropdown item previews it before you pick.
- State chips force sample states.
- Eye toggles show or hide optional elements.
- 'Show in world' opens Test frames through Layout mode.
- Behaviour-only settings show a one-line confirmation in the footer instead of a preview.

**Navigation groups (no duplicates):**
- **Frames:** Unit Frames, Group Frames, Nameplates, Cast Bars, Buffs & Debuffs.
- **Bars:** Action Bars, Cooldown Manager, Cooldown Text.
- **Combat:** Combat Text, Damage Meter, Spell History.
- **Interface:** Chat, Minimap, Tooltips, Bags, Item Level, Data Texts, Skins.
- **Content:** Quests, Group Finder, Mythic+, Encounters, PvP, Sim.
- **Phoenix:** Appearance & General, Profiles, Layout, Quality of life, Automation, AFK, Bugs, Diagnostics.

## 5. Stages (ordered; total ≈ 92 dev-days)

Each feature belongs to exactly one stage. Cross-module features are owned once: cast bars on unit frames → S9 (Unit Frames only provides the anchor); arena frames → S8; reminders → S12; quest automation → S14; auto release → PvP; fonts/borders/shadows → S6 style library.

Already in flight and not re-planned here: Bugs rebuild (other worker), Sim uploader 1.2.0 (waiting for the user's go-ahead).

### S6 — Foundation v2: settings shell + widget kit + style library (~9 days)

- Settings window v2: 1280×800, icon rail + module list + page tabs + element chips + pinned preview dock + footer — 2.5 d
- Widget kit: dual rows, section gate toggle, cog popups, ⇄ apply-to-all, Copy from…, per-row right-click reset, hover-preview dropdowns — 2 d
- Pickers: font cards, texture cards, border/shadow style picker, colour swatch with Class/Theme tokens, sound list with ▶ — 1.5 d
- Shared style library (Core/Style): border styles (Pixel, Thin, Thick, Glow, Ember, Inset), shadows (Soft/Hard/Glow), backdrops — used by every module — 1 d
- Search index over all 1,186 settings (labels, groups, synonyms) with jump-and-flash — 0.5 d
- Profiles page: per-spec profile, per-character overrides, export by module, import with change preview, presets — 1 d
- Appearance & General v2 (global fonts/borders/colours/glow every module inherits) — 0.5 d

### S7 — Action Bars v2 (own secure bars) + Cooldown Text (~8 days)

- Secure bar containers (SecureHandlerStateTemplate) re-parenting Blizzard ActionButtons; Edit Mode bars hidden; fallback to Blizzard bars — 3 d
- Per-bar layout (buttons, rows, size, spacing, grow, order, backdrop, border) + paging + state-driver visibility — 2 d
- Buttons: shape, feedback tints (range / power / unusable via C_ActionBar), pushed/highlight/proc/assist styles, swipe — 1.5 d
- Text: hotkey/macro/count/cooldown fonts & positions; short hotkeys; Cooldown Text module depth — 1 d
- Extra bars: extra action, zone ability, vehicle exit, micro menu, bag bar, extra item bar — 0.5 d

### S8 — Unit Frames v2 (own frames) incl. boss and arena (~12 days)

- Secure unit buttons for player, target, ToT, focus, focus-target, pet, boss1–5, arena1–5; Blizzard-frame mode kept — 3 d
- Health: colour modes, gradient via C_CurveUtil colour curves, dark mode, absorbs / heal absorb / prediction (CreateUnitHealPredictionCalculator) — 2 d
- Power bar + class power (pips, runes, stagger, soul fragments, Ebon Might), detached option — 2 d
- Tag engine (secret-safe sinks: AbbreviateNumbers, UnitHealthPercent+curves, C_StringUtil) + text slots — 2 d
- Portraits, indicators, threat, auras on frames (filters via Blizzard aura flags) — 1.5 d
- Arena: trinket/racial/DR/spec + test frames — 1.5 d

### S9 — Cast Bars v2 + Buffs & Debuffs v2 (~5 days)

- Cast bars for player/target/focus/pet/boss: colours by state, spark, ticks, empower stages, latency, kick-ready tick, spell target, GCD + swing (Forever) — 3 d
- Player buffs/debuffs: layout, sort, separate own, duration formats, colour by time, private aura anchor — 2 d

### S10 — Nameplates depth (~5 days)

- Size/stacking CVars, target scale, non-target alpha, clickable area — 1 d
- Colours: role-aware threat, reaction, quest, execute; target/focus/hover effects — 1.5 d
- Cast bar (kick-ready, target, shield), auras rows, text layouts, class power on target, preview eye toggles — 2.5 d

### S11 — Group Frames v2 (own party/raid headers) (~8 days)

*Shipped 22 Oct 2026: 191 settings on retail, 190 on Forever (target 68); needs an in-game test (TESTING §13h).*

- SecureGroupHeaderTemplate party/raid with 3 size profiles, sorting, role order, pets, MT/MA — 3 d
- Indicators: dispel highlight (only mine), aggro, range, role/leader/ready/summon/res, private aura anchor — 2 d
- Auras: HoT corners, debuff row, big defensive, filters; test raid 5/20/40 — 2 d
- Click casting via Blizzard Click Cast bindings — 1 d

### S12 — Cooldown Manager depth + reminders (~4 days)

*Shipped 22 Oct 2026: 91 settings on retail, 87 on Forever (target 59); needs an in-game test (TESTING §13i).*

- Per-viewer rows/sizes/overflow, keep-in-place, glow styles, keybinds, buff bars — 2.5 d
- Out-of-combat reminders (consumables, raid buffs, pet, healthstone) — 1.5 d

### S13 — Interface modules to full depth (~13 days)

*S13a (Chat, Minimap, Tooltips) shipped 22 Oct 2026: Chat 58 (target 51), Minimap 47 / 45 on Forever (41), Tooltip
54 / 52 (45); needs an in-game test (TESTING §13j). S13b (Bags, Data Texts, Skins) shipped 22 Oct 2026: Bags 53 / 52 on Forever
(target 47), Data Texts 67 / 66 (47), Skins 34 / 32 (28); Item Level's own font row is still open; needs an in-game
test (TESTING §13k). Gap counts are regenerated by `data/gen_gap.py`.*

- Chat: window/backdrop/border, tabs, timestamps, class names, keyword highlight, edit box, chat bar, emotes — 2.5 d
- Minimap: shapes incl. rectangle, elements (zone, clock, coords, difficulty…), button drawer, world map coords — 2 d
- Tooltips: realm, guild rank, targeted-by, inspect ilvl/spec, raid progression, item counts, ID kinds — 1.5 d
- Bags: columns, slot size, categories, slot extras, window, open/close rules — 3 d
- Item Level: inspect, loot/vault/merchant, enchant/gem warnings, upgrade track — 1 d
- Data Texts: per-panel layout, more sources, XP/rep/honor bars — 1.5 d
- Skins: 14 more Blizzard windows — 1.5 d

### S14 — Quests + Phoenix_UI_Data (~9 days)

*Shipped 22 Oct 2026: Quests 38 settings on retail, 36 on Forever (target 27). Phoenix_UI_Data ships the first data
slice (Midnight + The War Within for retail, Azeroth for Forever; sources, accuracy check and the remaining slices
in docs/QUEST_DATA.md). TaxiNodes/AreaPOI and dungeon quests are the next slices; Forever has no turn-in spots (no
QuestPOI data published). Needs an in-game test (TESTING §13l).*

- tools/build_questdata.py: ATT (MIT) + DB2 QuestPOI/TaxiNodes/AreaPOI → packed per-map data; separate load-on-demand Phoenix_UI_Data addon with LICENSE files — 3 d
- Objective tracker restyle (fonts, widths, colours, auto-collapse) — 1.5 d
- Quest helper: waypoint arrow, map pins for available quests (C_QuestLine), turn-ins (QuestPOI), quest NPC pins (ATT data), auto accept/turn-in, reward picker — 4 d
- Opt-in contribution toggle (UI only; collector ships when backend approved) — 0.5 d

### S15 — Group Finder (~4 days)

- Filter panel + Phoenix expression syntax (re-implemented, not PGF code) — 2.5 d
- Helpers: one-click sign up, remember note, role/class icons, score tooltip, lockout hint, role-check accept — 1.5 d

### S16 — Remaining modules (~11 days)

- Damage Meter restyle depth (bars, fonts, formats, second window) — 2 d
- Combat Text: Phoenix scroll areas for own events — 1.5 d
- Mythic+: chest timers, affixes, death breakdown, party keys window, teleports — 2 d
- Movers: Blizzard frame list (move/scale) + snap to frames, nudge, unlock keybind — 2 d
- QoL + Automation adds (banners, camera, markers bar, cursor, CVar browser, auto loot, gossip, role check) — 1.5 d
- PvP adds, AFK screen, Spell History border/fail marks, Sim inclusion toggles, Encounters adds — 2 d

### S17 — Community NPC data collector (needs approval) (~4 days)

- In-game collector (secret-safe, opt-in) + uploader channel + Cloudflare aggregation + CC0 publish into Phoenix_UI_Data — 4 d

## 6. Quests and NPC data (summary of research/NPC_DATA.md)

- **Usable now (licence-clean):**
  - **AllTheThings repo, MIT:** Midnight zones alone have 1,408 quests, 1,938 coordinates and 630 quest-giver NPCs with positions.
  - **Blizzard DB2 via wago.tools, build-time:**
    - QuestPOI: 21,809 quests; 16,348 with a turn-in area.
    - AreaPOI: 3,946 with positions.
    - TaxiNodes: 1,485.
  - **Runtime APIs:** `C_QuestLine.GetAvailableQuestLines` (quest-giver x/y), `C_QuestLog`, `C_TaskQuest`, `C_VignetteInfo`, `C_AreaPoiInfo`, `C_SuperTrack`.
- **Not usable:** Wowhead (ToS), Questie (unlicensed/GPL, Classic), RareScanner and HandyNotes plugins (ARR), TrinityCore/CMaNGOS (GPL, sniffed).
- **Later:** an opt-in Phoenix community collector (S17) to fill gaps between ATT updates.

## 7. Licence notes

| Reference | Licence | Use in Phoenix (MIT) |
|---|---|---|
| EllesmereUI 9.6.1 (all modules) | All rights reserved | ideas only |
| WindTools (EllesmereUI_WindTools) | ElvUI/NDui-only licence | ideas only |
| MoveAny | GPL-3 (GitHub) / ARR (CurseForge) | ideas only |
| PremadeGroupsFilter | GPL-2 | ideas only (re-implement) |
| sArena Reloaded | MIT + ARR for Reloaded parts | ideas only |
| Simulationcraft addon | Unlicense | format reuse OK |
| idTip | BSD-2 | reusable with notice |
| AutoQueue | none (ARR) | ideas only |
| AllTheThings repo | MIT | data extraction OK with notice |

**I:\ attribution:** every addon copy on I:\ has `VortexQ8` inserted into author and licence lines (PGF 56 files, sArena 40, EllesmereUI 17, MoveAny 7, …), and there are no LICENSE files. The original authors' licences still apply. Phoenix ships nothing from these copies.

## 8. Decisions needed (asked)

1. **Own frames:** approve Phoenix-owned Action Bars, Unit Frames and Group Frames (Blizzard mode kept as a fallback). Without this, the depth targets for those three modules can't be met.
2. **Redesign:** approve the window shape and navigation in mockups 1–5 (or ask for changes) before S6 starts.
3. **Quest data:** approve the ATT (MIT) extraction into a separate `Phoenix_UI_Data` addon with an ATT credit. Optionally, ask the ATT team for a written OK.
4. **Community collector (S17):** approve the opt-in consent text, Cloudflare storage and CC0 publication. Until then, ship only the toggle as 'coming soon', or nothing.
5. **Scope cuts:** chat announcements and automatic LFG sign-ups are left out (spam risk). Confirm.
6. **I:\ copies:** confirm they are personal edits. They are not used as a source either way.

## 9. Decisions recorded (2026-10-22)

The user approved plan v2 in full:

1. **Own frames: yes.** Phoenix will own Action Bars, Unit Frames and Group Frames, with a *Blizzard frames* fallback (S7–S9).
2. **Redesign: yes, raise the bar.** Use the mockups as the starting point: "not exactly like EllesmereUI, but similar and even better quality, more polished and professional". Ember identity, a typography hierarchy, a spacing grid, subtle fast motion, one consistent Phosphor icon set (uncompressed 32-bit TGA atlases, edges ≤ 1024), pinned live previews and one widget kit. Shipped in S6.
3. **Quest data: yes.** AllTheThings data (MIT, notice kept) goes in a separate `Phoenix_UI_Data` addon, later.
4. **Community NPC collector: later** (S17, opt-in).
5. **Scope cuts confirmed:** no chat announcements, no automatic group sign-ups.
6. **Publishing:** after a stable release, GitHub is linked to CurseForge and Wago. Until then `.pkgmeta` and the TOC metadata stay ready, and nothing is published.

Not committed here: the extracted third-party reference data (`data/db2` DB2 CSVs, the EllesmereUI and WindTools setting dumps). They were used for counting only, stay outside the repo, and no third-party code is copied into Phoenix.
