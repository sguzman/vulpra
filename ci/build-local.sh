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


# The original Vulpra import accidentally omitted this gitignored upstream
# Breakpad dependency. A git ls-files check alone cannot detect such omissions.
LSS_HEADER="$REPO/toolkit/crashreporter/google-breakpad/src/third_party/lss/linux_syscall_support.h"
if [[ ! -s "$LSS_HEADER" ]]; then
  echo 'ERROR: Missing upstream Breakpad Linux syscall header; refusing a doomed 85-minute build.' >&2
  echo 'Restore the pinned upstream source, keeping existing obj-vulpra-linux artifacts intact.' >&2
  echo 'See: https://github.com/sguzman/vulpra/commit/b9349a7f9a3e00e5e4f11aea4af7179a315412ec' >&2
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

# Build-system success is a native compilation acceptance gate, not a
# packaged-browser / runtime gate. Do not turn a legitimate compiler success
# into a failure because we guessed the executable's name or location.
printf 'PASS: Native Vulpra compilation finished successfully (mach exit 0).\n' | tee -a "$BUILD_LOG"
printf 'NEXT: Package and test the native browser; launch/runtime are not yet verified.\n' | tee -a "$BUILD_LOG"

# Evidence-only inspection; packaging is responsible for verifying its actual
# executable, packaged application.ini and isolated profile. This never fails
# an otherwise successful compilation.
BIN="$REPO/obj-vulpra-linux/dist/bin"
if [[ -d "$BIN" ]]; then
  if [[ -f "$BIN/application.ini" ]]; then
    sed -n '/^\[App\]/,/^\[/{ /^(Name|Vendor|Version)=/p; }' "$BIN/application.ini" | tee -a "$BUILD_LOG" || true
  else
    printf 'NOTE: application.ini not yet found in dist/bin; package gate pending.\n' | tee -a "$BUILD_LOG"
  fi
  for candidate in firefox vulpra; do
    if [[ -x "$BIN/$candidate" ]]; then
      printf 'Detected executable candidate: %s\n' "$BIN/$candidate" | tee -a "$BUILD_LOG"
    fi
  done
else
  printf 'NOTE: dist/bin not yet present; package gate pending.\n' | tee -a "$BUILD_LOG"
fi
