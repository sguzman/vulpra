#!/usr/bin/env bash
# Negative controls for ORIGINAL CSS regression's independent native-source link.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
source_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
package_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
cat > "$tmp/replay.json" <<JSON
{"schema_version":1,"status":"passed_bounded_original_crashtest_replay","source_commit":"$source_sha","fixture_git_blob_sha1":"31a14963b356d869475bac62ca44991d9275a285","fixture":"testing/web-platform/tests/css/css-position/crashtests/inline-containing-block-delete-continuations-001.html","real_packaged_browser":true,"accept_insecure_certs":false,"temporary_profile_preserved":true,"official_wpt_harness_used":false,"memory_safety_exploit_rejection_proven":false,"security_current":false,"release_ready":false,"iterations":[{"iteration":0,"height":100},{"iteration":1,"height":120},{"iteration":2,"height":130}]}
JSON
cat > "$tmp/native.json" <<JSON
{"source_commit":"$source_sha","workflow_run_id":123,"runtime_passed_after_link_audit":true,"package":{"package_sha256":"$package_sha"}}
JSON
check() {
  jq -n --slurpfile replay "$1" --slurpfile native "$2" \
    --arg source "$source_sha" --argjson run 123 \
    -f ci/security-159-css-evidence.jq
}
check "$tmp/replay.json" "$tmp/native.json" > "$tmp/passed.json"
jq -e '.status=="bounded_css_regression_source_linked_reconciliation" and
        .three_real_packaged_replays_verified == true and
        .exploit_rejection_proven == false and
        .release_ready == false and
        .m3_sixth_gate_closed == false' "$tmp/passed.json" >/dev/null
n=0
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/replay.json" > "$tmp/forged.json"
  if check "$tmp/forged.json" "$tmp/native.json" >/dev/null 2>&1; then
    echo "FAIL: accepted tampered CSS report: $mutation" >&2
    exit 1
  fi
  n=$((n+1))
done <<'CSS_FORGERIES'
.status="success"
.source_commit="0000000000000000000000000000000000000000"
.fixture_git_blob_sha1="0000000000000000000000000000000000000000"
.fixture="other.html"
.real_packaged_browser=false
.accept_insecure_certs=true
.temporary_profile_preserved=false
.official_wpt_harness_used=true
.memory_safety_exploit_rejection_proven=true
.security_current=true
.release_ready=true
.iterations=[]
.iterations[0].height=0
.iterations[1].height="120"
.iterations[2].iteration=3
.iterations[0].iteration=1
CSS_FORGERIES
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/native.json" > "$tmp/forged-native.json"
  if check "$tmp/replay.json" "$tmp/forged-native.json" >/dev/null 2>&1; then
    echo "FAIL: accepted tampered native report: $mutation" >&2
    exit 1
  fi
  n=$((n+1))
done <<'NATIVE_FORGERIES'
.source_commit="0000000000000000000000000000000000000000"
.workflow_run_id=999
.runtime_passed_after_link_audit=false
.package.package_sha256="invalid"
NATIVE_FORGERIES
test "$n" -eq 20
echo "PASS: 20/20 CSS replay, native source and package forgeries rejected; normal valid source accepted"
