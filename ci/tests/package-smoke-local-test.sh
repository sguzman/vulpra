#!/usr/bin/env bash
set -Eeuo pipefail
RUNNER=${1:?Pass package-smoke-local.sh path}
FIXTURES=${2:?Pass local packaging scripts directory}
R=$(mktemp -d)
trap 'rm -rf "$R"' EXIT
mkdir -p "$R/repo/packaging" "$R/home/.mozbuild" "$R/repo/obj-vulpra-linux/dist/bin"
cp "$FIXTURES/stage.sh" "$FIXTURES/vulpra" "$R/repo/packaging/"
cd "$R/repo"
git init -q
git config user.name Test
git config user.email test@example.invalid
printf 'mock mozconfig\n' > "$R/home/.mozbuild/vulpra-local.mozconfig"
printf 'Name=Vulpra\n' > obj-vulpra-linux/dist/bin/application.ini
cat > obj-vulpra-linux/dist/bin/firefox <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
for ((i=1;i<=$#;i++)); do
  if [[ "${!i}" == --screenshot ]]; then
    j=$((i+1))
    printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlV3y8AAAAASUVORK5CYII=' | base64 -d > "${!j}"
  fi
done
MOCK
chmod +x obj-vulpra-linux/dist/bin/firefox
cat > mach <<'MACH'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$1" == package ]] || exit 2
if [[ "${MOCK_PACKAGE_EXIT:-0}" != 0 ]]; then exit "$MOCK_PACKAGE_EXIT"; fi
mkdir -p obj-vulpra-linux/dist/package-input/firefox
cp "obj-vulpra-linux/dist/bin/${MOCK_BROWSER_NAME:-firefox}" "obj-vulpra-linux/dist/package-input/firefox/"
cp obj-vulpra-linux/dist/bin/application.ini obj-vulpra-linux/dist/package-input/firefox/
tar -cJf obj-vulpra-linux/dist/native-browser.tar.xz -C obj-vulpra-linux/dist/package-input .
MACH
chmod +x mach
git add mach packaging
git commit -qm 'Package test fixture'
HOME="$R/home" VULPRA_SKIP_WAYLAND=1 bash "$RUNNER" "$R/repo" > "$R/success.log" 2>&1 || { cat "$R/success.log"; exit 1; }
grep -Fq 'PASS: Vulpra packaged and launched headlessly with private profile' "$R/success.log"
test "$(find "$R/repo/.git/vulpra-native-build/packages" -name '*.tar.xz' | wc -l)" -eq 1
test "$(find "$R/repo/.git/vulpra-native-build" -name 'package-smoke-*.png' | wc -l)" -eq 1
echo 'PASS: native package staging, checksum, isolated profile and PNG screenshot'
# Vulpra may itself be the executable name. Ensure packaging does not
# overwrite the native binary with its new private-profile launcher.
mv "$R/repo/obj-vulpra-linux/dist/bin/firefox" "$R/repo/obj-vulpra-linux/dist/bin/vulpra"
HOME="$R/home" VULPRA_SKIP_WAYLAND=1 MOCK_BROWSER_NAME=vulpra bash "$RUNNER" "$R/repo" > "$R/vulpra.log" 2>&1 || {
  cat "$R/vulpra.log"; exit 1;
}
grep -Fq 'PASS: Vulpra packaged and launched headlessly with private profile' "$R/vulpra.log"
echo 'PASS: standalone package runner supports native executable named vulpra'
mv "$R/repo/obj-vulpra-linux/dist/bin/vulpra" "$R/repo/obj-vulpra-linux/dist/bin/firefox"
set +e
HOME="$R/home" VULPRA_SKIP_WAYLAND=1 MOCK_PACKAGE_EXIT=19 bash "$RUNNER" "$R/repo" > "$R/failure.log" 2>&1
rc=$?
set -e
[[ $rc -eq 19 ]] || { cat "$R/failure.log"; echo "FAIL: package error not preserved: $rc"; exit 2; }
echo 'PASS: failed native packaging preserves original exit status'
chmod -x "$R/repo/obj-vulpra-linux/dist/bin/firefox"
set +e
HOME="$R/home" VULPRA_SKIP_WAYLAND=1 bash "$RUNNER" "$R/repo" > "$R/missing-binary.log" 2>&1
rc=$?
set -e
[[ $rc -eq 4 ]] || { cat "$R/missing-binary.log"; echo "FAIL: missing executable not rejected: $rc"; exit 3; }
echo 'PASS: refuses absent compiled executable'
chmod +x "$R/repo/obj-vulpra-linux/dist/bin/firefox"
logdir="$R/repo/.git/vulpra-native-build"
exec 8>"$logdir/build.lock"
flock 8
set +e
HOME="$R/home" VULPRA_SKIP_WAYLAND=1 bash "$RUNNER" "$R/repo" > "$R/lock.log" 2>&1
rc=$?
set -e
[[ $rc -eq 7 ]] || { cat "$R/lock.log"; echo "FAIL: lock not enforced: $rc"; exit 4; }
flock -u 8
echo 'PASS: refuses simultaneous build/package'
echo 'PASS: all package and smoke runner regressions'
