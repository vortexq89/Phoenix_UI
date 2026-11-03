# 10 · sArena Reloaded

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\sArena_Reloaded` (Modules: DR, Trinkets, Racials, Dispels, Interrupt, Absorbs(_Midnight), Auras(_Midnight), AuraHighlight, CooldownFrame, Dampening, ModernCastbar, PetFrames, RangeCheck, SpecFinder, TestMode, ImportExport, ConflictCheck; Layouts: BlizzArena, BlizzCompact, BlizzRaid, BlizzRetail, BlizzTarget, BlizzTourney, Gladiuish, Pixelated, Xaryu). Licence: none found in the TOC, so behaviour only.

| Feature | Phoenix UnitFrames › Arena + PvP | Status |
|---|---|---|
| Arena frames (Phoenix-styled) | UnitFrames › Arena layout | have |
| DR tray | takes the game's tray and follows its CVar | have (Midnight-safe) |
| Trinkets | from the game frames | have |
| Racials | — | **missing** |
| Dispel cooldowns | — | **missing** |
| Interrupt cooldowns | — | missing |
| Spec icon | yes | have |
| Cast bar | yes | have |
| Pet frames | — | missing |
| Dampening | — | missing (PvP page) |
| Range fade | — | check |
| Test mode | preview | partial |
| Layout presets (9) | one layout | partial (offer 3: Phoenix, Compact, Gladius-style) |
| Import/export | profiles | have |

## Overlap
- **PvP › Arena frames** and **UnitFrames › Arena** are two places for one feature. Move it to UnitFrames › Arena and leave a link row in PvP.

Plan (spec 011): racials, dispel and interrupt cooldowns where the API is not secret, pet frames, dampening, layout presets and a real test mode; editable like the other unit frames.
