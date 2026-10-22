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
- [ ] **2.2 Home.** **Expect:** module stats, the **This week** card (section 7.4) and a grid of module tiles. Clicking a tile opens that module.
- [ ] **2.3 Search.** Type `font` in the search box.
  **Expect:** results from several modules. Clicking one jumps to the setting and highlights it. A nonsense word
  shows `Nothing matches that search.`
- [ ] **2.4 Window scale.** Drag the **Window scale** slider in the footer from small to large.
  **Expect:** the window scales smoothly, text stays sharp, and the size is kept after `/reload`. `/pui reset` puts the window back in the middle.
- [ ] **2.5 Dragging.** Move the window by its title bar.
  **Expect:** it moves, and the position is kept after `/reload`.
- [ ] **2.6 Sidebar groups.** The sidebar has 13 headings (Home, General, Appearance & Media, Unit Frames, Nameplates,
  Action Bars & Cooldowns, Combat, Group & Mythic+, Chat & Social, Maps, Minimap & Data, Tooltips & Items,
  Quality of Life, Tools). Click a heading with an arrow to fold or unfold it.
  **Expect:** the group with the open page is unfolded, the open/closed state is kept after `/reload`, no label is
  cut off or wraps, and every module you used before is still there with the same settings.
- [ ] **2.7 Search jumps.** Search `texture`, then click a result in another group.
  **Expect:** that group unfolds, the page opens on the right tab and the row flashes. Results show the path
  (group › module › tab › section).
- [ ] **2.8 Reset.** Change a slider, then right-click its row (or click the orange ↺ arrow beside it).
  **Expect:** that one setting goes back to its default. The ↺ on a card's header asks for a second click, then
  resets the card; the ↺ beside a module's Enabled switch resets the whole module but keeps it on.
- [ ] **2.9 Diagnostics.** Tools → Diagnostics → **Run**.
  **Expect:** "N of N loaded" in green and a report you can copy. If anything failed, screenshot this page.
  Set **Icon source** to Game icons: every sidebar icon turns into a Blizzard icon; set it back to Automatic.

## 3. Every module page

For **each** module in the sidebar (General, Action Bars, Unit Frames, Group Frames, Name Plates, Cast Bars, Auras,
Auras & Cooldowns, Cooldown Text, Combat Text, Damage Meter, Tooltip, Chat, Minimap, Data Texts, Item Level, Spell History, Mythic+,
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
- [ ] **3.5b Appearance & Media.** Open Fonts, then Textures.
  **Expect:** every font/texture setting of every module listed on one page; changing one here changes it on the
  module page too (the → arrow jumps there). **Apply to all** sets every row at once; **Use theme** returns them to
  Default. Sounds: each **Play** button plays the alert or the 5→1 countdown.
- [ ] **3.5c Auras & Cooldowns (Combat group).** First turn on Blizzard's Cooldown Manager (Options → Gameplay →
  Advanced Options → Cooldown Manager) and press **Open** on the **Choose spells** row (Behaviour tab) to pick a few spells.
  **Expect:** the Essential, Utility, Buffs and Bars viewers show square, cropped icons with a border and Phoenix
  timer/stack fonts; **Square icons** off gives Blizzard's round icons back; the Bars viewer uses your bar texture
  and colour. Timers and swipes keep counting **in combat** (they are Blizzard's). **Fade out of combat** dims the
  viewers until you pull. **If not:** name the viewer and the option, and send `/pui bugs`.
- [ ] **3.5d Countdown voice.** Press **Try it** on the Behaviour tab: you hear 5 → 1 in the chosen voice. Then
  in a group type `/countdown 10` (or let DBM/BigWigs start a pull).
  **Expect:** the voice speaks the last five seconds; `/countdown 0` (cancel) stops it. Mythic+ key start and
  arena/battleground gates count down too when **Mythic+, arena and battleground starts** is on. Nothing is spoken twice.
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
- [ ] **3.5g Presets.** Tools → Presets: apply **Clean**, then **Vivid**, then press **Undo**.
  **Expect:** each look changes the theme colour, fonts, bar texture and borders everywhere at once; Undo puts the
  previous look back exactly. Your profile list and other settings are untouched.
- [ ] **3.5h Welcome picker.** Only on a brand-new install (no `Phoenix_UI.lua` in SavedVariables) or with
  **Open** on the Presets page.
  **Expect:** about four seconds after the first login a window offers the three looks and **Skip**; picking or
  skipping closes it for good. Existing users never see it on their own.
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
  **Expect:** the preview reads `Valid profile "…" with N modules.`, the import gives the same settings, and pasting
  garbage shows `This is not a Phoenix UI profile string.`
- [ ] **4.5 Reset.** Click Reset profile and confirm.
  **Expect:** `Profile reset.` and defaults restored, in that profile only.
- [ ] **4.6 Rename and delete.** Rename `Test2`, then delete it.
  **Expect:** it is gone from the list, and you cannot delete the active profile.
- [ ] **4.7 Per specialization.** Turn on Profile per specialization, set a profile for each spec, then change spec.
  **Expect:** the profile switches automatically.
- [ ] **4.8 Slash.** Type `/pui profile Default`.
  **Expect:** `Switched to profile Default.` A name that doesn't exist gives `No profile named …`.

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
