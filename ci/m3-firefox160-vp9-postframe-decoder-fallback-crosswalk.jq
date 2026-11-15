# Original Firefox160 real RDD media fallback, source pins independently
# checked by CI workflow. This crosswalk joins three distinct genuine
# successful source/runtime proofs; it never reads private MOZ_LOG raw lines.
def must($value;$reason): if $value then . else error($reason) end;
must(($real|length)==1 and ($prior|length)==1 and ($soname|length)==1;
   "Source-verified native decoder proof requires exactly three original artifacts") |
($real[0]) as $r | ($prior[0]) as $p | ($soname[0]) as $s |
must($p.schema_version==1 and
     $p.status=="exact_firefox160_source_and_actual_ffvpx_vs_ffmpeg_denial_vp9_proof" and
     $p.original_upstream_source_commit==$upstream and
     $p.materialized_vulpra_source_tree==$tree and
     $p.exact_original_compiled_package_sha256==$archive and
     $p.verified_original_source_owner_blobs==10 and
     $p.original_source_owner_and_native_loader_producer_runs==[43745057569,43743231236] and
     $p.same_native_package_bytes_across_all_source_and_media_reports==true and
     $p.actual_source_and_init_confirmed_ffvpx_candidates==["libmozavcodec.so","libmozavutil.so"] and
     $p.system_ffmpeg_denied_load_attempts==14 and
     $p.bundled_ffvpx_denied_load_attempts==2 and
     $p.FFmpeg_denials_after_navigation==0 and $p.FFVPX_denials_after_navigation==0 and
     $p.baseline_vp9_playback_decoded_in_both_media_workloads==true and
     $p.real_vp9_playback_decoded_under_independent_denial_conditions==true and
     $p.both_denied_media_runs_no_video_error==true and
     $p.both_private_browser_profiles_preserved==true and
     $p.exact_decoder_provider_or_successful_fallback_identified==false and
     $p.no_single_workload_combining_both_denials==true and
     $p.complete_CXX_Rust_FFI_dlopen_dlsym_graph_proven==false and
     $p.source_pruning_authorized==false and $p.security_current==false and
     $p.release_ready==false and $p.m3_sixth_gate_closed==false;
   "Forged previous independently verified FFmpeg vs FFVPX native runtime provenance") |
must($s.schema_version==1 and
     $s.status=="original_firefox160_actual_FFVPX_exact_named_dlopen_denials_with_VP9_playback" and
     $s.original_source_commit==$upstream and
     $s.exact_vulpra_candidate_tree==$tree and
     $s.exact_original_native_package_sha256==$archive and
     $s.existing_independent_four_producer_crosswalk_run==43747660588 and
     $s.newly_source_pinned_real_bundled_ffvpx_denial_run==43748031202 and
     $s.source_owner_original_Git_blobs_verified==10 and
     $s.two_separately_denied_native_FFVPX_names==
       [{"name":"libmozavcodec.so","actual_dlopen_denial_count":1},
        {"name":"libmozavutil.so","actual_dlopen_denial_count":1}] and
     $s.total_ffvpx_native_dlopen_denials==2 and
     $s.ffvpx_denials_during_video_navigation==0 and
     $s.previous_system_ffmpeg_native_denials_in_distinct_real_browser_run==14 and
     $s.actual_vp9_video_decoded_in_baseline_and_bundled_FFVPX_denied_browser==true and
     $s.actual_vp9_video_decoded_in_separate_system_FFmpeg_denied_browser==true and
     $s.original_archive_reused_without_browser_build==true and
     $s.exact_decoder_or_successful_fallback_implementation_identified==false and
     $s.FFVPX_source_level_failure_guard_actual_machine_branch_proven==false and
     $s.all_future_dlopen_dlsym_and_Rust_CXX_FFI_proven==false and
     $s.source_pruning_authorized==false and $s.security_current==false and
     $s.release_ready==false and $s.m3_sixth_gate_closed==false;
   "Forged independently checked previous exact per-FFVPX-SONAME native denial") |
must($r.schema_version==1 and
     $r.status=="real_firefox160_native_bundled_ffvpx_dlopen_denial_and_vp9_media_outcome" and
     $r.original_upstream_release_commit==$upstream and
     $r.original_vulpra_source_tree==$tree and
     $r.original_compiled_native_archive_sha256==$archive and
     $r.original_source_owner_validation_run==43745057569 and
     $r.original_native_build_run==43138458940 and
     $r.native_browser_unmodified_replayed==true and
     $r.authentic_pinned_source_owner_rows==10 and
     $r.exact_original_Firefox160_decoder_log_source_blobs_verified==9 and
     $r.exact_source_owned_bundled_ffvpx_names==["libmozavcodec.so","libmozavutil.so"] and
     $r.ffvpx_actual_native_denied_dlopen_attempt_count==2 and
     $r.ffvpx_libmozavcodec_denied_dlopen_attempt_count==1 and
     $r.ffvpx_libmozavutil_denied_dlopen_attempt_count==1 and
     $r.ffvpx_denials_during_video_navigation==0 and
     $r.private_mozilla_ffvpx_decoder_logs_captured==true and
     $r.ffvpx_real_NoProvidedLib_link_failure_logged==true and
     $r.ffvpx_real_NoProvidedLib_link_failure_log_count==1 and
     $r.ffvpx_denied_pdm_log_lines>=1 and
     $r.baseline_mediaformatreader_video_decoder_init_logs==1 and
     $r.denied_mediaformatreader_video_decoder_init_logs==1 and
     $r.baseline_bounded_source_defined_video_decoder_names==
       ["MediaChangeMonitor decoder (pending)"] and
     $r.denied_bounded_source_defined_video_decoder_names==
       ["MediaChangeMonitor decoder (pending)"] and
     $r.baseline_mediaformatreader_video_update_log_count>=1 and
     $r.denied_mediaformatreader_video_update_log_count>=1 and
     $r.baseline_resolved_post_frame_video_decoder_descriptions==
       ["ffvpx video decoder (RDD remote)","uninitialized"] and
     $r.denied_resolved_post_frame_video_decoder_descriptions==
       ["ffmpeg video decoder (RDD remote)","uninitialized"] and
     $r.baseline_vp9_decoded_frames_and_advancing_time==true and
     $r.with_bundled_ffvpx_denied_vp9_decoded_frames_and_advancing_time==true and
     $r.with_bundled_ffvpx_denied_media_error_observed==false and
     $r.observed_denied_vp9_outcome=="decoded_frames_and_advancing_time" and
     $r.browser_and_temporary_profile_preserved_under_both_modes==true and
     $r.interposer_actually_attached_to_browser==true and
     $r.altered_system_library_files==false and
     $r.raw_dlopen_names_PIDs_or_profiles_archived==false and
     $r.compiled_machine_caller_of_ffvpx_dlopen_known==false and
     $r.actual_ffvpx_missing_provider_failure_guard_source_branch_attributed==false and
     $r.exact_decoder_backend_selected_independent_of_source_description_proven==false and
     $r.successful_alternative_decoder_identified==false and
     $r.all_protected_media_features_and_fallbacks_proven==false and
     $r.target_endeavouros_hyprland_verified==false and
     $r.source_pruning_authorized==false and $r.security_current==false and
     $r.release_ready==false and $r.m3_sixth_gate_closed==false;
  "Forged real source-reported post-frame RDD decoder, ABI or failure scope") |
{
  schema_version:1,
  status:"firefox160_original_real_rdd_vp9_ffvpx_to_ffmpeg_decoder_fallback_source_verified",
  original_mozilla_firefox160_commit:$upstream,
  original_vulpra_28_overlay_git_tree:$tree,
  original_native_archive_sha256:$archive,
  original_native_compiled_browser_run:43138458940,
  prior_source_and_media_crosswalk_run:43747660588,
  prior_per_soname_denial_crosswalk_run:43748375268,
  actual_ffvpx_denied_source_logged_decoder_selection_run:43750879381,
  previous_NSS_FFVPX_source_owner_git_blobs:10,
  additional_official_MediaFormatReader_change_monitor_remote_decoder_and_linker_git_blobs_verified:10,
  observed_original_VP9_baseline_decoder_after_video_samples:"ffvpx video decoder (RDD remote)",
  observed_original_VP9_with_bundled_FFVPX_denied_decoder_after_video_samples:"ffmpeg video decoder (RDD remote)",
  prior_initial_decoder_wrapper_name_in_both_modes:"MediaChangeMonitor decoder (pending)",
  initial_decoder_wrapper_is_not_final_backend:true,
  original_mediaformatreader_runtime_update_lines_baseline:$r.baseline_mediaformatreader_video_update_log_count,
  original_mediaformatreader_runtime_update_lines_ffvpx_denied:$r.denied_mediaformatreader_video_update_log_count,
  distinct_exact_bundled_ffvpx_dlopen_denials:{libmozavcodec:1,libmozavutil:1},
  source_logged_FFVPX_link_result_NoProvidedLib_denied_mode:true,
  FFVPX_denials_before_video_navigation:2,
  working_VP9_media_frames_and_time_with_system_FFmpeg_selected_under_FFVPX_denial:true,
  same_video_playback_test_baseline_uses_FFVPX:true,
  no_video_media_error_in_either_mode:true,
  browser_process_and_isolated_profiles_survived_both_modes:true,
  prior_independent_system_FFmpeg_denied_playback_is_a_separate_workload:true,
  raw_MOZ_LOG_or_dlopen_paths_PIDs_uploaded:false,
  source_name_and_RDD_IPC_mapping_verified_not_machine_disassembly:true,
  direct_machine_code_FFVPX_dlopen_caller_and_branch_proven:false,
  actual_hardware_Arch_Hyprland_GPU_test_proven:false,
  all_codecs_and_media_backends_tested:false,
  all_protected_feature_fallbacks_tested:false,
  complete_native_Rust_CXX_FFI_dlopen_dlsym_graph_proven:false,
  source_pruning_authorized:false,
  security_current:false,
  release_ready:false,
  m3_sixth_gate_closed:false
}
