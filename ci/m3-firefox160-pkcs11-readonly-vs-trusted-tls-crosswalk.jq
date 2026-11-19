# Actual original Firefox160 NSS PKCS11 slot/SHA256/read-only FIPS
# against previous independent original Firefox160 trusted TLS baseline.
# Never infer FIPS certification from PK11_IsFIPS() or mode zero.
def need($v;$why):if $v then . else error($why) end;
need(($tls|length)==1 and ($pkcs11|length)==1;
  "One authentic original Firefox160 trusted TLS and one PKCS11 API report") |
($tls[0]) as $t | ($pkcs11[0]) as $p |
need($t.schema_version==1 and
  $t.status=="firefox160_original_actual_verified_CA_trusted_local_HTTPS_and_NSS_failure_source_crosswalk" and
  $t.official_original_firefox160_source_commit==$source and
  $t.unchanged_vulpra_28_overlay_tree==$tree and
  $t.unchanged_original_native_browser_archive_sha256==$archive and
  $t.original_compiled_native_browser_run==43138458940 and
  $t.source_attested_prior_original_NSS_API_browser_run==43762347874 and
  $t.real_original_trusted_local_TLS_and_NSS_denial_run==43763326904 and
  $t.ephemeral_CA_exists_only_in_disposable_profile==true and
  $t.ephemeral_localhost_CA_absent_from_system_trust==true and
  $t.browser_tls_certificate_verification_enabled_for_all_real_sessions==true and
  $t.untrusted_control_same_local_https_server_strictly_rejected==true and
  $t.trusted_original_browser_succeeded_actual_local_TLS_secure_document_and_JavaScript==true and
  $t.trusted_profile_certs_NSS_DB_original_copy_unchanged==true and
  $t.actual_original_browser_NSS_softoken_denied_loads==2 and
  $t.actual_original_browser_NSS_freebl_denied_loads==3 and
  $t.combined_target_NSS_softoken_denials==2 and
  $t.combined_target_NSS_freebl_denials==0 and
  $t.denied_softoken_or_freebl_sessions_created==false and
  $t.all_denied_provider_modes_rejected_before_HTTPS_navigation==true and
  $t.all_temp_browser_profiles_preserved==true and
  $t.combined_mode_generic_error_not_misclassified_as_session_not_created==true and
  $t.no_system_trust_or_personal_browser_profile_modifications==true and
  $t.no_keys_raw_log_lines_paths_PIDs_or_NSS_DB_exported==true and
  $t.tested_only_single_temporary_local_CA_with_RSA_leaf==true and
  $t.no_external_TLS_or_public_network_tests==true and
  $t.no_full_FIPS_PKCS11_NSS_and_Gecko_security_coverage==true and
  $t.no_complete_Rust_CXX_FFI_dlopen_dlsym_dependency_closure==true and
  $t.no_direct_compiled_dlopen_callsite_attribution==true and
  $t.source_pruning_authorized==false and
  $t.security_current==false and $t.release_ready==false and
  $t.m3_sixth_gate_closed==false;
  "Forged original Firefox160 actual trusted TLS and NSS source evidence") |
need($p.schema_version==1 and
  $p.status=="original_firefox160_real_readonly_PKCS11_internal_slot_SHA256_FIPS_state_under_NSS_denial" and
  $p.official_Firefox160_release_commit==$source and
  $p.complete_vulpra_28_overlay_tree==$tree and
  $p.unchanged_original_native_archive_sha256==$archive and
  $p.original_native_browser_build_run==43138458940 and
  $p.probe_harness_commit=="66599cc889a854de41bf5912159ee8056cc981ef" and
  $p.original_packaged_NSS_PKCS11_readonly_operations_executed==true and
  $p.baseline_real_original_PKCS11_available==true and
  $p.original_module_FIPS_mode_readonly==0 and
  $p.runner_system_FIPS_mode_readonly==0 and
  $p.softoken_missing_actual_loads_observed==true and
  $p.freebl_missing_actual_loads_observed==true and
  $p.combined_target_softoken_failure_prevents_freebl_attempt==true and
  $p.all_original_NSS_PKCS11_probes_completed_without_crash==true and
  $p.FIPS_enabled_or_FIPS_security_compliance_tested==false and
  $p.no_FIPS_mode_change_or_system_crypto_config_mutation==true and
  $p.no_private_key_PIN_token_write_or_password_operation==true and
  $p.no_external_HSM_or_PKCS11_module_enumeration==true and
  $p.real_browser_HTTPS_PKCS11_tested_in_this_native_run==false and
  $p.full_Rust_CXX_FFI_dlopen_dlsym_graph_closed==false and
  $p.actual_source_level_machine_callstacks_proven==false and
  $p.personal_Arch_Hyprland_profiles_modified==false and
  $p.source_pruning_authorized==false and $p.security_current==false and
  $p.release_ready==false and $p.m3_sixth_gate_closed==false and
  ($p.modes|length)==4 and
  ($p.modes|map(.mode))==["baseline","softoken_missing","freebl_missing","both_targeted"] and
  ($p.modes|map(.denial_group))==["none","nss_softoken","nss_freebl","nss_both"] and
  all($p.modes[];
    .process_exit==0 and
    .original_nss_open==1 and
    .exact_original_symbols==1 and
    .FIPS_mode_changed==false and
    .original_private_paths_PIDs_keys_tokens_PINS_or_raw_logs_exported==false and
    .actual_total_native_denials==
      (.actual_softoken_native_denials+.actual_freebl_native_denials)) and
  ($p.modes[0]|
    .NSS_NoDB_Init_rc==0 and .original_PKCS11_FIPS_mode_readonly==0 and
    .system_FIPS_mode_readonly==0 and
    .internal_slot_obtained==1 and .internal_key_slot_obtained==1 and
    .internal_slot_present==1 and .internal_key_slot_present==1 and
    .SHA256_PKCS11_mechanism_available==1 and
    .original_RNG_rc==0 and .random_bytes_nonzero==true and
    .NSS_Shutdown_rc==0 and
    .original_softoken_ELF_mapped==true and
    .original_freebl_ELF_mapped==true and
    .actual_total_native_denials==0 and
    .original_native_shim_attachment_count==0) and
  ($p.modes[1]|
    .NSS_NoDB_Init_rc==-1 and .original_PKCS11_FIPS_mode_readonly==-2 and
    .system_FIPS_mode_readonly==-2 and
    .internal_slot_obtained==-2 and .internal_key_slot_obtained==-2 and
    .internal_slot_present==-2 and .internal_key_slot_present==-2 and
    .SHA256_PKCS11_mechanism_available==-2 and
    .original_RNG_rc==-2 and .random_bytes_nonzero==false and
    .NSS_Shutdown_rc==-2 and
    .original_softoken_ELF_mapped==false and
    .original_freebl_ELF_mapped==false and
    .actual_softoken_native_denials==2 and
    .actual_freebl_native_denials==0 and
    .original_native_shim_attachment_count==1) and
  ($p.modes[2]|
    .NSS_NoDB_Init_rc==-1 and .original_PKCS11_FIPS_mode_readonly==-2 and
    .system_FIPS_mode_readonly==-2 and
    .internal_slot_obtained==-2 and .internal_key_slot_obtained==-2 and
    .internal_slot_present==-2 and .internal_key_slot_present==-2 and
    .SHA256_PKCS11_mechanism_available==-2 and
    .original_RNG_rc==-2 and .random_bytes_nonzero==false and
    .NSS_Shutdown_rc==-2 and
    .original_softoken_ELF_mapped==true and
    .original_freebl_ELF_mapped==false and
    .actual_softoken_native_denials==0 and
    .actual_freebl_native_denials==3 and
    .original_native_shim_attachment_count==1) and
  ($p.modes[3]|
    .NSS_NoDB_Init_rc==-1 and .original_PKCS11_FIPS_mode_readonly==-2 and
    .system_FIPS_mode_readonly==-2 and
    .internal_slot_obtained==-2 and .internal_key_slot_obtained==-2 and
    .internal_slot_present==-2 and .internal_key_slot_present==-2 and
    .SHA256_PKCS11_mechanism_available==-2 and
    .original_RNG_rc==-2 and .random_bytes_nonzero==false and
    .NSS_Shutdown_rc==-2 and
    .original_softoken_ELF_mapped==false and
    .original_freebl_ELF_mapped==false and
    .actual_softoken_native_denials==2 and
    .actual_freebl_native_denials==0 and
    .original_native_shim_attachment_count==1);
  "Forged original Firefox160 PKCS11 slot/mechanism/FIPS readout or native provider observation") |
{
  schema_version:1,
  status:"original_firefox160_readonly_PKCS11_SHA256_nonFIPS_source_attested_native_proof",
  original_official_Mozilla_Firefox160_commit:$source,
  complete_vulpra_28_overlay_source_tree:$tree,
  original_compiled_Firefox160_native_archive_sha256:$archive,
  original_native_browser_producer_run:43138458940,
  ten_exact_original_upstream_NSS_source_blobs_verified_in_native_run:true,
  source_paths_outside_all_28_Vulpra_overlays_verified:true,
  actual_source_attested_prior_trusted_CA_local_TLS_crosswalk_run:43763693842,
  actual_source_attested_pkcs11_readonly_original_native_run:43765136534,
  original_libnss3_PKCS11_symbols_resolved_from_exact_package:true,
  original_baseline_NSS_NoDB_Init_rc:0,
  baseline_internal_PKCS11_slot_and_keyslot_present:true,
  original_PKCS11_CKM_SHA256_mechanism_available:true,
  baseline_original_RNG_and_NSS_shutdown_success:true,
  actual_PK11_IsFIPS_readonly_result:0,
  actual_system_FIPS_indicator_readonly_result:0,
  observed_NSS_mode_is_nonFIPS:true,
  actual_individual_softoken_loader_denials:2,
  actual_individual_freebl_loader_denials:3,
  actual_combined_softoken_denials:2,
  actual_combined_freebl_requests:0,
  three_provider_missing_NSS_initializations_fail_without_process_crash:true,
  actual_trusted_local_RSA_CA_https_webdriver_success_in_separate_real_browser_run:true,
  no_private_keys_PINs_tokens_passwords_or_FIPS_mode_changes:true,
  cannot_claim_FIPS_mode_test_or_140_certification:true,
  no_external_PKCS11_HSM_or_key_management_tests:true,
  no_any_source_pruning_or_native_library_removal_authorization:true,
  no_public_TLS_replay_or_all_Gecko_security_test_completion:true,
  direct_NSS_native_dlopen_machine_callstack_unproven:true,
  complete_Rust_CXX_FFI_dlopen_dlsym_closure_unproven:true,
  target_Arch_Hyprland_GPU_validation_unproven:true,
  source_pruning_authorized:false,
  security_current:false,release_ready:false,m3_sixth_gate_closed:false
}
