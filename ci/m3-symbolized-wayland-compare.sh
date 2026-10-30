#!/usr/bin/env bash
# Source-pinned native graphical comparison; diagnostics are not M3 acceptance.
# Usage: m3-symbolized-wayland-compare.sh original.tar.xz fresh.tar.xz unstripped-libxul.so report.txt
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-symbolized-wayland-compare.sh old.tar.xz fresh.tar.xz unstripped-libxul.so report.txt' >&2
  exit 2
fi
original="$(realpath -e -- "$1")"
fresh="$(realpath -e -- "$2")"
unstripped="$(realpath -e -- "$3")"
output="$4"
diagnostics_root="$(dirname -- "$(dirname -- "$(realpath -e -- "$0")")")"
harness="$diagnostics_root/packaging/test-wayland.sh"
sanitizer="$diagnostics_root/ci/m3-wayland-gdb-sanitize.awk"
for tool in weston wayland-info gdb readelf objcopy sha256sum timeout cmp; do
  command -v "$tool" >/dev/null || { echo "Required diagnostic program unavailable: $tool" >&2; exit 2; }
done
test -f "$harness"
test -f "$sanitizer"
umask 077
work="$(mktemp -d)"
weston_pid=''
cleanup() {
  if [[ -n "$weston_pid" ]]; then
    kill "$weston_pid" 2>/dev/null || true
    wait "$weston_pid" 2>/dev/null || true
  fi
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -p "$work/old" "$work/fresh"
tar -xf "$original" -C "$work/old"
tar -xf "$fresh" -C "$work/fresh"
oldapp="$work/old/vulpra"
freshapp="$work/fresh/vulpra"
test -x "$oldapp/vulpra"
test -x "$freshapp/vulpra"
test -f "$freshapp/libxul.so"
test -f "$unstripped"

# Both real packages are exercised under the SAME runner, script and
# current isolated compositor contract. An old/fresh difference is still
# not a controlled same-toolchain build comparison: the old archive is
# historical, and this workflow builds only the new archive.
echo 'SOURCE-PINNED WAYLAND DIAGNOSTIC: no source removal, no accepted gate'
printf 'Original archive SHA-256: '
sha256sum "$original" | cut -d ' ' -f 1
printf 'Fresh archive SHA-256: '
sha256sum "$fresh" | cut -d ' ' -f 1
run_case() {
  local label="$1"
  local app="$2"
  local status=0
  if env MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 VULPRA_WAYLAND_TEST_SECONDS=10 \
    bash "$harness" "$app" >"$work/$label.log" 2>&1; then
    echo "DIAGNOSTIC $label: native private Weston 10-second acceptance PASS"
  else
    status="$?"
    echo "DIAGNOSTIC $label: native private Weston 10-second acceptance FAIL (harness status $status)"
    # Never print a raw GTK/Wayland trace or profile paths.
    if grep -Fq 'native exit status: 11' "$work/$label.log"; then
      echo "DIAGNOSTIC $label: crash-reporter-style exit 11 detected"
    elif grep -Fq 'native exit status: 139' "$work/$label.log"; then
      echo "DIAGNOSTIC $label: SIGSEGV-style exit 139 detected"
    fi
  fi
}
run_case original "$oldapp"
run_case fresh "$freshapp"

# Compare code sections from the fresh package and its own unstripped link
# output. Never attach symbols from a different binary or claim parity
# merely because source versions match.
if ! readelf -SW "$unstripped" | grep -Eq '[.]debug_info|[.]symtab'; then
  echo 'DIAGNOSTIC: fresh native linked libxul has no observable symbol section'
  exit 0
fi
if ! objcopy --dump-section ".text=$work/linked.text" "$unstripped" 2>"$work/linked.err"; then
  echo 'DIAGNOSTIC: could not extract linked libxul .text; no symbols attached'
  exit 0
fi
if ! objcopy --dump-section ".text=$work/packaged.text" "$freshapp/libxul.so" 2>"$work/package.err"; then
  echo 'DIAGNOSTIC: could not extract packaged libxul .text; no symbols attached'
  exit 0
fi
if ! cmp -s "$work/linked.text" "$work/packaged.text"; then
  echo 'DIAGNOSTIC: linked/package .text differ; refusing mismatched debug substitution'
  exit 0
fi
echo 'DIAGNOSTIC: verified exact fresh libxul .text equality before debug substitution'
# Never mutate the verified archive. The scratch copy is ONLY for a separate
# symbolized reproduction; source SHA and matching text do not prove original
# historical package binary parity.
mkdir -p "$work/symbolized"
cp -a "$freshapp/." "$work/symbolized/"
cp -- "$unstripped" "$work/symbolized/libxul.so"
test -x "$work/symbolized/vulpra"

mkdir -p "$work/runtime" "$work/home/.local/share/vulpra/default"
export XDG_RUNTIME_DIR="$work/runtime"
export WAYLAND_DISPLAY=wayland-vulpra-symbols
unset DISPLAY
weston --backend=headless-backend.so --renderer=pixman \
  --socket="$WAYLAND_DISPLAY" --idle-time=0 \
  --log="$work/weston.log" >"$work/weston.stdout" 2>&1 &
weston_pid="$!"
socket_ready=0
for ((attempt=1; attempt<=40; ++attempt)); do
  if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
    socket_ready=1
    break
  fi
  if ! kill -0 "$weston_pid" 2>/dev/null; then break; fi
  sleep 0.25
done
if [[ "$socket_ready" -ne 1 ]]; then
  echo 'DIAGNOSTIC: private Weston GDB socket unavailable'
  exit 0
fi
# Process-local debugger signal handling intentionally differs from normal
# acceptance. Raw traces may contain file paths, pointers and sensitive args:
# never log or upload them.
gdb_status=0
env -u MOZ_HEADLESS \
  HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" \
  XDG_SESSION_TYPE=wayland GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1 \
  MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 MOZ_CRASHREPORTER_DISABLE=1 \
  timeout --signal=TERM --kill-after=3s 90s \
  gdb -q -nx -batch \
  -ex 'set pagination off' \
  -ex 'set debuginfod enabled off' \
  -ex 'set auto-load safe-path /dev/null' \
  -ex 'handle SIGPIPE nostop noprint pass' \
  -ex run \
  -ex "p ((unsigned long)\$_siginfo._sifields._sigfault.si_addr < 4096)" \
  -ex "p ((unsigned long)\$_siginfo._sifields._sigfault.si_addr == 0)" \
  -ex "p \$_siginfo.si_code" \
  -ex 'bt 15' \
  --args "$work/symbolized/vulpra" --no-remote --new-instance \
  --profile "$work/home/.local/share/vulpra/default" about:blank \
  >"$work/gdb-raw.log" 2>&1 || gdb_status="$?"
echo "DIAGNOSTIC: GDB process status $gdb_status (not graphical acceptance)"
awk -f "$sanitizer" "$work/gdb-raw.log" >"$work/sanitized.txt"
cat -- "$work/sanitized.txt"
if grep -Fq 'DIAGNOSTIC signal: SIGSEGV' "$work/sanitized.txt"; then
  echo 'DIAGNOSTIC: symbolized fresh-binary reproduction observed SIGSEGV'
else
  echo 'DIAGNOSTIC: symbolized fresh-binary reproduction did NOT observe SIGSEGV'
fi
if grep -Eq '^DIAGNOSTIC symbolic frame [0-9]+: [A-Za-z_~]' "$work/sanitized.txt"; then
  echo 'DIAGNOSTIC: at least one sanitized native symbol resolved'
else
  echo 'DIAGNOSTIC: no native function symbol resolved'
fi
# Report contains sanitized results and scalar source identifiers only.
{
  echo 'Diagnostic only — not a passed native browser or M3 gate.'
  echo 'Original and fresh 10-second results recorded in run logs.'
  sha256sum "$original" "$fresh" | cut -d ' ' -f 1
  cat -- "$work/sanitized.txt"
} > "$output"
echo 'DIAGNOSTIC: temporary Weston/profile/raw debugger data disposed'
