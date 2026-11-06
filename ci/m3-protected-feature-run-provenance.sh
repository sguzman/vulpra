#!/usr/bin/env bash
# Authenticates recorded M3 workflow provenance; NOT browser runtime,
# artifact content, full native FFI closure, or target workstation QA.
set -euo pipefail
repo=sguzman/vulpra
matrix=docs/vulpra/M3-PROTECTED-FEATURE-ACTIVATION-MATRIX-20261104.json
expected_runs() {
  cat <<'RUNS'
41762298450|96454f7a1fbe6b505af440c6c2c5fc91e798756d|M3 Source Matched Native Link Inputs and Runtime|.github/workflows/m3-source-matched-native-link.yml
41233793696|04ae6d102139e51ed26cbd0b8bc0f83373f7de25|M3 Combined Four-Opt-In Native JS WebExtension Nimbus Fallback|.github/workflows/m3-combined-four-native-webextension-smoke.yml
41724548163|5a87b673f6f702bc88178059fee86d7a63008626|M3 Original Browser Fatal Abort to Crashreporter Exec|.github/workflows/m3-original-browser-crashreporter-fatal-abort.yml
41161508642|4996b4de404e3fc1889952e7d31e882f497255ce|M3 Original Protected Auxiliary Diagnostic Native Loader ABI|.github/workflows/m3-original-auxiliary-guarded-cli.yml
41741770814|333baf74074b47c547f553654200fe598beacb2b|M3 Original Browser Pingsender Real Curl Perform No Egress|.github/workflows/m3-original-browser-pingsender-real-curl-perform.yml
41266875131|fd5a92b7ee108da4916d0860399000405547e663|M3 Arch FFmpeg63 Original Runtime ABI|.github/workflows/m3-arch-ffmpeg63-original-abi.yml
41161025114|b7eed71eac2cfa8246edb477c56241cb590090f7|M3 Original Native ClearKey CDM C ABI No-Egress Negative Probe|.github/workflows/m3-native-clearkey-abi.yml
41714793962|050206fc1bdb10e6f9717585f42c9ea570ba4c4b|M3 Original Browser WebAudio Noninterposing Glibc Bindings|.github/workflows/m3-original-browser-pulse-glibc-bindings.yml
41674689904|e1c4442ff053cd39017d72124a30cf93b9072075|M3 Original Browser USB Backend No-Device Loader Probe|.github/workflows/m3-original-browser-usb-nodevice-loader.yml
41567402153|a2e6a5f7374774fa8cccc6e99524ae3657f53be0|M3 Original ONNX External EP Factory Lifecycle|.github/workflows/m3-original-onnx-external-ep-lifecycle.yml
RUNS
}
verify_matrix() {
  local file="$1" expected
  expected="$(expected_runs | cut -d '|' -f 1 | jq -R 'tonumber' | jq -sc 'sort')"
  jq -e --argjson expected "$expected" '
    .schema_version == 1 and
    .kind == "m3_protected_feature_activation_acceptance_matrix" and
    .current_native_workflow_run == 41762298450 and
    .current_source_commit == "96454f7a1fbe6b505af440c6c2c5fc91e798756d" and
    .original_source_commit == "b1482404dfb8b01342990ee99ea3df0f9756b5f7" and
    (.features | length) == 18 and
    ([.current_native_workflow_run,
      (.features[].configuration.run),
      (.features[].current_behavior.run),
      (.features[].historical_behavior.run),
      (.features[].negative_fallback.run)]
      | map(select(. != null)) | unique | sort) == $expected and
    all(.features[];
      .protected_retain == true and
      .target_current_workstation_verified == false and
      .complete_feature_dependency_closure == false and
      .source_removal_authorized == false) and
    .m3_sixth_gate_closed == false and
    .actual_current_workstation_parity_proven == false and
    .conditional_native_ffi_dlopen_closure_proven == false and
    .source_removal_authorized == false
  ' "$file" >/dev/null
}
verify_run() {
  local file="$1" id="$2" sha="$3" name="$4" workflow="$5"
  jq -e --argjson id "$id" --arg sha "$sha" --arg name "$name" --arg workflow "$workflow" --arg repo "$repo" '
    .id == $id and .head_sha == $sha and .head_branch == "main" and
    .head_repository.full_name == $repo and .name == $name and
    .path == $workflow and .event == "push" and
    .status == "completed" and .conclusion == "success" and
    .run_attempt == 1
  ' "$file" >/dev/null
}
self_test() {
  verify_matrix "$matrix"
  local tmp id sha name workflow mutation failed=0
  tmp="$(mktemp -d)"
  trap "rm -rf -- '$tmp'" EXIT
  IFS='|' read -r id sha name workflow < <(expected_runs | head -n 1)
  jq -n --argjson id "$id" --arg sha "$sha" --arg name "$name" --arg workflow "$workflow" --arg repo "$repo" '
    {id:$id,head_sha:$sha,head_branch:"main",
     head_repository:{full_name:$repo},name:$name,path:$workflow,
     event:"push",status:"completed",conclusion:"success",run_attempt:1}
  ' > "$tmp/valid.json"
  verify_run "$tmp/valid.json" "$id" "$sha" "$name" "$workflow"
  while IFS= read -r mutation; do
    jq "$mutation" "$tmp/valid.json" > "$tmp/forged.json"
    if verify_run "$tmp/forged.json" "$id" "$sha" "$name" "$workflow" 2>/dev/null; then
      echo "FAIL: accepted forged Actions provenance: $mutation" >&2
      return 1
    fi
    failed=$((failed + 1))
  done <<'MUTATIONS'
.id = 123
.head_sha = ("0" * 40)
.head_branch = "security/firefox-159-postbeta-hotfixes"
.head_repository.full_name = "untrusted/fork"
.name = "another workflow"
.path = ".github/workflows/another.yml"
.event = "pull_request"
.status = "in_progress"
.conclusion = "failure"
.conclusion = null
.run_attempt = 2
del(.head_repository)
MUTATIONS
  jq '(.features[0].current_behavior.run) = 1' "$matrix" > "$tmp/forged-matrix.json"
  if verify_matrix "$tmp/forged-matrix.json" 2>/dev/null; then
    echo "FAIL: accepted forged source-matrix run reference" >&2; return 1
  fi
  failed=$((failed + 1))
  jq '.m3_sixth_gate_closed = true' "$matrix" > "$tmp/forged-matrix.json"
  if verify_matrix "$tmp/forged-matrix.json" 2>/dev/null; then
    echo "FAIL: accepted forged M3 gate closure" >&2; return 1
  fi
  failed=$((failed + 1))
  test "$failed" -eq 14
  echo "PASS: 14/14 forged run identities, matrix witness and gate claims rejected"
}
check_live() {
  verify_matrix "$matrix"
  command -v gh >/dev/null
  if test -z "$(printenv GH_TOKEN)"; then
    echo "FAIL: GitHub Actions read token is required" >&2; return 1
  fi
  local tmp id sha name workflow passed=0
  tmp="$(mktemp -d)"
  trap "rm -rf -- '$tmp'" EXIT
  while IFS='|' read -r id sha name workflow; do
    gh api "repos/$repo/actions/runs/$id" > "$tmp/run.json"
    if ! verify_run "$tmp/run.json" "$id" "$sha" "$name" "$workflow"; then
      echo "::error::Actions metadata mismatch for accepted M3 witness $id" >&2
      return 1
    fi
    passed=$((passed + 1))
  done < <(expected_runs)
  test "$passed" -eq 10
  echo "PASS: all ten M3 workflow witnesses authenticated by exact workflow, source SHA and outcome"
  echo "LIMIT: workflow metadata does not prove runtime details, full FFI closure, or workstation parity"
}
case "$*" in
  --self-test) self_test ;;
  --check-live) check_live ;;
  *) echo "Usage: $0 --self-test | --check-live" >&2; exit 2 ;;
esac
