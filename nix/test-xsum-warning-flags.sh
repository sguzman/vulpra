#!/usr/bin/env bash
# Guard against Firefox xsum per-file flags negating Nix format hardening.
# This compiles the *actual* vendored xsum.cpp, not a synthetic substitute.
set -euo pipefail

[[ "${VULPRA_NIX_DEV:-}" == 1 ]] || {
  printf 'ERROR: xsum compiler regression test requires Nix devShell\n' >&2
  exit 1
}
root="${1:-.}"
source="$root/js/src/xsum/xsum.cpp"
flags="$root/js/src/xsum/moz.build"
[[ -f "$source" && -f "$flags" && -f "$root/js/src/xsum/xsum.h" ]] || {
  printf 'ERROR: xsum source, header or moz.build missing\n' >&2
  exit 1
}
# The original xsum-specific flag disabled -Wformat, and thus made the
# Nix wrapper's required -Wformat-security illegal with -Werror=format-security.
if grep -Fq "'-Wno-format'" "$flags"; then
  printf 'ERROR: xsum disables -Wformat, conflicting with format-security hardening\n' >&2
  exit 1
fi
compiler="${CXX:-g++}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
"$compiler" -std=gnu++20 -O2 -fPIC -Wformat -Wformat-security \
  -Werror=format-security -Wno-implicit-fallthrough -Wno-unused-value \
  -c "$source" -o "$scratch/xsum.o"
[[ -s "$scratch/xsum.o" ]] || {
  printf 'ERROR: vendored xsum object not produced\n' >&2
  exit 1
}
printf 'PASS: vendored xsum.cpp compiles with pinned Nix GCC and format-security hardening\n'
