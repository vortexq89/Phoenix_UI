# Embers - damage meter (PUI_V2 6.1)

Data: `C_DamageMeter` only (12.0.0+, also on Forever): `IsDamageMeterAvailable`, `GetCombatSessionFromType`, `GetCombatSessionFromID`, `GetAvailableCombatSessions`, `ResetAllCombatSessions`; events `DAMAGE_METER_COMBAT_SESSION_UPDATED`, `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `DAMAGE_METER_RESET`. Meter types are the API enum `DamageMeterType` (11 types). No combat log, no addon comms.

Secret handling: live `name`, `totalAmount`, `amountPerSecond` may be secret; they go only to `StatusBar:SetValue`, `AbbreviateNumbers` and `SetText`. `classFilename`, `specIconID`, `isLocalPlayer`, `deathRecapID` are NeverSecret. Rows are drawn in API order (never sorted on secrets).

Segment store (`embers.segments`, hidden): a finished session is captured after combat (CombatQueue), keeping only non-secret fields; cap `embers.maxSegments`, pinned segments kept; rename, pin, delete, merge, compare across runs; boss-only filter. Graph: own per-second value sampled at 1 Hz in combat via the Ticker. Report: top-N to a chat channel, refused in combat and when `C_ChatInfo.InChatMessagingLockdown()`. Export/import `!PUI_EMB1:` plain text. Up to 5 windows, each a Studio element (`embers.window1..5`); title click cycles meter type, right-click cycles Current/Overall/Saved. Looks: bars, compact, minimal.

Settings: `embers.windows`, `meter`, `rows`, `look`, `maxSegments`, `bossOnly`, `graph`, `report`. Slash: `/pui embers list|report|export|pin|deaths|reset`.

Deferred: LoadOnDemand packaging, graph window (data is stored, no drawing yet), death recap window (list via slash only), per-window saved meter type, snapping between windows beyond Studio grid, encounter history per boss with best-pull markers, "my parse vs my average" trend view, Forever threat meter, report formatting options.
