# EllesmereUI gap audit (t123u)

How EllesmereUI presents and organises its settings, compared with Phoenix UI, feature by feature.
Sources: ellesmereui.com, and the installed EllesmereUI addons on the PC. I read only their file names and
comments, for presentation and UX. **No EllesmereUI code, layout data or assets are used in Phoenix.**
Status: **has** = Phoenix does it, **partial** = some of it, **missing** = not there.
"Changed" marks what this round (t123u) added.

## 1. Structure: modules, pages, tabs
| Item | EllesmereUI | Phoenix | Status |
|---|---|---|---|
| Module list | Left list of modules, each its own addon | Icon rail of 7 groups, then a page list (bars first since t119) | has |
| Sub-pages per module | Named pages inside a module (e.g. Action Bars: Bar Display, XP Bar, Menu/Bags/Rep, Animations) | Tabs inside a module page (Action Bars: Bars, Buttons, Text, Extra) | has (tabs instead of pages) |
| Same tab pattern across modules | Pages differ by module, each grouped by job | Main/Layout first, then Look, then Text, then Extras or Behaviour; Unit Frames and Nameplates add Health, Power, Indicators and Auras | has |
| No single-item tabs, no setting on two tabs | — | Harness check "tab consistency" (changed): every tab has at least 2 rows and no visible setting is on two tabs. It passes for all modules | has (changed) |
| Big modules without tabs | — | Every long page now has tabs (Bags, DataTexts, Chat, and since 2026-10-29 General: Appearance, Text, Colours, Behaviour; Skins: Blizzard windows, Appearance, Behaviour) | has |
| Search across everything | Global search | Search across every page, jumps to and flashes the row | has |

## 2. Preview
| Item | EllesmereUI | Phoenix | Status |
|---|---|---|---|
| Location | Content header at the top of the page: element dropdown, then the live preview, then the settings | Changed: previews always sit at the top of the page under the element chips (no longer docked in the narrow right column) | has (changed) |
| Stays in view while scrolling | The header stays fixed | The preview pins and sticks once the page header scrolls away | has |
| Real size, real content | The real bar's buttons and icons | Real spells and units at true size, scaled only to fit, with a 1:1 / % label (t119) | has |
| Per element / per tab | Follows the selected bar | Follows the selected chip; state chips (cooldown, low health…) | has |
| Click a preview part to jump to its setting | Hit overlays on preview elements open the setting | Not there | **missing** |
| Dismissable hint | One-line hint, can be dismissed | Hint text, fold/eye button | has |

## 3. Editing several elements at once (bars, unit frames, nameplates, cast bars)
| Item | EllesmereUI | Phoenix | Status |
|---|---|---|---|
| Choose the element being edited | Dropdown | Chips (bars, units, plate kinds, cast bars) | has |
| Select several and edit together | "Apply to Multiple": a checkbox popup per setting | Shift-click chips to add elements; every edit goes to all selected elements. Tested for Action Bars, Unit Frames, Cast Bars and Nameplates (changed) | has |
| Everything at once | "Apply to All" link under a setting | The "All" toggle on the chip bar (edits go to every element), plus the ⇄ apply-to-all button on each row | has |
| Shows what is being edited | Current element marked | Changed: the hint line becomes "Editing 3: Bar 1, Bar 2, Bar 3" | has (changed) |
| Mixed values shown | Sync icon shows whether elements match | Changed: a "MIXED" tag on a row whose selected elements differ | has (changed) |
| Copy settings from | "Copy From" | "Copy settings from" dropdown. Changed: it keeps each element's own position and on/off state, so copying no longer stacks bars on top of each other | has (changed) |
| Positions never fan out | — | Changed: anchor and X/Y rows are per element (`single`), even with All or several selected | has (changed) |
| Flash on synced rows | Accent border flash on the rows it applied to | Only the row flashes when search jumps to it | partial |

## 4. Reset, presets, profiles, import/export, setup
| Item | EllesmereUI | Phoenix | Status |
|---|---|---|---|
| Per-setting reset | Yes | ↺ on each changed row, and right-click a row | has |
| Reset a module | Yes | "Reset module" in the page header | has |
| Presets | Community presets, imported in one click, shown on the site | Built-in presets page | partial (no community gallery, no screen preview) |
| Profiles | One profile across modules | Profiles page: per character, copy, delete | has |
| Import / export | Profile strings | Profile import/export strings | has |
| First-install wizard | Yes (FirstInstall) | No guided first run; there is a migration notice | **missing** |
| Unlock / move | One key makes everything drag-and-drop, snaps to frames, screen and pixel grid | Layout mode: boxes only for shown frames, grid, snapping, arrow-key nudge, per-frame reset, Settings button (t119) | has |
| Edit a frame's settings in place while moving | Cog popups on the element | Settings button jumps to the page, not a popup | partial |
| Quick keybind mode | Built-in | Blizzard's own | missing |

## Next gaps, most valuable first
1. Click a preview element to jump to its setting.
2. A first-run setup wizard: role, resolution, preset.
3. Split Bags and DataTexts into tabs (Layout / Look / Text / Behaviour).
4. An in-place settings popup on a mover box.
5. A preset gallery with a full-screen preview.
6. A flash on every row that receives an apply-to-all edit.
