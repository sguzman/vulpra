#!/usr/bin/env bash
# Exercise a packaged Vulpra (not MOZ_HEADLESS) on a private Weston compositor.
set -euo pipefail
if [[ $# -ne 1 ]]; then
  echo 'usage: test-wayland.sh package-application-directory' >&2
  exit 2
fi
appdir="$(realpath -e -- "$1")"
# The private launcher has a different name when the native ELF is vulpra.
if [[ -x "$appdir/vulpra-launch" ]]; then
  launcher="$appdir/vulpra-launch"
elif [[ -x "$appdir/vulpra" && -x "$appdir/firefox" ]]; then
  launcher="$appdir/vulpra"
else
  echo 'Missing isolated Vulpra package launcher' >&2
  exit 2
fi
for command in weston wayland-info python3; do
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
# The Firefox native XRE startup explicitly honors XRE_START_OFFLINE=1 and
# calls nsIIOService::SetOffline(true) before normal browser services start.
# Keep this *CI smoke only*, confined to the browser process, because the
# host-runner also enforces MOZ_DISABLE_NONLOCAL_CONNECTIONS=1. Never modify
# real user profiles, allow non-local egress or weaken frame/liveness checks.
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
grep -Fq 'xdg_wm_base' "$work/compositor-info" || {
  echo 'Compositor is missing xdg_wm_base protocol' >&2
  exit 1
}

# Private HOME and no X11 DISPLAY: a normal browser must use GTK Wayland
# or fail to start; MOZ_HEADLESS is removed to exercise graphical startup.
# Optional CI loader observation applies ONLY to browser processes, never the
# Weston compositor, wayland-info or Python QA helper. No default behavior change.
loader_env=()
trace_kind="${VULPRA_M3_LOADER_TRACE_KIND:-libs,files}"
case "$trace_kind" in
  libs,files|versions|versions,bindings) ;;
  *) echo 'Invalid browser-only GNU loader trace kind' >&2; exit 2 ;;
esac
if [[ -n "${VULPRA_M3_LOADER_TRACE_KIND:-}" &&
      -z "${VULPRA_M3_LOADER_TRACE_PREFIX:-}" ]]; then
  echo 'GNU loader trace kind requires disposable trace prefix' >&2
  exit 2
fi
if [[ -n "${VULPRA_M3_LOADER_TRACE_PREFIX:-}" ]]; then
  [[ "$VULPRA_M3_LOADER_TRACE_PREFIX" == /* ]] || {
    echo 'Native loader trace prefix must be an absolute disposable path' >&2
    exit 2
  }
  loader_env=("LD_DEBUG=$trace_kind" "LD_DEBUG_OUTPUT=$VULPRA_M3_LOADER_TRACE_PREFIX")
fi
# Opt in only on the specific ordinary-host CI that intentionally forbids
# non-local connections. Existing disconnected-netns and other graphical
# workloads retain their normal online browser startup semantics.
offline_env=()
case "${VULPRA_WAYLAND_TEST_OFFLINE:-0}" in
  0) ;;
  1) offline_env=(XRE_START_OFFLINE=1) ;;
  *) echo 'VULPRA_WAYLAND_TEST_OFFLINE must be 0 or 1' >&2; exit 2 ;;
esac
env -u MOZ_HEADLESS -u XRE_START_OFFLINE "${loader_env[@]}" "${offline_env[@]}" \
  HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" \
  XDG_SESSION_TYPE=wayland GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1 \
  WAYLAND_DEBUG=client \
  "$launcher" about:blank >"$work/browser.log" 2>&1 &
browser_pid="$!"
sleep "$duration"
if ! kill -0 "$browser_pid" 2>/dev/null; then
  # Distinguish an intentional parent/launcher exit from a native fault.
  # Do not treat a failed/finished primary process as a successful browser.
  browser_exit=0
  wait "$browser_pid" || browser_exit="$?"
  echo "Vulpra exited before ${duration}s of Wayland startup smoke (native exit status: $browser_exit)" >&2
  tail -n 80 "$work/browser.log" >&2 || true
  exit 1
fi
# Gecko writes compatibility.ini while actually initializing a new profile.
# This is stronger than testing directory existence or merely surviving.
[[ -s "$work/home/.local/share/vulpra/default/compatibility.ini" ]] || {
  echo 'Wayland startup did not initialize its isolated Vulpra profile' >&2
  exit 1
}
[[ ! -e "$work/home/.mozilla" ]] || {
  echo 'Wayland startup unexpectedly created Firefox profile directory' >&2
  exit 1
}
# A process that merely stays alive is insufficient; require a committed
# non-null pixel buffer on an actual Wayland surface. Accept both common
# libwayland object-ID renderings (wl_surface#1 and wl_surface@1).
# Only an attach followed by a commit *on the same surface* is
# evidence of a submitted Wayland frame. Independent grep checks could
# accidentally match separate surfaces and falsely accept blank startup.
if ! python3 - "$work/browser.log" <<'PY'
import re
import sys
from pathlib import Path

attached = set()
# Wayland attach(NULL) replaces/detaches a previous surface buffer.
# A later commit of that empty state must not be accepted as painted.
attach = re.compile(r"wl_surface([#@][0-9]+)\.attach\(([^)]*)\)")
nonnull = re.compile(r"^wl_buffer[#@][0-9]+(?:\s|,|$)")
commit = re.compile(r"wl_surface([#@][0-9]+)\.commit\(")
for line in Path(sys.argv[1]).open(encoding="utf-8", errors="replace"):
    found_attach = attach.search(line)
    if found_attach:
        surface, args = found_attach.groups()
        if nonnull.search(args):
            attached.add(surface)
        else:
            attached.discard(surface)
    found_commit = commit.search(line)
    if found_commit and found_commit.group(1) in attached:
        break
else:
    print("Vulpra has not attached and committed a buffer on the same Wayland surface", file=sys.stderr)
    sys.exit(1)
PY
then
  echo "Vulpra did not attach and commit a graphical Wayland frame on one surface" >&2
  tail -n 100 "$work/browser.log" >&2 || true
  exit 1
fi
echo "PASS: private Weston compositor, Wayland surface buffer attachment and commit, and isolated profile for ${duration}s"
