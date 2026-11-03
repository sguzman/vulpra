# Nine original packaged ELF members absent from three bounded browser
# residency samples all have independent diagnostic native-binding evidence.
# Each workload is separate. A helper's ELF binding is NOT normal lifecycle
# coverage; a C API diagnostic is NOT browser frontend execution.
def check($ok;$why): if $ok then . else error($why) end;
def safe($xs):
  ($xs|type)=="array" and ($xs|length)<=128 and
  ($xs|unique|length)==($xs|length) and
  all($xs[];type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
def binding($x;$name):
  $x.schema_version==1 and
  $x.status=="original_native_feature_module_actual_symbol_bindings" and
  $x.original_source_commit==$src and
  $x.original_archive_sha256==$sha and
  $x.original_requester_basename==$name and
  $x.pid_traces_with_original_requester_bindings>=1 and
  $x.normal_symbol_binding_events>=1 and
  $x.distinct_symbol_provider_pairs>=1 and
  $x.distinct_symbol_provider_pairs<=$x.normal_symbol_binding_events and
  $x.observed_provider_basename_count==($x.observed_provider_basenames|length) and
  safe($x.observed_provider_basenames) and
  $x.actual_normal_symbol_bindings_observed==true and
  $x.raw_loader_logs_exported==false and
  $x.symbol_names_exported==false and
  $x.model_inference_or_drm_decryption_proven==false and
  $x.all_lazy_or_transitive_bindings_proven==false and
  $x.new_source_pruning_authorized==false;
($resident[0]) as $r |
($ten[0]) as $t |
($aux[0]) as $a |
($moz[0]) as $m |
($cdm[0]) as $c |
($onnx[0]) as $o |
($ping[0]) as $p |
($gfx[0]) as $g |
($alt[0]) as $v |
["crashhelper","crashreporter","gfxtest","libclearkey.so",
 "libmozinference.so","libonnxruntime.so","pingsender","updater",
 "vulpra-bin"] as $nine |
check(
  $r.schema_version==1 and
  $r.status=="source_pinned_original_28_elf_three_actual_browser_workload_residency_crosswalk" and
  $r.original_source_commit==$src and $r.original_archive_sha256==$sha and
  $r.matrix_original_elf_members==28 and
  $r.matrix_arch_direct_needed_edges==268 and
  $r.actually_mapped_in_at_least_one_bounded_workload_count==19 and
  $r.not_observed_as_resident_in_these_samples_count==9 and
  $r.not_observed_as_resident_in_these_samples_names==$nine and
  ($r.rows|length)==28 and
  ([ $r.rows[]|select((.in_wayland_startup_mapped_elf or
                      .in_webaudio_during_stream_mapped_elf or
                      .in_webauthn_usb_during_attempt_mapped_elf)|not)|.elf]|sort)==$nine and
  $r.no_source_pruning_justified_by_absence_of_a_sample==true and
  $r.cross_run_workloads_not_one_continuous_loader_trace==true and
  $r.full_28_elf_feature_build_ffi_and_future_dlopen_closure==false and
  $r.source_pruning_authorized==false and
  $r.native_bytes_saved==0 and $r.m3_sixth_gate_closed==false;
  "original 28-ELF three-browser sample absence set unverified") |
check(
  $t.schema_version==1 and
  $t.status=="original_native_ten_requester_real_binding_observation_reconciled" and
  $t.original_source_commit==$src and $t.original_archive_sha256==$sha and
  $t.original_elf_requester_count==10 and
  $t.original_elf_requester_basenames==(["libxul.so"]+$nine|sort) and
  $t.sum_normal_symbol_binding_events==8394 and
  $t.sum_per_requester_distinct_symbol_provider_pairs==4520 and
  $t.observed_provider_basename_count==51 and
  $t.separate_native_workloads_reconciled==7 and
  $t.raw_traces_or_symbol_names_exported==false and
  $t.complete_dependency_or_lazy_binding_map_proven==false and
  $t.production_browser_rebuilt==false and
  $t.new_source_removals_authorized==false and
  $t.m3_final_dependency_gate_closed==false;
  "previous independently accepted all-ten native binding reconciliation not verified") |
check(
  $a.schema_version==1 and
  $a.status=="original_protected_auxiliary_normal_symbol_bindings" and
  $a.original_source_commit==$src and $a.original_archive_sha256==$sha and
  ($a.per_member|keys)==["crashhelper","crashreporter","updater"] and
  $a.original_auxiliary_elf_member_count==3 and
  $a.pid_traces_with_member_bindings>=3 and
  $a.diagnostic_paths_only==true and
  $a.no_network_egress==true and
  $a.actual_runtime_bindings_witnessed==true and
  $a.raw_loader_logs_exported==false and
  $a.symbol_names_exported==false and
  $a.actual_crash_or_update_pipeline_proven==false and
  $a.complete_transitive_or_lazy_binding_coverage==false and
  $a.all_28_native_elf_members_covered==false and
  $a.new_source_pruning_authorized==false and
  all($a.per_member[]; .pid_traces_with_bindings>=1 and
    .normal_symbol_binding_events>=1 and
    .distinct_symbol_provider_pairs>=1 and
    .distinct_symbol_provider_pairs<=.normal_symbol_binding_events) and
  $a.normal_symbol_binding_events==
    ([$a.per_member[].normal_symbol_binding_events]|add) and
  $a.sum_per_member_distinct_symbol_provider_pairs==
    ([$a.per_member[].distinct_symbol_provider_pairs]|add) and
  $a.normal_symbol_binding_events==797 and
  $a.per_member.crashhelper.normal_symbol_binding_events==246 and
  $a.per_member.crashreporter.normal_symbol_binding_events==227 and
  $a.per_member.updater.normal_symbol_binding_events==324;
  "original three helper diagnostic binding evidence not authenticated") |
check(
  binding($m;"libmozinference.so") and
  binding($c;"libclearkey.so") and
  binding($o;"libonnxruntime.so") and
  # Original accepted module artifacts predate later parser output fields.
  # Validate only booleans actually recorded by those archived reports.
  all([$m,$c,$o][]; .original_c_api_diagnostic_only==true and
      .no_network_egress==true) and
  $m.normal_symbol_binding_events==184 and
  $c.normal_symbol_binding_events==71 and
  $o.normal_symbol_binding_events==246;
  "original optional native C API module evidence not authenticated") |
check(
  binding($p;"pingsender") and
  $p.synthetic_loopback_telemetry_only==true and
  $p.original_c_api_diagnostic_only==false and
  $p.no_network_egress==true and
  $p.normal_symbol_binding_events==170 and
  binding($g;"gfxtest") and
  $g.private_weston_wayland_gfx_probe_only==true and
  $g.original_c_api_diagnostic_only==false and
  $g.no_network_egress==false and
  $g.normal_symbol_binding_events==64 and
  binding($v;"vulpra-bin") and
  $v.alternate_browser_wayland_frame_only==true and
  $v.original_c_api_diagnostic_only==false and
  $v.no_network_egress==false and
  $v.normal_symbol_binding_events==534;
  "original pingsender, gfx or alternate browser executable probe not authenticated") |
([
  {elf:"crashhelper",mode:"protected_early_exit_helper",native:$a.per_member.crashhelper},
  {elf:"crashreporter",mode:"synthetic_crash_helper_diagnostic",native:$a.per_member.crashreporter},
  {elf:"gfxtest",mode:"private_weston_egl_probe",native:$g},
  {elf:"libclearkey.so",mode:"standalone_invalid_interface_c_api",native:$c},
  {elf:"libmozinference.so",mode:"standalone_inference_c_api",native:$m},
  {elf:"libonnxruntime.so",mode:"standalone_onnx_c_api",native:$o},
  {elf:"pingsender",mode:"synthetic_loopback_http",native:$p},
  {elf:"updater",mode:"read_only_channel_diagnostic",native:$a.per_member.updater},
  {elf:"vulpra-bin",mode:"alternate_private_weston_browser_frame",native:$v}
 ] | map(. as $item |
   ($r.rows[]|select(.elf==$item.elf)) as $source_row |
   {
     elf:$item.elf,
     original_source_manifest:$source_row.source_manifest,
     original_build_declaration:$source_row.source_declaration_class,
     host_direct_needed_provider_count:$source_row.arch_loader_provider_count,
     absent_from_three_browser_samples:true,
     independent_native_workload_type:$item.mode,
     original_native_executable_launched:
        (["crashhelper","crashreporter","gfxtest","pingsender","updater","vulpra-bin"]|index($item.elf)!=null),
     independent_c_api_library_load_tested:
        (["libclearkey.so","libmozinference.so","libonnxruntime.so"]|index($item.elf)!=null),
     original_module_normal_symbol_bindings_observed:true,
     glibc_binding_events:$item.native.normal_symbol_binding_events,
     distinct_symbol_provider_pairs:$item.native.distinct_symbol_provider_pairs,
     normal_browser_feature_path_verified:false,
     end_to_end_feature_success_proven:false,
     unused_or_removable_proven:false
   }
 )) as $rows |
([$rows[].glibc_binding_events]|add) as $events |
([$rows[].distinct_symbol_provider_pairs]|add) as $pairs |
check(($rows|length)==9 and
      ([$rows[].elf]|sort)==$nine and
      ($events==$t.sum_normal_symbol_binding_events-
        $t.per_workload_normal_binding_events.libxul) and
      ($pairs==1658) and
      $t.sum_per_requester_distinct_symbol_provider_pairs==4520 and
      all($rows[]; .original_source_manifest!="" and
        (.host_direct_needed_provider_count|type)=="number" and
        .glibc_binding_events>=1 and .distinct_symbol_provider_pairs>=1 and
        .unused_or_removable_proven==false);
      "nine original runtime witness rows disagree with independent ten-ELF evidence") |
{
 schema_version:1,
 status:"nine_original_unmapped_in_three_browser_samples_have_independent_bounded_native_bindings",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 input_run_ids:{
   three_browser_residency:41717623238,
   ten_requester_reconciliation:41206028051,
   auxiliary_helpers:41164023607,
   optional_c_api_modules:41165330510,
   synthetic_ping:41165514106,
   private_wayland_gfxtest:41165690323,
   alternate_wayland_browser:41205746021
 },
 original_28_elf_members:28,
 three_browser_sample_mapped_members:19,
 three_sample_unobserved_members:9,
 unobserved_three_sample_members_with_separate_normal_bindings:($rows|length),
 separate_helper_executable_kinds:6,
 separate_c_api_module_kinds:3,
 summed_nine_elf_binding_events:$events,
 summed_nine_elf_distinct_provider_symbol_pairs:$pairs,
 all_ten_requester_binding_events:$t.sum_normal_symbol_binding_events,
 no_same_browser_session_assumed:true,
 sample_absence_does_not_mean_unneeded:true,
 diagnostic_helper_early_exit_not_crash_or_update_lifecycle:true,
 synthetic_ping_does_not_mean_real_telemetry:true,
 c_api_test_does_not_mean_browser_frontend_uses_module:true,
 gfx_test_does_not_mean_accelerated_gpu:true,
 separate_alternate_executable_does_not_replace_normal_launcher:true,
 completed_28_elf_ffi_or_future_conditional_loader_closure:false,
 target_endeavouros_hyprland_verified:false,
 source_pruning_authorized:false,
 native_bytes_saved:0,
 m3_sixth_gate_closed:false,
 rows:$rows
}
