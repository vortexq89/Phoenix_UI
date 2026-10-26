# Cooldown Manager (PUI_V2 5.7) - Phase 4 core

Re-anchors Blizzard's four Cooldown Viewer containers (Essential, Utility, Buff Icon, Buff Bar) to Phoenix anchors. Post-hooks on `RefreshLayout` and `Layout` re-place `GetItemFrames()` children (sorted by `layoutIndex`) into a Phoenix grid; Blizzard keeps acquisition, cooldown and secret data. Off by default; disable calls `RefreshLayout()` to hand layout back.

Settings: `cdm.preset` (custom/minimal/standard/everything), `cdm.<viewer>.{enabled,size,perRow,spacing,growth}`. Layout elements `cdm.<viewer>`. Share string `!PUI_CDM` (`/pui cdm export|import`), imports only `cdm.*` keys.

Deferred: per-spec stores, custom bars, stable buff slots, cursor/frame anchoring, decorations, glows, per-spell states, talent conditions, custom additions, tracking-bar reskins, audio cues, per-spell import.
