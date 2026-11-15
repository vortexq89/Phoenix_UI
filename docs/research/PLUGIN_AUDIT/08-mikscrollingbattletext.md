# 08 · MikScrollingBattleText

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\MikScrollingBattleText` (53 Lua files; Display, Parser, Triggers, Cooldowns, Profiles, Options). Licence: **MIT** (SPDX in the TOC), so code may be adapted with credit and its fonts can be bundled if their own licences allow (check each font file's licence before bundling).

| Feature | Phoenix CombatText (76 rows) | Status |
|---|---|---|
| Scroll areas (add, remove, name, position, size) | yes | have |
| Animations and direction, alignment, time on screen | yes | have |
| Incoming, outgoing, notifications, power gains | yes | have |
| Merge rapid hits, throttle | yes | have |
| Crits (size, area, sound) | yes, but **greyed out, 0 %, blank sound** in the screenshot | partial (bug) |
| Triggers (custom) and import from MSBT | yes | have |
| Cooldown notifications (spell ready) | — | **missing** |
| Loot and money, honour, reputation notices | partial | partial |
| Per-event colour, font and sound | area colour plus one sound | partial |
| MSBT fonts | Combat font list | partial (add the MSBT fonts when their licences allow) |
| Spell icon, skill name | yes | have |

## Overlaps
- "Hide the game's own text" vs the Blizzard CVars `floatingCombatText*`: one toggle that writes the CVar, shown once.
- The combat-text areas show in **Movers** as huge boxes (04).

Plan (spec 010): fix crit defaults (an enabled area, a 150 % default and a default sound), cooldown notices, per-event overrides, fonts.
