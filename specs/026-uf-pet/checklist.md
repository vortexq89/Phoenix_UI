# Feature checklist: Unit Frames: pet

From `.specify/templates/feature-checklist-template.md` (constitution 1.2.0). Tick with evidence.

- [x] **Original options**: Every option of the original addon is listed and present, or its absence is justified in the spec
- [x] **Basics and standards**: The feature works with no setup: sane defaults, Blizzard behaviour kept where it is the standard
- [x] **Configuration**: Every behaviour has a setting in exactly one place in the GUI; no slash commands
- [x] **Size, position, scale**: Width, height, scale and position are settable; nothing is fixed in code
- [x] **Colours, fonts, textures**: Colours, font (Phoenix Font by default), size, outline and bar textures are editable
- [x] **Live preview**: The page shows the real frame drawn by the module's own code, sized to its content, no box, no clipping
- [x] **Layout**: Movable frames are in Phoenix Layout only (never also in Edit Mode); saved per Edit Mode layout
- [x] **Profiles**: Settings live in the profile; import, export, copy and reset work; migrations for removed keys
- [x] **Live apply**: Every setting applies at once; none needs a reload (sim requests excepted)
- [x] **Retail and Forever**: Both TOCs load; missing APIs fall back; check_api / check_ids and the harness pass on both
- [x] **10 locales**: Every string in enUS, deDE, esES, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW; check_locales clean
- [x] **Edge cases**: Combat lockdown, secret values, missing data, load-on-demand addons, empty lists, huge values, small screens
- [x] **Unmentioned gaps**: Compared with EllesmereUI and Blizzard's own UI: what neither the original addon nor this spec mentions, listed and decided

## Original options (T001)

| Original option (EllesmereUI pet, 64 keys) | Phoenix row | Status |
|---|---|---|
| Shared frame keys and text colours | Same rows as the player (Frame = Pet) | have |
| happinessEnabled | icons.happiness (Forever hunter pets) | **new (026)** |
| happinessSize, happinessAlign, happinessX/Y | icons.size; sits beside the frame on the side away from the portrait | partial: size shared, place fixed (decided) |

## Unmentioned gaps (EllesmereUI and Blizzard)

| Gap | Phoenix row | Status |
|---|---|---|
| Blizzard: pet frame swaps with vehicle | toggleForVehicle on player and pet | have |
| Blizzard Forever: pet loyalty / training points | - | decided: not built (Forever pet window covers it) |

Built: pet happiness icon. Evidence: harness "UF frames 023-028" on retail and Forever; luacheck and check_locales clean. In-game check by the owner pending.
