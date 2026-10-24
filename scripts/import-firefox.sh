#!/usr/bin/env bash
set -euo pipefail

# GitHub Actions bootstrap only. upstream-base receives untouched source files.
: "$GITHUB_WORKSPACE"
: "$GITHUB_REPOSITORY"
: "$GH_TOKEN"
if [[ "$GITHUB_REPOSITORY" != "sguzman/vulpra" || "$GITHUB_REF" != "refs/heads/main" ]]; then
  echo "Refusing to import outside sguzman/vulpra main" >&2
  exit 1
fi

version="159.0b5"
tag="FIREFOX_159_0b5_RELEASE"
upstream_sha="34ac0671eb25f31f8c56ace36e1c413dd471eb8d"
archive="firefox-$version.source.tar.xz"
root_url="https://archive.mozilla.org/pub/firefox/releases/$version"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "::group::Check Mozilla tag"
actual_sha="$(curl -fsSL --retry 3 "https://api.github.com/repos/mozilla-firefox/firefox/git/ref/tags/$tag" | jq -r '.object.sha')"
[[ "$actual_sha" == "$upstream_sha" ]] || { echo "Upstream tag target differs" >&2; exit 1; }
echo "$tag -> $actual_sha"
echo "::endgroup::"

if git ls-remote --exit-code --heads origin upstream-base >/dev/null; then
  echo "upstream-base already exists: inspect branch before resuming; never overwrite" >&2
  exit 1
fi

echo "::group::Download and verify release source"
curl -fL --retry 3 --retry-all-errors "$root_url/source/$archive" -o "$work/$archive"
curl -fL --retry 3 --retry-all-errors "$root_url/SHA256SUMS" -o "$work/SHA256SUMS"
expected="$(awk -v a="$archive" '$NF == a || $NF == ("source/" a) || $NF == ("./source/" a) {print $1}' "$work/SHA256SUMS")"
[[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || { echo "Missing/ambiguous official SHA-256 checksum" >&2; exit 1; }
printf '%s  %s\n' "$expected" "$work/$archive" | sha256sum --check --status
echo "Verified SHA-256: $expected"
echo "::endgroup::"

echo "::group::Unpack and check source paths"
mkdir -p "$work/source"
tar -xJf "$work/$archive" --strip-components=1 -C "$work/source"
echo "Unpacked root entries:"
ls -la "$work/source" | sed -n '1,45p'
echo "Directory sizes:"
du -sh "$work/source"
echo "Candidate mach/license paths:"
find "$work/source" -maxdepth 4 \( -name mach -o -name LICENSE -o -name Cargo.toml \) -print | sed -n '1,40p'
for p in mach toolkit/content/license.html.mako LICENSE Cargo.toml; do
  if [[ ! -f "$work/source/$p" ]]; then
    echo "Missing required file: $p" >&2
    exit 1
  fi
done
echo "::endgroup::"

echo "::group::Commit pristine release snapshot into upstream-base"
mkdir -p "$work/baseline"
# Hardlinks conserve limited runner disk; no source contents are modified.
cp -al "$work/source/." "$work/baseline/"
git -C "$work/baseline" init -q -b upstream-base
git -C "$work/baseline" config user.name "github-actions[bot]"
git -C "$work/baseline" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$work/baseline" config core.autocrlf false
git -C "$work/baseline" add --all --force
git -C "$work/baseline" commit -qm "Import pristine Mozilla Firefox $version source archive ($tag)"
git -C "$work/baseline" fsck --no-reflogs
git -C "$work/baseline" remote add origin "https://x-access-token:$GH_TOKEN@github.com/$GITHUB_REPOSITORY.git"
git -C "$work/baseline" push --porcelain origin HEAD:refs/heads/upstream-base
echo "::endgroup::"

echo "::group::Attach baseline ancestry and stage main"
cd "$GITHUB_WORKSPACE"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git fetch --no-tags origin upstream-base
git merge -s ours --allow-unrelated-histories --no-edit -m "Connect pristine Firefox source baseline" FETCH_HEAD

# Preserve Vulpra's own README, AGENTS and Actions. Baseline contains all
# original Mozilla files. Replace the template MIT root LICENSE with Mozilla's.
rsync -a --link-dest="$work/source" \
  --exclude='/.git/' \
  --exclude='/.github/' \
  --exclude='/README.md' \
  --exclude='/AGENTS.md' \
  --exclude='/docs/vulpra/' \
  "$work/source/" "$GITHUB_WORKSPACE/"
sed -i "s/Archive digest: \\*\\*not yet recorded\\*\\*/Archive digest (SHA-256): \`$expected\`/" docs/vulpra/UPSTREAM.md
git add --all
git commit -m "Import Firefox $version as Vulpra development base"
git fsck --no-reflogs
git push --porcelain origin HEAD:refs/heads/main
echo "::endgroup::"
echo "Source imported. Verify remote branch contents and build before marking browser working."
