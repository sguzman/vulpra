# Independently reconcile exact original compiled dependentlibs.list against
# actual native library initializer witnesses during original Arch Weston GUI.
# Init observed != configured preload order or full future dlopen closure.
def check($ok;$why): if $ok then . else error($why) end;
def safe($list):
 ($list|type)=="array" and ($list|unique|length)==($list|length) and
 all($list[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
($order[0]) as $o |
($runtime[0]) as $r |
($frame[0]) as $f |
check($o.schema_version==1 and
  $o.status=="original_compiled_generated_native_dependentlibs_order_verified" and
  $o.original_source_commit==$src and $o.original_archive_sha256==$sha and
  $o.original_dependentlibs_count==14 and
  $o.mozgtk_position_zero_indexed==11 and
  $o.mozwayland_position_zero_indexed==12 and
  $o.libxul_position_zero_indexed==13 and
  $o.all_listed_native_files_exist_in_original_archive==true and
  $o.runtime_dlopen_success_for_every_item_proven==false and
  $o.safe_source_or_library_removal_authorized==false and
  $o.m3_sixth_gate_closed==false;
  "original compiled generated dependentlibs provenance invalid") |
check($r.schema_version==1 and
  $r.status=="original_arch_wayland_browser_actual_loader_initializers" and
  $r.original_source_commit==$src and $r.original_archive_sha256==$sha and
  $r.native_browser_loader_pid_traces_with_initializers==7 and
  $r.initialized_native_provider_basename_count==103 and
  $r.runtime_dynamic_loader_requested_basename_count==40 and
  $r.direct_needed_loader_requested_basename_count==84 and
  $r.libmozgtk_actual_init_observed==true and
  $r.libmozwayland_actual_init_observed==true and
  $r.libxul_actual_init_observed==true and
  $r.init_order_or_full_dynamic_closure_proven==false and
  $r.raw_loader_logs_symbol_names_paths_or_pids_exported==false and
  $r.full_future_dlopen_or_feature_coverage_proven==false and
  $r.m3_sixth_gate_closed==false;
  "actual original private Arch Wayland loader witness invalid") |
check($f.schema_version==1 and
  $f.original_source_commit==$src and $f.original_archive_sha256==$sha and
  $f.real_private_weston_compositor==true and
  $f.native_browser_nonnull_wayland_surface_buffer_attached_then_committed==true and
  $f.native_browser_graphical_10_seconds_alive==true and
  $f.isolated_native_vulpra_profile_compatibility_initialized==true and
  $f.offline_network_namespace==true and
  $f.actual_hyprland_or_gpu_acceleration_tested==false and
  $f.source_pruning_authorized==false and
  $f.m3_sixth_gate_closed==false;
  "actual original private Arch frame was not validated") |
check(safe($o.ordered_package_member_basenames) and
  safe($r.initialized_native_provider_basenames) and
  safe($r.runtime_dynamic_loader_requested_basenames) and
  safe($r.direct_needed_loader_requested_basenames);
  "unsafe original native library basename or duplicates") |
($o.ordered_package_member_basenames) as $preloads |
($r.initialized_native_provider_basenames) as $inits |
($preloads-$inits) as $missing |
check(($missing|length)==0 and
  ($preloads|length)==14 and
  ([$preloads[]|select(. as $n | ($inits|index($n))!=null)]|length)==14;
  "compiled original preload library did not initialize during real Arch Wayland browser") |
{
 schema_version:1,
 status:"original_all_14_generated_preloads_initialized_in_arch_wayland",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 generated_native_preload_count:14,
 generated_native_preload_init_witness_count:14,
 generated_native_preload_order:$preloads,
 not_initialized_compiled_preload_basenames:$missing,
 original_arch_wayland_native_initializer_basename_count:103,
 original_arch_wayland_dynamic_request_basename_count:40,
 original_arch_wayland_direct_needed_request_basename_count:84,
 original_arch_wayland_process_traces_with_initializers:7,
 actual_private_weston_real_wayland_frame_observed:true,
 actual_source_built_glibc_native_initializers_observed:true,
 generated_preload_order_matches_init_order_not_proven:true,
 full_future_dlopen_or_all_features_tested:false,
 arch_container_not_hyprland_host:true,
 raw_paths_process_ids_symbols_and_browser_profiles_not_exported:true,
 no_source_or_package_removals_authorized:true,
 m3_sixth_gate_closed:false
}
