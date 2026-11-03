# Join immutable source-pinned original 28-ELF per-file build+loader matrix
# with three *different* actual-browser Arch/Weston workload observations.
# This does not infer library non-use, explain transient loads or close M3.
def check($ok;$why): if $ok then . else error($why) end;
def safe($a):
  ($a|type)=="array" and ($a|unique|length)==($a|length) and
  ($a|length)<=256 and
  all($a[];type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
def family($n):
  if ($n|test("^libpulse\\.so\\.0(\\.[0-9]+)*$")) then "libpulse.so.0"
  elif ($n|test("^libudev\\.so\\.1(\\.[0-9]+)*$")) then "libudev.so.1"
  else null end;
($matrix[0]) as $m |
($wayland[0]) as $w |
($audio[0]) as $a |
($audio_proof[0]) as $ap |
($usb[0]) as $u |
($usb_proof[0]) as $up |
check(
  $m.schema_version==1 and
  $m.status=="original_28_elf_ubuntu_arch_per_elf_loader_and_source_crosswalk_verified" and
  $m.original_source_commit==$src and $m.original_archive_sha256==$sha and
  $m.source_manifest_owners==28 and
  $m.resolved_ubuntu_direct_needed==268 and
  $m.resolved_arch_direct_needed==268 and
  $m.every_original_elf_has_arch_loader_provider_list==true and
  $m.every_elf_direct_needed_count_matches_across_distros==true and
  $m.per_elf_provider_names_are_metadata_only==true and
  $m.complete_future_dlopen_closure_proven==false and
  $m.source_pruning_authorized==false and $m.m3_sixth_gate_closed==false and
  ($m.rows|type)=="array" and ($m.rows|length)==28 and
  ([$m.rows[].elf]|unique|length)==28 and
  all($m.rows[];
     (.elf|type)=="string" and .elf!="" and
     (.source_manifest|type)=="string" and
     (.source_manifest|contains("..")|not) and
     safe(.arch_loader_provider_basenames) and
     (.arch_loader_provider_basenames|length)==.arch_loader_provider_count and
     .direct_needed_cross_distro_count_matches==true);
  "28-ELF original per-binary manifest+provider crosswalk invalid") |
check(
  $w.schema_version==1 and
  $w.status=="original_arch_private_wayland_browser_proc_maps_residency" and
  $w.original_source_commit==$src and $w.original_archive_sha256==$sha and
  $w.browser_process_samples>=4 and
  $w.private_original_executable_only==true and
  $w.absolute_paths_or_pids_exported==false and
  $w.time_bounded_snapshot_not_all_runtime_libraries==true and
  $w.complete_browser_feature_or_ffi_dependency_closure==false and
  $w.source_removal_authorized==false and $w.m3_sixth_gate_closed==false and
  safe($w.package_mapped_library_basenames) and
  safe($w.host_mapped_library_basenames) and
  (["libxul.so","libmozgtk.so","libmozwayland.so"]-$w.package_mapped_library_basenames|length)==0;
  "original Wayland startup browser residency missing or unauthenticated") |
check(
  $a.schema_version==1 and
  $a.status=="original_browser_feature_live_mapped_library_snapshot" and
  $a.original_source_commit==$src and $a.original_archive_sha256==$sha and
  $a.phase=="during" and
  $a.original_browser_processes_observed>=1 and
  $a.original_browser_executables_only==true and
  $a.raw_paths_or_process_ids_exported==false and
  $a.time_bounded_phase_not_full_dlopen_graph==true and
  $a.source_pruning_authorized==false and $a.m3_sixth_gate_closed==false and
  safe($a.package_mapped_shared_library_basenames) and
  safe($a.host_mapped_shared_library_basenames) and
  (["libxul.so","libmozgtk.so"]-$a.package_mapped_shared_library_basenames|length)==0 and
  $a.libpulse_mapped_in_original_browser==true and
  any($a.host_mapped_shared_library_basenames[];family(.)=="libpulse.so.0") and
  $ap.schema_version==1 and
  $ap.status=="original_browser_webaudio_pulse_glibc_provider_and_live_mapping_verified" and
  $ap.original_source_commit==$src and $ap.original_browser_archive_sha256==$sha and
  $ap.original_browser_audio_backend=="pulse-rust" and
  $ap.real_web_audio_stream_into_private_null_sink==true and
  $ap.no_ld_preload_or_ld_audit==true and
  $ap.native_libpulse_binding_events>=1 and
  $ap.native_distinct_pa_symbol_count>=1 and
  $ap.exact_rust_c_caller_proven==false and
  $ap.source_pruning_authorized==false and $ap.m3_sixth_gate_closed==false and
  $ap.during_mapped_host_pulse==
    [$a.host_mapped_shared_library_basenames[]|select(family(.)=="libpulse.so.0")];
  "original live WebAudio mappings or noninterposing runtime witness inconsistent") |
check(
  $u.schema_version==1 and
  $u.status=="original_browser_feature_live_mapped_library_snapshot" and
  $u.original_source_commit==$src and $u.original_archive_sha256==$sha and
  $u.phase=="usb-during" and
  $u.original_browser_processes_observed>=1 and
  $u.original_browser_executables_only==true and
  $u.raw_paths_or_process_ids_exported==false and
  $u.time_bounded_phase_not_full_dlopen_graph==true and
  $u.source_pruning_authorized==false and $u.m3_sixth_gate_closed==false and
  safe($u.package_mapped_shared_library_basenames) and
  safe($u.host_mapped_shared_library_basenames) and
  (["libxul.so","libmozgtk.so"]-$u.package_mapped_shared_library_basenames|length)==0 and
  $u.libudev_mapped_in_original_browser==true and
  any($u.host_mapped_shared_library_basenames[];family(.)=="libudev.so.1") and
  $up.schema_version==1 and
  $up.status=="source_pinned_original_browser_host_libudev_elf_fingerprint_reconciled" and
  $up.original_source_commit==$src and $up.original_browser_archive_sha256==$sha and
  $up.mapped_file_device_and_inode_checked==true and
  $up.original_browser_same_process_glibc_self_binding_observed==true and
  $up.original_browser_host_libudev_backing_name==
    ($u.host_mapped_shared_library_basenames|map(select(family(.)=="libudev.so.1"))|.[0]) and
  ($up.original_browser_host_libudev_sha256|test("^[0-9a-f]{64}$")) and
  $up.byte_identity_proves_exact_instruction_or_rust_ffi_caller==false and
  $up.source_pruning_authorized==false and $up.m3_sixth_gate_closed==false;
  "original USB WebAuthn mapped ELF or browser host fingerprint inconsistent") |
($w.package_mapped_library_basenames) as $wp |
($a.package_mapped_shared_library_basenames) as $apkg |
($u.package_mapped_shared_library_basenames) as $upkg |
($w.host_mapped_library_basenames) as $wh |
($a.host_mapped_shared_library_basenames) as $ah |
($u.host_mapped_shared_library_basenames) as $uh |
([$m.rows[] as $item |
  {elf:$item.elf,
   source_manifest:$item.source_manifest,
   source_declaration_class:$item.source_declaration_class,
   arch_loader_provider_count:$item.arch_loader_provider_count,
   in_wayland_startup_mapped_elf:($wp|index($item.elf)!=null),
   in_webaudio_during_stream_mapped_elf:($apkg|index($item.elf)!=null),
   in_webauthn_usb_during_attempt_mapped_elf:($upkg|index($item.elf)!=null)}
 ]) as $rows |
# Guard against silently forgetting a mapped original library or conflating
# package-mapped names with host files / executable non-ELF artifacts.
($m.rows|map(.elf)|sort) as $originals |
check(([$wp[]|select(. as $n|$originals|index($n)!=null)]|unique|length)<=28 and
      ([$apkg[]|select(. as $n|$originals|index($n)!=null)]|unique|length)<=28 and
      ([$upkg[]|select(. as $n|$originals|index($n)!=null)]|unique|length)<=28;
      "original mapped ELF set exceeds source matrix") |
([ $rows[]|select(.in_wayland_startup_mapped_elf or
                  .in_webaudio_during_stream_mapped_elf or
                  .in_webauthn_usb_during_attempt_mapped_elf)|.elf]) as $seen |
($originals-$seen) as $not_seen |
([$wh[],$ah[],$uh[]]|unique|sort) as $host_union |
{
 schema_version:1,
 status:"source_pinned_original_28_elf_three_actual_browser_workload_residency_crosswalk",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 accepted_input_run_ids:{
   per_elf_two_platform_loader:41515803526,
   arch_weston_browser_startup:41658199812,
   native_webaudio_glibc:41714793962,
   native_usb_no_device:41712441426
 },
 matrix_original_elf_members:28,
 matrix_arch_direct_needed_edges:268,
 actually_mapped_in_at_least_one_bounded_workload_count:($seen|length),
 actually_mapped_in_at_least_one_bounded_workload_names:$seen,
 not_observed_as_resident_in_these_samples_count:($not_seen|length),
 not_observed_as_resident_in_these_samples_names:$not_seen,
 original_elf_wayland_sample_count:([$rows[]|select(.in_wayland_startup_mapped_elf)]|length),
 original_elf_webaudio_sample_count:([$rows[]|select(.in_webaudio_during_stream_mapped_elf)]|length),
 original_elf_usb_sample_count:([$rows[]|select(.in_webauthn_usb_during_attempt_mapped_elf)]|length),
 original_browser_host_mapped_basename_union_count:($host_union|length),
 original_browser_host_mapped_basename_union:$host_union,
 host_pulse_backing_names:[$ah[]|select(family(.)=="libpulse.so.0")],
 host_usb_backing_names:[$uh[]|select(family(.)=="libudev.so.1")],
 webaudio_native_glibc_pa_symbol_count:$ap.native_distinct_pa_symbol_count,
 usb_udev_host_sha256_verified:true,
 no_source_pruning_justified_by_absence_of_a_sample:true,
 glibc_loader_provider_lists_are_not_runtime_mappings:true,
 cross_run_workloads_not_one_continuous_loader_trace:true,
 phases_can_miss_transient_libraries:true,
 host_library_filename_does_not_identify_abi_provider_or_caller:true,
 full_28_elf_feature_build_ffi_and_future_dlopen_closure:false,
 target_endeavouros_hyprland_verified:false,
 source_pruning_authorized:false,
 native_bytes_saved:0,
 m3_sixth_gate_closed:false,
 rows:$rows
}
