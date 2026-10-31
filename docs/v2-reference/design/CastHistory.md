# Cast History (plan 1.O owner of spell history, mockup 17) - step 9b

35 settings and a module switch. TrufiGCD parity (all 10 features) in Phoenix's own code.

- **Tracker** (`Tracker.lua`): castGUID-keyed state per unit; start/channel/empower add, success confirms or adds an instant, interrupted shows a red cross, stop or failed after a start without success shows a grey cross, a failed press without a start adds nothing. Secret spell IDs and GUIDs are never compared or used as keys; blocklists check plain IDs only. History newest first for Embers (`CastHistory.Tracker.History(unit)`).
- **Strips** (`Strip.lua`): per unit (you, target, focus, party 1-4, arena 1-3; you, target and arena on by default), moving strip (per-frame Ticker only while moving, catch-up when queued, pause on hover) or still and fade (0.25 s Ticker while icons show). Direction, size, spacing, count, slide time, fade time, newest glow, held empowered mark, PvP trinket faction art, zoom, border. Studio element per unit.
- **Blocklists:** built-in (auto attack, auto shot, shoot, GCD), spell IDs, item IDs (mapped to their use spell), Ctrl+Alt+click to add, `/pui casthistory find <name>` lists every seen spell matching a name plus the game's own lookup.
- Tooltip and pause on hover, Shift+click prints name and ID (opt-in). Where to show: always, in combat (shared combat timer), in instances, in PvP.

Deferred: Masque, Addon Compartment entry, an Embers link button.
