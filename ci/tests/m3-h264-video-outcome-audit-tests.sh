#!/usr/bin/env bash
# Adversarially check that source-bound H264 WebDriver report validation never
# turns startup-only FFmpeg denial, stale counters, stalled video or media errors
# into a claim of media-triggered loading or safe decoder fallback.
set -euo pipefail
filter=ci/m3-h264-video-outcome-audit.jq
test -s "$filter"
audit() {
  jq -e --arg expected_source_commit "$(printf 'a%.0s' {1..40})" \
    --arg expected_package_sha256 "$(printf 'b%.0s' {1..64})" \
    -f "$filter" "$1"
}
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
jq -n '{
  schema_version:1,
  status:"real_packaged_H264_WebDriver_video_decode_with_FFmpeg_denial",
  source_commit:("a"*40),
  normal_packaged_archive_sha256:("b"*64),
  fixture_H264_codec_validated:true,
  real_browser_decoded_frames_and_time_measured:true,
  baseline_H264_playback_passed:true,
  denied_H264_playback_passed:false,
  denied_H264_media_error_observed:true,
  denied_FFmpeg_loader_attempts:14,
  denial_attempts_after_video_navigation:0,
  exact_source_private_webdriver_modes_safe:true,
  real_denied_FFmpeg_attempt_observed:true,
  alternative_software_H264_decoder_fallback_proven:false,
  VAAPI_Wayland_DMABuf_runtime_fallback_proven:false,
  complete_indirect_dynamic_loader_graph_closed:false,
  source_pruning_authorized:false,
  m3_sixth_gate_closed:false,
  release_ready:false,
  modes:[
    {
      mode:"baseline",actual_packaged_browser_session:true,
      browser_interposer_attached:false,
      ffmpeg_denials_before_video_navigation:0,
      ffmpeg_denials_after_video_navigation:0,
      new_denials_during_video_navigation:0,
      h264_decoded_frames_and_time_verified:true,
      media_error_observed:false,
      webdriver_browser_responsive:true,
      isolated_profile_preserved:true,
      observed_video_state:{
        found:true,time:1.5,frames:22,width:192,height:108,
        error:null,playRejected:null
      }
    },
    {
      mode:"denied",actual_packaged_browser_session:true,
      browser_interposer_attached:true,
      ffmpeg_denials_before_video_navigation:14,
      ffmpeg_denials_after_video_navigation:14,
      new_denials_during_video_navigation:0,
      h264_decoded_frames_and_time_verified:false,
      media_error_observed:true,
      webdriver_browser_responsive:true,
      isolated_profile_preserved:true,
      observed_video_state:{
        found:true,time:0,frames:0,width:0,height:0,
        error:4,playRejected:"NotSupportedError"
      }
    }
  ]
}' > "$work/original.json"
audit "$work/original.json" > "$work/first.json"
jq -e '
  .actual_normal_H264_frames_and_time_verified == true and
  .observed_denied_ffmpeg_loads_in_session==14 and
  .ffmpeg_loads_denied_before_media_navigation==14 and
  .ffmpeg_additional_denials_observed_after_media_navigation==0 and
  .additional_ffmpeg_denials_observed_after_media_navigation==false and
  .zero_new_denials_means_media_specific_library_attempt_not_established==true and
  .ffmpeg_requests_causally_proven_to_originate_in_H264_decoder==false and
  .H264_decoding_with_FFmpeg_denied_measured==false and
  .H264_media_error_with_FFmpeg_denied_measured==true and
  .alternative_software_codec_fallback_proven==false and
  .m3_sixth_gate_closed==false and .source_pruning_authorized==false
' "$work/first.json" >/dev/null

# A positive post-navigation *increment* has distinct evidence, and even
# that does not establish which browser code path caused the load.
jq '.modes[1].ffmpeg_denials_after_video_navigation=16 |
    .modes[1].new_denials_during_video_navigation=2 |
    .denied_FFmpeg_loader_attempts=16 |
    .denial_attempts_after_video_navigation=2' "$work/original.json" > "$work/post-nav.json"
audit "$work/post-nav.json" > "$work/second.json"
jq -e '
  .ffmpeg_additional_denials_observed_after_media_navigation==2 and
  .additional_ffmpeg_denials_observed_after_media_navigation==true and
  .zero_new_denials_means_media_specific_library_attempt_not_established==false and
  .ffmpeg_requests_causally_proven_to_originate_in_H264_decoder==false and
  .alternative_software_codec_fallback_proven==false and
  .m3_sixth_gate_closed==false
' "$work/second.json" >/dev/null

# Even a successful denied playback mode cannot be *assumed* to have used
# an alternate software decoder without separately proving its identity.
jq '.modes[1].observed_video_state={
       found:true,time:1.6,frames:23,width:192,height:108,
       error:null,playRejected:null
     } |
     .modes[1].h264_decoded_frames_and_time_verified=true |
     .modes[1].media_error_observed=false |
     .denied_H264_playback_passed=true |
     .denied_H264_media_error_observed=false' "$work/post-nav.json" > "$work/playable.json"
audit "$work/playable.json" > "$work/third.json"
jq -e '
  .H264_decoding_with_FFmpeg_denied_measured==true and
  .additional_ffmpeg_denials_observed_after_media_navigation==true and
  .alternative_software_codec_fallback_proven==false and
  .m3_sixth_gate_closed==false
' "$work/third.json" >/dev/null

count=0
reject() {
  local alteration="$1"
  jq "$alteration" "$work/original.json" > "$work/forged.json"
  if audit "$work/forged.json" > "$work/accepted-bad.json" 2>/dev/null; then
    echo "FAIL: forged H264 evidence accepted: $alteration" >&2
    exit 1
  fi
  count=$((count + 1))
}
while IFS= read -r mutation; do
  reject "$mutation"
done <<'FORGERIES'
.source_commit=("0"*40)
.normal_packaged_archive_sha256=("0"*64)
.m3_sixth_gate_closed=true
.source_pruning_authorized=true
.release_ready=true
.modes[0].observed_video_state.frames=0
.modes[0].observed_video_state.time=0.1
.modes[0].observed_video_state.error=4
.modes[0].observed_video_state.width=0
.modes[1].browser_interposer_attached=false
.modes[1].ffmpeg_denials_after_video_navigation=13
.modes[1].new_denials_during_video_navigation=4
.modes[1].observed_video_state.error=null
.modes[1].h264_decoded_frames_and_time_verified=true
.modes[1].media_error_observed=false
.denied_H264_playback_passed=true
.denied_FFmpeg_loader_attempts=0
.exact_source_private_webdriver_modes_safe=false
.modes[0].mode="denied"
.modes[0].isolated_profile_preserved=false
FORGERIES
test "$count" -eq 20
echo "PASS: startup-only denial, post-navigation load, and denied-playback outcomes are correctly distinguished"
echo "PASS: 20/20 forged WebDriver frame/error/loader/profile/release states rejected"
echo "LIMIT: synthetic evidence classifier tests; no actual H264 browser run or decoder fallback established"
