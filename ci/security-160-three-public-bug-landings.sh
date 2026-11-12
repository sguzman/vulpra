#!/usr/bin/env bash
# Read-only source-identity crosswalk for three selected published Firefox 160 bugs.
# This does not prove full bug fixes, exploit resistance or release readiness.
set -euo pipefail
die() { echo "FAIL: $*" >&2; exit 1; }
if [[ $# -eq 2 && "$1" == --self-test ]]; then
  mode=self-test; manifest=$2
elif [[ $# -eq 5 && "$1" == --verify ]]; then
  mode=verify; manifest=$2; ledger=$3; identity=$4; output=$5
else
  die 'usage: SCRIPT --self-test MANIFEST | --verify MANIFEST LEDGER SOURCE_PROOF NEW_OUTPUT'
fi
[[ -s "$manifest" && ! -L "$manifest" ]] || die 'Missing normal immutable manifest'
jq -e '
  .schema_version==1 and
  .kind=="firefox160_three_public_security_bug_landings_source_crosswalk" and
  .upstream_repository=="mozilla-firefox/firefox" and
  .upstream_release=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .candidate_git_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .original_native_run==43138458940 and
  .selected_cve_count==3 and
  .selected_commit_file_records==11 and .selected_unique_paths==11 and
  (.landings | length)==3 and
  ([.landings[] | [.cve,.mozilla_bug,.upstream_commit,.changed_paths]])==[
    ["CVE-2026-124874",2080420,"1bedf724b441ee7e15979c206b3e143676c9f14f",[
      "netwerk/protocol/http/EarlyHintPreloader.cpp",
      "netwerk/protocol/http/EarlyHintPreloader.h",
      "netwerk/protocol/http/EarlyHintRegistrar.cpp",
      "netwerk/protocol/http/EarlyHintRegistrar.h",
      "netwerk/protocol/http/HttpChannelParent.cpp"
    ]],
    ["CVE-2026-124905",2086254,"a274700a0da7cbe35f81703b8b81610ee5ebfcfc",[
      "docshell/base/nsDocShell.cpp"
    ]],
    ["CVE-2026-124872",2079689,"55de37c0d3f09e5ac57be77b71674da9b83d2086",[
      "js/public/friend/CycleCollector.h",
      "js/src/gc/FinalizationObservers.cpp",
      "js/src/gc/FinalizationObservers.h",
      "js/src/gc/GCRuntime.h",
      "xpcom/base/CycleCollectedJSRuntime.cpp"
    ]]
  ] and
  all(.landings[]; .commit_title | startswith("Bug ")) and
  ([.landings[].changed_paths[]]|length)==11 and
  ([.landings[].changed_paths[]]|unique|length)==11 and
  .limits.public_bug_commit_search_not_exhaustive==true and
  .limits.full_fix_commit_set_unverified==true and
  .limits.changed_path_identity_only==true and
  .limits.divergence_does_not_mean_fix_absent==true and
  .limits.all_selected_cve_fixes_verified==false and
  .limits.full_mfsa_reviewed==false and
  .limits.security_current==false and
  .limits.release_ready==false
' "$manifest" >/dev/null || die 'Manifest changed, malformed or contains false completion claims'
if [[ "$mode" == self-test ]]; then
  echo 'PASS: immutable three-public-bug/five+one+five source-path selection'
  exit 0
fi
for tool in jq gh cmp sort wc sha256sum; do command -v "$tool" >/dev/null || die "Missing $tool"; done
[[ -n "${GH_TOKEN:-}" ]] || die 'GitHub read token missing'
[[ -d "$ledger" && ! -L "$ledger" ]] || die 'No pinned candidate source ledger'
for path in "$ledger/candidate-tree-report.json" "$ledger/overlay-paths.txt" "$identity"; do
  [[ -s "$path" && ! -L "$path" ]] || die "Missing source proof $path"
done
[[ ! -e "$output" && ! -L "$output" ]] || die 'Refusing evidence overwrite'
jq -e '
  .firefox160_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .assembled_git_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .source_files_modified==26 and .vulpra_source_files_added==2 and
  .upstream_files_deleted==0 and .all_other_upstream_files_preserved==true and
  .security_current==false
' "$ledger/candidate-tree-report.json" >/dev/null || die 'Wrong candidate ledger'
jq -e '
  .upstream_release_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .complete_materialized_source_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .verified_overlays==28 and .exact_assembly_tree_match==true and
  .upstream_paths_otherwise_preserved==true and .security_current==false
' "$identity" >/dev/null || die 'Wrong materialized release identity'
[[ $(wc -l < "$ledger/overlay-paths.txt") -eq 28 ]] || die 'Wrong overlay-path count'
[[ $(sort -u "$ledger/overlay-paths.txt" | wc -l) -eq 28 ]] || die 'Duplicate overlay path'
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
: > "$scratch/rows.jsonl"
exact=0; diverged=0; checked=0; divergent_addition_lines=0; divergent_hunk_files=0
while IFS=$'\t' read -r cve bug commit; do
  jq -r --arg sha "$commit" '.landings[] | select(.upstream_commit==$sha) | .changed_paths[]' \
    "$manifest" > "$scratch/expected-paths"
  gh api "repos/mozilla-firefox/firefox/commits/$commit" > "$scratch/commit.json" ||
    die "Could not retrieve upstream Mozilla commit $commit"
  jq -e --arg sha "$commit" --arg bug "$bug" '
    .sha==$sha and (.commit.message|startswith("Bug "+$bug+" -")) and
    (.files|type=="array" and length>0 and length<30) and
    all(.files[]; .status=="modified")
  ' "$scratch/commit.json" >/dev/null || die "Selected Mozilla commit provenance mismatch $commit"
  jq -r '.files[].filename' "$scratch/commit.json" | sort > "$scratch/actual-paths"
  cmp -s "$scratch/expected-paths" "$scratch/actual-paths" ||
    die "Public Mozilla commit paths do not match manifest $commit"
  echo "PASS: Mozilla Bug $bug exact public commit and changed-path list confirmed"
  while IFS= read -r source_path; do
    if grep -Fxq -- "$source_path" "$ledger/overlay-paths.txt"; then
      die "Vulpra changed an audited upstream security path: $source_path"
    fi
    landed=$(gh api "repos/mozilla-firefox/firefox/contents/$source_path?ref=$commit" --jq '.sha') ||
      die "Cannot check upstream landed blob: $source_path"
    release=$(gh api "repos/mozilla-firefox/firefox/contents/$source_path?ref=2887d9de1f69c0e9776413da80e7ba0d1225dd9b" --jq '.sha') ||
      die "Cannot check official release blob: $source_path"
    [[ "$landed" =~ ^[a-f0-9]{40}$ && "$release" =~ ^[a-f0-9]{40}$ ]] ||
      die "Invalid release or landing blob SHA for $source_path"
    additions=0
    if [[ "$landed" == "$release" ]]; then
      classification=exact_landing_blob; exact=$((exact+1))
    else
      classification=release_has_different_blob; diverged=$((diverged+1))
      # A later unrelated source edit can alter the blob while preserving
      # an earlier security fix. Compare selected *added lines* from the
      # authenticated public patch to the final Firefox 160 file. This is
      # only literal hunk survival, not proof of complete fix semantics.
      jq -er --arg path "$source_path" '
        .files[] | select(.filename==$path) | .patch | select(type=="string")
      ' "$scratch/commit.json" > "$scratch/selected-patch" ||
        die "Missing public patch for changed release blob $source_path"
      awk '/^\+[^+]/ {
        line=substr($0,2)
        if (line ~ /[^[:space:]]/) print line
      }' "$scratch/selected-patch" > "$scratch/added-lines"
      [[ -s "$scratch/added-lines" ]] ||
        die "No nonblank public additions to trace in divergent file $source_path"
      gh api "repos/mozilla-firefox/firefox/contents/$source_path?ref=2887d9de1f69c0e9776413da80e7ba0d1225dd9b" \
        --jq '.content' | base64 -d > "$scratch/release-content" ||
        die "Failed to retrieve verified official release content for $source_path"
      # All added nonblank lines must survive exactly as printed. Each
      # source path is already proven unmodified by the Vulpra overlay.
      while IFS= read -r line; do
        grep -Fxq -- "$line" "$scratch/release-content" ||
          die "Selected public added line missing from final release $source_path"
        additions=$((additions+1))
      done < "$scratch/added-lines"
      divergent_addition_lines=$((divergent_addition_lines+additions))
      divergent_hunk_files=$((divergent_hunk_files+1))
    fi
    checked=$((checked+1))
    jq -cn --arg cve "$cve" --argjson bug "$bug" --arg commit "$commit" \
      --arg path "$source_path" --arg landed "$landed" --arg release "$release" \
      --arg class "$classification" --argjson additions "$additions" '{
        cve:$cve,mozilla_bug:$bug,public_commit:$commit,path:$path,
        public_landing_blob:$landed,firefox160_release_blob:$release,
        comparison:$class,divergent_release_added_lines_observed:$additions,
        vulpra_overlay_collision:false,complete_fix_verified:false
      }' >> "$scratch/rows.jsonl"
  done < "$scratch/expected-paths"
done < <(jq -r '.landings[] | [.cve,(.mozilla_bug|tostring),.upstream_commit] | @tsv' "$manifest")
[[ "$checked" -eq 11 && $((exact+diverged)) -eq 11 ]] || die 'Incomplete selected source-file check'
# Source-review reconciliation of this *frozen* release and these three
# selected public commits: eight identical blobs and three changed blobs.
# Twenty-one nonblank public patch additions survive in those changed files.
[[ "$exact" -eq 8 && "$diverged" -eq 3 &&
   "$divergent_hunk_files" -eq 3 && "$divergent_addition_lines" -eq 21 ]] ||
   die 'Selected public landing/release identity or added-line reconciliation drifted'
jq -n --slurpfile rows "$scratch/rows.jsonl" \
  --argjson exact "$exact" --argjson diverged "$diverged" \
  --argjson hunk_files "$divergent_hunk_files" \
  --argjson added "$divergent_addition_lines" \
  --arg ledger_sha "$(sha256sum "$ledger/candidate-tree-report.json" | cut -d' ' -f1)" \
  --arg source_sha "$(sha256sum "$identity" | cut -d' ' -f1)" '{
    schema_version:1,kind:"firefox160_three_public_bug_source_identity_review",
    upstream_release:"2887d9de1f69c0e9776413da80e7ba0d1225dd9b",
    candidate_git_tree:"42dd7439a27dde92f89ac5eed13f88117a4d7ab5",
    original_native_run:43138458940,
    candidate_source_ledger_sha256:$ledger_sha,materialized_source_proof_sha256:$source_sha,
    selected_cves:3,selected_public_commits:3,checked_file_records:($rows|length),
    checked_unique_paths:($rows|map(.path)|unique|length),
    exact_landing_vs_release_blobs:$exact,different_release_blobs:$diverged,
    divergent_release_files_with_added_lines_checked:$hunk_files,
    selected_public_patch_nonblank_added_lines_found_in_release:$added,
    all_selected_divergent_added_lines_verbatim_in_final_release:true,
    full_changed_hunks_or_semantics_verified:false,
    vulpra_overlay_collisions:0,rows:$rows,
    publicly_searched_commit_set_exhaustive:false,
    all_fix_hunks_and_followups_verified:false,
    different_release_blobs_mean_missing_fix:false,
    native_exploit_regression_executed:false,
    full_advisory_audited:false,
    security_current:false,release_ready:false
  }' > "$output"
jq -e '
  .checked_file_records==11 and .checked_unique_paths==11 and
  (.exact_landing_vs_release_blobs+.different_release_blobs)==11 and
  .exact_landing_vs_release_blobs==8 and .different_release_blobs==3 and
  .divergent_release_files_with_added_lines_checked==3 and
  .selected_public_patch_nonblank_added_lines_found_in_release==21 and
  .all_selected_divergent_added_lines_verbatim_in_final_release==true and
  .full_changed_hunks_or_semantics_verified==false and
  .vulpra_overlay_collisions==0 and
  all(.rows[]; .vulpra_overlay_collision==false and .complete_fix_verified==false) and
  .all_fix_hunks_and_followups_verified==false and
  .security_current==false and .release_ready==false
' "$output" >/dev/null || die 'Final proof failed audit contract'
printf 'PASS: %s/11 changed-path source identities audited: %s exact, %s divergent, no Vulpra collision\n' \
  "$checked" "$exact" "$diverged"
printf 'PASS: %s nonblank public patch additions remain verbatim in %s changed release source files\\n' "$divergent_addition_lines" "$divergent_hunk_files"
echo 'LIMIT: literal additions surviving do not establish full patch semantics, exploits or release approval'
