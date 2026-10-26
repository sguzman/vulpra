#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT=${1:?expected build script path}
R=$(mktemp -d)
trap 'rm -rf "$R"' EXIT
mkdir -p "$R/repo/ci" "$R/home/.mozbuild"
cd "$R/repo"
git init -q
git config user.email test@example.invalid
git config user.name 'Local build regression test'
printf 'release mock\n' > ci/mozconfig-linux
printf 'tracked supplemental file\n' > ci/test-file.txt
# Emulate the formerly ignored Breakpad dependency without tracking it in Git.
LSS="$R/repo/toolkit/crashreporter/google-breakpad/src/third_party/lss/linux_syscall_support.h"
mkdir -p "$(dirname "$LSS")"
printf 'mock Breakpad header\n' > "$LSS"
printf 'local wasm sysroot mock\n' > "$R/home/.mozbuild/vulpra-local.mozconfig"
cat > mach <<'MOCK'
#!/usr/bin/env bash
printf 'mock mach invoked with %s\n' "$*"
[[ "$*" == build ]] || exit 8
if [[ "${MOCK_BUILD_EXIT:-0}" == 0 && "${MOCK_SKIP_BINARY:-0}" != 1 ]]; then
  mkdir -p obj-vulpra-linux/dist/bin
  printf '#!/bin/sh\n' > obj-vulpra-linux/dist/bin/firefox
  chmod +x obj-vulpra-linux/dist/bin/firefox
  printf 'Name=Vulpra\n' > obj-vulpra-linux/dist/bin/application.ini
fi
exit "${MOCK_BUILD_EXIT:-0}"
MOCK
chmod +x mach
git add mach ci/mozconfig-linux ci/test-file.txt
git commit -qm 'mock checkout'
if HOME="$R/home" bash "$SCRIPT" "$R/repo" > "$R/pass.log" 2>&1; then
  grep -q 'PASS: Native Vulpra compilation finished successfully' "$R/pass.log" || exit 9
  echo 'PASS: fake native build succeeds; source checks and logging work'
else
  cat "$R/pass.log"
  exit 1
fi
# A native build may succeed before downstream package layout is established.
# Do not relabel a successful compile as a failure based on a guessed file path.
rm -rf "$R/repo/obj-vulpra-linux"
if HOME="$R/home" MOCK_SKIP_BINARY=1 bash "$SCRIPT" "$R/repo" > "$R/compile-only.log" 2>&1; then
  grep -Fq 'PASS: Native Vulpra compilation finished successfully' "$R/compile-only.log" || exit 11
else
  cat "$R/compile-only.log"
  echo 'FAIL: successful compilation incorrectly rejected due to missing package binaries'
  exit 12
fi
echo 'PASS: successful compile accepted without a preexisting packaged binary'
set +e
HOME="$R/home" MOCK_BUILD_EXIT=13 bash "$SCRIPT" "$R/repo" > "$R/fail.log" 2>&1
rc=$?
set -e
[[ "$rc" == 13 ]] || { cat "$R/fail.log"; echo "FAIL: unexpected build error propagation $rc"; exit 2; }
echo 'PASS: failed compilation returns original exit code and log'
git sparse-checkout init --cone >/dev/null
set +e
HOME="$R/home" bash "$SCRIPT" "$R/repo" > "$R/sparse.log" 2>&1
rc=$?
set -e
[[ "$rc" == 3 ]] || { cat "$R/sparse.log"; echo "FAIL: expected sparse refusal $rc"; exit 3; }
echo 'PASS: refuses incomplete sparse checkout'
git sparse-checkout disable >/dev/null
rm mach
set +e
HOME="$R/home" bash "$SCRIPT" "$R/repo" > "$R/missing.log" 2>&1
rc=$?
set -e
[[ "$rc" == 2 ]] || { cat "$R/missing.log"; echo "FAIL: missing file should refuse $rc"; exit 4; }
echo 'PASS: refuses source with missing core file'
# Verify that ordinary missing tracked sources block compilation too.
git checkout -- mach
git sparse-checkout disable >/dev/null
rm ci/test-file.txt
set +e
HOME="$R/home" bash "$SCRIPT" "$R/repo" > "$R/missing-tracked.log" 2>&1
rc=$?
set -e
[[ "$rc" == 3 ]] || { cat "$R/missing-tracked.log"; echo "FAIL: missing tracked source should refuse: $rc"; exit 5; }
echo 'PASS: refuses missing ordinary tracked source'
# Simulate another process holding the build lock, with intact checkout.
git checkout HEAD -- ci/test-file.txt
logdir="$R/repo/.git/vulpra-native-build"
mkdir -p "$logdir"
exec 8> "$logdir/build.lock"
flock 8
set +e
HOME="$R/home" bash "$SCRIPT" "$R/repo" > "$R/locked.log" 2>&1
rc=$?
set -e
[[ "$rc" == 7 ]] || { cat "$R/locked.log"; echo "FAIL: concurrent build should be refused: $rc"; exit 6; }
flock -u 8
echo 'PASS: refuses concurrent native build'
rm -f "$LSS"
set +e
HOME="$R/home" bash "$SCRIPT" "$R/repo" > "$R/ignored-source.log" 2>&1
rc=$?
set -e
[[ "$rc" == 3 ]] || { cat "$R/ignored-source.log"; echo "FAIL: ignored upstream source missing, expected exit 3, got $rc"; exit 7; }
grep -Fq 'Missing upstream Breakpad Linux syscall header' "$R/ignored-source.log"
echo 'PASS: detects omitted gitignored upstream Breakpad header before compilation'
echo 'PASS: all local-build wrapper regressions'
