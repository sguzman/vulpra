#!/usr/bin/env bash
# Compare every changed file in six selected Mozilla security-bug commits.
# Different release blob != absent security fix; this is only source identity.
set -euo pipefail
die() { echo "FAIL: $*" >&2; exit 1; }
if test "$#" = 2 && test "$1" = --self-test; then
  mode=self-test; manifest="$2"
elif test "$#" = 5 && test "$1" = --verify; then
  mode=verify; manifest="$2"; ledger="$3"; identity="$4"; output="$5"
else
  die "Usage: SCRIPT --self-test MANIFEST | --verify MANIFEST LEDGER SOURCE_IDENTITY OUTPUT"
fi
test -s "$manifest" && test ! -L "$manifest" || die 'Missing normal manifest'
jq -e '
  .schema_version==1 and
  .kind=="firefox160_four_boundary_bugs_six_public_landings_all_changed_paths_inventory" and
  .official_source_repository=="mozilla-firefox/firefox" and
  .firefox160_release_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .vulpra_candidate_git_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .original_ci_run_id==43138458940 and
  .selected_cve_count==4 and .upstream_commits_examined==6 and
  .changed_file_records==31 and .unique_changed_paths==27 and
  (.commits|type=="array" and length==6) and
  ([.commits[].upstream_commit]|unique|length)==6 and
  ([.commits[].cve]|unique|sort)==["CVE-2026-124855",
    "CVE-2026-124859","CVE-2026-124903","CVE-2026-124907"] and
  ([.commits[].changed_paths[]]|length)==31 and
  ([.commits[].changed_paths[]]|unique|length)==27 and
  all(.commits[];
    (.upstream_commit|test("^[a-f0-9]{40}$")) and
    (.mozilla_bug|type=="number") and
    (.commit_title|startswith("Bug " + (.mozilla_bug|tostring) + " -")) and
    (.changed_paths|type=="array" and length>0 and length<20) and
    (.changed_paths==(.changed_paths|unique|sort)) and
    all(.changed_paths[];
      (type=="string" and length>5 and length<200) and
      test("^[a-zA-Z0-9_./-]+$") and
      (startswith("/")|not) and
      (contains("../")|not) and (endswith("/..")|not))) and
  .limits.public_bug_id_search_not_exhaustive==true and
  .limits.complete_cve_fix_hunks_verified==false and
  .limits.diverged_release_blobs_are_not_automatically_failures==true and
  .limits.security_current==false and .limits.release_ready==false
' "$manifest" >/dev/null || die 'Manifest structural or no-release contract failed'

expected_commits="$(printf '%s\n' \
  31ff32bbcdcf80827e72d6af6d5241bfbb9c7658 \
  6955af1bd121f6da8c590c699d6e2e3fba42bfb9 \
  4b3e088a325ceb62bb355e9abf264f76a0e829f0 \
  f1c9c8b97e0e162b7b78d6c9d2b1aa38c29e3443 \
  ba26f55c646c3002a3d7c9de475861d1cc675724 \
  53fa8fe451d46060c0e4be67e55042e22783bc49 | sort)"
actual_commits="$(jq -r '.commits[].upstream_commit' "$manifest" | sort)"
test "$actual_commits" = "$expected_commits" || die 'Public commit list changed'
if test "$mode" = self-test; then
  echo 'PASS: six immutable commits, 31 source-path records, 27 unique paths; no fake security clearance'
  exit 0
fi

for app in gh jq sha256sum sort cmp; do command -v "$app" >/dev/null || die "Missing $app"; done
test -n "$GH_TOKEN" || die 'Missing GitHub token'
test -d "$ledger" && test ! -L "$ledger" || die 'No original source-tree ledger'
for file in "$ledger/candidate-tree-report.json" "$ledger/overlay-paths.txt" \
  "$ledger/changes-against-exact-firefox160.tsv" "$identity"; do
  test -s "$file" && test ! -L "$file" || die "Missing proven source ledger: $file"
done
test ! -e "$output" || die 'Refuse overwrite'
jq -e '.schema_version==1 and
  .firefox160_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .assembled_git_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .source_files_modified==26 and .vulpra_source_files_added==2 and
  .upstream_files_deleted==0 and .all_other_upstream_files_preserved==true and
  .security_current==false' "$ledger/candidate-tree-report.json" >/dev/null ||
  die 'Candidate exact Git-tree source ledger invalid'
jq -e '.upstream_release_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .complete_materialized_source_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .verified_overlays==28 and .exact_assembly_tree_match==true and
  .upstream_paths_otherwise_preserved==true and .security_current==false' "$identity" >/dev/null ||
  die 'Materialized source proof invalid'
test "$(wc -l < "$ledger/overlay-paths.txt")" -eq 28 &&
test "$(sort -u "$ledger/overlay-paths.txt" | wc -l)" -eq 28 ||
  die 'Expected 28 unique source overlays'
test "$(cut -f2 "$ledger/changes-against-exact-firefox160.tsv" | sort | sha256sum | cut -d' ' -f1)" = \
     "$(sort "$ledger/overlay-paths.txt" | sha256sum | cut -d' ' -f1)" ||
  die 'Original candidate changed-path list is inconsistent'

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
: > "$tmp/rows.jsonl"
exact=0; diverged=0
while IFS=$'\t' read -r cve bug commit; do
  jq -r --arg sha "$commit" '.commits[] |
    select(.upstream_commit==$sha)|.changed_paths[]' "$manifest" > "$tmp/expected"
  gh api "repos/mozilla-firefox/firefox/commits/$commit" > "$tmp/commit.json" ||
    die "Cannot fetch real Mozilla commit $commit"
  jq -e --arg bug "$bug" '
    (.commit.message|startswith("Bug " + $bug + " -")) and
    (.files|type=="array" and length>0 and length<20)' "$tmp/commit.json" >/dev/null ||
    die "Mozilla commit/bug provenance mismatch $commit"
  jq -r '.files[].filename' "$tmp/commit.json" | sort > "$tmp/actual"
  cmp -s "$tmp/expected" "$tmp/actual" ||
    die "Public landed commit path set differs from frozen manifest $commit"
  printf 'PASS: authenticated Mozilla bug %s, commit %.8s, %s changed paths\n' \
    "$bug" "$commit" "$(wc -l < "$tmp/expected")"
  while IFS= read -r path; do
    if grep -Fxq -- "$path" "$ledger/overlay-paths.txt"; then
      die "Vulpra overlay overwrote selected security path: $path"
    fi
    landed="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=$commit" --jq '.sha')" ||
      die "Cannot authenticate landed blob for $path"
    released="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=2887d9de1f69c0e9776413da80e7ba0d1225dd9b" --jq '.sha')" ||
      die "Cannot authenticate release blob for $path"
    [[ "$landed" =~ ^[a-f0-9]{40}$ && "$released" =~ ^[a-f0-9]{40}$ ]] ||
      die "Bad Git SHA for $path"
    if test "$landed" = "$released"; then
      classification=exact_file_blob; exact=$((exact+1))
    else
      classification=diverged_release_file_blob; diverged=$((diverged+1))
    fi
    another="$(jq -n --arg path "$path" --arg current "$commit" \
      --slurpfile manifest "$manifest" '
      any($manifest[0].commits[]; .upstream_commit!=$current and
        (.changed_paths|index($path))!=null)')"
    jq -cn --arg cve "$cve" --argjson bug "$bug" \
      --arg commit "$commit" --arg path "$path" \
      --arg landed "$landed" --arg released "$released" \
      --arg class "$classification" --argjson another "$another" '{
      cve:$cve,mozilla_bug:$bug,selected_public_commit:$commit,path:$path,
      landed_blob_sha:$landed,firefox160_release_blob_sha:$released,
      comparison:$class,also_touched_by_other_selected_commit:$another,
      vulpra_overlay_collision:false,complete_fix_hunks_verified:false
    }' >> "$tmp/rows.jsonl"
  done < "$tmp/expected"
done < <(jq -r '.commits[] |
  [.cve,(.mozilla_bug|tostring),.upstream_commit]|@tsv' "$manifest")
test "$((exact+diverged))" -eq 31 || die 'Not all 31 occurrences compared'
jq -n --slurpfile rows "$tmp/rows.jsonl" --argjson exact "$exact" \
  --argjson diverged "$diverged" --slurpfile manifest "$manifest" \
  --arg ledger_sha "$(sha256sum "$ledger/candidate-tree-report.json" | cut -d' ' -f1)" \
  --arg identity_sha "$(sha256sum "$identity" | cut -d' ' -f1)" '{
    schema_version:1,
    kind:"firefox160_six_selected_security_landings_all_changed_paths_crosswalk",
    firefox160_source_commit:$manifest[0].firefox160_release_commit,
    pinned_vulpra_tree:$manifest[0].vulpra_candidate_git_tree,
    original_native_run_id:$manifest[0].original_ci_run_id,
    source_ledger_sha256:$ledger_sha,materialized_source_proof_sha256:$identity_sha,
    selected_cves:4,public_fix_commits:6,
    checked_commit_file_records:($rows|length),
    checked_unique_source_paths:($rows|map(.path)|unique|length),
    exact_public_landed_file_blobs:$exact,
    different_public_landed_vs_release_blobs:$diverged,
    vulpra_overlay_collisions:0,
    rows:$rows,
    development_commit_ancestry_in_release_not_assumed:true,
    source_patch_hunks_for_diverged_files_audited:false,
    all_fix_changes_for_selected_cves_verified:false,
    full_advisory_audited:false,
    native_exploit_regressions_run:false,
    security_current:false,release_ready:false
  }' > "$output"
jq -e '
  .checked_commit_file_records==31 and .checked_unique_source_paths==27 and
  (.exact_public_landed_file_blobs+.different_public_landed_vs_release_blobs)==31 and
  .vulpra_overlay_collisions==0 and
  all(.rows[]; .vulpra_overlay_collision==false) and
  .all_fix_changes_for_selected_cves_verified==false and
  .security_current==false and .release_ready==false
' "$output" >/dev/null || die 'Final audit integrity failure'
printf 'PASS: all 31 selected security commit-file records verified: %d exact, %d divergent, 0 Vulpra collisions\n' \
  "$exact" "$diverged"
echo 'LIMIT: different release blobs need later-change analysis; commit file identity is not complete CVE fix verification'
