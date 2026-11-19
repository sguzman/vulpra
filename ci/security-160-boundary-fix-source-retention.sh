#!/usr/bin/env bash
# Selected high-impact Firefox 160 boundary-CVE source blob retention audit.
# Only tests exact landed/release source blobs outside Vulpra's 28 overlays.
# DOES NOT establish entire CVE fix completeness or security-current release.
set -euo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if test "$#" -eq 2 && test "$1" = --self-test; then
  manifest="$2"
  mode=self-test
elif test "$#" -eq 5 && test "$1" = --verify; then
  manifest="$2"
  ledger="$3"
  source="$4"
  output="$5"
  mode=verify
else
  echo 'Usage: script --self-test MANIFEST or --verify MANIFEST CANDIDATE_LEDGER_DIR MATERIALIZED_PROOF OUTPUT_JSON' >&2
  exit 2
fi
test -s "$manifest" && test ! -L "$manifest" || fail 'missing or symlinked reviewed manifest'
jq -e '
  .schema_version == 1 and
  .kind == "firefox160_additional_boundary_cve_bounded_release_blob_spotcheck" and
  .official_source_repository == "mozilla-firefox/firefox" and
  .firefox160_release_commit == "2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .pinned_vulpra_candidate_tree == "42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .original_native_run_id == 43138458940 and
  (.records|type=="array" and length==5) and
  ([.records[].path]|unique|length)==5 and
  ([.records[].cve]|unique|sort)==
    ["CVE-2026-124855","CVE-2026-124859",
     "CVE-2026-124903","CVE-2026-124907"] and
  all(.records[];
    (.landed_commit|test("^[0-9a-f]{40}$")) and
    (.landed_blob|test("^[0-9a-f]{40}$")) and
    (.firefox160_release_blob==.landed_blob) and
    (.path|type=="string" and length>5) and
    (.mozilla_bug|type=="number")) and
  .scope.selected_files==5 and .scope.selected_cves==4 and
  .scope.all_relevant_fix_files_reviewed==false and
  .scope.full_advisory_audited==false and
  .scope.full_exploit_regressions_run==false and
  .scope.security_current==false and
  .scope.release_ready==false
' "$manifest" >/dev/null || fail 'bounded-source security contract invalid'

count=0
while IFS=$'\t' read -r cve bug commit path fixed release; do
  test -n "$cve" && test -n "$path" && test -n "$commit" || fail 'missing source line'
  case "$path" in
    dom/file/uri/BlobURL.h)
      expected=$'CVE-2026-124855\t2072096\t6955af1bd121f6da8c590c699d6e2e3fba42bfb9\t9fcd8413ea3732964f60d1115689b1c40f919945' ;;
    dom/bindings/ErrorResult.h)
      expected=$'CVE-2026-124859\t2074179\t4b3e088a325ceb62bb355e9abf264f76a0e829f0\tf52099e10089c9a591e06540df19f61a84ebec21' ;;
    ipc/glue/NodeChannel.h)
      expected=$'CVE-2026-124903\t2084673\tf1c9c8b97e0e162b7b78d6c9d2b1aa38c29e3443\t46ca2748c927e268e753bbcdc4eafb9c25dc8519' ;;
    dom/canvas/WebGLMemoryTracker.h)
      expected=$'CVE-2026-124907\t2087324\t53fa8fe451d46060c0e4be67e55042e22783bc49\t5ecd4545e81d45d9f3a5037fa50a72cba7d6dfbf' ;;
    dom/canvas/HostWebGLContext.h)
      expected=$'CVE-2026-124907\t2087324\tba26f55c646c3002a3d7c9de475861d1cc675724\t29ac44618d172dc81737baa63a7786d1ebd2ce30' ;;
    *) fail "Unrecognized security source path: $path" ;;
  esac
  test "$(printf '%s\t%s\t%s\t%s' "$cve" "$bug" "$commit" "$fixed")" = "$expected" ||
    fail "Forged or changed landed-source evidence: $path"
  test "$release" = "$fixed" || fail "No exact landed fix blob in Firefox 160 release: $path"
  count=$((count+1))
done < <(jq -r '.records[] | [.cve,(.mozilla_bug|tostring),.landed_commit,
                              .path,.landed_blob,.firefox160_release_blob] | @tsv' "$manifest")
test "$count" -eq 5 || fail 'source crosswalk has wrong record count'
if test "$mode" = self-test; then
  echo 'PASS: five immutable four-CVE source blob contracts and bounded no-release flags'
  exit 0
fi

for cmd in gh jq sha256sum grep sort wc; do command -v "$cmd" >/dev/null || fail "missing $cmd"; done
test -d "$ledger" && test ! -L "$ledger" &&
  test -s "$ledger/candidate-tree-report.json" &&
  test -s "$ledger/overlay-paths.txt" &&
  test -s "$ledger/changes-against-exact-firefox160.tsv" ||
  fail 'missing frozen complete-source assembly provenance'
test -s "$source" && test ! -L "$source" || fail 'missing on-disk source proof'
test ! -e "$output" && test ! -L "$output" || fail 'refusing overwrite of proof'
jq -e '
  .schema_version==1 and
  .firefox160_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .assembled_git_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .source_files_modified==26 and .vulpra_source_files_added==2 and
  .upstream_files_deleted==0 and .all_other_upstream_files_preserved==true and
  .security_current==false
' "$ledger/candidate-tree-report.json" >/dev/null || fail 'candidate tree ledger not authenticated'
jq -e '
  .upstream_release_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .complete_materialized_source_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .verified_overlays==28 and .exact_assembly_tree_match==true and
  .upstream_paths_otherwise_preserved==true and .security_current==false
' "$source" >/dev/null || fail 'on-disk source identity proof not authenticated'
test "$(wc -l < "$ledger/overlay-paths.txt")" -eq 28 ||
  fail 'candidate overlay must contain exactly 28 paths'
test "$(LC_ALL=C sort -u "$ledger/overlay-paths.txt" | wc -l)" -eq 28 ||
  fail 'overlay contains duplicated changed path'
test "$(cut -f2 "$ledger/changes-against-exact-firefox160.tsv" | LC_ALL=C sort |
       sha256sum | cut -d ' ' -f1)" = \
     "$(LC_ALL=C sort "$ledger/overlay-paths.txt" | sha256sum | cut -d ' ' -f1)" ||
  fail 'overlay list does not reconcile with full-tree changed paths'

while IFS=$'\t' read -r cve bug commit path fixed release; do
  if grep -Fxq -- "$path" "$ledger/overlay-paths.txt"; then
    fail "Vulpra candidate overwrote reviewed Firefox 160 security path: $path"
  fi
  # GitHub source blob IDs are independently verified twice: at the public
  # landed commit AND the official Firefox 160 release. The original
  # source-tree candidate proof establishes unchanged upstream paths.
  commit_url="repos/mozilla-firefox/firefox/commits/$commit"
  headline="$(gh api "$commit_url" --jq '.commit.message' | head -n1)"
  case "$headline" in
    "Bug $bug "*|"Bug $bug -"*) ;;
    *) fail "Upstream Git commit did not reference expected Mozilla bug: $cve" ;;
  esac
  gh api "$commit_url" --jq '.files[].filename' | grep -Fxq -- "$path" ||
    fail "Landed fix commit did not touch advertised path: $path"
  fixed_sha="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=$commit" --jq '.sha')" ||
    fail "Cannot verify public landed fix blob: $path"
  release_sha="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=2887d9de1f69c0e9776413da80e7ba0d1225dd9b" --jq '.sha')" ||
    fail "Cannot verify Firefox 160 official release blob: $path"
  test "$fixed_sha" = "$fixed" && test "$release_sha" = "$release" ||
    fail "Public landed/release Git blobs differ from pinned evidence: $path"
  printf 'PASS: retained %s exact landed Firefox 160 source blob for %s\n' "$path" "$cve"
done < <(jq -r '.records[] | [.cve,(.mozilla_bug|tostring),.landed_commit,
                              .path,.landed_blob,.firefox160_release_blob] | @tsv' "$manifest")

jq -n --slurpfile manifest "$manifest" --arg source_sha \
  "$(sha256sum "$source" | cut -d ' ' -f1)" --arg ledger_sha \
  "$(sha256sum "$ledger/candidate-tree-report.json" | cut -d ' ' -f1)" '{
    schema_version:1,
    kind:"firefox160_verified_selected_boundary_fix_source_retention",
    source_candidate_tree:$manifest[0].pinned_vulpra_candidate_tree,
    original_native_run_id:$manifest[0].original_native_run_id,
    source_identity_proof_sha256:$source_sha,
    verified_complete_candidate_ledger_sha256:$ledger_sha,
    exact_landed_fix_blobs_in_official_release:5,
    selected_advisory_cves_source_spotchecked:4,
    selected_security_source_paths_overwritten_by_vulpra:0,
    records:$manifest[0].records,
    complete_fixes_for_these_cves_independently_verified:false,
    all_advisory_cves_independently_verified:false,
    native_browser_exploit_regressions_run:false,
    security_current:false,release_ready:false
  }' > "$output"
jq -e '
  .exact_landed_fix_blobs_in_official_release==5 and
  .selected_security_source_paths_overwritten_by_vulpra==0 and
  .complete_fixes_for_these_cves_independently_verified==false and
  .security_current==false and .release_ready==false
' "$output" >/dev/null || fail 'invalid source-retention report'
echo 'PASS: five selected exact Firefox 160 landed source blobs retained, no Vulpra overlay collisions'
echo 'LIMIT: selected headers across four CVEs; full fix hunks, applicability, exploit and security-current unverified'
