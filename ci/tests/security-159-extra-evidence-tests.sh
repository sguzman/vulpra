#!/usr/bin/env bash
# Synthetic attacks on the independent original Mozilla SVG/table/multicol
# browser-evidence reconciliation. They are NOT actual browser execution.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
source_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
package_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
cat > "$tmp/native.json" <<JSON
{"source_commit":"$source_sha","workflow_run_id":123,"runtime_passed_after_link_audit":true,"package":{"package_sha256":"$package_sha"}}
JSON
jq -n --arg sha "$source_sha" '
  {
    schema_version: 1,
    status: "passed_bounded_original_extra_crashtests",
    source_commit: $sha,
    real_packaged_browser: true,
    accept_insecure_certs: false,
    temporary_profile_preserved: true,
    original_mozilla_fixture_hashes_verified: true,
    official_wpt_harness_used: false,
    memory_safety_exploit_rejection_proven: false,
    security_current: false, release_ready: false,
    cases: [
      {name:"multicol", fixture:"testing/web-platform/tests/css/css-multicol/crashtests/block-break-before.html",git_blob_sha1:"bfb5f0894b80bf39633afcf37be9fdcbb68ab96c",iterations:[{iteration:0,height:150},{iteration:1,height:155}]},
      {name:"svg",fixture:"layout/svg/crashtests/2079252.html",git_blob_sha1:"a8d78aae061029dcc7cb72e86a18647b2d483625",iterations:[{iteration:0,height:175},{iteration:1,height:180}]},
      {name:"table",fixture:"testing/web-platform/tests/css/css-tables/crashtests/border-collapse-dynamic-crash.html",git_blob_sha1:"6d716acb679c1f174e75a4d3d6ddfc85dcba7852",iterations:[{iteration:0,height:210},{iteration:1,height:215}]}
    ]
  }
' > "$tmp/replay.json"
check() {
  jq -n --slurpfile replay "$1" --slurpfile native "$2" \
    --arg source "$source_sha" --argjson run 123 \
    -f ci/security-159-extra-crashtest-evidence.jq
}
check "$tmp/replay.json" "$tmp/native.json" > "$tmp/accepted.json"
jq -e '
  .schema_version == 1 and
  .status == "bounded_extra_crashtests_source_linked_reconciliation" and
  .real_packaged_fixture_replays == 6 and
  (.original_mozilla_fixture_blobs | length == 3) and
  .exploit_rejection_proven == false and
  .release_ready == false and
  .m3_sixth_gate_closed == false
' "$tmp/accepted.json" >/dev/null
n=0
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/replay.json" > "$tmp/forged.json"
  if check "$tmp/forged.json" "$tmp/native.json" >/dev/null 2>&1; then
    echo "FAIL: accepted forged browser record: $mutation" >&2
    exit 1
  fi
  n=$((n + 1))
done <<'REPLAY_FORGERIES'
.status="passed_fake"
.source_commit="0000000000000000000000000000000000000000"
.real_packaged_browser=false
.accept_insecure_certs=true
.temporary_profile_preserved=false
.original_mozilla_fixture_hashes_verified=false
.official_wpt_harness_used=true
.memory_safety_exploit_rejection_proven=true
.security_current=true
.release_ready=true
.cases=[]
.cases |= .[:-1]
.cases[0].name="unknown"
.cases[0].name="svg"
.cases[0].fixture="wrong.html"
.cases[0].git_blob_sha1="0000000000000000000000000000000000000000"
.cases[1].fixture="not-original-svg.html"
.cases[1].git_blob_sha1="bad"
.cases[2].git_blob_sha1="0000000000000000000000000000000000000000"
.cases[2].iterations=[]
.cases[1].iterations[1].iteration=0
.cases[1].iterations[0].height=0
.cases[2].iterations[1].height="215"
.cases[0].iterations[0].height=1.25
REPLAY_FORGERIES
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/native.json" > "$tmp/forged-native.json"
  if check "$tmp/replay.json" "$tmp/forged-native.json" >/dev/null 2>&1; then
    echo "FAIL: accepted forged native record: $mutation" >&2
    exit 1
  fi
  n=$((n + 1))
done <<'NATIVE_FORGERIES'
.source_commit="0000000000000000000000000000000000000000"
.workflow_run_id=999
.runtime_passed_after_link_audit=false
.package.package_sha256="invalid"
NATIVE_FORGERIES
test "$n" -eq 28
echo "PASS: 28/28 forged SVG/table/multicol and native linkage reports rejected"
