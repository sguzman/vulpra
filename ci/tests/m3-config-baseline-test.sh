#!/usr/bin/env bash
set -Eeuo pipefail
RUNNER="${1:?Pass absolute config probe path}"
R=$(mktemp -d)
trap 'rm -rf -- "$R"' EXIT
repo="$R/vulpra"
obj="$R/native-obj"
mkdir -p "$repo" "$obj/config.statusd/substs"
git -C "$repo" init -q
git -C "$repo" config user.name "CI Probe"
git -C "$repo" config user.email "test@example.invalid"
printf 'baseline\n' > "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm 'synthetic source'
base=$(git -C "$repo" rev-parse HEAD)
sub="$obj/config.statusd/substs"
printf '"browser"\n' > "$sub/MOZ_BUILD_APP"
printf '"gtk"\n' > "$sub/MOZ_WIDGET_TOOLKIT"
printf 'true\n' > "$sub/MOZ_SERVICES_SYNC"
printf 'false\n' > "$sub/MOZ_TELEMETRY_REPORTING"
printf '"all"\n' > "$sub/MOZ_DEVTOOLS"
printf 'null\n' > "$sub/MOZ_NORMANDY"
bash "$RUNNER" "$repo" "$obj" > "$R/output" 2>&1 || {
  cat "$R/output"
  exit 1
}
test "$(git -C "$repo" rev-parse HEAD)" = "$base"
test -z "$(git -C "$repo" status --porcelain)"
test -s "$repo/.git/vulpra-debloat/m3-config-baseline.tsv"
grep -Fq $'MOZ_SERVICES_SYNC\tobserved\ttrue' "$repo/.git/vulpra-debloat/m3-config-baseline.tsv"
grep -Fq $'MOZ_TELEMETRY_REPORTING\tobserved\tfalse' "$repo/.git/vulpra-debloat/m3-config-baseline.tsv"
grep -Fq $'MOZ_DEVTOOLS\tobserved\t"all"' "$repo/.git/vulpra-debloat/m3-config-baseline.tsv"
grep -Fq $'MOZ_NORMANDY\tnot-recorded\tnull' "$repo/.git/vulpra-debloat/m3-config-baseline.tsv"
grep -Fq $'MOZ_UPDATER\tnot-recorded\t(missing)' "$repo/.git/vulpra-debloat/m3-config-baseline.tsv"
echo 'PASS: exact generated configure JSON values distinguished from missing values'
test ! -e "$repo/config.statusd"
test ! -e "$obj/output"
echo 'PASS: source tree, HEAD and build metadata were not modified'
rm -f "$sub/MOZ_WIDGET_TOOLKIT"
set +e
bash "$RUNNER" "$repo" "$obj" > "$R/bad" 2>&1
status=$?
set -e
[[ "$status" == 3 ]] || { cat "$R/bad"; echo "FAIL: missing identity gave $status"; exit 2; }
grep -Fq 'Build identity keys missing' "$R/bad"
echo 'PASS: refuses unidentified build metadata'
echo 'PASS: M3 read-only native configuration probe regressions'
