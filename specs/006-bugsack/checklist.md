# Feature checklist: Bugs: BugSack parity

From `.specify/templates/feature-checklist-template.md` (constitution 1.2.0). Tick with evidence.

- [x] **Original options**: Every option of the original addon is listed and present, or its absence is justified in the spec
- [x] **Basics and standards**: The feature works with no setup: sane defaults, Blizzard behaviour kept where it is the standard
- [x] **Configuration**: Every behaviour has a setting in exactly one place in the GUI; no slash commands
- [x] **Size, position, scale**: Width, height, scale and position are settable; nothing is fixed in code
- [x] **Colours, fonts, textures**: Colours, font (Phoenix Font by default), size, outline and bar textures are editable
- [x] **Live preview**: The page shows the real frame drawn by the module's own code, sized to its content, no box, no clipping
- [x] **Layout**: Movable frames are in Phoenix Layout only (never also in Edit Mode); saved per Edit Mode layout
- [x] **Profiles**: Settings live in the profile; import, export, copy and reset work; migrations for removed keys
- [x] **Live apply**: Every setting applies at once; none needs a reload (sim requests excepted)
- [x] **Retail and Forever**: Both TOCs load; missing APIs fall back; check_api / check_ids and the harness pass on both
- [x] **10 locales**: Every string in enUS, deDE, esES, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW; check_locales clean
- [x] **Edge cases**: Combat lockdown, secret values, missing data, load-on-demand addons, empty lists, huge values, small screens
- [x] **Unmentioned gaps**: Compared with EllesmereUI and Blizzard's own UI: what neither the original addon nor this spec mentions, listed and decided

## Original options (T001, read from BugSack config.lua/core.lua/sack.lua and !BugGrabber, 3 Nov)

| Original option | Phoenix row | Status |
|---|---|---|
| BugGrabber: catch Lua errors (error handler) | Core/Errors.lua handler, or BugGrabber's store when installed | have |
| BugGrabber: ADDON_ACTION_BLOCKED / FORBIDDEN | Bugs › Blocked actions | have |
| BugGrabber: Lua warnings | Bugs › Lua warnings | have |
| BugGrabber: duplicate counter, sessions, saved limit | count per report, sessions, Reports kept (100–500) | have |
| BugGrabber: throttle of repeated errors | one record per hash + count; one chat line per hash; sound every 10 s; popup gap | have |
| BugSack: Auto popup | Open the viewer on a new error + Open at most every (s), never in combat | have (new) |
| BugSack: Chatframe output | Chat notice | have |
| BugSack: Minimap icon | Bug indicator on the minimap (Layout movable) + Never/Errors/Always | have |
| BugSack: Addon compartment | compartment badge with the count | have |
| BugSack: Mute | Sound = None | have |
| BugSack: Use Master channel | Play on the master channel | have (new) |
| BugSack: Minimap alt-click wipe | Alt+click clears the session | have (new) |
| BugSack: Font size | Report text size (9–20) | have (new) |
| BugSack: Sound (LSM list, preview) | Sound (Phoenix sounds) | have |
| BugSack: viewer sessions, next/prev, current/previous/all | viewer sessions, prev/next, source and search filters | have |
| BugSack: Send bugs to a player (AceComm) | Send (Phoenix to Phoenix, accept popup, 50 reports) | have (new) |
| BugSack: wipe | Clear / Clear all reports | have |

## Unmentioned gaps (T002: EllesmereUI and Blizzard's UI)

| Gap | Decision |
|---|---|
| EllesmereUI has no bug viewer; Blizzard has the Lua error frame (scriptErrors) | keep "Blizzard error window" as an extra toggle |
| BugSack has no export or upload | Export (all listed reports with version, build, locale, addon list) + one-click upload (asks once, turns sharing on) |
| Copying a report without the client details is useless to an author | Copy adds the Phoenix version, build, locale and addon list |
| StaticPopup can taint Blizzard dialogs | Phoenix's own question box for send, accept and upload |
| A burst of errors would spam popups | popup gap; never opens in combat |
| Huge or hostile incoming data | caps: 50 reports, 16 KB per field, accept first, one transfer per sender |
| Two viewers when BugSack is also installed | Phoenix claims the display only when BugSack is absent (unchanged); noted for the Plugins page |

## t230: error sounds (3 Nov)

- [x] BugSack's sound (Media/error.ogg) checked: no licence shipped, so it is not reused; four original CC0 sounds made (Error, Glitch, Fatal, Blip), credited in Media/Sounds/SOUNDS.md
- [x] In the Bugs sound picker, with a Test button
- [x] Quiet time (2–120 s, default 10): plays only after that long with no new error, so a burst makes one sound (harness)
- [x] Follows "Mute in combat" and "Master channel"
