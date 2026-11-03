# A real original Vulpra PulseAudio null-sink WebAudio workload plus glibc
# provider bindings and bounded /proc/maps snapshots; no LD_PRELOAD/LD_AUDIT.
# Provider and requester names are not a Rust/C ownership or causal proof.
def check($v;$msg): if $v then . else error($msg) end;
def safe_names($a):
  ($a|type)=="array" and ($a|unique|length)==($a|length) and
  all($a[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
def pulse_name:
  type=="string" and (.=="libpulse.so.0" or
  test("^libpulse\\.so\\.0\\.[0-9]+(\\.[0-9]+)*$"));
def map_valid($m; $phase):
  $m.schema_version==1 and
  $m.status=="original_browser_feature_live_mapped_library_snapshot" and
  $m.original_source_commit==$source and $m.original_archive_sha256==$archive and
  $m.phase==$phase and
  $m.original_browser_processes_observed>=1 and
  $m.original_browser_executables_only==true and
  $m.raw_paths_or_process_ids_exported==false and
  $m.source_pruning_authorized==false and
  $m.m3_sixth_gate_closed==false and
  safe_names($m.package_mapped_shared_library_basenames) and
  safe_names($m.host_mapped_shared_library_basenames) and
  (["libxul.so","libmozgtk.so"]-$m.package_mapped_shared_library_basenames|length)==0 and
  $m.libpulse_mapped_in_original_browser==
    any($m.host_mapped_shared_library_basenames[];pulse_name);
($audio[0]) as $a | ($before[0]) as $b | ($during[0]) as $d | ($glibc[0]) as $g |
check(
  map_valid($b;"before") and map_valid($d;"during") and
  $d.libpulse_mapped_in_original_browser==true and
  $a.schema_version==1 and
  $a.status=="original_browser_webaudio_pulse_null_sink_stream_verified" and
  $a.source_commit==$source and $a.archive_sha256==$archive and
  $a.original_native_browser_executed==true and
  $a.real_user_click_audio_context_running==true and
  $a.pulse_null_sink_created==true and
  $a.pulse_sink_had_no_inputs_before_browser_audio==true and
  $a.pulse_sink_input_observed_during_browser_audio==true and
  $a.libpulse_mapped_before_click==$b.libpulse_mapped_in_original_browser and
  $a.libpulse_mapped_during_audio==true and
  $a.reported_cubeb_backend=="pulse-rust" and
  $a.reported_cubeb_backend_is_pulse_rust==true and
  $a.instrumented_original_libxul_origin_libpulse_dlopen_successes==0 and
  $a.original_browser_libpulse_loader_caller_pc_observed_with_ld_preload==false and
  $a.instrumentation_changes_original_symbol_resolution==false and
  $a.noninterposing_glibc_libpulse_bindings_observed==true and
  $a.glibc_debug_changes_timing==true and
  $a.ld_preload_and_ld_audit_unset_for_browser==true and
  $a.network_egress_allowed==false and
  $a.physical_audio_or_microphone_used==false and
  $a.source_pruning_authorized==false and $a.m3_sixth_gate_closed==false;
  "real noninterposed WebAudio backend or source-pinned browser maps absent") |
check(
  $g.schema_version==1 and
  $g.status=="original_browser_noninterposing_glibc_libpulse_binding_observed" and
  $g.original_source_commit==$source and $g.original_archive_sha256==$archive and
  $g.diagnostic_mode=="glibc_LD_DEBUG_bindings" and
  $g.private_glibc_trace_count>=1 and
  $g.original_libxul_loaded_trace_count>=1 and
  $g.original_libxul_and_libpulse_binding_same_trace_count>=1 and
  $g.original_browser_libpulse_binding_event_count>=1 and
  $g.original_browser_libpulse_binding_event_count<=20000 and
  $g.original_browser_distinct_libpulse_symbol_count>=1 and
  $g.original_browser_distinct_libpulse_symbol_count==
    ($g.original_browser_resolved_libpulse_symbol_names|length) and
  safe_names($g.original_browser_resolved_libpulse_symbol_names) and
  all($g.original_browser_resolved_libpulse_symbol_names[];test("^pa_[A-Za-z0-9_]+$")) and
  safe_names($g.glibc_requester_basenames) and
  safe_names($g.libpulse_provider_basenames) and
  ($g.libpulse_provider_basenames|length)>=1 and
  all($g.libpulse_provider_basenames[];pulse_name) and
  $g.no_ld_preload_or_ld_audit_used==true and
  $g.glibc_diagnostic_changes_timing==true and
  $g.binding_requester_does_not_prove_rust_or_c_caller==true and
  $g.actual_browser_rust_ffi_caller_stack_proven==false and
  $g.raw_process_ids_paths_or_logs_exported==false and
  $g.physical_audio_device_or_microphone_used==false and
  $g.full_native_dependency_closure_proven==false and
  $g.source_pruning_authorized==false and
  $g.native_bytes_saved==0 and $g.m3_sixth_gate_closed==false;
  "missing, forged or unsafe same-trace original browser native Pulse bindings") |
{
  schema_version:1,
  status:"original_browser_webaudio_pulse_glibc_provider_and_live_mapping_verified",
  original_source_commit:$source,
  original_browser_archive_sha256:$archive,
  original_browser_audio_backend:$a.reported_cubeb_backend,
  real_web_audio_stream_into_private_null_sink:true,
  original_browser_libxul_and_libpulse_binding_same_trace_count:
    $g.original_libxul_and_libpulse_binding_same_trace_count,
  native_libpulse_binding_events:$g.original_browser_libpulse_binding_event_count,
  native_distinct_pa_symbol_count:$g.original_browser_distinct_libpulse_symbol_count,
  native_pa_symbol_names:$g.original_browser_resolved_libpulse_symbol_names,
  native_binding_requester_basenames:$g.glibc_requester_basenames,
  native_libpulse_provider_basenames:$g.libpulse_provider_basenames,
  before_mapped_host_pulse:[$b.host_mapped_shared_library_basenames[]|select(pulse_name)],
  during_mapped_host_pulse:[$d.host_mapped_shared_library_basenames[]|select(pulse_name)],
  no_ld_preload_or_ld_audit:true,
  glibc_timing_instrumented:true,
  exact_rust_c_caller_proven:false,
  original_browser_full_libpulse_ffi_coverage_proven:false,
  full_28_elf_feature_dependency_closure_proven:false,
  source_pruning_authorized:false,
  native_bytes_saved:0,
  m3_sixth_gate_closed:false
}
