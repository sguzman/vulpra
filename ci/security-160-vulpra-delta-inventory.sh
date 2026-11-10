#!/usr/bin/env bash
# Compare ENTIRE Git trees, not a sparse working tree or installed browser.
# Requires authenticated and already-fetched Mozilla 159.0b5 commit.
# No file blobs, source mutation, rebuild, pruning or 160 rebase.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if [[ "$#" != 3 || "$1" != "--inventory" ]]; then
  echo 'Usage: security-160-vulpra-delta-inventory.sh --inventory <fetched-mozilla-159-beta-sha> <empty-output-dir>' >&2
  exit 2
fi
repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
expected_beta="34ac0671eb25f31f8c56ace36e1c413dd471eb8d"
test "$2" = "$expected_beta" || fail 'non-authenticated upstream baseline ref'
git -C "$repo" cat-file -e "$expected_beta^{commit}" ||
  fail 'authenticated upstream beta commit not in CI Git object store'

mkdir -p -- "$3"
out="$(cd -- "$3" && pwd -P)"
test "$out" != "$repo" || fail 'never write into source root'
case "$out/" in "$repo/"*) fail 'output may not be inside Vulpra source' ;; esac
test -z "$(find "$out" -mindepth 1 -maxdepth 1 -print -quit)" ||
  fail 'output directory must start empty'

head="$(git -C "$repo" rev-parse HEAD)"
test -n "$head"
base_tree="$(git -C "$repo" rev-parse "$expected_beta^{tree}")"
head_tree="$(git -C "$repo" rev-parse "$head^{tree}")"
raw="$out/inventory-z.tmp"
git -C "$repo" diff --no-renames --name-status -z "$expected_beta" "$head" > "$raw"
test -s "$raw" || fail 'unexpected empty whole-tree diff'

countA=0
countD=0
countM=0
countT=0
total=0
outfile="$out/vulpra-modifications-vs-mozilla-159-beta.tsv"
printf 'status\tpath\n' > "$outfile"
while IFS= read -r -d '' status && IFS= read -r -d '' path; do
  test -n "$path" || fail 'empty Git path'
  [[ "$path" != *$'\t'* && "$path" != *$'\n'* ]] ||
    fail "tab/newline Git path needs escaped serialization: $path"
  case "$status" in
    A) countA=$((countA+1)) ;;
    D) countD=$((countD+1)) ;;
    M) countM=$((countM+1)) ;;
    T) countT=$((countT+1)) ;;
    *) fail "unexpected diff status: $status" ;;
  esac
  printf '%s\t%s\n' "$status" "$path" >> "$outfile"
  total=$((total+1))
done < "$raw"
rm -f -- "$raw"
test "$total" -gt 0 || fail 'no source changes counted'
test "$((countA+countD+countM+countT))" -eq "$total" ||
  fail 'status count mismatch'

dirs_tsv="$out/directory-change-counts.tsv"
printf 'root\tchanges\n' > "$dirs_tsv"
awk -F'\t' 'NR > 1 { split($2, p, "/"); counts[p[1]]++ }
  END { for (root in counts) print root "\t" counts[root] }' "$outfile" |
  LC_ALL=C sort >> "$dirs_tsv"

jq -n \
  --arg source_commit "$head" \
  --arg mozilla_beta_commit "$expected_beta" \
  --arg mozilla_beta_tree "$base_tree" \
  --arg vulpra_tree "$head_tree" \
  --argjson total "$total" \
  --argjson added "$countA" \
  --argjson deleted "$countD" \
  --argjson modified "$countM" \
  --argjson type_changed "$countT" \
  --rawfile directory_counts "$dirs_tsv" \
  '{
    schema_version: 1,
    kind: "vulpra_vs_authenticated_firefox_159_beta_full_git_tree_delta",
    source_commit: $source_commit,
    mozilla_beta_commit: $mozilla_beta_commit,
    mozilla_beta_tree: $mozilla_beta_tree,
    vulpra_tree: $vulpra_tree,
    counts: {total:$total, added:$added, deleted:$deleted,
      modified:$modified, type_changed:$type_changed},
    directory_counts_tsv: $directory_counts,
    tree_diff_was_complete: true,
    only_git_trees_inspected: true,
    file_contents_downloaded_for_diff: false,
    includes_unrelated_ci_docs_artifacts: true,
    complete_rebase_plan: false,
    firefox_160_upgrade_performed: false,
    machine_native_build_performed: false,
    user_source_or_browser_modified: false,
    security_current: false
  }' > "$out/vulpra-full-delta-summary.json"
jq -e \
  --arg sha "$head" \
  --arg beta "$expected_beta" \
  --argjson total "$total" '
    .source_commit == $sha and .mozilla_beta_commit == $beta and
    .counts.total == $total and
    (.counts.added + .counts.deleted + .counts.modified + .counts.type_changed) == $total and
    .tree_diff_was_complete == true and
    .file_contents_downloaded_for_diff == false and
    .security_current == false
  ' "$out/vulpra-full-delta-summary.json" >/dev/null
echo "PASS: whole Vulpra vs Mozilla 159 beta Git tree inventory; $total changed paths"
printf 'STATUS: A=%s D=%s M=%s T=%s\n' "$countA" "$countD" "$countM" "$countT"
echo 'LIMIT: change inventory (including CI/docs), not an applied 160 rebase or security-current claim'
