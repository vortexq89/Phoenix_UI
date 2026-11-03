# Feature checklist: Unit Frames: boss

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

| Original option (EllesmereUI boss, 139 keys) | Phoenix row | Status |
|---|---|---|
| Shared frame keys | Same rows as the player (Frame = Boss) | have |
| oorAlpha | rangeFade / rangeAlpha | have |
| bossStackDirection, buffSpacing, debuffSpacing | growth, spacing, auras.spacing | have |
| simpleBuffs / simpleDebuffs and their cooldown text | auras with filters and duration text | have (one aura style) |
| buff/debuff cooldown and stack text colours | auras.duration / auras.count text style | have |
| bossTargetBorderEnabled, colour, alpha | targetBorder + targetBorderColor | **new (028): colour** |
| bossHoverBorderEnabled, colour, alpha | highlight + highlightColor + highlightAlpha (021) | have |
| borderCustom | units.@.border | have |
| castbar* (size, offsets, interrupt colours, kick tick) | Cast bars module | in Cast bars spec |

## Unmentioned gaps (EllesmereUI and Blizzard)

| Gap | Phoenix row | Status |
|---|---|---|
| Blizzard: boss frames show at encounter start | INSTANCE_ENCOUNTER_ENGAGE_UNIT, Unit Watch | have |
| Test with 5 bosses | Test frames | have |

Built: target border colour (every frame). Evidence: harness "UF frames 023-028" on retail and Forever; luacheck and check_locales clean. In-game check by the owner pending.
