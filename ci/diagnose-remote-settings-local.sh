#!/usr/bin/env bash
# Observe Remote Settings online BEFORE terminating an isolated packaged Vulpra.
# No rebuild, installation, preference changes, or access to Firefox profiles.
set -Eeuo pipefail
repo="${1:-$HOME/Code/Apps/vulpra}"
cd "$repo" || { echo 'ERROR: Vulpra checkout missing.' >&2; exit 2; }
[[ -f mach ]] || { echo 'ERROR: Not a Vulpra checkout.' >&2; exit 2; }
duration="${VULPRA_REMOTE_SETTINGS_SECONDS:-45}"
[[ "$duration" =~ ^[1-9][0-9]{0,2}$ ]] && ((duration <= 180)) || {
  echo 'ERROR: VULPRA_REMOTE_SETTINGS_SECONDS must be 1..180.' >&2; exit 2;
}
logdir="$(git rev-parse --path-format=absolute --git-path vulpra-native-build)"
archive="${2:-}"
if [[ -z "$archive" ]]; then
  packages="$logdir/packages"
  [[ -d "$packages" ]] || { echo 'ERROR: No staged packages.' >&2; exit 4; }
  mapfile -d '' -t archives < <(
    find "$packages" -maxdepth 1 -type f -name 'vulpra-local-*.tar.xz' -printf '%T@ %p\0' |
      sort -zrn | cut -z -d ' ' -f2-
  )
  ((${#archives[@]} > 0)) || { echo 'ERROR: No staged package. Run package smoke first.' >&2; exit 4; }
  archive="${archives[0]}"
fi
archive="$(realpath -e -- "$archive")"
[[ -f "$archive.sha256" ]] || { echo 'ERROR: Missing checksum sidecar.' >&2; exit 4; }
(cd "$(dirname "$archive")" && sha256sum --check -- "$(basename "$archive").sha256") || {
  echo 'ERROR: Invalid archive checksum.' >&2; exit 4;
}
work="$(mktemp -d)"
browser_pid=""
cleanup() {
  if [[ -n "$browser_pid" ]]; then
    kill -TERM "$browser_pid" 2>/dev/null || true
    for _ in {1..20}; do kill -0 "$browser_pid" 2>/dev/null || break; sleep 0.1; done
    kill -KILL "$browser_pid" 2>/dev/null || true
    wait "$browser_pid" 2>/dev/null || true
  fi
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -p -m 0700 "$work/home" "$work/package"
tar -xf "$archive" -C "$work/package"
mapfile -d '' -t inis < <(find "$work/package" -mindepth 1 -maxdepth 4 -type f -name application.ini -print0)
((${#inis[@]} == 1)) || { echo 'ERROR: Expected one application.ini.' >&2; exit 4; }
appdir="$(dirname "${inis[0]}")"
[[ -x "$appdir/vulpra-launch" ]] && grep -Fxq 'Name=Vulpra' "$appdir/application.ini" || {
  echo 'ERROR: Private launcher or Vulpra identity missing.' >&2; exit 4;
}
mkdir -p "$logdir"
stamp="$(date +%Y%m%d-%H%M%S-%N)"
live_log="$logdir/remote-settings-live-$stamp.log"
full_log="$logdir/remote-settings-full-$stamp.log"
profile="$work/home/.local/share/vulpra/default"
echo "Remote Settings sustained online startup ($duration seconds)"
echo "Verified archive: $archive"
# Ensure caller's offline QA flags do not silently invalidate online evidence.
# No TLS, proxy, root, endpoint or security preference overrides.
env -u XRE_START_OFFLINE -u MOZ_DISABLE_NONLOCAL_CONNECTIONS \
  HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" MOZ_HEADLESS=1 \
  "$appdir/vulpra-launch" --headless about:blank > "$work/browser.log" 2>&1 &
browser_pid="$!"
sleep "$duration"
if ! kill -0 "$browser_pid" 2>/dev/null; then
  rc=0; wait "$browser_pid" || rc="$?"
  browser_pid=""
  cp -- "$work/browser.log" "$full_log"
  echo "FAIL: Vulpra exited during the observation window (exit $rc). Log: $full_log" >&2
  exit 1
fi
if [[ ! -s "$profile/compatibility.ini" || -e "$work/home/.mozilla" ]]; then
  cp -- "$work/browser.log" "$full_log"
  echo "FAIL: Missing isolated profile or unexpected Firefox profile. Log: $full_log" >&2
  exit 1
fi
cp -- "$work/browser.log" "$live_log" # The critical PRE-shutdown boundary.
kill -TERM "$browser_pid" 2>/dev/null || true
for _ in {1..30}; do kill -0 "$browser_pid" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$browser_pid" 2>/dev/null; then kill -KILL "$browser_pid" 2>/dev/null || true; fi
wait "$browser_pid" 2>/dev/null || true
browser_pid=""
cp -- "$work/browser.log" "$full_log"
pattern='Remote Settings startup changesets bundle could not be extracted'
if grep -Fq "$pattern" "$live_log" || grep -Fq 'console.error: services.settings:' "$live_log"; then
  echo 'FAIL: Remote Settings errors occurred WHILE the browser was alive.' >&2
  printf 'Live log: %s\nFull log: %s\n' "$live_log" "$full_log" >&2
  exit 1
fi
if grep -Fq "$pattern" "$full_log" || grep -Fq 'console.error: services.settings:' "$full_log"; then
  echo 'OBSERVED: Remote Settings errors occurred only AFTER controlled shutdown.'
else
  echo 'OBSERVED: No Remote Settings errors during observation or shutdown.'
fi
printf 'PASS: %ss online startup, isolated profile, no live Remote Settings errors.\n' "$duration"
echo 'LIMIT: This does not prove successful sync or TLS reachability.'
printf 'Live log: %s\nFull log: %s\n' "$live_log" "$full_log"
