# Patch watcher and auto-fix

`.github/workflows/api-watch.yml` runs daily (and on demand):

1. Clones Blizzard's interface source (Gethe/wow-ui-source: live, ptr, forever).
2. Rebuilds `Data/ApiCatalog.json` (`.tools/api_catalog.py`).
3. Runs `.tools/autofix.py`, which:
   - regenerates `Data/ApiManifest.lua` and `Data/SchemaIndex.lua`;
   - regenerates `Phoenix_UI_Locales/keys.txt`;
   - adds offline-harness stubs for any manifest API the harness lacks, in the
     generated block of `.tools/harness/wow_stub.lua` (without them Sentinel's
     drift check stops early or safe-modes a module in CI);
   - runs guardrails, lint, the Retail and Forever smoke suites and the locale
     and manifest checks.
4. When anything changed, commits to `api-watch/<date>` and opens a PR into
   `main-v2` labelled `api-drift`; the PR body says whether every local check
   passed. The job itself never fails on a check, so the scheduled run stays
   green; the PR's own CI shows the real state.

What it cannot fix: an API Phoenix calls that Blizzard removed or changed.
That needs a code change; the drift check names the API and the owning module.

Run it locally the same way: `python3 .tools/autofix.py` (or `--stubs` to only
list the stubs it would add).
