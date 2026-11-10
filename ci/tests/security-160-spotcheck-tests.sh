#!/usr/bin/env bash
# Mutation tests: all forged Firefox 160 security-source claims must fail.
set -euo pipefail
root="$(cd "$(dirname -- "$0")/../.." && pwd -P)"
cd "$root"
original="docs/vulpra/SECURITY-160-INITIAL-PATCH-GAPS-20261110.json"
verifier="$root/ci/security-160-spotcheck.sh"
bash -n "$verifier"
bash "$verifier"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
jq '.upstream_release_sha = ("0"*40)' "$original" > "$tmp/alter-release.json"
jq '.patch_files[0].landed_fix_result_git_blob = ("f"*40)' "$original" > "$tmp/alter-fixed.json"
jq '.patch_files[0].firefox_160_release_git_blob = ("a"*40)' "$original" > "$tmp/alter-release-file.json"
jq '.patch_files[3].classification = "exact_fixed_file_in_release_pre_fix_in_vulpra"' "$original" > "$tmp/false-same-blob.json"
jq '.patch_files[1].path = .patch_files[0].path' "$original" > "$tmp/duplicate-path.json"
jq 'del(.patch_files[5])' "$original" > "$tmp/omitted-file.json"
jq '.scope.security_current = true' "$original" > "$tmp/false-security-ready.json"
jq '.patch_files[2].cve = "CVE-2000-000001"' "$original" > "$tmp/forged-cve.json"
jq '.advisory = "MFSA 2026-118"' "$original" > "$tmp/wrong-advisory.json"
jq '.patch_files[3].vulpra_main_git_blob = .patch_files[3].landed_fix_result_git_blob' "$original" > "$tmp/false-main-fixed.json"
jq '.source_beta_tag = "FIREFOX_160_0_RELEASE"' "$original" > "$tmp/false-beta.json"
jq '.patch_files[0].mozilla_bug = 1' "$original" > "$tmp/forged-bug.json"
count=0
for bad in "$tmp"/*.json; do
  if bash "$verifier" "$bad" >/dev/null 2>&1; then
    echo "FAIL: accepted forged source-security claim $bad" >&2
    exit 1
  fi
  count=$((count+1))
done
test "$count" -eq 12
echo 'PASS: 12/12 forged Firefox 160 advisory, patch, source, release and security-ready claims rejected'
echo 'LIMIT: read-only source-identity fixtures; no browser execution or full security update'
