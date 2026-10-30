#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
parser="$root/ci/m3-wayland-gdb-sanitize.awk"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
cat > "$work/numeric" <<'LOG'
Thread 1 received signal SIGSEGV, Segmentation fault.
$1 = 1
$2 = 1
$3 = 1
#0  0xFEED1234 in ?? () from /private/secret/libxul.so
#1  0xFEED2222 in doThings (password=secret) from /private/secret/libxul.so
LOG
awk -f "$parser" "$work/numeric" >"$work/out"
grep -Fxq 'DIAGNOSTIC signal: SIGSEGV' "$work/out"
grep -Fxq 'DIAGNOSTIC fault address under 4096 bytes: yes' "$work/out"
grep -Fxq 'DIAGNOSTIC fault address exactly null: yes' "$work/out"
test "$(grep -cF 'DIAGNOSTIC fault class: SEGV_MAPERR' "$work/out")" -eq 1
grep -Fq '[module=libxul.so]' "$work/out"
if grep -Eq 'FEED1234|FEED2222|/private/|password|secret' "$work/out"; then
  echo 'FAIL: private debugger input exposed in sanitizer output' >&2
  exit 1
fi
cat > "$work/textual" <<'LOG'
Program received signal SIGSEGV, Segmentation fault.
$1 = false
$2 = false
$3 = 2
#0  0xABBACCDD in func (x=123) from /abs/other/libgtk-3.so
LOG
awk -f "$parser" "$work/textual" >"$work/out"
grep -Fxq 'DIAGNOSTIC fault address under 4096 bytes: no' "$work/out"
grep -Fxq 'DIAGNOSTIC fault address exactly null: no' "$work/out"
grep -Fxq 'DIAGNOSTIC fault class: SEGV_ACCERR' "$work/out"
grep -Fq '[module=libgtk-3.so]' "$work/out"
echo '$1 = 1' > "$work/incomplete"
awk -f "$parser" "$work/incomplete" >"$work/out"
grep -Fxq 'DIAGNOSTIC fault classification: incomplete' "$work/out"
grep -Fxq 'DIAGNOSTIC frames: none' "$work/out"
echo 'PASS: GDB numeric/boolean/signal-code fixtures, stripped frames, path privacy, incomplete response'
