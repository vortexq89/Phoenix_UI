# Bug reports (`PhoenixUIBugsDB`)

Phoenix UI stores the errors it catches in an account-wide SavedVariable. The **Phoenix Uploader** app (Windows)
reads it and sends new reports to VQ8S.com. This file is the addon side of the shared contract (schema 1); change
it only together with the uploader and the website.

## File

`World of Warcraft\_retail_\WTF\Account\<account>\SavedVariables\Phoenix_UI.lua` (the game writes it on logout and
`/reload`). The same file also holds `PhoenixUIDB` (settings) and, until migration, `Phoenix_UIDB`.

```lua
PhoenixUIBugsDB = {
    schema = 1,
    installId = "3f9a0c17be42d905",   -- random 16 hex, created once, no personal data
    session = 42,                     -- +1 on every login and /reload
    share = true,                     -- "Send error reports to the author"; the uploader skips the account when false
    shareNotice = true,               -- the one-time chat notice about share has been shown
    reports = {                       -- newest last, capped (default 500)
        {
            id = "3f9a0c17be42d905-42-1",  -- <installId>-<session>-<n>
            hash = "a1b2c3d4e5f60718",      -- 16 hex, stable across sessions and line numbers
            kind = "error",                 -- "error" | "taint" | "warning"
            message = "Interface/AddOns/Foo/Foo.lua:12: attempt to index a nil value",
            stack = "[Interface/AddOns/Foo/Foo.lua]:12: in function <...>\n...",
            locals = "self = <table> {\n ...",  -- may be ""
            count = 3, firstSeen = 1792000000, lastSeen = 1792000420, session = 42,
            addonVersion = "2.0.0", interface = 120105, build = "12.1.5.70448", locale = "enUS",
            flavor = "retail", zone = "Dornogal", combat = false,
            source = "Foo",                 -- "Phoenix_UI" | "<addon folder>" | "Blizzard" | "Unknown"
            uploaded = false,
            reported = true,                -- optional: the player marked it in the viewer; not sent, ignore
        },
    },
}
```

## Field notes

* **kind**: `error` = Lua error from the error handler (or BugGrabber, read through its
  `BugGrabber.BugGrabbed` EventRegistry event); `taint` = `ADDON_ACTION_BLOCKED` /
  `ADDON_ACTION_FORBIDDEN` (message `"[EVENT] AddOn 'X' tried to call the protected function 'F'."`);
  `warning` = `LUA_WARNING`.
* **hash**: two 32-bit polynomial hashes over the message and the first three stack lines, after removing
  `Interface/AddOns/` prefixes, line numbers and memory addresses. Same bug, same hash, on every PC.
* **Dedupe**: within one session a repeat increases `count` and `lastSeen` on the existing report. A new session
  starts a new report with the same `hash`; group by `hash` across sessions and installs.
* **source**: the first `Interface/AddOns/<folder>/` found in the message, else in the stack. `Blizzard_*`
  folders become `"Blizzard"`. When nothing names an addon (rare, e.g. a bare `[string]` chunk) it is
  `"Unknown"`, which the contract's three named values do not list; the server should accept it.
* **addonVersion**: the TOC `Version` of Phoenix UI (`2.0.0-dev` in an unpackaged checkout).
* **flavor / zone / combat**: `retail` or `forever`, the zone name when the report was first caught (plain text only), and whether combat lockdown was on. Optional: older reports lack them.
* **Limits**: message 2000 chars, stack and locals 6000 chars each (cut with `…`). Secret values (12.x) are
  never stored; they appear as `<secret value>`. Locals are not collected during a boss encounter.
* **Flood protection**: at most 10 captures per second (burst 30); skipped repeats are not stored.
* **share**: on by default and set to `true` on installs from before the setting existed. Only an explicit
  `false` stops the uploader; a missing value means on. The game writes the file on logout and `/reload`, so a change
  reaches the uploader from then. Reports caught while it is off are never sent, not even after it is switched back on.
* **Privacy**: before anything is stored (or hashed) the addon removes this character's name and realm, player
  GUIDs (`Player-<guid>`), BattleTags, the Windows user folder and the WoW account folder. String locals that look
  like text (spaces or non-ASCII: chat lines, tooltips, other players' names) become `"<text, N bytes>"`; short
  token-like values (`"player"`, `"BOTTOMLEFT"`) are kept. The uploader applies the same rules again before sending,
  and also removes every realm and character name that has a folder under the account.
* **uploaded** is always `false`; the addon cannot know, and the uploader marks nothing in the file. It keeps its
  own list of sent `id`s; the server dedupes by `id`.

## Upload

The uploader finds every `WTF\Account\*\SavedVariables\Phoenix_UI.lua`, parses `PhoenixUIBugsDB` and posts new
reports to `https://vq8s.com/phoenix/api/ingest`. Download it from <https://vq8s.com/phoenix-ui>. The settings page
*Bugs → Upload reports to VQ8S.com* holds the **Send error reports to the author** switch and shows the install ID
so players can quote it. `/pui bugs share` toggles the switch, `/pui bugs share on|off` sets it.
