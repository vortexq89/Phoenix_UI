# Feature checklist: Unit Frames: player

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

## Original options (T001, 235 EllesmereUI player keys grouped)

| Original option (EllesmereUI player) | Phoenix row | Status |
|---|---|---|
| frameWidth, healthHeight | units.@.width / height | have |
| powerHeight, powerPosition, powerWidth, powerX/Y | powerBar.height / position / width / gap | have (x/y: position + gap) |
| power text: format, percent, size, x/y, power-coloured | tags.power + Text style (size, place, colour) | have (tags) |
| manaRegenSpark | resources.spark (detached bars) | have |
| healthClassColored, customBgColor, bgClassColored | bar.color, bar.bgColor, bar.bg | have |
| healthDisplay, healthReverseFill, healthVerticalFill, smoothBars, powerReverseFill | bar.reverse / vertical / smooth, powerBar.direction / smooth | have |
| healthBarOpacity, powerBarOpacity | bar.alpha, powerBar.alpha | **new (021)** |
| buffs/debuffs: show, max, anchor, growth, size, offsets | auras.buffs / debuffs / max / growth / size / gap / perRow | have |
| aura border texture, size, colour, behind, dispel-textured | auras.border (Border spec), auras.dispel | have |
| aura cooldown text and size | auras.duration text style, auras.swipe | have |
| left / right / center / extra text: content, size, x/y, class colour, align | tags.name / health / power / info + Text style per slot | have (4 slots) |
| bottom text bar (btb*) with 3 texts and class icon | strip.show / height / gap / tag + text style | have (one tag string) |
| showPortrait, portraitStyle/Mode, side, size, x/y, mirror | portrait, portraitPos, portraitSize, portraitShape, portraitZoom, portraitAlpha | have |
| detached portrait border, ring, inner shadow, wingless dragon art | portraitBorder, portraitRing, portraitArt | have (dragon art: Phoenix art kit instead) |
| absorb: show, alpha, position, height, colour, heal absorb, glow line | absorb.show / alpha / position / style / healAbsorb / overheal, colors.absorb | have |
| player cast bar (all cast* keys) | Cast bars module (spec 03x), cast.attach / height / gap here | in Cast bars spec |
| class power: show, lock, style, position, size, spacing, colours | classPower.* (show, height, shape, spacing, color, emptyAlpha, border, orientation) | have |
| foreverComboLocation | classPower.show on Forever | have |
| borderSize, borderColor, borderTexture, borderPowerSeam | units.@.border (Border spec) | have |
| highlightColor | highlight + highlightColor + highlightAlpha | **new (021)** |
| textSize | Text style per slot | have |
| combat indicator style, colour, position, size, x/y | icons.combat, icons.size | partial: position/colour decided not needed (one icon place) |
| showSolo, showInParty, showInRaid, barVisibility | vis.solo / party / raid | **new (021)** |
| visHideMounted | vis.mounted | **new (021)** |
| visHideHousing, visOnlyInstances, visHideNoTarget, visHideNoEnemy | - | decided: not built (no secure macro condition for housing; OOC fade covers the rest) |
| showWhenHealthMissing, oocFadeEnabled, oocAlpha | oocFade, oocAlpha, oocKeep | have |
| raid marker: enabled, size, align, x/y | icons.marker / markerSize / markerAnchor | have |
| leader indicator: enabled, size, position, style | icons.leader, icons.size | have |
| faction / PvP indicator: mode, style, size, position | icons.pvp | have |

## Unmentioned gaps (EllesmereUI and Blizzard)

| Gap | Phoenix row | Status |
|---|---|---|
| Hide in a vehicle (Blizzard swaps the player frame to the vehicle) | vis.vehicle | **new (021)** |
| Click actions (Blizzard: left target, right menu) | click.* on arena; secure *type1/*type2 on all | have |
| Resting / role / ready check icons | icons.resting / role / ready | have (Phoenix only) |
| Totem bar and weapon imbues (Forever) | totems.*, imbues.* | have |

Evidence: harness test "UF player: visibility, opacity, highlight (specs/021)" on retail and Forever; luacheck and check_locales clean. In-game check by the owner pending.
