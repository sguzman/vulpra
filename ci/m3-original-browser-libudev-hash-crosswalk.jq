# Reconcile live original-browser mapped host ELF fingerprint with a separate
# accepted Arch ELF relocation artifact. Filenames alone never prove identity.
def check($ok; $why): if $ok then . else error($why) end;
def hash: type=="string" and test("^[0-9a-f]{64}$");
def udev_file: type=="string" and test("^libudev\\.so\\.1\\.[0-9]+(\\.[0-9]+)*$");
($live[0]) as $l | ($maps[0]) as $m | ($glibc[0]) as $g | ($arch[0]) as $a |
check(
  $l.schema_version==1 and
  $l.status=="original_browser_live_mapped_host_libudev_sha256" and
  $l.original_source_commit==$source and $l.original_archive_sha256==$archive and
  ($l.host_mapped_elf_backing_name|udev_file) and
  ($l.host_mapped_elf_sha256|hash) and
  $l.original_browser_processes_observed>=1 and
  $l.original_libxul_loaded_browser_mapping_verified==true and
  $l.mapped_elf_device_and_inode_verified==true and
  $l.no_ld_preload_or_ld_audit_used==true and
  $l.raw_process_ids_paths_or_maps_exported==false and
  $l.exact_rust_or_c_caller_identified==false and
  $l.full_dynamic_dependency_closure_proven==false and
  $l.source_pruning_authorized==false and $l.m3_sixth_gate_closed==false and
  $m.status=="original_webauthn_usb_nodevice_three_phase_browser_mappings_verified" and
  $m.original_source_commit==$source and $m.original_archive_sha256==$archive and
  $m.during_udev_mapped_filenames==[$l.host_mapped_elf_backing_name] and
  $m.libudev_real_browser_mapped_during_attempt==true and
  $m.m3_sixth_gate_closed==false and
  $g.status=="original_browser_source_pinned_glibc_no_preload_udev_binding_reconciled" and
  $g.original_source_commit==$source and $g.original_archive_sha256==$archive and
  $g.native_glibc_unattributed_symbol_glibc_requester_basenames==["libudev.so.1"] and
  $g.native_glibc_unattributed_symbol_provider_basenames==["libudev.so.1"] and
  $g.m3_sixth_gate_closed==false and
  $a.status=="arch_libudev_versioned_glob_dat_self_relocation_correlated_with_original_vulpra_runtime" and
  $a.original_source_commit==$source and $a.original_browser_archive_sha256==$archive and
  $a.compared_arch_host_elf_backing_name==$l.host_mapped_elf_backing_name and
  ($a.compared_arch_host_elf_sha256|hash) and
  $a.host_relocation_kind=="R_X86_64_GLOB_DAT" and
  $a.host_relocation_symbol=="udev_monitor_filter_update" and
  $a.host_relocation_version=="LIBUDEV_183" and
  $a.host_dynamic_symbol_is_defined_global_func==true and
  $a.glibc_browser_observed_self_binding==true and
  $a.m3_sixth_gate_closed==false;
  "live original browser host ELF fingerprint, mapped snapshot, glibc binding or Arch ELF provenance mismatch") |
{
  schema_version:1,
  status:"source_pinned_original_browser_host_libudev_elf_fingerprint_reconciled",
  original_source_commit:$source,
  original_browser_archive_sha256:$archive,
  original_browser_host_libudev_backing_name:$l.host_mapped_elf_backing_name,
  original_browser_host_libudev_sha256:$l.host_mapped_elf_sha256,
  separately_inspected_arch_host_libudev_sha256:$a.compared_arch_host_elf_sha256,
  separate_arch_host_elf_byte_identical_to_browser_host:
    ($l.host_mapped_elf_sha256==$a.compared_arch_host_elf_sha256),
  mapped_file_device_and_inode_checked:true,
  original_browser_same_process_glibc_self_binding_observed:true,
  byte_identity_proves_exact_instruction_or_rust_ffi_caller:false,
  full_native_dependency_closure_proven:false,
  source_pruning_authorized:false,
  native_bytes_saved:0,
  m3_sixth_gate_closed:false
}
