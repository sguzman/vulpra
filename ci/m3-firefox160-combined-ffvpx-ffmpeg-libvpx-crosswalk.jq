# Independent original Firefox160 actual real RDD decoder selection,
# source-pinned native package, and combined provider denial reconciliation.
# Two separate genuine producers, not a claim every ffmpeg path was blocked.
def check($ok;$why): if $ok then . else error($why) end;
check(($previous|length)==1 and ($combined|length)==1;
  "One prior source-attested RDD decoder fallback and one real combined denial report required") |
($previous[0]) as $p | ($combined[0]) as $c |
check($p.schema_version==1 and
      $p.status=="firefox160_original_real_rdd_vp9_ffvpx_to_ffmpeg_decoder_fallback_source_verified" and
      $p.original_mozilla_firefox160_commit==$upstream and
      $p.original_vulpra_28_overlay_git_tree==$tree and
      $p.original_native_archive_sha256==$archive and
      $p.original_native_compiled_browser_run==43138458940 and
      $p.prior_source_and_media_crosswalk_run==43747660588 and
      $p.prior_per_soname_denial_crosswalk_run==43748375268 and
      $p.actual_ffvpx_denied_source_logged_decoder_selection_run==43750879381 and
      $p.previous_NSS_FFVPX_source_owner_git_blobs==10 and
      $p.additional_official_MediaFormatReader_change_monitor_remote_decoder_and_linker_git_blobs_verified==10 and
      $p.observed_original_VP9_baseline_decoder_after_video_samples=="ffvpx video decoder (RDD remote)" and
      $p.observed_original_VP9_with_bundled_FFVPX_denied_decoder_after_video_samples=="ffmpeg video decoder (RDD remote)" and
      $p.prior_initial_decoder_wrapper_name_in_both_modes=="MediaChangeMonitor decoder (pending)" and
      $p.initial_decoder_wrapper_is_not_final_backend==true and
      $p.distinct_exact_bundled_ffvpx_dlopen_denials=={"libmozavcodec":1,"libmozavutil":1} and
      $p.source_logged_FFVPX_link_result_NoProvidedLib_denied_mode==true and
      $p.FFVPX_denials_before_video_navigation==2 and
      $p.working_VP9_media_frames_and_time_with_system_FFmpeg_selected_under_FFVPX_denial==true and
      $p.same_video_playback_test_baseline_uses_FFVPX==true and
      $p.no_video_media_error_in_either_mode==true and
      $p.browser_process_and_isolated_profiles_survived_both_modes==true and
      $p.prior_independent_system_FFmpeg_denied_playback_is_a_separate_workload==true and
      $p.raw_MOZ_LOG_or_dlopen_paths_PIDs_uploaded==false and
      $p.direct_machine_code_FFVPX_dlopen_caller_and_branch_proven==false and
      $p.all_codecs_and_media_backends_tested==false and
      $p.all_protected_feature_fallbacks_tested==false and
      $p.complete_native_Rust_CXX_FFI_dlopen_dlsym_graph_proven==false and
      $p.source_pruning_authorized==false and $p.security_current==false and
      $p.release_ready==false and $p.m3_sixth_gate_closed==false;
  "Previously accepted source-bound original FFVPX-to-FFmpeg decoder fallback altered") |
check($c.schema_version==1 and
      $c.status=="original_firefox160_real_VP9_combined_FFVPX_system_FFmpeg_denial_observation" and
      $c.original_release_commit==$upstream and
      $c.original_overlay_candidate_tree==$tree and
      $c.original_native_package_sha256==$archive and
      $c.original_native_producer_run==43138458940 and
      $c.original_source_blob_paths_verified==10 and
      $c.actual_combined_native_browser_test_harness_commit=="9187ef4af33dfb24419d92f44cb3312ec45b3cb0" and
      $c.actual_combined_denied_ffvpx_codec_loads==1 and
      $c.actual_combined_denied_ffvpx_util_loads==1 and
      $c.actual_combined_denied_system_ffmpeg_loads==14 and
      $c.actual_combined_denials_total==16 and
      ($c.actual_combined_denied_ffvpx_codec_loads+
       $c.actual_combined_denied_ffvpx_util_loads+
       $c.actual_combined_denied_system_ffmpeg_loads)==$c.actual_combined_denials_total and
      $c.both_provider_families_actually_denied==true and
      $c.observed_source_FFVPX_NoProvidedLib==true and
      $c.baseline_VP9_decoded_frames_and_time==true and
      $c.combined_denied_VP9_decoded_frames_and_time==true and
      $c.combined_denied_VP9_media_error==false and
      $c.combined_denied_VP9_outcome=="decoded_frames_and_advancing_time" and
      $c.baseline_initial_decoder_descriptions==["MediaChangeMonitor decoder (pending)"] and
      $c.combined_denied_initial_decoder_descriptions==["MediaChangeMonitor decoder (pending)"] and
      $c.baseline_resolved_post_frame_decoders==["ffvpx video decoder (RDD remote)","uninitialized"] and
      $c.combined_denied_resolved_post_frame_decoders==["libvpx video decoder (RDD remote)","uninitialized"] and
      $c.combined_browser_and_private_profiles_preserved==true and
      $c.combined_denial_new_requests_after_video_navigation==0 and
      $c.baseline_original_video_fixture_validated==true and
      $c.same_compiled_original_browser_reused_without_rebuild==true and
      $c.direct_runtime_machine_dlopen_callsite_proven==false and
      $c.all_system_FFmpeg_native_load_paths_denied_proven==false and
      $c.libvpx_decoder_selected_and_actual_frames_proven==false and
      $c.all_codecs_or_video_hardware_fallbacks_proven==false and
      $c.target_Arch_Hyprland_GPU_proven==false and
      $c.all_Rust_CXX_FFI_dlopen_dlsym_dependency_edges_closed==false and
      $c.native_source_pruning_authorized==false and $c.security_current==false and
      $c.release_ready==false and $c.m3_sixth_gate_closed==false and
      $c.raw_native_logs_paths_PIDs_or_profiles_archived==false;
  "Real combined FFVPX/FFmpeg native-denial, libvpx decoder or conservative scope falsified") |
{
  schema_version:1,
  status:"source_attested_original_firefox160_actual_ffvpx_and_ffmpeg_denial_libvpx_rdd_vp9_fallback",
  original_official_firefox160_commit:$upstream,
  materialized_vulpra_28_overlay_git_tree:$tree,
  original_compiled_native_archive_sha256:$archive,
  native_browser_original_producer_run:43138458940,
  prior_independently_accepted_FFVPX_to_FFmpeg_fallback_run:43751456133,
  actual_combined_providers_denied_VP9_webdriver_run:43758489134,
  source_verified_original_decoder_and_linker_git_blob_count:10,
  exact_unmodified_compiled_package_reused:true,
  actual_combined_denied_native_loads:{
    bundled_ffvpx_codec:1,bundled_ffvpx_util:1,system_ffmpeg_libavcodec:14,total:16
  },
  both_native_provider_families_actually_observed_denied:true,
  source_specific_FFVPX_Link_NoProvidedLib_observed:true,
  observed_VP9_baseline_post_frame_decoder:"ffvpx video decoder (RDD remote)",
  observed_VP9_under_combined_denial_post_frame_decoder:"libvpx video decoder (RDD remote)",
  FFVPX_only_denial_elsewhere_selected_FFmpeg_in_separate_real_browser_run:true,
  actual_real_VP9_frames_and_advancing_time_in_both_browser_modes:true,
  observed_VP9_media_error_under_combined_denial:false,
  browser_sessions_and_private_profiles_preserved:true,
  both_provider_denial_requests_before_video_navigation:true,
  exact_Linux_RDD_VP9_libvpx_fallback_source_reported:true,
  overall_all_possible_FFmpeg_providers_absent_proven:false,
  direct_FFVPX_machine_code_callstack_proven:false,
  all_media_codecs_GPU_VAAPI_Wayland_DMABuf_modes_tested:false,
  target_endeavouros_hyprland_device_verified:false,
  native_Rust_CXX_FFI_dlopen_dlsym_closure_complete:false,
  raw_interposer_MOZ_LOG_paths_PIDs_or_profiles_archived:false,
  source_pruning_authorized:false,
  security_current:false,
  release_ready:false,
  m3_sixth_gate_closed:false
}
