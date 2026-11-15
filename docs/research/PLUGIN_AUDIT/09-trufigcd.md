# 09 · TrufiGCD

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\TrufiGCD` (Modules/Core, Frames, Settings; Masque). Licence: none found, so behaviour only.

| Feature | TrufiGCD | Phoenix SpellHistory (12 rows) | Status |
|---|---|---|---|
| Player cast icon queue | yes | yes | have |
| **Party, arena and target units** (one queue per unit) | yes | — | **missing** |
| Icon size, count, direction, spacing | yes | yes | have |
| Fade time, only in combat | yes | yes | have |
| Interrupted or failed mark | yes | yes | have |
| Spell blocklist | yes | — | **missing** |
| Tooltip on hover | yes | — | missing |
| Masque | yes | — (Phoenix style) | n/a |
| Moved in Layout | own drag | own "Move" row | partial (should be in Layout, see 04) |

Plan (spec 010): unit queues (player, party1–4, arena1–3, target, focus), a blocklist, tooltips, and Layout entries for each queue.
