<p align="center">
  <img src="docs/screenshots/home.png" alt="Phoenix UI settings window" width="860">
</p>

# Phoenix UI

**A flat, consistent look for the default World of Warcraft 12.x interface.**
Retail · Interface 120105 (12.1.5) · by **VortexQ8** · MIT licence

Phoenix UI builds on Blizzard's interface instead of replacing it. Edit Mode keeps control of layout, and Phoenix
adds a consistent look and small comforts on top. It restyles secure frames but never rebuilds them, which keeps
it light and out of the way of taint. It also catches Lua errors from every addon, and moves the few frames Edit
Mode cannot reach.

[CurseForge](https://www.curseforge.com/projects/1242528) ·
[Wago](https://addons.wago.io/addons/jK8XQjKy) ·
[GitHub](https://github.com/vortexq89/Phoenix_UI)

---

## Features

| Category | Module | What it does |
|---|---|---|
| System | **General** | Theme (Phoenix Ember, Frost, Fel, Arcane, Class, Custom), fonts, bar texture, font scale, reduce motion; 89 bundled fonts and 24 statusbars shared through LibSharedMedia |
| | **Bugs** | Catches Lua errors, blocked actions (taint) and Lua warnings from every addon; viewer with search, sessions and copy; data-bar count, minimap indicator, optional chat notice and sound; works alongside BugGrabber/BugSack |
| Interface | **Skins** | Phoenix styling for the game menu, popups and ready check |
| | **Action Bars** | Square buttons, readable hotkeys and macro names, out-of-range tint |
| | **Unit Frames** | Bar texture, class and power colors, fonts for player, target, focus and pet |
| | **Group Frames** | Party and raid frame bar texture, border, background and name/status fonts, with a live party preview |
| | **Cast Bars** | Flat cast bars; icon, timer and latency on your own bar |
| | **Buffs & Debuffs** | Cropped icons, crisp borders, readable timers and stacks |
| | **Nameplates** | Bar texture, a health percent that works in restricted content, Mythic+ enemy forces per mob; nameplate visibility toggles |
| | **Tooltip** | Dark style, class and quality borders, health bar, target, role and IDs, Mythic+ rating, cursor anchor, hide in combat |
| | **Item Level** | Item levels on the character sheet and bags |
| | **Bags** | Phoenix bag windows, quality borders, stack-count font, upgrade arrows on better gear; item levels from Item Level |
| | **Minimap** | Square minimap, zone text style, coordinates, a button bin for addon minimap buttons; size stays in Edit Mode |
| | **Data Bar** | FPS, latency, speed, durability, gold, clock, bug count, free bag slots, item level, friends, guild and mail, in the order you drag them to; movable in Edit Mode |
| | **Movers** | Move, scale and fade frames Edit Mode does not manage: zone text, error messages, alerts, top-center widgets, boss banner, event toasts, ready check |
| Combat | **Cooldown Text** | Blizzard's countdown numbers in the Phoenix font |
| | **Encounters** | Boss timers as Phoenix bars and boss warnings in a Phoenix banner (from the game's own encounter timeline), every Blizzard boss-warning setting, a Test button, pull and break timers shared with DBM/BigWigs users, the countdown voice, and a Phoenix bar style for BigWigs/LittleWigs |
| | **Combat Text** | Every floating combat text option in one page |
| | **Damage Meter** | Skin for Blizzard's built-in meter; optional one-click Details! style |
| | **Spell History** | A strip of your recent casts, movable in Edit Mode |
| | **PvP** | Safe queue pop with timer, TAB targets players in PvP, `/gg` to surrender an arena |
| Social | **Chat** | Clickable URLs with a copy box, copy-chat window, arrow-key history that survives a reload, Shift/Ctrl wheel scrolling, unread tabs that glow in the accent colour, whisper tabs in the whisper colour |
| | **AFK Screen** | A calm full-screen view of your character while away |
| Utility | **Quality of Life** | Hide talking heads, quiet errors in combat, achievement screenshots, Cooldown Manager toggle |
| | **Automation** | Repair, sell junk, fill "DELETE", decline duels, accept friend invites and resurrections, release in BGs, skip seen cinematics |
| | **Mythic+** | Run timer with chest thresholds, enemy forces, boss splits, deaths and personal bests; ahead/behind against your best run, the current pull on the forces line (when the game allows it); party keystones over LibKeystone (works with BigWigs and DBM users); auto-insert your keystone, report your new key |

Every module can be switched off. Modules that hook Blizzard frames ask for a reload when you turn them off.

Home shows **this week** at a glance: Great Vault progress for dungeons, raid and world, your Mythic+ rating, runs
and best key.

**Languages:** English, Deutsch, Français, Español (ES and MX), Português (BR), Русский, Italiano, 한국어, 简体中文 and
繁體中文, every string. Korean and Chinese clients draw all Phoenix text with the game's own font so no glyph is ever
missing; Russian clients only offer bundled fonts that include Cyrillic.

## Screenshots

| | |
|---|---|
| ![Home](docs/screenshots/home.png) | ![Module page](docs/screenshots/module.png) |
| ![Search](docs/screenshots/search.png) | ![Profiles](docs/screenshots/profiles.png) |
| ![Bug viewer](docs/screenshots/bugs.png) | ![Movers](docs/screenshots/movers.png) |
| ![Mythic+ timer and nameplate forces](docs/screenshots/mplus.png) | ![Nameplates with live preview](docs/screenshots/nameplates.png) |
| ![Unit frames with unit selector](docs/screenshots/unitframes.png) | ![Font picker](docs/screenshots/fonts.png) |
| ![Bar texture picker](docs/screenshots/textures.png) | ![Bundled fonts and statusbars](docs/screenshots/media.png) |
| ![This week: Great Vault and rating on Home](docs/screenshots/vault.png) | ![Mythic+ page with party keystones](docs/screenshots/keystones.png) |
| ![Bags: quality borders and upgrade arrows](docs/screenshots/bags.png) | ![Data bar with drag ordering](docs/screenshots/databar.png) |
| ![Minimap button bin](docs/screenshots/minimap.png) | ![Presets](docs/screenshots/presets.png) |
| ![Encounters: boss timeline and warnings](docs/screenshots/encounters_timeline.png) | ![Encounters test mode in the world](docs/screenshots/encounters_test.png) |
| ![Pull and break timers](docs/screenshots/encounters_timers.png) | ![Module picker for new installs](docs/screenshots/modpicker.png) |

The screenshots are design mockups of the settings window rendered from HTML (`docs/screenshots/src`) with the
same rasterized icon atlas the addon ships. The Mythic+ page shows the in-world timer at 150 % and sample nameplates.

### Icons

Every icon in the window, the data bar and Phoenix's own frames comes from one set: 101
[Phosphor](https://phosphoricons.com) duotone glyphs (MIT), packed into white atlases with 24, 48 and 96 px
cells and tinted by the active theme. Each icon picks the atlas that matches its size in physical pixels,
so it stays sharp from 1080p up to 4K at a UI scale of about 1.15.

![Icon set](docs/screenshots/icons.png)

## Installation

Install from CurseForge or Wago, or download a release and extract **both** folders, `Phoenix_UI` and
`Phoenix_UI_Options`, into `World of Warcraft/_retail_/Interface/AddOns/`. `Phoenix_UI_Options` is the settings
window; it is load-on-demand, so it costs no memory until you type `/pui`. Keep both enabled in the AddOns list.

## Usage

| Command | Action |
|---|---|
| `/pui` or `/phoenix` | Open or close the settings window |
| `/pui edit` | Open Edit Mode |
| `/pui bugs` | Open the bug viewer (`/pui bugs clear`, `/pui bugs options`) |
| `/pui movers` | Unlock or lock the movers |
| `/pui profile [name]` | Show or switch the profile |
| `/pui reset` | Reset the settings window position |
| `/pui <module>` | Jump to a module, e.g. `/pui tooltip` |
| `/pui settings` | Open the Phoenix page in Blizzard's settings |
| `/pui help` | List every command in chat |
| `/pui diag` | Check that textures, icons and fonts load (Tools → Diagnostics shows the result) |
| `/pui bugs share on\|off` | Allow or stop error reports to the author |
| `/pui debug` | Toggle debug output |
| `/gg` | Surrender an arena match (PvP module, asks first) |

You can also open the settings from the Addon Compartment (the button by the minimap) or from
*Options → AddOns → Phoenix UI*.

### Bug reports

The Bugs module records every Lua error, blocked action and Lua warning, from load time on, without taking over
Blizzard's error window or BugSack (it hands every error on to them). Repeats are counted instead of stored twice.
Open the viewer from the data bar, the minimap bug button, a right-click on the Addon Compartment entry or
`/pui bugs`, and use **Copy** to paste a report anywhere.

Reports are saved to `WTF\Account\<account>\SavedVariables\Phoenix_UI.lua` when you log out or reload. To share
them with the author, run the **Phoenix Uploader** app for Windows from
[vq8s.com/phoenix-ui](https://vq8s.com/phoenix-ui): it sends new reports to VQ8S.com. Nothing leaves your PC
otherwise. **Send error reports to the author** (Bugs page, on by default) decides whether the uploader may send
this account's reports; turn it off there or with `/pui bugs share off`. What is sent: the error text, call stack,
locals, addon and game version and client language. Character names, realms, GUIDs, BattleTags, chat text and
account or Windows user names are removed first. The file format is documented in
[docs/BUG_REPORTS.md](docs/BUG_REPORTS.md).

### Movers

Edit Mode places action bars, unit frames, the minimap and most of the HUD. `/pui movers` unlocks the frames it does
not cover: drag to move, mouse wheel to scale (Shift: opacity), arrow keys to nudge, right-click to reset, with an
optional snap grid. Positions are saved per profile. Movers never touches an Edit Mode frame and locks itself in
combat.

### Profiles

Profiles are shared across your account. You can create, duplicate, rename, reset and delete them, switch
automatically per specialization, and share them as text strings. An import shows what the string contains before
anything is changed.

### Upgrading from Phoenix UI 11.x

On first login, 2.0 imports your old profiles once where the setting still exists (theme, automation, tooltip,
action bar text, cast bar extras, chat links, PvP options and more). Everything else starts from fresh defaults.

## What changed in 2.0, and where features went

12.x changed what addons are allowed to do. Addons can no longer read the combat log, and many combat values are
"secret" in restricted content. Blizzard also now ships many features that used to need addons. Phoenix UI 2.0
follows that. It skins and configures the Blizzard features and no longer bundles copies of other addons.

| Old Phoenix feature | Use instead |
|---|---|
| Frame mover (MoveAny) | Blizzard **Edit Mode** (`/pui edit`) + Phoenix **Movers** (`/pui movers`) |
| Scrolling combat text (MikScrollingBattleText) | Phoenix **Combat Text** page (Blizzard floating combat text), or [MikScrollingBattleText](https://www.curseforge.com/wow/addons/mikscrollingbattletext) (the 12.x rewrite) |
| Group finder filters (Premade Groups Filter) | [Premade Groups Filter](https://www.curseforge.com/wow/addons/premade-groups-filter) |
| Buff overlays on raid frames (BuffOverlay) | Blizzard raid frame aura settings. BuffOverlay does not work in 12.x, where aura data is secret in restricted content |
| Cooldown tracker / spell notifications | Blizzard **Cooldown Manager** (Quality of Life page) for your own cooldowns. Party cooldown tracking relied on the combat log and was dropped |
| Details! skin | Phoenix **Damage Meter** page (Blizzard meter skin + one-click Details! style) |

## Development

```bash
luacheck .                          # zero warnings, generated 12.1.5 API std
python3 tools/check_api.py          # APIs, events, CVars, templates, atlases vs. 12.1.5; load-chain check
python3 tools/check_ids.py          # every icon path, atlas, spellID, SOUNDKIT and enum fallback vs the pinned 12.1.5 snapshot
python3 tools/check_locales.py      # locale coverage; every translation complete
lua5.1 tools/smoke/harness.lua .    # offline load test
```

CI runs all four on every push. The in-game checklist for a release is [`docs/TESTING.md`](docs/TESTING.md).
 Read [`AGENTS.md`](AGENTS.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
before contributing. They cover the module contract, taint and secret-value rules, and the theme tokens.

## Credits

- Libraries: LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibEditMode (each under its own licence).
- Fonts: 89 faces in 36 families (Inter, Barlow, Oswald, Fira Sans, Rajdhani, Cinzel, Roboto and more) under the
  SIL Open Font License 1.1, the Ubuntu Font Licence or Apache 2.0. See `Media/Fonts/FONTS.md` and
  `Media/Fonts/Licenses`.
- Icons: [Phosphor Icons](https://phosphoricons.com) 2.1.1 (© 2023 Phosphor Icons), MIT License
  (`Media/Icons/LICENSE`). Rasterized by `tools/media/gen_icons.py`.

## Licence

MIT © 2024–2026 VortexQ8. See [LICENSE](LICENSE).
