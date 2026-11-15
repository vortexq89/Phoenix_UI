# Group Finder (2.0 S15)

The Group Finder page (Content → Group Finder, retail only) adds filters, sorting, highlights and sign-up helpers
to Blizzard's premade group list, and applicant details for group leaders. The ideas are the ones group-finder
addons share (PremadeGroupsFilter was studied for facts only, docs/research/premade-groups-filter.md); the
design, the filter language and the code are Phoenix's own.

## How filtering works (and why it dims)

Blizzard's list (`LFGListFrame.SearchPanel`) is secure UI. Writing its `results` table, reordering it, or calling
its selection and sign-up code from an addon taints the panel, and the taint then blocks Blizzard's own sign-up.
So Phoenix:

* **never** writes a Blizzard field, never removes, reorders or selects results, and never calls
  `C_LFGList.ApplyToGroup` (it is not in the public API documentation; Blizzard calls it from its own dialog);
* **dims** groups that fail a Phoenix filter (`SetAlpha` from a post-hook of `LFGListSearchEntry_Update`), or only
  flags them in the tooltip if you prefer, and outlines groups that pass;
* lets the **game's own advanced filter** do real removal: the *Game filters* (difficulty, needs my role, has
  tank / healer, minimum rating) are saved with `C_LFGList.SaveAdvancedFilter`, starting from
  `C_LFGList.GetAdvancedFilter()` so your dungeon and playstyle picks stay. Phoenix writes it only when you change
  one of those settings;
* lists the **best matches** in its panel, sorted your way (fit, newest, leader score, best key, item level,
  members, PvP rating). Clicking one flashes it in Blizzard's list, where you sign up as usual.

Some result fields can be secret while chat is locked down (`SecretInChatMessagingLockdown`). Phoenix reads them
as *unknown*, and an unknown value never hides a group.

The listing's own key level is not available to addons (the title and comment are protected strings), so the
*best key* filter and sort use the leader's best run in that dungeon (`leaderDungeonScoreInfo.bestRunLevel`).

## The filter expression

Type an expression in *Filter expression*; the panel counts matches while you type and explains errors.

* `and`, `or`, `not` (also `&&`, `||`, `!`), parentheses
* comparisons `==` (or `=`), `~=` (or `!=`), `<`, `<=`, `>`, `>=`
* arithmetic `+ - * /` and unary `-`; `true` / `false`; yes/no words count as 1 / 0 (`tanks + heals >= 2`)

Examples: `tankfree > 0 and score >= 2000 and age < 15` · `myrole and not declined` · `raid and bosses == 0` ·
`lust and brez and leavers == 0`

| Word | Reads |
|---|---|
| `age` | minutes listed |
| `members` | players in the group |
| `slots` | free places |
| `tanks` | tanks |
| `heals` | healers |
| `dps` | damage dealers |
| `tankfree` | free tank places |
| `healfree` | free healer places |
| `dpsfree` | free damage places |
| `myrole` | a free place for your role |
| `score` | leader's Mythic+ score |
| `dungeonscore` | leader's score in this dungeon |
| `bestkey` | leader's best key in this dungeon |
| `timed` | leader timed that key |
| `pvp` | leader's PvP rating |
| `ilvl` | required item level |
| `reqscore` | required score |
| `reqrating` | required PvP rating |
| `friends` | friends in the group |
| `guild` | guild members in the group |
| `voice` | uses voice chat |
| `bosses` | bosses defeated |
| `autoaccept` | joins without approval |
| `warmode` | War Mode |
| `crossfaction` | cross-faction |
| `newfriendly` | new-player friendly |
| `declined` | declined you before |
| `leavers` | players flagged as leavers |
| `lust` | has Bloodlust |
| `brez` | has a battle resurrection |
| `mythicplus` | Mythic+ key |
| `mythic` | Mythic |
| `heroic` | Heroic |
| `normal` | Normal |
| `raid` | raid |
| `dungeon` | dungeon |
| `pvpactivity` | PvP |
| `rated` | rated PvP |
| `saved` | you are saved to this raid |

## Sign-up helpers

Every helper ends in a click on Blizzard's own button, made by the secure action code
(`SecureActionButtonTemplate`, type `click`), and starts from your own click or key press:

* **Click again to sign up:** after you select a group (Blizzard's click), a secure button covers that entry;
  clicking it again clicks Blizzard's *Sign Up*. Right-click still opens Blizzard's menu.
* **Enter signs up:** while the list is shown, an override binding makes Enter click *Sign Up* (or the dialog's
  *Sign Up* when it is open). Open chat with `/` meanwhile.
* **Role-check key:** while a role check is shown, the key you pick clicks its *Accept*.

Bindings and secure attributes only change out of combat; the overlay's holder hides in combat
(`[combat] hide`). Not built, on purpose or because the game does not allow it: signing up or accepting role
checks without your input; remembering the sign-up note (Blizzard's note box refuses `SetText` from addons);
skipping the sign-up dialog; cancelling your oldest application.

## Leader view

While you list a group, each applicant row shows that player's best key in your listed dungeon (green when
timed, `C_LFGList.GetApplicantDungeonScoreForListing`), a spec icon, and a class-colour tint when their Mythic+
score reaches your *Highlight applicants from score* line.

## WoW Forever

Forever's client excludes Blizzard_GroupFinder (its TOC has `ExcludeLoadGameType: camelot`) and uses the secure,
load-on-demand Blizzard_GroupFinder_VanillaStyle instead, so there is no premade list to extend: the module and
page are hidden there (feature `lfgList`), and saved settings stay in the profile.

## Testing

Offline: `tools/smoke/harness.lua` (three S15 tests: the language, records/filters/sort/presets/advanced filter
with a stub `C_LFGList`, decoration/panel/helpers/preview, and Forever gating). In game: TESTING §13m.
