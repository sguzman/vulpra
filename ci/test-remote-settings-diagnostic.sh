#!/usr/bin/env bash
# Offline fixtures for the packaged Remote Settings diagnostic: NO real browser.
set -Eeuo pipefail
script="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/diagnose-remote-settings-local.sh"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
repo="$work/repo"
stage="$work/stage/vulpra"
mkdir -p "$repo/ci" "$stage"
git -C "$repo" init -q
printf '#!/bin/sh\n' > "$repo/mach"
printf 'Name=Vulpra\n' > "$stage/application.ini"
cat > "$stage/vulpra-launch" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${MOZ_HEADLESS:-}" == 1 ]] || exit 13
[[ ! -v XRE_START_OFFLINE && ! -v MOZ_DISABLE_NONLOCAL_CONNECTIONS ]] || exit 14
[[ "$*" == '--headless about:blank' ]] || exit 15
[[ "$HOME" == /* && "$XDG_DATA_HOME" == "$HOME/.local/share" ]] || exit 16
mkdir -p "$XDG_DATA_HOME/vulpra/default"
printf '[Compatibility]\n' > "$XDG_DATA_HOME/vulpra/default/compatibility.ini"
case "${MOCK_MODE:-quiet}" in
  live) echo 'Remote Settings startup changesets bundle could not be extracted' >&2 ;;
  shutdown) trap 'echo "console.error: services.settings:" >&2; exit 0' TERM ;;
  crash) exit 7 ;;
esac
while :; do sleep 0.1 & wait "$!"; done
MOCK
chmod +x "$stage/vulpra-launch"
package="$repo/vulpra-local-fixture.tar.xz"
tar -cJf "$package" -C "$work/stage" .
(cd "$(dirname "$package")" && sha256sum "$(basename "$package")" > "$(basename "$package").sha256")
run() {
  local label="$1" mode="$2" expected="$3" needle="$4" status=0
  env XRE_START_OFFLINE=1 MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
    VULPRA_REMOTE_SETTINGS_SECONDS=1 MOCK_MODE="$mode" \
    bash "$script" "$repo" "$package" > "$work/$label.log" 2>&1 || status=$?
  [[ "$status" == "$expected" ]] && grep -Fq "$needle" "$work/$label.log" || {
    cat "$work/$label.log" >&2
    echo "FAIL: fixture $label returned $status, expected $expected or message '$needle'" >&2
    exit 1
  }
  echo "PASS: fixture $label"
}
run quiet quiet 0 'No Remote Settings errors during observation'
run shutdown shutdown 0 'Remote Settings errors occurred only AFTER controlled shutdown'
run live live 1 'Remote Settings errors occurred WHILE the browser was alive'
run crash crash 1 'Vulpra exited during the observation window'
printf '%064d  %s\n' 0 "$(basename "$package")" > "$package.sha256"
run bad-checksum quiet 4 'Invalid archive checksum'
echo 'PASS: Remote Settings diagnostic fixtures (no real browser or network).'
