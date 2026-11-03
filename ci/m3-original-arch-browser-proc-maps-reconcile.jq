# Cross-check genuine original Arch Weston process mappings against an
# independently parsed native original browser GNU loader initializer report.
# Only exact source/archive-pinned sanitized basenames. No proof of closure.
def check($pred; $message): if $pred then . else error($message) end;
def safe($xs):
  ($xs|type)=="array" and ($xs|unique|length)==($xs|length) and
  all($xs[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
($map[0]) as $m |
($native[0]) as $n |
check($m.schema_version==1 and $n.schema_version==1 and
  $m.original_source_commit==$src and $n.original_source_commit==$src and
  $m.original_archive_sha256==$sha and $n.original_archive_sha256==$sha and
  $m.status=="original_arch_private_wayland_browser_proc_maps_residency" and
  $n.status=="original_arch_wayland_browser_actual_loader_initializers";
  "source-pinned Arch process map / real loader fingerprint mismatch") |
check($m.browser_process_samples>=4 and
  $m.max_simultaneously_visible_original_browser_processes>=1 and
  $m.distinct_original_browser_processes_observed>=1 and
  $m.unreadable_original_process_maps_count>=0 and
  $m.private_original_executable_only==true and
  $m.absolute_paths_or_pids_exported==false and
  $m.time_bounded_snapshot_not_all_runtime_libraries==true and
  $m.complete_browser_feature_or_ffi_dependency_closure==false and
  $m.source_removal_authorized==false and $m.m3_sixth_gate_closed==false and
  $n.libxul_actual_init_observed==true and
  $n.libmozgtk_actual_init_observed==true and
  $n.libmozwayland_actual_init_observed==true and
  $n.full_future_dlopen_or_feature_coverage_proven==false and
  $n.raw_loader_logs_symbol_names_paths_or_pids_exported==false;
  "not a bounded genuine Arch graphical browser workload") |
check(safe($m.package_mapped_library_basenames) and
  safe($m.host_mapped_library_basenames) and
  safe($n.initialized_native_provider_basenames) and
  ($m.package_mapped_library_basenames|length)>=3 and
  ($n.initialized_native_provider_basenames|length)>=3;
  "invalid mapped or initializer library basenames") |
($m.package_mapped_library_basenames) as $package |
($m.host_mapped_library_basenames) as $host |
($n.initialized_native_provider_basenames) as $init |
check(all(["libxul.so","libmozgtk.so","libmozwayland.so"][] as $core;
    ($package|index($core))!=null and ($init|index($core))!=null);
  "missing original actual mapped-and-initialized core browser library") |
([$package[] as $name | select(($init|index($name))!=null) | $name]) as $both |
([$package[] as $name | select(($init|index($name))==null) | $name]) as $only_map |
{
  schema_version:1,
  status:"original_arch_wayland_mapped_browser_libs_vs_real_initializer_witness",
  original_source_commit:$src,
  original_archive_sha256:$sha,
  observed_original_browser_processes_max:$m.max_simultaneously_visible_original_browser_processes,
  observed_original_browser_process_samples:$m.browser_process_samples,
  unreadable_original_process_maps_count:$m.unreadable_original_process_maps_count,
  actual_package_mapped_library_count:($package|length),
  actual_host_mapped_library_count:($host|length),
  original_native_loader_init_count:($init|length),
  actual_package_mapped_and_initialized_count:($both|length),
  original_package_mapped_and_initialized_basenames:$both,
  package_mapped_without_initializer_witness_basenames:$only_map,
  original_three_core_wayland_libraries_both_mapped_and_initialized:true,
  all_28_original_elf_members_runtime_mapped:false,
  observed_initializers_not_equivalent_to_process_residency:true,
  observed_process_mappings_not_equivalent_to_loader_events:true,
  single_private_weston_frame_workload_only:true,
  no_absolute_paths_or_pids_exported:true,
  arch_container_not_hyprland_or_real_host:true,
  all_future_features_dynamic_ffi_dependencies_proven:false,
  source_pruning_authorized:false,
  native_package_bytes_saved:0,
  m3_sixth_gate_closed:false
}