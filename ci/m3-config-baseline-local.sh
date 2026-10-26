#!/usr/bin/env bash
# Read configured Firefox feature flags from generated build metadata.
# Does NOT run mach, configure, packaging or edit the source/build tree.
set -Eeuo pipefail
repo="${1:-$HOME/Code/Apps/vulpra}"
objdir="${2:-$repo/obj-vulpra-linux}"
cd -- "$repo"
repo=$(pwd -P)
objdir=$(realpath -m -- "$objdir")
src="$objdir/config.statusd/substs"
[[ -d "$src" ]] || {
  echo "NOT VERIFIED: Generated configure metadata absent: $src" >&2
  exit 3
}
gitdir=$(git rev-parse --absolute-git-dir)
logdir="$gitdir/vulpra-debloat"
mkdir -p "$logdir"
report="$logdir/m3-config-baseline.tsv"
if [[ ! -f "$src/MOZ_BUILD_APP" || ! -f "$src/MOZ_WIDGET_TOOLKIT" ]]; then
  echo 'NOT VERIFIED: Build identity keys missing from config.statusd/substs.' >&2
  exit 3
fi
getflag() {
  local key="$1" val state
  if [[ ! -f "$src/$key" ]]; then
    val='(missing)'
    state='not-recorded'
  else
    val=$(head -c 1024 -- "$src/$key" | tr -d '\r\n')
    if [[ "$val" == 'null' || -z "$val" ]]; then
      state='not-recorded'
    else
      state='observed'
    fi
  fi
  [[ "$val" != *$'\t'* ]] || { echo "ERROR: Tab in configured value: $key" >&2; exit 4; }
  printf '%s\t%s\t%s\n' "$key" "$state" "$val" >> "$report"
  printf '%-31s %s\n' "$key" "$val"
}
printf '# Vulpra config flags from %s\n' "$objdir" > "$report"
printf '# Worktree Git HEAD %s; build provenance may be earlier\n' "$(git rev-parse HEAD)" >> "$report"
printf 'key\tstatus\tvalue_json\n' >> "$report"
echo 'Read-only selected config values:'
for key in MOZ_BUILD_APP MOZ_WIDGET_TOOLKIT OS_TARGET MOZ_APP_BASENAME MOZ_APP_NAME MOZ_APP_VERSION MOZ_SERVICES_SYNC MOZ_SERVICES_HEALTHREPORT MOZ_NORMANDY MOZ_DEVTOOLS MOZ_TELEMETRY_REPORTING MOZ_CRASHREPORTER MOZ_HAS_REMOTE ENABLE_WEBDRIVER MOZ_GECKODRIVER ENABLE_TESTS MOZ_UPDATER MOZ_SANDBOX MOZ_WAYLAND; do
  getflag "$key"
done
echo "Report: $report"
echo 'Only generated config.statusd/substs values were inspected; source and build files unchanged.'
echo 'Not evidence that a feature has been removed or that the current Git HEAD was compiled.'
