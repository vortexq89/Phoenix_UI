# 05 · BigWigs + LittleWigs and plugins

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\BigWigs*` (core, Options, Plugins and 15 expansion packs), `I:\LittleWigs*` (11). Licence: **All Rights Reserved**, so only facts are used: EJ IDs, spell IDs and the option flags, read by tools/sync/boss_data.py. No code is copied.

## Plugin parity
| BigWigs plugin | Phoenix Encounters (79 rows) | Status |
|---|---|---|
| Bars, BarStyles | Phoenix bars (width, height, texture, colour, emphasis, spark, direction) + "Phoenix bar style for BigWigs" | have |
| Timeline (Midnight) | Boss timeline | have |
| Messages | Phoenix banner, least important shown | have |
| Countdown | Countdown voice (start at, pull, M+/arena/BG starts, emphasised abilities) | have |
| Sound | Warning sounds critical/medium/minor | partial (no per-ability sound) |
| Pull, Break | Pull timer, Break timer, share | have |
| Flash | Flash on critical | have |
| BossBlock (hide talking head, movies, …) | — | **missing** |
| AutoReply (whisper "in combat with X") | — | **missing** |
| Victory, Wipe sounds and messages | — | **missing** |
| Statistics (kills, wipes, best time) | — | **missing** |
| BattleRes counter | — | **missing** |
| InfoBox, AltPower | — | missing (low; mostly secret values in Midnight) |
| Proximity | — | out of scope (removed by Blizzard in Midnight) |
| RaidIcon (auto-mark) | — | missing (low) |
| Nameplates (icons on nameplates) | — | missing |
| Auras | — | missing (low) |
| Colors per bar type | Bar colour, emphasis colour | partial |
| Per-boss options | Boss modules (expansion › instance › boss › ability › "On the bars") | have |

## Daily GitHub tracking loop
- `tools/sync/boss_data.py` rebuilds `Phoenix_UI_Encounters/Data.lua` from shallow clones of BigWigsMods/BigWigs, LittleWigs and BigWigs_<Expansion>. The docstring says "The daily sync reruns this".
- **Gap:** it only carries the EJ ID and spell IDs plus role and emphasis flags. It does **not** report new plugin features or fixes, and the expansion list is fixed at clone time. New packs (MidnightLairs, Sporefall, TheDreamrift, TheVenomousAbyss, TheVoidspire, TheUnbindingOfKithix and MarchOnQuelDanas are all in I:\) must be added to the clone list.
- **Proposed:** the loop also diffs `BigWigs_Plugins/*.lua` option keys and the CHANGELOG and opens a PLUGIN_AUDIT note. That is reporting only; nothing is copied.

## Bug found (screenshot)
- Encounters › BigWigs says "BigWigs is not loaded" while it is installed: BigWigs core is **load on demand**. Use `C_AddOns.GetAddOnEnableState` plus `IsAddOnLoadOnDemand`, and say "installed — loads in instances". This is a crash-free fix in a kept module, so it is allowed under t225. The tab is also thin and needs the plugin rows above.

## Overlaps
- When BigWigs is enabled, Phoenix bars and BigWigs bars both draw. "Boss warnings and timeline" needs a clear owner choice: **Phoenix draws, BigWigs supplies the data** (default) or **BigWigs draws** (Phoenix only restyles). That is one switch, not two toggles.

## Improvements (spec 008)
BossBlock, AutoReply, Victory/Wipe, Statistics, BattleRes and a per-ability sound column in Boss modules.
