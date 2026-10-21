# Phoenix UI changelog

## 2.0.0 — Midnight rebuild (Interface 120105, WoW 12.1.5)

A ground-up rewrite for the 12.x interface. Settings from 11.x are imported once where they still mean something;
everything else starts from fresh defaults.

### New
- **Standalone settings window** (`/pui`): sidebar by category, instant search across every option, live changes,
  "reload" and "out of combat" badges, resizable and remembered between sessions.
- **Phoenix Ember theme** with Frost, Fel, Arcane, Class and Custom accents, curated fonts (Inter, Roboto, Cinzel),
  three bar textures, font scaling and a reduce-motion option.
- **Profiles**: create, duplicate, rename, reset, delete, per-specialization switching, and export/import strings
  with a preview before anything is changed.
- **Damage Meter** skin for Blizzard's built-in meter, plus an optional one-click style for Details!.
- **Combat Text** page that gathers Blizzard's floating combat text options in one place.
- **Cooldown Text** uses Blizzard's countdown numbers with the Phoenix font and colour.
- **Spell History** strip of your recent casts, movable in Edit Mode.
- **Nameplates** health percent that keeps working in restricted content.
- Blizzard Settings landing page and an Addon Compartment entry.

### Changed
- Layout belongs to Edit Mode: Phoenix no longer moves Blizzard frames. The data bar and spell history are
  Edit Mode frames with per-layout positions.
- Action bars, unit frames, group frames, cast bars, auras, tooltip, minimap, item level, chat, AFK screen,
  automation, Mythic+ and PvP were rewritten on top of Blizzard's 12.x frames, taint-free and secret-value safe.
- `/gg` (arena surrender) now asks for confirmation through Blizzard's own dialog.

### Removed
- Bundled copies of other addons: MoveAny, MikScrollingBattleText, Premade Groups Filter, BuffOverlay and the
  others. Use the maintained originals (see the README) or the Blizzard features that replace them.
- Combat-log features (scrolling battle text, spell notifications, cooldown tracking from the log, arena
  dampening): addons can no longer read the combat log in 12.x.
- Chat history and emoji, the minimap size slider and the Mythic+ timer overlay.

### Upgrading from 11.x
- Your old profiles are imported on first login and a chat message says how many settings came across. The old
  SavedVariables are read once and then cleared.
