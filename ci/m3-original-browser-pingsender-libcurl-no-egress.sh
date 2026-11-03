#!/usr/bin/env bash
# CI-only real browser-controlled original pingsender native executable.
# Synthetic payload and localhost-only URL under Docker --network none.
# The genuine original binary's ELF loader verifies its parent is browser.
# Normal telemetry upload disabled. No real user profile or network.
set -euo pipefail
[[ $# == 2 && "$1" == /original/vulpra &&
  "$2" == /reports/m3-original-browser-pingsender-libcurl-no-egress.json ]] || exit 2
[[ "$VULPRA_M3_DISPOSABLE_PINGSENDER" == 1 &&
   "$VULPRA_OFFLINE_CONTAINER_ONLY" == 1 &&
   "$MOZ_DISABLE_NONLOCAL_CONNECTIONS" == 1 ]] || exit 2
[[ "$(awk '/^CapEff:/ {print $2}' /proc/self/status)" == 0000000000000000 &&
   "$(awk '/^CapPrm:/ {print $2}' /proc/self/status)" == 0000000000000000 ]] || exit 2
[[ -f /audit/pingsender-libcurl-observer.so && -x /original/pingsender &&
   -x /original/vulpra ]] || exit 2
for app in weston wayland-info geckodriver curl jq; do command -v "$app" >/dev/null || exit 2; done
work="$(mktemp -d /tmp/vulpra-m3-pingsender.XXXXXX)"
export HOME="$work/home" XDG_DATA_HOME="$work/data" XDG_RUNTIME_DIR="$work/runtime"
export WAYLAND_DISPLAY=wayland-vulpra-m3-pingsender XDG_SESSION_TYPE=wayland
export GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1
export MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1 XRE_START_OFFLINE=1
unset DISPLAY MOZ_HEADLESS
browser_pid='' driver_pid='' weston_pid='' session=''
base=http://127.0.0.1:4444
api(){
  curl --noproxy '*' -fsS --max-time 12 -X "$1" \
    -H 'Content-Type: application/json' -d "$3" "$base$2"
}
cleanup(){
  if [[ -n "$session" ]]; then api DELETE "/session/$session" '{}' >/dev/null 2>&1 || true; fi
  for pid in "$driver_pid" "$browser_pid" "$weston_pid"; do
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  done
  rm -f -- /tmp/vulpra-m3-synthetic-only-ping.json
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -m 0700 "$HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR" "$work/profile"
cat >"$work/profile/user.js" <<'EOF'
user_pref("app.update.disabledForTesting", true);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.testing.suppressPingsender", false);
user_pref("browser.shell.checkDefaultBrowser", false);
EOF
# Test synthetic payload only. No identifiers or real telemetry data.
test ! -e /tmp/vulpra-m3-synthetic-only-ping.json
test ! -e /reports/m3-original-browser-pingsender-libcurl-dlsym.json
test ! -e "$2"
printf '{"vulpra_ci_synthetic":true,"no_real_telemetry":true}\n' \
  > /tmp/vulpra-m3-synthetic-only-ping.json
chmod 0600 /tmp/vulpra-m3-synthetic-only-ping.json
weston --backend=headless-backend.so --renderer=pixman --idle-time=0 \
  --socket="$WAYLAND_DISPLAY" --log="$work/weston.log" \
  >"$work/weston.stdout" 2>&1 &
weston_pid=$!
ready=0
for _ in {1..45}; do
  if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then ready=1; break; fi
  kill -0 "$weston_pid" 2>/dev/null || exit 1
  sleep 0.25
done
[[ "$ready" == 1 ]] || { echo 'Private original browser Weston not ready' >&2; exit 1; }
wayland-info >"$work/wayland-info.log" 2>&1
grep -Fq xdg_wm_base "$work/wayland-info.log" || exit 1

# Test-only ELF initializer observes the genuine child executable; no
# telemetry bytes, parent PIDs, process argv, or other raw data exported.
LD_PRELOAD=/audit/pingsender-libcurl-observer.so "$1" \
  --marionette --no-remote --new-instance --profile "$work/profile" about:blank \
  >"$work/browser.log" 2>&1 &
browser_pid=$!
geckodriver --connect-existing --marionette-port 2828 \
  --host 127.0.0.1 --port 4444 --log error \
  >"$work/driver.log" 2>&1 &
driver_pid=$!
ready=0
for _ in {1..65}; do
  if api GET /status '{}' 2>/dev/null | jq -e '.value.ready==true' >/dev/null 2>&1; then ready=1; break; fi
  kill -0 "$driver_pid" 2>/dev/null || exit 1
  sleep 0.3
done
[[ "$ready" == 1 ]] || { echo 'Original browser geckodriver unavailable' >&2; exit 1; }
resp="$(api POST /session '{"capabilities":{"alwaysMatch":{"browserName":"firefox"}}}')"
session="$(jq -er '.value.sessionId // .sessionId' <<<"$resp")" || exit 1
context="$(api POST "/session/$session/moz/context" '{"context":"chrome"}')"
jq -e '.value==null or .value=="chrome"' <<<"$context" >/dev/null || exit 1
# Inspect the real original browser's upload policy and module method.
# If source behavior or pref names drift, refuse to trigger any process.
preflight='const p=Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefBranch);const m=ChromeUtils.importESModule("resource://gre/modules/TelemetrySend.sys.mjs").TelemetrySend;const bin=Components.classes["@mozilla.org/file/directory_service;1"].getService(Components.interfaces.nsIProperties).get("GreBinD",Components.interfaces.nsIFile).path;return {method:typeof m.testRunPingSender,suppress:p.getBoolPref("toolkit.telemetry.testing.suppressPingsender",true),enabled:p.getBoolPref("toolkit.telemetry.enabled",true),upload:p.getBoolPref("datareporting.healthreport.uploadEnabled",true),bin};'
pre="$(api POST "/session/$session/execute/sync" \
  "$(jq -nc --arg script "$preflight" '{script:$script,args:[]}')")"
jq -e '.value.method=="function" and .value.suppress==false and
  (.value.enabled|type)=="boolean" and .value.upload==false and
  .value.bin=="/original"' <<<"$pre" >/dev/null || {
  # Explicit approved scalar fields only. Never emit browser profile paths,
  # raw WebDriver error strings or unbounded browser data.
  jq -c '{method:.value.method,suppress:.value.suppress,
    collection_pref:.value.enabled,upload_permission:.value.upload,
    original_bin:(.value.bin=="/original"),
    webdriver_error:(.value.error!=null)}' <<<"$pre" >&2 || true
  echo 'M3_PINGSENDER_FAILURE=browser_module_or_upload_policy_not_safe' >&2
  exit 1
}
echo 'M3_PINGSENDER_PREFLIGHT=PASS original module resolved and actual upload permission disabled; collection pref separately observed'
# Original C++ pingsender permits localhost; Docker no-network namespace
# has no external route. Do not start any local server for this test.
if curl --noproxy '*' -fsS --max-time 1 \
    http://localhost:9/vulpra-m3-synthetic-never-submit \
    >"$work/probe.out" 2>"$work/probe.err"; then
  echo 'M3_PINGSENDER_FAILURE=unexpected_local_listener' >&2
  exit 1
fi
# Real original in-browser test-only API uses nsIProcess.runAsync internally.
# It is not a shell-launched fake pingsender process. No upload prefs are
# enabled, and the requested payload contains only synthetic fixed bytes.
script='const m=ChromeUtils.importESModule("resource://gre/modules/TelemetrySend.sys.mjs").TelemetrySend;m.testRunPingSender([{url:"http://localhost:9/vulpra-m3-synthetic-never-submit",path:"/tmp/vulpra-m3-synthetic-only-ping.json"}],null);return "synthetic_original_pingsender_requested";'
result="$(api POST "/session/$session/execute/sync" \
  "$(jq -nc --arg script "$script" '{script:$script,args:[]}')")"
jq -e '.value=="synthetic_original_pingsender_requested"' <<<"$result" >/dev/null || {
  echo 'M3_PINGSENDER_FAILURE=original_browser_spawn_method_not_accepted' >&2
  exit 1
}
# A marker can only appear after the actual original child ELF passed
# exact parent/kernel-argv verification, its source-listed curl dlopen
# returned a real handle, and all 14 source curl_* dlsym calls succeeded.
marker=/reports/m3-original-browser-pingsender-libcurl-dlsym.json
observed=0
for _ in {1..150}; do
  if [[ -s "$marker" ]]; then observed=1; break; fi
  kill -0 "$browser_pid" 2>/dev/null || {
    echo 'M3_PINGSENDER_CURL_FAILURE=original_browser_terminated' >&2; exit 1;
  }
  sleep 0.1
done
[[ "$observed" == 1 ]] || {
  echo 'M3_PINGSENDER_CURL_FAILURE=no_original_child_curl_dlopen_and_14_dlsym_witness' >&2
  exit 1
}
jq -e '
  .schema_version==1 and
  .status=="original_browser_owned_pingsender_loaded_libcurl_and_resolved_all_14_source_symbols" and
  .source_commit=="b1482404dfb8b01342990ee99ea3df0f9756b5f7" and
  .archive_sha256=="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a" and
  .real_original_packaged_pingsender_elf_loaded==true and
  .parent_executable_original_browser==true and
  .kernel_argv_localhost_synthetic_only==true and
  .real_pingsender_called_dlopen_for_original_curl_soname==true and
  .real_dlopen_returned_nonnull_libcurl_handle==true and
  .actual_dlsym_invocations_on_same_libcurl_handle==14 and
  .all_9_required_source_symbols_returned_nonnull==true and
  .all_5_optional_url_symbols_returned_nonnull==true and
  .no_remote_network_or_real_telemetry==true and
  .telemetry_post_success_proven==false and
  .actual_curl_easy_perform_executed_proven==false and
  .full_conditional_loader_or_ffi_graph_closed==false and
  .source_pruning_authorized==false and .native_bytes_saved==0 and
  .m3_sixth_gate_closed==false
' "$marker" >/dev/null
test -f /tmp/vulpra-m3-synthetic-only-ping.json
test ! -e "$HOME/.mozilla"
alive="$(api POST "/session/$session/execute/sync" \
  '{"script":"return 1+1;","args":[]}')"
jq -e '.value==2' <<<"$alive" >/dev/null || exit 1
jq -n --slurpfile child "$marker" \
  --arg src 'b1482404dfb8b01342990ee99ea3df0f9756b5f7' \
  --arg sha '7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a' '
  if ($child|length)!=1 then error("no authentic original pingsender libcurl runtime marker")
  else {
    schema_version:1,
    status:"source_pinned_original_browser_owned_pingsender_real_libcurl_14_dlsym",
    source_commit:$src,archive_sha256:$sha,
    original_browser_owned_actual_pingsender_elf:true,
    same_genuine_pingsender_loaded_libcurl_and_resolved_all_14_original_symbols:true,
    source_defined_9_required_symbols_resolved:true,
    source_defined_5_optional_symbols_resolved:true,
    only_synthetic_localhost_payload_used:true,
    synthetic_local_payload_not_deleted:true,
    original_browser_remained_responsive:true,
    real_upload_permission_disabled:true,
    original_installation_read_only:true,
    no_network_egress_or_real_user_telemetry:true,
    successful_send_or_normal_submission_proven:false,
    all_possible_conditional_ffi_dependency_paths_closed:false,
    source_pruning_authorized:false,native_bytes_saved:0,
    m3_sixth_gate_closed:false,
    real_original_child_libcurl_witness:$child[0]
  } end' >"$2"
echo 'M3_ORIGINAL_BROWSER_PINGSENDER_CURL=PASS actual original browser->pingsender ELF->real libcurl dlopen and 14 source dlsym symbols, no telemetry egress'
