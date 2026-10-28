# EllesmereUI UX study (description only)

Written for the t119u overhaul. It describes how EllesmereUI (https://ellesmereui.com/) presents itself and how
its setup feels to a player. **No code, art, layout data or assets from EllesmereUI are used in Phoenix UI**; this
file only records product-level observations, so Phoenix can set its own, better bar.

## What the site promises
- "Your entire interface. One addon." Twenty modules, one profile, free.
- Each module is pitched by the *job it does for the player*, not by its settings: cooldown manager ("the heart of
  the HUD"), raid frames ("healer-grade"), nameplates (aura filtering, interrupt-aware casts, execute glow), unit
  frames, action bars (modern or Blizzard look, custom shapes, paging, icon effects), resource and cast bars,
  chat and quest tracker.
- Unlock mode: "one keypress and the whole interface becomes drag-and-drop", snapping to other elements, to the
  screen and to a pixel grid, then lock it back down.
- Community presets imported in one click; detailed patch notes per release.

## Why it feels easy
1. **One obvious way in.** A single key / button opens everything; layout editing is one step away.
2. **The game is the preview.** Changes show on the real frames on screen, at their real size, not in a mock-up.
3. **Opaque, calm surfaces.** Flat dark panels, thin 1 px edges, one accent colour, generous spacing, and text
   large enough to read at any UI scale. Nothing is tinted by the world behind the window.
4. **Module-first navigation.** A short list of modules, each opening on its most-used controls; deep options
   sit lower or behind expanders instead of all at once.
5. **Starting points.** Presets and profiles make a good default one click away, so a new user is never facing
   a blank or broken layout.
6. **Safe defaults.** Nothing overlaps out of the box; optional bars start hidden.

## Where Phoenix must be better (and what this round changed)
| Area | Gap seen in the t119u screenshots | Phoenix answer |
|---|---|---|
| Entry | No obvious way to open PUI | Minimap button, Game Menu button, compartment entry |
| Bars | Buttons 24 px, bars bunched together | Edit Mode icon-size scale undone on taken-over buttons; non-overlapping defaults |
| Movers | Boxes for invisible Blizzard frames, clutter | Boxes only for frames on screen, eye toggle for hidden ones, Settings button per frame |
| Previews | Sample icons, capped sizes | Real spells/units at true size, scaled only to fit, with a scale label |
| Look | Brown, muddy, tiny "PS1" text | Opaque higher-contrast surfaces, 12 px text floor, window auto-scaled at small UI scales |
| Navigation | Hard to find things | Bars first, setup tools (Layout, profiles, presets) first in the Phoenix group |

## Still to reach and pass
- Edit directly on the real frame: click a mover box to get its key settings in place (a popup), not a jump to
  the options page.
- One-click community presets with a preview of the whole screen.
- A first-run wizard: role, resolution, preset, done.
- Per-module "simple / advanced" split so the first screen of each page shows only the most-used controls.
