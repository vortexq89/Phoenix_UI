# Phoenix UI — Master Audit and Plan (main-v2 @ c6213ce, updated 2026-10-26 with I:\ competitor study §13, EllesmereUI deep study §15, the finished-study integration §16 and the retail 12.1 Blizzard UI reference §19)

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

> **2026-10-26 retail 12.1 reference (§19).** The Blizzard UI export from your own client was studied (every Phoenix-priority folder read in full; merged notes in `pui_study/others/RetailUI_MERGED.md`). D-RETAIL-REF is decided. Key changes: the Auras module owns `CustomAuraContainer` (private-aura container anchors are a raid-frame option); opt-in DR = turn on `spellDiminishPVPEnemiesEnabled` and restyle Blizzard's DR tray (the combat log is closed, so Phoenix can't compute DR); new conflict-notice entries for Blizzard's built-in map coordinates, Combat Audio Alerts and objective tracker; chat window 3 is never taken over and chat window 1 stays with Edit Mode; item quality colours come from ColorManager; guardrails G35–G40; lint, menu and settings tests.

> **2026-10-26 finished-study integration (§16).** The whole I:\ study is finished (Auctionator: general player-visible UX ideas only, D-AUC decided 2026-10-26; ElvUI ignored per the user). The settings model for every module is now the EllesmereUI-style live preview (§1.S). The 25 cross-cutting rules are guardrails G1–G25 (§1.G). 23 missing items were added as rows 1.19–1.36 and in §5 and §11 (Phase F0, N, O). Ownership is fixed by the matrix in §1.O. Open questions are in §17 Decisions pending.

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
| 1.6 | Profiles: create/copy/rename/delete UI | B (Core/Profiles.lua, Options/ProfilesPage.lua; in-game check pending) | DB has no Copy/Delete/Rename | ElvUI/EUI have full profile managers | M |
| 1.7 | Spec→profile auto-switch (combat-deferred) | M | none (wizard toggle omitted in PR #14) | EUI, ElvUI (LibDualSpec) | M |
| 1.8 | Spec overrides inside a profile ("Editing as <spec>") | B (in-game check pending) | Core/Overrides.lua: spec layer, "Editing as", promote, provenance; Options/OverridesUI.lua: "Editing as" banner, gold row markers with "Overridden for X" (right-click clears), Overrides list page with Promote/Remove | EUI | L |
| 1.9 | Conditional overrides (party/raid/arena/BG/solo/keybind) | P (in-game check pending) | Core/Overrides.lua: arena/BG/raid/party/solo layers; keybind condition open | EUI | L |
| 1.10 | Export/import `!PUI_` (whole, per-module, CDM-only, layout-only), merge/replace, async decode, media reconcile | P (core `!PUI1!` whole/per-module with checked preview, new/merge/replace built; async decode and media reconcile open) | CDM and Embers have their own strings (CooldownManager.lua, Embers.lua); no core serializer | ElvUI/EUI/Wago | L |
| 1.11 | Wago UI Packs installer hook | M | — | ElvUI | M |
| 1.12 | Migrations (scoped, idempotent, stamped) | B | DB:RegisterMigration/RunMigrations | — | — |
| 1.13 | Public APIs: RegisterPlugin/Skin/DataBlock/OracleProvider/VaultRule/NicknameProvider | P | Core/API.lua registries exist; consumers only partly wired (Skins yes, DataBlock/VaultRule unverified) | — | M |
| 1.14 | Data packs with packVersion/gameBuild warning | P | Reminders/Pack.lua, `/pui packs`; no NPC colour, interrupt, portal or crest packs | — | M per pack |
| 1.15 | `conflictsWith` auto-disable for companion addons | M | replaced by the conflict notice/picker (1.35, D-WT-COMPAT-1): the user chooses which side to turn off | spec 23 | S |
| 1.16 | Accessibility: colour-blind palettes, high contrast, large text, reduced motion, TTS events | M | only `media.fontScale` | spec 22.14 | M |
| 1.17 | Controller/gamepad navigation | M | — | spec 5.17 | L |
| 1.18 | Performance: per-module CPU readout on pages | M | Sentinel Perf.lua samples, not shown in options | spec 8/11 | S |

| 1.19 | **Load-conditions / shared visibility engine** (`PUI.Visibility`): one "where to show" model for every module (instance type, difficulty, combat, spec, group, resting, vehicle, skyriding, pet battle) with a chip picker and a "why hidden right now" readout | B (in-game check pending) | Core/Visibility.lua: rule model, Validate/Describe/Explain, Test() reasons, coalesced event-driven Watch/SetRule/Why, VISIBILITY_CHANGED; schema type `visibility` + Options/VisibilityControl.lua chip picker with live "why hidden" readout; first user: Unit Frames (alpha only, combat-safe) | replaces bespoke collectors (EUI-ABR, TGCD, MA, QST); event-driven state + priority chain, coalesced on the Ticker | M |
| 1.20 | **Binding ledger + cross-module keybind conflict check** (Action Bars, Click-cast, Quickdraw, QoL keys, Embers hotkeys) | B (engine; ledger page open) | Core/Ledger.lua PUI.Bindings: owner override bindings via CombatQueue, Normalise, Conflicts (Phoenix + Blizzard) | owner-tagged SetOverrideBinding*, set+save out of combat; one checker warns at capture time and on a ledger page | M |
| 1.21 | **FrameLedger** for approved takeovers: record parent, points, shown, alpha; restore on disable/uninstall | B (engine; ledger page open) | Core/Ledger.lua PUI.FrameLedger: Take/Release/List, one owner per id, combat-deferred restore | G4/G6; ledger page with owner and restore button | S |
| 1.22 | **Ledger page + "Uninstall Phoenix"**: lists every CVar/binding/frame entry and restores only values that are still ours, to the user's prior value | B (in-game check pending) | Options/LedgerPage.lua (per-entry Restore, Uninstall via Phoenix confirm dialog); Core/Ledger.lua `PUI.Ledger.Summary/Uninstall`, `CVars:RestoreName`, `Bindings/FrameLedger:ReleaseAll` | G6 | S |
| 1.23 | **Async data service** (items, spells, talent strings): owner + generation + timeout; one talent-string service with validated serialisation version; never mutates live config | M | — | fixes SIMC `/simc` silent hang and WT ID-table hang (G20) | S |
| 1.24 | **Versioned import schema**: `!PUI_` envelope validated against a schema version, size-bounded, deep-copied, merge-or-replace with a preview count, private exclusions (gold ledger never exported) | P | extends 1.10 | G19 | M |
| 1.25 | **Plain-text search runner**: generation-tagged Ticker jobs with budget, cancelled on new query; quoted = exact, numeric = ID then prefix | B | Core/Search.lua: Parse/Match (quoted exact, ID then prefix, AND words, tags), budgeted generation-tagged Run/Cancel | G11; used by Ctrl+K, IDs, Quest/DB search, pickers | S |
| 1.26 | **Shared copy dialog** (select-all, explicit hint, no key sniffing) and **chat link handler** via `LinkUtil.RegisterLinkHandler` (existence-checked) or `addon:` links; never hook SetItemRef | B (in-game check pending) | Core/Dialogs.lua Copy + PUI.Links (addon link type via EventRegistry SetItemRef), Options/Dialogs.lua | used by SIMC export, chat URL copy, Diagnostics, "open this Phoenix page" links | S |
| 1.27 | **Own confirm dialogs, no StaticPopup** (avoid rectangles of shown Blizzard popups) | B (in-game check pending) | Core/Dialogs.lua Confirm/KeepOrRevert (Ticker countdown), no StaticPopup | G5 | S |
| 1.28 | **Season data file** `PUI.Season` (current season IDs, dungeons, crests, affix IDs) with live-API fill; nothing hard-coded in modules | B (in-game check pending) | Core/Season.lua: live season/dungeons/affixes, Thresholds, ScoreColor (Blizzard / Raider.IO / own gradient, 4 settings) | WT/EUI-BS hard-coded season tables went stale | S |
| 1.29 | **Shared services** `PUI.Mouse` (one cursor poll), `PUI.Range` (refcounted), `PUI.Glow` (C-side AnimationGroups, shared prefix schema), `PUI.Format` (BreakUpLargeNumbers, locale) | B (in-game check pending) | Core/Services.lua: PUI.Format (2 settings), PUI.Range (refcounted, 1 setting), PUI.Mouse, PUI.Glow (AnimationGroup, RegisterSettings) | owners per §1.O | M |
| 1.30 | **Staged boot**: Ticker-budgeted index slices, fail-closed module status row with an action button, heavy dispatchers start one tick later inside a login budget | P | Kernel boots modules | QST fail-closed pattern, declared deferral | S |
| 1.31 | **Diagnostics `PUI.Diag`** (see §5.17a) | M | Sentinel capture exists | coexist with BugGrabber | M |
| 1.32 | **Developer profiler `/pui profile`** (see §5.17b) | M | Sentinel perf sampler only | opt-in, zero cost off | M |
| 1.33 | **Lint suite inside `/pui test`**: implicit globals and **undefined globals (luacheck-style, with a must-fail fixture)**, undefined refs, OnUpdate, **timers only through the Ticker registry (flags OnUpdate, `C_Timer.NewTicker` and per-object `C_Timer` outside Core/Ticker.lua)**, Blizzard frame writes, unescaped gsub replacements, pattern-from-input, mixed `and`/`or` without parentheses, `SetRotation` with a literal above 2π, OnShow register without OnHide unregister, tooltip SetText without Show; **menu tests** (every Phoenix `Menu.ModifyMenu` modifier is idempotent across re-opens; parent toggle set = union of children; checked state read from the same key list) and **settings tests** (each key's attribute/setting name written and read under one name; reset scopes; timed revert restores; search finds every key including canvas pages); schema coverage (every key visible, searchable, live-applied, resettable) | P (lint.py: implicit globals + Ticker-only timers with must-fail fixtures; undefined globals, menu/settings tests open) | guardrail scripts partial | G15, G25, §19 (Blizzard shipped about 25 undefined-global bugs: isComplete, recipeId, show, isNewStage, questID, animOffset, prevShownStatus, hideUnlessExpanded…) | M |
| 1.34 | **Ownership matrix** (§1.O) enforced by review and by a registry check (one owner per service/feature) | M | — | no duplication or overlap | S |
| 1.35 | **Coexistence detector** (BigWigs, BugGrabber, PGF, FrameSort, Masque, SimulationCraft, Details!/Skada, and Blizzard's own 12.x features: built-in map coordinates `worldMapShowPlayerCoords`/`minimapShowPlayerCoords`/`coordsByTenths`, Combat Audio Alerts, the objective tracker, Damage Meter, Boss Timeline/Combat Warnings, DR tray, Cooldown Viewer, raid dispel indicators): yield their frames/CVars, integrate via public APIs, never write their settings; on overlap show the conflict notice/picker (user chooses Phoenix module or the other addon; nothing changes until they pick; changeable in settings) | P | ad hoc PGF stand-down | G22; generalises 1.15 | S |
| 1.37 | **Blizzard 12.x feature page** ("Midnight features"): live state of each native system (Combat Warnings, Boss Timeline, Damage Meter, External Defensives, Cooldown Viewer, DR, Combat Audio Alerts, map coords) with the "why unavailable" reason from its IsAvailable/IsSystemSupported API; each overlap with a Phoenix module goes through the conflict notice (1.35) | M | — | §19 | S |
| 1.38 | **Retail reference data in the build**: deprecated-API denylist, current CVar list, secret-returning and NotAllowed-argument lists generated from the 12.1 export (`retail_ref/*.tsv`) and checked by the lint suite | M | data generated on the box | G31, D-RETAIL-REF | S |
| 1.36 | **Phoenix chat hyperlinks** ("open this page") and **Blizzard Settings entry** (one "Open Phoenix" button, opens our panel next frame) | P | — | WT pattern, original code | S |

### 1.S Settings model for every module (EllesmereUI-style live preview — user direction t53u)
- Every setting applies live, with no /reload. A key that can't be live-applied can't exist (G25).
- Every page opens with a **live preview drawn by the module's real paint code**, fed fixed sample values (fake roster, cycling auras, sample casts, sample numbers). No second preview implementation.
- **Every design choice is a user setting (D-MOD-DEF, user direction t71u):** each look, layout or behaviour shown in a mockup is a setting with Simple and Advanced options; defaults are only first-install starting points, never fixed design.
- **Simple first, advanced expandable**: the common rows show by default; depth sits behind a per-row cog or an "Advanced" expander.
- **No code required, ever.** Wherever a power-user expression or raw tag exists, a visual builder produces it (tag chips, filter builder, trigger builder, rule rows).
- Every disabled control says why; every feature has its own reset; changed values show a reset dot and tint.
- Widget contract: slider with typed input; keybind capture with conflict warning (1.20); colour picker whose Cancel restores the old colour and commits debounced while dragging; Escape reverts, Enter commits (G10); keyboard/controller focus.
- This replaces any ElvUI-style reference: ElvUI is ignored by the user's direction.
- **Override stack (QDB):** `default < profile < spec < character < temporary (preview/test)`, recomposed at read time. Every row shows who set its value (provenance). A layer overrides fields and never deletes the row below; withdrawing restores the one below exactly; re-enabling never reorders; a user delete is sticky; atomic values (anchor point + offset) are replaced whole; the temporary layer never writes saved data. Only non-default values are saved; presence is kept apart from value.
- **Apply model (WAPI):** live apply stays the default; staged Apply/Revert only for expensive or relayout settings; a timed "Keep these settings?" revert (Phoenix's own dialog) for UI scale and layout swaps; snapshot on open, Cancel restores, Undo confirmed. One shared flag pass for anything needing a reload (should never be needed, G25).
- **Rows (WAPI):** built from data tables, one key per row for label/reader/writer; parent/child indentation with predicates re-evaluated on parent change; confirmation intercepts; per-row callback handles released on recycle (asserted empty); the list repairs in place and keeps scroll position; per class+spec layouts with last-used memory and an explicit "use default".
- **Settings ideas (retail 12.1, §19):** commit class per setting (live by default; *confirm* only for UI scale/layout swaps, with a Ticker-driven 10 s keep/revert); reset with three scopes (this page / this module / everything), each confirmed and firing events so previews redraw, protected rows skipped; revert/Undo to the snapshot taken on open; search with AND semantics, debounced, synonym tags, covering canvas pages too, mirrored rows deduplicated; "NEW" badges keyed by the version a setting was introduced, shown until seen or N versions later, bubbling to the sidebar; hovering a dropdown option previews it live and reverts on close; visible vs enabled predicates with "why disabled"; one column at large accessibility text scale; colour-blind palette on `colorblindMode`.
- **Settings panel layout (mockups `pui_mockups/settings/` 01–07, decided 2026-10-26, D-SET-UI):** a floating window (not docked); sidebar of 11 grouped sections; arena options live only under Combat/Arena (no per-page Arena filter); content profiles (Raid, Arena, Mythic+) store only differences from Base and switch automatically by content, **on by default** (toggle on the Profiles page; switch is combat-deferred and atomic).
- **Blizzard Settings panel (WAPI):** Phoenix registers there too (AddOn/proxy settings) so Blizzard search, defaults, restart-required marks, recommended/warning lines and per-version "new" badges work. Retail: one Canvas category "Phoenix UI" (`Settings.RegisterCanvasLayoutCategory` + `RegisterAddOnCategory`) as a launcher; OnDefault routes to Phoenix's scoped reset with a confirm (Blizzard's "All settings" defaults calls it); never touch Blizzard's settings tables.

### 1.G Guardrails (cross-cutting rules G1–G25, from the finished study)
These are in force for every PR alongside the standing rules (original code only; live apply; no OnUpdate outside the Ticker; secret values to widgets only; done = guardrails + `/pui test` + in-game check). "Source" names the behaviour seen in the studied addons that each rule prevents; no code was copied.

| # | Rule | Source (bug it prevents) |
|---|---|---|
| G1 | **Secret values go only to widgets** (SetValue, SetText, SetFormattedText, a colour curve, an engine container). Never compare them, do arithmetic on them, or use them as table keys. Use `issecretvalue`/`canaccessvalue` before any logic, and place the check *before* any `or ""`-style coercion. | WT's IsSecretValue was implemented as a nil check. Unguarded compares in EUI-RB (icicles, stagger, Devourer, Maelstrom), EUI-RF (lossPct, display name) and EUI-DM (pcall wrapped only the read). EUI-AB's count froze after a coercion-before-check throw. |
| G2 | **No OnUpdate.** All timing runs through PUI.Ticker, with self-disarming subscriptions. Animations use C-side AnimationGroups or duration objects (SetTimerDuration, SetCooldownFromDurationObject). Fixed-step animation is banned. | EUI-RB's 0.016 s fixed step slowed animation at low FPS, and it ran 4×60 Hz tickers per bar. AQ and QST polled forever. MA, EUI-OPT popups and EUI-CH idle fade used OnUpdate. |
| G3 | **Protected work goes through CombatQueue.** Drain is event-driven (PLAYER_REGEN_ENABLED) with a frame budget, and entries are deduplicated by key, so ten "update tracker" calls become one. | QST polled at 10 Hz. WT's TaskManager had no dedupe. EUI-DB hid/showed secure content in combat (ADDON_ACTION_BLOCKED). |
| G4 | **No edits to Blizzard frames, globals or shared metatables.** This means no SetScript, function replacement or reparenting of Blizzard secure frames. Use hooksecurefunc/HookScript only, and keep per-frame state in external weak tables, never fields on Blizzard frames. Any approved takeover goes through FrameLedger (record parent, points, shown state and alpha; restore on disable). | AQ replaced a global dialog function. WT nop'd map-pin mixins and extended the FontString metatable. SAR reparented CompactArenaFrame with no restore. EUI-BG's hooks are permanent with no undo. BW caches unhooked globals "in case others hook them". EUI-UF: a `.unit` field taints PingManager. |
| G5 | **Never toggle Edit Mode from code, and never enter StaticPopup lists.** Phoenix uses its own confirm and copy dialogs and avoids the rectangles of shown Blizzard popups. | SAR's Edit Mode toggle caused the MirrorTimer bug. QT flagged StaticPopup as an Edit Mode taint vector. |
| G6 | **Every CVar, binding and frame takeover is ledgered.** Writes are owner-tagged and restored to the user's *prior* value, never to a hard-coded "1" or a default. Persistent CVars are never re-asserted at login. | EUI-BS forced UberTooltips at every login. EUI-OPT (D2b) set scriptErrors=0 by default. BW wrote encounter CVars without a ledger. SAR forced DR/PvP colour CVars. EUI-QOL lost its weSetCVar flag after reload. BW's reset left an override binding active. |
| G7 | **Errors are never hidden by default.** Error suppression is opt-in and visible. | EUI-OPT (D2b) set scriptErrors=0 at every login. |
| G8 | **One settings scope per data set.** Seed flags, positions and links live in the same scope as the data they describe. | EUI-BG seed flags were account-wide while the data was per profile, so new profiles were never seeded. EUI unlock links were global while positions were per profile. EUI-BS mixed scopes. |
| G9 | **Read-time override layering** (`condition → spec → profile → default`), never swap-and-harvest of live values. Transitions are guarded so they always reset their latch on error. | EUI's spec-override data loss, `_condBusy` freezing until /reload, override values leaking onto shared entries. |
| G10 | **Save before apply, and revert on every hide path.** Each popup or editor holds a draft and commits or discards it as a single transaction. Escape *reverts* and Enter commits. A colour picker's Cancel restores the old colour. | EUI-OPT inputs: Escape actually committed. MSBT popups wrote caller tables directly. EUI-FE closing a window mid-commit rolled back a learn. EUI-OPT font change saved before the reload prompt, leaving the screen out of step. |
| G11 | **Plain-text search everywhere.** Use `find(s, q, 1, true)`. Quoted means exact; numeric means exact ID first, then prefix. User input is never used as a Lua pattern. Searches are generation-tagged Ticker jobs with a budget and are cancelled when a new query starts. | QST slash command crashed on `/q (`. PGF article filter used `|`, which Lua patterns don't support. |
| G12 | **Escape every substitution.** Any user or game text placed into a gsub replacement is %-escaped. | MSBT %e/%a/%t replacements. SAR's `@arena` substring bug rewrote arenapet. |
| G13 | **Maps: open with `C_Map.OpenWorldMap(mapID)`, never SetMapID on the frame.** Use `C_Map.GetMapChildrenInfo` plus GetMapRectOnMap for zone↔continent transforms, cached lazily per session. Nothing static ships. | Questie.md Pass 4b (QuestieCompat: OpenWorldMap and GetMapChildrenInfo usage) and QT #6. |
| G14 | **Never mutate Blizzard UI state in order to read it.** Use ByID APIs (reputation, trade skill) and never expand or collapse headers. Never write Blizzard LFG tables, the AH saved filter, or Blizzard_CombatLog filters. | QT #3. EUI-FE scanned only expanded rep headers. AQ cleared `LFGListFrame.declines`. PGF wrote back the results table. EUI-QOL wrote the AH filter. MSBT wrote a combat-log filter. |
| G15 | **No globals.** Lint for implicit globals and undefined references. Forward-declared locals are fine. | EUI-CDM `GetBarData`, `FOCUSKICK_BAR_KEY`, `_focusKickIsHealer`; EUI-UF `_cpExpectedParent`; EUI-BG `sidebarChild`; EUI-BS `dialog`; MSBT undefined validator; BS and MA global names. (MSBT bug 1 was retracted: lesson learned.) |
| G16 | **Locale-safe logic.** Use IDs, enums and Blizzard global strings. Never match English chat or tooltip text, and never truncate by bytes. | EUI-QOL Hero/Myth scan, QST loot strings, SAR healer names, PGF affix names, MSBT English summaries, EUI-DB byte truncation and hard-coded ",". |
| G17 | **Versioned, idempotent, snapshot-first migrations.** Never inside constructors or import paths. Never reset user settings: convert old settings; if one value fails to convert, back it up, tell the user, and reset only that setting (D-WT-MIGRATE-1, decided). | EUI-DB factory silently migrated. SAR ran 12 flag migrations and forced drResetTime. EUI-RF migrated every profile at every login. WT migrated only the active profile. |
| G18 | **Pure reads.** A getter never writes defaults, prints anything or mutates the profile. Hot paths never write saved settings. | MA IsEnabled had side effects. EUI-RB Enhancement threshold was written from the update path. EUI-OPT mouseover mode mutated the profile. |
| G19 | **Copy means deep copy.** Profiles and imports are deep-copied, validated against a versioned schema and bounded in size. There is a merge-or-replace choice with a preview count. | MA profile copy created an alias. MSBT copy overwrote an existing profile. BS received payloads with no size limit or allow-list. |
| G20 | **Async with owner, generation and timeout.** Item and spell loads carry the requesting view's generation plus a timeout. Stale results are dropped, and a never-firing callback can't block a window. | SIMC `/simc` silently never opened (bug 8). WT's ID table never completed on an invalid ID. MSBT stale timers (the generation counter is a good pattern). |
| G21 | **Event-driven, demand-gated modules.** No events are registered while a feature is off or empty, and none outside their content (for example arena). Hooks are installed once and gated by the enable flag. | WT UnhookAll was a no-op. EUI-CDM demand gate (good). SAR zero-cost-outside-arena (good). QST forever tickers. |
| G22 | **Coexist; don't compete.** Detect BigWigs, BugGrabber, PGF, FrameSort, Masque and SimulationCraft. Yield the frames and CVars they own, and integrate through their public APIs. Never write another addon's settings (D-WT-COMPAT-1). | BW frame ownership. BGr/BS contract. PGF stand-down. |
| G23 | **Pixel-perfect integer maths.** Compute sizes in physical pixels, then multiply by the scale. Centre snapping is parity-aware. | EUI-CDM float-dust bug (3×21.666 → 81). EUI-RB 1 px drift on spec swap. |
| G24 | **Stable keys, not indexes**, for selection, journal entries and profiles. Avoid `pairs` order wherever order matters. | MSBT index selection. EUI-FE and PGF nondeterministic `pairs`. QST journal. |
| G25 | **Every setting is schema-declared.** Each one carries an apply target and a struct/style/geo/filter tag. The page, search, defaults, reset and fingerprint are all generated from that one declaration, so a key that is never live-applied can't exist. | EUI-RF FP lists were maintained by hand. EUI-OPT duplicated defaults (pushed default 3 vs 2; pipWidth 214 vs 220). Shift X/Y stored nil at 0. Two swatches edited one key. |
| G26 | **Validate, then publish (all-or-nothing).** Settings writes, imports and conflict-picker choices are staged and checked at entry; a rejected change leaves UI, caches and provenance untouched and names module/setting/value. | QDB correction engine; Blizzard staged settings skipped type checks until Commit. |
| G27 | **Refuse, don't default.** Unknown key → nil + Sentinel note; unknown spec/client/API → feature off (fail closed); exact tokens for slash arguments; presence kept apart from value. | QDB getters could not tell explicit 0 from absent; registry returned a fake owner. |
| G28 | **Heavy work is time-sliced and scoped.** Login/zone-in scans yield, publish only complete results and restart on invalidation; invalidate only what changed; decode on first use. | QDB "script ran too long" at login; 67 ms apply storm. |
| G29 | **No aliasing, no mutation during iteration.** Handed-out tables are copies or frozen; copy at the save boundary; never remove from a table inside its own loop. | QDB aliasing write-through; Blizzard buff frame tremove-in-pairs. |
| G30 | **Events match handlers.** Every handled event is registered and vice versa; unit events via RegisterUnitEvent; heavy events only while shown. | Blizzard arena/castbar/buff frames handle unregistered events. |
| G31 | **Retail API hygiene.** A deprecated-API denylist (retail 12.x) and a current-client CVar list fail the build on use of removed names. | WAPI Manual/Deprecated list (UnitAura, GetSpellInfo, IsAddOnLoaded…). |
| G32 | **Isolated callbacks.** Module registration, apply, menu and settings callbacks run protected; one failure never blocks other modules and is retried later. | Blizzard Settings panel isolates each addon canvas. |
| G33 | **Timers are owned.** Cancel the previous timer before arming a new one; throttles reset their accumulator; clocks are event or Ticker driven. | Blizzard double revert timers; never-reset resize throttle. |
| G34 | **IDs, not names; correct maths.** Never match by display name when an ID exists; no `bit.*` masks over 32 bits; WoW global trig uses degrees. | QDB race masks above 32 bits; WAPI compat notes. |

| G35 | **Branch-free secret visibility.** Visibility derived from a secret calls every SetShown/SetAlphaFromBoolean branch unconditionally, or maps through a `C_CurveUtil` curve, so call counts never leak the value. | Retail EncounterTimeline makes all five SetShown calls for the deadly flag. |
| G36 | **Secrecy spreads through bounds.** Containers that auto-size ignore children that can show secrets (`ignoreChildrenForBounds`) or use fixed sizes; a frame anchored to an AuraContainer first copies its inheritable forbidden aspects (`AddForbiddenAspects`) or anchors to a fixed-size proxy. Never measure secret text (whisper tabs use a fixed width). | Retail CDM settings items; TargetFrame cast bar under the aura container; FloatingChatFrame secret names. |
| G37 | **Pool release resets everything**: text, alpha, animation alphas, cached numbers, and Duration/timer references (`SetMinMaxValues(0,0)` on bars). One acquire→release→acquire test per pool. | Retail EncounterTimeline recycle fix; ObjectiveTracker oldValue/oldPercent flare bug; AuraContainer ReleaseAllFrames leak. |
| G38 | **Hands off Blizzard-owned text and windows.** Never write into secure edit boxes (`SetSecurityDisableSetText`: LFG listing name/description, search box); never take over chat window 3 (voice transcription); chat window 1 is placed only by Edit Mode; never toggle or override Edit Mode system methods. | Retail LFGList, VoiceChat, ChatFrame1 Edit Mode system. |
| G39 | **Hide, don't disable, Blizzard addons.** Edit Mode re-enables Blizzard_ObjectiveTracker and Blizzard_CompactRaidFrames at every load, so Phoenix hides at runtime (e.g. `ObjectiveTrackerManager:SetCanAddModules(false)`) after the conflict notice, and restores on disable. | Retail EditModePresetLayoutsManager. |
| G40 | **Colours from the colour system.** Item quality colours come from `ColorManager.GetColorDataForItemQuality` (honours the user's `C_ColorOverrides`); power colours from `PowerBarColor` keyed by Enum; never hard-coded tables. | Retail ColorManager; PowerBarColor index-4 CHI bug. |

Every lint rule above ships with a self-proof fixture that must fail (QDB). Full lint additions and test-harness rules: §5.17c and §18.

### 1.O Ownership matrix (one owner each — no duplication or overlap)
| Feature | Claimed by | Owner / resolution |
|---|---|---|
| Spell/cast history | EUI-DM Spell History, TGCD | **Cast History (B11)** owns it. Embers only links to it. |
| Cast bars | Unit Frames, Resource Bars, Nameplates, Arena | One castbar **element** in Core (paint + dispatcher). Modules instantiate it, and the 13-event dispatcher is shared. |
| Aura display | UF, Raid, Plates, Arena, Player Aura Bars, CDM buff bars, weapon enchants | **PUI.Auras (B7.1)** is the engine and **owns `CustomAuraContainer`** (Blizzard's public secure aura framework: AddAuraGroup/AddAuraSlot/AddItemEnchantment, CustomAuraButton Set* calls, DurationTextBinding). Surfaces only configure it. **Private-aura container anchors** (`C_UnitAuras.AddPrivateAuraAnchor` with max-buffs/max-debuffs/dispel-indicator attributes) are an **option for raid frames**, configured through PUI.Auras; needs an in-game test on addon frames. CDM buff bars stay on Blizzard viewer data (no own aura calls). |
| Range | Raid fade, plates, target distance, Arena | **PUI.Range** service, refcounted. |
| Visibility / "where to show" | Every module | **B1.4** load-conditions engine. |
| Glows | Action Bars, CDM, Raid, Arena | **PUI.Glow**. |
| Movers | Studio, MA-style window mover, per-module unlock | **Studio (B3)** registry. Modules register; none build their own drag. |
| M+ timer | Ascent (EUI-MT), QST challenge timer | **Ascent** owns it. The quest tracker shows nothing for keys. |
| Encounter timers / warnings | Pulse, BigWigs | Conflict notice/picker (D-WT-COMPAT-1): the user chooses Pulse off (with BigWigs bridge, R22) or BigWigs off; nothing changes until they pick. |
| Group-finder filtering | GroupFinder, PGF | Conflict notice/picker (D-WT-COMPAT-1/D-PGF): the user chooses Phoenix's Group Finder module off or PGF off; nothing changes until they pick. |
| Error capture | Diagnostics, BugGrabber/BugSack | Coexist: become a display on BugGrabber's callback. |
| Profiles | TGCD, MSBT, SAR, MA (own stores) | Only the **Core profiles**. Modules hold no profile store. |
| Key bindings | Action Bars, Click-cast, Quickdraw, QoL FPS key, DM hotkeys | **Binding ledger** plus one conflict checker across all of them. |
| CVars | Nameplates, Arena, Combat Text, QoL, Flow | **CVar ledger**. With BigWigs loaded, its encounter CVars are excluded. |
| Group-age tooltip line | AQ, PGF, Phoenix GF | One line from GroupFinder. Skipped when PGF is loaded. |
| Number formatting | DM, Data Bars, Combat Text, UF tags | **PUI.Format**. |
| Copy box | SIMC, WT, Chat URL copy | One shared copy dialog. |
| XP/Rep bars | Action Bars (EUI-AB), Data Bars | **Data Bars** owns the blocks. The XP/Rep bar is a Data Bars template. |
| DR display | Arena, Blizzard SpellDiminishUI | **Arena** owns the opt-in: turn on `spellDiminishPVPEnemiesEnabled` (CVar ledger, prior value restored) and restyle/position Blizzard's DR tray. No Phoenix DR maths (combat log closed). |
| Map coordinates | HUD Minimap, Data Bars coords block, Blizzard built-in coords | Conflict notice: the user chooses Phoenix coords or Blizzard's (`worldMapShowPlayerCoords`, `minimapShowPlayerCoords`, `coordsByTenths`); nothing changes until they pick. |
| Audio alerts | Reminders/Pulse sounds, Blizzard Combat Audio Alerts | Conflict notice for overlapping cues; Phoenix offers a friendly page over Blizzard's CAA settings and custom pulse sounds (`SetPulseHealthSoundKit`), never its own reading of secret values. |
| Objective tracker | Quest Tracker, Blizzard_ObjectiveTracker | Conflict notice; when Phoenix's tracker is chosen, `ObjectiveTrackerManager:SetCanAddModules(false)` (restored on disable). Never DisableAddOn (G39). |
| Chat windows | Chat, Edit Mode, Voice | Chat skins every window; **chat window 1 is placed by Edit Mode**; **chat window 3 (voice transcription) is never taken over**. |
| Item quality colours | Tooltip, Vault, Skins, Chat | `ColorManager.GetColorDataForItemQuality` (G40). |
| Death recap / death log | Embers, Ascent | **Embers** (C_DeathRecap). Ascent's M+ death log lists deaths and time lost and opens the Embers recap. |
| Interrupt counts (party kicks) | Embers Interrupts meter, Ascent kick tracker, run-summary Kicks column | **Embers** (C_DamageMeter interrupts). Ascent reads the segment engine. |
| Own kick readiness (kick tick, your kick CD) | UF, Plates, Arena, CDM Focus Kick | One own-interrupt state inside the Core castbar element (§1.O cast bars). |
| Target/focus cast bars | Unit Frames, Ascent "standalone", CDM Focus Kick | **Unit Frames** (target/focus) and the **CDM Focus Kick bar** (focus + kick). Ascent links to them. |
| Player cast bar / class resource | Unit Frames, Resource Bars, target plate | **Resource Bars** owns each element; UF and Plates only host them (setting: attach here / keep separate). |
| Keystone data, /keys, insert/auto-slot keystone, M+ countdown | Ascent, Flow, Group Finder (EUI keystone insert), Vault shelf, BigWigs tools | **Ascent Keystones**. Flow and GF rows link to it; Vault's shelf is only a bag category; the countdown is Raid Tools'. |
| Pull / break / M+ countdown, /cd | Raid Tools, Flow `/cd`, Ascent, Pulse | **Raid Tools** (C_PartyInfo.DoCountdown). `/cd` is an alias; Pulse draws the bar. |
| Raid markers, ready check | Flow, Raid Tools | **Raid Tools**. |
| Combat / encounter / stage timer | Embers standalone timer, BigWigs-style stage timers, QoL | One **Combat & encounter timer** on the Pulse page; the Embers header reads it. |
| Battle res + Bloodlust | Ascent M+ block, combat tools | One **Ascent** widget, docked in the M+ block or standalone. |
| Combat enter/leave alert | WindTools alert (QoL), Spark notification | **Spark** "combat in/out" event; the QoL alert is a Spark preset. |
| Item / potion cooldown ready | Spark, EUI Alerts "potion ready", CDM ready sound | **Spark** item-cooldown-ready event; CDM keeps its own icon sound. |
| Combat text CVars, self combat text | Spark, Core Combat CVars, QoL | **Spark** (3×2 Blizzard SCT switches via the CVar ledger). Other pages link. |
| Loot / money / rep / XP text, loot feed (Forever) | Spark, Forever | **Spark** notifications; the Forever loot feed is a Spark area preset. |
| Announcements (quest, keys, resets, interrupts, meter reports) | Chat, Quest Tracker, Loadouts, GF, Ascent, Flow, Embers | One **announcement router** (QoL). Modules only choose what to send. |
| Role-check accept, sign-up confirm, role per spec | Group Finder, Flow role-check confirm, BigWigs auto-role | **Group Finder** queue helper; "auto from spec" is a mode of the one role-per-spec setting. |
| Queue-pop countdown, queue status | Group Finder, Skins queue popup timer, Minimap queue eye | **Group Finder**; Skins and Minimap reuse it. |
| Arena match timer, dampening, Shadowsight | Arena, Flow dampening display | **Arena**. |
| Party⇄arena targeting dots | Arena, Raid frames | One **Arena** targeting service; raid frames display it. Built as `PUI.Targeting` (Core/Targeting.lua) for Arena to reuse. |
| Junk definition, sell junk, auto-sell | Vault, Flow sell junk | **Vault** (rules define junk). Flow's row links here. |
| Gold ledger, currencies | Vault, Data Bars gold/currency blocks | **Vault** (has offline alts); Data Bars blocks read it. |
| Equipment sets | Vault builder, Loadouts | **Loadouts**; Vault shows set names and opens Loadouts. |
| Waypoints (/way, super tracker) | Quest Tracker, Flow, EUI QoL | **Quest Tracker** super tracker; Flow `/way` links. |
| Skip cinematics, talking head, toasts, auto-accept res | Flow, WindTools QoL, BigWigs BossBlock | One **Quiet mode** row set in Flow per content type plus per-instance overrides; every option OFF at first install (D-MOD-DEF3). |
| Auto combat logging | Flow, Ascent study | **Flow** (per content, Recorder compatibility). |
| Enemy forces % (tooltip, plate text) | Ascent, Tooltip, Nameplates | **Ascent** provides forces data; Tooltip and a Nameplate text slot display it. |
| M+ score colours | Tooltip, GF rating, Data Bars | **PUI.Season** (1.28) colour source (Blizzard / Raider.IO / custom). |
| Window sets by content | Embers auto-switch, content profiles | **Core content profiles** (D-SET-UI); Embers has no own switcher. |
| Threat meter (Forever) | Embers, §5.20, §13.10 | **Embers** window type, code in `Phoenix_UI_Forever`. |
| Extra item bar | Action Bars, Quickdraw, CDM custom bar | **Action Bars** clickable item bar; CDM custom bar is display-only; one item-list service feeds both. |
| Buff bars | Player Aura Bars, CDM tracked buff bars | Both stay (different sources); new dedupe setting hides an aura already shown in CDM bars. |


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
| 2.10 | Border picker, colour picker (HSV, recents, class/accent swatches) | P (colour type + picker with alpha, accent/class swatches; recents and border picker open) | no colour type in the schema | M |
| 2.11 | Keybind capture widget | B (conflict note vs Blizzard bindings; binding ledger 1.20 open) | Oracle key is text | S |
| 2.12 | List editor (reorder), rule editor, aura picker, visibility-rule editor, tag editor | P (list editor and per-content grid built; rule/aura/visibility/tag editors open) | lists are stored as text keys (`db.bar1.blocks`, `chat.keywords`, `cc.bindings`, `loadouts.rules`, `wisdom.weights`) | L |
| 2.13 | Cog popups / sub-settings per row | M | — | M |
| 2.14 | Deep links (`/pui options <key>` scroll-to/highlight) | P | page/search only | S |
| 2.15 | Theme & Media page | B | ThemePage.lua | — |
| 2.16 | Panel themes (Phoenix/Dark/Class/Faction/Custom) | P | accent and panel material only | S |
| 2.17 | Pixel-pinned options scale | M | — | S |
| 2.18 | Sentinel page (mockup 14) | B | SentinelPage.lua | — |
| 2.19 | Plugins page (mockups P1–P3) | M | design only | (see section 9) |
| 2.20 | Reset all, reset module | P | per-page Reset; no reset-all | S |
| 2.21 | Localised labels at the render boundary | P | PUI.L used in Studio; options labels not wrapped everywhere | S |

**Menus (WAPI, 2026-10-26):** retail Menu API only (no legacy dropdown); regenerate on open; mouse-wheel cycles radios; one menu stack with a close-to-level primitive; ~0.3 s hover delay, immediate clicks; layout measure → columns → common width → scroll/grid → flip → clamp; close when the owner hides or on an outside click; a tag-based "modify menu" hook so modules extend each other's menus. Drag-reorder with explicit cancel, drop markers and empty-slot targets; filter dropdowns with a Reset "x"; disabled rows restore their cached enabled colour and desaturate icons.

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

- **Study additions (§16):**
  - Mover registry entries {key, label, frameGetter, kind, defaultPoint, minSize, resizable, active, options schema}; drag on Ticker/animation callbacks (no OnUpdate); positions as centre offsets in UIParent units snapped by parity (G23); combat moves parked via CombatQueue; Edit Mode never toggled from code (G5); undo/redo; anchor cycles reported, not hidden by pcall; position links in the same scope as positions (G8).
  - **Window mover (new):** move/scale Blizzard panels, registry keyed by Blizzard_* LoD addon (ADDON_LOADED), Phoenix overlay handle on the title region, HookScript + FrameLedger only, no reparenting of aura containers.
  - **Importers from other mover addons (new):** one-shot, read-only, user-triggered.

- **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — Studio (MoveAny):** Move/resize ~130 Blizzard elements → Added a Blizzard-element mover list using Edit Mode where it owns the frame, otherwise FrameLedger (off by default, full restore); Alpha by state → Added skyriding, pet battle and zone states to the shared engine; Make Blizzard windows draggable and remember positions → Added 'Move Blizzard windows' (off by default, FrameLedger, reset off-screen, confirm before clearing).

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

- **Study additions (§16, 2026-10-26):**
  - Unit engine: one tracker per unit with RegisterUnitEvent, painters per channel, vehicle handled at registration; unit kept in secure attributes only (never a `.unit` field — taints PingManager); secure unit-menu proxy for the 12.1 togglemenu bug.
  - Cast bar is the shared Core castbar element (§1.O) on UNIT_SPELLCAST_* events; aura bottom reserve from live geometry in physical pixels (G23).
  - Text tags without code: token chips + format dropdown; raw tag field optional for power users; secret-safe formatters (UnitHealthPercent with a curve → SetFormattedText) so a secret value never shows 0.
  - Per-frame visibility via 1.19 (fade out of combat, resting alpha, show when health missing, solo/party/raid).
  - Auras only through PUI.Auras (F1); `C_UnitAuras.AddAuraSound` for gain sounds.
- **Study (WAPI):** cast bar is one castID-matched state machine (casting/channeling/empowered/hold/fade), queries its own unit on show, uses duration-object timers (12.x secret-safe), unit-scoped events only.

### 5.2 Raid & Party — step 4 built (RaidFrames.lua, Elements.lua, Indicators.lua, ClickCast.lua)

- **Step 4 status (feat/groupframes):** size tiers with auto/fixed choice and Mythic cap; sorting; role icon/letter, dispel highlight (border/glow/tint, mine/all, type colours); debuff/buff/defensive containers and corner indicators on PUI.Auras with healer presets; private-aura anchors; enemy-target dots from `PUI.Targeting`; click-cast list editor with composer and ledger reservations; range, absorbs, heal-absorb and incoming heals via `PUI.Prediction` with overflow marks; test mode and where-to-show per content; live Options preview. The table below is the pre-step-4 snapshot; §15.3 rows carry the current status.


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

- **Study additions (§16, 2026-10-26):**
  - SecureGroupHeader; range fading via PUI.Range; absorb coalescer; FrameSort provider shim; health % via safe paths only; per-frame state in external weak tables; migrations versioned, never every login over all profiles (G17).
  - Indicator manager page (70/30: list left, live preview right, spec selector, healer-spec presets) over F1 containers + a declarative indicator list. Honest notes where 12.1 secrecy blocks a mode ("missing/allPresent", frame alpha) instead of silent fallback.
  - Click-cast + Hovercast: global / options / per-spec columns, conflict warning via 1.20, WrapScript or persistent secure button, all changes via CombatQueue.
  - Aura-icon tooltip on modifier (secure motion eater).
- **Study (WAPI, raid frames):** frames reserved by player GUID across sorts; batched layout (pause → add → resume); tank/assist + target + ToT as one atomic group; total-order sorts with deterministic fallback; permission-gated controls rebuilt on leader/roster change; one typed setting dispatcher (booleans normalised); one shared heal-prediction/absorb renderer for raid, party, unit and arena; StatusBar setters only; positions as screen-half-relative anchors clamped on all edges; one shared flash clock for expiring auras; auraInstanceID deltas.

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

- **Study additions (§16, 2026-10-26):**
  - Own plate pool with prewarm; overlays created lazily for target/focus only; quest mobs via C_TooltipInfo (cached, locale-safe); friendly name-only mode rides Blizzard's own name FontString.
  - Visibility CVars written only on explicit intent, via the CVar ledger; never re-asserted at login (G6).
  - Aura lanes: pre-created container bundle attached/detached on NAME_PLATE_UNIT_ADDED/REMOVED; purge glow by engine group.
  - Cast dispatcher: the 13 SPELLCAST events registered once globally and shared with every castbar (§1.O); kick-ready tick, interrupted flash, cast target.
  - NPC rules engine as visual rule rows (NPC, colour, scale, glow).
- **Study (WAPI):** unit-scoped events; no aura events when no aura lane is on; click insets from visual bounds with a minimum hit height; forbidden plates untouched.

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

- **Study additions (§16, 2026-10-26):**
  - Secure controller with restricted map; showgrid bitmask; state-driver paging; SetOverrideBindingClick through the Binding ledger (1.20); range via ACTION_RANGE_CHECK_UPDATE; bar dormancy.
  - Counts guarded by secret checks *before* any coercion (count-freeze bug); durations straight to SetCooldownFromDurationObject, never memo compares (stale swipe); assisted-combat slot spam excluded.
  - Preview uses the real button paint (no drifting second implementation); apply-to-all has undo and never copies mouseoverAlpha into transparent bars; shape change never overwrites fonts.
  - Micro/bag bar: own buttons calling Blizzard toggles, vehicle and pet-battle visibility. XP/Rep/House Favor bar is a **Data Bars template** (§1.O).
  - Game Menu button inside the Esc menu (standing rule, D1).
- **Study (WAPI):** secure buttons via attributes/state drivers only; two event tiers (all buttons vs filled buttons); pooled proc glows; step aside for vehicle/override bars; fit-to-space vertical bars with a minimum scale then fold; AnimationGroup slides; "missing from my bars" helper after talent swaps; keybind mode on Blizzard's listener model with conflict report, rollback and save to the current binding set (feeds 1.20).

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

- **Study additions (§16, 2026-10-26):**
  - Hooks OnCooldownIDSet and pool Acquire, queues re-anchor; never SetParent/SetScale/Hide on viewer frames (unclaimed frames get alpha 0); all state in weak external tables.
  - Demand-gated; "store not ready" held and retried; talent debounce; integer-pixel layout (G23); flicker fixed by UnitIsUnit checks; schema-driven re-evaluation instead of once-per-login flags.
  - Spell Picker page (add/swap/move/replace) with live preview and presets; Focus Kick bar; Mirror Key Presses; pandemic sync with nameplates. Buff bars stay on Blizzard viewer data.
- **Study (WAPI):** keep skinning Blizzard's Cooldown Viewer; resolution aura > linked > override > base; late-join aura handling; reconcile saved order (drop missing, append new); class+spec-tagged layouts with last-used memory; events only while shown; edit-mode placeholders with paused timers and a minimum item count; one ordered visibility function; stable hidden slots; search cache invalidated on talent change.

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

- **Study additions (§16, 2026-10-26):**
  - Colour curves (Step ColorCurve) and hidden one-slot aura containers for spec helpers: zero Lua per frame; memoised ticks; smoothing via C-side animation, never fixed-step (G2); one Ticker subscription per bar group, not 4×60 Hz per bar.
  - Threshold bands drawn on the preview with their meaning stated; growth settings that are live (no dead keys).
  - GCD, swing, totem and cast bars on duration objects; a GCD change applies only its own target.

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

- **Study additions (§16, 2026-10-26):**
  - **Tooltip IDs (27 kinds)** + derived IDs (icon, use-spell, enchant, bonus, gems) merged per kind; four groups (Items, Spells, World, Collections), each kind toggleable and searchable; bonus/trait IDs off by default; secret guards before compares; skipped in pet battles.
  - **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — Tooltip IDs (idTip):** Extra sources: hyperlinks, action buttons, talents, recipe, transmog wardrobe, achievement criteria, map pins, garrison and pet-battle abilities → Pet-battle ability/aura IDs were excluded; added for the pet journal and battle tooltips (secret-guarded); Show only while a modifier is held, copy the ID, colour per kind → Added modifier gate (Shift default, off/Shift/Ctrl/Alt), click-to-copy into the shared copy box, colour per kind; /idtip slash → Added `/pui ids` (opens the IDs page).
  - Tooltip info via one TooltipDataProcessor post-call; never force UberTooltips; locale-safe stat names.
  - Minimap: border on a dedicated host re-anchored each pass; addon-button collector flyout; first-install capture.
  - Data bars: user-created bars from templates; layout solver; secure blocks (travel, spec popups) built out of combat, never Hide/Show secure content in combat; gold ledger with confirm; filtered currency refresh; locale-safe text.
- **Study (WAPI):** tooltips refresh through the owner's update on the shared throttle; padding only on meaningful change; comparison side by free space.

### 5.8 Quest Tracker — 8 keys

- **B:** sort, filter, auto-track zone, auto quest, sound, collapsed, hide Blizzard.
- **M:** quest-item SecureActionButton; Wowhead links; M+ objective collapse; progress colours (verify); auto-share.

- **Study additions (§16, 2026-10-26):**
  - HookScript only; pooled rows grown on demand; one per-character collapse set keyed by questID; timer job only while a timed quest exists; auto-quest popups inside the tracker; capability-gated right-click menu with explained disabled entries; never ReloadUI on enable/disable.
  - **Map rules (G13):** open maps with `C_Map.OpenWorldMap(mapID)`; zone↔continent transforms via `C_Map.GetMapChildrenInfo` + GetMapRectOnMap, cached lazily; a **map-lines service**; pin removal O(n) with icon limits; private tooltip for gamepad hover without OnUpdate.
  - **Quest item delete-protection:** tooltip warning line or our own confirm overlay (no StaticPopup, G5).
  - Quest/DB search via the plain-text runner (1.25). M+ timer is owned by Ascent, not the tracker.
  - **Retail (§19):** Blizzard's tracker is switched off only through the conflict notice and `ObjectiveTrackerManager:SetCanAddModules(false)` (G39); quest item buttons are SecureActionButton type=item, assigned out of combat; one dirty flag per section flushed once per frame; mark-and-sweep keyed reuse; one scheduler for the real next wake time.
- **Study (QDB):** retail quest data from live APIs only (quest log, task quests, map); QuestieDB data is Classic-only and not reused; UiMapID/AreaID/MapID kept as distinct types; never match by name when an ID exists.

- **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — Quest Tracker (Questie, WindTools):** Tracker options: quest level, completed handling, hide in pet battles, minimise in combat/instances, click shortcuts, padding, colours, fonts → Added these rows with click-binding conflict check; Auto accept/turn-in with modifier and rules (trivial, repeatable, PvP) → Added rule set with pause modifier; Quest progress announce to party → Added via the shared announcement router (off by default); Sounds on objective progress / complete / quest complete → Added; Party members' quest objectives in tooltips → Added (addon-comm, lockdown-aware).

### 5.9 Skins — 30 keys

- **B:** 25 window toggles plus Details/Pawn/WeakAuras/Plater toggles.
- **P:** the quality of each pack is unverified in game; Primitives are in Skins.lua. Tooltip/dialog/HUD/chat-bubble skins are not keyed.
- **M:** Questie/Auctionator via Skin API; guild bank skin.

- **Study additions (§16, 2026-10-26):**
  - Style-aware window skins and character/inspect sheet (ilvl, enchants, upgrade track, gems): borders deduplicated on INSPECT_READY; gem flyout respects socket type; no auto-equip without an option and a combat guard; level tables from PUI.Season (1.28).
  - Friends skin: search, class icons.

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
  - chat channel bar (plain buttons, no edit-box hooks);
  - channel colour editor.

- **Study additions (§16, 2026-10-26):**
  - Blizzard chat stays the data plane; display-time decoration through the ChatFrameFilters registries (corrected by §19: no AddMessage hook); never hook FCF_* or reparent chat widgets; idle fade on the Ticker.
  - URL copy via the shared copy dialog (1.26); class names in bodies; history across reload (never stores secret text); search. Documented limit: secret args skip chat filters.
- **Retail (§19):** filters are skipped silently for secret arguments, so a skipped line must look like stock Blizzard; whisper tabs fixed width; EventRegistry edit-box and hyperlink callbacks; `Menu.ModifyMenu("MENU_CHAT_SHORTCUTS")`; chat window 1 via Edit Mode, chat window 3 untouched (G38); current-language tag in the edit box (Blizzard's is broken); GUILD_DISCORD and PING types; UTF-8 truncation.
- **Overlap/upgrade audit (2026-10-26):** announcements go through the one router (QoL); upgrade: history search filters by channel, player and date.
- **Study (WAPI):** opt-in battleground join/leave batch summary; every text-built pattern escaped; live example-line previews for formatting options; tab strip shrinks evenly on overflow.

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

- **Overlap/upgrade audit (2026-10-26):** Vault owns junk (Flow links), the gold ledger and currencies (Data Bars read them); equipment sets belong to Loadouts; keystone shelf reads Ascent. Defaults (D-MOD-DEF2): category view, junk auto-sell OFF. Upgrade: undo last sort.

- **Study additions (§16, 2026-10-26):**
  - Categories by Enum.ItemClass; bag ranges from Constants.InventoryConstants; keyed on links/IDs, names filled later; seed flags in the same scope as data (G8); one pin semantic; gold wipe needs confirm; restore path and trim.

### 5.12 Flow — 21 keys (spec ~40)

- **B:** repair, sell junk, release, accept res/invites, decline duels/guild, skip cinematics, auto delete, gossip, quick loot, hide errors, hide talking head, durability warn, max camera, combat log, countdown, `/rl`, `/cd`.
- **M (about 19 items):**
  - insert keystone → **Ascent** (link); role-check confirm → **Group Finder** (link); leave-queue popups, open containers, Train All;
  - *Overlap audit 2026-10-26:* sell junk → Vault owns (link); skip cinematics, hide talking head, loot toasts and accept res merge into one **Quiet mode** row set. Quiet mode starts with **every option OFF in every content type** (D-MOD-DEF3); each option is toggled per content type (raid, M+, dungeon, delve, world, arena, BG) and per individual instance through a per-instance override list (add instance, toggle each option, otherwise inherits its content type; cell cycles inherit → on → off).; `/way` → Quest Tracker; `/cd` and raid markers/ready check → Raid Tools; dampening → Arena; interrupt announce → announcement router.
  - hide tutorials/loot toasts/banners;
  - `/keys`, `/way`, `/gg`, queue protection;
  - Tab binder;
  - screenshot on achievement;
  - WindTools-harvest list (spec 23).

### 5.13 Reminders — 7 keys

- **B:** raid/class rows, custom, size, sound, text, only grouped (pack data).
- **M:** consumables pack depth, talents by zone, per-reminder sound/icon.

- **Study additions (§16, 2026-10-26):**
  - One declarative reminder engine (class/spec/talent/content/combat-safe rule rows, per-section "where to show" via 1.19, sounds); secure pool out of combat, visual-only icons in combat; pre-combat aura snapshot; UNIT_IN_RANGE_UPDATE instead of polling; "why hidden" overlay in preview.

### 5.14 Embers — 10 keys (LoD)

- **B:** windows up to 5, meter type, segments, boss-only, max segments, graph, report, rows, look; export; history/compare (tests).
- **M:** death recap window (sole owner; Ascent links), window snapping, per-spec icons (verify), Forever threat meter, encounter history markers.
- **Overlap/upgrade audit (2026-10-26):** interrupts feed Ascent; standalone combat timer → Pulse Combat & encounter timer; window sets via content profiles; reports via the announcement router. Upgrades: compare current pull vs your best pull of the same boss; pinned own row; side-aware breakdown.

- **Study additions (§16, 2026-10-26):**
  - Meter windows over C_DamageMeter with the §15.5 segment engine; secret-guarded amounts *and* durations (past segments too); per-window cog; show/hide-all hotkey through the Binding ledger.
  - Spell history is **not** built here: Embers links to Cast History (§5.21, §1.O).

### 5.15 Ascent — 8 keys

- **B:** timer, splits, records, sounds, TTS, notes, hide Blizzard, scale.
- **M:** forces current-pull preview (verify), death log, score projection, vault planner, kick tracker, run summary card.
- **Overlap/upgrade audit (2026-10-26):** death log opens the Embers recap; kick tracker reads Embers interrupts; target/focus cast bars link to Unit Frames / Focus Kick; Ascent owns keystones, /keys and keystone insert. Upgrade: **pace line** (forces ahead/behind the +1/+2/+3 pace, from public forces and timer data).

- **Study additions (§16, 2026-10-26):**
  - M+ timer: completion time from `C_ChallengeMode.GetChallengeCompletionInfo` (GetWorldElapsedTime can be secret/stale — the "99:99" bug); Ticker job only while a key is active; next-threshold countdown colour; per-run summary with rating deltas; IDs not English difficulty names.
  - Alerts, battle res, Bloodlust, cursor ring, combat logging per content, target distance (PUI.Range); every UnitClass/unit read secret-checked.

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

- **Study additions (§16, 2026-10-26):**
  - **GroupFinder filters:** visual filter builder (role counts, rating sliders, lockout, friends) that *generates* an expression; optional expression field with plain-text validation; sort picker with stable comparator; delve tiers, raid bosses, group age, new/declined colouring; decorates our own overlay rows, never writes Blizzard results/decline tables (G14); cached activity map by ID; read-only in restricted states.
  - **Defaults (D-MOD-DEF2):** role-check auto-accept, sign-up auto-confirm and double-click sign-up are **ON at first install**; the taint explanation stays visible as info. Role per spec is one setting (manual / auto from spec). GF owns role-check accept and the queue-pop bar; keystone insert links to Ascent.
  - **Queue QoL:** role-check auto-accept, sign-up auto-confirm (Shift bypass), per-spec role override, declined/delisted colouring with timer, persistent sign-up note; event-driven only, no global function replacement, no SetScript on ScrollBox; auto-enter is a user-confirmed big button or sound, never a synthetic click.
  - PGF present: conflict notice/picker (D-PGF, 1.35): the user chooses Phoenix's Group Finder module off or PGF off; one group-age tooltip line, skipped when PGF is the chosen side.
  - **Export hub (Wisdom):** calls SimulationcraftAPI when present, never duplicates it; uses the async data service (1.23) and the shared copy dialog.
  - **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — Group Finder (PGF, AutoQueue, BigWigs tools):** Dungeon panel: difficulty, M+ rating min/max, members/tanks/heals/dps min/max, party fit, BL fit / needs BL, not declined, season dungeon ticks → Added party-fit, BL/BR-fit, not-declined and a dungeon grid built live from the season map list (any count, keyed by map ID, survives season change); Delve panel: tier min/max, delve ticks, select bountiful (highlighted) → Added delve picker from live activity groups and a 'bountiful only' chip from POI data, tier read from the activity ID; Raid panel: difficulty, bosses defeated min/max, matching lockout, group ahead/behind → Added raid picker (current tier first), per-boss must-be-alive/dead toggles and a lockout selector (any / same ID / not ahead of me) with a 'you are saved X/Y' badge; Arena and RBG panels: bracket, PvP rating min/max, roles → Added arena/RBG panels: bracket chips (2v2/3v3/RBG/Blitz), rating range, comp picker (wanted/unwanted classes or specs, has healer); Minimised mini panel (expression + sort only) → Added a compact view; sorting and filters are shared between compact and full views; Row colours: new groups green, soft/hard declined orange/red, cancelled pink, lockout colours on the activity name → Added cancelled and lockout colours; every colour is a setting with a sample-row preview; Role indicators: spec icon, class bar, class circle, leader crown, missing roles → Added spec icon, class bar, class circle and leader crown, each toggleable with size/colour, fixed tank-healer-dps order; Rating info: leader M+ score + best key → Added best key level and colour source choice (Blizzard / Raider.IO if loaded / custom gradient); no Blizzard region resizing; Group tooltip: member names, class/role counts for raids/BGs/custom groups → Added a structured tooltip section: roles in fixed order, class-coloured counts, age, leader score, lockout (post-hook only); One-click sign-up, skip sign-up dialog, sign-up on Enter, cancel oldest application when at the cap → All four added as opt-in helpers done safely (pre-select + focus, Enter via Blizzard binding, visible cancel-oldest button the user clicks), each with a taint explanation; Compact list entries (row height, hide playstyle line) → Added row density setting (comfortable / compact / ultra), applies live with no reload; Movable dialog, class names in tooltip, coloured group texts → Added dock anchor (attach left/right/detached, saved position and scale), class-name and coloured-text toggles; PGF on/off toggle per category with server/removed/shown counts → Added header toggle plus a visible 'showing X of Y' line with a per-filter 'why hidden' breakdown (click to relax); Mirror UI into Blizzard's server-side advanced filter → Added as opt-in 'also narrow Blizzard's search', restoring your previous Blizzard filter on disable (ledger); Raider.IO and PremadeRegions plugin variables (rio score, milestones, region/language) → Added optional pcall adapters (Raider.IO) and a built-in realm→region/language filter and badge; Public API: sort override, Macro(expr, sort) → Added sort/extra-variable plugin hooks and `/pui lfg filter <preset>` with named presets per category; Keyword cheat-sheet help + copy wiki URL → Added help panel generated from the keyword registry: searchable, click-to-insert, autocomplete with which dungeon each keyword matches; Role bar docked above the Group Finder with lock icons for impossible roles, +/- toggle, first-run tip → Added the docked Phoenix role bar with lock icons, collapse toggle and first-run tip (FrameLedger restore); Double-click a result to sign up → Added (opt-in) through a post-hook on our overlay row; opens Blizzard's dialog, no SetScript on Blizzard buttons; Minimap/LDB icon showing on/off state, /aq on|off|minimap, status print → Added compartment/broker entry with state colour and `/pui queue on|off`; Roles printed with icons when solo → Added optional chat confirmation line; Auto-set role from spec → Added to Group QoL, opt-in, stands down with BigWigs; Queue-pop countdown bar on the LFG proposal → Added to Group QoL; Auto-invite on keywords → Added (opt-in, trimmed/case-folded, lockdown-aware replies).

### 5.17 Sentinel — 8 keys (+ Companion, website)

- **B:**
  - capture, ring, taint, integrity, drift, perf, heartbeat, toast, export;
  - new viewer with resolved state, copy and `/pui sentinel`.
- **P:** resolved state is not persisted across sessions intentionally (verify the SV write); tester matrix not recruited.
- **Companion:** `companion/sentinel_companion` with build.py and tests exists — **P** (packaging/signing and auto-start unverified).
- **Website:**
  - **B:** ingest + D1 + admin `/phoenix/*` pages deployed (#15–#19).
  - **M:** public `/status`, `/sentinel` pages generated from data (verify which exist).

- **5.17a Diagnostics `PUI.Diag` (new, M):** if BugGrabber is present, subscribe to its BugGrabbed callback and register as a display; otherwise own handler with a token-bucket throttle. Viewer with sessions, prev/next, counter, links. Store non-secret text only; no gsub on possibly-secret text. Sharing (D-DIAG-SEND): user-initiated in-game sharing of Sentinel reports to other players, and every report auto-uploads via the Companion app to the vq8s.com admin dashboard for analysis. Privacy kit for exports (GUID-kind allow-list, whole-word name redaction, system-string allow-list). Opt-in dev recorder (change-only streams, orphan-session recovery). Errors never hidden by default (G7).
- **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — Diagnostics (BugSack):** New-error alerts: sound, chat line, auto-open (never in combat) → Added sound choice + channel, chat line and auto-open toggles, per-signature throttle; Broker/minimap count badge, wipe → Added compartment badge; wipe/reload behind confirm.
- **5.17b Profiler `/pui profile` (new, M):** opt-in, zero cost off; samples module entry points registered through the Phoenix API (no _G/frame traversal); GetTimePreciseSec; active-slice timing for Ticker jobs; measurement generations; frame-free report builder (self vs inclusive, grouped tree, honest "N hidden"); interleaved A/B helper; hot-primitive exclusions declared once; feeds the per-page CPU chip (1.18).
- **5.17c `/pui test` depth:** pure-Lua view-model tests with mock widgets; unit-tested aura partition solver and Classify functions; lint suite (1.33); schema coverage.
- **Study (WAPI/QDB):** dedupe by message+stack with counts in a capped ring buffer; excess-error warning once; messages state expected/found/why/where; warning baseline of stable fingerprints (fail on new rows only); dev-mode badge whenever a dev/test build or test mode runs; dev event-trace panel for Phoenix's bus (ring buffer, frame deltas, markers, filters, plain search); self-measurement with the retail addon profiler (signature verified), top-addons readout on hover only.
- **§5.17c test-harness additions (QDB/WAPI):** zero-check suite fails; unknown test name fails with no PASS; per-test sandbox that restores and asserts globals; real module code in the sandbox; literal fixtures not derived from code; idempotence re-runs; self-proof per gate and lint rule; persona matrix (class × spec × role × faction); every module exercised at least once; allocation guard; warm-up + best-of-N benchmarks; harness stricter than the client; override-stack collision tests; time-format edges; determinism check (two builds byte-identical).
- **Lint additions:** deprecated-API denylist; CVar list check; handled-vs-registered events; remove-inside-pairs; unplain user-text search; `type(a == b)`; multi-return captured as a list; handlers reading global `event`; `total + max` accumulator slips; numeric results as booleans; reader/writer key mismatch; function-valued format args; raw children on pooled frames; never-reset throttles.

### 5.18 Theme & Media

- **B:**
  - 12 Phoenix statusbars + legacy, fonts (Inter, Rajdhani, JetBrains Mono, Noto KR/SC …), sounds, LSM share;
  - accent (11) and panel material;
  - module icons 64/128.
- **M:** border styles picker (6), shape masks (8), class/role icon sets, dark-mode/faction themes.

- **Study additions (§16, 2026-10-26):**
  - Media library: openly licensed or our own only, highest quality; LSM registration of licensed media only; global Fonts/Textures/Colours/Glows pages with preview; font change applies live.
  - Looks axis (Phoenix / Blizzard-like / Classic) as StyleCards; accessibility palettes and reduced motion (1.16).

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
| **Cast History** (new; spell-history strip or fading icons; castGUID-keyed state machine start/channel/empower/succeed/stop/interrupted with secret-safe early-out; pooled icon ring; blocklist picker by ID; "where to show" via 1.19; Studio mover; Core profiles only; owns spell history for Embers too) | M | — | M |
| Raid Tools (markers, ready check, pull, notes ooc) | M | 22.13 | M |

**Deepened Tier 1 entries (§16):**
- **Pulse:** `C_EncounterTimeline` natively, never index-walking a fixed timer list (so a fight that outruns the list still warns); active only without a boss mod. With BigWigs loaded: stand down, keep its encounter frames and CVars (excluded from the CVar ledger), offer the BigWigs bar-style/profile bridge. Countdowns cancel their own timers only; emphasised fade honours settings.
- **Arena overlap/upgrade audit (2026-10-26):** Arena owns match timer, dampening and Shadowsight (Flow links), and the one party⇄arena targeting service that raid frames also use. Upgrade: post-match card (comp, rating/MMR delta, trinket and DR-tray history).
- **Arena:** own secure buttons (click attributes via CombatQueue, `@arena` substitution escaped, G12); secret-first spec display through the Blizzard role-map helper; health/power to widgets only; ArenaMatch state service (Idle/Prep/Engaged/Ended) on PVP_MATCH_STATE_CHANGED; zero events outside arena; 1 Hz Ticker match timers; DR: opt-in (off by default) switch that turns on `spellDiminishPVPEnemiesEnabled` through the CVar ledger and restyles Blizzard's DR tray; no Phoenix DR maths (D-ARENA-DR, revised by §19); built on CompactArenaFrame data (`GetArenaCrowdControlInfo`, `AddBlockedAura`), pre-match/live/stealthed states; "assume regen in stealth" option, off by default (D-SARENA-STEALTH); optional FrameSort numbering; PvP colour CVar via ledger; layout presets as schema styles over one paint function, test mode uses that paint; never toggles Edit Mode or reparents CompactArenaFrame; relative frame levels.
- **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — Arena (sArena):** 9 layouts → Now 9 data presets over one layout engine in Phoenix's own art, plus your own saved styles; Mirrored layout → Added a true geometric flip setting; Trinket: CC info, surrender flag when none, use sound → All added; healer-only variants greyed with the reason when specs are secret; Racial with shared trinket CD, swap racial into trinket slot, per-race toggles → Added shared-CD state machine with tests, swap option and per-race list; DR display: size, spacing, growth, border styles, DR text + anchor, decimals, coloured CD text, per-category size offsets, only triggerable by me → Added these as styling of Blizzard's DR tray; 'only triggerable by me' via the CVar ledger; durations labelled estimated; Class-icon aura: CC/defensive/important priority, sort order each, only CC, hide/replace healer icon, decimals threshold → Added sort per category, only-CC, replace healer icon, decimal threshold; Aura highlight on class icon: per category → Added via PUI.Glow with live preview; Dispel tracker per enemy (cooldown, charges, show after use) → Added as an observed-dispel widget (shown after first seen use), honest Midnight limits; Cast bar: modern/classic/simple styles, hide shield/spark/icon, arena-ID text, cast-target text → All added on Phoenix's own cast bar element; Pet frames: per-class filter, size, strata, name/number/ID, border style, widgets, range, status text → Added full pet frame page; Range check: per-spec spell list, alpha/icon/both, atlas presets, tint, scale, offset → Added arena range page with per-spec spell override and icon modes; Combat indicator (swords / food / sap), death, disconnect, feign death icons → Added indicator set with in/out-of-combat toggles; Target and focus indicators: icon and/or border, colours, size, offset, wrap class icon/trinket/racial → Added; Party⇄arena targeting icons → Added to the plan (it was only in the mockup): direction, spacing, scale, text anchor; labelled limited in Midnight arenas; Shadowsight timer → Added to match timers (1 Hz Ticker, restored from match duration); Gladiator / Legend / Strategist progress on the conquest frame → Added to the plan: read-only overlay; Text: name/health/power/spec name anchors and sizes, class-coloured names and spec names, arena number, % / formatted numbers, hide power text, reverse fill → Added full text page with per-text font/size/outline; Dark mode, class-coloured frame textures (healer green), healer texture, pixel borders → Added via Skin tokens; Cooldown look: swipe colour, edge, per-element swipe/invert/CD-text toggles → Added per element; Click actions per mouse binding → Added binding editor through the binding ledger, CombatQueue applied; PvP UI: rated card, MMR delta, scoreboard column registry, leave countdown, Training Grounds → Added to the Arena/BG module.
- **Spark defaults (D-MOD-DEF2):** Spark turns **all three Blizzard combat-text categories off** at first install (CVar ledger, prior values restored when Spark is off). Spark owns combat in/out alerts, item/potion-ready alerts and loot/progress text. Upgrade: density cap in big pulls (extra lines merge).
- **Spark:** attribution from UNIT_COMBAT plus own casts with confidence (trust a guess only once confirmed, nil when ambiguous); pooled text lines on the Ticker; escaped formatters; per-frame dedupe (no double heals, no double loot); Blizzard SCT via CVar ledger only; never writes Blizzard_CombatLog filters; area cards with live preview of sample numbers; visual trigger builder (health, power, aura, cooldown) without code.
- **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — Spark (MSBT):** Scroll areas → Added the full per-area settings list with inherit chain (event → area → master); ~165 event rows: incoming/outgoing for player and pet, notifications → Added every category; each row: enable, colour, area, font, sound, message template; Message tokens %a %n %s %e %t %p, overheal/overkill and partial-effect trailers → Added token chips with live sample; trailers editable; Ability substitution and suppression lists, ability abbreviation → Added (locale-safe; abbreviation by rule, not English-only); Class colours, damage-school colours, partial colouring → Added class and per-school colour tables; Aura tracking allow/block list with per-aura style overrides → Added; Loot alerts: items, money, currency, quality filter, always show quest items, allow and exclude lists → Added, including Legendary/Artifact/Heirloom (MSBT stops at Epic); Item cooldown-ready alerts with threshold and exclusions → Added; Sounds per event, custom sounds → Added via the PUI sound service; Blizzard SCT control: per-category Blizzard/MSBT on/off for outgoing, incoming, notifications; reset Blizzard SCT → Added the 3×2 per-category switches and a restore button, all through the CVar ledger; Toggle all / move all events (incl. aura rows) → Added set-all (one state) and move-all.
- **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — Cast History (TrufiGCD):** Catch-up speed for queued icons → Added catch-up speed setting; Built-in + user spell blocklist, item blocklist, Ctrl+Alt+click to add, name→ID picker → Added item blocklist, click-to-add and a picker listing every name match; Tooltip on hover, pause on hover, print spell link/ID → Added (print is opt-in, no hover spam); PvP trinket shown with faction art → Added; Masque, Addon Compartment, slash → Added compartment entry.
| Council | M | Tier 2 | XL |
- **Arena study (WAPI):** explicit opponent lifecycle (seen/unseen/destroyed/cleared) with a greyed stale look; prep-phase class/spec; CC/trinket requested on show, item icon preferred; shared heal-prediction renderer (§5.2); no arithmetic on possibly-secret health/absorbs.

- **All-addons parity additions (audit 2026-10-26, `pui_study/others/AllAddons_parity.md`; each a setting with Simple + Advanced views) — QoL and combat tools (WindTools, BigWigs tools):** Announcements: quest progress, keystone + !keys, goodbye, instance reset/difficulty, utility spells → Added one announcement router (off by default, self channel default, restriction-aware); Combat enter/leave alert (animation, text, sound) → Added (coalesced, live preview); Destroy-totem buttons + keybinds → Added (secure, out of combat); Damage meter window layout (weighted split, auto-switch by content) → Added optional layout for Blizzard meter windows with FrameLedger restore; Already-known colouring at vendors/AH → Added; Mail contacts book, open all, return selected → Added recipient book and open-all/return-selected; Super tracker: waypoint parser, middle-click clear, auto-track → Added (/way style input, pure C_Map/C_SuperTrack); Instance difficulty text on minimap → Added; World map fog reveal → Added as an overlay (no Blizzard canvas edits); Objective tracker auto-collapse per context (combat, instance type, resting) → Added per-context state; Prey hunt stage text (Midnight) → Added as Phoenix-owned overlay; Loss-of-control alert restyle → Added (own display fed by C_LossOfControl); UI error colours and size → Added; Vignette edge shading → Added; Chat channel bar → Added plain-button bar (no edit-box hooks); Quick focus (modifier-click) → Added for Phoenix frames only; M+ and tier-set info in tooltips → Added tier-set count and M+ best runs lines; Skip cutscenes, hide talking head, auto accept resurrect → Added to QoL (each opt-in); CVar editor → Added CVar page through the ledger; BossBlock: hide talking heads, movies, toasts, boss emotes, error speech per content type, mute SFX/music → Added 'Quiet mode' (per content type + per-instance overrides, all OFF at first install per D-MOD-DEF3, CVar ledger), stands down while BigWigs is loaded; Statistics: kills, wipes, best time per difficulty → Added encounter stats (when no boss mod owns it); Combat/encounter/stage timers with history → Added stage timer and history ring; disable never resets; Keystones: party/guild keys, teleport grid, who has a key, enemy forces % on tooltip/plates, M+ countdown, auto-slot key, Challenges frame scores → Added keystone viewer tabs, teleport grid, who-has-a-key, enemy forces %, Challenges frame decoration.

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

**Companion installer and release rules (QDB, 2026-10-26):** validate the whole ZIP first (names, reserved Windows names, case collisions, no links, only Phoenix_UI* top folders); checksum before unpack; refuse while Wow.exe runs; stage + swap with a recovery copy so an I/O error can't half-install; keep the user's other files and never overwrite user-edited files; Windows path edge cases tested; "can't reach server" ≠ "no update". Releases fail closed and keep the previous build; draft until complete, manifest last; never reuse a tag; reproducible archives; CI pinned by SHA; TOC lint (one Version, 12.x Interface, files exist); ship by allowlist; player-language changelog from tagged entries without emails; append-only validation log per release; end-to-end install of the built ZIP into a clean AddOns folder. Store manifest compatibility only at the store-publishing phase (end).

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

**Phase B+ — Foundations from the finished study (L; before module depth)**
- Progress (2026-10-26, `feat/foundations`, end-to-end build step 1 + step 2): engines built and covered by offline tests for PUI.Auras (F1), CVar/Binding/Frame ledgers with the keybind conflict check (1.20, 1.21, F4), PUI.Visibility (1.19), PUI.Format/Range/Mouse/Glow (1.29), PUI.Season (1.28), own confirm, keep-or-revert and copy dialogs plus Phoenix chat links (1.26, 1.27), the search runner (1.25), the Core cast bar element with the single own-kick state (1.O), and per-spec/per-condition overrides with provenance (1.8, 1.9, F2); `lint.py` (implicit globals, Ticker-only timers, must-fail fixtures). Still open here: the options UI for these engines (visibility chip picker and "why hidden" readout, Editing-as banner, gold override dots and overrides list, ledger page and "Uninstall Phoenix"), 1.22–1.24, 1.30–1.38 and the in-game checks.
- 1.19 visibility engine, 1.20 Binding ledger + conflict check, 1.21/1.22 FrameLedger + ledger page, 1.23 async data, 1.24 versioned import schema, 1.25 search runner, 1.26 copy dialog + link handler, 1.27 own confirm dialogs, 1.28 PUI.Season, 1.29 shared services, 1.30 staged boot, 1.33 lint suite, 1.34 ownership check, 1.35 coexistence detector.
- Settings model §1.S applied to the options shell: live preview slot, simple/advanced expander, disabled-reason tooltips, per-feature reset.
- Accept: G1–G25 enforced by the lint suite where mechanical (T); every ledger restores the prior value after disable (T + I); keybind conflict warning shown across modules (I).

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
- Pulse → Arena → Spark → **Cast History** → Raid Tools (deepened entries in §5.21).
- Each gets its mockup first, a "not possible on 12.1.5" list, and stand-down rules.

**Phase N — Diagnostics and profiler (M)**
- §5.17a `PUI.Diag` with BugGrabber coexistence, privacy kit, recorder; §5.17b `/pui profile`; §5.17c test depth.
- Accept: with BugGrabber loaded Phoenix registers as a display and installs no handler (T + I); profiler off = zero hooks (T); report totals match within 5% on an A/B run (I).

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
| Party mode celebrations (EUI fun) | M | Planned as Celebrations (step 10), opt-in, every trigger toggleable, reduced-motion aware (parity audit) | N | |
| Error viewer (BugSack parity: sessions, counts, copy, sound) | B | Sentinel already exceeds (taint, perf, shareable reports) | N | |
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
| F1 | `PUI.Auras` on 12.1 `AuraContainer`: canonical filter builder (cached, sorted tokens), add-only groups toggled by cap, flow layout (anchor/growth/padding/line size/axis) with API-generation fallback, processing policy, scheduler-spread construction, restriction-aware restyle queue (`C_Secrets.ShouldAurasBeSecret`), engine duration text (`C_DurationUtil` binding + `C_StringUtil` formatters) and bars, engine-hosted glows | B (engine; in-game check in M+/raid pending) | One shared engine for UF, Raid, Plates, Player aura bars, CDM decimals, spec helpers; per-container perf readout in Sentinel | N | G, T (filter canonicalisation, cap toggling), IG: auras correct in M+ key and raid boss (restricted) with zero Lua errors; Ticker shows no per-frame Lua |
| F2 | Overrides layer: per-spec-group and per-condition overlays on any `overridable` schema key; "Editing as" banner; gold dot on overridden rows; promote to profile; list page | B (engine + options UI) | Generic on schema (no per-module forks), diff view | Y | G, T (resolve order profile→spec→condition), IG: swap spec in town and in combat (deferred) |
| F3 | Studio v2 parity: anchor-to-element, width/height match links, resize handles, grow-direction anchors, combat-parked moves (CombatQueue), Edit Mode guard, save/revert banner (snap, grid, nudge, undo/redo already Built in #15) | P | Undo/redo (EUI has revert only) + layout presets | Y | IG: anchor UF to CDM bar, resize CDM, UF follows; combat enter mid-drag safe |
| F4 | `PUI.CVars` ledger: owner-tagged CVar writes, restore when a module turns off and on "Uninstall Phoenix" | B (engine; ledger page open) | Visible ledger page | N | T, IG: disable Nameplates → CVars back |
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
| Auras via F1 per class group (buffs/debuffs/dispellable/own/CC), caps, sort, dispel slots, purgeable glow | B (buff/debuff containers per frame with plain filters, count, size, per row, side, sort; dispel slots as a third engine group `uf.<unit>.dispel.*`; purge glow `uf.purgeGlow` gated on a known offensive dispel) | shared filter registry with Raid | Y | restricted content |
| Player Aura Bars (buffs, debuffs) + custom aura bars with named filters, 10 presets, match any/all, per-spec | P (two movable icon rows on PUI.Auras, Blizzard BuffFrame/DebuffFrame parked via FrameLedger, CDM dedupe setting; named bars/presets open) | — | Y | |
| Mini frames (companion), boss1-5 with range dimming, pet, ToT, FoT | B (range fade on PUI.Range, boss growth/spacing, test frames `/pui uftest`, Copy settings from...) | `/pui test boss` | Y | |
| Text slots + tags + nicknames + decimals + smart power % | P | live token editor | Y | |
| Portraits 2D/3D/class, attached/detached, masks, borders | B (looks Ember/Glass/Blizzard-like/Classic-like, each part its own setting; square/round mask, side) | Phoenix masks | Y | |
| Castbar kick tick, interrupt colours, important cast | B (PUI.CastBar on target/focus/pet/boss: icon, name, timer, shield, own-interrupt, colours, fade) | | N | |
| Absorb styles, heal absorb, max-health reduction, heal prediction, glow line | P (absorb and heal-absorb overflow marks from the calculator's clamped flags, `uf.overflow`; max-health reduction open) | | N | |
| Class power (bars/circles) on player frame | B (Resource Bars hosted under the player frame: attach / keep separate, gap) | | N | |
| Visibility: fade OOC, resting alpha, show when missing health; dark mode; dynamic health colour | P (where-to-show rule + hidden alpha, dark mode, gradient/class/reaction/custom colour; missing-health rule open) | | N | |
| **EUI parity additions (audit 2026-10-26)**: vertical (bottom-to-top) fill; level coloured by difficulty; threat % position + colour by status; Blizzard-coloured target name; portrait mirror, NPC class-art choice, class-colour ring and second outer ring; lockout-debuff hide preset (Sated/Exhaustion/Temporal Displacement) | P (lockout preset built: `uf.<unit>.auras.debuffs.hideLockouts` via `PUI.Auras.LOCKOUTS`; vertical fill, difficulty level colour, threat glow, Blizzard-coloured name built; portrait rings and lockout preset open) | per-row preview | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

**Raid & Party** (EUI 343 controls; ours ~100 `rf.*` + click-cast)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Per-group + flat headers, party header, raid size tiers | B (4 tiers party/≤10/≤20/≤40, each with size, orientation, spacing, per column, growth; auto or fixed tier) | auto tier | Y | 5/10/20/40 |
| Buff Manager indicators (icon/square/bar/health colour/border/frame alpha), healer spell DB per spec, filters, ≤20 per spec | P (corner indicators `rf.corners` with per-class heal presets, buff/debuff/defensive containers on PUI.Auras; bar/health-colour indicator types and per-spec lists open) | drag-to-corner editor on replica | Y | |
| Debuff Manager tiles, match any/all, shown-on-modifier, per spec | P (debuff container with raid/all/dispellable/important/CC filters, lockout preset; tiles per instance open) | | Y | |
| Click-cast: frame path + hovercast path, global defaults, per spec | B (list editor with composer, `cc.list` overridable per spec, hovercast keys reserved in PUI.Bindings, conflict text) | conflict detector | Y | combat-safe rebinds |
| Grid Mode / Compact Mode shared outlines | M | | Y | |
| Extra Frames (chosen members), friendly boss frames, party targets, pets (header/beside owner) | M | | Y | |
| Sort: self first, prioritize class, FrameSort shim | P (group/role/class/name sort, role order, party sort; FrameSort shim open) | | N | |
| Range fading, ghost-aura safety net, healer mana text, ping marker, role/leader/combat icons, ready check | P (range on PUI.Range, absorbs/heal-absorb/incoming via PUI.Prediction with overflow marks, role icon/letter, leader, marker, status; ping/ready check open) | | N | |
| Frame-provider API for external trackers | M | with plugin API | N | |
| Preview: fake roster, cycling auras, size preview | B (options preview per tier from the module's own painter; `/pui rftest 5|10|20|40` and Test 5/20/40 buttons) | state toggles | Y | |
| **EUI parity additions (audit 2026-10-26)**: Mythic 20-player cap (groups 1–4) and benched members ignored in custom sizes; Thorns-on-tanks missing-buff rule, role shown as text, hide role icons in combat; status colours; healer-mana layout (row gap, stack direction, names); wrap direction + free-move positions for pet/extra/boss groups | P (Mythic cap, role as text, hide role icons in combat built; Thorns rule, healer-mana layout, pet/extra groups open) | auto tier | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

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
| **EUI parity additions (audit 2026-10-26)**: neutral & minor enemy colours, modify-out-of-combat colours; classic tank-aggro mode and threat gap on target; stacking speed; hide enemy name while casting; cast lockout shown as CC icon; quest objective text replaces quest icon; hide duplicate Blood Plague; Sunder Armor stacks | M | rules engine | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

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
| **EUI parity additions (audit 2026-10-26)**: never-dim list for usable-on-condition spells (Swiftmend default, replaces EUI's single toggle) | M | list, not one spell | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

**Cooldown Manager** (EUI 198; ours 22)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Restyle + reanchor Blizzard viewer children (hooks only, side tables, alpha-0 unclaimed), 4-phase collect | M | | N | combat reanchors, no taint |
| Custom bars per spec + global groups, spell store, spell picker, talent conditions, empty slots, trinket slots, item presets, racials, spec sync | M | manager page | Y | |
| Tracking bars from CDM children: thresholds, ticks, stacks, pandemic, sounds, auto-add, presets, engine decimals | M | | Y | |
| Fake-active, custom icons, ready sound, state effects, charge text | M | | N | |
| Bar glows (active/missing/usable/stacks/AND/hero tree), proc glows, pandemic sync | M | condition chips | Y | |
| Rotation assist icon, mirror key presses, focus kick bar | M | | N | |
| **EUI parity additions (audit 2026-10-26)**: per-row icon size offsets, dim bar out of combat; crafted-quality rank on tracked items; charges/stacks-only mode | M | condition chips | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

**Resource Bars** (EUI 285; ours 18)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Health/power/class resource bars, thresholds as colour curves, ticks/hash, smooth, fades | P | | N | |
| Cast bar (ticks, empower, latency), GCD bar, totem bar, swing timer (Forever) on duration objects | P | engine fills | N | |
| Spec helpers: Ironfur, Ignore Pain, Ebon Might, Arcane Soul, Warrior charges (hidden aura slots) | M | data pack | N | restricted |
| Blizzard class art re-host, anchors/stack, border-around-all | M | | N | |
| **EUI parity additions (audit 2026-10-26)**: cast bar: grey fill when target out of range, own colour for non-interruptible casts, total-duration text; GCD bar: instance only, instant casts only, deplete fill; swing timer: off-hand as spark on main-hand bar, ranged movement guide | M | engine fills | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

**HUD: Minimap / Data Bars / Tooltip** (EUI 83 + 70 + skin)
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Minimap collector (scan, blacklist, flyout grid, free move), indicators (vault, portals, friends, calendar lockouts), micro menu on middle click | M | search | Y | |
| Data bars engine: N bars from templates, 20+ blocks incl. LDB, layout solver, themes, heartbeat | M | | Y | |
| Tooltip: anchor modes + mover, visibility with peek modifier, health strip, IDs | P | | N | |
| **EUI parity additions (audit 2026-10-26)**: minimap friends tooltip cap with notes on a second line, Omnium Folio show/scale, mail icon position; data-bar volume/audio-channel block, silver/copper toggle, 24 h / local clock; skin: resurrect-accept glow, accent bar, bar fill opacity, link colour; character sheet socket panel with gem stat letters, season panel + Great Vault button, PvP item level, tertiary stat letters, stat-section layout; full skyriding bar (hide in combat, speed bar, Second Wind, Whirling Surge, vigor style, chime, thrill colours, speed text) | M | search | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

**Chat / Vault / Quest / Group Finder / Friends**
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Chat engine (AddMessage bridge, own SMF, ghost tabs), sidebar, idle fade, URL copy, session history | P | | Y | taint log during whisper creation |
| Vault: categories engine, grid/compact/list, bank + warband parity, junk/pin/assign modes, stack splitter, sort two-phase, Pawn/overlay API | P | rule categories | Y | |
| Quest tracker skin by hooks, item hotkey, auto accept/turn-in, visibility | P | | N | |
| Group finder filters (dungeon/delve/raid boss/region), applications bar, cancel oldest | P | expression filter | Y | |
| Friends skin | M | | N | |
| **EUI parity additions (audit 2026-10-26)**: chat: lock main chat size, separate sidebar, free-move sidebar icons; Vault: nest by expansion, hide empty slots when grouped, armory slot packing, open with character window; tracker: hide in raid, top line, announce progress, quest tools; Friends: class icon theme, class-colour names, border, accent tabs, faction banners, region icons, BattleTag copy box, status orb (Online/AFK/DND), invite-search dropdown, auto-accept friend/guild invites (OFF) | M | rule categories | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

**Combat tools / QoL**
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Embers on `C_DamageMeter`: 8 meter types, Current/Overall + historical session IDs, source breakdowns, death recap via `C_DeathRecap`, ≤5 windows, standalone timer, spell history | P | segment engine (see 15.5) | Y | secret numbers via setters; chain-pull, wipe-with-survivors, arena round end, feign death |
| Ascent: run summary/history, target/focus cast bars, targeted spell bars | P | | Y | |
| Reminders: combat-safe raid buffs vs OOC checks, secure click-to-use, where-to-show, talent reminders, ready-check mana | P | season data pack | Y | |
| QoL toggles (~40) | P (Flow) | all OFF | N | |
| Alerts anchor, battle res + lust icons, cursor rings, movement alert, raid tools band, self combat text, shifter, waypoint, upgrade calc, auto logging, /keys | M | | Y (cursor, raid tools) | |
| Radial palette (Quickdraw idea) with secure in-combat selection | M | | Y | backlog after parity |
| **EUI parity additions (audit 2026-10-26)**: reminders: explicit class presets (rogue poisons, paladin, shaman, warlock right demon + own Soulstone, missing/passive pet), Inky Black Potion, show without item in bags, show below key level / pre-key, cursor-attached important-buff strip, Forever camp benefits + Well Fed; meter: always show player, reset-data keybind, rows 8/15/N, hide rank numbers, forced K/M/B units; QoL: hide item transforms, disable right click in combat, secondary stat display, guild chat privacy cover, rested indicator, environment ping, Artisan payouts kept closed, Warcraft Recorder compatibility, centre reticle, cursor only-when-hidden, sated/ready bloodlust states; Studio movers for loot windows and top-bar event text; Quickdraw nests, visible-icon cap, appearance options; Forever active stance icon, gathering skill on tooltips, name format; loadouts per saved instance/boss, content-type defaults and assignment list; Celebrations (party mode) with every trigger, opt-in | M | all OFF by default | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

**Options / onboarding / locales**
| Feature | St | Phoenix better | Mock | Check |
|---|---|---|---|---|
| Schema renderer (F7), cog popups, apply-to-all, previews for every module | P | | Y | |
| Global search (F6), profile export/import, profile sync groups | P/M | diff before import | Y | |
| First-install module picker + look picker, one-time announcements, video guide links | P | | Y | |
| Translations for 8 locales + Arabic generated from schema | M | | N | key coverage ≥95% |
| **EUI parity additions (audit 2026-10-26)**: Fonts page: a font/size/outline row for every text element of every module (inherit global by default), icon-text outline, outline renderer choice; aura tooltip max-duration filter and anchor (cursor/position) | M | override badges | N | every row's setting visible, searchable, live, resettable; Simple + Advanced (D-MOD-DEF) |

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
Step 2 now also includes §11 Phase B+ (1.19–1.36); step 10 adds Cast History; Diagnostics/profiler (Phase N) run after step 9. Every step: mockups first where Mock = Y; each PR updates this section's St column and `CHANGELOG.md`.

### 15.5 Hand-read corrections (pass 2, 2026-10-26)
Read by hand so far: DamageMeters main file and Lifecycle (full), the Window refresh core, and the first 260 lines of Nameplates AuraContainers. The tracking column is `hand_read` in `COVERAGE.tsv`. The remaining module files are still parse-only and are tracked as `no` (see the report).
- **Embers segment engine (new F-level item for Embers):** one shared refresh ticker, combat-only and visible-only; refresh floor 0.5 s; fetch-time spike guard (defer paint when the API takes >1.5 ms); segment token; `ENCOUNTER_START` as a hard boundary; kill vs wipe freeze rules; group-still-fighting poll with a 5 s failsafe; teammate-pulled-first pre-warm; PvP match end; post-combat declassify refresh at +0.5 s; source-key snapshot on `ADDON_RESTRICTION_STATE_CHANGED`. All timing goes through `PUI.Ticker` in our version.
- **Correction (F1):** aura container creation is legal in combat on current 12.1 builds, so pools are warm caches, not hard limits. While auras are secret, anchoring to aura buttons is restricted, so restyles must make zero button calls when nothing changed. Added to F1's acceptance: "restyle inside an M+ key with unchanged anchors produces no restriction errors".
- **Correction (Nameplates):** you can't read per-aura dispellability in restricted content, so purge glow must be done by engine group (Dispellable token).

### 15.6 EllesmereUI parity audit (2026-10-26, user direction t72u)
Every EllesmereUI option section (≈2,000 labelled controls in 288 sections, from `pui_study/ellesmere/*` §3 tables) was checked against this plan and `Feature_Catalogue.md`. Result: 181 feature rows, 125 matched, 47 weaker, 9 missing; all 56 gaps are now fixed in place (the "EUI parity additions" rows in §15.3, the Party mode row in §13.11, and (p) lines in the catalogue). Full table: `pui_study/others/EllesmereUI_parity.md`. Rule: Phoenix must offer every EllesmereUI option, each as a user setting with Simple and Advanced views (D-MOD-DEF), plus the "Phoenix better" column; a module is not parity-complete until every row of its audit table is Built.

### 15.7 All-addons parity audit (2026-10-26, user direction t73u)
Every other addon studied from the I:\ drive (PremadeGroupsFilter, AutoQueue, idTip, sArena Reloaded, MikScrollingBattleText, MoveAny, TrufiGCD, Simulationcraft, !BugGrabber, BugSack, BigWigs + LittleWigs, Questie, QuestieDB, QuestieTrace, WoW-API, Auctionator UX ideas, EllesmereUI_WindTools; ElvUI listed and excluded per t53u) plus the Blizzard retail 12.x reference was checked feature by feature against this plan and the catalogue: 193 rows, 91 OK, 50 WEAKER, 47 MISSING, 5 N/A (recorded exclusions). All 97 gaps are fixed in place as "All-addons parity additions" bullets in §4, §5.7, §5.8, §5.16, §5.17a and §5.21, plus catalogue `(p)` lines. Rule (D-LIC): a VortexQ8 module (Group Finder, Arena, Spark, Tooltip IDs, Studio movers) is not finished until every feature of the matching VortexQ8 addon is built, better, in Phoenix's own code. Full tables: `pui_study/others/AllAddons_parity.md` (built by `pui_study/tools/allparity.py`).

### 15.8 Overlap and upgrade audit (2026-10-26, user direction t75u)
Module mockups 01–11 and §1.O/§5.x/§15.3/§15.6/§15.7 were checked for features owned twice. 31 overlaps found; each now has one owner in §1.O (rows from "Death recap" to "Buff bars"), and the other modules link to or reuse it (§5.10, 5.11, 5.12, 5.14, 5.15, 5.16, 5.21 updated). Every screen's source-addon features now list a concrete Phoenix upgrade; features that were only matched got one (pace line, history filters, undo sort, density cap, best-pull compare, aura and CDM dedupe, post-match card, shared targeting service). Smart Tab is removed from §5.10. Full report: `pui_mockups/modules/OVERLAP_UPGRADE_AUDIT.md`.

## 16. Finished-study integration (2026-10-26)
Source: `Feature_Catalogue.md` (finished I:\ study, every file of every studied addon). From Auctionator only general player-visible UX ideas are used (D-AUC decided 2026-10-26); no code-level internals, bug lists or API patterns; ElvUI is ignored per the user (t53u). No code was copied; all notes describe behaviour only.
- Guardrails G1–G25 merged into §1.G; ownership matrix §1.O; settings model §1.S.
- 18 new foundation rows 1.19–1.36; Study additions in §4 and §5.1–§5.18; new §5.17a–c; Cast History and deepened Pulse/Arena/Spark in §5.21; Phases B+ and N in §11.
- Coverage of the 23 "not yet in plan" items: Cast History (§5.21), Diagnostics (§5.17a, 1.31), `/pui profile` (§5.17b, 1.32), visibility engine (1.19), Binding ledger + conflict check (1.20), FrameLedger (1.21), window mover + importers (§4), GF queue QoL + filter builder (§5.16), Tooltip IDs (§5.7), Arena internals (§5.21), Spark attribution + triggers (§5.21), BigWigs coexistence + C_EncounterTimeline (§5.21, 1.35), AddAuraSound (§5.1), copy dialog/link handler/no-StaticPopup (1.26, 1.27), map rules + delete-protection (§5.8), search runner + escaped substitution (1.25, G12), versioned import schema (1.24), lint suite (1.33), export hub (§5.16), async data (1.23), errors-not-hidden + no CVar re-assert (G6, G7), PUI.Season (1.28), ownership matrix (§1.O).

## 18. QuestieDB and WoW-API integration (2026-10-26)
Source: `QuestieDB.md`, `WoW-API.md` (studied in full; ideas only, original code, retail 12.x). Merged feature by feature into `Feature_Catalogue.md` as (f) lines; no duplicates of G1–G25.
- **Guardrails** G26–G34 (§1.G) with self-proof fixtures; lint and test-harness additions in §5.17.
- **Settings model** §1.S: written override stack with provenance, apply model, data-driven rows, Blizzard Settings panel entry. **Menus** §2. **Raid frames** §5.2; also §5.1, 5.3, 5.4, 5.5, 5.7, 5.8, 5.10, 5.21. **Companion/release** §10.
- **Shared services (row 1.29 scope):** lazy data modules (index at login, decode on first use, bounded cache); contract range check core ↔ modules ↔ Companion; deterministic, idempotent offline generators (spell/DR/aura lists) with hand-authored overrides kept separate and authoritative, a written limitations list and a review step; enum tables that error on unknown keys in dev/test; slash-command registry with help and ranges.
- **Export/import format (concept only, extends 1.24):** Phoenix prefix + encoding version, then Base64(Deflate(CBOR)) via retail `C_EncodingUtil`; schema version inside the table, one reader per schema version; checksum; string keys or dense arrays, shallow depth, no functions; protected serialize; whole-string validation and type check before anything applies; newer-schema or already-applied strings refused clearly; import preview (changes / kept / unknown); unknown newer fields preserved; user text escaped; chunking with round-trip test for in-game report sharing (D-DIAG-SEND).
- **Retail-reference need:** both sources are Classic-only (QuestieDB TOC 11508–50504; WoW-API generated from the vanilla branch, Jan 2026, no secret-value marks). Every behaviour idea must be re-checked against retail 12.x. Phoenix needs a retail 12.x LuaLS workspace (retail Blizzard UI source + generated API docs with secret-return marks; Blizzard stubs as a library; need-check-nil, undefined-global and undefined-field kept on) and generated guardrail data (events, CVars, secret-returning functions, deprecations). Trust order: Blizzard-generated docs > community annotations > AI-generated docs (never trusted). See D-RETAIL-REF.

## 19. Retail 12.1 Blizzard UI reference (2026-10-26)
Source: `pui_study/others/RetailUI_MERGED.md` (feature by feature: Blizzard API to use, secret/lockdown rules, Blizzard bugs to avoid, how Phoenix does better) and `retail_ref/` lists. Reference only; no Blizzard code is copied. Coverage: 1,520 of 4,022 files read in full (all Phoenix-priority folders), 2,484 non-priority files noted only, 17 small priority TOC/XML files partial.
- **Decisions:** D-RETAIL-REF and D-AURA-OWNER decided; D-ARENA-DR revised (§17).
- **Guardrails** G35–G40 (§1.G); lint, menu and settings tests (1.33); feature page 1.37; reference data 1.38; settings ideas (§1.S); ownership rows for DR, map coords, audio alerts, objective tracker, chat windows, item quality colours (§1.O); coexistence list extended (1.35).
- **Hard limits found:** no combat log for addons (no own DR, meter or interrupt tracking); no SecureAuraHeader on retail; C_DamageMeter is secret in combat; PvP scores secret during a match; C_LFGList info secret in chat lockdown; chat filters skipped for secret arguments; Blizzard names slow addons to the player (profiler budget is a requirement, 1.32).
- **Per module:** Auras on CustomAuraContainer (§1.O); cast bars on `UnitCastingDuration` + `SetTimerDuration` with `castBarID`; nameplates style client plates with the renamed 12.x CVars and `C_NamePlateManager` hit insets; action bars on `C_ActionBar` with three Cooldown widgets and refcounted range checks; Pulse renders `C_EncounterTimeline` (replace the display only with `overrideViewType=None`); Embers skins `C_DamageMeter`; menus extend Blizzard's through `Menu.ModifyMenu(tag)`; tooltips via `TooltipDataProcessor`; minimap buttons through AddonCompartment; every Phoenix TOC carries `## Group: Phoenix_UI`.
- **In-game checks still needed:** private-aura container anchors on addon frames; AnimatedHealthLossMixin on addon frames; whether Devourer stack counts are secret.

## 17. Decisions pending
| ID | Question | Recommendation |
|---|---|---|
| D-AUC | May Auctionator study notes be used at all? (Its files ask AI tools not to use its code as a reference.) Until answered, nothing from it is in this plan, including a shared market-price API. | **Decided 2026-10-26:** keep ONLY general player-visible UX ideas (price-history side panel, live match count while filtering, import preview), designed Phoenix's own way. No code-level internals, bug lists or API patterns. A shared market-price API is not taken from it. |
| D-WT-DEBUG-1 | Offer `/pui safe` bisect mode? | **Decided 2026-10-26:** REJECTED. No `/pui safe`; removed everywhere. |
| D-WT-COMPAT-1 | Conflict picker for overlapping addons, never writing their settings? | **Decided 2026-10-26:** YES, the main tool. Conflict notice/picker (D-WT-COMPAT-1): on detecting an overlapping addon Phoenix notifies and the user chooses which to turn off (the Phoenix module or the other addon); nothing changes until they pick; changeable later in settings; applies to every conflict. |
| D-WT-MIGRATE-1 | Never force-reset a user subtree? | **Decided 2026-10-26:** never reset user settings; convert old settings; on a failed conversion back up that value, tell the user, reset only that setting. |
| D-PGF | With PGF loaded, stand down the whole filter layer or only the expression filter? | **Decided 2026-10-26:** resolved by D-WT-COMPAT-1: the user chooses Phoenix's Group Finder module off or PGF off. |
| D-DIAG-SEND | Allow sending error reports to another player? | **Decided 2026-10-26:** YES. User-initiated in-game sharing of Sentinel reports to other players, and every report auto-uploads via the Companion app to the vq8s.com admin dashboard for analysis. |
| D-ARENA-DR | If Blizzard DR APIs aren't exposed, build an opt-in ledger-restored mirror? | **Decided 2026-10-26, revised by §19:** the combat log is closed to addons, so no Phoenix DR tracker is possible. The opt-in (off by default) DR feature turns on `spellDiminishPVPEnemiesEnabled` (child `spellDiminishPVPOnlyTriggerableByMe`, PvP enemies only, when `C_SpellDiminish.IsSystemSupported()`) through the CVar ledger, restoring your prior value, and restyles Blizzard's DR tray. |
| D-SARENA-STEALTH | Keep the cosmetic "assume regen in stealth" option? | **Decided 2026-10-26:** keep, as an option off by default. |
| D-LIC | Licence questions on the VortexQ8-tagged forks (PGF, MSBT, SAR, AQ, idTip). | **Decided 2026-10-26:** closed. These are the user's own/co-built addons. Still never copy code, but Phoenix must include every one of their exact features, built more advanced and higher quality in Phoenix's style. |
| D-STAGE | Stage QuestieDB-master and WoW-API-main (not studied) by zipping them on your drive? | **Done 2026-10-26:** both studied in full; findings merged (§18, Feature Catalogue (f) lines). |
| D-RETAIL-REF | Where to get a retail 12.x reference (Blizzard UI source + generated API docs) for the LuaLS workspace and guardrail data? | **Decided 2026-10-26:** the Blizzard interface export from your own retail client (12.1.0+, 4,022 files), staged read-only and studied (§19); generated lists in `retail_ref/`. Later sources if needed: warcraft.wiki.gg 12.0.1–12.1.7 API pages, wago.tools. |
| D-AURA-OWNER | Who owns `CustomAuraContainer`? | **Decided 2026-10-26:** the Auras module (PUI.Auras). Private-aura container anchors are an option for raid frames, configured through PUI.Auras (§1.O). |
| D-SET-UI | Settings panel mockups (7 screens): auto profile switching default, per-page Arena filter, floating vs docked panel? | **Decided 2026-10-26:** auto profile switching by content (Raid, Arena, Mythic+) on by default; no per-page Arena filter, arena options stay under Combat/Arena; floating window as in the mockups (§1.S). Mockups await final approval. |
| D-MOD-DEF | Module mockups batch 1 (5 screens): default unit-frame style, friendly plates in instances, arena DR tray position? | **Decided 2026-10-26:** every design choice is a user setting (Simple + Advanced), defaults are first-install only (§1.S). Unit frames default Ember, Glass and other looks selectable; arena DR tray default right of the trinket, adjustable (right, left, under cast bar, free offset); friendly plates name-only vs health bars per content (open world, dungeon, raid, arena, battleground), each switchable. |
| D-MOD-DEF2 | Module mockups batch 2 first-install defaults: GF sign-up helpers, Spark vs Blizzard combat text, bag view and junk auto-sell? | **Decided 2026-10-26:** GF sign-up helpers (auto-accept role checks, auto-confirm, double-click sign-up) **ON**, taint warning kept as info; Spark turns **all** Blizzard combat-text categories off; bags open in **category view**, junk auto-sell **OFF**. All stay user settings (Simple + Advanced). |
| D-MOD-DEF3 | Module mockups batch 3 (12–19) first-install defaults? | **Decided 2026-10-26 (user t80u):** (1) Studio "Move Blizzard windows" and the Blizzard-element mover list **OFF**; (2) tooltip IDs **always visible** (Shift-only gate selectable); (3) Sentinel new-error alert: toast + badge **ON**, sound and auto-open **OFF**; (4) battleground leave countdown **ON, 15 s**; (5) Quiet mode: **every option OFF everywhere**, user turns each option on/off per content type **and per individual instance** (per-instance override list, inherits content type otherwise). All stay user settings (Simple + Advanced). Mockups 12–19 approved. |
| D-MOCK | Mockups for every new page (Cast History, Diagnostics, profiler, ledger page, visibility picker, filter builder) before UI code. | Required by standing rule. |

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
