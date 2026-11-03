#!/usr/bin/env bash
# CI-only uninterrupted original browser -> REAL original updater process.
# Original packaged executables are immutable; synthetic update.mar ABSENT.
# Strict Rust preload hook forwards exactly source-declared stage execv;
# inherited ELF initializer witnesses actual updater with browser parent.
# Real original updater must fail: 6; only disposable mounts are writable.
set -euo pipefail
[[ $# == 2 && "$1" == /original/vulpra &&
  "$2" == /reports/m3-original-browser-updater-real-elf-chain.json ]] || exit 2
[[ "$VULPRA_M3_DISPOSABLE_UPDATER_EXECV_FORWARD" == 1 &&
   "$VULPRA_OFFLINE_CONTAINER_ONLY" == 1 &&
   "$MOZ_DISABLE_NONLOCAL_CONNECTIONS" == 1 ]] || exit 2
[[ "$(awk '/^CapEff:/ {print $2}' /proc/self/status)" == 0000000000000000 &&
   "$(awk '/^CapPrm:/ {print $2}' /proc/self/status)" == 0000000000000000 ]] || exit 2
[[ -f /audit/execv-forward.so && -x /original/updater &&
   -d /original/updates && -x /original/vulpra ]] || exit 2
for app in weston wayland-info geckodriver curl jq; do command -v "$app" >/dev/null || exit 2; done
work="$(mktemp -d /tmp/vulpra-m3-updater-guard.XXXXXX)"
export HOME="$work/home" XDG_DATA_HOME="$work/data" XDG_RUNTIME_DIR="$work/runtime"
export WAYLAND_DISPLAY=wayland-vulpra-m3-guard XDG_SESSION_TYPE=wayland
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
# The synthetic fixture must not pre-exist before startup, preventing any
# ordinary startup update path from touching it.
test ! -e /original/updates/0
test -d /original/updated
test -z "$(find /original/updated -mindepth 1 -print -quit)"
test ! -e /reports/m3-real-browser-updater-pre-exec.json
test ! -e /reports/m3-real-browser-updater-loader.json
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

# Guard loads only in original browser/exec child. Reject every other
# execv; real updater may run with absent MAR and immutable installation.
LD_PRELOAD=/audit/execv-forward.so "$1" \
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
root_script='return Components.classes["@mozilla.org/file/directory_service;1"].getService(Components.interfaces.nsIProperties).get("UpdRootD",Components.interfaces.nsIFile).path;'
root_payload="$(jq -nc --arg script "$root_script" '{script:$script,args:[]}')"
root_resp="$(api POST "/session/$session/execute/sync" "$root_payload")"
jq -e '.value=="/original"' <<<"$root_resp" >/dev/null || {
  echo 'Original update root is not exact isolated /original install directory; refusing staging' >&2; exit 1;
}
echo 'M3_SOURCE_ORIGINAL_UPDROOT=PASS original compiled browser resolved isolated /original'
# Only private /original/updates and /original/updated mounts writable.
# Original packaged installation remains immutable and no MAR exists.
mkdir -m 0700 /original/updates/0
printf 'null\n' > /original/updates/0/update.version
printf 'pending\n' > /original/updates/0/update.status
test ! -e /original/updates/0/update.mar
test -d /original/updated
test -z "$(find /original/updated -mindepth 1 -print -quit)"
test ! -e /reports/m3-real-browser-updater-pre-exec.json
test ! -e /reports/m3-real-browser-updater-loader.json
# Request actual staged updater missing-MAR failure from live original
# browser without a valid update payload, callback or network.
trigger='Components.classes["@mozilla.org/updates/update-processor;1"].createInstance(Components.interfaces.nsIUpdateProcessor).processUpdate();return "synthetic_stage_requested";'
trigger_payload="$(jq -nc --arg script "$trigger" '{script:$script,args:[]}')"
echo 'M3_ORIGINAL_UPDATE_PROCESSOR_STAGE=requested'
answer="$(api POST "/session/$session/execute/sync" "$trigger_payload")"
jq -e '.value=="synthetic_stage_requested"' <<<"$answer" >/dev/null || {
  echo 'Original browser source-declared update processor refused synthetic staging' >&2; exit 1;
}
# PRE authenticates browser-owned execv, POST authenticates a genuinely
# executed original updater ELF and its original browser parent.
pre=/reports/m3-real-browser-updater-pre-exec.json
post=/reports/m3-real-browser-updater-loader.json
complete=0
for _ in {1..200}; do
  test ! -e /original/updates/0/update.mar
  if [[ -s "$pre" && -s "$post" &&
        "$(tr -d '\r\n' </original/updates/0/update.status)" == 'failed: 6' ]]; then
    complete=1; break
  fi
  kill -0 "$browser_pid" 2>/dev/null || {
    echo 'M3_REAL_CHAIN_FAILURE=original_browser_exited' >&2; exit 1;
  }
  sleep 0.10
done
if [[ "$complete" != 1 ]]; then
  echo 'M3_REAL_CHAIN_FAILURE=missing_exec_loader_or_READ_ERROR_6' >&2
  if [[ -s "$pre" ]]; then echo 'M3_REAL_CHAIN_PRE=true' >&2; else echo 'M3_REAL_CHAIN_PRE=false' >&2; fi
  if [[ -s "$post" ]]; then echo 'M3_REAL_CHAIN_POST=true' >&2; else echo 'M3_REAL_CHAIN_POST=false' >&2; fi
  state="$(tr -d '\r\n' </original/updates/0/update.status)"
  if [[ "$state" =~ ^failed:\ [0-9]{1,3}$ || "$state" == applying || "$state" == pending ]]; then
    printf 'M3_REAL_CHAIN_STATUS=%s\n' "$state" >&2
  else
    echo 'M3_REAL_CHAIN_STATUS=other' >&2
  fi
  exit 1
fi
jq -e '
 .schema==1 and
 .status=="authentic_original_browser_staging_execv_forwarded" and
 .caller_original_browser==true and
 .exact_original_updater_path==true and
 .source_declared_seven_argument_stage_shape==true and
 .staging_pid_arg_negative_one==true and
 .test_only_missing_mar_confirmed==true and
 .forward_to_libc_execve_attempted==true and
 .updater_load_confirmed_by_this_marker==false and
 .no_other_execv_allowed==true and
 .native_package_modified==false and
 .source_pruning_authorized==false and .native_bytes_saved==0
' "$pre" >/dev/null
jq -e '
 .schema==1 and
 .status=="real_original_updater_elf_loaded_from_original_browser_parent" and
 .actual_proc_exe_is_original_packaged_updater==true and
 .kernel_arg_vector_matches_original_source==true and
 .parent_proc_exe_is_original_browser==true and
 .browser_execv_intent_marker_preexists==true and
 .updater_loader_initialized_after_actual_exec==true and
 .updater_install_success_or_mar_validity_proven==false and
 .original_install_writable==false and
 .source_pruning_authorized==false and .native_bytes_saved==0
' "$post" >/dev/null
test ! -e /original/updates/0/update.mar
test -z "$(find /original/updated -mindepth 1 -print -quit)"
test ! -e "$HOME/.mozilla"
# Original live browser must remain WebDriver-responsive after failed update.
live="$(api POST "/session/$session/execute/sync" \
  '{"script":"return 1+1;","args":[]}')"
jq -e '.value==2' <<<"$live" >/dev/null || exit 1
jq -n \
  --arg src 'b1482404dfb8b01342990ee99ea3df0f9756b5f7' \
  --arg sha '7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a' \
  --slurpfile pre "$pre" --slurpfile post "$post" '
  if ($pre|length)!=1 or ($post|length)!=1 then
    error("expected exactly two original process witnesses")
  else {
    schema_version:1,
    status:"source_pinned_original_browser_to_actual_updater_executed_missing_mar",
    source_commit:$src,archive_sha256:$sha,
    original_browser_launched_directly_and_still_responsive:true,
    original_browser_update_root_is_exact_disposable_package:true,
    synthetic_pending_status_created_after_browser_start:true,
    original_update_processor_issued_from_live_browser:true,
    real_original_browser_native_execv_called:true,
    actual_updater_elf_loaded_with_original_browser_parent:true,
    actual_original_updater_executed_in_same_process_chain:true,
    actual_original_updater_status:"failed: 6",
    original_updater_expected_read_error:6,
    original_updater_missing_mar_failure_path_confirmed:true,
    missing_mar_still_absent:true,
    separate_writable_staging_fixture_remained_empty:true,
    original_binary_installation_read_only:true,
    private_container_network_disabled:true,
    no_real_browser_profile_or_hardware_touched:true,
    browser_to_updater_interposer_allows_only_exact_staging_command:true,
    no_mar_download_or_install_attempted:true,
    normal_update_success_or_mar_signature_validation_proven:false,
    normal_auto_update_workflow_proven:false,
    production_browser_loader_or_dependency_closure_proven:false,
    source_pruning_authorized:false,native_bytes_saved:0,
    m3_sixth_gate_closed:false,
    native_execv_witness:$pre[0],
    native_real_updater_loader_witness:$post[0]
  } end' >"$2"
echo 'M3_ORIGINAL_BROWSER_TO_REAL_UPDATER=PASS original browser launched genuine updater, failed: 6, original installed ELF immutable'
