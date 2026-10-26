#!/usr/bin/env bash
# Package and smoke-test a compiled local Vulpra browser in an isolated home.
set -Eeuo pipefail
REPO="${1:-$HOME/Code/Apps/vulpra}"
cd "$REPO" || { echo "ERROR: Missing repository: $REPO" >&2; exit 2; }
REPO=$(pwd -P)
[[ "$(git config --bool core.sparseCheckout || true)" != true ]] || {
  echo 'ERROR: Source checkout is still sparse; finish retrieval first.' >&2; exit 3;
}
[[ -f mach && -f packaging/stage.sh && -f packaging/vulpra ]] || {
  echo 'ERROR: Missing Vulpra package scripts.' >&2; exit 2;
}
missing=$(git ls-files -d | sed -n '1p') || {
  echo 'ERROR: Unable to check tracked source-file presence.' >&2; exit 3;
}
if [[ -n "$missing" ]]; then
  echo "ERROR: Missing tracked source: $missing" >&2
  exit 3
fi
BIN="$REPO/obj-vulpra-linux/dist/bin"
DIST="$REPO/obj-vulpra-linux/dist"
[[ -x "$BIN/firefox" && -s "$BIN/application.ini" ]] || {
  echo 'ERROR: No compiled native browser found. Run the native build first.' >&2; exit 4;
}
grep -Fxq 'Name=Vulpra' "$BIN/application.ini" || {
  echo 'ERROR: Compiled browser does not report Name=Vulpra.' >&2; exit 4;
}
export MOZCONFIG="${MOZCONFIG:-$HOME/.mozbuild/vulpra-local.mozconfig}"
[[ -f "$MOZCONFIG" ]] || { echo "ERROR: Missing mozconfig: $MOZCONFIG" >&2; exit 4; }
LOGDIR=$(git rev-parse --path-format=absolute --git-path vulpra-native-build)
mkdir -p "$LOGDIR/packages"
exec 9>"$LOGDIR/build.lock"
flock -n 9 || { echo 'ERROR: Native build/package job already running.' >&2; exit 7; }
STAMP=$(date +%Y%m%d-%H%M%S-%N)
LOG="$LOGDIR/package-smoke-$STAMP.log"
log() { printf '%s\n' "$*" | tee -a "$LOG"; }
log "Vulpra package and smoke: $(date -Is)"
log "Source: $REPO"
log "Packaging log: $LOG"
set +e
./mach package 2>&1 | tee -a "$LOG"
pipe_status=("${PIPESTATUS[@]}")
set -e
if ((pipe_status[1] != 0)); then
  echo "ERROR: Packaging log write failed: $LOG" >&2; exit 6;
fi
if ((pipe_status[0] != 0)); then
  log "ERROR: Native package command failed (exit ${pipe_status[0]})."
  exit "${pipe_status[0]}"
fi
mapfile -d '' -t archives < <(find "$DIST" -maxdepth 1 -type f \( -name '*.tar.xz' -o -name '*.tar.bz2' -o -name '*.tar.gz' \) -print0)
if ((${#archives[@]} != 1)); then
  log "ERROR: Expected one generated browser archive in $DIST, found ${#archives[@]}."
  exit 5
fi
OUT="$LOGDIR/packages/vulpra-local-$STAMP.tar.xz"
bash packaging/stage.sh "${archives[0]}" "$OUT" 2>&1 | tee -a "$LOG"
(cd "$(dirname "$OUT")" && sha256sum --check "$(basename "$OUT").sha256") 2>&1 | tee -a "$LOG"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/package" "$work/home/.mozilla/firefox"
printf '[Profile0]\nName=existing-firefox\nPath=existing-profile\n' > "$work/home/.mozilla/firefox/profiles.ini"
original_hash=$(sha256sum "$work/home/.mozilla/firefox/profiles.ini" | cut -d' ' -f1)
tar -xf "$OUT" -C "$work/package"
mapfile -d '' -t inis < <(find "$work/package" -maxdepth 4 -type f -name application.ini -print0)
if ((${#inis[@]} != 1)); then
  log "ERROR: Packaged application.ini count ${#inis[@]}, expected one."
  exit 5
fi
appdir=$(dirname "${inis[0]}")
[[ -x "$appdir/vulpra" && -x "$appdir/firefox" ]] || {
  log 'ERROR: Isolated Vulpra launcher or browser executable missing.'; exit 5;
}
grep -Fxq 'Name=Vulpra' "$appdir/application.ini" || {
  log 'ERROR: Packaged app identity is not Vulpra.'; exit 5;
}
cat > "$work/smoke.html" <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8">
<title>Vulpra local smoke</title><h1>Vulpra started</h1>
<script>document.querySelector('h1').textContent = 'Vulpra JavaScript executed';</script>
HTML
log 'Testing headless packaged browser with private HOME and profile...'
set +e
HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" MOZ_HEADLESS=1 \
  timeout 120 "$appdir/vulpra" --headless --screenshot "$work/screenshot.png" "file://$work/smoke.html" 2>&1 | tee -a "$LOG"
pipe_status=("${PIPESTATUS[@]}")
set -e
if ((pipe_status[1] != 0)); then
  echo "ERROR: Smoke-test log write failed: $LOG" >&2; exit 6;
fi
if ((pipe_status[0] != 0)); then
  log "ERROR: Packaged browser exited ${pipe_status[0]} during smoke test."
  exit "${pipe_status[0]}"
fi
[[ -s "$work/screenshot.png" ]] || { log 'ERROR: Missing headless screenshot.'; exit 5; }
[[ "$(head -c 8 "$work/screenshot.png" | od -An -tx1 | tr -d ' \n')" == 89504e470d0a1a0a ]] || {
  log 'ERROR: Screenshot is not a PNG.'; exit 5;
}
[[ -d "$work/home/.local/share/vulpra/default" ]] || {
  log 'ERROR: Isolated profile directory was not created.'; exit 5;
}
[[ "$(sha256sum "$work/home/.mozilla/firefox/profiles.ini" | cut -d' ' -f1)" == "$original_hash" ]] || {
  log 'ERROR: Existing Firefox profile changed during smoke test.'; exit 5;
}
cp "$work/screenshot.png" "$LOGDIR/smoke-$STAMP.png"
log "PASS: Packaged Vulpra launched headlessly, produced a PNG screenshot and preserved existing Firefox profile."
if [[ "${VULPRA_SKIP_WAYLAND:-0}" != 1 ]] && command -v weston >/dev/null && command -v wayland-info >/dev/null; then
  log 'Testing graphical Wayland startup in a private Weston compositor...'
  bash packaging/test-wayland.sh "$appdir" 2>&1 | tee -a "$LOG"
  log 'PASS: Wayland startup test finished.'
else
  log 'NOT VERIFIED: Wayland compositor smoke skipped (weston or wayland-info unavailable).'
fi
log "Package: $OUT"
log "Screenshot: $LOGDIR/smoke-$STAMP.png"
log 'PASS: Local packaging and isolated headless smoke acceptance gates.'
