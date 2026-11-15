# Authenticate one actual Firefox160 libxul LD_DEBUG binding observation against
# the separately source-bound 28-ELF package census. This is a bounded
# runtime trace witness, not proof of every future/conditional resolution.
def check($ok; $why): if $ok then . else error($why) end;
def safe_provider:
  (type=="string") and (length<=111) and
  test("^[A-Za-z0-9][A-Za-z0-9_.+-]*$");
def providers_ok($xs):
  ($xs|type)=="array" and ($xs|length)==45 and
  all($xs[]; safe_provider) and
  $xs==($xs|unique|sort) and
  (["libxul.so","libc.so.6","ld-linux-x86-64.so.2","vulpra"] -
   $xs)==[];
check(($graph|length)==1 and ($bindings|length)==1;
  "Missing native source graph or real binding observation") |
($graph[0]) as $g | ($bindings[0]) as $b |
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
  "Unauthenticated original compiled Firefox160 ELF source/package graph") |
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
      providers_ok($b.default_provider_basenames) and
      providers_ok($b.eager_provider_basenames) and
      $b.default_provider_basenames==$b.eager_provider_basenames and
      $b.original_firefox160_webdriver_js_extensions_tls_nimbus_smoke_both_modes_passed==true and
      $b.loader_records_observed_from_actual_browser_processes==true and
      $b.raw_loader_traces_or_symbol_names_archived==false and
      $b.eager_binding_applied_to_observed_process==true and
      $b.complete_dependency_and_ffi_coverage==false and
      $b.no_future_dlopen_or_lazy_symbol_coverage_claim==true and
      $b.target_arch_hyprland_runtime_verified==false and
      $b.source_pruning_authorized==false and
      $b.security_current==false and
      $b.release_ready==false and
      $b.m3_sixth_gate_closed==false;
  "Forged actual Firefox160 workload/ELF/ABI/privacy or completion claim") |
{
  schema_version:1,
  status:"reconciled_firefox160_actual_libxul_bindings_with_original_elf_census",
  original_firefox160_native_source_commit:$source,
  original_native_candidate_tree:$tree,
  original_native_archive_sha256:$g.archive_sha256,
  independently_sourced_original_elf_graph_run:43730900702,
  actual_browser_binding_observation_run:43741731639,
  original_native_elf_members:28,
  original_direct_needed_edges:268,
  observed_libxul_binding_events_default:$b.default_libxul_binding_events,
  observed_libxul_binding_events_eager:$b.eager_libxul_binding_events,
  distinct_symbol_provider_pairs_in_each_mode:2861,
  actual_provider_basenames_in_each_mode:45,
  actual_provider_basename_parity:true,
  default_and_eager_real_browser_smoke_both_passed:true,
  actual_glibc_binding_observations_in_exercised_libxul_workload:true,
  raw_trace_or_symbol_names_archived:false,
  all_static_imports_guaranteed_resolved:false,
  all_optional_dlopen_or_Rust_CXX_FFI_proven:false,
  target_arch_hyprland_verified:false,
  protected_feature_fallback_coverage_complete:false,
  source_pruning_authorized:false,
  security_current:false,
  release_ready:false,
  m3_sixth_gate_closed:false
}
