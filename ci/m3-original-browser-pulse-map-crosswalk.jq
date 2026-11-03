# Exact original archive's Vulpra WebAudio pre-click/during-playback
# sampled mapped ELF basenames. One private Arch/Weston workload only.
# LD_PRELOAD interposition is used by the existing cubeb probe; this census
# does NOT claim uninfluenced library load order, full FFI or path ownership.
def check($ok;$why): if $ok then . else error($why) end;
def safe($xs):
 ($xs|type)=="array" and ($xs|unique|length)==($xs|length) and
 all($xs[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
($before[0]) as $b |
($during[0]) as $d |
($audio[0]) as $a |
check($b.schema_version==1 and $d.schema_version==1 and
 $b.status=="original_browser_feature_live_mapped_library_snapshot" and
 $d.status==$b.status and $b.phase=="before" and $d.phase=="during" and
 $b.original_source_commit==$src and $d.original_source_commit==$src and
 $b.original_archive_sha256==$sha and $d.original_archive_sha256==$sha;
 "not source-matched private browser phase snapshots") |
check($a.schema_version==1 and
 $a.status=="original_browser_webaudio_pulse_null_sink_stream_verified" and
 $a.source_commit==$src and $a.archive_sha256==$sha and
 $a.original_native_browser_executed==true and
 $a.real_user_click_audio_context_running==true and
 $a.pulse_sink_input_observed_during_browser_audio==true and
 $a.libpulse_mapped_during_audio==true and
 $a.reported_cubeb_backend=="pulse-rust" and
 $a.instrumented_original_libxul_origin_libpulse_dlopen_successes>=1 and
 $a.instrumentation_changes_original_symbol_resolution==true and
 $a.network_egress_allowed==false and
 $a.source_pruning_authorized==false and $a.m3_sixth_gate_closed==false;
 "missing original native audio feature-execution witness") |
check($b.original_browser_processes_observed>=1 and
 $d.original_browser_processes_observed>=1 and
 $b.unreadable_original_browser_maps>=0 and
 $d.unreadable_original_browser_maps>=0 and
 $b.original_browser_executables_only==true and
 $d.original_browser_executables_only==true and
 $b.raw_paths_or_process_ids_exported==false and
 $d.raw_paths_or_process_ids_exported==false and
 $b.time_bounded_phase_not_full_dlopen_graph==true and
 $d.time_bounded_phase_not_full_dlopen_graph==true and
 $b.source_pruning_authorized==false and $d.source_pruning_authorized==false and
 $b.m3_sixth_gate_closed==false and $d.m3_sixth_gate_closed==false and
 safe($b.package_mapped_shared_library_basenames) and
 safe($d.package_mapped_shared_library_basenames) and
 safe($b.host_mapped_shared_library_basenames) and
 safe($d.host_mapped_shared_library_basenames);
 "invalid or unsafe map observation") |
($b.host_mapped_shared_library_basenames) as $host_before |
($d.host_mapped_shared_library_basenames) as $host_during |
($b.package_mapped_shared_library_basenames) as $pkg_before |
($d.package_mapped_shared_library_basenames) as $pkg_during |
check((["libxul.so","libmozgtk.so"] - $pkg_before |length)==0 and
 (["libxul.so","libmozgtk.so"] - $pkg_during |length)==0 and
 $d.libpulse_mapped_in_original_browser==true and
 ($host_during|index("libpulse.so.0"))!=null and
 $b.libpulse_mapped_in_original_browser==($host_before|index("libpulse.so.0")!=null) and
 $a.libpulse_mapped_before_click==$b.libpulse_mapped_in_original_browser;
 "real PulseAudio host mapping and before-click state inconsistent") |
{
 schema_version:1,
 status:"original_webaudio_before_during_actual_browser_library_residency_crosswalk",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 original_browser_before_process_count:$b.original_browser_processes_observed,
 original_browser_during_process_count:$d.original_browser_processes_observed,
 before_original_package_library_count:($pkg_before|length),
 during_original_package_library_count:($pkg_during|length),
 before_host_library_count:($host_before|length),
 during_host_library_count:($host_during|length),
 newly_mapped_package_library_basenames:($pkg_during-$pkg_before),
 newly_mapped_host_library_basenames:($host_during-$host_before),
 no_longer_mapped_package_library_basenames:($pkg_before-$pkg_during),
 no_longer_mapped_host_library_basenames:($host_before-$host_during),
 pulse_already_mapped_before_click:$b.libpulse_mapped_in_original_browser,
 pulse_mapped_during_real_audio:true,
 native_backend_pulse_rust_verified:true,
 real_private_null_sink_audio_confirmed:true,
 phase_differences_not_causation_or_complete_load_log:true,
 ld_preload_instrumentation_affects_resolution:true,
 raw_process_ids_or_paths_exported:false,
 complete_future_browser_ffi_dlopen_closure:false,
 source_pruning_authorized:false,
 native_bytes_saved:0,
 m3_sixth_gate_closed:false
}