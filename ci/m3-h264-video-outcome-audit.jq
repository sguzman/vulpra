# Independent, conservative validator of the real source-matched packaged
# H.264 WebDriver report. It rejects fake playback, stale counters and
# contradictory media errors. A loader attempt observed before navigation
# is NOT evidence of a load triggered during media playback.
def require($ok;$msg): if $ok then true else error($msg) end;
def sha40: type=="string" and test("^[0-9a-f]{40}$");
def sha64: type=="string" and test("^[0-9a-f]{64}$");
def integer_nonnegative: type=="number" and .>=0 and .==floor;
def decoded($row): ($row.observed_video_state.found==true and
  ($row.observed_video_state.time|type)=="number" and
  $row.observed_video_state.time>=0.35 and
  $row.observed_video_state.width==192 and
  $row.observed_video_state.height==108 and
  ($row.observed_video_state.frames|type)=="number" and
  $row.observed_video_state.frames>=2 and
  $row.observed_video_state.error==null and
  $row.observed_video_state.playRejected==null);

. as $report |
require($report.schema_version==1 and
        $report.status=="real_packaged_H264_WebDriver_video_decode_with_FFmpeg_denial" and
        ($report.source_commit|sha40) and
        ($report.normal_packaged_archive_sha256|sha64) and
        $report.fixture_H264_codec_validated==true and
        $report.real_browser_decoded_frames_and_time_measured==true and
        $report.alternative_software_H264_decoder_fallback_proven==false and
        $report.VAAPI_Wayland_DMABuf_runtime_fallback_proven==false and
        $report.complete_indirect_dynamic_loader_graph_closed==false and
        $report.m3_sixth_gate_closed==false and
        $report.source_pruning_authorized==false and
        $report.release_ready==false and
        ($report.modes|type)=="array" and
        ($report.modes|length)==2 and
        ([ $report.modes[].mode ]|sort)==["baseline","denied"];
        "Missing exact bounded normal/denied H264 evidence or false acceptance") |
($report.modes[] | select(.mode=="baseline")) as $b |
($report.modes[] | select(.mode=="denied")) as $d |
require(all($report.modes[];
    .actual_packaged_browser_session==true and
    .webdriver_browser_responsive==true and
    .isolated_profile_preserved==true and
    (.ffmpeg_denials_before_video_navigation|integer_nonnegative) and
    (.ffmpeg_denials_after_video_navigation|integer_nonnegative) and
    .ffmpeg_denials_after_video_navigation >= .ffmpeg_denials_before_video_navigation and
    .new_denials_during_video_navigation ==
      (.ffmpeg_denials_after_video_navigation-.ffmpeg_denials_before_video_navigation) and
    (.browser_interposer_attached|type)=="boolean" and
    (.h264_decoded_frames_and_time_verified|type)=="boolean" and
    (.media_error_observed|type)=="boolean" and
    (.observed_video_state|type)=="object" and
    .h264_decoded_frames_and_time_verified==decoded(.) and
    .media_error_observed==(.observed_video_state.error!=null));
    "Per-session H264 times/decoded frames, errors or denial counters contradictory") |
require($b.h264_decoded_frames_and_time_verified==true and
    $b.ffmpeg_denials_before_video_navigation==0 and
    $b.ffmpeg_denials_after_video_navigation==0 and
    $b.browser_interposer_attached==false and
    $d.browser_interposer_attached==true and
    $d.ffmpeg_denials_after_video_navigation>0 and
    $report.baseline_H264_playback_passed==decoded($b) and
    $report.denied_H264_playback_passed==decoded($d) and
    $report.denied_H264_media_error_observed==$d.media_error_observed and
    $report.denied_FFmpeg_loader_attempts==$d.ffmpeg_denials_after_video_navigation and
    $report.denial_attempts_after_video_navigation==$d.new_denials_during_video_navigation and
    $report.exact_source_private_webdriver_modes_safe==true and
    $report.real_denied_FFmpeg_attempt_observed==true;
    "Baseline frame evidence, denied session attachment or aggregate mismatch") |
{
  schema_version:1,
  status:"conservative_original_packaged_h264_webdriver_media_outcome_classified",
  native_source_commit:$report.source_commit,
  normal_package_sha256:$report.normal_packaged_archive_sha256,
  actual_normal_H264_frames_and_time_verified:true,
  observed_denied_ffmpeg_loads_in_session:$d.ffmpeg_denials_after_video_navigation,
  ffmpeg_loads_denied_before_media_navigation:$d.ffmpeg_denials_before_video_navigation,
  ffmpeg_additional_denials_observed_after_media_navigation:$d.new_denials_during_video_navigation,
  additional_ffmpeg_denials_observed_after_media_navigation:
    ($d.new_denials_during_video_navigation>0),
  zero_new_denials_means_media_specific_library_attempt_not_established:
    ($d.new_denials_during_video_navigation==0),
  ffmpeg_requests_causally_proven_to_originate_in_H264_decoder:false,
  H264_decoding_with_FFmpeg_denied_measured:decoded($d),
  H264_media_error_with_FFmpeg_denied_measured:$d.media_error_observed,
  failure_without_media_error_possible:(!decoded($d) and !$d.media_error_observed),
  entire_requested_library_argument_and_indirect_graph_proven:false,
  alternative_software_codec_fallback_proven:false,
  hardware_video_or_Wayland_DMABuf_fallback_proven:false,
  source_pruning_authorized:false,
  m3_sixth_gate_closed:false,
  release_ready:false
}
