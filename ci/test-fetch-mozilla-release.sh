#!/usr/bin/env bash
set -euo pipefail
t="$(mktemp -d)"
trap 'rm -rf -- "$t"' EXIT
repo="${VULPRA_TEST_REPO:?set VULPRA_TEST_REPO to checkout root}"
baseline="$(git -C "$repo" status --porcelain)"
git init -q "$t/upstream"
git -C "$t/upstream" config user.name 'Vulpra CI'
git -C "$t/upstream" config user.email ci@example.invalid
git -C "$t/upstream" config uploadpack.allowFilter true
mkdir -p "$t/upstream/browser"
printf 'Mozilla pinned release fixture\n' > "$t/upstream/browser/moz.configure"
git -C "$t/upstream" add .
git -C "$t/upstream" commit -qm 'official-source-fixture'
want="$(git -C "$t/upstream" rev-parse HEAD)"
url="file://$t/upstream"
# No pinned tag yet: two fetch attempts fail but leave an intact Git repo.
set +e
bash "$repo/scripts/fetch-mozilla-release.sh" "$t/partial" \
  FIREFOX_160_0_1_RELEASE "$want" "$url" > "$t/failure" 2>&1
first="$?"
set -e
test "$first" -eq 2
test -d "$t/partial/.git"
test "$(git -C "$t/partial" remote get-url origin)" = "$url"
test "$(git -C "$t/partial" config --get http.version)" = HTTP/1.1
# Remote becomes available: reuse the same existing source cache, not a
# replacement clone. Confirm identity and contents, then idempotent reuse.
git -C "$t/upstream" tag FIREFOX_160_0_1_RELEASE
bash "$repo/scripts/fetch-mozilla-release.sh" "$t/partial" \
  FIREFOX_160_0_1_RELEASE "$want" "$url"
test "$(git -C "$t/partial" rev-parse HEAD)" = "$want"
cmp "$t/upstream/browser/moz.configure" "$t/partial/browser/moz.configure"
test -z "$(git -C "$t/partial" status --porcelain)"
bash "$repo/scripts/fetch-mozilla-release.sh" "$t/partial" \
  FIREFOX_160_0_1_RELEASE "$want" "$url"
# Existing unrelated paths and repositories are always preserved.
mkdir -p "$t/foreign"
echo 'must survive' > "$t/foreign/important"
set +e
bash "$repo/scripts/fetch-mozilla-release.sh" "$t/foreign" \
  FIREFOX_160_0_1_RELEASE "$want" "$url" > "$t/foreign-failure" 2>&1
foreign_exit="$?"
set -e
test "$foreign_exit" -eq 2
test "$(cat "$t/foreign/important")" = 'must survive'
grep -Fq 'preserved:' "$t/foreign-failure"
# Interrupted fetch makes no changes to parent checkout / global Git config.
test "$(git -C "$repo" status --porcelain)" = "$baseline"
echo 'PASS: safe failed fetch retained; successful retry and idempotent reuse; foreign data untouched'
