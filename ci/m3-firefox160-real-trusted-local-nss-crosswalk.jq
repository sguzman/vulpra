# Genuine original Firefox160 native NSS failure + real private CA-trusted
# localhost TLS evidence, from two independent immutable native CI runs.
# Exact mode-level counters and errors; never construct success from a
# provider denial request or temporary profile claim alone.
def expect($ok;$reason): if $ok then . else error($reason) end;
expect(($prior|length)==1 and ($actual|length)==1;
       "one original source/API/browser proof and one genuine trusted TLS proof required") |
($prior[0]) as $p | ($actual[0]) as $t |
expect(
  $p.schema_version==1 and
  $p.status=="firefox160_original_native_NSS_API_and_real_browser_webdriver_failure_source_crosschecked" and
  $p.exact_official_mozilla_firefox160_source_commit==$source and
  $p.original_vulpra_28_overlay_source_tree==$tree and
  $p.original_unmodified_compiled_native_archive_sha256==$archive and
  $p.original_compiled_native_browser_producer==43138458940 and
  $p.original_NSS_10_blob_source_owner_run==43745057569 and
  $p.independent_real_NSS_API_source_native_crosswalk_run==43760419551 and
  $p.actual_original_Firefox160_webdriver_NSS_denial_and_local_TLS_run==43761905154 and
  $p.source_verified_original_NSS_library_names==["libsoftokn3.so","libfreeblpriv3.so"] and
  $p.previous_native_NSS_api_softoken_failure_loader_denials==2 and
  $p.previous_native_NSS_api_freebl_failure_loader_denials==3 and
  $p.browser_baseline_WebDriver_session_created==true and
  $p.browser_baseline_actual_local_HTTP_navigation_and_javascript==true and
  $p.browser_baseline_strict_self_signed_local_HTTPS_certificate_rejected==true and
  $p.browser_softoken_denied_actual_attempts==2 and
  $p.browser_softoken_denial_rejected_WebDriver_session==true and
  $p.browser_freebl_denied_actual_attempts==3 and
  $p.browser_freebl_denial_rejected_WebDriver_session==true and
  $p.combined_mode_softoken_loader_attempts==2 and
  $p.combined_mode_freebl_loader_attempts==0 and
  $p.combined_mode_rejected_WebDriver_session==true and
  $p.all_actual_NSS_denied_browser_cases_failed_before_local_HTTP_or_HTTPS_navigation==true and
  $p.all_actual_browser_profile_sentinels_untouched==true and
  $p.browser_tested_trusted_local_certificate_TLS_handshake==false and
  $p.browser_tested_actual_public_network_TLS==false and
  $p.original_native_source_or_system_libraries_removed==false and
  $p.user_Arch_Hyprland_GPU_or_personal_profile_touched==false and
  $p.raw_library_paths_keys_PIDs_or_GeckoDriver_errors_archived==false and
  $p.direct_compiled_machine_dlopen_caller_attributed==false and
  $p.complete_Rust_CXX_FFI_dlopen_dlsym_closure_proven==false and
  $p.source_pruning_authorized==false and
  $p.security_current==false and $p.release_ready==false and
  $p.m3_sixth_gate_closed==false;
  "forged old original NSS source/runtime/browser provenance") |
expect(
  $t.schema_version==1 and
  $t.status=="firefox160_original_actual_trusted_disposable_NSS_CA_local_HTTPS_browser_and_denial" and
  $t.original_official_firefox160_commit==$source and
  $t.original_vulpra_28_overlay_source_tree==$tree and
  $t.original_compiled_browser_archive_sha256==$archive and
  $t.original_native_producer_run==43138458940 and
  $t.test_harness_commit=="658df46706b76ed984111566477d418acf40d709" and
  $t.real_original_Firefox160_native_elf_used==true and
  $t.actual_localhost_TLS_server_with_ephemeral_CA_verified_by_host==true and
  $t.ephemeral_local_CA_not_trusted_by_default_system_client==true and
  $t.temporary_NSS_cert9_key4_database_profile_only==true and
  $t.temporary_NSS_database_bytes_unchanged==true and
  $t.temporary_CA_profile_encoded_as_geckodriver_base64_ZIP==true and
  $t.acceptInsecureCerts_never_enabled==true and
  $t.untrusted_original_browser_rejected_same_local_https_server==true and
  $t.trusted_original_browser_verified_actual_secure_https_document_and_JS==true and
  $t.denied_softoken_actual_named_request_seen==true and
  $t.denied_freebl_actual_named_request_seen==true and
  $t.all_disposable_profile_sentinels_preserved==true and
  $t.all_denied_modes_reached_successful_trusted_HTTPS==false and
  $t.trusted_TLS_success_in_denied_provider_modes_proven==false and
  $t.real_external_TLS_or_public_sites_tested==false and
  $t.all_NSS_FIPS_PKCS11_browser_security_paths_proven==false and
  $t.system_NSS_trust_store_or_user_profiles_modified==false and
  $t.raw_CA_keys_geckodriver_logs_paths_PIDs_profiles_archived==false and
  $t.direct_compiled_NSS_dlopen_callsite_or_full_Rust_CXX_FFI_proven==false and
  $t.source_pruning_authorized==false and
  $t.security_current==false and $t.release_ready==false and
  $t.m3_sixth_gate_closed==false and
  ($t.modes|length)==5 and
  ($t.modes|map(.mode))==[
     "untrusted","trusted","trusted_softoken_denied",
     "trusted_freebl_denied","trusted_both_targeted"] and
  ($t.modes|map(.denial_group))==[
     "none","none","nss_softoken","nss_freebl","nss_both"] and
  ($t.modes|map(.temporary_CA_profile_injected))==[false,true,true,true,true] and
  all($t.modes[];
      .driver_ready==true and
      .private_profile_sentinel_preserved==true and
      .unexpected_native_provider_denial_lines==0 and
      .raw_log_keys_geckodriver_errors_profile_paths_or_pids_archived==false and
      .accept_insecure_certs!=true) and
  ($t.modes[0]|
      .session_created==true and
      .session_outcome=="session_created" and
      .original_packaged_firefox_reported==true and
      .accept_insecure_certs==false and
      .local_https_outcome=="strict_certificate_rejection" and
      .local_https_error_class=="insecure certificate" and
      .actual_trusted_https_secure_document_title_and_javascript==false and
      .browser_is_secure_context==false and
      .native_denied_softoken_loads==0 and
      .native_denied_freebl_loads==0 and
      .browser_native_shim_attachment_witness_count==0) and
  ($t.modes[1]|
      .session_created==true and
      .session_outcome=="session_created" and
      .original_packaged_firefox_reported==true and
      .accept_insecure_certs==false and
      .local_https_outcome=="verified_secure_document_and_javascript" and
      .actual_trusted_https_secure_document_title_and_javascript==true and
      .browser_is_secure_context==true and
      .native_denied_softoken_loads==0 and
      .native_denied_freebl_loads==0 and
      .browser_native_shim_attachment_witness_count==0) and
  ($t.modes[2]|
      .session_created==false and
      .session_outcome=="webdriver_session_rejected" and
      .session_error_class=="session not created" and
      .local_https_outcome=="not_attempted" and
      .actual_trusted_https_secure_document_title_and_javascript==false and
      .native_denied_softoken_loads==2 and
      .native_denied_freebl_loads==0 and
      .browser_native_shim_attachment_witness_count==2) and
  ($t.modes[3]|
      .session_created==false and
      .session_outcome=="webdriver_session_rejected" and
      .session_error_class=="session not created" and
      .local_https_outcome=="not_attempted" and
      .actual_trusted_https_secure_document_title_and_javascript==false and
      .native_denied_softoken_loads==0 and
      .native_denied_freebl_loads==3 and
      .browser_native_shim_attachment_witness_count==2) and
  ($t.modes[4]|
      .session_created==false and
      .session_outcome=="webdriver_session_rejected" and
      .session_error_class=="unknown error" and
      .local_https_outcome=="not_attempted" and
      .actual_trusted_https_secure_document_title_and_javascript==false and
      .native_denied_softoken_loads==2 and
      .native_denied_freebl_loads==0 and
      .browser_native_shim_attachment_witness_count==2);
  "falsified real original Firefox160 temporary CA trust, TLS/JS, NSS loads or conservative scope") |
{
  schema_version:1,
  status:"firefox160_original_actual_verified_CA_trusted_local_HTTPS_and_NSS_failure_source_crosswalk",
  official_original_firefox160_source_commit:$source,
  unchanged_vulpra_28_overlay_tree:$tree,
  unchanged_original_native_browser_archive_sha256:$archive,
  original_compiled_native_browser_run:43138458940,
  source_attested_prior_original_NSS_API_browser_run:43762347874,
  real_original_trusted_local_TLS_and_NSS_denial_run:43763326904,
  ephemeral_CA_exists_only_in_disposable_profile:true,
  ephemeral_localhost_CA_absent_from_system_trust:true,
  browser_tls_certificate_verification_enabled_for_all_real_sessions:true,
  untrusted_control_same_local_https_server_strictly_rejected:true,
  trusted_original_browser_succeeded_actual_local_TLS_secure_document_and_JavaScript:true,
  trusted_profile_certs_NSS_DB_original_copy_unchanged:true,
  actual_original_browser_NSS_softoken_denied_loads:2,
  actual_original_browser_NSS_freebl_denied_loads:3,
  combined_target_NSS_softoken_denials:2,
  combined_target_NSS_freebl_denials:0,
  denied_softoken_or_freebl_sessions_created:false,
  all_denied_provider_modes_rejected_before_HTTPS_navigation:true,
  all_temp_browser_profiles_preserved:true,
  combined_mode_generic_error_not_misclassified_as_session_not_created:true,
  no_system_trust_or_personal_browser_profile_modifications:true,
  no_keys_raw_log_lines_paths_PIDs_or_NSS_DB_exported:true,
  tested_only_single_temporary_local_CA_with_RSA_leaf:true,
  no_external_TLS_or_public_network_tests:true,
  no_full_FIPS_PKCS11_NSS_and_Gecko_security_coverage:true,
  no_complete_Rust_CXX_FFI_dlopen_dlsym_dependency_closure:true,
  no_direct_compiled_dlopen_callsite_attribution:true,
  source_pruning_authorized:false,
  security_current:false,release_ready:false,m3_sixth_gate_closed:false
}
