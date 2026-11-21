#!/usr/bin/env bash
# Audit the entire CURRENT Vulpra main Git tree against official Firefox 160.0.1.
# Source trees only; never check out Mozilla files, build, install, or touch profiles.
set -Eeuo pipefail
umask 077

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ "$#" == 2 && "$1" == --audit ]] ||
  fail 'Usage: security-160-main-source-audit.sh --audit <new-output-directory>'
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ "$(git -C "$repo" rev-parse --is-inside-work-tree)" == true ]] ||
  fail 'missing Vulpra Git repository'
[[ "${GITHUB_REF:-refs/heads/main}" == refs/heads/main ]] ||
  fail 'must audit main, not an upgrade candidate'
head="$(git -C "$repo" rev-parse HEAD^{commit})"
[[ -z "${GITHUB_SHA:-}" || "$head" == "$GITHUB_SHA" ]] ||
  fail 'checked-out source does not match the workflow commit'
expected=58fed86b1b6864ad71b83c910a879d6f1a6b678b
tag=FIREFOX_160_0_1_RELEASE
remote=https://github.com/mozilla-firefox/firefox.git
dest="$(realpath -m -- "$2")"
[[ ! -L "$2" && ! -e "$dest" && "$dest" != / ]] ||
  fail 'output directory must be new, not a symlink or filesystem root'
case "$dest/" in "$repo/"*) fail 'refusing output inside the source checkout' ;; esac
mkdir -p -m 0700 -- "$dest"

# Resolve the official tag before downloading any tree objects; reject tag drift.
resolved="$(git -C "$repo" ls-remote --tags "$remote" "refs/tags/$tag")" ||
  fail 'official Mozilla release tag lookup failed'
[[ "$resolved" == "$expected"$'\t'"refs/tags/$tag" ]] ||
  fail 'official Mozilla release tag identity changed'
git -C "$repo" fetch -q --no-tags --filter=blob:none --depth=1 \
  "$remote" "refs/tags/$tag" ||
  fail 'unable to fetch the official commit and Git-tree objects'
actual="$(git -C "$repo" rev-parse 'FETCH_HEAD^{commit}')"
[[ "$actual" == "$expected" ]] ||
  fail 'fetched Mozilla release is not the authenticated 160.0.1 commit'
mozilla_tree="$(git -C "$repo" rev-parse "$expected^{tree}")"
vulpra_tree="$(git -C "$repo" rev-parse "$head^{tree}")"
[[ "$mozilla_tree" =~ ^[[:xdigit:]]{40}$ && "$vulpra_tree" =~ ^[[:xdigit:]]{40}$ ]] ||
  fail 'missing exact complete Git trees'

# Reconcile the three previously reviewed hotfix/version paths against live
# full-tree blob objects, instead of assuming they survived source integration.
hotfix="$dest/reviewed-source-blobs.tsv"
printf 'path\tmozilla_blob\tvulpra_blob\n' > "$hotfix"
while IFS=$'\t' read -r path expected_blob; do
  [[ -n "$path" && "$expected_blob" =~ ^[0-9a-f]{40}$ ]] ||
    fail 'invalid pinned hotfix path'
  upstream="$(git -C "$repo" rev-parse "$expected:$path")" ||
    fail "missing official hotfix path: $path"
  downstream="$(git -C "$repo" rev-parse "$head:$path")" ||
    fail "missing current Vulpra hotfix path: $path"
  [[ "$upstream" == "$expected_blob" && "$downstream" == "$expected_blob" ]] ||
    fail "Firefox 160.0.1 reviewed source blob changed: $path"
  printf '%s\t%s\t%s\n' "$path" "$upstream" "$downstream" >> "$hotfix"
done <<'REVIEWED'
dom/media/ChannelMediaDecoder.cpp	d688d7ec968395490c84c308eb0ddc241a7ba2ea
gfx/gl/GLBlitHelper.cpp	0fb43a1429ef359313ebae7873ac3b2cd20fea64
browser/config/version.txt	9aab5b81294c1aeb29b4b926c76bb1e52c617cd6
REVIEWED

# NUL-delimited Git diff is complete even when GitHub's compare API truncates
# at 300 files. Disallow silently mangled tabs/newlines in report serialization.
raw="$dest/changed-names.z"
git -C "$repo" diff --no-renames --name-status -z "$expected" "$head" > "$raw" ||
  fail 'full tree diff could not be enumerated'
changes="$dest/all-changed-paths.tsv"
critical="$dest/security-sensitive-changed-paths.tsv"
printf 'status\tpath\n' > "$changes"
printf 'status\tpath\n' > "$critical"
added=0; deleted=0; modified=0; typechanged=0; sensitive=0; total=0
while IFS= read -r -d '' status && IFS= read -r -d '' path; do
  [[ -n "$path" && "$path" != *$'\t'* && "$path" != *$'\n'* ]] ||
    fail 'Git path not safely serializable as TSV'
  case "$status" in
    A) added=$((added+1)) ;;
    D) deleted=$((deleted+1)) ;;
    M) modified=$((modified+1)) ;;
    T) typechanged=$((typechanged+1)) ;;
    *) fail "unexpected diff status: $status" ;;
  esac
  printf '%s\t%s\n' "$status" "$path" >> "$changes"
  case "$path" in
    browser/*|caps/*|dom/*|gfx/*|ipc/*|js/*|netwerk/*|security/*|toolkit/*|widget/*|xpcom/*|modules/libpref/*)
      printf '%s\t%s\n' "$status" "$path" >> "$critical"
      sensitive=$((sensitive+1)) ;;
  esac
  total=$((total+1))
done < "$raw"
rm -f -- "$raw"
[[ "$total" -gt 0 && "$total" -eq "$((added+deleted+modified+typechanged))" ]] ||
  fail 'invalid complete diff counters'
[[ "$(wc -l < "$changes")" -eq "$((total+1))" ]] ||
  fail 'complete diff path listing did not reconcile'
[[ "$(wc -l < "$critical")" -eq "$((sensitive+1))" ]] ||
  fail 'security-sensitive path listing did not reconcile'
printf 'source_root\tchanged_paths\n' > "$dest/source-root-counts.tsv"
awk -F '\t' 'NR>1 {split($2,a,"/"); counts[a[1]]++}
END {for (k in counts) print k "\t" counts[k]}' "$changes" |
  LC_ALL=C sort >> "$dest/source-root-counts.tsv"
jq -n --arg head "$head" --arg head_tree "$vulpra_tree" \
  --arg release "$expected" --arg release_tree "$mozilla_tree" \
  --argjson added "$added" --argjson deleted "$deleted" \
  --argjson modified "$modified" --argjson typechanged "$typechanged" \
  --argjson total "$total" --argjson sensitive "$sensitive" '{
    schema_version:1,
    kind:"vulpra_main_vs_official_firefox_160_0_1_full_git_tree_delta",
    current_main_commit:$head, current_main_tree:$head_tree,
    official_release:"FIREFOX_160_0_1_RELEASE",
    official_release_commit:$release, official_release_tree:$release_tree,
    reviewed_hotfix_source_blobs_identical:3,
    counts:{added:$added,deleted:$deleted,modified:$modified,
            typechanged:$typechanged,total:$total,security_sensitive_paths:$sensitive},
    full_tree_diff_enumerated:true,
    path_inventory_created:true,
    all_changes_reviewed_for_security:false,
    full_mozilla_advisory_patch_coverage_verified:false,
    native_browser_compiled_or_tested:false,
    on_target_sandbox_verified:false,
    provider_backed_safebrowsing_verified:false,
    security_current:false, release_ready:false
  }' > "$dest/source-audit-summary.json"
jq -e --arg head "$head" --arg release "$expected" '
  .current_main_commit==$head and .official_release_commit==$release and
  .full_tree_diff_enumerated==true and .reviewed_hotfix_source_blobs_identical==3 and
  .counts.total == (.counts.added+.counts.deleted+.counts.modified+.counts.typechanged) and
  .counts.security_sensitive_paths>=0 and
  .all_changes_reviewed_for_security==false and
  .native_browser_compiled_or_tested==false and
  .security_current==false and .release_ready==false' \
  "$dest/source-audit-summary.json" >/dev/null ||
  fail 'source audit JSON failed security limitations / counter checks'
printf 'PASS: official Firefox 160.0.1 tag authenticated; current main vs Mozilla complete Git-tree path audit\n'
printf 'PASS: 3/3 reviewed hotfix/version source Git blobs identical to Mozilla\n'
printf 'CHANGED: total %s, added %s, deleted %s, modified %s, typechanged %s; security-sensitive paths %s\n' \
  "$total" "$added" "$deleted" "$modified" "$typechanged" "$sensitive"
echo 'LIMIT: path-only inventory, NOT full patch review, compiled-binary validation or security-release approval'
