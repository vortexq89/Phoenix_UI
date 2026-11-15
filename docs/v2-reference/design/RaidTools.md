# Raid Tools (spec 22.13, plan 1.O / 5.21) - step 9a

19 settings. Owner of countdowns, markers, ready check and encounter stats.

- **Countdowns:** pull through Blizzard's group countdown (`C_PartyInfo.DoCountdown`; 0 cancels), break as a Phoenix countdown announced through the router (topic "Raid tools"), key countdown (`RT.KeyCountdown`, for Ascent's keystone insert). Every countdown, including one someone else starts (`START_PLAYER_COUNTDOWN`), is one shared state; Kernel signal `COUNTDOWN` lets Pulse draw the bar. `/pui pull [s]`, `/pui cd [s]` (alias), `/pui break [min]`, `/pui rc`.
- **Bar** (off / when I lead or assist / any group / always; scale; Studio element `raidtools.bar`): 8 target markers, 8 secure world-marker buttons plus clear (built and changed out of combat only), Ready, Pull/Cancel, Break, countdown text on a Ticker entry that runs only while a countdown runs.
- **Ready check summary:** who was not ready or did not answer; names the game hides are counted, never shown.
- **Encounter stats** (`Stats.lua`, BigWigs tools parity, mockup 16): kills, wipes, best kill, last pull per boss and difficulty from `ENCOUNTER_START/END`; last pull vs best; wipe trend (longest pull per night, a plain proxy since phases are known only to boss mods); CSV export (`/pui stats export`); reset one boss with a confirm (`/pui stats reset <id> [difficulty]`); per character or warband-wide; history size; optional line after each pull; raids only; pauses while BigWigs or DBM is loaded (setting, on). Turning it off never deletes stats.

Deferred: boss-frame tooltip line, a stats window (the list prints in chat and the preview card for now), Pulse's countdown bar itself (Pulse step).
