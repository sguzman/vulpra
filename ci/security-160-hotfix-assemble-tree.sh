#!/usr/bin/env bash
# Assemble a separate full official Firefox 160.0.1 Git tree with exactly the
# already-authenticated Vulpra BYOB 28-file overlay. Git objects/index only.
# No source checkout modifications, full browser build, installation or release.
set -euo pipefail
umask 077
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if [[ "$#" -ne 5 || "$1" != "--assemble" ]]; then
  echo 'Usage: security-160-hotfix-assemble-tree.sh --assemble <official-160-tree> <official-160.0.1-tree> <exact-BYOB-stage> <unused-output-dir>' >&2
  exit 2
fi
old="$(cd -- "$2" && pwd -P)" || fail 'original Firefox 160 checkout unavailable'
new="$(cd -- "$3" && pwd -P)" || fail 'Firefox 160.0.1 checkout unavailable'
stage="$(cd -- "$4" && pwd -P)" || fail 'verified BYOB stage unavailable'
dest="$(realpath -m -- "$5")" || fail 'output destination cannot be resolved'
old_commit=2887d9de1f69c0e9776413da80e7ba0d1225dd9b
new_commit=58fed86b1b6864ad71b83c910a879d6f1a6b678b
[[ "$(git -C "$old" rev-parse HEAD)" == "$old_commit" ]] ||
  fail 'original official Firefox160 source identity mismatch'
[[ "$(git -C "$new" rev-parse HEAD)" == "$new_commit" ]] ||
  fail 'official Firefox160.0.1 source identity mismatch'
[[ ! -L "$5" && ! -e "$dest" ]] || fail 'must use a fresh non-symlink output'
for root in "$old" "$new" "$stage" "$(cd -- "$(dirname -- "$0")/.." && pwd -P)"; do
  [[ "$dest" != "$root" ]] || fail 'output coincides with a source checkout'
  case "$dest/" in "$root/"*) fail 'output nested in an original source checkout' ;; esac
done
[[ "$old" != "$new" && "$new" != "$stage" && "$old" != "$stage" ]] ||
  fail 'all source roots must be distinct'
mkdir -p -- "$dest"
[[ -z "$(find "$stage" -type l -print -quit)" ]] || fail 'source stage contains symlinks'
[[ "$(find "$stage" -type f | wc -l)" -eq 28 ]] ||
  fail 'exactly 28 original BYOB source overlays required'

newtree="$(git -C "$new" rev-parse HEAD^{tree})"
oldtree="$(git -C "$old" rev-parse HEAD^{tree})"
[[ "$newtree" != "$oldtree" ]] || fail 'hotfix tree did not change official source'
export GIT_INDEX_FILE="$dest/firefox160-0-1-vulpra.index"
git -C "$new" read-tree "$newtree"
[[ "$(git -C "$new" write-tree)" == "$newtree" ]] ||
  fail 'separate Git index failed to preserve official full hotfix source'

paths="$dest/overlay-paths.txt"
: > "$paths"
count=0
while IFS= read -r -d '' file; do
  path="$(realpath --relative-to="$stage" -- "$file")"
  [[ -n "$path" && "$path" != /* && "$path" != ../* &&
     "$path" != *$'\n'* && "$path" != *$'\t'* ]] ||
    fail 'unsafe relative BYOB source path'
  old_entry="$(git -C "$old" ls-tree HEAD -- "$path")"
  new_entry="$(git -C "$new" ls-tree HEAD -- "$path")"
  [[ "$old_entry" == "$new_entry" ]] ||
    fail "official hotfix changed a Vulpra overlay base: $path"
  if [[ -n "$new_entry" ]]; then
    mode="$(printf '%s\n' "$new_entry" | awk '{print $1}')"
    case "$mode" in 100644|100755) ;; *) fail "unsafe upstream file mode: $path" ;; esac
  else
    case "$path" in
      browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCardOptOut.jsx|toolkit/components/nimbus/NimbusBootstrap.sys.mjs)
        mode=100644 ;;
      *) fail "unexpected new source path lacking official base: $path" ;;
    esac
  fi
  blob="$(git -C "$new" hash-object -w -- "$file")" ||
    fail "unable to authenticate staged BYOB blob: $path"
  git -C "$new" update-index --add --cacheinfo "$mode" "$blob" "$path"
  printf '%s\n' "$path" >> "$paths"
  count=$((count+1))
done < <(find "$stage" -type f -print0)
[[ "$count" -eq 28 ]] || fail 'incomplete BYOB stage inventory'
LC_ALL=C sort -u -o "$paths" "$paths"
[[ "$(wc -l < "$paths")" -eq 28 ]] || fail 'duplicate or incomplete source path list'

candidate="$(git -C "$new" write-tree)" || fail 'hotfix candidate full tree assembly failed'
[[ "$candidate" != "$newtree" ]] || fail 'candidate source identical to Mozilla despite Vulpra overlays'
unset GIT_INDEX_FILE
git -C "$new" diff-tree --no-commit-id --name-status -r HEAD "$candidate" \
  > "$dest/changed-against-official-hotfix.tsv"
git -C "$new" diff-tree --no-commit-id --name-only -r HEAD "$candidate" |
  LC_ALL=C sort > "$dest/candidate-changed-paths.txt"
cmp -s "$paths" "$dest/candidate-changed-paths.txt" ||
  fail 'unreviewed Git path appeared in complete candidate'
added="$(awk -F '\t' '$1=="A"{n++}END{print n+0}' "$dest/changed-against-official-hotfix.tsv")"
modified="$(awk -F '\t' '$1=="M"{n++}END{print n+0}' "$dest/changed-against-official-hotfix.tsv")"
deleted="$(awk -F '\t' '$1=="D"{n++}END{print n+0}' "$dest/changed-against-official-hotfix.tsv")"
[[ "$added" -eq 2 && "$modified" -eq 26 && "$deleted" -eq 0 ]] ||
  fail "expected 26 Vulpra modifications, two additions and zero removals: $modified/$added/$deleted"
[[ "$(git -C "$new" rev-parse "$candidate:browser/branding/unofficial/pref/firefox-branding.js")" == ae3fd50a6aee0ad58933dca09db39b7b87c0eb5e ]] ||
  fail 'BYOB source branding and identity unexpectedly changed'
git -C "$old" diff --exit-code
git -C "$new" diff --exit-code

jq -n --arg original_commit "$old_commit" --arg hotfix_commit "$new_commit" \
  --arg original_tree "$oldtree" --arg hotfix_tree "$newtree" \
  --arg candidate_tree "$candidate" \
  '{
    schema_version:1,kind:"firefox160_0_1_full_source_with_exact_original_byob_overlay",
    original_release_commit:$original_commit,
    hotfix_release_commit:$hotfix_commit,
    original_release_git_tree:$original_tree,
    hotfix_release_git_tree:$hotfix_tree,
    candidate_git_tree:$candidate_tree,
    source_overlay_count:28,modified_upstream_paths:26,
    vulpra_only_source_additions:2,removed_upstream_paths:0,
    all_overlay_upstream_bases_unchanged_since_160_0:true,
    byob_branding_blob:"ae3fd50a6aee0ad58933dca09db39b7b87c0eb5e",
    all_other_mozilla_hotfix_source_paths_preserved:true,
    candidate_git_tree_assembled_without_checkout:true,
    native_browser_compiled:false,real_browser_runtime_verified:false,
    provider_backed_safebrowsing_verified:false,
    security_current:false,release_ready:false
  }' > "$dest/hotfix-candidate-tree-proof.json"
jq -e '.source_overlay_count==28 and .modified_upstream_paths==26 and
  .vulpra_only_source_additions==2 and .removed_upstream_paths==0 and
  .all_overlay_upstream_bases_unchanged_since_160_0==true and
  .candidate_git_tree_assembled_without_checkout==true and
  .native_browser_compiled==false and .security_current==false and
  .release_ready==false' "$dest/hotfix-candidate-tree-proof.json" >/dev/null
printf 'PASS: complete official 160.0.1 tree retained with 26 Vulpra modifications + 2 added modules\n'
printf 'PASS: zero upstream source deletions; source candidate Git tree %s\n' "$candidate"
printf 'LIMIT: no native compile, target runtime, provider-backed Safe Browsing or release approval\n'
