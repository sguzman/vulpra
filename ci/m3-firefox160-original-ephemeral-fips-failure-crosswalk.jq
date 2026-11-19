# Actual source-pinned Firefox160 NSS_Init SQL FIPS-request device failure.
# Verify only observed state: FIPS was enabled inside a temporary database by
# host modutil, but original Firefox160 PKCS11 mode was NOT reachable.
# Compare independently accepted original NSS nonFIPS PKCS11/TLS baseline.
def require($ok;$message):if $ok then . else error($message) end;
require(($baseline|length)==1 and ($fips|length)==1;
  "One independently verified original NSS nonFIPS/TLS report and one actual temporary FIPS failure required") |
($baseline[0]) as $b | ($fips[0]) as $f |
require(
  $b.schema_version==1 and
  $b.status=="original_firefox160_readonly_PKCS11_SHA256_nonFIPS_source_attested_native_proof" and
  $b.original_official_Mozilla_Firefox160_commit==$source and
  $b.complete_vulpra_28_overlay_source_tree==$tree and
  $b.original_compiled_Firefox160_native_archive_sha256==$archive and
  $b.original_native_browser_producer_run==43138458940 and
  $b.ten_exact_original_upstream_NSS_source_blobs_verified_in_native_run==true and
  $b.source_paths_outside_all_28_Vulpra_overlays_verified==true and
  $b.actual_source_attested_prior_trusted_CA_local_TLS_crosswalk_run==43763693842 and
  $b.actual_source_attested_pkcs11_readonly_original_native_run==43765136534 and
  $b.original_libnss3_PKCS11_symbols_resolved_from_exact_package==true and
  $b.original_baseline_NSS_NoDB_Init_rc==0 and
  $b.baseline_internal_PKCS11_slot_and_keyslot_present==true and
  $b.original_PKCS11_CKM_SHA256_mechanism_available==true and
  $b.baseline_original_RNG_and_NSS_shutdown_success==true and
  $b.actual_PK11_IsFIPS_readonly_result==0 and
  $b.actual_system_FIPS_indicator_readonly_result==0 and
  $b.observed_NSS_mode_is_nonFIPS==true and
  $b.actual_individual_softoken_loader_denials==2 and
  $b.actual_individual_freebl_loader_denials==3 and
  $b.actual_combined_softoken_denials==2 and
  $b.actual_combined_freebl_requests==0 and
  $b.three_provider_missing_NSS_initializations_fail_without_process_crash==true and
  $b.actual_trusted_local_RSA_CA_https_webdriver_success_in_separate_real_browser_run==true and
  $b.no_private_keys_PINs_tokens_passwords_or_FIPS_mode_changes==true and
  $b.cannot_claim_FIPS_mode_test_or_140_certification==true and
  $b.no_external_PKCS11_HSM_or_key_management_tests==true and
  $b.direct_NSS_native_dlopen_machine_callstack_unproven==true and
  $b.complete_Rust_CXX_FFI_dlopen_dlsym_closure_unproven==true and
  $b.source_pruning_authorized==false and
  $b.security_current==false and $b.release_ready==false and
  $b.m3_sixth_gate_closed==false;
  "Forged original Firefox160 source/TLS/nonFIPS PKCS11 evidence") |
require(
  $f.schema_version==1 and
  $f.status=="real_original_firefox160_ephemeral_SQL_DB_FIPS_requested_NSS_device_error" and
  $f.official_Mozilla_Firefox160_commit==$source and
  $f.original_vulpra_28_overlay_source_tree==$tree and
  $f.original_native_browser_archive_sha256==$archive and
  $f.original_native_browser_producer_run==43138458940 and
  $f.fips_test_harness_commit=="272888fa610a1b9d6d218b4d47902e8466628232" and
  $f.actual_temp_SQL_NSS_databases_constructed==true and
  $f.FIPS_setting_only_changed_inside_temp_SQL_DB_by_system_modutil==true and
  $f.disposable_modutil_enabled_FIPS_in_temp_DB_and_verified==true and
  $f.disposable_plain_SQL_NSS_DB_prepared_and_verified_nonFIPS==true and
  $f.original_NSS_run_used_the_actual_archived_libnss3==true and
  $f.original_NSS_read_only_PK11_IsFIPS_witnessed_true==false and
  $f.original_plain_SQL_PK11_IsFIPS_witnessed_false==true and
  $f.original_plain_SQL_NSS_Init_successfully_executed_nonFIPS==true and
  $f.original_FIPS_requested_NSS_Init_reported_PKCS11_DEVICE_ERROR==true and
  $f.FIPS_requested_mode_could_not_query_PK11_IsFIPS_due_to_init_failure==true and
  $f.original_FIPS_request_with_softoken_blocked_reported_load_library_error==true and
  $f.FIPS_request_with_only_freebl_deny_did_not_reach_freebl_load==true and
  $f.FIPS_request_with_both_deny_stops_at_softoken==true and
  $f.original_FIPS_mode_internal_and_key_slot_shared==false and
  $f.original_nonFIPS_mode_internal_and_key_slot_distinct==true and
  $f.original_FIPS_SQL_PKCS11_SHA256_mechanism_and_RNG_successful==false and
  $f.original_FIPS_SQL_softoken_denied_loads_actually_observed==true and
  $f.original_FIPS_SQL_freebl_denied_loads_actually_observed==false and
  $f.original_FIPS_SQL_both_targeted_and_softoken_failure==true and
  $f.original_temporary_NSS_DB_bytes_unchanged_after_all_original_native_probes==true and
  $f.FIPS_device_error_underlying_cause_disassembled_or_proven==false and
  $f.exact_temp_NSS_SQL_profile_only_no_user_or_system_trust_modification==true and
  $f.all_five_probe_processes_terminated_without_crash_or_timeout==true and
  $f.all_temporary_data_deleted_after_process_exits==true and
  $f.FIPS_140_security_certification_or_compliance_proven==false and
  $f.FIPS_approved_crypto_policy_and_external_HSMs_exhaustively_tested==false and
  $f.no_private_key_PIN_token_write_or_password_operations==true and
  $f.source_pruning_authorized==false and $f.security_current==false and
  $f.release_ready==false and
  $f.complete_original_Rust_CXX_FFI_dlopen_dlsym_closure_proven==false and
  $f.m3_sixth_gate_closed==false and
  ($f.modes|length)==5 and
  ($f.modes|map(.mode))==[
    "normal_sql","temporary_fips_sql","temporary_fips_softoken_missing",
    "temporary_fips_freebl_missing","temporary_fips_both_targeted"] and
  ($f.modes|map(.denial_group))==[
    "none","none","nss_softoken","nss_freebl","nss_both"] and
  all($f.modes[];
    .probe_exit==0 and .original_libnss3_open==1 and
    .original_NSS_symbols_exact_ownership==1 and
    .raw_NSS_DB_keys_logs_paths_PIDs_tokens_or_PINs_exported==false and
    .actual_total_denied_native_loads==
      (.actual_denied_softoken_native_loads+.actual_denied_freebl_native_loads)) and
  ($f.modes[0]|
    .original_NSS_Init_sql_rc==0 and .original_NSS_Init_error_code==0 and
    .original_PK11_IsFIPS_mode==0 and .runner_system_FIPS_indicator_read_only==0 and
    .internal_slot_obtained==1 and .internal_key_slot_obtained==1 and
    .internal_slot_present==1 and .internal_key_slot_present==1 and
    .internal_default_and_key_slot_same_identity==0 and
    .original_CKM_SHA256_mechanism_supported==1 and
    .original_PK11_GenerateRandom_rc==0 and
    .RNG_nonzero_sample_not_archived==true and
    .original_NSS_Shutdown_rc==0 and
    .original_packaged_softoken_mapped==true and
    .original_packaged_freebl_mapped==true and
    .actual_total_denied_native_loads==0 and
    .native_probe_shim_attachment_witnesses==0) and
  ($f.modes[1]|
    .original_NSS_Init_sql_rc==-1 and
    .original_NSS_Init_error_code==-8023 and
    .original_PK11_IsFIPS_mode==-2 and
    .internal_slot_obtained==-2 and .internal_key_slot_obtained==-2 and
    .original_CKM_SHA256_mechanism_supported==-2 and
    .original_PK11_GenerateRandom_rc==-2 and
    .original_NSS_Shutdown_rc==-2 and
    .original_packaged_softoken_mapped==true and
    .original_packaged_freebl_mapped==false and
    .actual_total_denied_native_loads==0 and
    .native_probe_shim_attachment_witnesses==0) and
  ($f.modes[2]|
    .original_NSS_Init_sql_rc==-1 and
    .original_NSS_Init_error_code==-5977 and
    .original_PK11_IsFIPS_mode==-2 and
    .actual_denied_softoken_native_loads==2 and
    .actual_denied_freebl_native_loads==0 and
    .original_packaged_softoken_mapped==false and
    .original_packaged_freebl_mapped==false and
    .native_probe_shim_attachment_witnesses==1) and
  ($f.modes[3]|
    .original_NSS_Init_sql_rc==-1 and
    .original_NSS_Init_error_code==-8023 and
    .original_PK11_IsFIPS_mode==-2 and
    .actual_denied_softoken_native_loads==0 and
    .actual_denied_freebl_native_loads==0 and
    .original_packaged_softoken_mapped==true and
    .original_packaged_freebl_mapped==false and
    .native_probe_shim_attachment_witnesses==1) and
  ($f.modes[4]|
    .original_NSS_Init_sql_rc==-1 and
    .original_NSS_Init_error_code==-5977 and
    .original_PK11_IsFIPS_mode==-2 and
    .actual_denied_softoken_native_loads==2 and
    .actual_denied_freebl_native_loads==0 and
    .original_packaged_softoken_mapped==false and
    .original_packaged_freebl_mapped==false and
    .native_probe_shim_attachment_witnesses==1);
  "Forged original NSS FIPS-request failure, initialization error, module mappings or conservative scope") |
{
  schema_version:1,
  status:"source_attested_original_firefox160_actual_ephemeral_FIPS_request_device_failure",
  official_original_mozilla_firefox160_source_commit:$source,
  complete_original_vulpra_28_overlay_source_tree:$tree,
  original_compiled_browser_archive_sha256:$archive,
  original_compiled_native_browser_producer_run:43138458940,
  authentic_nonFIPS_original_PKCS11_and_localhost_TLS_crosswalk_run:43765487245,
  authentic_original_temporary_FIPS_request_native_run:43766793297,
  original_temporary_FIPS_mode_verified_successfully_enabled_by_host_modutil_only:true,
  original_temporary_FIPS_mode_usable_by_archived_Firefox160_NSS:false,
  source_defined_PKCS11_DEVICE_ERROR_code:-8023,
  source_defined_PR_LOAD_LIBRARY_ERROR_code:-5977,
  original_NSS_Init_normal_SQL_database_success:true,
  original_nonFIPS_PKCS11_SHA256_mechanism_and_RNG_success:true,
  original_FIPS_SQL_db_NSS_Init_returned_device_error:true,
  original_FIPS_PK11_IsFIPS_getter_was_not_called:true,
  original_FIPS_P11_mechanism_not_tested_after_failure:true,
  original_FIPS_request_softoken_denials_observed:2,
  original_FIPS_request_freebl_denials_observed:0,
  original_FIPS_request_missing_softoken_returned_library_error:true,
  original_FIPS_request_freebl_denial_not_exercised_due_to_earlier_error:true,
  original_temporary_SQL_database_bytes_unchanged:true,
  no_original_system_or_user_FIPS_settings_changed:true,
  original_device_error_root_cause_unknown:true,
  all_source_or_binary_removal_authorizations_false:true,
  FIPS_security_140_compliance_or_certification_proven:false,
  all_SSL_TLS_PKCS11_HSM_and_security_paths_proven:false,
  direct_machine_FIPS_module_failure_callstack_proven:false,
  Rust_CXX_FFI_dlopen_dlsym_dependency_closure_complete:false,
  source_pruning_authorized:false,security_current:false,
  release_ready:false,m3_sixth_gate_closed:false
}
