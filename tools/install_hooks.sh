#!/usr/bin/env bash
# Installs the pre-push hook. With Lua tools present it runs the full guard; without them (the Windows PC) it
# only lets through commits that carry the passing note written by tools/prepush.sh.
cd "$(git rev-parse --show-toplevel)" || exit 1
hook=.git/hooks/pre-push
cat > "$hook" <<'H'
#!/usr/bin/env bash
cd "$(git rev-parse --show-toplevel)" || exit 1
shas=()
while read -r lref lsha rref rsha; do
    [ "$lsha" = "0000000000000000000000000000000000000000" ] && continue
    case "$rref" in refs/notes/*) continue ;; esac
    if [ "$rsha" = "0000000000000000000000000000000000000000" ]; then shas+=("$lsha")
    else while read -r s; do shas+=("$s"); done < <(git rev-list "$rsha..$lsha"); fi
done
[ ${#shas[@]} -eq 0 ] && exit 0
if command -v lua5.1 >/dev/null && command -v luacheck >/dev/null && [ "$(git rev-parse HEAD)" = "${shas[0]}" ]; then
    tools/prepush.sh || exit 1
fi
# every pushed commit's tip must be checked: verify the newest one (the tree that CI builds)
exec tools/prepush.sh --verify "${shas[0]}"
H
chmod +x "$hook"
echo "installed $hook"
