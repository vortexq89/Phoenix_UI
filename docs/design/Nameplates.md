# Nameplates (PUI_V2 5.5) - Phase 3 design

Child addon `Phoenix_UI_Nameplates` (depends on `Phoenix_UI`), module `Nameplates`, off by default.

## Structure
- `Plate.lua`: pooled plate frame (health, name, health text, cast bar, target outline, raid marker, elite/rare and quest icons, execute marker) and its update functions.
- `Nameplates.lua`: pool lifecycle on `NAME_PLATE_UNIT_ADDED`/`REMOVED`, one dispatcher frame for every unit event (one cast dispatcher), CVar control, schema.

## Rules applied
- Phoenix frames are parented to the Blizzard plate (`C_NamePlate.GetNamePlateForUnit(unit, false)`: forbidden plates are never touched). The Blizzard `UnitFrame` is parked with `SetAlpha(0)` and restored to 1 on removal and on disable. No Blizzard field is written.
- The dispatcher registers only the events the settings need (cast events only with cast bars, threat events only with threat colours, classification only with the icon).
- Colour priority: tapped grey, then (in combat, threat colours on) a 3-tier threat colour by role (tank wants status 3, others want 0), then class colour (players, class mode) or `UnitSelectionColor`. A secret threat status or combat flag is never compared: the plate falls back to reaction colour.
- Friendly name-only: class-coloured name, no health or cast bar; decided only when `UnitIsFriend` is not secret.
- Secret safety: health via `SetMinMaxValues`/`SetValue`, percent via `UnitHealthPercent` + `CurveConstants.ScaleTo100`, casts via `SetTimerDuration`, uninterruptible shield and target outline via `SetAlphaFromBoolean`, raid marker via `SetSpriteSheetCell`.
- CVars (`nameplateMotion`, `nameplateGlobalScale`) are written only when a setting leaves "default"/1, out of combat, with the original value saved and restored when the module turns off.

## Not in this phase (reported)
Colour rules engine and data packs (Section 9), off-tank detection through boolean curves, 6 icon / 6 text slots, target arrows, class resource on the target plate, aura container with CC/important/own filters, important-cast glow, totem/pet compact plates.
