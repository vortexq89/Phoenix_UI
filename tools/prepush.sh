#!/usr/bin/env bash
# Pre-push guard: runs exactly the steps of .github/workflows/luacheck.yml and fails on the first problem.
# On success it records a git note (ref: prepush) on HEAD, so a machine without Lua (the hook in --verify mode)
# can still refuse commits that were never checked.
#   tools/prepush.sh            run every check (needs lua5.1, luac5.1, luacheck, python3)
#   tools/prepush.sh --verify   only check that every commit being pushed carries a passing note
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

if [ "${1:-}" = "--verify" ]; then
    shift
    bad=0
    for sha in "$@"; do
        if [ "$(git notes --ref=prepush show "$sha" 2>/dev/null)" != "ok" ]; then
            echo "prepush: $sha has no passing check note - run tools/prepush.sh where Lua is installed"; bad=1
        fi
    done
    exit $bad
fi

fail=0
step() {
    local name="$1"; shift
    printf '== %s\n' "$name"
    local out
    if ! out=$("$@" 2>&1); then printf '%s\nFAILED: %s\n' "$out" "$name"; fail=1; return; fi
    printf '%s\n' "$out" | tail -n 2
}
need() { command -v "$1" >/dev/null 2>&1 || { echo "prepush: '$1' not found"; exit 2; }; }
need lua5.1; need luac5.1; need luacheck; need python3

syntax() {
    local bad=0
    while IFS= read -r f; do luac5.1 -p "$f" || bad=1; done < <(git ls-files '*.lua'; git ls-files -o --exclude-standard '*.lua')
    return $bad
}
harness() { # the harness prints problems but must also end with "0 errors"
    local out; out=$(lua5.1 tools/smoke/harness.lua . "$@" 2>&1) || { echo "$out" | tail -n 20; return 1; }
    echo "$out" | tail -n 3
    echo "$out" | grep -q ", 0 errors" || return 1
}

step "syntax" syntax
step "luacheck retail (12.1.5 std)" luacheck . --formatter plain
step "check_api retail" python3 tools/check_api.py
step "check_ids retail" python3 tools/check_ids.py
step "check_locales" python3 tools/check_locales.py
step "harness retail" harness
step "harness core alone (no plugin folders)" env PUI_NOPLUGINS=1 lua5.1 tools/smoke/harness.lua .
step "luacheck forever (1.60.1 std)" luacheck . --std lua51+wowf --formatter plain
step "check_api forever" env PUI_FLAVOR=forever python3 tools/check_api.py
step "check_ids forever" env PUI_FLAVOR=forever python3 tools/check_ids.py
step "harness forever" harness forever

if [ $fail -ne 0 ]; then echo "prepush: FAILED - push blocked"; exit 1; fi
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "prepush: passed, but the work tree has uncommitted changes - no note written"; exit 0
fi
if ! git notes --ref=prepush add -f -m ok HEAD >/dev/null; then echo "prepush: passed, but the note could not be written (git user.name/email?)"; exit 1; fi
echo "prepush: all checks passed for $(git rev-parse --short HEAD)"
