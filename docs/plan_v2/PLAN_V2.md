# Phoenix UI — Plan v2 (2026-10-22)

Written by the research worker. Docs only — no code changed; another worker owns code in /workspace/Phoenix_UI (bug fixes + Bugs rebuild).

Companion files: `GAP_MATRIX.md` (every setting: type, range, default, preview, status), `research/` (one note per I:\ addon + NPC_DATA.md), `mockups/` (5 rendered screens), `data/` (extractors, spec source, counts).

## 1. Why Phoenix feels ~1% complete

- **It skins Blizzard frames instead of owning them.** Edit Mode owns size, rows, spacing and position of action bars and unit frames, so Phoenix can only change fonts, borders and colours. EllesmereUI owns its frames (secure bar containers that hold Blizzard buttons; `SecureUnitButtonTemplate` unit frames), and that is what unlocks per-bar size/rows/spacing, text slots, absorbs, class power, portraits and indicators.
- **Depth today vs target:** Phoenix has **455** settings. The v2 target is **1,186** (EllesmereUI has 2,420 controls across more modules). Of the target rows, 393 already exist, 49 exist only in a shallower form and 744 are missing.
- **The settings window is flat.** It has one page per module and no per-element switcher, no copy/apply-to-all, and no section gates. Its preview is not tied to states such as cooldown, range or combat.

## 2. Settings now vs target (per module)

*Historical (first plan v2 baseline). Current numbers: [GAP_MATRIX.md](GAP_MATRIX.md) — after the I:\\ parity audit (22 Oct 2026) 1,326 target rows: 1,065 has, 137 part, 124 new, 40 link / api; per-addon parity in [PARITY.md](PARITY.md).*

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

*Shipped 22 Oct 2026: Group Finder 57 settings on retail (target 14); not on Forever (no Blizzard_GroupFinder
list there). Filtering dims instead of removing (writing Blizzard's results taints the list); the game's advanced
filter does the real removal. "Remember sign-up note" is not possible (Blizzard's note box refuses SetText from
addons) and role checks are accepted by a key press, never on their own. Needs an in-game test (TESTING §13m).*

- Filter panel + Phoenix expression syntax (re-implemented, not PGF code) — 2.5 d
- Helpers: one-click sign up, remember note, role/class icons, score tooltip, lockout hint, role-check accept — 1.5 d

### S16 — Remaining modules (~11 days)

*Shipped 22 Oct 2026: every page meets its target on retail (gap matrix re-audited against the shipped pages: 1,160
target rows, 1,065 has, 57 part, 38 new; 26 rows left the targets as `link`, owned by another page or Edit Mode, or
`api`, impossible in 12.x; 1,820 settings on retail, 1,646 on Forever). Damage Meter keeps bar size, class colours, value format and the second window in Edit Mode (linked); auto
release stays in Automation with a link from PvP; Mythic+ teleport buttons are not built (no verifiable,
licence-clean spell list). Settings window consistency pass: one owner per CVar, shadow size on every border, Content
sub-headings. Needs an in-game test (TESTING §13n).*

- Damage Meter restyle depth (bars, fonts, formats, second window) — 2 d
- Combat Text: Phoenix scroll areas for own events — 1.5 d
- Mythic+: chest timers, affixes, death breakdown, party keys window, teleports — 2 d
- Movers: Blizzard frame list (move/scale) + snap to frames, nudge, unlock keybind — 2 d
- QoL + Automation adds (banners, camera, markers bar, cursor, CVar browser, auto loot, gossip, role check) — 1.5 d
- PvP adds, AFK screen, Spell History border/fail marks, Sim inclusion toggles, Encounters adds — 2 d

### S17 — NPC locations + the open gap rows (~5 days)

*Re-scoped 22 Oct 2026 (brief): no uploader channel or Cloudflare backend. The collector is local and opt-in; data is
merged by `tools/` into Phoenix_UI_Data slices by the maintainer.*

*Shipped 22 Oct 2026: NPC slices (712 Midnight, 987 War Within, 2,113 Forever spots from ATT), one NPC index for
search, `/way`, tooltips and townsfolk / rare pins, the local collector and its merge tool. Of the 36 open gap rows,
23 are `has`, 4 `link` (click casting, minimap scale, group finder tooltip, per-character overrides → Profiles ›
Characters), 5 `api` (buff bar smooth and stack fill, remember chat channel, hide combat log tab, group finder eye)
and 4 move on (world map reveal S25, raid progression S24, skyriding vigor S24, Mythic+ teleports S28). Gap matrix:
1,321 target rows, 1,088 has, 141 part, 92 new, 49 link/api; 1,869 settings on retail, 1,693 on Forever. Needs an
in-game test (TESTING §13o).*

- NPC spawn data: AllTheThings (MIT) `N|npcID|uiMapID|x|y` lines + DB2 (wago.tools) + runtime APIs → NPC slices in Phoenix_UI_Data; provenance in docs — 1.5 d
- Opt-in position collector: npcID + uiMapID + your x/y on gossip / quest dialog / vignette, only when nothing is secret, out of combat, open world; no names, realms or GUIDs; SavedVariables → `tools/` merge — 1 d
- Wire NPC locations into tooltips, quest pins and map search / `/way` waypoint (one owner: Quests) — 1 d
- Close the 36 open `new` gap rows as far as the API allows (power colour overrides, group dispel colours, buff-bar smooth fill / gradient, class power pip shape, …; the audit already closed charge count at 0 and mana regen spark as `api`) and the parity features tagged S17 — 1.5 d

## 5b. Stages from the I:\ parity audit (S18–S28)

Added 22 Oct 2026 after auditing every addon on I:\ ([PARITY.md](PARITY.md): 315 features, 96 done, 90 partial,
97 missing, 16 impossible, 16 skipped). In [GAP_MATRIX.md](GAP_MATRIX.md) 180 of the open ones became new rows with their
source addon and stage, and 11 that were already spec rows were folded into them (two of those, charge count at 0 and
mana regen spark, are now `api`). One owner page per feature; the stage follows the owner.

**Live-preview rule for every stage below:** each new or deepened setting redraws the pinned preview and any
unlocked / test frames in the same frame it changes (no reload, no lag); the preview uses the same code path as the
real frame, so what you see is exactly what you get (100% accurate). Behaviour-only settings show a live example
(sample tooltip, sample message, sample bar) instead. Secret values are shown in previews with plain test data.

### S18 — Unit Frames II + arena (sArena parity), resource bars, totems, quick focus (~8 days)

*Shipped 23 Oct 2026: Unit Frames 359 settings on retail, 314 on Forever (no arenas there); Cast Bars 105 / 115;
PvP 18 / 10. Arena frames with 9 layouts, 2–5 test frames, DR and PvP trinket taken from the game's own trackers
(Blizzard's DR tray fed by the secret DR events, `CcRemoverFrame`) and restyled, racials on seen casts, class icon
auras, widgets, secure click actions and arena pets; a detached resource block with spec bars; a Phoenix totem bar with
secure right-click destroy; quick focus, nicknames, frame look rows; standalone GCD bar, swing labels and range cue;
Shadowsight timer. No sArena code (no licence file). Of the 29 S18 parity features 25 are done and 4 partial (3D
portraits, regen spark, gladiator tracker, Masque for arena). Gap matrix: 1,297 target rows, 1,100 has,
120 part, 77 new, 49 link/api; 2,029 settings on retail, 1,800 on Forever. Needs an in-game test (TESTING §13p).*

- Arena frames: 9 layout presets, class icon with CC / defensive auras, DR tracker from the game's DR events (look: borders, text, size), trinkets and racials, arena pet frames, widgets (healer / target / focus), range, click actions (secure), cast bar extras — 4 d
- Resource bars: detached player health / power (personal resource display), class power look (orientation, separators, pip borders, charged colour, thresholds), spec bars (Ironfur, Ignore Pain, Sweeping Strikes), totem bar with click-to-destroy (secure) — 2.5 d
- Frame look: nicknames, fade, threat %, portraits (2D / 3D / class, rings), text bar strip; modifier-click focus with marker; GCD bar and swing timer as standalone bars; Shadowsight / dampening on PvP — 1.5 d
- *Preview:* arena test frames (3 / 5 enemies with fake DR, trinket, casts) and resource bars for every class you pick in the preview.

### S19 — Group Frames II (~4 days)

- Absorb overshield / glow line / heal absorb / max-health reduction; indicators (missing buffs, status, group numbers); portraits; party target frames; friendly boss frames; top name strip — 2.5 d
- Assigned buff / debuff lists with order and placement (also for player aura bars); buff manager (own only, pandemic border, threshold text) — 1.5 d
- *Preview:* test party / raid 5 / 20 / 40 with fake auras, absorbs and dispel types.

### S20 — Cooldown Manager & reminders II (~4 days)

- Icon look (shape, zoom, stack text, item count / quality, numbers-only); rotation-assist icon (C_AssistedCombat) with keybind; glow conditions (stacks, combat, hero talent); per-spell overrides — 2 d
- Buff bar groups (named, auto-add, shift when empty), stack-based fill, smooth bars; focus interrupt reminder on the plate — 1 d
- Reminders: custom spells and sounds, pets (missing / passive / wrong demon), soulstone, movement-cooldown alert with TTS — 1 d
- *Preview:* the viewer with sample spells per spec, glows firing on a loop, bars counting down.

### S21 — Encounters II: per-boss data (~6 days)

- Phoenix-authored per-boss tables for Midnight raids, dungeons and delves (ability names for counts, sounds, nameplate icons; colours stay by severity, spell IDs are secret), built from the Encounter Journal API and in-game logs, never copied from BigWigs — 3 d
- Bars / messages depth (emphasize anchor, class colours, chat copy), alert sounds by type, block emotes / movies / talking heads during encounters, victory / wipe sounds, respawn bar, kill / wipe statistics — 2 d
- Battle-res charges and bloodlust / sated icons, alternate (encounter) power, auto raid icons where SetRaidTarget allows, share encounter settings — 1 d
- *Preview:* a scripted fake encounter (timeline bars, warnings, nameplate icons) playing on a loop.

### S22 — Auction House (new page, ~5 days)

- Price database from ReplicateItems scans (no hardware event), price lines in tooltips (auction / vendor / disenchant) — 1.5 d
- Shopping lists and saved searches, selling view with undercut rules and durations, cancel-undercut list — 3 d. Every search, post and cancel is your click (hardware event); Phoenix only prepares them.
- Forever: the same where its auction API matches — 0.5 d
- *Preview:* sample price tooltip and a mock selling row update instantly with your undercut rule.

### S23 — Bags & items II (~4 days)

- Bag grid extras (item level, track rank, warbound / BoE label, set name), list view, category sidebar, pinned / recent items, custom categories, merge stacks, gold history — 2.5 d
- Character / inspect sheet extras (stat letters, enchants, durability, crests, season panel), crest upgrade calculator — 1.5 d
- *Preview:* a mock bag with sample items in each category and a sample character sheet.

### S24 — Skins, chat & tooltips II (~4 days)

- Chat sidebar with icon buttons, tabs in the panel, restore last lines after /reload — 1 d
- Skins: widget bars, extra action / queue pop-up with timer, skyriding vigor and speed bar, friends list, merchant list / wider merchant, mail contacts, chat bubbles (open world only), third-party skins — 2 d
- Tooltips: unit buffs as icons, raid / M+ progression, tier set count, icons — 1 d
- *Preview:* sample chat window, sample tooltip, sample vigor bar.

### S25 — Maps, quests & navigation II (~5 days)

- Quest tracker: sorting, filters, auto-track zone quests, completion sounds, text tweaks, switch buttons, achievement tracker, prey hunt helper — 2 d
- Quest icons by type and limits, quest tooltips on NPCs (chains, breadcrumbs), auto reject shared quests, My Journey (quest history) — 1.5 d
- World map: fade while moving, reveal with coloured fog, zone levels, event timers; flight timer bar and travel pins from DB2 TaxiNodes / AreaPOI; minimap addon-button bar extras — 1.5 d
- *Preview:* sample tracker with live font / colour changes; map preview with sample pins.

### S26 — QoL, automation, movers, tooltip IDs (~5 days)

- Movers for the remaining Blizzard frames (MoveAny list), drag / scale keys, clamp, remember positions — 1.5 d
- QoL: cursor ring / trail / GCD circle, crosshair, potion / talent alerts, party-mode celebrations, gamepad mode, raid tools window, exit phase diving, spell-alert opacity, CVar editor depth, auto combat logging — 2 d
- Automation: train all, open containers, invite on keyword, confirm summon; opt-in automatic role-check accept (CompleteLFGRoleCheck is allowed) — 1 d
- Tooltip IDs: the 19 idTip kinds Phoenix lacks; action-bar animations, crafted-quality pips, radial action menu — 0.5 d
- *Preview:* movers show their real frames' outlines; cursor and crosshair preview follows the mouse in the settings window.

### S27 — WoW Forever essentials (~4 days)

- Highest rank on bars after training, threat meter, stance / form / aspect icon, junk window, auto companion pet, loot feed, macro manager, fishing helper, gathering skill in tooltips, shorter stat lines — 4 d
- *Preview:* Forever-only; sample threat bars and loot feed lines.

### S28 — Profiles & loadouts, damage meter, data texts, M+, nameplates II, group finder II, spell history II (~6 days)

- Loadouts page (talents + gear set per instance, warn on change; switching only out of combat, after your confirm) — 1 d
- Damage meter window / bar depth, combat timer with history, spell history as bars; spell history for party / arena / target / focus with tooltips and blocklist — 1.5 d
- Data texts: experience bar extras, data bar blocks, game bar; micro / bag / reputation bar layout; dark mode amount and glow parameters — 1 d
- M+ run summary window; enemy cast bars (with the cast-target limit); nameplate colours by your debuffs and caster / boss types — 1.5 d
- Group finder: compact entries, more filter variables, applications counter, not-queued reminder, role bar — 1 d
- *Preview:* sample meter with fake combat, sample data bar, sample listing rows.

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
4. **Community collector (S17):** approve the opt-in consent text, Cloudflare storage and CC0 publication. Until then, ship only the toggle as 'coming soon', or nothing. *(22 Oct: S17 builds the local collector only; no upload.)*
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
