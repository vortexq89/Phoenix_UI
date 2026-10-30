# Phoenix Damage Meter (t158)

Status: built on `restore/v1-ui`. Owner ask (t158u): the same method as EllesmereUI's damage meter, written in
Phoenix's own code, presented, designed and organised better.

## 1. Method (what EllesmereUI does, and what Phoenix does the same way)

The data source is the one every Midnight meter must use: Blizzard's own `C_DamageMeter` API (12.x, also present on
WoW Forever 1.60). Neither addon reads the combat log (forbidden in 12.x).

| Step | API | Notes |
|---|---|---|
| Rows of one window | `C_DamageMeter.GetCombatSessionFromType(sessionType, meterType)` or `...FromID(sessionID, meterType)` | `combatSources` arrive sorted, highest first; `maxAmount` is the top row |
| Segments list | `C_DamageMeter.GetAvailableCombatSessions()` | `{ sessionID, name, durationSeconds }`, never secret |
| Spell breakdown | `C_DamageMeter.GetCombatSessionSourceFromID/FromType(..., sourceGUID, sourceCreatureID)` | arguments may only be secret for untainted callers, so addon code opens a breakdown only with a plain GUID (out of combat) |
| Fight clock | `C_DamageMeter.GetSessionDurationSeconds(sessionType)` | not secret; still gated by `issecretvalue` |
| Reset | `C_DamageMeter.ResetAllCombatSessions()` | |
| Updates | `DAMAGE_METER_COMBAT_SESSION_UPDATED`, `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `DAMAGE_METER_RESET` | |
| Blizzard window off | CVar `damageMeterEnabled` = 0 (through `ns.Combat:Run`, never in combat) | the API keeps recording |

Secret values (in combat, amounts, rates and other players' names are secret):

* Bars: `SetMinMaxValues(0, session.maxAmount)` and `SetValue(source.totalAmount)` - secrets go straight to the
  StatusBar sink. No percent of total is computed (that would be arithmetic on a secret).
* Text: `AbbreviateNumbers(secret)` and `FontString:SetFormattedText("%s (%s)", ...)` - display sinks only.
* Never-secret fields (`classFilename`, `specIconID`, `isLocalPlayer`) drive the class colour, spec icon and the
  "you" highlight; everything else is only displayed.
* No sorting, comparing or storing of a secret value anywhere.

Refresh: events mark windows dirty and one `C_Timer.After(rate)` repaints them (coalesced; no `OnUpdate`,
nothing runs while idle). The clock repaints from a 1 s `C_Timer.NewTicker` that exists only in combat.

## 2. What Phoenix adds over EllesmereUI (presentation and organisation)

* One header line per window: accent mode chip (click: mode menu), segment chip (click: segment menu), the fight
  clock, and Reset - every control one click, no hidden cog.
* Modes grouped in the menu as Damage / Healing / Utility / Taken, each with its short name in the chip
  ("DPS", "HPS", "Taken").
* Rows: rank, spec icon, class-coloured bar on a dark track, your own row outlined in the accent colour, value in
  the number font right-aligned, a subtle top sheen; same Phoenix Font and theme tokens as every Phoenix frame.
* Click a row: that player's spells in the same window (header shows "< name"), click the header to go back.
  Hover: tooltip with the player's top spells when the data is readable.
* Up to three windows, each its own mode and segment, each a Layout-mode mover; empty windows show a quiet
  "No data yet" line instead of a blank box.
* Out-of-combat fade, and visibility always / in combat / in a group.
* Every setting is live (no /reload); the plugin itself toggles live; "Blizzard" engine keeps the old Phoenix skin
  of Blizzard's own meter for players who prefer it.

## 3. Settings (v4 Flow page "Damage Meter")

Engine (Phoenix windows / Blizzard's skinned), Windows (count, width, rows, row height, spacing), Rows (class colour,
spec icon, rank, value format: total / per second / both), Behaviour (visibility, out-of-combat alpha, refresh
rate), per-window mode and segment, Threat (Forever), Blizzard skin, Details!.

## 4. Files

`Modules/DamageMeter/Meter.lua` (engine and windows), `Modules/DamageMeter/DamageMeter.lua` (module, Blizzard skin),
`Phoenix_UI_Options/Options/DamageMeter.lua` (page), harness test "phoenix damage meter".
