#!/usr/bin/env bash
# CI ONLY: intentionally abort the *disposable original Vulpra parent browser*
# through original nsIDebug2 chrome XPCOM after authenticating its availability.
# Never run outside an isolated Arch docker container with --network none,
# an ephemeral HOME/profile, private Weston, and zero Linux capabilities.
set -euo pipefail
[[ $# == 2 && "$1" == /original/vulpra &&
   "$2" == /reports/m3-original-browser-crashreporter-exec.json ]] || exit 2
[[ "$MOZ_DISABLE_NONLOCAL_CONNECTIONS" == 1 &&
   "$VULPRA_M3_DISPOSABLE_FATAL_ABORT" == 1 &&
   "$VULPRA_OFFLINE_CONTAINER_ONLY" == 1 ]] || exit 2
[[ "$(cat /proc/self/status | awk '/^CapEff:/ {print $2}')" == 0000000000000000 ]] || exit 2
[[ "$(cat /proc/self/status | awk '/^CapPrm:/ {print $2}')" == 0000000000000000 ]] || exit 2
[[ -x /audit/crashreporter-witness && -x "$1" && -x /original/crashreporter &&
   ! -e /tmp/vulpra-m3-fatal-abort-triggered ]] || exit 2
for app in geckodriver weston wayland-info curl jq; do command -v "$app" >/dev/null || exit 2; done

work="$(mktemp -d /tmp/vulpra-m3-crash-witness.XXXXXX)"
export HOME="$work/home" XDG_DATA_HOME="$work/data" XDG_RUNTIME_DIR="$work/runtime"
export XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-vulpra-crash-m3
export GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1
export MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1 XRE_START_OFFLINE=1
export MOZ_CRASHREPORTER=1
# No installed browser, permanent profile, external network or crash submission.
# This explicit lack of NO_REPORT is necessary to test the reporter-launch path.
unset MOZ_CRASHREPORTER_DISABLE MOZ_CRASHREPORTER_NO_REPORT MOZ_HEADLESS DISPLAY
mkdir -m 0700 "$HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
driver_pid='' observer_pid='' weston_pid='' session='' triggered=0
base=http://127.0.0.1:4444
api() {
  local method="$1" path="$2" data="$3"
  curl --noproxy '*' -sS --max-time 12 -X "$method" \
    -H 'Content-Type: application/json' -d "$data" "$base$path"
}
cleanup() {
  if [[ "$triggered" == 0 && -n "$session" ]]; then
    api DELETE "/session/$session" '{}' >/dev/null 2>&1 || true
  fi
  for pid in "$driver_pid" "$weston_pid" "$observer_pid"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  rm -rf -- "$work"
}
trap cleanup EXIT
weston --backend=headless-backend.so --renderer=pixman --idle-time=0 \
  --socket="$WAYLAND_DISPLAY" --log="$work/weston.log" \
  >"$work/weston.stdout" 2>&1 &
weston_pid=$!
ready=false
for _ in {1..40}; do
  if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then ready=true; break; fi
  kill -0 "$weston_pid" 2>/dev/null || exit 1
  sleep 0.25
done
[[ "$ready" == true ]] || { echo 'Private Weston did not start' >&2; exit 1; }
wayland-info >"$work/wayland-info.log" 2>&1
grep -Fq xdg_wm_base "$work/wayland-info.log" || exit 1

/audit/crashreporter-witness /tmp/vulpra-m3-fatal-abort-triggered "$2" \
  >"$work/witness.log" 2>&1 &
observer_pid=$!
geckodriver --host 127.0.0.1 --port 4444 --log error \
  >"$work/driver.log" 2>&1 &
driver_pid=$!
ready=false
for _ in {1..50}; do
  if api GET /status '{}' 2>/dev/null | jq -e '.value.ready==true' >/dev/null 2>&1; then
    ready=true; break
  fi
  kill -0 "$driver_pid" 2>/dev/null || exit 1
  sleep 0.3
done
[[ "$ready" == true ]] || { echo 'Local original browser WebDriver unavailable' >&2; exit 1; }
caps="$(jq -nc --arg bin "$1" '{
  capabilities:{alwaysMatch:{browserName:"firefox",
    "moz:firefoxOptions":{binary:$bin,args:["--no-remote","--new-instance"],
     prefs:{"browser.shell.checkDefaultBrowser":false}}}}
}')"
resp="$(api POST /session "$caps")"
session="$(jq -er '.value.sessionId // .sessionId' <<<"$resp")" || {
  echo 'Original Vulpra browser WebDriver launch failed' >&2; exit 1;
}
chrome="$(api POST "/session/$session/moz/context" '{"context":"chrome"}')"
jq -e '.value==null or .value=="chrome"' <<<"$chrome" >/dev/null || exit 1
# Query only the actual original browser's privileged XPCOM contract.
preflight='const d=Components.classes["@mozilla.org/xpcom/debug;1"].getService(Components.interfaces.nsIDebug2);return typeof d.abort;'
pre="$(api POST "/session/$session/execute/sync" \
  "$(jq -nc --arg script "$preflight" '{script:$script,args:[]}')")"
jq -e '.value=="function"' <<<"$pre" >/dev/null || {
  echo 'Original browser fatal-abort API unavailable; refusing unverified crash route' >&2; exit 1;
}
kill -0 "$observer_pid" 2>/dev/null || {
  echo 'Original reporter witness exited before trigger' >&2; exit 1;
}
# Marker tells the independent observer no reporter could have existed
# before the real verified chrome-context fatal-abort request.
touch /tmp/vulpra-m3-fatal-abort-triggered
triggered=1
fatal='const d=Components.classes["@mozilla.org/xpcom/debug;1"].getService(Components.interfaces.nsIDebug2);d.abort("vulpra-private-original-browser-CI-only",1);return "UNREACHABLE";'
# The original process is supposed to die before returning an HTTP response;
# never treat the WebDriver disconnection itself as proof of reporter launch.
set +e
api POST "/session/$session/execute/sync" \
  "$(jq -nc --arg script "$fatal" '{script:$script,args:[]}')" \
  >"$work/abort-webdriver-response.json" 2>"$work/abort-curl.stderr"
set -e
if [[ -r "$work/abort-webdriver-response.json" ]] &&
   jq -e '.value=="UNREACHABLE"' "$work/abort-webdriver-response.json" >/dev/null 2>&1; then
  echo 'Fatal original browser abort unexpectedly returned' >&2
  exit 1
fi
# Real /proc witness verifies both the original parent process went away and
# original /original/crashreporter executed with its sole .dmp argument.
if ! wait "$observer_pid"; then
  echo 'Original parent crash did not produce an observed original reporter ELF' >&2
  # Only the fixed-prefix diagnostic with safe booleans and event counts:
  # never print raw browser/WebDriver logs, crash files, PIDs or argv.
  grep '^M3_ORIGINAL_CRASHREPORTER_WITNESS_FAILURE=' "$work/witness.log" >&2 || true
  # The WebDriver result can distinguish a fatal process disconnect from a
  # rejected privileged XPCOM call, without exporting its exception contents.
  if [[ -s "$work/abort-webdriver-response.json" ]]; then
    if jq -e '.value.error' "$work/abort-webdriver-response.json" >/dev/null 2>&1; then
      echo 'M3_ORIGINAL_ABORT_HTTP_RESULT=webdriver_error' >&2
    elif jq -e '.value=="UNREACHABLE"' "$work/abort-webdriver-response.json" >/dev/null 2>&1; then
      echo 'M3_ORIGINAL_ABORT_HTTP_RESULT=unexpected_return' >&2
    else
      echo 'M3_ORIGINAL_ABORT_HTTP_RESULT=other' >&2
    fi
  else
    echo 'M3_ORIGINAL_ABORT_HTTP_RESULT=no_body' >&2
  fi
  exit 1
fi
observer_pid=''
test -s "$2"
[[ ! -e "$HOME/.mozilla" ]] || {
  echo 'Isolated original Vulpra unexpectedly wrote to Firefox profile' >&2
  exit 1
}
echo 'PASS: original browser chrome fatal abort spawned real packaged crashreporter, no network and no user profile'
