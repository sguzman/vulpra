#!/usr/bin/env bash
# Fail-closed offline source integrity preflight for the isolated security port.
set -euo pipefail
cd "$(dirname "$0")/.."
manifest=docs/vulpra/SECURITY-159-HOTFIX-PORT.json
test -f "$manifest"
jq -e '
  .schema_version == 1 and
  .kind == "vulpra_159_postbeta_hotfix_source_port" and
  .baseline_commit == "b100f0ba13b62021544bc5cf5a9a75b810447427" and
  (.patched_files | length) == 17 and
  ([.patched_files[].path] | unique | length) == 17 and
  ([.patched_files[].cve] | group_by(.) | map({cve:.[0], count:length}) |
    sort_by(.cve) == [
      {cve:"CVE-2026-117860",count:14},
      {cve:"CVE-2026-120572",count:3}
    ]) and
  all(.patched_files[]; .preimage_matches_exact_upstream_patch_parent == true and
    (.path | type == "string") and (.path | length > 0) and
    (.upstream_fixed_sha | test("^[0-9a-f]{40}$")) and
    (.preimage_sha | test("^[0-9a-f]{40}$")) and
    (.upstream_fixed_sha != .preimage_sha)) and
  .upstream_added_regression_test.path ==
    "testing/web-platform/tests/css/css-position/crashtests/inline-containing-block-delete-continuations-001.html" and
  .acceptance.compiled_native_security_port == false and
  .acceptance.browser_runtime_security_verified == false and
  .acceptance.full_advisory_audit_complete == false and
  .acceptance.release_ready == false and
  .acceptance.frozen_main_m3_comparator_untouched == true
' "$manifest" >/dev/null
count=0
while IFS=$'\t' read -r path sha; do
  test -f "$path" || { echo "FAIL missing $path" >&2; exit 1; }
  actual="$(git hash-object "$path")"
  if test "$actual" != "$sha"; then
    echo "FAIL patched source blob differs: $path" >&2
    exit 1
  fi
  count=$((count+1))
done < <(jq -r '.patched_files[] | [.path,.upstream_fixed_sha] | @tsv' "$manifest")
test "$count" -eq 17
regression="$(jq -r '.upstream_added_regression_test.path' "$manifest")"
expected="$(jq -r '.upstream_added_regression_test.upstream_fixed_sha' "$manifest")"
test -f "$regression"
test "$(git hash-object "$regression")" = "$expected"
echo "PASS: 17 exact upstream patched code blobs and one real upstream regression fixture retained"
echo "LIMIT: source integrity ONLY; no compile/runtime/security-current assertion"
