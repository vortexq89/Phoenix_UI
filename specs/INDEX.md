# Spec index

Every spec, its status and the build order (owner t229, constitution 1.2.0 Principle VII). Status: **Done** = built
and shipped; **Partial** = built, checklist not yet passed; **Draft** = spec, plan, tasks and checklist written, nothing built.

## Finished area specs (before t229)

| Spec | Status |
|---|---|
| 001-settings-window | Done |
| 002-global-pages | Done |
| 003-gui-polish | Done |
| 004-eui-parity-plus | Done except T008 data bar fit (waits for a screenshot); its open items move to the per-feature specs below |
| 005-layout-model | Done (Layout-only Phoenix frames, frame list, layout profiles, MoveAny windows, drag code in Layout) |

## Per-plugin and per-feature specs

| Spec | Title | Parent | Audit rows | Gaps | Status |
|---|---|---|---|---|---|
| [006-bugsack](006-bugsack/spec.md) | Bugs: BugSack parity | — | 15 | 7 | Built (3 Nov), in-game check pending |
| [007-simulationcraft](007-simulationcraft/spec.md) | Sim: SimulationCraft parity | — | 9 | 1 | Draft |
| [008-moveany](008-moveany/spec.md) | Layout: MoveAny parity | — | 6 | 2 | Draft |
| [009-bigwigs](009-bigwigs/spec.md) | Encounters: BigWigs and LittleWigs parity | — | 19 | 11 | Draft |
| [010-autoqueue](010-autoqueue/spec.md) | Group finder: AutoQueue parity | — | 5 | 5 | Draft |
| [011-premade-groups-filter](011-premade-groups-filter/spec.md) | Group finder: Premade Groups Filter parity | — | 12 | 5 | Draft |
| [012-msbt](012-msbt/spec.md) | Combat Text: MikScrollingBattleText parity | — | 11 | 5 | Draft |
| [013-trufigcd](013-trufigcd/spec.md) | Spell History: TrufiGCD parity | — | 9 | 4 | Draft |
| [014-sarena](014-sarena/spec.md) | Arena: sArena Reloaded parity | — | 14 | 7 | Draft |
| [015-auctionator](015-auctionator/spec.md) | Auction house: Auctionator parity | — | 9 | 7 | Draft |
| [016-idtip](016-idtip/spec.md) | Tooltip IDs: idTip parity | — | 7 | 6 | Draft |
| [017-questie](017-questie/spec.md) | Quests: Questie parity | — | 13 | 3 | Draft |
| [018-rarescanner](018-rarescanner/spec.md) | Rares: RareScanner parity | — | 8 | 7 | Draft |
| [019-ellesmereui](019-ellesmereui/spec.md) | EllesmereUI: every module, better (umbrella) | — | 22 | 0 | Draft |
| [020-eui-options-window](020-eui-options-window/spec.md) | Options window (rail, header tabs, footer) | 019-ellesmereui | 1 | 0 | Draft |
| [021-uf-player](021-uf-player/spec.md) | Unit Frames: player | 019-ellesmereui | 1 | 1 | Built (3 Nov), in-game check pending |
| [022-uf-target](022-uf-target/spec.md) | Unit Frames: target | 019-ellesmereui | 1 | 1 | Draft |
| [023-uf-target-of-target](023-uf-target-of-target/spec.md) | Unit Frames: target of target | 019-ellesmereui | 1 | 1 | Draft |
| [024-uf-focus](024-uf-focus/spec.md) | Unit Frames: focus | 019-ellesmereui | 1 | 1 | Draft |
| [025-uf-focus-target](025-uf-focus-target/spec.md) | Unit Frames: focus target | 019-ellesmereui | 1 | 1 | Draft |
| [026-uf-pet](026-uf-pet/spec.md) | Unit Frames: pet | 019-ellesmereui | 1 | 1 | Draft |
| [027-uf-party](027-uf-party/spec.md) | Unit Frames: party | 019-ellesmereui | 1 | 1 | Draft |
| [028-uf-boss](028-uf-boss/spec.md) | Unit Frames: boss | 019-ellesmereui | 1 | 1 | Draft |
| [029-uf-arena](029-uf-arena/spec.md) | Unit Frames: arena | 019-ellesmereui | 1 | 1 | Draft |
| [030-eui-raidframes](030-eui-raidframes/spec.md) | RaidFrames | 019-ellesmereui | 1 | 1 | Draft |
| [031-eui-nameplates](031-eui-nameplates/spec.md) | Nameplates | 019-ellesmereui | 1 | 0 | Draft |
| [032-eui-actionbars](032-eui-actionbars/spec.md) | ActionBars (+XP/rep bars) | 019-ellesmereui | 1 | 0 | Draft |
| [033-eui-cooldownmanager](033-eui-cooldownmanager/spec.md) | CooldownManager | 019-ellesmereui | 1 | 0 | Draft |
| [034-eui-resourcebars](034-eui-resourcebars/spec.md) | ResourceBars | 019-ellesmereui | 1 | 1 | Draft |
| [035-eui-aurabuffreminders](035-eui-aurabuffreminders/spec.md) | AuraBuffReminders | 019-ellesmereui | 1 | 0 | Draft |
| [036-eui-bags](036-eui-bags/spec.md) | Bags | 019-ellesmereui | 1 | 0 | Draft |
| [037-eui-chat](037-eui-chat/spec.md) | Chat | 019-ellesmereui | 1 | 0 | Draft |
| [038-eui-damagemeters](038-eui-damagemeters/spec.md) | DamageMeters | 019-ellesmereui | 1 | 0 | Draft |
| [039-eui-databars](039-eui-databars/spec.md) | DataBars | 019-ellesmereui | 1 | 1 | Draft |
| [040-eui-friends](040-eui-friends/spec.md) | Friends | 019-ellesmereui | 1 | 1 | Draft |
| [041-eui-groupfinder](041-eui-groupfinder/spec.md) | GroupFinder | 019-ellesmereui | 1 | 0 | Draft |
| [042-eui-minimap](042-eui-minimap/spec.md) | Minimap | 019-ellesmereui | 1 | 0 | Draft |
| [043-eui-mythictimer](043-eui-mythictimer/spec.md) | MythicTimer | 019-ellesmereui | 1 | 0 | Draft |
| [044-eui-qol](044-eui-qol/spec.md) | QoL | 019-ellesmereui | 1 | 1 | Draft |
| [045-eui-questtracker](045-eui-questtracker/spec.md) | QuestTracker | 019-ellesmereui | 1 | 0 | Draft |
| [046-eui-blizzardskin](046-eui-blizzardskin/spec.md) | BlizzardSkin | 019-ellesmereui | 1 | 1 | Draft |
| [047-eui-quickdraw](047-eui-quickdraw/spec.md) | Quickdraw (macro/keybind helper) | 019-ellesmereui | 1 | 1 | built (ee1d11b0, Quickdraw drop-to-macro and bind; checklist pending) |
| [048-eui-foreveressentials](048-eui-foreveressentials/spec.md) | ForeverEssentials | 019-ellesmereui | 1 | 1 | Draft |
| [049-eui-windtools](049-eui-windtools/spec.md) | WindTools (326 files) | 019-ellesmereui | 1 | 1 | Draft |

## Build order

Bugs first (owner request), then the unit frames one by one (the previews were the visible break), then the
plugins by how much is missing and how often it is used, then the remaining EllesmereUI modules by gap count.

1. 006-bugsack (7 gap(s))
2. 021-uf-player (1 gap(s))
3. 022-uf-target (1 gap(s))
4. 023-uf-target-of-target (1 gap(s))
5. 024-uf-focus (1 gap(s))
6. 025-uf-focus-target (1 gap(s))
7. 026-uf-pet (1 gap(s))
8. 027-uf-party (1 gap(s))
9. 028-uf-boss (1 gap(s))
10. 029-uf-arena (1 gap(s))
11. 008-moveany (2 gap(s))
12. 014-sarena (7 gap(s))
13. 009-bigwigs (11 gap(s))
14. 013-trufigcd (4 gap(s))
15. 010-autoqueue (5 gap(s))
16. 011-premade-groups-filter (5 gap(s))
17. 012-msbt (5 gap(s))
18. 016-idtip (6 gap(s))
19. 017-questie (3 gap(s))
20. 018-rarescanner (7 gap(s))
21. 015-auctionator (7 gap(s))
22. 007-simulationcraft (1 gap(s))
23. 030-eui-raidframes (1 gap(s))
24. 034-eui-resourcebars (1 gap(s))
25. 039-eui-databars (1 gap(s))
26. 040-eui-friends (1 gap(s))
27. 044-eui-qol (1 gap(s))
28. 046-eui-blizzardskin (1 gap(s))
29. 047-eui-quickdraw (1 gap(s))
30. 048-eui-foreveressentials (1 gap(s))
31. 049-eui-windtools (1 gap(s))
32. 020-eui-options-window (0 gap(s))
33. 031-eui-nameplates (0 gap(s))
34. 032-eui-actionbars (0 gap(s))
35. 033-eui-cooldownmanager (0 gap(s))
36. 035-eui-aurabuffreminders (0 gap(s))
37. 036-eui-bags (0 gap(s))
38. 037-eui-chat (0 gap(s))
39. 038-eui-damagemeters (0 gap(s))
40. 041-eui-groupfinder (0 gap(s))
41. 042-eui-minimap (0 gap(s))
42. 043-eui-mythictimer (0 gap(s))
43. 045-eui-questtracker (0 gap(s))

019-ellesmereui is the umbrella: it closes when its module specs do.
