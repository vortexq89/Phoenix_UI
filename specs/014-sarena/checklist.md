# Feature checklist: Arena: sArena Reloaded parity

From `.specify/templates/feature-checklist-template.md` (constitution 1.2.0). Tick with evidence.

- [ ] **Original options**: Every option of the original addon is listed and present, or its absence is justified in the spec
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

## Original options (T001: sArena Reloaded v2.7.1, 123 profile keys plus per-layout settings, grouped)

Studied for behaviour only (sArena is all rights reserved; nothing reused). On retail 12.x sArena registers the combat log only off Midnight, so its combat-log features (dispel cooldowns, trinket sound/glow/colour, shadowsight) are off there; they are marked **not possible on retail**. Dampening uses the commentator API and works on 12.x. WoW Forever has no arenas.

| sArena Reloaded keys | Phoenix | Status |
|---|---|---|
| currentLayout, layoutSettings (9 layouts: BlizzArena, BlizzRaid, BlizzRetail, BlizzCompact, BlizzTourney, BlizzTarget, Gladiuish, Pixelated, Xaryu) | units.arena.layout (8 presets) + every unit row | partial: 8 own presets, no copy of sArena's 9 looks |
| classColors, classColorFrameTexture*, darkMode, darkModeValue, darkModeDesaturate, reverseBarsFill | bar.color, bar.dark, bar.reverse | have |
| showNames, classColorNames, colorNameEnabled/Color, colorSpecNameEnabled/Color, classColorSpecNames, colorMysteryGray | tags.name, nameColor, strip.tag [spec] | have |
| showArenaNumber, arenaNumberIdOnly | tag [arena:number] in any text slot | **new (029)** |
| hidePowerText, statusText.alwaysShow / formatNumbers / formatNumbersFix | tags.power, numbers, decimals | have |
| hideClassIcon, disableAurasOnClassIcon, onlyShowCCAuras, onlyShowAuras, onlyShowAurasBeforeBlizzRaid | classIcon, classIconAuras | partial: no CC-only filter |
| ccSort, defensiveSort, importantSort | class icon priority (CC > defensive > important) | partial: fixed order |
| auraHighlight (cc / important / defensive colours, class icon glow, pixel border, pulse) | auraGlow, colors.cc / defensive / important | partial: one glow style |
| trinket shown, desaturateTrinketCD, disableCDTextTrinket, invertTrinketRacialCooldown | trinket (the game's CcRemoverFrame) | have |
| playTrinketSound, trinketSound*, healerTrinketSound*, trinketUseGlow*, colorTrinket, trinketColors | - | **not possible on retail** (sArena: combat-log only, off on 12.x); Forever has no arenas |
| swapRacialTrinket, swapHumanTrinket, replaceHumanRacialWithTrinket, forceShowTrinketOnHuman, removeUnequippedTrinketTexture | racial | partial: no swap options |
| racialCategories, disableCDTextRacial | racial | partial: no per-racial list |
| showDispels, dispelCategories, desaturateDispelCD | - | **not possible on retail** (sArena registers the combat log only off 12.x); Forever has no arenas |
| drIcons*, drCategories*, drStaticIcons*, drResetTime, disableDRSwipe, disableDRBorder, colorDRCooldownText, invertDRCooldown, showDecimalsDR, drTextOn, disableCDTextDR, hideMidnightDRs, drBugFix*, newMidnightDRHandling | dr.show / size / spacing / gap / zoom / immune / mineOnly / border / text (the game's secure tray) | have on 12.x (categories are secret; per-category lists not possible on retail, as in sArena's 12.x path) |
| showCastbarTarget, showCastbarID, highlightCastsOnMe, glowCastbarIcon, castBarColors (standard, channel, uninterruptable, interruptNotReady), includeShadowWordDeath | Cast bars module (kick-ready colour, target name) | have in Cast bars; cast-on-me highlight: see Cast bars spec |
| showDampening | units.arena.dampening.show + text style | **new (029)** |
| rangeCheck (enabled, mode, in/out atlas, colour, scale, x/y), rangeCheckSpellsPerSpec | rangeFade / rangeAlpha / rangeSpell + rangeIcon (mode, size, anchor, x, y) | **new (029)**: icons; custom atlas and colour not built |
| stealthAlpha | stealthAlpha | have |
| petFrames (enabled, classes, statusText, colours, border), usePetFrameClickActions, petFrameClickAttributes | arenapet (attach, size, tags, colour), click.* | partial: no per-class filter |
| clickAttributes, enableCliqueSupport, clickthroughFrames | click.left / right / middle (+ text), ClickCastFrames | partial: no click-through |
| gladTracker, shadowSightTimer, tbcStunIconFix | - | not on retail (TBC/Wrath only in sArena) |
| cooldownSwipeColor, disableSwipeEdge, disableClassIconSwipe, disableTrinketRacialSwipe, invertClassIconCooldown, showDecimalsClassIcon, decimalThreshold, disableCDTextClassIcon | auras.swipe, iconZoom | partial |
| disableOvershields | absorb.overheal | have |
| useHighlightColor, highlightColor, highlightCC | highlight + highlightColor (021), targetBorderColor (028) | have |
| useDefaultPartyFrames, arena targets on party frames | widgets.targets | have |
| enableMasque, enableMasqueExtra | - | decided: Phoenix skins its own icons (no Masque) |
| improveTextRendering, Fonts module | Text style per slot (Phoenix Font) | have |
| Import/Export, Profiles, TestMode | Phoenix profiles, test frames (2-5 opponents) | have |

**Original options line stays open**: 9 rows are still missing or partial (see the table); they are the next arena pass.
