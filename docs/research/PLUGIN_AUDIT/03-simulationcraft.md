# 03 · SimulationCraft (simc addon)

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\Simulationcraft`. Licence: **Unlicense**, so adapting code is allowed with credit, though Phoenix already has its own exporter.

## Parity
| Feature | simc addon | Phoenix Sim (15 rows) | Status |
|---|---|---|---|
| Export of the equipped profile string | yes | Export.lua (simc format) | have |
| Bag items in the export | yes | Pick gear | have |
| Bank and Great Vault | flag | Include bank / Include Great Vault | have |
| Copy box | yes | yes | have |
| Auto-select **all equipped gear** and copy in one click | manual | Pick gear (manual list) | partial |
| Run a sim and show results | — | through the Phoenix app (Bridge) | have (unique) |
| Fight style, targets, length | — | yes | have |
| Results history | — | Last 10 sims | have |
| Results in tooltips | — | Tooltip › Sim results | have |

## Research: "instant" sim
- Raidbots has **no public API** (its ToS forbids automated submission). The SimulationCraft CLI is GPL-3 and can be run locally by the Phoenix app. That is the only legal "instant" path, and results come back through the app and the SavedVariables bridge after a reload.
- In game: one button, "Sim my gear", auto-selects every equipped slot and copies the string, and the app picks it up on the next reload or logout.

## Screenshot issues
- The gear list shows "1-10 of 23 (scroll)", the slot icons are cramped, the help text is clipped and tooltips cover row text (15 › P5).

## Improvements (spec 007)
1. The default selection is every equipped item, and a "Copy string" button sits in the page header.
2. The gear list is a 2-column grid of 46 px slots with a scrollbar, without the "(scroll)" text.
3. A results card per spec and gear set, comparing DPS with the last run.
