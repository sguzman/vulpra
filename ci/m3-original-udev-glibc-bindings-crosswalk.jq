# Original compiled Vulpra, no LD_PRELOAD, source-pinned glibc debug
# bindings from original libxul-loaded PID traces; no actual Rust caller
# attribution from dlsym binding-file field. Discard raw glibc traces.
def check($yes;$why): if $yes then . else error($why) end;
def safe($xs):
 ($xs|type)=="array" and ($xs|unique|length)==($xs|length) and
 all($xs[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
def provider:
 .=="libudev.so.1" or test("^libudev\\.so\\.1\\.[0-9]+(\\.[0-9]+)*$");
($glibc[0]) as $g | ($abi[0]) as $a | ($feature[0]) as $f |
check(
 $g.schema_version==1 and
 $g.status=="original_browser_glibc_binding_provider_noninterposing_diagnostics" and
 $g.original_source_commit==$src and
 $g.original_archive_sha256==$sha and
 $g.diagnostic_mode=="glibc_LD_DEBUG_bindings" and
 $g.ld_preload_and_ld_audit_unset==true and
 $g.glibc_debug_mode_changes_timing==true and
 $g.binding_requester_not_proven_actual_rust_dlsym_caller==true and
 $g.original_browser_udev_provider_binding_observed==true and
 $g.actual_rust_ffi_caller_from_binding_log_proven==false and
 $g.all_49_symbols_resolved_in_original_browser_proven==false and
 $g.raw_glibc_logs_paths_and_pids_exported==false and
 $g.physical_usb_device_used==false and
 $g.full_binary_feature_ffi_dependency_closure==false and
 $g.source_pruning_authorized==false and
 $g.native_bytes_saved==0 and $g.m3_sixth_gate_closed==false and
 ($g.glibc_trace_file_count|type)=="number" and
 $g.glibc_trace_file_count>=1 and $g.glibc_trace_file_count<=128 and
 ($g.original_libxul_present_trace_count|type)=="number" and
 $g.original_libxul_present_trace_count>=1 and
 $g.original_libxul_present_trace_count<=$g.glibc_trace_file_count and
 ($g.original_libxul_and_libudev_binding_same_trace_count|type)=="number" and
 $g.original_libxul_and_libudev_binding_same_trace_count>=1 and
 $g.original_libxul_and_libudev_binding_same_trace_count<=$g.original_libxul_present_trace_count and
 ($g.original_browser_libudev_binding_event_count|type)=="number" and
 $g.original_browser_libudev_binding_event_count>=1 and
 safe($g.original_browser_resolved_udev_symbol_names) and
 safe($g.original_browser_udev_provider_basenames) and
 ($g.original_browser_resolved_udev_symbol_names|length)==$g.original_browser_unique_udev_symbol_count and
 ($g.original_browser_resolved_udev_symbol_names|index("udev_new")) != null;
 "original source-pinned glibc debug observation or coverage flags invalid") |
check(
 $a.schema_version==1 and
 $a.status=="pinned_webauthn_libudev_isolated_host_dynamic_abi" and
 $a.original_source_commit==$src and
 $a.isolated_host=="archlinux-container" and
 $a.source_declared_udev_soname=="libudev.so.1" and
 $a.source_declared_udev_symbol_count==49 and
 $a.host_resolved_udev_symbol_count==49 and
 ($a.source_declared_udev_symbols|unique|length)==49 and
 $a.original_browser_executed==false and
 $a.m3_sixth_gate_closed==false and
 $f.schema_version==1 and
 $f.status=="original_browser_usb_backend_no_device_negative_probe" and
 $f.original_source_commit==$src and $f.original_archive_sha256==$sha and
 $f.original_native_browser_executed==true and
 $f.real_browser_usbtoken_pref==true and
 $f.real_browser_softtoken_pref==false and
 $f.virtual_authenticator_registered==false and
 $f.physical_usb_device_passthrough==false and
 $f.credential_create_result=="NotAllowedError" and
 $f.libudev_mapped_during_or_after_attempt==true and
 $f.instrumented_dlopen_symbol_interposition==false and
 $f.network_egress_allowed==false and
 $f.source_pruning_authorized==false and $f.m3_sixth_gate_closed==false;
 "original source-defined ABI or real no-device WebAuthn feature not authenticated") |
# The loader sees all libudev consumers in the browser process.
# The exact original WebAuthn libudev-sys source declares 49 functions, but
# this workload also uses udev_monitor_filter_update from a different,
# UNATTRIBUTED consumer. Never claim it belongs to the WebAuthn Rust crate.
($g.original_browser_resolved_udev_symbol_names - $a.source_declared_udev_symbols) as $extra |
($g.original_browser_resolved_udev_symbol_names - $extra) as $source_matches |
check(
 $extra==["udev_monitor_filter_update"] and
 ($source_matches|length)==15 and
 ($source_matches|index("udev_new"))!=null and
 all($g.original_browser_resolved_udev_symbol_names[]; test("^udev_[a-z0-9_]+$")) and
 all($g.original_browser_udev_provider_basenames[]; provider) and
 ($g.original_browser_udev_provider_basenames|length)>=1;
 "native libudev symbol outside source-declared WebAuthn and pinned unowned-symbol boundary") |
{
 schema_version:1,
 status:"original_browser_source_pinned_glibc_no_preload_udev_binding_reconciled",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 source_declared_udev_ffi_symbols:49,
 native_glibc_binding_event_count:$g.original_browser_libudev_binding_event_count,
 native_glibc_unique_udev_symbol_count:$g.original_browser_unique_udev_symbol_count,
 native_glibc_source_declared_web_authn_symbol_count:($source_matches|length),
 native_glibc_source_declared_web_authn_symbol_names:$source_matches,
 native_glibc_unattributed_external_symbol_count:($extra|length),
 native_glibc_unattributed_external_symbol_names:$extra,
 extra_symbol_original_caller_ownership_proven:false,
 native_glibc_resolved_udev_names:$g.original_browser_resolved_udev_symbol_names,
 native_glibc_provider_basenames:$g.original_browser_udev_provider_basenames,
 original_libxul_loaded_pid_traces_with_udev_bindings:$g.original_libxul_and_libudev_binding_same_trace_count,
 no_ld_preload_or_ld_audit_used:true,
 glibc_bindings_debug_changes_timing:true,
 provider_resolved_in_actual_original_browser_trace:true,
 glibc_dlsym_binding_requester_not_rust_caller:true,
 original_browser_uninstrumented_production_run_proven:false,
 original_browser_rust_to_ffi_uninstrumented_stack_proven:false,
 full_49_original_browser_symbols_proven:false,
 physical_usb_key_tested:false,
 complete_28_elf_source_binary_ffi_dependency_graph:false,
 raw_private_logs_or_process_ids_exported:false,
 source_pruning_authorized:false,native_bytes_saved:0,m3_sixth_gate_closed:false
}