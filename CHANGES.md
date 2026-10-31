# Phoenix UI changelog

## 2.0.0-beta2 (in progress, 30–31 Oct 2026)

### New
- **Resource bars review** (31 Oct, review 31, EllesmereUI parity): a spark on each fill, an optional gradient, damage and heal absorbs on the health row, a power threshold colour (the bar lights up from a chosen percent, also in combat), and show rules (always, in combat, with a hostile target, either, in a group, in instances; hide while mounted) that fade the block to a chosen opacity.
- **Reminders review** (31 Oct, review 30, EllesmereUI parity): reminder icons are clickable: a left click casts the missing buff or uses the best flask, food, rune or oil from your bags (oil goes on the main hand), and the icon shows that item and its count; a right click hides a reminder until you change zone; class buffs (rogue poisons, shaman shields, Holy paladin Beacon on the tank); glow and name options; the tooltip says what a click does.
- **Minimap review** (31 Oct, review 29, EllesmereUI / ElvUI parity): an info line (frame rate, latency) whose tooltip lists the Great Vault and saved lockouts (also on the clock's tooltip), difficulty as text (N / H / M / M+12 / LFR with raid size), a Great Vault button, right-click tracking menu and middle-click calendar (work with those buttons hidden), fade in combat or while mounted, zone text and coordinates on mouse-over only.
- **Encounters review** (31 Oct, review 28, BigWigs parity): Move emphasised bars (their own bigger stack with its own place), bar direction (drain or fill), a spark on each bar, the voice counts abilities in (spellID=count, or every emphasised one), banner lines (1-5) and a red screen-edge flash on critical warnings.
- **Layout mode for every Phoenix frame** (31 Oct, review 28): the encounter bars and warnings, Mythic+ timer, spell history, XP bar and data text panels were only in Blizzard's Edit Mode; they now also have a Layout mode box with the same saved place (plus scale and opacity), and the encounter frames show samples while you move them.
- **Quiet mode for instances** (31 Oct, BigWigs BossBlock idea): Quality of Life > Hide boss emotes (boss emotes and whispers stay in chat; raid warnings stay), and Where to hide (everywhere, dungeons and raids, raids only) for talking heads, zone text, the boss banner and boss emotes.
- **Gold ledger** (31 Oct, EllesmereUI idea): the gold tooltip shows what this character earned and spent this session and its net change today (green / red); Data Texts > Gold can forget a deleted or transferred character.
- **Combat text: per-event always sticky, message and icon** (31 Oct, MSBT parity): each event's cog now has Always sticky, Show the icon, Font (one of the six combat faces) and Message (%a = the number, for example (%a) or +%a; %s = the word on lines without one); the MSBT import also takes always sticky and %a messages.
- **Layout mode: hide a frame, a scale per window** (31 Oct, MoveAny level): the cog popup on a Layout mode box has Hide this frame (faded out, kept hidden when the game sets its opacity, shown with a (hidden) label while unlocked so you can bring it back); Movers > Blizzard windows gives each window its own scale on top of the shared one.
- **Announcements** (31 Oct, WindTools idea): Automation > Announcements tells your group your new keystone after a run, that an instance reset worked, and your own thank-you after a key; each off by default.
- **Rare alert: killed and seen today** (31 Oct, 2711acd): the toast says when you already killed or saw that rare today on this character; the list clears at the daily reset.
- **Layout mode: any frame** (31 Oct, 0ecfd2a): Movers > Any frame adds any named frame by clicking it on screen or typing its name; it then moves, scales and fades like the built-in entries, per profile.
- **Combat text: import from MikScrollingBattleText** (31 Oct, 6b6732b): one button on the Triggers tab copies MSBT's area styles, directions, alignment and height, event colours, areas and on/off, and its ability substitutions; MSBT is only read.
- **Combat text: your own triggers** (31 Oct, 1b81f2b): on the Triggers tab, show your message (%s = the name) with a colour, area and sound when you gain or lose a named aura or a reactive spell lights up; all in the GUI.
- **Combat text: money and experience notifications** (31 Oct, 343cb59): money gained (off by default, as Loot feed already shows it) and experience gained in the notification area, each with its own colour, size, area and sound.
- **Macro editor** (31 Oct, e9df41f): Automation > Macro editor: account and character macros, name, icon picker, body with a live character count, a conditionals helper that inserts at the cursor, New / Save / Delete / Pick up; never in combat, no /macro needed.
- **Combat text: substitutions** (31 Oct, 60a33fe): rename or shorten spell, aura and miss words before they are drawn ("from = to; ..."), MSBT style; amounts are never touched.
- **Combat text: combat font pick** (31 Oct, 6502bc8): Phoenix Font Bold (default), Bebas Neue, Oswald, Russo One, Black Ops One or Grenze Black, applied live.
- **Combat text: no double text** (31 Oct, 6a71fb6): while the scroll is on, the game's own text over your character is hidden (it still feeds the scroll) and returns when the scroll or the switch is off.
- **Combat text: an icon on every line** (31 Oct, cfb8ed8): lines without a spell icon (incoming hits, misses, honor, reputation, power) get a Phoenix glyph in the line colour on the area's left or right icon side; switch under Combat text.
- **Combat text: MSBT styles on built-in animations** (31 Oct, 3aac2fb): horizontal and pow join straight, parabola, angled and static; every line now moves with the game's own animations (no per-frame Lua), merged hits restart their flight.
- **Combat text: your own scroll areas** (31 Oct, e3473f7): add, name, rename and remove areas and route any event to them; every area, on or off, is always shown and draggable (with snapping) in Layout mode.
- **Gamepad** (31 Oct, f802454, d0d2ab2): Automation > Gamepad: controller support switch and camera turn and tilt speed, no console needed.
- **Party mode** (31 Oct, 935031c, 4130082): edge lights with a start/stop button; celebrations on boss kills, finished keys and level ups; sound, length and strength; a session you start is never ended by a trigger.
- **Loadouts** (31 Oct, 363cc17): per spec, a talent loadout and equipment set for raid, dungeon, arena, battleground and open world; offered (or applied) when you enter, plus an apply-now button.
- **Loot council** (31 Oct, 4082ba5): this session's boss drops and who got them; Want tells the group with your equipped item level in that slot; auto-open and raids-only switches.
- **What's new and full changelog** (31 Oct, 126e7cb): About > Full changelog lists every version; the popup has a Full changelog button and can be switched off.
- **Upgrade calculator** (31 Oct, 78d720c): crests per track and in total, average item level gain, cost and item-level-per-step sliders, refreshes when gear changes.
- **Macros from the GUI** (31 Oct, 09d76c9): Pick up buttons for each PUI macro and a Macro window button.
- **Everything in the GUI** (31 Oct, 7889c9f, 323fdf5): every former slash feature has a control (About > Tools: Layout mode, setup wizard, What's new, game AddOns settings, diagnostics, reset window, debug; Bugs test error; arena surrender; waypoint box); the settings window opens from the Esc menu, the minimap icon and the AddOns list on both clients; no text tells you to type a command.
- **Quickdraw** (30 Oct, f9b36d3): quick ring hold-and-release mode, open at the cursor, v9 ring art.
- **Data texts v9.1 art** (30 Oct, 214e405): ember strip, feather caps (kept on screen), dividers, Time / Gold / Bugs icons; Time (12/24 h, local/server), Gold and Bugs sections at the top of the page; the bug count updates live.
- **Movement alert** (30 Oct, 487f657): your class movement spell's cooldown as a movable icon.
- **Auto combat logging** (30 Oct, d45461f): turns combat logging on in Mythic+, raids and dungeons (your pick) and off when you leave; never stops a log you started.
- **Minimap button bin as a bar** (30 Oct, d3310d8): flyout or a bar under the minimap.
- **Mythic+ timer art** (30 Oct, 282a04a): v9 bar, chest marks, skull, affix and forces art; clock position.
- **Aura reminders and aura bars** (30 Oct, a888acd): custom reminders by class or role, group buffs, banner style; aura bars for the auras you pick.
- **Cooldown Manager** (30 Oct, 200014e): spell picker, bar display for custom bars, cooldown icon art.
- **Phoenix art kits v7.1, v8.1 and v9.1** (30 Oct, e072648, 83231bc, 0ce5b9d): background, logo, meter art, phoenix-wings default look (portrait rings, action/stance/cast borders, resource gems, nameplates, party/raid), v9.1 portraits, compact boss ring, gold-coin greed roll; Grenze Black and Metamorphous fonts (OFL).
- **Ember Bevel chrome** (30 Oct, f18a001, 33f5b93, b68f9af): 76 icons and 28 window medallions in four states and themes (ember, frost, fel, arcane).
- **Group frame aura indicators** (30 Oct, 8f33ac8): six placeable indicators per profile.
- **Resource bars** (30 Oct, ee3b916): row order, power ticks, colour modes, smooth fill.

### Fixed
- **Self-test on WoW Forever** (31 Oct): the review 28 Layout mode check no longer expects a Mythic+ timer box on Forever (it has no Mythic+, so that box is never made there) and checks that it really is absent.
- **Combat text: crit size with sticky crits** (31 Oct): the Crit size slider was greyed out for the sticky crit style although sticky crits use it; it is now live for sticky and grow.
- **Combat state and Combat alert** (31 Oct): both switches now name the other, so the two "entering / leaving combat" messages are not shown twice by accident.
- **Code review fixes** (30 Oct, 80aef95, 6ae60cf, cfce46c, 728cdee, c7c1413, 887fadd, 180e254, 44b185a, 0b7f321, fd50673, f7582fc, c59e539): secret numbers in "full" format, plugin dependency loading, event registration failures, third-party plugin keys, IsSecret fallback, PvP timers on C_Timer, plugin API 1.2 docs, mover queueing, sample plugin TOC, Forever TOC docs.
- **QA fixes** (30 Oct, 0ce5b9d, e559187, 7be2326): undressed art stays hidden, no new holders on secure frames in combat, waypoints turn on and off live, a Russian profile import crash.
- **Settings and spec icons** (30 Oct, 67332c2, a07b0b2, 248ea30, a43f3da): even ring strokes, whole-pixel columns, preview scrolls away unless kept, damage meter value fade.

### Docs
- **Coverage and parity** (31 Oct, 55c2ebd): FEATURE_COVERAGE refreshed for every studied addon, combat text review against the real code, duplicate checks before building.

## 2.0.0-beta1

### New
- **Spec icon styles** (t163): 15 looks for every spec icon Phoenix draws (damage meter, arena frames, group finder
  applicants): Blizzard, zoomed, bordered, class outline, round, round with ring, hexagon, diamond, shield, octagon,
  squircle, glossy 3D, ember frame, monochrome, class tint. Pick one in General (live gallery) or per meter.
- **Damage meter, round 3** (t163): item level per player (after the name or in the tooltip; read from the game's inspect
  data out of combat), a standalone big fight timer (movable, combat-only option), name and value text offsets, icon
  borders (theme or class colour) and header colours (accent, class, custom or none, with a fill strength).
- **Plugins** (t163): every optional system (25 of them: bars, frames, nameplates, skins, meter, chat, bags ...) is now its own
  load-on-demand addon folder, `Phoenix_UI_<System>`, loaded only while it is on. New Phoenix > Plugins page: state
  (Loaded / Off / Not installed / Needs reload), memory, switches, Enable all and Minimal. A plugin turned on loads
  live (systems that take over Blizzard frames at login ask for a reload); off is live too, and its code leaves memory
  at the next reload. Install every folder in the zip; a missing one simply shows as Not installed.
- **Public plugin API** (t162): global read-only `PhoenixUI` table, versioned (API 1.0) — register plugins with
  settings pages, Layout-mode movers, theme/font access, events and after-combat queueing. Guide and a sample
  plugin in docs/PLUGIN_API.md and docs/samples/Phoenix_UI_Hello.
- **Phoenix damage meter** (both clients, t158): Phoenix's own meter windows, read from Blizzard's damage meter data
  (C_DamageMeter, the same source EllesmereUI uses), replacing Blizzard's window while on. Up to three windows, each
  a Layout-mode mover with its own mode (damage, DPS, healing, HPS, absorbs, interrupts, dispels, deaths, damage
  taken, avoidable, enemy) and segment (current, overall, any recorded fight); a click on a player opens their
  spells. Rank, spec icon, class colour, your row outlined, fight clock, out-of-combat fade, visibility rules; every
  setting live. Combat values stay secret and only reach the bars and text. Damage Meter > Meter
  (docs/DAMAGE_METER.md). The plugin now also switches on and off without a reload.
- **Damage meter, round 2** (t160): per-target lists (shift-click), compare two players (ctrl-click two), death recap
  tooltips, top-spell tooltips, report to chat, a per-fight graph, role filters, pin yourself, role presets, window
  lock, keybinds (show / hide, reset), four number formats, bar colour class / accent / custom with opacity and
  background, class-coloured text, header height, and the settings preview now draws the real meter rows.
- **Map reveal** (WoW Forever): zone maps also show the parts you have not explored yet, tinted in the accent colour
  (switch and opacity on Minimap > World map). The pieces are the client's own map overlays, generated from its
  WorldMapOverlay tables by tools/mapreveal/build.py; explored parts stay Blizzard's.
- **Event tracker** (both clients): a new Data Texts segment, Events, counts the world events running on your
  continent and today's holidays; its tooltip lists each one with its zone and time left (soonest first) and a click
  opens the world map on the next one. All from the game's own event markers and calendar, no shipped schedules.
  Data Texts > Events.
- **Drag the live preview** to size and place a module: grips in the preview's corner resize (width / height, or
  size / scale) and move (X / Y); highlighted parts also take edge drags (right = width, bottom = height, corner =
  both) and body drags. Values go through the same rows as the sliders: live, clamped, snapped, multi-select aware.
  Works on every module page whose settings have a size (20 of 30 previews; the rest have no size settings).
- **Settings navigation**: compact grouped list with section icons and page counts, hairline section headings, and
  a segmented tab strip with an icon per tab.
- **Share strings v2**: export the whole profile or picked modules with a title; the string carries author, client,
  version, date and a checksum, plus a short code (PX-XXXX-XXXX) that names it on vq8s.com/phoenix/profiles. Import shows
  each module with its change count and the first changed settings (old > new), then Merge or Replace the picked modules,
  or import as a new profile. Old !PUI1! strings still import.
- **New Phoenix emblem** (Flame Crest) on the addon list, compartment, minimap, Game Menu, settings, installer and
  AFK screen, with a breathing glow and rising embers (General > Emblem effects; never in combat, no OnUpdate).
- **Installer** (both clients): one window with nine steps (welcome, look, UI scale, accent, action bars, unit
  frames, chat, windows, finish), a step rail, a live preview, Back / Next / Skip. Choices apply at once; a module
  that only switches at load makes Finish reload once. Replaces the three-popup wizard; reopen with /pui install.
- **Junk window** (both clients): at a vendor a Phoenix window lists your grey items with real icons and value;
  Sell all, or click a row to sell it; away from a vendor two clicks on a row destroy it. Automation > Junk.
- **Fishing helper** (both clients): effects volume up, auto loot on and (optionally) music and ambience muted while
  you fish; everything goes back when the cast ends. Automation > Fishing.
- **Simplified stats** (WoW Forever): the Phoenix Character window lists the five attributes, armour, attack power,
  spell power, healing, hit, crits, dodge, parry and block instead of retail's haste / mastery / versatility.
- **Phoenix inspect window** (both clients, on by default): name in class colour, level, specialization, guild and
  average item level, and every gear slot as a card (real icon in its quality frame, item level, enchanted and gem
  marks) around the player's model; shift-click links, ctrl-click previews. The arrow opens Blizzard's window (talents,
  PvP) for that visit. Skins > Phoenix inspect window off: Blizzard's window, restyled; applies live.
- **Zone levels on the world map** (both clients, on by default): on a continent map each zone shows its name and
  level range at its middle, the range coloured by how hard it is for you; the levels come from the game, the labels
  stay a fixed size when you zoom. Minimap > Zone levels on the world map; applies live.
- **Loot feed** (both clients, off by default): a short-lived stack of Phoenix item cards for what you gain:
  looted, received and crafted items (real icon in its quality frame, count, item level and slot, how many you carry),
  money (outside vendors, mail, trade and the auction house) and currencies; the same thing again adds to its card.
  Read from your own loot lines with the client's localized formats (secret lines are skipped). Quality of Life >
  Loot feed: lowest quality, seconds, rows, width, grow up or down; movable in Layout mode.
- **Auto summon pet** (both clients, off by default): when the game takes your companion away (loading screen,
  death, flight, vehicle) Phoenix summons a random favourite or your last pet a moment later. A pet you put away
  yourself stays away until you summon one; never in combat, instances, pet battles, while mounted, stealthed or
  casting. Automation > Companion pet.
- **Flight timer** (both clients): while you ride a flight path a Phoenix bar shows the destination, a progress fill
  in the accent colour and the time left, with a Land button. Phoenix learns each route's time from your own landed
  flights (account-wide); routes not flown yet are estimated from their length and a speed learned from your flights
  (shown with a ~). The flight map's node tooltips show the same time. A reload mid-flight keeps the bar. Quality of
  Life > Travel; movable in Layout mode (it shows a sample there).
- **Phoenix quest window**: Phoenix's own window for all four quest pages: the NPC's quest list (in progress first),
  offers with every reward (items and currencies with their real icons in quality frames, spells, gold, experience,
  honor, title, renown), what you still need, and turn-in with reward cards to pick (the best vendor value carries
  the Quests page's coin; a quest that costs gold asks for a second click). PvP-flagged offers keep Blizzard's window.
  Skins > Phoenix quest window off brings back Blizzard's, live.
- **Phoenix gossip window**: Phoenix's own NPC dialog: portrait (optional), greeting text that scrolls when long, then
  Available quests, Quests in progress (ready ones marked) and Options, each with the game's own icon; Goodbye. Opens
  on Blizzard's spot or its own place. Skins > Phoenix gossip window off brings back Blizzard's dialog, live.
- **Phoenix loot window**: Phoenix's own loot window stands in for Blizzard's (also in combat): each item's real icon
  framed in its quality colour, item level and slot for gear, quest tags, locked slots marked, gold first and best
  quality next (or as dropped), Loot all. It opens where Blizzard's would (your Edit Mode spot or under the mouse) or
  at its own place. Skins > Phoenix loot window off brings back Blizzard's loot window, live.
- **Tabs on General and Skins**: General is split into Appearance (theme, scale, borders), Text, Colours and
  Behaviour (launcher, sound, accessibility); Skins into Blizzard windows, Appearance and Behaviour (moving windows).
- **PvP scoreboard skin**: the battleground / arena scoreboard and match results in the Phoenix look (dense table,
  team-coloured rows, your row in the accent, Phoenix Leave / Requeue); Skins > PvP scoreboard, live.
- **Diminishing returns in stat tooltips**: crit, haste, mastery, versatility, leech, avoidance and speed tooltips on
  the character sheet show what diminishing returns cost and what the next 100 rating adds (Item Level page).
- **Teleport prompt**: joining a premade group for a dungeon whose teleport you know offers it in a small popup with
  a secure spell button (Group Finder page).
- **Process items** (retail): a Process chip on the bags (and a button on the Phoenix bag window) lists what you can
  disenchant, mill, prospect or unlock; one click on an item casts the spell on it (secure buttons of ours).
- **PUI Mount rules**: name a flyer, a ground mount and a swimmer and the smart mount macro picks by place.
- **Quest progress**: sounds when an objective is done and when a quest is ready to turn in; optional party-chat steps.
- Fixed: a saved scale of 0, a negative number or NaN can no longer reach `SetScale` (data texts, movers, bags,
  extra buttons, minimap button bin); a quick ring item entry without an item ID no longer errors.
- **Unit Frames II, arena and resource bars** (plan v2 stage S18).
  - *Arena frames* (retail, off by default): 9 layout presets (Phoenix, mirrored, compact, tall, wide, slim, class
    portrait, gladiator, cropped icons) that set size, power height, portrait, mirroring and icon crop; 2–5 Test
    frames. Diminishing returns come from the game itself: Phoenix takes Blizzard's own DR tray for each foe
    (`SpellDiminishStatusTray`, fed by the secret `UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED`) onto its frame and
    restyles it (size, spacing, zoom, border, countdown text, red immune edge, *only what I can apply*). The PvP
    trinket comes from the game's `CcRemoverFrame` the same way; racials (14 races) show with a cooldown on seen casts.
    Class icon with crowd-control / big-defensive / important auras over it and a coloured glow; healer badge, focus
    mark, targeted-by pips; unseen-foe opacity, an optional range spell; left / right / middle click actions (target,
    focus, menu, a spell or a macro with `@unit`); arena pet frames beside their owner. No sArena code is used
    (sArena Reloaded has no licence file); only its feature list was compared.
  - *Resource bars*: a detached block for the player with health, power, druid mana while shapeshifted, the class
    resource and a spec bar (Ironfur, Ignore Pain, Sweeping Strikes, Soul Fragments, Ebon Might; retail); rows close
    up when unused; texture, border, background, strata, scale, out-of-combat fade, Layout-mode mover. Class power:
    orientation, separators, highlight from N points, fade when idle, count text.
  - *Totem bar*: Phoenix buttons (size, spacing, growth, zoom, border, time text, mover); right-click destroys a
    totem through a secure button. Blizzard's totem frame or none are the other choices.
  - *Frame look*: frame background texture, health share of the frame, power bar width / fill direction / gradient,
    own and others' incoming heals in two colours, class ring and elite / rare art on portraits, a text strip under the
    frame, nicknames, `[threat]`, `[level:color]`, `[spec]` and `[target]` tags; modifier-click quick focus with an
    optional raid marker.
  - *Cast Bars*: a standalone GCD bar (own width and mover); swing timer hand labels and an out-of-melee range cue.
  - *PvP*: arena Shadowsight timer from the match clock (retail), with its own font and mover.
  - Previews: the whole arena stack (2–5) with sample DR, trinket, racial and class-icon auras; the resource block
    and totems for any class you pick; GCD and swing samples; the Shadowsight line.
- **NPC locations and the open gap rows** (plan v2 stage S17).
  - *Quests › NPCs*: where quest givers, vendors, profession NPCs / trainers, flight masters and rares stand, from
    AllTheThings (MIT) facts in Phoenix_UI_Data (712 Midnight, 987 War Within, 2,113 WoW Forever NPC spots). One NPC
    index serves an NPC search (`/pui quests npc <name>`, a search box on the world map), `/way` (`/pway` when TomTom
    owns `/way`), the giver's place in quest tooltips and townsfolk / rare pins (Phoenix glyphs) on the
    map and minimap.
  - *Record NPC positions* (Quests › Automation, opt-in, off by default): NPC ID (`UnitCreatureID`), map and your
    position when you talk to an NPC, and vignette positions; open world, out of combat, never a secret value; no
    names, realms or GUIDs; kept in your SavedVariables only, never uploaded. A clear button empties it.
    `tools/questdata/merge_collected.py` folds a maintainer's own file into `NPCs_Collected.lua`.
  - *Unit Frames*: overheal past the frame end, spell cost prediction on the player power bar, class power pip shape
    (bar, square, round), portrait size, `[npctitle]` and `[guild:title]` tags; a link to Blizzard's click casting.
  - *General*: power colours (16 power types) and dispel colours (magic, curse, disease, poison, bleed) used by unit,
    group and Blizzard frames.
  - *Nameplates*: friendly NPC titles (default friendly info tag `[guild:title]`).
  - *Chat*: timestamp colour, an emote picker on the chat bar.
  - *Tooltip*: vendor price (only when the game shows none), already known / collected (toys, mounts, pets,
    appearances), keystone timer and season best (retail); a link to the Group Finder page.
  - *Data Texts*: currency picker, honor bar, data bar texture, fill direction, smooth fill and gradient.
  - *Cooldown Manager*: buff bar gradient. *Minimap*: windowed world map scale (retail). *Bags*: a bag bar in the
    Phoenix window (hover a bag to dim the others). *Item Level*: character sheet stats panel look. *Skins*:
    alerts and toasts.
  - Not possible with the 12.x API (listed as `api` in the gap matrix): buff bar smooth / stack fill (the Cooldown
    Manager owns the timer and stack counts are secret), remembering the last chat channel and hiding the combat
    log tab (both taint chat), moving the group finder eye (Edit Mode / menu bar). Deferred: world map reveal (S25),
    raid progression in tooltips and the skyriding vigor skin (S24), Mythic+ teleport buttons (S28).
- **Remaining modules** (plan v2 stage S16): every page now reaches its plan v2 target.
  - *Damage Meter*: bar texture, reverse fill, shading, name and value fonts, window background and border (style
    library, with shadow size) for Blizzard's meter; what Edit Mode already owns (bar size, class colours, value
    format, rank/spec icons, auto show, second window) is linked, not duplicated.
  - *Combat Text*: Phoenix scroll areas for your own events (incoming, target, notifications) with font, merge of
    rapid hits (×N), crit grow/flash, position, height and direction, a test button; amounts stay secret-safe; the
    damage-number font.
  - *Spell History*: icon border and zoom, interrupted/failed casts marked.
  - *Item Level*: inspect window, equipment flyout, loot and roll windows, merchants; font, quality colour, place;
    upgrade track, enchant and empty-socket notes; average item level decimals.
  - *Mythic+*: +2/+3 chest timers, affix icons, deaths by player, timer width, bar texture/fill/smoothing/shading,
    colours, a party keystones window beside the dungeon list.
  - *Movers*: snap to other frames, arrow-key nudge (Shift = 10 px), coordinates while dragging, an unlock key, one
    scale for Blizzard windows.
  - *Quality of Life*: hide zone text and boss banners, a raid markers bar (movable), a cursor ring, a combat
    enter/leave alert with sound, known items tinted at merchants, camera distance and turn speed, and a curated
    list of safe game settings (spell queue window, auto dismount, compare items, clear AFK, error speech, glow and
    death effects, screenshot quality).
  - *Automation*: faster auto loot, confirm bind-on-pickup loot when solo, pick a single gossip option (Shift
    pauses), decline pet-battle duels and guild invites, a low-health sound.
  - *AFK screen*: model on/off and spin, guild, a stats line (item level, Mythic+ rating, vault), dimming, timer
    font, off in instances. *PvP*: a styled queue countdown and a queue sound, links to arena frames, objective
    movers and auto release. *Sim*: bank and Great Vault items can join the picker.
  - *General*: UI scale with pixel perfect, window surface opacity, a global outline, theme fonts on Blizzard
    text, default border style/colour/shadow, class colour overrides (used by every page), sound channel and a
    mute list.
- **Settings window consistency pass** (S16): one owner per game setting (the countdown-numbers and Cooldown
  Manager switches now live only on Cooldown Text and Cooldown Manager; Action Bars and Quality of Life link to
  them), every border row gains a *shadow size*, Content gets sub-headings (Questing & groups / Dungeons, raids &
  PvP / Gear), Cooldown Text sits next to Action Bars, refreshed page descriptions and search words on every new
  row. Gap matrix re-audited against the shipped pages, with rows owned elsewhere (`link`) or impossible in 12.x
  (`api`) listed but no longer counted in a target.
- **Group Finder** (plan v2 stage S15, new page under Content, retail): a Phoenix filter panel beside the premade
  group list. Presets (push score, relaxed keys, needs my role, fresh or in-progress raid, friends and guild,
  rated PvP); the game's own filters (difficulty, needs my role, has tank/healer, minimum rating) written to
  Blizzard's advanced filter only when you change one; Phoenix filters for free tank/healer/damage places, leader
  score, the leader's best key in that dungeon (min/max), members, age, required item level, PvP rating range,
  friends or guild, voice chat, raid bosses defeated (fresh / in progress), Bloodlust, battle res, leavers and
  groups that declined you; an advanced *filter expression* in Phoenix's own small language (`tankfree > 0 and
  score >= 2000 and age < 15`, 39 words, live match count, errors explained). Groups that fail are dimmed (or only
  flagged in the tooltip) — never removed from Blizzard's list, which would taint it; matches get an Ember
  outline, and the panel lists the best matches sorted by fit, age, score, best key, item level, members or PvP
  rating (click one to find it). Entries show the leader's score and best key and a class-colour strip; group
  tooltips add score, best key, PvP rating, Bloodlust / battle res, your raid lockout and why a group is dimmed.
  Leaders see each applicant's best key in the listed dungeon, a spec icon and a class tint from a score line.
  Sign-up helpers that always start from your click or key: click a selected group again to sign up, Enter signs
  up, and a key accepts role checks. Nothing signs up or accepts on its own. 57 settings (target 14). Not on
  WoW Forever (its client has no premade group list).
- **Quests** (plan v2 stage S14, new page under Content): the objective tracker restyled — header/title and
  objective fonts (size, outline, shadow, colour), progress-bar texture, titles coloured by difficulty, a level and
  tag prefix ([82+G]), width and maximum height (out of combat), collapse in instances and/or fade in combat, and a
  click on a quest title focuses it. Quest helper: a movable waypoint arrow (three styles, size, distance, ETA)
  to a pin you clicked, your map pin or the focused quest; Phoenix pins on the world map and minimap for the
  game's available quest lines, for every quest you can pick up now from the new data addon (not done,
  prerequisites met, your side, race, class and level; low-level quests hidden if you like) and for turn-in spots
  of finished quests (retail); an expansion filter; NPC tooltips list the quests they offer, pin tooltips show
  giver, level and objective progress. Automation: auto-accept and auto-turn-in (Shift pauses, never pays gold),
  reward choice off / highest vendor value / best Sim upgrade (retail). Quest item buttons stay the Action Bars
  item bar (mirrored here). An opt-in *Contribute quest positions* switch (UI only; nothing is recorded yet).
  38 settings on retail, 36 on WoW Forever (target 27).
- **Phoenix_UI_Data** (S14): a new load-on-demand addon folder with quest givers, prerequisites and turn-ins —
  facts from AllTheThings (MIT) and Blizzard's QuestPOI tables, built by `tools/questdata/build_questdata.py`.
  First slice: Midnight and The War Within (retail), Azeroth (WoW Forever). Install it next to Phoenix_UI.
- **Bags** (plan v2 stage S13b): an optional Phoenix bag window (*Bag window*: Blizzard's or Phoenix; Blizzard's stays
  the default). One combined grid or category sections (new, equipment, consumables, reagents, quest, junk, other)
  you reorder and hide by dragging chips, sorted by bag order, quality, item level or name; columns, slot size,
  spacing, scale, the reagent bag as its own section, empty slots shown or not. Search box, sort button (and the
  game's sort direction), gold and currency footer, free-slot count, a Layout-mode mover. Slots: border from the
  style library, quality colours, junk coin (or dimmed junk), new-item glow, bind-on-equip/warbound label,
  cooldowns, count font and place, upgrade arrows and item levels. Blizzard's bank and warband bank get the same
  slot styling. Opens with the auction house and trade if you like; selling junk and repairs stay in Automation
  (mirrored here). The old *Count size* moves into the count font (migration 6). 53 settings on retail, 52 on WoW
  Forever (target 47).
- **Data Texts** (S13b): a second panel; drag texts between panels and reorder them. New texts: specialization and
  loot specialization (click opens talents), Mythic+ key (retail), coordinates, volume (mouse wheel). Tooltips for
  each text (durability per slot, gold per character plus the warband bank and total, local and realm time,
  friends and guild online, bags, key and rating), hidden in combat if you like. Panel width, text alignment,
  mouseover only; gold with silver/copper, account-wide totals, realm clock, durability warning level. An
  experience/reputation bar with rested overlay, size, text font and when to show the text, movable in Edit Mode.
  67 settings on retail, 66 on WoW Forever (target 47).
- **Skins** (S13b): 24 Blizzard windows and dialogs in the Phoenix look, each on or off: background and border from
  the style library, a title strip (Phoenix, minimal or Blizzard), a Phoenix close glyph and Phoenix tabs.
  Load-on-demand windows are styled when they load. 34 settings on retail, 32 on WoW Forever (target 28).
- **Chat** (plan v2 stage S13a): styled chat windows (background and border from the style library), fade after N
  seconds, lines kept, hide in combat (the window you type in stays), Blizzard's side buttons on/off, a jump-to-bottom
  arrow; tabs fade when idle and can take a selected-tab colour. The game's own timestamp, class-colour and
  whisper-mode settings on the page. Messages: short channel names ([2. Trade] → [2]), item levels and icons on
  links, role icons on group members' names, keyword highlight (your name plus a list) with a sound, a spam filter
  for repeats, all through Blizzard's addon-safe chat filters (restricted messages pass untouched). Edit box above
  the window, styled, its own font, history length. A chat bar (Say, Party, Instance, Raid, Guild, roll, ready
  check, pull countdown) and a raid-marker picker; an extra whisper sound. 58 settings (target 51).
- **Minimap** (S13a): round, square or rectangle (50-90 % band) with a border from the style library, zone text
  (PvP colours or your colour), clock and coordinates in your fonts (coordinates placeable, 0-2 decimals), each
  Blizzard button (calendar, tracking, mail, crafting orders, difficulty, expansion, addon compartment, zoom) on or
  off, mouse wheel zoom and auto zoom-out, the button bin with columns, button size, a keep-on-minimap list and
  show-on-hover, who-pinged names and world map player/cursor coordinates (retail). The old *Square minimap*
  setting moves to *Map shape*. 47 settings on retail, 45 on WoW Forever (target 41).
- **Tooltip** (S13a): anchor at the cursor (right, left, above, with offsets) or a Layout-mode mover, scale;
  hide in combat with a chosen modifier and for units or every tooltip; class-coloured player names and
  reaction-coloured NPC names, guild rank, realm, targeted by (group), item level and specialization from a
  throttled inspect, mount (and whether you own it), PvP line hidden, health percent on the bar, item counts in
  bags, bank and warband bank, and IDs for spells, items, NPCs, auras, currencies, quests, achievements and mounts.
  Everything secret is skipped. 54 settings on retail, 52 on WoW Forever (target 45).
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
- Minimap: the shape (Round / Square / Rectangle) applies live; Round puts the game's mask and compass back, and
  `GetMinimapShape()` now follows the shape (it always said SQUARE, so button addons laid out a round map wrong).
- Preview drag grips show on all 30 previews; where nothing can be sized they are dimmed and say why.
- Theme: nameplate health background, texture swatches, mail attachment counts and Group Finder result rows use
  theme tokens and fonts instead of fixed greys and Blizzard fonts.
- Dev self-test also drags each preview one step and back, walks the installer and round-trips a share string.
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
