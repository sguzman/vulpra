#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
source='b1482404dfb8b01342990ee99ea3df0f9756b5f7'
archive='7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a'
jq -n --arg source "$source" --arg sha "$archive" '
  {schema_version:1,status:"actual_native_full_normal_loader_observation",
   old_normal_native_archive_source:$source,old_normal_native_archive_sha256:$sha,
   browser_process_traces_with_libxul:1,
   libxul_requested_in_real_browser_process:true,libc_loader_init_observed:true,
   raw_loader_traces_retained:false,whole_m3_feature_dependency_gate_completed:false,
   new_source_removal_authorized:false,new_compressed_savings_bytes:null,
   complete_dynamic_symbol_and_ABI_resolution_proven:false,
   complete_dlopen_graph_proven:false,unexecuted_feature_routes_proven:false,
   observed_workload_mode:"headless_webdriver",
   real_native_webdriver_workload_passed:true,
   real_native_wayland_surface_commit_passed:false,
   observed_loader_init_library_basename_count:3,
   observed_loader_init_library_basenames:["libc.so.6","libxul.so","one.so"]}
' > "$work/headless.json"
jq '
  .observed_workload_mode="private_weston_wayland" |
  .real_native_webdriver_workload_passed=false |
  .real_native_wayland_surface_commit_passed=true |
  .observed_loader_init_library_basenames=["libc.so.6","libxul.so","two.so"]
' "$work/headless.json" > "$work/wayland.json"
bash "$root/ci/m3-graphical-loader-workload-diff.sh" "$work/headless.json" \
  "$work/wayland.json" "$work/output.json"
# Historical authenticated headless schema predated explicit mode/Wayland
# fields. The fallback must apply only to the old headless record.
jq 'del(.observed_workload_mode, .real_native_wayland_surface_commit_passed)' \
  "$work/headless.json" > "$work/old-headless.json"
bash "$root/ci/m3-graphical-loader-workload-diff.sh" \
  "$work/old-headless.json" "$work/wayland.json" "$work/legacy.json"
jq -e '.observed_both_count==2 and .m3_sixth_gate_closed==false' \
  "$work/legacy.json" >/dev/null
jq -e '
  .observed_both_count==2 and
  .observed_headless_only_count==1 and
  .observed_wayland_only_count==1 and
  .observed_wayland_only_library_basenames==["two.so"] and
  .m3_sixth_gate_closed==false
' "$work/output.json" >/dev/null
reject() {
  if bash "$root/ci/m3-graphical-loader-workload-diff.sh" \
    "$work/headless.json" "$work/bad.json" "$work/rejected.json" \
    >"$work/error.log" 2>&1; then
    echo 'FAIL: invalid native-loader evidence was accepted' >&2
    exit 1
  fi
}
jq '.old_normal_native_archive_sha256="forged"' "$work/wayland.json" >"$work/bad.json"
reject
jq '.observed_loader_init_library_basenames=["/private/a.so","libc.so.6","libxul.so"]' \
  "$work/wayland.json" >"$work/bad.json"
reject
jq '.observed_loader_init_library_basenames=["libc.so.6","libxul.so","libxul.so"]' \
  "$work/wayland.json" >"$work/bad.json"
reject
jq '.observed_loader_init_library_basename_count=9' "$work/wayland.json" >"$work/bad.json"
reject
jq '.real_native_wayland_surface_commit_passed=false' "$work/wayland.json" >"$work/bad.json"
reject
echo 'PASS: loader workload diff accepts valid signed-source shapes and rejects wrong SHA, unsafe names, duplicates, mismatched counts, and false graphical acceptance'
