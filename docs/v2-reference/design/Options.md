# Options, Studio, Theme and Media (Phase 1)

## Where the code lives
- **Core** (always loaded):
  - `Core/Theme.lua`: tokens, accent and `Theme:Paint` live repaint.
  - `Core/Media.lua`: named fonts and textures, plus shared Font objects.
  - `Core/Layout.lua`: element registry and `layout.positions`.
  - `Core/OptionsHost.lua`: the options and Studio settings, and `/pui`, `/pui options` and `/pui studio`.
- **`Phoenix_UI_Options`** (load on demand):
  - `Model.lua`: pages, search, commit and reset. Pure data, unit-tested.
  - `Widgets.lua`: rows and controls.
  - `Panel.lua`: the window.
  - `StudioModel.lua`: the session with undo and redo.
  - `Studio.lua`: overlay, grid and movers.

## Settings
| key | type | mode | applies |
|---|---|---|---|
| theme.accent | select ember/flame/spark/void/life/class | simple | repaints every painted object |
| theme.panelAlpha | range 0.5-1 | advanced | repaints panel backgrounds |
| media.uiFont / media.numberFont | select (registered fonts) | simple / advanced | re-fonts shared Font objects |
| media.fontScale | range 0.8-1.5 | simple | re-fonts shared Font objects |
| options.mode | select simple/advanced | simple | re-renders the window |
| studio.showGrid / studio.snap / studio.gridSize | toggle / toggle / range 4-64 | simple / simple / advanced | redraws the grid |
| layout.positions | layout (hidden) | - | re-places every registered element |

## Rules
- **Live apply:** each widget writes through `Model.Commit`, which validates the value, quantizes it and then calls `Schema:Set`. Right-clicking a row resets it. A row shows the accent dot while its value differs from the default.
- **Search:** searches every visible key in both modes. Matches on label, tooltip, key and `searchTags`, with a fuzzy fallback on the label.
- **Studio and combat:**
  - Studio refuses to open in combat.
  - `PLAYER_REGEN_DISABLED` suspends it, and the CombatQueue resumes it once combat ends.
  - Movers use the engine's StartMoving, so there is no OnUpdate.
  - Keyboard nudges are 1 px, 10 px with Shift and 100 px with Ctrl. Ctrl+Z and Ctrl+Y undo and redo.
  - Esc exits; with unsaved changes it needs a second Esc.
- **Positions:** stored as `{ point, x, y }` relative to UIParent, and only for elements away from their default. Protected frames are placed through the CombatQueue.
- **Media:** fonts and textures point only at client files until the licensed packs ship, so no path can be missing.
