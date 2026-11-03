# Overnight self-test loop

Unattended testing of Phoenix UI while nobody plays. **No gameplay and no input is ever sent to the game**:
no key presses, clicks or macros from outside WoW. The game sits idle in a safe spot and the addon tests itself.

## What is technically possible (checked against warcraft.wiki.gg, 12.x)

| Thing | Possible? | Why |
|---|---|---|
| Addon calling `ReloadUI()` / `C_UI.Reload()` by itself | **No** | Marked *restricted, #hwevent*: it needs a real key or mouse press. A timer cannot do it. |
| Addon calling `Screenshot()` | Yes | Not protected. Saves into the game's own Screenshots folder (opt-in, `/pui dev selftest shots on`); the PC helper never reads or copies that folder. |
| SavedVariables written mid-session | No | Only on /reload, logout, exit or disconnect. |
| Passive capture of the PC screen | Yes | `tools/pc/phoenix_shots.ps1`, read-only `CopyFromScreen`. Needs an unlocked desktop session (no lock screen). |

**Fallback for "no self-reload":** results build up in memory and are flushed to `PhoenixUIDevDB.selftest` at the
next /reload, logout or idle disconnect. Each finished page is also printed to chat and (with shots on)
screenshotted, so the 10-minute screen captures show the per-page counts even before the save.
In the morning, one `/reload` (or logging out) writes everything; bugwatch then turns it into the diag files.

## In game (before bed)

1. Stand somewhere safe (a city/inn), out of combat. Close bags and other windows.
2. `/pui dev on`, then `/pui dev selftest shots on` (optional), then `/pui dev selftest on`.
3. Don't touch anything. Moving, casting, targeting or entering a vehicle stops the test at once. Combat pauses it.

What it does: every options page, each of its tabs, each preview state (and plain), then movers on and off. It audits
after every step (texts, previews, frames) and records counts and the first 40 issues per page. It waits 60 s and
starts again, capped at 500 loops. It only uses C_Timer (no OnUpdate). `/pui dev selftest off` stops it, and
`/pui dev selftest` shows its status.

## PC side

`tools\bugwatch.ps1 -Watch` (the hidden PhoenixBugWatch task) runs on every SavedVariables change and writes:
- `bugs\phoenix_bugs.txt/.json` (errors)
- `bugs\phoenix_diag.txt/.json` (DevDiag, including the self-test pages)
- `bugs\shots\screen_*.png` (full screen), on every save **and every 10 minutes while Wow.exe runs**, so the
  self-test's chat lines are visible overnight without a /reload. Newest 50 kept; only its own screen_*.png are pruned.

## The agent's loop

1. Read `bugs\phoenix_diag.txt` / `.json`, `bugs\phoenix_bugs.txt` and the newest `bugs\shots\*`.
2. Fix in `/workspace/pui_restore` (original code only).
3. Run the guard: `tools/prepush.sh`.
4. Push through the PC bundle flow (`restore/v1-ui` plus `refs/notes/prepush`); CI must be green.
5. Install with `tools\pui_sync.ps1` **only when Wow.exe is not running**. If it is running, write "install pending" in
   the report and install next time.
