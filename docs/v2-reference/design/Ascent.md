# Ascent - Mythic+ timer (PUI_V2 6.2)

Retail only (module `loadCondition` refuses Forever). Timer from the world timer (`GetWorldElapsedTimers`/`GetWorldElapsedTime`, type `Enum.WorldElapsedTimerTypes.ChallengeMode`), so a reload resumes correctly. Map name/limit `C_ChallengeMode.GetMapUIInfo`; level/affixes `GetActiveKeystoneInfo` + `GetAffixInfo`; +3 = 60 %, +2 = 80 % of the limit, one sound (and optional TTS via `C_VoiceChat.SpeakText`) when each is lost. Forces: the weighted `C_ScenarioInfo.GetCriteriaInfo` entry, fed to a StatusBar as-is (secret-safe). Deaths/time lost `GetDeathCount`. Boss splits from `ENCOUNTER_END` (success), compared with the personal best for that map and level. Completion `GetChallengeCompletionInfo`: run summary with score change, personal best stored per character (`ascent.records`), leaderboard via `/pui ascent best`. Route notes per dungeon (`ascent.notes`, `/pui ascent note`). Blizzard tracker faded (alpha) while a key runs when `ascent.hideBlizzard` is on.

Settings: `ascent.sounds`, `tts`, `hideBlizzard`, `splits`, `notes`, `scale`; Studio element `ascent.timer`.

Deferred: LoadOnDemand packaging, current-pull forces preview (needs an NPC forces data pack), targeted-spell bars and kick tracker (secret-gated), score projection, Embers stats in the run summary, vault planner, season recap card, death log beyond the count.
