# 14 · RareScanner

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `D:\…\RareScanner` (171 Lua files; Core: Service, SpecialEvents, Plugins; Tables; Guide). Licence: **All Rights Reserved**, so behaviour only and no data tables.

| Feature | Phoenix | Status |
|---|---|---|
| Rare alert on vignette (sound, flash) | Automation › Rare alert | have |
| Alert button with model and a **secure target click** | — | **missing** |
| Map pins for rares, events and treasures | Quests › Rare pins | partial (rares only) |
| Killed / looted state per character | — | **missing** |
| Loot preview (mounts, pets, toys) on the alert | — | missing |
| Filters (per zone, per rare, collected loot only) | — | missing |
| Waypoint on alert | waypoint arrow exists | partial (not wired to the alert) |
| Navigation between rares on the alert | — | missing |

Overlap: the rare features sit in **two** modules (Automation and Quests). Plan (spec 015): one "Rares" page in Quests (alert, button, pins, filters, kill state), and the Automation row moves there.
