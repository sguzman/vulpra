#!/usr/bin/env bash
# Offline safety fixtures; synthetic browser only, never reads real profiles.
set -Eeuo pipefail
umask 077
die() { echo "FAIL: $*" >&2; exit 1; }
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash -n "$root/scripts/vulpra-security-qa.sh"
bash -n "$root/nix/vulpra"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
repo="$work/vulpra"
qa="$work/vulpra-security-qa"
mkdir -p "$repo/scripts" "$repo/nix" "$repo/browser/config" \
  "$repo/obj-vulpra-main-160/dist/bin" "$work/home/.mozilla/firefox" \
  "$work/home/.local/share/vulpra/default" "$work/bin"
cp -- "$root/scripts/vulpra-security-qa.sh" "$repo/scripts/vulpra-security-qa.sh"
cp -- "$root/nix/vulpra" "$repo/nix/vulpra"
printf '# Vulpra synthetic fixture\n' > "$repo/AGENTS.md"
printf '160.0.1\n' > "$repo/browser/config/version.txt"
printf '/obj*/\n' > "$repo/.gitignore"
printf 'Firefox sentinel\n' > "$work/home/.mozilla/firefox/sentinel"
printf 'Dogfood sentinel\n' > "$work/home/.local/share/vulpra/default/sentinel"
cat > "$repo/obj-vulpra-main-160/dist/bin/application.ini" <<'INI'
[App]
Name=Vulpra
Version=160.0.1
INI
cat > "$repo/obj-vulpra-main-160/dist/bin/vulpra" <<'BROWSER'
#!/usr/bin/env bash
# Test-only browser substitute, producing a valid PNG header.
set -Eeuo pipefail
[[ "$MOZ_HEADLESS" == 1 ]] || exit 90
screen=""
profile=""
while (($#)); do
  case "$1" in
    --screenshot) screen="$2"; shift 2 ;;
    --profile) profile="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$screen" && -d "$profile" ]] || exit 91
printf '%s\n' "$HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" \
  "$XDG_CONFIG_HOME" "$profile" > "$HOME/env-proof"
printf '\211PNG\r\n\032\n' > "$screen"
BROWSER
chmod 0755 "$repo/obj-vulpra-main-160/dist/bin/vulpra"
# Ensure no Nix/nom use in any QA command.
for name in nix nom; do
  cat > "$work/bin/$name" <<'NO_NIX'
#!/usr/bin/env bash
echo 'ERROR: security QA unexpectedly entered Nix/nom' >&2
exit 99
NO_NIX
  chmod 0755 "$work/bin/$name"
done
git -C "$repo" init -q -b main
git -C "$repo" add .
git -C "$repo" -c user.name='QA Fixture' \
  -c user.email='qa-fixture@example.invalid' commit -qm 'synthetic source'
original="$(git -C "$repo" rev-parse HEAD)"
export HOME="$work/home" PATH="$work/bin:$PATH"
bash "$repo/nix/vulpra" security-qa status > "$work/status"
grep -Fq 'QA worktree: not set up' "$work/status"
if bash "$repo/nix/vulpra" security-qa headless >/dev/null 2>&1; then
  die 'headless ran before setup'
fi
bash "$repo/nix/vulpra" security-qa setup > "$work/setup"
[[ -f "$qa/.git" ]] || die 'registered QA Git worktree missing'
[[ "$(git -C "$qa" rev-parse HEAD)" == "$original" ]] ||
  die 'QA pinned to wrong commit'
[[ -z "$(git -C "$qa" symbolic-ref --short -q HEAD || :)" ]] ||
  die 'QA should be detached, not main'
if bash "$repo/nix/vulpra" security-qa setup >/dev/null 2>&1; then
  die 'duplicate setup unexpectedly overwrote a worktree'
fi
bash "$repo/nix/vulpra" security-qa snapshot > "$work/snapshot"
name="$(cat "$qa/obj-vulpra-security-qa/active-snapshot")"
[[ "$name" =~ ^[0-9a-f]{12}-[0-9a-f]{12}$ ]] || die 'invalid snapshot identifier'
app="$qa/obj-vulpra-security-qa/snapshots/$name/app/vulpra"
[[ -x "$app" ]] || die 'snapshot executable missing'
cmp "$app" "$repo/obj-vulpra-main-160/dist/bin/vulpra"
if bash "$repo/nix/vulpra" security-qa snapshot >/dev/null 2>&1; then
  die 'duplicate snapshot unexpectedly overwrote files'
fi
bash "$repo/nix/vulpra" security-qa headless > "$work/out"
grep -Fq 'PASS: isolated Vulpra QA headless screenshot' "$work/out"
shopt -s nullglob
runs=("$qa/obj-vulpra-security-qa/runtime"/run.*)
[[ "${#runs[@]}" -eq 1 ]] || die 'unexpected QA run count'
run="${runs[0]}"
mapfile -t proof < "$run/home/env-proof"
[[ "${proof[0]}" == "$run/home" && "${proof[1]}" == "$run/data" &&
   "${proof[2]}" == "$run/cache" && "${proof[3]}" == "$run/config" &&
   "${proof[4]}" == "$run/profile" ]] ||
  die 'browser environment escaped disposable QA paths'
[[ "$(git -C "$repo" rev-parse HEAD)" == "$original" &&
   "$(git -C "$repo" symbolic-ref --short HEAD)" == main ]] ||
  die 'daily main source branch altered'
grep -Fxq 'Firefox sentinel' "$work/home/.mozilla/firefox/sentinel"
grep -Fxq 'Dogfood sentinel' "$work/home/.local/share/vulpra/default/sentinel"
if bash "$repo/nix/vulpra" security-qa headless --profile \
  "$work/home/.mozilla/firefox" >/dev/null 2>&1; then
  die 'QA accepted profile override'
fi
echo 'PASS: detached QA source, checksum copied browser, private HOME/XDG/profile and test screenshot'
echo 'PASS: daily main + Firefox/Vulpra sentinels unchanged; duplicate writes rejected'
echo 'LIMIT: synthetic executable, not an actual Gecko browser security result'
