# Nameplates (PUI_V2 5.5) - step 5 design

Child addon `Phoenix_UI_Nameplates` (depends on `Phoenix_UI`), module `Nameplates`, off by default. Mockup: `docs/mockups/modules/02_nameplates.png`.

## Structure
- `Rules.lua`: custom NPC colour rules. One list item per NPC: `<npc id or exact name>:<RRGGBB>[:<scale>][:glow]`, validated by the list editor, compiled into id and name lookups. A secret NPC id or name never matches.
- `Plate.lua`: the pooled plate (health, border, name, subtitle, health text, forces text, target outline/glow and arrows, focus outline and letter, raid marker, elite/rare and quest icons, execute line, important-cast outline, class resource pips), its update functions and the preview painter (`PaintSample`).
- `Nameplates.lua`: settings table, pool lifecycle on `NAME_PLATE_UNIT_ADDED`/`REMOVED`, one unit-event dispatcher, content tracking, CVars, schema and the step-3 migration.

## Owners reused (plan 1.O)
- Cast bar: `PUI.CastBar` (shared 13-event dispatcher, engine-timed, own-kick state). The plate only adds the important-cast outline and "hide name while casting".
- Auras: three `PUI.Auras` containers per plate (debuffs / buffs / cc); a released plate caps its lanes at 0 so the engine stops parsing them.
- CVars: `PUI.CVars` ledger, owner `Nameplates`; restored on `MODULE_DISABLED` and when a setting goes back to "game" / 0.
- M+ forces: `PUI.Season:UnitForces(unit)` (minimal provider over `C_ScenarioInfo.GetUnitCriteriaProgressValues`; Ascent remains the forces owner).
- Class resource: `PUI.ResourceBars.ClassResource.Resolve` (read only).
- Content type: `PUI.Visibility.Probe().content`.

## Rules applied
- Forbidden plates are never touched (`GetNamePlateForUnit(unit, false)`). The Blizzard `UnitFrame` is parked at alpha 0 and restored on removal and disable; no Blizzard field is written.
- The dispatcher registers only what settings need (threat, classification, cast extras, player power).
- Colour order: tapped, NPC rule (when "NPC colours win"), threat in combat (role or classic, off-tank), NPC rule (when threat wins), quest colour, class colour, reaction palette, engine selection colour. Threat, reaction, combat, tapped, quest and role values are used only when not secret.
- Secret safety: health via `SetMinMaxValues`/`SetValue`, text via `UnitHealthPercent` + curves and `SetFormattedText`, execute recolour through an engine-evaluated step colour curve, highlights and important casts via `SetAlphaFromBoolean`, resource pips receive the whole amount and the engine clamps.
- No OnUpdate: timing is engine-driven (cast bars) or C-side animation (glow, fade).

## Deferred (see PLAN 5.3)
Totem/pet compact plates, enemy range/LoS opacity, "interrupted by", NPC subtitles and quest objective text, hit-box insets and click-through, hover highlight, per-lane important/pandemic/purge glows, pool pre-warm sizing, richer rule conditions and data packs, drag-slot layout editor.
