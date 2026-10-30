# Review log

A system-by-system review and polish pass on the plugin layout. Each entry lists what was checked, what was
changed and what was left for later. EllesmereUI was studied for ideas only; no code was taken from it.

## 1. Spec icons (art audit, t165)
Input: the spec icon frame audit (findings F1–F4, G1–G9), the art style guide and the chrome icon spec.

Changed:
- **Even ring stroke.** `tools/media/gen_spec_icons.py` now cuts every ring by moving the outline inward along
  its normals (with a miter at the corners), so the stroke is the same perpendicular width on every shape. Before,
  the inset was radial, so flat sides came out thinner than corners.
- **Margins and centring.** Every shape reaches 1 px from the cell edge on both axes. The octagon is sized by its
  flat sides, and the shield is centred vertically (top at 1 px, point at 62 px), with the shoulder taken from the
  same box.
- **Hexagon.** The spec icon set has its own hexagon (`MaskSpecHex` / `RingSpecHex`), cut the same way. The
  action-button hexagon is unchanged.
- **One ring colour rule.** Every ring and class border uses the player's class colour. When the class is
  unknown it falls back to `border.strong` (neutral), never the accent.
- **Ember frame.** The inner line is 2 px at 64 and full strength (it was 1 px at about 60%), so it still reads
  at 16–20 px.
- **Gallery.** The gap between cells is 4 px (it was 6).
- **Docs.** `DESIGN_SYSTEM_V3.md` §3/§4 now give the surface, border and text values from `Core/Theme.lua`
  (approved in game). §5b now lists 28 panel icons: the 28th is the Great Vault, which the code skins (`Phoenix_UI_Skins/Vault.lua`).

Left for later: the PROPOSAL colours and the texture-needs list are input for the media library; they were not
adopted here.

## 2. Settings window layout (layout audit, BUILD_SPEC §4)
The audit was measured on the Figma mock, which uses Barlow and a separate 36 px title bar. Each finding was
checked against the shipping code (Phoenix Font, the merged 78 px header) before changing anything.

| # | finding | in code | change |
|---|---|---|---|
| A3 | chrome 33% of the height | header 78 + footer 40, plus the pinned preview (about 160–230 px), which stuck under the header while scrolling | The preview now scrolls away with the page by default; a lock button on the preview card keeps it on screen (remembered per module). The footer is 32 px (was 40). Fixed chrome is now 78 + 32 = 110 px (13%), or about 156 px (18%) with the Action Bars scope chips |
| A4 | 6-row card overflows by 4 px | rows are already contiguous in code (no 8 px gap) | none needed; doc says so now |
| A1 | fractional columns (360.67) | columns used `floor`, so the last pixels were lost on the right | whole-pixel columns, with the remainder spread over the first columns |
| A5 | empty column | masonry is already shortest-column-first | none; checked on the Action Bars page |
| A6 | half-empty rail | categories that aren't open collapse to one line by design | left as is |
| A11 | preview strip 53% empty | the stage zooms small samples (`Previews:Fit`); the Figma strip was fixed at 92 px | none; the empty-looking Action Bars stage in box renders is only because game icons don't render off the client |
| A7–A10 | doc contradictions | code: toggle 38×20, card titles uppercase `heading` 14 Bold, every selection bar 2 px, rail page rows 28 | the doc now matches the code |
| — | found while rendering | the spec icon style gallery overflowed its 32 px row and covered "Icon border" | the gallery rows are 64 px (General and Damage Meter) |

## 3. Damage meter rows (A12)
- The value sat over the end of the class bar with nothing behind it. Values and names are secret, so the bar
  can't be measured or stopped short of the text. Each row now has a soft dark fade behind the value column
  (Rows › Value backing, on by default, applies live; its width follows the value offset). The text keeps its
  shadow.
- Figma meter sizes and colours (260×22 rows, track = `bg.sunken`) are proposals. The current defaults stay;
  they were not clearly better.

## 4. Ember Bevel chrome icons (t169, approved style)
- 76 chrome icons (micro menu, settings nav, tabs, module tiles, macro window, window controls) in 4 states (normal,
  hover, pressed with the light burst, disabled), packed into `Media/Icons/Bevel64_*` (64 px cells, 4 px glow
  margin) and `Bevel16_*`, the simplified small variant (3 px bevel, no rivets). Draws of 20 px or less use it.
- 28 round panel medallions (`Panel128_*`). The 28th is the Great Vault, checked against the code
  (`Phoenix_UI_Skins/Vault.lua`, Skins key `vault`).
- Look-alike pairs re-drawn: module-actionbars (one button with a cooldown sweep) vs tab-layout,
  module-groupframes (stacked health bars) vs nav-bars, and panel-collections (a paw) vs the micro menu's cube.
- Wired: the micro menu (Skins › Micro menu style: Ember Bevel / Flat, live). Each button's texture is the full
  cell, so the 4 px glow margin sits inside the button. The pressed burst plays as a 0.25 s flash. Window
  medallions sit in the top-left corner of every skinned window (Skins › Window medallions, live).
- Not wired yet: the settings rail, tabs and module tiles, the macro window and the window controls still use the
  flat glyphs. The atlases and `ns.ChromeBevel:Apply` are in place for them.
- Credited as original Phoenix art in CREDITS.md. Class, spec and ability icons are never touched.

## 5. Themed Ember Bevel sets (t169, approved)
- Ember, frost, fel and arcane use their own pre-rendered sheets. Class and custom accents use the neutral sheet,
  tinted with the accent through SetVertexColor. Icons swap live on PUI_THEME_CHANGED.
- Arcane's 16 px cells (the ones drawn at 20 px or less) get +35% contrast and +15% brightness.
- Size: only the in-game sizes ship (64, 16, and 128 for panels), with no 256 masters. Only the normal look
  ships per theme, plus one shared grey disabled set. Hover and pressed are drawn in game: a theme-coloured glow
  overlay in the 4 px margin (square or round), an additive lift (12% hover, 20% pressed) and, when pressed, the
  light-burst overlay as a 0.25 s flash. `Media/Icons/Chrome` is about 13 MB, against about 37 MB with every
  state pre-rendered.
- The re-drawn look-alike icons (module-actionbars, module-groupframes, panel-collections) are hue-shifted into
  each theme, or made grey for neutral.
- The sources (the approved theme folders) stay outside the repo; `gen_chrome_bevel.py` reads them through
  `PUI_CHROME_ART`.

## 6. t169 — Ember Bevel wired through Phoenix chrome
- Settings rail (group heads + module rows), sub-page tabs, page header tile, window close buttons and the macro window controls show Ember Bevel icons over the flat glyphs; General > Chrome icons (bevel / flat) switches live.
- Medallions on bags, bank, map, help, macro, talents and the Phoenix replacement windows (quests, guild, …). The shop is skipped: its frame is Blizzard's secure store UI.
- Hover / pressed states are drawn in game; only normal per theme + a shared disabled set ship (about 13 MB).
