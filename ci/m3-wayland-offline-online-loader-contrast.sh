#!/usr/bin/env bash
# Compare two separately authenticated successful native loader workloads.
# Report JSON alone does not encode network mode; workflow proves run origin.
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo 'usage: m3-wayland-offline-online-loader-contrast.sh host-offline.json netns-online.json output.json' >&2
  exit 2
fi
for file in "$1" "$2"; do
  test -f "$file" || exit 2
  bytes="$(stat -c %s -- "$file")"
  ((bytes > 0 && bytes <= 131072)) || { echo 'FAIL: invalid input report size' >&2; exit 1; }
done
source='b1482404dfb8b01342990ee99ea3df0f9756b5f7'
archive='7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a'
check() {
  jq -e --arg src "$source" --arg sha "$archive" '
    def validname: type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+\\-]{0,110}$");
    def valid_edge:
      type=="object" and
      ((keys|sort)==["requested_library_basename","requester_basename"]) and
      (.requester_basename|validname) and
      (.requested_library_basename|validname);
    .schema_version==1 and
    .status=="actual_native_full_normal_loader_observation" and
    .old_normal_native_archive_source==$src and
    .old_normal_native_archive_sha256==$sha and
    .observed_workload_mode=="private_weston_wayland" and
    .real_native_webdriver_workload_passed==false and
    .real_native_wayland_surface_commit_passed==true and
    .browser_process_traces_with_libxul>=1 and
    .libxul_requested_in_real_browser_process==true and
    .libc_loader_init_observed==true and
    .raw_loader_traces_retained==false and
    .loader_request_edges_complete==false and
    .loader_init_name_is_exclusive_browser_requirement_proven==false and
    .complete_dlopen_graph_proven==false and
    .unexecuted_feature_routes_proven==false and
    .complete_dynamic_symbol_and_ABI_resolution_proven==false and
    .current_main_browser_recompiled==false and
    .new_source_removal_authorized==false and
    .new_compressed_savings_bytes==null and
    .whole_m3_feature_dependency_gate_completed==false and
    (.observed_loader_init_library_basenames|type=="array") and
    (.observed_loader_init_library_basenames|length)==.observed_loader_init_library_basename_count and
    (.observed_loader_init_library_basenames|length>=3) and
    (.observed_loader_init_library_basenames|.==unique) and
    (.observed_loader_init_library_basenames|all(.[];validname)) and
    (.observed_loader_init_library_basenames|index("libxul.so")!=null and index("libc.so.6")!=null) and
    (.loader_reported_needed_by_initialized_edges|type=="array") and
    (.loader_reported_dynamic_initialized_edges|type=="array") and
    (.loader_reported_needed_by_initialized_edges|length)==.loader_reported_needed_by_initialized_edge_count and
    (.loader_reported_dynamic_initialized_edges|length)==.loader_reported_dynamic_initialized_edge_count and
    (.loader_reported_needed_by_initialized_edges|.==unique) and
    (.loader_reported_dynamic_initialized_edges|.==unique) and
    (.loader_reported_needed_by_initialized_edges|all(.[];valid_edge)) and
    (.loader_reported_dynamic_initialized_edges|all(.[];valid_edge)) and
    ((.observed_loader_init_library_basenames) as $names |
     all(.loader_reported_needed_by_initialized_edges[]; .requested_library_basename as $target|$names|index($target)!=null)) and
    ((.observed_loader_init_library_basenames) as $names |
     all(.loader_reported_dynamic_initialized_edges[]; .requested_library_basename as $target|$names|index($target)!=null))
  ' "$1" >/dev/null
}
check "$1"
check "$2"
jq -n --slurpfile h "$1" --slurpfile n "$2" \
  --arg src "$source" --arg sha "$archive" '
  ($h[0]) as $h0 | ($n[0]) as $n0 |
  ($h0.observed_loader_init_library_basenames) as $h |
  ($n0.observed_loader_init_library_basenames) as $n |
  ($h0.loader_reported_needed_by_initialized_edges) as $hn |
  ($n0.loader_reported_needed_by_initialized_edges) as $nn |
  ($h0.loader_reported_dynamic_initialized_edges) as $hd |
  ($n0.loader_reported_dynamic_initialized_edges) as $nd |
  {
    schema_version: 1,
    source_commit: $src,
    compiled_archive_sha256: $sha,
    network_mode_provenance: "Authenticated separate successful Actions runs (outside source reports)",
    host_offline_loader_name_count: ($h|length),
    netns_online_loader_name_count: ($n|length),
    host_offline_needed_by_count: ($hn|length),
    netns_online_needed_by_count: ($nn|length),
    host_offline_dynamic_count: ($hd|length),
    netns_online_dynamic_count: ($nd|length),
    observed_both_initialized_basenames: ($h-($h-$n)),
    host_offline_only_initialized_basenames: ($h-$n),
    netns_online_only_initialized_basenames: ($n-$h),
    host_offline_only_needed_by_edges: ($hn-$nn),
    netns_online_only_needed_by_edges: ($nn-$hn),
    host_offline_only_dynamic_request_edges: ($hd-$nd),
    netns_online_only_dynamic_request_edges: ($nd-$hd),
    complete_feature_graph_proven: false,
    complete_symbol_abi_resolution_proven: false,
    equivalent_network_behavior_proven: false,
    new_source_removal_authorized: false,
    m3_sixth_gate_closed: false
  }' > "$3"
jq -e '
  .m3_sixth_gate_closed==false and
  .new_source_removal_authorized==false and
  ((.observed_both_initialized_basenames|length)+(.host_offline_only_initialized_basenames|length))==.host_offline_loader_name_count and
  ((.observed_both_initialized_basenames|length)+(.netns_online_only_initialized_basenames|length))==.netns_online_loader_name_count
' "$3" >/dev/null
jq -r '"PASS: source-pinned host OFFLINE vs netns ONLINE names: shared=\(.observed_both_initialized_basenames|length), host-only=\(.host_offline_only_initialized_basenames|length), online-only=\(.netns_online_only_initialized_basenames|length); needed-by exclusive host/online=\(.host_offline_only_needed_by_edges|length)/\(.netns_online_only_needed_by_edges|length); dynamic exclusive host/online=\(.host_offline_only_dynamic_request_edges|length)/\(.netns_online_only_dynamic_request_edges|length). M3 gate stays open."' "$3"
