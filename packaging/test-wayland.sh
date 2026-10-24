#!/usr/bin/env bash
# Exercise a packaged Vulpra (not MOZ_HEADLESS) on a private Weston compositor.
set -euo pipefail
if [[ $# -ne 1 ]]; then
  echo 'usage: test-wayland.sh package-application-directory' >&2
  exit 2
fi
appdir="$(realpath -e -- "$1")"
[[ -x "$appdir/vulpra" ]] || { echo 'Missing Vulpra package launcher' >&2; exit 2; }
for command in weston wayland-info; do
  command -v "$command" >/dev/null || { echo "Missing compositor test dependency: $command" >&2; exit 2; }
done

duration="${VULPRA_WAYLAND_TEST_SECONDS:-10}"
[[ "$duration" =~ ^[1-9][0-9]?$ ]] || { echo 'Invalid smoke duration' >&2; exit 2; }
work="$(mktemp -d)"
browser_pid=""
weston_pid=""
cleanup() {
  if [[ -n "$browser_pid" ]]; then
    kill "$browser_pid" 2>/dev/null || true
    wait "$browser_pid" 2>/dev/null || true
  fi
  if [[ -n "$weston_pid" ]]; then
    kill "$weston_pid" 2>/dev/null || true
    wait "$weston_pid" 2>/dev/null || true
  fi
  rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -m 0700 -p "$work/runtime" "$work/home"
export XDG_RUNTIME_DIR="$work/runtime"
export WAYLAND_DISPLAY="wayland-vulpra"
unset DISPLAY
weston --backend=headless-backend.so --renderer=pixman \
  --socket="$WAYLAND_DISPLAY" --idle-time=0 \
  --log="$work/weston.log" >"$work/weston.stdout" 2>&1 &
weston_pid="$!"

ready=0
for attempt in {1..30}; do
  if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
    ready=1
    break
  fi
  if ! kill -0 "$weston_pid" 2>/dev/null; then
    break
  fi
  sleep 0.25
done
if [[ "$ready" -ne 1 ]]; then
  echo 'Weston did not create a working Wayland socket' >&2
  cat "$work/weston.log" "$work/weston.stdout" >&2 || true
  exit 1
fi
if ! wayland-info > "$work/compositor-info" 2>"$work/compositor-error"; then
  echo 'Wayland registry inspection failed' >&2
  cat "$work/compositor-error" "$work/weston.log" >&2 || true
  exit 1
fi
grep -Fq 'wl_compositor' "$work/compositor-info" || {
  echo 'Compositor is missing wl_compositor protocol' >&2
  exit 1
}

# Private HOME and no X11 DISPLAY: a normal browser must use GTK Wayland
# or fail to start; MOZ_HEADLESS is removed to exercise graphical startup.
env -u MOZ_HEADLESS \
  HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" \
  XDG_SESSION_TYPE=wayland GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1 \
  "$appdir/vulpra" about:blank >"$work/browser.log" 2>&1 &
browser_pid="$!"
sleep "$duration"
if ! kill -0 "$browser_pid" 2>/dev/null; then
  echo "Vulpra exited before ${duration}s of Wayland startup smoke" >&2
  tail -n 80 "$work/browser.log" >&2 || true
  exit 1
fi
[[ -d "$work/home/.local/share/vulpra/default" ]] || {
  echo 'Wayland startup did not establish isolated Vulpra profile' >&2
  exit 1
}
[[ ! -e "$work/home/.mozilla" ]] || {
  echo 'Wayland startup unexpectedly created Firefox profile directory' >&2
  exit 1
}
echo "PASS: private Weston compositor started, registry responded, and Vulpra remained alive with its isolated profile for ${duration}s"
