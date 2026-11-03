#!/usr/bin/env bash
# CI-only original compiled browser update staging execv boundary.
# Fake update.status=pending, update.version=null in disposable nested writable
# mount /original/updates/0. No MAR exists. Browser installation is read-only.
# LD_PRELOAD Rust guard denies *every execv* in the disposable browser, and
# records only an exact source-shaped /original/updater staging attempt.
# This proves an attempted browser-owned execv, NOT actual updater execution.
set -euo pipefail
[[ $# == 2 && "$1" == /original/vulpra &&
  "$2" == /reports/m3-original-browser-updater-execv-denied.json ]] || exit 2
[[ "$VULPRA_M3_DISPOSABLE_UPDATER_EXECV_GUARD" == 1 &&
   "$VULPRA_OFFLINE_CONTAINER_ONLY" == 1 &&
   "$MOZ_DISABLE_NONLOCAL_CONNECTIONS" == 1 ]] || exit 2
[[ "$(awk '/^CapEff:/ {print $2}' /proc/self/status)" == 0000000000000000 &&
   "$(awk '/^CapPrm:/ {print $2}' /proc/self/status)" == 0000000000000000 ]] || exit 2
[[ -f /audit/execv-guard.so && -x /original/updater &&
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
test ! -e /original/updated
test ! -e /reports/m3-original-updater-execv-denied.json
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

# Guard is loaded only in the actual browser and inherited fork children,
# never the driver/Weston. It cannot let a staged updater execv succeed.
LD_PRELOAD=/audit/execv-guard.so "$1" \
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
# Only newly mounted private /original/updates path can be modified. There
# is NO MAR and /original/updated staging target cannot be written.
mkdir -m 0700 /original/updates/0
printf 'null\n' > /original/updates/0/update.version
printf 'pending\n' > /original/updates/0/update.status
test ! -e /original/updates/0/update.mar
test ! -e /original/updated
test ! -e /reports/m3-original-updater-execv-denied.json
# Explicitly request the source-declared updater process *staging intent*.
# This call is on a disposable, test-disabled profile with a synthetic
# pending fixture, not a normal application update or install.
trigger='Components.classes["@mozilla.org/updates/update-processor;1"].createInstance(Components.interfaces.nsIUpdateProcessor).processUpdate();return "synthetic_stage_requested";'
trigger_payload="$(jq -nc --arg script "$trigger" '{script:$script,args:[]}')"
echo 'M3_ORIGINAL_UPDATE_PROCESSOR_STAGE=requested'
answer="$(api POST "/session/$session/execute/sync" "$trigger_payload")"
jq -e '.value=="synthetic_stage_requested"' <<<"$answer" >/dev/null || {
  echo 'Original browser source-declared update processor refused synthetic staging' >&2; exit 1;
}
marker=/reports/m3-original-updater-execv-denied.json
observed=0
for _ in {1..150}; do
  if [[ -s "$marker" ]]; then observed=1; break; fi
  kill -0 "$browser_pid" 2>/dev/null || { echo 'Original test browser exited unexpectedly' >&2; exit 1; }
  sleep 0.1
done
[[ "$observed" == 1 ]] || {
  echo 'No original-browser-owned updater execv attempt reached the deny guard' >&2; exit 1;
}
jq -e '
  .schema_version==1 and
  .status=="original_native_browser_staging_updater_execv_attempt_denied_preexecution" and
  .caller_exact_original_browser_executable==true and
  .original_updater_target_exact_packaged_elf==true and
  .source_declared_linux_stage_arguments_matched==true and
  .staging_mode_pid_arg_minus_one==true and
  .genuine_original_updater_execv_attempt_seen==true and
  .actual_updater_executable_execution_permitted==false and
  .all_execv_calls_denied_in_disposable_test==true and
  .no_mar_downloaded_or_provided==true and
  .source_pruning_authorized==false and
  .native_bytes_saved==0 and .m3_sixth_gate_closed==false' "$marker" >/dev/null
# The single real candidate still has no payload and no writable apply tree.
test ! -e /original/updates/0/update.mar
test ! -e /original/updated
test ! -e "$HOME/.mozilla"
jq -n --arg src 'b1482404dfb8b01342990ee99ea3df0f9756b5f7' \
  --arg sha '7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a' \
  --slurpfile guard "$marker" '
    if ($guard|length)!=1 or $guard[0].genuine_original_updater_execv_attempt_seen!=true then
      error("no authentic browser execv attempt")
    else {
      schema_version:1,
      status:"source_pinned_original_browser_controlled_updater_staging_execv_denied",
      source_commit:$src,archive_sha256:$sha,
      original_compiled_browser_started_directly:true,
      original_browser_update_root_exact_isolated_package:true,
      synthetic_pending_status_created_after_browser_startup:true,
      synthetic_version_not_older:"null",
      original_update_processor_invoked_from_browser:true,
      missing_mar_fixture_confirmed:true,
      no_staged_install_tree_available:true,
      updater_executable_never_allowed_to_exec:true,
      actual_browser_to_updater_execv_boundary_observed:true,
      actual_updater_process_executed:false,
      valid_source_shaped_guard_observation:$guard[0],
      browser_installation_read_only:true,
      synthetic_update_status_mounted_in_disposable_directory:true,
      private_network_disabled:true,
      no_real_user_browser_or_profile_touched:true,
      no_download_or_install_requested:true,
      full_updater_install_success_proven:false,
      complete_source_build_or_loader_closure_proven:false,
      source_pruning_authorized:false,native_bytes_saved:0,
      m3_sixth_gate_closed:false
    } end
  ' >"$2"
echo 'M3_SOURCE_ORIGINAL_UPDATER_EXECV_DENIED=PASS exact source-shaped original browser execv attempted but denied preexecution'
