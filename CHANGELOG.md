# Changelog

All notable changes to Phoenix UI on `main-v2`. Newest first. Every merged PR adds a line here and updates `docs/PLAN.md`.

## Unreleased (canary)

### Docs
- docs: master plan updated from the finished I:\ study: guardrails G1–G25 (§1.G), EllesmereUI-style live-preview settings model (§1.S), ownership matrix (§1.O), foundation rows 1.19–1.36 (visibility engine, Binding/Frame ledgers with keybind conflict check, async data, versioned import schema, search runner, copy dialog, PUI.Season, lint suite), Studio window mover, module study additions §5.1–§5.18, Diagnostics and `/pui profile` (§5.17a–c), Cast History and deepened Pulse/Arena/Spark (§5.21), Phases B+ and N, Decisions pending (§17). Auctionator content excluded pending decision.
- docs: plan §15.5, the first hand-read corrections from the EllesmereUI study: Embers segment engine on `C_DamageMeter`/`C_DeathRecap`, aura container pools are combat-legal warm caches, aura button anchor restriction, purge glow by engine group.
- docs: EllesmereUI deep study (937 files, 764,729 lines, 3,113 option controls) folded into the single plan as §15: self-evaluation of §13, new foundations (12.1 aura container engine, Blizzard-viewer Cooldown Manager model, per-spec/condition Overrides, Studio anchor and size-match links, CVar ledger), full per-section feature tables with status and acceptance, revised order. ElvUI, Plater, Cell, Bartender, Details and WeakAuras dropped as references.
- docs: single master plan in `docs/PLAN.md` (feature audit per section, I:\ competitor study, decisions on the in-menu Game Menu row and action-bar defaults, ordered phases) and this changelog. (#17)

### 2026-10-26 — design build
- HUD defaults per mockup 15: unit frame, raid, resource, cooldown, action bar, tracker, M+ timer, reminder and meter positions; Phoenix Smooth bar texture as default. (#16)
- Studio redesign (toolbar, categories, snap, grid, undo/redo, inspector with X/Y, anchor grid, nudge, mirror), game menu button and minimap button restyle with themed hover card, Shift-click to Sentinel, Sentinel viewer page in Options (mockups 12-14). (#15)
- Setup wizard redesign (mockups 05-11): welcome, five-step rail, preset art, live look preview, finish summary without reload; `theme.panel`; design accents; search magnifier. (#14)
- Options window rebuild (mockups 01-04): design kit, grouped sidebar, Dashboard, module pages with live previews, Theme & Media page. (#13)
- Design media: approved Phoenix design set in Phoenix_UI_Media (logo, 33 module icons x3, ability icons, 13 Phoenix bars incl. Carbon weave, panels, nine-slices, controls, glows, unit overlays, hero and preset art, 12 original sounds), Inter / Rajdhani Bold, Phoenix edge borders for LibSharedMedia, new TOC icon. (#12)
- Entry points: Phoenix icon, Category and Group in every TOC, Game Menu button, Addon Compartment entry, draggable minimap button. (#11)
- Media library: Phoenix_UI_Media child (43 OFL fonts incl. Arabic/CJK/Cyrillic, 22 bars, 12 backgrounds, 6 borders, 12 glows, 84 CC BY icons, 145 CC0 sounds), Core/Media kinds, LibSharedMedia bridge, alert sound, picker previews, manifest, LICENSES.md and media guardrail. (#10)
- Sentinel: readable incident viewer (message, stack, locals, count), Copy / Copy all from this session, `/pui sentinel copy [all]`. (#9)

### 2026-10-26 — PUI_V2 phases
- Phase 6: Embers, Ascent, Oracle, Wisdom, Loadouts, Group Finder, locale depth, public API v2, data packs, third-party skins, beta packaging. (#8)
- Phase 5: Skins, Vault, Flow (original CVars kept in profile and restored on uninstall), Quest Tracker, Reminders, first-install Setup, release tooling (changelog, releases.json, site features). (#7)
- Phase 4: Cooldown Manager, Minimap, Tooltip, Data Bars, Chat mirror. (#6)
- Phase 3: Nameplates, Raid/Party frames and click-casting, harness stubs, design notes. (#5)
- Phase 2: Unit Frames, Resource Bars, Action Bars, agent sweep. (#4)
- Phase 1 UI: settings renderer (Simple/Advanced), Studio v1, Theme/Media tokens, Layout registry, Sentinel Companion v1. (#3)
- Phase 1: Kernel, Schema, DB, CombatQueue, Ticker, Budget, Secret, Locale, API, Slash, Sentinel (capture, taint, drift, integrity, perf, safe mode, export), tooling (guardrails, API catalog, manifest, CI), `/pui test` harness. (#2)
