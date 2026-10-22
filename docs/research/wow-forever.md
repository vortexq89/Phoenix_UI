# World of Warcraft: Forever (verified 2026-10-22)

- Blizzard's permanent level 1–60 Azeroth game; **launch 4 Nov 2026**, beta since 17 Sep 2026
  (news.blizzard.com "World of Warcraft: Forever What's Next Panel Recap").
- TOC interface **16001** (1.60.1); game type `camelot`, alias `forever` (TOC suffix `_Forever.toc`/`_Camelot.toc`,
  `## AllowLoadGameType: forever`), `WOW_PROJECT_CAMELOT` = 18 (warcraft.wiki.gg Patch_1.60.1/API_changes).
- **"WoW Forever shares Mainline WoW's UI architecture, including the vast majority of APIs available in 12.1.5…
  secrets will also be active in Forever"** (Blizzard, quoted on the same wiki page). wago.tools product `wowf`
  = 1.60.1.70532.
- BigWigs (`Init_Camelot.lua`, `isForever`), Questie (`Questie_Camelot.toc`), QuestieDB, EllesmereUI (16001 in TOC
  + Forever Essentials) and NaowhForever already ship for it.

## Consequence for Phoenix
Forever is the cheapest second flavour by far: same Lua API family and the same secret rules as Phoenix's target.
Work = a TOC line, a `ns.flavor` flag, gating retail-only modules (Mythic+, Great Vault, Cooldown Manager
viewers, Delves) and Forever-only additions (classic talents/spellbook skins, threat, flight timers). Classic
Era/TBC/Mists Classic are a different client family (older APIs, no secrets) and cost far more.
