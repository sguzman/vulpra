#!/usr/bin/env bash
# Integrate the ACTUAL Mozilla Firefox 160.0.1 source and verified Vulpra delta
# directly on main. GitHub Actions only; no force push, no local computer.
set -Eeuo pipefail
umask 077
fail() { echo "Vulpra 160 main integration: $*" >&2; exit 2; }
[[ "$GITHUB_ACTIONS" == true &&
   "$GITHUB_REPOSITORY" == sguzman/vulpra &&
   "$GITHUB_REF" == refs/heads/main &&
   "$VULPRA_INTEGRATE_FIREFOX160" == 1 ]] ||
  fail 'main-only authorized GitHub Actions job required'
repo="$(git rev-parse --show-toplevel)"
[[ "$(git -C "$repo" branch --show-current)" == main ]] ||
  fail 'checkout is not main'
base="$(git -C "$repo" rev-parse HEAD)"
[[ "$(cat "$repo/browser/config/version.txt")" == 159.0 ]] ||
  fail 'main was not Firefox 159 at job start; fail closed'

old_sha=2887d9de1f69c0e9776413da80e7ba0d1225dd9b
new_sha=58fed86b1b6864ad71b83c910a879d6f1a6b678b
candidate_sha=d6f7faf6583831a58d127480db54b5bcd5ab5949
old="$repo/upstream160"
new="$repo/upstream160hotfix"
[[ "$(git -C "$old" rev-parse HEAD)" == "$old_sha" &&
   "$(git -C "$new" rev-parse HEAD)" == "$new_sha" ]] ||
  fail 'official Mozilla source release identities mismatch'

tmp="$RUNNER_TEMP/vulpra160-main-integration"
[[ ! -e "$tmp" ]] || fail 'integration scratch already exists'
mkdir -p -- "$tmp"
bash "$repo/ci/security-160-stage-overlay.sh" --stage "$old" "$tmp/stage-original"
bash "$repo/ci/security-160-stage-byob-branding.sh" --derive \
  "$tmp/stage-original" "$repo/browser/branding/unofficial/pref/firefox-branding.js" \
  "$tmp/stage-byob"
bash "$repo/ci/security-160-hotfix-assemble-tree.sh" --assemble \
  "$old" "$new" "$tmp/stage-byob" "$tmp/proof"
jq -e --arg want "$candidate_sha" \
  '.candidate_git_tree==$want and .source_overlay_count==28 and
   .modified_upstream_paths==26 and .vulpra_only_source_additions==2 and
   .removed_upstream_paths==0' \
  "$tmp/proof/hotfix-candidate-tree-proof.json" > /dev/null ||
  fail 'Vulpra source tree proof mismatch'
[[ "$(wc -l < "$tmp/proof/overlay-paths.txt")" == 28 ]] ||
  fail 'source overlay inventory incomplete'

# Full official source Git objects are fetched onto the disposable runner,
# not onto the user's workstation or into the old Vulpra checkout.
git -C "$repo" -c http.version=HTTP/1.1 fetch --no-tags --depth=1 \
  https://github.com/mozilla-firefox/firefox.git refs/tags/FIREFOX_160_0_1_RELEASE
[[ "$(git -C "$repo" rev-parse FETCH_HEAD)" == "$new_sha" ]] ||
  fail 'full official 160.0.1 source identity mismatch'

index="$tmp/final.index"
export GIT_INDEX_FILE="$index"
git -C "$repo" read-tree "$new_sha^{tree}"
count=0
while IFS= read -r file; do
  [[ -n "$file" && "$file" != /* && "$file" != ../* &&
     "$file" != */../* ]] || fail "unsafe overlay path: $file"
  [[ -f "$tmp/stage-byob/$file" && ! -L "$tmp/stage-byob/$file" ]] ||
    fail "overlay missing: $file"
  mode="$(git -C "$repo" ls-files --stage -- "$file" | awk '{print $1}')"
  if [[ -z "$mode" ]]; then
    case "$file" in
      browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCardOptOut.jsx|toolkit/components/nimbus/NimbusBootstrap.sys.mjs) mode=100644 ;;
      *) fail "unreviewed source addition: $file" ;;
    esac
  fi
  [[ "$mode" == 100644 || "$mode" == 100755 ]] || fail "unexpected mode: $file"
  blob="$(git -C "$repo" hash-object -w -- "$tmp/stage-byob/$file")"
  git -C "$repo" update-index --add --cacheinfo "$mode" "$blob" "$file"
  count=$((count + 1))
done < "$tmp/proof/overlay-paths.txt"
[[ "$count" == 28 ]] || fail 'incomplete overlays'
[[ "$(git -C "$repo" write-tree)" == "$candidate_sha" ]] ||
  fail 'real source candidate tree is not verified Vulpra160.0.1 tree'

# Preserve Vulpra-specific README, documentation, CI, Nix, and scripts.
# Everything else is the actual official Firefox160.0.1 + 28-file Vulpra delta.
git -C "$repo" restore --source="$base" --staged -- \
  .github ci nix scripts packaging docs/vulpra AGENTS.md CLAUDE.md README.md
final_tree="$(git -C "$repo" write-tree)"
[[ "$(git -C "$repo" show "$final_tree:browser/config/version.txt")" == 160.0.1 ]] ||
  fail 'final tree is not 160.0.1'
[[ "$(git -C "$repo" rev-parse "$final_tree:browser/branding/unofficial/pref/firefox-branding.js")" == ae3fd50a6aee0ad58933dca09db39b7b87c0eb5e ]] ||
  fail 'Vulpra branding changed'
for path in AGENTS.md CLAUDE.md README.md ci/security-160-stage-overlay.sh nix/vulpra; do
  [[ "$(git -C "$repo" rev-parse "$final_tree:$path")" == "$(git -C "$repo" rev-parse "$base:$path")" ]] ||
    fail "project-owned source not preserved: $path"
done

unset GIT_INDEX_FILE
export GIT_AUTHOR_NAME='Vulpra Source Integration'
export GIT_AUTHOR_EMAIL='github-actions[bot]@users.noreply.github.com'
export GIT_COMMITTER_NAME='Vulpra Source Integration'
export GIT_COMMITTER_EMAIL='github-actions[bot]@users.noreply.github.com'
new_commit="$(printf 'source: integrate Firefox 160.0.1 and Vulpra patches on main\n\nMozilla: %s\nAuthenticated source tree: %s\nNo branch, no force push; previous main is parent.\n' "$new_sha" "$candidate_sha" |
  git -C "$repo" commit-tree "$final_tree" -p "$base")"
[[ "$(git -C "$repo" rev-list --parents -n 1 "$new_commit")" == "$new_commit $base" ]] ||
  fail 'integration commit lost main ancestry'
echo "Prepared main commit:   $new_commit"
echo "Original main commit:   $base"
echo "Mozilla source commit:  $new_sha"
echo "Vulpra source tree:     $candidate_sha"
git -C "$repo" push origin "$new_commit:refs/heads/main"
echo "PASS: Firefox 160.0.1 SOURCE committed to main; native browser build still pending"
