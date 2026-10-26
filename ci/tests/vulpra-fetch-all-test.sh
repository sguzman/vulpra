#!/usr/bin/env bash
# Offline integration regression checks for Vulpra's partial-clone downloader.
set -Eeuo pipefail
REAL_GIT=$(command -v git)
DOWNLOADER="$1"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
setup_remote() {
  "$REAL_GIT" init -q "$ROOT/source"
  "$REAL_GIT" -C "$ROOT/source" config user.email 'build-test@example.invalid'
  "$REAL_GIT" -C "$ROOT/source" config user.name 'Vulpra source downloader test'
  mkdir -p "$ROOT/source/ci" "$ROOT/source/docs"
  printf 'preserve this initial file\n' > "$ROOT/source/ci/user-edit.txt"
  for n in $(seq 1 24); do
    mkdir -p "$ROOT/source/source-$((n%4))"
    printf 'tracked file %03d %03d\n' "$n" "$((n*n))" > "$ROOT/source/source-$((n%4))/data-$n.txt"
  done
  printf '#!/bin/sh\nexit 0\n' > "$ROOT/source/ci/executable.sh"
  chmod +x "$ROOT/source/ci/executable.sh"
  ln -s ../ci/user-edit.txt "$ROOT/source/docs/symlink"
  # Test durable blob storage with an incompressible multi-megabyte source.
  mkdir -p "$ROOT/source/assets"
  dd if=/dev/urandom of="$ROOT/source/assets/large.bin" bs=1M count=5 status=none
  "$REAL_GIT" -C "$ROOT/source" add .
  "$REAL_GIT" -C "$ROOT/source" commit -qm 'Source test fixtures'
  "$REAL_GIT" clone -q --bare "$ROOT/source" "$ROOT/remote.git"
  "$REAL_GIT" -C "$ROOT/remote.git" config uploadpack.allowFilter true
}
setup_clone() {
  local dest="$1"
  "$REAL_GIT" clone -q --filter=blob:none --no-checkout "file://$ROOT/remote.git" "$dest"
  "$REAL_GIT" -C "$dest" sparse-checkout init --cone
  "$REAL_GIT" -C "$dest" sparse-checkout set ci
  "$REAL_GIT" -C "$dest" checkout -q
  "$REAL_GIT" -C "$dest" config remote.origin.promisor true
  "$REAL_GIT" -C "$dest" config remote.origin.partialclonefilter blob:none
}
assert_finished() {
  local dest="$1"
  [[ "$($REAL_GIT -C "$dest" config --bool core.sparseCheckout || true)" != true ]] || fail "sparse checkout not disabled"
  [[ -L "$dest/docs/symlink" ]] || fail "symlink not restored"
  [[ -x "$dest/ci/executable.sh" ]] || fail "executable bit not restored"
  [[ -e "$dest/source-0/data-24.txt" ]] || fail "tracked source not restored"
  cmp "$ROOT/source/assets/large.bin" "$dest/assets/large.bin" || fail 'large blob contents changed or missing'
  GIT_NO_LAZY_FETCH=1 "$REAL_GIT" -C "$dest" fsck --full --no-reflogs --unreachable >/dev/null 2> "$ROOT/fsck-stderr" || fail "Git object integrity invalid"
}
setup_remote
setup_clone "$ROOT/happy"
printf 'preserve this initial file\nlocal tracked edit\n' > "$ROOT/happy/ci/user-edit.txt"
env VULPRA_BATCH_SIZE=3 bash "$DOWNLOADER" "$ROOT/happy" > "$ROOT/happy.log" 2>&1 || { tail -35 "$ROOT/happy.log"; fail 'ordinary partial-clone recovery failed'; }
assert_finished "$ROOT/happy"
grep -Fq 'local tracked edit' "$ROOT/happy/ci/user-edit.txt" || fail 'local user modification lost'
grep -Fq 'SUCCESS: Complete tracked HEAD source checkout' "$ROOT/happy.log" || fail 'completion marker absent'
echo 'PASS: complete source, symlinks, mode bits, local edits, object integrity'

# Allow the first two tiny fetches and simulate disconnection afterward.
# Previously completed objects must remain valid and reusable after restart.
mkdir -p "$ROOT/bin"
cat > "$ROOT/bin/git" <<'SHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
for arg in "$@"; do
  if [[ "$arg" == fetch ]]; then
    count=0
    [[ ! -f "$VULPRA_TEST_COUNT_FILE" ]] || read -r count < "$VULPRA_TEST_COUNT_FILE"
    count=$((count + 1))
    printf '%d\n' "$count" > "$VULPRA_TEST_COUNT_FILE"
    if ((count > 2)); then
      echo 'fatal: simulated network reset' >&2
      exit 128
    fi
    break
  fi
done
exec "$VULPRA_REAL_GIT" "$@"
SHIM
chmod +x "$ROOT/bin/git"
setup_clone "$ROOT/interrupted"
set +e
PATH="$ROOT/bin:$PATH" VULPRA_REAL_GIT="$REAL_GIT" VULPRA_TEST_COUNT_FILE="$ROOT/count" VULPRA_BATCH_SIZE=3 VULPRA_SINGLE_RETRIES=1 bash "$DOWNLOADER" "$ROOT/interrupted" > "$ROOT/interrupted.log" 2>&1
failure=$?
set -e
((failure != 0)) || fail 'simulated network disconnection unexpectedly succeeded'
grep -Fq 'simulated network reset' "$ROOT/interrupted.log" || fail 'failure not exercised'
INDEX="$ROOT/interrupted/.git/vulpra-complete-source/blobs-$($REAL_GIT -C "$ROOT/interrupted" rev-parse HEAD).txt"
missing_before=$(GIT_NO_LAZY_FETCH=1 "$REAL_GIT" -C "$ROOT/interrupted" cat-file --batch-check='%(objectname) %(objecttype)' < "$INDEX" | awk '$2=="missing"{n++} END {print n+0}')
total=$(wc -l < "$INDEX")
((missing_before > 0 && missing_before < total)) || fail 'successful prior batches were not retained'
env VULPRA_BATCH_SIZE=3 bash "$DOWNLOADER" "$ROOT/interrupted" > "$ROOT/resume.log" 2>&1 || { tail -25 "$ROOT/resume.log"; fail 'retry did not resume'; }
assert_finished "$ROOT/interrupted"
grep -Fq 'SUCCESS: Complete tracked HEAD source checkout' "$ROOT/resume.log" || fail 'retry missing success marker'
echo "PASS: disconnected with $missing_before/$total still missing; earlier batches retained; retry completed"

# A second downloader must fail rather than compete over one shared state dir.
setup_clone "$ROOT/locked"
mkdir -p "$ROOT/locked/.git/vulpra-complete-source"
exec 8> "$ROOT/locked/.git/vulpra-complete-source/download.lock"
flock 8
set +e
env VULPRA_BATCH_SIZE=3 bash "$DOWNLOADER" "$ROOT/locked" > "$ROOT/locked.log" 2>&1
blocked=$?
set -e
((blocked == 3)) || fail "concurrent run not rejected (exit=$blocked)"
grep -Fq 'already running' "$ROOT/locked.log" || fail 'lock rejection message missing'
flock -u 8
echo 'PASS: concurrent downloader rejected cleanly'

echo 'PASS: all Vulpra source-download regressions'
