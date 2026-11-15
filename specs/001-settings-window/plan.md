# Implementation Plan: Settings window and controls in the EllesmereUI look

**Branch**: `restore/v1-ui` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-settings-window/spec.md`

## Summary
Restyle Phoenix's shared widgets (UI/Widgets/*) and the options window (Phoenix_UI_Options/Config/Window.lua,
Renderer.lua) to EllesmereUI's measured look and layout. The work is done in place: the option schema
(`ns:RegisterOptions` rows) and the module option files stay as they are, so every module is restyled at once.
The look values sit in one table, `W.EUI`, in UI/Widgets/Core.lua, and every widget reads it with theme tokens for
colour.

## Technical Context
**Language/Version**: Lua 5.1 (WoW 12.1.5 retail, 1.60.1 Forever)
**Primary Dependencies**: the WoW UI API; Phoenix Core (Theme, Skin, Anim/Ticker, DB)
**Storage**: PhoenixUIDB (window size and scale under the Options module; no new keys except `ui.windowScale` if
missing)
**Testing**: tools/smoke/harness.lua (mock frames), luacheck, check_locales, check_api / check_ids, prepush, CI
**Target Platform**: WoW retail and Forever clients
**Project Type**: WoW addon (multi-folder, plugin packages)
**Performance Goals**: the window opens in under 150 ms (as now); no per-frame scripts
**Constraints**: no OnUpdate (use ns.Anim / C_Timer), live apply, secret-safe, no reload text, 10 locales
**Scale/Scope**: about 16 widget files, Window.lua (928 lines), Renderer.lua (1 729 lines), ~4 700 settings rendered

## Constitution Check
| Principle | Status |
|---|---|
| I. EllesmereUI look, own code | PASS: only measured values (sizes, alphas) are used; the code is written fresh |
| II. One theme, no duplicates | PASS: the widgets are restyled in place with no second widget set; colours come from theme tokens |
| III. Retail and Forever | PASS: shared files; the harness runs both TOCs |
| IV. Live, safe runtime | PASS: the toggle animation uses ns.Anim:Tween (ticker); the reload footer text is removed |
| V. Permissive libraries | PASS: no library added |
| Gates (changelog, plan, locales, harness, prepush) | Required for every commit |

## Project Structure

### Documentation (this feature)
```text
specs/001-settings-window/
├── spec.md
├── plan.md
├── tasks.md
└── checklists/requirements.md
```

### Source Code (repository root)
```text
UI/Widgets/Core.lua        # W.EUI look table (sizes, alphas) + helpers (flat fill, 1 px border)
UI/Widgets/Toggle.lua      # 40x20 square-knob toggle
UI/Widgets/Controls.lua    # Segmented, Tabs, Cog popover (+ sync icon)
UI/Widgets/Slider.lua      # track/fill/input box
UI/Widgets/Dropdown.lua    # box + menu
UI/Widgets/Button.lua      # flat button
UI/Widgets/ColorSwatch.lua # swatch border
UI/Widgets/Section.lua     # section header + row bands
Phoenix_UI_Options/Config/Window.lua    # sidebar 295 / header 138 / tabs 40 / footer 82 / 1300x946
Phoenix_UI_Options/Config/Renderer.lua  # two-up / three-up rows 50 high, alternating shading, cog + sync
Phoenix_UI_Options/Config/Groups.lua    # sidebar groups in the map §7 order
tools/smoke/harness.lua    # checks per task
```

**Structure Decision**: the existing files are extended (constitution II). No new module.

## Complexity Tracking
None.
