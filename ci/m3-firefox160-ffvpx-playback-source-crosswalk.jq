# Independent source / real-loader / protected-media behavior reconciliation.
# Actual successful VP9 WebDriver playback with system FFmpeg-denial is not
# evidence of the exact decoder implementation or of any named FFVPX native
# machine-code branch, nor of source deletion / whole dependency closure.
def check($ok;$why): if $ok then . else error($why) end;
def row_ok:
  .source_load_failure_guard_present==true and
  .actual_glibc_initialized_dynamic_request_seen_from_libnspr4==true and
  .observed_native_glibc_request_direct_callsite_attributed==false and
  .compiled_direct_loader_caller_function_proven==false and
  .fallback_exercised==false;

check(($source|length)==1 and ($loader|length)==1 and ($media|length)==1;
  "Requires one authenticated source owner, actual loader and VP9 denial report") |
($source[0]) as $s | ($loader[0]) as $l | ($media[0]) as $m |
check($s.schema_version==1 and
      $s.status=="firefox160_exact_upstream_nss_ffvpx_source_candidates_crosschecked_with_actual_loader_requests" and
      $s.official_release_commit==$upstream and
      $s.assembled_candidate_source_tree==$tree and
      $s.original_native_archive_sha256==$archive and
      $s.original_native_runtime_observation_run==43743231236 and
      $s.original_exact_source_verified_blob_count==10 and
      $s.original_source_files_nonoverlaid_by_vulpra==true and
      $s.source_routes_crosschecked_with_actual_native_loader_requests==4 and
      ($s.source_candidate_rows|length)==4 and
      ($s.source_candidate_rows|map(.id)|sort)==["ffvpx_codec","ffvpx_util","nss_freebl","nss_softoken"] and
      all($s.source_candidate_rows[];row_ok) and
      ([ $s.source_candidate_rows[] | select(.id=="ffvpx_codec" or .id=="ffvpx_util") |
         .candidate_provider ]|sort)==["libmozavcodec.so","libmozavutil.so"] and
      $s.exact_runtime_loader_caller_source_function_verified==false and
      $s.exact_machine_dlopen_symbol_arguments_verified==false and
      $s.all_conditional_ffi_and_protected_fallbacks_exercised==false and
      $s.source_pruning_authorized==false and
      $s.security_current==false and $s.release_ready==false and
      $s.m3_sixth_gate_closed==false;
  "Source owner identity, protected guard, provider or false callsite claim") |
check($l.schema_version==1 and
      $l.status=="firefox160_real_browser_native_glibc_initialized_loader_request_edges" and
      $l.original_native_source_commit==$upstream and
      $l.original_native_archive_sha256==$archive and
      $l.browser_pid_traces_with_actual_libxul_initialization==2 and
      $l.initialized_dynamic_request_edge_count==18 and
      $l.only_same_browser_pid_trace_initialized_targets_classified_as_initialized==true and
      all(["libmozavcodec.so","libmozavutil.so"][];
        . as $lib |
        any($l.initialized_dynamic_request_edges[];
          .requester_basename=="libnspr4.so" and .requested_library_basename==$lib)) and
      $l.all_native_feature_fallbacks_exercised==false and
      $l.all_conditional_dlopen_and_dlsym_edges_proven==false and
      $l.raw_loader_logs_paths_pids_symbols_or_profile_data_exported==false and
      $l.source_pruning_authorized==false and
      $l.m3_sixth_gate_closed==false;
  "Authentic actual FFVPX NSPR dynamic requests or conservative runtime scope missing") |
check($m.schema_version==1 and
      $m.status=="real_packaged_VP9_WebDriver_video_decode_with_FFmpeg_denial" and
      $m.source_commit=="0624235fdc956ab18af3c3f310b3588ca72fff61" and
      $m.test_harness_commit=="dbdb564bcc09cb84810a17a10c46781872595dad" and
      $m.normal_packaged_archive_sha256==$archive and
      $m.original_native_run_id=="43138458940" and
      $m.firefox160_candidate_git_tree==$tree and
      $m.original_package_reused_without_browser_rebuild==true and
      $m.fixture_VP9_codec_validated==true and
      $m.real_browser_decoded_frames_and_time_measured==true and
      $m.baseline_VP9_playback_passed==true and
      $m.denied_VP9_playback_passed==true and
      $m.denied_VP9_media_error_observed==false and
      $m.denied_FFmpeg_loader_attempts==14 and
      $m.denial_attempts_after_video_navigation==0 and
      $m.VP9_playback_with_FFmpeg_denied_demonstrated==true and
      $m.real_denied_FFmpeg_attempt_observed==true and
      $m.exact_source_private_webdriver_modes_safe==true and
      $m.specific_VP9_decoder_implementation_identified==false and
      $m.alternative_H264_software_decoder_fallback_proven==false and
      $m.VAAPI_Wayland_DMABuf_runtime_fallback_proven==false and
      $m.complete_indirect_dynamic_loader_graph_closed==false and
      $m.tested_only_temporary_headless_localhost_playback==true and
      $m.source_pruning_authorized==false and
      $m.security_current==false and
      $m.release_ready==false and
      $m.m3_sixth_gate_closed==false and
      ($m.modes|length)==2 and
      ($m.modes|map(.mode)|sort)==["baseline","denied"] and
      all($m.modes[];
         .actual_packaged_browser_session==true and
         .vp9_decoded_frames_and_time_verified==true and
         .media_error_observed==false and
         .webdriver_browser_responsive==true and
         .isolated_profile_preserved==true and
         .observed_video_state.found==true and
         .observed_video_state.time>=0.35 and
         .observed_video_state.width==192 and
         .observed_video_state.height==108 and
         .observed_video_state.frames>=2) and
      ([ $m.modes[]|select(.mode=="denied") |
        .browser_interposer_attached and
        .ffmpeg_denials_before_video_navigation==14 and
        .ffmpeg_denials_after_video_navigation==14 and
        .new_denials_during_video_navigation==0 ][0]==true);
  "Forged original VP9 denial outcome, source/payload or claim of decoder/fallback attribution") |
{
  schema_version:1,
  status:"firefox160_pinned_ffvpx_source_and_real_init_consistent_with_vp9_under_ffmpeg_denial",
  upstream_release_commit:$upstream,
  verified_vulpra_candidate_tree:$tree,
  source_pinned_original_native_archive_sha256:$archive,
  source_owner_validation_run:43745057569,
  native_initialization_observation_run:43743231236,
  actual_protected_VP9_denial_playback_run:43724363730,
  verified_original_source_owner_blobs:10,
  original_source_paths_nonoverlaid_by_vulpra:true,
  observed_initialized_ffvpx_provider_names:["libmozavcodec.so","libmozavutil.so"],
  official_ffvpx_loader_and_build_source_candidates:
    [$s.source_candidate_rows[] | select(.id=="ffvpx_codec" or .id=="ffvpx_util") |
      {id, candidate_provider, owner_path,linked_build_manifest}],
  actual_VP9_decoded_under_baseline:true,
  actual_VP9_decoded_under_system_ffmpeg_denial:true,
  actual_ffmpeg_denied_loader_attempts:14,
  all_ffmpeg_denial_attempts_before_video_navigation:true,
  ffvpx_was_exact_decoder_in_VP9_playback_proven:false,
  FFVPX_compiled_machine_loader_callsite_attributed:false,
  actual_FFVPX_missing_provider_guard_exercised:false,
  system_ffmpeg_denial_equals_ffvpx_denial:false,
  all_H264_or_hardware_video_fallbacks_proven:false,
  same_webdriver_run_for_loader_and_VP9_denial:false,
  complete_rust_CXX_ffi_and_dlopen_dependency_graph_proven:false,
  target_endeavouros_hyprland_verified:false,
  source_pruning_authorized:false,
  security_current:false,
  release_ready:false,
  m3_sixth_gate_closed:false
}
