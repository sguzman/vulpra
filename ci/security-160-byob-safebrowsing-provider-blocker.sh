#!/usr/bin/env bash
# Real native BYOB Firefox160 classifier/provider negative acceptance:
# PASS means the expected missing-provider BLOCKER was observed, not safety.
set -euo pipefail
umask 077

fail() {
  echo 'FAIL: BYOB real-browser Safe Browsing blocker contract rejected evidence' >&2
  exit 1
}

validate() {
  local report="$1" sha="$2"
  [[ -s "$report" && "$sha" =~ ^[0-9a-f]{64}$ ]] || fail
  jq -e --arg sha "$sha" '
    .schema_version == 1 and
    .kind == "firefox160_native_safebrowsing_effective_configuration_audit" and
    .status == "configuration_blocked" and
    .package_sha256 == $sha and
    .native_firefox160_webdriver_and_disposable_profile_verified == true and
    .original_firefox_profile_preserved == true and
    .strict_webdriver_tls_configuration == true and
    .web_driver_recommended_security_disabling_prefs_off == true and
    .configuration_readiness_gate_passed == false and
    (.blocking_reasons | sort) == ([
      "google5_credential_missing_or_unaccepted",
      "google5_effective_https_update_endpoint_unavailable",
      "google5_effective_https_hash_lookup_unavailable"
    ] | sort) and
    .observed.runtime_prefs.phishing == true and
    .observed.runtime_prefs.malware == true and
    .observed.runtime_prefs.downloads == true and
    .observed.runtime_prefs.update == true and
    .observed.runtime_prefs.google5 == true and
    .observed.automation_recommended_prefs_disabled == true and
    .observed.default_user_pref_override_count == 0 and
    .observed.expected_table_presence.phishing == true and
    .observed.expected_table_presence.malware == true and
    .observed.expected_table_presence.download_block == true and
    .observed.url_classifier_db_service_available == true and
    .observed.url_classifier_list_manager_service_available == true and
    .observed.safe_browsing_module_imported == true and
    .observed.safe_browsing_module_initialized == true and
    .observed.google5_credential_check_accepted == false and
    .observed.google5_https_update_endpoint_present == false and
    .observed.google5_https_hash_lookup_endpoint_present == false and
    .observed.runtime_features.phishing.enabled == true and
    .observed.runtime_features.phishing.update == true and
    .observed.runtime_features.phishing.registered_table_count > 0 and
    .observed.runtime_features.malware.enabled == true and
    .observed.runtime_features.malware.update == true and
    .observed.runtime_features.malware.registered_table_count > 0 and
    .observed.runtime_features.downloads.enabled == true and
    .observed.runtime_features.downloads.update == true and
    .observed.runtime_features.downloads.registered_table_count > 0 and
    .observed.secret_values_or_endpoint_urls_returned == false and
    .observed.no_malicious_url_or_threat_update_requested_by_probe == true and
    .actual_threat_list_download_verified == false and
    .actual_malicious_navigation_denied_verified == false and
    .network_protection_coverage_certified == false and
    .security_current == false and .release_ready == false
  ' "$report" >/dev/null || fail
}

self_test() {
  local temp sha count
  temp=$(mktemp -d)
  sha='1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
  count=0
  jq -n --arg sha "$sha" '{
    schema_version:1,
    kind:"firefox160_native_safebrowsing_effective_configuration_audit",
    status:"configuration_blocked",package_sha256:$sha,
    native_firefox160_webdriver_and_disposable_profile_verified:true,
    original_firefox_profile_preserved:true,
    strict_webdriver_tls_configuration:true,
    web_driver_recommended_security_disabling_prefs_off:true,
    configuration_readiness_gate_passed:false,
    blocking_reasons:[
      "google5_credential_missing_or_unaccepted",
      "google5_effective_https_update_endpoint_unavailable",
      "google5_effective_https_hash_lookup_unavailable"],
    observed:{
      runtime_prefs:{phishing:true,malware:true,downloads:true,update:true,google5:true},
      automation_recommended_prefs_disabled:true,
      default_user_pref_override_count:0,
      expected_table_presence:{phishing:true,malware:true,download_block:true},
      url_classifier_db_service_available:true,
      url_classifier_list_manager_service_available:true,
      safe_browsing_module_imported:true,safe_browsing_module_initialized:true,
      google5_credential_check_accepted:false,
      google5_https_update_endpoint_present:false,
      google5_https_hash_lookup_endpoint_present:false,
      runtime_features:{
        phishing:{enabled:true,update:true,registered_table_count:1},
        malware:{enabled:true,update:true,registered_table_count:1},
        downloads:{enabled:true,update:true,registered_table_count:1}},
      secret_values_or_endpoint_urls_returned:false,
      no_malicious_url_or_threat_update_requested_by_probe:true},
    actual_threat_list_download_verified:false,
    actual_malicious_navigation_denied_verified:false,
    network_protection_coverage_certified:false,
    security_current:false,release_ready:false
  }' > "$temp/positive"
  validate "$temp/positive" "$sha"
  negative() {
    jq "$1" "$temp/positive" > "$temp/negative"
    if (validate "$temp/negative" "$sha") >/dev/null 2>&1; then
      rm -rf -- "$temp"
      fail
    fi
    count=$((count+1))
  }
  negative '.status="configuration_ready"'
  negative '.configuration_readiness_gate_passed=true'
  negative '.blocking_reasons=[]'
  negative '.blocking_reasons+=["missing_phishing_classification_table"]'
  negative '.observed.runtime_prefs.phishing=false'
  negative '.observed.runtime_features.downloads.enabled=false'
  negative '.observed.google5_credential_check_accepted=true'
  negative '.observed.google5_https_update_endpoint_present=true'
  negative '.observed.default_user_pref_override_count=1'
  negative '.observed.secret_values_or_endpoint_urls_returned=true'
  negative '.original_firefox_profile_preserved=false'
  negative '.release_ready=true'
  rm -rf -- "$temp"
  [[ "$count" -eq 12 ]] || fail
  echo 'PASS: expected provider-blocker evidence validator and 12 rejected fixtures'
}

run_native() {
  local repo="$1" archive sha report proof
  [[ "$(ip -j link show | jq -r '[.[].ifname] | join(",")')" == lo ]] || fail
  [[ -z "$(ip -4 route show)" && -z "$(ip -6 route show)" ]] || fail
  archive="$repo/.git/vulpra-native-build/packages/vulpra-local-firefox160-bitwarden-qa.tar.xz"
  [[ -s "$archive" && -s "$archive.sha256" ]] || fail
  (cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256" >/dev/null) || fail
  sha=$(sha256sum "$archive" | cut -d ' ' -f1)
  report="$repo/.git/vulpra-native-build/byob-safebrowsing-blocker-runtime.json"
  proof="$repo/.git/vulpra-native-build/byob-safebrowsing-blocker-proof.json"
  [[ ! -e "$report" && ! -e "$proof" ]] || fail
  # Existing real-browser readiness code raises AFTER writing the report
  # when an actual provider credential is missing. Unexpected errors cannot
  # pass without a correctly signed and structured native report.
  if python3 "$repo/ci/security-160-safebrowsing-readiness.py" "$repo" "$report"; then
    echo 'FAIL: provider unexpectedly ready; review separately before release' >&2
    exit 1
  fi
  validate "$report" "$sha"
  jq '{
    schema_version:1,status:"expected_provider_blocker_observed",
    exact_byob_native_browser:true,no_external_network_routes:true,
    local_phishing_malware_download_classifiers_intact:true,
    google_v5_provider_credential_accepted:false,
    public_release_security_gate_open:true,
    provider_backed_warning_verified:false,
    provider_use_authorization_obtained:false,
    browser_source_security_current:false,release_ready:false,
    package_sha256,blocking_reasons
  }' "$report" > "$proof"
  [[ -s "$proof" ]] || fail
  echo 'PASS: native BYOB local classifier intact; Safe Browsing provider BLOCKED'
}

[[ $# -ge 1 ]] || fail
case "$1" in
  --self-test) [[ $# -eq 1 ]] || fail; self_test ;;
  --validate) [[ $# -eq 3 ]] || fail; validate "$2" "$3" ;;
  --run) [[ $# -eq 2 ]] || fail; run_native "$2" ;;
  *) fail ;;
esac
