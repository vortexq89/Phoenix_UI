# Design comparison: ElvUI, EllesmereUI and Phoenix UI

Design reference only. EllesmereUI was studied read-only from the user's install (`docs/research/addons/EllesmereUI*.md`,
`ELLESMERE_UX_STUDY.md`); ElvUI from its public behaviour (options via AceConfig, `/ec`, movers via `/moveui`). No code
or assets are copied; every Phoenix change is original.

| Area | ElvUI | EllesmereUI | Phoenix (before this pass) | Phoenix direction |
|---|---|---|---|---|
| Window | AceConfig tree window, resizable, plain; size independent of content | Fixed-size custom window (about 60% of a 1440p screen), dark flat panels, never grows | 1280x800 x readable scale: up to ~80% of the screen; panels looked muddy in shots | Smaller default, hard cap 80%x85% of the screen, constant size (done) |
| Navigation | Left tree, every module and sub-group as text | Module list on the left, tabs across the top of each module | Icon rail + page list + tabs; list showed developer meters | Keep rail+list, remove meters (done), tab order Layout / Appearance / Text / Behaviour (done earlier) |
| Home | None (opens on General) | Short welcome with quick actions and module toggles | Hero, stats, side panel, weekly card, 30 flat cards behind a filter | Grouped cards with headings (done); next: quick actions first, fewer panels |
| Typography | Expressway/PT Sans, user font everywhere | One clean sans in two weights, clear size steps (title > section > row > hint) | Five font families, 12 px floor | Stage 2: two families, four sizes, more contrast between title, section and row |
| Spacing | Dense, AceConfig default | Generous row height, aligned control column, one card per concern | Cards with paired cells; badges on many rows | Fewer badges (done); stage 2: one control column, fixed row rhythm |
| Controls | Ace widgets (sliders with edit box, dropdowns, colour swatches) | Custom sliders, toggles, segmented buttons, each with live preview | Custom kit (slider + box, toggle, chips, dropdown, cog) | Keep; quick-edit popover reuses the same sliders (done) |
| Previews | None in options; test frames in world (`/testui`) | Live preview pinned on top of the module page; clicking a part selects its settings | Pinned preview with states; click only scrolled; sample tiny in a big stage | Click opens size/layout sliders at the click (done); constant footprint (done); stage 2: zoom small samples to fill |
| Size / position editing | `/moveui` movers with nudge window (X/Y, anchor) | Unlock mode with per-frame popup (size, position, scale) and snap | Movers with cog popup (sizes), Layout mode, offsets deep in a card | "Size & position" on every element preview (done); mover popup has sizes; stage 2: X/Y and anchor in the mover popup |
| Unit frames | oUF frames, tags, very configurable | Clean flat frames with class bars and portraits, strong defaults | Own frames with many options | Defaults pass in stage 3 |
| Action bars | LibActionButton bars, paging, fade | Own secure bars, glows, range colouring, keybind mode | Own secure bars, paging, fade, glows | Quick keybind mode (gap list) |
| Nameplates | Own plates, auras, cast bar, threat | Plates with aura groups, kick tick, quest mobs | Own plates and styles | Stage 3 visual pass |

## Key takeaways

1. The window must be a fixed, moderate size; content adapts to it, never the reverse. Phoenix grew with content and
   was too large - both fixed and covered by the geometry test.
2. Players never see developer numbers. Counts should mean something to them ("49 settings", "12 of 30 on").
3. The preview is the main editing surface in EllesmereUI. Clicking a part must open its controls, and size and
   position must be one click away - now true in Phoenix for bars, unit frames and cast bars.
4. Less chrome per row: one badge type (reload), descriptions short, one control column.
5. Consistent iconography: one icon language per screen; no placeholders - now enforced by a smoke test.
6. ElvUI's strength is density and its mover nudge window; EllesmereUI's is presentation. Phoenix keeps its own
   look, takes the ideas: constant window, preview-first editing, quick nudge controls.
