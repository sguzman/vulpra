# Independent bounded cross-report reconciliation for *current native* TLS denial.
# Called with externally verified workflow SHA/run and the original downloaded
# native link, localhost screenshot and WebDriver reports. Synthetic fixtures
# only test this verifier; they never prove real browser behavior themselves.
def insist($ok; $error): if $ok then true else error($error) end;
def sha40: type == "string" and test("^[0-9a-f]{40}$");
def sha64: type == "string" and test("^[0-9a-f]{64}$");
($link[0]) as $l |
($local[0]) as $p |
($webextension[0]) as $w |
($w.security.local_untrusted_tls_denial) as $t |
[
  insist(($source_sha|sha40) and (($run_id|type)=="number" and $run_id>0);
         "Expected trusted source and run identity"),
  insist($l.schema_version==1 and $p.schema_version==1 and
         $w.schema_version==1; "Incompatible native runtime report schema"),
  insist($l.source_commit==$source_sha and
         $l.workflow_run_id==$run_id; "Linked binary not authenticated to trusted run"),
  insist(($l.package.package_sha256|sha64) and
         $l.package.package_sha256==$p.sha256 and
         $l.package.package_compressed_bytes>10000000;
         "Local browser package hash/size differs from linked source"),
  insist($l.runtime_passed_after_link_audit==true and
         $l.runtime_gates==["Wayland private Weston","localhost JS navigation",
                            "isolated profile and WebExtension","Nimbus check"];
         "Native workflow runtime gates missing"),
  insist($p.result=="pass" and
         $p.package==$w.package and
         $w.package=="vulpra-local-m3-native-link-ci.tar.xz" and
         $p.profile_isolation==true and
         $w.status=="pass" and
         $w.security.original_firefox_profile_preserved==true and
         $w.security.temporary_home==true;
         "WebDriver and native localhost reports not from same isolated package"),
  insist($w.javascript_navigation.verified==true and
         $w.webextension.temporary_unsigned_install==true and
         $w.webextension.uninstall==true and
         $w.nimbus.store_ready==true and $w.nimbus.api_ready==true;
         "Browser navigation/extension/Nimbus context invalid"),
  insist(($t|type)=="object" and
         ($t|keys|sort)==([
           "certificate_store_modified","fixture_health_passed",
           "local_self_signed_only","no_external_egress_proven",
           "ordinary_tls_client_rejected","safebrowsing_tested",
           "sandbox_denial_tested","verified",
           "webdriver_accept_insecure_certs","webdriver_error"
         ]|sort);
         "Absent/unknown TLS denial evidence fields"),
  insist($t.verified==true and $t.local_self_signed_only==true and
         $t.fixture_health_passed==true and
         $t.ordinary_tls_client_rejected==true and
         $t.webdriver_accept_insecure_certs==false and
         $t.webdriver_error=="insecure certificate" and
         $t.certificate_store_modified==false;
         "The actual packaged browser did not assert strict loopback TLS rejection"),
  insist($t.safebrowsing_tested==false and
         $t.sandbox_denial_tested==false and
         $t.no_external_egress_proven==false;
         "TLS test falsely claims Safe Browsing, sandbox or egress coverage"),
  insist($l.source_removal_authorized==false and
         $l.compressed_package_savings_claimed==null and
         $l.linker_full_map_recorded==false;
         "TLS evidence falsely grants source deletion or complete native link map")
] | all as $ok |
{
 schema_version:1,
 status:"bounded_current_native_local_certificate_rejection_crosscheck",
 authenticated_source_sha:$source_sha,
 authenticated_workflow_run_id:$run_id,
 source_linked_packaged_archive_sha256:$l.package.package_sha256,
 verified_current_native_loopback_self_signed_tls_denial:$ok,
 webdriver_insecure_cert_overrides_enabled:false,
 certificate_store_modified:false,
 safe_browsing_proven:false,
 sandbox_process_denial_proven:false,
 no_background_network_egress_proven:false,
 all_conditional_ffi_dlopen_proven:false,
 target_endeavouros_hyprland_tested:false,
 m3_sixth_gate_closed:false,
 additional_source_pruning_authorized:false,
 marginal_native_savings_bytes:null
}
