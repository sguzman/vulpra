#!/usr/bin/env bash
# CI-only actual original updater binary run, with source-shaped stage arguments
# and intentionally ABSENT MAR in isolated read-only/no-egress environment.
# This is a direct CI REPLAY, not a browser-started executable claim.
set -euo pipefail
[[ $# == 1 && "$1" == /reports/m3-original-updater-missing-mar-replay.json ]] || exit 2
[[ "${VULPRA_M3_DISPOSABLE_MISSING_MAR_REPLAY:-}" == 1 &&
   "${VULPRA_OFFLINE_CONTAINER_ONLY:-}" == 1 ]] || exit 2
[[ "$(awk '/^CapEff:/ {print $2}' /proc/self/status)" == 0000000000000000 &&
   "$(awk '/^CapPrm:/ {print $2}' /proc/self/status)" == 0000000000000000 ]] || exit 2
[[ -x /original/updater && -x /original/vulpra &&
   -d /original/updates && ! -e /original/updates/0 &&
   ! -e /original/updated && ! -e "$1" ]] || exit 2
for executable in timeout jq sha256sum; do command -v "$executable" >/dev/null || exit 2; done
work="$(mktemp -d /tmp/vulpra-m3-missing-mar.XXXXXX)"
trap 'rm -rf -- "$work"' EXIT
export HOME="$work" XDG_DATA_HOME="$work/data"
mkdir -m 0700 "$XDG_DATA_HOME"
unset DISPLAY WAYLAND_DISPLAY MOZ_TEST_SKIP_UPDATE_STAGE MOZ_TEST_SLOW_SKIP_UPDATE_STAGE MOZ_FORCE_ERROR_CODE
mkdir -m 0700 /original/updates/0
printf 'null\n' > /original/updates/0/update.version
printf 'pending\n' > /original/updates/0/update.status
test ! -e /original/updates/0/update.mar
test ! -e /original/updated
# These EXACT seven native Linux arguments were observed at the real original
# browser's fork->execv boundary in accepted CI 41731162834.
# No browser, UI, callback, network or installation code is invoked by this
# shell outside the original updater's own missing-payload failure handling.
set +e
timeout --signal=TERM --kill-after=2s 25s \
  /original/updater 3 /original/updates/0 /original \
    /original/updated first -1 \
  >"$work/original-updater-stdout" 2>"$work/original-updater-stderr"
rc=$?
set -e
if [[ "$rc" != 1 ]]; then
  echo 'M3_MISSING_MAR_REPLAY_FAILURE=unexpected_exit_code' >&2
  exit 1
fi
status="$(tr -d '\r\n' </original/updates/0/update.status)"
if [[ "$status" != 'failed: 6' ]]; then
  echo 'M3_MISSING_MAR_REPLAY_FAILURE=expected_SOURCE_READ_ERROR_6_not_observed' >&2
  exit 1
fi
if [[ -e /original/updates/0/update.mar || -e /original/updated || -e "$HOME/.mozilla" ]]; then
  echo 'M3_MISSING_MAR_REPLAY_FAILURE=unexpected_payload_or_install_tree' >&2
  exit 1
fi
jq -n \
  --arg src 'b1482404dfb8b01342990ee99ea3df0f9756b5f7' \
  --arg sha '7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a' \
  --arg status "$status" --argjson rc "$rc" '
{
  schema_version:1,
  status:"original_updater_executes_and_rejects_absent_mar_with_original_read_error",
  source_commit:$src,
  archive_sha256:$sha,
  original_compiled_updater_actually_executed:true,
  updater_invoked_by_disposable_ci_replay_not_original_browser:true,
  exact_original_linux_stage_arguments_replayed:true,
  original_updater_exit_code:$rc,
  actual_original_update_status:$status,
  expected_original_read_error_code:6,
  original_updater_open_missing_mar_failure_confirmed:true,
  no_mar_payload_created_or_available:true,
  original_install_read_only:true,
  original_staging_target_unwritable_and_absent:true,
  original_updater_error_status_written_in_disposable_fixture:true,
  no_real_user_profile_or_device_accessed:true,
  network_egress_allowed:false,
  no_update_installation_or_success_claimed:true,
  no_callback_application_requested:true,
  no_raw_stdout_stderr_argv_pids_or_profiles_exported:true,
  browser_controlled_actual_updater_exec_proven:false,
  native_update_success_proven:false,
  full_dependency_closure_proven:false,
  source_pruning_authorized:false,
  native_bytes_saved:0,
  m3_sixth_gate_closed:false
}' >"$1"
echo 'M3_ORIGINAL_UPDATER_MISSING_MAR=PASS original binary executed, rc=1, READ_ERROR=6, no MAR, install immutable'
