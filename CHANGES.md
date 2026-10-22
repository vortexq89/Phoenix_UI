# Phoenix UI changelog

## 2.0.0-beta1

### New
- **Settings window 2.0**: the sidebar is 13 folding groups (Appearance & Media, Combat, Group & Mythic+, Tools …);
  every module and option kept its place in your saved settings, only the menu moved. Search covers every page and
  shows the full path. Reset any setting (right-click or ↺), any card, or a whole module.
- **Previews**: every visual module has one; it stays pinned while you scroll, folds away, and Unit Frames,
  Nameplates and Cast Bars can show low health, out of range, targeted or interrupted. Hovering a font, texture or
  dropdown choice previews it before you pick.
- **Card pickers** for fonts, textures and sounds, with search and style filters; 100 fonts (SIL OFL), new bar
  textures, alert sounds and a countdown voice (CC0) — credits in `Media/*/*.md`.
- **Appearance & Media** pages: every font and texture setting of every module on one page, with Apply to all.
- **Tools → Diagnostics**: the media check, icon source (falls back to Blizzard icons if the Phoenix sheet fails)
  and a copyable report.
- `/pui diag`: checks that every Phoenix texture and icon atlas loads in your client and records what the
  settings window's icons look like to the game; the result is kept in the SavedVariables for support. It also
  runs quietly once per version after login and only speaks up if something failed.
- **Mythic+ timer**: ahead/behind against your best timed run of the dungeon and level for every boss and the forces,
  the time to beat beside bosses still alive, and the current pull added to the forces line when the game lets
  addons read it (otherwise it stays silent).
- **Party keystones** on the Mythic+ page: your group's keys, dungeons and ratings over the LibKeystone protocol, so
  BigWigs and DBM users show up too. Sent only outside instances, never during chat lockdown.
- **This week** on Home: Great Vault progress for dungeons, raid and world, Mythic+ rating, runs and best key.
- **Chat**: unread tabs glow in the accent colour; whisper tabs use the whisper colour.
- **Translations**: deDE, frFR, esES/esMX, ptBR, ruRU, itIT, koKR, zhCN and zhTW, for every string.
- `/phoenix testerror` raises a harmless, clearly labelled error to try the bug catcher and the uploader.
- `docs/TESTING.md`: the in-game checklist for this beta.
- **Send error reports to the author** (Bugs page, on by default, account-wide): whether Phoenix Uploader may send
  this account's reports. `/pui bugs share [on|off]`. A one-time chat line on first login says it is on and how to
  turn it off. Phoenix Uploader 1.1.0 honours it.
- **Privacy**: reports no longer carry your character name or realm, player GUIDs, BattleTags, Windows user or
  account folder names; text-like string locals (chat lines and the like) are reduced to their length.

### Fixed
- **Tooltip**: no more "attempt to call a nil value" when an item, unit or spell tooltip is not a standard game
  tooltip (seen 43 times in testing); the item quality border reads the tooltip data first.
- Texture pickers draw each texture in a neutral tint so its shading is visible; the chosen one keeps the accent.
- The version no longer reads `@project-version@` in an unpackaged checkout: the source TOC carries `2.0.0-beta1`
  and only packaged builds use the packager token.


## 2.0.0 — Midnight rebuild (Interface 120105, WoW 12.1.5)

A ground-up rewrite for the 12.x interface. Settings from 11.x are imported once where they still mean something;
everything else starts from fresh defaults.

### New
- **Standalone settings window** (`/pui`): sidebar by category, instant search across every option, live changes,
  "reload" and "out of combat" badges, resizable and remembered between sessions.
- **Phoenix Ember theme** with Frost, Fel, Arcane, Class and Custom accents, font scaling and a reduce-motion option.
- **Fonts and textures**: 89 font files in 36 families (SIL OFL 1.1, Ubuntu Font Licence; see `Media/Fonts/FONTS.md`)
  and 24 original statusbars, registered with LibSharedMedia as "Phoenix …" so other addons can use them. Pickers
  show every font in its own face and every bar as a strip, grouped, with type-to-filter.
- **Options 2.1**: two-column pages, tabs, live previews built from each module's own styling code (Nameplates,
  Unit Frames with a unit selector, Group Frames, Cast Bars, Action Bars, Buffs & Debuffs, Data Bar, Tooltip, Chat and the theme),
  cog popovers for per-text font, size, outline, shadow, colour and position, border style/size/colour,
  background opacity/colour, icon zoom and slot placement, "Apply to" This / All / Multiple, "Apply all settings
  from", a window scale slider and Reload UI / Close in the footer. Search also finds options inside cogs.
- **Profiles**: create, duplicate, rename, reset, delete, per-specialization switching, and export/import strings
  with a preview before anything is changed.
- **Damage Meter** skin for Blizzard's built-in meter, plus an optional one-click style for Details!.
- **Combat Text** page that gathers Blizzard's floating combat text options in one place.
- **Cooldown Text** uses Blizzard's countdown numbers with the Phoenix font and color.
- **Spell History** strip of your recent casts, movable in Edit Mode.
- **Nameplates** health percent that keeps working in restricted content, and Mythic+ enemy forces per mob.
- **Mythic+ timer**: level, affixes, clock against the limit with +2/+3 thresholds, enemy forces, boss splits,
  deaths with their time penalty and your best time per dungeon and level. Movable in Edit Mode, where it shows a
  sample run.
- **Tooltip** Mythic+ rating line for players, colored like Blizzard's rating.
- **Chat** arrow-key history of what you typed, kept across reloads (32 lines), and fast scrolling: Shift + wheel
  jumps to the top or bottom, Ctrl + wheel pages.
- **Minimap** page shows the size set in Edit Mode and opens Edit Mode to change it.
- Blizzard Settings landing page and an Addon Compartment entry.
- **Bugs**: an error catcher in the spirit of BugGrabber + BugSack. Lua errors, blocked actions and Lua warnings
  from every addon are captured from load time, with stack and locals, deduplicated with counts, attributed to
  the addon and protected against floods. A Phoenix-styled viewer (search, session filter, prev/next, copy,
  clear), a data-bar count, a minimap indicator and the Addon Compartment entry flash on new errors; optional chat
  notice and sound; a switch for Blizzard's error window. Blizzard's handler and BugGrabber keep working. Reports
  are stored in `PhoenixUIBugsDB` for the Phoenix Uploader app (VQ8S.com).
- **Movers** (`/pui movers`): move, scale and fade the frames Edit Mode does not manage (zone text, error
  messages, alerts, top-center widgets, boss banner, event toasts, ready check) with a grid, snapping, arrow-key
  nudging and per-profile positions. Locks itself in combat and never touches Edit Mode frames.
- **One icon set everywhere**: 88 Phosphor duotone icons (MIT) in the sidebar, page and section headers,
  search results, buttons, toggles, dropdowns, profile lists, home tiles, the About page, popups, the footer
  status, the data bar and the PvP queue timer. They follow the accent color and stay sharp at 4K.
- New high-resolution Phoenix emblem and logo (addon list, Addon Compartment, window header, home, About,
  Settings landing page, AFK screen).

### Changed
- Layout belongs to Edit Mode: Phoenix no longer moves Edit Mode frames. The data bar and spell history are
  Edit Mode frames with per-layout positions; the old MoveAny mover is replaced by Movers, which only covers a
  verified list of frames Edit Mode does not manage.
- Action bars, unit frames, group frames, cast bars, auras, tooltip, minimap, item level, chat, AFK screen,
  automation, Mythic+ and PvP were rewritten on top of Blizzard's 12.x frames and handle secret values.
- `/gg` (arena surrender) now asks for confirmation through Blizzard's own dialog.

### Removed
- Bundled copies of other addons: MoveAny, MikScrollingBattleText, Premade Groups Filter, BuffOverlay and the
  others. Use the maintained originals where they still exist (see the README) or the Blizzard features that
  replace them.
- Combat-log features (scrolling battle text, spell notifications, cooldown tracking from the log, arena
  dampening): addons can no longer read the combat log in 12.x.
- Chat emoji and the separate minimap size slider (the size now lives in Edit Mode).

### Upgrading from 11.x
- Your old profiles are imported on first login and a chat message says how many settings came across. The old
  SavedVariables are read once and then cleared.
