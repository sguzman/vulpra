#!/usr/bin/env bash
set -Eeuo pipefail
RUNNER="${1:?Pass absolute sync-local-safe.sh path}"
R=$(mktemp -d)
trap 'rm -rf -- "$R"' EXIT
root="$R/upstream"
remote="$R/remote.git"
work="$R/work"
emitter="python/mozbuild/mozbuild/frontend/emitter.py"
testing="python/mozbuild/mozbuild/testing.py"
git init -q -b main "$root"
git -C "$root" config user.name "Vulpra test"
git -C "$root" config user.email "test@example.invalid"
mkdir -p "$root/$(dirname "$emitter")" "$root/$(dirname "$testing")"
printf 'before-emitter\n' > "$root/$emitter"
printf 'before-testing\n' > "$root/$testing"
printf 'baseline\n' > "$root/README.md"
git -C "$root" add .
git -C "$root" commit -qm 'Older pinned local build commit'
git clone -q --bare "$root" "$remote"
git -C "$root" remote add origin "$remote"
git clone -q "$remote" "$work"
git -C "$work" config user.name "Vulpra test"
git -C "$work" config user.email "test@example.invalid"
base=$(git -C "$work" rev-parse HEAD)
# Simulate tracked source modifications later committed on GitHub, while the
# still-pinned workstation carries the exact same patches as dirty files.
printf 'patched-emitter\n' > "$root/$emitter"
printf 'patched-testing\n' > "$root/$testing"
printf 'new feature script\n' > "$root/ci.txt"
git -C "$root" add .
git -C "$root" commit -qm 'Remote incorporates workstation compile patches'
git -C "$root" push -q origin main
cp "$root/$emitter" "$work/$emitter"
cp "$root/$testing" "$work/$testing"
test "$(git -C "$work" rev-parse HEAD)" = "$base"
VULPRA_SYNC_ALLOW_TEST_REMOTE=1 bash "$RUNNER" "$work" > "$R/pass.log" 2>&1 || {
  cat "$R/pass.log"
  exit 1
}
grep -Fq 'PASS: Local main fast-forwarded' "$R/pass.log"
test "$(git -C "$work" rev-parse HEAD)" = "$(git -C "$root" rev-parse HEAD)"
test -z "$(git -C "$work" status --porcelain=v1)"
cmp "$root/$emitter" "$work/$emitter"
cmp "$root/$testing" "$work/$testing"
test -s "$work/ci.txt"
backup=$(find "$work/.git/vulpra-native-build/sync-backups" -mindepth 1 -maxdepth 1 -type d | head -n 1)
test -s "$backup/local-changes.patch"
(cd "$backup/files" && sha256sum -c "$backup/local-file-hashes.sha256") >/dev/null
test -s "$backup/commits.txt"
echo 'PASS: patch-identical pinned worktree safely fast-forwards and backs up original files'
# A future ordinary fast-forward while clean should preserve tracked files.
printf 'newest remote script\n' > "$root/ci.txt"
git -C "$root" add ci.txt
git -C "$root" commit -qm 'Later remote update'
git -C "$root" push -q origin main
VULPRA_SYNC_ALLOW_TEST_REMOTE=1 bash "$RUNNER" "$work" > "$R/clean.log" 2>&1 || {
  cat "$R/clean.log"
  exit 1
}
grep -Fq 'PASS: Local main fast-forwarded' "$R/clean.log"
test -z "$(git -C "$work" status --porcelain=v1)"
echo 'PASS: clean local worktree uses normal safe fast-forward without source rewrites'

# One differing local patch must prevent any source modification.
printf 'third remote version\n' > "$root/$emitter"
git -C "$root" add "$emitter"
git -C "$root" commit -qm 'Another upstream change'
git -C "$root" push -q origin main
printf 'personal-only patch\n' > "$work/$emitter"
local_before=$(git -C "$work" rev-parse HEAD)
file_hash_before=$(sha256sum "$work/$emitter" | cut -d' ' -f1)
set +e
VULPRA_SYNC_ALLOW_TEST_REMOTE=1 bash "$RUNNER" "$work" > "$R/mismatch.log" 2>&1
status=$?
set -e
[[ "$status" -eq 6 ]] || { cat "$R/mismatch.log"; echo "FAIL: mismatch returned $status"; exit 2; }
test "$(git -C "$work" rev-parse HEAD)" = "$local_before"
test "$(sha256sum "$work/$emitter" | cut -d' ' -f1)" = "$file_hash_before"
grep -Fq 'differs from remote main' "$R/mismatch.log"
echo 'PASS: different local patch safely refuses sync and preserves commit and file'
# An unrelated dirty file also prevents source modification.
printf 'third remote version\n' > "$work/$emitter"
printf 'other local modifications\n' >> "$work/README.md"
set +e
VULPRA_SYNC_ALLOW_TEST_REMOTE=1 bash "$RUNNER" "$work" > "$R/other.log" 2>&1
status=$?
set -e
[[ "$status" -eq 4 ]] || { cat "$R/other.log"; echo "FAIL: unexpected tracked change returned $status"; exit 3; }
test "$(git -C "$work" rev-parse HEAD)" = "$local_before"
grep -Fq 'Unexpected working-tree change' "$R/other.log"
echo 'PASS: unrelated dirty changes refuse sync before fetch or restoration'
echo 'PASS: guarded workstation Git sync regressions'
