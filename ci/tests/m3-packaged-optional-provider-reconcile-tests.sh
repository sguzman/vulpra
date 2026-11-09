#!/usr/bin/env bash
# Fail-closed negative fixture checks against real, source-matched normal native
# and packaged-browser denied-provider reports. Run after GitHub API run-origin
# authentication and original named-artifact retrieval in the workflow.
set -euo pipefail
if test "$#" -ne 6; then
  echo "usage: $0 NATIVE_JSON DENIAL_JSON RECONCILED_JSON SOURCE_SHA NATIVE_RUN RECON_RUN" >&2
  exit 2
fi
native="$1"; denial="$2"; reconciled="$3"; source="$4"; run="$5"; recon_run="$6"
filter=ci/m3-packaged-optional-provider-reconcile.jq
for f in "$native" "$denial" "$reconciled" "$filter"; do test -s "$f"; done
[[ "$source" =~ ^[0-9a-f]{40}$ ]]
[[ "$run" =~ ^[0-9]+$ ]]
[[ "$recon_run" =~ ^[0-9]+$ ]]
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
check() {
  jq -n \
    --slurpfile native "$1" \
    --slurpfile denial "$2" \
    --slurpfile reconciled "$3" \
    --arg source "$source" \
    --argjson run "$run" \
    --argjson recon_run "$recon_run" \
    -f "$filter"
}
check "$native" "$denial" "$reconciled" > "$tmp/accepted.json"
jq -e \
  --arg source "$source" \
  --argjson run "$run" \
  --argjson reconciliation "$recon_run" '
  .schema_version == 1 and
  .authenticated_native_source_commit == $source and
  .authenticated_native_workflow_run_id == $run and
  .authenticated_independent_reconciliation_run_id == $reconciliation and
  .ffmpeg_actual_dynamic_loads_intentionally_denied == 14 and
  .ffmpeg_browser_screenshot_after_denials == true and
  .gbm_load_denials_observed == 0 and
  .vaapi_load_denials_observed == 0 and
  .gbm_and_vaapi_missing_library_paths_exercised == false and
  .actual_video_playback_or_software_decoder_fallback_proven == false and
  .actual_Wayland_gpu_DMABuf_failure_fallback_proven == false and
  .m3_sixth_gate_closed == false and
  .source_pruning_authorized == false and
  .security_hotfix_release_ready == false
' "$tmp/accepted.json" >/dev/null
rejections=0
reject() {
  if check "$1" "$2" "$3" > "$tmp/rejected.json" 2>/dev/null; then
    echo "FAIL: forged real packaged FFmpeg/GBM/VA-API evidence accepted: $4" >&2
    exit 1
  fi
  rejections=$((rejections + 1))
}
while IFS= read -r mut; do
  jq "$mut" "$native" > "$tmp/fake-native.json"
  reject "$tmp/fake-native.json" "$denial" "$reconciled" "$mut"
done <<'NATIVE_CASES'
.source_commit = ("0" * 40)
.workflow_run_id = 1
.runtime_passed_after_link_audit = false
.package.package_sha256 = ("0" * 64)
.source_removal_authorized = true
NATIVE_CASES
while IFS= read -r mut; do
  jq "$mut" "$denial" > "$tmp/fake-denial.json"
  reject "$native" "$tmp/fake-denial.json" "$reconciled" "$mut"
done <<'DENIAL_CASES'
.native_source_commit = ("0" * 40)
.verified_packaged_archive_sha256 = ("0" * 64)
.observed_denied_library_loads = 15
.runtime_modes[0].screenshot_passed = false
.runtime_modes[0].actual_packaged_browser_instrumentation_attached = false
.runtime_modes[0].actual_browser_process_attachment_records = 0
.runtime_modes[2].actual_matching_optional_provider_load_denials = 0
.runtime_modes[2].provider_missing_path_observed = false
.runtime_modes[0].actual_matching_optional_provider_load_denials = 1
.runtime_modes[0].provider_missing_path_observed = true
.runtime_modes[1].screenshot_passed_after_observed_denial = true
.source_pruning_authorized = true
.all_requested_library_arguments_and_indirect_edges_proven = true
.hardware_video_or_Wayland_gpu_fallback_complete = true
.m3_sixth_gate_closed = true
.release_ready = true
DENIAL_CASES
while IFS= read -r mut; do
  jq "$mut" "$reconciled" > "$tmp/fake-reconciled.json"
  reject "$native" "$denial" "$tmp/fake-reconciled.json" "$mut"
done <<'RECON_CASES'
.source_commit = ("0" * 40)
.package_sha256 = ("0" * 64)
.native_elf_member_count = 27
.host_transitive_and_dlopen_dependencies_closed = true
.additional_source_removal_authorized = true
RECON_CASES
test "$rejections" -eq 26
echo "PASS: authenticated current real packaged FFmpeg denial source/package/normal-browser crosscheck"
echo "PASS: 26/26 forged native, provider and reconciliation evidence states rejected"
echo "LIMIT: GBM and VA-API no-hit; no real media playback, software codec, Wayland GPU fallback or full FFI closure"
