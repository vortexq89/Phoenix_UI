# AGENTS.md — Phoenix_UI 2.0

Instructions for any AI agent or contributor working in this repository. Read this first, then
`docs/ARCHITECTURE.md` (the contract) and `docs/AUDIT.md` (what the legacy code did and why it is being replaced).
Scoped rules live in `.cursor/rules/*.mdc`.

## 1. Target

| | |
|---|---|
| Game | World of Warcraft **Retail**, Midnight; and **WoW Forever** (same Mainline UI, ARCHITECTURE §17) |
| Patch / TOC | **12.1.5 → `## Interface: 120105`**; Forever **1.60.1 → 16001** (`*_Forever.toc`, generated) |
| Build | **12.1.5.70448** (wago.tools `wow`, 2026-10-16); Forever **1.60.1.70532** (`wowf`) |
| Lua | 5.1 (WoW dialect) + 12.1.5 natives (`string.startswith/endswith/split/trim`, `table.contains/count`, `math.clamp/round/lerp` …) |
| Not targeted | Classic (Era, Anniversary, Mists …), PTR (12.1.7 is on `wowt` — do not use PTR-only API) |

When a new patch ships: update the TOC number, regenerate the std (`tools/audit/README.md`), run luacheck, read the
wiki "Patch X API changes" page, and use `docs/PROMPTS.md` → *API update*.

## 2. How to verify an API (never from memory)

In order of authority:
1. `Blizzard_APIDocumentationGenerated` in Gethe **wow-ui-source `live`** (12.1.5.70448), e.g.
   `rg -n 'Name = "SetTimerDuration"' $PUI_REF/wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated`.
   The `SecretReturns`, `SecretArguments`, `SecretWhen*` and `HasRestrictions` fields tell you the Midnight behaviour.
2. FrameXML Lua for mixins/utils (`ActionBarActionButtonMixin`, `MenuUtil`, `Settings`, `TooltipDataProcessor`),
   but **only mainline files** (`$PUI_REF/mainline_files.txt`). `Classic/`, `Mists/`, `Cata/` subfolders do not exist on retail.
3. `api_dump.tsv` (`grep -P "\tName\t"`) for quick lookups, and the luacheck std.
4. warcraft.wiki.gg: *API change summaries*, *Patch 12.x.x/API changes*, *Secret values*. wago.tools for builds, CVars and DB2.

Anything only in `Blizzard_Deprecated*` (`.luacheck/deprecated_12.1.5.json`) is **unavailable**.
Never invent an API. If you can't find it in (1)–(3), it does not exist.

## 3. Hard rules (each one is a review blocker)

1. **No globals.** Only `PhoenixUIDB`, `PhoenixUIBugsDB` (error reports, `Core/Errors.lua`; shape fixed by `docs/BUG_REPORTS.md`), `GetMinimapShape` (square minimap convention) and the legacy SVs during migration. Every file starts with `local ADDON, ns = ...`. luacheck W111/W112/W121/W122 = fail.
2. **No taint.** Never assign to Blizzard globals or fields of Blizzard frames/tables, never replace Blizzard functions, never `SetScript` on Blizzard frames (use `HookScript`/`hooksecurefunc`). Protected frame changes only out of combat via `ns.Combat:Run`. See `.cursor/rules/taint-combat.mdc`.
3. **Secret-safe.** Treat health, power (non-player), auras, cooldowns, casts, unit names/GUIDs, threat and chat text as possibly secret. Use the display sinks; gate logic with `ns.Secret`. See `.cursor/rules/midnight-secrets.mdc`.
4. **Forbidden:** `COMBAT_LOG_EVENT(_UNFILTERED)`, `CombatLogGetCurrentEventInfo`, parsing combat-log chat, addon comms or `SendChatMessage` during lockdown, reading NPC IDs from GUIDs, `collectgarbage`, `EnumerateFrames`, disabling other addons, `loadstring` on user input outside the import path.
5. **No duplication.** Before you write a helper, search `Core/` and `UI/`. A second implementation of anything (event frame, timer wrapper, skin function, option widget, item-level lookup …) is a bug.
6. **Theme only.** No literal colours, font paths, sizes or backdrops in modules. Use `ns.Theme`/`ns.Skin`. See `.cursor/rules/ui-theme.mdc`.
7. **Localize.** User-visible strings use `L.KEY` from `Locales/enUS.lua`.
8. **Lint clean.** `luacheck .` returns 0 warnings for `Core/ UI/ Modules/ Locales/`.
9. **Errors and positions are owned.** Only `Core/Errors.lua` calls `seterrorhandler`, and it always chains to the previous handler (stand down when BugGrabber is present). Only the Movers module repositions Blizzard frames, only frames on its verified list (ARCHITECTURE §16), never an Edit Mode system.
10. **Game IDs are verified, never remembered.** Prefer runtime lookups (`C_Spell.GetSpellTexture`, `C_ChallengeMode.GetMapUIInfo`, `C_Texture.GetAtlasInfo`, `GetClassAtlas`) to literals. Any literal icon path, atlas, spell ID (tag the line `-- spellIDs: Name, Name`), `SOUNDKIT` key or enum fallback must pass `tools/check_ids.py`; after adding one, run `tools/ids/refresh.py` (wago.tools DB2 for the live build) and commit the snapshot.

## 4. Code style

* 4-space indent, double quotes, `local` everything, early returns, ≤140 columns.
* Names: modules `PascalCase` keys (`"Tooltip"`). Files `PascalCase.lua`. Locals/functions `camelCase`. Methods `PascalCase` (`M:OnEnable`, Blizzard convention). Constants `UPPER_SNAKE` on `ns.C`. Locale keys `MODULE_THING`. Internal messages `PUI_*`. Frame names (only when Blizzard requires one, e.g. `UISpecialFrames`) `PhoenixUI_<Thing>`.
* Cache hot globals in locals at file top only where profiling shows benefit (no blanket `local _G = _G` blocks).
* One responsibility per file. Module files are listed directly in `Modules/Modules.xml` (`<Module>.lua`, any helper files such as `Viewer.lua`); its options schema is `Phoenix_UI_Options/Options/<Module>.lua`, listed in `Phoenix_UI_Options/Phoenix_UI_Options.toc` (the settings window is a separate load-on-demand addon).
* Comments explain *why* (especially every secret/taint workaround, with the API doc reference).
* No dead code, no commented-out blocks, no `.bak`, no debug prints (use `ns:Debug()`, compiled out unless `/pui debug`).

## 5. Module template

`Modules/Example/Example.lua`
```lua
local ADDON, ns = ...
local L = ns.L

local M = ns:NewModule("Example", {
    label    = "EXAMPLE",          -- L.EXAMPLE
    category = "utility",
    order    = 100,
    defaults = {
        enabled = true,
        scale   = 1,
        showText = true,
    },
})

function M:OnInitialize()
    -- one-time setup that needs self.db but creates nothing visible
end

function M:OnEnable()
    self.frame = self.frame or self:CreateFrame()
    ns.Events:On("PLAYER_ENTERING_WORLD", self, self.Refresh)
    ns.EditMode:Register(self.frame, { key = "Example", name = L.EXAMPLE, default = { point = "CENTER", x = 0, y = 0 } })
    self:Refresh()
end

function M:OnDisable()
    -- events are released by the core (ns.Events:OffAll(self)); revert visuals here
    if self.frame then self.frame:Hide() end
end

function M:OnSettingChanged(path, value)
    self:Refresh()
end

function M:CreateFrame()
    local f = CreateFrame("Frame", nil, UIParent)
    ns.Skin:Panel(f, "raised")
    f.text = f:CreateFontString(nil, "OVERLAY")
    ns.Skin:Text(f.text, "body")
    f.text:SetPoint("CENTER")
    return f
end

function M:Refresh()
    if not self.frame then return end
    self.frame:SetScale(self.db.scale)
    self.frame.text:SetShown(self.db.showText)
    self.frame:Show()
end
```

`Phoenix_UI_Options/Options/Example.lua`
```lua
local ADDON, ns = ...
ns:RegisterOptions("Example", {
    { type = "header", label = "EXAMPLE_GENERAL" },
    { type = "range",  key = "scale", label = "SCALE", min = 0.5, max = 2, step = 0.05 },
    { type = "toggle", key = "showText", label = "EXAMPLE_SHOW_TEXT", desc = "EXAMPLE_SHOW_TEXT_DESC", keywords = "label" },
})
```

Then add `<Script file="Example\Example.lua"/>` to `Modules/Modules.xml` (in its category block), `Options\Example.lua` to `Phoenix_UI_Options/Phoenix_UI_Options.toc`, and the locale keys to `Locales/enUS.lua` (and every translation).

## 6. How to add a feature (checklist)

1. Does Blizzard already do it in 12.1.5 (Edit Mode, Cooldown Manager, damage meter, boss timeline, nameplate options)? If so, skin or configure it. Don't rebuild it.
2. Does it need combat data? Check every API's `Secret*` flags. If the feature needs logic on secret data, it can't be built. Say so and stop.
3. Find the owning module (ARCHITECTURE §2.1). Create a new module only if none fits.
4. Add defaults, the options schema and locale keys. No UI code in modules for options.
5. Implement with `ns.Events`, `ns.Combat`, `ns.Secret`, `ns.Skin`. No new frames for events.
6. `luacheck .` must be clean. Then run the in-game checklist (§7).
7. Update `docs/ARCHITECTURE.md` if you changed a contract. Add an entry to `CHANGES.md`.
8. Does it exist on WoW Forever? If not, tag the module or option rows with `feature = "…"` (`ns.FEATURES` in
   `Core/Flavor.lua`) so Forever hides it, and run `python3 tools/check_flavors.py`. After any TOC edit run
   `python3 tools/gen_tocs.py`; never edit a `_Forever.toc` by hand.

## 7. Testing

There is no headless WoW client, so testing has two layers:

**Static (agent can run):**
```bash
luacheck .                          # 0 warnings required (generated 12.1.5 std)
python3 tools/check_api.py          # methods/events/CVars/templates/atlases vs 12.1.5, forbidden patterns,
                                    # TOC/XML files exist with exact case, every .lua loaded exactly once
python3 tools/check_ids.py          # every icon path, atlas, spellID, SOUNDKIT and enum fallback vs the pinned 12.1.5 snapshot
python3 tools/check_locales.py      # enUS has every key used, and no unused or duplicate keys
lua5.1 tools/smoke/harness.lua .    # offline load: every file, boot events, every settings page, profiles, slash
python3 tools/check_flavors.py      # all of the above for retail and for WoW Forever (wowf std, Forever data, 16001 boot)
```
CI (`.github/workflows/luacheck.yml`) runs the same five commands. The harness uses permissive stubs: it proves the
load order and boot path, not in-game behaviour.

**In-game (human, before merge to main):** `/console scriptErrors 1`, BugSack optional, then:
* login / `/reload` / logout with all modules on, and again with all modules off → no errors
* toggle the module off and on in the config window → no errors, visuals revert/reapply
* combat: `/console taintLog 2` → `Logs/taint.log` shows no `Phoenix_UI` blocked actions after a dungeon/BG
* secrets: `/console secretCombatRestrictionsForced 1` (and `secretEncounterRestrictionsForced`, `secretChallengeModeRestrictionsForced`, `secretPvPMatchRestrictionsForced`, `secretMapRestrictionsForced`, `addonChatRestrictionsForced`). Fight a dummy → no errors. Reset to 0 afterwards.
* Edit Mode: enter/exit, switch layouts, check positions persist
* profile export → import on a fresh profile → identical
* locale: `/console textLocale` (or a deDE/koKR client) → no missing glyphs (fallback fonts)

## 8. Git

* Work on feature branches off `rework` (until 2.0 ships), with small focused commits: `module: imperative summary`.
* Never commit generated noise outside `.luacheck/` and `docs/audit/`.
* Do not push or open PRs unless the user asked for it explicitly.
