#!/usr/bin/env bash
# Bounded source-line survival review: CVE-2026-124859 / Mozilla bug 2074179.
# Exact added-lines ≠ complete hunk semantics ≠ security-current acceptance.
set -euo pipefail
die() { echo "FAIL: $*" >&2; exit 1; }
if test "$#" = 1 && test "$1" = --self-test; then
  mode=self-test
elif test "$#" = 4 && test "$1" = --verify; then
  mode=verify; ledger="$2"; identity="$3"; report="$4"
else
  die 'Usage: SCRIPT --self-test | --verify CANDIDATE_LEDGER MATERIALIZED_SOURCE OUTPUT'
fi
commit=4b3e088a325ceb62bb355e9abf264f76a0e829f0
release=2887d9de1f69c0e9776413da80e7ba0d1225dd9b
paths="$(printf '%s\n' dom/bindings/BindingUtils.cpp dom/bindings/ErrorResult.h ipc/chromium/src/chrome/common/ipc_message_utils.h | sort)"
test "$(printf '%s\n' "$paths" | sort -u | wc -l)" -eq 3 ||
  die 'Expected three selected distinct source paths'
if test "$mode" = self-test; then
  echo 'PASS: pinned CVE 2026-124859 commit and exact three changed-path sources'
  exit 0
fi
for program in gh jq curl git grep sed awk comm cmp sort; do
  command -v "$program" >/dev/null || die "Missing utility: $program"
done
test -n "$GH_TOKEN" || die 'Missing read-only GitHub token'
test -s "$ledger/candidate-tree-report.json" &&
test -s "$ledger/overlay-paths.txt" &&
test -s "$identity" && test ! -L "$identity" || die 'Missing exact source provenance'
test ! -e "$report" || die 'Refusing existing output'
jq -e '.firefox160_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .assembled_git_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .source_files_modified==26 and .vulpra_source_files_added==2 and
  .all_other_upstream_files_preserved==true and .security_current==false' \
  "$ledger/candidate-tree-report.json" >/dev/null || die 'Candidate ledger failed'
jq -e '.upstream_release_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .complete_materialized_source_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .verified_overlays==28 and .upstream_paths_otherwise_preserved==true' \
  "$identity" >/dev/null || die 'Materialized source evidence failed'
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
gh api "repos/mozilla-firefox/firefox/commits/$commit" > "$tmp/landed.json" ||
  die 'Mozilla commit unavailable'
jq -e '.commit.message|startswith("Bug 2074179 -")' "$tmp/landed.json" >/dev/null ||
  die 'Unexpected Mozilla bug commit'
jq -r '.files[].filename' "$tmp/landed.json" | sort > "$tmp/changed"
printf '%s\n' "$paths" > "$tmp/expected"
cmp -s "$tmp/changed" "$tmp/expected" ||
  die 'Public commit has unreviewed changed source files'
: > "$tmp/results.jsonl"
total=0
while IFS= read -r path; do
  if grep -Fxq -- "$path" "$ledger/overlay-paths.txt"; then
    die "Vulpra overlay overwrote source fix file: $path"
  fi
  jq -er --arg path "$path" '.files[]|select(.filename==$path)|.patch' \
    "$tmp/landed.json" > "$tmp/patch"
  test "$(wc -c < "$tmp/patch")" -gt 100 || die 'Missing source diff hunk'
  # Gather nontrivial ADDED lines, excluding metadata, comments and short
  # syntactic tokens. Full-context and deleted-line semantics remain unproven.
  awk '/^\+[^+]/ {
    line=substr($0,2)
    sub(/^[[:space:]]+/, "", line);sub(/[[:space:]]+$/, "", line)
    if (length(line)>10 && line !~ /^\/\//) print line
  }' "$tmp/patch" | LC_ALL=C sort -u > "$tmp/added"
  test -s "$tmp/added" || die "No significant changed source for $path"
  curl --fail --location --show-error --silent --retry 3 --max-time 90 \
    "https://raw.githubusercontent.com/mozilla-firefox/firefox/$release/$path" \
    -o "$tmp/release" || die "Missing exact Firefox 160 source $path"
  content_sha="$(git hash-object -- "$tmp/release")"
  release_sha="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=$release" --jq '.sha')" ||
    die "Release blob SHA missing $path"
  landed_sha="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=$commit" --jq '.sha')" ||
    die "Landed blob SHA missing $path"
  test "$content_sha" = "$release_sha" ||
    die "Downloaded official Firefox 160 source differs from recorded release blob"
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$tmp/release" |
    LC_ALL=C sort -u > "$tmp/release-lines"
  LC_ALL=C comm -23 "$tmp/added" "$tmp/release-lines" > "$tmp/missing"
  test ! -s "$tmp/missing" ||
    die "At least one nontrivial landed security patch addition is absent: $path"
  count="$(wc -l < "$tmp/added")"
  total=$((total+count))
  if test "$content_sha" = "$landed_sha"; then
    classification=exact_landed_blob
  else
    classification=diverged_whole_file_with_selected_additions_retained
  fi
  jq -cn --arg path "$path" --arg landed "$landed_sha" \
    --arg released "$content_sha" --arg class "$classification" \
    --argjson count "$count" '{
      path:$path,landed_blob_sha:$landed,release_blob_sha:$released,
      whole_file_classification:$class,
      nontrivial_landed_added_lines_found_in_release:$count,
      missing_selected_added_lines:0,
      all_patch_hunk_context_and_removed_lines_verified:false,
      full_security_fix_verified:false,
      vulpra_overlaid:false
    }' >> "$tmp/results.jsonl"
  printf 'PASS: %s has %d significant added source lines retained (%s)\n' \
    "$path" "$count" "$classification"
done < "$tmp/expected"
jq -n --slurpfile files "$tmp/results.jsonl" --argjson total "$total" '{
  schema_version:1,kind:"firefox160_cve2026_124859_added_source_lines_check",
  cve:"CVE-2026-124859",mozilla_bug:2074179,
  public_landed_commit:"4b3e088a325ceb62bb355e9abf264f76a0e829f0",
  firefox160_release_commit:"2887d9de1f69c0e9776413da80e7ba0d1225dd9b",
  pinned_vulpra_source_tree:"42dd7439a27dde92f89ac5eed13f88117a4d7ab5",
  files_compared:($files|length),
  nontrivial_added_lines_verified:$total,
  exact_landed_source_blob_count:([$files[]|select(.whole_file_classification=="exact_landed_blob")]|length),
  changed_whole_file_blob_count:([$files[]|select(.whole_file_classification=="diverged_whole_file_with_selected_additions_retained")]|length),
  missing_selected_source_lines:0,
  candidate_overwritten_security_files:0,
  files:$files,
  complete_patch_hunks_and_deleted_lines_checked:false,
  real_exploit_regression_executed:false,
  complete_cve_fix_verified:false,
  security_current:false,release_ready:false
}' > "$report"
jq -e '
  .files_compared==3 and .nontrivial_added_lines_verified>=10 and
  .exact_landed_source_blob_count==1 and .changed_whole_file_blob_count==2 and
  .missing_selected_source_lines==0 and .candidate_overwritten_security_files==0 and
  .complete_cve_fix_verified==false and
  .security_current==false and .release_ready==false
' "$report" >/dev/null || die 'Invalid final bounded security report'
echo "PASS: 3/3 source files; $total nontrivial landed added lines still present in official 160"
echo 'LIMIT: added lines are not full fix-hunk semantics, exploit regression or release acceptance'
