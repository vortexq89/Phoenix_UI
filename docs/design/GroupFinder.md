# Group Finder (PUI_V2 6.6)

On by default (spec 6.6), display only; stands down when PremadeGroupsFilter is loaded. Hooks `LFGListSearchEntry_Update` (hooksecurefunc) and adds a Phoenix font string per entry: leader score in `C_ChallengeMode.GetDungeonScoreRarityColor`, missing roles from `C_LFGList.GetSearchResultPlayerInfo`, role fit for your current spec role, "declined you before" (memory of the newest 200 leaders from `LFG_LIST_APPLICATION_STATUS_UPDATED`). Groups below the minimum rating or from declining leaders are dimmed (alpha), never removed: the result list and sign-up run protected code and are left untouched. Server-side filters go through `C_LFGList.GetAdvancedFilter/SaveAdvancedFilter` and are written only when a Phoenix filter is on (or once when it is turned off). Optional sound for a new fitting group on `LFG_LIST_SEARCH_RESULTS_RECEIVED`.

Settings: `gf.scoreColor`, `missingRoles`, `roleFit`, `declined`, `dim`, `minRating`, `needMyRole`, `sound` (off); hidden `gf.declined`.

Deferred: quick sign-up and persistent sign-up note (both touch the protected application dialog), spec/class icons per member, per-dungeon filter presets, PvP rating display, raid composition view, client-side hiding.
