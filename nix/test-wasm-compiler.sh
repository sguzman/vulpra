#!/usr/bin/env bash
set -euo pipefail

# Gecko's WASM configure probes need raw LLVM: Nix's host cc-wrapper
# injects host-only hardening flags that fail for wasm32-wasi.
: "${WASM_CC:?WASM_CC missing from the developer shell}"
: "${WASM_CXX:?WASM_CXX missing from the developer shell}"
[[ -x "$WASM_CC" ]] || { echo "Not executable: WASM_CC=$WASM_CC" >&2; exit 1; }
[[ -x "$WASM_CXX" ]] || { echo "Not executable: WASM_CXX=$WASM_CXX" >&2; exit 1; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
cat > "$scratch/target.c" <<'SRC'
#if !defined(__wasm32__) || !defined(__wasi__)
#error WASM_CC did not select wasm32-wasi
#endif
SRC
cat > "$scratch/target.cpp" <<'SRC'
#if !defined(__wasm32__) || !defined(__wasi__)
#error WASM_CXX did not select wasm32-wasi
#endif
SRC
"$WASM_CC" --target=wasm32-wasi -E -o /dev/null "$scratch/target.c"
"$WASM_CXX" --target=wasm32-wasi -E -o /dev/null "$scratch/target.cpp"
# The previous preprocess-only test missed the absent compiler-rt archive.
# Exercise real WASI links, as Mozilla's configure requires.
cat > "$scratch/link.c" <<'SRC'
int main(void) { return 0; }
SRC
cat > "$scratch/link.cpp" <<'SRC'
int main() { return 0; }
SRC
"$WASM_CC" --target=wasm32-wasi "$scratch/link.c" -o "$scratch/link-c.wasm"
"$WASM_CXX" --target=wasm32-wasi "$scratch/link.cpp" -o "$scratch/link-cxx.wasm"
[[ -s "$scratch/link-c.wasm" && -s "$scratch/link-cxx.wasm" ]] || {
  printf 'ERROR: wasm32-wasi link outputs missing\n' >&2
  exit 1
}
printf 'PASS: WASM C/C++ preprocess and link wasm32-wasi with compiler-rt\n'
