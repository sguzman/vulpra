#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../.." && pwd -P)"
script="$root/ci/m3-wayland-offline-online-loader-contrast.sh"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
for extra in libhost.so libonline.so; do
  jq -n --arg extra "$extra" '
    ["libc.so.6",$extra,"libxul.so"]|sort as $names |
    {
      schema_version:1,
      status:"actual_native_full_normal_loader_observation",
      old_normal_native_archive_source:"b1482404dfb8b01342990ee99ea3df0f9756b5f7",
      old_normal_native_archive_sha256:"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a",
      observed_workload_mode:"private_weston_wayland",
      real_native_webdriver_workload_passed:false,
      real_native_wayland_surface_commit_passed:true,
      browser_process_traces_with_libxul:1,
      libxul_requested_in_real_browser_process:true,
      libc_loader_init_observed:true,
      raw_loader_traces_retained:false,
      loader_request_edges_complete:false,
      loader_init_name_is_exclusive_browser_requirement_proven:false,
      complete_dlopen_graph_proven:false,
      unexecuted_feature_routes_proven:false,
      complete_dynamic_symbol_and_ABI_resolution_proven:false,
      current_main_browser_recompiled:false,
      new_source_removal_authorized:false,
      new_compressed_savings_bytes:null,
      whole_m3_feature_dependency_gate_completed:false,
      observed_loader_init_library_basenames:$names,
      observed_loader_init_library_basename_count:($names|length),
      loader_reported_needed_by_initialized_edges:[{requester_basename:"libxul.so",requested_library_basename:$extra}],
      loader_reported_needed_by_initialized_edge_count:1,
      loader_reported_dynamic_initialized_edges:[],
      loader_reported_dynamic_initialized_edge_count:0
    }' > "$work/$extra.json"
done
bash "$script" "$work/libhost.so.json" "$work/libonline.so.json" "$work/output.json" > "$work/pass.log"
jq -e '
  (.observed_both_initialized_basenames|length)==2 and
  .host_offline_only_initialized_basenames==["libhost.so"] and
  .netns_online_only_initialized_basenames==["libonline.so"] and
  (.host_offline_only_needed_by_edges|length)==1 and
  (.netns_online_only_needed_by_edges|length)==1 and
  .m3_sixth_gate_closed==false and
  .new_source_removal_authorized==false
' "$work/output.json" >/dev/null
for tweak in '
  .old_normal_native_archive_sha256="spoofed"
' '
  .observed_loader_init_library_basenames+=["libxul.so"] |
  .observed_loader_init_library_basename_count+=1
' '
  .loader_reported_needed_by_initialized_edges[0].requested_library_basename="not-initialized.so"
' '
  .loader_reported_needed_by_initialized_edges[0].requester_basename="/private/secret"
' '
  .new_source_removal_authorized=true
' '
  .real_native_wayland_surface_commit_passed=false
'; do
  jq "$tweak" "$work/libhost.so.json" > "$work/bad.json"
  if bash "$script" "$work/bad.json" "$work/libonline.so.json" "$work/rejected.json" > "$work/fail.log" 2>&1; then
    echo 'FAIL: invalid loader evidence accepted' >&2
    exit 1
  fi
done
if grep -Eq '/private/secret|/tmp|pid=' "$work/output.json"; then
  echo 'FAIL: rejected raw paths or trace IDs leak into report' >&2
  exit 1
fi
echo 'PASS: synthetic distinct name/edge sets and six provenance/policy rejection fixtures'
