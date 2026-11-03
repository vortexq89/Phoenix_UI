# I:\ addon inventory (research notes)

Source: the user's drive `I:\` on the PC (machine 46671855…), copied read-only to the box as `/workspace/i_drive/` (zip of 31 MB) on 2026-10-22. Nothing was changed on I:\.
Option counts come from `../data/extract_eui.py` (EllesmereUI-style widget tables, 2,420 controls), a WindTools option-table parse (361), AceConfig parse for sArena (416) and `AddCheckBox` counts for MoveAny (~150).

| Addon (folder) | Version | Purpose | Upstream licence | Lua files / lines | Options | Ships data |
|---|---|---|---|---|---|---|
| EllesmereUI (+22 module folders) | 9.6.1 | Full UI suite: own action bars, unit/raid frames, nameplates, CDM, resource bars, skins, QoL | **All rights reserved** (Ellesmere) — study only | 75 core + ~520 module files, ~0.66 M lines incl. options (157 k) and locales (71 k) | 2,420 controls | Spell lists (CDM, buff reminders, interrupts), M+ dungeon data, Forever map travel pins + flight times generated from DB2 (TaxiNodes, AreaPOI, UiMapAssignment) |
| EllesmereUI_WindTools | 0.2.8 | Port of WindTools (ElvUI plugin) onto EllesmereUI; most modules disconnected | WindTools licence: free use **only with ElvUI/NDui**, no redistribution in other UIs — study only | 337 / 115 k | 361 | Keystone/affix data, prey hunt quests, emote lists |
| MoveAny | 1.13.22 | Unlock/move/scale ~all Blizzard frames | GitHub GPL-3.0; CurseForge page says All Rights Reserved — treat as study only | 72 / 36 k | ~150 checkboxes (one per frame) | Frame name lists |
| PremadeGroupsFilter | 7.6.5 | Group finder filter UI + expression language | **GPL-2.0** (Bernhard Saumweber) — ideas only, no code into MIT Phoenix | 53 / 9 k | ~40 UI + 105 expression variables | Activity / dungeon / boss tables |
| sArena_Reloaded (Stako, "reloaded" by Bodify) | 2.6.7 | Arena enemy frames (9 layouts), DR, trinkets, racials | Custom: MIT for original sArena code, ARR for "Reloaded" additions — study only | 116 (incl. Ace3) / 64 k | 416 AceConfig | DR lists, interrupt lists, dispel lists, trinket/racial IDs (spell IDs are game facts) |
| Simulationcraft | 12.1.5-02 | `/simc` export string | **Unlicense** (public domain) — reusable | 14 / 7 k | 4 | Slot/stat tables |
| idTip | 12.1.4 | IDs in tooltips (27 kinds) | **BSD-2-Clause** (silverwind) — reusable with notice | 1 / 640 | 1 | — |
| AutoQueue (+AutoSignLFG) | 1.5.4 | Auto-accept role checks; auto sign-up | No licence file → ARR by default — study only | 17 / 2.5 k | ~10 | — |
| BigWigs (+Core, Plugins, Options, 19 content modules) | 12.1 | Boss mod: bars, messages, sounds, nameplate icons, 581 boss modules | All rights reserved (fork on GitHub allowed) — study only | see PARITY.md | 1,269 incl. per-boss | Journal / encounter / NPC / spell IDs per boss |
| LittleWigs (+11 legacy modules) | 12.1 | Dungeon / delve boss mod (758 modules) | All rights reserved — study only | see PARITY.md | per-boss | Same as BigWigs |
| !BugGrabber + BugSack | — | Error capture and viewer | All rights reserved — study only | — | 11 | — |
| TrufiGCD | — | Ability history for player / party / arena | **MIT** — reusable with notice (nothing copied) | — | 44 | Spell blocklist |
| Auctionator | — | Auction House: scans, shopping lists, selling, cancelling, price tooltips | All rights reserved — study only | — | 110 | — |
| Questie, QuestieDB, QuestieTrace | — | Classic quest helper, its database (incl. a WoW Forever NPC table), session recorder | **GPL-3.0** — not used (GPL; Classic-era data) | — | 220 + DB | Quest / NPC / object / item DB |
| WoW-API-main | — | API reference | facts only | — | — | API signatures |

## Attribution warning (important)
Every copy on I:\ has been edited to insert **"VortexQ8"** into author/licence lines, e.g. `## Author:  VortexQ8  Ellesmere`, `## Title: MoveAny by VortexQ8`, PGF README "licens by VortexQ8e … GNU General Public licens by VortexQ8e, Version 2", LibRealmInfo `## X-licens by VortexQ8e: Zlib`, AceConsole header `--- by VortexQ8`. Hits: PGF 56 files, sArena 40, EllesmereUI 17, MoveAny 7, Simulationcraft 5, WindTools 4, one in each EUI module, idTip, AutoQueue. No LICENSE files are present in the copies.
These edits do not change who owns the code: the upstream authors and their licences still apply. Phoenix must not ship any file or code from these copies; we use them only to learn features and option depth (as already done for /workspace/addons_study). If the user is VortexQ8 and these are personal edits, that is fine for private use, but republishing them would breach the ARR/GPL terms.

## Notes per addon
- [EllesmereUI.md](EllesmereUI.md) — core + every module, option pages and counts
- [WindTools.md](WindTools.md) · [MoveAny.md](MoveAny.md) · [PremadeGroupsFilter.md](PremadeGroupsFilter.md) · [sArena.md](sArena.md) · [Simulationcraft.md](Simulationcraft.md) · [idTip.md](idTip.md) · [AutoQueue.md](AutoQueue.md)
- [NPC_DATA.md](NPC_DATA.md) — spawn-location sources, licences, verdict
- [../PARITY.md](../PARITY.md) — full feature-parity audit of every addon on I:\ (22 Oct 2026): 315 features, one Phoenix owner each, status, stage; encounter module coverage; built by `../data/parity_build.py` (the raw option dump stays on the box, outside the repo)
