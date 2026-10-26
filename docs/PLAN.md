# Phoenix UI — Master Audit and Plan (main-v2 @ c6213ce, updated 2026-10-26 with I:\ competitor study §13 and EllesmereUI deep study §15)

Audit and plan only. No code was changed for this document.
Sources:
- the spec C:\Users\Vorte\Phoenix_UI\PUI_V2.md (copied read-only);
- main-v2 code (448 schema keys from `.tools/harness/schema_dump.lua`, greps, file reads);
- mockups in /workspace/pui_design;
- the plugin design in /workspace/pui_design/plugins.

Status legend:
- **B** = Built: code and schema exist and are tested in the harness.
- **P** = Partial: some of it exists, or it exists without UI/preview/test.
- **M** = Missing.

"In-game verified" is a separate column. Nothing below has been verified in game yet; the harness does not render.

Size legend:
- **S**: up to 1 day.
- **M**: 2–4 days.
- **L**: 1–2 weeks.
- **XL**: more than 2 weeks.

Competitor references describe feature parity only. Behaviour is reimplemented and no code is copied.

---

## 0. One-page summary — the biggest gaps

> **2026-10-26 deep-study correction:** the top gaps are now the 12.1 aura container engine (F1), the Blizzard-viewer CDM model, the per-spec/condition Overrides layer (F2) and Studio v2 anchor/size-match parity (F3). See §15.1 for what changed and §15.4 for the new order.

> **Update 2026-10-26 (competitor study, §13).** Every addon on I:\ was studied (EllesmereUI suite first). Biggest new gaps vs EllesmereUI: global Fonts/Textures/Colors/Glows pages; action-bar appearance/paging/keybind/visibility builder; unit-frame text slots and portraits; raid indicator editor and assigned buff/debuff managers; nameplate slot layout and colour rules; CDM spell picker, buff bars and glow conditions; GCD/swing/totem bars; minimap button collector and data-bar blocks; bag categories; M+ run summary; threat, battle-res, cursor and movement tools; Quickdraw menus. Decisions D1 (Game Menu row inside the Esc menu, taint-safe) and D2 (action-bar defaults = EllesmereUI/ElvUI and beyond) are in §13.D. New phases A+…I+ are in §13.12.

1. **Auras are missing everywhere except raid debuffs.**
   - Unit frames have no buff/debuff containers, no dispel overlay and no Player Aura Bars.
   - Nameplates have no aura lanes.
   - Spec 5.3/5.5 lists auras as Tier 0. Every competitor (ElvUI, EUI, Plater, Cell) has them.
   - This is the single largest parity hole.
2. **Profiles are a single dropdown.**
   - There is no create/copy/rename/delete.
   - There is no export/import string (`!PUI_`): Import and Export are greyed out in the wizard and dashboard.
   - There is no spec→profile auto-switch, no spec overrides and no conditional overrides (spec 5.15).
3. **Unit frames are shallow: 89 keys against roughly 300 settings in the spec and competitors.** They lack:
   - per-unit colours, textures and fonts;
   - portrait shapes/3D;
   - a tag editor (only 13 tags exist; the spec asks for at least 20);
   - cast bar details (empower pips, latency, kick tick, important glow);
   - visibility rules;
   - class resources on the frame.
4. **Nameplates (17 keys) have no rules engine**: no NPC colour rules, no aura lanes, no icon/text slots and no important-cast glow.
5. **Vault has no bank, warband bank, guild bank, category rules engine or offline alts.** It has 6 keys.
6. **Chat is basic (5 keys).** It lacks emoji, history search, per-line copy, spam filter, tab editor and role icons.
7. **Data Bars and Minimap are basic:**
   - 2 fixed bars with 11 blocks; no LDB host, no per-spec sets, no user-created bars;
   - no minimap button flyout or tracking/calendar buttons.
8. **Three Tier 1 modules do not exist**: Pulse (timeline), Arena Frames and Spark (scrolling combat text).
9. **Options are missing the tools that make depth usable:**
   - no colour picker;
   - no keybind capture;
   - no list, rule or aura-picker editors;
   - no per-module CPU readout;
   - no patch notes;
   - only 3 of 28 pages have live previews.
10. **Studio lacks:**
    - resize/scale per element;
    - multi-select, align/distribute and element snapping/guides;
    - per-spec layouts and layout templates;
    - layout export;
    - the Edit Mode hand-off for Blizzard frames.
11. **Locales are about 2% translated** (837 keys; roughly 18 strings per language). Arabic does not exist.
12. **Release pipeline**: no CurseForge/Wago release has been made; there is no `/features`/`/docs` generated from the schema; the plugin system is design-only.

**Recommended order:** Profiles/Export → Auras framework → Unit Frames depth → Raid/Nameplates depth → Options editor widgets → Studio v2 → Vault/Chat/HUD depth → Pulse/Arena/Spark → Locales → Plugins → Release.

---

## 1. Cross-cutting foundations

| # | Feature | Status | Evidence | Gap / parity note | Size |
|---|---|---|---|---|---|
| 1.1 | ClientGate, Kernel, module registry, LoD children | B | Core/Kernel.lua, Core/ClientGate.lua | `loadCondition` re-evaluated on zone/spec/roster: P (Kernel listens to PLAYER_SPECIALIZATION_CHANGED; no per-module conditions UI) | M |
| 1.2 | Schema: every setting has an apply function, Simple/Advanced, search tags | B | Core/Schema.lua, 448 keys | `overridable` flag (spec 8) M | S |
| 1.3 | Ticker (no OnUpdate) and CombatQueue | B | Core/Ticker.lua, Core/CombatQueue.lua | — | — |
| 1.4 | Secret-safe helpers | B | Core/Secret.lua | — | — |
| 1.5 | Profiles: switch | B | Core/DB.lua `SetProfile`, key `core.profile` | — | — |
| 1.6 | Profiles: create/copy/rename/delete UI | M | DB has no Copy/Delete/Rename | ElvUI/EUI have full profile managers | M |
| 1.7 | Spec→profile auto-switch (combat-deferred) | M | none (wizard toggle omitted in PR #14) | EUI, ElvUI (LibDualSpec) | M |
| 1.8 | Spec overrides inside a profile ("Editing as <spec>") | M | — | EUI | L |
| 1.9 | Conditional overrides (party/raid/arena/BG/solo/keybind) | M | — | EUI | L |
| 1.10 | Export/import `!PUI_` (whole, per-module, CDM-only, layout-only), merge/replace, async decode, media reconcile | P | CDM and Embers have their own strings (CooldownManager.lua, Embers.lua); no core serializer | ElvUI/EUI/Wago | L |
| 1.11 | Wago UI Packs installer hook | M | — | ElvUI | M |
| 1.12 | Migrations (scoped, idempotent, stamped) | B | DB:RegisterMigration/RunMigrations | — | — |
| 1.13 | Public APIs: RegisterPlugin/Skin/DataBlock/OracleProvider/VaultRule/NicknameProvider | P | Core/API.lua registries exist; consumers only partly wired (Skins yes, DataBlock/VaultRule unverified) | — | M |
| 1.14 | Data packs with packVersion/gameBuild warning | P | Reminders/Pack.lua, `/pui packs`; no NPC colour, interrupt, portal or crest packs | — | M per pack |
| 1.15 | `conflictsWith` auto-disable for companion addons | M | grep finds none (GroupFinder stands down for PGF ad hoc) | spec 23 | S |
| 1.16 | Accessibility: colour-blind palettes, high contrast, large text, reduced motion, TTS events | M | only `media.fontScale` | spec 22.14 | M |
| 1.17 | Controller/gamepad navigation | M | — | spec 5.17 | L |
| 1.18 | Performance: per-module CPU readout on pages | M | Sentinel Perf.lua samples, not shown in options | spec 8/11 | S |

## 2. Options window (mockups 01–04) and tabs

| # | Feature | Status | Evidence | Size |
|---|---|---|---|---|
| 2.1 | Glass window, header, search with Ctrl K hint and magnifier, Simple/Advanced, profile chip, close | B | Options/Panel.lua | — |
| 2.2 | Ctrl K actually focuses search | P | hint shown; no binding (Oracle owns Ctrl K) | S |
| 2.3 | Grouped sidebar with icons, dots and collapse | B | Panel.lua RenderSidebar, Nav.lua | — |
| 2.4 | Dashboard: hero, module cards, filter, quick toggles, profile card, Sentinel card | B | Dashboard.lua | — |
| 2.5 | Dashboard: "What's new"/patch notes, per-module CPU | M | — | M |
| 2.6 | Module page: header, Move in Studio, Reset, enable toggle, tabs from keys | B | PageView.lua | — |
| 2.7 | Vertical bar list for Action Bars (mockup 03) | M | divergence, PR #13 | S |
| 2.8 | Live previews | P | Previews.lua covers UnitFrames, ActionBars and ResourceBars only. Missing: RaidFrames, Nameplates, CDM, Chat, Tooltip, DataBars, Minimap, Reminders, Embers, Ascent, QuestTracker, Vault | L |
| 2.9 | Pickers with samples for font/texture/sound | B | Widgets.lua dropdown with previews | — |
| 2.10 | Border picker, colour picker (HSV, recents, class/accent swatches) | M | no colour type in the schema | M |
| 2.11 | Keybind capture widget | M | Oracle key is text | S |
| 2.12 | List editor (reorder), rule editor, aura picker, visibility-rule editor, tag editor | M | lists are stored as text keys (`db.bar1.blocks`, `chat.keywords`, `cc.bindings`, `loadouts.rules`, `wisdom.weights`) | L |
| 2.13 | Cog popups / sub-settings per row | M | — | M |
| 2.14 | Deep links (`/pui options <key>` scroll-to/highlight) | P | page/search only | S |
| 2.15 | Theme & Media page | B | ThemePage.lua | — |
| 2.16 | Panel themes (Phoenix/Dark/Class/Faction/Custom) | P | accent and panel material only | S |
| 2.17 | Pixel-pinned options scale | M | — | S |
| 2.18 | Sentinel page (mockup 14) | B | SentinelPage.lua | — |
| 2.19 | Plugins page (mockups P1–P3) | M | design only | (see section 9) |
| 2.20 | Reset all, reset module | P | per-page Reset; no reset-all | S |
| 2.21 | Localised labels at the render boundary | P | PUI.L used in Studio; options labels not wrapped everywhere | S |

## 3. Setup, tour, entry points (mockups 05–11, 13)

| # | Feature | Status | Evidence | Size |
|---|---|---|---|---|
| 3.1 | Welcome, 5 steps, finish, live apply without reload | B | Setup/Wizard.lua | — |
| 3.2 | Import a profile on the welcome page | M | disabled button (needs 1.10) | — |
| 3.3 | Spec auto-switch toggle on the role step | M | needs 1.7 | — |
| 3.4 | PvP/Minimal role cards | P | data in Presets.lua, not shown | S |
| 3.5 | Arabic language card | M | no arAR locale | see 15 |
| 3.6 | Minimal Ash fades out of combat | M | no fade rule | S |
| 3.7 | Role presets set dozens of keys with a before/after preview (spec 22.2) | P | modules on/off and positions only | M |
| 3.8 | Tour (login 2) restyled to the design kit | P | old Theme:Backdrop tour; no mockup | S + mockup |
| 3.9 | Uninstall restores CVars, Edit Mode layout, bindings and chat fonts | P | CVars only | M |
| 3.10 | Game Menu entry inside the menu | P | docked above the menu (taint-safe divergence) | design decision |
| 3.11 | Minimap button: ring, hover card, Shift-click Sentinel, compartment | B | Core/Entry.lua | — |
| 3.12 | Minimap button hide toggle in Quick toggles | B | Dashboard QUICK | — |

## 4. Studio (mockup 12, spec 7, 22.1)

| # | Feature | Status | Evidence | Size |
|---|---|---|---|---|
| 4.1 | Overlay, grid, centre guides, movers with icons, hover names, chips, handles | B | Options/Studio.lua | — |
| 4.2 | Toolbar: filter, snap, grid cycle, undo/redo, reset, save & exit | B | Studio.lua buildToolbar | — |
| 4.3 | Inspector: X/Y, anchor grid, nudge, mirror, settings | B | buildInspector | — |
| 4.4 | W/H edit and per-element scale | M | read-only size; Layout stores only point/x/y | L (Layout schema change + every module reading size/scale) |
| 4.5 | Snap to elements, alignment guides, distance labels | M | divergence | M |
| 4.6 | Side anchors (edge-to-edge), anchor to other elements, connector lines, cycle detection | M | anchors are UIParent-only | L |
| 4.7 | Width/height matching chains | M | — | M |
| 4.8 | Grow direction and orientation per bar | P | module settings exist (cdm growth, rf orientation); not in Studio | S |
| 4.9 | Multi-select, box select, group drag, align/distribute | M | — | M |
| 4.10 | Overlap cycling with the mouse wheel | M | — | S |
| 4.11 | Per-spec and per-condition layouts | M | needs 1.8/1.9 | M |
| 4.12 | Layout templates with thumbnails; apply with scale conversion | P | 3 wizard presets only | M |
| 4.13 | Layout export/import (`!PUI_LAY`) | M | needs 1.10 | S after 1.10 |
| 4.14 | Blizzard-element hand-off to Edit Mode (`C_EditMode`) | M | — | M |
| 4.15 | "Explain this element" (keys driving it) | M | — | S |
| 4.16 | Safe-area/HUD-zone guides | M | — | S |
| 4.17 | Chat, minimap and buff frames as movers | M | not Layout elements | M |

## 5. Module-by-module audit

Each table lists what exists against the spec. "Competitor extra" lists parity items from ElvUI/EUI/Plater/Cell/Bartender/Baganator/Prat/Leatrix that the spec did not already name.

### 5.1 Unit Frames — 89 keys (Phoenix_UI_UnitFrames: UnitFrames.lua, Elements.lua, Tags.lua)

| Feature | Status | Evidence / note |
|---|---|---|
| Units player/target/focus/pet/ToT/FoT/boss1–5; source Phoenix/Blizzard/hidden | B | `uf.<unit>.source`, GROUPS |
| Secure buttons, click-cast registration, menu | B | UnitFrames.lua (verify in game) |
| Width/height/power height/reverse per unit | B | `uf.<unit>.width/height/powerHeight/reverse` |
| Colour mode (class/reaction/custom), fill alpha, smooth | P | global `uf.colorMode`, `uf.fillAlpha`, `uf.smooth`; no per-unit colours, gradient, custom colour picker or dynamic colours |
| Per-unit texture/font/outline overrides | M | global `bars.texture` only |
| Text zones (left/center/right/power) with tags | P | 4 zones per unit; 13 tags (Tags.lua); spec asks ≥20 plus a detached text bar and a user tag editor |
| Portraits | P | `uf.<unit>.portrait` toggle; no 2D/3D/class choice, 8 shapes or zoom |
| Cast bars per unit | P | `uf.<unit>.castbar` with SetTimerDuration; no icon/time/target options, latency, kick-ready tick, uninterruptible shield, important glow or empower pips |
| Absorbs, heal prediction | B | `uf.absorbs`, `uf.healPrediction` |
| Indicators: combat/rested/raid marker/leader/classification/PvP | B | `uf.indicator.*` |
| Class resources on the player frame | M | they live only in ResourceBars |
| **Auras (buffs/debuffs/dispellable/stealable/CC/defensives) via AuraContainer** | **M** | no aura code in UnitFrames |
| Dispel overlay | M | — |
| Player Aura Bars (BuffFrame replacement) | M | — |
| Visibility rules (10 modes compiled to secure drivers) | M | — |
| Blizzard/Classic looks (live) | M | — |
| Range fade on target/focus | M | — |
| Preview with fake units | P | Options preview only (player/target health, cast) |
| Studio elements | B | `uf.player` … `uf.boss` |
| Competitor extra | — | ElvUI: "fader" (combat/target/hover), heal-absorb overlay, pvp trinket/classbar on frame, threat glow, ToT inline, aura filters per unit with priority lists; EUI: aura bars with filtering |

### 5.2 Raid & Party — 23 keys (RaidFrames.lua, Elements.lua) + ClickCast (3 keys)

| Feature | Status | Evidence |
|---|---|---|
| Group headers, party/raid, solo/player show, sort, orientation, spacing, size | B | `rf.*` |
| Health text, colour mode, absorbs, aggro, dispel highlight, healer mana, range fade, role/leader/marker/status icons | B | `rf.*` |
| Private aura slots | P | `rf.privateAuras` (needs in-game verification each tier) |
| Debuff Manager (dispellable/boss/CC/important/custom lists, priority tiles) | P | debuff code in Elements.lua; no list editor or priority tiles UI |
| Buff Manager (spell→indicator corners) | M | — |
| Pet frames, tank duplicates, friendly boss frames, party target buttons | M | — |
| 8 separate headers vs merged; per-group visibility | P | — |
| Click-casting: spell/macro/item/target/menu/focus; hovercast; Clique interop | P | `cc.bindings` (text), `cc.hovercast`; no binding editor UI |
| Smart sort presets (tanks/healers first, by group) | P | `rf.sort` |
| Dead/offline/phased/ghost/summon/res overlays | P | status icons; verify the full set |
| Role-aware default layouts | M | — |
| Preview | M | — |
| Competitor extra | — | Cell/VuhDo/Grid2: corner indicators editor, raid debuff tiles per instance (data pack), buff tracking per role, health gradient colours, mouseover highlight, "spotlight" frames, layout per group size (5/10/20/40) |

### 5.3 Nameplates — 17 keys (Nameplates.lua, Plate.lua)

| Feature | Status |
|---|---|
| Pooled plates, size/scale/stacking, health text, name, cast bar + height, colour mode, threat, execute marker, target highlight, friendly name-only, icons (classification/quest/raid marker) | B |
| **Rules engine (NPC id/name/classification/reaction/threat → colour/scale/alpha/visibility)** | **M** (spec P1) |
| Aura lanes (CC / own debuffs / important buffs) | M |
| Important-cast glow, kick-ready tint | M |
| 6 icon slots / 6 text slots | M |
| Target arrows, class resource on target plate | M |
| Off-tank threat detection (3-tier) | P (`np.threat`; verify off-tank) |
| CVar restore on disable | P (verify) |
| Totem/pet compact plates | M |
| Preview | M |
| Competitor extra | Plater: per-NPC colour tables (importable), cast-target name where public, "focus" indicator, health % colouring thresholds, quest progress text on plate |

### 5.4 Action Bars — 105 keys (ActionBars.lua, Buttons.lua)

| Feature | Status |
|---|---|
| 10 bars: enabled, buttons, per row, size, spacing, scale, fade + alpha, visibility string, paging | B (`ab.barN.*`) |
| Hotkeys, macro text, show empty, tooltips, lock | B |
| Stock bars hidden, state drivers, proc glow, range colouring | P (verify in game) |
| Per-button overrides (size, hide hotkey, text) | M |
| 14 buttons per bar | P (verify the `buttons` max) |
| Quick keybind mode, conflict detection, printable sheet | M |
| Micro menu bar, bag bar, stance/pet/possess/extra/zone/encounter bars | M (no keys) |
| Flyout skinning | M |
| Mouseover/hold-modifier reveal, combat-only | P (visibility string covers part of it) |
| Assisted-combat highlight | M |
| Blizzard/Classic looks | M |
| Extra item bar (quest items/potions/toys) | M |
| Preview | B (icons) |
| Competitor extra | Bartender/Dominos: per-bar alpha/padding/flip, "hide in pet battle/vehicle" presets, cooldown text options, keybind abbreviations |

### 5.5 Cooldown Manager — 22 keys

| Feature | Status |
|---|---|
| Re-anchor Essential/Utility/Buff icons/Buff bars; size/perRow/spacing/growth; preset; CDM share string | B |
| Per-spec stores | P (verify) |
| Unlimited custom bars | M |
| Decorations (shape, border, thresholds, charges, keybind badge, item count) | M |
| Glows (proc/ready/buff active/missing/pandemic) | M |
| Per-spell hide/alpha/desaturate; talent conditions | M |
| Custom additions (trinkets/racial/potion/item) | M |
| Tracking bars reskin with groups/hash lines | M |
| Audio on ready/gain/loss; TTS | M |
| Per-spell import | M |
| Preview | M |

### 5.6 Resource Bars — 18 keys (ResourceBars.lua, ClassResource.lua)

| Feature | Status |
|---|---|
| Health/power/class/cast/GCD/totem bars, heights, width, spacing, smooth, power ticks, hide Blizzard cast | B |
| Swing timer (Forever) | M |
| Thresholds with talent gates, hash lines, spender/buff colouring | M |
| Custom pip shapes/art | M |
| Coverage of 20+ resources | P (ClassResource.lua; verify each class in game) |
| Empower pips, latency on the cast bar | M |
| Preview | B |

### 5.7 HUD: Minimap (7), Tooltip (6), Data Bars (7) — Phoenix_UI_HUD

| Feature | Status |
|---|---|
| Minimap shape/size/clock/coords/zone/hide cluster | B |
| Minimap own tracking/calendar/mail/crafting/difficulty/zoom buttons | M |
| Addon-button flyout (LibDBIcon scan) | M |
| Ping announcer, queue eye with ETA | M |
| Tooltip anchor/combat hide/guild rank/IDs/M+ score | B |
| Tooltip ilvl, mount owned, transmog known, upgrade track, aura source, secret-safe health strip, skin | M/P |
| Data Bars: 2 fixed bars, 11 blocks (clock, fps, latency, location, coords, gold, bags, durability, ilvl, xp, spec) | P |
| User-created bars, layout solver, per-spec sets | M |
| Blocks: professions, travel/hearth, micro menu, currency, crests, vault, audio, friends/guild, mail, CPU, M+ score, LDB host | M |
| Previews | M |

### 5.8 Quest Tracker — 8 keys

- **B:** sort, filter, auto-track zone, auto quest, sound, collapsed, hide Blizzard.
- **M:** quest-item SecureActionButton; Wowhead links; M+ objective collapse; progress colours (verify); auto-share.

### 5.9 Skins — 30 keys

- **B:** 25 window toggles plus Details/Pawn/WeakAuras/Plater toggles.
- **P:** the quality of each pack is unverified in game; Primitives are in Skins.lua. Tooltip/dialog/HUD/chat-bubble skins are not keyed.
- **M:** Questie/Auctionator via Skin API; guild bank skin.

### 5.10 Chat — 6 keys

- **B:** mirror, fade, timestamps, abbreviations, keyword alerts (text list), whisper sound, `/copychat`.
- **M:**
  - emoji (panel + autocomplete);
  - role/class icons;
  - spam filter;
  - per-line copy;
  - searchable history;
  - tab editor;
  - sidebar;
  - edit box position;
  - URL copy (verify);
  - class-coloured names (verify);
  - smart whisper windows;
  - chat bar / smart tab;
  - channel colour editor.

### 5.11 Vault — 6 keys

- **B:** grid/list/compact mode, columns, ilvl, junk, new glow.
- **M:**
  - rules engine and categories with drag-assign;
  - bank/warband/reagent tabs (**deferred**);
  - guild bank;
  - offline alts;
  - sort/merge plan;
  - currencies;
  - keystone shelf;
  - equipment-set builder;
  - sell-junk button (verify);
  - stack splitter.

### 5.12 Flow — 21 keys (spec ~40)

- **B:** repair, sell junk, release, accept res/invites, decline duels/guild, skip cinematics, auto delete, gossip, quick loot, hide errors, hide talking head, durability warn, max camera, combat log, countdown, `/rl`, `/cd`.
- **M (about 19 items):**
  - insert keystone, role-check confirm, leave-queue popups, open containers, Train All;
  - hide tutorials/loot toasts/banners;
  - `/keys`, `/way`, `/gg`, queue protection;
  - Tab binder, dampening display, interrupt announce;
  - raid marker tools, ready check tool;
  - screenshot on achievement;
  - WindTools-harvest list (spec 23).

### 5.13 Reminders — 7 keys

- **B:** raid/class rows, custom, size, sound, text, only grouped (pack data).
- **M:** consumables pack depth, talents by zone, per-reminder sound/icon.

### 5.14 Embers — 10 keys (LoD)

- **B:** windows up to 5, meter type, segments, boss-only, max segments, graph, report, rows, look; export; history/compare (tests).
- **M:** death recap window, window snapping, per-spec icons (verify), Forever threat meter, encounter history markers.

### 5.15 Ascent — 8 keys

- **B:** timer, splits, records, sounds, TTS, notes, hide Blizzard, scale.
- **M:** forces current-pull preview (verify), death log, score projection, vault planner, kick tracker, run summary card.

### 5.16 Oracle (5), Wisdom (6), Loadouts (5), GroupFinder (9)

- **Oracle:**
  - **B:** palette, providers, secure arm, key, recent.
  - **M:** mounts/toys/pets provider depth (verify), WA display search, "do at reload" queue.
- **Wisdom:**
  - **B:** weights, tooltip, star, bags.
  - **M:** vendor/loot-roll badges, upgrade track/crest calculator, comparison panel, simc export.
- **Loadouts:**
  - **B:** rules, auto, announce, sound.
  - **M:** rule editor UI (currently text), "don't move" guard.
- **GroupFinder:**
  - **B:** role fit, rating, missing roles, declined memory, dim, sound, PGF stand-down.
  - **M:** filter presets per dungeon, quick signup on Enter, persistent note (verify).

### 5.17 Sentinel — 8 keys (+ Companion, website)

- **B:**
  - capture, ring, taint, integrity, drift, perf, heartbeat, safe mode, toast, export;
  - new viewer with resolved state, copy and `/pui sentinel`.
- **P:** resolved state is not persisted across sessions intentionally (verify the SV write); tester matrix not recruited.
- **Companion:** `companion/sentinel_companion` with build.py and tests exists — **P** (packaging/signing and auto-start unverified).
- **Website:**
  - **B:** ingest + D1 + admin `/phoenix/*` pages deployed (#15–#19).
  - **M:** public `/status`, `/sentinel` pages generated from data (verify which exist).

### 5.18 Theme & Media

- **B:**
  - 12 Phoenix statusbars + legacy, fonts (Inter, Rajdhani, JetBrains Mono, Noto KR/SC …), sounds, LSM share;
  - accent (11) and panel material;
  - module icons 64/128.
- **M:** border styles picker (6), shape masks (8), class/role icon sets, dark-mode/faction themes.

### 5.19 Locales — 837 keys, 9 languages at about 2%

- **P:** engine (`Core/Locale.lua`), `/pui loc`, keys.txt CI.
- **M:**
  - real translations;
  - **Arabic (arAR)** strings plus an Arabic-capable font (Noto Sans Arabic, OFL) — the client has no RTL shaping, so this needs a mockup and a feasibility note;
  - locale number abbreviations (万/亿).

### 5.20 Forever specifics (spec 5.17)

- **M:** `Phoenix_UI_Forever` child (spellbook/talent skins, threat meter, flight timer, swing, pet happiness, fishing).
- **P:** gates exist in modules.

### 5.21 Not started (Tier 1)

| Module | Status | Spec | Size |
|---|---|---|---|
| **Pulse** (C_EncounterTimeline bars, next-three HUD, pull/break, private-aura sounds, per-boss options, BigWigs/DBM stand-down) | M (paused) | 6.8 | XL |
| **Arena Frames** (spec icons, trinkets/racials gated by issecretvalue probe, DR, dampening, test mode, layouts, "no longer possible" list) | M (paused) | 6.9 | XL |
| **Spark** SCT (C_CombatText; scroll areas, animations, merge, school colours, notifications; MSBT stand-down) | M (paused) | 6.10 | L |
| Raid Tools (markers, ready check, pull, notes ooc) | M | 22.13 | M |
| Council | M | Tier 2 | XL |

## 6. Deferred list (consolidated)

1. Unit frame and nameplate auras (AuraContainer filters, dispel overlay, Player Aura Bars).
2. Raid debuff tiles with per-instance data packs; Buff Manager corner indicators.
3. Nameplate rules engine; NPC colour data packs.
4. Vault bank, warband, reagent and guild bank; offline alts; rules engine.
5. Chat emoji, history, spam filter, tab editor.
6. Data Bars user bars, LDB host, per-spec sets.
7. Minimap button flyout and own buttons.
8. Profiles manager, export/import, spec auto-switch, overrides.
9. Studio resize/scale, anchors to elements, multi-select, templates, layout export, Edit Mode hand-off.
10. Pulse, Arena, Spark, Raid Tools.
11. Arabic locale and real translations.
12. Plugin system (build last).
13. Forever child.
14. CurseForge/Wago release.

## 7. Mockup divergences carried from PRs #13–#16 (to resolve)

| PR | Divergence | Resolution |
|---|---|---|
| #13 | Export disabled (no profile export) | after 1.10 |
| #13 | Action Bars horizontal tabs instead of a vertical bar list | S, item 2.7 |
| #13 | Only 3 previews | 2.8 |
| #14 | Arabic card replaced by zhTW | needs 5.19 |
| #14 | Spec auto-switch toggle and Import omitted | 1.7, 1.10 |
| #14 | Minimal Ash has no out-of-combat fade | 3.6 |
| #14 | Look step applies live before Finish (no revert on skip) | S: snapshot and revert on Skip |
| #15 | Game Menu entry above, not inside | keep (taint), or re-mockup |
| #15 | Studio: no scale/W-H edit/distance chip | 4.4, 4.5 |
| #15 | Core uses Media textures (blank if Media disabled) | S fallback |
| #16 | Third action bar on by default; CDM/resource rows higher | decision: keep 3 bars, or update mockup 15 |
| #16 | Data bar not full width; chat/minimap not movers | 5.7, 4.17 |
| all | Nothing verified in game; the harness cannot render | in-game pass (phase A) |

## 8. Design-first: items needing new mockups before code

Use the same design package rules: 1420×860 options, the tokens and the kit.

1. Profiles manager (list, create/copy/rename/delete, spec→profile table, export/import dialogs with module checkboxes, merge/replace).
2. Overrides UI ("Editing as <spec/condition>" banner, marked slots).
3. Aura configuration (filter chains, aura picker, priority list, per-unit lanes) and the on-frame aura look.
4. Unit frame tag/text editor (zones, tag palette, live sample).
5. Colour picker (HSV, recents, class/accent swatches) and border picker.
6. Raid frames page: indicator corner editor, debuff tiles, Buff Manager, role layouts, preview grid.
7. Nameplate rules editor (rule list, conditions, effects, preview plate).
8. CDM page: custom bars, per-spell table, decorations, glows.
9. Vault window (bags, bank tabs, categories, rule editor, offline alt switcher).
10. Chat window (tabs, emoji panel, history search, copy).
11. Data Bars editor (bar list, block palette drag, per-spec sets) and minimap flyout.
12. Studio v2 (resize handles, scale, element anchors with connector lines, multi-select toolbar, templates gallery).
13. Pulse (timer bars, next-three HUD, per-boss options), Arena frames (3 layouts plus test mode), Spark (scroll areas editor).
14. Tour cards (login 2) in the new kit.
15. Arabic UI sample (font, RTL limits).
16. Plugins: already designed (P1–P4), approve as-is.
17. Website: `/features` and `/docs` generated pages, plugin dev docs (P4).

## 9. Plugin system (build last)

- Design: /workspace/pui_design/plugins/PhoenixUI_Plugin_API.md and mockups P1–P4.
- Scope:
  - TOC discovery (`X-PhoenixUI-Plugin`), `RequireAPI`, `RegisterPlugin` validation;
  - default OFF;
  - isolation (pcall + Sentinel `plugin.*` incidents);
  - Plugins page with Compatible/Outdated/Incompatible badges;
  - per-plugin sidebar section;
  - SV namespace;
  - design-kind plugins (skins/media/layouts);
  - dev docs site.
- Existing: Core/API.lua registries — P.
- Size: XL.

## 10. Website, admin, Companion, release

| Item | Status | Next |
|---|---|---|
| Phoenix site section, admin `/phoenix/*`, ingest, D1, retention | B (deployed) | keep in sync per release |
| `/features`, `/docs` generated from schema (spec 12/17.2) | P/M (verify) | generator + deploy, M |
| `/changelog` from `releases.json`, `/status`, `/sentinel` | P (verify) | M |
| Plugin dev docs page (P4) | M | with the plugin phase |
| Companion v1 (upload SV to ingest) | P | signed build, auto-start, tester distribution, M |
| CurseForge/Wago release via release.yml (BigWigs packager) | M (never run; needs your approval and project IDs/tokens) | final phase |
| Discord | M | out of code scope |

## 11. Ordered phase plan with acceptance criteria

Every item must pass all four of these before it is done:

- **G** = guardrails PASS.
- **T** = `/pui test` (harness) retail + Forever green, with new tests for the item.
- **I** = an in-game check on 12.1.5 retail (plus Forever where relevant), with zero Sentinel incidents in a session that uses the feature.
- **D** = matches the approved mockup or an explicit design note.

Merge, push live and install follow the existing rules.

**Phase A — Verify what exists (M, about 1 week)**
- In-game pass of PRs #13–#16:
  - options screens 01–04;
  - wizard 05–11;
  - Studio 12, menu/minimap 13, Sentinel 14;
  - HUD 15 at 1080p/1440p and pixel scale.
- Screenshot every screen against its mockup; fix spacing and fonts.
- Quick divergence fixes: 2.7, Core media fallback, Look-step revert on Skip, Ctrl K focus.
- Accept: I + D on every screen; the divergence list in section 7 is updated.

**Phase B — Profiles and sharing (L)**
- 1.6 manager, 1.10 serializer/export/import (whole/module/CDM/layout), 1.7 spec auto-switch, then enable Import/Export in the wizard and dashboard.
- Accept: round-trip export→import equals the source (T); the switch is deferred in combat (T + I); malformed strings are rejected safely.

**Phase C — Options editor widgets (M–L)**
- Colour picker, border picker, keybind capture, list editor, rule editor, aura picker, tag editor, cog popups, deep links, reset-all, CPU readout.
- Accept: each widget is schema-driven with an apply function, and has a T test per widget type.

**Phase D — Auras framework + Unit Frames depth (XL)**
- AuraContainer filters; UF auras/dispel/Player Aura Bars.
- Per-unit colours/textures/fonts; portraits; ≥20 tags + detached text bar; cast bar details; visibility rules; class resources on the frame; looks; previews with fake units.
- Accept: secrets are only passed to widgets (guardrail and review); I in M+ and raid with zero incidents; CPU within budget (spec 11).

**Phase E — Raid and Nameplates depth (XL)**
- Debuff/Buff Manager with tiles and corner indicators.
- Raid debuff data pack.
- Pets/tanks/boss frames.
- Click-cast editor.
- Role layouts.
- Nameplate rules engine + packs, aura lanes, important-cast glow, slots, target arrows.
- Previews.

**Phase F — Bars and CDM depth (L)**
- Per-button overrides, keybind mode, micro/bag/stance/pet/extra bars, flyouts, looks.
- CDM custom bars, decorations, glows, per-spell table, audio.
- Resource thresholds, swing, empower.

**Phase G — Studio v2 (L)**
- 4.4–4.17 in this order: resize/scale → element snapping and guides → multi-select/align → per-spec layouts (needs B) → templates/export → Edit Mode hand-off → chat/minimap/buff movers.

**Phase H — Suite depth (L each)**
- Vault: bank/warband/guild, rules, offline alts.
- Chat features.
- Data Bars editor + LDB host + blocks.
- Minimap flyout/buttons.
- Tooltip extras.
- Quest Tracker items.
- Flow to about 40 toggles + `conflictsWith`.
- Reminders depth.
- Embers/Ascent remaining items.
- Skins audit in game.

**Phase I — New modules (XL each)**
- Pulse → Arena → Spark → Raid Tools.
- Each gets its mockup first, a "not possible on 12.1.5" list, and stand-down rules.

**Phase J — Locales and accessibility (M–L)**
- Translation workflow (export keys, community PR).
- Arabic feasibility and font.
- Number formats.
- Colour-blind and high-contrast themes, TTS, reduced motion, gamepad.

**Phase K — Forever child (L)**

**Phase L — Plugin system (XL)**
- Per section 9, with the dev docs page on the website.

**Phase M — Release (M)**
- `/features`, `/docs` and `/changelog` generated.
- Companion signed.
- Tester matrix cycle with zero incidents.
- CurseForge/Wago projects and tokens (needs your approval), then the first tag through release.yml.

## 13. Competitor study (I:\ drive, read-only, 2026-10-26) and per-section parity + "better than"

> **Superseded in part by §15 (deep study, same day).** Where §13 and §15 differ, §15 wins. ElvUI/Plater/Cell/Bartender/Details/WeakAuras rows are no longer references.

**Method.** Every addon folder on `I:\` was read in place (copies of .lua/.toc/.xml only, into a scratch area on the box, never into the repo; nothing on `I:\` was modified). For EllesmereUI the option pages were parsed control by control (section headers, control type, label) and the runtime files read for how settings apply, how defaults are set and how the game menu entry is built. Other addons were read for their feature set and presentation. **No code is copied; every Phoenix item below is an original implementation** under Section 3 doctrine and 20.2 rules (no OnUpdate outside PUI.Ticker, CombatQueue for protected work, 150 locals/50 upvalues, behaviour defaults OFF, every setting = schema + apply, gated APIs).

**Addons present and studied:** EllesmereUI (core + 23 children: ActionBars, AuraBuffReminders, Bags, BlizzardSkin, Chat, CooldownManager, DamageMeters, DataBars, ForeverEssentials, Friends, GroupFinder, Locales, Minimap, MythicTimer, Nameplates, Options, QoL, QuestTracker, Quickdraw, RaidFrames, ResourceBars, UnitFrames, WindTools shell), BugSack + !BugGrabber, BigWigs (+ Core/Options/Plugins + 20 content packs), LittleWigs (+ 10 packs), sArena_Reloaded, MoveAny, TrufiGCD, MikScrollingBattleText, PremadeGroupsFilter, idTip, Auctionator, AutoQueue, Simulationcraft, Questie / QuestieDB / QuestieTrace, WoW-API (reference only).
**Not present on I:\ (could not be studied there):** ElvUI, Plater, Cell, Bartender4, Details!, WeakAuras. Parity rows marked "(ElvUI/…)" come from public documentation knowledge only, not from reading their code; re-study if the user puts them on the drive.

**Legend.** Status: **B** Built, **P** Partial, **M** Missing. Mock: **Y** needs a new/updated mockup before code, **N** uses existing kit. Acceptance (every row): **G** guardrails + manifest + locales pass, **T** `/pui test` green incl. a new unit test for the row, **IG** in-game check stated in the row, done with Wow.exe on live 12.1.5 and Forever, zero Sentinel incidents.

### 13.0 How EllesmereUI is built and presented (design-level lessons)
| Pattern seen | What it does | Phoenix "better" |
|---|---|---|
| Two-column `DualRow` page grammar (1,013 rows), `SectionHeader` blocks (274) | Dense, scannable pages; every row = two controls | Keep the 2-column grid but add per-row **reset dot**, **changed-from-default tint**, **search deep-link** highlight, and **"why" tooltip** from schema `desc` |
| Section toggles that hide (not grey) dependent rows | Short pages | Same, plus collapsed summary chip ("Background: off") so users see what's hidden |
| Per-row `disabledTooltip` naming the gate | Explains greyed rows | Clickable gate chip jumps to and flashes the gating toggle |
| Live preview panes per module (UnitPreview, NameplatePreview, CDM LivePreview, ActionBar preview) | Settings change preview instantly | Shared **Preview host** fed by the same apply() as the real frame; preview states (combat, low HP, casting, dispellable) selectable |
| Colour rows with class-colour checkbox + swatch + alpha | Per-element colouring | Token-based colours: pick a **design token** or custom; class/reaction/power modes in one segmented control |
| Global Fonts and Textures pages that list every module's font/texture | One place to restyle | Same, plus **"apply to all"** and **per-module override badges** |
| Profiles page with export/import string (LibDeflate), per-character/spec profiles | Sharing | Phoenix string v1 with checksum, **diff preview before import**, partial import per module, Wago hook |
| Sync icons (link setting across bars/units) | Edit once, apply many | **Link groups** shown as chain icon; Studio multi-select edits linked rows |
| Uninstall recorder (game settings restored) | Clean removal | Already have Flow CVar restore; extend to every CVar/setting we touch (Built for Flow, M elsewhere) |
| Game menu: own button parented to `GameMenuFrame`, `hooksecurefunc(GameMenuFrame,"Layout")` pushes Blizzard buttons and grows the frame; hidden in combat | Entry inside the menu without taint | Adopt (see 13.D1) |
| Unlock mode with movers for every element incl. Blizzard ones | Positioning | Studio already; add Blizzard-element hand-off + Shifter-style window moving |
| Shared fader queue, side tables instead of frame fields, secret-value-safe alpha | Perf + 12.x secret safety | Already doctrine (PUI.Ticker, Secret helpers); add perf readout per module |

### 13.D Decisions folded in
**D1 Game Menu button inside the game menu (verified against wow-ui-source `live` 12.1.5.70575, `Blizzard_GameMenu/Shared/GameMenuFrame.lua`).** `GameMenuFrameMixin:InitButtons()` rebuilds a `buttonPool` via `self:AddButton(text, callback, disabled, tooltip)` and `self:AddSection()` on every OnShow and on events, then lays out. Adding into Blizzard's pool from addon code risks spreading addon taint to pooled buttons that run Logout/Quit/Options, so Phoenix will **not** inject into the pool (same choice EllesmereUI makes). Implementation: one Phoenix button created from `MainMenuFrameButtonTemplate`, parented to `GameMenuFrame`; `hooksecurefunc(GameMenuFrame, "InitButtons", ...)` (post-hook; also `"Layout"` when that method exists, since InitButtons ends in a layout pass) places it under the Options/AddOns section, shifts the enumerated `buttonPool` buttons below it by one row via `ClearAllPoints/SetPoint` on our side only, and adds one row to the frame height; skipped while `InCombatLockdown()` (button hidden, menu untouched), re-applied on `PLAYER_REGEN_ENABLED` via CombatQueue. Gated: if `GameMenuFrameMixin.InitButtons` or `buttonPool` is absent (Forever), fall back to the current standalone frame. Setting `general.gameMenuButton` stays; adds `general.gameMenuStudio` (second "Phoenix Studio" row, default OFF). Status **P** (separate frame today). Mock **Y** (update mockup 13 to show the in-menu row). IG: open Esc menu out of and in combat 20x, click Logout/Exit/Options/AddOns after using our row, `/pui sentinel` shows no taint, `/console taintLog 2` clean.

**D2 Action bars match EllesmereUI/ElvUI defaults and go further.** EllesmereUI defaults read from `EllesmereUIActionBars.lua`: square icons, icon zoom 5.5%, 1px solid black border, padding 2, cooldown edge 2.1px warm-gold, pushed/highlight border type 2 (4px), cast highlight on, hide casting animations on, CD swipe black 80%, desaturate-on-CD off, alpha-on-CD 100, keybind/macro/count font 12 white, grow up, always show buttons on, paging arrows off, mouseover off per bar, 10 bars + Stance + Pet + Micro/Bags/Queue/XP/Rep/Extra/Encounter visibility entries. ElvUI-parity (public docs): bars 1–6 with per-bar buttons/per-row/size/spacing/backdrop/visibility macro state driver, keybind mode, global fade, cooldown text with thresholds. **New Phoenix defaults** (replaces mockup-15 bar notes): Bar 1 12×1 at bottom centre 40px, Bar 2 12×1 above, Bar 3 12×1 above (kept ON for keybinds), Bars 4–5 right vertical 12×1 mouseover-fade OFF, Bars 6–10 OFF, Stance/Pet small (28px) above Bar 3 left/right; button 40px, spacing 2, zoom 5.5%, 1px black border, Phoenix Smooth slot background 50%, cooldown edge accent token, keybind 12 top-right, macro hidden, count 12 bottom-right, cast highlight ON, casting animation hidden ON, range red tint ON, usable/no-mana blue tint ON. These are **visual** defaults (allowed ON); every **behaviour** (mouseover fade, combat show/hide, click-through, paging overrides) remains default OFF. Mockup 15 notes and the action-bar mockup (03) notes are updated in `pui_design/design/PhoenixUI_Design_Spec.md` §AB-15; the 15 image itself needs the design pass to redraw (they own the artwork) — flagged Mock **Y**.

### 13.1 Options window / framework
| Feature (source) | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Grouped sidebar, per-module pages, tabs (EUI) | B | Search deep-links into tab+row, Ctrl K | N | open every page |
| Accent colour, options theme, options language (EUI General) | P | Accent from 6 design accents + custom; language switch live where possible | N | switch live |
| UI scale slider (EUI) | P (wizard only) | Pixel-perfect suggestion per resolution | N | 1080p/1440p/4K |
| Fonts page: global font, outline, game text scale, per-module fonts (EUI Fonts, 30 rows) | M | Per-module override badges, live specimen | Y | change global font, all modules restyle |
| Textures page: per-module bar/cast/absorb/background textures (EUI Textures) | P | One grid + per-module override | Y | |
| Colors page: dark mode, class/power/resource colour tables, pull-from (EUI Colors) | M | Token editor with contrast check | Y | |
| Glows page: glow template + per-module glows (EUI Glows) | M | Shared Phoenix glow library (pixel/autocast/proc/button) | Y | |
| Profiles: export/import, per-char/spec, copy, reset (EUI Profiles 2.5k lines) | P | Diff preview, partial import, spec auto-switch, Wago | Y | round-trip string |
| Uninstall restores game settings (EUI Uninstall) | P | Covers all touched CVars | N | uninstall → CVars back |
| Gamepad page: hide bars/cast bars on gamepad (EUI Gamepad) | M | Controller profile auto-switch | N | |
| Developer: suppress Lua errors, spell ID on tooltip (EUI General) | P (Sentinel) | Routed to Sentinel, never silently swallowed | N | |
| Combat: max camera distance, key-down casting, lag tolerance, image quality (EUI General) | M (Flow partly) | Flow CVar cards with restore | N | |

### 13.2 Unit Frames (EUI UnitFrames: SharedAppearance/SharedBars/SharedCastAuras/MiniFrames/TextSlots)
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Health bar: height, width, scale, reverse fill, fill colour/opacity, background, smooth, level, L/R/C/extra text with class colour | P | Tag editor with live token preview | N | |
| Text slots: "+ Add Text Slot" free text anywhere (EUI) | M | Drag text slots in preview | Y | |
| Power bar: hide, height, position, text, colours, spell cost prediction, mana regen spark, power type per spec | P | Cost prediction secret-safe | N | |
| Class resource on frame: position, size, colours, combo style | P | | N | |
| Absorbs/heal absorb/max-health styles + opacity + bars; heal prediction + overheal | P | Striped overlay textures from Phoenix media | N | |
| Cast bar per unit: height, icon, name/duration/target text, reverse, glow on interruptible | P | Kick-ready hint colour | N | |
| Buffs/debuffs: display mode, size, duration/stack size, dispel overlay + colours, type icon, only dispellable by me | P | Aura filter rule builder (Phase D) | Y | |
| Portrait: mode, art style, non-player portrait, size, position, shape, border, dragon size | P | 3D/2D/class icon/off + Phoenix shapes | Y | |
| Text bar strip (EUI) | M | | N | |
| Indicators: combat, raid marker, leader, elite/rare, faction, threat % | P | | N | |
| Nicknames, dark mode, hover borders, strata, decimal health (EUI) | M | | N | |
| Mini frames: pet (happiness), ToT, focus, focus-target, boss (stack direction, simple aura display, boss buff filter, OOR alpha) | P | Boss frames with test mode `/pui test boss` | Y | |
| Copy auras from another unit (EUI) | M | "Copy settings from…" on every unit tab | N | |

### 13.3 Raid & Party (EUI RaidFrames + ManagerPages)
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Frame sizes per raid size (5/20/40 + custom sizes), auto-resize icons | P | Size profiles auto-picked per group size | Y | |
| Layout: group/unit growth, sort by, self position, show groups, merge groups, horizontal, hide self, party-in-small-raid, show solo | P | | N | |
| Health: texture, fill/colour, background, heal prediction, smooth, threat borders | P | | N | |
| Absorbs/heal absorbs/max-health styles | P | | N | |
| Power bar for roles, height, border | P | | N | |
| Text: name size/colour/position, health/level/power/heal-absorb text | P | | N | |
| Indicators: missing buffs, role icons, marker, ready/summon/rez, status text, leader, combat, group numbers, ping marker | P | | N | |
| Dispels: overlay, opacity, border, type icon, colours, only dispellable | P | | N | |
| Assigned buffs/debuffs managers (filters, extra spells, custom order, per-position icons) — corner indicators (Cell-style) | M | Indicator editor with drag-to-corner in preview | Y | |
| Top name bar, portrait, party targets, friendly boss frames, extra (tank) group, pets | M | | Y | |
| OOR alpha, tooltips, healer mana display, hide Blizzard party, right-mouse camera unlock, strata | P | | N | |
| Raid debuff tiles (deferred list) | M | Data-pack driven | Y | |

### 13.4 Nameplates (EUI Nameplates: General/DisplayBars/DisplayLayout/Colors/Preview)
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Friendly plates name-only, friendly NPC, subtitle/guild text, not clickable, enemy pets | P | | N | |
| Stacking/overlap, spacing, hitbox X/Y, top inset | P | | N | |
| Health/cast sizes, cast icon/timer/offset, kick-ready mid-cast hint, interrupted flash, casts in front | P | | N | |
| Target/focus/hover effects (arrows, textures, colour, scale, non-target alpha, focus letter) | P | | Y | |
| Class resource on plate | M | | N | |
| Core positions grid (top/left/right/bottom slots) + text slots | M | Drag-slot editor in preview | Y | |
| Colour rules: debuff-based colouring + combos, enemy types, quest mob, threat (tank/non-tank), threat % | M | Rule builder with priority list (deferred "nameplate rules") | Y | |
| Execute pulse, LoS opacity, range opacity, hide OOC, hash line at %, scale on cast, raid marker | M | | N | |
| Debuff filters, max debuffs, pandemic glow | P | | N | |

### 13.5 Action Bars (EUI ActionBars: Visibility/Layout, Appearance, Animations, Menu/Bags/Rep, XP bar) — see D2
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| 10 bars + stance + pet: icons, rows, size (W/H separately), padding, vertical, icon order, grow direction | P (no W/H, order, grow) | Live grid preview + Studio resize | Y (03) | |
| Visibility: always/combat/mouseover/hidden, show-all-on-mouseover, drag-show, housing/mounted/no-target/instances, macro state string (ElvUI) | P | Visibility builder with readable chips + raw state string | Y | |
| Bar background: on, colour, opacity, border style/size, multipliers | M | | N | |
| Button shape (square/round/custom), icon zoom, Blizzard icon bg, slot bg | P | | N | |
| Icon effects: desaturate on CD, alpha on CD, swipe opacity, OOR colouring, equipped colour, item rank, hide charge at 0 | P | | N | |
| Cooldown numbers + edge size/colour | P | Threshold colours (ElvUI) | N | |
| Pushed/highlight textures + class colour, cast highlight, hide casting animations, proc glow, assisted highlight style/outset/overlay | M | | N | |
| Paging: disable form/skyriding paging, arrows, skip visible, modifier/target paging | M | Per-class paging editor (behaviour OFF) | Y | |
| Text: keybind/macro/charges/CD font size, colour, hide | P | | N | |
| Keybind mode (ElvUI/Bartender `/kb`) | M | Hover-bind with conflict warning | N | |
| Click-through, tooltips off, lock, always show buttons | P | | N | |
| Micro menu, bags bar, queue status, vehicle bar, extra action/encounter bar movers | M | | N | |
| XP/Rep/House-favor bars with styles, dividers, rested, quest XP overlay, text slots | P (HUD data bars) | | Y | |

### 13.6 Cooldown Manager (EUI CDM: Bars, BuffBars, Pickers, SpellPicker, LivePreview, glow conditions)
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Rows, max icons + overflow to, vertical, keep buffs in place, bar opacity/background | P | | N | |
| Icon scale/shape/zoom/border, duration/stack size, suppress GCD, numbers only | P | | N | |
| Spell picker (add/remove/reorder tracked spells, 5.9k lines) | M | Drag list + search, per spec | Y | |
| Buff bars groups (grow, name, auto-add, global, shift), bar texture/text/spark/reverse, stack-based bar, max stacks ticks, threshold | M | | Y | |
| Glow conditions (at stacks, combat only, hero talent, AND) | M | Condition chips | Y | |
| Rotation assist icon/style/colour, keybind display, mirror key presses | M | | N | |
| FocusKick: nameplate anchor, focus text, cast sound, interrupt spell | M | | N | |
| Trinkets/potions: hide missing items, non-on-use trinkets, swap combat potions | M | | N | |

### 13.7 Resource Bars (EUI ResourceBars: Health/Power/ClassResource/CastBar/GCD/Swing/Totem/BarDisplay)
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Health/power/class resource bars: orientation, size, border, opacity, colours, text, threshold & hash lines | P | | N | |
| Bar shifting when no resource/power; mana while shapeshifted; spell cost prediction; regen spark | M | | N | |
| Spec helpers (Ironfur, Ignore Pain, Sweeping Strikes, Arcane Soul) | M | Data-pack driven helpers | N | |
| Player cast bar: size, icon, spark, ticks (channel/last/empower stages), latency overlay/text, rank | P | | N | |
| GCD bar, swing timer (weapons, range, attack state), totem bar | M | | N | |

### 13.8 HUD: Minimap / Data Bars / Tooltip / Blizzard skin
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Minimap shape, size, border, rotate, zoom reset, scroll zoom | P | | N | |
| Button collector (ungroup, size, mouseover, row position, free move), M+ portals, addon compartment scale | M | | Y | |
| Clock/zone/coords/FPS-MS/difficulty text with positions + hover tooltips | P | | N | |
| Data bars: blocks (gold w/ history, durability, bags low-space, ilvl, currency, crests, clock, latency, volume, LDB plugins), fill-remaining, snap to edge | P | | Y | |
| Tooltip: anchor cursor, growth, spell IDs, max stack, player buffs, health strip, background/border (EUI, idTip) | P | IDs for spell/item/aura/npc/quest/achievement (idTip parity) | N | |
| Blizzard skin: popups, game menu, widget bars, extra button, queue popup + timer, character/inspect sheet (ilvl, enchants, upgrade track, durability), skyriding bar, chat bubbles, third-party skins | P | | Y | |

### 13.9 Chat, Bags (Vault), Quest Tracker, Friends, Group Finder
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Chat: panel bg/texture/font/border, idle fade, sidebar icons, tabs inside/spacing/height/fonts/colours/underline, edit box top/height/font, remember lines, timestamps, short channels, class names, whisper sound | P | | Y | |
| Bags (EUI Bags): categories/sidebar, pinned/recent, grid/compact/list views, ilvl/BoE/set names, merge duplicates, gear by slot, junk visuals, quality border, gold history, currencies, stack splitter, bank display | P (Vault 6 keys) | Category rules editor | Y | |
| Quest tracker: fonts, colours by progress, dim completed, sounds, sort/filter, auto-track zone, auto accept/turn in (Questie data for Forever) | P | | N | |
| Friends list skin: class icons/colours, faction banners, region icons | M | | N | |
| Group finder: applications counts, remember roles, quick signup, persistent note, auto insert keystone; PremadeGroupsFilter-style expression filter | P | Filter chips + expression | Y | |

### 13.10 Combat tools: Damage meter (Embers), M+ timer (Ascent), Reminders, Threat, Battle res, Alerts, Cursor, Movement
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Meter: refresh, header, bars, number format, breakdown on hover, standalone combat timer, icon/bar spell history (TrufiGCD parity) | P | | Y | |
| M+ timer: title/affix, timer formats, bar + thresholds, forces + current pull, boss objectives + split compare, targeted-spell bars, run summary with columns | P | | Y | |
| Aura/buff reminders: flask/food/rune/weapon/pet/healthstone, click-to-buff preferred item, ready-check mana warning, M+ beacon | P | Secure click-to-buff via CombatQueue | Y | |
| Threat meter (Forever): bars, warning sound at %, text | M | | N | |
| Battle res + bloodlust tracker icons | M | | N | |
| Alerts: combat, potion ready, unspent talents, group deaths, low durability | P | | N | |
| Cursor circle/trail/GCD ring/cast ring, crosshair, target range text | M | | N | |
| Movement cooldown alert (sound/TTS), Time Spiral, gateway shard | M | | N | |
| Raid tools: world markers quick fire, pull timer, group buttons | M | | Y | |
| Scrolling combat text (MSBT parity: scroll areas, events, triggers, sounds) | M (Spark planned) | Spark = Phoenix SCT | Y | |
| Boss mod integration (BigWigs/LittleWigs present): bar skin + timeline hand-off | M | Skin only, no mod | N | |
| Arena frames (sArena parity: trinket/DR/spec icons, aura highlight CC/defensive) | M (Arena planned) | | Y | |

### 13.11 QoL, Quickdraw, Loadouts, Forever essentials
| Feature | St | Better-than | Mock | IG |
|---|---|---|---|---|
| Skip cinematics, quick loot, auto delete fill, auto repair/sell junk, auto gossip, auto open/unwrap, train all, hide screenshot text, AH current expansion | P (Flow) | All OFF by default | N | |
| /keys popup, LFG reminder, /way, auto combat logging | M | | N | |
| Shifter: move Blizzard windows (MoveAny parity) | M | Studio "Blizzard windows" category | N | |
| Quickdraw radial/grid action menus with keybind | M | | Y | |
| Loadout manager: auto-swap per instance/difficulty, gear+talents, warnings, announce | P | | N | |
| Upgrade calculator (crests) | M | | Y | |
| Forever: auto uprank, map fade/reveal/levels, classic windows, simplified stats, best quest reward, pet auto-summon, junk window, fishing, loot feed, macro manager, flight timer, threat | P | | N | |
| Party mode celebrations (EUI fun) | M | Deferred | N | |
| Error viewer (BugSack parity: sessions, counts, copy, sound) | B | Sentinel already exceeds (taint, perf, safe mode) | N | |
| SimC export | M | Deferred / link to Simulationcraft | N | |

### 13.12 New phases added to §11 from this study
- **Phase A+ (first):** D1 in-menu Game Menu row; D2 action-bar defaults; global Fonts/Textures/Colors/Glows pages. S–M.
- **Phase B+:** Action bars full parity (13.5) incl. keybind mode, paging editor, visibility builder, micro/bags/vehicle movers. L.
- **Phase C+:** Unit frame text slots, portraits, mini/boss frames, copy-from (13.2). L.
- **Phase D+:** Raid indicator editor + assigned buffs/debuffs managers, size profiles, extra/pet/boss groups (13.3). XL.
- **Phase E+:** Nameplate slot layout + colour rule builder (13.4). L.
- **Phase F+:** CDM spell picker, buff bars, glow conditions (13.6); resource GCD/swing/totem/helpers (13.7). XL.
- **Phase G+:** HUD minimap collector, data bar blocks, tooltip IDs, Blizzard skin depth (13.8); Chat/Vault depth (13.9). XL.
- **Phase H+:** Combat tools 13.10 (meter history, M+ summary, threat, bres, cursor, movement, raid tools), then Pulse/Arena/Spark. XL.
- **Phase I+:** QoL/Forever 13.11. M–L.
Each phase ships as stacked PRs; each PR updates `docs/PLAN.md` statuses and `CHANGELOG.md`.


## 15. EllesmereUI deep study (2026-10-26, second pass) — corrections and full per-section feature tables

**Scope and method.** EllesmereUI core + 23 children on `I:\` (read-only; nothing on `I:\` modified; nothing copied into the repo). **937 files, 764,729 lines** (Lua/XML/TOC), every file parsed line by line into inventories (events, C_ APIs, global APIs, CVars, hooks, default literals, every options control with label/range/key/tooltip — **3,113 controls**) and every file and section header read; core runtime files of AuraKit, CDM, Chat engine, Unit Frame engine read by hand. Per-module study notes live on the box at `/workspace/pui_study/ellesmere/<module>.md` with `COVERAGE.tsv` (937/937 files marked read). ElvUI, Plater, Cell, Bartender, Details and WeakAuras are **dropped as references** (user decision 2026-10-26); rows in §13 citing them are superseded by this section. **Ideas only; every Phoenix implementation stays original.**

| Module | Files | Lines | Controls |
|---|---|---|---|
| EllesmereUI (core) | 81 | 84,927 | 154 |
| Options | 99 | 157,236 | 30 (+ the per-module pages below) |
| UnitFrames | 32 | 33,094 | 598 |
| RaidFrames | 37 | 43,730 | 343 |
| Nameplates | 20 | 17,716 | 210 |
| ActionBars | 30 | 22,475 | 147 |
| CooldownManager | 45 | 39,237 | 198 |
| ResourceBars | 24 | 18,508 | 285 |
| AuraBuffReminders | 14 | 7,722 | 62 |
| DamageMeters | 12 | 8,982 | 96 |
| MythicTimer | 5 | 8,129 | 135 |
| QoL | 16 | 19,719 | 256 |
| Bags | 18 | 17,198 | 52 |
| Chat | 15 | 10,941 | 62 |
| Minimap | 11 | 6,915 | 83 |
| DataBars | 21 | 12,070 | 70 |
| BlizzardSkin | 24 | 37,416 | 143 |
| QuestTracker | 6 | 3,885 | 38 |
| Quickdraw | 15 | 10,394 | 37 |
| Friends | 2 | 3,272 | 9 |
| GroupFinder | 4 | 4,365 | 6 |
| ForeverEssentials | 26 | 10,276 | 99 |
| Locales | 11 | 70,744 | — |
| WindTools shell | 369 | 115,778 | — |
| **Total** | **937** | **764,729** | **3,113** |

### 15.1 Self-evaluation: what the previous plan (§13) got wrong or missed
1. **Auras architecture was wrong.** §13 planned a Lua aura scanner + "filter rule builder". In 12.1 auras are secret in restricted content; EUI renders *all* auras (unit frames, raid, nameplates, player aura bars, CDM decimals, Ebon Might/Arcane Soul) through Blizzard's new **`AuraContainer` frame (`CustomAuraContainerTemplate`, `Blizzard_AuraContainer`)** with engine-side filters, sorting, duration text and bars. Phoenix has zero use of it. This is now the #1 foundation item (F1).
2. **Cooldown Manager approach was wrong.** §13 listed CDM as a spell picker on our own tracking. EUI never tracks cooldowns itself: it **restyles and re-anchors Blizzard's Cooldown Viewer children** (hooks on `OnCooldownIDSet`, pool Acquire, viewer Layout; alpha-0 unclaimed; weak side tables) because that is the only secret-safe data source. Our CDM (202 lines) only positions viewers.
3. **Missed the Spec/Conditional Overrides system** (~10k lines): per-spec and per-condition values for any setting inside one profile, "Editing as" sessions, gold borders on overridden rows, promote-to-profile. §13 only had "spec auto-switch profiles".
4. **Missed Unlock Mode depth**: anchor-to-element and **width/height match links** (elements follow each other's size and position), grow-direction-aware anchors, combat-parked moves, Edit Mode anchor guard, Blizzard-owned frame overlays. §13 said "Studio already". Studio (#15) has snap, grid, nudge, undo/redo and an anchor grid, but no element-to-element anchors, size matching or resizing.
5. **Damage meter source**: Midnight addons have no combat log; EUI uses `C_DamageMeter` sessions (secret in combat; rendered via setters). §13 did not state the data source; Embers must be checked against this.
6. **Chat**: missed the only taint-safe reskin route (AddMessage post-hook bridge into our own ScrollingMessageFrame + ghost tabs over Blizzard's invisible strip) and the measured taint rules (never hook FCF_*, never reparent chat widgets, never write fields).
7. **Raid frames**: missed Click-Cast hovercast path, Buff Manager indicator types (icon/square/bar/health colour/border/frame alpha), Debuff Manager tiles with match-any/all, Grid Mode, Extra Frames, friendly boss frames, party targets, size tiers, FrameSort shim, frame-provider API.
8. **Unit frames**: missed the channel-painter engine model, Player Aura Bars + custom aura bars with named filters, mini frames, boss range dimming.
9. **Nameplates**: missed per-plate container bundle pool, global cast dispatcher, quest mob detection via `C_TooltipInfo`, friendly name-only system riding Blizzard's FontString, debuff colour lists per class.
10. **Resource bars**: missed engine-driven duration fills (`SetTimerDuration`), hidden-aura-slot displays for secret buffs, colour-curve thresholds, Blizzard class art re-host.
11. **Data bars** are a **user-built multi-bar + block engine** (any number of bars, 20+ block types, layout solver, LDB), not 7 fixed keys. **Bags** have three views (grid/compact bin-packing/list), category engine and bank parity. **QoL** has ~40 toggles + 12 separate systems. **Quickdraw** (radial/fan/grid palette with secure in-combat selection) was not in the plan. **Mythic timer** has run summary/history, target/focus cast bars and targeted-spell bars. **Reminders** split combat-safe vs OOC-only with secure click-to-use icons.
12. **Onboarding/ops** missed: ClientGate first-file failsafe, Uninstall/CVar restore ledger for every module, global fuzzy search, profile sync groups, first-install module picker + style picker, one-time feature announcements, video guides, three looks (EUI/Blizzard/Classic).
13. **Locales**: EUI ships 8 near-complete translations (70.7k lines). Our 2% is the largest content gap; Arabic is ours to add.

### 15.2 New and corrected foundation items (build before module parity)
| ID | Item | St | Phoenix better | Mock | Acceptance |
|---|---|---|---|---|---|
| F1 | `PUI.Auras` on 12.1 `AuraContainer`: canonical filter builder (cached, sorted tokens), add-only groups toggled by cap, flow layout (anchor/growth/padding/line size/axis) with API-generation fallback, processing policy, scheduler-spread construction, restriction-aware restyle queue (`C_Secrets.ShouldAurasBeSecret`), engine duration text (`C_DurationUtil` binding + `C_StringUtil` formatters) and bars, engine-hosted glows | M | One shared engine for UF, Raid, Plates, Player aura bars, CDM decimals, spec helpers; per-container perf readout in Sentinel | N | G, T (filter canonicalisation, cap toggling), IG: auras correct in M+ key and raid boss (restricted) with zero Lua errors; Ticker shows no per-frame Lua |
| F2 | Overrides layer: per-spec-group and per-condition overlays on any `overridable` schema key; "Editing as" banner; gold dot on overridden rows; promote to profile; list page | M | Generic on schema (no per-module forks), diff view | Y | G, T (resolve order profile→spec→condition), IG: swap spec in town and in combat (deferred) |
| F3 | Studio v2 parity: anchor-to-element, width/height match links, resize handles, grow-direction anchors, combat-parked moves (CombatQueue), Edit Mode guard, save/revert banner (snap, grid, nudge, undo/redo already Built in #15) | P | Undo/redo (EUI has revert only) + layout presets | Y | IG: anchor UF to CDM bar, resize CDM, UF follows; combat enter mid-drag safe |
| F4 | `PUI.CVars` ledger: owner-tagged CVar writes, restore when a module turns off and on "Uninstall Phoenix" | P (Flow only) | Visible ledger page | N | T, IG: disable Nameplates → CVars back |
| F5 | ClientGate hardening: refuse migrations on unknown interface | P | — | N | T |
| F6 | Global search over `SchemaIndex` with deep-link + flash | P | Ctrl+K palette | N | IG |
| F7 | Schema-driven page renderer (DualRow, cog popups, apply-to-all links, reset dot, changed tint, disabled-gate tooltip) | P | 100% coverage from schema | Y | every schema key visible on a page |
| F8 | Shared services: `PUI.Mouse` (one cursor poll as Ticker subscriber), `PUI.Range`, `PUI.Visibility` dispatcher, `PUI.Glow` | M | zero cost unsubscribed | N | T |
| F9 | Looks axis (Phoenix / Blizzard-like / Classic) | M | after parity | Y | backlog |

### 15.3 Per-section feature tables (status vs main-v2 b5c2682)
Legend as §13: St **B/P/M**; Mock **Y/N**; every row's acceptance = **G** guardrails+manifest, **T** `/pui test` incl. a unit test, **IG** in-game check on 12.1.5 retail and Forever with zero Sentinel incidents, plus the row's specific check.

**Unit Frames** (EUI 598 controls; ours 89 keys)
| Feature | St | Phoenix better | Mock | Specific check |
|---|---|---|---|---|
| Channel-painter engine, RegisterUnitEvent per token, vehicle at registration, same-frame dedupe, ToT/FoT on one Ticker sub | P | perf readout | N | 40 events/s without dropped paints |
| Auras via F1 per class group (buffs/debuffs/dispellable/own/CC), caps, sort, dispel slots, purgeable glow | M | shared filter registry with Raid | Y | restricted content |
| Player Aura Bars (buffs, debuffs) + custom aura bars with named filters, 10 presets, match any/all, per-spec | M | — | Y | |
| Mini frames (companion), boss1-5 with range dimming, pet, ToT, FoT | P | `/pui test boss` | Y | |
| Text slots + tags + nicknames + decimals + smart power % | P | live token editor | Y | |
| Portraits 2D/3D/class, attached/detached, masks, borders | P | Phoenix masks | Y | |
| Castbar kick tick, interrupt colours, important cast | P | | N | |
| Absorb styles, heal absorb, max-health reduction, heal prediction, glow line | P | | N | |
| Class power (bars/circles) on player frame | P | | N | |
| Visibility: fade OOC, resting alpha, show when missing health; dark mode; dynamic health colour | P | | N | |

**Raid & Party** (EUI 343 controls; ours 23+3)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Per-group + flat headers, party header, raid size tiers | P | auto tier | Y | 5/10/20/40 |
| Buff Manager indicators (icon/square/bar/health colour/border/frame alpha), healer spell DB per spec, filters, ≤20 per spec | M | drag-to-corner editor on replica | Y | |
| Debuff Manager tiles, match any/all, shown-on-modifier, per spec | M | | Y | |
| Click-cast: frame path + hovercast path, global defaults, per spec | P | conflict detector | Y | combat-safe rebinds |
| Grid Mode / Compact Mode shared outlines | M | | Y | |
| Extra Frames (chosen members), friendly boss frames, party targets, pets (header/beside owner) | M | | Y | |
| Sort: self first, prioritize class, FrameSort shim | P | | N | |
| Range fading, ghost-aura safety net, healer mana text, ping marker, role/leader/combat icons, ready check | P | | N | |
| Frame-provider API for external trackers | M | with plugin API | N | |
| Preview: fake roster, cycling auras, size preview | P | state toggles | Y | |

**Nameplates** (EUI 210; ours 17)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Plate pool + prewarm, NamePlateDriverFrame suppression | P | | N | 40 plates |
| Container bundle pool (player debuffs, important buffs, CC) with Blizzard nameplate filter rule, show-all toggle, tracked auras popup; warm pool 16, pre-warm to 25 when zoning in, grows on demand in combat; layout fingerprint skips engine setters | M | F1 | Y | restricted; 25-plate M+ pull with no missing auras |
| Purge glow per **group** (Dispellable token split Magic / enrage) gated on the player's offensive dispel | M | | N | arena (restricted) |
| Global cast dispatcher, kick tick + kick window, interrupted flash, cast target, important cast | P | | N | |
| Colour rules: class/reaction/threat context/quest (C_TooltipInfo cache)/focus/debuff lists per class | M | unified Rules engine with priority | Y | |
| Lazy target/focus overlays (arrows, glow, low health, near aggro, focus letter), non-target alpha, hover | P | | Y | |
| Friendly system: name-only riding Blizzard name, subtitle/guild, class colours, faction badge, click-through, CVar enable/disable path | P | ledger (F4) | N | |
| Range: distance text, out-of-range alpha (F8 Range) | M | | N | |
| Class power on target plate, stacking/inset CVars re-applied, hide enemy OOC | M | | N | |

**Action Bars** (EUI 147; ours 105)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Own secure buttons, Blizzard bars disposed to hidden parent, events re-registered | P | | N | taint log clean |
| Central dispatcher + bar dormancy, ACTION_RANGE_CHECK_UPDATE tint | P | | N | |
| Override-binding keybinds, key-down, pushed flash, Quick Keybind compat, keybind mode | P | conflict warnings | N | |
| Paging per bar (state driver, modifier/target conditions, class fallbacks), arrows | M | editor | Y | |
| Visibility builder (multi-select → state driver), mouseover fade, gamepad hide, toggle-bar key | P | readable chips | Y | |
| Shapes/masks/borders/chrome/end caps, pushed/highlight textures, proc + assisted highlight glows, flyout reskin | P | Phoenix media | Y | |
| XP/Rep/House Favor bars: styles, dividers, smart ticks, quest-XP overlay, text positions (XP/h, session) | P | | Y | |
| Vehicle exit, override controller, micro/bag holders, extra action button holder | P | | N | |
| First-install capture of the user's Edit Mode layout | M | | N | |

**Cooldown Manager** (EUI 198; ours 22)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Restyle + reanchor Blizzard viewer children (hooks only, side tables, alpha-0 unclaimed), 4-phase collect | M | | N | combat reanchors, no taint |
| Custom bars per spec + global groups, spell store, spell picker, talent conditions, empty slots, trinket slots, item presets, racials, spec sync | M | manager page | Y | |
| Tracking bars from CDM children: thresholds, ticks, stacks, pandemic, sounds, auto-add, presets, engine decimals | M | | Y | |
| Fake-active, custom icons, ready sound, state effects, charge text | M | | N | |
| Bar glows (active/missing/usable/stacks/AND/hero tree), proc glows, pandemic sync | M | condition chips | Y | |
| Rotation assist icon, mirror key presses, focus kick bar | M | | N | |

**Resource Bars** (EUI 285; ours 18)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Health/power/class resource bars, thresholds as colour curves, ticks/hash, smooth, fades | P | | N | |
| Cast bar (ticks, empower, latency), GCD bar, totem bar, swing timer (Forever) on duration objects | P | engine fills | N | |
| Spec helpers: Ironfur, Ignore Pain, Ebon Might, Arcane Soul, Warrior charges (hidden aura slots) | M | data pack | N | restricted |
| Blizzard class art re-host, anchors/stack, border-around-all | M | | N | |

**HUD: Minimap / Data Bars / Tooltip** (EUI 83 + 70 + skin)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Minimap collector (scan, blacklist, flyout grid, free move), indicators (vault, portals, friends, calendar lockouts), micro menu on middle click | M | search | Y | |
| Data bars engine: N bars from templates, 20+ blocks incl. LDB, layout solver, themes, heartbeat | M | | Y | |
| Tooltip: anchor modes + mover, visibility with peek modifier, health strip, IDs | P | | N | |

**Chat / Vault / Quest / Group Finder / Friends**
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Chat engine (AddMessage bridge, own SMF, ghost tabs), sidebar, idle fade, URL copy, session history | P | | Y | taint log during whisper creation |
| Vault: categories engine, grid/compact/list, bank + warband parity, junk/pin/assign modes, stack splitter, sort two-phase, Pawn/overlay API | P | rule categories | Y | |
| Quest tracker skin by hooks, item hotkey, auto accept/turn-in, visibility | P | | N | |
| Group finder filters (dungeon/delve/raid boss/region), applications bar, cancel oldest | P | expression filter | Y | |
| Friends skin | M | | N | |

**Combat tools / QoL**
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Embers on `C_DamageMeter`: 8 meter types, Current/Overall + historical session IDs, source breakdowns, death recap via `C_DeathRecap`, ≤5 windows, standalone timer, spell history | P | segment engine (see 15.5) | Y | secret numbers via setters; chain-pull, wipe-with-survivors, arena round end, feign death |
| Ascent: run summary/history, target/focus cast bars, targeted spell bars | P | | Y | |
| Reminders: combat-safe raid buffs vs OOC checks, secure click-to-use, where-to-show, talent reminders, ready-check mana | P | season data pack | Y | |
| QoL toggles (~40) | P (Flow) | all OFF | N | |
| Alerts anchor, battle res + lust icons, cursor rings, movement alert, raid tools band, self combat text, shifter, waypoint, upgrade calc, auto logging, /keys | M | | Y (cursor, raid tools) | |
| Radial palette (Quickdraw idea) with secure in-combat selection | M | | Y | backlog after parity |

**Options / onboarding / locales**
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Schema renderer (F7), cog popups, apply-to-all, previews for every module | P | | Y | |
| Global search (F6), profile export/import, profile sync groups | P/M | diff before import | Y | |
| First-install module picker + look picker, one-time announcements, video guide links | P | | Y | |
| Translations for 8 locales + Arabic generated from schema | M | | N | key coverage ≥95% |

### 15.4 Revised order (replaces §13.12; §11 phases keep their acceptance rules)
1. In-game check of current build (unchanged).
2. **Foundations**: F1 Auras engine, F4 CVar ledger, F5 gate, F8 services, F7 schema renderer + F6 search.
3. Profiles (export/import/copy) + **F2 Overrides**.
4. Unit Frames + Player Aura Bars on F1.
5. Raid & Party (Buff/Debuff managers, click-cast hovercast, tiers, grid mode).
6. Nameplates (bundle pool, cast dispatcher, Rules engine).
7. CDM rewrite on Blizzard viewer + Action Bars depth + Resource Bars engine fills.
8. **F3 Studio v2**.
9. HUD (minimap collector, data-bar engine), Chat engine, Vault views, Embers/Ascent depth, Reminders.
10. QoL systems, Pulse/Arena/Spark, radial palette.
11. Translations, plugins, release.
Every step: mockups first where Mock = Y; each PR updates this section's St column and `CHANGELOG.md`.

### 15.5 Hand-read corrections (pass 2, 2026-10-26)
Read by hand so far: DamageMeters main file and Lifecycle (full), the Window refresh core, and the first 260 lines of Nameplates AuraContainers. The tracking column is `hand_read` in `COVERAGE.tsv`. The remaining module files are still parse-only and are tracked as `no` (see the report).
- **Embers segment engine (new F-level item for Embers):** one shared refresh ticker, combat-only and visible-only; refresh floor 0.5 s; fetch-time spike guard (defer paint when the API takes >1.5 ms); segment token; `ENCOUNTER_START` as a hard boundary; kill vs wipe freeze rules; group-still-fighting poll with a 5 s failsafe; teammate-pulled-first pre-warm; PvP match end; post-combat declassify refresh at +0.5 s; source-key snapshot on `ADDON_RESTRICTION_STATE_CHANGED`. All timing goes through `PUI.Ticker` in our version.
- **Correction (F1):** aura container creation is legal in combat on current 12.1 builds, so pools are warm caches, not hard limits. While auras are secret, anchoring to aura buttons is restricted, so restyles must make zero button calls when nothing changed. Added to F1's acceptance: "restyle inside an M+ key with unchanged anchors produces no restriction errors".
- **Correction (Nameplates):** you can't read per-aura dispellability in restricted content, so purge glow must be done by engine group (Dispellable token).

## 14. Appendix — current schema keys by owner (448)

Generated by `schema_dump.lua`, main-v2 c6213ce.

| Owner | Keys |
|---|---|
| ActionBars | 105 |
| UnitFrames | 89 |
| Skins | 30 |
| RaidFrames | 23 |
| CooldownManager | 22 |
| Flow | 21 |
| ResourceBars | 18 |
| Nameplates | 17 |
| Theme | 10 |
| Embers | 10 |
| GroupFinder | 9 |
| Sentinel | 8 |
| QuestTracker | 8 |
| Ascent | 8 |
| Reminders | 7 |
| Minimap | 7 |
| DataBars | 7 |
| Wisdom | 6 |
| Vault | 6 |
| Tooltip | 6 |
| Chat | 6 |
| Oracle | 5 |
| Loadouts | 5 |
| Studio | 4 |
| Options | 4 |
| Core | 3 |
| ClickCast | 3 |
| Setup | 1 |

The full list is in `keys.tsv` next to this file.

Slash commands: ascent, cd, cdm, copychat, embers, get, help, list, loadout, loc, options, oracle, packs, rl, sentinel (panel, export, copy [all], send, clear, induce, enable), set, setup, studio, test, tour, uninstall, wisdom.

**Missing slash commands from the spec:** keys, way, gg, profile (new/copy/delete/export/import), layout export, debug.
