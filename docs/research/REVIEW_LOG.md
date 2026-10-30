# Polish review log (t156)

One system at a time: compared with EllesmereUI (local copy, read as reference only - nothing copied) and ElvUI
(from its published behaviour; not installed on the test PC), then fixed. Each entry lists what is added, what is
missing, the look, the presentation, size and shape, and the features, and what was changed.

## 1. Settings window (v4 "Flow")

Reference: EllesmereUI's panel (EllesmereUI_Panel.lua): 295 px sidebar with a fixed nav block (Unlock, Global,
Patch notes, Profiles) and one row per addon with its own on/off switch; 138 px header (title, description,
banner glow) with a 40 px tab bar under it; 82 px footer; search highlights the hits on the page; remembers the
last page per module; resizable with a corner grip. ElvUI: AceConfig tree on the left, tabs as nested tree nodes,
no live preview, fixed fonts, a search box since 13.x, per-module enable toggles inside each page.

| Area | Phoenix before | Compared | Finding | Fix |
|---|---|---|---|---|
| Sidebar switches | on/off dot, display only | EUI: a switch per addon row | turning a module off took two clicks (open page, Enabled) | the dot is now the module's switch (click, tooltip says so) |
| Last sub-page | reset to the first on every reload | EUI keeps the last page per module | reopening Unit Frames always landed on Frames | ui.lastTab[module] kept and reopened |
| Header | flat band | EUI: banner glow behind the title | header did not read as the page banner | faint accent wash from the module tile |
| Changed count | count only | neither has one (Phoenix-only) | count told you how many but not where | clicking it walks through the changed settings, opening folded cards |
| Narrow cards (3 columns) | RELOAD badge cut labels to "Bars o..." | EUI uses one wide column, no clipping | badge took 64 px of a 160 px text column | the badge folds to its icon when the label would be cut |
| Columns | 3 / 2 / 1 masonry, folding cards with value chips | EUI: one column of sections; ElvUI: one column | Phoenix shows ~2.5x the settings per screen | kept |
| Size | 1400 x 860, resizable, min 1100 x 700 | EUI ~1300 x 900 resizable | comparable | kept |
| Footer | 40 px: profile, Layout, Test, status, scale | EUI 82 px with big buttons | ours is denser, same tools | kept |
| Fonts | Phoenix Font, Expressway when installed | EUI ships Expressway; ElvUI PT Sans Narrow + Expressway | parity without redistributing Expressway | kept |

Open (later passes): search hits could also be highlighted on the page while typing (EUI does this); keyboard
focus of the search with Ctrl+F.

## 2. Unit frames

Reference: EllesmereUI Unit Frames (visibility rules per frame: combat, target, mouseover, casting; portraits
2D/3D/class; absorbs, heal prediction, class power, castbar on the frame, range fade, dispel highlight) and ElvUI
(oUF-based: tags, combat fader with "show on target / casting / hover / health", aura bars, portraits). The PC
was offline for this pass, so the comparison uses both addons' documented features, not a fresh read of the code.

| Area | Phoenix | Compared | Finding | Fix |
|---|---|---|---|---|
| Indicators | leader, raid marker, combat, resting, ready check, resurrection, role, PvP, elite, threat | parity with both | complete | none |
| Health | class / reaction / gradient colours, absorbs, heal prediction, tags | parity | complete | none |
| Class power | runes, combo points etc, fade when empty | parity | complete | none |
| Range | range fade with its own alpha, arena stealth alpha | parity | complete | none |
| Out-of-combat fade | fades whenever out of combat | ElvUI fader and EUI visibility rules show the frame again while you target, cast or hover | a faded player frame stayed faded while casting or targeting out of combat | new "Show while active" (on by default, in the fade cog): full alpha with a target, while casting or channelling, or under the mouse; evaluated on the existing range tick |
| Settings depth | 371 settings across 7 sub-pages | EUI ~250, ElvUI ~400 | at the deep end | none |

Open (later passes): per-frame visibility rules beyond fading (hide in pet battles / vehicles) as EUI offers.
