# Loadouts (PUI_V2 6.5)

Rules per content kind (`world`, `dungeon`, `mythicplus` = difficulty 8, `raid`, `pvp`, `scenario`) from `GetInstanceInfo`: spec index, saved talent loadout (`C_ClassTalents.GetLastSelectedSavedConfigID`) and equipment set (`C_EquipmentSet`). Checked on `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, spec change; differences announced in chat (optional sound). "Equip now" (`/pui loadout apply`, or `loadouts.auto`) runs through the CombatQueue one step at a time: `C_SpecializationInfo.SetSpecialization`, then (after `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`) `C_ClassTalents.LoadConfig` if `CanChangeTalents`, then `C_EquipmentSet.UseEquipmentSet`.

Settings: `loadouts.announce`, `auto` (off), `sound`; hidden `loadouts.rules`. Slash `/pui loadout save|clear|check [content] | apply`.

Deferred: per-difficulty and per-dungeon rules, options page editor for rules, loot spec, announcing to group. Unverified in game: whether `SetSpecialization`/`LoadConfig` need a hardware event when called from the zone-in path (the slash path is a key press).
