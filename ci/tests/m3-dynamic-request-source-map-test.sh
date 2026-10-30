#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
test -f "$root/ci/m3-dynamic-request-source-map.sh"
# This test is run from an exact historical Git checkout, on purpose:
# only the guard script comes from the current working tree.
if [[ $# -ne 1 ]]; then
  echo 'usage: m3-dynamic-request-source-map-test.sh pinned-historical-source-root' >&2
  exit 2
fi
src="$(realpath -e -- "$1")"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
jq -n '
  {schema_version:1,
   source_commit:"b1482404dfb8b01342990ee99ea3df0f9756b5f7",
   compiled_archive_sha256:"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a",
   headless_dynamic_request_count:18,
   graphical_dynamic_request_count:21,
   dynamic_both_count:18,dynamic_headless_only_count:0,
   dynamic_graphical_only_count:3,
   request_target_had_glibc_init_event:true,
   file_paths_and_raw_pids_retained:false,
   full_source_feature_graph_proven:false,full_dlopen_graph_proven:false,
   dynamic_symbol_abi_closure_proven:false,further_source_removal_authorized:false,
   m3_sixth_gate_closed:false,
   dynamic_graphical_only_edges:[
     {requester_basename:"libnspr4.so",requested_library_basename:"libavcodec.so.60"},
     {requester_basename:"libxul.so",requested_library_basename:"libgbm.so.1"},
     {requester_basename:"libxul.so",requested_library_basename:"libpulse.so.0"}
   ]}
' > "$work/valid.json"
bash "$root/ci/m3-dynamic-request-source-map.sh" \
  "$work/valid.json" "$src" "$work/output.json"
jq -e '
  .source_candidates_confirmed_with_exact_original_tree==true and
  .observed_three_dynamic_library_requests|length==3
' "$work/output.json" >/dev/null
reject() {
  if bash "$root/ci/m3-dynamic-request-source-map.sh" \
    "$work/invalid.json" "$src" "$work/invalid-output.json" >"$work/err" 2>&1; then
    echo 'FAIL: invalid observed loader edge contract was accepted' >&2
    exit 1
  fi
}
jq '.dynamic_graphical_only_edges[1].requested_library_basename="libfake.so"' \
  "$work/valid.json" >"$work/invalid.json"
reject
jq '.dynamic_graphical_only_edges[0].requester_basename="libxul.so"' \
  "$work/valid.json" >"$work/invalid.json"
reject
jq '.source_commit="forged"' "$work/valid.json" >"$work/invalid.json"
reject
jq '.m3_sixth_gate_closed=true' "$work/valid.json" >"$work/invalid.json"
reject
jq '.dynamic_graphical_only_edges +=
     [{requester_basename:"libxul.so",requested_library_basename:"libother.so"}]' \
  "$work/valid.json" >"$work/invalid.json"
reject
echo 'PASS: exact pinned-source dynamic request source mapping rejects wrong target, wrong requester, altered source, invented M3 completion and extra edge'
