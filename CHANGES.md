# Phoenix UI changelog

## 2.0.0-beta1

### New
- **Cooldown Manager** (plan v2 stage S12; was *Auras & Cooldowns*, settings kept): Blizzard's Cooldown Manager in
  Phoenix style **and layout**. Per viewer (*Essential*, *Utility*, *Buff icons*, *Buff bars*): icon size, icons per
  row, rows, a size step for later rows, spacing, growth and wrap, centred short rows, *Keep places*, extra icons
  hidden, moved in front of Utility or added as rows; bars with width, height, wrap, icon left/right/off and reverse
  fill; placed by Edit Mode or by a Phoenix mover with scale (Layout mode). Proc glows (Blizzard's, pixel, autocast,
  button, with colour) and a ready glow when a real cooldown ends; grey-out on cooldown, no GCD swipe, swipe
  darkness, out-of-range tint, **keybinds** from your action bars. Countdown numbers stay Cooldown Text's (one owner)
  unless a viewer takes them with its own font. Visibility: always, in combat, with a target, either or never, hide
  mounted or in vehicles, per specialization, plus the out-of-combat fade and a link to per-spec profiles. **Three
  custom bars** for spells the Cooldown Manager cannot show, items and on-use trinkets (IDs or names), secret-safe in
  combat: cooldown and charge rings, charge counts, grey-out, *show always / on cooldown / when ready*, ready and
  proc glows, tooltips. **Reminders** out of combat: flask, food, augment rune, your raid buff (retail), weapon oil,
  pet, healthstone and low mana on ready checks, with a sound. **Test** shows samples where everything sits; the page
  has a live pinned preview. Buffs & Debuffs stays the separate page for every aura on you. 91 settings on retail,
  87 on WoW Forever (target 59).
- **Group frames** (plan v2 stage S11): Phoenix now draws its own party, raid, main tank/assist and pet frames from
  secure group headers (Group Frames → *Group frames*: *Phoenix frames*, the default; *Blizzard frames, restyled*
  keeps the game's compact frames with the 1.x style). Three layouts that switch by group size: *Party (5)*,
  *Raid (10-20)* and *Large raid (25-40)* (chips with Shift multi-edit and *Apply to: All*), each with its own size,
  scale, unit growth and spacing, group growth and spacing, units per column, sorting (group, role, class, name or
  join order, ascending or descending, four role orders), show yourself, show when solo, groups shown and *Groups
  1-4 in Mythic* (retail). Separate frames for main tanks (and main assists) and, opt-in, pets, each on its own
  mover. Every frame is a Unit Frames button (no second copy): health with absorbs and incoming heals, class or
  custom colours, range fade, dead/offline/ghost states, power bar **by role** (tanks, healers, damage dealers),
  name/health/status tags from the Unit Frames tag engine, role icon (optionally hidden in combat), leader,
  raid marker, ready check, incoming summons and resurrections, aggro border and a new **phase icon**. **Dispel
  highlight** as border, overlay or gradient in the debuff type's colour (optionally only what you can dispel).
  Auras asked of the game with filter words only: buffs in the corners or a row (my heals over time, buffs I can
  cast, or all), debuffs in a row or the centre (all, dispellable by me, by the group, crowd control), a **big
  defensive** icon and **private auras** drawn by the game in slots on each frame. Click-cast addons (Clique and
  others) get every button through `ClickCastFrames`. **Test group** shows a fake party of 5 or raid of 20 or 40
  where the frames sit (combat ends it); the page has a live pinned preview; Layout mode moves the party, raid,
  main tank and pet frames. Blizzard's party and raid frames are parked out of combat (the raid manager only when
  *Hide the raid manager* is on). 191 settings on retail, 190 on WoW Forever (target 68).
- **Nameplates** (plan v2 stage S10): Phoenix now draws its own nameplates (Nameplates → *Plates drawn by*:
  *Phoenix*, the default; *Blizzard (restyled)* keeps the game's plates with the 2.0 restyle). Separate *Enemy* and
  *Friendly* styles (chips with Shift multi-edit and *Apply to: All*): size, names only (friendly), bar texture,
  reverse and smooth fill, shading, colour by reaction, class, health left or a fixed colour, class colours for
  players, absorb shields, border and background. Colours: reaction colours (hostile, neutral, friendly, tapped),
  threat colours by role (automatic from your spec, tank or damage/healer, with an off-tank colour when another
  tank holds the mob), quest mobs in their own colour with a quest badge, and an **execute range** colour with a
  threshold mark. Target: glow, border or arrows (or arrows on top), target and focus colours, a focus stripe, a
  mouseover highlight, your class resource under the target plate, and the game's target scale, non-target alpha
  and occluded alpha. Cast bars on plates come from the S9 cast bar engine (no second copy): fill and state colours,
  interrupt-ready tick, **important-cast colour** (also new on every Cast Bars bar), shield, icon, time format,
  name length, hold and flash. Texts use Unit Frames tags (name, health, level with classification, an info line
  such as the new `[guild]` tag) with their own fonts, plus Mythic+ enemy forces. Auras: debuff rows (yours,
  important or all, crowd control first) and enemy buff rows (purgeable, important or all) asked of the game with
  filter words only. Indicators: raid marker (left, top or right), quest, elite and rare badges. **Per zone**: open
  world, dungeons and raids, battlegrounds and arenas each get a scale, friendly players as plates, names or hidden,
  hide enemies out of combat and enemy minions. The *Game* tab gathers stacking for enemy and friendly plates,
  overlap spacing, max distance and every nameplate visibility CVar; the click area (enemy and friendly width and
  height, click-through friendly plates) is set out of combat. **Test plates** shows three samples mid-screen; the
  page has a live pinned preview (target, low health, marker, quest, absorbs). Built for 12.1.5's nameplate rules:
  forbidden plates are never touched, target/focus/mouseover are found by comparing plate frames, secret health,
  threat, reaction and aura data only reach the game's drawing functions. 272 settings on retail, 266 on WoW
  Forever (target 100).
- **Cast bars** (plan v2 stage S9): Phoenix now draws its own cast bars for the player, target, focus, pet, boss
  1–5 and arena 1–5 (Cast Bars → *Bars drawn by*: *Phoenix*, the default; *Blizzard (skinned)* keeps the game's
  bars with the 1.x skin). The player bar replaces Edit Mode's. Each bar sits on its Phoenix unit frame's cast bar
  anchor (Unit Frames → *Cast bar*) or on its own mover in Layout mode. Per bar (chips with Shift multi-edit and
  *Apply to: All*): show, size, placement, texture, border, background, reverse and smooth fill, class colour for
  your own casts; fill colours for interruptible casts, channels and casts that cannot be interrupted, plus
  kick-not-ready, interrupted and finished colours; spark; spell icon left, right, outside the bar or off, with a
  shield on locked casts; spell name (length limit), time (left, elapsed, left/total, elapsed/total or none) and
  spell target texts with their own fonts; hold time and an interrupted/finished flash. Player extras: latency
  zone, channel ticks (built-in counts plus your own `spellID:ticks` list), empower stages, a global cooldown bar
  (retail) and a **swing timer** with off-hand bar (WoW Forever). Enemy bars: an interrupt-ready tick where your
  interrupt comes off cooldown, a glow on casts the game marks as important and a red edge on casts aimed at you.
  **Test casts** loops a sample on every bar; the page has a live preview (casting, channel, empower, locked,
  interrupted). Built for 12.x secret values: timing comes from `UnitCastingDuration` duration objects
  (`SetTimerDuration`), colours from `SetVertexColorFromBoolean`/`EvaluateColorFromBoolean`, the time text from
  duration text bindings, never a compare in addon code. 100 settings on retail, 110 on WoW Forever (target 55).
- **Buffs & debuffs** (plan v2 stage S9): Phoenix shows your buffs, debuffs and weapon enchants on its own aura
  containers (Buffs & Debuffs → *Auras drawn by*: *Phoenix*, the default; *Blizzard (skinned)* keeps BuffFrame and
  DebuffFrame with the 1.x skin). Per block (Buffs / Debuffs): show, icon size, square or wide icons, icons per
  row, rows, spacing, grow direction and where new rows go, sort by time left / name / order applied, ascending or
  descending, your own auras first or mixed in; borders by debuff type (also on buffs if you like), cooldown
  swipe (reversible), grey debuff art; timer format (short, clock, seconds), tenths under a threshold and colours
  by time left (a game colour curve, secret auras too), stack and timer fonts; right-click cancels buffs (in combat
  too); tooltips always or out of combat. Weapon enchants with the buffs, as their own block or hidden. Private
  aura anchors (boss mechanics the game draws itself) with count, swipe and countdown numbers. Every block moves in
  Layout mode; **Test auras** fills them with samples; the page has a live preview. **Test frames** in the top bar
  now also starts test casts and test auras.
- **Unit frames** (plan v2 stage S8): Phoenix now draws its own player, target, target of target, focus, focus
  target, pet and boss 1–5 frames, plus optional arena 1–5 frames (Unit Frames → *Unit frames*: *Phoenix frames*,
  the default; *Blizzard frames, reskinned* keeps the game's frames with the 1.x skin after a reload). Per frame
  (chips with Shift multi-edit and *Apply to: All*): show, size, scale, strata, position, stacking for boss/arena,
  bar texture, any border style, background, mouseover highlight, a target mark on boss/arena frames, unit
  tooltips always / out of combat / never, range fade and fade out of combat. Health: class, reaction, by health
  left (three-step colour curve), fixed or theme colour, dark mode, shading, smooth bars, fill from the right,
  vertical bars, background style; absorb shields (striped or solid, after health or from the right edge), heal
  absorbs and incoming heals; state colours (tapped, dead, offline). Power: always / mana users only / off, inside
  or below the frame, height, gap, texture, colour, smooth, and the encounter (alternate) power bar. Class
  resource on the player: combo points (charged ones coloured), holy power, soul shards, chi, arcane charges,
  essence, runes (sorted by time left) and a Brewmaster stagger bar, attached or on its own mover, pip border,
  spacing, empty opacity, hide when idle. **Text tags**: four texts per frame (name, health, power, extra) written
  with tags such as `[name]`, `[health:current-percent]`, `[power:percent]`, `[status]` (20 tags, up to 8 per
  text), each with its own font, size, outline, colour and position; name length and colour, hide health text at
  full, number style (12.3K, 12,345 or 万/億) and decimals. Portraits: 2D, live 3D model, class icon or none, left,
  right or behind the health bar, square or circle, opacity and border. Icons: raid marker (size and place),
  leader, role, PvP, combat, resting, elite/rare star, threat glow and ready check. Auras: buffs and debuffs above
  or below (all / mine / raid), size, per row, most, spacing, grow direction, dispel-type colours, grey for other
  players' debuffs on enemies, icon zoom and border, time-left sweep and text, stack count, tooltips. Arena: PvP
  trinket and specialization. A cast bar anchor per frame (below / above / not attached) where Blizzard's own
  target, focus and boss cast bars sit until Phoenix cast bars arrive (S9). Every frame moves in **Layout** mode;
  **Test frames** shows all of them with sample data; the page has a live pinned preview with low-health,
  out-of-range and combat states. Frames are secure unit buttons (left click targets, right click opens the unit
  menu, Clique and Blizzard click bindings work) and are built for 12.x secret values: health colour and
  percentages come from `UnitHealthPercent` curves and every number goes straight into the game's text and bar
  functions, never compared or added in addon code. 200 settings (target 150).
- **Action bars** (plan v2 stage S7): Phoenix now owns its action bars (Action Bars → *Bars owned by*: *Phoenix*, the
  default; *Blizzard (Edit Mode)* hands them back to Edit Mode after a reload). Bars 1–8, pet, stance and a new **item bar**
  (usable quest items in your bags plus any item IDs you list). Per bar: buttons, lines, width/height or square,
  spacing, grow and wrap direction, order, show empty buttons, click-through, anchor, scale, strata, backdrop and
  border; show in combat / out of combat, fade out of combat, mouseover only (with linked bars), reveal while
  dragging a spell or with the spellbook open, hide in vehicles, or your own visibility macro. Bar 1 pages for forms
  and stances, skyriding, vehicles/possession and Shift/Ctrl/Alt pages, with optional page arrows that work in
  combat. Buttons: square, rounded, circle or hexagon shapes (icon, swipe, highlight and border all follow), icon
  zoom, any border style, out-of-range / not-enough-power / unusable tints on the icon, hotkey or both, pressed /
  mouseover / active looks, proc glow and assisted highlight as Blizzard, pixel lines, sparks or soft glow, grey
  icons on cooldown, swipe opacity, ready flash, global-cooldown swipe, equipped and quality borders, tooltips off
  in combat or always, Blizzard's lock setting. Text: hotkey (with short names like S-1, M4, N5), macro and count
  fonts and positions, cooldown number size and charge numbers. Extra: extra/zone ability style, scale and art,
  a movable vehicle exit button, game-menu and bag buttons always / on mouseover / hidden. Every bar moves in
  **Layout** mode. Secure and taint safe: Phoenix never calls a Blizzard button's methods; layouts run as
  restricted snippets out of combat. 116 settings (target 114).
- **Cooldown Text**: font, size, outline, shadow and colour; scale with the icon; tenths below N seconds; shortest
  cooldown with numbers; hide on buff/debuff icons; optional colour by time left (almost ready / seconds / minutes)
  on action buttons. 15 settings (target 12).
- **WoW Forever** (interface 16001, launches 4 Nov 2026): Phoenix loads on Blizzard's new level 1–60 game through
  its own `Phoenix_UI_Forever.toc` files, same code, same settings format. What Forever does not have is not shown
  rather than left broken: no Mythic+ or Sim pages, no Great Vault card, no Mythic+ rating, enemy forces or Sim
  switches, and the Encounters page keeps pull and break timers, their bars and the countdown voice (Forever has no
  boss timeline or warnings; Run test shows a pull bar). Per-spec profiles appear only where a class can choose a
  specialization. A retail profile imports as is; settings for retail-only modules are kept for when you go back.
  Phoenix → Diagnostics names the game. Checked against Forever 1.60.1's own API, UI source and game data
  (`tools/check_flavors.py`).
- **Game ID audit**: every hard-coded icon path, atlas, spell ID, sound and enum fallback was checked against
  build 12.1.5.70448 (wago.tools DB2 + Blizzard UI source). One was wrong: the Bugs page game-icon fallback
  (`INV_Misc_Bug_01` does not exist) now uses `INV_Misc_Bugsprayer`. `tools/check_ids.py` keeps it that way.
- **Settings window v2** (plan v2 stage S6): a 1280×800 window (resizable 900×560 to 1800×1200) with an icon rail
  of seven groups (Home, Frames, Bars, Combat, Interface, Content, Phoenix), the open group's pages beside it with
  sub-headings and a depth meter (settings now against the plan target), the page, a **preview dock** on the right
  (from 1100 px wide; narrower windows keep the preview in the page) and a footer with auto-save, status, the
  pixel-perfect UI scale, window scale and Reload. The top bar has search ("Search 607 settings…"), a profile
  switch, **Layout** (unlock frames) and **Test frames**. Every module and option kept its saved place; only the
  menu moved, and every option is still reachable (smoke-tested).
- **Widget kit**: compact rows pair two to a line on wide cards; a card's first switch can sit in its header and
  turn the whole card off (Cast bar, Auras, Threat, countdown voice, Tooltip and Cast Bars skins…); element chips
  (Player, Target, Bar 1 …) with Shift-click to edit several, **All** to edit every element, **Apply all settings
  from**, and a ⇄ button on each row that sends that one setting to every element; right-click any row to reset it.
- **Style library** (Appearance → Borders & shadows): border styles Follow Appearance, None, Pixel, Solid, Thick,
  Inset, Shadow, Glow and **Ember**; shadows Soft, Hard and Glow; backdrops Solid, Gradient and Glass, all picked
  from visual cards. Set the border style, size, colour, shadow depth and glow colour once and every border set to
  Follow Appearance follows. Colours can follow your **Class** or the **Theme**.
- **Search** understands players' words: `hp`, `cd`, `colour`/`color`, `bg`, `np`, `m+`, `ilvl` …, and finds pages
  by their rail group or sub-heading.
- **Profiles**: which profile each of your characters loads; export the whole profile or only the modules you pick;
  an import shows what it changes ("4 modules, 23 settings change", per module) and can be **merged** into the
  active profile instead of making a new one; a link to Presets.
- **Home**: module tiles filtered by group (or Off), each with its on/off switch and depth meter; the side panel
  (health checks, quick actions, what's new) sits in the dock.
- 7 new icons (109 in the atlas), all 10 languages translated.
- **Previews**: every visual module has one; it stays pinned while you scroll, folds away, and Unit Frames,
  Nameplates and Cast Bars can show low health, out of range, targeted or interrupted. Hovering a font, texture or
  dropdown choice previews it before you pick.
- **Card pickers** for fonts, textures and sounds, with search and style filters; 100 fonts (SIL OFL), new bar
  textures, alert sounds and a countdown voice (CC0) — credits in `Media/*/*.md`.
- **Appearance & Media** pages: every font and texture setting of every module on one page, with Apply to all.
- **Auras & Cooldowns** (Combat): the Phoenix take on WeakAuras within Midnight's rules. Blizzard's Cooldown
  Manager viewers get square cropped icons (or keep the round ones), borders, Phoenix fonts for timers, stacks and
  bar names, your bar texture and colour, and an optional fade out of combat.
- **Encounters** (Combat): Phoenix's boss-mod layer for Midnight, built on the game's own encounter timeline and
  boss warnings. Boss abilities as Phoenix bars (sorted, emphasised in their last seconds, paused or blocked casts
  faded, the game's "hide long/queued" settings followed) and boss alerts in a Phoenix banner with a sound per
  severity, both movable in Edit Mode. Every Blizzard setting for them on one page (master switch, minimum level,
  cast counts, role and effect icons by type). **Run test** plays the game's sample encounter on the real bars.
  Pull timer (button or `/pui encounters pull 10`, the game's group countdown) and break timer
  (`/pui encounters break 5`) that DBM and BigWigs users see and send; the countdown voice moved here from Auras &
  Cooldowns (your settings come along). With BigWigs or DBM loaded Phoenix draws nothing twice, and BigWigs and
  LittleWigs get a **Phoenix bar style** through BigWigs' public style API. Spell names, icons and texts stay
  secret: they are only displayed, never read.
- **Sim** (Tooltips & Items): SimulationCraft for your character without leaving the game, run by the Phoenix app
  on your PC (1.2.0). A paperdoll and a list of the gear in your bags you could wear (click a slot to filter, tick
  what to try), four modes (gear, compare items, best set of the ticked items, stat weights) and the fight
  (style, targets, length). **Prepare sim**, then **Reload to send**; the app runs it in seconds (about 2.5 s for
  six items on a single-target fight) and the answer appears after your next reload: DPS per set with the
  difference to what you wear, the sim time, stat weights, and the last 10 sims (click to show, right-click to
  delete). Item tooltips get a "Sim: +1.2% (+2,640)" line and the bag upgrade arrows follow the sim instead of
  the item level (both can be switched off). **Test** fills the page with a sample. The exporter follows the
  SimulationCraft addon's item format (Unlicense, credited); spec and profession names come from the game data.
- **Module picker**: after the welcome looks, new installs choose which modules to run (Apply, or Apply and reload
  when one needs it); reopen it from Phoenix → Presets.
- **Unit Frames**: Boss 1–5 frames, class-icon or hidden portraits, leader/raid-marker/PvP icon switches, a range
  fade for group members you target or focus, cropped aura icons, and **test frames** shown where the real frames
  sit (they close in combat).
- **Nameplates**: target and focus colours, role-aware threat colours (tank or damage/healer), a styled plate cast
  bar, and cropped, bordered debuff/buff icons with Phoenix fonts.
- **Presets** (Tools): three complete looks — Ember, Clean, Vivid — in one click with Undo; new installs are offered
  them once in a welcome window.
- **Phoenix → Diagnostics**: the media check, icon source (falls back to Blizzard icons if the Phoenix sheet fails)
  and a copyable report.
- `/pui diag`: checks that every Phoenix texture and icon atlas loads in your client and records what the
  settings window's icons look like to the game; the result is kept in the SavedVariables for support. It also
  runs quietly once per version after login and only speaks up if something failed.
- **Mythic+ timer**: ahead/behind against your best timed run of the dungeon and level for every boss and the forces,
  the time to beat beside bosses still alive, and the current pull added to the forces line when the game lets
  addons read it (otherwise it stays silent).
- **Party keystones** on the Mythic+ page: your group's keys, dungeons and ratings over the LibKeystone protocol, so
  BigWigs and DBM users show up too. Sent only outside instances, never during chat lockdown.
- **This week** on Home: Great Vault progress for dungeons, raid and world, Mythic+ rating, runs and best key.
- **Chat**: unread tabs glow in the accent colour; whisper tabs use the whisper colour.
- **Bags** (Tooltips & Items): Phoenix bag windows (separate and combined), cropped icons with quality-coloured
  borders, a stack-count size, and a green arrow on gear you can use that beats what you wear in that slot.
- **Data bar**: drag the segments into any order; new free bag slots, item level, friends online, guild online and
  mail segments (off by default) with tooltips and click-to-open out of combat.
- **Minimap button bin**: addon minimap buttons (LibDBIcon) gathered into one Phoenix flyout on the minimap corner.
- **Every settings row explains itself on hover**: description, default value, right-click to reset, and whether it
  needs a reload or waits for combat to end. `/pui help` lists every command.
- **Settings load on demand**: the settings window is a second folder, `Phoenix_UI_Options`, loaded the first time
  you open it (`/pui`, the minimap/compartment entry or the game's AddOns settings), so it costs no memory or load
  time until then. Install both folders.
- **Translations**: deDE, frFR, esES/esMX, ptBR, ruRU, itIT, koKR, zhCN and zhTW, for every string.
- `/phoenix testerror` raises a harmless, clearly labelled error to try the bug catcher and the uploader.
- `docs/TESTING.md`: the in-game checklist for this beta.
- **Send error reports to the author** (Bugs page, on by default, account-wide): whether Phoenix Uploader may send
  this account's reports. `/pui bugs share [on|off]`. A one-time chat line on first login says it is on and how to
  turn it off. Phoenix Uploader 1.1.0 honours it.
- **Privacy**: reports no longer carry your character name or realm, player GUIDs, BattleTags, Windows user or
  account folder names; text-like string locals (chat lines and the like) are reduced to their length.

### Fixed
- Phoenix_UI warns once if the `Phoenix_UI_Options` folder is from a different version (one folder updated, the other
  not); Phoenix → Diagnostics shows the same.
- Less background work: Spell History's fade timer, the data bar and the minimap coordinates stop polling while
  idle or hidden; nameplates ignore health events while the health text is off; bag and roster events are coalesced.
- Every settings card has an icon; the Data Bar and Minimap descriptions name their new features.
- **Tooltip**: no more "attempt to call a nil value" when an item, unit or spell tooltip is not a standard game
  tooltip (seen 43 times in testing); the item quality border reads the tooltip data first.
- Texture pickers draw each texture in a neutral tint so its shading is visible; the chosen one keeps the accent.
- The version no longer reads `@project-version@` in an unpackaged checkout: the source TOC carries `2.0.0-beta1`
  and only packaged builds use the packager token.
- **Bugs caught nothing next to BugGrabber.** BugGrabber 12.x dropped CallbackHandler and announces captures through
  `EventRegistry` (`BugGrabber.BugGrabbed`); Phoenix listened for the old callback, so with BugGrabber installed its
  sack stayed empty. Phoenix now reads every BugGrabber capture (repeats count once each), imports what BugGrabber
  caught before Phoenix loaded, and keeps errors, blocked actions and warnings apart. Without BugGrabber, errors from
  addons that loaded before Phoenix are taken over from Blizzard's error window. The Bugs page and the viewer say
  which way errors are being caught (and warn if another addon replaced the error handler).
- **Bugs viewer**: filter by addon and by any past session, delete a report, mark one as reported; option to catch
  only Phoenix UI's own errors; two more notification sounds; with BugGrabber but no BugSack, BugGrabber's own chat
  line gives way to Phoenix's notice.
- **No icons in game.** The icon atlases were RLE-compressed TGAs, the largest 1024×2048. They are now uncompressed
  32-bit TGAs with no edge over 1024 px (tiers 24/48/64 px; brand art uncompressed too). New file names need a full
  game restart once, not just `/reload`.
- **`/pui diag` crashed** ("Diag.lua:54: attempt to call a nil value"): textures have no `GetEffectiveAlpha`. The
  self-test now guards every probe, always saves its report and never throws, so the automatic game-icon fallback
  can kick in when Phoenix's atlases do not load.
- **Tooltip**: every hook is guarded (a fault is reported once, not on every hover) and target, rating and item
  quality are checked for secret values before use.


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
