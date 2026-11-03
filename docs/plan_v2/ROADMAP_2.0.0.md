# Phoenix UI roadmap (12.1.5 and later)

This roadmap comes from three things: a review of every module, a look at the addons Midnight players use most,
and what the 12.x API still allows. Items are ranked **Must**, **Should** and **Could**. Every item lists why it
matters, the API it depends on and a rough effort estimate (S = under a day, M = a few days, L = a week or
more). If Midnight forbids something (combat log, reading secrets, protected frames, Edit Mode systems), it goes
under *Not doing* below, not into a tier.

## Where the ecosystem is (October 2026)

| Area | What players use | What changed in Midnight | What it means for Phoenix |
|---|---|---|---|
| Mythic+ | WarpDeplete, MPlusTimer; Platynator / Plater for forces | Timer and criteria APIs stay non-secret. 12.0.5 added `C_ScenarioInfo.GetUnitCriteriaProgressValues` for forces per mob | A timer and forces per mob are now in scope (shipped) |
| Auras / alerts | WeakAuras forks (M33kauras) | WeakAuras was discontinued: aura and combat data are secret in combat | No custom aura engine. Blizzard's Cooldown Manager is the supported path (already a toggle) |
| Unit frames | ElvUI, Unhalted, Blizzard + skins | ElvUI lost style filters, aura sorting and complex tags | Phoenix's skin-Blizzard approach is the right one. Do not rebuild frames |
| Meters | Details! (now on `C_DamageMeter`) | The combat log is closed to addons | The Damage Meter skin plus the Details! style is enough |
| Party cooldowns | OmniCD (broken), MiniCC (cast events) | Party spell casts are partly secret, and there is no combat log | Not doing (see below) |
| Chat | Chattynator, Prat | Chat frames are secure mixins. History must come from addon storage | Typed-line history and fast scrolling (shipped). A full replacement is out of scope |
| Bags | Baganator, BetterBags | Healthy | Item level on bag slots already exists. No bag replacement |
| Minimap | Leatrix Plus (size up to 400 %), SexyMap | The size is an Edit Mode setting (50–200 %) | Show the size and link to Edit Mode (shipped). Do not override it |
| Errors | BugSack / BugGrabber | Unchanged | Phoenix Bugs covers this already |
| Movers | MoveAny, Edit Mode | Edit Mode covers more frames | Movers only handles frames Edit Mode does not manage (already the rule) |

The features players mention most are a Mythic+ timer, forces per mob, rating in tooltips, chat history, bag
item levels and movers. The first four were missing or partial in 2.0.0.

## Must (done in this pass)

| # | Item | Why | API and feasibility | Effort | Status |
|---|---|---|---|---|---|
| M1 | **Secret-safe ordering** in Tooltip, UnitFrames and CastBars | A truthiness test on a secret raises an error before `IsSecret` runs. That is a crash in restricted content | `plain(x)` must come before `x` (Core/Secret.lua) | S | Done, b2f0f8f |
| M2 | **Mythic+ run timer** | The most requested M+ feature, and it was missing since 2.0.0 | `C_ChallengeMode.GetActiveChallengeMapID/GetMapUIInfo/GetActiveKeystoneInfo/GetDeathCount/GetChallengeCompletionInfo`, `GetWorldElapsedTime`, `C_Scenario.GetStepInfo`, `C_ScenarioInfo.GetCriteriaInfo`. All non-secret. Frame registered with LibEditMode | M | Done, 40f2d6e |
| M3 | **Chat input history** | Losing what you typed after `/reload` is the most common chat complaint | `EditBox:AddHistoryLine` (post-hook) and `SetAltArrowKeyMode`, saved in `global.history` (32 lines, matches `historyLines`) | S | Done, 631b03a |
| M4 | **Fast chat scrolling** | Scrolling back through a busy channel one line at a time is slow | `ScrollingMessageFrameSecureMixin` `ScrollToTop/ScrollToBottom/PageUp/PageDown` through `HookScript("OnMouseWheel")`. No taint, because the methods are callable from addon code | S | Done, 631b03a |
| M5 | **Minimap size, through Edit Mode** | Users asked for the old slider. A Phoenix slider would fight Edit Mode | `MinimapCluster:GetSettingValue(Enum.EditModeMinimapSetting.Size)` is read-only. The button opens Edit Mode | S | Done, 8bac2c6 |
| M6 | **Mythic+ rating in tooltips** | Rating is the first thing checked on a group applicant or a player in town | `C_PlayerInfo.GetPlayerMythicPlusRatingSummary`, `C_ChallengeMode.GetDungeonScoreRarityColor` | S | Done, ca16483 |
| M7 | **Theme tokens everywhere** | The range tint and item level text used literal colors and did not follow theme changes | `ns.Theme` `state.danger` and `Skin:Text`, plus `PUI_THEME_CHANGED` | S | Done, a02ce19 |
| M8 | **Enemy forces on nameplates** | Pulling for count is the core M+ planning task. Platynator proved the API works | `C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)` (12.0.5), which may be secret, so it is shown with `C_StringUtil.WrapString(TruncateWhenZero(count), "+")` and never compared | S | Done, 7140a64. **Verify in game** |

## Should (done for 2.0.0-beta1)

| # | Item | Why | API and feasibility | Effort | Status |
|---|---|---|---|---|---|
| S1 | **Timer: compare against your best splits** | WarpDeplete users rely on "ahead/behind" for each boss | Splits are already stored per run. Store the best run's splits with `best[...]` and show the difference. Plain numbers only | S | Done, 6675461 |
| S2 | **Timer: forces "pull" preview** | Shows how much the current pull adds before it dies | Sum `GetUnitCriteriaProgressValues` over nameplates in combat. **Only if the values are not secret in game**. If they are, the sum cannot be done and the item is dropped | M | Done, 6675461. The sum is dropped silently when any value is secret. **Verify in game** |
| S3 | **Keystone list in the Mythic+ page** | Lets you see party keys without asking in chat | Party data needs addon messages (`C_ChatInfo.SendAddonMessage`), which are restricted inside instances in 12.x. Possible in town only. Needs a design decision | M | Done, b1315e3. Speaks LibKeystone (BigWigs, DBM); never sends during chat lockdown |
| S4 | **Great Vault and season summary on Home** | One glance at weekly progress | `C_WeeklyRewards.GetActivities`, `C_MythicPlus.GetRunHistory`. Non-secret | S | Done, 2466387 |
| S5 | **Chat: tab flash and whisper tab colors** | Small readability win | `FCF_StartAlertFlash` hooks, theme tokens. Purely cosmetic | S | Done, f613919 |
| S6 | **Locales** beyond enUS | 756 keys, enUS only before beta1 | Locale files plus `check_locales.py` already enforce the key set. Needs translators | M | Done: deDE, frFR, esES (also esMX), ptBR, ruRU, itIT, koKR, zhCN, zhTW (91bc938…90f6425). check_locales.py and the harness enforce completeness. Native-speaker review welcome |
| S7 | **In-game test pass** for M2, M8 and the tooltip rating | Secret behaviour of the forces API and completion events can only be confirmed live | A test checklist in docs/TESTING.md | S | Done: docs/TESTING.md (f9cdae4) |

## Could (later, if there is demand)

| # | Item | Why | API and feasibility | Effort |
|---|---|---|---|---|
| C1 | **Restore received chat messages after a reload** (Chattynator style) | Some users want the scrollback, not just their own lines | Messages must be captured in `ChatFrame_AddMessageEventFilter` and replayed with `AddMessage`. Secret message bodies (12.x) cannot be stored, so the result would have gaps. Large SavedVariables | M |
| C2 | **Timer: death log** | Who died, and when | `UNIT_DIED`-style data is not available without the combat log. Only the total death count is non-secret. Feasible only as "time of each death" | S |
| C3 | **Timer: reskin Blizzard's challenge block instead of a separate frame** | Some users prefer one tracker | The Objective Tracker is an Edit Mode system. Restyling (not moving) is allowed, but the block is rebuilt often | M |
| C4 | **PvP: dampening from the arena widget** | Dampening was a popular arena readout | Only if Blizzard exposes it as a UI widget (`C_UIWidgetManager`). Estimating it from time drifts when Blizzard tunes it | S if a widget exists |
| C5 | **Minimap: button bin** | Collects LibDBIcon buttons | Optional `LibStub("LibDBIcon-1.0", true)` (embedded by other addons) plus its `LibDBIcon_IconCreated` callback; no new dependency | M | Done (2.0 P2) |

## Not doing, and why

* **Party cooldown tracking (OmniCD style)**: needs the combat log or party aura data, and both are restricted in
  12.x. MiniCC's cast-event approach is incomplete by design and would break on every hotfix.
* **Custom aura/alert engine (WeakAuras style)**: aura contents are secret in combat. The supported path is
  Blizzard's Cooldown Manager, which Phoenix already exposes.
* **A Phoenix minimap size slider or scaling of `MinimapCluster`**: it is an Edit Mode system. Writing its scale
  taints Edit Mode, and writing layouts through `C_EditMode` needs a layout reload. Edit Mode stays the owner.
* **Arena dampening from aura data**: aura data in arenas is restricted.
* **Forces as a percentage on nameplates**: the value can be secret, so a percentage (division) is not possible
  and a zero cannot be hidden without `TruncateWhenZero`, which only works on the raw count.
* **Hiding Blizzard's challenge block automatically**: it lives in the Objective Tracker (Edit Mode). Users can
  collapse it themselves. Phoenix will not hide Edit Mode systems.
* **Whisper sound**: Blizzard already plays one. A second sound only duplicates it.
* **Replacing the chat, bag or unit frames**: Phoenix skins Blizzard frames. Full replacements (Chattynator,
  Baganator, ElvUI) are separate projects with their own upkeep.
