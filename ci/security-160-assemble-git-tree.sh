#!/usr/bin/env bash
# Build a complete, deterministic Firefox 160 + Vulpra overlay Git TREE
# using only Git metadata, sparse checked-out staged blobs, and a separate
# temporary Git index. No reset, clean, branch merge, file deletion, or native
# compilation. The resulting tree object is local to this CI run.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if [[ "$#" != 4 || "$1" != "--assemble" ]]; then
  echo 'Usage: security-160-assemble-git-tree.sh --assemble <official-160-checkout> <verified-stage-dir> <empty-output-dir>' >&2
  exit 2
fi
repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
upstream="$(cd -- "$2" && pwd -P)" || fail 'Firefox 160 repository not found'
stage="$(cd -- "$3" && pwd -P)" || fail 'verified stage not found'
dest="$(realpath -m -- "$4")" || fail 'cannot canonicalize output'
release="2887d9de1f69c0e9776413da80e7ba0d1225dd9b"
test "$(git -C "$upstream" rev-parse HEAD)" = "$release" ||
  fail 'not the authenticated Firefox 160 release'
for source_dir in "$upstream" "$stage" "$repo"; do
  test "$dest" != "$source_dir" || fail 'output overlaps a source root'
  case "$dest/" in "$source_dir/"*) fail 'output may not be nested in any source tree' ;; esac
done
test "$stage" != "$upstream" && test "$stage" != "$repo" ||
  fail 'stage is not an isolated output directory'
test ! -L "$4" || fail 'output path is a symlink'
mkdir -p -- "$dest"
dest="$(cd -- "$dest" && pwd -P)"
test -z "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit)" ||
  fail 'assembly output must start empty'

test -z "$(find "$stage" -type l -print -quit)" ||
  fail 'staging source must not contain symlinks'
test "$(find "$stage" -type f | wc -l)" -eq 28 ||
  fail 'expected exactly 28 verified source files'
source_tree="$(git -C "$upstream" rev-parse HEAD^{tree})"
export GIT_INDEX_FILE="$dest/complete-160-candidate.index"
git -C "$upstream" read-tree "$source_tree"
test "$(git -C "$upstream" write-tree)" = "$source_tree" ||
  fail 'temporary index failed to retain the entire official 160 source tree'

list="$dest/overlay-paths.txt"
: > "$list"
count=0
while IFS= read -r -d '' file; do
  path="$(realpath --relative-to="$stage" -- "$file")"
  test -n "$path" && [[ "$path" != ../* && "$path" != /* ]] ||
    fail "invalid staged source path: $path"
  [[ "$path" != *$'\n'* && "$path" != *$'\t'* ]] ||
    fail 'unexpected whitespace in checked source path'
  old="$(git -C "$upstream" ls-tree HEAD -- "$path")"
  if test -n "$old"; then
    mode="$(printf '%s\n' "$old" | awk 'NR==1 {print $1}')"
    case "$mode" in 100644|100755) ;; *) fail "unexpected original Git mode: $path ($mode)" ;; esac
  else
    # The two Vulpra-only browser/toolkit sources did not exist upstream 160.
    case "$path" in
      browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCardOptOut.jsx|toolkit/components/nimbus/NimbusBootstrap.sys.mjs)
        mode=100644 ;;
      *) fail "unreviewed source addition: $path" ;;
    esac
  fi
  blob="$(git -C "$upstream" hash-object -w -- "$file")" ||
    fail "unable to write temporary source object: $path"
  git -C "$upstream" update-index --add --cacheinfo "$mode" "$blob" "$path"
  printf '%s\n' "$path" >> "$list"
  count=$((count+1))
done < <(find "$stage" -type f -print0)
test "$count" -eq 28 || fail 'staging path count was not exactly 28'

candidate_tree="$(git -C "$upstream" write-tree)" ||
  fail 'unable to create candidate Git tree'
test "$candidate_tree" != "$source_tree" ||
  fail 'candidate tree identical to upstream despite 28 verified overlays'
unset GIT_INDEX_FILE

git -C "$upstream" diff-tree --no-commit-id --name-status -r HEAD "$candidate_tree" \
  > "$dest/changes-against-exact-firefox160.tsv"
git -C "$upstream" diff-tree --no-commit-id --name-only -r HEAD "$candidate_tree" \
  | LC_ALL=C sort > "$dest/changed-paths.txt"
LC_ALL=C sort -o "$list" "$list"
cmp -s "$list" "$dest/changed-paths.txt" ||
  fail 'assembly unexpectedly changed an unapproved file or omitted an overlay'
a="$(awk -F '\t' '$1=="A" {n++} END {print n+0}' "$dest/changes-against-exact-firefox160.tsv")"
m="$(awk -F '\t' '$1=="M" {n++} END {print n+0}' "$dest/changes-against-exact-firefox160.tsv")"
d="$(awk -F '\t' '$1=="D" {n++} END {print n+0}' "$dest/changes-against-exact-firefox160.tsv")"
test "$a" -eq 2 && test "$m" -eq 26 && test "$d" -eq 0 ||
  fail "candidate tree diff not exactly 2 added, 26 modified, 0 deleted: A=$a M=$m D=$d"
test "$(wc -l < "$dest/changed-paths.txt")" -eq 28 ||
  fail 'candidate changed-file count not 28'
for path in \
  mobile/android/fenix/app/build.gradle \
  toolkit/components/moz.build \
  browser/app/profile/firefox.js; do
  # Do not require unchanged trees at the two explicitly modified paths:
  # these are probed for presence in the complete candidate.
  test -n "$(git -C "$upstream" ls-tree "$candidate_tree" -- "$path")" ||
    fail "expected upstream file absent in assembled tree: $path"
done

jq -n \
  --arg firefox160_commit "$release" \
  --arg firefox160_tree "$source_tree" \
  --arg assembled_git_tree "$candidate_tree" \
  --argjson source_files_modified "$m" \
  --argjson vulpra_source_files_added "$a" \
  --argjson upstream_files_deleted "$d" \
  '{
    schema_version: 1,
    kind: "full_firefox_160_git_tree_with_bounded_vulpra_source_overlay",
    firefox160_commit: $firefox160_commit,
    firefox160_tree: $firefox160_tree,
    assembled_git_tree: $assembled_git_tree,
    source_files_modified: $source_files_modified,
    vulpra_source_files_added: $vulpra_source_files_added,
    upstream_files_deleted: $upstream_files_deleted,
    all_other_upstream_files_preserved: true,
    tree_created_in_private_ci_git_database: true,
    git_tree_published_as_repository_branch: false,
    full_checkout_materialized: false,
    browser_configured: false,
    native_binary_compiled: false,
    package_installed: false,
    security_current: false
  }' > "$dest/candidate-tree-report.json"
jq -e --arg sha "$release" \
  '.firefox160_commit==$sha and .source_files_modified==26 and
   .vulpra_source_files_added==2 and .upstream_files_deleted==0 and
   .native_binary_compiled==false and .security_current==false' \
  "$dest/candidate-tree-report.json" >/dev/null
git -C "$upstream" diff --exit-code
git -C "$repo" diff --exit-code
echo "PASS: complete official Firefox 160 Git tree with exactly 26 reviewed modifications + 2 Vulpra source additions"
echo "PASS: 0 upstream deletions, unmodified upstream source retained, candidate tree $candidate_tree"
echo "LIMIT: this is a Git tree assembly and metadata proof; no source checkout, browser build or security-current claim"
