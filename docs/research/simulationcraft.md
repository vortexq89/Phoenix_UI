# SimulationCraft (engine, wiki, in-game addon) and Raidbots

Studied: `simulationcraft/simc` (default branch `midnight`, GPL-3.0, pushed 2026-10-22), its wiki, the
`simulationcraft/simc-addon` in-game exporter (Unlicense, v12.1.0-04), downloads.simulationcraft.org/nightly,
and raidbots.com/developers.

## Licences
- **simc engine: GPL-3.0.** Running `simc.exe` as a separate program from our companion is "aggregation", not a
  derived work: Phoenix (MIT) and the Go companion stay MIT. If we *redistribute* simc.exe we must ship the GPL
  text and offer the matching source. Downloading it at runtime from the official site avoids that duty.
- **simc-addon: Unlicense (public domain).** Phoenix may reuse its export logic (item strings with bonus IDs,
  gems, enchants, crafted stats, talent loadout export, upgrade currencies). We still re-implement it in Phoenix
  style, with a credit line.

## Facts verified
- Nightly Windows build: `simc-1210.01.7bc1071-win64.7z`, 115 MB, 2026-10-21 (CLI `simc.exe` included; GUI optional).
  Midnight data is in the `midnight` branch; the engine already carries 12.1.5 PTR data.
- simc reads a profile text file and writes `json2=` / `html=` reports; no network needed for a local sim.
- **Raidbots has no public submission API.** Its developer page documents static data JSON and report files
  (`data.json`, `input.txt`) only; sims are submitted through the website or the Discord bot. So "one click →
  Raidbots" is not possible without driving a browser, which we will not do.
- simc-addon export = text block: header comments, `class="name"`, level, race, region, server, role,
  professions, `spec=`, `talents=` (loadout string), one `slot=,id=,bonus_id=,gem_id=,enchant_id=,crafted_stats=`
  line per item, bag items as comments (`# trinket1=…`), plus catalyst/upgrade currency comments and a checksum.

## The Phoenix Sim flow (designed)
1. **In game (instant):** Phoenix "Sim" page (Group *Tools* → or *Tooltips & Items*) shows the paperdoll + bag
   grid. Pick a mode — *Current gear*, *Compare items* (tick bag items per slot), *Top Gear* (up to N combos),
   *Stat weights*. Phoenix builds the profile string in Lua (out of combat only; item info is not secret) and
   stores the request in SavedVariables.
2. **Reload #1** (Phoenix shows a "Send to Phoenix app" button → `C_UI.Reload()`): WoW writes SavedVariables.
3. **Companion (Phoenix app, the existing Go uploader grown up):** sees the new request, runs
   `simc.exe input.simc json2=out.json threads=N target_error=0.2`, and shows results in its window and a toast
   *immediately* (DPS per set, delta vs equipped, stat weights). Estimated runtime on an 8-thread PC: a single
   profile 5–20 s, a 2–10 item compare 15–60 s, Top Gear grows with combinations (estimate; measure in stage S2).
4. **Results back in game:** the companion writes `Interface\AddOns\Phoenix_UI_Sim\Results.lua` (a file shipped
   empty and listed in that addon's TOC). WoW re-reads Lua files on **reload #2**, so results appear in the Sim
   page and as "+1.8% DPS" lines on item tooltips. Files are only re-read on reload; brand-new files need a full
   client restart, which is why the file must already exist.
- Total: 2 reloads; results visible in the app seconds after reload #1. Nothing is uploaded anywhere.
- Safety: the companion only executes the simc binary it downloaded itself (SHA-256 pinned from the release
  listing), writes only inside the Phoenix folders, and the Lua it writes is data-only (same parser rules as the
  uploader, in reverse).

## How Phoenix does it better
- No copy/paste, no browser, no account; bag items are picked visually instead of editing text.
- Results land back on tooltips and the Bags upgrade arrow (which today only compares item level).
- What we cannot do: run a sim inside WoW (no network, no processes, Lua CPU budget) or send to Raidbots
  automatically (no API).
