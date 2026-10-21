# Phoenix_UI 2.0 — Architecture

Target: **WoW Retail 12.1.5 (Midnight), `## Interface: 120105`, build 12.1.5.70448.** Retail only. No Classic code paths.
This describes the code as it is. If code and this document disagree, fix one of them in the same change.

---

## 1. Headline decisions

1. **One addon, one namespace, zero globals.** Everything hangs off the private addon table `local ADDON, ns = ...`.
   The only globals are the SavedVariables, the `SLASH_*` strings created by Blizzard's `RegisterNewSlashCommand`, and
   `GetMinimapShape` (defined by the Minimap module in square mode; minimap-button libraries read it).
2. **No Ace3 / no embedded third-party addons.** Kept libraries: `LibStub`, `CallbackHandler-1.0`, `LibSharedMedia-3.0` (12000005, interop), `LibEditMode` (current, our own movable frames). Everything else is replaced by our small core or by Blizzard APIs (`C_EncodingUtil`, `MenuUtil`, `C_Timer`, `hooksecurefunc`, `Settings`).
3. **Blizzard owns layout, we own looks.** Blizzard frames are positioned/sized by **Edit Mode**. Phoenix modules *skin* and *augment* Blizzard frames (textures, fonts, colours, extra text). We do not move or replace protected frames. Our *own* frames (data bar, spell history) are registered with Edit Mode via LibEditMode.
4. **Display-only combat UI.** Under Midnight secret values we never do maths/comparisons on combat data. We hand possible secrets straight to display sinks (`FontString:SetFormattedText`, `Texture:SetTexture`, `UnitHealthPercent` with `CurveConstants.ScaleTo100`) and never test them.
5. **Declarative options.** Each module declares an options schema once (`Options.lua`). The same schema drives its config page and the search index. Defaults live on the module.
6. **One theme.** Every pixel goes through `ns.Theme` tokens and `ns.Skin` primitives. No module hard-codes a colour, font path or border.
7. **One SavedVariables owner (`ns.DB`)** with profiles, a schema version, and ordered migrations, including a one-shot import of the legacy `Phoenix_UIDB`.

---

## 2. Folder layout


```
Phoenix_UI/
├─ Phoenix_UI.toc               -- only file list; order = Libs → Locales → Core → UI → Modules → Core/Init.lua
├─ Libs/
│  ├─ Libs.xml
│  ├─ LibStub/  CallbackHandler-1.0/  LibSharedMedia-3.0/  LibEditMode/
├─ Locales/
│  ├─ Locales.xml  Locales.lua (fallback table, ns.RegisterLocale)  enUS.lua
├─ Core/
│  ├─ Core.xml
│  ├─ Namespace.lua     -- ns tables, version, constants, ns:Print / ns:Debug, SafeCall
│  ├─ Util.lua          -- pure helpers (tables, strings, colour maths on *non-secret* data)
│  ├─ Events.lua        -- ns.Events: game-event dispatcher + internal message bus (combat-log guard)
│  ├─ Secret.lua        -- ns.Secret.IsSecret: the one secret-value gate
│  ├─ Combat.lua        -- ns.Combat: lockdown queue (run after combat), CVar option accessors
│  ├─ Media.lua         -- fonts/bar/surface texture registry (+ LSM registration)
│  ├─ IconData.lua      -- GENERATED icon manifest (names → atlas cell, tier geometry)
│  ├─ Icons.lua         -- ns.Icons: named icons, tint/states, tier pick by physical px, markup, brand art
│  ├─ Theme.lua         -- design tokens, presets, font roles
│  ├─ Skin.lua          -- skin primitives (panel, border, shadow, text, statusbar, icon, hide/restore)
│  ├─ DB.lua            -- ns.DB: SavedVariables, profiles, defaults merge/strip, change notifications
│  ├─ Migrations.lua    -- ordered schema migrations + legacy Phoenix_UIDB importer
│  ├─ Modules.lua       -- ns:NewModule, lifecycle, enable/disable
│  ├─ EditMode.lua      -- LibEditMode wrapper for Phoenix-owned frames
│  ├─ Profiles.lua      -- export/import strings (C_EncodingUtil CBOR + deflate + base64)
│  └─ Init.lua          -- boot sequence + slash commands (loaded last, from the TOC)
├─ UI/
│  ├─ UI.xml
│  ├─ Anim.lua
│  ├─ Widgets/          -- Core, Button, Toggle, Slider, Dropdown, ColorSwatch, Input, Scroll, Section, Popup
│  └─ Config/           -- Window, Renderer (schema → widgets), Search, Home, Profiles, About, Blizzard (landing + compartment)
├─ Modules/
│  ├─ Modules.xml       -- lists every module file directly (no per-module XML)
│  └─ <ModuleName>/
│     ├─ <ModuleName>.lua   -- module object, defaults, lifecycle
│     └─ Options.lua        -- options schema (no UI code)
├─ Media/ Fonts/ Textures/ (surfaces, Emblem64/128/256, Logo512/1024)  Icons/ (Icons24/48/96 atlases + LICENSE)
├─ tools/ check_api.py  check_locales.py  smoke/harness.lua  audit/ (reference generators)  media/
├─ .luacheck/ wow_std_12.1.5.lua  reference_12.1.5.json  deprecated_12.1.5.json
├─ docs/  AUDIT.md  ARCHITECTURE.md  PROMPTS.md  audit/  screenshots/
├─ .github/workflows/luacheck.yml   .pkgmeta   AGENTS.md   .cursor/rules/*.mdc   .luacheckrc
```

File and include names are **case-exact** (the audit found 52 Windows-only includes).

### 2.1 Modules

| Module (key) | Replaces legacy | What it does |
|---|---|---|
| `General` | Init theme/fonts | Theme preset and accent, fonts, bar texture, reduce motion (locked on) |
| `Skins` | Skins/* | Game menu, popups and ready check, applied lazily |
| `ActionBars` | ActionBars | Square button art, hotkey/macro text, out-of-range tint |
| `UnitFrames` | UnitFrames | Bar texture, class and power colors, fonts on player/target/focus/pet |
| `GroupFrames` | RaidFrames | Texture and fonts on party/raid `CompactUnitFrame`s |
| `CastBars` | CastBars | Restyle player/target/focus bars; player-only icon, timer and latency zone |
| `Auras` | Buffs | Cropped icons and themed timers on BuffFrame/DebuffFrame |
| `NamePlates` | NamePlates | Bar texture and secret-safe health percent |
| `Tooltip` | Tooltip, idTip | Skin, cursor anchor, class/quality borders, target/role/ID lines |
| `Chat` | Chat | Clickable URLs with a copy popup, copy-chat window |
| `Minimap` | Maps | Square mask, zone text, coordinates |
| `DataTexts` | General/_Stats | Edit Mode movable bar: FPS, latency, speed, durability, gold, clock |
| `ItemLevel` | _Itemlevel, _BagIlvl | Item level on the character sheet and bags |
| `Automation` | General automation | Repair, sell junk, invites, duels, resurrections, BG release, DELETE fill, cinematics |
| `AFK` | _AfkCam | AFK screen |
| `MythicPlus` | Mythic+ | Auto-insert keystone, new-key report |
| `PvP` | Misc PvP | Safe queue, TAB targets players, `/gg` |
| `CooldownText` | CooldownTracker CooldownText | Phoenix font and color on Blizzard countdown numbers |
| `SpellHistory` | CooldownTracker SpellTracker | Player-only recent casts strip |
| `CombatText` | MSBT | Blizzard floating combat text settings in one page |
| `DamageMeter` | Detail-Skin | Skin for `Blizzard_DamageMeter`, optional one-click Details! style |
| `Quality` | Talkhead, Errors | Talking head, error filter, achievement screenshots, Cooldown Manager toggle |

---

## 3. Core and event bus

```lua
-- Core/Namespace.lua
local ADDON, ns = ...
ns.name, ns.version = ADDON, C_AddOns.GetAddOnMetadata(ADDON, "Version")
ns.L = ns.L or {}          -- filled by Locales
```

`ns.Events` (Core/Events.lua) owns one hidden frame for game events, one frame per owner and unit pair for unit events, and a registry for internal messages:

```lua
ns.Events:On("PLAYER_ENTERING_WORLD", owner, handler)       -- game event, handler(owner, event, ...)
ns.Events:OnUnit("UNIT_HEALTH", owner, handler, "player")   -- RegisterUnitEvent under the hood
ns.Events:Off("PLAYER_ENTERING_WORLD", owner)
ns.Events:OffAll(owner)                                     -- used by Module:Disable()
ns.Events:Fire("PUI_PROFILE_CHANGED", profileKey)           -- internal message (PUI_ prefix)
ns.Events:Listen("PUI_PROFILE_CHANGED", owner, handler)
```

Rules:
* The frame unregisters an event when its last handler leaves.
* `COMBAT_LOG_EVENT*` registrations raise an error (forbidden in 12.x).
* Handlers run through `ns.SafeCall` (`xpcall` with `geterrorhandler()`, so BugSack and BugGrabber see them). One broken handler never stops dispatch.
* Owners added while their event is being dispatched take effect after that dispatch.
* Internal messages: `PUI_PROFILE_CHANGED(name)`, `PUI_SETTING_CHANGED(moduleKey, path, value)`, `PUI_THEME_CHANGED`, `PUI_MODULE_STATE(moduleKey, state)`, `PUI_COMBAT_END`.

`ns.Secret.IsSecret` is `issecretvalue`; every secret check goes through it.
`ns.Combat:Run(key, fn, ...)` runs now if out of combat, else once at `PLAYER_REGEN_ENABLED`, de-duplicated by key. `ns.Combat.CVarAccessors` builds get/set pairs for CVar options whose writes wait for combat to end.

---

## 4. Module registration and enable/disable contract

```lua
local _, ns = ...
local M = ns:NewModule("Tooltip", {
    label    = "TOOLTIP",           -- locale key
    category = "interface",         -- sidebar group
    order    = 40,
    icon     = "tooltip",           -- ns.Icons name (defaults to the lower-cased module key)
    requires = { },                 -- module keys that must be enabled first
    defaults = { enabled = true, anchor = "CURSOR", showIDs = true, … },
    reloadOnToggle = false,         -- true only when disabling cannot be undone (e.g. secure hooks)
    loadWhen = nil,                 -- optional fn() -> bool (e.g. addon loaded, class)
})

function M:OnInitialize() end      -- once, after DB ready. No frames shown, no events.
function M:OnEnable() end          -- create/attach, register events, apply settings
function M:OnDisable() end         -- revert visuals, OffAll events (core does OffAll automatically)
function M:OnSettingChanged(path, value) end  -- live update; default = self:Refresh()
function M:Refresh() end           -- re-apply whole module from self.db
function M:OnProfileChanged() end  -- default = Disable/Enable or Refresh
```

* `self.db` is the module's slice of the active profile; `self.global` the module's account-wide slice.
* The module manager enables modules in dependency/`order` order at `PLAYER_LOGIN`, each inside `xpcall`. A failing module is marked `errored`, shown in the config window with its error, and the others continue.
* Runtime toggle: `ns:SetModuleEnabled(key, bool)`. If `reloadOnToggle` is set, the window shows a "Reload required" badge and offers `C_UI.Reload()`.
* Hooks: `hooksecurefunc` cannot be removed, so every hook body starts with `if not M:IsEnabled() then return end`. Every visual change keeps the original value so `OnDisable` can restore it (`ns.Skin:Restore(frame)`).
* Modules talk to each other only through `ns.Events` messages or a module's documented public API (`ns:GetModule("ItemLevel"):GetItemLevel(link)`); never through each other's locals.

---

## 5. SavedVariables, profiles, migrations

### 5.1 TOC
```
## SavedVariables: PhoenixUIDB, Phoenix_UIDB
## SavedVariablesPerCharacter: Phoenix_UIPerCharDB
```
`Phoenix_UIDB` / `Phoenix_UIPerCharDB` are the **legacy** tables, listed only so they can be read once and then set to `nil` (dropping them from disk). After a grace release they are removed from the TOC.

### 5.2 Shape
```lua
PhoenixUIDB = {
  schema   = 1,                      -- bumped by migrations
  global   = { modules = { <key> = {…} }, ui = { windowPos, lastPage, … } },
  profiles = { ["Default"] = { modules = { <key> = { enabled = true, … } }, theme = {…} } },
  profileKeys = { ["Name - Realm"] = "Default" },
  specProfiles = { ["Name - Realm"] = { enabled = true, [specIndex] = "Healer" } },
}
```
* **Defaults are not stored.** `ns.DB` applies the module `defaults` via metatables. Only diffs are written, which keeps SavedVariables small and makes default changes ship to users.
* **Never store secret values** (they are saved as `nil`). `ns.DB:Set` asserts `not issecretvalue(v)`.
* Profile ops: `NewProfile` (optionally copying), `RenameProfile`, `DeleteProfile`, `ResetProfile`, `SetProfile`, and a per-specialization auto switch.

### 5.3 Import/export
`ns.Profiles:Export()` → `"!PUI1!" .. EncodeBase64(CompressString(SerializeCBOR(payload)))`, all through `C_EncodingUtil`.
The payload is `{ v, schema, addon, name, profile }`. Import checks the prefix and schema, lists the modules it contains, keeps only known modules, and saves under a free name (`Name (2)` when taken). There is no comms-based sharing (comms are blocked during lockdown).

### 5.4 Migrations
`Core/Migrations.lua` holds an ordered list `{ version = n, run = function(db) … end }`. On `ADDON_LOADED` the core runs every migration with `version > db.schema` inside `xpcall`.

**Legacy importer (migration 1):** if `Phoenix_UIDB` exists, map the known keys (see the table below), copy the profile names, then `Phoenix_UIDB = nil`. Unknown keys are dropped; chat reports how many settings were imported.

| Legacy (Phoenix_UIDB.profiles[*]) | New |
|---|---|
| `general.theme`, theme colour keys | `theme.preset`, `theme.accent` |
| `actionbars.*` (hotkeys, macros, range, flash) | `modules.ActionBars.*` |
| `unitframes.*`, `castbars.*`, `nameplates.*` (cosmetic keys only) | matching modules |
| `tooltip.*` + `idtip.*` | `modules.Tooltip.*` |
| `chat.*` (style, urls, emoji, history) | `modules.Chat.*` |
| `maps.minimap.*` | `modules.Minimap.*` |
| `general.autorepair/autosell/…` | `modules.Automation.*` |
| `mythicplus.*` (timer/objectives) | `modules.MythicPlus.*` |
| MSBT / CooldownTracker PartyCD / MoveAny / PGF / BuffOverlay blobs | **not migrated** (features removed) |

---

## 6. Localization

* `Locales/enUS.lua` defines the base table: `ns.L = setmetatable({ KEY = "English text", … }, { __index = function(t, k) return k end })`.
* Other locale files return early unless `GetLocale()` matches, and only override keys.
* Code uses **keys**, never inline English: `L.TOOLTIP_SHOW_IDS`. Option schema `label`/`desc` fields are locale keys.
* Fonts must support the client locale. `ns.Theme:Font(role)` falls back to Blizzard `STANDARD_TEXT_FONT` / `UNIT_NAME_FONT` on koKR/zhCN/zhTW (the bundled Latin fonts lack CJK glyphs). Roboto and Inter cover Cyrillic (ruRU); Cinzel is only used for the Latin "PHOENIX" wordmark.

---

## 7. Theme system (one, shared)

`ns.Theme` holds **tokens**. `ns.Skin` turns tokens into visuals. Modules only call `ns.Skin` and `ns.Theme:Color("token")`.

```lua
ns.Theme:Color("bg.base")        -- returns r,g,b,a
ns.Theme:Font("body")            -- returns path, size, flags (locale-aware)
ns.Skin:Panel(frame, "raised")   -- background + 1px border + optional accent edge
ns.Skin:Button(btn, "primary")
ns.Skin:StatusBar(bar, "health") -- texture + background + border; never reads values
ns.Skin:Icon(tex)                -- crop 0.08–0.92 + border
ns.Skin:Text(fs, "label")        -- font + colour + shadow
ns.Skin:Restore(frame)           -- undo (module disable)
```

Presets change the accent family over one shared dark surface palette: **Phoenix Ember** (default), **Frost**, **Fel**, **Arcane**, **Class** (`C_ClassColor.GetClassColor`) and **Custom** (`theme.custom = { r, g, b }`). Changing a preset fires `PUI_THEME_CHANGED`, and every skinned object re-applies from tokens (registry of weak-keyed skinned objects).

---

## 8. Blizzard Settings registration

* `Settings.RegisterCanvasLayoutCategory(landingFrame, "Phoenix UI")` + `Settings.RegisterAddOnCategory(category)` (UI/Config/Blizzard.lua). The landing canvas is themed: logo, short text and an **Open Phoenix UI** button.
* `/pui settings` → `Settings.OpenToCategory(category:GetID())`.
* Addon Compartment: `AddonCompartmentFrame:RegisterAddon({ text, icon, notCheckable, func, funcOnEnter, funcOnLeave })` with a themed tooltip. There is no `## AddonCompartmentFunc` global.
* Slash (Core/Init.lua): `RegisterNewSlashCommand(handler, "pui", "phoenix")`. Sub-commands: none/`config`, `settings`, `edit`, `profile [name]`, `reset`, `debug`, `<module key>`.
* Opening the config window in combat is allowed (it is not protected). Any setting that touches protected state queues through `ns.Combat:Run` and shows an "out of combat" badge.

---

## 9. Standalone config window

Movable and resizable (860×540 to 1600×1100, default 1000×660). Built on first open, closes with Esc
(`UISpecialFrames`, frame `PhoenixUI_Config`), position and size saved in `global.ui` (`/pui reset` clears them).
Header 56, sidebar 216, footer 28. See `docs/screenshots` for the rendered layout.

* **Sidebar:** Home, then modules grouped System / Interface / Combat / Social / Utility, then Profiles and About.
  Rows show the module icon and state (enabled, errored, reload pending).
* **Search:** indexes every schema entry (`label`, `desc`, `keywords`, module name). Picking a result opens the
  page, scrolls to the row and flashes it.
* **Live updates:** controls write through `ns.DB:Set(module, path, value)`, which calls
  `module:OnSettingChanged()` and fires `PUI_SETTING_CHANGED`.
* **Schema → widgets** (`UI/Config/Renderer.lua`): `header`, `description`, `toggle`, `range`, `select`, `font`,
  `texture`, `color`, `input`, `button`, `custom` (`build(row, module)`). Per entry: `key` or `get`/`set`, `desc`,
  `keywords`, `disabled = fn(m)`, `hidden = fn(m)`, `reload` (Reload badge) and `combat` (applies after combat).
* **Layout:** page padding 24, card gap 16, card header 40, rows 36 (52 with a description), controls 28 high.

## 10. Edit Mode support

* Our movable frames register through `ns.EditMode:Register(frame, { name = L.X, default = { point = "CENTER", x = 0, y = 0 }, settings = { … } })`. This wraps **LibEditMode** (`AddFrame`, `AddFrameSettings`, layout callbacks). Positions are stored **per Edit Mode layout** in `global.layouts[layoutName][frameKey]`, so they follow the user's Blizzard layout switches.
* Blizzard frames: we never call `SetPoint` on frames managed by `EditModeManagerFrame`. Size and position settings for Blizzard systems are left to Edit Mode. Our config page links to it with an "Open Edit Mode" button (`ShowUIPanel(EditModeManagerFrame)` out of combat).
* LibEditMode's `layout` callback re-applies our positions when the user switches layouts.

---

## 11. Visual design language — "Phoenix Ember"

### 11.1 Palette (tokens)

| Token | Hex | Use |
|---|---|---|
| `bg.base` | `#0E0F13` α 0.94 | window/panel background |
| `bg.raised` | `#16181E` α 0.96 | cards, sections, sidebar |
| `bg.sunken` | `#0A0B0E` α 0.90 | inputs, slider tracks, status-bar backgrounds |
| `bg.hover` | `#1F222A` | row/button hover |
| `border.subtle` | `#262A33` | 1-px separators, idle borders |
| `border.strong` | `#3A3F4B` | focused input border |
| `accent.primary` | `#FF6A1A` | ember orange: active nav, toggles on, sliders, focus ring |
| `accent.secondary` | `#FFB23F` | flame gold: gradient end, highlights |
| `accent.glow` | `#FF3D00` α 0.35 | glow/pulse overlays |
| `text.primary` | `#ECEEF2` | main text |
| `text.secondary` | `#A3A9B6` | descriptions, labels |
| `text.muted` | `#6B7180` | hints, disabled |
| `state.success` | `#3DDC97` | enabled dots, success toasts |
| `state.warning` | `#FFC24B` | reload/after-combat badges |
| `state.danger` | `#FF4D5E` | errors, destructive buttons |
| `state.info` | `#4DA3FF` | info badges |

Combat colours (class, power, reaction) are not re-invented; they come from Blizzard (`C_ClassColor`, `PowerBarColor`, read only).

### 11.2 Typography (bundled fonts, curated)

Roles live in `Theme.fontRoles`; users can override the interface font (body/desc) and the unit font (unit/combat) and scale every UI role.

| Role | Font file (Media/Fonts) | Size | Flags |
|---|---|---:|---|
| `brand` (logo/wordmark) | `Cinzel-Bold.ttf` | 20 | — |
| `title` (page titles) | `InterBold.ttf` | 17 | — |
| `heading` (section headers, uppercase) | `Roboto_Condensed-Bold.ttf` | 11 | — |
| `body` (labels, controls) | `Roboto-Medium.ttf` | 12 | — |
| `desc` (descriptions) | `Roboto-Regular.ttf` | 11 | — |
| `number` (values, timers) | `Roboto_Condensed-SemiBold.ttf` | 12 | — |
| `small` (badges, footer) | `Roboto_Condensed-Medium.ttf` | 10 | — |
| `unit` (in-world frames, nameplates, bars) | `Roboto_Condensed-SemiBold.ttf` | per element | shadow 1,-1 or `OUTLINE` |
| `combat` (big timers, CDs) | `Roboto_Condensed-Bold.ttf` | per element | `OUTLINE` |

Shipped font set (9 files, all SIL OFL 1.1): Cinzel-Bold, InterBold, Roboto-{Regular,Medium,Bold}, Roboto_Condensed-{Regular,Medium,SemiBold,Bold}. Expressway, PT Sans Narrow, AvantGarde and the other legacy fonts were dropped (licence unclear or unused). koKR/zhCN/zhTW clients fall back to `STANDARD_TEXT_FONT`. All shipped fonts and bars are registered with LSM under `Phoenix *` names.

### 11.3 Spacing, sizing, borders
* **4 px grid** for every offset and size in the config UI (see §9 for the main measurements).
* **Borders:** 1 physical pixel (`PixelUtil`), `border.subtle` by default. Cards have a faint top sheen. The active
  nav row gets a 2 px accent bar.
* **Icons:** game icons are cropped 8 % with a 1 px black border; UI glyphs come from `ns.Icons` (§14).
* **Status bars:** the bar texture chosen in General (any LSM texture), `bg.sunken` background, 1 px border.
* No rounded corners.

### 11.4 Motion
* `ns.Anim` tweens on one shared OnUpdate that only runs while a tween is active.
* Page switch and popups: 100–140 ms fade in. Toggle knob: 100 ms. Scroll: 120 ms. Search hit: 900 ms row flash.
* Reduce motion (General) skips every tween. Nothing animates on in-world frames.

---

## 12. Cross-cutting rules (summary; details in `.cursor/rules`)

* **Taint:** never assign to Blizzard globals or fields on Blizzard tables/frames, never replace Blizzard functions, only `hooksecurefunc`/`HookScript`. Protected operations go through `ns.Combat`.
* **Secrets:** treat combat-related API returns as possibly secret. Use the display sinks. Test with `ns.Secret.IsSecret` before any comparison.
* **Performance:** event-driven. OnUpdate only while something is animating or visible and time-dependent, and throttled (the cast timer runs at 20 Hz). No allocation or `SetFont` in per-event paths such as `UNIT_HEALTH`; style once, then update values. No `collectgarbage`. Create frames lazily.
* **Lint:** `luacheck .` must be clean with the generated 12.1.5 std (`.luacheckrc`).

---

## 13. Scope notes

* **No `Core/Settings.lua`.** Boot and slash live in `Core/Init.lua` (loaded last from the TOC so every module is registered); the Blizzard landing page and compartment entry live with the rest of the config UI in `UI/Config/Blizzard.lua`.
* **No per-module XML.** `Modules/Modules.xml` lists `<Module>.lua` + `Options.lua` for every module; one place to read the load order.
* **No empty locale stubs.** Only `enUS.lua` ships; `ns.RegisterLocale` accepts other locales when translations exist. `tools/check_locales.py` keeps enUS complete and free of unused keys.
* **Positions:** Phoenix never moves Blizzard frames. Only Phoenix-owned frames (data bar, spell history) register with LibEditMode; their positions are stored per Edit Mode layout.
* **Removed with no replacement in Phoenix:** chat history/emoji, arena dampening display, minimap size slider, M+ timer/objectives (Blizzard's tracker covers it), mouseover bar fading. Combat-log features are replaced by Blizzard options exposed as toggles (Cooldown Manager, floating combat text v2, damage meter, countdown numbers).
* **Details!:** optional, never a dependency. The Damage Meter page offers a one-click "Style Details!" button that calls Details' public instance API inside `pcall`; it is never applied automatically because it rewrites Details' own saved settings.
* **Icons (§14):** one Phosphor duotone set via `ns.Icons`; brand art via `ns.Icons:Brand`.
* **Checks:** `luacheck .` (generated 12.1.5 std), `tools/check_api.py` (methods/events/CVars/templates/atlases vs. the 12.1.5 reference, forbidden patterns, TOC/XML completeness and case), `tools/check_locales.py`, and `tools/smoke/harness.lua` (offline load + boot + every settings page). All run in `.github/workflows/luacheck.yml`.

## 14. Icon system

* **Source:** [Phosphor Icons](https://phosphoricons.com) 2.1.1, duotone weight only (MIT, `Media/Icons/LICENSE`). The SVGs
  live in `tools/media/phosphor/`; `tools/media/icon_map.py` maps Phoenix names (`home`, `cat-combat`, `delete`, `fps` …)
  to glyphs. The list is append-only so atlas cells stay stable. Micro-controls (`close`, `check`, `add`, chevrons,
  `resize`) render the line layer only; the duotone fill is 30 % opacity.
* **Build:** `python3 tools/media/gen_icons.py` rasterizes white glyphs with cairosvg into three atlases (RLE TGA,
  power of two, clean alpha): `Icons24` (24 px cells, 256²), `Icons48` (48 px, 512²), `Icons96` (96 px, 1024²),
  each cell with a transparent gutter so bilinear sampling never bleeds. It also writes `Core/IconData.lua`, the
  emblem (`Emblem64/128/256`) and logo (`Logo512/1024`), and the PNGs used by the doc mockups.
* **Why tiers:** WoW does not mipmap addon TGAs. `ns.Icons` converts the on-screen size to physical pixels
  (`size × effectiveScale ÷ PixelUtil.GetPixelToUIUnitFactor()`) and picks the smallest tier that covers it, so
  downsampling never exceeds ~2×. A 16-unit icon uses 24 px cells at 1080p and 48 px cells at 4K/1.15; page
  headers use 96 px cells. Tiers are re-picked on `UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED` and when a frame's
  own scale changes (data bar).
* **API:** `Icons:Create(parent, name, size, token, layer)`, `Apply`, `Tint(tex, token, alpha)`,
  `SetState(tex, "hover"|"active"|"danger"|"disabled")`, `Markup(name, size, token)` for FontStrings,
  `Brand(tex, "emblem"|"logo", width)` and `Has`. `W.Icon` and `W.Color` route through it, so icons repaint
  with the theme. Unknown names show the `question` glyph and are recorded in `Icons.missing`.
* **Checks:** `tools/check_api.py` rejects unknown literal icon names, unused glyphs, missing atlas/brand files,
  dead files under `Media/` and unused `Media.textures` keys. The smoke harness fails on any unknown icon request
  and asserts the 48/96 px tier choice at 4K.
