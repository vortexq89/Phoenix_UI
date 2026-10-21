<p align="center">
  <img src="docs/screenshots/home.png" alt="Phoenix UI settings window" width="860">
</p>

# Phoenix UI

**A flat, consistent look for the default World of Warcraft 12.x interface.**
Retail · Interface 120105 (12.1.5) · by **VortexQ8** · MIT licence

Phoenix UI builds on Blizzard's interface instead of replacing it. Edit Mode keeps control of layout, and Phoenix
adds a consistent look and small comforts on top. It restyles secure frames but never moves or rebuilds them,
which keeps it light and out of the way of taint.

[CurseForge](https://www.curseforge.com/projects/1242528) ·
[Wago](https://addons.wago.io/addons/jK8XQjKy) ·
[GitHub](https://github.com/vortexq89/Phoenix_UI)

---

## Features

| Category | Module | What it does |
|---|---|---|
| System | **General** | Theme (Phoenix Ember, Frost, Fel, Arcane, Class, Custom), fonts, bar texture, font scale, reduce motion |
| Interface | **Skins** | Phoenix styling for the game menu, popups and ready check |
| | **Action Bars** | Square buttons, readable hotkeys and macro names, out-of-range tint |
| | **Unit Frames** | Bar texture, class and power colors, fonts for player, target, focus and pet |
| | **Group Frames** | Party and raid frame textures, fonts and borders |
| | **Cast Bars** | Flat cast bars; icon, timer and latency on your own bar |
| | **Buffs & Debuffs** | Cropped icons, crisp borders, readable timers and stacks |
| | **Nameplates** | Bar texture and a health percent that works in restricted content; nameplate visibility toggles |
| | **Tooltip** | Dark style, class and quality borders, health bar, target, role and IDs, cursor anchor, hide in combat |
| | **Item Level** | Item levels on the character sheet and bags |
| | **Minimap** | Square minimap, zone text style, coordinates |
| | **Data Bar** | FPS, latency, speed, durability, gold and clock, movable in Edit Mode |
| Combat | **Cooldown Text** | Blizzard's countdown numbers in the Phoenix font |
| | **Combat Text** | Every floating combat text option in one page |
| | **Damage Meter** | Skin for Blizzard's built-in meter; optional one-click Details! style |
| | **Spell History** | A strip of your recent casts, movable in Edit Mode |
| | **PvP** | Safe queue pop with timer, TAB targets players in PvP, `/gg` to surrender an arena |
| Social | **Chat** | Clickable URLs with a copy box, copy-chat window |
| | **AFK Screen** | A calm full-screen view of your character while away |
| Utility | **Quality of Life** | Hide talking heads, quiet errors in combat, achievement screenshots, Cooldown Manager toggle |
| | **Automation** | Repair, sell junk, fill "DELETE", decline duels, accept friend invites and resurrections, release in BGs, skip seen cinematics |
| | **Mythic+** | Auto-insert your keystone, report your new key |

Every module can be switched off. Modules that hook Blizzard frames ask for a reload when you turn them off.

## Screenshots

| | |
|---|---|
| ![Home](docs/screenshots/home.png) | ![Module page](docs/screenshots/module.png) |
| ![Search](docs/screenshots/search.png) | ![Profiles](docs/screenshots/profiles.png) |

The screenshots are design mockups of the settings window rendered from HTML (`docs/screenshots/src`) with the
same rasterized icon atlas the addon ships.

### Icons

Every icon in the window, the data bar and Phoenix's own frames comes from one set: 68
[Phosphor](https://phosphoricons.com) duotone glyphs (MIT), packed into white atlases with 24, 48 and 96 px
cells and tinted by the active theme. Each icon picks the atlas that matches its size in physical pixels,
so it stays sharp from 1080p up to 4K at a UI scale of about 1.15.

![Icon set](docs/screenshots/icons.png)

## Installation

Install from CurseForge or Wago, or download a release and extract `Phoenix_UI` into
`World of Warcraft/_retail_/Interface/AddOns/`.

## Usage

| Command | Action |
|---|---|
| `/pui` or `/phoenix` | Open or close the settings window |
| `/pui edit` | Open Edit Mode |
| `/pui profile [name]` | Show or switch the profile |
| `/pui reset` | Reset the settings window position |
| `/pui <module>` | Jump to a module, e.g. `/pui tooltip` |
| `/pui settings` | Open the Phoenix page in Blizzard's settings |
| `/gg` | Surrender an arena match (PvP module, asks first) |

You can also open the settings from the Addon Compartment (the button by the minimap) or from
*Options → AddOns → Phoenix UI*.

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
| Frame mover (MoveAny) | Blizzard **Edit Mode** (`/pui edit`) |
| Scrolling combat text (MikScrollingBattleText) | Phoenix **Combat Text** page (Blizzard floating combat text), or [MikScrollingBattleText](https://www.curseforge.com/wow/addons/mikscrollingbattletext) (the 12.x rewrite) |
| Group finder filters (Premade Groups Filter) | [Premade Groups Filter](https://www.curseforge.com/wow/addons/premade-groups-filter) |
| Buff overlays on raid frames (BuffOverlay) | Blizzard raid frame aura settings. BuffOverlay does not work in 12.x, where aura data is secret in restricted content |
| Cooldown tracker / spell notifications | Blizzard **Cooldown Manager** (Quality of Life page) for your own cooldowns. Party cooldown tracking relied on the combat log and was dropped |
| Details! skin | Phoenix **Damage Meter** page (Blizzard meter skin + one-click Details! style) |

## Development

```bash
luacheck .                          # zero warnings, generated 12.1.5 API std
python3 tools/check_api.py          # APIs, events, CVars, templates, atlases vs. 12.1.5; load-chain check
python3 tools/check_locales.py      # locale coverage
lua5.1 tools/smoke/harness.lua .    # offline load test
```

CI runs all four on every push. Read [`AGENTS.md`](AGENTS.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
before contributing. They cover the module contract, taint and secret-value rules, and the theme tokens.

## Credits

- Libraries: LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibEditMode (each under its own licence).
- Fonts: Inter, Roboto, Roboto Condensed and Cinzel, under the SIL Open Font License 1.1 (`Media/Fonts`).
- Icons: [Phosphor Icons](https://phosphoricons.com) 2.1.1 (© 2023 Phosphor Icons), MIT License
  (`Media/Icons/LICENSE`). Rasterized by `tools/media/gen_icons.py`.

## Licence

MIT © 2024–2026 VortexQ8. See [LICENSE](LICENSE).
