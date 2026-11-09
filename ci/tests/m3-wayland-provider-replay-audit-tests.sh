#!/usr/bin/env bash
# Reject false graphical-frame, missing-provider or release claims.
set -euo pipefail
filter=ci/m3-wayland-provider-replay-audit.jq
test -s "$filter"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
sha_a="$(printf 'a%.0s' {1..40})"
sha_b="$(printf 'b%.0s' {1..40})"
sha_c="$(printf 'c%.0s' {1..64})"
audit() {
  jq -e --arg expected_source_sha "$sha_a" \
    --arg expected_harness_sha "$sha_b" \
    --arg expected_archive_sha "$sha_c" \
    -f "$filter" "$1"
}
jq -n '{
  schema_version:1,
  status:"actual_packaged_graphical_Weston_Wayland_optional_provider_denial_probe",
  native_source_commit:("a"*40),test_harness_commit:("b"*40),
  verified_normal_packaged_archive_sha256:("c"*64),
  actual_graphical_packaged_Vulpra_executed:true,
  private_Weston_pixman_renderer_used:true,
  non_MOZ_HEADLESS_Wayland_browser_verified:true,
  three_graphical_frames_and_attach_witnesses_passed:true,
  targeted_provider_calls_intercepted:14,
  any_targeted_optional_provider_load_seen:true,
  GPU_DMABuf_or_software_video_fallback_complete:false,
  all_direct_indirect_dynamic_loader_routes_covered:false,
  user_endeavouros_hyprland_qa_done:false,
  host_system_libraries_modified:false,
  user_normal_profile_or_credentials_used:false,
  source_pruning_authorized:false,m3_sixth_gate_closed:false,release_ready:false,
  scenarios:[
    {provider_group:"gbm",browser_process_instrumentation_attached:true,
     browser_attachment_records:3,targeted_optional_library_denial_events:0,
     targeted_missing_provider_path_actually_seen:false,
     actual_graphical_Wayland_frame_committed:true,
     frame_after_observed_targeted_denial:false,
     actual_GPU_acceleration_or_DMABuf_fallback_verified:false,
     media_decoding_fallback_verified:false,
     complete_native_dynamic_dependency_graph:false},
    {provider_group:"vaapi",browser_process_instrumentation_attached:true,
     browser_attachment_records:3,targeted_optional_library_denial_events:0,
     targeted_missing_provider_path_actually_seen:false,
     actual_graphical_Wayland_frame_committed:true,
     frame_after_observed_targeted_denial:false,
     actual_GPU_acceleration_or_DMABuf_fallback_verified:false,
     media_decoding_fallback_verified:false,
     complete_native_dynamic_dependency_graph:false},
    {provider_group:"ffmpeg",browser_process_instrumentation_attached:true,
     browser_attachment_records:3,targeted_optional_library_denial_events:14,
     targeted_missing_provider_path_actually_seen:true,
     actual_graphical_Wayland_frame_committed:true,
     frame_after_observed_targeted_denial:true,
     actual_GPU_acceleration_or_DMABuf_fallback_verified:false,
     media_decoding_fallback_verified:false,
     complete_native_dynamic_dependency_graph:false}
  ]
}' > "$work/valid.json"
audit "$work/valid.json" > "$work/valid-out.json"
jq -e '.real_private_Wayland_buffer_commits_verified==true and
  .gbm_missing_provider_path_tested==false and
  .vaapi_missing_provider_path_tested==false and
  .ffmpeg_missing_provider_path_tested==true and
  .same_session_Wayland_frame_and_gbm_denial_observed==false and
  .provider_denial_temporally_precedes_frame_proven==false and
  .actual_GPU_or_DMA_BUF_graphics_fallback_proven==false and
  .m3_sixth_gate_closed==false' "$work/valid-out.json" >/dev/null
# An all-no-hit run may render Wayland, but proves no missing-provider branch.
jq '.scenarios[2].targeted_optional_library_denial_events=0 |
    .scenarios[2].targeted_missing_provider_path_actually_seen=false |
    .scenarios[2].frame_after_observed_targeted_denial=false |
    .targeted_provider_calls_intercepted=0 |
    .any_targeted_optional_provider_load_seen=false' "$work/valid.json" > "$work/no-hits.json"
audit "$work/no-hits.json" > "$work/no-hits-out.json"
jq -e '(.gbm_missing_provider_path_tested,.vaapi_missing_provider_path_tested,
         .ffmpeg_missing_provider_path_tested)|not' "$work/no-hits-out.json" >/dev/null
count=0
reject() {
  jq "$1" "$work/valid.json" > "$work/forged.json"
  if audit "$work/forged.json" > "$work/incorrect.json" 2>/dev/null; then
    echo "FAIL: accepted forged Wayland provider report: $1" >&2
    exit 1
  fi
  count=$((count+1))
}
while IFS= read -r alteration; do
  reject "$alteration"
done <<'FORGERIES'
.native_source_commit=("0"*40)
.test_harness_commit=("0"*40)
.verified_normal_packaged_archive_sha256=("0"*64)
.three_graphical_frames_and_attach_witnesses_passed=false
.private_Weston_pixman_renderer_used=false
.non_MOZ_HEADLESS_Wayland_browser_verified=false
.scenarios[0].browser_process_instrumentation_attached=false
.scenarios[0].browser_attachment_records=0
.scenarios[0].actual_graphical_Wayland_frame_committed=false
.scenarios[0].targeted_missing_provider_path_actually_seen=true
.scenarios[0].frame_after_observed_targeted_denial=true
.scenarios[2].targeted_optional_library_denial_events=0
.scenarios[2].frame_after_observed_targeted_denial=false
.targeted_provider_calls_intercepted=13
.any_targeted_optional_provider_load_seen=false
.scenarios[0].actual_GPU_acceleration_or_DMABuf_fallback_verified=true
.scenarios[1].media_decoding_fallback_verified=true
.all_direct_indirect_dynamic_loader_routes_covered=true
.user_endeavouros_hyprland_qa_done=true
.source_pruning_authorized=true
.m3_sixth_gate_closed=true
.release_ready=true
FORGERIES
test "$count" -eq 22
echo "PASS: observed-denial versus no-hit graphical Wayland classification"
echo "PASS: $count/$count forged source, package, frame, attachment, denial and release states rejected"
echo "LIMIT: fixture only; no browser launched or DMA-BUF/VA-API acceleration tested"
