#!/usr/bin/env bash
# Invoke the source-pinned gfxtest GLX --wayland path against a disposable
# Weston socket. This is a probe-path test, not GPU acceleration certification.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo 'usage: m3-gfxtest-private-wayland.sh original-package-dir private-report-dir' >&2
  exit 2
fi
appdir="$(realpath -e -- "$1")"
reportdir="$(realpath -m -- "$2")"
[[ -x "$appdir/gfxtest" ]] || { echo 'Original package missing executable gfxtest' >&2; exit 2; }
[[ ! -e "$reportdir" ]] || { echo 'Refusing to overwrite existing native gfxtest reports' >&2; exit 2; }
mkdir -m 0700 -p "$reportdir"
for command in weston wayland-info timeout; do
  command -v "$command" >/dev/null || { echo 'Missing private compositor dependency' >&2; exit 2; }
done
work="$(mktemp -d)"
pid=''
cleanup() {
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -m 0700 -p "$work/runtime" "$work/home"
export XDG_RUNTIME_DIR="$work/runtime"
export WAYLAND_DISPLAY="wayland-gfxtest"
unset DISPLAY
weston --backend=headless-backend.so --renderer=pixman \
  --socket="$WAYLAND_DISPLAY" --idle-time=0 \
  --log="$work/weston.log" >"$work/weston.stdout" 2>&1 &
pid="$!"
ready=0
for attempt in {1..30}; do
  if [[ -S "$work/runtime/$WAYLAND_DISPLAY" ]]; then
    ready=1
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    break
  fi
  sleep 0.25
done
[[ "$ready" == 1 ]] || { echo 'Private gfx Weston socket missing' >&2; exit 1; }
wayland-info >"$work/registry" 2>"$work/registry.err" || {
  echo 'Cannot inspect private gfx Wayland registry' >&2; exit 1;
}
grep -Fq 'wl_compositor' "$work/registry" || exit 1
grep -Fq 'xdg_wm_base' "$work/registry" || exit 1
umask 077
# Opt-in runtime-binding mode does not alter the original native Wayland
# probe, its disposable compositor, or its regular version-only test.
debug_modes=versions
if [[ -n "${M3_GFX_BINDINGS_REPORT:-}" ]]; then
  [[ -x "${M3_NATIVE_BINDINGS_PARSER:-}" && ! -e "$M3_GFX_BINDINGS_REPORT" ]] || exit 2
  debug_modes=versions,bindings
fi
# Real source in toolkit/xre/gfxtest/glxtest.cpp emits TEST_TYPE / EGL
# *after* wl_display_connect, EGL attempt, roundtrip and disconnect.
# A headless pixman renderer can return EGL test errors: never mislabel
# reaching the EGL probe as functioning GPU acceleration.
if ! timeout --signal=TERM --kill-after=3s 20s \
  env -u DISPLAY -u MOZ_HEADLESS -u XRE_START_OFFLINE \
    HOME="$work/home" XDG_RUNTIME_DIR="$work/runtime" \
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_SESSION_TYPE=wayland \
    GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1 \
    MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
    LD_DEBUG="$debug_modes" LD_DEBUG_OUTPUT="$reportdir/gfxtest-loader" \
    "$appdir/gfxtest" glx --wayland >"$work/gfxtest.out" 2>"$work/gfxtest.err"; then
  echo 'Original gfxtest Wayland probe exited unsuccessfully' >&2
  exit 1
fi
python3 - "$work/gfxtest.out" <<'PY'
from pathlib import Path
import sys
lines=Path(sys.argv[1]).read_text(errors="replace").splitlines()
if not any(lines[i:i+2]==["TEST_TYPE","EGL"] for i in range(len(lines)-1)):
    raise SystemExit("No TEST_TYPE/EGL proof of real Wayland roundtrip")
if any(line=="Missing Wayland libraries" or "Could not connect to wayland display" in line
       for line in lines):
    raise SystemExit("Failed to enter native Wayland EGL probe")
print("PASS: source-pinned native gfxtest GLX Wayland probe connected and completed its roundtrip")
PY
[[ ! -e "$work/home/.mozilla" ]] || {
  echo 'Private gfx probe touched Firefox profile' >&2
  exit 1
}
if [[ -n "${M3_GFX_BINDINGS_REPORT:-}" ]]; then
  "$M3_NATIVE_BINDINGS_PARSER" "$reportdir" "$M3_GFX_BINDINGS_REPORT" "gfxtest"
fi
echo 'LIMIT: entering EGL probe is not evidence of accelerated GPU initialization'
