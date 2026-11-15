# Read-only independent four-artifact source/runtime/media comparison:
# original 10-blobs NSS/FFVPX source candidate, actual native glibc loader
# requests, original real system FFmpeg denial VP9 WebDriver replay, and new
# actual bundled FFVPX denial VP9 WebDriver replay. One native compiled archive;
# distinct experiments, NOT a single decoder callstack or a global fallback.
def check($ok;$reason): if $ok then . else error($reason) end;
def has_ffvpx($xs;$p): any($xs[];
   .requester_basename=="libnspr4.so" and .requested_library_basename==$p);
check(($source|length)==1 and ($loader|length)==1 and
      ($ffmpeg|length)==1 and ($ffvpx|length)==1;
  "Exactly one verified source, loader, FFmpeg and FFVPX real media report required") |
($source[0]) as $s | ($loader[0]) as $l |
($ffmpeg[0]) as $f | ($ffvpx[0]) as $v |
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
      ([ $s.source_candidate_rows[]|select(.id=="ffvpx_codec" or .id=="ffvpx_util")|
         .candidate_provider ]|sort)==["libmozavcodec.so","libmozavutil.so"] and
      all($s.source_candidate_rows[];
        .source_load_failure_guard_present==true and
        .actual_glibc_initialized_dynamic_request_seen_from_libnspr4==true and
        .observed_native_glibc_request_direct_callsite_attributed==false and
        .compiled_direct_loader_caller_function_proven==false and
        .fallback_exercised==false) and
      $s.exact_runtime_loader_caller_source_function_verified==false and
      $s.exact_machine_dlopen_symbol_arguments_verified==false and
      $s.all_conditional_ffi_and_protected_fallbacks_exercised==false and
      $s.security_current==false and $s.release_ready==false and
      $s.source_pruning_authorized==false and $s.m3_sixth_gate_closed==false;
  "Forged original exact-source/FFVPX names/guard/source fallback claim") |
check($l.schema_version==1 and
      $l.status=="firefox160_real_browser_native_glibc_initialized_loader_request_edges" and
      $l.original_native_source_commit==$upstream and
      $l.original_native_archive_sha256==$archive and
      $l.browser_pid_traces_with_actual_libxul_initialization==2 and
      $l.observed_initialized_library_basename_count==94 and
      $l.initialized_dynamic_request_edge_count==18 and
      ($l.initialized_dynamic_request_edges|length)==18 and
      has_ffvpx($l.initialized_dynamic_request_edges;"libmozavcodec.so") and
      has_ffvpx($l.initialized_dynamic_request_edges;"libmozavutil.so") and
      $l.only_same_browser_pid_trace_initialized_targets_classified_as_initialized==true and
      $l.glibc_reported_request_relationships_not_proven_callstacks==true and
      $l.all_conditional_dlopen_and_dlsym_edges_proven==false and
      $l.all_native_feature_fallbacks_exercised==false and
      $l.raw_loader_logs_paths_pids_symbols_or_profile_data_exported==false and
      $l.source_pruning_authorized==false and $l.m3_sixth_gate_closed==false;
  "Forged actual original FFVPX native glibc init-observation or scope") |
check($f.schema_version==1 and
      $f.status=="real_packaged_VP9_WebDriver_video_decode_with_FFmpeg_denial" and
      $f.source_commit=="0624235fdc956ab18af3c3f310b3588ca72fff61" and
      $f.test_harness_commit=="dbdb564bcc09cb84810a17a10c46781872595dad" and
      $f.normal_packaged_archive_sha256==$archive and
      $f.firefox160_candidate_git_tree==$tree and
      $f.original_native_run_id=="43138458940" and
      $f.original_package_reused_without_browser_rebuild==true and
      $f.fixture_VP9_codec_validated==true and
      $f.baseline_VP9_playback_passed==true and
      $f.denied_VP9_playback_passed==true and
      $f.denied_VP9_media_error_observed==false and
      $f.denied_FFmpeg_loader_attempts==14 and
      $f.denial_attempts_after_video_navigation==0 and
      $f.VP9_playback_with_FFmpeg_denied_demonstrated==true and
      $f.real_denied_FFmpeg_attempt_observed==true and
      $f.exact_source_private_webdriver_modes_safe==true and
      $f.specific_VP9_decoder_implementation_identified==false and
      $f.alternative_H264_software_decoder_fallback_proven==false and
      $f.complete_indirect_dynamic_loader_graph_closed==false and
      $f.security_current==false and $f.release_ready==false and
      $f.source_pruning_authorized==false and $f.m3_sixth_gate_closed==false;
  "Forged historical actual system FFmpeg-denied VP9 browser evidence") |
check($v.schema_version==1 and
      $v.status=="real_firefox160_native_bundled_ffvpx_dlopen_denial_and_vp9_media_outcome" and
      $v.original_upstream_release_commit==$upstream and
      $v.original_vulpra_source_tree==$tree and
      $v.original_compiled_native_archive_sha256==$archive and
      $v.original_source_owner_validation_run==43745057569 and
      $v.original_native_build_run==43138458940 and
      $v.native_browser_unmodified_replayed==true and
      $v.authentic_pinned_source_owner_rows==10 and
      $v.exact_source_owned_bundled_ffvpx_names==
        ["libmozavcodec.so","libmozavutil.so"] and
      $v.ffvpx_actual_native_denied_dlopen_attempt_count==2 and
      $v.ffvpx_denials_during_video_navigation==0 and
      $v.baseline_vp9_decoded_frames_and_advancing_time==true and
      $v.with_bundled_ffvpx_denied_vp9_decoded_frames_and_advancing_time==true and
      $v.with_bundled_ffvpx_denied_media_error_observed==false and
      $v.observed_denied_vp9_outcome=="decoded_frames_and_advancing_time" and
      $v.browser_and_temporary_profile_preserved_under_both_modes==true and
      $v.interposer_actually_attached_to_browser==true and
      $v.altered_system_library_files==false and
      $v.raw_dlopen_names_PIDs_or_profiles_archived==false and
      $v.compiled_machine_caller_of_ffvpx_dlopen_known==false and
      $v.actual_ffvpx_missing_provider_failure_guard_source_branch_attributed==false and
      $v.successful_alternative_decoder_identified==false and
      $v.all_protected_media_features_and_fallbacks_proven==false and
      $v.target_endeavouros_hyprland_verified==false and
      $v.source_pruning_authorized==false and
      $v.security_current==false and $v.release_ready==false and
      $v.m3_sixth_gate_closed==false;
  "Forged actual bundled FFVPX-denied VP9 outcome/host/bytes/false-fallback claim") |
{
  schema_version:1,
  status:"exact_firefox160_source_and_actual_ffvpx_vs_ffmpeg_denial_vp9_proof",
  original_upstream_source_commit:$upstream,
  materialized_vulpra_source_tree:$tree,
  exact_original_compiled_package_sha256:$archive,
  verified_original_source_owner_blobs:10,
  original_source_owner_and_native_loader_producer_runs:[43745057569,43743231236],
  actual_real_vp9_webdriver_denial_producer_runs:{
    system_ffmpeg:43724363730,bundled_ffvpx:43747140617
  },
  independent_real_browser_workloads_used:true,
  same_native_package_bytes_across_all_source_and_media_reports:true,
  actual_source_and_init_confirmed_ffvpx_candidates:
    ["libmozavcodec.so","libmozavutil.so"],
  baseline_vp9_playback_decoded_in_both_media_workloads:true,
  system_ffmpeg_denied_load_attempts:14,
  bundled_ffvpx_denied_load_attempts:2,
  FFmpeg_denials_after_navigation:0,
  FFVPX_denials_after_navigation:0,
  real_vp9_playback_decoded_under_independent_denial_conditions:true,
  both_denied_media_runs_no_video_error:true,
  both_private_browser_profiles_preserved:true,
  exact_browser_executable_reused_without_build:true,
  no_original_source_or_host_library_files_modified:true,
  raw_traces_or_profiles_archived:false,
  exact_decoder_provider_or_successful_fallback_identified:false,
  FFVPX_missing_provider_source_guard_machine_branch_executed_proven:false,
  FFVPX_and_FFmpeg_denials_are_distinct_provider_experiments:true,
  no_single_workload_combining_both_denials:true,
  all_H264_VAAPI_DMABuf_and_protected_features_proven:false,
  complete_CXX_Rust_FFI_dlopen_dlsym_graph_proven:false,
  target_endeavouros_hyprland_verified:false,
  source_pruning_authorized:false,
  security_current:false,
  release_ready:false,
  m3_sixth_gate_closed:false
}
