#!/usr/bin/env bash
# Verify pinned Firefox build-manifest gates without deleting source files.
# Works on partial Git clones: git show lazily fetches selected tiny blobs.
set -Eeuo pipefail
repo="${1:-$HOME/Code/Apps/vulpra}"
cd "$repo"
rev=$(git rev-parse HEAD)
gitdir=$(git rev-parse --absolute-git-dir)
logdir="$gitdir/vulpra-debloat"
mkdir -p "$logdir"
report="$logdir/m3-manifest-gates.tsv"
printf 'manifest\tverified_rule\tstatus\n' > "$report"
checks=0
check() {
  local path="$1" needle="$2" label="$3" content
  if ! content=$(git show "HEAD:$path"); then
    echo "FAIL: Missing pinned source manifest: $path" >&2
    exit 4
  fi
  if ! grep -Fq -- "$needle" <<< "$content"; then
    echo "FAIL: Expected rule missing from $path: $needle" >&2
    exit 5
  fi
  printf '%s\t%s\tPASS\n' "$path" "$label" >> "$report"
  printf 'PASS: %s (%s)\n' "$label" "$path"
  ((checks+=1))
}
check widget/moz.build 'DIRS += [toolkit]' 'selected widget-toolkit directory only'
check browser/moz.build 'if CONFIG["MAKENSISU"]:' 'Windows installer guarded by MAKENSISU'
check browser/moz.configure 'imply_option("MOZ_SERVICES_SYNC", True)' 'browser implies Sync enabled'
check browser/moz.configure 'imply_option("MOZ_SERVICES_HEALTHREPORT", True)' 'browser implies health reporting enabled'
check browser/moz.configure 'imply_option("MOZ_NORMANDY", True, when=vulpra_include_normandy)' 'normal browser implies Normandy; opt-in experiment disables'
check browser/moz.configure 'imply_option("MOZ_DEVTOOLS", "all")' 'browser implies full DevTools client'
check services/moz.build 'if CONFIG["MOZ_SERVICES_SYNC"]:' 'Sync directory build-gated'
check services/moz.build '"fxaccounts",' 'FxAccounts listed separately from Sync'
check toolkit/moz.configure 'project_flag("MOZ_SERVICES_SYNC"' 'Sync exposes project config gate'
check toolkit/moz.configure 'env="MOZ_TELEMETRY_REPORTING"' 'telemetry reporting separate config'
check toolkit/components/telemetry/moz.build 'FINAL_LIBRARY = "xul"' 'telemetry native code in xul'
check devtools/moz.build 'if CONFIG["MOZ_DEVTOOLS"] == "all":' 'DevTools client conditional'
check devtools/moz.build '"server",' 'DevTools server directory retained separately'
check moz.build '"testing",' 'root always traverses testing'
check toolkit/toolkit.mozbuild '"/testing/gtest",' 'toolkit includes testing/gtest regardless ENABLE_TESTS'
check browser/components/moz.build '"genai",' 'GenAI component directory included'
check browser/components/moz.build '"newtab",' 'newtab component directory included'
check browser/components/newtab/moz.build 'FINAL_LIBRARY = "browsercomps"' 'newtab components in browsercomps'
check browser/components/genai/moz.build 'MOZ_SRC_FILES += [' 'GenAI browser resource files packaged'
check toolkit/modules/FirstStartup.sys.mjs 'if (AppConstants.MOZ_NORMANDY) {' 'FirstStartup optional Normandy call is guarded'
check toolkit/components/nimbus/lib/ExperimentManager.sys.mjs 'ClientEnvironment: "resource://normandy/lib/ClientEnvironment.sys.mjs"' 'Nimbus depends on Normandy ClientEnvironment'
check toolkit/components/nimbus/lib/ExperimentManager.sys.mjs 'NormandyUtils: "resource://normandy/lib/NormandyUtils.sys.mjs"' 'Nimbus depends on NormandyUtils'
check toolkit/components/normandy/lib/ClientEnvironment.sys.mjs 'NormandyApi: "resource://normandy/lib/NormandyApi.sys.mjs"' 'shared ClientEnvironment loads NormandyApi'
check toolkit/components/normandy/Normandy.sys.mjs 'await lazy.ExperimentAPI.init();' 'Normandy currently initiates Nimbus lifecycle'
check toolkit/components/nimbus/FeatureManifest.yaml 'uri: "resource://normandy/schemas/LegacyHeartbeat.schema.json"' 'Nimbus legacy Heartbeat schema has Normandy URI'
echo "PASS: $checks manifest rule checks against pinned Git HEAD $rev"
echo "Report: $report"
echo 'No source modification, configure change, compile or runtime regression performed.'
