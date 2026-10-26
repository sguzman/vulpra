#!/usr/bin/env bash
# Verify the already-built native browser without compiling or packaging again.
# No real Firefox profile or existing browser installation is touched.
set -Eeuo pipefail
REPO="${1:-$HOME/Code/Apps/vulpra}"
cd "$REPO" || { echo "ERROR: Vulpra checkout not found: $REPO" >&2; exit 2; }
REPO=$(pwd -P)
OBJDIR="$REPO/obj-vulpra-linux"
BIN="$OBJDIR/dist/bin"
[[ -d "$BIN" ]] || {
  echo "ERROR: No built dist/bin directory at $BIN" >&2
  echo 'The compiler reported success, but the resulting binary directory is not present.' >&2
  exit 4
}
APP_NAME=""
if [[ -s "$OBJDIR/mozinfo.json" ]]; then
  APP_NAME=$(sed -nE 's/^[[:space:]]*"appname"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$OBJDIR/mozinfo.json" | head -n 1)
fi
candidates=()
[[ -z "$APP_NAME" ]] || candidates+=("$APP_NAME" "${APP_NAME,,}")
candidates+=(vulpra firefox)
browser=""
for candidate in "${candidates[@]}"; do
  if [[ -n "$candidate" && "$candidate" != */* && -x "$BIN/$candidate" ]]; then
    browser="$BIN/$candidate"
    break
  fi
done
if [[ -z "$browser" ]]; then
  echo "ERROR: No native browser executable among expected candidates: ${candidates[*]}" >&2
  echo "Contents of $BIN (executable regular files/symlinks):" >&2
  find "$BIN" -maxdepth 1 \( -type f -o -type l \) -perm /111 -printf '%f\n' | sort | sed -n '1,35p' >&2
  exit 4
fi
if [[ ! -s "$BIN/application.ini" ]]; then
  echo "ERROR: Missing or empty $BIN/application.ini" >&2
  echo "Found a candidate executable ($browser), but native startup identity is not yet verifiable." >&2
  exit 4
fi
if ! grep -Fxq 'Name=Vulpra' "$BIN/application.ini"; then
  echo 'ERROR: Built application.ini does not report Name=Vulpra.' >&2
  grep -E '^(Name|Vendor|Version)=' "$BIN/application.ini" >&2 || true
  exit 5
fi
LOGDIR=$(git rev-parse --path-format=absolute --git-path vulpra-native-build)
mkdir -p "$LOGDIR"
STAMP=$(date +%Y%m%d-%H%M%S-%N)
LOG="$LOGDIR/native-smoke-$STAMP.log"
WORK=$(mktemp -d)
cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT
mkdir -p "$WORK/home" "$WORK/profile"
cat > "$WORK/smoke.html" <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8">
<title>Vulpra Native Smoke</title>
<h1>Vulpra rendered a local HTML page</h1>
<script>document.querySelector('h1').textContent += ' and executed JavaScript';</script>
HTML
echo "Compiled browser: $browser" | tee "$LOG"
echo "Application identity: $(grep '^Name=' "$BIN/application.ini" | head -n 1)" | tee -a "$LOG"
echo 'Running isolated, headless startup test with a temporary HOME and profile...' | tee -a "$LOG"
set +e
HOME="$WORK/home" XDG_DATA_HOME="$WORK/home/.local/share" MOZ_HEADLESS=1 \
  timeout "${VULPRA_HEADLESS_TIMEOUT:-120}" "$browser" --no-remote --new-instance \
    --profile "$WORK/profile" --headless --screenshot "$WORK/smoke.png" \
    "file://$WORK/smoke.html" 2>&1 | tee -a "$LOG"
pipe_status=("${PIPESTATUS[@]}")
set -e
if ((pipe_status[1] != 0)); then
  echo "ERROR: Cannot write startup log $LOG" >&2
  exit 6
fi
if ((pipe_status[0] != 0)); then
  echo "ERROR: Native browser startup failed (exit ${pipe_status[0]}). Log: $LOG" >&2
  exit "${pipe_status[0]}"
fi
if [[ ! -s "$WORK/smoke.png" ]]; then
  echo "ERROR: Native browser exited without producing a screenshot. Log: $LOG" >&2
  exit 5
fi
if [[ "$(head -c 8 "$WORK/smoke.png" | od -An -tx1 | tr -d ' \n')" != 89504e470d0a1a0a ]]; then
  echo "ERROR: Screenshot is not a PNG. Log: $LOG" >&2
  exit 5
fi
if [[ -e "$WORK/home/.mozilla" ]]; then
  echo "ERROR: A Firefox profile directory was unexpectedly created in the test HOME." >&2
  exit 5
fi
cp -- "$WORK/smoke.png" "$LOGDIR/native-smoke-$STAMP.png"
printf 'PASS: Compiled Vulpra started headlessly and rendered a PNG screenshot using an isolated profile.\n' | tee -a "$LOG"
printf 'Screenshot: %s\nLog: %s\n' "$LOGDIR/native-smoke-$STAMP.png" "$LOG" | tee -a "$LOG"
printf 'Graphical Wayland startup, extensions and security checks remain unverified.\n' | tee -a "$LOG"
