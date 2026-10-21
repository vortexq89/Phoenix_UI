# Phoenix UI changelog

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
