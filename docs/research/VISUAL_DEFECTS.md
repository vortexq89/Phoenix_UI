# Visual defects audit (2026-10-28)

Sources: the user's list (t-msg 19:18), 7 passive screen captures in `bugs\shots` and 134 of today's in-game
screenshots (read-only copies; 39 from the 19:03-19:13 self-test run walking every page), plus a code audit of
`Phoenix_UI_Options/Config`, `Previews`, `UI/Widgets`, `Core/Icons.lua`, `UI/Anim.lua`. Severity: S1 breaks use or
trust, S2 clearly wrong/ugly on every screen, S3 polish. Status: **fixed** (with the commit and the test that
guards it), **open**, or **verify** (needs an in-game look; the cause is not certain from screenshots).

| # | Sev | Where | Defect | Evidence | Status |
|---|---|---|---|---|---|
| 1 | S1 | Previews (CastBars and all) | `SetScale()` with scale <= 0 when the panel is not laid out yet (error from the self-test) | BugSack 19:03, CastBars.lua:173 | fixed a4bcbf4 - every fit scale clamped >= 0.05, 0-size stage retries next frame; test "preview zero-width panel" |
| 2 | S1 | Module cards, page header, search results | "Orange squares instead of icons": in game-icon mode full-colour art was drawn small on an orange accent tile | shots 190312, 190323, 190640 (header tile) | fixed stage 1a - `W.TileColor` (art fills the tile on a neutral backing) |
| 3 | S1 | Rail (Interface, Content, Phoenix) and ~60 other names | Placeholder grey dot instead of an icon in game-icon mode | every self-test shot (rail) | fixed stage 1a - every requested name mapped; test "no placeholder icons" |
| 4 | S1 | Home cards, page list | Counters like "117 / 112": a developer depth target shown to players, with a meter | user report; nav rows with orange meters in every shot | fixed stage 1a - cards say "N settings", meters removed |
| 5 | S1 | Previews | Clicking the preview gave no adjustment (it only scrolled to the row) | user report | fixed stage 1b - quick-edit popover with size/layout/offset sliders at the click; test "preview click to setting" |
| 6 | S1 | Element pages | No obvious size or position control | user report | fixed stage 1b - "Size & position" button on every element preview (width, height, X, Y …); test asserts it on Action Bars, Unit Frames, Cast Bars |
| 7 | S1 | Action Bars page | Changing bar size grows the page/window: the preview stage raised its own height with the content and pushed the page | user report; Previews.lua measure() | fixed stage 1b - constant preview footprint (content scales); test "options window geometry" |
| 8 | S1 | Window | Window too big, covers most of a 1440p screen (1280x800 x readable scale) | shots 190312+ (window ~60% x 80% of 2560x1440) | fixed stage 1a - default 1180x740, never more than 80% x 85% of the screen at any scale; re-fits on resolution/UI-scale change; geometry test at 1366x768, 1920x1080, 4830x2717 |
| 9 | S2 | Home | Flat grid of 30 cards behind a filter, reads as unorganised | user report | fixed stage 1c - cards grouped under rail-group headings in rail order; "x of y on" instead of "x / y" |
| 10 | S2 | Every page in self-test shots | Pages look dimmed to ~30% | 35 of 39 self-test shots | fixed - artefact of the self-test (Screenshot() captured the frame the next page started its fade); shots now taken one tick later. Also: a replaced tween now lands on its end value, so no fade can stay stuck |
| 11 | S2 | Settings rows | Brown/orange tint over whole card bodies | shots 142628, 190640 crop | verify - colour matches the row flash texture (accent at 22%) at full alpha; flash is now hidden except while it plays, and the row highlight starts transparent |
| 12 | S2 | Settings rows | "OUT OF COMBAT" badge on most rows of bar/unit pages: noise | shot 190312 | fixed stage 1b - only "Reload" keeps a badge; combat note stays in the tooltip |
| 13 | S2 | Preview stages | Tiny sample in a large empty dark stage (unit frame, cast bar, nameplate) | shots 190323, 190331, 190342 | open - stage 2: fit-to-stage zoom for small samples |
| 14 | S2 | Top bar | Profile dropdown empty on first open (no text) | shot 190312 | open - stage 2 |
| 15 | S2 | Window | Rail labels and list text 12 px on a 2560x1440 screen at UI scale 0.53 look small next to the large panels | all shots | open - stage 2 typography pass (sizes per role) |
| 16 | S3 | Page header | "117 SETTINGS / ACTIVE" chips under the title compete with the title | shot 190312 | open - stage 2 |
| 17 | S3 | Chips | Element chips (Bar 1 … Item bar) wrap into two lines at narrow widths without a scroll | shot 190312 | open |
| 18 | S3 | Cards | Section header ticks/icons use mixed game art and glyphs in game-icon mode | shots | open |
| 19 | S3 | In world | Blizzard Edit Mode shots show Phoenix movers and Blizzard's own grid at once; overlapping labels | shots 150334-150415 | open - stage 3 (hide Blizzard grid while Phoenix layout mode is on) |
| 20 | S3 | Mail / windows | New: Alts button and Shift-drag move need an in-game look | - | verify |

Counts: 20 defects (8 S1, 7 S2, 5 S3). Fixed 12 (all 8 S1, 4 S2); verify 2; open 6.

Not visible from screenshots and therefore not listed: anything inside combat, group frames in a raid,
nameplates in the world. The self-test now takes shots after the fade and logs per-page audit counts, so the next
overnight run will extend this list automatically.
