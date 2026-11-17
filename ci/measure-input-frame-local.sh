#!/usr/bin/env bash
# Synthetic WebDriver input -> next rAF timing in isolated packaged Vulpra.
# Headless, local file fixture, no global hotkeys, system profile or settings.
set -Eeuo pipefail
umask 077

repo="${1:-$HOME/Code/Apps/vulpra}"
cd "$repo" || { echo "ERROR: Missing Vulpra checkout: $repo" >&2; exit 2; }
repo="$(pwd -P)"
[[ -f "$repo/mach" ]] || { echo 'ERROR: Not a Vulpra checkout.' >&2; exit 2; }
for command in git jq curl tar sha256sum shuf setsid; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "ERROR: Missing $command (no installation performed)." >&2; exit 2;
  }
done
gecko="$(command -v geckodriver || true)"
if [[ -z "$gecko" && -x "$repo/obj-vulpra-linux/dist/bin/geckodriver" ]]; then
  gecko="$repo/obj-vulpra-linux/dist/bin/geckodriver"
fi
[[ -n "$gecko" ]] || {
  echo 'ERROR: geckodriver missing; use the existing Vulpra Nix devShell (no pip/npm).' >&2; exit 3;
}
fixture="$repo/ci/fixtures/input-to-raf.html"
[[ -s "$fixture" ]] || { echo 'ERROR: Missing synthetic local HTML fixture.' >&2; exit 2; }
# file:// URL interpretation is platform-dependent for unsafe characters.
[[ "$fixture" != *[[:space:]\#\?]* ]] || {
  echo 'ERROR: Checkout path contains characters unsafe for a direct file:// URL.' >&2; exit 2;
}
samples="${VULPRA_INPUT_SAMPLES:-48}"
[[ "$samples" =~ ^[1-9][0-9]?$ ]] && ((samples >= 24 && samples <= 80)) || {
  echo 'ERROR: VULPRA_INPUT_SAMPLES must be 24..80.' >&2; exit 2;
}
logdir="$(git rev-parse --path-format=absolute --git-path vulpra-native-build)"
packdir="$logdir/packages"
mapfile -d '' -t archives < <(
  find "$packdir" -maxdepth 1 -type f -name 'vulpra-local-*.tar.xz' -printf '%T@ %p\0' |
    sort -zrn | cut -z -d ' ' -f2-
)
(("${#archives[@]}" > 0)) || { echo "ERROR: No verified package under $packdir" >&2; exit 3; }
archive="${archives[0]}"
[[ -f "$archive.sha256" ]] && (
  cd "$(dirname "$archive")" && sha256sum -c --status "$(basename "$archive").sha256"
) || { echo 'ERROR: Package checksum invalid or missing.' >&2; exit 3; }

mkdir -p "$logdir"
stamp="$(date +%Y%m%d-%H%M%S-%N)"
report="$logdir/input-frame-$stamp.json"
driverlog="$logdir/input-frame-driver-$stamp.log"
work="$(mktemp -d)"
driver_pid=""
session=""
port=""
cleanup() {
  if [[ -n "$session" && -n "$port" ]]; then
    curl -fsS --max-time 3 -X DELETE "http://127.0.0.1:$port/session/$session" \
      >/dev/null 2>&1 || true
  fi
  if [[ -n "$driver_pid" ]]; then
    # Only our own freshly created setsid process group is targeted.
    kill -TERM -- "-$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -p "$work/app" "$work/home/.mozilla/firefox" "$work/tmp"
printf 'existing Firefox sentinel: must not change\n' > "$work/home/.mozilla/firefox/profiles.ini"
tar -xf "$archive" -C "$work/app"
mapfile -d '' -t inis < <(find "$work/app" -mindepth 1 -maxdepth 4 -type f -name application.ini -print0)
(("${#inis[@]}" == 1)) || { echo 'ERROR: Expected a single packaged application.ini.' >&2; exit 3; }
appdir="$(dirname "${inis[0]}")"
grep -Fxq 'Name=Vulpra' "${inis[0]}" || { echo 'ERROR: Not a Vulpra package.' >&2; exit 3; }
browser=""
for candidate in vulpra firefox; do
  executable="$appdir/$candidate"
  if [[ -x "$executable" && "$(head -c 4 "$executable" | od -An -tx1 | tr -d ' \n')" == 7f454c46 ]]; then
    browser="$executable"
    break
  fi
done
[[ -n "$browser" ]] || { echo 'ERROR: No packaged native browser ELF.' >&2; exit 3; }
port="$(shuf -i 41000-59999 -n 1)"
echo "Vulpra synthetic input-frame check (headless, isolated, local fixture)"
echo "Verified archive: $(basename "$archive")"
echo "Input samples requested: $samples"
setsid env -u DISPLAY -u WAYLAND_DISPLAY -u MOZ_REMOTE \
  HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" TMPDIR="$work/tmp" \
  MOZ_HEADLESS=1 XRE_START_OFFLINE=1 MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
  NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost \
  "$gecko" --host 127.0.0.1 --port "$port" > "$driverlog" 2>&1 &
driver_pid=$!
ready=0
for ((i=0; i<100; ++i)); do
  if ! kill -0 "$driver_pid" 2>/dev/null; then break; fi
  if curl -fsS --max-time 1 "http://127.0.0.1:$port/status" 2>/dev/null |
     jq -e '.value.ready == true' >/dev/null 2>&1; then ready=1; break; fi
  sleep 0.2
done
((ready)) || { echo "ERROR: Geckodriver failed to start. Log: $driverlog" >&2; exit 4; }

# All requests use loopback W3C WebDriver. Response values are never eval'd.
webdriver() {
  local method="$1" route="$2" payload="${3:-}"
  if [[ -n "$payload" ]]; then
    curl -fsS --max-time 20 -X "$method" -H 'Content-Type: application/json' \
      --data "$payload" "http://127.0.0.1:$port$route" > "$work/response.json"
  else
    curl -fsS --max-time 20 -X "$method" \
      "http://127.0.0.1:$port$route" > "$work/response.json"
  fi
  jq -e 'has("value") and ((.value | type) != "object" or (.value | has("error") | not))' \
    "$work/response.json" >/dev/null || {
      echo 'ERROR: WebDriver returned an error (details in isolated driver log).' >&2
      return 1
    }
}
capabilities="$(jq -nc --arg binary "$browser" '
  {capabilities:{alwaysMatch:{
    browserName:"firefox",acceptInsecureCerts:false,
    "moz:firefoxOptions":{binary:$binary,args:["-headless","-no-remote"],
      prefs:{"browser.shell.checkDefaultBrowser":false,
             "app.update.enabled":false,
             "extensions.update.enabled":false}}
  }}}
')"
webdriver POST /session "$capabilities"
session="$(jq -er '.value.sessionId' "$work/response.json")" || {
  echo 'ERROR: No isolated WebDriver session created.' >&2; exit 4;
}
jq -e '.value.capabilities.browserName=="firefox" and .value.capabilities.acceptInsecureCerts==false' \
  "$work/response.json" >/dev/null || {
    echo 'ERROR: Browser identity or certificate-validation state unexpected.' >&2; exit 4;
  }
base="/session/$session"
url="file://$fixture"
webdriver POST "$base/url" "$(jq -nc --arg url "$url" '{url:$url}')"
webscript='{"script":"return !!(window.vulpraProbe && window.vulpraProbe.report().ready);","args":[]}'
webdriver POST "$base/execute/sync" "$webscript"
jq -e '.value == true' "$work/response.json" >/dev/null || {
  echo 'ERROR: Local synthetic input page did not initialize.' >&2; exit 4;
}
webdriver POST "$base/element" '{"using":"css selector","value":"#typing-probe"}'
element="$(jq -er '.value["element-6066-11e4-a52e-4f735466cecf"]' "$work/response.json")" || {
  echo 'ERROR: Input element not found on local fixture.' >&2; exit 4;
}
webdriver POST "$base/element/$element/click" '{}'
for ((i=0; i<samples; ++i)); do
  webdriver POST "$base/element/$element/value" '{"text":"x","value":["x"]}'
done
# Allow independent frame scheduling after the final synthetic keypress.
observed=0
for ((i=0; i<80; ++i)); do
  webdriver POST "$base/execute/sync" \
    '{"script":"return window.vulpraProbe.report();","args":[]}'
  if jq -e --argjson expected "$samples" '
    .value.inputEvents == $expected and
    .value.trustedEvents == $expected and
    .value.inputToNextRafMs.count == $expected and
    .value.rafIntervalMs.count >= 30
  ' "$work/response.json" >/dev/null; then
    observed=1
    break
  fi
  sleep 0.25
done
((observed)) || {
  echo 'FAIL: Incomplete trusted input/rAF observations; no performance result inferred.' >&2
  echo "Driver log: $driverlog" >&2
  exit 5
}
jq -n \
  --arg package "$(basename "$archive")" \
  --arg commit "$(git rev-parse --short=12 HEAD)" \
  --argjson requested "$samples" \
  --slurpfile response "$work/response.json" '
  {schema_version:1,kind:"synthetic_input_to_animation_frame",
   status:"pass",mode:"headless",isolated_profile:true,package:$package,
   source_commit:$commit,requested_input_events:$requested,
   metrics:$response[0].value,
   limits:["Headless WebDriver uses synthetic trusted typing, not a physical keyboard.",
           "Input-to-rAF callback time is not pixel presentation or human-perceived latency.",
           "Headless results cannot be used to attribute AMD/NVIDIA or Hyprland frame pacing.",
           "This test uses offline, localhost-only/fixture conditions, not normal online browsing."]}
' > "$report"
grep -Fxq 'existing Firefox sentinel: must not change' \
  "$work/home/.mozilla/firefox/profiles.ini" || {
    rm -f "$report"
    echo 'FAIL: Temporary Firefox sentinel modified.' >&2; exit 5;
  }
jq -r '"PASS: " + (.metrics.inputEvents|tostring) +
  " trusted input events. Input-to-rAF p50=" +
  (.metrics.inputToNextRafMs.p50|tostring) + "ms, p95=" +
  (.metrics.inputToNextRafMs.p95|tostring) +
  "ms; frame-interval p95=" +
  (.metrics.rafIntervalMs.p95|tostring) + "ms."' "$report"
printf 'Report: %s\n' "$report"
echo 'LIMIT: This does not measure physical typing latency, actual display presentation, or GPU attribution.'
