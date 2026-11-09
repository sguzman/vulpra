#!/usr/bin/env bash
# No browser build. Reject forged source, video/Wayland, canvas, denial and
# premature GPU/VA-API/release closure claims in authentic report schema.
set -euo pipefail
filter=ci/m3-wayland-vp9-provider-outcome-audit.jq
test -s "$filter"
temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT
source_sha="$(printf 'a%.0s' {1..40})"
harness_sha="$(printf 'b%.0s' {1..40})"
package_sha="$(printf 'c%.0s' {1..64})"
audit() {
  jq -e --arg expected_compiled_source "$source_sha" \
    --arg expected_harness_source "$harness_sha" \
    --arg expected_package_sha256 "$package_sha" \
    -f "$filter" "$1"
}
jq -n '{
  schema_version:1,
  status:"real_packaged_non_headless_Wayland_VP9_video_canvas_provider_denial",
  native_source_commit:("a"*40),test_harness_commit:("b"*40),
  verified_normal_packaged_archive_sha256:("c"*64),
  private_Weston_pixman_compositor_available:true,
  actual_GPU_or_DMABuf_provider_execution_proven:false,
  hardware_video_decoder_identified:false,
  complete_indirect_loader_graph_proven:false,
  restricted_to_disposable_localhost_media_probe:true,
  target_endeavouros_hyprland_verified:false,
  user_normal_profile_or_credentials_used:false,
  source_pruning_authorized:false,m3_sixth_gate_closed:false,release_ready:false,
  baseline_playback_verified:true,all_real_browser_sessions_safe:true,
  gbm_video_playback_verified:true,vaapi_video_playback_verified:true,
  modes:[
    {mode:"baseline",actual_packaged_browser_session:true,
     browser_interposer_attached:false,
     ffmpeg_denials_before_video_navigation:0,
     ffmpeg_denials_after_video_navigation:0,
     new_denials_during_video_navigation:0,
     vp9_decoded_frames_and_time_verified:true,
     actual_webdriver_png_screenshot:true,
     canvas_video_readback:true,webgl2_context_available:false,
     observed_graphics_state:{canvas_video_readback:true,webgl2_context_available:false,
                              graphics_error:null},
     media_error_observed:false,webdriver_browser_responsive:true,
     isolated_profile_preserved:true,
     observed_video_state:{found:true,time:0.5,frames:6,width:192,height:108,
                           error:null,playRejected:null}},
    {mode:"gbm",actual_packaged_browser_session:true,
     browser_interposer_attached:true,
     ffmpeg_denials_before_video_navigation:1,
     ffmpeg_denials_after_video_navigation:1,
     new_denials_during_video_navigation:0,
     vp9_decoded_frames_and_time_verified:true,
     actual_webdriver_png_screenshot:true,
     canvas_video_readback:true,webgl2_context_available:false,
     observed_graphics_state:{canvas_video_readback:true,webgl2_context_available:false,
                              graphics_error:null},
     media_error_observed:false,webdriver_browser_responsive:true,
     isolated_profile_preserved:true,
     observed_video_state:{found:true,time:0.6,frames:8,width:192,height:108,
                           error:null,playRejected:null}},
    {mode:"vaapi",actual_packaged_browser_session:true,
     browser_interposer_attached:true,
     ffmpeg_denials_before_video_navigation:0,
     ffmpeg_denials_after_video_navigation:0,
     new_denials_during_video_navigation:0,
     vp9_decoded_frames_and_time_verified:true,
     actual_webdriver_png_screenshot:true,
     canvas_video_readback:true,webgl2_context_available:false,
     observed_graphics_state:{canvas_video_readback:true,webgl2_context_available:false,
                              graphics_error:null},
     media_error_observed:false,webdriver_browser_responsive:true,
     isolated_profile_preserved:true,
     observed_video_state:{found:true,time:0.6,frames:8,width:192,height:108,
                           error:null,playRejected:null}}
  ]
}' > "$temp/genuine.json"
audit "$temp/genuine.json" > "$temp/classified.json"
jq -e '.gbm_provider_denial_observed==true and
  .vaapi_provider_denial_observed==false and
  .normal_canvas_video_readback_measured==true and
  .normal_webgl2_context_available_measured==false and
  .VA_API_hardware_decoding_fallback_proven==false and
  .m3_sixth_gate_closed==false' "$temp/classified.json" >/dev/null

# A measured post-navigation request is a distinct observation, not proof of
# causation by the video decoder or GPU hardware fallback.
jq '.modes[2].ffmpeg_denials_after_video_navigation=2 |
    .modes[2].new_denials_during_video_navigation=2' "$temp/genuine.json" > "$temp/post-nav.json"
audit "$temp/post-nav.json" > "$temp/post-nav-output.json"
jq -e '.vaapi_provider_denial_observed==true and
  .vaapi_denial_requests_added_after_navigation==2 and
  .VA_API_hardware_decoding_fallback_proven==false and
  .actual_GPU_hardware_fallback_proven==false' "$temp/post-nav-output.json" >/dev/null

count=0
reject() {
  jq "$1" "$temp/genuine.json" > "$temp/forged.json"
  if audit "$temp/forged.json" > "$temp/false-accepted.json" 2>/dev/null; then
    echo "FAIL: accepted forged Wayland VP9 provider claim: $1" >&2
    exit 1
  fi
  count=$((count+1))
}
while IFS= read -r mutation; do
  reject "$mutation"
done <<'FORGERIES'
.native_source_commit=("0"*40)
.test_harness_commit=("0"*40)
.verified_normal_packaged_archive_sha256=("0"*64)
.private_Weston_pixman_compositor_available=false
.actual_GPU_or_DMAbuf_provider_execution_proven=true
.hardware_video_decoder_identified=true
.complete_indirect_loader_graph_proven=true
.target_endeavouros_hyprland_verified=true
.user_normal_profile_or_credentials_used=true
.source_pruning_authorized=true
.m3_sixth_gate_closed=true
.release_ready=true
.modes[0].observed_video_state.frames=0
.modes[0].observed_video_state.time=0
.modes[0].observed_video_state.error=4
.modes[0].media_error_observed=true
.modes[0].actual_webdriver_png_screenshot=false
.modes[0].canvas_video_readback=false
.modes[1].browser_interposer_attached=false
.modes[1].ffmpeg_denials_after_video_navigation=0
.modes[1].new_denials_during_video_navigation=2
.modes[1].observed_graphics_state.canvas_video_readback=false
.modes[2].isolated_profile_preserved=false
.modes[2].observed_video_state.playRejected="NotSupportedError"
.modes[2].mode="gbm"
.gbm_video_playback_verified=false
.all_real_browser_sessions_safe=false
FORGERIES
test "$count" -eq 27
echo "PASS: baseline, GBM-denied and VAAPI-no-hit evidence distinguished"
echo "PASS: $count/$count falsified media, graphics, integrity and release states rejected"
echo "LIMIT: fixture only; no real browser, GPU, DMA-BUF or hardware VAAPI outcome proven"
