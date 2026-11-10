# Phoenix UI build loop

The standing brief for every working session on Phoenix UI. Read it first, do one turn of the loop, log the result at the bottom. The owner is VortexQ8.

## Mission

Phoenix UI must be the easiest addon in World of Warcraft to make a UI your own, at EllesmereUI's quality and then past it: every EllesmereUI feature plus Phoenix's extras, in Phoenix's own look. A player should be able to change anything they can see by pointing at it. EllesmereUI's code is never copied; its methods are studied and rebuilt in Phoenix's own architecture.

## Rules that never bend

1. AGENTS.md hard rules: no globals, theme tokens only, every string in all ten locales, lint clean, APIs verified for retail (12.1.5) and Forever (1.60.1), secret values never compared, nothing protected touched in combat.
2. Every gate green before a commit: `luacheck .` (both standards), `tools/check_api.py` (both flavours), `check_ids.py`, `check_locales.py`, the smoke harness (full and core alone) and `tools/check_flavors.py`.
3. Git: branch `feat/phoenix-colors`, never `main`, never force. Commit, push and install to both clients after each green turn (owner's standing instruction of 8 Nov).
4. English first; the other nine locales get the same keys and are polished later.
5. No FPS cost: nothing in the settings window runs when it is closed; no OnUpdate while idle; the frame budget test must hold.
6. Say what was not verified. The offline renderer cannot see the game; anything only the game can show is listed as "needs an in-game look".

## The loop

One turn, in this order:

1. **Pick** the top open item of the backlog below (or what the owner just asked for; an owner message always goes first).
2. **Study** how EllesmereUI solves it: open its files under `_forever_/Interface/AddOns/EllesmereUI*`, read the method (what the player sees and can do), write two or three lines of findings into this file. Never paste its code.
3. **Design** the Phoenix version so it is at least as easy: fewer clicks, the real thing shown, direct manipulation where possible. If Phoenix can do something EllesmereUI cannot (undo, search, drag in preview), use it.
4. **Build** in the module's own code path: previews call the builders that draw the real frames, never a mock.
5. **Check the page end to end** with the page checklist.
6. **Gates**, then commit, push, pull on the PC, install to retail and Forever.
7. **Log** the turn (date, what changed, what needs an in-game look) and re-rank the backlog.

## Page checklist (every page touched in a turn)

- **Preview**: only if the page styles something drawn on screen. One sample of the element picked in the scope bar, centred, real size, drawn by the real builder, every part present, the player's own spells, name and class on it, motion live (casts fill, cooldowns sweep) unless Reduce motion is on. Tabs that change nothing on the sample hide it.
- **Direct editing**: every part of the sample is a hot spot. Click jumps to its settings and flashes the row; dragging an edge sizes it; dragging the body moves it.
- **Lists**: anything that is a list of spells, items, auras or names is shown as rows with the real icon and name, added from a picker of what the player really has, removed with one click, reordered by dragging. Never a box of typed IDs as the only way.
- **Icons**: real game art for spells and items; Phoenix icon set for interface symbols; no placeholder squares.
- **Texts**: short label, one-line description, same word for the same idea on every page (duplicate scan `tools/check_dupes.py`), no jargon, no cut-off or overlapping text (`tools/smoke/layout_lint.py`).
- **Organising**: most used first; at most six tabs; sections fold; one owner per setting, link rows elsewhere; advanced options behind a cog.
- **Feedback**: a change shows on the sample and in the world at once; Undo names it; a module that is off says so.

## What EllesmereUI does (method notes)

- **Preview where it helps**: only on pages styling an on-screen element (action bars, unit frames, raid frames, nameplates, resource and cast bars, cooldown manager, data bars, Mythic+ timer, tooltip). None on chat, bags, minimap, damage meters, quest tracker, friends, group finder. Cleared on tabs it does not serve.
- **A 1:1 replica**: one sample at the real on-screen pixel size, built part by part to mirror the live frame (it keeps a hand-written copy; Phoenix reuses the real builder, which cannot drift).
- **The player's own data**: class, spec, level, name, portrait and spell icons come from the character (spell textures from spells the character knows), so the sample looks like their game.
- **Click navigation**: invisible hit areas over each part scroll to and highlight the matching setting.
- **Direct manipulation in the cooldown manager**: the bar is shown with its real spells; click a slot to open a spell picker (the character's spells with icon and name), drag to reorder, right-click to remove.
- **Sample values re-rolled** when a tab opens, so text formats are seen with varied numbers.

## Backlog (top first)

2. **Names under the tiles** when a spell list is short.
3. **Action Bars preview**: hot spots on the hotkey and count texts (needs a text hot spot that does not start a size drag).
4. **Row flash** exists (`row:Flash()` on every jump); compare its strength with EllesmereUI in game.
5. **Simple view, fine pass**: review which rows count as fine-tuning page by page (`advanced = true / false` on the row overrides the key rule in Renderer.lua).
10. **Other nine locales** reviewed by page.
11. **Audit waves 0 to 4** from `PUI_AUDIT_2026-11-07`.

## Log

- **10 Nov 2026, turn 1**: preview policy applied (13 pages keep a preview, 17 lost it, tabs can opt out with `preview = false`). Nameplate preview is one full plate with a live cast. Needs an in-game look: plate centring.
- **10 Nov 2026, turn 2**: samples wear the character's own spells (icons from the action bars, cast named after the real spell) in every preview and in Test frames. Every part of the nameplate and unit frame samples is a hot spot (name, health text, power text, portrait, marker, auras, cast bar, class resource); edges of a part drag its size where the page has a size row. This file written. Needs an in-game look: real icons appear, hot spots land on the right rows.
- **10 Nov 2026, turn 3**: `ns.Opt.SpellList` (Config/SpellList.lua): lists of spells and items are tiles with real icons, right-click to remove, drag to reorder, a + tile with a spellbook or bag picker and search, the list still editable as text. Applied to six lists (Tracker custom bars, aura glows, wanted auras, aura bars; Action Bars item bar and ring). Needs an in-game look: icons resolve for names and items, drag reorder lands on the right tile, the picker popover position.
- **10 Nov 2026, turns 4 to 6**: pickers on the three single-spell fields (`single`, `store = "name"`, `addSuffix`). Custom Cooldown Manager bars preview their own spells; the preview is a hot spot to the list. Cast Bars preview audited: live casts, hot spots on icon, name and timer. Needs an in-game look: the picker inside the range-fade cog popover, the trigger spell stored by name.
- **10 Nov 2026, turns 7 and 8**: Group Frames and Auras previews audited (hot spots). Tabs: no page over six (Nameplates 9 to 6, Group Frames 8 to 5, Unit Frames 7 to 6), guarded by a harness test. Needs an in-game look: the merged tabs read well and are not too long.
- **10 Nov 2026, turn 9**: search results highlight the typed words; up, down and Enter work from the search box. Needs an in-game look: the edit box passes the arrow keys (OnKeyDown) on both clients.
- **10 Nov 2026, turns 10 and 11**: custom Cooldown Manager bars are edited in the preview (right-click remove, drag reorder, click to the list, with Undo). Previews audit finished for Data texts, Tooltip, Cooldown text, Mythic+ timer (hot spots). Needs an in-game look: drag reorder inside the preview, Undo after a removal.
- **10 Nov 2026, turn 12**: Simple view (footer button, off by default): rows whose key ends in a fine-tuning word hide; a jump from search or the preview reveals the row. Needs an in-game look: the footer still fits at the smallest window width; the choice of hidden rows feels right.
- **10 Nov 2026, turn 13**: full render of 98 views: 0 overlaps, 0 outside the window, 9 one-line header descriptions cut by design (full text in the tooltip). Anchor conflicts (72, then fewer after the description row fix): the remaining ones are a top corner plus RIGHT on regions with an explicit or text height, which the game resolves from the top and the height, so they stay warnings and are not rewritten blind. Range differences between frame families (9) reviewed: they follow the elements' real sizes (a nameplate cast bar is smaller than a unit frame's), left as they are. Spell list texts translated in nine languages.
