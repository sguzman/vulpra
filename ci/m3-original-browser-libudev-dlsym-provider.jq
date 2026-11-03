# Original libxul-origin dlsym events only from opt-in CI interposer.
# Raw transient-PID traces are never uploaded. Provider basenames do not
# establish complete ABI/version or all 49 original Rust symbols in browser.
def check($yes;$why): if $yes then . else error($why) end;
def lines($s): $s | split("\n") | map(select(length>0) | split("\t"));
def provider: .=="libudev.so.1" or test("^libudev\\.so\\.1\\.[0-9]+(\\.[0-9]+)*$");
($abi[0]) as $source |
($feature[0]) as $browser |
lines($dlsym) as $s |
lines($dlopen) as $l |
($source.source_declared_udev_symbols) as $declared |
check(
 $source.schema_version==1 and $source.original_source_commit==$src and
 $source.status=="pinned_webauthn_libudev_isolated_host_dynamic_abi" and
 $source.isolated_host=="archlinux-container" and
 $source.source_declared_udev_soname=="libudev.so.1" and
 $source.source_declared_udev_symbol_count==49 and
 $source.host_resolved_udev_symbol_count==49 and
 ($declared|type)=="array" and ($declared|length)==49 and
 ($declared|unique|length)==49 and
 $source.original_browser_executed==false and
 $source.m3_sixth_gate_closed==false and
 $browser.schema_version==1 and
 $browser.status=="original_browser_usb_libudev_interposed_callsite_verified" and
 $browser.original_source_commit==$src and $browser.original_archive_sha256==$archive and
 $browser.original_native_browser_executed==true and
 $browser.instrumented_dlopen_symbol_interposition==true and
 $browser.real_browser_usbtoken_pref==true and $browser.real_browser_softtoken_pref==false and
 $browser.physical_usb_device_passthrough==false and
 $browser.credential_create_result=="NotAllowedError" and
 $browser.source_pinned_libxul_noload_miss_at_return_pc_0x9936652==true and
 $browser.source_pinned_libxul_normal_load_hit_at_return_pc_0x9936667==true and
 $browser.full_uninstrumented_browser_stack_observed==false and
 $browser.source_pruning_authorized==false and $browser.m3_sixth_gate_closed==false;
 "source pinned real browser / original 49-symbol Rust source ABI provenance mismatch") |
check(($l|length)>=2 and ($l|length)<=2000 and
 all($l[]; length==4 and
   (.[0]|test("^[0-9]{1,12}$")) and
   (.[1]|test("^0x[0-9a-f]+$")) and
   (.[2]|test("^0x[0-9a-f]+$")) and
   (.[3]=="hit" or .[3]=="miss"));
 "invalid instrumented browser dlopen trace") |
check(($s|length)>=1 and ($s|length)<=2000 and
 all($s[];
    length==5 and
    (.[0]|test("^[0-9]{1,12}$")) and
    (.[1]|test("^0x[0-9a-f]+$")) and
    (.[2]|test("^udev_[a-z0-9_]{1,90}$")) and
    (($declared|index(.[2]))!=null) and
    (.[3]=="hit" or .[3]=="miss") and
    (if .[3]=="hit" then (.[4]|provider) else .[4]=="none" end));
 "not source-declared original libxul dlsym or unexpected resolved provider") |
([$l[]|select(.[1]=="0x9936652" and .[2]=="0x105" and .[3]=="miss")|.[0]]) as $miss_pids |
([$l[]|select(.[1]=="0x9936667" and .[2]=="0x101" and .[3]=="hit")|.[0]]) as $open_pids |
([$s[]|select(.[3]=="hit")|.[0]]) as $symbol_hit_pids |
check(any($miss_pids[]; . as $pid | ($open_pids|index($pid))!=null and ($symbol_hit_pids|index($pid))!=null);
 "no original browser process shares source-matched dlopen miss/hit and real provider dlsym") |
([$s[]|select(.[3]=="hit")|.[2]]|unique) as $names |
([$s[]|select(.[3]=="hit")|.[4]]|unique) as $providers |
([$s[]|select(.[3]=="hit")|.[1]]|unique) as $pcs |
check(($names|index("udev_new"))!=null;
 "no actual libxul-origin udev_new symbol resolved in original native browser") |
{
 schema_version:1,
 status:"original_instrumented_browser_libxul_udev_symbol_real_provider_resolution_observed",
 original_source_commit:$src,original_archive_sha256:$archive,
 original_rust_source_declared_symbol_count:($declared|length),
 original_arch_isolated_host_symbol_resolution_count:$source.host_resolved_udev_symbol_count,
 original_browser_udev_dlsym_event_count:($s|length),
 original_browser_udev_dlsym_success_count:([$s[]|select(.[3]=="hit")]|length),
 original_browser_udev_dlsym_failure_count:([$s[]|select(.[3]=="miss")]|length),
 unique_original_browser_udev_symbols_resolved:($names|length),
 actual_original_browser_resolved_symbol_names:$names,
 actual_original_browser_udev_provider_basenames:$providers,
 original_libxul_dlsym_caller_pcs:$pcs,
 libxul_dlopen_and_libudev_dlsym_success_same_original_browser_pid_verified:true,
 source_declared_udev_new_resolved_by_actual_original_browser:true,
 source_declared_udev_symbols_not_all_tested_in_browser:true,
 ld_preload_instrumentation_changes_original_symbol_resolution:true,
 uninstrumented_original_browser_dlsym_provider_verified:false,
 physical_usb_authenticator_used:false,
 independent_archive_artifact_source_not_real_browser_ffi_execution:true,
 transient_process_ids_or_paths_exported:false,
 complete_c_abi_version_or_ffi_signatures_proven:false,
 complete_browser_feature_binary_ffi_dependency_closure:false,
 source_pruning_authorized:false,native_bytes_saved:0,m3_sixth_gate_closed:false
}