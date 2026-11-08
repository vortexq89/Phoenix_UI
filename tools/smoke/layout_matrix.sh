#!/usr/bin/env bash
# Layout matrix for the settings window (GUI polish plan §5): writes the scenes of every page and tab
# (tools/smoke/shot.lua) for each window size, font scale and language below, then runs tools/smoke/layout_lint.py
# on each set. Slow (several minutes per set), so it is not part of tools/prepush.sh; run it after GUI changes.
#   tools/smoke/layout_matrix.sh [out dir] [--quick]     --quick: default size and enUS only
#   LAYOUT_RENDER=1 also writes a contact sheet of every set (tools/smoke/contact_sheet.py)
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
out="${1:-/tmp/pui_layout}"
mkdir -p "$out"
python3 tools/smoke/shot_metrics.py "$out/metrics.lua" >/dev/null || exit 1
sets=("1300x946 1 enUS")
if [ "${2:-}" != "--quick" ]; then
    sets+=("1100x700 1 enUS" "1300x946 1.3 enUS" "1100x700 1 deDE" "1100x700 1 frFR" "1100x700 1 ruRU" "1300x946 1 esES")
fi
fail=0
for s in "${sets[@]}"; do
    read -r size scale loc <<<"$s"
    dir="$out/${loc}_${size}_x${scale}"
    rm -rf "$dir"; mkdir -p "$dir"
    PUI_SHOT_OUT="$dir" PUI_SHOT_PAGES=ALL PUI_SHOT_SIZE="$size" PUI_SHOT_FONTSCALE="$scale" PUI_SHOT_LOCALE="$loc" \
        PUI_SHOT_METRICS="$out/metrics.lua" lua5.1 tools/smoke/harness.lua . >"$dir.log" 2>&1
    printf '== %s %s font x%s\n' "$loc" "$size" "$scale"
    python3 tools/smoke/layout_lint.py "$dir" --strict | tail -n 25 || fail=1
    if [ "${LAYOUT_RENDER:-}" = "1" ]; then python3 tools/smoke/contact_sheet.py "$dir" "$dir.sheets" >/dev/null; fi
done
exit $fail
