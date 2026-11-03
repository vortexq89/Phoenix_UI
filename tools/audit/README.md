# tools/audit — API verification toolchain

Generates the luacheck std (`.luacheck/wow_std_12.1.5.lua`) that defines **every global that exists in the
Retail 12.1.5 client** and nothing else, so luacheck reports removed/renamed/invented APIs as W113/W143.

Inputs (clone once into `$PUI_REF`, default `/workspace/ref`):

| Dir | Source | Branch |
|---|---|---|
| `wow-ui-source/` | https://github.com/Gethe/wow-ui-source | `live` (must say `12.1.5 (70448)` or newer) |
| `bir/` | https://github.com/Ketho/BlizzardInterfaceResources | `live` |

Steps (repo root as cwd):

```bash
export PUI_REF=/workspace/ref
lua5.1 tools/audit/dump_api.lua $PUI_REF/wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated $PUI_REF/api_dump.tsv  # C API/events/enums + Secret* flags from Blizzard_APIDocumentationGenerated
python3 tools/audit/mainline_files.py                      # resolve files the *mainline* client loads (TOC + XML includes)
python3 tools/audit/gen_globals.py                         # -> $PUI_REF/wow_std_12.1.5.lua (+ json)
cp $PUI_REF/wow_std_12.1.5.lua .luacheck/
luacheck .                                                 # uses .luacheckrc
```

Audit-only extras (legacy code report):

```bash
luacheck --config $PUI_REF/audit.luacheckrc --formatter plain . | sed 's#^\./##' > $PUI_REF/luacheck_all.txt
python3 tools/audit/summarize.py && python3 tools/audit/gen_api_appendix.py   # -> docs/audit/API_FINDINGS.md
```

`.luacheck/deprecated_12.1.5.json` maps 371 names that only exist in `Blizzard_Deprecated*` (not loaded by default
since 12.1.5 / only with `loadDeprecationFallbacks`) to their replacement — treat them as **unavailable**.

Look up a single symbol quickly:

```bash
grep -P "\tC_Spell\.GetSpellInfo\t" $PUI_REF/api_dump.tsv          # exists? secret flags?
rg -n "SetTimerDuration" $PUI_REF/wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated
jq '.["GetSpellInfo"]' .luacheck/deprecated_12.1.5.json
```

Known limits: widget methods (`StatusBar:SetTimerDuration` …) are not in the std. Verify them in
`Blizzard_APIDocumentationGenerated/*APIDocumentation.lua`. Colour globals (`*_FONT_COLOR`) come from the C colour DB
and are whitelisted by pattern.

## WoW Forever (1.60.1)

The same scripts generate Forever's data when `PUI_FLAVOR=forever` (`tools/audit/flavor.py` picks the inputs,
the `[Game]` value `Camelot`, the game types that load, and the output names):

| Dir | Source | Branch |
|---|---|---|
| `wow-ui-source-forever/` | https://github.com/Gethe/wow-ui-source | `forever` (1.60.1 (70450) or newer) |
| `bir_forever/` | https://github.com/Ketho/BlizzardInterfaceResources | `forever` |

```bash
export PUI_REF=/workspace/ref PUI_FLAVOR=forever
lua5.1 tools/audit/dump_api.lua $PUI_REF/wow-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated $PUI_REF/api_dump_forever.tsv
python3 tools/audit/mainline_files.py                      # -> $PUI_REF/mainline_files_forever.txt
python3 tools/audit/gen_globals.py                         # -> $PUI_REF/wow_std_forever_1.60.1.lua
python3 tools/audit/gen_reference.py                       # -> .luacheck/reference_forever_1.60.1.json
cp $PUI_REF/wow_std_forever_1.60.1.lua .luacheck/
python3 tools/ids/refresh.py --flavor forever --ui-source $PUI_REF/wow-ui-source-forever --enum-source $PUI_REF/bir_forever
unset PUI_FLAVOR
python3 tools/check_flavors.py                             # every check, retail and Forever
```

`.luacheckrc` defines both stds (`wow`, `wowf`); `luacheck --std lua51+wowf .` checks against Forever.
`PUI_FLAVOR=forever` also switches `tools/check_api.py` and `tools/check_ids.py` to Forever's reference and ID
snapshot, and `lua5.1 tools/smoke/harness.lua . forever` boots the harness as a 16001 client.

