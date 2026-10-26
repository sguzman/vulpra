#!/usr/bin/env bash
# Build Vulpra on the local Linux workstation without altering installed Firefox.
set -Eeuo pipefail

REPO="${1:-$HOME/Code/Apps/vulpra}"
if ! cd "$REPO"; then
  echo "ERROR: Vulpra checkout not found: $REPO" >&2
  exit 2
fi
REPO=$(pwd -P)
if [[ "$(git config --bool core.sparseCheckout || true)" == true ]]; then
  echo 'ERROR: Sparse checkout still enabled. Finish the resumable source download first.' >&2
  exit 3
fi
[[ -f mach && -f ci/mozconfig-linux ]] || {
  echo "ERROR: Not a Vulpra source checkout: $REPO" >&2
  exit 2
}
# No fetching here. Detect incomplete checkout rather than running a doomed build.
missing=$(git ls-files -d | sed -n '1p') || {
  echo 'ERROR: Unable to check tracked source-file presence.' >&2
  exit 3
}
if [[ -n "$missing" ]]; then
  echo "ERROR: Tracked source is missing: $missing" >&2
  echo 'Finish the full-source downloader before building.' >&2
  exit 3
fi

export MOZCONFIG="${MOZCONFIG:-$HOME/.mozbuild/vulpra-local.mozconfig}"
[[ -f "$MOZCONFIG" ]] || {
  echo "ERROR: Missing local mozconfig: $MOZCONFIG" >&2
  echo 'Preserve the already working local WASI sysroot override; do not use the CI config.' >&2
  exit 4
}

# Store logs inside the Git directory, outside tracked source and installed Firefox.
LOGDIR=$(git rev-parse --path-format=absolute --git-path vulpra-native-build)
mkdir -p "$LOGDIR"
# Only one native compile may write to this object directory at a time.
LOCK="$LOGDIR/build.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "ERROR: Another Vulpra native build is already running in $REPO." >&2
  exit 7
fi
STAMP=$(date +%Y%m%d-%H%M%S-%N)
BUILD_LOG="$LOGDIR/build-$STAMP.log"

printf 'Vulpra native build: %s\n' "$(date -Is)"
printf 'Source: %s\n' "$REPO"
printf 'Commit: %s\n' "$(git rev-parse HEAD)"
printf 'Mozconfig: %s\n' "$MOZCONFIG"
printf 'Build log: %s\n' "$BUILD_LOG"
printf 'Installed Firefox and its profile are not used or modified by this script.\n'

start=$(date +%s)
set +e
./mach build 2>&1 | tee "$BUILD_LOG"
pipe_status=("${PIPESTATUS[@]}")
set -e
result=${pipe_status[0]}
if ((pipe_status[1] != 0)); then
  echo "ERROR: Build log could not be saved reliably: $BUILD_LOG" >&2
  exit 6
fi
elapsed=$(($(date +%s) - start))
printf 'Vulpra build exit code: %d (elapsed %ds)\n' "$result" "$elapsed" | tee -a "$BUILD_LOG"
if ((result != 0)); then
  echo "Native compilation is not yet verified. Diagnose: $BUILD_LOG" >&2
  exit "$result"
fi

# A zero exit code alone is not proof that a native browser executable exists.
BIN="$REPO/obj-vulpra-linux/dist/bin"
if [[ ! -x "$BIN/firefox" || ! -s "$BIN/application.ini" ]]; then
  echo "ERROR: mach returned 0, but the native browser binary or application.ini is missing in $BIN" | tee -a "$BUILD_LOG" >&2
  exit 5
fi
if ! grep -Fxq 'Name=Vulpra' "$BIN/application.ini"; then
  echo "ERROR: Built application.ini does not report Name=Vulpra" | tee -a "$BUILD_LOG" >&2
  exit 5
fi
printf 'PASS: ./mach build returned 0 and a Vulpra executable/application.ini exist.\n' | tee -a "$BUILD_LOG"
# Packaging is an explicit later gate, not a hidden post-build side effect.
# To package, run ./mach package after confirming this actual native build.
