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


# All other audited, source-positive CVEs must also retain their code blobs.
# Unlike the fixed WebRTC/GC cohort above, this is deliberately data-driven:
# adding a verified CVE to the register immediately adds all of its referenced
# source paths to the mandatory Git-object check, with no allowlist changes.
jq -e --argjson minimum_cves 40 --argjson minimum_paths 206 '
  (.verified_present_in_beta | type == "array" and length >= $minimum_cves)
  and (.findings | type == "array" and length == 2)
  and ([.findings[].cve] | sort) == ["CVE-2026-117860", "CVE-2026-120572"]
  and ([.verified_present_in_beta[].cve] | unique | length) == (.verified_present_in_beta | length)
  and ([.verified_present_in_beta[].cve, .findings[].cve] | unique | length) ==
      ((.verified_present_in_beta | length) + (.findings | length))
  and ([.verified_present_in_beta[].source_file_blobs[]] | length) >= $minimum_paths
  and all(.verified_present_in_beta[];
    (.cve | type == "string" and test("^CVE-[0-9]{4}-[0-9]{4,}$"))
    and (.source_file_blobs | type == "array" and length > 0)
    and ([.source_file_blobs[].path] | unique | length) == (.source_file_blobs | length)
    and all(.source_file_blobs[];
      (.path | type == "string" and test("^[A-Za-z0-9_./-]+$")
        and (startswith("/") | not) and (contains("../") | not))
      and (.vulpra_sha | type == "string" and test("^[0-9a-f]{40}$"))
      and (.pinned_beta_sha | type == "string" and test("^[0-9a-f]{40}$"))
      and (.vulpra_sha == .pinned_beta_sha)
      and (if has("upstream_stable_159_sha") then
             .upstream_stable_159_sha == .vulpra_sha
           else true end)
      and (if has("vulpra_matches_pinned_beta") then
             .vulpra_matches_pinned_beta == (.vulpra_sha == .pinned_beta_sha)
           else true end)
      and (if has("fix_result_blob_matches_beta") then
             ((.upstream_fix_commit_result_sha //
               .upstream_selected_patch_result_sha) == .pinned_beta_sha) ==
               .fix_result_blob_matches_beta
           else true end)
      and (if has("fix_result_blob_matches_vulpra") then
             ((.upstream_fix_commit_result_sha //
               .upstream_selected_patch_result_sha) == .vulpra_sha) ==
               .fix_result_blob_matches_vulpra
           else true end)
    )
  )
  and ([.verified_present_in_beta[].source_file_blobs[]]
       | group_by(.path)
       | all(.[]; ([.[].vulpra_sha] | unique | length) == 1))
' "$manifest" >/dev/null || {
  echo "Source-positive security register has missing, inconsistent or forged evidence" >&2
  exit 1
}

registered="$(jq -r '.verified_present_in_beta | length' "$manifest")"
recorded="$(jq -r '[.verified_present_in_beta[].source_file_blobs[]] | length' "$manifest")"
tested=0
while IFS=$'\t' read -r path expected; do
  actual="$(git rev-parse --verify "HEAD:$path" 2>/dev/null)" || {
    echo "Missing tracked audited source path: $path" >&2
    exit 1
  }
  if [[ "$actual" != "$expected" ]]; then
    echo "Security source mismatch: $path" >&2
    exit 1
  fi
  tested=$((tested + 1))
done < <(jq -r '.verified_present_in_beta[].source_file_blobs[]
            | [.path, .vulpra_sha] | @tsv' "$manifest")

if (( tested != recorded )); then
  echo "Audited source rows were not all inspected ($tested/$recorded)" >&2
  exit 1
fi
echo "PASS: $registered source-positive CVEs; $tested/$recorded tracked source claims verified"
echo "Source-only evidence; not full MFSA coverage, browser exploit QA or a release gate"


# Require the entire vendor-published high-impact CVE scope, not only
# the subset with source-level evidence. These exact published CVE ranges were
# checked against MFSA 2026-118 (Firefox 159) and 2026-123 (Firefox 159.0.1).
# Fail closed when an advisory entry disappears from this pinned denominator.
jq -e '
  ([range(117860; 117955) | "CVE-2026-\(.)"] +
   [range(118005; 118018) | "CVE-2026-\(.)"]) as $expected |
  ($expected | length == 108)
  and (.advisory_coverage.mfsa_2026_118_high.expected_cve_ids == $expected)
  and (.advisory_coverage.mfsa_2026_118_high.advisory == "MFSA 2026-118")
  and (.advisory_coverage.mfsa_2026_118_high.impact == "high")
  and (.advisory_coverage.mfsa_2026_123_high.expected_cve_ids == ["CVE-2026-120572"])
  and ([.findings[] | select(.cve == "CVE-2026-120572")] | length == 1)
  and (
    ([.verified_present_in_beta[].cve,
      (.findings[] | select(.cve == "CVE-2026-117860") | .cve)] | unique) as $reviewed |
    ($reviewed | length >= 42)
    and all($reviewed[]; . as $id | $expected | index($id) != null)
  )
' "$manifest" >/dev/null || {
  echo "Firefox 159 high-impact advisory coverage was changed, truncated or misclassified" >&2
  exit 1
}

jq -rn --slurpfile evidence "$manifest" '
  ($evidence[0].advisory_coverage.mfsa_2026_118_high.expected_cve_ids) as $all |
  ([$evidence[0].verified_present_in_beta[].cve,
    ($evidence[0].findings[] | select(.cve == "CVE-2026-117860") | .cve)] | unique) as $reviewed |
  ($all | map(select(. as $id | $reviewed | index($id) == null))) as $remaining |
  "MFSA 2026-118: \($reviewed | length)/\($all | length) high-impact CVEs scoped and \($remaining | length) still unaudited; MFSA 2026-123: CVE-2026-120572 isolated-patch evidence recorded; NOT release-ready"
'
