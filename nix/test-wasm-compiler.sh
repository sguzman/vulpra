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
printf 'PASS: LLVM WASM C/C++ compilers preprocess wasm32-wasi without Nix host flags\n'
