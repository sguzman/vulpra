# Compare a current isolated Arch libudev ELF's internal PLT relocation
# with independently source-pinned Vulpra original-browser glibc trace.
# A matched backing filename is NOT an identical ELF SHA across CI runs.
def check($v;$message): if $v then . else error($message) end;
def ishash: type=="string" and test("^[0-9a-f]{64}$");
($glibc[0]) as $g | ($abi[0]) as $a |
($relocs | split("\n") | map(select(contains("udev_monitor_filter_update") and contains("R_X86_64_JUMP_SLOT")))) as $r |
($dynsym | split("\n") | map(select(contains("udev_monitor_filter_update") and test("[[:space:]]FUNC[[:space:]]+GLOBAL[[:space:]]+DEFAULT[[:space:]]")))) as $s |
check(
 $g.status=="original_browser_source_pinned_glibc_no_preload_udev_binding_reconciled" and
 $g.original_source_commit==$source and $g.original_archive_sha256==$archive and
 $g.native_glibc_unattributed_external_symbol_names==["udev_monitor_filter_update"] and
 $g.native_glibc_unattributed_symbol_binding_events==1 and
 $g.native_glibc_unattributed_symbol_glibc_requester_basenames==["libudev.so.1"] and
 $g.native_glibc_unattributed_symbol_provider_basenames==["libudev.so.1"] and
 $g.native_glibc_unattributed_symbol_requesters_are_only_its_provider==true and
 $g.native_glibc_binding_file_requester_not_definitive_original_caller==true and
 $g.extra_symbol_original_caller_ownership_proven==false and
 $g.no_ld_preload_or_ld_audit_used==true and $g.m3_sixth_gate_closed==false and
 $a.status=="pinned_webauthn_libudev_isolated_host_dynamic_abi" and
 $a.original_source_commit==$source and $a.isolated_host=="archlinux-container" and
 $a.source_declared_udev_symbol_count==49 and $a.host_resolved_udev_symbol_count==49 and
 ($a.source_declared_udev_symbols|length)==49 and
 ($a.source_declared_udev_symbols|index("udev_monitor_filter_update"))==null and
 $a.original_browser_executed==false and $a.m3_sixth_gate_closed==false;
 "original browser self-binding or Rust source ownership boundary mismatch") |
check(
 $arch_backing_name=="libudev.so.1.7.15" and ($arch_elf_sha256|ishash) and
 ($r|length)==1 and ($s|length)==1 and
 ($r[0]|test("^[[:space:]]*[0-9a-fA-F]+[[:space:]]+[0-9a-fA-F]+[[:space:]]+R_X86_64_JUMP_SLOT[[:space:]]+[0-9a-fA-F]+[[:space:]]+udev_monitor_filter_update@@LIBUDEV_183[[:space:]]+\\+[[:space:]]+0[[:space:]]*$")) and
 ($s[0]|test("^[[:space:]]*[0-9]+:[[:space:]]+[0-9a-fA-F]+[[:space:]]+[0-9]+[[:space:]]+FUNC[[:space:]]+GLOBAL[[:space:]]+DEFAULT[[:space:]]+[0-9]+[[:space:]]+udev_monitor_filter_update@@LIBUDEV_183[[:space:]]*$"));
 "isolated Arch ELF self-PLT relocation or versioned global export missing") |
($r[0]|capture("^[[:space:]]*(?<offset>[0-9a-fA-F]+)[[:space:]]+")) as $slot |
{
 schema_version:1,
 status:"arch_libudev_internal_versioned_plt_self_binding_correlated_with_original_vulpra_runtime",
 original_source_commit:$source,
 original_browser_archive_sha256:$archive,
 compared_arch_host_elf_backing_name:$arch_backing_name,
 compared_arch_host_elf_sha256:$arch_elf_sha256,
 host_relocation_kind:"R_X86_64_JUMP_SLOT",
 host_relocation_symbol:"udev_monitor_filter_update",
 host_relocation_version:"LIBUDEV_183",
 host_relocation_offset_hex:("0x"+$slot.offset),
 host_dynamic_symbol_is_defined_global_func:true,
 glibc_browser_observed_self_binding:true,
 source_declared_original_web_authn_ffi_symbols:49,
 extra_symbol_not_original_web_authn_ffi_declaration:true,
 independent_arch_host_elf_binaries_cryptographically_matched:false,
 original_browser_uninstrumented_rust_call_stack_proven:false,
 specific_internal_libudev_source_instruction_proven:false,
 physical_security_key_tested:false,
 complete_28_elf_dependency_closure_proven:false,
 source_pruning_authorized:false,
 native_bytes_saved:0,
 m3_sixth_gate_closed:false
}