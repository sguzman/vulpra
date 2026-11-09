# Independently join actual native build package evidence, the real packaged
# browser denied-provider probe and source-matched normal native reconciler.
# The invoking workflow authenticates both GitHub Actions run identities and
# downloads the named artifacts. Counts are deliberately pinned to the
# observed run; adding/forging coverage fails, rather than silently expanding.
def insist($ok;$msg): if $ok then true else error($msg) end;
def sha256: type=="string" and test("^[0-9a-f]{64}$");

insist(($native|length)==1 and ($denial|length)==1 and ($reconciled|length)==1;
       "Expected one native, denied-provider and independently reconciled report") |
$native[0] as $n | $denial[0] as $d | $reconciled[0] as $r |
insist($n.schema_version==1 and $n.source_commit==$source and
       $n.workflow_run_id==$run and
       $n.native_build_required==true and
       $n.runtime_passed_after_link_audit==true and
       $n.source_removal_authorized==false and
       ($n.package.package_sha256|sha256);
       "Native run, source, runtime or package evidence invalid") |
insist($r.schema_version==1 and
       $r.status=="passed_full_native_evidence_reconciliation" and
       $r.source_commit==$source and $r.workflow_run_id==$run and
       $r.package_sha256==$n.package.package_sha256 and
       $r.Wayland_JS_WebExtension_Nimbus_passed==true and
       $r.native_elf_member_count==28 and $r.native_direct_needed_edges==268 and
       $r.complete_resolved_linker_symbol_map==false and
       $r.host_transitive_and_dlopen_dependencies_closed==false and
       $r.additional_source_removal_authorized==false;
       "Independent native source/package/runtime evidence mismatch") |
insist($d.schema_version==1 and
       $d.status=="real_packaged_native_browser_optional_provider_denial_probe" and
       $d.native_source_commit==$source and
       $d.verified_packaged_archive_sha256==$n.package.package_sha256 and
       $d.actual_normal_packaged_browser_relaunched==true and
       $d.original_private_home_and_profiles_untouched==true and
       $d.system_libraries_modified==false and
       $d.used_compiled_LD_PRELOAD_interposer==true and
       $d.attempted_provider_groups==["gbm","vaapi","ffmpeg"] and
       $d.observed_denied_library_loads==14 and
       $d.every_scenario_attached_and_screenshot_passed==true and
       $d.at_least_one_matching_provider_denial_observed==true and
       ($d.runtime_modes|type)=="array" and
       ($d.runtime_modes|length)==3 and
       ([ $d.runtime_modes[].provider_group ]|unique|length)==3 and
       ([ $d.runtime_modes[].actual_matching_optional_provider_load_denials ]|add)==14 and
       all($d.runtime_modes[];
         .actual_packaged_browser_instrumentation_attached==true and
         .actual_browser_process_attachment_records==3 and
         .screenshot_passed==true and
         .all_conditional_feature_routes_tested==false and
         .software_video_decoding_fallback_proven==false and
         .Wayland_dmabuf_rendering_fallback_proven==false) and
       $d.all_requested_library_arguments_and_indirect_edges_proven==false and
       $d.hardware_video_or_Wayland_gpu_fallback_complete==false and
       $d.target_endeavouros_hyprland_verified==false and
       $d.source_pruning_authorized==false and
       $d.m3_sixth_gate_closed==false and
       $d.release_ready==false;
       "Real packaged-browser probe or limits mismatched") |
([ $d.runtime_modes[] |
   select(.provider_group=="gbm" and
      .actual_matching_optional_provider_load_denials==0 and
      .provider_missing_path_observed==false and
      .screenshot_passed_after_observed_denial==false) ]|length) as $gbm |
([ $d.runtime_modes[] |
   select(.provider_group=="vaapi" and
      .actual_matching_optional_provider_load_denials==0 and
      .provider_missing_path_observed==false and
      .screenshot_passed_after_observed_denial==false) ]|length) as $va |
([ $d.runtime_modes[] |
   select(.provider_group=="ffmpeg" and
      .actual_matching_optional_provider_load_denials==14 and
      .provider_missing_path_observed==true and
      .screenshot_passed_after_observed_denial==true) ]|length) as $ff |
insist($gbm==1 and $va==1 and $ff==1;
       "Unexpected failed-to-load counts or false conditional-loader coverage") |
{
  schema_version:1,
  status:"independent_current_real_packaged_ffmpeg_denials_and_nohit_graphics_probes_reconciled",
  authenticated_native_source_commit:$source,
  authenticated_native_workflow_run_id:$run,
  authenticated_independent_reconciliation_run_id:$recon_run,
  normal_packaged_browser_archive_sha256:$n.package.package_sha256,
  normal_native_runtime_and_package_authentic:true,
  separate_source_matched_native_reconciliation_passed:true,
  real_packaged_browser_attached_all_three_modes:true,
  real_packaged_browser_screenshot_all_three_modes_passed:true,
  ffmpeg_actual_dynamic_loads_intentionally_denied:14,
  ffmpeg_browser_screenshot_after_denials:true,
  gbm_load_denials_observed:0,
  vaapi_load_denials_observed:0,
  gbm_and_vaapi_missing_library_paths_exercised:false,
  actual_video_playback_or_software_decoder_fallback_proven:false,
  actual_Wayland_gpu_DMABuf_failure_fallback_proven:false,
  FFmpeg_dynamic_library_requests_fully_enumerated:false,
  other_process_or_indirect_loader_graph_complete:false,
  user_endeavouros_hyprland_qa_performed:false,
  m3_sixth_gate_closed:false,
  source_pruning_authorized:false,
  security_hotfix_release_ready:false
}
