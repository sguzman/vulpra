#!/usr/bin/env bash
# Compare complete official Firefox 160.0 and 160.0.1 Git trees, not GitHub's
# truncated compare API. No checkout, source mutation, build, or release.
set -euo pipefail
umask 077

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

if [[ "$#" != 2 || "$1" != "--audit" ]]; then
  echo 'Usage: security-160-hotfix-source-delta.sh --audit <new-empty-output-directory>' >&2
  exit 2
fi

old=2887d9de1f69c0e9776413da80e7ba0d1225dd9b
new=58fed86b1b6864ad71b83c910a879d6f1a6b678b
dest="$(realpath -m -- "$2")"
[[ ! -L "$2" ]] || fail 'output may not be a symlink'
[[ ! -e "$dest" ]] || fail 'output directory must not already exist'
case "$dest" in
  /|/home|/tmp|/mnt|/mnt/data) fail 'refusing ambiguous output root' ;;
esac
mkdir -p -- "$dest"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
git init -q "$work/mozilla"
git -C "$work/mozilla" remote add origin https://github.com/mozilla-firefox/firefox.git

# Resolve official tags, and independently pin to the two previously accepted
# Mozilla Git commit identities. Fetch commit+tree objects, not source blobs.
tag_refs="$(git -C "$work/mozilla" ls-remote --tags origin \
  refs/tags/FIREFOX_160_0_RELEASE refs/tags/FIREFOX_160_0_1_RELEASE)" ||
  fail 'official release tag lookup failed'
printf '%s\n' "$tag_refs" | grep -Fqx "$old"$'\trefs/tags/FIREFOX_160_0_RELEASE' ||
  fail 'official 160.0 tag drift'
printf '%s\n' "$tag_refs" | grep -Fqx "$new"$'\trefs/tags/FIREFOX_160_0_1_RELEASE' ||
  fail 'official 160.0.1 tag drift'
git -C "$work/mozilla" fetch -q --no-tags --filter=blob:none --depth=1 origin \
  +refs/tags/FIREFOX_160_0_RELEASE:refs/tags/FIREFOX_160_0_RELEASE \
  +refs/tags/FIREFOX_160_0_1_RELEASE:refs/tags/FIREFOX_160_0_1_RELEASE ||
  fail 'official pinned source-tree fetch failed'
[[ "$(git -C "$work/mozilla" rev-parse 'refs/tags/FIREFOX_160_0_RELEASE^{commit}')" == "$old" ]] ||
  fail 'fetched 160.0 tag mismatch'
[[ "$(git -C "$work/mozilla" rev-parse 'refs/tags/FIREFOX_160_0_1_RELEASE^{commit}')" == "$new" ]] ||
  fail 'fetched 160.0.1 tag mismatch'

old_tree="$(git -C "$work/mozilla" rev-parse "$old^{tree}")"
new_tree="$(git -C "$work/mozilla" rev-parse "$new^{tree}")"
[[ "$old_tree" != "$new_tree" ]] || fail 'release trees unexpectedly identical'
git -C "$work/mozilla" diff --no-renames --name-status -z "$old" "$new" > "$work/changed.z" ||
  fail 'complete upstream diff failed'

: > "$dest/changed-paths.tsv"
added=0 modified=0 deleted=0 typechanged=0
while IFS= read -r -d '' status && IFS= read -r -d '' path; do
  [[ -n "$path" && "$path" != *$'\n'* && "$path" != *$'\t'* ]] ||
    fail 'upstream path not safely representable as TSV'
  case "$status" in
    A) added=$((added+1)) ;;
    M) modified=$((modified+1)) ;;
    D) deleted=$((deleted+1)) ;;
    T) typechanged=$((typechanged+1)) ;;
    *) fail "unexpected Git status (no renames expected): $status" ;;
  esac
  printf '%s\t%s\n' "$status" "$path" >> "$dest/changed-paths.tsv"
done < "$work/changed.z"
total=$((added+modified+deleted+typechanged))
[[ "$total" -gt 0 && "$total" -eq "$(wc -l < "$dest/changed-paths.tsv")" ]] ||
  fail 'incomplete Git tree diff parsing'
[[ "$total" -gt 300 ]] || fail 'expected full tree inventory beyond compare API 300-file cap'
LC_ALL=C sort -k2,2 -o "$dest/changed-paths.tsv" "$dest/changed-paths.tsv"

# Precise high-priority source paths: verify these actually differ between
# official release trees; source presence is NOT runtime patch acceptance.
for path in dom/media/ChannelMediaDecoder.cpp gfx/gl/GLBlitHelper.cpp; do
  before="$(git -C "$work/mozilla" ls-tree "$old" -- "$path" | awk '{print $3}')"
  after="$(git -C "$work/mozilla" ls-tree "$new" -- "$path" | awk '{print $3}')"
  [[ "$before" =~ ^[0-9a-f]{40}$ && "$after" =~ ^[0-9a-f]{40}$ && "$before" != "$after" ]] ||
    fail "required hotfix source path not changed: $path"
  grep -Fqx $'M\t'"$path" "$dest/changed-paths.tsv" ||
    fail "required hotfix path absent from full diff: $path"
done

# Derive the exact 28 staged source paths from the current, accepted Firefox
# 160 staging contract. This is an overlap INVENTORY, not an overlay port.
stage_script="$(cd -- "$(dirname -- "$0")" && pwd -P)/security-160-stage-overlay.sh"
[[ -f "$stage_script" ]] || fail 'original source-overlay contract missing'
{
  grep -oE 'hash_is "\$dest/[^"]+"' "$stage_script" |
    sed -E 's|^hash_is "\$dest/||;s|"$||' | grep -v '^\$path https://github.com/mozilla-firefox/firefox \
  --arg old_release FIREFOX_160_0_RELEASE --arg old_commit "$old" --arg old_tree "$old_tree" \
  --arg new_release FIREFOX_160_0_1_RELEASE --arg new_commit "$new" --arg new_tree "$new_tree" \
  --argjson added "$added" --argjson modified "$modified" \
  --argjson deleted "$deleted" --argjson typechanged "$typechanged" \
  --argjson total "$total" \
  --argjson overlay_total "$overlay_total" --argjson overlay_changed "$overlay_changed" \
  '{
    schema_version:1, kind:"complete_mozilla_firefox_160_to_160_0_1_git_tree_delta",
    upstream_repository:$upstream_repository,
    original:{tag:$old_release,commit:$old_commit,git_tree:$old_tree},
    hotfix:{tag:$new_release,commit:$new_commit,git_tree:$new_tree},
    full_git_tree_diff_verified:true,
    git_diff_renames_disabled:true,
    counts:{added:$added,modified:$modified,deleted:$deleted,
            typechanged:$typechanged,total:$total},
    changed_path_listing:"changed-paths.tsv",
    overlay_paths_total:$overlay_total,
    overlay_paths_extracted_from_staging_contract:true,
    overlay_upstream_changed_paths_count:$overlay_changed,
    overlay_paths_listing:"overlay-paths.txt",
    overlay_overlap_paths_listing:"overlay-upstream-overlap-paths.txt",
    priority_source_paths_changed:["dom/media/ChannelMediaDecoder.cpp",
                                   "gfx/gl/GLBlitHelper.cpp"],
    overlay_compatibility_verified:false,
    candidate_source_tree_assembled:false,
    native_binary_compiled:false,
    native_browser_retested:false,
    provider_backed_safebrowsing_verified:false,
    security_current:false,release_ready:false
  }' > "$dest/hotfix-source-delta.json"
jq -e '.schema_version==1 and .full_git_tree_diff_verified==true and
  .counts.total==(.counts.added+.counts.modified+.counts.deleted+.counts.typechanged) and
  .overlay_paths_total==28 and
  .overlay_upstream_changed_paths_count>=0 and
  .overlay_compatibility_verified==false and .native_binary_compiled==false and
  .security_current==false and .release_ready==false' "$dest/hotfix-source-delta.json" >/dev/null
printf 'PASS: full official Firefox 160.0 -> 160.0.1 Git tree diff: %s changed paths\n' "$total"
printf 'PASS: audio/video and graphics source paths changed; original release tags and trees authenticated\n'
printf 'PASS: 28 existing Vulpra overlay paths inventoried; %s intersect official hotfix changes\n' "$overlay_changed"
printf 'LIMIT: overlay adaptation, recompilation, native security and release readiness NOT accepted\n'

  sed -n "/^done <<'PINNED_STABLE_BASE_OVERLAYS'$/,/^PINNED_STABLE_BASE_OVERLAYS$/p" "$stage_script" |
    sed '1d;$d' | awk '{print $1}'
  grep -E "^  '(browser/|toolkit/)[^ ]+ [0-9a-f]{40}'" "$stage_script" |
    sed -E "s|^  '([^ ]+) .*|\1|"
} | LC_ALL=C sort -u > "$dest/overlay-paths.txt"
overlay_total="$(wc -l < "$dest/overlay-paths.txt")"
[[ "$overlay_total" -eq 28 ]] || fail 'source staging overlay inventory drifted from 28'
grep -Fxq 'browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCardOptOut.jsx' "$dest/overlay-paths.txt" ||
  fail 'missing expected Vulpra-added PromoCard module'
grep -Fxq 'toolkit/components/nimbus/NimbusBootstrap.sys.mjs' "$dest/overlay-paths.txt" ||
  fail 'missing expected Vulpra-added Nimbus bootstrap module'
cut -f2 "$dest/changed-paths.tsv" | LC_ALL=C sort -u > "$work/upstream-changed-paths"
comm -12 "$dest/overlay-paths.txt" "$work/upstream-changed-paths" > "$dest/overlay-upstream-overlap-paths.txt"
overlay_changed="$(wc -l < "$dest/overlay-upstream-overlap-paths.txt")"
[[ "$overlay_changed" -ge 0 && "$overlay_changed" -le 28 ]] ||
  fail 'invalid overlay conflict count'
# The two original Vulpra-only files may not silently become upstream files.
for source_added in \
  browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCardOptOut.jsx \
  toolkit/components/nimbus/NimbusBootstrap.sys.mjs; do
  [[ -z "$(git -C "$work/mozilla" ls-tree "$new" -- "$source_added")" ]] ||
    fail "official hotfix unexpectedly owns an original Vulpra-only source path: $source_added"
done

jq -n \
  --arg upstream_repository https://github.com/mozilla-firefox/firefox \
  --arg old_release FIREFOX_160_0_RELEASE --arg old_commit "$old" --arg old_tree "$old_tree" \
  --arg new_release FIREFOX_160_0_1_RELEASE --arg new_commit "$new" --arg new_tree "$new_tree" \
  --argjson added "$added" --argjson modified "$modified" \
  --argjson deleted "$deleted" --argjson typechanged "$typechanged" \
  --argjson total "$total" \
  '{
    schema_version:1, kind:"complete_mozilla_firefox_160_to_160_0_1_git_tree_delta",
    upstream_repository:$upstream_repository,
    original:{tag:$old_release,commit:$old_commit,git_tree:$old_tree},
    hotfix:{tag:$new_release,commit:$new_commit,git_tree:$new_tree},
    full_git_tree_diff_verified:true,
    git_diff_renames_disabled:true,
    counts:{added:$added,modified:$modified,deleted:$deleted,
            typechanged:$typechanged,total:$total},
    changed_path_listing:"changed-paths.tsv",
    priority_source_paths_changed:["dom/media/ChannelMediaDecoder.cpp",
                                   "gfx/gl/GLBlitHelper.cpp"],
    overlay_compatibility_verified:false,
    candidate_source_tree_assembled:false,
    native_binary_compiled:false,
    native_browser_retested:false,
    provider_backed_safebrowsing_verified:false,
    security_current:false,release_ready:false
  }' > "$dest/hotfix-source-delta.json"
jq -e '.schema_version==1 and .full_git_tree_diff_verified==true and
  .counts.total==(.counts.added+.counts.modified+.counts.deleted+.counts.typechanged) and
  .overlay_compatibility_verified==false and .native_binary_compiled==false and
  .security_current==false and .release_ready==false' "$dest/hotfix-source-delta.json" >/dev/null
printf 'PASS: full official Firefox 160.0 -> 160.0.1 Git tree diff: %s changed paths\n' "$total"
printf 'PASS: audio/video and graphics source paths changed; original release tags and trees authenticated\n'
printf 'LIMIT: overlay adaptation, recompilation, native security and release readiness NOT accepted\n'
