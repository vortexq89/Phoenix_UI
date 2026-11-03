# Phoenix UI rebuild map: the EllesmereUI look, structure and behaviour (t222, 1 Nov 2026)

Status: **plan only, no code**. It replaces the t213 consolidation and GUI-rework items (5 part 2, 7, 8, 9, 11, 13,
17, 18, 20, 21, 24); those are now the work packages below. Done before t222 and kept: the t213 broken-behaviour
fixes and item 5 part 1 (one theme, EllesmereUI tokens and accent, migration step 8).

Sources read (all read-only, copied to the box as text only, never into the repo):
`I:\EllesmereUI*` 9.6.1 (24 addons, ~600 000 lines of Lua, 157 000 of them options pages), `I:\EllesmereUI_WindTools`
0.2.8, `I:\idTip` 12.1.4, `I:\MoveAny` 1.13.22, `I:\PremadeGroupsFilter` 7.6.5, `I:\Simulationcraft` 12.1.5-02, and
the newest captures in `bugs\shots` and the retail Screenshots folder.
Inventories, generated from the reference and committed next to this file:
- [ellesmere_inventory/SETTINGS.md](ellesmere_inventory/SETTINGS.md): every one of the 1 830 option rows, page by page
  and section by section, with its saved key and default.
- [ellesmere_inventory/FILES.md](ellesmere_inventory/FILES.md): every EllesmereUI Lua file and its size.

## 0. Rules this plan keeps

- **Copy the look, the structure and the behaviour, never the Lua.** EllesmereUI's own code has no open licence
  (LIBRARIES.md §9). Every Phoenix file is written fresh. WindTools (MIT upstream, ElvUI_WindTools) and idTip
  (open upstream) may be read for method. **PremadeGroupsFilter is GPL-2**, so it is behaviour only.
  MoveAny has no licence file, so it is behaviour only too. SimulationCraft's addon is Unlicense and is already
  credited in Phoenix_UI_Sim/Export.lua.
  Note: the licence words in the local PGF README and headers were find-and-replaced ("licens by VortexQ8e"), so
  the upstream licence (GPL-2) applies. The same goes for the `Author` lines that were changed to "VortexQ8".
- Media: only files whose licence allows it. No EllesmereUI logos, no Ember-Bevel class, spec or ability icons, no
  custom cursor, no raid-warning banner, no duplicate Teko. EllesmereUI's fonts are mostly commercial or OFL: take
  only OFL ones (Barlow, Exo, Fira Sans, Poppins, Russo One, Ubuntu, Changa, Cinzel Decorative) after checking each
  licence. Expressway is a commercial font, so Phoenix keeps its own Phoenix Font as the house face.
- Every setting applies live; no OnUpdate outside the Ticker registry; secret values go to widgets and are never
  compared; there are no slash commands and everything is in the GUI; there are 10 locales; Forever has its own TOC
  path in every package.
- One theme. The only Phoenix extra is the square phoenix portrait border (off, unwired until approved).

## 1. EllesmereUI inventory (what it has and how it presents it)

### 1.1 Shell: window, navigation, widgets (EllesmereUI/EllesmereUI_Panel.lua, EllesmereUI.lua, EllesmereUIOptions/EllesmereUI_Widgets*.lua)

| Part | EllesmereUI value / behaviour |
|---|---|
| Window | click area 1300 × 946 inside a 1500 × 1154 background; there is one background picture per theme (eui-bg-*.png). Phoenix keeps its flat black and small logo. |
| Sidebar | 295 wide. Group rows are 28 high with a 10 gap. There is no on/off switch per group. The child rows are 28 high: an icon, a name and an enable state (selected text alpha 1, enabled 0.6, disabled 0.11, hover 0.86/0.39). Search sits at the top of the sidebar. |
| Groups (order) | **Core**: Action Bars, Nameplates, Unit Frames, Cooldown Manager, Resource & Cast Bars, Raid & Party Frames. **QoL**: Quality of Life, Forever Essentials, Simple Loot Council, AuraBuff Reminders, DataBars, Quickdraw, Loadout Manager, Party Mode. **UI Reskin**: Blizzard Skins+, Group Finder, Damage Meters, Mythic+ Tools, Quest Tracker, Friends, Minimap, Chat, Bags. Then **Standalone**. Global pages: General, Colors, Fonts, Textures, Style, Glows, Profiles, What's New, Unlock Mode. |
| Header | 138 high: title, description, accent glow band. Below it a tab bar, 40 high, one tab per module page (e.g. Action Bars: Display / XP Bar / Menu-Bags-Rep / Animations). |
| Content | 45 padding. **Section header** (white 0.41 caps) and then **DualRow** rows: two widgets side by side, each 350 wide with a 42 gap (triple 180 / 50). Rows alternate black 0.1 / 0.2. A **cog** (inline popup) holds the advanced sub-settings of a row. A **sync icon** applies a value to all frames. |
| Footer | 82 high: profile, Reload, Unlock Mode, links. |
| Widgets | toggle (off track #444 0.65, on accent 0.75, knob white 0.5/1), checkbox (box 0.112/0.105/0.098), slider (track white 0.16, fill accent 0.75, input 0.030/0.023/0.018 at 0.25), dropdown (bg 0.103/0.095/0.088 at 0.9, border white 0.20), button (bg 0.089/0.080/0.072 at 0.6, border 0.3, text 0.55), colour swatch, segmented control, checkbox-dropdown (visibility), aura popups. |
| Search | global: every page is pre-built off-screen and indexed (EllesmereUI_GlobalSearch.lua). |
| Accent | EllesmereUI #0CD29D; Forever #DCA77F; Horde, Alliance, Faction auto, Midnight, Dark, Pixels, Class, Custom. Phoenix keeps EllesmereUI green, Class and Custom, plus a Forever default of #DCA77F (§6). |
| Unlock mode | EUI_UnlockMode*.lua: movers, anchors (attach a frame to another), snap, grid, flashlight, orientation, per-frame reset, and a position registry. |
| Profiles | EllesmereUI_Profiles.lua: profiles, import / export (LibDeflate), spec overrides (EUI_SpecOverrides_*.lua: per-spec layers, conditional overrides). |

### 1.2 Modules (file, pages and sections, number of settings; keys and defaults in SETTINGS.md)

| EllesmereUI module | Main files | Pages → sections (settings) |
|---|---|---|
| Action Bars | EllesmereUIActionBars (Setup, Apply, Events, ButtonArt, Glows, XPBar) | Display: bar background, icon appearance, icon effects, paging, text (34); visibility & layout (11); XP Bar: core, text positions, display (10); Menu, Bags & Rep: micro menu & bags, vehicle bar (11); Animations: bar interactions, proc glow (10) |
| Nameplates | EllesmereUINameplates (Plate, Layout, Styles, Colors, AuraContainers, ClassPower, Friendly) | Display: style, core positions, text positions (17); health & cast bar, cast bar, target / focus / hover effects, class resource, text (31); Colors: debuff colouring, enemy, threat (18); General: friendly, enemy, auras, target & focus, misc (36) |
| Unit Frames | EllesmereUIUnitFrames (Init, Reload, StockStyles, Castbar, Absorb, AuraContainers) | Display: per-unit tabs with display, portrait, text bar, extras (37); health, power, class resource, absorbs & heals (48); cast bar, buffs & debuffs (21); text slots; Boss; Mini frames (67); Aura bars (24). Sizes 181 / 46 / 6 (approved). |
| Raid & Party | EllesmereUIRaidFrames (ClickCast, BuffManager, DebuffManager, AuraContainers, PetFrames) | frame sizes, display, layout, style, raid sync & solo (28); health, absorbs, power, text (38); indicators, dispels, top name bar, friendly boss, extra frames, pets, extras (57); buff / debuff managers (37); portrait, party targets (13); click casting |
| Cooldown Manager | EllesmereUICooldownManager (Rebuild, Bars, Hook*, SpellPicker, FakeActive) | bar layout, focus-kick, icon display, extras (48); buff bars (27); spell picker; glow and talent conditions; rotation assist |
| Resource & Cast Bars | EllesmereUIResourceBars (Build, Update, CastBar, SwingTimer, ArcaneSoul) | bar display & shifting (25); health (10); power (10); class resource (18); cast bar with ticks and latency (22); GCD bar (14); swing timer (18); totem bar (7) |
| AuraBuff Reminders | EllesmereUIAuraBuffReminders | core, display, raid buffs, Forever, auras, class (rogue / paladin / shaman / warlock), pets, consumables, active (37) |
| Quality of Life | EllesmereUIQoL (MovementAlert, RaidTools, Cursor, Shifter, Bloodlust, UpgradeCalc) | self combat text, general, extras, crosshair, group finder, UI (30); alerts (4); auto logging / keystone check / LFG reminder / waypoint (10); battle res + bloodlust (29); cursor GCD / cast ring (26); movement alert (7); raid tools: quick fire, group buttons, pull timer (7); shifter (7); upgrade calculator (10) |
| Forever Essentials | EllesmereUIForeverEssentials (ThreatMeter, LootFeed, FlightTimer, JunkItems, ClassicTalents, ClassicSpellbook) | spell ranks, world map, classic windows, stats, quest rewards, pets, stance, names, gathering, junk, fishing (31); loot feed (8); macros (5); threat meter (14); flight timer (13) |
| Blizzard Skins+ | EllesmereUIBlizzardSkin (WindowPacks, WindowEngine, CharacterSheet, InspectSheet, TooltipSkin, GroupFinder, DragonRiding) | popups & game menu, tooltip, bars / popups / buttons, third-party addons, global, character sheet, speed bar (85) |
| Group Finder | EllesmereUIGroupFinder (Search, Applications) | group finder, applications, reset counts (4) |
| Damage Meters | EllesmereUIDamageMeters (Window, State, Format, Style, Tooltip, SpellHistory) | display, header, bars, bar text, standalone combat timer, extras (49); Spell History: icon history, bar history. Several windows, each with its own mode. |
| Mythic+ Tools | EllesmereUIMythicTimer (RunSummary, TargetedSpellBars, TargetFocusBars) | display, title & affixes, timer, bar, thresholds, forces, bosses, targeted spell bars, interrupt, cast colours, run summary (73) |
| Quest Tracker | EllesmereUIQuestTracker | display, colours, tracking, extras (22) |
| Friends | EllesmereUIFriends | display (8): region flags, faction, offline |
| Minimap | EllesmereUIMinimap (Layout, Apply, Styles, Flyout, Indicators, Tooltips) | minimap, buttons (flyout bin), Blizzard elements, text (39) |
| Chat | EllesmereUIChat (Engine, Tabs, Skin, Position, Sidebar) | display, idle fade, sidebar, icons, layout, typography, appearance, border, input, extras (46) |
| Bags | EllesmereUIBags (Grid, List, Categories, Sidebar, Bank) | display, grouping, sidebar, layout, categories, grid / compact, list, extras (38); Bank page |
| DataBars | EllesmereUIDataBars + Blocks/ (MicroMenu, Spec, Stats, Travel, Gold, GreatVault and more) | per bar: bar settings, then per-block type settings (50) |
| Quickdraw | EllesmereUIQuickdraw (Secure, Actions, Geometry, Nests) | radial action menu: general, setup, layout, appearance (20) |
| Loadout Manager, Party Mode, Simple Loot Council | options only in this copy | 10 / 12 / - |
| Global pages | EUI__General / Colors / Fonts / Textures / Style / Glows / Profiles | general: display, combat, developer (14); colours: dark mode, class, power, class resource; fonts: global + per module (36); textures: per module (19); glows |

### 1.3 Fonts and media (I:\EllesmereUI\media)
fonts (23 faces), textures (39 bar / background fills), borders (pixels, glow, slim), portraits (masks + borders:
circle, square, csquare, diamond, hexagon, shield, pixels ring / dragon), rounded corners and glows (glow-corner-1..32),
micromenu icons (19), icons (UI glyphs), combat indicators, sounds (16), backgrounds (theme pictures).
Phoenix draws its own equivalents; the shapes are copied as **behaviour** (a mask and a border per shape), drawn new.

## 2. Gaps from WindTools and idTip (features neither Phoenix nor core EllesmereUI has)

| Feature (source) | Phoenix section |
|---|---|
| idTip ID kinds Phoenix lacks: talent, criteria, ability, artifact power, enchant, bonus, gem, macro, set, visual, source, species, icon, area POI, vignette, expansion, object, trait node / entry / definition | Tooltip › Content › IDs (extend `idKinds`; advanced) |
| Event tracker: world event timers on the world map (WindTools Maps/EventTracker) | Maps › World map |
| Super tracker: distance and ETA under the waypoint, right-click the map to set a waypoint (Maps/SuperTracker) | Maps › World map |
| Smart tab: Tab cycles the chat channel to whisper / party / raid / instance (Social/SmartTab) | Chat › Input |
| Chat link icons and item level in links (Social/ChatLink) | Chat › Messages |
| Context menu extras: armory, guild invite, copy name (Social/ContextMenu) | Chat › Extras |
| Tooltip group info, tier set count, raid / M+ progression, objective progress % on mobs (Tooltips/*) | Tooltip › Content |
| Quick keystone: insert your key when the font opens (Combat/QuickKeystone) | Mythic+ › Keystone |
| Reset instance / goodbye announcements (Announcement/*) | Automation › Announce |
| Pause to slash (Misc/PauseToSlash): the pause key opens chat with "/" | Chat › Input (advanced) |
| Keybind alias (short key labels) (Misc/KeybindAlias) | Action bars › Text (advanced) |
| Anti-override (keep your key bindings when a vehicle overrides them) (Misc/AntiOverride) | Action bars › Paging (advanced) |
| Quest auto-collapse in instances, achievement tracker, switch buttons (Quest/*) | Quests › Tracker |
| Hide crafter name, guild news item level, exit phase diving (Misc/*) | Quality › Extras |
| Friendly nameplate outline (UnitFrames/FriendlyNameplateOutline) | Nameplates › Friendly |

Phoenix already has: already-known tint, wide vendor, extra item bar, fast loot, delete fill, rectangle minimap,
instance difficulty, skip cinematics, achievement screenshot, chat bar, raid markers, combat alert, inspect /
item level, absorb, range, mute, turn-in, trade. Those are not listed above.

## 3. MoveAny: the two features (method)

MoveAny's method (moveframes.lua, behaviour only):
- It keeps a list of about 120 Blizzard window names (CharacterFrame, AuctionHouseFrame, AchievementFrame,
  CollectionsJournal, PVEFrame, ProfessionsFrame, WeeklyRewardsFrame, …).
- A window is taken over only once it exists, is visible, and is not protected in combat.
- It makes a mover proxy `<name>Move`. A mouse-down on the window starts moving the proxy; mouse-up saves the point
  per window name.
- It hooks the window's `SetPoint` and `SetScale` with hooksecurefunc and re-applies the saved point and scale
  whenever Blizzard's panel manager moves it.
- Its scale is a **right-drag** that maps the mouse delta (×0.0024, clamped 0.5–2.5) to the scale and shows the
  percentage in a tooltip.

Phoenix plan (extend Phoenix_UI_Skins/Move.lua, which already moves windows with Shift-drag and stores centre offsets):
1. Replace its short list with the full window list (per client, Forever names included). Add a load-on-demand hook
   on ADDON_LOADED for Blizzard_* windows.
2. **Shift + mouse wheel** over a window changes its scale in 5 % steps, 0.5–2.0, saved per window. The wheel is
   EnableMouseWheel on the window plus a check for IsShiftKeyDown. Scrolling lists keep the plain wheel. The window
   is re-scaled from the hooked SetScale. A percentage tip is shown.
3. Ctrl + right-click resets the window's place and scale. Nothing protected is touched in combat; changes wait for
   PLAYER_REGEN_ENABLED.
4. No other MoveAny extras (frame alpha, bar editing): Layout mode owns everything else.
Section: Layout › Windows (simple: on/off; advanced: per-window reset list).

## 4. One-click sim of the equipped gear

Today (Phoenix_UI_Sim + uploader/sim.go): you pick bag items and press Prepare, Phoenix writes a request into
PhoenixUISimDB, you /reload, the Phoenix app runs SimulationCraft and writes Sim\Results.lua, and you /reload again to
read the result.
The easiest correct one-click design:
- One **Sim my character** button on the Sim page, and on the character window: mode `gear` (the equipped set only),
  default fight Patchwerk, 300 s, 1 target.
- The click builds the request (Export.lua already produces the SimC profile) and asks with one confirm popup to
  reload. The reload is a protected-free ReloadUI from a click.
- The app runs it in the background. The result appears on the next reload or login, and there is a "result ready"
  line on the Sim page when Results.lua is newer.
- Fallback with no app: **Copy SimC string** (an edit box, selected) to paste into Raidbots Quick Sim. No network from
  the addon.
- Addons cannot start programs or write files without a reload, so this is the minimum (one click plus one reload).
  Forever: same path, using the Forever profile rules already in Export.lua.

## 5. Premade Groups Filter, improved, in Phoenix's skin (behaviour only, GPL-2)

PGF structure:
- a panel docked beside the group finder;
- one panel per category: Dungeon (per-dungeon checkboxes), Raid, Arena, Rated BG, Delve, Role, plus a mini panel;
- an advanced expression box (about 150 keywords, sort expressions);
- list enhancements: class names in the tooltip, coloured names (new / declined / lockout), class-colour bars, leader
  crown, leader rating with Raider.IO colours, spec icons, missing-role icons;
- sign-up helpers: one-click sign-up, cancel oldest application, persist note, sign up on Enter, skip the sign-up
  dialog (Shift to show it), sign up to declined groups;
- group age, a help dialog, and a PremadeRegions plugin.

Phoenix_UI_GroupFinder already has: difficulty filters, role slots, score / key / PvP / item-level / members / age,
friends, voice, bosses, lust / brez, hide declined, leavers, an expression box (~45 keywords), dim or hide
non-matches, sort, quick and Enter sign-up, entry score, class bars, tooltip, lockout, applicant tools, leader realm.

Missing, to build:
- per-category panels with per-dungeon / raid boss checkboxes, and an Arena / RBG / Delve panel;
- multi-key sort expressions;
- keyword parity (aim ~150, with a keyword help list in the GUI);
- leader crown, spec icons, missing-role icons;
- coloured group names (new / declined / lockout);
- cancel oldest application;
- persist note;
- skip the sign-up dialog with Shift override;
- sign up to declined groups;
- group age column;
- a mini panel when collapsed.

Improvements:
- saved filter presets per category (the `preset` key exists);
- live match count;
- every control is a Phoenix widget in the EllesmereUI look;
- the panel docks to PVEFrame and follows its scale.

## 6. Screenshots (newest) and what they show

- `bugs\shots\screen_20261101_083717*.png` (8:37 UTC+3) is the desktop: chat and a CurseForge page, no game. No
  character-panel capture yet, so item 6 still waits.
- Retail `WoWScrnShot_110126_051157` and `_050947` (5:09–5:11 UTC+3, a build from before today's fixes):
  - Tooltip page: orange ember borders and the PHOENIX watermark art bleed behind the Style card. Fixed by #4/#12
    and the one theme, so confirm after install.
  - The footer says "Saved – reload the UI to apply", which conflicts with the live rule. It must go in the rework.
  - Unit Frames › Arena pets: the live preview is empty, a black box (preview work, §8 step 4).
  - Chat: "New Lua error in Phoenix_UI_Quests". Check the Bugs window after install.
  - The chat frame and data bar still carry the orange theme. Fixed by the theme.
  - The GUI covers half the screen (#21): the EllesmereUI window is 1300 × 946 at its own scale, with a window-scale
    slider in the footer.

## 7. The new settings tree (sections and order)

The sidebar groups follow EllesmereUI's order, with Phoenix modules mapped in. **S** = simple (shown by default),
**A** = advanced (behind the row's cog or the "Advanced" switch per page).

1. **Home**: what's new, quick actions (S).
2. **Core**
   - Action Bars: Display / XP Bar / Menu & Bags / Animations. Phoenix_UI_ActionBars plus CooldownText (moved in
     as Icon effects › cooldown numbers).
   - Nameplates: Display / Colors / General.
   - Unit Frames: Display (per-unit tabs) / Boss / Mini / Aura bars. Phoenix_UI_UnitFrames.
   - Cooldown Manager. Phoenix_UI_Tracker (Viewers, AuraBars).
   - Resource & Cast Bars. Phoenix_UI_CastBars plus the UnitFrames resources.
   - Raid & Party Frames. Phoenix_UI_GroupFrames.
3. **QoL**
   - Quality of Life (Quality, Automation, AFK).
   - Forever Essentials (Forever only).
   - AuraBuff Reminders (Tracker/Reminders).
   - DataBars (DataTexts).
   - Loot Council (Automation/LootCouncil).
   - Sim.
4. **UI Reskin**
   - Blizzard Skins (Skins, Tooltip skin, Character window).
   - Group Finder (§5).
   - Damage Meters (DamageMeter plus SpellHistory as its second page).
   - Mythic+ Tools (MythicPlus plus Encounters timers).
   - Quest Tracker (Quests).
   - Friends.
   - Minimap.
   - Chat.
   - Bags.
5. **Phoenix**: General (UI scale, combat, developer), Colors (accent, class, power, resource), Fonts (global plus per
   module), Textures (per module), Glows, Profiles (plus per-spec and per-place), Layout (Unlock mode plus Windows
   §3), Plugins, Bugs, About.
   - PvP and Encounters (boss mods) stay their own pages in Core until EllesmereUI has an equivalent.
   - Combat text stays under QoL.

In every module the shared settings are simple and the per-frame details are advanced:
- **S:** enable, size, position (Layout), font size, the main colour choice, the visibility preset.
- **A:** offsets, per-text anchors, strata, per-aura filters, thresholds, sync-to-all.

## 8. Dependencies and build order (each step is dedicated work, its own commits, prepush, CI)

1. **Shell & widgets** (Config/Window, UI/Widgets, Renderer): the EllesmereUI window, sidebar groups, header and tab
   bar, footer, DualRow / triple rows, section headers, cog popups, segmented control, sync-to-all, global search.
   Window-scale slider. The "reload to apply" text is removed. *Everything else depends on this.*
2. **Global pages**: Colors, Fonts, Textures, Glows, General (merging the Presets page, Skins › Appearance and the
   Textures page: item 5 part 2), Profiles.
3. **Layout (Unlock mode)**: per-frame alpha while editing, Ctrl + right-click reset, right-click quick menu, anchors
   and snap, one owner per frame versus Blizzard Edit Mode (#9, #23 follow-up), Windows mover (§3, #8).
4. **Unit Frames** (#21): the EllesmereUI layout 181 / 46 / 6, per-unit tabs, live preview that is the real frame,
   a clear lock (Layout).
5. **Raid & Party**, then **Nameplates**, then **Action Bars** (+ micro menu / bags bar), then **Resource & Cast Bars**,
   then **Cooldown Manager**.
6. **Damage Meters**: several windows, each with a mode (#11).
7. **DataBars** (#18): one bar model of bar plus blocks; the background spans the bar.
8. **Chat** (#20), **Minimap**, **Bags**, **Quest Tracker**, **Friends**, **Mythic+ Tools**, **Blizzard Skins**
   (+ character panel #6).
9. **Group Finder** (§5), **Sim one-click** (§4), **Tooltip IDs and gaps** (§2), then the remaining WindTools gaps,
   module by module.
10. **About** (#17) and **live previews** (#13): each preview shows the real result, and pages that don't need one
    lose it.
11. Phoenix portrait border: only after the user approves the code.

Connections:
- Colors and Fonts feed every module; Layout owns every position.
- Profiles hold everything (with per-spec and per-place).
- Unit Frames and Raid share the aura containers and the bar textures.
- The Cooldown Manager and Resource Bars share the class-resource data.
- DataBars blocks reuse Minimap / Bags / Great Vault data.

## 9. Phoenix modules: kept, merged or replaced

Kept (restyled):
- ActionBars, UnitFrames, GroupFrames, NamePlates, CastBars, Tracker, DamageMeter, DataTexts, Chat, Minimap, Bags,
  Quests, GroupFinder, MythicPlus, Encounters, PvP, Tooltip, Skins, Sim, Bugs, Movers, General, Automation, Quality,
  CombatText, AFK, ItemLevel, Auras.

Merged:
- CooldownText into ActionBars › Icon effects;
- SpellHistory into Damage Meters page 2;
- Presets page, Skins › Appearance and the Textures page into Phoenix › Colors / Fonts / Textures;
- the art kit (UI/Art*.lua) stays off and is retired after one release.

Replaced: none wholesale. Each module is rebuilt in place, so there are no duplicates and no second module beside an
old one.

## 10. Saved-settings migration

- One ordered step per package in Core/Migrations.lua, from step 9 on. Step 8 (one theme) is done.
- Each step moves old keys to the new ones (Mg.MOVES / MODULE_MOVES / CONVERTS), drops keys that no longer exist, and
  tolerates any shape. It also runs on imported profiles through `UpgradeProfile`.
- Every step gets a round-trip harness check: an old profile goes in, and the expected new keys come out with nothing
  lost (as in #23: 1 231 settings).
- Positions move once, from Movers to the Layout registry.
- Forever profiles go through the same steps. Forever-only keys stay under their modules.

## 11. Libraries (per LIBRARIES.md)

- Keep LibStub, CallbackHandler and LibSharedMedia (register all Phoenix media; pickers show shared media like
  EllesmereUI's `AppendSharedMediaTextures`).
- Add LibDataBroker for DataBars blocks (show other addons' feeds).
- LibDeflate / LibSerialize only if export strings must be shared.
- No AceDB (Phoenix's DB and profiles stay), no LibOpenRaid / LibKeystone / LibSpecialization (unknown licence
  locally; Phoenix has its own data).
- LibRangeCheck from WindTools (MIT upstream, check its notice) is a candidate for the range block.

## 12. Forever compatibility

- Every package keeps its `_Forever.toc` path and the client gate (ns.isForever).
- The accent default on Forever is #DCA77F, as in EllesmereUI.
- Forever Essentials only loads there (spell ranks, classic windows, threat meter, flight timer, junk).
- APIs missing on Forever (Edit Mode, cooldown viewer, Adventure Guide) fall back to Phoenix's own frames, as they do
  today.
- The harness runs both TOCs.
