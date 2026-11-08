#!/usr/bin/env bash
# Fail-closed discovery of the actual current Mozilla-built crash helper Rust
# staticlib, for a future source-pinned compiled archive-member audit.
# No binary execution, source changes, extraction or pruning.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: m3-locate-crashhelper-archive.sh COMPILED_OBJDIR" >&2
  exit 2
fi

obj="$(realpath -e -- "$1")" || {
  echo "FAIL: compiled object directory not found" >&2
  exit 1
}
if [ "$obj" = / ] || [ ! -d "$obj" ]; then
  echo "FAIL: expected a real compiled object directory" >&2
  exit 1
fi

helper="$obj/dist/bin/crashhelper"
if [ ! -f "$helper" ] || [ ! -s "$helper" ] || [ -L "$helper" ]; then
  echo "FAIL: unstripped crashhelper executable absent, empty or symlinked" >&2
  exit 1
fi
canonical_helper="$(realpath -e -- "$helper")"
case "$canonical_helper" in
  "$obj"/*) ;;
  *) echo "FAIL: linked crashhelper escaped the compiled object directory" >&2; exit 1 ;;
esac

expected="$obj/toolkit/crashreporter/crash_helper_server/libcrash_helper_server.a"
if [ -L "$expected" ]; then
  echo "FAIL: expected crash helper Rust staticlib path is a symlink" >&2
  exit 1
fi
if [ -f "$expected" ] && [ -s "$expected" ]; then
  archive="$expected"
  mode=expected
else
  # The full native build (42502043415) compiled this Rust target but its
  # archive was NOT in the crashreporter subtree at the later package/runtime
  # audit. Cargo's real output root may differ from the moz.build directory.
  # Look only under this exact native objdir, never HOME, the source tree,
  # stale sibling objdirs, the filesystem root, or symlinked directories.
  tmp="$(mktemp)"
  trap 'rm -f -- "$tmp"' EXIT
  find -P "$obj" -type f -name libcrash_helper_server.a -print > "$tmp" || {
    echo "FAIL: failed to enumerate bounded native object-tree Rust archives" >&2
    exit 1
  }
  mapfile -t candidates < "$tmp"
  if [ "${#candidates[@]}" -ne 1 ]; then
    echo "FAIL: expected exactly one actual crash helper Rust staticlib anywhere in source-matched objdir; found ${#candidates[@]}" >&2
    exit 1
  fi
  archive="${candidates[0]}"
  mode=unique-objdir-fallback
fi

if [ ! -f "$archive" ] || [ ! -s "$archive" ] || [ -L "$archive" ]; then
  echo "FAIL: selected crash helper Rust archive missing, empty or symlinked" >&2
  exit 1
fi

canonical="$(realpath -e -- "$archive")"
case "$canonical" in
  "$obj"/*) ;;
  *) echo "FAIL: crash helper archive escaped the source-matched object tree" >&2; exit 1 ;;
esac

echo "PASS: selected exactly one normal-build crash helper Rust staticlib via $mode" >&2
printf '%s\n' "$canonical"
