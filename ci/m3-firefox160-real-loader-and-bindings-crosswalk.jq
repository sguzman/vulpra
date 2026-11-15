# Independent immutable-source join of three separate real Firefox160 reports:
# original ELF package census, actual glibc libxul bindings, and real
# initialized vs uninitialized loader requests in an independent WebDriver run.
# This is not a global or source-owner-complete dynamic dependency proof.
def check($ok;$why): if $ok then . else error($why) end;
def basename_safe:
  (type=="string") and (length<=111) and
  test("^[A-Za-z0-9][A-Za-z0-9_.+-]*$");
def names_ok($xs;$expected):
  ($xs|type)=="array" and ($xs|length)==$expected and
  $xs==($xs|unique|sort) and all($xs[];basename_safe);
def edges_ok($xs;$names):
  ($xs|type)=="array" and
  ($xs|length)==($xs|unique|length) and
  $xs==($xs|sort_by(.requester_basename,.requested_library_basename)) and
  all($xs[];
    (.requester_basename|basename_safe) and
    (.requested_library_basename|basename_safe) and
    (.requested_library_basename as $target | ($names|index($target))!=null));
def contains_edge($xs;$from;$to):
  any($xs[]; .requester_basename==$from and .requested_library_basename==$to);
def expected_uninitialized:
  (["libavcodec-ffmpeg.so.56","libavcodec-ffmpeg.so.57",
    "libavcodec-ffmpeg.so.58","libnssckbi.so","libpulse.so.0"] +
   [range(53;64)|"libavcodec.so.\(.)"]) | sort;

check(($graph|length)==1 and ($loader|length)==1 and ($bindings|length)==1;
  "Exactly one independent original ELF, real loader and real binding report needed") |
($graph[0]) as $g | ($loader[0]) as $l | ($bindings[0]) as $b |
check($g.schema_version==1 and
      $g.firefox160_upstream_release_commit==$source and
      $g.firefox160_candidate_git_tree==$tree and
      $g.native_browser_producer_run==43138458940 and
      $g.exact_source_archive_mirror_run==43724886827 and
      ($g.elf_members|length)==28 and
      $g.direct_needed_edges==268 and
      $g.all_native_binary_execution_avoided==true and
      $g.complete_native_ffi_dependency_map_proven==false and
      $g.m3_sixth_gate_closed==false;
  "Original source-pinned 28-ELF/268-needed package graph changed") |
check($l.schema_version==1 and
      $l.status=="firefox160_real_browser_native_glibc_initialized_loader_request_edges" and
      $l.original_native_source_commit==$source and
      $l.original_native_archive_sha256==$g.archive_sha256 and
      $l.total_numeric_pid_traces_examined==8 and
      $l.browser_pid_traces_with_actual_libxul_initialization==2 and
      $l.observed_initialized_library_basename_count==94 and
      names_ok($l.observed_initialized_library_basenames;94) and
      ($l.observed_initialized_library_basenames|index("libxul.so"))!=null and
      ($l.observed_initialized_library_basenames|index("libc.so.6"))!=null and
      $l.initialized_needed_request_edge_count==80 and
      ($l.initialized_needed_request_edges|length)==80 and
      edges_ok($l.initialized_needed_request_edges;$l.observed_initialized_library_basenames) and
      $l.initialized_dynamic_request_edge_count==18 and
      ($l.initialized_dynamic_request_edges|length)==18 and
      edges_ok($l.initialized_dynamic_request_edges;$l.observed_initialized_library_basenames) and
      $l.dynamically_requested_but_no_same_trace_init_basename_count==16 and
      names_ok($l.dynamically_requested_but_no_same_trace_init_basenames;16) and
      $l.dynamically_requested_but_no_same_trace_init_basenames==expected_uninitialized and
      all($l.dynamically_requested_but_no_same_trace_init_basenames[];
        . as $name | ($l.observed_initialized_library_basenames|index($name))==null) and
      contains_edge($l.initialized_dynamic_request_edges;"libnspr4.so";"libsoftokn3.so") and
      contains_edge($l.initialized_dynamic_request_edges;"libnspr4.so";"libfreeblpriv3.so") and
      contains_edge($l.initialized_dynamic_request_edges;"libnspr4.so";"libmozavcodec.so") and
      contains_edge($l.initialized_dynamic_request_edges;"libnspr4.so";"libmozavutil.so") and
      $l.only_same_browser_pid_trace_initialized_targets_classified_as_initialized==true and
      $l.glibc_reported_request_relationships_not_proven_callstacks==true and
      $l.same_pid_may_include_shell_launcher_and_native_browser==true and
      $l.all_runtime_attempts_or_error_paths_known==false and
      $l.all_conditional_dlopen_and_dlsym_edges_proven==false and
      $l.all_native_feature_fallbacks_exercised==false and
      $l.actual_symbol_binding_pairs_reconciled_by_this_report==false and
      $l.target_endeavouros_hyprland_verified==false and
      $l.raw_loader_logs_paths_pids_symbols_or_profile_data_exported==false and
      $l.source_pruning_authorized==false and
      $l.security_current==false and $l.release_ready==false and
      $l.m3_sixth_gate_closed==false;
  "Forged source, PID, initialized/native request edge, privacy or closure claim") |
check($b.schema_version==1 and
      $b.status=="firefox160_actual_libxul_default_vs_eager_glibc_bindings" and
      $b.original_firefox160_native_build==43138458940 and
      $b.archive_preservation_run==43724886827 and
      $b.original_native_source_commit==$source and
      $b.original_archive_sha256==$g.archive_sha256 and
      $b.default_libxul_binding_events==6337 and
      $b.eager_libxul_binding_events==6338 and
      $b.default_distinct_symbol_provider_pairs==2861 and
      $b.eager_distinct_symbol_provider_pairs==2861 and
      names_ok($b.default_provider_basenames;45) and
      names_ok($b.eager_provider_basenames;45) and
      $b.default_provider_basenames==$b.eager_provider_basenames and
      all($b.default_provider_basenames[];
        . as $name | $name=="vulpra" or
        ($l.observed_initialized_library_basenames|index($name))!=null) and
      $b.loader_records_observed_from_actual_browser_processes==true and
      $b.original_firefox160_webdriver_js_extensions_tls_nimbus_smoke_both_modes_passed==true and
      $b.raw_loader_traces_or_symbol_names_archived==false and
      $b.complete_dependency_and_ffi_coverage==false and
      $b.no_future_dlopen_or_lazy_symbol_coverage_claim==true and
      $b.target_arch_hyprland_runtime_verified==false and
      $b.source_pruning_authorized==false and
      $b.security_current==false and
      $b.release_ready==false and $b.m3_sixth_gate_closed==false;
  "Original Firefox160 actual symbol-binding witness disagrees with loader/package identity") |
{
 schema_version:1,
 status:"reconciled_firefox160_actual_initialized_loader_requests_and_real_libxul_bindings",
 original_firefox160_source_commit:$source,
 original_firefox160_candidate_tree:$tree,
 original_native_archive_sha256:$g.archive_sha256,
 independently_authenticated_native_graph_run:43730900702,
 actual_libxul_binding_run:43741731639,
 actual_native_loader_request_run:43743231236,
 verified_original_native_elf_members:28,
 verified_original_direct_needed_edges:268,
 observed_browser_pid_traces_with_libxul_initialization:2,
 initialized_library_basename_count:94,
 observed_initialized_needed_request_edge_count:80,
 observed_initialized_dynamic_request_edge_count:18,
 observed_initialized_dynamic_request_edges:$l.initialized_dynamic_request_edges,
 observed_dynamic_request_names_without_same_trace_init_confirmation:
   $l.dynamically_requested_but_no_same_trace_init_basenames,
 observed_dynamic_request_names_without_same_trace_init_confirmation_count:16,
 glibc_reported_nspr_to_nss_and_ffvpx_dynamic_requests_init_confirmed:true,
 observed_different_workload_libxul_provider_basename_consistency:true,
 libxul_binding_provider_basename_count:45,
 actual_libxul_normal_and_eager_binding_event_counts:[6337,6338],
 real_native_webdriver_workload_passed:true,
 actual_loader_observations_not_full_symbol_or_callstack_attribution:true,
 missing_same_pid_init_not_equal_failed_dlopen:true,
 no_raw_trace_pids_symbol_names_or_profile_data_archived:true,
 glibc_loader_reporter_requester_not_verified_direct_source_owner:true,
 full_rust_cxx_ffi_and_conditional_dlopen_graph_proven:false,
 all_protected_feature_fallbacks_exercised:false,
 target_endeavouros_hyprland_verified:false,
 source_pruning_authorized:false,
 security_current:false,
 release_ready:false,
 m3_sixth_gate_closed:false
}
