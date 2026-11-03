# Feature checklist: Rares: RareScanner parity

From `.specify/templates/feature-checklist-template.md` (constitution 1.2.0). Tick with evidence.

- [ ] **Original options**: Every option of the original addon is listed and present, or its absence is justified in the spec
- [ ] **Basics and standards**: The feature works with no setup: sane defaults, Blizzard behaviour kept where it is the standard
- [ ] **Configuration**: Every behaviour has a setting in exactly one place in the GUI; no slash commands
- [ ] **Size, position, scale**: Width, height, scale and position are settable; nothing is fixed in code
- [ ] **Colours, fonts, textures**: Colours, font (Phoenix Font by default), size, outline and bar textures are editable
- [ ] **Live preview**: The page shows the real frame drawn by the module's own code, sized to its content, no box, no clipping
- [ ] **Layout**: Movable frames are in Phoenix Layout only (never also in Edit Mode); saved per Edit Mode layout
- [ ] **Profiles**: Settings live in the profile; import, export, copy and reset work; migrations for removed keys
- [ ] **Live apply**: Every setting applies at once; none needs a reload (sim requests excepted)
- [ ] **Retail and Forever**: Both TOCs load; missing APIs fall back; check_api / check_ids and the harness pass on both
- [ ] **10 locales**: Every string in enUS, deDE, esES, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW; check_locales clean
- [ ] **Edge cases**: Combat lockdown, secret values, missing data, load-on-demand addons, empty lists, huge values, small screens
- [ ] **Unmentioned gaps**: Compared with EllesmereUI and Blizzard's own UI: what neither the original addon nor this spec mentions, listed and decided

## Original options (fill in T001)

| Original option | Phoenix row | Status |
|---|---|---|
| Rare alert on vignette (sound, flash) | Automation › Rare alert | have |
| Alert button with model and a secure target click | — | missing |
| Map pins for rares, events and treasures | Quests › Rare pins | partial |
| Killed / looted state per character | — | missing |
| Loot preview (mounts, pets, toys) on the alert | — | missing |
| Filters (per zone, per rare, collected loot only) | — | missing |
| Waypoint on alert | waypoint arrow exists | partial |
| Navigation between rares on the alert | — | missing |
