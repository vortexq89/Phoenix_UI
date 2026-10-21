# Phoenix_UI 2.0 — Architecture

Target: **WoW Retail 12.1.5 (Midnight), `## Interface: 120105`, build 12.1.5.70448.** Retail only. No Classic code paths.
This is the contract every phase-2 change is measured against. If code and this document disagree, fix one of them in the same PR.

---

## 1. Headline decisions

1. **One addon, one namespace, zero globals.** Everything hangs off the private addon table `local ADDON, ns = ...`.
   The only globals are the SavedVariables and the `SLASH_PHOENIXUI*` strings created by Blizzard's `RegisterNewSlashCommand`.
2. **No Ace3 / no embedded third-party addons.** Kept libraries: `LibStub`, `CallbackHandler-1.0`, `LibSharedMedia-3.0` (12000005, interop), `LibEditMode` (current, our own movable frames). Everything else is replaced by our small core or by Blizzard APIs (`C_EncodingUtil`, `MenuUtil`, `C_Timer`, `hooksecurefunc`, `Settings`).
3. **Blizzard owns layout, we own looks.** Blizzard frames are positioned/sized by **Edit Mode**. Phoenix modules *skin* and *augment* Blizzard frames (textures, fonts, colours, extra text). We do not move or replace protected frames. Our *own* frames (data texts, M+ timer, spell history …) are registered with Edit Mode via LibEditMode.
4. **Display-only combat UI.** Under Midnight secret values we never do maths/comparisons on combat data. We feed secrets straight into widgets (`StatusBar:SetValue`, `SetTimerDuration`, `Cooldown:SetCooldownFromDurationObject`, colour curves, `SetAlphaFromBoolean`, `AbbreviateNumbers`, `C_StringUtil`).
5. **Declarative options.** Each module declares an options schema once. The same schema drives the standalone config window, the search index, profile import/export and the defaults table. There is no hand-built options page per module.
6. **One theme.** Every pixel goes through `ns.Theme` tokens and `ns.Skin` primitives. No module hard-codes a colour, font path or border.
7. **One SavedVariables owner (`ns.DB`)** with profiles, a schema version, and ordered migrations, including a one-shot import of the legacy `Phoenix_UIDB`.

---

## 2. Folder layout

```
Phoenix_UI/
├─ Phoenix_UI.toc               -- only file list; order = Libs → Locales → Core → UI → Modules
├─ Libs/
│  ├─ Libs.xml
│  ├─ LibStub/  CallbackHandler-1.0/  LibSharedMedia-3.0/  LibEditMode/
├─ Locales/
│  ├─ Locales.xml  enUS.lua  deDE.lua  esES.lua  esMX.lua  frFR.lua  itIT.lua  koKR.lua  ptBR.lua  ruRU.lua  zhCN.lua  zhTW.lua
├─ Core/
│  ├─ Core.xml
│  ├─ Namespace.lua     -- ns tables, version, constants, ns.Print / ns.Debug
│  ├─ Util.lua          -- pure helpers (tables, strings, colour maths on *non-secret* data)
│  ├─ Events.lua        -- ns.Events: game-event dispatcher + internal message bus
│  ├─ Secret.lua        -- ns.Secret: issecretvalue/canaccessvalue wrappers, restriction state
│  ├─ Combat.lua        -- ns.Combat: lockdown queue (run-after-combat), protected-call guard
│  ├─ DB.lua            -- ns.DB: SavedVariables, profiles, defaults merge, change notifications
│  ├─ Migrations.lua    -- ordered schema migrations + legacy Phoenix_UIDB importer
│  ├─ Modules.lua       -- ns:NewModule, lifecycle, enable/disable, dependency order
│  ├─ Media.lua         -- fonts/textures/sounds registry (+ LSM registration)
│  ├─ Theme.lua         -- design tokens, palettes, theme switching
│  ├─ Skin.lua          -- skin primitives (backdrop, border, button, statusbar, font, icon)
│  ├─ EditMode.lua      -- LibEditMode wrapper for our frames
│  ├─ Settings.lua      -- Blizzard Settings landing category + Addon Compartment + slash
│  └─ Profiles.lua      -- export/import strings (C_EncodingUtil CBOR + compress + base64)
├─ UI/
│  ├─ UI.xml
│  ├─ Widgets/          -- Button, Toggle, Slider, Dropdown(MenuUtil), ColorSwatch, Input, Section, List, Tabs, Badge, Tooltip
│  └─ Config/           -- Window, Sidebar, Search, Page renderer (schema → widgets), Preview, Profiles page, About
├─ Modules/
│  ├─ Modules.xml
│  └─ <ModuleName>/
│     ├─ <ModuleName>.xml   -- lists files of the module only
│     ├─ <ModuleName>.lua   -- module object, defaults, lifecycle
│     ├─ Options.lua        -- options schema (no UI code)
│     └─ *.lua              -- feature files
├─ Media/ Fonts/ Textures/ (curated, §11.2)
├─ tools/ audit/ (API/lint generators)   .luacheck/ wow_std_12.1.5.lua
├─ docs/  AUDIT.md  ARCHITECTURE.md  PROMPTS.md  audit/
├─ AGENTS.md   .cursor/rules/*.mdc   .luacheckrc   .pkgmeta
```

File and include names are **case-exact** (the audit found 52 Windows-only includes).

### 2.1 Module set (target)

| Module (key) | Replaces legacy | Notes |
|---|---|---|
| `Skins` | Skins/*, Init Skin/Color | Lazy per Blizzard addon, mixin/parentKey targeting |
| `ActionBars` | ActionBars | Cosmetic: button skin, hotkey/macro text, range/usable tint, mouseover fade (secure state drivers) |
| `UnitFrames` | UnitFrames | Player/Target/Focus/Boss/Arena skins, class colours, portraits, text via `UnitFrameUtil` |
| `GroupFrames` | RaidFrames, part of buffoverlay | CompactUnitFrame skin: textures, fonts, role/dispel colours |
| `CastBars` | CastBars | Skin `CastingBarMixin`; timer text from `UnitCastingDuration`; latency (player) |
| `Auras` | Buffs, buffoverlay | Skin BuffFrame/DebuffFrame; optional `CustomAuraContainer` displays |
| `NamePlates` | NamePlates | Cosmetics only (texture, font, health %, cast bar skin) |
| `Tooltip` | Tooltip, idTip | `TooltipDataProcessor` post-calls; IDs; item level; secret-safe unit lines |
| `Chat` | Chat | Style, URL copy, copy window, history/search, emoji, class/role icons — secret-aware |
| `Minimap` | Maps | Shape/size, coords, clock, button tray, compartment |
| `DataTexts` | General/_Stats, MoveAny fps | FPS/latency/speed/durability/gold/etc, Edit Mode movable |
| `ItemLevel` | General/_Itemlevel, _BagIlvl, Tooltip ilvl | Character/inspect/bags/bank |
| `Automation` | General automation, Misc bits | Repair, sell junk, decline duels, release, accept res, invites, cinematics, stack-buy |
| `AFK` | General/_AfkCam | |
| `MythicPlus` | Mythic+ | Timer, objectives %, deaths count, keystone info, auto-gossip |
| `PvP` | Misc PvP | Safe queue, tab-target binder (out of combat), surrender, dampening |
| `CooldownText` | CooldownTracker CooldownText | Styles Blizzard countdown numbers on Cooldown frames |
| `SpellHistory` | CooldownTracker SpellTracker | Player-only recent casts strip (secrecy-checked) |
| `CombatText` | MSBT | Configures/themes Blizzard floating combat text v2 |
| `DamageMeter` | Detail-Skin | Skin for `Blizzard_DamageMeter` |
| `Quality` | Talkhead, Errors, misc hides | Talking head, error filter, small hides |

---

## 3. Core and event bus

```lua
-- Core/Namespace.lua
local ADDON, ns = ...
ns.name, ns.version = ADDON, C_AddOns.GetAddOnMetadata(ADDON, "Version")
ns.L = ns.L or {}          -- filled by Locales
```

`ns.Events` (Core/Events.lua) owns **one** hidden frame for game events and a callback registry for internal messages:

```lua
ns.Events:On("PLAYER_ENTERING_WORLD", owner, handler)       -- game event, handler(owner, event, ...)
ns.Events:OnUnit("UNIT_HEALTH", owner, handler, "player")   -- RegisterUnitEvent under the hood
ns.Events:Off("PLAYER_ENTERING_WORLD", owner)
ns.Events:OffAll(owner)                                     -- used by Module:Disable()
ns.Events:Fire("PUI_PROFILE_CHANGED", profileKey)           -- internal message (prefix PUI_)
ns.Events:Listen("PUI_PROFILE_CHANGED", owner, handler)
```

Rules:
* Registering an event no handler needs is a bug; the frame unregisters an event when its last listener leaves.
* `COMBAT_LOG_EVENT` / `COMBAT_LOG_EVENT_UNFILTERED` are rejected by `ns.Events:On` with an error in debug builds (forbidden in 12.x).
* Handlers run through `xpcall` with `ns.Errors` reporting (module name + stack) so one broken module never stops dispatch. In debug mode errors re-raise.
* Internal messages used across modules: `PUI_PROFILE_CHANGED`, `PUI_SETTING_CHANGED(moduleKey, path, value)`, `PUI_THEME_CHANGED`, `PUI_MODULE_STATE(moduleKey, enabled)`, `PUI_COMBAT_END`, `PUI_RESTRICTION_CHANGED(state)`.

`ns.Secret` wraps `issecretvalue`, `canaccessvalue`, `issecrettable`, `C_Secrets.*` predicates and `C_RestrictedActions.GetAddOnRestrictionState`, listening to `ADDON_RESTRICTION_STATE_CHANGED`.
`ns.Combat` provides `ns.Combat:Run(key, fn)` (runs now if out of combat, else once at `PLAYER_REGEN_ENABLED`, de-duplicated by key) and `ns.Combat:Guard()` (returns false + queues when locked down).

---

## 4. Module registration and enable/disable contract

```lua
local _, ns = ...
local M = ns:NewModule("Tooltip", {
    label    = "TOOLTIP",           -- locale key
    category = "interface",         -- sidebar group
    order    = 40,
    icon     = "Interface/AddOns/Phoenix_UI/Media/Textures/Icons/Tooltip",
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
## SavedVariablesPerCharacter: PhoenixUICharDB, Phoenix_UIPerCharDB
```
`Phoenix_UIDB` / `Phoenix_UIPerCharDB` are the **legacy** tables, listed only so they can be read once and then set to `nil` (dropping them from disk). After a grace release they are removed from the TOC.

### 5.2 Shape
```lua
PhoenixUIDB = {
  schema   = 1,                      -- bumped by migrations
  global   = { modules = { <key> = {…} }, ui = { windowPos, lastPage, … } },
  profiles = { ["Default"] = { modules = { <key> = { enabled = true, … } }, theme = {…} } },
  profileKeys = { ["Name - Realm"] = "Default" },
  specProfiles = { ["Name - Realm"] = { [specID] = "Healer" } },   -- optional auto-switch
}
PhoenixUICharDB = { schema = 1, char = { … } }
```
* **Defaults are not stored.** `ns.DB` applies the module `defaults` via metatables. Only diffs are written, which keeps SavedVariables small and makes default changes ship to users.
* **Never store secret values** (they are saved as `nil`). `ns.DB:Set` asserts `not issecretvalue(v)`.
* Profile ops: `New`, `Copy`, `Rename`, `Delete`, `Reset`, `SetActive`, per-spec auto switch (on `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, out of combat).

### 5.3 Import/export
`ns.Profiles:Export(profileName, {modules = …})` → `"!PUI1!" .. EncodeBase64(CompressString(SerializeCBOR(payload)))`, all through `C_EncodingUtil`.
The payload includes `{schema, addonVersion, profile}`. Import validates the prefix and schema, runs migrations on the payload, then previews the diff in the config window before applying. There is no comms-based sharing (comms are blocked during lockdown).

### 5.4 Migrations
`Core/Migrations.lua` holds an ordered list `{ version = n, run = function(db) … end }`. On `ADDON_LOADED` the core runs every migration with `version > db.schema` inside `xpcall`. Before the first migration it takes a backup in `PhoenixUIDB.backup` (one slot only, removed after 2 successful logins).

**Legacy importer (migration 1):** if `Phoenix_UIDB` exists, map the known keys (see the table below), copy the profile names, then `Phoenix_UIDB = nil`. Unknown keys are dropped and listed once in chat as "not migrated".

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

The exact key list is built in phase 2 from `Core/Init.lua` defaults (lines ~59–1100).

---

## 6. Localization

* `Locales/enUS.lua` defines the base table: `ns.L = setmetatable({ KEY = "English text", … }, { __index = function(t, k) return k end })`.
* Other locale files return early unless `GetLocale()` matches, and only override keys.
* Code uses **keys**, never inline English: `L.TOOLTIP_SHOW_IDS`. Option schema `label`/`desc` fields are locale keys.
* Fonts must support the client locale. `ns.Media:Font(role)` falls back to Blizzard `STANDARD_TEXT_FONT` / `UNIT_NAME_FONT` on koKR/zhCN/zhTW (the bundled Latin fonts lack CJK glyphs) and checks ruRU Cyrillic coverage (Roboto/Inter yes; Expressway/Cinzel no → fallback per role).

---

## 7. Theme system (one, shared)

`ns.Theme` holds **tokens**. `ns.Skin` turns tokens into visuals. Modules only call `ns.Skin` and `ns.Theme:Color("token")`.

```lua
ns.Theme:Color("bg.base")        -- returns r,g,b,a
ns.Theme:Font("body")            -- returns path, size, flags (locale-aware)
ns.Theme:Space(3)                -- 12 (4-px grid)
ns.Skin:Panel(frame, "raised")   -- background + 1px border + optional accent edge
ns.Skin:Button(btn, "primary")
ns.Skin:StatusBar(bar, "health") -- texture + background + border; never reads values
ns.Skin:Icon(tex)                -- crop 0.08–0.92 + border
ns.Skin:Text(fs, "label")        -- font + colour + shadow
ns.Skin:Restore(frame)           -- undo (module disable)
```

Presets: **Phoenix Ember** (default), **Obsidian** (neutral), **Class** (accent = class colour via `C_ClassColor.GetClassColor`), **Blizzard** (minimal: fonts only), **Custom** (user accent + base). Changing a preset fires `PUI_THEME_CHANGED`, and every skinned object re-applies from tokens (registry of weak-keyed skinned objects).

---

## 8. Blizzard Settings registration

* `Settings.RegisterCanvasLayoutCategory(landingFrame, "Phoenix UI")` + `Settings.RegisterAddOnCategory(category)`. The landing canvas is themed and shows: the logo, version, an **Open Phoenix UI** button, quick module toggles, profile selector, and a "reset window position" button.
* `ns.Settings.categoryID = category:GetID()`; `/pui settings` → `Settings.OpenToCategory(ns.Settings.categoryID)`.
* Addon Compartment: `AddonCompartmentFrame:RegisterAddon({ text = "Phoenix UI", icon = …, notCheckable = true, func = ns.ToggleConfig, funcOnEnter = …, funcOnLeave = … })`. There is no `## AddonCompartmentFunc` global.
* Slash: `RegisterNewSlashCommand(ns.HandleSlash, "pui", "phoenix")`. Sub-commands: `config`, `settings`, `profile <name>`, `editmode`, `reset`, `debug`.
* Opening the config window in combat is allowed (it is not protected). Any setting that touches protected frames queues through `ns.Combat:Run` and shows an "applies after combat" badge.

---

## 9. Standalone config window

A movable, resizable (`SetResizeBounds`) window (default 980×640, saved position/scale), built lazily on first open and closable with Esc (`tinsert(UISpecialFrames, …)` using a uniquely named frame).

```
┌───────────────────────────────────────────────────────────────────────────┐
│ ◆ PHOENIX UI   v2.0.0                    [ 🔍 Search settings…   ]  ⟳  ✕ │  header 48px
├──────────────┬────────────────────────────────────────────────────────────┤
│ ● Home       │  Tooltip                                   [■■ Enabled ]   │  page header
│ INTERFACE    │  Rich unit and item tooltips.                              │
│   Action Bars│  ┌ Anchor ───────────────────────────────────────────────┐ │
│   Unit Frames│  │ Position   [ Cursor        ▾ ]                         │ │
│   Group      │  │ Offset X   ───────●────── 12                           │ │
│   Cast Bars  │  └────────────────────────────────────────────────────────┘ │
│   Tooltip  ◀ │  ┌ Content ──────────────────────────────────────────────┐ │
│   …          │  │ [✓] Show spell / item IDs   [✓] Item level           │ │
│ COMBAT       │  └────────────────────────────────────────────────────────┘ │
│ SOCIAL       │                                                            │
│ UTILITY      │                                          live preview ▸    │
│ ───────────  │                                                            │
│ Profiles     │                                                            │
│ About        │                                                            │
└──────────────┴────────────────────────────────────────────────────────────┘
```

* **Sidebar navigation:** groups Interface / Combat / Social / Utility / System, module rows with icon, an enabled dot, an error dot, and a reload badge. Collapsible groups. Keyboard ↑/↓ navigation.
* **Search:** an index built from every schema entry (`label`, `desc`, `keywords`, module name), localized. Results list `Module › Section › Setting`; Enter jumps to the setting and the setting pulses with the accent highlight.
* **Live preview:** every control writes through `ns.DB:Set(module, path, value)`, which fires `PUI_SETTING_CHANGED`, then `module:OnSettingChanged()`, so the real UI updates instantly. Pages can declare a `preview` (for example "show test cast bar" or "show tooltip sample") that drives demo frames, using Blizzard Edit Mode preview APIs where they exist (12.1.5 `SetEditModePreviewEnabled` on custom aura containers).
* **Profile page:** active profile, new/copy/rename/delete/reset, per-spec mapping, an **Export** box (select-all string) and an **Import** box (paste → diff preview → apply).
* **Per-module toggles:** in the page header and on the Home grid (cards with toggle + short description).
* **Schema → widgets:** `toggle`, `range`, `select`, `color`, `font`, `texture`, `input`, `header`, `description`, `button`, `group`, `list`. The schema supports `disabled = fn`, `hidden = fn`, `requiresReload`, and `combatSafe = false`.

---

## 10. Edit Mode support

* Our movable frames register through `ns.EditMode:Register(frame, { name = L.X, default = { point = "CENTER", x = 0, y = 0 }, settings = { … } })`. This wraps **LibEditMode** (`AddFrame`, `AddFrameSettings`, layout callbacks). Positions are stored **per Edit Mode layout** in `global.layouts[layoutName][frameKey]`, so they follow the user's Blizzard layout switches.
* Blizzard frames: we never call `SetPoint` on frames managed by `EditModeManagerFrame`. Size and position settings for Blizzard systems are left to Edit Mode. Our config page links to it with an "Open Edit Mode" button (`ShowUIPanel(EditModeManagerFrame)` out of combat).
* `EDIT_MODE_LAYOUTS_UPDATED` and LibEditMode's `layout` callback re-apply our positions.

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

Combat colours (health, power, reaction, class, dispel types) are **not** re-invented. They come from Blizzard (`C_ClassColor`, `PowerBarColor` (read-only), `DEBUFF_TYPE_*`) through colour curves so they work with secret values.

### 11.2 Typography (bundled fonts, curated)

| Role | Font file (Media/Fonts) | Size | Flags |
|---|---|---:|---|
| `brand` (logo/wordmark) | `Cinzel-Bold.ttf` | 20 | — (+ gradient) |
| `title` (page titles) | `Expressway.ttf` | 18 | — |
| `heading` (section headers, uppercase, +1 tracking via spacing) | `Expressway.ttf` | 12 | — |
| `body` (labels, controls) | `Roboto-Medium.ttf` | 12 | — |
| `desc` (descriptions) | `Roboto-Regular.ttf` | 11 | — |
| `mono/number` (values, timers) | `Roboto_Condensed-Bold.ttf` | 12 | — |
| `unit` (in-world frames, nameplates, bars) | `Roboto_Condensed-SemiBold.ttf` | per element | `OUTLINE` optional, shadow 1,-1 |
| `combat` (big timers, CDs) | `Expressway.ttf` | per element | `OUTLINE` |

Shipped font set (≈12 files): Cinzel-Bold, Expressway, Roboto-{Regular,Medium,Bold}, Roboto_Condensed-{Regular,SemiBold,Bold}, InterBold, PTSansNarrow, PhoenixFont, plus `Invisible.ttf` if used for hiding. Everything else, including the 13 MB `AvantGarde.TTF` and the 40+ italic/thin weights, is removed. All shipped fonts are also registered with LSM under `Phoenix *` names.

### 11.3 Spacing, sizing, borders
* **4-px grid**: `space(1)=4, (2)=8, (3)=12, (4)=16, (6)=24, (8)=32`. Page padding 24, section padding 16, control row height 28, sidebar width 200, header 48.
* **Borders:** 1 physical pixel (`PixelUtil.SetSize`/`SetRoundLayoutToNearestPixel`), `border.subtle`. Panels have a 1-px top inner highlight (`#FFFFFF` α 0.04). Active nav row gets a 2-px left accent bar with an `accent.primary→secondary` vertical gradient (`SetGradient`).
* **Icons:** cropped 8 % with a 1-px black border and an inner 1-px `border.subtle`.
* **Status bars:** flat texture (`Phoenix Flat`), background `bg.sunken`, 1-px border. The optional "ember" spark uses Blizzard statusbar interpolation (`Enum.StatusBarInterpolation`).
* No rounded corners baked into code. One 9-slice texture set (`Media/Textures/UI/Panel*`) gives a 2-px soft radius for windows only.

### 11.4 Motion
* Window open: 160 ms alpha 0→1 + 8-px upward slide (`AnimationGroup`, `Smooth` easing). Close: 120 ms fade.
* Page switch: 120 ms cross-fade. Toggle knob: 100 ms translate. Hover: 80 ms colour lerp (driven by a single shared OnUpdate during transitions only).
* Search-hit pulse: accent glow, 2 × 300 ms.
* Setting `ui.reduceMotion` disables everything above. Animations never run in combat on in-world frames.

---

## 12. Cross-cutting rules (summary; details in `.cursor/rules`)

* **Taint:** never assign to Blizzard globals or fields on Blizzard tables/frames, never replace Blizzard functions, only `hooksecurefunc`/`HookScript`. Protected operations go through `ns.Combat`.
* **Secrets:** treat combat-related API returns as possibly secret. Use the display sinks. Gate any logic on `ns.Secret` predicates.
* **Performance:** event-driven. OnUpdate is allowed only while something is animating or visible and time-dependent. No `collectgarbage`. Throttle with `C_Timer.NewTimer` de-bounce. Create frames lazily, and pool them (`CreateFramePool`/`CreateObjectPool`).
* **Lint:** `luacheck .` must be clean with the generated 12.1.5 std (`.luacheckrc`).

---

## 13. Phased build order

| Phase | Scope | Exit criteria |
|---|---|---|
| **2.0 Clean slate** | Move legacy code out (delete on `rework`; history keeps it), new TOC `120105`, Libs (LibStub, CBH, LSM 12000005, LibEditMode current), `.luacheckrc`, `.pkgmeta` | Addon loads with zero Lua errors and zero globals (verified by luacheck + `/dump` checks) |
| **2.1 Core** | Namespace, Events, Secret, Combat, DB+profiles, Migrations (+legacy importer skeleton), Modules, Media, Theme, Skin, Settings landing, slash, compartment, Locales enUS | Module toggle round-trip works; profile switch works; `/pui` opens a stub |
| **2.2 Config UI** | Widgets, window, sidebar, search, schema renderer, profiles page (export/import), About/credits | Every widget type is themed; search finds every setting; import/export round-trips |
| **2.3 Low-risk modules** | Quality, Automation, AFK, ItemLevel, Tooltip, Minimap, DataTexts, Chat | Each passes the test checklist (§AGENTS) incl. forced secret CVars |
| **2.4 Combat UI** | Skins core + ActionBars, UnitFrames, CastBars, GroupFrames, Auras, NamePlates, CooldownText | No taint ("/console taintLog 2" clean through a dungeon + BG), no secret errors |
| **2.5 Content** | MythicPlus, PvP, SpellHistory, CombatText, DamageMeter skin, remaining Blizzard window skins | M+ run with `secretChallengeModeRestrictionsForced=1` is clean |
| **2.6 Migration & polish** | Full legacy key map, locale stubs, reduce-motion, accessibility (font scale), performance pass, packaging | Clean install and legacy-upgrade both verified; tagged 2.0.0 |
