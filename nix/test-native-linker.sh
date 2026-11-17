#!/usr/bin/env bash
# Regression: native GCC linking must never select WASI compiler-rt/libgcc.
# The native SQLite libmozsqlite3.so linker failed after cross CC was included
# as a mkShell package, contaminating its native linker search paths.
set -euo pipefail

[[ "${VULPRA_NIX_DEV:-}" == 1 ]] || {
  echo 'ERROR: native linker smoke requires the Vulpra Nix devShell' >&2
  exit 1
}
: "${WASM_CC:?WASI compiler must remain available by explicit path}"
[[ -x "$WASM_CC" ]] || {
  echo "ERROR: WASM_CC is not executable: $WASM_CC" >&2
  exit 1
}
# Avoid cross-target wrapper flags in the common native linker environment.
for key in NIX_LDFLAGS NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK LIBRARY_PATH; do
  value="${!key-}"
  case "$value" in
    *wasm32*|*wasi32*|*unknown-wasi*)
      echo "ERROR: cross-target path has contaminated native $key: $value" >&2
      exit 1
      ;;
  esac
done

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
# Dynamic 128-bit division requires the native libgcc compiler runtime.
# A WASI libgcc.a chosen by the x86_64 linker reproduces the original error.
cat > "$scratch/divide.c" <<'SRC'
__attribute__((visibility("default")))
unsigned __int128 vulpra_divide(unsigned __int128 a, unsigned __int128 b) {
  return a / b;
}
SRC
"${CC:-gcc}" -std=gnu17 -O2 -fPIC -shared -Wl,-z,defs \
  -Wl,-z,relro -Wl,-z,now -Wl,--gc-sections \
  -o "$scratch/libvulpra-native-link-smoke.so" "$scratch/divide.c" -ldl -lm
file "$scratch/libvulpra-native-link-smoke.so" | grep -Fq 'ELF 64-bit'
file "$scratch/libvulpra-native-link-smoke.so" | grep -Fq 'x86-64'
echo 'PASS: native x86_64 GCC shared link resolves libgcc without WASI contamination'
