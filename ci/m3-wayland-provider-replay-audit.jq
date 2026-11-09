# Conservative audit of real packaged Weston/Wayland frame and provider-denial
# evidence. A successful frame with zero matching loader denials is NOT a
# missing-provider fallback test. Sources and package SHA are supplied by CI.
def require($valid;$why): if $valid then true else error($why) end;
def sha40: type=="string" and test("^[0-9a-f]{40}$");
def sha64: type=="string" and test("^[0-9a-f]{64}$");
def nat: type=="number" and .>=0 and .==floor;
def positive: nat and .>0;
def scenario_ok:
  (.provider_group=="gbm" or .provider_group=="vaapi" or .provider_group=="ffmpeg") and
  .browser_process_instrumentation_attached==true and
  (.browser_attachment_records|positive) and
  (.targeted_optional_library_denial_events|nat) and
  .targeted_missing_provider_path_actually_seen==(.targeted_optional_library_denial_events>0) and
  .actual_graphical_Wayland_frame_committed==true and
  .frame_after_observed_targeted_denial==(.targeted_optional_library_denial_events>0) and
  .actual_GPU_acceleration_or_DMABuf_fallback_verified==false and
  .media_decoding_fallback_verified==false and
  .complete_native_dynamic_dependency_graph==false;

. as $r |
require(($expected_source_sha|sha40) and
        ($expected_harness_sha|sha40) and
        ($expected_archive_sha|sha64) and
        $r.schema_version==1 and
        $r.status=="actual_packaged_graphical_Weston_Wayland_optional_provider_denial_probe" and
        $r.native_source_commit==$expected_source_sha and
        $r.test_harness_commit==$expected_harness_sha and
        $r.verified_normal_packaged_archive_sha256==$expected_archive_sha and
        $r.actual_graphical_packaged_Vulpra_executed==true and
        $r.private_Weston_pixman_renderer_used==true and
        $r.non_MOZ_HEADLESS_Wayland_browser_verified==true and
        $r.three_graphical_frames_and_attach_witnesses_passed==true and
        $r.GPU_DMABuf_or_software_video_fallback_complete==false and
        $r.all_direct_indirect_dynamic_loader_routes_covered==false and
        $r.user_endeavouros_hyprland_qa_done==false and
        $r.host_system_libraries_modified==false and
        $r.user_normal_profile_or_credentials_used==false and
        $r.source_pruning_authorized==false and
        $r.m3_sixth_gate_closed==false and
        $r.release_ready==false and
        ($r.scenarios|type)=="array" and
        ($r.scenarios|length)==3 and
        ([$r.scenarios[].provider_group]|sort)==["ffmpeg","gbm","vaapi"];
        "source, package, frame or false safety contract invalid") |
require(all($r.scenarios[];scenario_ok);
        "frame, attached real browser or observed library denial contradictory") |
require(($r.targeted_provider_calls_intercepted|nat) and
        $r.targeted_provider_calls_intercepted==([$r.scenarios[].targeted_optional_library_denial_events]|add) and
        $r.any_targeted_optional_provider_load_seen==any($r.scenarios[];.targeted_optional_library_denial_events>0);
        "aggregate denial counts or coverage assertions invalid") |
($r.scenarios[]|select(.provider_group=="gbm")) as $g |
($r.scenarios[]|select(.provider_group=="vaapi")) as $v |
($r.scenarios[]|select(.provider_group=="ffmpeg")) as $f |
{
  schema_version:1,
  status:"source_bound_graphical_Wayland_provider_denial_evidence_classified",
  native_source_commit:$r.native_source_commit,
  test_harness_commit:$r.test_harness_commit,
  normal_package_sha256:$r.verified_normal_packaged_archive_sha256,
  real_private_Wayland_buffer_commits_verified:true,
  private_Weston_pixman_only:true,
  gbm_denied_library_requests:$g.targeted_optional_library_denial_events,
  vaapi_denied_library_requests:$v.targeted_optional_library_denial_events,
  ffmpeg_denied_library_requests:$f.targeted_optional_library_denial_events,
  gbm_missing_provider_path_tested:($g.targeted_optional_library_denial_events>0),
  vaapi_missing_provider_path_tested:($v.targeted_optional_library_denial_events>0),
  ffmpeg_missing_provider_path_tested:($f.targeted_optional_library_denial_events>0),
  same_session_Wayland_frame_and_gbm_denial_observed:($g.targeted_optional_library_denial_events>0),
  same_session_Wayland_frame_and_vaapi_denial_observed:($v.targeted_optional_library_denial_events>0),
  same_session_Wayland_frame_and_ffmpeg_denial_observed:($f.targeted_optional_library_denial_events>0),
  provider_denial_temporally_precedes_frame_proven:false,
  actual_GPU_or_DMA_BUF_graphics_fallback_proven:false,
  hardware_VAAPI_video_decode_or_fallback_proven:false,
  complete_conditional_indirect_native_dependency_graph:false,
  target_endeavouros_hyprland_verified:false,
  source_pruning_authorized:false,
  m3_sixth_gate_closed:false,
  release_ready:false
}
