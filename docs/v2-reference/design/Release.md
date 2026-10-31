# Release pipeline (PUI_V2 12, 17.2, 20.6)

`.github/workflows/release.yml` runs only from a manual `workflow_dispatch`; merging never triggers it. Default is a dry run: guardrails, manifest check, harness (retail + Forever), release tool tests, `changelog.py` (merged PRs since the last tag; fails on a scope that is not a module in Data/SchemaIndex.lua), `releases.py` (releases.json with latest stable/canary, history, supported builds), `site_features.py` (feature list from the module registry and schema), and a packager build without upload, all as artifacts. Publishing needs `publish=true` and the version typed again: it tags, packages and uploads, attaches releases.json/CHANGELOG.md/features.json, and posts the release record to /phoenix/api/release.

## Phase 6: public beta packaging and the exact publish steps

Packaging is ready: `.pkgmeta` moves all 23 child folders, uses the generated `CHANGELOG.md` as the manual changelog, and leaves out tooling, docs, the API catalog, the companion and `Phoenix_UI_Locales/keys.txt`. Every TOC carries `X-License: All Rights Reserved (source-visible)` and the website. The publish job refuses to run unless the CurseForge/Wago project ids (repository variables) and API keys (release environment secrets) all exist, and passes the ids to the packager (`-p`/`-w`). Release type follows the tag: `v3.0.0-beta1` is a beta, `-alpha` an alpha, a plain version a release.

Nothing has been published, tagged or released. To publish the public beta (owner only):

1. Merge the stacked PRs in order (#4, #5, #6, #7, then the Phase 6 PR) into `main-v2`, each with CI green.
2. Create the listings under the VortexQ8 account only: CurseForge project "Phoenix UI" (licence: All Rights Reserved) and Wago project "Phoenix UI". Note both project ids.
3. GitHub repo settings: Variables -> `CF_PROJECT_ID`, `WAGO_PROJECT_ID`. Environments -> create `release` (add yourself as required reviewer) with secrets `CF_API_KEY` (CurseForge API token) and `WAGO_API_TOKEN` (Wago addons token). `PHOENIX_INGEST_KEY` there too if the release should be recorded on vq8s.com.
4. Actions -> release -> Run workflow on `main-v2` with version `3.0.0-beta1`, track `canary`, publish OFF. Check the artifact: zip contents, CHANGELOG.md, releases.json, features.json.
5. Run again with publish ON and confirm `3.0.0-beta1`. Approve the `release` environment when asked. The job tags `v3.0.0-beta1`, uploads to CurseForge, Wago and GitHub Releases as a beta, attaches releases.json/CHANGELOG.md/features.json and posts the record to `/phoenix/api/release`.
6. Website: merge the website PRs and deploy as usual so /phoenix-ui/changelog and /status read the new releases.json.
