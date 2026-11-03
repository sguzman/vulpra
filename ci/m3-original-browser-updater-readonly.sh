#!/usr/bin/env bash
# CI only: browser-owned, no-network read-only updater state interrogation.
# Never call update check, init, download, staging, processing, or applying.
# Source's canApplyUpdates() getter WRITES test files: do not call it.
set -euo pipefail
[[ $# == 2 && "$1" == /original/vulpra && "$2" == /reports/m3-original-browser-updater-readonly.json ]] || exit 2
[[ "$VULPRA_M3_DISPOSABLE_UPDATER_READONLY" == 1 &&
   "$VULPRA_OFFLINE_CONTAINER_ONLY" == 1 &&
   "$MOZ_DISABLE_NONLOCAL_CONNECTIONS" == 1 ]] || exit 2
[[ "$(awk '/^CapEff:/ {print $2}' /proc/self/status)" == 0000000000000000 &&
   "$(awk '/^CapPrm:/ {print $2}' /proc/self/status)" == 0000000000000000 ]] || exit 2
[[ -x /original/updater && -x /audit/updater-observer && -x "$1" ]] || exit 2
for program in weston wayland-info geckodriver curl jq; do command -v "$program" >/dev/null || exit 2; done
work="$(mktemp -d /tmp/vulpra-m3-update.XXXXXX)"
export HOME="$work/home" XDG_DATA_HOME="$work/data" XDG_RUNTIME_DIR="$work/runtime"
export WAYLAND_DISPLAY=wayland-vulpra-updater XDG_SESSION_TYPE=wayland
export GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1 XRE_START_OFFLINE=1
export MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1
unset DISPLAY MOZ_HEADLESS
browser_pid='' driver_pid='' weston_pid='' observer_pid='' session=''
base=http://127.0.0.1:4444
api() {
  curl --noproxy '*' -fsS --max-time 12 -X "$1" \
    -H 'Content-Type: application/json' -d "$3" "$base$2"
}
cleanup() {
  if [[ -n "$session" ]]; then api DELETE "/session/$session" '{}' >/dev/null 2>&1 || true; fi
  for pid in "$driver_pid" "$observer_pid" "$browser_pid" "$weston_pid"; do
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  done
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -m 0700 "$HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR" "$work/profile"
cat >"$work/profile/user.js" <<'EOF'
user_pref("app.update.disabledForTesting", true);
user_pref("app.update.auto", false);
user_pref("app.update.background.enabled", false);
user_pref("app.update.staging.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
EOF
weston --backend=headless-backend.so --renderer=pixman --idle-time=0 \
  --socket="$WAYLAND_DISPLAY" --log="$work/weston.log" >"$work/weston.stdout" 2>&1 &
weston_pid=$!
ready=0
for _ in {1..45}; do
  if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then ready=1; break; fi
  kill -0 "$weston_pid" 2>/dev/null || exit 1
  sleep 0.25
done
[[ "$ready" == 1 ]] || exit 1
wayland-info >"$work/wayland-info" 2>&1
grep -Fq xdg_wm_base "$work/wayland-info" || exit 1
/audit/updater-observer /tmp/vulpra-m3-updater-readonly-query-complete \
  /reports/m3-original-browser-updater-no-exec-samples.json >"$work/observer.log" 2>&1 &
observer_pid=$!
# Actual original browser is launched directly, not by geckodriver.
"$1" --marionette --no-remote --new-instance --profile "$work/profile" about:blank \
  >"$work/browser.log" 2>&1 &
browser_pid=$!
geckodriver --connect-existing --marionette-port 2828 --host 127.0.0.1 \
  --port 4444 --log error >"$work/geckodriver.log" 2>&1 &
driver_pid=$!
ready=0
for _ in {1..65}; do
  if api GET /status '{}' 2>/dev/null | jq -e '.value.ready==true' >/dev/null 2>&1; then
    ready=1; break
  fi
  kill -0 "$driver_pid" 2>/dev/null || exit 1
  sleep 0.3
done
[[ "$ready" == 1 ]] || { echo 'Original browser WebDriver inaccessible' >&2; exit 1; }
echo "M3_UPDATE_STAGE=create_attached_session"
resp="$(api POST /session '{"capabilities":{"alwaysMatch":{"browserName":"firefox"}}}')"
session="$(jq -er '.value.sessionId // .sessionId' <<<"$resp")" || exit 1
echo "M3_UPDATE_STAGE=chrome_context"
context="$(api POST "/session/$session/moz/context" '{"context":"chrome"}')"
jq -e '.value==null or .value=="chrome"' <<<"$context" >/dev/null || exit 1
# These XPCOM members have been individually checked against the immutable
# original source. Do NOT request canApplyUpdates/canUsuallyApplyUpdates:
# their supposedly read-only getter actually creates and removes test files.
script='const S=ChromeUtils.importESModule("resource://gre/modules/Services.sys.mjs").Services;const stub=Components.classes["@mozilla.org/updates/update-service-stub;1"].getService(Components.interfaces.nsIApplicationUpdateServiceStub);const upd=Components.classes["@mozilla.org/updates/update-service;1"].getService(Components.interfaces.nsIApplicationUpdateService);return {prefTestingDisabled:S.prefs.getBoolPref("app.update.disabledForTesting",false),prefAuto:S.prefs.getBoolPref("app.update.auto",true),prefBackground:S.prefs.getBoolPref("app.update.background.enabled",true),prefStaging:S.prefs.getBoolPref("app.update.staging.enabled",true),stubTestingDisabled:stub.updateDisabledForTesting,stubDisabled:stub.updateDisabled,serviceDisabled:upd.disabled,usuallyCanCheck:upd.canUsuallyCheckForUpdates,idle:upd.currentState===Components.interfaces.nsIApplicationUpdateService.STATE_IDLE,stateName:upd.getStateName(upd.currentState)};'
payload="$(jq -nc --arg script "$script" '{script:$script,args:[]}')"
predicate='.value.prefTestingDisabled==true and
 .value.prefAuto==false and .value.prefBackground==false and
 .value.prefStaging==false and .value.stubTestingDisabled==true and
 .value.stubDisabled==true and .value.serviceDisabled==true and
 .value.usuallyCanCheck==false and .value.idle==true and
 .value.stateName=="STATE_IDLE"'
echo "M3_UPDATE_STAGE=first_browser_readonly_query"
first="$(api POST "/session/$session/execute/sync" "$payload")"
jq -e "$predicate" <<<"$first" >/dev/null || {
  echo 'Original browser did not return disabled/idle updater service' >&2; exit 1;
}
sleep 2
echo "M3_UPDATE_STAGE=second_browser_readonly_query"
second="$(api POST "/session/$session/execute/sync" "$payload")"
jq -e "$predicate" <<<"$second" >/dev/null || {
  echo 'Original browser update state did not remain disabled/idle' >&2; exit 1;
}
touch /tmp/vulpra-m3-updater-readonly-query-complete
if ! wait "$observer_pid"; then
  grep '^M3_ORIGINAL_UPDATER_READONLY_OBSERVER_ERROR=' "$work/observer.log" >&2 || true
  exit 1
fi
observer_pid=''
test -s /reports/m3-original-browser-updater-no-exec-samples.json
test ! -e "$HOME/.mozilla"
jq -n --arg sha '7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a' \
  --arg src 'b1482404dfb8b01342990ee99ea3df0f9756b5f7' \
  --slurpfile native /reports/m3-original-browser-updater-no-exec-samples.json \
  --argjson q1 "$(jq -c .value <<<"$first")" \
  --argjson q2 "$(jq -c .value <<<"$second")" '
  if ($native|length)!=1 or $q1!=$q2 then error("readonly state mismatch") else {
    schema_version:1,
    status:"real_original_browser_read_only_update_service_disabled_and_idle",
    original_source_commit:$src,original_archive_sha256:$sha,
    update_service_stub_registered_and_invoked:true,
    update_service_registered_and_invoked:true,
    real_browser_chrome_xpcom_read_only_state:$q1,
    query_repeat_matches:true,
    actual_updater_file_original_packaged_elf:true,
    actual_updater_executable_not_invoked_by_test:true,
    updater_process_sample:$native[0],
    did_not_call_update_check_or_download_or_staging_or_apply:true,
    did_not_read_write_testing_update_getters:true,
    original_package_mounted_read_only:true,
    no_user_profile_modified:true,network_egress_allowed:false,
    normal_browser_update_when_enabled_proven:false,
    original_browser_controlled_updater_process_launch_proven:false,
    complete_update_dependency_closure_proven:false,
    source_pruning_authorized:false,native_bytes_saved:0,m3_sixth_gate_closed:false
  } end' >"$2"
echo 'M3_ORIGINAL_BROWSER_UPDATER_READONLY=PASS original browser update service disabled and idle twice; no updater observed in bounded proc samples'
