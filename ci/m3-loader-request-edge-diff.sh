#!/usr/bin/env bash
# Reconcile observed GNU-loader request relations for two authenticated native
# browser workloads. This is not the full feature, ABI, dlopen or Arch graph.
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo 'usage: m3-loader-request-edge-diff.sh headless.json graphical.json output.json' >&2
  exit 2
fi
headless="$(realpath -e -- "$1")"
graphical="$(realpath -e -- "$2")"
out="$3"
root="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
bash "$root/ci/m3-graphical-loader-workload-diff.sh" \
  "$headless" "$graphical" "$tmp/names.json"
for report in "$headless" "$graphical"; do
  jq -e '
    .request_relationships_from_same_browser_pid_trace==true and
    .only_initialized_request_targets_included==true and
    .loader_request_edges_complete==false and
    (.loader_reported_needed_by_initialized_edges|type=="array") and
    (.loader_reported_dynamic_initialized_edges|type=="array") and
    (.loader_reported_needed_by_initialized_edges|length)==
      .loader_reported_needed_by_initialized_edge_count and
    (.loader_reported_dynamic_initialized_edges|length)==
      .loader_reported_dynamic_initialized_edge_count and
    (.observed_loader_init_library_basenames) as $names |
    (
      [.loader_reported_needed_by_initialized_edges[],
       .loader_reported_dynamic_initialized_edges[]] as $all |
      (($all|unique|length)==($all|length)) and
      (($all|length)<=10000) and
      all($all[];
        (.requester_basename|type=="string" and
         test("^[A-Za-z0-9][A-Za-z0-9_.+\\-]{0,110}$")) and
        (.requested_library_basename|type=="string" and
         test("^[A-Za-z0-9][A-Za-z0-9_.+\\-]{0,110}$")) and
        (.requested_library_basename as $name | ($names|index($name)!=null)))
    )
  ' "$report" >/dev/null
done
jq -n --slurpfile h "$headless" --slurpfile g "$graphical" \
  --slurpfile names "$tmp/names.json" '
    ($h[0].loader_reported_needed_by_initialized_edges) as $hn |
    ($g[0].loader_reported_needed_by_initialized_edges) as $gn |
    ($h[0].loader_reported_dynamic_initialized_edges) as $hd |
    ($g[0].loader_reported_dynamic_initialized_edges) as $gd |
    ($hn-$gn) as $hn_only |
    ($gn-$hn) as $gn_only |
    ($hd-$gd) as $hd_only |
    ($gd-$hd) as $gd_only |
    {
      schema_version:1,
      source_commit:$names[0].source_commit,
      compiled_archive_sha256:$names[0].compiled_archive_sha256,
      headless_needed_by_count:($hn|length),
      graphical_needed_by_count:($gn|length),
      needed_by_both_count:(($hn-$hn_only)|length),
      needed_by_headless_only_count:($hn_only|length),
      needed_by_graphical_only_count:($gn_only|length),
      headless_dynamic_request_count:($hd|length),
      graphical_dynamic_request_count:($gd|length),
      dynamic_both_count:(($hd-$hd_only)|length),
      dynamic_headless_only_count:($hd_only|length),
      dynamic_graphical_only_count:($gd_only|length),
      needed_by_graphical_only_edges:$gn_only,
      dynamic_graphical_only_edges:$gd_only,
      observed_unique_graphical_names: $names[0].observed_wayland_only_library_basenames,
      observed_only_in_executed_workloads_not_feature_exclusivity:true,
      request_target_had_glibc_init_event:true,
      file_paths_and_raw_pids_retained:false,
      full_source_feature_graph_proven:false,
      full_dlopen_graph_proven:false,
      dynamic_symbol_abi_closure_proven:false,
      further_source_removal_authorized:false,
      m3_sixth_gate_closed:false
    }
  ' > "$out"
jq -e '
  (.needed_by_both_count+.needed_by_headless_only_count)==.headless_needed_by_count and
  (.needed_by_both_count+.needed_by_graphical_only_count)==.graphical_needed_by_count and
  (.dynamic_both_count+.dynamic_headless_only_count)==.headless_dynamic_request_count and
  (.dynamic_both_count+.dynamic_graphical_only_count)==.graphical_dynamic_request_count and
  .m3_sixth_gate_closed==false
' "$out" >/dev/null
jq -r '"PASS: real initialized-target request relations: needed-by both=\(.needed_by_both_count), headless-only=\(.needed_by_headless_only_count), graphical-only=\(.needed_by_graphical_only_count); dynamically-loaded both=\(.dynamic_both_count), headless-only=\(.dynamic_headless_only_count), graphical-only=\(.dynamic_graphical_only_count). No completed ABI/dlopen/feature map."' "$out"
