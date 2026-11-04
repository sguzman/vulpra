#!/usr/bin/env bash
# Verify the two complex Firefox 159 security source crosswalks against real
# tracked Git objects. This does not execute an exploit or attest release safety.
set -euo pipefail

manifest="${1:-docs/vulpra/SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json}"
if [[ ! -f "$manifest" ]]; then
  echo "Missing source crosswalk: $manifest" >&2
  exit 1
fi
command -v jq >/dev/null
command -v git >/dev/null
git rev-parse --is-inside-work-tree >/dev/null

for entry in "CVE-2026-118006:11:3" "CVE-2026-118007:74:10"; do
  IFS=: read -r cve required_paths required_commits <<< "$entry"

  jq -e --arg cve "$cve" --argjson n "$required_paths" --argjson commits "$required_commits" '
    [.verified_present_in_beta[] | select(.cve == $cve)] as $matches
    | ($matches | length) == 1
      and ($matches[0].patch_commits | length) == $commits
      and ($matches[0].source_file_blobs | length) == $n
      and ([$matches[0].source_file_blobs[].path] | unique | length) == $n
      and all($matches[0].source_file_blobs[];
        (.path | type == "string" and test("^[A-Za-z0-9_./-]+$"))
        and (.path | startswith("../") | not)
        and (.vulpra_sha | test("^[0-9a-f]{40}$"))
        and (.pinned_beta_sha | test("^[0-9a-f]{40}$"))
        and (.upstream_stable_159_sha | test("^[0-9a-f]{40}$"))
        and (.upstream_selected_patch_result_sha | test("^[0-9a-f]{40}$"))
        and (.vulpra_sha == .pinned_beta_sha)
        and (.vulpra_sha == .upstream_stable_159_sha)
        and (.fix_result_blob_matches_beta == (.upstream_selected_patch_result_sha == .pinned_beta_sha))
        and (.fix_result_blob_matches_vulpra == (.upstream_selected_patch_result_sha == .vulpra_sha))
      )
  ' "$manifest" >/dev/null || {
    echo "Malformed or inflated source claim for $cve" >&2
    exit 1
  }

  rows="$(jq -r --arg cve "$cve" '
    .verified_present_in_beta[] | select(.cve == $cve)
    | .source_file_blobs[] | [.path, .vulpra_sha] | @tsv
  ' "$manifest")"
  passed=0
  while IFS=$'\t' read -r path expected; do
    actual="$(git rev-parse --verify "HEAD:$path" 2>/dev/null)" || {
      echo "Missing tracked source path: $path" >&2
      exit 1
    }
    if [[ "$actual" != "$expected" ]]; then
      echo "Source crosswalk mismatch for $cve: $path" >&2
      exit 1
    fi
    passed=$((passed + 1))
  done <<< "$rows"

  if (( passed != required_paths )); then
    echo "Wrong number of source paths verified for $cve" >&2
    exit 1
  fi
  echo "$cve: $passed/$required_paths tracked source object hashes verified"
done

echo "Source-only crosswalk PASS; no browser security or release acceptance implied"
