#!/usr/bin/env bash
# Mutation-test the explicit M3 feature matrix without browser builds.
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
matrix="$root/docs/vulpra/M3-PROTECTED-FEATURE-ACTIVATION-MATRIX-20261104.json"
checker="$root/ci/m3-protected-feature-activation-matrix.jq"
tmp="$(mktemp -d -t vulpra-m3-feature-matrix.XXXXXXXX)"
trap 'rm -rf -- "$tmp"' EXIT
command -v jq >/dev/null || { echo "Missing jq" >&2; exit 2; }
jq -e -f "$checker" "$matrix" > "$tmp/accepted.json"
jq -e '
 .status=="bounded_protected_feature_matrix_consistent" and
 .protected_feature_count==18 and
 (.current_bounded_runtime_witnesses|length)==4 and
 (.historical_bounded_witnesses|length)==9 and
 (.negative_fallback_witnesses|length)==3 and
 (.current_runtime_unverified|length)==14 and
 (.negative_fallback_unverified|length)==15 and
 .actual_workstation_accepted==false and
 .complete_dynamic_or_ffi_graph==false and
 .m3_sixth_gate_closed==false
' "$tmp/accepted.json" >/dev/null
count=0
while IFS= read -r mutation; do
  test -n "$mutation" || continue
  jq "$mutation" "$matrix" > "$tmp/bad.json"
  if jq -e -f "$checker" "$tmp/bad.json" >/dev/null 2>"$tmp/error"; then
    echo "FAIL: forged metadata accepted: $mutation" >&2
    exit 1
  fi
  count=$((count+1))
done <<'MUTATIONS'
del(.features[0])
.features[1].id=.features[0].id
.features[2].id="invented_module"
.current_source_commit="0000000000000000000000000000000000000000"
.original_source_commit=.current_source_commit
.current_native_workflow_run+=1
.features[0].current_behavior.run+=1
.features[4].current_behavior={"status":"bounded_pass","run":41762298450,"source_commit":.current_source_commit}
.features[5].historical_behavior.run+=1
.features[7].historical_behavior={"status":"bounded_pass","run":41762298450,"kind":"current_browser_workload"}
.features[16].negative_fallback.source="current"
.features[10].negative_fallback={"status":"bounded_pass","run":41724548163,"source":"historical"}
.features[0].configuration.flag="MOZ_SANDBOX"
.features[6].configuration.value="0"
.features[8].configuration={"status":"observed_current","flag":"MOZ_SERVICES_SYNC","value":"0","run":41762298450}
.features[4].configuration.run=null
.features[2].target_current_workstation_verified=true
.features[13].complete_feature_dependency_closure=true
.features[15].source_removal_authorized=true
.features[7].protected_retain=false
.features[1].next_check=""
.source_removal_authorized=true
.all_protected_features_current_runtime_complete=true
.all_negative_fallbacks_complete=true
.conditional_native_ffi_dlopen_closure_proven=true
.actual_current_workstation_parity_proven=true
.m3_sixth_gate_closed=true
.features[17].negative_fallback={"status":"bounded_pass","run":41567402153,"source":"historical"}
MUTATIONS
test "$count" -eq 28
jq '.features[0].next_check="Run current Vulpra under a private real Hyprland GPU compositor with no profile mutations"' \
 "$matrix" > "$tmp/modified.json"
jq -e -f "$checker" "$tmp/modified.json" >/dev/null
echo "PASS: 18 protected features; 4 current, 9 historical and 3 bounded negative witnesses; 28/28 forged claims rejected"
