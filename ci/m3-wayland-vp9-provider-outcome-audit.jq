# Review the source-pinned non-headless Weston/Pixman VP9+canvas+WebGL2
# media experiment without confusing browser video progress and actual
# native provider-denial requests or identifying a hardware decoder.
def need($ok;$msg): if $ok then true else error($msg) end;
def sha40: type=="string" and test("^[0-9a-f]{40}$");
def sha64: type=="string" and test("^[0-9a-f]{64}$");
def nat: type=="number" and .>=0 and .==floor;
def decoded($r):
  $r.observed_video_state.found==true and
  ($r.observed_video_state.time|type)=="number" and
  $r.observed_video_state.time>=0.35 and
  ($r.observed_video_state.frames|type)=="number" and
  $r.observed_video_state.frames>=2 and
  $r.observed_video_state.width==192 and
  $r.observed_video_state.height==108 and
  $r.observed_video_state.error==null and
  $r.observed_video_state.playRejected==null;
def checked_mode:
  .actual_packaged_browser_session==true and
  .webdriver_browser_responsive==true and
  .isolated_profile_preserved==true and
  .actual_webdriver_png_screenshot==true and
  (.ffmpeg_denials_before_video_navigation|nat) and
  (.ffmpeg_denials_after_video_navigation|nat) and
  .ffmpeg_denials_after_video_navigation>=.ffmpeg_denials_before_video_navigation and
  .new_denials_during_video_navigation==
    (.ffmpeg_denials_after_video_navigation-.ffmpeg_denials_before_video_navigation) and
  (.browser_interposer_attached|type)=="boolean" and
  (.vp9_decoded_frames_and_time_verified|type)=="boolean" and
  .vp9_decoded_frames_and_time_verified==decoded(.) and
  (.canvas_video_readback|type)=="boolean" and
  (.webgl2_context_available|type)=="boolean" and
  (.observed_graphics_state|type)=="object" and
  .canvas_video_readback==(.observed_graphics_state.canvas_video_readback==true) and
  .webgl2_context_available==(.observed_graphics_state.webgl2_context_available==true) and
  .media_error_observed==(.observed_video_state.error!=null);

. as $r |
need(($expected_compiled_source|sha40) and
     ($expected_harness_source|sha40) and
     ($expected_package_sha256|sha64) and
     $r.schema_version==1 and
     $r.status=="real_packaged_non_headless_Wayland_VP9_video_canvas_provider_denial" and
     $r.native_source_commit==$expected_compiled_source and
     $r.test_harness_commit==$expected_harness_source and
     $r.verified_normal_packaged_archive_sha256==$expected_package_sha256 and
     $r.private_Weston_pixman_compositor_available==true and
     $r.actual_GPU_or_DMABuf_provider_execution_proven==false and
     $r.hardware_video_decoder_identified==false and
     $r.complete_indirect_loader_graph_proven==false and
     $r.restricted_to_disposable_localhost_media_probe==true and
     $r.target_endeavouros_hyprland_verified==false and
     $r.user_normal_profile_or_credentials_used==false and
     $r.source_pruning_authorized==false and
     $r.m3_sixth_gate_closed==false and
     $r.release_ready==false and
     ($r.modes|type)=="array" and
     ($r.modes|length)==3 and
     ([$r.modes[].mode]|sort)==["baseline","gbm","vaapi"];
     "Invalid authenticated source/package or false GPU/safety claims") |
need(all($r.modes[]; checked_mode);
     "Inconsistent decoded frames, canvas, WebDriver screenshot or denial counts") |
($r.modes[]|select(.mode=="baseline")) as $b |
($r.modes[]|select(.mode=="gbm")) as $g |
($r.modes[]|select(.mode=="vaapi")) as $v |
need($r.baseline_playback_verified==decoded($b) and
     $r.baseline_playback_verified==true and
     $r.all_real_browser_sessions_safe==true and
     $r.gbm_video_playback_verified==decoded($g) and
     $r.vaapi_video_playback_verified==decoded($v) and
     $b.browser_interposer_attached==false and
     $b.ffmpeg_denials_before_video_navigation==0 and
     $b.ffmpeg_denials_after_video_navigation==0 and
     $g.browser_interposer_attached==true and
     $v.browser_interposer_attached==true;
     "Baseline, denial attachment, or aggregate playback claim invalid") |
{
  schema_version:1,
  status:"conservative_real_wayland_vp9_graphics_provider_outcome_classified",
  compiled_browser_source:$r.native_source_commit,
  test_harness_source:$r.test_harness_commit,
  normal_browser_package_sha256:$r.verified_normal_packaged_archive_sha256,
  normal_wayland_vp9_video_verified:true,
  normal_canvas_video_readback_measured:$b.canvas_video_readback,
  normal_webgl2_context_available_measured:$b.webgl2_context_available,
  gbm_denial_requests_before_media_navigation:$g.ffmpeg_denials_before_video_navigation,
  gbm_denial_requests_after_media_navigation:$g.ffmpeg_denials_after_video_navigation,
  gbm_denial_requests_added_after_navigation:$g.new_denials_during_video_navigation,
  gbm_provider_denial_observed:($g.ffmpeg_denials_after_video_navigation>0),
  gbm_wayland_video_decoded_with_provider_denial:$g.vp9_decoded_frames_and_time_verified,
  vaapi_denial_requests_before_media_navigation:$v.ffmpeg_denials_before_video_navigation,
  vaapi_denial_requests_after_media_navigation:$v.ffmpeg_denials_after_video_navigation,
  vaapi_denial_requests_added_after_navigation:$v.new_denials_during_video_navigation,
  vaapi_provider_denial_observed:($v.ffmpeg_denials_after_video_navigation>0),
  vaapi_wayland_video_decoded_with_provider_denial:$v.vp9_decoded_frames_and_time_verified,
  video_decoder_implementation_identified:false,
  compositor_or_hardware_DMA_BUF_path_verified:false,
  actual_GPU_hardware_fallback_proven:false,
  VA_API_hardware_decoding_fallback_proven:false,
  sandbox_and_nonlocal_egress_guaranteed:false,
  all_native_loader_and_FFI_routes_closed:false,
  target_workstation_accepted:false,
  source_pruning_authorized:false,
  m3_sixth_gate_closed:false,
  release_ready:false
}