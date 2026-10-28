# Pulse (plan 5.21, 1.O) - step 9b

29 settings, a module switch and a soft conflict choice. Draws timers; owns none of the countdowns (Raid Tools does) and none of the clocks (Core `PUI.CombatTimer`).

- **Bars** (`Bars.lua`): pooled bar group, fill driven by the engine (`StatusBar:SetTimerDuration` with a duration object), one text pass on a Ticker entry that exists only while bars show. Width, height, gap, most bars, grow, icon and side, text size, time format, opacity, background, spark. Soonest first for plain timers; timeline events keep the game's order.
- **Boss bars:** `ENCOUNTER_TIMELINE_EVENT_ADDED/REMOVED/HIGHLIGHT`, resync from `C_EncounterTimeline.GetSortedEventList` on enable and on setting changes. Names, icons and times that may be secret go straight to widgets; danger colour from the game (`GetEventColor`) or the plain severity; rough timings marked `~`; highlight glows. Soft conflict `core.coexist.pulse.timeline` with BigWigs and DBM-Core.
- **Countdown bar:** from Kernel `COUNTDOWN` (Raid Tools), optional sound.
- **Combat timer:** display of the shared clock (off by default), any fight or boss only, hold after the fight, clock or tenths, fight name, text size; history ring of recent fights (`/pui pulse history`).
- Studio elements `pulse.bars`, `pulse.timer`. Live preview draws the real bar group with sample data.

Deferred: next-three HUD, private-aura sounds, per-boss options, BigWigs bar-style bridge, hiding Blizzard's timeline view.
