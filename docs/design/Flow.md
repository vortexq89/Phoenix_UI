# Flow (PUI_V2 5.14, plan 5.12) - step 9a

21 settings. Every automation is off by default and the module registers only the events of enabled toggles. Auto repair (player/guild), sell junk (Vault owns junk while it is on), auto release (never BG/arena or with a self-resurrect), decline duels / guild invites, accept invites from friends/Battle.net/guild (secret GUIDs never trusted), fill DELETE, auto gossip, quick loot (Shift skips), low durability warning, hide errors in combat, max camera distance (CVar saved and restored), `/pui rl`.

**Quiet mode** (`Quiet.lua`, BigWigs BossBlock parity, owner per plan 1.O): hide talking heads, skip movies and cinematics (Shift to watch), hide toasts, hide boss emotes, mute error speech, mute SFX during boss fights, mute music, accept resurrection out of combat. Every cell starts OFF in every content type (D-MOD-DEF3). A grid sets each option per content type; a per-instance list (`instanceID:option=on|off`, or `/pui quiet here <option> on|off|inherit`) overrides single instances, otherwise the instance inherits its content type. Sound options go through the CVar ledger and your values come back when a cell stops applying or Flow turns off. Soft conflict choice with BigWigs (stands down while it is loaded until you pick). `/pui quiet` prints what applies here.

**Auto combat logging** (owner): on in the content types you tick (raids and M+ ticked to start with; master switch off), off elsewhere, and never stops a log Flow did not start (recorder addons keep theirs).

Moved out: `/pui cd`, pull/break and ready check -> Raid Tools; old skip-cinematics / talking-head / accept-res switches -> Quiet mode cells (migration `0009a_flow_quiet` keeps your choices).

Deferred: auto decline pet battle duels, leave-queue popups, open containers, Train All, hide tutorials/banners, rested ZZZ, `/gg`, queue protection, Tab binder, screenshot on achievement.
