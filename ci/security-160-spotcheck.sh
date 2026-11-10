#!/usr/bin/env bash
# Immutable, bounded Firefox 160 high-impact patch-presence spot-check.
# Source integrity only: not a native browser build or a security-readiness claim.
set -euo pipefail
cd "$(dirname -- "$0")/.."
if (( $# == 0 )); then
  manifest="docs/vulpra/SECURITY-160-INITIAL-PATCH-GAPS-20261110.json"
elif (( $# == 1 )); then
  manifest="$1"
else
  echo 'Usage: security-160-spotcheck.sh [manifest]' >&2
  exit 2
fi
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
test -s "$manifest" || fail "missing manifest"
jq -e '
  .schema_version == 1 and
  .kind == "vulpra_firefox_160_security_patch_presence_bounded_spotcheck" and
  .source_main_commit == "83d4ef76263b8d67ade0f70c2083109b6f8498bf" and
  .source_original_rebuilt_main_commit == "2006922502b6d27a7d89e56662530726441d8b45" and
  .source_beta_tag == "FIREFOX_159_0b5_RELEASE" and
  .source_beta_sha == "34ac0671eb25f31f8c56ace36e1c413dd471eb8d" and
  .upstream_release_tag == "FIREFOX_160_0_RELEASE" and
  .upstream_release_sha == "2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .advisory == "MFSA 2026-125" and
  .advisory_url == "https://www.mozilla.org/en-US/security/advisories/mfsa2026-125/" and
  .announced == "2026-11-10" and
  (.patch_files | type == "array" and length == 6) and
  ([.patch_files[].path] | unique | length == 6) and
  ([.patch_files[].cve] | unique | sort) ==
    ["CVE-2026-124853","CVE-2026-124854","CVE-2026-124856","CVE-2026-124902"] and
  all(.patch_files[];
    (.path | type == "string" and length > 0) and
    (.mozilla_bug | type == "number") and
    (.upstream_landed_fix_commit | test("^[0-9a-f]{40}$")) and
    (.vulpra_main_git_blob | test("^[0-9a-f]{40}$")) and
    (.firefox_159_beta_git_blob | test("^[0-9a-f]{40}$")) and
    (.landed_fix_result_git_blob | test("^[0-9a-f]{40}$")) and
    (.firefox_160_release_git_blob | test("^[0-9a-f]{40}$")) and
    .source_file_pre_fix_confirmed == true and
    .vulpra_main_git_blob == .firefox_159_beta_git_blob and
    .vulpra_main_git_blob != .firefox_160_release_git_blob and
    .vulpra_main_git_blob != .landed_fix_result_git_blob and
    .release_blob_is_landed_fix_result ==
      (.landed_fix_result_git_blob == .firefox_160_release_git_blob) and
    .classification ==
      (if .release_blob_is_landed_fix_result then
         "exact_fixed_file_in_release_pre_fix_in_vulpra"
       else "release_has_later_edits_pre_fix_in_vulpra" end)) and
  .scope.cves_checked == 4 and
  .scope.paths_checked == 6 and
  .scope.old_beta_identical_paths == 6 and
  .scope.exact_landed_result_in_160_paths == 5 and
  .scope.release_later_modified_paths == 1 and
  .scope.all_mfsa2026_125_audited == false and
  .scope.security_current == false and
  .scope.source_migrated_to_160 == false and
  .scope.original_user_binary_modified == false and
  .scope.full_browser_build_or_runtime_this_check == false and
  .scope.release_ready == false
' "$manifest" >/dev/null || fail "source/provenance/scope contract failed"
count=0
exact_release=0
while IFS=$'\t' read -r path cve bug commit beta fix release; do
  case "$path" in
    gfx/thebes/SharedFontList.cpp) expected=$'CVE-2026-124853\t2058035\t94db1bf32f349f160269b2857a75cc883c0f64fd\t1f3bd63aa5fcb4c168ca43944c8a4fa68233bd4b\t0b1c70178c1e7a4de7b81f5539156feb221683ab\t0b1c70178c1e7a4de7b81f5539156feb221683ab' ;;
    gfx/thebes/SharedFontList.h) expected=$'CVE-2026-124853\t2058035\t94db1bf32f349f160269b2857a75cc883c0f64fd\t5ce0885c7033381f1044ee65169deff9b63b79d3\t111c61f8decd2218e7ebaaba8c888a1f1c062d63\t111c61f8decd2218e7ebaaba8c888a1f1c062d63' ;;
    dom/ipc/ProcessIsolation.cpp) expected=$'CVE-2026-124854\t2060230\t0caf08d01122563fbe9ca617c40b423dc8d0bd2a\ta1b725eafb33226d8a1b5735cea4750db90cfe1b\t4e02df9672c56fa56ce2ad250908657c9b37ec93\t4e02df9672c56fa56ce2ad250908657c9b37ec93' ;;
    netwerk/protocol/http/nsHttpChannel.cpp) expected=$'CVE-2026-124856\t2072437\t5bc7f7a016a0db55d9f8380ae5b2e0a8d90677bc\td17a57fd8b96d618a1452c95d4d5e27bc0cd88db\tb347736774390d8d07aa0ae368d2363da7744eb9\t050d925fe3a49705d64e253190d34ff58913a06f' ;;
    netwerk/protocol/http/nsHttpChannel.h) expected=$'CVE-2026-124856\t2072437\t5bc7f7a016a0db55d9f8380ae5b2e0a8d90677bc\tcb5da1a630eb49624078262917d34146c6367444\t0a6c3a49ae7c36bbedb502c1515b64093cff0135\t0a6c3a49ae7c36bbedb502c1515b64093cff0135' ;;
    dom/media/FileBlockCache.cpp) expected=$'CVE-2026-124902\t2083629\te696700fc1a892d1cc9f3a694cf8d34ca720c5f9\t13f9faddb3b6dc0d568cf4ed4c0777df5277079f\t73c3f6833916464fab8137908fc0108a8eeeb464\t73c3f6833916464fab8137908fc0108a8eeeb464' ;;
    *) fail "unrecognized path: $path" ;;
  esac
  got="$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$cve" "$bug" "$commit" "$beta" "$fix" "$release")"
  test "$got" = "$expected" || fail "untrusted advisory or upstream SHA claim: $path"
  test -f "$path" || fail "missing checked source: $path"
  actual="$(git hash-object -- "$path")" || fail "could not hash $path"
  test "$actual" = "$beta" || fail "current source hash changed: $path"
  if test "$fix" = "$release"; then exact_release=$((exact_release+1)); fi
  count=$((count+1))
done < <(jq -er '.patch_files[] | [.path,.cve,(.mozilla_bug|tostring),.upstream_landed_fix_commit,.vulpra_main_git_blob,.landed_fix_result_git_blob,.firefox_160_release_git_blob] | @tsv' "$manifest")
test "$count" -eq 6 && test "$exact_release" -eq 5 || fail "incomplete verified source inventory"
echo "PASS: 6/6 source paths retain exact frozen Firefox 159 beta blobs rather than verified Firefox 160 patches"
echo "PASS: 5 upstream 160 blobs equal landed fix; 1 was modified again after landed fix"
echo "LIMIT: selected source blobs only; not all advisory CVEs, exploit tests or release acceptance"
