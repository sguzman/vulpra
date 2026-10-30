#!/usr/bin/env bash
# Compare proven native loader INIT names between two distinct workloads.
# "Observed only" means only in THESE traces: it does not mean Wayland
# requires the name, that the library was loaded via dlopen, or that another
# feature could safely remove it.
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo 'usage: m3-graphical-loader-workload-diff.sh headless.json wayland.json output.json' >&2
  exit 2
fi
headless="$(realpath -e -- "$1")"
graphical="$(realpath -e -- "$2")"
out="$3"
source='b1482404dfb8b01342990ee99ea3df0f9756b5f7'
archive='7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a'
for path in "$headless" "$graphical"; do
  test "$(stat -c %s -- "$path")" -le 131072
  test "$(stat -c %s -- "$path")" -gt 0
done
check() {
  local file="$1"
  local mode="$2"
  jq -e --arg sha "$archive" --arg source "$source" --arg mode "$mode" '
    .schema_version==1 and
    .status=="actual_native_full_normal_loader_observation" and
    .old_normal_native_archive_source==$source and
    .old_normal_native_archive_sha256==$sha and
    # Historical headless report predates explicit workload fields. Accept
    # only their absence in headless mode, never spoof the new graphical flag.
    ((.observed_workload_mode==$mode) or
      ($mode=="headless_webdriver" and (has("observed_workload_mode")|not))) and
    .browser_process_traces_with_libxul>=1 and
    .libxul_requested_in_real_browser_process==true and
    .libc_loader_init_observed==true and
    .raw_loader_traces_retained==false and
    .whole_m3_feature_dependency_gate_completed==false and
    .new_source_removal_authorized==false and
    .new_compressed_savings_bytes==null and
    .complete_dynamic_symbol_and_ABI_resolution_proven==false and
    .complete_dlopen_graph_proven==false and
    .unexecuted_feature_routes_proven==false and
    (if $mode=="headless_webdriver"
     then (.real_native_webdriver_workload_passed==true and
           ((.real_native_wayland_surface_commit_passed==false) or
            (has("real_native_wayland_surface_commit_passed")|not)))
     else (.real_native_webdriver_workload_passed==false and
           .real_native_wayland_surface_commit_passed==true and
           .observed_workload_mode=="private_weston_wayland")
     end) and
    (.observed_loader_init_library_basenames|type=="array") and
    (.observed_loader_init_library_basenames|length)==
      .observed_loader_init_library_basename_count and
    (.observed_loader_init_library_basenames|
      .==(unique) and
      (all(.[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+\\-]{0,110}$")))) and
    (.observed_loader_init_library_basenames|
      index("libxul.so")!=null and index("libc.so.6")!=null)
  ' "$file" >/dev/null
}
check "$headless" headless_webdriver
check "$graphical" private_weston_wayland
jq -n --slurpfile headless "$headless" --slurpfile graphical "$graphical" \
  --arg source "$source" --arg archive "$archive" '
    ($headless[0].observed_loader_init_library_basenames) as $h |
    ($graphical[0].observed_loader_init_library_basenames) as $g |
    ($h-$g) as $honly |
    ($g-$h) as $gonly |
    ($h-$honly) as $both |
    {
      schema_version: 1,
      source_commit: $source,
      compiled_archive_sha256: $archive,
      workload_labels: ["headless_webdriver", "private_weston_wayland_in_disconnected_netns"],
      observed_headless_library_name_count: ($h|length),
      observed_wayland_library_name_count: ($g|length),
      observed_both_count: ($both|length),
      observed_headless_only_count: ($honly|length),
      observed_wayland_only_count: ($gonly|length),
      observed_both_library_basenames: $both,
      observed_headless_only_library_basenames: $honly,
      observed_wayland_only_library_basenames: $gonly,
      raw_trace_paths_or_pids_retained: false,
      full_feature_graph_proven: false,
      full_dlopen_graph_proven: false,
      abi_symbol_resolution_proven: false,
      arch_hyprland_runtime_proven: false,
      further_source_removal_authorized: false,
      m3_sixth_gate_closed: false,
      interpretation: "Libraries seen only in one executed trace are not proven exclusively required by that feature or absent from other possible workloads."
    }
  ' > "$out"
jq -e '
  (.observed_both_count + .observed_headless_only_count)==.observed_headless_library_name_count and
  (.observed_both_count + .observed_wayland_only_count)==.observed_wayland_library_name_count and
  .full_feature_graph_proven==false and
  .further_source_removal_authorized==false
' "$out" >/dev/null
jq -r '"PASS: source-pinned graphical/headless native loader contrast: both=\(.observed_both_count), headless-only=\(.observed_headless_only_count), graphical-only=\(.observed_wayland_only_count). No complete dependency-graph or safe-source-removal credit."' "$out"
