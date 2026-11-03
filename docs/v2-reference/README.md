# v2 reference (read-only)

These files come from the Phoenix UI v2 rework (branch `docs/addon-research`, built on `main-v2`, 25–28 Oct 2026),
which was set aside on 28 Oct 2026 in favour of the original design restored on `restore/v1-ui`.

They are kept as **reference only**: plans, feature lists, audits and in-game check lists. They describe v2's
file layout (`Phoenix_UI_HUD`, `Phoenix_UI_Ascent`, Studio, Sentinel …), which does not exist here. No v2 UI code
is brought over. Anything worth having is ported into the original module structure, one item at a time,
through [../ROADMAP.md](../ROADMAP.md).

| File | What it is |
|---|---|
| PLAN.md | The v2 master plan: modules, phases, rules |
| DEFERRED.md | Items v2 deferred, with reasons |
| REVIEW_2026-10-27.md | End-to-end review of v2 before the in-game test |
| INGAME_CHECKS.md | v2's in-game check list (most checks still apply to the same features here) |
| SKINS_AUDIT.md, SKINS_FEATURE_AUDIT.md | Blizzard window skin coverage audit |
| PLUGINS.md | v2's plugin API design |
| PATCH_WATCHER.md | Watching Blizzard API changes between builds |
| FIXED_SYNC.md | Signed "fixed errors" list design (uploader + website) |
| releases/2.0.0-beta2.md | Draft release notes of v2 (never published) |
| design/*.md | One design note per v2 module |

The 28 Oct 2026 diagnosis of why v2 failed is [../research/RECOVERY_REPORT.md](../research/RECOVERY_REPORT.md).
