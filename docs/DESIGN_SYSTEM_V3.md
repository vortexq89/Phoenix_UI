# Phoenix UI — Design System v3 (draft for owner approval)

Status: **proposal, revision 2 (t148)**. Nothing in this document is built yet, except the t146/t147 fixes listed at the end.

**Revision 2 direction (owner, t148):** every Blizzard window keeps **the game's own layout and structure** and is
restyled in the Phoenix theme, with our extra features and settings added, the way ElvUI and EllesmereUI skin
(no custom re-layouts of Blizzard windows). Phoenix's own icon set appears **only on UI chrome**: micro menu,
macro window controls, settings GUI tabs and navigation, and window controls. Class, spec, ability, spell, item,
mount, pet, toy and portrait icons are never replaced.
Mockups (`docs/screenshots/v3/`, schematic renders, not in-game). Each Blizzard-window mockup is drawn on the real
geometry from the Blizzard source (`BlizzardInterfaceCode`, read-only):
- `character_v3.png`: CharacterFrame expanded (540×424; 8+8 slots 37 px at 4 px gaps; model; InsetRight stats pane 172 wide
  with its 3 sidebar tabs; Character / Reputation / Currency bottom tabs).
- `collections_v3.png`: CollectionsJournal (703×606; MountCount; LeftInset list of 208×46 rows with 38 px icons; search 145×20;
  Filter; MountDisplay; Summon; 6 bottom tabs).
- `macro_v3.png`: MacroFrame (338×424; General / Character top tabs; 319×146 selector, 6 per row; selected macro, Change
  Name/Icon; 286×85 edit box; Delete / New / Exit).
- `micromenu_v3.png`: the 13 micro buttons (32×40) in Blizzard's order, with their states.
- `settings_v3.png`: Phoenix's own settings GUI (not a Blizzard window), with the chrome icon set on the rail and tabs.
- `chrome_icons.png`: the chrome icon set (§5a).

Why v3: the first real in-game review (2026-10-29, 16 screenshots at 2560×1440, UI scale 0.53) showed the
settings window wasting about 35% of its width, clipped labels, previews that are bigger than what they preview,
a half-skinned mix of Blizzard parchment and Phoenix dark, and windows that can't be moved. v3 fixes the system
behind all of this, not each screen on its own.

---

## 1. Principles

0. **Same as the game.** A Blizzard window keeps Blizzard's layout: the same frames, positions, sizes, tabs,
   lists and order. Phoenix restyles every region (surfaces, borders, fonts, buttons, tabs, scroll bars, inputs),
   and may *add* information inside the existing structure (item level on slots, a usage count, syntax colours,
   tooltip lines) and settings for it. It never moves Blizzard controls into a new arrangement or replaces a
   window with its own. Phoenix's own frames (bars, unit frames, nameplates, the settings GUI) are designed freely.
1. **One surface language.** Every Phoenix surface is one of three levels: `base`, `raised` or `sunken`.
   No window ever shows Blizzard parchment, red buttons or gold frames next to Phoenix chrome. A frame is
   either fully skinned (every region listed in §8 handled), or left fully Blizzard and marked "not skinned".
   Never half.
2. **Content first.** Chrome (rails, headers, footers) takes at most 20% of a window. No column exists only
   to hold one entry.
3. **Nothing truncates by design.** Labels wrap to two lines, or the control moves under its label. "…" is only
   allowed in user data (names, item links), and then a tooltip shows the full text.
4. **Show, don't decorate.** A preview appears only when it shows something the controls can't (§6).
5. **The game's art stays.** Class, spec, ability, spell, item, mount, pet, toy, macro and portrait icons are never
   replaced or recoloured. The only exceptions are the game's own states: empty, not collected, unusable.
   Phoenix chrome icons (§5a) go only on chrome.
6. **Live.** Every setting applies without /reload. A reload is allowed only for a module's first enable,
   and the badge says so in its own line (it never shares a line with a label).

## 2. Grid and spacing

- **Base unit 4 px** (in UI units at scale 1; Phoenix snaps to physical pixels via `PixelUtil`).
- **Spacing scale** (tokens `space.*`): `0`=0, `1`=4, `2`=8, `3`=12, `4`=16, `5`=24, `6`=32, `7`=48.
- **Layout grid in content areas:** 12 columns, 16 px gutters, 24 px outer margin. Cards span 12, 6 or 4 columns.
  Two-column settings pages use 6+6 above 960 px of content width, and drop to one column below that.
- **Control heights:** 24 (compact), 28 (default), 36 (primary actions). Row height in lists is 32, or 44 with
  a subtitle.
- **Radius:** 4 for controls, 6 for cards, 8 for windows. Borders are 1 physical px.
- **Window sizes** (settings): minimum 960×620, default 1180×760, remembered per profile; resizable from the
  bottom-right corner, movable from the title bar.

## 3. Type scale

**One family for all Phoenix text: Inter** (SIL OFL 1.1, `Media/Fonts/Inter-*.ttf`, licence in
`Media/Fonts/Licenses`). Only the brand wordmark stays Cinzel.

Chosen by rendering six OFL candidates at true pixel sizes 10–14 on the Phoenix surface
(`docs/screenshots/v3/font_compare.png`):

| font          | x-height / cap | width of a 12 px sample | at 10–12 px                                              |
|---------------|----------------|-------------------------|----------------------------------------------------------|
| **Inter**     | 0.75           | 234 px                  | clearest: open counters, distinct `I l 1`, `rn` ≠ `m`    |
| Noto Sans     | 0.75           | 230 px                  | very close second; slightly softer stems at 10 px        |
| Source Sans 3 | 0.74           | 203 px                  | the narrowest (fits the most text), but cramped at 10–11 |
| Roboto (old)  | 0.75           | 216 px                  | good, but `I/l` look alike; it was mixed with Inter      |
| Fira Sans     | 0.77           | 222 px                  | readable; its humanist shapes clash with the geometric UI |
| Lato          | 0.71           | 213 px                  | the smallest x-height; blurs at 10 px                    |

Roles (`Core/Theme.lua` `fontRoles`, at 1:1 pixels at pixel-perfect scale; render
`docs/screenshots/v3/type_scale.png`). No role goes below 12:

| role      | face           | size | use                                         |
|-----------|----------------|------|---------------------------------------------|
| `title`   | Inter Bold     | 20   | page / window title                         |
| `heading` | Inter Bold     | 13   | card headers (uppercase)                    |
| `body`    | Inter Medium   | 14   | labels, row text                            |
| `desc`    | Inter Regular  | 12   | descriptions, hints                         |
| `number`  | Inter SemiBold | 13   | values, timers                              |
| `small`   | Inter Medium   | 12   | badges, captions, chips                     |
| `unit`    | Inter SemiBold | 12   | unit frame names and health text            |
| `combat`  | Inter Bold     | 16   | in-world numbers (outlined); combat text 20 |

Skins: Blizzard's font objects (GameFont*, SystemFont*, tooltip, quest and GameNN fonts used by the skinned windows)
take the same Inter faces, keeping their sizes and outlines (General › Text › "Use theme fonts on Blizzard UI",
**on by default**, live; names above heads change after a relog). CJK clients keep the game font; ruRU uses Inter,
which includes Cyrillic. The user's own UI font and unit font choices still override the roles.

Colour roles: `text.primary` (92% white), `text.secondary` (68%), `text.muted` (48%), `accent.text`.
Minimum contrast: 4.5:1 for body text on its surface, and 3:1 for icons and borders that carry meaning.

## 4. Colour and surfaces

- Surfaces: `bg.base` #15171B, `bg.raised` #1C1F24, `bg.sunken` #101215, `bg.hover` (white 6%).
- Accent (theme): `accent.primary`, `accent.secondary`, and `accent.soft` = accent at **10%** alpha.
  Soft tokens carry their own alpha and are never forced opaque. (A harness lint enforces this, after the nav
  rail bug.)
- State: `state.success`, `state.warning`, `state.danger`, `state.info`, each with a `.soft` variant.
- Elevation: `raised` adds a 1 px top highlight (white 4%) and a 12 px, 30% black shadow. Popovers and menus
  use a 24 px shadow.

## 5. Components

Every component has the states **default, hover, pressed, selected, focused, disabled**, plus **error** where
it applies. Its focus ring is a 1 px `accent.primary` outline plus a 2 px gap.

- **Nav rail item** (icon 20, label `micro` below, 64×56):
  - default: icon `text.secondary`, no fill;
  - hover: `bg.hover` fill, icon `text.primary`;
  - **selected**: `accent.soft` fill (10%), a 3 px accent bar on the left edge, icon `accent.primary`, label
    `text.primary`. The fill never hides the icon;
  - disabled: 40% opacity.
- **Sub-nav list** (page list): rows of 32 px, icon 16 and `body`; selected = `accent.soft` fill plus a 2 px
  bar plus `body.strong`. **Only shown when the group has 2 or more pages.** A one-page group opens its page
  directly, and the column collapses (this removes the empty "Home" column).
- **Tabs** (page tabs): text `body`, 12 px horizontal padding, auto width (never a fixed width). Selected = a
  2 px accent underline plus `text.primary`. They overflow into a "More ▾" menu, never truncate.
- **Card**: `bg.raised`, radius 6, 16 padding, title row (icon 16 + `title` + optional actions on the right).
- **Setting row**: label (`body`) + optional description (`small`, `text.muted`, max 2 lines) on the left;
  the control on the right at a fixed 40% column. Below 420 px of card width, the control moves under the
  label. Badges (`RELOAD`, `NEW`, `BETA`) sit on their own line under the label, never inline.
- **Toggle** 36×20, **slider** with a value field (number, editable), **select**, **color swatch**,
  **media picker** (§9). All 28 high.
- **Buttons**: primary (accent fill), secondary (raised + border), ghost, danger. Labels never truncate; the
  button grows.
- **List row** (game windows): 32/44 px, icon 24 on the left, title + subtitle, value on the right, hover fill,
  selected bar.
- **Window chrome**: a 36 px title bar (icon, title, actions, close), body, optional 32 px footer. Movable by
  the title bar; position saved (§7).
- **Empty / unknown slot**: the slot fill `bg.raised` plus a 1 px `border.subtle` border; the game's empty-slot
  art is drawn at 70%, additive, so it reads as an outline rather than a black square.

## 5a. Chrome icon set

An original set (`tools/media/gen_chrome_icons.py`, SVG sources in `tools/media/chrome/`, sheet
`docs/screenshots/v3/chrome_icons.png`): 45 icons on a 24-unit grid with a 2-unit safe margin, a 1.75 stroke,
round caps and joins, outline only, and one tint set by the theme per state (default `text.secondary`, hover
`text.primary`, active `accent.primary`, disabled 40%). Drawn at 16 / 20 px in game.

| group | icons | used on |
|---|---|---|
| Micro menu (13) | character, professions, spells, achievements, quests, housing, guild, group finder, collections, journal, help, shop, menu | the 13 micro buttons, in Blizzard's order |
| Settings nav & GUI tabs (17) | home, bars, frames, interface, combat, content, windows, systems, phoenix, profiles, look, support; tab: layout, appearance, text, behaviour, colours | settings rail, sub-nav, page tabs |
| Macro window (6) | general, character, new, delete, rename, save | the macro tabs and buttons (never the macros' own icons) |
| Window controls (9) | close, move, settings, search, filter, lock, reset, favourite, expand | title bars, search boxes, filter dropdowns, list markers |

Where a Blizzard chrome element has a glyph (sidebar tabs, filter dropdown, search magnifier, close X), the
Phoenix one replaces that glyph. Where the element shows game content (the portrait tab, a mount icon, a
macro's icon), nothing changes.

## 6. When a preview is shown

A preview appears **only** if all three are true:
1. the page configures something visual that isn't on screen while the settings are open (or is hidden in
   combat or only in groups);
2. the preview can draw it at **at least 75% of its real size** (otherwise "Show in world" with test mode
   replaces it);
3. the page has at least 3 settings that change the preview.

Placement: a docked card at the top of the content, **height-fitted to its content** (no fixed 140 px black
box), with a 16 px stage padding and the stage colour `bg.sunken`. The stage is never darker than the window
behind it. Action Bars: one bar at real size (40 px buttons); bars that don't fit scroll horizontally, and are
never scaled below 75%. Pages with no preview (Profiles, Diagnostics, About, Chat filters, Automation...) use
the full width.

Grips (size / move) are 18 px buttons in the stage's bottom-right corner, 12 px glyphs, always explicitly sized.

## 7. Moving windows ("move any panel")

A `Movers.Window` registry (separate from the HUD movers): any Blizzard or Phoenix window can be dragged by
its title bar, and Shift-drag on a window without one. Its position is saved per profile, it resets from
right-click on the title, and nothing is moved in combat if the frame is protected (the drag is queued for after
combat). Covers Character, Collections, Achievements, Group Finder, Friends, Guild, Professions, Talents,
Spellbook, Map, Quest Log, Mail, Merchant, Bank, Bags, Auction, Calendar, Encounter Journal, Inspect, Trade and
Vault (list in `SKINS_PLAN.md` §window list).

## 8. Skin coverage rule (ElvUI / EllesmereUI style)

A skin keeps the frame and restyles its regions in place. For each skinned frame, Phoenix keeps a **region
manifest** taken from the Blizzard source (`BlizzardInterfaceCode/Interface/AddOns`, read-only reference). Every
NineSlice, Bg, Inset, ThreeSlice piece (`Left/Center/Right`), tab, scroll bar, close button and parchment
texture of that frame is listed, then either hidden behind a Phoenix surface or restyled. Game content (model
scenes, item and portrait art, icons) is kept. Nothing is re-anchored except where Blizzard's own art left gaps
that our 1 px borders don't need; such shifts are at most 4 px and listed in the manifest. A frame ships as
"skinned" only when its manifest has no unhandled region. A dev command (`/pui skincheck`) walks the frame's
regions and lists anything that is still Blizzard art.

Order: Game Menu, Character (with Reputation, Currency), Collections (Mounts, Pets, Toys, Heirlooms, Appearances,
Campsites), Macro, micro menu, Achievements, Group Finder, Bags, Quest Log and objective tracker, then the rest of
`SKINS_PLAN.md`.

**Replacement windows retire:** Phoenix's own re-laid-out windows (the Phoenix character, friends, guild,
mail, merchant, inspect... windows in `Modules/Skins/*Window.lua`) go against principle 0. Under v3 they become
skins of Blizzard's window, keeping their extra data (item level, set tools, search) inside Blizzard's layout.
Until that skin exists, each one stays available as an opt-in "classic Phoenix window", off by default.

## 9. Media pickers

Pickers show a live sample per entry (bar fill, border, glow, font line, sound play button), in a grid of
5 columns above 12 entries, searchable, with a source badge (Phoenix / LSM / Blizzard).

## 10. Plugin architecture

Goal (EllesmereUI-style): each system is a **self-contained plugin** with an on/off switch, and **third
parties can register replacement designs** that users switch between.

### 10.1 Systems

```lua
local sys = Phoenix:RegisterSystem("Character", {
  label = "Character window", icon = "character", category = "windows",
  defaults = { enabled = true, design = "phoenix" },   -- per-profile
  owns = { "CharacterFrame" },                          -- frames this system is responsible for
})
```

Each existing module becomes a system (the module manager already provides the lifecycle and on/off). It is
switchable live: **Off** gives Blizzard's frame untouched (all regions restored).

### 10.2 Designs

```lua
Phoenix:RegisterDesign("Character", "phoenix", {        -- id unique per system
  label = "Phoenix", author = "Phoenix UI", version = "1",
  preview = "Interface/AddOns/Phoenix_UI/Media/Designs/character_phoenix",  -- 512x320 thumbnail
  apply   = function(ctx) ... end,    -- build or restyle; ctx = { frame, db, theme, tokens, Skin, W }
  remove  = function(ctx) ... end,    -- undo completely (required)
  options = function(ctx) return { ...option rows... } end,  -- optional extra settings for this design
  supports = { retail = true, forever = false },
})
```

- Built-in designs per system: `blizzard` (the game's frame, untouched) and `phoenix` (the game's frame in the Phoenix
  theme, plus our extras). For Phoenix-owned systems (bars, unit frames, nameplates, group frames, auras,
  combat text) designs may differ freely. **For Blizzard windows, a design is a skin:** it may restyle and add,
  never re-lay out (principle 0). The registration check refuses a window design that re-anchors the frame's
  manifest regions.
- A third-party addon declares `## Dependencies: Phoenix_UI` and calls `RegisterDesign` at load. Phoenix lists
  it in the system's **Design** picker, with its thumbnail and author.
- Contract: designs only use the public API (`Phoenix.Skin`, `Phoenix.Widgets`, tokens, `Phoenix.Events`).
  They never touch protected frames in combat; `remove` must restore every region (checked by
  `/pui skincheck`). Errors in a design are caught (SafeCall), and Phoenix falls back to `blizzard` for that
  system and shows a notice.
- Switching designs is live: `remove(old)` then `apply(new)`. The settings of a design are stored under
  `systems.<key>.designs.<id>`.
- Versioned API: `Phoenix.API_VERSION = 3`. A design declares `api = 3`, and a mismatch is refused with a
  message.

### 10.3 Settings UI

The **Systems** page is a grid of system cards (on/off, design picker, "Configure"). Each system's page starts
with a **Design** row (thumbnail strip).

## 11. Settings window layout (v3)

`rail 64 | sub-nav 200 (only when needed) | content (fluid) `, with the preview inside the content (§6), not in
a fixed right column. The header has the page title (`display`) and a description, with Reset and the module
toggle on the right. Tabs sit below the header and never truncate. The footer holds save status, the scale
slider and Reload (only when one is needed).

## 12. Feature catalogue

`docs/design_v3/FEATURES.md` has one entry per feature: all 30 modules, each section (card) inside them, and the
8 built-in pages, 1,488 options in all. Each entry gives the feature's purpose, what it shows, its place in the
settings tree, the components it uses (per section), how it fits with its neighbours, and whether it gets a live
preview, with the reason under §6. The catalogue is regenerated from the live option schemas
(`PUI_DUMP=… lua5.1 tools/smoke/harness.lua . retail`, then `tools/design/features.py`), so it can't drift from the
code.

Preview verdicts under §6 (today every module has one):
- **Keep:** Action Bars, Cooldown Manager, Cooldown Text, Unit Frames, Group Frames, Cast Bars, Nameplates, Auras,
  Combat Text, Spell History, Tooltip, Item Level, Mythic+, Encounters, General.
- **"Show in world" instead:** Damage Meter, Bags, PvP, AFK.
- **Drop:** Chat, Minimap, Data Texts, Skins (an "Open" button per window instead), Quests, Group Finder, Sim,
  Layout mode, Quality of Life, Automation, Bugs.

## 13. Delivery plan (after approval)

1. Tokens + type scale + spacing in `Core/Theme.lua`; component states in `UI/Widgets` (1 commit, live).
2. Settings window v3 layout + preview rule (§6, §11).
3. Chrome icon set into `Media` (an atlas sheet like the current icons) and onto the micro menu, macro window,
   settings rail and tabs.
4. Plugin API (§10) on top of the module manager; Game Menu, Character, Collections and Macro become systems with
   `blizzard` / `phoenix` (skin) designs.
5. Skin manifests + `/pui skincheck`; same-as-the-game skins in the §8 order, each retiring its replacement window.
6. `Movers.Window` (move any panel).
Each step: harness tests, guard, push, install and in-game screenshots for review.

## Already done (t146 quick fixes and t147 font, before approval)

- (a) Nav rail, tabs and icon tiles: the selected `accent.soft` was forced to alpha 1 and became a solid
  orange block over the orange icon. Now a 10% tint; a lint test blocks forced alpha on soft tokens.
- (c) The orange "staircase" on the Buffs, Cooldown Manager and Action Bars previews was the preview resize
  grip's glyph drawn at the atlas sheet's full size (the texture had one anchor and no size). Fixed in the grip
  and in `Icons:Apply`, which now sizes single-anchor glyphs; test added.
- (e) Game Menu: Blizzard's ThreeSlice buttons name the middle piece `Center`; we hid `Middle`, so the red
  128-RedButton centre showed. All three pieces are hidden now; test added.
- (d) Character window: a player model between the slot columns, readable empty slots (filled slot plus
  outline art), no icon left over from another tab on stat rows, and wider tabs (no "Reputati…").
- Font: Inter for every role (it replaces the Roboto / Roboto Condensed mix), Inter Bold for combat text,
  Inter as the Cyrillic fallback, and Blizzard font objects in Inter by default (extended to the faces the
  skinned windows use).
