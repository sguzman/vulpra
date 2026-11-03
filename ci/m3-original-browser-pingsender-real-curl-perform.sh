#!/usr/bin/env bash
# CI-only real browser-controlled original pingsender native executable.
# Synthetic payload and localhost-only URL under Docker --network none.
# The genuine original binary's ELF loader verifies its parent is browser.
# Normal telemetry upload disabled. No real user profile or network.
set -euo pipefail
[[ $# == 2 && "$1" == /original/vulpra &&
  "$2" == /reports/m3-original-browser-pingsender-real-curl-perform.json ]] || exit 2
[[ "$VULPRA_M3_DISPOSABLE_PINGSENDER" == 1 &&
   "$VULPRA_OFFLINE_CONTAINER_ONLY" == 1 &&
   "$MOZ_DISABLE_NONLOCAL_CONNECTIONS" == 1 ]] || exit 2
[[ "$(awk '/^CapEff:/ {print $2}' /proc/self/status)" == 0000000000000000 &&
   "$(awk '/^CapPrm:/ {print $2}' /proc/self/status)" == 0000000000000000 ]] || exit 2
[[ -f /audit/pingsender-real-perform-observer.so && -x /original/pingsender &&
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
test ! -e /reports/m3-original-browser-pingsender-libcurl-perform.json
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
LD_PRELOAD=/audit/pingsender-real-perform-observer.so "$1" \
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
# The only accepted marker is emitted by the actual original child
# process AFTER real curl_easy_perform was invoked through the original
# CurlWrapper function pointer, forwarded to real host libcurl and returned
# CURLE_COULDNT_CONNECT=7 for localhost:9. Merely resolving the function
# address or invoking a proxy without forwarding is not accepted.
marker=/reports/m3-original-browser-pingsender-libcurl-perform.json
observed=0
for _ in {1..150}; do
  if [[ -s "$marker" ]]; then observed=1; break; fi
  kill -0 "$browser_pid" 2>/dev/null || {
    echo 'M3_PINGSENDER_PERFORM_FAILURE=original_browser_terminated' >&2; exit 1;
  }
  sleep 0.1
done
[[ "$observed" == 1 ]] || {
  echo 'M3_PINGSENDER_PERFORM_FAILURE=no_real_libcurl_perform_return_7_witness' >&2
  exit 1
}
jq -e '
  .schema_version==1 and
  .status=="original_browser_owned_pingsender_real_libcurl_perform_connection_refused" and
  .source_commit=="b1482404dfb8b01342990ee99ea3df0f9756b5f7" and
  .archive_sha256=="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a" and
  .original_packaged_pingsender_elf_and_browser_parent_authenticated==true and
  .synthetic_localhost_only_kernel_argv_authenticated==true and
  .real_original_child_dlopen_libcurl_success==true and
  .real_source_defined_dlsym_nonnull_count==14 and
  .all_9_required_original_curl_symbols_resolved==true and
  .all_5_optional_original_url_symbols_resolved==true and
  .original_pingsender_invoked_real_curl_easy_perform==true and
  .real_libcurl_function_forwarded_and_returned==true and
  .actual_curl_easy_perform_return_code==7 and
  .actual_curl_easy_perform_returned_curle_couldnt_connect==true and
  .no_telemetry_success==true and
  .no_network_egress_possible==true and
  .original_installation_read_only==true and
  .normal_telemetry_policy_or_actual_upload_proven==false and
  .complete_native_dependency_graph_proven==false and
  .source_pruning_authorized==false and .native_bytes_saved==0 and
  .m3_sixth_gate_closed==false
' "$marker" >/dev/null
test -f /tmp/vulpra-m3-synthetic-only-ping.json
test ! -e "$HOME/.mozilla"
alive="$(api POST "/session/$session/execute/sync" \
  '{"script":"return 1+1;","args":[]}')"
jq -e '.value==2' <<<"$alive" >/dev/null || exit 1
jq -n --slurpfile witness "$marker" \
  --arg src 'b1482404dfb8b01342990ee99ea3df0f9756b5f7' \
  --arg sha '7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a' '
  if ($witness|length)!=1 then error("missing exact authentic real original curl perform witness")
  else {
    schema_version:1,
    status:"original_browser_owned_actual_pingsender_real_curl_easy_perform_failed_localhost",
    source_commit:$src,archive_sha256:$sha,
    original_browser_owned_actual_pingsender_elf:true,
    genuine_source_defined_libcurl_dlopen_and_14_dlsym:true,
    actual_original_pingsender_executed_real_libcurl_easy_perform:true,
    actual_real_libcurl_perform_return_code:7,
    original_browser_remained_responsive:true,
    only_synthetic_localhost_payload_used:true,
    synthetic_local_payload_retained:true,
    real_upload_permission_disabled:true,
    original_installation_read_only:true,
    no_network_egress_or_real_user_telemetry:true,
    successful_telemetry_send_or_normal_policy_proven:false,
    all_possible_conditional_ffi_dependency_paths_closed:false,
    source_pruning_authorized:false,native_bytes_saved:0,
    m3_sixth_gate_closed:false,
    real_original_child_curl_perform_witness:$witness[0]
  } end' >"$2"
echo 'M3_ORIGINAL_BROWSER_REAL_CURL_PERFORM=PASS original browser-owned packaged pingsender executed actual libcurl curl_easy_perform, returned CURLE_COULDNT_CONNECT=7; no egress'
