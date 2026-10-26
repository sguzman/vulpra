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
printf 'local wasm sysroot mock\n' > "$R/home/.mozbuild/vulpra-local.mozconfig"
cat > mach <<'MOCK'
#!/usr/bin/env bash
printf 'mock mach invoked with %s\n' "$*"
[[ "$*" == build ]] || exit 8
exit "${MOCK_BUILD_EXIT:-0}"
MOCK
chmod +x mach
git add mach ci/mozconfig-linux
git commit -qm 'mock checkout'
if HOME="$R/home" bash "$SCRIPT" "$R/repo" > "$R/pass.log" 2>&1; then
  grep -q 'PASS: ./mach build returned exit code 0' "$R/pass.log" || exit 9
  echo 'PASS: fake native build succeeds; source checks and logging work'
else
  cat "$R/pass.log"
  exit 1
fi
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
echo 'PASS: all local-build wrapper regressions'
