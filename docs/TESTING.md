# Phoenix UI 2.0.0-beta1 – in-game test checklist

One play session, top to bottom. Tick each box as you go. Every step says what you should see (**Expect**) and what
to send back if it doesn't (**If not**). When something fails, keep going; most steps don't depend on each other.

**What to send back for any failure:** the step number, a screenshot, and the newest entries in `/pui bugs`. Lua
errors and taint are reported automatically if the uploader is running (section 0.3), so you only need to mention
the step number.

---

## 0. Setup (before you log in)

- [ ] **0.1 Back up WTF.** Copy `World of Warcraft\_retail_\WTF` to somewhere safe (for example `WTF-backup-2026-10-22`).
  **Expect:** a full copy of the folder. **If not:** stop and fix this first. You need it to retest migration.
- [ ] **0.2 Install the build.** Replace `Interface\AddOns\Phoenix_UI` with the beta1 folder and add the
  `Phoenix_UI_Options` folder next to it, then delete any old `Phoenix_UI` copies (for example `Phoenix_UI-main`).
  **Expect:** exactly `Phoenix_UI` and `Phoenix_UI_Options`. In the AddOns list *Phoenix UI Options* shows as
  load-on-demand. **If not:** report the folder names you found.
- [ ] **0.2b Settings load on demand.** Log in, then type `/run print(C_AddOns.IsAddOnLoaded("Phoenix_UI_Options"))`.
  **Expect:** `false`. Type `/pui`: the window opens; the same line now prints `true`. Esc → Options → AddOns →
  Phoenix UI → **Open Phoenix UI** and the minimap compartment entry open it too.
- [ ] **0.3 Start the uploader.** Run `PhoenixUploader.exe` (from https://vq8s.com/phoenix-ui). With no options it
  runs in the tray.
  **Expect:** a tray icon, and `uploader.log` (in `%LOCALAPPDATA%\PhoenixUploader`) shows `watching …\_retail_`.
  **If not:** send `uploader.log`.
- [ ] **0.4 Turn on the taint log.** On the character screen or after login, type `/console taintLog 1`. It stays on
  until you set it to 0.
  **Expect:** no message (that is normal). After the session, `Logs\taint.log` exists.
  **If not:** mention it. We just get less detail on taint.
- [ ] **0.5 Other addons.** For the first pass, test with Phoenix UI **alone** (AddOns list → Disable All, then enable
  Phoenix UI). Run section 12 again later with your usual addons.

## 1. First login and migration

- [ ] **1.1 Log in a character that used Phoenix UI 1.x.**
  **Expect:** one chat line, `Imported N settings from Phoenix UI 1.x.`, with N greater than 0. No Lua error.
  **If not:** send the line you saw (or none) and your backed-up `WTF\Account\<acc>\SavedVariables\Phoenix_UI.lua`.
- [ ] **1.2 Migrated values.** Open `/pui` → Automation and Quality.
  **Expect:** your old choices are kept (repair from guild funds, auto-sell junk, hide talking head and so on).
  **If not:** name the setting, your old value and the new value.
- [ ] **1.3 Second login.** `/reload`.
  **Expect:** the import message does **not** appear again.
- [ ] **1.4 Fresh character.** Log in a character that never used Phoenix.
  **Expect:** defaults and no import message. The Default profile is active.
- [ ] **1.5 Version.** Settings window → About.
  **Expect:** version `2.0.0-beta1`. It must never show `@project-version@` or anything with `@`.
  **If not:** screenshot.

## 2. Settings window

- [ ] **2.1 Open and close.** Try `/pui`, `/phoenix` and the minimap or addon compartment button. Press Escape to close.
  **Expect:** it opens on Home and closes with Escape. You also get one Phoenix UI entry under Esc → Options → AddOns.
- [ ] **2.2 Home.** **Expect:** module stats, the **This week** card (section 7.4), filter chips (All, Frames, Bars,
  Combat, Interface, Content, Phoenix, Off) and module tiles, each with its switch and a depth bar ("44 / 150").
  Clicking a tile opens that module. On a wide window the right side shows Health checks, Quick actions and What's
  new; make the window narrower than 1100 px and they move under the stats.
- [ ] **2.3 Search.** Type `font` in the search box.
  **Expect:** results from several modules. Clicking one jumps to the setting and highlights it. A nonsense word
  shows `Nothing matches that search.`
- [ ] **2.4 Window scale.** Drag the **Window scale** slider in the footer from small to large.
  **Expect:** the window scales smoothly, text stays sharp, and the size is kept after `/reload`. `/pui reset` puts the window back in the middle.
- [ ] **2.5 Dragging.** Move the window by its title bar.
  **Expect:** it moves, and the position is kept after `/reload`.
- [ ] **2.6 Rail and page list.** The left rail has 7 groups: Home, Frames, Bars, Combat, Interface, Content,
  Phoenix. Click each one.
  **Expect:** the list beside it shows that group's pages (Interface and Phoenix with sub-headings), each with a
  green dot when on and a thin depth bar; hovering the bar says "N of M planned settings built". Every module you
  used before is still there with the same settings. On WoW Forever, Content has Encounters and PvP only.
- [ ] **2.7 Search jumps.** Search `texture`, then click a result in another group. Then search `hp` and `cd`.
  **Expect:** the rail switches group, the page opens on the right tab and the row flashes. Results show the path
  (group › module › tab › section). `hp` finds health options, `cd` cooldown ones. The empty box reads
  "Search N settings…".
- [ ] **2.8 Reset.** Change a slider, then right-click its row (or click the orange ↺ arrow beside it).
  **Expect:** that one setting goes back to its default. The ↺ on a card's header asks for a second click, then
  resets the card; the ↺ beside a module's Enabled switch resets the whole module but keeps it on.
- [ ] **2.9 Diagnostics.** Phoenix → Diagnostics → **Run**.
  **Expect:** "N of N loaded" in green and a report you can copy. If anything failed, screenshot this page.
  Set **Icon source** to Game icons: every rail and page-list icon turns into a Blizzard icon; set it back to Automatic.
  The **Settings addon** line reads "Phoenix_UI_Options 2.0.0-beta1, matches" in green.
- [ ] **2.10 Row tooltips.** Point at a few rows on different pages (a toggle, a slider, a dropdown, a font picker).
  **Expect:** a small tooltip above the label with the default value ("Default: On", "Default: 12", the default
  choice) and "Right-click the row to reset it."; rows marked Reload or Out of combat say so. No row is silent.
- [ ] **2.11 Slash help.** Type `/pui help`, then `/pui nonsense`.
  **Expect:** the full command list in chat; the nonsense command says it is unknown and points to `/pui help`.
- [ ] **2.12 Preview dock.** Open Nameplates on a window at least 1100 px wide (the default 1280×800 is).
  **Expect:** the live preview sits on the right, scaled to fit, with sample-state chips (pick several) and
  **Show in world**; scrolling the page does not move it. Drag the window narrower than 1100 px: the preview moves
  into the page above the cards and stays pinned while you scroll.
- [ ] **2.13 Section switches.** Nameplates → Colours → Threat: switch the card's header toggle off.
  **Expect:** the card's rows grey out and cannot be changed; switch it on and they come back. Hovering the header
  switch shows its name and description.
- [ ] **2.14 Element chips.** Unit Frames: click Target, then Shift-click Focus, change Bar texture.
  **Expect:** both Target and Focus change, Player does not. Turn on **All** and change it again: every frame
  changes. Click the ⇄ beside one row: only that setting goes to every frame. "Apply all settings from" copies
  every setting from the frame you pick.
- [ ] **2.15 Borders & shadows.** Phoenix → General → Borders & shadows: open Border style and hover the cards.
  **Expect:** the preview and every Phoenix border set to Follow Appearance change as you hover; clicking keeps
  it. Try Ember with Glow colour on **Class**: borders glow in your class colour. Border colour **Theme** returns
  to the dark edge. Shadow depth darkens or lightens shadows.
- [ ] **2.16 Colour chips.** Any colour row with Class / Theme chips (for example a background colour cog).
  **Expect:** Class lights up and the swatch shows your class colour on every character; Theme follows the theme;
  picking a colour in the swatch unlights both.
- [ ] **2.17 Top bar.** Use the profile switch, **Layout** and **Test frames**.
  **Expect:** the profile changes at once; Layout closes the window and unlocks frames to move (Edit Mode when
  Movers is off); Test frames shows sample unit frames (a note if Unit Frames is off). In combat the footer says
  changes wait for the end of combat.
- [ ] **2.18 Footer.** **Expect:** "Changes save automatically", the last action, the pixel-perfect UI scale for
  your screen, the window scale slider and, only when something needs it, **Reload UI**.

## 3. Every module page

For **each** module in the page lists (General, Action Bars, Unit Frames, Group Frames, Name Plates, Cast Bars, Auras,
Auras & Cooldowns, Cooldown Text, Combat Text, Damage Meter, Tooltip, Chat, Minimap, Data Texts, Item Level, Bags, Spell History, Mythic+,
PvP, Automation, Quality, Skins, AFK, Movers, Bugs):

- [ ] **3.1 Preview.** The live preview at the top of the page reacts at once to every option you change.
  Scroll down: the preview stays stuck at the top while the options scroll under it. The eye button folds it away
  (kept after `/reload`). On Unit Frames, Nameplates and Cast Bars, the chips (Low health, Out of range, Targeted,
  Interrupted) switch the sample state.
  **If not:** name the module and the option.
- [ ] **3.2 Cogs.** Every ⚙ cog opens its popover, the popover settings work, and clicking outside closes it.
- [ ] **3.3 Enable toggle.** Turn the module off and on.
  **Expect:** off reverts to the Blizzard look (some modules ask for `/reload`, and that's fine); on restores it.
  No Lua error either way.
- [ ] **3.4 Fonts.** Open any font picker.
  **Expect:** a grid of cards, each with a sample line in its own face; typing and the style filter narrow it.
  Pointing at a card shows it on the preview at once; moving away puts the old font back; clicking keeps it.
- [ ] **3.5 Textures.** Open any bar texture picker.
  **Expect:** a grid of neutral-tinted strips (about 36), the same hover-to-try behaviour, and the choice applies to bars in game.
- [ ] **3.5b Fonts and Textures.** Phoenix → Fonts, then Textures.
  **Expect:** every font/texture setting of every module listed on one page; changing one here changes it on the
  module page too (the → arrow jumps there). **Apply to all** sets every row at once; **Use theme** returns them to
  Default. Sounds: each **Play** button plays the alert or the 5→1 countdown.
- [ ] **3.5c Auras & Cooldowns (Combat group).** First turn on Blizzard's Cooldown Manager (Options → Gameplay →
  Advanced Options → Cooldown Manager) and press **Open** on the **Choose spells** row (Behaviour tab) to pick a few spells.
  **Expect:** the Essential, Utility, Buffs and Bars viewers show square, cropped icons with a border and Phoenix
  timer/stack fonts; **Square icons** off gives Blizzard's round icons back; the Bars viewer uses your bar texture
  and colour. Timers and swipes keep counting **in combat** (they are Blizzard's). **Fade out of combat** dims the
  viewers until you pull. **If not:** name the viewer and the option, and send `/pui bugs`.
- [ ] **3.5d Countdown voice (now on Encounters → Sounds).** After updating from an older build your voice, start
  number and switches are still as you left them (they moved from Auras & Cooldowns). Press **Try it**: you hear
  5 → 1 in the chosen voice. Then in a group type `/countdown 10` (without DBM or BigWigs loaded).
  **Expect:** the voice speaks the last five seconds and a **Pull** bar runs; `/countdown 0` (cancel) stops both.
  Mythic+ key start and arena/battleground gates count down too when **Mythic+, arena and battleground starts** is
  on. With DBM or BigWigs loaded Phoenix stays quiet on pulls (their voice counts). Nothing is spoken twice.
- [ ] **3.5e Unit Frames depth.** On the Unit Frames page pick **Boss** in the frame bar and press **Test** on the **Show test frames** row.
  **Expect:** sample Target, Focus and Boss 1–3 frames appear where the real ones sit, each tagged *TEST*, in your
  styles; pressing again hides them; entering combat hides them at once. Try **Portrait → Class icon / Hidden**,
  the Leader / Raid marker / PvP icon switches, **Fade out of range** (target a party member and walk away: the
  frame fades; enemies never fade), and **Phoenix aura icons** (cropped buff/debuff icons under target and focus).
  **If not:** name the frame and the option.
- [ ] **3.5f Nameplates depth.** On the **Colours** tab turn on target and focus colours and **Threat colours**.
  **Expect:** your target and focus plates take their colours; in a dungeon as a tank, mobs you hold are green,
  mobs slipping are yellow and mobs on others red (as damage or healer: red when they attack you). The plate cast
  bar uses the Phoenix texture/colour/font, and the debuff icons above the plates are cropped with a border.
  No Lua errors in Mythic+ or delves. **If not:** send `/pui bugs`.
- [ ] **3.5g Presets.** Phoenix → Presets: apply **Clean**, then **Vivid**, then press **Undo**.
  **Expect:** each look changes the theme colour, fonts, bar texture and borders everywhere at once; Undo puts the
  previous look back exactly. Your profile list and other settings are untouched.
- [ ] **3.5h Welcome picker.** Only on a brand-new install (no `Phoenix_UI.lua` in SavedVariables) or with
  **Open** on the Presets page.
  **Expect:** about four seconds after the first login a window offers the three looks and **Skip**; picking or
  skipping closes it for good. Existing users never see it on their own.
- [ ] **3.5h2 Module picker.** Right after the welcome picker (pick a look or Skip), or with **Choose modules** on
  Phoenix → Presets.
  **Expect:** a window lists every optional module with its icon, name and description, all switches matching their
  current state. Turn two off: the button reads **Apply and reload** if one of them needs a reload, otherwise
  **Apply**. Applying changes exactly those modules; **Keep all** changes nothing. It does not open again on its own.
- [ ] **3.5h3 Encounters (Combat group) without a boss mod.** Disable DBM and BigWigs for this test. Open
  Encounters and press **Run test**.
  **Expect:** for about 30 s Phoenix bars count down the game's sample boss abilities (sorted, soonest at the
  bottom, the last 5 s in the emphasis colour) and a banner shows a critical, a medium and a minor sample warning
  with sounds. Change width, height, texture, fonts and border: the preview and the running bars follow. Edit Mode
  (`/pui edit`) shows **Phoenix UI – Boss timeline** and **Phoenix UI – Boss warnings** to move. Switch **Show boss
  timers as → Game default** and run the test again: Blizzard's own timeline is back (its option in Options →
  Gameplay → Combat Warnings is on again). Switch back to Phoenix: Blizzard's timeline is off again.
  **If not:** name the step and send `/pui bugs`.
- [ ] **3.5h4 Encounters in a real fight.** Any dungeon or raid boss with boss warnings on (Normal is fine).
  **Expect:** the boss abilities appear as Phoenix bars with names and icons, paused abilities fade, warnings show in
  the Phoenix banner. **No Lua errors** and nothing in `Logs\taint.log` mentioning Phoenix (secret names are only
  displayed, never read). After the kill, `/reload` and check the bars are gone.
- [ ] **3.5h5 Pull and break.** As leader (or solo) press **Pull** on the Pull & break tab, then **Cancel the pull**;
  type `/pui encounters pull 5`. Then **Break** (5 min) and **End the break**; `/pui encounters break 1`.
  **Expect:** the game's countdown starts and stops for the whole group; the break bar appears. In a group with a DBM
  or BigWigs user, they see your break and Phoenix shows theirs. As a plain member you get "You need to be group
  leader or assistant". During a boss fight a break is refused.
- [ ] **3.5h6 With BigWigs.** Enable BigWigs (and LittleWigs), `/reload`, open Encounters.
  **Expect:** the overview says BigWigs draws the bars; Phoenix draws no second set and says nothing on pulls. On
  the BigWigs tab the status reads "the Phoenix style is registered". In BigWigs → Bars → Style pick **Phoenix**
  and run BigWigs' test bars: they wear the Phoenix texture, fonts and border. Pick BigWigs' default style again:
  the bars look like BigWigs' own again.

- [ ] **3.5i Bags.** Open your bags (separate and combined: Bag options → Combine bags).
  **Expect:** a Phoenix panel behind each bag window, cropped icons with thin borders (green/blue/purple for
  uncommon and better when **Quality borders** is on), a dark empty-slot background and the stack-count size you
  chose. Gear you can use with a higher item level than what you wear in that slot shows a **green arrow** at top
  left (a cloth helm on a warrior does not). Equip it: the arrow goes away. Using, dragging and selling items works
  in and out of combat with no "blocked action" message. **If not:** name the item and send `/pui bugs`.
- [ ] **3.5j Data bar order and new segments.** On Data Bar turn on Free bag slots, Item level, Friends online,
  Guild online and Mail, then drag the chips in **Order**.
  **Expect:** an accent marker shows where a chip will land; the bar and the preview follow at once and keep the
  order after `/reload`; the ↺ on the row restores the default order. Clicking a segment out of combat opens bags,
  the character pane, friends or guild; in combat nothing opens. The values update when you loot, equip or a friend
  logs in.
- [ ] **3.5k Minimap button bin.** With an addon that has a minimap button (most use LibDBIcon: DBM, BigWigs,
  Details!, …), look at the minimap's top-right corner.
  **Expect:** one Phoenix glyph; clicking it opens a panel with the addon buttons in a grid (Columns slider); each
  button still works; Escape closes it. Buttons an addon hides stay hidden. With **Collect addon buttons** off and
  `/reload`, the buttons are back on the minimap edge.
- [ ] **3.6 Tooltip page.** It has two tabs, **Appearance** and **Content**. The preview tooltip changes with every option.
- [ ] **3.7 Chat page.** Turn on **Flashing tabs in the accent colour** and **Coloured whisper tabs**. Ask someone to whisper you while another
  tab is selected.
  **Expect:** that tab glows in the theme colour, and a whisper tab (right-click a tab → new whisper window) is coloured
  pink or blue.
- [ ] **3.8 Disabled and hidden options.** Turn a parent toggle off.
  **Expect:** the options that depend on it grey out or hide.

## 4. Profiles (Settings → Profiles)

- [ ] **4.1 Create.** Click New profile and name it `Test`.
  **Expect:** it switches to `Test` with default settings.
- [ ] **4.2 Copy.** Use Duplicate profile to make `Test2`.
  **Expect:** identical settings, and changing `Test2` does not change `Test`.
- [ ] **4.3 Export.** Click Export.
  **Expect:** a string starting with the Phoenix prefix. Press Ctrl+A, Ctrl+C and paste it into Notepad.
- [ ] **4.4 Import.** Paste it back, using Import as `Imported`.
  **Expect:** the preview reads `"…": N modules, M settings change.` with one entry per module (unchanged modules
  greyed), the import gives the same settings, and pasting garbage shows `This is not a Phoenix UI profile string.`
- [ ] **4.5 Reset.** Click Reset profile and confirm.
  **Expect:** `Profile reset.` and defaults restored, in that profile only.
- [ ] **4.6 Rename and delete.** Rename `Test2`, then delete it.
  **Expect:** it is gone from the list, and you cannot delete the active profile.
- [ ] **4.7 Per specialization.** Turn on Profile per specialization, set a profile for each spec, then change spec.
  **Expect:** the profile switches automatically.
- [ ] **4.8 Slash.** Type `/pui profile Default`.
  **Expect:** `Switched to profile Default.` A name that doesn't exist gives `No profile named …`.
- [ ] **4.9 Export some modules.** Under Export pick Nameplates and Unit Frames in Modules to export, then Generate.
  **Expect:** importing that string on another profile lists only those two modules.
- [ ] **4.10 Merge.** Paste a string and click **Merge** instead of Import.
  **Expect:** "N modules merged into <your profile>"; only those modules change, everything else stays.
- [ ] **4.11 Characters.** With two or more characters that used Phoenix, set another character's profile under
  Characters, then log in on it.
  **Expect:** it loads that profile. Changing this character's row switches at once.

## 5. Edit Mode and Movers

- [ ] **5.1 Edit Mode.** Type `/pui edit` or use Esc → Edit Mode.
  **Expect:** Phoenix frames (Mythic+ timer, Damage Meter, Spell History, Data Text panels) appear as Edit Mode frames
  with a sample, can be dragged, and are kept after `/reload`. Blizzard frames keep their own Edit Mode settings.
- [ ] **5.2 Edit Mode layouts.** Switch Edit Mode layout.
  **Expect:** Phoenix frame positions follow the layout.
- [ ] **5.3 Movers.** Type `/pui movers` to unlock them.
  **Expect:** handles over zone text, alerts, the boss banner and the other listed frames. Test each control: drag;
  mouse wheel (scale); Shift+wheel (opacity); arrow keys (1 px) and Shift+arrows (10 px) while hovering; right-click
  (reset). Run `/pui movers` again to lock.
- [ ] **5.4 Movers in combat.** Unlock, then pull a training dummy.
  **Expect:** movers lock themselves at once, with no taint error.

## 6. Combat and taint

- [ ] **6.1 Dummy fight.** Fight a dummy for 1–2 minutes using action bars, cast bars and cooldowns.
  **Expect:** cooldown text, cast bar and combat text work, there are no errors, and `/pui bugs` stays empty.
- [ ] **6.2 Settings in combat.** Open `/pui` in combat and change a cosmetic option (for example a font).
  **Expect:** either it applies, or Phoenix waits and applies it after combat. No `ADDON_ACTION_BLOCKED`.
- [ ] **6.3 Protected actions.** In combat: open the spellbook, the talents and the world map; change targets; use focus.
  **Expect:** no "Interface action failed because of an AddOn" message.
- [ ] **6.4 After combat.** Leave combat.
  **Expect:** anything that waited for combat to end has now applied.
- [ ] **6.4b New features in combat.** With the Cooldown Manager skin, aura icons, threat colours and range fade
  on, do a full Mythic+ key or a raid boss.
  **Expect:** no `secret value` errors, no `ADDON_ACTION_BLOCKED`, and the test frames refuse to open in combat.
- [ ] **6.5 taint.log.** After the session, search `Logs\taint.log` for `Phoenix`.
  **Expect:** no lines blaming Phoenix_UI. **If not:** send the file.

## 7. Mythic+

- [ ] **7.1 Timer.** Start a key (any level).
  **Expect:** the Phoenix timer replaces the Blizzard block, showing the time with +2/+3 marks, enemy forces, deaths with
  the time penalty, and bosses as they fall.
- [ ] **7.2 Best splits.** Run the same dungeon twice, or a dungeon you have already timed with beta1.
  **Expect:** the second run shows green `-m:ss` (ahead) or red `+m:ss` (behind) next to each boss and forces, and the time
  to beat beside bosses still alive. Turn this off with **Compare with your best run**.
- [ ] **7.3 Forces pull preview (option: Current pull).** In combat, while pulling a pack.
  **Expect:** a `+x.x%` preview next to forces for what's in combat, or nothing at all. It must never show an error, a
  wrong huge number, or `?`. (Midnight may hide this data, and then the preview stays silent by design.)
  **If not:** screenshot, and say whether you were in a pack or on a boss.
- [ ] **7.4 Rating and vault.** Home → **This week** card.
  **Expect:** three tracks (Dungeons, Raid, World), each with 3 pips filled to match your Great Vault, progress text such as
  `3/4`, your season rating in its colour, runs this week and best key. Compare with the real Great Vault window.
  **If not:** screenshots of both.
- [ ] **7.5 Party keystones.** In a party (not in an instance), open Mythic+ → **Party keystones**.
  **Expect:** your own key at once. Party members with Phoenix, BigWigs, DBM or another LibKeystone addon show theirs
  within a few seconds, and Refresh asks again. Solo, it shows a hint instead.
- [ ] **7.6 In the key.** Inside the dungeon.
  **Expect:** no keystone messages are sent (chat lockdown). The list keeps the last known keys.
- [ ] **7.7 Completion.** Finish the key.
  **Expect:** a final time, upgrade level and no error. The next run of that dungeon uses the new best.

## 8. PvP and arena

- [ ] **8.1 Battleground.** Join a random battleground.
  **Expect:** the PvP module features (score and objective styling, `/gg` hint) work. No errors at the start or end.
- [ ] **8.2 Arena.** Join a skirmish.
  **Expect:** arena frames are styled, and `/gg` surrenders when that's allowed. Nothing breaks during prep or the gates.
- [ ] **8.3 Duels.** If Automation → **Decline duels** is on, a duel request is declined automatically.

## 9. Raid and group frames

- [ ] **9.1 Party.** Join a party of 5.
  **Expect:** group frames are restyled (texture, name font, health colours), and roles and ready check are visible.
- [ ] **9.2 Raid.** Join a raid of 10–40 (LFR or a world boss works).
  **Expect:** frames styled and no lag. Changing the group frame options outside combat updates every frame.
- [ ] **9.3 Group changes in combat.** Someone joins or leaves while you're in combat.
  **Expect:** no taint error. The style catches up after combat.

## 10. Name plates in a busy area

- [ ] **10.1 Busy zone.** Go to a crowded zone, city event or world boss with 20+ plates visible.
  **Expect:** plates are styled (texture, fonts, threat or class colours) with no frame drops compared to Phoenix off, and
  no errors as plates appear and disappear quickly.
- [ ] **10.2 Friendly and enemy.** Toggle friendly and enemy plates (Shift+V, Ctrl+V).
  **Expect:** both styles apply.

## 11. Tooltip

- [ ] **11.1 IDs.** With Tooltip → **IDs** on, hover over an item, a spell, an aura, an NPC and a mount.
  **Expect:** the matching ID line (Item ID, Spell ID, NPC ID and so on), with no duplicate lines after several hovers.
- [ ] **11.2 Units.** Hover over players and NPCs.
  **Expect:** class colours, guild, target and item level (where on), and a styled health bar. **In combat** nothing errors
  (secret values).
- [ ] **11.3 Anchor.** If the cursor anchor is on, the tooltip follows the mouse out of combat and uses the default anchor
  as configured.

## 12. Bug catcher

- [ ] **12.1 Provoke one.** Type `/phoenix testerror`.
  **Expect:** a chat line saying a labelled test error is being raised, then `/pui bugs` shows
  `PHOENIX TEST ERROR - safe to delete (/phoenix testerror)` with source `Phoenix_UI`. No Blizzard error window if the
  **Blizzard error window** option is off.
- [ ] **12.2 Repeat.** Run it 3 more times.
  **Expect:** one entry with count 4, not four separate entries.
- [ ] **12.3 Viewer.** In `/pui bugs`, step through the entries and copy one.
  **Expect:** the full stack and locals are readable. `/pui bugs clear` clears them after confirmation.
- [ ] **12.4 With your addons.** Enable your usual addons and `/reload`.
  **Expect:** other addons' errors are captured with their folder as the source, and Phoenix causes no new errors.
- [ ] **12.5 With BugGrabber and BugSack.** Keep both enabled, `/reload`, then `/phoenix testerror`.
  **Expect:** the Bugs page says *Capturing through BugGrabber*; the test error is in BugSack **and** in `/pui bugs`
  (same count after running it 3 more times). Errors BugSack shows for this session from addons that load before
  Phoenix are in `/pui bugs` too.
- [ ] **12.6 BugGrabber without BugSack.** Disable BugSack, `/reload`, `/phoenix testerror`.
  **Expect:** one Phoenix chat notice with a link, no extra "captured, click the link" line from BugGrabber.
- [ ] **12.7 Without BugGrabber.** Disable BugGrabber and BugSack, `/reload`.
  **Expect:** the Bugs page says *Capturing with Phoenix's own error handler*; `/phoenix testerror` is caught.
- [ ] **12.8 Viewer filters.** In `/pui bugs`, pick an addon in the addon menu and an earlier session in the session
  menu; search for part of a message.
  **Expect:** the list shows only matching reports; Clear removes only what is listed.
- [ ] **12.9 Delete and mark.** Select a report; click the check (Mark as reported), then the bin (Delete).
  **Expect:** the marked report dims with a check in the list and its copy text says *Marked as reported*; the deleted
  one is gone, and comes back as a new report if the error happens again.
- [ ] **12.10 Scope.** On the Bugs page set **Catch errors from** to *Phoenix UI only*, cause an error in another addon.
  **Expect:** it is not added; `/phoenix testerror` still is. Set it back to *All addons*.
- [ ] **12.11 Sounds.** Pick each notification sound and run `/phoenix testerror` (10 s apart).
  **Expect:** the chosen sound plays once per new error.

## 12b. Icons and self-test

- [ ] **12b.1 Restart.** After installing this build, quit the game completely and start it again (new icon files are
  only found at game start; `/reload` is not enough).
- [ ] **12b.2 Icons.** Open `/pui`.
  **Expect:** every rail button, page-list entry, card header and button shows its glyph, sharp at your resolution.
- [ ] **12b.3 Self-test.** Type `/pui diag`.
  **Expect:** `diag: N/N media files loaded …`, no Lua error. If any file is listed as FAILED, Phoenix switches to game
  icons by itself; `/reload` and send the `diag` block of `Phoenix_UI.lua`.

## 13. Uploader to the dashboard

- [ ] **13.1 Write the file.** After 12.1, `/reload` (this writes SavedVariables).
- [ ] **13.2 Upload.** Within about a minute, `uploader.log` shows `… 1 report(s) to send` and `accepted 1` (or `updated`).
  **If not:** send `uploader.log`.
- [ ] **13.3 Dashboard.** Open https://vq8s.com/phoenix/admin and sign in.
  **Expect:** an issue with the message `PHOENIX TEST ERROR - safe to delete …`, your install ID (shown on Bugs → Upload),
  version `2.0.0-beta1` and your locale.
- [ ] **13.4 Send to the author: default.** First login after installing this build.
  **Expect:** one chat line saying error reports are sent to the author while Phoenix Uploader runs, and how to turn
  it off. It does not appear again after `/reload`. On *Bugs → Upload reports to VQ8S.com*, **Send error reports to
  the author** is on.
- [ ] **13.5 Switch it off.** Turn it off (or `/pui bugs share off`), `/reload`, then `/phoenix testerror` and `/reload`.
  **Expect:** `uploader.log` shows `skipping … "Send error reports to the author" is off in Phoenix UI` and nothing
  new reaches the dashboard. (Needs Phoenix Uploader 1.1.0; the 1.0.0 build ignores the switch.)
- [ ] **13.6 Switch it back on.** `/pui bugs share on`, `/reload`, `/phoenix testerror` 3 times, `/reload`.
  **Expect:** the test error arrives with the new count; nothing caught while it was off is sent.
- [ ] **13.7 Privacy.** Open the test report on the dashboard (or copy one in `/pui bugs`).
  **Expect:** no character name, realm, BattleTag or Windows user name anywhere in message, stack or locals.
- [ ] **13.8 Clean up.** On the issue page click **Delete**.
  **Expect:** the issue and its reports are gone, and the Data page audit log lists the deletion.

## 13b. Sim (needs Phoenix Uploader 1.2.0)

Uses the Phoenix app 1.2.0 (until it is released: the test build you were given), running in the tray. Use a
character with a spec, talents and at least one wearable item in the bags (a ring or trinket is best).

- [ ] **13b.1 Page.** `/pui sim` (or Content → Sim).
  **Expect:** the pinned results card shows a sample with a *Sample* badge, the paperdoll shows your gear with item
  icons (empty slots in grey), the list shows the bag gear you could wear with item level and slot.
- [ ] **13b.2 Filter and pick.** Click your ring slot on the paperdoll, tick one ring, click **All slots**.
  **Expect:** the list filters to rings, the tick stays, the footer says how many sets the mode will sim.
- [ ] **13b.3 Test mode.** Press **Test**. **Expect:** the card, history and footer fill with sample data; press it
  again to leave.
- [ ] **13b.4 Prepare and send.** Mode **Compare**, fight Patchwerk, press **Prepare sim**.
  **Expect:** the status dot reads ready and the button becomes **Reload to send**. Press it.
- [ ] **13b.5 First time: consent.** **Expect:** within about 5 seconds a Phoenix Uploader window asks whether it may
  download SimulationCraft (version, size, source, folder; *No* is the default). Press **No**, `/reload`.
  **Expect:** the Sim page says the download was declined. In the tray choose **Download SimulationCraft...**.
- [ ] **13b.6 The sim.** **Expect:** `uploader.log` shows `archive SHA-256 matches the pin`, `SimulationCraft 1210-01
  ready` and `sim: … done in N s`, and (unless switched off) a window offering the HTML report. `/reload`.
  **Expect:** chat says a sim result arrived; the card shows your DPS, each tried item's DPS and difference, the
  fight and the sim time; the run is first in History.
- [ ] **13b.7 Tooltip and bags.** Hover the ring in your bags, open the bags.
  **Expect:** a `Sim: +x.x% (+n)` line with its age; the bag arrow follows the sim (up only if it gained DPS).
  Switch either off on the Sim page (*Show results*) and they go away.
- [ ] **13b.8 Weights and best set.** Repeat 13b.4 with **Stat weights** (no ticks needed) and with **Best set**
  (two rings ticked). **Expect:** weights listed with your main stat at 1.00; best set lists the combinations.
- [ ] **13b.9 History.** Click an older entry: the card shows it. Right-click it: it is deleted.
- [ ] **13b.10 Cancel and errors.** Prepare, then **Cancel** before reloading: nothing is sent. Prepare in combat:
  refused with a message. Respec to a spec without talents chosen: Prepare says talents are missing.
- [ ] **13b.11 Remove.** Tray → **Remove SimulationCraft**. **Expect:** `%LOCALAPPDATA%\Phoenix UI Uploader\simc`
  is gone; the next sim asks again.
  **If anything fails:** send `uploader.log` and the folder `%LOCALAPPDATA%\Phoenix UI Uploader\sims\<newest>`.

## 13c. WoW Forever (from 4 Nov 2026, or a Forever test client)

Phoenix loads `Phoenix_UI_Forever.toc` on WoW Forever (interface 16001). Forever's launch folder name is not
published yet (the beta used `_classic_beta_`): in Battle.net pick *World of Warcraft: Forever*, cog → *Show in
Explorer*, and copy **both** folders into that client's `Interface\AddOns`. The Phoenix app does not watch
Forever yet, so send errors from `/pui bugs` by hand.

- [ ] **13c.1 Loads, not out of date.** Character select → AddOns.
  **Expect:** *Phoenix UI* and *Phoenix UI Options* listed without "Out of date". `/pui` opens the window.
  `/run print(GetBuildInfo())` prints 1.60.1 … 16001. **If not:** screenshot of the AddOns list.
- [ ] **13c.2 Which game.** Phoenix → Diagnostics. **Expect:** *Game client* starts with *WoW Forever · 1.60.1*.
- [ ] **13c.3 Retail-only features are gone, not broken.** **Expect:** no *Mythic+* page (the group is called
  *PvP*), no *Sim* page, no Great Vault card on Home, no Mythic+ rating or Sim switches on the Tooltip page, no
  enemy-forces switches on Nameplates, no Sim arrow switch on Bags, none of them in search (`keystone`, `sim`) or
  in Phoenix → Presets → module picker. The Nameplates card no longer mentions Mythic+.
- [ ] **13c.4 Encounters.** Content → Encounters. **Expect:** tabs *Pull & break*, *Sounds* and *BigWigs* only, and a
  note that this game has no boss timeline or warnings. **Run test**: a 10-second pull bar with the countdown
  voice on your screen only. In a group as leader: **Pull** starts the game's countdown for everyone and the bar;
  **Break** shows the break bar (and reaches DBM/BigWigs users when shared).
- [ ] **13c.5 Everything else.** Walk sections 2, 3 (skipping Mythic+ and Sim), 5, 6, 9, 10 and 11 once.
  **Expect:** the same results as retail. Unit frames, minimap and chat use Forever's own art underneath (Blizzard
  reskinned them), so look for text or bars that sit wrong, not for retail's exact look.
- [ ] **13c.6 Profiles.** Profiles page. **Expect:** the *Specializations* section shows only if your class can choose a
  specialization on Forever. Importing a retail export works; Mythic+ and Sim settings in it are kept but unused.
- [ ] **13c.7 Taint and errors.** A dungeon run with `/console taintLog 1`.
  **Expect:** nothing from Phoenix in `/pui bugs` or `Logs\taint.log`.
  **If anything fails:** the step number, a screenshot and `/pui bugs` → copy.

## 13d. Action bars (2.0 S7)

Phoenix bars are the default. Start with `/console taintLog 1` and an empty `/pui bugs`. Steps marked *combat*
need a target dummy.

- [ ] **13d.1 First login.** **Expect:** bars 1–4 (bar 4 vertical on the right), the pet bar when you have a pet, the
  stance bar for classes with forms; Blizzard's art bar is gone. Every spell is where it was. Edit Mode still opens.
- [ ] **13d.2 Layout.** Bars tab, chip *Bar 1*: Buttons 8, Lines 2, Grow *Left*, Wrap *Up*, spacing 6, *Square* off
  with height 30. **Expect:** the bar and the pinned preview change together. Shift-click *Bar 2* and change Width:
  both bars follow. *Show empty buttons* shows the grid; with it off, dragging a spell still reveals the slots.
- [ ] **13d.3 Layout mode.** Press **Layout mode** on *Move the bars* (or Layout in the top bar). **Expect:** every Phoenix bar, the vehicle
  exit and the item bar get an overlay; dragging saves; right-click resets that bar to its default. `/reload`: the
  positions stay. Start combat: Layout mode closes.
- [ ] **13d.4 Paging (bar 1).** Druid: cat/bear/moonkin/travel swap bar 1; Rogue: stealth. Skyriding mount: the
  skyriding page. Set *Shift switches to Page 2* and hold Shift. Turn on *Page arrows* and click them in combat.
  **Expect:** each switch works, also in combat, with no error.
- [ ] **13d.5 Visibility (combat).** Bar 3: *Out of combat* off → it appears only in combat. Bar 2 *Fade out of
  combat* 40 %: dims out of combat, full when hovered, in combat, while dragging a spell and with the spellbook open.
  Bar 5 *Mouseover only* with *Linked bars*. A visibility macro `[mod:alt] show; hide` on bar 6.
- [ ] **13d.6 Vehicles.** A vehicle quest or a flight path. **Expect:** with *Hide in vehicles* the bars go away and
  Blizzard's vehicle bar takes over; the Phoenix vehicle exit button leaves the vehicle or lands the flight early.
- [ ] **13d.7 Buttons.** Buttons tab: each shape (square, rounded, circle, hexagon), border styles, icon zoom.
  **Expect:** icon, cooldown swipe, highlight and border follow the shape. Out of range (red), not enough power
  (blue), unusable (grey), with Tint = icon / hotkey / both. Proc glow: Blizzard, pixel lines, sparks, soft glow
  (a proc spell such as Hot Streak or Sudden Death). Assisted highlight with Blizzard's assisted combat on.
- [ ] **13d.8 Text.** Short hotkey names: Shift-1 shows **S-1**, mouse button 4 **M4**. Macro names on/off, count
  font on a stack of potions, cooldown number size on bars (0 = Cooldown Text size), charge numbers.
- [ ] **13d.9 Extra bars.** An extra action button or a zone ability (garrison/covenant style): Phoenix style, scale,
  hide art. Game menu and bag buttons *On mouseover*: invisible until hovered, clickable then.
- [ ] **13d.10 Item bar.** Bars tab, chip *Item bar*, enabled; accept a quest with a usable item, and list `5512` (healthstone)
  in *Extra items*. **Expect:** both appear, show their count and cooldown, and use the item on click (also in combat).
- [ ] **13d.11 Cooldown Text.** Cooldown Text page: size 18 with *Scale with icon size*: small pet buttons get smaller
  numbers. Tenths below 3 s, shortest cooldown 1.5 s (the global cooldown has no number), hide on buff icons.
  *Colour numbers by time left*: red under 3 s, then the seconds and minutes colours (action buttons only).
- [ ] **13d.12 Combat and taint (combat).** Change any Action Bars setting in combat. **Expect:** Phoenix says it will
  apply after combat and does so; no `ADDON_ACTION_BLOCKED`, nothing in `Logs\taint.log` from Phoenix_UI.
- [ ] **13d.13 Blizzard bars.** *Bars owned by* → *Blizzard (Edit Mode)*, reload. **Expect:** Blizzard's bars back under Edit Mode with
  Phoenix button styling only; switching back and reloading restores the Phoenix bars and their layout.

Known limits: Edit Mode's *number of buttons* for a Blizzard bar can still hide buttons on the matching Phoenix bar
(set it to 12); action buttons lock with Blizzard's global *Lock action bars* setting (no per-bar lock); charge
counts are not hidden at 0 (the value is secret); the item bar needs Phoenix bars; colour by time left is new and
action-button only.
  **If anything fails:** the step number, a screenshot and `/pui bugs` → copy (and `Logs\taint.log` for 13d.12).

## 13e. Unit frames (2.0 S8)

Phoenix frames are the default. Start with `/console taintLog 1` and an empty `/pui bugs`. Steps marked *combat*
need a target dummy; *group* needs a party or a follower dungeon.

- [ ] **13e.1 First login.** **Expect:** Phoenix player and target frames left and right of centre, the pet frame
  under the player frame when you have a pet; Blizzard's player, target, focus and boss frames are gone. Click a
  frame: left click targets, right click opens the unit menu (set focus from it: the focus frame appears).
- [ ] **13e.2 Test frames.** Unit Frames → **Show test frames** (or Test in the top bar). **Expect:** every frame,
  including five boss frames, with sample names, bars, auras and icons where the real ones sit. Press again to
  hide. Start combat: they hide by themselves.
- [ ] **13e.3 Per-frame settings.** Chip *Target*: width 260, height 50, portrait *3D model* on the left, power
  *Below the frame*. **Expect:** the target frame and the pinned preview change together. Shift-click *Focus* and
  change the width: both follow. *Apply to: All* on a row copies it to every frame.
- [ ] **13e.4 Layout mode.** Press **Move frames**. **Expect:** each Phoenix frame (and the boss group as one) has
  an overlay; drag, snap, right-click to reset. `/reload`: the positions stay.
- [ ] **13e.5 Health colours (combat).** Health colour *By health left* on the target: green at full, yellow at
  half, red when low (the colours are in *Health colour steps*). *Dark mode bar*: the lost part shows the colour.
  Shield yourself (Power Word: Shield, Ignore Pain …): a striped shield after the health; a heal absorb debuff
  shows dark at the end.
- [ ] **13e.6 Text tags.** Health text `[health:current] / [health:max] ([health:percent])`, extra text
  `[level] [classification]`. **Expect:** the numbers update in combat with no error; 1234567 reads 1.2M (or
  123万 with East Asian numbers). Dead targets show *Dead*, players who log off *Offline*.
- [ ] **13e.7 Class resource.** Rogue or feral druid in cat form: combo points (charged points coloured). Death
  knight: six runes, sorted by time left. Brewmaster: the stagger bar turns yellow then red under heavy damage.
  Paladin, warlock, evoker, Windwalker monk, Arcane mage likewise. *Hide when idle* hides it out of combat.
- [ ] **13e.8 Icons (group).** Raid markers on yourself and the target, leader crown, role icon, combat and resting
  marks, an elite or rare target star, a ready check (ready / not ready / waiting), the threat glow when a mob
  attacks you.
- [ ] **13e.9 Auras.** Target a mob and debuff it: your debuffs bright, other players' greyed, dispel colours on
  magic/curse/poison/disease. Buffs above the frame, 8 per row. Point at an icon: its tooltip.
- [ ] **13e.10 Range and fading (group).** A party member more than 40 yards away as focus fades to the range
  opacity. *Fade out of combat* on the player frame: dims at full health with no target, comes back on hover.
- [ ] **13e.11 Boss frames.** Any dungeon boss (or a world boss). **Expect:** boss frames with their cast bars
  (Blizzard's bars, placed under each Phoenix frame), the encounter power bar where a boss has one, the target
  mark on the boss you have targeted.
- [ ] **13e.12 Arena.** Turn on *Show this frame* for *Arena*, reload, and enter a skirmish. **Expect:** arena
  frames with PvP trinket and specialization; with arena off (the default) Blizzard's arena frames stay.
- [ ] **13e.13 Vehicles.** A vehicle quest. **Expect:** the player frame shows the vehicle, the pet frame you; on
  leaving they swap back.
- [ ] **13e.14 Combat and taint (combat).** Change size or position settings in combat. **Expect:** Phoenix says it
  will apply after combat and does; no `ADDON_ACTION_BLOCKED`, nothing in `Logs\taint.log` from Phoenix_UI.
- [ ] **13e.15 Blizzard frames.** *Unit frames* → *Blizzard frames, reskinned*, reload. **Expect:** Blizzard's frames
  back under Edit Mode with the 1.x skin options; the test button shows sample Blizzard-position frames.
  Switching back and reloading restores the Phoenix frames and their layout.

Known limits: arena diminishing returns are not shown (the 12.x crowd-control data is secret to addons, use
Blizzard's arena frames for it); enemy range is not known in combat (enemy frames stay solid then); spell cost
prediction is not drawn; the cast bars are still Blizzard's until S9; the player cast bar stays where Edit Mode
puts it.
  **If anything fails:** the step number, a screenshot and `/pui bugs` → copy (and `Logs\taint.log` for 13e.14).

## 14. Other client languages

Phoenix ships deDE, frFR, esES/esMX, ptBR, ruRU, itIT, koKR, zhCN and zhTW. To test a language without another
account: in the Battle.net launcher go to Settings → Game Settings → World of Warcraft → Text language, then restart
the game.

- [ ] **14.1 ruRU.** **Expect:** every page in Russian, with Cyrillic in all bundled fonts (fonts without Cyrillic fall
  back to the game font). No text runs past its row.
- [ ] **14.2 koKR.** **Expect:** Korean text everywhere with no empty boxes (□). All Phoenix text uses the game's own
  font on Korean and Chinese clients, so picking another font in a picker changes nothing there (that is by design).
- [ ] **14.3 zhCN or zhTW.** As 14.2, for Chinese characters.
- [ ] **14.4 Back to your language.** Switch back to English.
  **Expect:** everything is English again, and settings are unchanged.
  **If anything fails:** screenshot and the page name. For untranslated text, the English line you saw.

## 15. Persistence

- [ ] **15.1 Reload.** Change 3 settings in different modules, then `/reload`.
  **Expect:** all 3 are kept.
- [ ] **15.2 Relog.** Log out to the character screen and back in.
  **Expect:** same as 15.1. The profile and window position are kept.
- [ ] **15.3 Alt.** Log in an alt using the same profile.
  **Expect:** shared settings are identical. Mythic+ best splits are shared account-wide.
- [ ] **15.4 Restore test.** (Optional) Restore the WTF backup from 0.1 and log in.
  **Expect:** the migration from 1.x runs again cleanly (repeats 1.1).

---

**When you're done:** zip `Logs\taint.log`, `uploader.log` and `WTF\Account\<acc>\SavedVariables\Phoenix_UI.lua`, and send
them with the list of failed step numbers.
