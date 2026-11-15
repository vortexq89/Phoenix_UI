# Unit Frames (PUI_V2 5.3) - Phase 2 design

Child addon `Phoenix_UI_UnitFrames` (not load-on-demand, depends on `Phoenix_UI`), module `UnitFrames`, off by default.

## Structure
- `Tags.lua`: text tags for the four zones (left, center, right, power). Each tag says which channel refreshes it (name, health, power).
- `Elements.lua`: builds the children of one secure button (health, power, absorb/heal-absorb/incoming segments, texts, cast bar, portrait, indicators) and the per-channel `Update*` functions.
- `Blizzard.lua`: parks or restores the matching Blizzard frame per group (reparent through the CombatQueue).
- `UnitFrames.lua`: groups, trackers, lifecycle, schema, Studio elements.

## Rules applied
- Buttons: `SecureUnitButtonTemplate,PingableUnitFrameTemplate`, `type1=target`, `type2=togglemenu`, registered in `ClickCastFrames`, parented to a `SecureHandlerStateTemplate` frame with `[petbattle] hide; show`. Visibility by `RegisterUnitWatch` (player is always shown).
- One tracker frame per unit, `RegisterUnitEvent` only for needed channels: base, power (bar height > 0 or a power tag), prediction (absorbs or incoming heals on), portrait (not off), cast (cast bar on). Target of target and focus target use one shared 0.5 s Ticker entry (`uf.polled`) that exists only while one of them is drawn by Phoenix. No `UNIT_AURA`.
- Secret safety: health/power go to `SetMinMaxValues`/`SetValue`; percent text via `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` in `SetFormattedText`; gradient colour via a colour curve; class colour via `C_ClassColor.GetClassColor(token)`; reaction via `UnitSelectionColor`; absorbs and incoming heals via one `CreateUnitHealPredictionCalculator` per unit; cast bars via `SetTimerDuration(UnitCastingDuration/UnitChannelDuration)`; uninterruptible shield via `SetAlphaFromBoolean`; raid marker via `SetSpriteSheetCell`. Booleans that may be secret are checked with `PUI.Secret.IsSecret` before any Lua test.
- Protected work (button size/position, unit watch, state driver, Blizzard reparent) goes through `PUI.CombatQueue.Defer`.

## Not in this phase (reported)
Auras through `AuraContainer`, dispel overlay, Player Aura Bars, detached text bar, class art and portrait shapes, class resources on the player frame (Resource Bars carries them), kick-ready tick, important-cast glow, latency zone, empower pips, visibility rule lanes, Blizzard/Classic looks.
