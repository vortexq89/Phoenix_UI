# Phoenix_UI 2.0 — Architecture

Target: **WoW Retail 12.1.5 (Midnight), `## Interface: 120105`, build 12.1.5.70448**, and **WoW Forever 1.60.1
(`## Interface: 16001`)**, which shares Mainline's UI (§17). No Classic code paths.
This describes the code as it is. If code and this document disagree, fix one of them in the same change.

---

## 1. Headline decisions

1. **One addon, one namespace, zero globals.** Everything hangs off the private addon table `local ADDON, ns = ...`.
   The only globals are the SavedVariables, the `SLASH_*` strings created by Blizzard's `RegisterNewSlashCommand`, and
   `GetMinimapShape` (defined by the Minimap module in square mode; minimap-button libraries read it) and
   `ClickCastFrames` (the click-cast addons' shared table; Group Frames creates it only when no addon has).
2. **No Ace3 / no embedded third-party addons.** Kept libraries: `LibStub`, `CallbackHandler-1.0`, `LibSharedMedia-3.0` (12000005, interop), `LibEditMode` (current, our own movable frames). Everything else is replaced by our small core or by Blizzard APIs (`C_EncodingUtil`, `MenuUtil`, `C_Timer`, `hooksecurefunc`, `Settings`).
3. **Blizzard owns layout, we own looks.** Blizzard frames are positioned/sized by **Edit Mode**. Phoenix modules *skin* and *augment* Blizzard frames (textures, fonts, colours, extra text). We do not move or replace protected frames. Our *own* frames (data bar, spell history) are registered with Edit Mode via LibEditMode. **One exception (2.0 S7): action bars.** In Phoenix mode (the default) the ActionBars module owns its bars: Blizzard's bars are parked and their buttons live in Phoenix secure headers laid out by restricted snippets (§13); Blizzard mode hands the bars back to Edit Mode. **Second exception (2.0 S8): unit frames.** In Phoenix mode (the default) the UnitFrames module draws its own secure unit buttons for player, target, target of target, focus, focus target, pet, boss 1–5 and (opt-in) arena 1–5, and parks Blizzard's frames (§13); Blizzard mode keeps the game's frames and only skins them. **Third exception (2.0 S9): cast bars and player auras.** Phoenix mode draws plain (non-secure) cast bars and replaces the player's Edit Mode cast bar, and shows the player's buffs, debuffs and weapon enchants on Blizzard's addon aura containers (`CustomAuraContainerTemplate`), parking `BuffFrame`/`DebuffFrame` (§13); Blizzard mode skins the game's frames. **Fourth exception (2.0 S11): group frames.** Phoenix mode draws party, raid, main tank/assist and pet frames from its own secure group headers and parks Blizzard's party and compact raid frames (§13); Blizzard mode restyles the game's compact frames. **Nameplates (2.0 S10)** are not an exception: Phoenix draws its plates as plain frames parented to the game's (non-forbidden) base plates and only fades Blizzard's `UnitFrame` out; size and click area go through the game's own nameplate size API out of combat (§13).
4. **Display-only combat UI.** Under Midnight secret values we never do maths/comparisons on combat data. We hand possible secrets straight to display sinks (`FontString:SetFormattedText`, `Texture:SetTexture`, `UnitHealthPercent` with `CurveConstants.ScaleTo100`) and never test them.
5. **Declarative options.** Each module declares an options schema once (`Phoenix_UI_Options/Options/<Module>.lua`). The same schema drives its config page and the search index. Defaults live on the module.
6. **One theme.** Every pixel goes through `ns.Theme` tokens and `ns.Skin` primitives. No module hard-codes a colour, font path or border.
7. **One SavedVariables owner (`ns.DB`)** with profiles, a schema version, and ordered migrations, including a one-shot import of the legacy `Phoenix_UIDB`.

---

## 2. Folder layout


```
Phoenix_UI/
├─ Phoenix_UI.toc               -- only file list; order = Libs → Locales → Core → UI → Modules → Core/Init.lua
├─ Phoenix_UI_Forever.toc       -- WoW Forever (16001); GENERATED from Phoenix_UI.toc by tools/gen_tocs.py (§17)
├─ Libs/
│  ├─ Libs.xml
│  ├─ LibStub/  CallbackHandler-1.0/  LibSharedMedia-3.0/  LibEditMode/
├─ Locales/
│  ├─ Locales.xml  Locales.lua (fallback table, ns.RegisterLocale)  enUS.lua
│  │  deDE frFR esES(+esMX) ptBR ruRU itIT koKR zhCN zhTW .lua  (complete; checked by check_locales.py + harness)
├─ Core/
│  ├─ Core.xml
│  ├─ Namespace.lua     -- ns tables, version, constants, ns:Print / ns:Debug, SafeCall
│  ├─ Flavor.lua        -- ns.flavor (retail | forever), ns:Supports(feature), ns.FEATURES, ns:FilterSchema (§17)
│  ├─ Util.lua          -- pure helpers (tables, strings, colour maths on *non-secret* data)
│  ├─ Events.lua        -- ns.Events: game-event dispatcher + internal message bus (combat-log guard)
│  ├─ Secret.lua        -- ns.Secret.IsSecret: the one secret-value gate
│  ├─ Errors.lua        -- ns.Errors: error catcher installed at load (§15), owns PhoenixUIBugsDB
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
│  └─ Launcher.lua      -- ns.Config front door (loads Phoenix_UI_Options), Blizzard landing + compartment, welcome picker
├─ Modules/
│  ├─ Modules.xml       -- lists every module file directly (no per-module XML)
│  └─ <ModuleName>/
│     └─ <ModuleName>.lua   -- module object, defaults, lifecycle
├─ Phoenix_UI_Options/  -- SECOND ADDON (## LoadOnDemand: 1, ## Dependencies: Phoenix_UI); .pkgmeta move-folders ships it
│  ├─ Phoenix_UI_Options.toc  (+ Phoenix_UI_Options_Forever.toc, generated)
│  ├─ Bridge.lua        -- proxies this addon's private table to Phoenix_UI's ns (bridge global lives only during LoadAddOn)
│  ├─ Previews/         -- live previews built from each module's own styling code
│  ├─ Config/           -- Window, Groups, Renderer (schema → widgets), Search, Home, Profiles, Appearance, Diagnostics, Presets, About
│  └─ Options/<ModuleName>.lua -- options schema per module (no UI code)
├─ Media/ Fonts/ Textures/ (surfaces, Emblem64/128/256, Logo512/1024)  Icons/ (Icons24/48/64 atlases + LICENSE)
├─ tools/ check_api.py  check_ids.py  check_locales.py  check_flavors.py  gen_tocs.py  smoke/harness.lua
│         audit/ (reference generators, PUI_FLAVOR=retail|forever)  ids/  media/
├─ .luacheck/ wow_std_12.1.5.lua  reference_12.1.5.json  deprecated_12.1.5.json
│             wow_std_forever_1.60.1.lua  reference_forever_1.60.1.json
├─ docs/  AUDIT.md  ARCHITECTURE.md  ROADMAP.md  PROMPTS.md  audit/  screenshots/
├─ .github/workflows/luacheck.yml   .pkgmeta   AGENTS.md   .cursor/rules/*.mdc   .luacheckrc
```

File and include names are **case-exact** (the audit found 52 Windows-only includes).

### 2.1 Modules

| Module (key) | Replaces legacy | What it does |
|---|---|---|
| `General` | Init theme/fonts | Theme preset and accent, fonts, bar texture, reduce motion (locked on) |
| `Skins` | Skins/* | Game menu, popups and ready check, applied lazily |
| `ActionBars` | ActionBars | Phoenix-owned secure bars 1–8, pet, stance and an item bar (layout, paging, visibility/fade, Layout-mode positions), button shapes/borders/glows, range/power/unusable tints, hotkey/macro/count text, extra/zone/vehicle-exit, micro and bag menus; Blizzard mode keeps Edit Mode bars (`ActionBars.lua` pure layout + drivers, `Bars.lua` secure engine, `Buttons.lua` styling hooks, `Extras.lua`) |
| `UnitFrames` | UnitFrames (`UnitFrames.lua` core/tags/colours/geometry, `Build.lua` frame parts and layout, `Update.lua` secret-safe updates, `Spawn.lua` secure buttons/events/parking/test, `Blizzard.lua` 1.x skin for Blizzard mode) | Phoenix-owned player/target/ToT/focus/focus-target/pet/boss/arena frames; Blizzard-frame skin fallback |
| `GroupFrames` | RaidFrames (`GroupFrames.lua` saved shape/size profiles/pure header-attribute helpers/lifecycle, `Headers.lua` secure group headers/button init/parking/movers/events, `Update.lua` group-only parts (dispel, phase, aura rows, defensive, private auras) and samples/test, `Blizzard.lua` 1.x skin) | Phoenix-owned party/raid/main tank/pet frames on secure group headers; compact-frame skin fallback |
| `CastBars` | CastBars (`CastBars.lua` defaults/helpers/interrupts, `Bar.lua` bar parts and geometry, `Update.lua` secret-safe cast updates and samples, `Spawn.lua` holders/movers/events/parking/test, `Extras.lua` GCD and swing timer, `Blizzard.lua` 1.x skin) | Phoenix-owned player/target/focus/pet/boss/arena cast bars; Blizzard-bar skin fallback |
| `Auras` | Buffs (`Auras.lua` defaults and layout helpers, `Containers.lua` aura containers/parking/private anchors/test, `Blizzard.lua` 1.x skin) | Player buffs/debuffs/weapon enchants on aura containers; BuffFrame/DebuffFrame skin fallback |
| `NamePlates` | NamePlates (`NamePlates.lua` saved shape/colours/pure helpers/CVars/size/contexts, `Plate.lua` plate parts and layout, `Update.lua` secret-safe updates/live plates/samples/test, `Blizzard.lua` 2.0 restyle) | Phoenix-drawn enemy/friendly plates (health, cast bar from the CastBars engine, tags, auras, indicators, highlights, execute, threat, per-zone styles), Mythic+ enemy forces per mob (`C_ScenarioInfo.GetUnitCriteriaProgressValues`, shown through `C_StringUtil`); Blizzard-plate restyle fallback |
| `Tooltip` | Tooltip, idTip | Skin, cursor anchor, class/quality borders, target/role/ID lines, Mythic+ rating |
| `Chat` | Chat | Clickable URLs with a copy popup, copy-chat window, typed-line history (arrow keys, kept across reloads in `global.history`), Shift/Ctrl wheel scrolling |
| `Minimap` | Maps | Square mask, zone text, coordinates; LibDBIcon button bin (addon-owned buttons only); shows the Edit Mode size and opens Edit Mode (size is never written by Phoenix) |
| `DataTexts` | General/_Stats | Edit Mode movable bar: FPS, latency, speed, durability, gold, clock, bug count, bag space, item level, friends, guild, mail; `order` is a comma list normalised by `M:Order()` |
| `ItemLevel` | _Itemlevel, _BagIlvl | Item level on the character sheet and bags |
| `Bags` | (new) | Bag window skin, quality borders, count font, upgrade arrows; post-hooks `UpdateItems`, own regions in weak side tables |
| `Automation` | General automation | Repair, sell junk, invites, duels, resurrections, BG release, DELETE fill, cinematics |
| `AFK` | _AfkCam | AFK screen |
| `MythicPlus` | Mythic+ | Run timer overlay (`Timer.lua`: chest thresholds, forces, boss splits, deaths, personal bests in `global.best`; Edit Mode frame), auto-insert keystone, new-key report |
| `PvP` | Misc PvP | Safe queue, TAB targets players, `/gg` |
| `Tracker` | Auras & Cooldowns (1.x skin; key kept for saved settings) (`Tracker.lua` defaults/pure grid, stack, list and visibility helpers/state/event fan-out/Test, `Viewers.lua` Blizzard viewer items re-laid on Phoenix anchors, styling, glows, keybinds, claims, movers, `Custom.lua` three custom bars and the Test samples, `Reminders.lua` pre-pull reminders) | Cooldown Manager: Blizzard's Essential/Utility/Buff icon/Buff bar viewers in Phoenix style and layout (grid, overflow, keep-in-place, Edit Mode or mover placement), proc and ready glows, desaturation, GCD swipe, keybinds, visibility and spec rules; three secret-safe custom bars for spells, items and trinkets; out-of-combat reminders. Separate from `Auras` (every buff and debuff on you) |
| `CooldownText` | CooldownTracker CooldownText | Phoenix font and color on Blizzard countdown numbers; `M:Claim(cooldown, on)` hands a countdown to another module (one owner per number) |
| `SpellHistory` | CooldownTracker SpellTracker | Player-only recent casts strip |
| `Encounters` | (new, 2.0 S1) | `C_EncounterTimeline` events as Phoenix bars (`Bars.lua`), `ENCOUNTER_WARNING` as a Phoenix banner (`Warnings.lua`), pull (`C_PartyInfo.DoCountdown`) and break (DBM/BigWigs "D5" BT message) timers, countdown voice, BigWigs bar style (`BigWigs.lua`, public `BigWigsAPI:RegisterBarStyle`). Owns `encounterTimelineEnabled`/`encounterWarningsEnabled` while it draws (player's values kept in `global.cvars`, restored on hand-back); stands down when BigWigs or DBM is loaded. Secret event fields only reach SetText/SetTexture |
| `Sim` | (new, 2.0 S2; export format after simc-addon, Unlicense) | SimulationCraft through the Phoenix app. `Export.lua` (`ns.SimExport`): profile header (DB2 spec/profession tokens, `C_Traits.GenerateImportString`, omnium system 48) and SimC item options from plain links; item key = itemID + sorted bonus IDs. `Sim.lua`: paperdoll/bag gear, selection, `Prepare` writes one request per character into SV `PhoenixUISimDB`; the app answers in `Sim\Results.lua` (`PhoenixUISimResults`, data only), imported on login into SV (last 10 per character). `ItemResult(link)` feeds the Tooltip line and the Bags arrow (`PUI_SIM_RESULTS`). Contract fixtures shared with `uploader/` tests |
| `CombatText` | MSBT | Blizzard floating combat text settings in one page |
| `DamageMeter` | Detail-Skin | Skin for `Blizzard_DamageMeter`, optional one-click Details! style |
| `Quality` | Talkhead, Errors | Talking head, error filter, achievement screenshots, Cooldown Manager toggle |
| `Bugs` | — (BugGrabber/BugSack style) | Error catcher UI: viewer, chat notice, sound, minimap/compartment indicator, upload info (§15) |
| `Movers` | MoveAny (partial) | Move/scale/fade a verified list of Blizzard frames Edit Mode does not manage (§16) |

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
## SavedVariables: PhoenixUIDB, PhoenixUIBugsDB, Phoenix_UIDB
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
| `chat.link`, `chat.copy`, `chat.history.enabled` | `modules.Chat.urls/copyButton/keepHistory` (the switch only: stored received lines are not imported, 2.0 keeps typed lines) |
| `maps.minimap.*` | `modules.Minimap.*` |
| `general.autorepair/autosell/…` | `modules.Automation.*` |
| `mythicplus.enabled/showTimer/showObjectives/deathTracker` | `modules.MythicPlus.enabled/timer/timerForces+timerBosses/timerDeaths` (timer scale, position and colours are Edit Mode and theme now; `enhanceKeystones`, `autoGossip` have no counterpart) |
| MSBT / CooldownTracker PartyCD / MoveAny / PGF / BuffOverlay blobs | **not migrated** (features removed) |

**Migration 2 (style specs):** flat 2.0 keys move into the style specs added in 2.1 (`Mg.MOVES`):
`NamePlates.textSize → health.size`, `ActionBars.fontSize → hotkey.size`, `Auras.durationSize → duration.size`,
`Auras.countSize → count.size`, and (step 3, which re-runs the same idempotent move) `GroupFrames.nameSize → name.size`.
Imported export strings with an older `schema` get the same upgrade (`Migrations:UpgradeProfile`); `ns.C.SCHEMA`
is always the last step's version, and strings from a newer schema are refused. Only values saved in the profile move (defaults are not stored), and the old key is removed.

---

## 6. Localization

* `Locales/enUS.lua` defines the base table: `ns.L = setmetatable({ KEY = "English text", … }, { __index = function(t, k) return k end })`.
* Other locale files return early unless `GetLocale()` matches, and only override keys. Every shipped translation
  defines every enUS key with the same format specifiers, `\n` and colour codes (`check_locales.py`, harness "locales").
  Lua's `format` has no positional arguments, so a translation must keep the `%s`/`%d` order of the English text.
* koKR/zhCN/zhTW: `Media:Font` returns `STANDARD_TEXT_FONT` (bundled fonts have no CJK glyphs); ruRU hides fonts without
  Cyrillic from the pickers and swaps them for Roboto.
* Code uses **keys**, never inline English: `L.TOOLTIP_SHOW_IDS`. Option schema `label`/`desc` fields are locale keys.
* Fonts must support the client locale. `ns.Theme:Font(role)` falls back to Blizzard `STANDARD_TEXT_FONT` / `UNIT_NAME_FONT` on koKR/zhCN/zhTW (the bundled Latin fonts lack CJK glyphs). On ruRU the pickers only list fonts whose subset covers А–я (`cyrillic = true` in `Core/FontData.lua`); Cinzel is only used for the Latin "PHOENIX" wordmark.

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

### 7.1 Media
`Core/FontData.lua` and `Core/TextureData.lua` are generated (`tools/media/gen_fonts.py`, `gen_textures.py`) and
list every bundled font and statusbar with its saved key, LibSharedMedia name ("Phoenix …"), family/weight or style
group. `Core/Media.lua` registers them with LSM when it is present, adds the Roboto/Inter/Cinzel core set and
answers `Media:Font(key)`, `Media:Bar(key)` and `Media:List(kind)` (items carry the path and group heading the
pickers need for live samples). `tools/check_api.py` verifies every file exists, has a licence and that no key or
name is used twice. Licences and sizes: `Media/Fonts/FONTS.md`.

### 7.2 Style specs
`Core/Style.lua` defines the per-module look as plain tables stored in the profile:
`Style.Text(size)` (font, size, outline, shadow, colour, anchor, x, y, show), `Style.Border` (style theme / none /
pixel / solid / thick / inset / shadow / glow / ember, size, colour, shadow auto / none / soft / hard / glow),
`Style.Background` (alpha, colour, style solid / gradient / glass) and `Style.Icons` (size, spacing, zoom, growth).
Style `theme` follows Appearance & General (`theme.borderStyle`, `borderSize`); `theme.borderColor` and
`theme.glowColor` override the `border.black` and `accent.glow` tokens, and `theme.shadowAlpha` sets shadow depth.
`colour = false` means "follow the theme token", so presets keep working. `ns.Opt.Text/Border/Background/Icons`
build the matching option rows (a font row with a cog for size/outline/shadow/colour/position, and so on), and
`ns.Skin:TextSpec/Place/BorderSpec/Backdrop/IconZoom` apply a spec to a frame. Modules style their frames through
these helpers only, which is what lets the previews reuse the same code.

Presets change the accent family over one shared dark surface palette: **Phoenix Ember** (default), **Frost**, **Fel**, **Arcane**, **Class** (`C_ClassColor.GetClassColor`) and **Custom** (`theme.custom = { r, g, b }`). Changing a preset fires `PUI_THEME_CHANGED`, and every skinned object re-applies from tokens (registry of weak-keyed skinned objects).

---

## 8. Blizzard Settings registration

* `Settings.RegisterCanvasLayoutCategory(landingFrame, "Phoenix UI")` + `Settings.RegisterAddOnCategory(category)` (UI/Launcher.lua). The landing canvas is themed: logo, short text and an **Open Phoenix UI** button.
* `/pui settings` → `Settings.OpenToCategory(category:GetID())`.
* Addon Compartment: `AddonCompartmentFrame:RegisterAddon({ text, icon, notCheckable, func, funcOnEnter, funcOnLeave })` with a themed tooltip. There is no `## AddonCompartmentFunc` global.
* Slash (Core/Init.lua): `RegisterNewSlashCommand(handler, "pui", "phoenix")`. Sub-commands: none/`config`, `settings`, `edit`, `profile [name]`, `reset`, `debug`, `<module key>`.
* Opening the config window in combat is allowed (it is not protected). Any setting that touches protected state queues through `ns.Combat:Run` and shows an "out of combat" badge.

---

## 9. Standalone config window

Settings window v2 (plan v2 stage S6, `Phoenix_UI_Options/Config/Window.lua`). Movable and resizable (900×560 to
1800×1200, default 1280×800; sizes saved by the 13-group layout reset once). Built on first open, closes with Esc
(`UISpecialFrames`, frame `PhoenixUI_Config`), position and size saved in `global.ui` (`/pui reset` clears them).

* **Shell:** top bar 52 (brand, search centred and narrowing before it overlaps, profile switch, Layout, Test
  frames, close), icon rail 64, page list 212, content, preview dock (30 % of the width, 380–460, only from 1100 px;
  `Config:LayoutShell`), footer 34 (auto-saved, status, pixel-perfect UI scale from `GetPhysicalScreenSize`,
  window scale 0.7–1.4 applied on mouse-up and saved in `global.ui.scale`, Reload when a module needs it).
* **Navigation** (`Groups.lua`): seven rail groups (Home, Frames, Bars, Combat, Interface, Content, Phoenix), each a
  list of module or page keys with optional `{ heading = KEY }` sub-headings. Every module and page sits in exactly
  one group; unlisted modules fall into the group for their category. `Config.DEPTH` holds the plan v2 target per
  page and `Config:Depth(key)` returns now/target for the page-list and Home meters. Menu only: saved settings
  never move.
* **Search** (`Search.lua`): indexes every schema entry (`label`, `desc`, `keywords`, module name, rail group and
  sub-heading) and the rows inside cogs, with a synonym table for players' words (hp, cd, colour, bg, np, m+, ilvl…).
  Picking a result opens the page, switches to its tab, scrolls to the row and flashes it. The placeholder counts
  the settings it reaches (`Config:SearchCount`). No global key capture: `SetPropagateKeyboardInput` is
  restricted in combat, so there is no Ctrl+F.
* **Live updates:** controls write through `ns.DB:Set(module, path, value)`, which calls
  `module:OnSettingChanged()` and fires `PUI_SETTING_CHANGED`.
* **Schema → widgets** (`Phoenix_UI_Options/Config/Renderer.lua`): `header`, `description`, `toggle`, `range`, `select`, `font`,
  `texture`, `color`, `input`, `button`, `custom` (`build(row, module)`). Per entry: `key` or `get`/`set`, `desc`,
  `keywords`, `disabled = fn(m)`, `hidden = fn(m)`, `reload` (Reload badge) and `combat` (applies after combat).
* **2.1 additions:** `tab` (splits a page; cards belong to the last tab), `preview` (`kind` registered in
  `Phoenix_UI_Options/Previews`), `scope` (element chips; keys containing `@` resolve to the picked element),
  `colors` (several token swatches in one row) and `cog = { … }` on any row (a popover with the sub-options; cogs do
  not nest, `Opt.Flat` flattens rows for them). `color` rows take `token`, `reset`, `alpha` and `classToken`
  (Class / Theme chips; `{ token = "class" }` follows the class colour). `texture` and `font` pickers draw live
  samples, filter as you type and group by family or style.
* **S6 widget kit:** `style` rows (`kind` border / shadow / backdrop, `W:StylePicker`, cards drawn by
  `Skin:BorderSpec`/`Backdrop`); `gate = true` on the first toggle under a header makes it the card's header switch
  and disables the card's other rows while off; rows without a description pair two per line on cards of 400 px
  or more (`Renderer.lua` `CELL_H` 60, `TOGGLE_CELL_H` 38); the scope bar is `W:Chips` (Shift-click edits several,
  **All** edits every element, "Apply all settings from" copies one element), and each `@` row has ⇄
  (`Config.ApplyRowToAll`). Page header 96: icon, title, description, setting count, state, Reset module, switch.
* **Preview dock:** the page's preview card (or Home's side panel, `page.side`) moves into the dock on wide windows
  (`page:SetDocked`); stages wider than the dock scale down (`stage:Fit(width)`, `width` per preview kind).
* **Previews** (`Phoenix_UI_Options/Previews/*.lua`): `ns.Previews:Register(kind, { module, height, build(stage, m) })`. The build
  creates plain frames with fixed sample data and returns a redraw function that calls the module's own style
  methods (for example `NamePlates:StyleBar`, `UnitFrames:StyleTexts`, `CastBars:FillColor`). Redraws on
  `PUI_SETTING_CHANGED` for the module or General, on `PUI_THEME_CHANGED` and on show. No secure templates, no
  unit tokens, nothing that can taint. Kinds: theme, nameplate, unitframe, groupframe, castbar, actionbar, aura, datatext,
  tooltip, chat.
* **Layout:** page padding 24, card gap 16, card header 42, rows 46 (more with a description), cells 60 / 38,
  controls 26–28 high.
  From 760 px of content width cards flow into two columns (each card goes to the shorter column; `wide`
  headers and a lone card span both).

## 10. Edit Mode support

* Our movable frames register through `ns.EditMode:Register(frame, { name = L.X, default = { point = "CENTER", x = 0, y = 0 }, settings = { … } })`. This wraps **LibEditMode** (`AddFrame`, `AddFrameSettings`, layout callbacks). Positions are stored **per Edit Mode layout** in `global.layouts[layoutName][frameKey]`, so they follow the user's Blizzard layout switches.
* Blizzard frames: we never call `SetPoint` on frames managed by `EditModeManagerFrame`. Action bars in Phoenix mode are the exception: their buttons are re-parented by a restricted snippet into Phoenix headers, and the headers are placed by Layout mode (Movers store delegate, `modules.ActionBars.bars.<key>`), not Edit Mode. Edit Mode's own bar settings (e.g. number of buttons shown) can still hide buttons. Size and position settings for Blizzard systems are left to Edit Mode. Our config page links to it with an "Open Edit Mode" button (`ShowUIPanel(EditModeManagerFrame)` out of combat).
* Unit frames in Phoenix mode are the second exception: Blizzard's player, target, focus and boss frames are parked (events off, hidden, re-parented to a hidden frame out of combat); the Phoenix frames are placed by Layout mode (store delegate saving into `modules.UnitFrames.units.<key>`). Blizzard's target, focus and boss cast bars are lent to each Phoenix frame's cast anchor in Blizzard cast bar mode; in Phoenix mode (S9) Phoenix bars use the anchors and the player's Edit Mode cast bar is parked. Phoenix buff/debuff blocks (S9) move in Layout mode, not Edit Mode (`BuffFrame`/`DebuffFrame` are parked).
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
| `brand` (logo/wordmark) | `Cinzel-Bold.ttf` (`CinzelBold`) | 20 | — |
| `title` (page titles) | `Inter-Bold.ttf` (`InterBold`) | 17 | — |
| `heading` (section headers, uppercase) | `Roboto_Condensed-Bold.ttf` | 11 | — |
| `body` (labels, controls) | `Roboto-Medium.ttf` | 12 | — |
| `desc` (descriptions) | `Roboto-Regular.ttf` | 11 | — |
| `number` (values, timers) | `Roboto_Condensed-SemiBold.ttf` | 12 | — |
| `small` (badges, footer) | `Roboto_Condensed-Medium.ttf` | 10 | — |
| `unit` (in-world frames, nameplates, bars) | `Roboto_Condensed-SemiBold.ttf` | per element | shadow 1,-1 or `OUTLINE` |
| `combat` (big timers, CDs) | `Roboto_Condensed-Bold.ttf` | per element | `OUTLINE` |

Shipped font set: 89 files in 36 families, listed with their licences in `Media/Fonts/FONTS.md`. Roboto and Roboto Condensed (Apache 2.0) are hand-listed in `Core/Media.lua`; the rest is generated by `tools/media/gen_fonts.py` into `Core/FontData.lua` (fonts with a Reserved Font Name are shipped unmodified, the others are subset to Latin/Greek/Cyrillic). The keys `Inter` and `Cinzel` saved by 2.0 builds alias `InterBold` and `CinzelBold`. On ruRU clients fonts without Cyrillic are hidden and fall back to Roboto (brand text excepted). Expressway, PT Sans Narrow, AvantGarde and the other legacy fonts were dropped (licence unclear or unused). koKR/zhCN/zhTW clients fall back to `STANDARD_TEXT_FONT`. All shipped fonts and bars are registered with LSM under `Phoenix *` names.

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

* **No `Core/Settings.lua`.** Boot and slash live in `Core/Init.lua` (loaded last from the TOC so every module is registered); the Blizzard landing page and compartment entry live in `UI/Launcher.lua`, which stays in Phoenix_UI so they work before the settings addon is loaded.
* **No per-module XML.** `Modules/Modules.xml` lists `<Module>.lua` (and helpers) for every module; option schemas are listed in `Phoenix_UI_Options/Phoenix_UI_Options.toc`.
* **No empty locale stubs.** Only `enUS.lua` ships; `ns.RegisterLocale` accepts other locales when translations exist. `tools/check_locales.py` keeps enUS complete and free of unused keys.
* **Positions:** Edit Mode owns layout. Phoenix-owned frames that belong in Edit Mode (data bar, spell history) register with LibEditMode and are stored per Edit Mode layout. The Movers module (§16) positions only a verified list of Blizzard frames Edit Mode does not manage, plus small Phoenix frames such as the bug indicator; it never touches an Edit Mode system.
* **Unit frames (2.0 S8).** `Modules/UnitFrames/Spawn.lua` creates `SecureUnitButtonTemplate,PingableUnitFrameTemplate`
  buttons (`PhoenixUI_UF_<unit>`, `unit`, `*type1=target`, `*type2=togglemenu`, `toggleForVehicle` on player/pet,
  `RegisterUnitWatch`, listed in `ClickCastFrames`) inside one holder per unit key, always created and placed through
  `ns.Combat:Run`. Blizzard's frames are parked: `UnregisterAllEvents`, hidden and re-parented to a hidden frame
  (their bars' events too; `BossTargetFrameContainer` stops listening); `CompactArenaFrame` only when Phoenix arena
  frames are on. `TotemFrame` is re-homed under the Phoenix player frame. Blizzard's target/focus/boss spell bars are
  lent to our `CastAnchor` (the anchor answers `ShouldAnchorSpellBarToAuraContainer`/`powerBarAlt` for their
  `AdjustPosition`, a `hooksecurefunc` puts them back on it); `M:CastBarAnchor(key, index)` is the S9 hook point.
  Secret values: every health/power/absorb number goes straight to `StatusBar:SetValue`/`SetMinMaxValues` or
  `FontString:SetFormattedText` (tags compile to one format string plus getters, `AbbreviateNumbers` with custom
  breakpoints, `BreakUpLargeNumbers`); health colour by health left and "hide at full" use
  `UnitHealthPercent(unit, true, curve)` colour/alpha curves; range uses `SetAlphaFromBoolean`; possibly-secret
  facts (class, leader, role, PvP, threat, AFK, power) are read through `Secret.IsSecret` guards and skipped when
  secret. Aura icons come from `C_UnitAuras.GetUnitAuras` with dispel colours from `GetAuraDispelTypeColor` and a
  curve; counts from `GetAuraApplicationDisplayCount`; durations from `GetAuraDuration` duration objects. Class
  pips fall back to one bar when the count is secret. Not built: arena diminishing returns (secret payloads), spell
  cost prediction.
* **Cast bars (2.0 S9).** `Modules/CastBars` builds plain StatusBars (no secure template: cast bars are never
  clicked) per unit key, on the unit frame's `CastBarAnchor` or a free holder (`Movers:Register`, `cb.<key>`).
  `PlayerCastingBarFrame`, and in Phoenix mode the spell bars S8 lent to the anchors, are parked out of combat.
  Secret values: the fill and time come from `UnitCastingDuration`/`UnitChannelDuration` duration objects
  (`StatusBar:SetTimerDuration`, `C_DurationUtil` text bindings); interruptible vs locked colours use
  `SetVertexColorFromBoolean`/`EvaluateColorFromBoolean` on `notInterruptible`; the kick tick is a second
  StatusBar driven by `C_Spell.GetSpellCooldownDuration` of the first known interrupt (per-game ID lists); the
  important-cast glow and the targeted edge use `SetAlphaFromBoolean`. Latency, ticks and empower stages are drawn
  only from plain values (`Secret.IsSecret` guards). Swing timer: `PLAYER_SWING` behind `ns:Supports("swingTimer")`
  (Forever); the GCD bar behind `gcdBar` (retail).
* **Group frames (2.0 S11).** `Modules/GroupFrames/Headers.lua` owns 12 headers made from Blizzard's
  `SecureGroupHeaderTemplate` (pets: `SecureGroupPetHeaderTemplate`, both present in 12.1.5 and Forever 1.60.1):
  `party`, `g1`…`g8` (sort by group), `raid` (one sorted header for role/class/name/index), `tanks`
  (`roleFilter = "MAINTANK,MAINASSIST"`, `groupBy = "ROLE"`) and `pets`. The pure `M.HeaderAttributes(profile,
  kind, index, groups)` turns a size profile into header attributes (`point`, `xOffset`/`yOffset`,
  `columnAnchorPoint`, `columnSpacing`, `unitsPerColumn`, `maxColumns`, `groupFilter`, `groupBy`/`groupingOrder`,
  `sortMethod`/`sortDir`); `M.ProfileFor(inRaid, count)` picks *party*, *raid* (≤20) or *large*, switched out of
  combat on roster changes. Buttons are `SecureUnitButtonTemplate,PingableUnitFrameTemplate`; the header's
  `initialConfigFunction` (restricted) sizes them from `phoenix-width`/`phoenix-height`, sets `*type1 = target`,
  `*type2 = togglemenu` and `toggleForVehicle`, then `CallMethod("PhoenixInit", name)`, where `UnitFrames:Build(nil,
  key, { frame = button })` dresses the button with the S8 parts (tags, bars, indicators, aura buttons, range)
  and adds it to `ClickCastFrames` for click-cast addons. Buttons are precreated out of combat (`startingIndex = 1 -
  n`, then `1`), so the header never makes one under lockdown. A button's `unit` attribute change re-points its
  events through `UnitFrames.WatchUnit(f, unit, extra)` (extra: `UNIT_PHASE`, `UNIT_OTHER_PARTY_CHANGED`,
  `UNIT_IN_RANGE_UPDATE`). Unit Frames exports used: `NewUnitSettings`, `WatchUnit`, `DispelCurve`, `ShowAura`,
  `ShowSampleAura`, `UNIT_SOURCES["group.<profile>"]` (the tanks/pets keys proxy the raid profile with their own
  size). Secret values: health/absorbs/heals and range as in Unit Frames (`SetValue`, `UnitInRange` through
  `SetAlphaFromBoolean`); dispel colours come from a `C_UnitAuras.GetAuraDispelTypeColor` curve and only reach
  `SetVertexColor`; auras are listed with filter words (`HELPFUL|PLAYER|RAID_IN_COMBAT`, `HELPFUL|RAID`,
  `HARMFUL|RAID` (yours to dispel), `HARMFUL|RAID_PLAYER_DISPELLABLE` (the group's), `HARMFUL|CROWD_CONTROL`, `HELPFUL|BIG_DEFENSIVE`,
  `HELPFUL|EXTERNAL_DEFENSIVE`) and never compared; `UnitPhaseReason` and roles pass `Secret.IsSecret` first.
  Private auras: `C_UnitAuras.AddPrivateAuraAnchor` per slot, removed when the unit changes. Parking:
  `PartyFrame`, `CompactRaidFrameContainer` (and `CompactRaidFrameManager` on request) are reparented to a hidden
  frame out of combat and re-parked on zone/difficulty changes. Not built: placing yourself first/last (only show or
  hide yourself), per-member custom indicator slots.
* **Cooldown Manager (2.0 S12).** `Modules/Tracker` builds on Blizzard's `Blizzard_CooldownViewer` (loaded on
  "standard, camelot", so retail and WoW Forever): the four viewers are `GridLayoutFrame` Edit Mode systems whose
  items come from `itemFramePool`. Phoenix never moves, sizes or reparents a viewer (Edit Mode owns it, and the
  managed container also holds the action bars); it post-hooks `OnAcquireItemFrame` (style the item) and `Layout`
  (queue a re-layout for the next frame) and re-anchors the plain item frames onto its own anchor frame
  `PhoenixUI_CDM_<key>` (pure `M.Grid`/`M.Stack`), which sits on the viewer's edge (*Edit Mode*) or at a Layout-mode
  mover (*Phoenix mover*). Essential's overflow can hide or run in front of Utility. Behaviour post-hooks on each
  item: `RefreshIconDesaturation`, `RefreshSpellCooldownInfo` (swipe darkness, GCD swipe off only on a plain
  `isOnGCD`), `RefreshIconColor` (range tint), `OnCooldownDone` (`HookScript`; the ready glow only after a plain
  `isOnActualCooldown`), and `ActionButtonSpellAlertManager` `ShowAlert`/`HideAlert` (proc glow: Blizzard's or a
  Phoenix glow). Keybinds come from `C_ActionBar.FindSpellActionButtons` and the bound keys of the buttons showing
  those slots. Countdown numbers: Cooldown Text styles them unless a viewer claims them (`CooldownText:Claim`).
  Custom bars are Phoenix frames fed only through sinks: `C_Spell.GetSpellCooldownDuration`/`GetSpellChargeDuration`
  → `SetCooldownFromDurationObject`, `C_Spell.GetSpellDisplayCount` → `SetText`, `duration:IsZero()` →
  `C_CurveUtil.EvaluateColorValueFromBoolean` → `SetDesaturation` and `SetAlphaFromBoolean` (show modes, ready
  glow); items use plain `C_Item.GetItemCooldown`. Visibility (always/combat/target/either/never, mounted, vehicle,
  spec 1-4) and the fade set viewer and anchor alpha only. Reminders run out of combat; the aura-ID ones (flask,
  food, rune, raid buff) are behind `ns:Supports("cdmReminders")` (retail); oil, pet, healthstone and ready-check
  mana work on both clients.
* **Chat, Minimap, Tooltips (2.0 S13a).** `Modules/Chat` is four files: `Chat.lua` (defaults, URLs, copy, history,
  tab colours, the once-guard hooks), `Window.lua` (backdrop frame behind each chat frame, `SetFading`,
  `SetTimeVisible`, `SetMaxLines`, edit box place/skin, side buttons tucked by reparenting to a hidden frame, tab
  alpha through `ChatFrameUtil.SetTabAlphas`, combat hiding by alpha), `Messages.lua` (pure helpers plus one
  `ChatFrameUtil` message event filter and one sender name filter) and `Bar.lua` (chat bar, raid-marker picker).
  Restricted chat: Blizzard only calls addon filters for accessible messages and the filter also checks
  `Secret.IsSecret`; it returns `false, newMsg, author, arg3, shortChannel, ...` (arg4 for numbered channels only)
  and never writes chat globals (`CHAT_*_GET`, `ChatTypeInfo`). Timestamps, class colours and whisper mode are the
  game's CVars through `ns.Combat.CVarAccessors(name, "string")`. `Modules/Minimap`: shapes are mask textures
  (`Media/Textures/MinimapRect50-90`, generated by `tools/media/gen_textures.py`); `GetMinimapShape` is defined when
  not round; a holder band carries the border and our texts; Blizzard's elements (`M.ELEMENTS` resolvers) are
  tucked by reparenting to a hidden frame and given back the same way; `MinimapCluster` is never moved or scaled
  (Edit Mode). Migration step 5 converts `Minimap.square` to `Minimap.shape` (`Mg.CONVERTS`). `Modules/Tooltip`:
  `Tooltip.lua` owns the skin, anchoring (`GameTooltip_SetDefaultAnchor` post-hook; MOVER uses the Layout-mode
  anchor `PhoenixUI_TooltipAnchor`), scale and the `TooltipDataProcessor` post-calls (unit, item, spell, aura,
  currency, quest, achievement, mount); `Extras.lua` builds the lines. Every unit value passes `M.Plain`
  (`Secret.IsSecret`) first; NPC IDs come from `UnitCreatureID`, never a GUID; inspect is throttled (1.5 s), never in
  combat or with the Inspect window open, cached per GUID for 5 minutes, and refreshes the open tooltip with
  `RefreshData` on `INSPECT_READY`.
* **Group Finder (2.0 S15).** `Modules/GroupFinder` (retail; feature `lfgList`, because Blizzard_GroupFinder's TOC
  excludes the Forever game type): `Expression.lua` is our own tokenizer, parser and evaluator for the filter
  language (no `loadstring`, rule 4; unknown or secret fields compare as "unknown" and pass). `GroupFinder.lua`
  turns each result into a plain record (`M:Record`, cached until `LFG_LIST_SEARCH_RESULT_UPDATED`) from
  `C_LFGList.GetSearchResultInfo` / `GetSearchResultMemberCounts` / `GetSearchResultPlayerInfo` /
  `GetSearchResultEncounterInfo` / `GetApplicationInfo` and the saved-instance list; values that are secret read as
  nil. `Filter.lua` holds the checks (each with its reason), the sorts, presets and `M:PushGameFilter`, which copies
  `C_LFGList.GetAdvancedFilter()` and saves it back with our difficulty/role/rating fields only when one of those
  settings changes. `List.lua` decorates from post-hooks only: `LFGListSearchEntry_Update` (alpha, outline,
  score/key text, class strip on our own child frames), `LFGListUtil_SetSearchEntryTooltip` (extra lines) and
  `LFGListApplicationViewer_UpdateApplicantMember` (best key, spec icon, tint). It never writes
  `LFGListFrame.SearchPanel.results` or any Blizzard field, never reorders, removes or selects results and never
  calls `C_LFGList.ApplyToGroup` (undocumented). `Panel.lua` is our own frame anchored to `PVEFrame` (not its
  child), shown from `SearchPanel` OnShow/OnHide hooks. `Helpers.lua` uses `SecureActionButtonTemplate` buttons of
  type `click` (delegate `clickbutton` = Blizzard's Sign Up, the dialog's Sign Up or `LFDRoleCheckPopupAcceptButton`)
  under a `[combat] hide` state-driven holder, bound with `SetOverrideBindingClick` out of combat
  (`ns.Combat:Run`), so every sign-up is a hardware click on Blizzard's own button (docs/GROUP_FINDER.md).
* **Quests and Phoenix_UI_Data (2.0 S14).** `Modules/Quests`: `Quests.lua` loads the data addon on demand
  (`C_AddOns.LoadAddOn("Phoenix_UI_Data")`, global `PhoenixUI_QuestData`, only while a pin or tooltip option is on),
  decodes packed per-map records lazily (`M.Decode`, `M:QuestsOnMap`, `M:Record`, `M:QuestsFromNPC`) and filters
  them with `M:IsAvailable` (completed, in log, side/race/class, level, prerequisites, trivial). `Tracker.lua`
  restyles Blizzard's objective tracker without owning it: `SetFont` on the `ObjectiveTrackerHeaderFont` /
  `ObjectiveTrackerLineFont` font objects, title and bar dressing from `hooksecurefunc(module, "EndLayout")` per
  tracker module, a post-hook on `OnBlockHeaderClick` for focus, width/height only out of combat and only when
  set (0 leaves Edit Mode's size), `SetCollapsed` in instances out of combat and alpha-only fading in combat
  (AGENTS rule 9). `Pins.lua` puts plain buttons on `WorldMapFrame:GetCanvas()` from post-hooks on
  `OnMapChanged` / `OnCanvasScaleChanged` (no data provider is added) and on the minimap by world distance
  (`C_Map.GetWorldPosFromMapPos`, `C_Minimap.GetViewRadius`, rotation from `GetPlayerFacing` when plain).
  `Arrow.lua` targets a clicked pin (also `C_Map.SetUserWaypoint`), the user waypoint or the super-tracked quest.
  `Auto.lua` answers `GOSSIP_SHOW` / `QUEST_GREETING` / `QUEST_DETAIL` / `QUEST_PROGRESS` / `QUEST_COMPLETE` with
  plain quest-dialog calls (Shift pauses; no money quests; `M:PickReward` by vendor value or `Sim:ItemResult`).
  `Phoenix_UI_Data/` is generated by `tools/questdata/build_questdata.py` (docs/QUEST_DATA.md); each slice file
  returns early on the other client, so one TOC file list serves both games.
* **Bags, Data Texts, Skins (2.0 S13b).** `Modules/Bags/Window.lua` is the optional Phoenix bag window
  (`Bags.view = "phoenix"`, reload): our own `ContainerFrameItemButtonTemplate` buttons parented to per-bag holder
  frames (`SetID(bag)`, `IsCombinedBagContainer` false) so Blizzard's click, drag, use and tooltip code runs
  unchanged; sections come from plain `C_Container` data (`M.Categorize`, `M.Sections`), sort is
  `C_Container.SortBags`, search is `BagSearchBoxTemplate`. Open/close follows Blizzard's own functions through
  post-hooks (`OpenAllBags`, `ToggleBag` …) and `ContainerFrameContainer` is reparented to a hidden frame only
  in the Phoenix view (AGENTS rule 9). Bank and warband bank slots are styled from post-hooks on `BankPanel`
  (`GenerateItemSlotsForSelectedTab`, `RefreshAllItemsForSelectedTab`). `Modules/DataTexts`: two panels
  (`order`, `order2`), `TIPS` tooltip builders (hidden in combat when `combatTips` is off), gold saved per
  character in `ns.DB.sv.global.gold`, warband money via `C_Bank.FetchDepositedMoney` under `pcall`; `Bar.lua` is
  the experience/reputation bar (`DataTextsXP` in Edit Mode). `Modules/Skins`: `M.WINDOWS` (24 entries with
  optional `addon` and `feature` fields) styled by `window()` (Blizzard art hidden, backdrop and border specs,
  title strip, close glyph, tabs re-painted from a `PanelTemplates_SelectTab` post-hook); load-on-demand windows on
  `ADDON_LOADED`. `UI/Widgets/Chips.lua` `W:OrderChips` is the shared drag-to-reorder chip row (data-text panels,
  bag categories). Migration step 6 moves `Bags.countSize` to `Bags.count.size`.
* **Nameplates (2.0 S10).** `Modules/NamePlates` builds one plain plate per Blizzard base plate (kept in a weak
  side table, nothing written onto Blizzard frames), parented to the base and only for plates
  `C_NamePlate.GetNamePlateForUnit(unit, false)` returns (forbidden plates are never asked for); widget-only plates
  stay Blizzard's. Blizzard's `UnitFrame` is faded to alpha 0 and back on removal. One event owner per
  `nameplateN` token (`ns.Events:OnUnit`). Target, focus and mouseover are found by comparing plate frames, never
  `UnitIsUnit` on a secret answer. The cast bar is a `CastBars:BuildBar` bar with key `plate.<kind>`; CastBars reads
  its settings through `CastBars.SOURCES` (the NamePlates style), Unit Frames' tags/class power/aura buttons through
  `UnitFrames.UNIT_SOURCES` and its exported helpers. Secret values: health and absorbs go to `SetValue`, texts to
  tag format strings, health colour by health left and the execute overlay to `UnitHealthPercent(unit, true,
  curve)` colour/alpha curves; a secret reaction falls back to `SetStatusBarColor(UnitSelectionColor(unit))`;
  threat, role, classification and quest facts pass `Secret.IsSecret` first. Auras use `C_UnitAuras` filter words
  (`HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY`, `HARMFUL|IMPORTANT`, `HARMFUL|CROWD_CONTROL`,
  `HELPFUL|RAID_PLAYER_DISPELLABLE`, `HELPFUL|IMPORTANT`); aura data is never compared. Important casts use
  `C_Spell.IsSpellImportant` through `EvaluateColorFromBoolean`. Plate size (`C_NamePlate.SetNamePlateSize`) and
  hit-test insets (`C_NamePlateManager.SetNamePlateHitTestInsets`) are restricted: `ns.Combat:Run`, post-hooked on
  `NamePlateDriverFrame.UpdateNamePlateSize`. Stacking uses `GetCVarBitfield`/`SetCVarBitfield` on
  `nameplateStackingTypes` (`Enum.NamePlateStackType`); per-zone contexts own `nameplateShowFriendlyPlayers` and
  `nameplateShowEnemyMinions` only while enabled. Not built: NPC titles (no plain API), true click-area removal
  for *Hide enemies out of combat* (visuals fade; the game keeps the plate clickable).
* **Player auras (2.0 S9).** Secure aura headers (`SecureAuraHeader.lua`) load with `[AllowLoadGameType classic]`
  only, so on 12.1.5 and Forever 1.60.1 `Modules/Auras/Containers.lua` uses `CreateFrame("AuraContainer", …,
  "CustomAuraContainerTemplate")` (Blizzard_AuraContainer): one container per block, `AddAuraGroup` with the
  filter, `AuraContainerSortMethod`/`AuraContainerSortDirection`, flow layout, max frame count and
  `AddItemEnchantment` for weapon enchants. Buttons are dressed in `initializeFrame` (icon, duration text with a
  colour curve binding, cooldown, count, dispel-type textures, cancel button, tooltip anchor); after that the game
  restricts access while auras are secret, so every later restyle runs in `pcall`. Cancelling is Blizzard's own
  OnClick (works in combat). Container settings change through `ns.Combat:Run`. Private aura anchors use
  `C_UnitAuras.AddPrivateAuraAnchor`. If the container API is missing, Phoenix leaves `BuffFrame`/`DebuffFrame`
  alone and says so in debug.
* **Action bars (2.0 S7).** `Modules/ActionBars/Bars.lua` creates one `SecureHandlerStateTemplate` header per bar
  (`PhoenixUI_ActionBar_<key>`) and parks Blizzard's bars under a hidden frame. Addon code never touches a Blizzard
  button: it writes the layout (`"x,y;"` points, size, padding, page, flyout direction, show-empty bit) as header
  attributes, sets frame refs, and runs the `LAYOUT` restricted snippet with `SecureHandlerExecute`, always through
  `ns.Combat:Run`. Bar 1 pages through a state driver (`M.PageDriver`: vehicle/override/possess/temp shapeshift,
  modifier pages, manual pages, skyriding `[bonusbar:5]` behind `ns:Supports("skyriding")`, form bars) and the
  `_onstate-page` snippet sets every button's `actionpage`. Page arrows are `SecureActionButtonTemplate` macros
  (`/changeactionbar` with `[bar:n]`). Visibility is a `RegisterStateDriver` macro; fading is alpha only. Styling
  post-hooks Blizzard's own updates (`UpdateButtonArt`, `UpdateHotkeys`, `UpdateUsable`, the range indicator, the
  spell alert and assisted-combat managers) so Phoenix never calls a secure button method. Cooldown colour by time
  left uses `C_DurationUtil` duration text bindings, opt-in and `pcall`-guarded.
* **Removed with no replacement in Phoenix:** chat emoji, arena dampening display (aura data is restricted in arenas), a Phoenix minimap size slider (Edit Mode owns the size; the Minimap page links to it). Mouseover/out-of-combat bar fading is back with S7 (Phoenix bars). Brought back on 12.x APIs: the M+ timer (`MythicPlus/Timer.lua`, non-secret `C_ChallengeMode`/`C_ScenarioInfo` data) and chat history (typed lines only, not received messages). Combat-log features are replaced by Blizzard options exposed as toggles (Cooldown Manager, floating combat text v2, damage meter, countdown numbers).
* **Details!:** optional, never a dependency. The Damage Meter page offers a one-click "Style Details!" button that calls Details' public instance API inside `pcall`; it is never applied automatically because it rewrites Details' own saved settings.
* **Icons (§14):** one Phosphor duotone set via `ns.Icons`; brand art via `ns.Icons:Brand`.
* **Checks:** `luacheck .` (generated 12.1.5 std), `tools/check_api.py` (methods/events/CVars/templates/atlases vs. the 12.1.5 reference, forbidden patterns, TOC/XML completeness and case), `tools/check_ids.py`, `tools/check_locales.py`, and `tools/smoke/harness.lua` (offline load + boot + every settings page). `tools/check_flavors.py` runs them for retail and again for WoW Forever (§17). All run in `.github/workflows/luacheck.yml`.

## 14. Icon system

* **Source:** [Phosphor Icons](https://phosphoricons.com) 2.1.1, duotone weight only (MIT, `Media/Icons/LICENSE`). The SVGs
  live in `tools/media/phosphor/`; `tools/media/icon_map.py` maps Phoenix names (`home`, `cat-combat`, `delete`, `fps` …)
  to glyphs. The list is append-only so atlas cells stay stable. Micro-controls (`close`, `check`, `add`, chevrons,
  `resize`) render the line layer only; the duotone fill is 30 % opacity.
* **Build:** `python3 tools/media/gen_icons.py` rasterizes white glyphs with cairosvg into three atlases (uncompressed
  32-bit TGA, power of two, no edge over 1024 px, 16 columns, clean alpha): `Icons24` (24 px cells, 512×256),
  `Icons48` (48 px, 1024×512), `Icons64` (64 px, 1024×512), each cell with a transparent gutter so bilinear sampling never bleeds. It also writes `Core/IconData.lua`, the
  emblem (`Emblem64/128/256`) and logo (`Logo512/1024`), and the PNGs used by the doc mockups.
* **Why tiers:** WoW does not mipmap addon TGAs. `ns.Icons` converts the on-screen size to physical pixels
  (`size × effectiveScale ÷ PixelUtil.GetPixelToUIUnitFactor()`) and picks the smallest tier that covers it, so
  downsampling never exceeds ~2×. A 16-unit icon uses 24 px cells at 1080p and 48 px cells at 4K/1.15; page
  headers use 64 px cells. (2.0 shipped a 96 px tier at 1024×2048 in RLE TGA; nothing rendered on the user's
  12.1.5 client, so the generator now refuses edges over 1024 and writes uncompressed files.) Tiers are re-picked on `UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED` and when a frame's
  own scale changes (data bar).
* **API:** `Icons:Create(parent, name, size, token, layer)`, `Apply`, `Tint(tex, token, alpha)`,
  `SetState(tex, "hover"|"active"|"danger"|"disabled")`, `Markup(name, size, token)` for FontStrings,
  `Brand(tex, "emblem"|"logo", width)` and `Has`. `W.Icon` and `W.Color` route through it, so icons repaint
  with the theme. Unknown names show the `question` glyph and are recorded in `Icons.missing`.
* **Checks:** `tools/check_api.py` rejects unknown literal icon names, unused glyphs, missing atlas/brand files,
  dead files under `Media/` and unused `Media.textures` keys. The smoke harness fails on any unknown icon request
  and asserts the 48/64 px tier choice at 4K and that no atlas edge exceeds 1024 px.

## 15. Error catcher (Bugs)

`Core/Errors.lua` (`ns.Errors`) loads with Core, so it sees errors from the moment Phoenix's files run. The
Bugs module (`Modules/Bugs`) is only the UI on top. The stored shape is a contract with the Phoenix Uploader and
VQ8S.com; see `docs/BUG_REPORTS.md`.

* **Lua errors.** In 12.x `Blizzard_ScriptErrors` installs `HandleLuaError` with `seterrorhandler`
  (`AddLuaErrorHandler` asserts `issecure()`, so addons cannot use it). We read `geterrorhandler()` first and
  install a wrapper that captures and then always returns `previous(msg, ...)`, so Blizzard's window and any
  other handler still run. A re-entrancy flag and `pcall` keep a fault in the catcher from recursing or from
  swallowing the original error. We never restore or replace the handler later; disabling the module only stops
  recording.
* **Stack level.** Same arithmetic as Blizzard's `GetErrorData`:
  `GetCallstackHeight() - (GetErrorCallstackHeight() - 1)`, falling back to level 4. `debugstack(level)` and
  `debuglocals(level)` are captured there. Locals are skipped while `C_InstanceEncounter.IsEncounterInProgress()`
  is true (cheaper, and secret values are likeliest there).
* **Events.** `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` (payload addon, function) are recorded as
  `kind = "taint"` with the addon as `source`; `LUA_WARNING` (payload warning text) as `kind = "warning"`.
  All three fire synchronously, so the stack is useful after trimming our own frames.
* **Midnight.** Any message may be a secret value: text goes through `canaccessvalue`/`ns.Secret` before use and
  becomes `"<secret value>"` otherwise. `|K` kstrings are neutralised the way Blizzard does (`gsub("|([kK])", "%1")`).
  Messages, stacks and locals are truncated (2000/6000/6000 chars).
* **Dedupe and floods.** The hash is djb2/×131 over the message and first three stack frames with numbers and
  addresses stripped (16 hex chars), so the same bug on another line or table address counts as one report. A
  repeat in the same session bumps `count`/`lastSeen`. A token bucket (10/s, burst 30) drops floods and counts
  them in `Errors.dropped`.
* **Attribution.** `source` is the first `Interface/AddOns/<name>/` in the message or stack (`Blizzard_*` →
  `"Blizzard"`), else `"Unknown"`.
* **BugGrabber.** `!BugGrabber` is an OptionalDep, so it loads first, installs its handler and replaces
  `seterrorhandler` with a no-op (it also takes over the blocked-action and warning events). When the global
  `BugGrabber` exists we stand down (no handler, no events) and consume its results. BugGrabber 12.x has no
  CallbackHandler: every capture, new or repeat, ends in
  `EventRegistry:TriggerEvent("BugGrabber.BugGrabbed", tostring(errorTable))`, and `BugGrabber:GetErrorByID(id)`
  returns the table. Each announcement counts once (a weak map ties BugGrabber's table to our report). At
  ADDON_LOADED we import this session's entries from `BugGrabber:GetDB()` that were caught before we loaded.
  `LUA_WARNING: ` entries become `warning`, `[ADDON_ACTION_…]` entries `taint`. Older BugGrabber builds with
  `setupCallbacks`/`RegisterCallback` still get the `BugGrabber_BugGrabbed` callback. Without BugSack, Phoenix
  triggers `BugGrabber.DisplayRegistered` (as BugSack does) so BugGrabber stops printing its own chat line.
  (2.0 only knew the CallbackHandler event; with BugGrabber 12.x the sack stayed empty.) BugGrabber and BugSack
  are All Rights Reserved: Phoenix only uses their public interface, no code is copied.
* **Before we load.** Without BugGrabber, Blizzard's `HandleLuaError` (the handler we chain to) has already put
  earlier errors into `ScriptErrorsFrame.errorData` (or `ScriptErrors.unhandledErrors` before the frame exists);
  they are imported once, just before our handler goes in, with their counts.
* **Scope.** `scope = "all"` (default) or `"phoenix"`: only reports whose `source` is `Phoenix_UI` are kept.
* **Status.** `Errors:GetMode()` (`buggrabber`/`handler`), `Errors:OwnsHandler()`; `Bugs:CaptureState()` adds
  `lost` when another addon replaced our handler. Shown on the Bugs page and in the viewer footer.
* **Storage.** `PhoenixUIBugsDB` (account-wide): `schema`, random 16-hex `installId`, `session` incremented once
  per login/reload, `reports` newest last, capped (default 500, 100–500 in settings). Reports captured before
  ADDON_LOADED are buffered and placed on open.
* **UI.** Listeners are notified on the next frame (`C_Timer.After(0)`), never inside someone else's error path.
  The viewer (`PhoenixUI_Bugs`, closes on Escape) lists reports with a search box, an addon filter and a session
  filter (this/previous/all or any past session with reports), shows a detail pane with a selectable report text
  (Copy selects it for Ctrl+C), delete and mark-as-reported (`reported = true`, dimmed in the list; ignored by
  the uploader), prev/next, clear (the session, or exactly what the filters show) and a link to the upload
  settings. A data-bar segment, a minimap indicator (movable via Movers) and the
  addon-compartment entry (right-click) show the count and pulse on new errors. Optional chat notice with an
  `addon:Phoenix_UI:bugs` link and an optional sound (10 s gap).
* **Blizzard popup.** The "Blizzard error window" option is the `scriptErrors` CVar, which
  `ScriptErrorsFrame` already checks (`ShouldHideErrorFrame`). The blocked-action StaticPopup cannot be
  suppressed safely and is left alone.

## 16. Movers

`Modules/Movers` moves, scales and fades frames that Edit Mode does not reach. Every entry was checked against
the 12.1.5 FrameXML (`/workspace/ref`).

| Key | Frame | Notes |
|---|---|---|
| `ZoneText`, `SubZoneText` | `ZoneTextFrame`, `SubZoneTextFrame` | FadingFrame drives alpha → position/scale only |
| `Errors` | `UIErrorsFrame` | Barbershop saves its current point on show and restores it on hide, so ours survives |
| `Alerts` | `AlertFrame` | 10×10 anchor for the alert queue; position only |
| `TopWidgets` | `UIWidgetTopCenterContainerFrame` | Score/objective widgets; deferred in combat |
| `BossBanner` | `BossBanner` | Animated alpha → position/scale only |
| `EventToasts` | `EventToastManagerFrame` | `UpdateAnchor` re-anchors it; re-applied with `hooksecurefunc` |
| `ReadyCheck` | `ReadyCheckFrame` | Calls `SetAlpha(1)` on show → no alpha |
| `BugIndicator` | Phoenix minimap bug button | registered with `Movers:Register` |
| `uf.<unit>` | Phoenix unit frame holders (player, target, targettarget, focus, focustarget, pet, boss, arena) | store delegate saving into `modules.UnitFrames.units.<key>` (point, x, y, scale); Phoenix mode only |
| `cb.<key>`, `cb.swing` | Phoenix free cast bars (player, target, focus, pet, boss, arena) and the Forever swing timer | store delegate saving into `modules.CastBars.bars.<key>` / `swing`; Phoenix mode only |
| `auras.buffs`, `auras.debuffs`, `auras.enchants`, `auras.private` | Phoenix aura blocks | store delegate saving into `modules.Auras.headers.<key>`; Phoenix mode only |
| `ab.<bar>`, `ab.vehicle` | Phoenix action bar headers, vehicle exit | `Movers:Register(key, frame, label, store)`: the store delegate (`active/get/set/apply/reset`) saves into `modules.ActionBars.bars.<key>`, not `Movers.frames`; Phoenix mode only |

**Excluded, and why.** Everything with an Edit Mode system: Blizzard's action bars (Phoenix bars are ours, above), unit frames, minimap, buffs/debuffs,
objective tracker, loot, talking head, vehicle seat, vehicle leave button, durability, encounter bar (including
`UIWidgetPowerBarContainerFrame`/`PlayerPowerBarAlt`), extra abilities, loss of control, raid warnings, timer bars
(`MirrorTimerContainer`), archaeology bar, status tracking bars, bags, micro menu, chat, tooltip anchor, damage
meter, cooldown viewer, personal resource display, encounter events. `UIWidgetBelowMinimapContainerFrame` (right
managed: UIParent lays it out every update), `TicketStatusFrame` (placed by the buff-frame status tray),
`GhostFrame` (secure, anchored to the top-center widgets) and full-screen helpers (`AutoFollowStatus`,
`ActionStatus`) are also left out.

* **Guard.** `IsManaged(f)` refuses any frame with `system` or `isManagedFrame`. Positions are applied with
  `ClearAllPoints`/`SetPoint` from outside; we never call `SetMovable`, `StartMoving` or `SetScript` on a Blizzard
  frame and never assign fields on it. Protected frames are deferred through `ns.Combat:Run`.
* **Unlock mode.** `/pui movers` or the settings page: Phoenix-styled overlays (drag on the overlay, wheel scale,
  Shift+wheel alpha, right-click reset, arrow keys nudge while hovered, Escape locks), an optional grid with snap
  and a toolbar (frame cycle, nudge buttons, scale/opacity sliders, reset, done). Keyboard input is enabled only
  while an overlay is hovered (no `SetPropagateKeyboardInput`). Unlocking is refused in combat, combat start and
  Edit Mode entry (`EditMode.Enter`) lock it.
* **Storage.** Per profile in `modules.Movers.frames[key] = { point, x, y, scale, alpha }`. Offsets are UIParent
  units from the nearest screen third, so positions survive UI scale and resolution changes.

## 17. Games (flavours): retail and WoW Forever

Phoenix is one code base for the two games that share Mainline's UI and secret rules: retail (Midnight 12.1.5,
`Phoenix_UI.toc`) and WoW Forever (1.60.1, interface 16001, `Phoenix_UI_Forever.toc`). Research and the measured
API differences: `docs/research/wow-forever.md`.

* **TOCs.** The client picks `<Addon>_Forever.toc` on Forever and `<Addon>.toc` elsewhere. Both list the same files
  in the same order; only `## Interface` differs, so `tools/gen_tocs.py` writes the Forever ones and `check_api.py`
  fails when they drift. Never edit a `_Forever.toc` by hand.
* **Detection.** `Core/Flavor.lua` (loaded right after `Namespace.lua`) sets `ns.flavor` from `GetBuildInfo()`'s
  interface number (16000–19999 = Forever) and `ns.gameName` for Diagnostics.
* **Features, not flavours.** Code never asks "is this Forever?"; it asks `ns:Supports(feature)`. `ns.FEATURES`
  maps a feature to the flavours that have it (`mythicplus`, `vault`, `sim`: retail) or to a runtime check
  (`encounterTimeline`/`encounterWarnings`: the game's `IsFeatureAvailable()`; `specSelection`:
  `C_SpecializationInfo.IsSpecSelectionEnabled`, Forever-only). `"!feature"` means "where it is missing".
* **Modules** take `feature = "…"`: without it the module is `unavailable` and `hidden` (never initialized or
  enabled, absent from the sidebar, search, Home, presets and the module picker; `Config:Show` falls back to Home),
  while its saved settings stay so a profile moves between the games unchanged. `descWithout = { feature, desc }`
  swaps the card text.
* **Option rows** take `feature = "…"`; `ns:RegisterOptions` drops them (a `tab` row takes its whole tab), keeping
  row identity when nothing is dropped. Sidebar groups take `without = { feature, label, icon }`.
* **Checks per game.** `.luacheckrc` defines `wow` and `wowf` stds; `PUI_FLAVOR=forever` points `check_api.py` and
  `check_ids.py` at `reference_forever_1.60.1.json` and `tools/ids/snapshot_forever.json`; the harness takes
  `forever` as its second argument and asserts every gate. `tools/check_flavors.py` runs all of it.

