# Independently verify exact upstream NSS loader/guard provenance against
# genuinely executed NSS_NoDB_Init/PK11_GenerateRandom with original compiled
# NSS DSOs under named provider denials. This is NOT a Firefox TLS browser test.
def require($predicate;$why): if $predicate then . else error($why) end;
require(($source|length)==1 and ($runtime|length)==1;
  "Must provide one original NSS source owner and one real native API report") |
($source[0]) as $s | ($runtime[0]) as $r |
require($s.schema_version==1 and
    $s.status=="firefox160_exact_upstream_nss_ffvpx_source_candidates_crosschecked_with_actual_loader_requests" and
    $s.official_release_commit==$upstream and
    $s.assembled_candidate_source_tree==$tree and
    $s.original_native_archive_sha256==$archive and
    $s.original_native_runtime_observation_run==43743231236 and
    $s.original_exact_source_verified_blob_count==10 and
    $s.original_source_files_nonoverlaid_by_vulpra==true and
    ($s.source_candidate_rows|length)==4 and
    $s.source_routes_crosschecked_with_actual_native_loader_requests==4 and
    ([ $s.source_candidate_rows[]|select(.id=="nss_softoken" or .id=="nss_freebl")|
       {id,candidate_provider,owner_path,linked_build_manifest} ]|sort_by(.id))==
    [
      {"id":"nss_freebl","candidate_provider":"libfreeblpriv3.so",
       "owner_path":"security/nss/lib/freebl/loader.c",
       "linked_build_manifest":"security/nss/lib/freebl/manifest.mn"},
      {"id":"nss_softoken","candidate_provider":"libsoftokn3.so",
       "owner_path":"security/nss/lib/pk11wrap/pk11load.c",
       "linked_build_manifest":"security/nss/lib/softoken/manifest.mn"}
    ] and
    all($s.source_candidate_rows[];
      .source_load_failure_guard_present==true and
      .observed_native_glibc_request_direct_callsite_attributed==false and
      .actual_glibc_initialized_dynamic_request_seen_from_libnspr4==true and
      .compiled_direct_loader_caller_function_proven==false and
      .fallback_exercised==false) and
    $s.exact_runtime_loader_caller_source_function_verified==false and
    $s.exact_machine_dlopen_symbol_arguments_verified==false and
    $s.all_conditional_ffi_and_protected_fallbacks_exercised==false and
    $s.source_pruning_authorized==false and $s.security_current==false and
    $s.release_ready==false and $s.m3_sixth_gate_closed==false;
    "Forged original Firefox160 NSS/FFVPX release, guard ownership or false source completion") |
require($r.schema_version==1 and
    $r.status=="original_firefox160_real_NSS_NoDB_Init_PK11_random_missing_softoken_freebl" and
    $r.original_mozilla_firefox160_commit==$upstream and
    $r.original_vulpra_28_overlay_tree==$tree and
    $r.original_compiled_archive_sha256==$archive and
    $r.original_native_producer_run==43138458940 and
    $r.current_probe_harness_git_commit=="68294a9467ee09a65819b831f3fea22fbb854ae1" and
    $r.genuine_original_packaged_nss3_API_invoked==true and
    $r.original_random_bytes_never_recorded==true and
    $r.baseline_original_NSS_initialized_and_generated_random==true and
    $r.original_softoken_denial_actually_observed==true and
    $r.original_freebl_denial_actually_observed==true and
    $r.combined_mode_both_named_denials_actually_observed==false and
    $r.all_missing_provider_tests_completed_without_process_crash_or_timeout==true and
    $r.actual_real_firefox_browser_or_TLS_flow_tested==false and
    $r.all_NSS_PKCS11_FIPS_crypto_security_paths_tested==false and
    $r.original_NSS_direct_dlopen_machine_callstacks_proven==false and
    $r.complete_Rust_CXX_FFI_dlopen_dlsym_graph_closed==false and
    $r.workstation_browser_profile_or_arch_hyprland_touched==false and
    $r.source_pruning_authorized==false and $r.security_current==false and
    $r.release_ready==false and $r.m3_sixth_gate_closed==false and
    ($r.modes|length)==4 and
    ($r.modes|map(.mode))==["baseline","softoken_missing","freebl_missing","both_missing"] and
    ($r.modes|map(.denial_group))==["none","nss_softoken","nss_freebl","nss_both"] and
    all($r.modes[];
       .disposable_probe_exit_status==0 and
       .exact_original_NSS_API_probe_output_parsed==true and
       .original_libnss3_dlopen_succeeded==true and
       .original_NSS_three_symbols_resolved_from_exact_package==true and
       .raw_library_paths_dlopen_PIDs_or_random_bytes_archived==false) and
    ($r.modes[0].NSS_NoDB_Init_rc)==0 and
    ($r.modes[0].PK11_GenerateRandom_rc)==0 and
    ($r.modes[0].generated_random_bytes_nonzero)==true and
    ($r.modes[0].NSS_Shutdown_rc)==0 and
    ($r.modes[0].original_packaged_libsoftokn3_ELF_mapped)==true and
    ($r.modes[0].original_packaged_libfreeblpriv3_ELF_mapped)==true and
    ($r.modes[0].actual_denied_requests_total)==0 and
    ($r.modes[0].shim_attachment_fixture_witness_count)==0 and
    ($r.modes[1].NSS_NoDB_Init_rc)==-1 and
    ($r.modes[1].PK11_GenerateRandom_rc)==-2 and
    ($r.modes[1].NSS_Shutdown_rc)==-2 and
    ($r.modes[1].generated_random_bytes_nonzero)==false and
    ($r.modes[1].original_packaged_libsoftokn3_ELF_mapped)==false and
    ($r.modes[1].original_packaged_libfreeblpriv3_ELF_mapped)==false and
    ($r.modes[1].actual_denied_libsoftokn3_loader_requests)==2 and
    ($r.modes[1].actual_denied_libfreeblpriv3_loader_requests)==0 and
    ($r.modes[1].actual_denied_requests_total)==2 and
    ($r.modes[1].shim_attachment_fixture_witness_count)==1 and
    ($r.modes[2].NSS_NoDB_Init_rc)==-1 and
    ($r.modes[2].PK11_GenerateRandom_rc)==-2 and
    ($r.modes[2].NSS_Shutdown_rc)==-2 and
    ($r.modes[2].original_packaged_libsoftokn3_ELF_mapped)==true and
    ($r.modes[2].original_packaged_libfreeblpriv3_ELF_mapped)==false and
    ($r.modes[2].actual_denied_libsoftokn3_loader_requests)==0 and
    ($r.modes[2].actual_denied_libfreeblpriv3_loader_requests)==3 and
    ($r.modes[2].actual_denied_requests_total)==3 and
    ($r.modes[2].shim_attachment_fixture_witness_count)==1 and
    ($r.modes[3].NSS_NoDB_Init_rc)==-1 and
    ($r.modes[3].PK11_GenerateRandom_rc)==-2 and
    ($r.modes[3].NSS_Shutdown_rc)==-2 and
    ($r.modes[3].original_packaged_libsoftokn3_ELF_mapped)==false and
    ($r.modes[3].original_packaged_libfreeblpriv3_ELF_mapped)==false and
    ($r.modes[3].actual_denied_libsoftokn3_loader_requests)==2 and
    ($r.modes[3].actual_denied_libfreeblpriv3_loader_requests)==0 and
    ($r.modes[3].actual_denied_requests_total)==2 and
    ($r.modes[3].shim_attachment_fixture_witness_count)==1;
  "Forged authentic original Firefox160 NSS API provider failures, exact native ELF mapping, count or claim") |
{
  schema_version:1,
  status:"firefox160_original_nss_softoken_freebl_guards_real_C_API_failure_source_verified",
  exact_official_firefox160_source_commit:$upstream,
  original_vulpra_28_overlay_source_tree:$tree,
  original_compiled_native_archive_sha256:$archive,
  original_native_package_build_run:43138458940,
  exact_10_source_NSS_FFVPX_owner_producer_run:43745057569,
  original_real_NSS_C_API_denial_probe_run:43760051406,
  exact_source_Git_blobs_verified_by_prior_producer:10,
  NSS_source_guard_and_build_manifest_rows:
    [$s.source_candidate_rows[]|select(.id=="nss_softoken" or .id=="nss_freebl")|
       {id,candidate_provider,owner_path,linked_build_manifest}],
  original_libnss3_actual_functions_resolved_from_same_archived_binary:true,
  original_libsoftokn3_and_libfreeblpriv3_mapped_in_baseline:true,
  baseline_original_NSS_NoDB_Init_passed:true,
  baseline_original_PK11_GenerateRandom_passed:true,
  baseline_generated_random_bytes_nonzero_and_never_archived:true,
  tested_freebl_missing_loader_attempts:3,
  tested_softoken_missing_loader_attempts:2,
  tested_combined_mode_softoken_denials:2,
  tested_combined_mode_freebl_denials:0,
  softoken_denied_blocks_internal_NSS_initialization:true,
  freebl_denied_blocks_internal_NSS_initialization:true,
  combined_denial_freebl_not_attempted_due_to_earlier_softoken_failure:true,
  original_NSS_failure_returned_without_probe_process_crash_or_timeout:true,
  this_evidence_is_native_NSS_API_probe_not_real_webdriver_TLS_browser:true,
  original_missing_provider_fallback_success_proven:false,
  all_NSS_FIPS_PKCS11_TLS_and_security_paths_exercised:false,
  actual_target_Arch_Hyprland_verified:false,
  direct_compiled_machine_callstack_proven:false,
  complete_native_Rust_CXX_FFI_dlopen_dlsym_dependency_graph_proven:false,
  user_browser_profiles_or_host_files_modified:false,
  source_pruning_authorized:false,
  security_current:false,
  release_ready:false,
  m3_sixth_gate_closed:false
}
