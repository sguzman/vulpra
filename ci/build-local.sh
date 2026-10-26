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
STAMP=$(date +%Y%m%d-%H%M%S)
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
result=${PIPESTATUS[0]}
set -e
elapsed=$(($(date +%s) - start))
printf 'Vulpra build exit code: %d (elapsed %ds)\n' "$result" "$elapsed" | tee -a "$BUILD_LOG"
if ((result != 0)); then
  echo "Native compilation is not yet verified. Diagnose: $BUILD_LOG" >&2
  exit "$result"
fi

printf 'PASS: ./mach build returned exit code 0.\n' | tee -a "$BUILD_LOG"
# Packaging is an explicit later gate, not a hidden post-build side effect.
# To package, run ./mach package after confirming this actual native build.
