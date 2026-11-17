#!/usr/bin/env bash
# Offline reproduction of build-lock inheritance. No real browser or compiler.
set -Eeuo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
work="$(mktemp -d)"
cleanup() {
  for pidfile in "$work/repo"/last-helper-*; do
    [[ -f "$pidfile" ]] || continue
    IFS= read -r pid < "$pidfile" || true
    if [[ "$pid" =~ ^[0-9]+$ ]]; then kill "$pid" 2>/dev/null || true; fi
  done
  rm -rf -- "$work"
}
trap cleanup EXIT
repo="$work/repo"
mkdir -p "$repo/ci" "$repo/toolkit/crashreporter/google-breakpad/src/third_party/lss" \
  "$repo/obj-vulpra-linux/dist/bin" "$repo/mockpackage/vulpra"
git -C "$repo" init -q
printf '%s\n' '# mock mozconfig' > "$work/mozconfig"
printf '%s\n' '# mock Linux mozconfig' > "$repo/ci/mozconfig-linux"
printf '%s\n' '# mock upstream header' > "$repo/toolkit/crashreporter/google-breakpad/src/third_party/lss/linux_syscall_support.h"
printf 'Name=Vulpra\n' > "$repo/obj-vulpra-linux/dist/bin/application.ini"
cp "$repo/obj-vulpra-linux/dist/bin/application.ini" "$repo/mockpackage/vulpra/application.ini"
cat > "$repo/mockpackage/vulpra/vulpra" <<'BROWSER'
#!/usr/bin/env bash
set -Eeuo pipefail
while (( $# )); do
  if [[ "$1" == --screenshot ]]; then
    shift
    printf '\x89PNG\r\n\x1a\nmock' > "$1"
    break
  fi
  shift
done
BROWSER
chmod +x "$repo/mockpackage/vulpra/vulpra"
cp "$repo/mockpackage/vulpra/vulpra" "$repo/obj-vulpra-linux/dist/bin/vulpra"
cat > "$repo/mach" <<'MACH'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$1" in
  build|package)
    (sleep 15) </dev/null >/dev/null 2>&1 &
    printf '%s\n' "$!" > "$PWD/last-helper-$1"
    if [[ "$1" == package ]]; then
      tar -cJf obj-vulpra-linux/dist/vulpra-fixture.tar.xz -C mockpackage vulpra
    fi
    ;;
  *) exit 2 ;;
esac
MACH
chmod +x "$repo/mach"
git -C "$repo" add -A
git -C "$repo" -c user.name='Vulpra QA' -c user.email='qa@example.invalid' commit -qm fixture
env MOZCONFIG="$work/mozconfig" bash "$here/build-local.sh" "$repo" > "$work/build.log" 2>&1 || {
  cat "$work/build.log" >&2; echo 'FAIL: mock native build' >&2; exit 1;
}
lock="$(git -C "$repo" rev-parse --path-format=absolute --git-path vulpra-native-build)/build.lock"
[[ -f "$repo/last-helper-build" ]] || { echo 'FAIL: mock surviving build child missing' >&2; exit 1; }
kill -0 "$(cat "$repo/last-helper-build")"
flock -n "$lock" -c true || {
  echo 'FAIL: successful build left the lock held by a surviving helper' >&2; exit 1;
}
env MOZCONFIG="$work/mozconfig" bash "$here/package-smoke-local.sh" "$repo" > "$work/package.log" 2>&1 || {
  cat "$work/package.log" >&2; echo 'FAIL: mock native package' >&2; exit 1;
}
[[ -f "$repo/last-helper-package" ]] || { echo 'FAIL: mock surviving package child missing' >&2; exit 1; }
kill -0 "$(cat "$repo/last-helper-package")"
flock -n "$lock" -c true || {
  echo 'FAIL: successful package left the lock held by a surviving helper' >&2; exit 1;
}
grep -Fq 'PASS: Vulpra packaged and launched headlessly with private profile' "$work/package.log" || {
  cat "$work/package.log" >&2; echo 'FAIL: mock packaged runtime did not pass' >&2; exit 1;
}
echo 'PASS: build and package retain mutual exclusion but do not leak lock to surviving helpers (offline mocks only).'
