# Action Bars (PUI_V2 5.6) - Phase 2 design

Child addon `Phoenix_UI_ActionBars`, module `ActionBars`, off by default. Ten bars; bars 1-3 on by default once the module is enabled.

| Bar | Page (slots) | Keybinds taken over | Stock bar parked |
|---|---|---|---|
| 1 | paged (1-12 / bonus / override / vehicle) | ACTIONBUTTON1-12 | MainActionBar |
| 2 | 6 (61-72) | MULTIACTIONBAR1BUTTON | MultiBarBottomLeft |
| 3 | 5 (49-60) | MULTIACTIONBAR2BUTTON | MultiBarBottomRight |
| 4 | 3 (25-36) | MULTIACTIONBAR3BUTTON | MultiBarRight |
| 5 | 4 (37-48) | MULTIACTIONBAR4BUTTON | MultiBarLeft |
| 6-8 | 13-15 | MULTIACTIONBAR5-7BUTTON | MultiBar5-7 |
| 9, 10 | 2 and 10 (setting) | none | none |

- Headers are `SecureHandlerStateTemplate`; buttons `SecureActionButtonTemplate` with `type=action`. Bar 1 pages through `_onstate-page` using the restricted-environment functions `HasVehicleActionBar/GetVehicleBarIndex`, `HasOverrideActionBar/GetOverrideBarIndex`, `HasTempShapeshiftActionBar/GetTempShapeshiftBarIndex`, `HasBonusActionBar/GetBonusBarIndex`, `GetActionBarPage` (all in `RestrictedEnvironment.lua` on live and forever).
- Visibility: user macro conditions (`ab.barN.visibility`), default `[petbattle][vehicleui][overridebar][possessbar] hide; show` (bar 1: `[petbattle] hide; show`). Fade out of combat: a `[combat] in; out` driver whose snippet sets alpha in the secure environment.
- Keybinds: `SetOverrideBindingClick` for the keys bound to the matching Blizzard commands; refreshed on `UPDATE_BINDINGS` out of combat. Clicks are registered `AnyUp, AnyDown`; the template follows `ActionButtonUseKeyDown`.
- Visuals: icon, cooldown and charge cooldown from duration objects, count, macro name, keybind, usable tint via `C_CurveUtil.EvaluateColorFromBoolean`, range overlay from `ACTION_RANGE_CHECK_UPDATE` (range checks enabled only for shown slots), current-action overlay, proc glow from `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE` mapped with `C_ActionBar.FindSpellActionButtons`.

## Not in this phase (reported)
13-14 buttons per bar (an action page holds 12 slots, so buttons 13-14 would duplicate slots), per-button overrides, assisted-combat highlight, flyouts, micro menu, bag bar, stance/pet/possess/extra/zone/encounter bars, quick keybind mode, Blizzard/Classic looks. Blizzard's OverrideActionBar still appears in vehicles alongside the paged bar 1.
