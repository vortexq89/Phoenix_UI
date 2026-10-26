# Minimap, Tooltip, Data Bars (PUI_V2 5.9) - Phase 4 core

- Minimap: `mm.shape` (square/circle mask), `mm.size` (combat-deferred, restored on disable), `mm.hideCluster` (alpha only), `mm.clock`, `mm.zone`, `mm.coords` (ticker `mm.texts`, 1 s, only while a text is shown; secret positions skipped).
- Tooltip: `tt.anchor` (default/cursor), `tt.combat` (show/hide), `tt.ids`, `tt.guildRank`, `tt.mplus`. TooltipDataProcessor post-calls only; secret values never formatted.
- Data Bars: two bars, `db.barN.{blocks,width,height}`; blocks clock, fps, latency, location, coords, gold, bags, durability, ilvl, xp, spec. Equal-width solver; ticker `db.update` (1 s) only while a bar is shown; no frames created while off.

Deferred: Minimap own tracking/calendar/mail/crafting/difficulty buttons, addon flyout + LibDBIcon, rectangular/textured masks, FPS/difficulty texts, Vault/portals/friends buttons. Tooltip ilvl via paced inspect, mount owned, aura source, health strip skin. Data Bars full solver, professions/travel/micro menu/currency/crests/vault/audio/LDB host/spacer blocks, per-spec sets.
