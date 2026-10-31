# Reusable prompts

Copy a prompt, fill in the `<…>` parts and paste it to the agent. Every prompt assumes the agent has read
`AGENTS.md`, `docs/ARCHITECTURE.md` and the `.cursor/rules`. Keep the "Definition of done" lines. They are what makes the output reviewable.

---

## 1. New feature

```
Implement <feature> for Phoenix_UI (WoW Retail 12.1.5, TOC 120105).

Context: read AGENTS.md, docs/ARCHITECTURE.md (§2.1 module set, §4 module contract, §7/§11 theme) and
.cursor/rules. Legacy behaviour (if any) is described in docs/AUDIT.md → <module row>; the legacy code is in git
history at a2c69a9:<path> — use it only as a feature reference, never copy it.

Steps:
1. Check whether Blizzard 12.1.5 already provides this (Edit Mode, Cooldown Manager, damage meter, boss timeline,
   nameplate/unit-frame options). If yes, propose skinning/configuring it instead and stop for confirmation.
2. List every Blizzard API/event/template/mixin you will use and verify each in wow-ui-source live
   (Blizzard_APIDocumentationGenerated or mainline FrameXML). Quote the doc file + Secret* flags for each.
   If any required value is secret in the situations the feature runs in, explain the display-only approach
   or state that the feature cannot be built.
3. Put it in the owning module (<module>) or create Modules/<Key>/ from the AGENTS.md §5 template.
4. Defaults + Options.lua schema + Locales/enUS.lua keys. No option widgets in module code.
5. Use ns.Events / ns.Combat / ns.Secret / ns.Skin / ns.Theme; no new event frames, no literals for colours/fonts.

Definition of done:
- luacheck . = 0 warnings; forbidden-pattern rg check empty (lint-testing.mdc)
- toggling the module/setting live works and fully reverts
- no globals, no writes to Blizzard tables, protected work queued out of combat
- in-game test steps written out for me (incl. which secret*RestrictionsForced CVars to try)
- one focused commit "<module>: <summary>", not pushed
```

## 2. Bug fix

```
Fix this Phoenix_UI bug (WoW Retail 12.1.5):

Symptom: <what happens>
Error / stack (BugSack or /console scriptErrors 1):
<paste>
Repro: <steps, zone/instance type, in combat?, which modules enabled>
Taint log (if "action blocked"): <relevant Logs/taint.log lines>

Do:
1. Find the root cause and explain it in 2–5 sentences. Say which category it is: removed/renamed API, secret value
   misuse, taint, combat lockdown, nil/state bug, load order, or a duplicate implementation.
2. Verify any API you touch against wow-ui-source live (cite the file). Don't guess signatures.
3. Fix the cause, not the symptom: no pcall-wrapping, no "if x then" guards that hide a contract violation, no
   InCombatLockdown early-return that silently drops the change (queue it with ns.Combat:Run instead).
4. Search for the same pattern elsewhere (rg) and fix every instance in the same commit.

Definition of done: luacheck clean; the exact repro steps now pass; a regression check added to the in-game
checklist if it's a new class of bug; one commit "fix(<module>): <summary>", not pushed.
```

## 3. Code review

```
Review <branch/commit range/files> of Phoenix_UI against AGENTS.md §3 and .cursor/rules. Report findings as a
table: severity (blocker/major/minor/nit) | file:line | rule | problem | concrete fix.

Check specifically:
- APIs: every Blizzard call exists in 12.1.5 mainline (luacheck + doc lookup for widget methods); nothing from
  Blizzard_Deprecated*; signatures/returns match the docs (tables vs multiple returns).
- Secrets: any arithmetic/comparison/boolean test/#/table-key on values that may be secret (list the API's Secret*
  flag); chat filters early-out on issecretvalue; no secrets written to the DB.
- Taint: assignments to Blizzard globals/fields, SetScript on Blizzard frames, protected calls in combat, moving
  Edit-Mode-managed frames, SetCooldown on protected cooldowns.
- Architecture: globals, private event frames, duplicated helpers/widgets (search Core/ and UI/ for equivalents),
  options built outside the schema, hard-coded colours/fonts/sizes, missing locale keys, irreversible OnDisable.
- Performance: OnUpdate without need, per-frame allocations, un-throttled UNIT_* handlers, unpooled frames.
- Load order / TOC / XML case-exactness, orphan files.

Finish with: verdict (approve / changes required) and the 3 most important fixes. Don't modify files unless I ask.
```

## 4. API update (new WoW patch)

```
WoW patch <X.Y.Z> (build <NNNNN>) is live. Update Phoenix_UI.

1. Confirm the build on wago.tools (branch "wow") and that Gethe/wow-ui-source "live" says <X.Y.Z (NNNNN)>.
   Read https://warcraft.wiki.gg/wiki/Patch_<X.Y.Z>/API_changes and the API change summaries page. Note
   every removed/renamed API, new Secret*/restriction, forbidden aspect, CVar change and template change.
2. Refresh $PUI_REF checkouts, re-run tools/audit (README there), and copy the new std into .luacheck/
   (rename to wow_std_<X.Y.Z>.lua and update .luacheckrc + tools references).
3. Bump "## Interface:" to the new number (single value).
4. luacheck . and fix every new W113/W143. For each behaviour change lint can't see (secrets, aspects, events
   that changed payload), grep our code and fix or document why it's unaffected.
5. Update AGENTS.md §1 table, docs/ARCHITECTURE.md header, .cursor/rules/00-project.mdc and
   midnight-secrets.mdc if the restriction model changed.

Deliver: a summary table (change | affected files | action taken), luacheck clean, one commit
"chore(api): update to <X.Y.Z>", not pushed. List anything that needs in-game confirmation.
```

## 5. Port a legacy feature (rework phase)

```
Port legacy feature "<feature>" (docs/AUDIT.md row: <module>, verdict <KEEP/REWRITE/MERGE>) to the new
architecture. Legacy reference: `git show a2c69a9:<path>` (read only, don't copy code).
Write it fresh following prompt #1 (New feature). Also add the legacy SavedVariables keys for this feature to the
migration map in Core/Migrations.lua (old path → new path, with value transforms), and list the legacy options you
deliberately dropped and why.
```

## 6. Skin a Blizzard window

```
Add/repair the Phoenix theme skin for Blizzard "<window>" (addon <Blizzard_X>, mixin <XMixin>).
1. Locate the frame in wow-ui-source live mainline: list its parentKeys/regions you'll touch (NineSlice, Bg,
   TitleContainer, Inset, tabs, scroll bars). Don't use removed global names (see docs/audit/API_FINDINGS.md "Removed
   Blizzard frames").
2. Skin lazily with EventUtil.ContinueOnAddOnLoaded("<Blizzard_X>", …) through ns.Skin primitives only.
3. Must be reversible (ns.Skin:Restore) and re-apply on PUI_THEME_CHANGED. No taint: no SetScript, no field writes,
   no protected layout calls.
Done = luacheck clean + screenshot checklist (open, tab through, resize, close; theme switch while open).
```
