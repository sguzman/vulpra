#!/usr/bin/env bash
# Real cc/ar fixture for path discovery only; no actual Firefox claims.
set -euo pipefail
locator=ci/m3-locate-gkrust-archive.sh
bash -n "$locator"
tmp="$(mktemp -d)"
trap "rm -rf -- '$tmp'" EXIT
obj="$tmp/obj"
mkdir -p "$obj/dist/bin" "$obj/toolkit/library/rust" "$obj/alternate" "$obj/second"
cat > "$tmp/ffi.c" <<'C'
void GkRust_Init(void) {}
void GkRust_Shutdown(void) {}
C
cc -fPIC -c "$tmp/ffi.c" -o "$tmp/ffi.o"
cc -shared "$tmp/ffi.o" -o "$obj/dist/bin/libxul.so"
ar rcs "$tmp/libgkrust.a" "$tmp/ffi.o"
test -s "$tmp/libgkrust.a" || exit 1

cp "$tmp/libgkrust.a" "$obj/toolkit/library/rust/libgkrust.a"
actual="$(bash "$locator" "$obj")"
test "$actual" = "$(realpath "$obj/toolkit/library/rust/libgkrust.a")"

# A single different location is acceptable only when the expected path
# is absent and there is exactly one real regular archive candidate.
rm "$obj/toolkit/library/rust/libgkrust.a"
cp "$tmp/libgkrust.a" "$obj/alternate/libgkrust.a"
actual="$(bash "$locator" "$obj")"
test "$actual" = "$(realpath "$obj/alternate/libgkrust.a")"

cp "$tmp/libgkrust.a" "$obj/second/libgkrust.a"
if bash "$locator" "$obj" > "$tmp/invalid" 2>/dev/null; then
  echo "FAIL: accepted two ambiguous compiled Rust archives" >&2; exit 1
fi
test ! -s "$tmp/invalid"
rm "$obj/second/libgkrust.a" "$obj/alternate/libgkrust.a"

if bash "$locator" "$obj" > "$tmp/invalid" 2>/dev/null; then
  echo "FAIL: accepted missing compiled Rust archive" >&2; exit 1
fi
test ! -s "$tmp/invalid"

# The untrusted expected path cannot be a link outside the object directory.
ln -s "$tmp/libgkrust.a" "$obj/toolkit/library/rust/libgkrust.a"
if bash "$locator" "$obj" > "$tmp/invalid" 2>/dev/null; then
  echo "FAIL: accepted symlink-escaped Rust archive" >&2; exit 1
fi
rm "$obj/toolkit/library/rust/libgkrust.a"

cp "$tmp/libgkrust.a" "$obj/alternate/libgkrust.a"
rm "$obj/dist/bin/libxul.so"
if bash "$locator" "$obj" > "$tmp/invalid" 2>/dev/null; then
  echo "FAIL: accepted missing compiled consumer ELF" >&2; exit 1
fi

# Crucial Bash regression: this expression does NOT abort a script with -e.
test -f "$tmp/missing" && test -f "$tmp/ffi.o"
echo "PASS: actual compiler/ar archive discovered at exact and unique fallback paths"
echo "PASS: missing/ambiguous archive, escaped symlink and missing ELF all rejected"
echo "PASS: test A && test B is not relied upon for native file existence"
