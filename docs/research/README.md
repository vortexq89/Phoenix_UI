# Research notes (expansion study, 2026-10-22)

One file per source. Each covers: what it offers, how it structures data/features/UX, its licence and what that
means for Phoenix (MIT), the game facts it relies on and where Phoenix gets the same facts from Blizzard client data,
and "how Phoenix does it better". Rule for all of them: **learn and extract facts, never copy code or assets**
unless the licence clearly allows it in an MIT repo (only simc-addon, Unlicense, qualifies).

| File | Source | Licence | Reuse in Phoenix (MIT) |
|---|---|---|---|
| [bigwigs.md](bigwigs.md) | BigWigs, LittleWigs, BigWigs_Classic, BigWigs_Voice, LibDBIcon | none published (all rights reserved) | Clean-room only. Bridge via their public API |
| [simulationcraft.md](simulationcraft.md) | simc engine + wiki, simc-addon, Raidbots | engine GPL-3.0; addon Unlicense | Run simc.exe as a separate program; addon export logic may be reused |
| [questie.md](questie.md) | Questie, QuestieDB, QuestieTrace, Questie/WoW-API | "all rights reserved, GPLv3 in progress" | Clean-room; optional runtime use of QuestieDB's public API if the user installs it |
| [premade-groups-filter.md](premade-groups-filter.md) | 0xbs/premade-groups-filter | GPL-2.0-or-later | Clean-room (or relicense Phoenix to GPL) |
| [windtools.md](windtools.md) | EllesmereUI_WindTools (local), ElvUI_WindTools | restricted (GPLv3 only inside ElvUI/NDui) | Clean-room only |
| [ellesmereui.md](ellesmereui.md) | EllesmereUI suite, LibGetFrame | custom all rights reserved; LibGetFrame GPL-2.0 | Clean-room only |
| [naowhforever.md](naowhforever.md) | NaowhForever | all rights reserved | Clean-room only |
| [wow-forever.md](wow-forever.md) | Blizzard "World of Warcraft: Forever" (interface 16001) | n/a | Platform facts |
| [game-data.md](game-data.md) | wago.tools DB2 (all flavours) | Blizzard client data | Primary fact source for every generated table |

## Added on 2026-10-28

- [addons/](addons/README.md): one file per addon in the game folder and on the I:\ drive (86 folders, 45 files),
  each with features, design, code approach (our own words), benefit and a comparison with Phoenix. Written
  during the v2 work, so its Phoenix comparisons name v2 files; [../ROADMAP.md](../ROADMAP.md) maps each finding
  to this code base's modules.
- [RECOVERY_REPORT.md](RECOVERY_REPORT.md): why the v2 rework was set aside and this design restored.
