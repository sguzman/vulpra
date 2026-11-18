#!/usr/bin/env bash
# Offline end-to-end fixture. The fake WebDriver never starts a browser.
set -Eeuo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
work="$(mktemp -d)"
socket_pid=""
cleanup() {
  [[ -z "$socket_pid" ]] || { kill "$socket_pid" 2>/dev/null || true; wait "$socket_pid" 2>/dev/null || true; }
  rm -rf -- "$work"
}
trap cleanup EXIT
# Fixture-only diagnostics; work contains no live profile, secrets or browser.
on_error() {
  status=$?
  printf 'FAIL: mock input-frame fixture line %s (exit %s): %s\n' "$1" "$status" "$2" >&2
  if [[ -f "$work/out" ]]; then tail -n 18 "$work/out" >&2; fi
  if [[ -f "$work/gui-out" ]]; then tail -n 18 "$work/gui-out" >&2; fi
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR
repo="$work/repo"
bin="$work/bin"
mkdir -p "$repo/ci/fixtures" "$bin" "$work/pkg/vulpra"
git -C "$repo" init -q
printf 'mock mach\n' > "$repo/mach"
cp "$here/fixtures/input-to-raf.html" "$repo/ci/fixtures/input-to-raf.html"
printf 'Name=Vulpra\n' > "$work/pkg/vulpra/application.ini"
printf '\177ELFfake-binary-not-executed\n' > "$work/pkg/vulpra/vulpra"
chmod +x "$work/pkg/vulpra/vulpra"
git -C "$repo" add mach ci
git -C "$repo" -c user.name=QA -c user.email=qa@example.invalid commit -qm 'isolated mock'
packdir="$repo/.git/vulpra-native-build/packages"
mkdir -p "$packdir"
archive="$packdir/vulpra-local-fixture.tar.xz"
tar -cJf "$archive" -C "$work/pkg" vulpra
(cd "$packdir" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")

cat > "$bin/geckodriver" <<'DRIVER'
#!/usr/bin/env bash
# No actual port bound: the curl fixture returns synthetic WebDriver JSON.
exec sleep 60
DRIVER

cat > "$bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
url="${*: -1}"
[[ "$url" == http://127.0.0.1:* ]] || { echo "Non-loopback WebDriver URL" >&2; exit 3; }
printf '%s\n' "$url" >> "$MOCK_CALLS"
if [[ "$url" == */status ]]; then
  echo '{"value":{"ready":true}}'
elif [[ "$url" == */session ]]; then
  echo '{"value":{"sessionId":"fixture-session","capabilities":{"browserName":"firefox","acceptInsecureCerts":false,"moz:processID":54321}}}'
elif [[ "$url" == */element ]]; then
  echo '{"value":{"element-6066-11e4-a52e-4f735466cecf":"fixture-element"}}'
elif [[ "$url" == */execute/sync ]]; then
  if [[ "$*" == *'vulpraProbe.report().ready'* ]]; then
    echo '{"value":true}'
  else
    echo '{"value":{"ready":true,"inputEvents":48,"trustedEvents":48,"inputToNextRafMs":{"count":48,"p50":3,"p95":8,"max":11},"rafIntervalMs":{"count":120,"p50":16.7,"p95":20.1,"max":40},"visibility":"visible","note":"mock fixture"}}'
  fi
else
  echo '{"value":null}'
fi
CURL
chmod +x "$bin/geckodriver" "$bin/curl"
export MOCK_CALLS="$work/calls.txt"
PATH="$bin:$PATH" bash "$here/measure-input-frame-local.sh" "$repo" > "$work/out" 2>&1 || {
  cat "$work/out" >&2
  echo 'FAIL: mock WebDriver integration' >&2; exit 1;
}
grep -Fq 'PASS: 48 trusted input events.' "$work/out"
[[ "$(grep -c '/element/fixture-element/value$' "$MOCK_CALLS")" == 48 ]] || {
  echo 'FAIL: wrong synthetic keystroke count' >&2; exit 1;
}
mapfile -t reports < <(find "$repo/.git/vulpra-native-build" -maxdepth 1 -name 'input-frame-*.json' -type f)
(("${#reports[@]}" == 1)) || { echo 'FAIL: no bounded report' >&2; exit 1; }
jq -e '.status=="pass" and .mode=="headless" and .isolated_profile==true
  and .metrics.inputEvents==48 and .metrics.trustedEvents==48
  and .metrics.rafIntervalMs.p95==20.1
  and (.limits | length >= 3)' "${reports[0]}" >/dev/null
grep -Fq '/session/fixture-session' "$MOCK_CALLS"
if grep -q 'https://' "$MOCK_CALLS"; then
  echo 'FAIL: non-local WebDriver request' >&2; exit 1;
fi
# Native Wayland path is explicit opt-in and must attribute a mapped browser
# window, without changing the user's compositor or depending on actual GPUs.
cat > "$bin/hyprctl" <<'HYPRCTL'
#!/usr/bin/env bash
case "$*" in
  '-j monitors') echo '[{"id":0,"name":"HDMI-A-1","refreshRate":60.0,"description":"PRIVATE-MONITOR-SERIAL"}]' ;;
  '-j clients') echo '[{"pid":54321,"mapped":true,"xwayland":false,"monitor":0,"title":"PRIVATE-WINDOW-TITLE"}]' ;;
  *) exit 2 ;;
esac
HYPRCTL
chmod +x "$bin/hyprctl"
command -v node >/dev/null || { echo 'FAIL: CI fixture needs Node core net API (no npm)' >&2; exit 1; }
mkdir -p "$work/runtime"
WAYLAND_DISPLAY='wayland-fixture'
XDG_RUNTIME_DIR="$work/runtime"
node -e 'const net=require("net");const p=process.argv[1];net.createServer(()=>{}).listen(p)' \
  "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" >/dev/null 2>&1 &
socket_pid=$!
ready=0
for ((i=0; i<50; ++i)); do
  if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then ready=1; break; fi
  sleep 0.1
done
((ready)) || { echo 'FAIL: mock Wayland socket missing' >&2; exit 1; }
PATH="$bin:$PATH" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  VULPRA_INPUT_MODE=wayland bash "$here/measure-input-frame-local.sh" "$repo" > "$work/gui-out" 2>&1 || {
  cat "$work/gui-out" >&2
  echo 'FAIL: native-Wayland mock WebDriver integration' >&2; exit 1;
}
grep -Fq 'Verified native Wayland browser on connector HDMI-A-1, refresh 60 Hz.' "$work/gui-out"
mapfile -t gui_reports < <(find "$repo/.git/vulpra-native-build" -maxdepth 1 -name 'input-frame-*.json' -type f)
(("${#gui_reports[@]}" == 2)) || { echo 'FAIL: both timing modes did not report' >&2; exit 1; }
if grep -rq 'PRIVATE-MONITOR-SERIAL\|PRIVATE-WINDOW-TITLE' "${gui_reports[@]}"; then
  echo 'FAIL: compositor private window/monitor data leaked into report' >&2; exit 1;
fi
wayland_reports=0
for report in "${gui_reports[@]}"; do
  if jq -e '.mode=="wayland" and .native_wayland_window_verified==true
    and .active_monitor.connector=="HDMI-A-1" and .active_monitor.refresh_hz==60
    and .metrics.trustedEvents==48' "$report" >/dev/null; then
    ((wayland_reports += 1))
  fi
done
((wayland_reports == 1)) || { echo 'FAIL: native Wayland report mismatch' >&2; exit 1; }
# Decline an unrequested third mode even if the package is valid.
if PATH="$bin:$PATH" VULPRA_INPUT_MODE=xwayland bash "$here/measure-input-frame-local.sh" "$repo" > "$work/reject" 2>&1; then
  echo 'FAIL: unsupported input mode was accepted' >&2; exit 1;
fi
# An integrity failure is a hard denial, not a fallback to an unchecked tarball.
printf 'bad sha256\n' > "$archive.sha256"
if PATH="$bin:$PATH" bash "$here/measure-input-frame-local.sh" "$repo" > "$work/reject" 2>&1; then
  echo 'FAIL: unchecked package accepted' >&2; exit 1;
fi
if PATH="$bin:$PATH" VULPRA_INPUT_SAMPLES=81 bash "$here/measure-input-frame-local.sh" "$repo" > "$work/reject" 2>&1; then
  echo 'FAIL: unbounded sample count accepted' >&2; exit 1;
fi
echo 'PASS: mock headless and native Wayland input/rAF, window attribution, privacy, checksum denial and bounded samples.'
