# Independently correlate authenticated native artifacts. Sources and workloads
# remain distinct: matching names/PCs do NOT prove full browser FFI causation.
def check($condition;$message): if $condition then . else error($message) end;
def one($x): ($x|type)=="array" and ($x|length)==1;
def abi($x;$host):
  $x.status=="pinned_webauthn_libudev_isolated_host_dynamic_abi" and
  $x.original_source_commit==$src and $x.isolated_host==$host and
  $x.source_declared_udev_soname=="libudev.so.1" and
  $x.source_declared_udev_symbol_count==49 and
  $x.host_resolved_udev_symbol_count==49 and
  ($x.source_declared_udev_symbols|length)==49 and
  ($x.source_declared_udev_symbols|unique|length)==49 and
  $x.original_macro_initial_load_branch=="noload_miss_then_normal" and
  $x.warm_noload_double_lookup_succeeded==true and
  $x.real_host_dlopen_and_dlsym_executed==true and
  $x.original_browser_executed==false and $x.m3_sixth_gate_closed==false;
def wrapper($x;$host):
  $x.status=="source_pinned_original_rust_webauthn_libudev_first_use_context_smoke" and
  $x.original_source_commit==$src and $x.isolated_host==$host and
  $x.original_libudev_sys_rust_source_compiled_and_executed==true and
  $x.source_udev_new_function_invoked==true and
  $x.source_udev_unref_function_invoked==true and
  $x.source_udev_new_returned_nonnull_context==true and
  $x.libudev_soname=="libudev.so.1" and
  $x.libudev_noload_pre_first_use==false and
  $x.libudev_noload_post_first_use==true and
  $x.libudev_noload_after_context_release==true and
  $x.usb_device_enumeration_performed==false and
  $x.original_browser_executed==false and $x.m3_sixth_gate_closed==false;
null |
check(all([$source,$abi_ubuntu,$abi_arch,$wrap_ubuntu,$wrap_arch,$trace,$maps,$feature][];one(.));
 "missing, duplicated or malformed artifact") |
($source[0]) as $s | ($abi_ubuntu[0]) as $au | ($abi_arch[0]) as $aa |
($wrap_ubuntu[0]) as $wu | ($wrap_arch[0]) as $wa |
($trace[0]) as $t | ($maps[0]) as $m | ($feature[0]) as $f |
check($s.status=="original_webauthn_libudev_source_to_native_register_dlopen_candidate_verified" and
 $s.original_source_commit==$src and $s.original_archive_sha256==$archive and
 $s.native_libxul_sha256==$libxul and $s.native_libxul_bytes==189486696 and
 $s.original_source_path=="dom/webauthn/libudev-sys/src/lib.rs" and
 $s.native_constructed_soname=="libudev.so.1" and
 $s.native_first_call_register_r14_address==160654927 and
 $s.native_second_call_register_r14_address==160654948 and
 $s.native_first_rtld_flags_hex=="0x105" and
 $s.native_second_rtld_flags_conditional_hex==["0x101","0x105"] and
 $s.native_compiled_candidate_argument_verified==true and
 $s.actual_runtime_libudev_soname_loaded==false and
 $s.m3_sixth_gate_closed==false;
 "original source-to-compiled-loader route mismatch") |
check(abi($au;"ubuntu-24.04") and abi($aa;"archlinux-container") and
 $au.source_declared_udev_symbols==$aa.source_declared_udev_symbols and
 wrapper($wu;"ubuntu-24.04") and wrapper($wa;"archlinux-container");
 "original 49-symbol ABI or actual Rust-wrapper two-host mismatch") |
check($t.status=="original_browser_usb_libudev_interposed_callsite_verified" and
 $t.original_source_commit==$src and $t.original_archive_sha256==$archive and
 $t.instrumented_dlopen_symbol_interposition==true and
 $t.original_native_browser_executed==true and
 $t.source_pinned_libxul_noload_miss_at_return_pc_0x9936652==true and
 $t.source_pinned_libxul_normal_load_hit_at_return_pc_0x9936667==true and
 $t.exact_two_machine_callsite_and_flags_outcomes_reconciled==true and
 $t.bounded_instrumented_libxul_unwind_two_or_more_frames==true and
 $t.full_uninstrumented_browser_stack_observed==false and
 $t.credential_create_result=="NotAllowedError" and
 $t.physical_usb_device_passthrough==false and
 $t.m3_sixth_gate_closed==false;
 "instrumented native browser return-PC or load flags mismatch") |
check($m.status=="original_webauthn_usb_nodevice_three_phase_browser_mappings_verified" and
 $m.original_source_commit==$src and $m.original_archive_sha256==$archive and
 $m.before_host_shared_library_count==82 and
 $m.during_host_shared_library_count==83 and
 $m.after_host_shared_library_count==83 and
 $m.before_udev_mapped_filenames==[] and
 $m.during_udev_mapped_filenames==["libudev.so.1.7.15"] and
 $m.after_udev_mapped_filenames==["libudev.so.1.7.15"] and
 $m.new_host_library_basenames_during_usb_attempt==["libudev.so.1.7.15"] and
 $m.new_package_library_basenames_during_usb_attempt==[] and
 $m.snapshots_not_transient_dlopen_log_or_abi_resolution==true and
 $m.full_physical_webauthn_or_feature_ffi_closure==false and
 $m.m3_sixth_gate_closed==false and
 $f.status=="original_browser_usb_backend_no_device_negative_probe" and
 $f.original_source_commit==$src and $f.original_archive_sha256==$archive and
 $f.original_native_browser_executed==true and
 $f.real_browser_usbtoken_pref==true and $f.real_browser_softtoken_pref==false and
 $f.libudev_mapped_before_attempt==false and
 $f.libudev_mapped_during_or_after_attempt==true and
 $f.instrumented_dlopen_symbol_interposition==false and
 $f.credential_create_result=="NotAllowedError" and
 $f.physical_usb_device_passthrough==false and
 $f.m3_sixth_gate_closed==false;
 "uninterposed original browser mapping or feature result mismatch") |
{
 schema_version:1,
 status:"original_webauthn_libudev_source_machine_abi_wrapper_runtime_union_verified",
 original_source_commit:$src, original_archive_sha256:$archive,
 source_rust_loader_soname:$s.native_constructed_soname,
 original_libxul_sha256:$libxul,
 native_register_dlopen_addresses_hex:["0x993664f","0x9936664"],
 observed_instrumented_libxul_return_pcs:["0x9936652","0x9936667"],
 source_declared_udev_ffi_symbols:49,
 ubuntu_and_arch_resolved_udev_symbols:[49,49],
 original_source_rust_wrapper_udev_new_unref_executed_in_both_hosts:true,
 real_uninstrumented_browser_host_library_newly_mapped:"libudev.so.1.7.15",
 real_uninstrumented_browser_udev_still_mapped_after_notallowed:true,
 real_hardware_authenticator_tested:false,
 separate_abi_wrapper_instrumented_and_uninstrumented_workloads:true,
 cross_run_evidence_corroborates_conditional_libudev_dependency:true,
 full_uninstrumented_rust_to_dlopen_call_chain_proven:false,
 symbols_dlsym_resolved_in_real_browser_proven:false,
 full_28_elf_feature_build_and_ffi_graph_proven:false,
 source_pruning_authorized:false,native_bytes_saved:0,m3_sixth_gate_closed:false
}