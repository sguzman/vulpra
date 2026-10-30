#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
src='b1482404dfb8b01342990ee99ea3df0f9756b5f7'
sha='7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a'
jq -n --arg src "$src" --arg sha "$sha" '
  {schema_version:1,status:"actual_native_full_normal_loader_observation",
   old_normal_native_archive_source:$src,old_normal_native_archive_sha256:$sha,
   browser_process_traces_with_libxul:1,libxul_requested_in_real_browser_process:true,
   libc_loader_init_observed:true,raw_loader_traces_retained:false,
   whole_m3_feature_dependency_gate_completed:false,new_source_removal_authorized:false,
   new_compressed_savings_bytes:null,
   complete_dynamic_symbol_and_ABI_resolution_proven:false,
   complete_dlopen_graph_proven:false,unexecuted_feature_routes_proven:false,
   observed_workload_mode:"headless_webdriver",
   real_native_webdriver_workload_passed:true,
   real_native_wayland_surface_commit_passed:false,
   observed_loader_init_library_basename_count:3,
   observed_loader_init_library_basenames:["libc.so.6","libfoo.so","libxul.so"],
   request_relationships_from_same_browser_pid_trace:true,
   only_initialized_request_targets_included:true,
   loader_request_edges_complete:false,
   loader_reported_needed_by_initialized_edge_count:1,
   loader_reported_needed_by_initialized_edges:[
      {requester_basename:"vulpra-bin",requested_library_basename:"libxul.so"}],
   loader_reported_dynamic_initialized_edge_count:1,
   loader_reported_dynamic_initialized_edges:[
      {requester_basename:"libxul.so",requested_library_basename:"libfoo.so"}]}
' > "$work/h.json"
jq '
  .observed_workload_mode="private_weston_wayland" |
  .real_native_webdriver_workload_passed=false |
  .real_native_wayland_surface_commit_passed=true |
  .observed_loader_init_library_basenames=["libc.so.6","libfoo.so","libxul.so","two.so"] |
  .observed_loader_init_library_basename_count=4 |
  .loader_reported_needed_by_initialized_edges += [
     {requester_basename:"libxul.so",requested_library_basename:"two.so"}] |
  .loader_reported_needed_by_initialized_edge_count=2
' "$work/h.json" > "$work/g.json"
bash "$root/ci/m3-loader-request-edge-diff.sh" "$work/h.json" "$work/g.json" "$work/out.json"
jq -e '
  .needed_by_both_count==1 and .needed_by_graphical_only_count==1 and
  .dynamic_both_count==1 and .dynamic_graphical_only_count==0 and
  .m3_sixth_gate_closed==false
' "$work/out.json" >/dev/null
reject() {
  if bash "$root/ci/m3-loader-request-edge-diff.sh" "$work/h.json" \
    "$work/bad.json" "$work/rejected.json" >"$work/error.log" 2>&1; then
    echo 'FAIL: forged network loader request relationships accepted' >&2
    exit 1
  fi
}
jq '.loader_reported_needed_by_initialized_edge_count=999' "$work/g.json" >"$work/bad.json"
reject
jq '.loader_reported_dynamic_initialized_edges=[{requester_basename:"/home/secret",requested_library_basename:"libfoo.so"}]' \
 "$work/g.json" >"$work/bad.json"
reject
jq '.loader_reported_dynamic_initialized_edges=[{requester_basename:"libxul.so",requested_library_basename:"not-initialized.so"}]' \
 "$work/g.json" >"$work/bad.json"
reject
jq '.loader_request_edges_complete=true' "$work/g.json" >"$work/bad.json"
reject
echo 'PASS: actual initialized-target edge graph fixture, wrong counts, path leak, unloaded target and fabricated completion rejected'
