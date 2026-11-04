#!/usr/bin/env bash
# Tests metadata validation only: no native browser or certificate is run.
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
check="$root/ci/m3-current-local-tls-native-evidence.jq"
tmp="$(mktemp -d -t vulpra-tls-evidence.XXXXXXXX)"
trap 'rm -rf -- "$tmp"' EXIT
sha='1edfb3d5223e26fc15ecd703979cd2c8efb8d4f5'
run=41853893418
pkg='vulpra-local-m3-native-link-ci.tar.xz'
digest="$(printf 'a%.0s' {1..64})"
jq -n --arg sha "$sha" --argjson run "$run" --arg hash "$digest" '
{
 schema_version:1,source_commit:$sha,workflow_run_id:$run,
 package:{package_sha256:$hash,package_compressed_bytes:87149884},
 runtime_passed_after_link_audit:true,
 runtime_gates:["Wayland private Weston","localhost JS navigation",
                "isolated profile and WebExtension","Nimbus check"],
 source_removal_authorized:false,compressed_package_savings_claimed:null,
 linker_full_map_recorded:false
}' > "$tmp/link.json"
jq -n --arg hash "$digest" --arg pkg "$pkg" '
{schema_version:1,package:$pkg,sha256:$hash,result:"pass",profile_isolation:true}
' > "$tmp/local.json"
jq -n --arg pkg "$pkg" '
{
 schema_version:1,package:$pkg,status:"pass",
 javascript_navigation:{verified:true},
 webextension:{temporary_unsigned_install:true,uninstall:true},
 nimbus:{store_ready:true,api_ready:true},
 security:{
   original_firefox_profile_preserved:true,temporary_home:true,
   local_untrusted_tls_denial:{
     verified:true,local_self_signed_only:true,fixture_health_passed:true,
     ordinary_tls_client_rejected:true,webdriver_accept_insecure_certs:false,
     webdriver_error:"insecure certificate",certificate_store_modified:false,
     safebrowsing_tested:false,sandbox_denial_tested:false,
     no_external_egress_proven:false
   }
 }
}' > "$tmp/webextension.json"
run_check() {
  jq -n --arg source_sha "$sha" --argjson run_id "$run" \
     --slurpfile link "$tmp/link.json" \
     --slurpfile local "$tmp/local.json" \
     --slurpfile webextension "$tmp/webextension.json" -f "$check"
}
run_check > "$tmp/pass.json"
jq -e '.status=="bounded_current_native_local_certificate_rejection_crosscheck" and
       .verified_current_native_loopback_self_signed_tls_denial==true and
       .safe_browsing_proven==false and .sandbox_process_denial_proven==false and
       .m3_sixth_gate_closed==false and .additional_source_pruning_authorized==false' \
       "$tmp/pass.json" >/dev/null

count=0
while IFS='|' read -r target mutation; do
  test -n "$target" || continue
  jq "$mutation" "$tmp/$target.json" > "$tmp/tampered.json"
  cp "$tmp/$target.json" "$tmp/backup.json"
  cp "$tmp/tampered.json" "$tmp/$target.json"
  if run_check >/dev/null 2>"$tmp/error"; then
    echo "FAIL: forged native TLS evidence accepted: $target $mutation" >&2
    exit 1
  fi
  mv "$tmp/backup.json" "$tmp/$target.json"
  count=$((count+1))
done <<'MUTATIONS'
link|.source_commit="0000000000000000000000000000000000000000"
link|.workflow_run_id+=1
link|.package.package_sha256="0000000000000000000000000000000000000000000000000000000000000000"
link|.package.package_compressed_bytes=0
link|.runtime_passed_after_link_audit=false
link|.runtime_gates=[]
link|.source_removal_authorized=true
link|.linker_full_map_recorded=true
link|.compressed_package_savings_claimed=0
local|.sha256="0000000000000000000000000000000000000000000000000000000000000000"
local|.profile_isolation=false
local|.package="other-browser.tar.xz"
webextension|del(.security.local_untrusted_tls_denial)
webextension|.security.local_untrusted_tls_denial.verified=false
webextension|.security.local_untrusted_tls_denial.fixture_health_passed=false
webextension|.security.local_untrusted_tls_denial.ordinary_tls_client_rejected=false
webextension|.security.local_untrusted_tls_denial.webdriver_accept_insecure_certs=true
webextension|.security.local_untrusted_tls_denial.webdriver_error="timeout"
webextension|.security.local_untrusted_tls_denial.certificate_store_modified=true
webextension|.security.local_untrusted_tls_denial.safebrowsing_tested=true
webextension|.security.local_untrusted_tls_denial.sandbox_denial_tested=true
webextension|.security.local_untrusted_tls_denial.no_external_egress_proven=true
webextension|.security.local_untrusted_tls_denial.extra_field=true
webextension|.security.original_firefox_profile_preserved=false
webextension|.nimbus.api_ready=false
webextension|.webextension.uninstall=false
MUTATIONS
test "$count" -eq 26
echo "PASS: synthetic source-and-package TLS contract; 26/26 forged cross-report claims rejected; not a native browser test"
