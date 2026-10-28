# Approved guardrail exceptions

Every exception is also tagged in code on the line above the use:
`-- guardrails-allow: <check> YYYY-MM-DD approver=<name> reason=<text>`
(`.tools/guardrails.py` fails on an untagged or malformed use). Anything not
listed here is not approved.

| # | Check | Where | Approved | Scope |
|---|-------|-------|----------|-------|
| 1 | `pcall`, `xpcall` | `Tests/Runner.lua` | 2026-10-25, VortexQ8 | Test runner only: assert that code raises, isolate failing cases. |
| 2 | `deprecated` (`COMBAT_LOG_EVENT_UNFILTERED`, `CombatLogGetCurrentEventInfo`) | `Phoenix_UI_Forever/Forever.lua`, Swing section | 2026-10-28, VortexQ8 (t96u) | Forever swing timer. See below. |
| 3 | `pcall` | `Phoenix_UI_Sentinel/Share.lua`, `Share.Decode` | 2026-10-28, VortexQ8 (t96u) | Decoding a report received from another player. See below. |

## 2. Forever swing timer reads the combat log

- **Forever only.** `Swing.Wanted()` requires `PUI.IS_FOREVER`; the Forever
  module itself only loads there. Retail never registers the event.
- **Opt-in.** `forever.swingTimer` defaults to off. The event is registered
  when the setting is turned on and unregistered as soon as the setting, the
  module or the client gate turns off (live, no `/reload`).
- **Narrow.** Only the player's own `SWING_DAMAGE` / `SWING_MISSED` lines are
  used (source GUID equals `UnitGUID("player")`). A secret value is dropped,
  never compared.
- **No OnUpdate.** The bar is driven by the Ticker job `forever.swing`, which
  exists only while a swing is running and removes itself when idle.
- Tests: `Phoenix_UI_Forever/Tests/Forever_test.lua` ("swing timer: ...") and
  the Forever page preview test in `Phoenix_UI_Options/Tests/Options_test.lua`.

## 3. Sentinel decodes received reports inside a pcall

- The body comes from another player, so a checksum-valid but malformed body
  (bad base64, data that fails to inflate, broken JSON) must not raise an
  error in our own event handler.
- **Behind the existing gates.** Only offers within the size cap
  (`Share.MAX_CHUNKS` = 60 chunks, `Share.MAX_BYTES` = 60 x 220 bytes) are
  accepted; the assembled text must match the offered length and the checksum
  before `Share.Decode` runs. `Share.Decode` re-checks the cap and caps the
  inflated JSON at 16 x `MAX_BYTES`.
- **Narrow.** The pcall wraps only base64 decode, inflate and JSON parse. A
  failure (or a value that is not a report) returns `"bad data"` and is
  dropped. No Phoenix logic runs inside it, so our own bugs still surface.
- Tests: `Tests/Reporter_test.lua` ("in-game share: ...").
