# Damage meter: item level and spec icon styles (t161 A) - spec

Status: §1 item level built (t163, Phoenix_UI_DamageMeter/Extras.lua). §2 spec icon styles built (t163, UI/SpecIcon.lua): 15 styles (Blizzard + 14 Phoenix-made), a shared picker in General with a live gallery, and a per-meter override; also used by arena spec icons and group finder applicants.

## 1. Item level per player
* Source: `C_PaperDollInfo.GetInspectItemLevel(unit)` after `NotifyInspect(unit)` / `INSPECT_READY`, and
  `GetAverageItemLevel()` for you. The meter's own rows carry no unit token, and other players' GUIDs and names are
  secret in combat, so the match is made out of combat: group units are inspected (queued, one every 1.5 s, only out
  of combat, never while the inspect frame is open), cached by GUID, and a row shows the cached value when its GUID is
  plain. In combat the cached values still show by row order only when it can be matched without reading a secret
  (your own row through `isLocalPlayer`); others show after combat.
* Display: small number after the name (option: off / after name / tooltip only); colour by the Phoenix item-level
  quality ramp.

## 2. Spec icon styles
Licence check: no public icon set of WoW class/spec art is CC0 or permissive (the art is Blizzard's; fan sets are
"personal use"), so Phoenix ships **no third-party spec icon images**. Styles are Phoenix's own treatments of the
client's spec icons (`specIconID`, drawn by the game, nothing redistributed) plus Phoenix-drawn glyphs:

| # | Style | How |
|---|---|---|
| 1 | Blizzard (default) | the spec icon as the game draws it |
| 2 | Flat zoomed | 8% crop, no border |
| 3 | Square bordered | 1 px theme border |
| 4 | Outlined | 2 px class-colour outline |
| 5 | Round | circular mask (`SetMask` with Phoenix's own circle mask texture) |
| 6 | Round ringed | round + class-colour ring |
| 7 | Rendered / 3D | inner shadow + top highlight gradient + drop shadow |
| 8 | Desaturated | greyscale, class tint on hover |
| 9 | Class tint | desaturated + class-colour vertex tint |
| 10 | Hexagon | Phoenix hexagon mask |
| 11 | Role glyph | Phoenix-drawn tank / healer / damage glyphs (own SVG, MIT) in class colour |
| 12 | Class glyph | the client's class atlas (`classicon-<class>`), game-drawn |
| 13 | None | no icon |

Masks and glyphs are drawn for Phoenix (original, MIT, listed in CREDITS.md as Phoenix's own). Picker: a select with
a live strip of 5 sample icons per style, in the Rows card.
