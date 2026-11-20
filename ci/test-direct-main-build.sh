#!/usr/bin/env bash
# Offline integration test of default direct-main Vulpra build dispatch.
# Uses a tiny synthetic Git checkout + fake mach, NEVER real browser/source.
set -Eeuo pipefail
t="$(mktemp -d)"
trap 'rm -rf -- "$t"' EXIT
source_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
mkdir -p "$t/repo"/{scripts,ci,packaging,nix,browser/config} \
  "$t/repo/toolkit/crashreporter/google-breakpad/src/third_party/lss" \
  "$t/nix-lib"
cp "$source_root/scripts/vulpra-build-160.sh" "$t/repo/scripts/vulpra-build-160.sh"
cp "$source_root/scripts/vulpra-package-160.sh" "$t/repo/scripts/vulpra-package-160.sh"
cp "$source_root/ci/mozconfig-linux" "$t/repo/ci/mozconfig-linux"
cp "$source_root/packaging/vulpra" "$t/repo/packaging/vulpra"
printf '160.0.1\n' > "$t/repo/browser/config/version.txt"
printf 'mock Breakpad header\n' > "$t/repo/toolkit/crashreporter/google-breakpad/src/third_party/lss/linux_syscall_support.h"
cat > "$t/repo/mach" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ -f "$MOZCONFIG" ]] || exit 77
case "$1" in
  configure) echo 'fake configure of current main' ;;
  build)
    mkdir -p obj-vulpra-main-160/dist/bin
    printf '[App]\nName=Vulpra\nVersion=160.0.1\n' > obj-vulpra-main-160/dist/bin/application.ini
    printf '#!/usr/bin/env bash\nexit 0\n' > obj-vulpra-main-160/dist/bin/vulpra
    chmod +x obj-vulpra-main-160/dist/bin/vulpra ;;
  *) exit 78 ;;
esac
MOCK
chmod +x "$t/repo/mach"
git -C "$t/repo" init -qb main
git -C "$t/repo" config user.name 'Vulpra CI'
git -C "$t/repo" config user.email ci@example.invalid
git -C "$t/repo" add .
git -C "$t/repo" commit -qm 'synthetic Firefox160.0.1 main source'
export HOME="$t/home"
mkdir -p "$HOME"
bash "$t/repo/scripts/vulpra-build-160.sh" --status > "$t/status"
grep -Fq 'Tracked source version: 160.0.1' "$t/status"
grep -Fq 'Native Firefox 160.0.1 Vulpra: missing' "$t/status"
bash "$t/repo/scripts/vulpra-build-160.sh" --preflight > "$t/ready"
grep -Fq 'source is committed and materialized on main' "$t/ready"
set +e
bash "$t/repo/scripts/vulpra-build-160.sh" --fetch-source > "$t/denied" 2>&1
code="$?"
set -e
test "$code" -eq 2
grep -Fq 'obsolete and disabled' "$t/denied"
VULPRA_NIX_DEV=1 VULPRA_NIX_LIBCLANG_PATH="$t/nix-lib" \
  bash "$t/repo/scripts/vulpra-build-160.sh" --jobs 3 > "$t/build-output"
grep -Fq 'PASS: compiled committed main' "$t/build-output"
grep -Fq 'MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-main-160' \
  "$HOME/.cache/vulpra/main160/mozconfig"
grep -Fq 'MOZ_PARALLEL_BUILD=3' "$HOME/.cache/vulpra/main160/mozconfig"
grep -Fq 'Name=Vulpra' "$t/repo/obj-vulpra-main-160/dist/bin/application.ini"
grep -Fq 'Version=160.0.1' "$t/repo/obj-vulpra-main-160/dist/bin/application.ini"
bash "$t/repo/scripts/vulpra-package-160.sh" --preflight > "$t/package-ready"
grep -Fq 'available for packaging' "$t/package-ready"
bash "$t/repo/scripts/vulpra-build-160.sh" --status > "$t/after"
grep -Fq 'Native Firefox 160.0.1 Vulpra: compiled' "$t/after"
test ! -e "$t/repo/obj-vulpra-linux"
git -C "$t/repo" checkout -qb alternate
set +e
bash "$t/repo/scripts/vulpra-build-160.sh" --preflight > "$t/wrong-branch" 2>&1
code="$?"
set -e
test "$code" -eq 2
grep -Fq 'expected main branch' "$t/wrong-branch"
test ! -e "$t/home/.mozilla"
echo 'PASS: main-only source; no Mozilla fetch; independent objdir; configure/build; package preflight'
