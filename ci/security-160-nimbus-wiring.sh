#!/usr/bin/env bash
# Bounded cross-file Nimbus / Normandy source-wiring check of a hash-verified
# Firefox 160 candidate. No build configuration, compiled binary or runtime.
set -euo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if test "$#" -ne 5 || test "$1" != --check; then
  echo 'Usage: security-160-nimbus-wiring.sh --check <verified-stage> <candidate-ledger> <official-160-nimbus-dir> <new-report.json>' >&2
  exit 2
fi
stage="$(cd -- "$2" && pwd -P)" || fail 'stage missing'
ledger="$(cd -- "$3" && pwd -P)" || fail 'ledger missing'
upstream="$(cd -- "$4" && pwd -P)" || fail 'upstream source missing'
report="$5"
test ! -e "$report" && test ! -L "$report" || fail 'report output already exists'
test -s "$ledger/candidate-tree-report.json" && test -s "$ledger/overlay-paths.txt" || fail 'incomplete ledger'
jq -e '
  .schema_version==1 and
  .firefox160_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .source_files_modified==26 and .vulpra_source_files_added==2 and
  .upstream_files_deleted==0 and
  .all_other_upstream_files_preserved==true and
  .native_binary_compiled==false and .security_current==false
' "$ledger/candidate-tree-report.json" >/dev/null || fail 'candidate source ledger contract failed'
test "$(wc -l < "$ledger/overlay-paths.txt")" -eq 28 || fail 'overlay count wrong'
test "$(LC_ALL=C sort -u "$ledger/overlay-paths.txt" | wc -l)" -eq 28 || fail 'overlay paths not unique'

# The pinned hashes are generated Vulpra-over-Firefox-160 postimages, not 159
# source preimages. This detects altered artifacts before semantic checks.
checked=0
while read -r path sha; do
  test -n "$path" && test -n "$sha" || fail 'bad source record'
  grep -Fxq "$path" "$ledger/overlay-paths.txt" || fail "source not in audited 28-path set: $path"
  file="$stage/$path"
  test -f "$file" && test ! -L "$file" || fail "missing staged source: $path"
  actual="$(git hash-object -- "$file")" || fail "cannot hash source: $path"
  test "$actual" = "$sha" || fail "source hash drift: $path"
  checked=$((checked+1))
done <<'PINNED'
toolkit/components/nimbus/NimbusBootstrap.sys.mjs df7e5b95aa96d930550d794753c1acef942c70da
toolkit/components/nimbus/moz.build 263de482d19bf6afa5ad0ae2e986ffad6d007456
toolkit/components/normandy/jar.mn 06317cdd540b6e32eeb195b555923795894f5b0e
toolkit/components/normandy/moz.build 42a6649255080bda8d1d5cfd787d2c52b7e1103e
toolkit/components/moz.build 4c22a26aee7a8b163e7b315864f5e4dd11946f52
browser/components/BrowserComponents.manifest 35571da687bec3207d3d28f03c959d6cd6bc2b9e
browser/components/DesktopActorRegistry.sys.mjs e6c50e85908a4c870185390d61e396e7004414cc
PINNED
test "$checked" -eq 7 || fail 'source family incomplete'

bridge="$stage/toolkit/components/nimbus/NimbusBootstrap.sys.mjs"
nimbus="$stage/toolkit/components/nimbus/moz.build"
normandy="$stage/toolkit/components/normandy/jar.mn"
normandy_build="$stage/toolkit/components/normandy/moz.build"
components="$stage/toolkit/components/moz.build"
manifest="$stage/browser/components/BrowserComponents.manifest"
actors="$stage/browser/components/DesktopActorRegistry.sys.mjs"

grep -Fq 'export const NimbusBootstrap = {' "$bridge" || fail 'Nimbus bootstrap export missing'
grep -Fq 'const UI_READY = "sessionstore-windows-restored";' "$bridge" || fail 'Nimbus lifecycle event missing'
grep -Fq '"resource://nimbus/ExperimentAPI.sys.mjs"' "$bridge" || fail 'Nimbus API URL missing'
grep -Fq 'await ExperimentAPI.init();' "$bridge" || fail 'Nimbus initialization missing'

grep -Fq 'not CONFIG["MOZ_NORMANDY"]' "$nimbus" || fail 'no-Normandy build guard missing'
grep -Fqx '    MOZ_SRC_FILES += ["NimbusBootstrap.sys.mjs"]' "$nimbus" || fail 'Nimbus bootstrap not registered for source packaging'
grep -Fq 'JAR_MANIFESTS += ["jar.mn"]' "$nimbus" || fail 'Nimbus jar registration missing'
grep -Fq 'JAR_MANIFESTS += ["jar.mn"]' "$normandy_build" || fail 'Normandy jar registration missing'
grep -Fq 'DIRS += ["normandy"]' "$components" || fail 'Normandy directory no longer traversed'
grep -Fq 'DIRS += ["nimbus"]' "$components" || fail 'Nimbus directory no longer traversed'
grep -Fq '    "widgets",' "$components" || fail 'Firefox 160 widgets component registration lost'

grep -Fqx '#ifdef MOZ_NORMANDY' "$normandy" || fail 'normal Normandy package preprocessor guard absent'
grep -Fqx '#else' "$normandy" || fail 'no-Normandy helper branch absent'
grep -Fqx '  res/normandy/lib/NormandyApi.sys.mjs (./lib/NormandyApi.sys.mjs)' "$normandy" ||
  fail 'NormandyApi helper absent'
grep -Fqx '  res/normandy/lib/NormandyUtils.sys.mjs (./lib/NormandyUtils.sys.mjs)' "$normandy" ||
  fail 'NormandyUtils helper absent'
grep -Fqx '  res/normandy/schemas/LegacyHeartbeat.schema.json (./schemas/LegacyHeartbeat.schema.json)' "$normandy" ||
  fail 'LegacyHeartbeat schema absent'
if grep -Fq 'ClientEnvironment.sys.mjs' "$normandy"; then
  fail 'removed upstream Firefox 160 ClientEnvironment module referenced'
fi
if grep -Fq 'normandy-content' "$normandy"; then
  fail 'removed upstream Firefox 160 normandy-content resource referenced'
fi

grep -Fqx '#ifdef XP_LINUX' "$manifest" || fail 'Linux-specific bridge guard absent'
grep -Fqx '#ifndef MOZ_NORMANDY' "$manifest" || fail 'no-Normandy startup guard absent'
grep -Fqx 'category browser-before-ui-startup moz-src:///toolkit/components/nimbus/NimbusBootstrap.sys.mjs NimbusBootstrap.init' "$manifest" ||
  fail 'Nimbus startup category missing'
grep -Fqx 'category browser-before-ui-startup resource://normandy/Normandy.sys.mjs Normandy.init' "$manifest" ||
  fail 'normal upstream Normandy startup missing'
grep -Fq 'delete JSWINDOWACTORS.ShieldFrame' "$actors" ||
  fail 'no-Normandy actor removal missing'

# The upstream ExperimentAPI import target is actually present in Firefox 160,
# published through the 160 jar and implements the initialization call.
test "$(git -C "$upstream" rev-parse HEAD)" = "2887d9de1f69c0e9776413da80e7ba0d1225dd9b" ||
  fail 'unverified upstream Nimbus source checkout'
test -f "$upstream/toolkit/components/nimbus/ExperimentAPI.sys.mjs" ||
  fail 'upstream ExperimentAPI source file missing'
test -f "$upstream/toolkit/components/nimbus/jar.mn" ||
  fail 'upstream Nimbus jar missing'
grep -Fq 'async init({ extraContext, forceSync = false } = {}) {' \
  "$upstream/toolkit/components/nimbus/ExperimentAPI.sys.mjs" ||
  fail 'upstream ExperimentAPI.init interface changed'
grep -Fq '  res/nimbus/ExperimentAPI.sys.mjs (./ExperimentAPI.sys.mjs)' \
  "$upstream/toolkit/components/nimbus/jar.mn" ||
  fail 'upstream resource URL no longer packaged'

candidate="$(jq -r .assembled_git_tree "$ledger/candidate-tree-report.json")"
jq -n --arg tree "$candidate" '{
  schema_version:1,
  kind:"firefox160_vulpra_bounded_nimbus_normandy_source_wiring",
  candidate_tree:$tree,
  exact_source_postimages_verified:7,
  nimbus_bootstrap_import_target_present_in_160:true,
  nimbus_bootstrap_init_interface_present_in_160:true,
  no_normandy_resource_helpers_retained:3,
  deleted_clientenvironment_not_reintroduced:true,
  standard_normandy_source_path_preserved:true,
  native_configured_in_this_test:false,
  no_normandy_native_configured:false,
  no_normandy_runtime_exercised:false,
  normal_runtime_exercised:false,
  security_current:false,
  release_ready:false
}' > "$report"
echo 'PASS: seven exact Firefox 160 Vulpra sources and upstream ExperimentAPI URI/init source wiring'
echo 'LIMIT: source-level checks only; no opt-in configure/native/runtime result'
