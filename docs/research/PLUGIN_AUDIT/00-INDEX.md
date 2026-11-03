# Plugin audit — index (t226/t227)

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

The goal (constitution v1.1.0): **better than EllesmereUI**, meaning higher quality, more advanced, more user friendly and simpler, with every feature of the 14 sources below present in full, in the Phoenix style.

| # | Plugin | Doc | have / partial / missing (approx.) | Main gap |
|---|---|---|---|---|
| 1 | EllesmereUI (+20 modules) | [01](01-ellesmereui.md) | 9 / 11 / 2 | live previews, buff reminders, Quickdraw |
| 2 | BugGrabber + BugSack | [02](02-bugsack.md) | 9 / 2 / 5 | send in game, auto popup, .txt |
| 3 | SimulationCraft | [03](03-simulationcraft.md) | 8 / 1 / 0 | one-click all-equipped, gear grid |
| 4 | MoveAny | [04](04-moveany.md) | 4 / 2 / 0 | one layout model, full window list |
| 5 | BigWigs + LittleWigs | [05](05-bigwigs-littlewigs.md) | 9 / 2 / 9 | BossBlock, AutoReply, stats, LoD bug |
| 6 | AutoQueue | [06](06-autoqueue.md) | 0 / 2 / 3 | role from spec |
| 7 | Premade Groups Filter | [07](07-premade-groups-filter.md) | 7 / 1 / 4 | Delve panel, dungeon grid, note |
| 8 | MikScrollingBattleText | [08](08-mikscrollingbattletext.md) | 7 / 4 / 1 | crit bug, cooldown notices |
| 9 | TrufiGCD | [09](09-trufigcd.md) | 4 / 1 / 3 | party/arena queues |
| 10 | sArena Reloaded | [10](10-sarena-reloaded.md) | 6 / 2 / 5 | racials, dispels, pets |
| 11 | Auctionator | [11](11-auctionator.md) | 2 / 1 / 6 | everything but the skin |
| 12 | idTip | [12](12-idtip.md) | 1 / 0 / 6 | icon, bonus, talent IDs |
| 13 | Questie | [13](13-questie.md) | 10 / 2 / 1 | objective areas |
| 14 | RareScanner | [14](14-rarescanner.md) | 1 / 2 / 5 | secure target button, kill state |
| — | GUI screenshots | [15](15-gui-screenshots.md) | 22 issues | — |

## 1. Overlap and conflict map
| Area | Places today | One home (proposal) |
|---|---|---|
| Moving frames | Edit Mode · Movers · Skins › Move windows · per-module "Move" rows (SpellHistory, CDM, CombatText) | §2 model |
| Window scale vs UI scale | Movers › Window scale · options window 85 % · General scale | Movers/Layout for Blizzard windows; the options window has its own scale |
| Arena frames | UnitFrames › Arena · PvP › Arena frames | UnitFrames › Arena |
| Rares | Automation › Rare alert · Quests › Rare pins | Quests › Rares |
| Auction house | Skins · Bags · Automation | new Auction module |
| Friends | Skins › friends window · DataTexts | Social page (spec 004) |
| QoL | Automation (102 rows) · QoL | Automation = actions; QoL = interface tweaks; nothing in both |
| CDM naming | folder `Phoenix_UI_Tracker` vs the objective "tracker" under Quests | rename the label to "Cooldown Manager" everywhere (the folder stays, to keep saved data) |
| Boss bars | Phoenix bars + BigWigs bars together | one owner switch |
| Bug viewer | Phoenix Bugs + BugSack | Phoenix is the viewer when both are present |
| Tooltip IDs | Phoenix IDs + idTip | hide ours when idTip is present |
| Combat text | Phoenix CombatText + MSBT + Blizzard CVars | one switch writes the CVars |

## 2. The one layout model
1. **Blizzard Edit Mode** owns the frames it manages. Phoenix never moves those; when Phoenix *replaces* one, the Blizzard copy is hidden and the Phoenix copy is in Layout.
2. **Phoenix Layout** (Movers renamed) is the only Phoenix unlock mode. It covers every Phoenix frame and every Blizzard window or HUD element that Edit Mode does not manage, and handles move, scale, alpha, hide and reset. Skins' window drag merges into it.
3. Every "Move" row anywhere opens Layout on that frame. The two modes are exclusive, with a button between them.

## 3. Priority order (specs)
| Spec | Area | Why first |
|---|---|---|
| 003 | GUI polish: the 22 screenshot issues (15) plus RELOAD badges | visible on every page; small, safe |
| 004 | EllesmereUI parity+: live previews, buff reminders, CDM naming, Friends/Social, data bar | the core promise |
| 005 | One layout model (04) | removes the biggest confusion |
| 006 | Bugs (02) | small, high value |
| 007 | Sim (03) | small |
| 008 | Encounters (05) incl. LoD fix and sync-loop widening | raid season |
| 009 | Group finder + AutoQueue (06, 07) | — |
| 010 | Combat text + spell history (08, 09) | — |
| 011 | Arena (10) | — |
| 012 | Auction (11) | biggest new module |
| 013 | Tooltip IDs (12) | small |
| 014 | Quests (13) | Forever |
| 015 | Rares (14) | — |

Each spec follows Spec Kit (spec → plan → tasks) and the per-commit gates. No implementation starts before its spec is written.
