# Phoenix UI Constitution

## Core Principles

### I. EllesmereUI look, own code (NON-NEGOTIABLE)
The settings window, its controls, the theme, colours, borders and unit frames look and behave exactly like
EllesmereUI. The read-only reference is `I:\EllesmereUI*`, measured in docs/research/ELLESMERE_REBUILD_MAP.md and
AUDIT_T213.md. Every line of Lua is Phoenix's own: EllesmereUI code, or any other addon's code without an open
licence, is never copied. Only openly licensed code may be adapted, and it is credited. Logos, Ember-Bevel
class/spec/ability icons, the custom cursor, the raid-warning banner and a duplicate Teko font are never shipped.
The only Phoenix extra is the square phoenix portrait border on Player/Target, off by default and unwired until the
owner approves it.

### II. One theme, no duplicate features
There is one theme: EllesmereUI tokens with one accent (EllesmereUI green, class, or custom; #DCA77F by default on
Forever). No second accent, skin, preset or texture system. A feature exists in exactly one module and one place in
the GUI. Existing modules are extended rather than duplicated. A removed setting gets a migration step in
Core/Migrations.lua that tolerates any old data shape and runs on imported profiles.

### III. Retail and Forever
Every package loads on retail and WoW Forever through its own TOC. APIs missing on one client fall back to Phoenix's
own frames. The smoke harness, check_api and check_ids pass for both builds.

### IV. Live, safe runtime
Every setting applies live. There is no "reload to apply" text or footer, except a sim request, which needs a reload.
There is no OnUpdate outside the Ticker registry (use C_Timer). Secret values are passed to widgets and never
compared or used for arithmetic. Protected frames are not touched in combat. There are no slash commands: everything
is in the GUI. Phoenix Font is used everywhere.

### V. Permissive libraries only
Libraries are bundled only per docs/research/LIBRARIES.md: MIT, BSD, LGPL embedded, Unlicense, or other licences
that allow it, with the licence verified in the files. GPL and unlicensed sources are behaviour references only.
Other addons' media is used only where its licence allows.

### VI. Better than EllesmereUI, every plugin in full (owner t227)
The goal is not a copy of EllesmereUI. Phoenix must be of higher quality, more advanced, more user friendly and
simpler to use. Every feature of these sources is present in full and in the Phoenix style, in exactly one place:
EllesmereUI and all its modules; BugGrabber + BugSack; SimulationCraft; MoveAny (panels, not bars or unit frames);
BigWigs + LittleWigs and their plugins; AutoQueue (in the group finder); Premade Groups Filter;
MikScrollingBattleText; TrufiGCD; sArena Reloaded; Auctionator; idTip; Questie; RareScanner. The audit and the
priority order are in docs/research/PLUGIN_AUDIT/. Frame moving follows one model: Edit Mode owns its systems,
Phoenix Layout owns everything else, and there are no local mover modes.

### VII. One spec per feature, with the feature checklist (owner t229)
Work is spec-driven with GitHub Spec Kit: one spec folder per plugin, and inside large plugins one per feature
(for example each unit frame), never a bundled area spec. Each folder holds spec.md, plan.md, tasks.md and a
checklist.md copied from `.specify/templates/feature-checklist-template.md`. A feature is done only when every
checklist line is met with evidence: every option of the original addon; the basics and standards; configuration;
size, position and scale; editable colours, fonts and textures; a live preview; Layout support; profiles; live
apply; retail and Forever; 10 locales; edge cases; and the unmentioned gaps found by comparing with EllesmereUI and
Blizzard's own UI. specs/INDEX.md lists every spec with its status and the build order; nothing new is built
before its spec is in the index.

## Quality gates

- Every change has a CHANGES.md entry and a regenerated Core/Changelog.lua (tools/gen_changelog.py), and the plan
  docs are updated (docs/ROADMAP.md, the AUDIT/MAP status).
- Every new locale key is in all 10 locales. check_locales passes, with no unused or missing keys.
- luacheck, the smoke harness and prepush pass before a push, and CI must be green. There is never a force push, and
  main is never touched.
- Each behaviour change gets a harness check.
- The copyright notices "© 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF" are kept.
- Secrets (PHOENIX_* keys and `/home/box/.phoenix/secrets.env`) are never printed or committed.

## Development workflow

- Edit only in the PC repo (`restore/v1-ui`) and verify on the box mirror with prepush.
- Small commits, pushed as each one passes. After every fix commit, install with `tools\pc\install.ps1`, even while
  WoW is open. No input is ever sent to WoW.
- Only files you created yourself may be deleted. Ask before touching any folder outside the repository. `I:\` and
  the Blizzard source are read-only. Install only Phoenix_UI* folders. On the website, touch only `worker/phoenix/*`.
- Work follows Spec Kit: spec, then plan, then tasks under `specs/`, with the rebuild map's §8 build order.

## Governance

This constitution sums up the owner's standing rules and overrides any conflicting template or habit. Amendments
come only from the owner's instructions. Each one bumps the version (MAJOR: a rule removed or redefined; MINOR: a
rule added; PATCH: wording) and is noted in CHANGES.md. Every plan has a Constitution Check against Principles I–VII
and the gates before tasks are written.

**Version**: 1.2.0 | **Ratified**: 2026-11-01 | **Last Amended**: 2026-11-03
