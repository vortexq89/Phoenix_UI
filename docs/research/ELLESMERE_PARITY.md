# EllesmereUI parity matrix

Goal (t169): Phoenix is **ahead** of EllesmereUI on every module, setting and screen. EllesmereUI is studied for
features and layout only; Phoenix code is always original.

How this was measured (first pass, 30 Oct 2026): EllesmereUI option labels counted per options file in
`EllesmereUIOptions` (a row is roughly one `label =`), against Phoenix schema keys (`key = "`) per
`Phoenix_UI_Options/Options/*.lua`. These counts are rough: one Phoenix key can be a whole Style block (font, size,
outline, shadow, colour, anchor, offsets), so for Phoenix they undercount. Status comes from the counts plus a read
of both feature lists. **ahead** means more features or clearly better presentation. **equal** and **behind** rows
are the work queue, and each row is re-rated once its system has been through a pass and been rendered to
`renders\t169\`.

Legend: A = ahead, E = equal, B = behind, — = EllesmereUI has no equivalent, ✗ = Phoenix has no equivalent.

## 1. Modules
| system | EllesmereUI (options labels) | Phoenix (keys) | status | notes / gap to close |
|---|---|---|---|---|
| Settings window / organisation | Options shell, widgets, cog popups, apply-to-all | v4 Flow: rail, sticky header, masonry cards, search over every setting, live preview, fold chips | A | keep: whole-pixel columns and the 20% chrome rule (t165) |
| Plugin manager | per-addon folders, Panel/Startup | Plugins page, toggles that load live, `needs`, memory | A | |
| Profiles | 8 | Profiles page, import/export | E | add: per-spec auto-switch and a diff view before import |
| Unit frames | 24 + MiniFrames 213 + Shared* 347 (~370 in folder) | 201 keys (372 settings in the harness) | E | mini-frame (target-of-target, focus-target, pet) depth; per-frame copy-from |
| Raid / party frames | 91 + 12 + folder 149 | GroupFrames 53 keys + 6 placeable aura indicators (3x3 grid, nudge, growth, count, icon / colour / dispel-colour square, 8 filter kinds) per profile, raid marker bar | A | t169: indicators ship; previewed live on sample frames |
| Name plates | 8 + folder 133 | 97 keys (278 settings) | A | |
| Action bars | 7 + folder 97 | 88 | E | XP/rep bar page lives in DataBars for Phoenix; bar appearance presets |
| Resource bars (class power, swing, cast) | 13 + folder 145 | detached resource block (health, power, druid mana, class pips, spec bars, totems, imbues) on its own Resources tab; t169: row orders, power ticks, health/power colour modes, smooth fill | A | swing timer stays in Cast Bars |
| Cooldown manager | 28 + folder 204 (spell picker, bars, buff bars, glow and talent conditions) | Cooldown Manager skin + CooldownText 11 | A | done: spellbook picker, bars display, Cooldowns.icon art; open: glow and talent conditions |
| Aura / buff reminders | 57 | Auras 41 (reminders partial) | A | done: custom ID[:CLASS or ROLE] rules, group-buff mode, instance-only, v9 banner style |
| Player aura bars | 55 | in Auras | A | done: Tracker aura bars (watched IDs, timer fill via duration object, mover) |
| Damage meter | 48 | 54 + extras (ilvl, big timer, value backing, 15 spec icon styles) | A | |
| Mythic+ timer | 71 | MythicPlus 25 | A | done: v9 bar, chest, skull, affix and forces art, clock position; splits and death log were already in |
| Blizzard skins | 81 | Skins 57 | E | per-window toggles coverage |
| Chat | 14 | 42 | A | |
| Minimap | 57 | 29 | A | done: button bin bar mode under the minimap; shape, zoom and coords were already in |
| Bags | 23 | 29 | A | |
| Data bars / texts | 30 | DataTexts 54 | A | |
| Quest tracker | 11 | Tracker 64 + Quests 36 | A | |
| Group finder | 5 | 50 | A | |
| Tooltip | in General | 42 | A | |
| QoL (general) | 66 | Automation 27 + General 23 | B | |
| QoL movement alert | 27 | Tracker Mobility | A | done: class movement spell icon with cooldown, mover, live |
| QoL battle res | 7 | brez tracking present | E | |
| QoL alerts | 14 | partial (Encounters 28) | E | |
| QoL auto logging | 10 | Automation AutoLog | A | done: M+, raid, dungeon picks; only stops logs it started; live |
| QoL cursor | 1 | cursor ring present | E | |
| QoL raid tools | — | ready check / countdown partial | E | |
| Quickdraw (hold-key action menu) | 45 | ActionBars Ring | A | done: hold and release, open at cursor, v9 quick_ring art; verify the secure release pick in game |
| Macro model / macros | 104 + 6 | macro window skin, smart macros (heal, kick, mount rules), Pick up buttons per macro, open macro window from the GUI | E | t191: no step needs /macro; a full in-addon macro editor would make this A |
| Upgrade calculator | 9 | planner (track and level per slot, steps left per track) + calculator: crests per track and total, average item level gain, crest cost and ilvl-per-step sliders, refreshes on gear change | A | |
| Loot council | 5 | session boss drops with looter, Want button that shares your equipped item level in that slot, wants sorted by biggest upgrade, auto-open, raid-only, clear | E | in-game check: ENCOUNTER_LOOT_RECEIVED on both clients |
| Loadout manager | 7 | per spec: talent loadout + equipment set for raid, dungeon, arena, battleground and open world; offer window or auto apply on entering, apply-now button | A | in-game check: LoadConfig and UseEquipmentSet out of combat |
| Party mode | 10 | edge party lights (button start/stop), celebrations on boss kills, timed keys and level ups, sound, length and strength sliders; a manual session is never ended by a trigger | E | AFK screen lives in the AFK module |
| Friends | 1 | Friends skin | E | |
| Chrome icons (micro menu, window medallions) | flat micro buttons | Ember Bevel set: 76 icons + 28 medallions, 4 states, 16 px variant (t169) | A | t169: rail, tabs, page tile, window controls, macro window and 20+ window medallions wired; flat switch |
| Colours / fonts / textures / glows / style | 21 + 6 + 6 + 2 | Appearance page, Theme presets, media library, Phoenix Font | A | |
| What's new | 1 | popup once per update (off switch in About), Full changelog popup with every version from CHANGES.md (tools/gen_changelog.py), opened from the popup and About | A | changelog item titles are English (generated from CHANGES.md) |
| Gamepad | 1 | controller support switch, camera turn and tilt speed sliders (game console variables, no console needed) | A | |
| Combat text | — | 26 | A | |
| Encounters, PvP, AFK, Item level, Sim, Spell history, Bugs | — | yes | A | Phoenix-only |

## 2. Screens (to render to renders\t169\ per system)
Each system's pass renders its settings page, plus the in-game visual where the harness can draw it.

## 3. Work queue (behind first, then equal)
1. Raid/party frames: visual indicators. 2. Resource bars. 3. Cooldown manager. 4. Aura reminders and aura bars.
5. Mythic+ timer. 6. Minimap. 7. QoL (movement alert, auto logging). 8. Quickdraw. 9. Macros. 10. The small ones
(upgrade calculator, loot council, loadouts, party mode, what's new, gamepad). Then the equal rows.
