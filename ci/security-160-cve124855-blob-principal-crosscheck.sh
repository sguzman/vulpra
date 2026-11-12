#!/usr/bin/env bash
# Source-only audit of final Part 2 and retained cross-process Part 1 blob:null
# principal changes from public Mozilla Bug 2072096 / CVE-2026-124855.
# Does not certify all Part 1 hunks, semantic principal isolation, or release.
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
if test "$#" -eq 1 && test "$1" = --self-test; then
  echo 'PASS: pinned two-part blob URI principal source verifier'; exit 0
fi
if test "$#" -ne 4 || test "$1" != --verify; then
  fail 'Usage: SCRIPT --self-test | --verify LEDGER SOURCE_IDENTITY OUTPUT'
fi
ledger="$2"; identity="$3"; output="$4"
test -n "$GH_TOKEN" || fail 'Read-only source API token missing'
test ! -e "$output" || fail 'Refusing to overwrite source audit proof'
for f in "$ledger/candidate-tree-report.json" "$ledger/overlay-paths.txt" "$ledger/changes-against-exact-firefox160.tsv" "$identity"; do
  test -s "$f" && test ! -L "$f" || fail 'Missing exact source candidate proof'
done
jq -e '
  .firefox160_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .assembled_git_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .source_files_modified==26 and .vulpra_source_files_added==2 and
  .upstream_files_deleted==0 and .all_other_upstream_files_preserved==true and
  .security_current==false
' "$ledger/candidate-tree-report.json" >/dev/null || fail 'Untrusted source candidate ledger'
jq -e '.upstream_release_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .complete_materialized_source_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .verified_overlays==28 and .exact_assembly_tree_match==true and
  .upstream_paths_otherwise_preserved==true' "$identity" >/dev/null ||
  fail 'Untrusted materialized source proof'
test "$(wc -l < "$ledger/overlay-paths.txt")" -eq 28 || fail 'Overlay list length unexpected'
test "$(cut -f2 "$ledger/changes-against-exact-firefox160.tsv" | sort | sha256sum | cut -d' ' -f1)" = \
  "$(sort "$ledger/overlay-paths.txt" | sha256sum | cut -d' ' -f1)" ||
  fail 'Overlay changed-source ledger mismatch'
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
first=31ff32bbcdcf80827e72d6af6d5241bfbb9c7658
second=6955af1bd121f6da8c590c699d6e2e3fba42bfb9
release=2887d9de1f69c0e9776413da80e7ba0d1225dd9b
gh api "repos/mozilla-firefox/firefox/commits/$first" > "$work/part1.json" ||
  fail 'Missing public Mozilla Part 1 commit'
gh api "repos/mozilla-firefox/firefox/commits/$second" > "$work/part2.json" ||
  fail 'Missing public Mozilla Part 2 commit'
jq -e '.commit.message|startswith("Bug 2072096 - Part 1:")' "$work/part1.json" >/dev/null ||
  fail 'Wrong Part 1 commit'
jq -e '.commit.message|startswith("Bug 2072096 - Part 2:")' "$work/part2.json" >/dev/null ||
  fail 'Wrong Part 2 commit'
cat > "$work/expected-part1" <<'PATHS'
dom/file/uri/BlobURL.cpp
dom/file/uri/BlobURL.h
dom/file/uri/BlobURLProtocolHandler.cpp
dom/file/uri/BlobURLProtocolHandler.h
dom/ipc/ContentChild.cpp
dom/ipc/ContentParent.cpp
PATHS
cat > "$work/expected-part2" <<'PATHS'
dom/file/uri/BlobURL.cpp
dom/file/uri/BlobURL.h
dom/file/uri/BlobURLProtocolHandler.cpp
dom/file/uri/BlobURLProtocolHandler.h
ipc/glue/URIParams.ipdlh
PATHS
jq -r '.files[].filename' "$work/part1.json" | sort > "$work/actual-part1"
jq -r '.files[].filename' "$work/part2.json" | sort > "$work/actual-part2"
cmp -s "$work/expected-part1" "$work/actual-part1" ||
  fail 'Part 1 Mozilla commit changed-path set differs'
cmp -s "$work/expected-part2" "$work/actual-part2" ||
  fail 'Part 2 Mozilla commit changed-path set differs'
: > "$work/rows.jsonl"
present_total=0; missing_total=0; record_count=0
for part in 1 2; do
  if test "$part" -eq 1; then
    changed="$work/part1.json"; paths="$work/expected-part1"
  else
    changed="$work/part2.json"; paths="$work/expected-part2"
  fi
  while IFS= read -r path; do
    # Part 1's four main blob URI implementation files were intentionally
    # changed by Part 2. Their *earlier intermediate* added lines are NOT
    # required unchanged; evaluate final Part 2 and Part 1-only DOM IPC files.
    if test "$part" -eq 1 && test "$path" != dom/ipc/ContentChild.cpp &&
      test "$path" != dom/ipc/ContentParent.cpp; then
      continue
    fi
    if grep -Fxq -- "$path" "$ledger/overlay-paths.txt"; then
      fail "Vulpra overwrote reviewed security source path: $path"
    fi
    jq -er --arg p "$path" '.files[]|select(.filename==$p)|.patch' \
      "$changed" > "$work/patch" || fail "Missing full public patch for $path"
    awk '/^\+[^+]/ {
      s=substr($0,2);sub(/^[[:space:]]+/, "", s);sub(/[[:space:]]+$/, "", s)
      if (length(s)>10 && s !~ /^\/\//) print s
    }' "$work/patch" | LC_ALL=C sort -u > "$work/added"
    test -s "$work/added" || fail "No nontrivial patch additions in $path"
    curl -fLsS --retry 3 --max-time 90 \
      "https://raw.githubusercontent.com/mozilla-firefox/firefox/$release/$path" \
      -o "$work/release" || fail "Missing pinned Firefox 160 source for $path"
    release_blob="$(git hash-object -- "$work/release")"
    official_blob="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=$release" --jq '.sha')" ||
      fail "Official source SHA unavailable for $path"
    test "$release_blob" = "$official_blob" || fail "Official release source SHA mismatch"
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$work/release" |
      LC_ALL=C sort -u > "$work/release-lines"
    LC_ALL=C comm -23 "$work/added" "$work/release-lines" > "$work/missing"
    missing="$(wc -l < "$work/missing")"
    present="$(wc -l < "$work/added")"
    present=$((present-missing))
    if test "$part" -eq 2 && test "$path" = dom/file/uri/BlobURLProtocolHandler.cpp; then
      test "$missing" -eq 1 || fail 'Unexpected missing final Part 2 blob URI code'
      grep -Fq 'aBlobImpl, aPrincipal, nullOriginEntry, aPartitionKey,' "$work/release" ||
        fail 'Combined final blob URI partition constructor arguments missing'
    else
      test "$missing" -eq 0 || fail "Unexpected missing selected patch code: $path"
    fi
    present_total=$((present_total+present))
    missing_total=$((missing_total+missing))
    record_count=$((record_count+1))
    jq -cn --arg path "$path" --arg release_sha "$release_blob" \
      --argjson part "$part" --argjson present "$present" --argjson missing "$missing" '{
      path:$path,public_bug_part:$part,verified_firefox160_blob:$release_sha,
      nontrivial_added_lines_present:$present,
      nontrivial_added_lines_not_verbatim:$missing,
      code_position_and_removal_semantics_not_fully_verified:true,
      vulpra_overlay_collision:false
    }' >> "$work/rows.jsonl"
    printf 'AUDIT: Part %d %s: %d nontrivial additions retained, %d differently formatted\n' \
      "$part" "$path" "$present" "$missing"
  done < "$paths"
done
test "$record_count" -eq 7 &&
test "$missing_total" -eq 1 &&
test "$present_total" -ge 60 ||
  fail 'Part 2 and retained Part 1 DOM IPC source coverage mismatch'
jq -n --slurpfile rows "$work/rows.jsonl" --argjson retained "$present_total" '{
  schema_version:1,
  kind:"firefox160_cve124855_final_blob_uri_part2_and_dom_ipc_part1_source_retention",
  cve:"CVE-2026-124855",mozilla_bug:2072096,
  part1_commit:"31ff32bbcdcf80827e72d6af6d5241bfbb9c7658",
  part2_commit:"6955af1bd121f6da8c590c699d6e2e3fba42bfb9",
  official_release_commit:"2887d9de1f69c0e9776413da80e7ba0d1225dd9b",
  pinned_candidate_tree:"42dd7439a27dde92f89ac5eed13f88117a4d7ab5",
  unique_final_source_paths_checked:($rows|length),
  final_part2_files_checked:5,unmodified_part1_dom_ipc_files_checked:2,
  significant_added_lines_present_verbatim:$retained,
  source_lines_changed_by_later_formatting:1,
  final_blob_uri_partition_constructor_arguments_present:true,
  intermediate_part1_blob_uri_source_hunks_not_required_verbatim:true,
  older_part1_hunk_semantics_and_deletions_not_verified:true,
  all_11_changed_file_occurrences_covered_by_prior_blob_identity_crosswalk:true,
  overlay_collisions:0,files:$rows,
  complete_cve_fix_verified:false,runtime_exploit_regression_executed:false,
  full_advisory_audited:false,security_current:false,release_ready:false
}' > "$output"
jq -e '
  .unique_final_source_paths_checked==7 and .final_part2_files_checked==5 and
  .unmodified_part1_dom_ipc_files_checked==2 and
  .significant_added_lines_present_verbatim>=60 and
  .source_lines_changed_by_later_formatting==1 and
  .overlay_collisions==0 and .complete_cve_fix_verified==false and
  .security_current==false and .release_ready==false
' "$output" >/dev/null || fail 'Invalid bounded source proof'
echo "PASS: $record_count final Part 2/Part 1 DOM IPC source files; $present_total significant code additions retained; 1 explicitly checked formatting difference"
echo 'LIMIT: earlier Part 1 implementation code was superseded by Part 2; full patch semantics, origin isolation and CVE fix remain unverified'
