#!/usr/bin/env bash
# Smoke-test a real packaged Vulpra GUI against a private headless Weston
# Wayland compositor. Does not compile, install, or touch installed Firefox.
set -Eeuo pipefail
REPO="${1:-$HOME/Code/Apps/vulpra}"
cd "$REPO" || { echo "ERROR: Missing Vulpra checkout: $REPO" >&2; exit 2; }
LOGDIR=$(git rev-parse --path-format=absolute --git-path vulpra-native-build)
PACKAGES="$LOGDIR/packages"
for command in weston wayland-info tar timeout; do
  command -v "$command" >/dev/null || {
    echo "NOT VERIFIED: Missing Wayland GUI smoke dependency: $command" >&2
    exit 3
  }
done
duration="${VULPRA_WAYLAND_TEST_SECONDS:-6}"
[[ "$duration" =~ ^[1-9][0-9]?$ ]] || { echo 'ERROR: Invalid Wayland test seconds (1-99).' >&2; exit 2; }
archive="${2:-}"
if [[ -z "$archive" ]]; then
  mapfile -d '' -t archives < <(
    find "$PACKAGES" -maxdepth 1 -type f -name 'vulpra-local-*.tar.xz' -printf '%T@ %p\0' |
      sort -zrn | cut -z -d ' ' -f2-
  )
  (("${#archives[@]}" > 0)) || { echo "ERROR: No staged Vulpra package under $PACKAGES" >&2; exit 4; }
  archive="${archives[0]}"
fi
archive=$(realpath -e -- "$archive")
if [[ -f "$archive.sha256" ]]; then
  (cd "$(dirname "$archive")" && sha256sum --check "$(basename "$archive").sha256") || exit 4
else
  echo 'ERROR: Package checksum sidecar missing; refuse unverified archive.' >&2
  exit 4
fi
mkdir -p "$LOGDIR"
stamp=$(date +%Y%m%d-%H%M%S-%N)
log="$LOGDIR/wayland-package-$stamp.log"
work=$(mktemp -d)
weston_pid=""
browser_pid=""
cleanup() {
  rc=$?
  if [[ -f "$work/browser.log" ]]; then
    cp -- "$work/browser.log" "$LOGDIR/wayland-browser-$stamp.log" || true
  fi
  if [[ -f "$work/weston.log" ]]; then
    cp -- "$work/weston.log" "$LOGDIR/wayland-weston-$stamp.log" || true
  fi
  if [[ -n "$browser_pid" ]]; then
    kill "$browser_pid" 2>/dev/null || true
    wait "$browser_pid" 2>/dev/null || true
  fi
  if [[ -n "$weston_pid" ]]; then
    kill "$weston_pid" 2>/dev/null || true
    wait "$weston_pid" 2>/dev/null || true
  fi
  rm -rf -- "$work"
  if ((rc != 0)); then
    echo "FAIL: Wayland GUI smoke (exit $rc). Log: $log" >&2
  fi
}
trap cleanup EXIT
mkdir -m 0700 -p "$work/runtime" "$work/home" "$work/package"
tar -xf "$archive" -C "$work/package"
mapfile -d '' -t inis < <(find "$work/package" -mindepth 1 -maxdepth 4 -type f -name application.ini -print0)
(("${#inis[@]}" == 1)) || { echo 'ERROR: Expected one packaged application.ini.' >&2; exit 4; }
appdir=$(dirname "${inis[0]}")
[[ -x "$appdir/vulpra-launch" ]] && grep -Fxq 'Name=Vulpra' "$appdir/application.ini" || {
  echo 'ERROR: Expected Vulpra identity and isolated vulpra-launch executable.' >&2; exit 4;
}
echo "Vulpra Wayland package smoke: $(date -Is)" | tee "$log"
echo "Archive: $archive" | tee -a "$log"
export XDG_RUNTIME_DIR="$work/runtime" WAYLAND_DISPLAY="wayland-vulpra-$$"
unset DISPLAY
weston --backend=headless-backend.so --renderer=pixman \
  --socket="$WAYLAND_DISPLAY" --idle-time=0 \
  --log="$work/weston.log" > "$work/weston.stdout" 2>&1 &
weston_pid=$!
ready=0
for attempt in {1..40}; do
  if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then ready=1; break; fi
  if ! kill -0 "$weston_pid" 2>/dev/null; then break; fi
  sleep 0.25
done
if ((ready != 1)); then
  echo 'ERROR: Weston did not open a private Wayland socket.' | tee -a "$log" >&2
  cat "$work/weston.stdout" "$work/weston.log" >&2 || true
  exit 5
fi
if ! wayland-info > "$work/compositor-info" 2> "$work/compositor-error"; then
  cat "$work/compositor-error" >&2 || true
  echo 'ERROR: Wayland registry could not be queried.' | tee -a "$log" >&2
  exit 5
fi
grep -Fq 'wl_compositor' "$work/compositor-info" || {
  echo 'ERROR: wl_compositor missing.' | tee -a "$log" >&2; exit 5;
}
grep -Fq 'xdg_wm_base' "$work/compositor-info" || {
  echo 'ERROR: xdg_wm_base missing.' | tee -a "$log" >&2; exit 5;
}
# WAYLAND_DEBUG captures real graphical protocol traffic. The client object
# formatter differs among libwayland versions ("wl_surface#13" or "@13").
# A running process alone cannot pass: it must attach a non-null buffer to a
# Wayland surface and commit a frame. Avoid assuming one specific xdg_* ID
# spelling; that produced a false failure against the real Weston 15 trace.
env -u MOZ_HEADLESS -u DISPLAY \
  HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" \
  XDG_RUNTIME_DIR="$work/runtime" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  XDG_SESSION_TYPE=wayland GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1 \
  WAYLAND_DEBUG=client \
  "$appdir/vulpra-launch" about:blank > "$work/browser.log" 2>&1 &
browser_pid=$!
sleep "$duration"
if ! kill -0 "$browser_pid" 2>/dev/null; then
  echo 'ERROR: Packaged Vulpra exited prematurely on Wayland.' | tee -a "$log" >&2
  tail -n 45 "$work/browser.log" >&2 || true
  exit 5
fi
[[ -d "$work/home/.local/share/vulpra/default" && ! -e "$work/home/.mozilla" ]] || {
  echo 'ERROR: Private profile missing or Firefox profile unexpectedly used.' | tee -a "$log" >&2
  exit 5
}
if ! grep -Eq 'wl_surface[#@][0-9]+\.attach\(wl_buffer[#@][0-9]+' "$work/browser.log" ||
   ! grep -Eq 'wl_surface[#@][0-9]+\.commit\(' "$work/browser.log"; then
  echo 'ERROR: No Wayland surface buffer attachment and frame commit recorded; being alive is insufficient.' | tee -a "$log" >&2
  tail -n 45 "$work/browser.log" >&2 || true
  exit 5
fi
printf 'PASS: Packaged Vulpra connected to private Weston, attached and committed Wayland buffers, remained alive for %ss, and isolated its profile.\n' "$duration" | tee -a "$log"
printf 'Log: %s\nWayland protocol log: %s\n' "$log" "$LOGDIR/wayland-browser-$stamp.log" | tee -a "$log"
echo 'This does not verify human-visible rendering, web navigation, extensions, or security behavior.' | tee -a "$log"
