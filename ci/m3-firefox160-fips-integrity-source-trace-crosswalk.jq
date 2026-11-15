# Independently source/byte-attest the actual original Firefox160 NSS FIPS
# filesystem witness, including 0 requested .chk files even though neither
# belongs to the original compiled archive. No false missing-.chk causality.
def verify($v;$e):if $v then . else error($e) end;
verify(($prior|length)==1 and ($trace|length)==1;
  "One original source-attested device error and one genuine filesystem trace required") |
($prior[0]) as $p | ($trace[0]) as $t |
verify(
  $p.schema_version==1 and
  $p.status=="source_attested_original_firefox160_actual_ephemeral_FIPS_request_device_failure" and
  $p.official_original_mozilla_firefox160_source_commit==$source and
  $p.complete_original_vulpra_28_overlay_source_tree==$tree and
  $p.original_compiled_browser_archive_sha256==$archive and
  $p.original_compiled_native_browser_producer_run==43138458940 and
  $p.authentic_nonFIPS_original_PKCS11_and_localhost_TLS_crosswalk_run==43765487245 and
  $p.authentic_original_temporary_FIPS_request_native_run==43766793297 and
  $p.original_temporary_FIPS_mode_verified_successfully_enabled_by_host_modutil_only==true and
  $p.original_temporary_FIPS_mode_usable_by_archived_Firefox160_NSS==false and
  $p.source_defined_PKCS11_DEVICE_ERROR_code==-8023 and
  $p.source_defined_PR_LOAD_LIBRARY_ERROR_code==-5977 and
  $p.original_NSS_Init_normal_SQL_database_success==true and
  $p.original_nonFIPS_PKCS11_SHA256_mechanism_and_RNG_success==true and
  $p.original_FIPS_SQL_db_NSS_Init_returned_device_error==true and
  $p.original_FIPS_PK11_IsFIPS_getter_was_not_called==true and
  $p.original_FIPS_P11_mechanism_not_tested_after_failure==true and
  $p.original_FIPS_request_softoken_denials_observed==2 and
  $p.original_FIPS_request_freebl_denials_observed==0 and
  $p.original_FIPS_request_missing_softoken_returned_library_error==true and
  $p.original_FIPS_request_freebl_denial_not_exercised_due_to_earlier_error==true and
  $p.original_temporary_SQL_database_bytes_unchanged==true and
  $p.no_original_system_or_user_FIPS_settings_changed==true and
  $p.original_device_error_root_cause_unknown==true and
  $p.all_source_or_binary_removal_authorizations_false==true and
  $p.FIPS_security_140_compliance_or_certification_proven==false and
  $p.all_SSL_TLS_PKCS11_HSM_and_security_paths_proven==false and
  $p.direct_machine_FIPS_module_failure_callstack_proven==false and
  $p.Rust_CXX_FFI_dlopen_dlsym_dependency_closure_complete==false and
  $p.source_pruning_authorized==false and
  $p.security_current==false and $p.release_ready==false and $p.m3_sixth_gate_closed==false;
  "Source-attested original Firefox160 NSS FIPS failure provenance falsified") |
verify(
  $t.schema_version==1 and
  $t.status=="original_firefox160_nss_fips_integrity_missing_chk_filesystem_trace" and
  $t.official_firefox160_source_commit==$source and
  $t.candidate_vulpra_28_overlay_git_tree==$tree and
  $t.original_native_browser_archive_sha256==$archive and
  $t.original_native_build_producer_run==43138458940 and
  $t.diagnostic_harness_commit=="baa726d935d7f5e2c861b34e86a3455a29494585" and
  $t.original_native_package_contains_libsoftokn3_chk==false and
  $t.original_native_package_contains_libfreeblpriv3_chk==false and
  $t.official_NSS_FIPS_integrity_check_source_routing_verified_externally==true and
  $t.original_NSS_standard_temporary_SQL_baseline_succeeded==true and
  $t.original_NSS_FIPS_requested_SQL_Init_failed_device_error==true and
  $t.missing_integrity_chk_is_directly_witnessed_during_FIPS_mode_request==false and
  $t.no_original_chk_files_present_in_byte_preserved_archive==true and
  $t.both_disposable_profile_database_bytes_unchanged==true and
  $t.actual_syscall_tracing_executed_and_original_NSS_ELFs_accessed==true and
  $t.original_NSS_FIPS_mode_worked==false and
  $t.all_FIPS_selftests_or_integrity_checks_individually_attributed==false and
  $t.missing_chk_was_proven_the_only_possible_fatal_cause==false and
  $t.original_FIPS_build_flags_completely_recovered==false and
  $t.read_only_external_signatures_imported_or_generated==false and
  $t.host_or_user_NSS_global_system_FIPS_activated==false and
  $t.full_crypto_FIPS_140_validation_or_certification_proven==false and
  $t.direct_NSS_FIPS_native_callstack_or_full_Rust_CXX_FFI_closure_proven==false and
  $t.original_upstream_source_or_native_provider_removal_allowed==false and
  $t.security_current==false and $t.release_ready==false and $t.m3_sixth_gate_closed==false and
  ($t.modes|length)==2 and
  ($t.modes|map(.mode))==["normal","fips_requested"] and
  ($t.modes|map(.host_modutil_marked_disposable_database_FIPS))==[false,true] and
  all($t.modes[];
    .actual_file_syscalls_observed_in_source_pinned_original_process>0 and
    .original_softoken_so_file_syscall_mentions>0 and
    .original_nss_so_file_syscall_mentions>0 and
    .actual_softoken_chk_filesystem_attempts==0 and
    .actual_softoken_chk_ENOENT_missing_events==0 and
    .actual_freebl_chk_filesystem_attempts==0 and
    .actual_freebl_chk_ENOENT_missing_events==0 and
    .temporary_database_bytes_unchanged==true and
    .no_raw_strace_paths_process_ids_keys_or_profiles_archived==true) and
  ($t.modes[0]|
    .actual_file_syscalls_observed_in_source_pinned_original_process==254 and
    .original_softoken_so_file_syscall_mentions==2 and
    .original_nss_so_file_syscall_mentions==24 and
    .original_packaged_NSS_Init_return_code==0 and
    .original_packaged_NSS_Init_error_code==0 and
    .original_PK11_IsFIPS_observed_or_minus2_if_not_attempted==0 and
    .original_packaged_softoken_ELF_mapped==true and
    .original_packaged_freebl_ELF_mapped==true) and
  ($t.modes[1]|
    .actual_file_syscalls_observed_in_source_pinned_original_process==194 and
    .original_softoken_so_file_syscall_mentions==2 and
    .original_nss_so_file_syscall_mentions==24 and
    .original_packaged_NSS_Init_return_code==-1 and
    .original_packaged_NSS_Init_error_code==-8023 and
    .original_PK11_IsFIPS_observed_or_minus2_if_not_attempted==-2 and
    .original_packaged_softoken_ELF_mapped==true and
    .original_packaged_freebl_ELF_mapped==false);
  "Exact original Firefox160 FIPS filesystem or NSS safety evidence falsified") |
{
  schema_version:1,
  status:"source_attested_original_Firefox160_FIPS_device_failure_before_any_chk_file_access",
  original_mozilla_firefox160_commit:$source,
  original_vulpra_28_overlay_tree:$tree,
  unchanged_original_compiled_native_archive_sha256:$archive,
  original_native_browser_producer_run:43138458940,
  original_native_FIPS_error_source_crosswalk_run:43767128907,
  actual_original_native_FIPS_checksum_file_syscall_trace_run:43769978149,
  seven_exact_original_NSS_FIPS_error_integrity_source_blobs_authenticated:true,
  FIPS_gate_precedes_common_softoken_initialization_in_source:true,
  FIPS_source_could_return_CKR_DEVICE_ERROR_before_any_checksum_access:true,
  original_native_archive_contains_both_original_NSS_shared_libraries:true,
  original_native_archive_missing_softoken_and_freebl_chk_files:true,
  normal_original_NSS_Init_sql_succeeds:true,
  original_FIPS_requested_NSS_Init_returns_PKCS11_device_error:true,
  actual_strace_file_syscalls_observed_in_normal_mode:254,
  actual_strace_file_syscalls_observed_in_FIPS_requested_mode:194,
  actual_strace_original_libsoftokn3_so_loaded_file_references_in_both_modes:2,
  actual_strace_original_libnss3_so_file_references_in_both_modes:24,
  actual_libsoftokn3_chk_attempts_in_FIPS_requested_mode:0,
  actual_libfreeblpriv3_chk_attempts_in_FIPS_requested_mode:0,
  FIPS_device_error_directly_caused_by_missing_chk_read_proven:false,
  NSS_FIPS_DISABLED_compile_flag_witnessed_in_original_binary:false,
  actual_FIPS_selftest_failing_substep_identified:false,
  original_binary_FIPS_capable_successfully_initialized:false,
  FIPS_certification_or_approved_crypto_policy_proven:false,
  no_original_libraries_or_user_or_system_FIPS_settings_mutated:true,
  no_raw_trace_paths_keys_PIDs_modules_or_NSS_SQL_databases_archived:true,
  direct_binary_failure_callsite_proven:false,
  full_Rust_CXX_FFI_dlopen_dlsym_graph_closed:false,
  source_pruning_authorized:false,security_current:false,
  release_ready:false,m3_sixth_gate_closed:false
}
