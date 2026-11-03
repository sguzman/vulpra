# Source-pinned original browser WebAuthn USB backend no-device trigger.
# Three live /proc/maps phases: before click, while libudev is mapped,
# and after expected NotAllowedError. Names are ELF backing basenames, not
# SONAME or proven symbol/version providers. No key was attached.
def check($ok; $why): if $ok then . else error($why) end;
def safe_names($xs):
  ($xs|type)=="array" and ($xs|unique|length)==($xs|length) and
  all($xs[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
def udev_file:
  type=="string" and
  (.=="libudev.so.1" or test("^libudev\\.so\\.1\\.[0-9]+(\\.[0-9]+)*$"));
def valid_map($m; $phase; $src; $sha):
  $m.schema_version==1 and
  $m.status=="original_browser_feature_live_mapped_library_snapshot" and
  $m.phase==$phase and $m.original_source_commit==$src and
  $m.original_archive_sha256==$sha and
  $m.original_browser_processes_observed>=1 and
  $m.unreadable_original_browser_maps>=0 and
  $m.original_browser_executables_only==true and
  $m.raw_paths_or_process_ids_exported==false and
  $m.time_bounded_phase_not_full_dlopen_graph==true and
  $m.source_pruning_authorized==false and $m.m3_sixth_gate_closed==false and
  ($m.libudev_mapped_in_original_browser|type)=="boolean" and
  safe_names($m.package_mapped_shared_library_basenames) and
  safe_names($m.host_mapped_shared_library_basenames) and
  (["libxul.so","libmozgtk.so"]-$m.package_mapped_shared_library_basenames|length)==0 and
  ($m.libudev_mapped_in_original_browser ==
    any($m.host_mapped_shared_library_basenames[]; udev_file));
($before[0]) as $b |
($during[0]) as $d |
($after[0]) as $z |
($feature[0]) as $f |
check(valid_map($b; "usb-before"; $src; $sha) and
      valid_map($d; "usb-during"; $src; $sha) and
      valid_map($z; "usb-after"; $src; $sha);
      "missing/invalid source-pinned original browser phase maps") |
check($f.schema_version==1 and
  $f.status=="original_browser_usb_backend_no_device_negative_probe" and
  $f.original_source_commit==$src and
  $f.original_archive_sha256==$sha and
  $f.original_native_browser_executed==true and
  $f.real_browser_usbtoken_pref==true and
  $f.real_browser_softtoken_pref==false and
  $f.real_original_web_authn_create_called_from_user_click==true and
  $f.virtual_authenticator_registered==false and
  $f.physical_usb_device_passthrough==false and
  $f.credential_create_result=="NotAllowedError" and
  $f.libudev_mapped_before_attempt==$b.libudev_mapped_in_original_browser and
  $f.libudev_mapped_during_or_after_attempt==true and
  $d.libudev_mapped_in_original_browser==true and
  $f.instrumented_dlopen_symbol_interposition==false and
  $f.actual_original_dlopen_call_stack_observed==false and
  $f.physical_security_key_authentication_verified==false and
  $f.real_user_profile_or_browser_accessed==false and
  $f.network_egress_allowed==false and
  $f.whole_dynamic_loader_graph_proven==false and
  $f.source_pruning_authorized==false and
  $f.m3_sixth_gate_closed==false;
  "real original browser USB no-device feature evidence missing") |
($b.host_mapped_shared_library_basenames) as $hb |
($d.host_mapped_shared_library_basenames) as $hd |
($z.host_mapped_shared_library_basenames) as $hz |
($b.package_mapped_shared_library_basenames) as $pb |
($d.package_mapped_shared_library_basenames) as $pd |
($z.package_mapped_shared_library_basenames) as $pz |
{
  schema_version:1,
  status:"original_webauthn_usb_nodevice_three_phase_browser_mappings_verified",
  original_source_commit:$src,
  original_archive_sha256:$sha,
  before_browser_processes:$b.original_browser_processes_observed,
  while_udev_mapped_browser_processes:$d.original_browser_processes_observed,
  after_notallowed_browser_processes:$z.original_browser_processes_observed,
  before_package_shared_library_count:($pb|length),
  during_package_shared_library_count:($pd|length),
  after_package_shared_library_count:($pz|length),
  before_host_shared_library_count:($hb|length),
  during_host_shared_library_count:($hd|length),
  after_host_shared_library_count:($hz|length),
  before_udev_mapped_filenames:[$hb[]|select(udev_file)],
  during_udev_mapped_filenames:[$hd[]|select(udev_file)],
  after_udev_mapped_filenames:[$hz[]|select(udev_file)],
  new_host_library_basenames_during_usb_attempt:($hd-$hb),
  new_package_library_basenames_during_usb_attempt:($pd-$pb),
  no_longer_mapped_host_basenames_during_usb_attempt:($hb-$hd),
  no_longer_mapped_package_basenames_during_usb_attempt:($pb-$pd),
  new_host_library_basenames_after_notallowed:($hz-$hd),
  no_longer_mapped_host_basenames_after_notallowed:($hd-$hz),
  original_browser_usbtoken_pref_verified:true,
  original_browser_softtoken_disabled:true,
  physical_hardware_device_used:false,
  real_user_clicked_create_ended_notallowed:true,
  libudev_real_browser_mapped_during_attempt:true,
  snapshots_not_transient_dlopen_log_or_abi_resolution:true,
  one_disposable_arch_weston_workload_only:true,
  no_raw_process_ids_paths_or_key_bytes:true,
  full_physical_webauthn_or_feature_ffi_closure:false,
  source_pruning_authorized:false,
  native_bytes_saved:0,
  m3_sixth_gate_closed:false
}