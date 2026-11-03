# PvP UI (step 9c)

Owner (plan 1.O): rated card, rated history, title progress, scoreboard column registry, battleground leave countdown, Training Grounds buttons, Solo Shuffle round tracker. Arena owns the arena frames, DR tray, trinkets, match timer and post-match card; Group Finder owns queue status and the pop countdown.

- Files: `Rated.lua` (bracket data, diff, title progress, conquest, Great Vault), `Columns.lua` (registry, sort, format), `Match.lua` (leave countdown, rounds, Training Grounds), `Card.lua` (rated card, scoreboard, leave bar), `PvP.lua` (settings, events, slash).
- Secrets: nothing is read during a match. Rows are read only when `C_PvP.IsMatchComplete()`; a secret cell is passed to `SetFormattedText`, never compared.
- Ticker: `pvp.leave` (1 s, only while counting), `pvp.round` (1 s, only while a Shuffle round runs).
- Column API: `PhoenixUI.PvP.Columns:Register(id, { label, value = function(score) end, width, format })`; fires Kernel `PVP_COLUMNS`.
- Defaults: everything on except the chat line and leave sound; leave countdown 15 s.
