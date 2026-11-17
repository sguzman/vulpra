#!/usr/bin/env bash
# Nix source-preserving mozconfig bridge contract, no browser build.
set -euo pipefail
overlay="${1:-$(dirname -- "${BASH_SOURCE[0]}")/mozconfig-overlay.sh}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/original.mozconfig" <<'MOZCONFIG'
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-linux
ac_add_options --with-branding=browser/branding/unofficial
ac_add_options --with-wasi-sysroot=/usr/share/wasi-sysroot
MOZCONFIG
mkdir -p "$tmp/clang/lib"
: > "$tmp/clang/lib/libclang.so"
export VULPRA_MOZCONFIG_SOURCE="$tmp/original.mozconfig"
export VULPRA_NIX_LIBCLANG_PATH="$tmp/clang/lib"
export TEST_CAPTURE="$tmp/capture"

sh -n "$overlay"
# Exercise this file exactly as Mozilla's mozconfig loader does: POSIX sh.
sh -c '
  mk_add_options() { printf "mk %s\n" "$*" >> "$TEST_CAPTURE"; }
  ac_add_options() { printf "ac %s\n" "$*" >> "$TEST_CAPTURE"; }
  . "$1"
' sh "$overlay"
printf 'mk %s\n' 'MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-linux' > "$tmp/expected"
printf 'ac %s\n' '--with-branding=browser/branding/unofficial' >> "$tmp/expected"
printf 'ac %s\n' '--with-wasi-sysroot=/usr/share/wasi-sysroot' >> "$tmp/expected"
printf 'ac --with-libclang-path=%s\n' "$VULPRA_NIX_LIBCLANG_PATH" >> "$tmp/expected"
cmp "$tmp/expected" "$tmp/capture"
test "$(wc -l < "$tmp/capture")" -eq 4
grep -Fxq 'ac_add_options --with-wasi-sysroot=/usr/share/wasi-sysroot' "$tmp/original.mozconfig"
echo 'PASS: Nix libclang bridge preserves source mozconfig and appends exactly one option'
