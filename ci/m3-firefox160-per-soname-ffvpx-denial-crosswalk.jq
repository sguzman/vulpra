# Independent original Firefox160 source/package/real media denial comparison.
# The older four-producer artifact independently verified 28-overlay/10-blobs
# exact source + original FFmpeg and FFVPX runtime. A newer actual browser
# replay resolves which named FFVPX libraries were blocked. No raw paths/PIDs.
def assert($ok;$why): if $ok then . else error($why) end;
assert(($old|length)==1 and ($specific|length)==1;
  "Require exactly one previous independent crosswalk and new per-SONAME native browser report") |
($old[0]) as $o | ($specific[0]) as $n |
assert($o.schema_version==1 and
  $o.status=="exact_firefox160_source_and_actual_ffvpx_vs_ffmpeg_denial_vp9_proof" and
  $o.original_upstream_source_commit==$upstream and
  $o.materialized_vulpra_source_tree==$tree and
  $o.exact_original_compiled_package_sha256==$archive and
  $o.verified_original_source_owner_blobs==10 and
  $o.original_source_owner_and_native_loader_producer_runs==[43745057569,43743231236] and
  $o.actual_real_vp9_webdriver_denial_producer_runs==
    {"system_ffmpeg":43724363730,"bundled_ffvpx":43747140617} and
  $o.actual_source_and_init_confirmed_ffvpx_candidates==
    ["libmozavcodec.so","libmozavutil.so"] and
  $o.independent_real_browser_workloads_used==true and
  $o.same_native_package_bytes_across_all_source_and_media_reports==true and
  $o.system_ffmpeg_denied_load_attempts==14 and
  $o.bundled_ffvpx_denied_load_attempts==2 and
  $o.FFmpeg_denials_after_navigation==0 and
  $o.FFVPX_denials_after_navigation==0 and
  $o.baseline_vp9_playback_decoded_in_both_media_workloads==true and
  $o.real_vp9_playback_decoded_under_independent_denial_conditions==true and
  $o.both_denied_media_runs_no_video_error==true and
  $o.both_private_browser_profiles_preserved==true and
  $o.raw_traces_or_profiles_archived==false and
  $o.exact_decoder_provider_or_successful_fallback_identified==false and
  $o.FFVPX_missing_provider_source_guard_machine_branch_executed_proven==false and
  $o.FFVPX_and_FFmpeg_denials_are_distinct_provider_experiments==true and
  $o.no_single_workload_combining_both_denials==true and
  $o.complete_CXX_Rust_FFI_dlopen_dlsym_graph_proven==false and
  $o.target_endeavouros_hyprland_verified==false and
  $o.source_pruning_authorized==false and $o.security_current==false and
  $o.release_ready==false and $o.m3_sixth_gate_closed==false;
  "Prior independent verified Firefox160 source/package/media comparison forged") |
assert($n.schema_version==1 and
  $n.status=="real_firefox160_native_bundled_ffvpx_dlopen_denial_and_vp9_media_outcome" and
  $n.original_upstream_release_commit==$upstream and
  $n.original_vulpra_source_tree==$tree and
  $n.original_compiled_native_archive_sha256==$archive and
  $n.original_source_owner_validation_run==43745057569 and
  $n.original_native_build_run==43138458940 and
  $n.native_browser_unmodified_replayed==true and
  $n.authentic_pinned_source_owner_rows==10 and
  $n.exact_source_owned_bundled_ffvpx_names==
    ["libmozavcodec.so","libmozavutil.so"] and
  $n.ffvpx_actual_native_denied_dlopen_attempt_count==2 and
  $n.ffvpx_libmozavcodec_denied_dlopen_attempt_count==1 and
  $n.ffvpx_libmozavutil_denied_dlopen_attempt_count==1 and
  ($n.ffvpx_libmozavcodec_denied_dlopen_attempt_count+
   $n.ffvpx_libmozavutil_denied_dlopen_attempt_count)==
   $n.ffvpx_actual_native_denied_dlopen_attempt_count and
  $n.ffvpx_denials_during_video_navigation==0 and
  $n.baseline_vp9_decoded_frames_and_advancing_time==true and
  $n.with_bundled_ffvpx_denied_vp9_decoded_frames_and_advancing_time==true and
  $n.with_bundled_ffvpx_denied_media_error_observed==false and
  $n.observed_denied_vp9_outcome=="decoded_frames_and_advancing_time" and
  $n.browser_and_temporary_profile_preserved_under_both_modes==true and
  $n.interposer_actually_attached_to_browser==true and
  $n.altered_system_library_files==false and
  $n.raw_dlopen_names_PIDs_or_profiles_archived==false and
  $n.compiled_machine_caller_of_ffvpx_dlopen_known==false and
  $n.actual_ffvpx_missing_provider_failure_guard_source_branch_attributed==false and
  $n.successful_alternative_decoder_identified==false and
  $n.all_protected_media_features_and_fallbacks_proven==false and
  $n.target_endeavouros_hyprland_verified==false and
  $n.source_pruning_authorized==false and
  $n.security_current==false and $n.release_ready==false and
  $n.m3_sixth_gate_closed==false;
  "Forged actual FFVPX per-library denial identity, source, browser behavior or false fallback claim") |
{
  schema_version:1,
  status:"original_firefox160_actual_FFVPX_exact_named_dlopen_denials_with_VP9_playback",
  original_source_commit:$upstream,
  exact_vulpra_candidate_tree:$tree,
  exact_original_native_package_sha256:$archive,
  existing_independent_four_producer_crosswalk_run:43747660588,
  newly_source_pinned_real_bundled_ffvpx_denial_run:43748031202,
  two_separately_denied_native_FFVPX_names:[
    {name:"libmozavcodec.so",actual_dlopen_denial_count:1},
    {name:"libmozavutil.so",actual_dlopen_denial_count:1}
  ],
  total_ffvpx_native_dlopen_denials:2,
  ffvpx_denials_during_video_navigation:0,
  source_owner_original_Git_blobs_verified:10,
  previous_system_ffmpeg_native_denials_in_distinct_real_browser_run:14,
  actual_vp9_video_decoded_in_baseline_and_bundled_FFVPX_denied_browser:true,
  actual_vp9_video_decoded_in_separate_system_FFmpeg_denied_browser:true,
  both_real_denied_VP9_browser_workloads_remained_responsive:true,
  original_archive_reused_without_browser_build:true,
  original_native_source_or_system_libraries_modified:false,
  private_paths_PIDs_symbols_or_raw_logs_archived:false,
  exact_decoder_or_successful_fallback_implementation_identified:false,
  FFVPX_source_level_failure_guard_actual_machine_branch_proven:false,
  same_runtime_workload_denied_both_FFVPX_and_FFmpeg:false,
  all_future_dlopen_dlsym_and_Rust_CXX_FFI_proven:false,
  all_protected_media_modes_or_target_Arch_Wayland_verified:false,
  source_pruning_authorized:false,
  security_current:false,
  release_ready:false,
  m3_sixth_gate_closed:false
}
