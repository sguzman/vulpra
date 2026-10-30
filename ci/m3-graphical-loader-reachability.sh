#!/usr/bin/env bash
# Reachability through ONLY observed glibc needed-by edges in two authentic
# runtime workloads. Reachability != exclusive ownership, required library,
# safe pruning, full dlopen closure, or native call-stack identification.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo 'usage: m3-graphical-loader-reachability.sh real-edge-contrast.json report.json' >&2
  exit 2
fi
input="$(realpath -e -- "$1")"
output="$2"
source='b1482404dfb8b01342990ee99ea3df0f9756b5f7'
archive='7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a'
test "$(stat -c %s -- "$input")" -gt 0
test "$(stat -c %s -- "$input")" -le 131072
jq -e --arg src "$source" --arg sha "$archive" '
  .schema_version==1 and
  .source_commit==$src and .compiled_archive_sha256==$sha and
  .graphical_needed_by_count==147 and .needed_by_both_count==80 and
  .needed_by_headless_only_count==0 and .needed_by_graphical_only_count==67 and
  .headless_dynamic_request_count==18 and .graphical_dynamic_request_count==21 and
  .dynamic_both_count==18 and .dynamic_headless_only_count==0 and
  .dynamic_graphical_only_count==3 and
  .request_target_had_glibc_init_event==true and
  .file_paths_and_raw_pids_retained==false and
  .full_source_feature_graph_proven==false and
  .full_dlopen_graph_proven==false and
  .dynamic_symbol_abi_closure_proven==false and
  .m3_sixth_gate_closed==false and
  (.observed_unique_graphical_names|type=="array") and
  (.observed_unique_graphical_names|length)==58 and
  (.observed_unique_graphical_names|unique|length)==58 and
  all(.observed_unique_graphical_names[];
    type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+\\-]{0,110}$")) and
  (.needed_by_graphical_only_edges|length)==67 and
  (.needed_by_graphical_only_edges|unique|length)==67 and
  (
    [.needed_by_graphical_only_edges[] | .requester_basename,.requested_library_basename] |
    all(.[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+\\-]{0,110}$"))
  ) and
  (
    (.dynamic_graphical_only_edges|sort_by(.requester_basename,.requested_library_basename))==
    [
      {requester_basename:"libnspr4.so",requested_library_basename:"libavcodec.so.60"},
      {requester_basename:"libxul.so",requested_library_basename:"libgbm.so.1"},
      {requester_basename:"libxul.so",requested_library_basename:"libpulse.so.0"}
    ]
  ) and
  (["libavcodec.so.60","libgbm.so.1","libpulse.so.0"] -
     .observed_unique_graphical_names | length)==0
' "$input" >/dev/null
# Finite, cycle-safe graph closure: unique set only increases, and after 64
# rounds it must have reached fixpoint for the 58 observable extra nodes.
jq '
  def walk($edges):
    reduce range(0;64) as $i (.;
      . as $seen |
      (($seen +
        [$edges[] |
          select(.requester_basename as $src | ($seen|index($src)) != null) |
          .requested_library_basename]) | unique)
    );
  def subset($valid): map(. as $item | select(($valid|index($item)) != null));
  . as $d |
  ($d.needed_by_graphical_only_edges) as $edges |
  ($d.observed_unique_graphical_names) as $g |
  (["libavcodec.so.60"] | walk($edges) | subset($g)) as $codec |
  (["libgbm.so.1"] | walk($edges) | subset($g)) as $gbm |
  (["libpulse.so.0"] | walk($edges) | subset($g)) as $pulse |
  ([$codec[], $gbm[], $pulse[]] | unique) as $reached |
  ($g - $reached) as $not_reached |
  {
    schema_version:1,
    original_source:$d.source_commit,
    native_archive_sha256:$d.compiled_archive_sha256,
    observed_graphical_only_basename_count:($g|length),
    dynamic_load_seed_names:["libavcodec.so.60","libgbm.so.1","libpulse.so.0"],
    ffmpeg_seed_reached_names:$codec,
    ffmpeg_seed_reached_count:($codec|length),
    gbm_seed_reached_names:$gbm,
    gbm_seed_reached_count:($gbm|length),
    pulse_seed_reached_names:$pulse,
    pulse_seed_reached_count:($pulse|length),
    reached_by_at_least_one_seed_names:$reached,
    reached_by_at_least_one_seed_count:($reached|length),
    not_reached_by_the_three_seed_names:$not_reached,
    not_reached_by_the_three_seed_count:($not_reached|length),
    overlapped_names_not_exclusive_to_one_root:true,
    uses_only_original_compiled_browser_observed_glibc_requests:true,
    graph_path_proves_actual_application_call_stack:false,
    missing_edge_proves_unused_library:false,
    source_feature_exclusivity_proven:false,
    all_runtime_loaders_or_dlopen_paths_mapped:false,
    arch_hyprland_abi_proven:false,
    any_new_source_removal_authorized:false,
    new_package_savings_bytes:null,
    m3_sixth_gate_closed:false
  }
' "$input" >"$output"
jq -e '
  .observed_graphical_only_basename_count==58 and
  (.reached_by_at_least_one_seed_count +
   .not_reached_by_the_three_seed_count)==58 and
  .m3_sixth_gate_closed==false and
  .any_new_source_removal_authorized==false
' "$output" >/dev/null
jq -r '"PASS: observed graph reached \(.reached_by_at_least_one_seed_count)/58 graphical-only initialized names from 3 dynamic request targets; not reached=\(.not_reached_by_the_three_seed_count). No feature exclusivity or deletion license."' "$output"
