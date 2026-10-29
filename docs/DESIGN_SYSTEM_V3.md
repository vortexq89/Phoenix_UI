# Phoenix UI — Design System v3 (draft for owner approval)

Status: **proposal, revision 4 (t150)**. Nothing in this document is built yet, except the t146/t147 fixes listed at the end.

**Revision 4 (owner, t150):** Expressway as the default font, by reference only, with Barlow Semi Condensed as the
fallback (§3a), and an own OFL family, Phoenix Font, proposed as that fallback (§3b); the settings GUI redesigned as v4 "Flow" (§11), with three concepts compared.

**Revision 3 (owner, t149):** full-colour ember chrome icons with hover glow and a pressed light burst (§5a);
a Phoenix panel icon in the top-left corner of every window (§5b); the UI font becomes Barlow Semi Condensed, the
closest licence-safe match to the Expressway look of ElvUI and EllesmereUI (§3). Mockups below are redrawn with both.

**Revision 2 direction (owner, t148):** every Blizzard window keeps **the game's own layout and structure** and is
restyled in the Phoenix theme, with our extra features and settings added, the way ElvUI and EllesmereUI skin
(no custom re-layouts of Blizzard windows). Phoenix's own icon set appears **only on UI chrome**: micro menu,
macro window controls, settings GUI tabs and navigation, and window controls. Class, spec, ability, spell, item,
mount, pet and toy icons are never replaced (the window portrait slot now holds the panel icon, §5b).
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

**Revision 3 (t149): one family for all Phoenix text, Barlow Semi Condensed** (SIL OFL 1.1, Regular / Medium /
SemiBold / Bold; licence ships beside the files). It replaces Inter, which the owner found pixelated in game. Only
the brand wordmark stays Cinzel. ruRU uses **PT Sans Narrow** (OFL, full Cyrillic), because Barlow has none. CJK
clients keep the game font.

**What ElvUI and EllesmereUI actually ship** (read-only, EllesmereUI from `Interface/AddOns/EllesmereUI/media/fonts`
on the PC and ElvUI from its public repo, `ElvUI/Game/Shared/Media/Fonts`):

| font | who uses it | licence (font `name` table) | can Phoenix ship it? |
|---|---|---|---|
| Expressway (Typodermic) | EllesmereUI default; ElvUI unit frames | "(c) 2005 Typodermic. **Do not distribute.**" | **no** |
| PT Sans Narrow Bold | ElvUI general font (`font = 'PT Sans Narrow'`, 12, OUTLINE) | SIL OFL 1.1 | yes |
| Fira Sans Medium / Bold / Light | EllesmereUI option | SIL OFL 1.1 | yes |
| Poppins, Ubuntu, Exo, Changa, Russo One, Barlow Condensed | EllesmereUI options | OFL / Ubuntu Font Licence | yes |
| Gotham Narrow, Avant Garde, Arial Bold / Narrow, Future X | EllesmereUI options | commercial (Hoefler, ITC, Monotype) | no |
| Homespun, ActionMan, ContinuumMedium, DieDieDie | ElvUI pixel and display faces | freeware, mixed terms | not as a default |

EllesmereUI's own addon licence is "all rights reserved", so nothing is copied from it; only the font files'
own licences matter.

**Why Inter looked pixelated:** WoW rasterises with FreeType grayscale at the true pixel size. Inter's thin,
wide strokes land between pixels at 10–13 px, so the stems fade and break under OUTLINE. The smooth look of
ElvUI and EllesmereUI comes from **Expressway**: a condensed DIN-style face with sturdy, even stems and a tall
x-height that hold one or two full pixels. The closest OFL equivalent is **Barlow Semi Condensed**, a DIN-style
family of the same width, with sturdy stems, a large x-height and open counters. In the comparison
(`docs/screenshots/v3/font_compare_t149.png`: native 10 / 12 / 14 / 16 px, no outline, OUTLINE and shadow, plus 12 px
at 3x) it matches Expressway's weight and smoothness best. PT Sans Narrow is a close second but narrower and
smaller at 10 px. Fira Sans is wider and rounder. Inter is the thinnest of the set.

Roles (`Core/Theme.lua` `fontRoles`, 1:1 pixels at pixel-perfect scale). No role goes below 12. Barlow runs
about 8% smaller than Inter at the same size, so each role is one step larger:

| role      | face                     | size | flags   | use                                   |
|-----------|--------------------------|------|---------|---------------------------------------|
| `title`   | Barlow SC Bold           | 21   |         | page / window title                   |
| `heading` | Barlow SC Bold           | 14   |         | card headers (uppercase)              |
| `body`    | Barlow SC Medium         | 15   |         | labels, row text                      |
| `desc`    | Barlow SC Regular        | 13   |         | descriptions, hints                   |
| `number`  | Barlow SC SemiBold       | 14   |         | values, timers                        |
| `small`   | Barlow SC Medium         | 13   |         | badges, captions, chips               |
| `unit`    | Barlow SC SemiBold       | 13   | OUTLINE | unit frame names and health text      |
| `combat`  | Barlow SC Bold           | 18   | OUTLINE | in-world numbers; combat text 22      |

Skins: Blizzard's font objects (GameFont*, SystemFont*, tooltip, quest and GameNN) take the same faces at their
own sizes and outlines (General › Text › "Use theme fonts on Blizzard UI", on by default). The user's own UI
and unit font choices still override the roles. Applying this in game is step 0 of §13 (after approval); the
build still ships Inter until then.

### 3a. Default font: Expressway by reference, Barlow Semi Condensed otherwise (t150)

The owner prefers **Expressway**. Its licence ("Do not distribute") means Phoenix never ships, copies or embeds the
file. Phoenix only **points at a copy the user already has** through another installed addon. If no copy is found,
the default is Barlow Semi Condensed, which Phoenix ships.

Resolution (`Core/Media.lua`, `ResolveDefaultFont()`), run at `PLAYER_LOGIN` and again on LibSharedMedia's
`LibSharedMedia_Registered` callback for the font type:

1. **LibSharedMedia:** `LSM:IsValid("font", "Expressway")`, then `LSM:Fetch("font", "Expressway")`. This covers any
   addon that registers it (EllesmereUI registers "Expressway", "Expressway Bold" and "Expressway CAPS").
2. **Known paths**, tried only if their addon is installed (`C_AddOns.GetAddOnInfo` / `C_AddOns.IsAddOnLoaded`):
   - `Interface\AddOns\EllesmereUI\media\fonts\Expressway.TTF` (Bold: `Expressway Bold.ttf`)
   - `Interface\AddOns\ElvUI\Game\Shared\Media\Fonts\Expressway.ttf` (current ElvUI layout)
   - `Interface\AddOns\ElvUI\Media\Fonts\Expressway.ttf` (older ElvUI layout)
3. **Probe:** each candidate is checked on a hidden FontString with `fs:SetFont(path, 12, "")`. It is accepted only
   when that returns true and `fs:GetFont()` gives the path back. Nothing is read or copied.
4. **Fallback:** if no candidate passes, Barlow Semi Condensed (`Media/Fonts/BarlowSemiCondensed-*.ttf`), with
   PT Sans Narrow for ruRU. CJK clients always keep the game font.

Rules:
- **Weights:** if only the regular Expressway is found, it is used for every role. Bold roles take
  `Expressway Bold` when it exists; otherwise they use the regular file. WoW cannot synthesise bold, so the role
  sizes from §3 apply unchanged.
- **Saving:** the profile stores the choice as a key, "Default (Expressway if installed)", not a file path. If the
  other addon is removed, Phoenix falls back to Barlow at the next login with no error and no missing-font boxes.
  The fallback is also checked once on `ADDON_LOADED` so a late loader can still switch it live.
- **Settings:** General › Text shows the resolved font and where it came from, for example "Expressway (from
  EllesmereUI)" or "Barlow Semi Condensed (Expressway not found)". The user can pin either one, or any LSM font.
- **Media picker:** an Expressway found this way is listed with an "external" badge. Phoenix never registers it
  with LSM itself, so it is never re-published.
- **Licence note** in `CREDITS.md`: Phoenix does not include Expressway. It only uses a copy supplied by another
  installed addon.
- **Harness test:** stub LSM with and without "Expressway" and stub `SetFont` to fail, then assert each fallback step.

### 3b. Phoenix Font (t154, awaiting approval)

**Phoenix Font** is Phoenix's own OFL family, tuned to look as close to Expressway as an OFL derivative can. It is
a Modified Version of **Barlow Semi Condensed** (© 2017 The Barlow Project Authors, OFL 1.1). Barlow declares no
Reserved Font Name; the family is renamed anyway, as the OFL expects of Modified Versions.

- **Files:** source `tools/media/phoenix_font/build.py`, output `tools/media/phoenix_font/build/PhoenixFont-{Regular,
  SemiBold,Bold}.ttf`, `OFL.txt` with the Barlow credit.
- **Method:** only fontTools geometric transforms of Barlow's own outlines.
- **Expressway's role:** a visual reference only. It is rendered from the owner's local EllesmereUI copy, on the
  owner's PC, and its rendered x-height and string widths are the targets. None of its outlines are opened, copied,
  traced or committed.

| tuning | Barlow SC | Phoenix Font | reference (rendered) |
|---|---|---|---|
| weight (Regular) | Medium | from Barlow SC **Bold** (SemiBold ← ExtraBold, Bold ← Black) | heavy at small sizes |
| x-height / cap height | 0.73 | **0.77** (x-height zone raised 6.5%, ascenders shifted, stems kept straight) | 0.78 |
| lowercase a–z width @100 px | 1150 | **1209** (x1.004) | 1210 |
| uppercase A–Z width @100 px | 1371 | **1501** (x1.067) | 1502 |
| digits 0–9 width @100 px | 457 | **539** (x1.126) | 539 |
| curves | round | off-curve points pushed 3% outward (squarer bowls) | squarish |
| spacing | | +4 units tracking per glyph on 1000 UPM | |
| hinting | TrueType | instructions removed; FreeType autohints, as WoW does | |

- **Comparison:** `renders/t150/font/font_compare_t154.png` shows Phoenix Font, Expressway and Barlow at
  10/11/12/14/16 px, with no outline, OUTLINE and shadow.
- **Still open:** Expressway pairs letters slightly tighter and uses a wider word space. If the owner wants it
  closer, the next pass changes the space width and kerning.
- **Default chain once approved** (§3a): Expressway by reference if installed, then Phoenix Font, then
  PT Sans Narrow for ruRU. Until the owner approves, the in-game build is unchanged (Inter), and Barlow Semi
  Condensed stays the documented fallback.

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

## 5a. Chrome icon set (v4, full colour)

**Revision 3 (t149):** the icons are full colour, not flat outlines. Source: `tools/media/gen_chrome_color.py`,
which reuses the v3 24-grid geometry from `gen_chrome_icons.py`. Sheet: `docs/screenshots/v3/chrome_icons.png`.
256 px masters for every icon and state are exported to the project's `renders/icons_v4/` folder.

- **Body:** a solid glyph with a vertical ember gradient: pale gold `#FFECAA` → ember `#FFB040` → flame `#F0601C`
  → crimson `#961E12`. Strokes are full brightness; the enclosed areas are filled at 62% of that brightness, so
  every shape has volume.
- **Depth:** a dark ember rim (`#340A06`), a soft drop shadow down and to the right, and a light along the top of
  the strokes.
- **States** (the same art in every state, so it never flickers):
  - `normal`
  - `hover`: an ember outer glow and 112% brightness
  - `pressed`: a **light burst** of 16 rays and a bright gold core behind the glyph, 128% brightness, 94% scale,
    played as a 0.25 s flash on click
  - `active` (selected tab or rail item): the hover look held, with no backing block (fixes t146 a)
  - `disabled`: desaturated, at 60% opacity
- **Sizes:** rendered at 4x and downsampled. Shipped as 64 px atlas cells and drawn at 16–24 px. Panel icons are
  shipped at 128 px.

| group | icons | used on |
|---|---|---|
| Micro menu (13) | character, professions, spells, achievements, quests, housing, guild, group finder, collections, journal, help, shop, menu | the 13 micro buttons, in Blizzard's order |
| Settings nav & GUI tabs (17) | home, bars, frames, interface, combat, content, windows, systems, phoenix, profiles, look, support; tab: layout, appearance, text, behaviour, colours | settings rail, sub-nav, page tabs |
| Macro window (6) | general, character, new, delete, rename, save | the macro tabs and buttons (never the macros' own icons) |
| Window controls (9) | close, move, settings, search, filter, lock, reset, favourite, expand | title bars, search boxes, filter dropdowns, list markers |

Where a Blizzard chrome element has a glyph (sidebar tabs, filter dropdown, search magnifier, close X), the
Phoenix one replaces that glyph. Where the element shows game content (a mount icon, a macro's icon, a spell),
nothing changes.

## 5b. Panel icons (top-left corner of every window)

Each window shows a Phoenix **panel icon** in its top-left corner, in the round portrait slot of Blizzard's
`PortraitFrameTemplate` / `ButtonFrameTemplate`. Each one says what the window is for. The ember glyph sits on
an obsidian medallion with a gold rim and an inner ring (sheet `docs/screenshots/v3/panel_icons.png`, headers
mockup `docs/screenshots/v3/panels_v3.png`). There are 28: character, bags, mail, collections, macro, friends,
guild, group finder, settings, achievements, spellbook, talents, quests, map, calendar, professions, journal
(Adventure Guide), PvP, shop, help, game menu, bank, merchant, auction house, trade, loot and communities.
It is drawn at 60 px in the portrait slot (40 px in the Phoenix settings header) and lights up on hover like
the chrome icons. The player's portrait is still shown on unit frames. On the Character window it moves to a
small inset, an option under Windows › Character.

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

## 11. Settings window layout (v4, t150)

The owner's problem with v3: tabs, then sections, then cards left large empty areas, an empty second column and
squeezed labels. v4 removes the second column and packs every page. Three concepts were drawn on the **same real
page** (Action Bars › Bars, with its 109 real options from the harness dump), mockups in `renders/t150/`:

| concept | idea | strengths | weaknesses |
|---|---|---|---|
| **A "Flow"** (recommended) | one left rail grouped by category; the open module expands **inline** to its sub-pages (Bars · Buttons · Text · Extra bars); a header that stays put on scroll (module icon tile, breadcrumb, title and summary, Enabled switch, Move on screen, Reset page); scope chips (Bar 1–8, Pet, Stance) and a Live preview switch; a slim preview strip; **3-column packed** setting groups | no empty column; the Bars page shows 47 settings without scrolling (v3 showed about 14); every control sits right next to its label | the 3 columns need a window at least 1280 wide (it drops to 2 columns below that) |
| B "Inspector" | rail + one scroll column of 2-up groups + a fixed right panel: screen bar picker, live preview, at-a-glance summary and changed-from-default count | best for spatial modules (bars, frames); you always see what you're editing | the fixed panel takes 330 px on every page, which is wasted on text-only modules |
| C "Deck" | an icon-only rail; all of a module's sub-pages on one page as collapsible bands; collapsed bands show **summary chips** (for example "Bottom · x 0 · y 48") | the densest overview; good for experts | the icon-only rail is harder to learn, and a long single page means a lot of scrolling |

**Recommendation: A "Flow"**, with two ideas taken from the others: C's summary chips on collapsed groups, and
B's "changed from default" count in the header. The rules:

- **Window:** 1400 × 860 by default, resizable down to 1100 × 700. The group columns are 3 at 1280 px or wider,
  2 at 900 px or wider, otherwise 1.
- **Rail (236 px):** Phoenix header, search (Ctrl K, all 1,875 settings), Home, then categories (Interface, Combat,
  Social, Utility, System).
  - Each module row has its chrome icon, label, and a status dot: green on, grey off.
  - The open module shows its sub-pages indented under it. Categories that don't hold the open module collapse to
    one line listing their modules.
- **Sticky header:** module icon tile 52 px, breadcrumb, title (21 px Bold) and a one-line summary.
  - Right side: Enabled switch (the module on/off of §10 plugins), Move on screen (Movers), Reset page.
  - Second line: scope chips for multi-instance modules; shift-click edits several scopes at once.
  - Live preview switch, shown only where §6 allows a preview.
- **Preview strip:** at most 92 px tall, full width, and only on modules §6 marks with a preview (bars, frames,
  cast bars, combat text, auras). Never on text-only pages. It can be hidden; the switch is remembered.
- **Groups:** one card per section header in the module's schema, with:
  - an accent bar and an uppercase title with a count badge
  - a collapse chevron; collapsed cards show summary chips of the current values
  - rows 28 px tall with zebra striping; the label on the left and the control on the right, in fixed control
    widths (switch 30, slider 120 plus a 38 px value box, dropdown up to 150, input up to 170)
  - packed by a **masonry** layout: each card goes into the shortest column, so there are no gaps
  Long descriptions become tooltips, and a "reload needed" note becomes a small badge, never inline text that
  crushes the label (fixes t146 b).
- **Footer:** "Changes save and apply instantly", the profile name, undo (Ctrl Z).
- **Home:** a hero card (panel icon, greeting, modules-on count, profile, health) with quick actions (Move
  frames, Install wizard, Profiles, Report a bug). Below it, packed category cards list every module with its
  settings count and an on/off switch, plus Health checks and Recently changed cards.

Mockups:
- `settings_v4_A_flow_actionbars.png`
- `settings_v4_B_inspector.png`
- `settings_v4_C_deck.png`
- `settings_v4_A_unitframes.png` (Unit Frames › Frames, scopes Player … Arena)
- `settings_v4_A_home.png`

All are drawn by `tools/design/settings_v4.py` from the real option dump and committed under
`docs/screenshots/v4/`.

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

0. Font: Expressway by reference with the Barlow Semi Condensed fallback (§3a; + PT Sans Narrow for ruRU), with the roles in §3; colour chrome and panel
   icon atlases in `Media/Icons/` from `gen_chrome_color.py`; panel icons wired into the skins.

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
