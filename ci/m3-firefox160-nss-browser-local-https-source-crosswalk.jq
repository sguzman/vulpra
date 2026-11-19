# Verify two immutable actual original Firefox160 cryptographic provider
# observations: native NSS API initialization failure and REAL WebDriver
# browser startup/local HTTP/strict local certificate behavior. No raw paths.
def ensure($v;$e):if $v then . else error($e) end;
ensure(($native|length)==1 and ($browser|length)==1;
  "Exactly one authentic original NSS API and real browser report required") |
($native[0]) as $n | ($browser[0]) as $b |
ensure(
  $n.schema_version==1 and
  $n.status=="firefox160_original_nss_softoken_freebl_guards_real_C_API_failure_source_verified" and
  $n.exact_official_firefox160_source_commit==$upstream and
  $n.original_vulpra_28_overlay_source_tree==$tree and
  $n.original_compiled_native_archive_sha256==$archive and
  $n.original_native_package_build_run==43138458940 and
  $n.exact_10_source_NSS_FFVPX_owner_producer_run==43745057569 and
  $n.original_real_NSS_C_API_denial_probe_run==43760051406 and
  $n.exact_source_Git_blobs_verified_by_prior_producer==10 and
  ($n.NSS_source_guard_and_build_manifest_rows|length)==2 and
  ([ $n.NSS_source_guard_and_build_manifest_rows[].candidate_provider ]|sort)==
    ["libfreeblpriv3.so","libsoftokn3.so"] and
  $n.original_libnss3_actual_functions_resolved_from_same_archived_binary==true and
  $n.original_libsoftokn3_and_libfreeblpriv3_mapped_in_baseline==true and
  $n.baseline_original_NSS_NoDB_Init_passed==true and
  $n.baseline_original_PK11_GenerateRandom_passed==true and
  $n.baseline_generated_random_bytes_nonzero_and_never_archived==true and
  $n.tested_softoken_missing_loader_attempts==2 and
  $n.tested_freebl_missing_loader_attempts==3 and
  $n.tested_combined_mode_softoken_denials==2 and
  $n.tested_combined_mode_freebl_denials==0 and
  $n.softoken_denied_blocks_internal_NSS_initialization==true and
  $n.freebl_denied_blocks_internal_NSS_initialization==true and
  $n.combined_denial_freebl_not_attempted_due_to_earlier_softoken_failure==true and
  $n.original_NSS_failure_returned_without_probe_process_crash_or_timeout==true and
  $n.this_evidence_is_native_NSS_API_probe_not_real_webdriver_TLS_browser==true and
  $n.original_missing_provider_fallback_success_proven==false and
  $n.all_NSS_FIPS_PKCS11_TLS_and_security_paths_exercised==false and
  $n.direct_compiled_machine_callstack_proven==false and
  $n.complete_native_Rust_CXX_FFI_dlopen_dlsym_dependency_graph_proven==false and
  $n.user_browser_profiles_or_host_files_modified==false and
  $n.source_pruning_authorized==false and
  $n.security_current==false and
  $n.release_ready==false and $n.m3_sixth_gate_closed==false;
  "Original source-authenticated NSS API report or guarded failure was falsified") |
ensure(
  $b.schema_version==1 and
  $b.status=="actual_original_firefox160_webdriver_local_http_https_with_NSS_softoken_freebl_deny" and
  $b.original_official_firefox160_commit==$upstream and
  $b.original_vulpra_28_overlay_source_tree==$tree and
  $b.original_native_browser_archive_sha256==$archive and
  $b.original_native_package_producer_run==43138458940 and
  $b.test_harness_git_commit=="ed213726d0703f0e14071234f04de9e7bb3733f6" and
  $b.exact_original_packaged_browser_elf_used==true and
  $b.actual_local_http_fixture_healthy==true and
  $b.actual_local_https_fixture_healthy==true and
  $b.local_https_certificate_verified_untrusted_by_host==true and
  $b.browser_accept_insecure_certs_requested==false and
  $b.baseline_real_webdriver_local_http_js_and_strict_tls_succeeded==true and
  $b.softoken_missing_requested_and_genuinely_denied==true and
  $b.freebl_missing_requested_and_genuinely_denied==true and
  $b.both_names_denied_in_combined_mode_proven==false and
  $b.no_unexpected_provider_denial_names_seen==true and
  $b.all_user_profile_sentinels_preserved==true and
  $b.all_denied_modes_genuine_session_outcome_recorded==true and
  $b.real_TLS_handshake_with_trusted_server_verified==false and
  $b.all_NSS_PKCS11_FIPS_TLS_and_browser_security_paths_proven==false and
  $b.direct_machine_NSS_dlopen_callsite_or_complete_FFI_proven==false and
  $b.complete_native_dlopen_dlsym_Rust_CXX_dependency_gate_closed==false and
  $b.target_Arch_Hyprland_or_personal_profile_touched==false and
  $b.raw_private_geckodriver_logs_PIDs_paths_TLS_private_keys_archived==false and
  $b.source_pruning_authorized==false and
  $b.security_current==false and
  $b.release_ready==false and $b.m3_sixth_gate_closed==false and
  ($b.modes|length)==4 and
  ($b.modes|map(.mode))==["baseline","softoken_missing","freebl_missing","both_targeted"] and
  ($b.modes|map(.denial_group))==["none","nss_softoken","nss_freebl","nss_both"] and
  all($b.modes[];
    .driver_ready==true and
    .browser_private_profile_sentinel_preserved==true and
    .unexpected_nss_denial_log_lines==0 and
    .raw_nss_loader_logs_geckodriver_errors_or_profiles_archived==false) and
  ($b.modes[0]|
    .session_created==true and
    .actual_packaged_firefox_browser_reported==true and
    .browser_accept_insecure_certs==false and
    .startup_outcome=="session_created" and
    .http_localhost_navigation_verified==true and
    .http_localhost_javascript_verified==true and
    .https_localhost_outcome=="strict_certificate_rejection" and
    .https_localhost_webdriver_error_class=="insecure certificate" and
    .actual_denied_softoken_requests==0 and
    .actual_denied_freebl_requests==0 and
    .attached_native_browser_witness_count==0) and
  ($b.modes[1]|
    .session_created==false and
    .startup_outcome=="webdriver_session_rejected" and
    .session_error_class=="session not created" and
    .http_localhost_navigation_verified==false and
    .http_localhost_javascript_verified==false and
    .https_localhost_outcome=="not_attempted" and
    .actual_denied_softoken_requests==2 and
    .actual_denied_freebl_requests==0 and
    .attached_native_browser_witness_count==2) and
  ($b.modes[2]|
    .session_created==false and
    .startup_outcome=="webdriver_session_rejected" and
    .session_error_class=="session not created" and
    .http_localhost_navigation_verified==false and
    .http_localhost_javascript_verified==false and
    .https_localhost_outcome=="not_attempted" and
    .actual_denied_softoken_requests==0 and
    .actual_denied_freebl_requests==3 and
    .attached_native_browser_witness_count==2) and
  ($b.modes[3]|
    .session_created==false and
    .startup_outcome=="webdriver_session_rejected" and
    .session_error_class=="session not created" and
    .http_localhost_navigation_verified==false and
    .http_localhost_javascript_verified==false and
    .https_localhost_outcome=="not_attempted" and
    .actual_denied_softoken_requests==2 and
    .actual_denied_freebl_requests==0 and
    .attached_native_browser_witness_count==2);
  "Actual original Firefox160 browser NSS session/HTTPS/denial evidence or its scope was falsified") |
{
  schema_version:1,
  status:"firefox160_original_native_NSS_API_and_real_browser_webdriver_failure_source_crosschecked",
  exact_official_mozilla_firefox160_source_commit:$upstream,
  original_vulpra_28_overlay_source_tree:$tree,
  original_unmodified_compiled_native_archive_sha256:$archive,
  original_compiled_native_browser_producer:43138458940,
  original_NSS_10_blob_source_owner_run:43745057569,
  independent_real_NSS_API_source_native_crosswalk_run:43760419551,
  actual_original_Firefox160_webdriver_NSS_denial_and_local_TLS_run:43761905154,
  source_verified_original_NSS_library_names:["libsoftokn3.so","libfreeblpriv3.so"],
  previous_native_NSS_api_softoken_failure_loader_denials:2,
  previous_native_NSS_api_freebl_failure_loader_denials:3,
  browser_baseline_WebDriver_session_created:true,
  browser_baseline_actual_local_HTTP_navigation_and_javascript:true,
  browser_baseline_strict_self_signed_local_HTTPS_certificate_rejected:true,
  browser_softoken_denied_actual_attempts:2,
  browser_softoken_denial_rejected_WebDriver_session:true,
  browser_freebl_denied_actual_attempts:3,
  browser_freebl_denial_rejected_WebDriver_session:true,
  combined_mode_softoken_loader_attempts:2,
  combined_mode_freebl_loader_attempts:0,
  combined_mode_rejected_WebDriver_session:true,
  all_actual_NSS_denied_browser_cases_failed_before_local_HTTP_or_HTTPS_navigation:true,
  all_actual_browser_profile_sentinels_untouched:true,
  browser_tested_trusted_local_certificate_TLS_handshake:false,
  browser_tested_actual_public_network_TLS:false,
  full_NSS_FIPS_PKCS11_TSL_and_all_optional_crypto_fallbacks_tested:false,
  original_native_source_or_system_libraries_removed:false,
  user_Arch_Hyprland_GPU_or_personal_profile_touched:false,
  raw_library_paths_keys_PIDs_or_GeckoDriver_errors_archived:false,
  direct_compiled_machine_dlopen_caller_attributed:false,
  complete_Rust_CXX_FFI_dlopen_dlsym_closure_proven:false,
  source_pruning_authorized:false,
  security_current:false,
  release_ready:false,
  m3_sixth_gate_closed:false
}
