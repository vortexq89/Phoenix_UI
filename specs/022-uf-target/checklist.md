# Feature checklist: Unit Frames: target

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

| Original option (EllesmereUI target, 232 keys) | Phoenix row | Status |
|---|---|---|
| Shared frame keys (size, power, texts, bottom text bar, portrait, absorbs, border, highlight, opacity, visibility, OOC fade, marker, leader, faction, fills) | Same rows as the player (scope bar: Frame = Target); see specs/021 | have (021 added opacity, highlight colour, visibility) |
| combatIndicator* (style, colour, position, size, x/y) | icons.combat, icons.size | partial: one icon place, decided |
| onlyPlayerDebuffs | auras.debuffFilter = Mine | have |
| buff/debuff anchor, growth, max, size, offsets, cooldown text | auras.buffs / debuffs / growth / max / size / gap / perRow, duration text | have (target defaults: buffs above, debuffs below) |
| target cast bar (castbar*, interrupt-ready colour, kick tick, mid-cast interrupt colour, uninterruptible colour, important glow) | Cast bars module; cast.attach / height / gap here | in Cast bars spec |
| eliteIndicator enabled, size, position | icons.elite, icons.size | have |
| eliteIndicatorShowInInstances, wingless art scale/flip/strata | - | decided: not built (Phoenix art kit draws the elite look) |
| factionIndicatorPlayersOnly | icons.pvp (shown only for PvP-flagged players) | have |
| detachedPortraitWinglessDragonInstances | portraitArt | have (no per-instance switch, decided) |

## Unmentioned gaps (EllesmereUI and Blizzard)

| Gap | Phoenix row | Status |
|---|---|---|
| Blizzard: threat percentage on the target | icons.threat | have |
| Blizzard: range fade on the target | rangeFade / rangeAlpha / rangeSpell | have |
| Blizzard: target-of-target beside the frame | spec 023 | own spec |
| Blizzard: classification (elite / rare / boss) text | tags.info [classification] | have |

Evidence: the target uses the player's code and rows, and the harness covers it on both clients. No target-only gap needed new code. In-game check by the owner pending.
