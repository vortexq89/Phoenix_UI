# Audit T213: the user's 24 points (+ item 25, t214)

Requested 1 Nov 2026, 5:25 AM (UTC+3). Item 25 added 5:26 AM. This is the only tracker for this list. It is
linked from [FEATURE_COVERAGE.md](FEATURE_COVERAGE.md) and summarised in [../ROADMAP.md](../ROADMAP.md).
Order of work: crashes and broken behaviour first, then settings consolidation, then the GUI rework.
Each fix lands in its own commit (CHANGES.md + Core/Changelog.lua) and ticks its box here.

Legend: **Cause** = root cause found in the code; **Suspected** = most likely cause, to confirm while fixing.

## A. Broken behaviour (first)

- [x] **1. Action bars tab: the Live Preview gets smaller every time you click the tab.**
  Cause: `Phoenix_UI_Options/Previews/Previews.lua`: `stage:Fit` / `measure()` only ever grows `designWidth` /
  `needHeight` and re-lays the page. On top of that, `Previews/ActionBars.lua` (lines ~171-201, STAGE_W 440 /
  STAGE_H 132) scales its own holder with `holder:SetScale(fit)` and works out y from STAGE_H/fit, so the two
  scales stack on every show. Fix: reset the measured size on each show and let self-fitting previews opt out of the stage zoom.
  **Done 1 Nov:** previews can be marked `selfFit`; the stage then neither measures nor zooms them. The action bars preview is one. Harness check added.
- [x] **2. Action bars flicker when you drag a spell to another slot; you can't move it properly.**
  Cause: `Phoenix_UI_ActionBars/Bars.lua:441`: every `ACTIONBAR_SLOT_CHANGED` (picking a spell up empties its slot)
  runs `RefreshBar` on every bar whose empty slots are hidden. That hides the slot under the cursor and re-lays
  the bar in the middle of the drag. Fix: while the cursor holds an action (ACTIONBAR_SHOWGRID / HIDEGRID), show the
  empty slots and skip the refresh until the drop.
  **Done 1 Nov:** while an action is on the cursor there is no relayout. Bars that hide empty slots show them on ACTIONBAR_SHOWGRID and hide them again on HIDEGRID; only the secure layout snippet runs, so the backdrop and border are not repainted. Harness check added.
- [x] **3. After /reload the micro menu skin is gone (back to Blizzard defaults); the same goes for Bags.**
  Suspected: `Phoenix_UI_Skins/MicroMenu.lua:165-178` skins once and again on PLAYER_ENTERING_WORLD. After a reload,
  Blizzard repaints the micro buttons later (its micro-menu layout / update calls), so the art comes back. Bags:
  `Phoenix_UI_Bags/Chrome.lua` has the same timing problem. Fix: re-apply from a hook on Blizzard's own update and
  layout functions (a post-hook, original code), not from a one-off event.
  **Done 1 Nov:** the micro menu and bag bar are skinned again after PLAYER_ENTERING_WORLD (and 1 s later), after EDIT_MODE_LAYOUTS_UPDATED, and after Blizzard's `Layout` on MicroMenu / MicroMenuContainer / BagsBar and `UpdateMicroButtons`. The re-skins are combined into one per frame. Harness check added; still to confirm in game after a /reload.
- [x] **4. Borders around every box, dialog and group: drop the border-image theme and draw them in code with colour, with better borders whose corners expand properly. Border colour doesn't change when you change the colour.**
  Cause: frames are framed with `UI/ArtKit.lua` `A:Dress(..., {slot=..., out=...})` image pieces. Their colour is baked
  into the texture and not repainted from the theme's border token when it changes. Fix: one code-drawn border
  (edges plus corner pieces that grow with the size), coloured by the `border` token and repainted on theme change.
  **Done 1 Nov:** `Skin:Panel` always draws a flat theme fill and a 1 px code border in the panel's border token, which is repainted on every theme change. The picture-frame path (`opts.art`) is ignored. Harness check added. The textured buttons and toggles are restyled in the GUI rework (EllesmereUI widgets).
- [x] **12. Tooltip: the theme/border art sits inside the tooltip instead of at the edge.**
  Cause: `UI/ArtKit.lua:501` `A:DressTooltip` (`out = 6`, scale 0.35). The art's inner padding is larger than `out`,
  so the visible frame line lands inside. This goes away with the code-drawn border (item 4) anchored on the tooltip edge.
  **Done 1 Nov:** `A:DressTooltip` is removed; tooltips keep only their code backdrop and border, on the edge.
- [x] **14. AFK preview button: you can't exit it with the mouse, only with a key. Make any mouse move or click exit it.**
  Cause: `Phoenix_UI_AFK/AFK.lua`: the screen `EnableMouse(true)` takes the mouse but has no mouse handler. It only
  closes on PLAYER_FLAGS_CHANGED (a key press clears AFK), and a preview never was AFK. The file also uses an
  `OnUpdate` (line 78) for the clock and spin, which breaks the Ticker rule. Fix: OnMouseDown closes it, cursor moves
  are checked from the Ticker registry while it is shown, and the OnUpdate moves to the Ticker.
  **Done 1 Nov:** a click closes the AFK screen; the preview also closes on any mouse move. Spin, clock and the mouse watch run on a C_Timer ticker that stops when the screen hides (the OnUpdate is gone). Harness check added.
- [x] **15. Bug upload: show clearly whether it was sent (success or failure) and tell the user what happens or what to do.**
  Cause: `Modules/Bugs/Viewer.lua:342-344`: "Upload" only opens the Bugs settings page. The sending is done outside
  the game by PhoenixUploader reading `PhoenixUIBugsDB` (Modules/Bugs/Bugs.lua:54), so the game never learns the result.
  Fix: a status line per report (Waiting: sent after /reload or logout, Sent at time, Failed with the reason and
  the next step). It reads an answer the uploader writes back into PhoenixUIBugsDB. That needs a small uploader
  change, website untouched apart from `worker/phoenix/*`.
  **Done 1 Nov (in game):** Upload now says what happens. If sending is off, it opens the Bugs settings and says where to switch it on. If sending is on, it says how many reports are ready, that they are saved on /reload or logout, and that the Phoenix Uploader app sends them and shows sent or the error. Without the app nothing is sent. The text is in all 10 locales. **Follow-up:** an in-game sent / failed line per report needs the uploader to write its result back, which means a new uploader release.
- [x] **16. Diagnostics shows weird icons; fix them.**
  To audit while fixing: the Diagnostics page's glyph names against `ns.Icons` (a missing glyph shows the fallback
  square). Files: Phoenix_UI_Options (About / Diagnostics section), UI icon atlas.
  Cause found: `Core/Icons.lua`. Icon source "auto" swapped the whole window to stock game spell icons (spyglass, fabric, gems...) as soon as a diagnostics run reported one icon atlas as not loaded. Diagnostics also offered a "Game icons" picker.
  **Done 1 Nov:** the window always draws Phoenix glyphs; the picker is gone and a saved "game" choice is cleared once. Harness checks updated.
- [x] **22. The GUI window can only be dragged by the logo in the top-left; make the whole title bar and top border draggable (and remember its position).**
  Cause: `Phoenix_UI_Options/Config/Window.lua:150-157`: the drag handle `h` is only `RAIL_W x HEAD_H` (the rail head
  with the logo). The rest of the top bar has no drag (the footer handle is at 602-603). Fix: one drag strip across
  the full width and top border, below the close and search buttons, saving through the existing `savePosition`.
  **Done 1 Nov:** the window now moves from the rail head, a strip along the whole top border, and every page header (title band). The position is saved as before. Harness check added.
- [ ] **23. Many settings and frame positions reset to defaults after /reload. Find every SavedVariables persistence bug.**
  To audit: every `## SavedVariables` / `SavedVariablesPerCharacter` in the .toc files against the tables each
  module writes, defaults merged over saved tables (overwriting instead of filling in), movers `set` writing to a
  copy, and Forever .toc lines that differ from retail. Add a harness check that saves, reloads and compares.
- [ ] **10. Talent frame borders are wrong.** Files: `Phoenix_UI_Skins/Talents.lua`. Same border system as item 4.
- [ ] **6. Character panel is a mess: Reputation is mixed up and overlapping. Fix and polish it.**
  Files: `Phoenix_UI_Skins/CharacterWindow.lua`, `CharacterLists.lua`, `Character.lua`. Suspected: the reputation
  list is laid out over the character tab's own area (two owners of the same space).
- [ ] **19. Group/raid frames: too hard; one change can push the frames entirely off screen. Need simple horizontal/vertical, width, height, spacing between members and between groups, and group numbers above each group; clamp to the screen.**
  Files: Phoenix_UI_GroupFrames, `Phoenix_UI_Options/Options/GroupFrames.lua`. Missing: clamp to the screen
  (SetClampedToScreen plus clamping the mover), a single orientation option, group labels.

## B. Settings consolidation (second)

- [ ] **5. Too many overlapping theme/colour systems: Accent, Interface>Skins, Phoenix>Presets, Interface>Skin>Appearance, Phoenix>General, Phoenix>Textures and more. Consolidate into ONE organised system with no duplicates and no conflicting settings.**
  Files: Options/General.lua, Options/Skins.lua, the presets / textures pages, Core theme tokens. Plan: one
  "Appearance" page (preset, accent, colours, textures, borders, fonts) that owns every token; the other pages link to it.
- [ ] **8. MoveAny: keep only two features: (a) move ANY unmovable Blizzard frame (auction house, character panel, achievements, warband collections, group finder and all the rest), (b) Shift + mouse wheel over a frame changes its scale. Remove or merge the other MoveAny extras so nothing duplicates Layout mode.**
  Files: `Phoenix_UI_Skins/Move.lua`, Modules/Movers, Options/Movers.lua.
- [ ] **9. Phoenix Layout/Edit mode: per-frame background transparency while editing. Ctrl+right-click resets a frame's position; plain right-click opens a quick menu (size, scale, position, transparency and every related option), not just the small cog. Reconcile Blizzard Edit Mode and Phoenix Layout so each frame is controlled in one place.**
  Files: Modules/Movers (mover overlay, cog menu), `Config/Window.lua` `layoutMode`, ns.EditMode.
  *(The middle of this point was cut short in the relayed text; the wording here is rebuilt from the plan summary.)*
- [ ] **18. Interface > Data bar: many overlapping and conflicting PANELS settings; the background doesn't cover everything when all options are added.**
  Files: Phoenix_UI_DataTexts and Options/DataTexts.lua. Suspected: the panel background has a fixed size, not
  sized from its slots.
- [ ] **11. Damage meter: let the user add multiple meter windows (damage, healing, dispels, etc.).**
  Files: Phoenix_UI_DamageMeter (Group.lua shows the extra-window pattern), Options/DamageMeter.lua.
- [ ] **20. Chat needs corrections and improvements.** Files: Phoenix_UI_Chat, Options/Chat.lua. Includes the open
  in-game checks: the grey strip over the top edge of the chat panel and the white outline around General.

## C. GUI rework (last; structure first, styling token-driven)

- [ ] **7. GUI tabs need a better list style; some tabs are in the wrong groups; many tabs are missing icons (give every tab one).**
  Files: `Config/Window.lua` (rail), page registration in Options/*.lua.
- [ ] **13. Live Previews: fix every one to show exactly the real result; remove previews from settings that don't need one.**
  Files: Phoenix_UI_Options/Previews/*. It shares the stage fix from item 1.
- [ ] **17. About page needs correction and improvement.** Files: Options About page.
- [ ] **21. Unit frames: many issues, including in the live preview; unclear how to lock them; the GUI covers half the screen.**
  Files: Phoenix_UI_UnitFrames, Options/UnitFrames.lua, Previews. Lock: one clear Lock / Unlock in the page header.
  Covering: the window size and scale (`Config/Window.lua` lines 78/101).
- [ ] **24. Overall: rework the GUI (settings, tabs, sections, dialogs, lists, live preview) to be organised, simple and professional, with fast, easy options.**
- [ ] **25 (t214, replaced by t215 below). The GUI rework also includes a NEW theme and GUI style: design, colours and icons.** The visual
  design comes from figma bro after the user approves it. Until then: the structural rework only (organisation,
  tabs, sections, consolidation, persistence), with every colour, size and icon read from theme tokens so the new
  design can be dropped in.

## t215 design decision (1 Nov 2026, 5:31 AM UTC+3): one theme, the EllesmereUI look

This replaces item 25 and drives items 4, 5 and 24. The GUI, theme, colours, borders and unit frame look follow
EllesmereUI exactly. The reference is the user's read-only copy in `I:\EllesmereUI*` (EllesmereUI 9.6.1). Phoenix
writes its own code to reproduce the look; no EllesmereUI file, function or media is copied. Values below are
measurements of the look (sizes, colours, alphas), written as Phoenix tokens.
There is **one theme**. The Accent, Skins, Presets, Appearance, General colour and Textures theme systems are merged
into it; old saved keys are migrated once (read the old value, write the token, drop the old key) so nothing conflicts.
The **only Phoenix-specific option** is an optional phoenix border around the portrait on the Player and Target unit frames.
No other variants.

### Mapping (EllesmereUI reference -> Phoenix token / place)

| Look element | EllesmereUI reference (I:\EllesmereUI) | Phoenix target |
|---|---|---|
| Accent | default theme accent #0CD29D (Forever client: #DCA77F) | `accent` token; the only colour choice is accent (default as reference, class colour, custom) |
| Panel background | warm near-black rgb 0.069 / 0.058 / 0.047 | `bg.panel` |
| Border | white at alpha 0.05, 1 px, drawn in code | `border` (item 4: code-drawn border, every box repainted from this token) |
| Text | white 1.0; dim white 0.53; section header white 0.41 | `text.primary` / `text.secondary` / `text.section` |
| Option rows | alternating black overlay 0.10 / 0.20 | `row.odd` / `row.even` |
| Slider | track white 0.16, fill accent 0.75, input box dark 0.25 with border 0.02 | Widgets slider |
| Toggle | off track #444 at 0.65, on track accent 0.75, knob white 0.5 off / 1.0 on | Widgets toggle |
| Checkbox | box rgb 0.112 / 0.105 / 0.098, border 0.05, checked 0.15 | Widgets checkbox |
| Button | bg rgb 0.089 / 0.080 / 0.072 at 0.6 (hover 0.65), border white 0.3 (0.45), text white 0.55 (0.70) | Widgets button |
| Dropdown | bg rgb 0.103 / 0.095 / 0.088 at 0.9 (0.98), border 0.20 (0.30), value text 0.50 (0.60), item hover 0.08, selected 0.04 | Widgets dropdown |
| Two-up / three-up rows | item 350 wide with a 42 gap / item 180 wide with a 50 gap | options layout grid |
| Window | click area 1300 x 946, centred; sidebar 295; header 138 (title, description, accent glow, tab band); tab bar 40; footer 82; content padding 45 | `Config/Window.lua` (items 7, 22, 24) |
| Sidebar nav | selected text and icon 1.0; enabled 0.6; disabled text 0.11, icon 0.20; hover 0.86 / 0.39; an icon on every entry | rail (item 7) |
| Close / collapse | 40 x 40 buttons at the top right | window chrome |
| Unit frames | width 181, health 46, power 6, 1 px border, absorb and heal-absorb bars 4, player cast bar 181 x 14, bottom text bar 16 | UnitFrames defaults (item 21) + phoenix portrait border option (Player, Target) |

Still to measure before the code change (from the same reference, by reading, not copying): the font sizes per
text role, the tab underline and sidebar indicator shapes, the popup and tooltip style, the raid / party frame
defaults (item 19), and the data bar and chat panels (items 18, 20).

### t217 (5:51 AM): unit frames and the phoenix portrait border

- Unit frames match EllesmereUI (approved t217): Player and Target 181 wide, health 46, power 6, 1 px border, an
  attached square 2D portrait (EllesmereUI's default `portraitStyle = "attached"`, `portraitMode = "2d"`).
- Phoenix portrait border (figma bro handoff in `/workspace/phoenix_ui/handoff/portrait_border/`):
  - **square shape only** (EllesmereUI's portrait shape); the round pieces are dropped from the atlas and the code;
  - an option on the Player and Target frames, **off by default**;
  - class pips are not changed unless the border is on;
  - **not wired until the user approves** the code (t217); it gets its own commit then.
