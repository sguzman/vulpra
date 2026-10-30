#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
jq -n '
  (["libavcodec.so.60","libgbm.so.1","libpulse.so.0"] +
   [range(0;55)|"libtest\(.)" + ".so"]) as $names |
  ([range(0;55) as $i |
    {requester_basename:(if $i<20 then "libavcodec.so.60"
                         elif $i<40 then "libgbm.so.1"
                         else "libpulse.so.0" end),
     requested_library_basename:("libtest\($i).so")}]
   +[range(0;12) as $i |
    {requester_basename:"libtest\($i).so",
     requested_library_basename:"libtest\($i+20).so"}]) as $edges |
  {
    schema_version:1,
    source_commit:"b1482404dfb8b01342990ee99ea3df0f9756b5f7",
    compiled_archive_sha256:"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a",
    graphical_needed_by_count:147,needed_by_both_count:80,
    needed_by_headless_only_count:0,needed_by_graphical_only_count:67,
    headless_dynamic_request_count:18,graphical_dynamic_request_count:21,
    dynamic_both_count:18,dynamic_headless_only_count:0,
    dynamic_graphical_only_count:3,
    request_target_had_glibc_init_event:true,
    file_paths_and_raw_pids_retained:false,
    full_source_feature_graph_proven:false,full_dlopen_graph_proven:false,
    dynamic_symbol_abi_closure_proven:false,m3_sixth_gate_closed:false,
    observed_unique_graphical_names:$names,
    needed_by_graphical_only_edges:$edges,
    dynamic_graphical_only_edges:[
      {requester_basename:"libnspr4.so",requested_library_basename:"libavcodec.so.60"},
      {requester_basename:"libxul.so",requested_library_basename:"libgbm.so.1"},
      {requester_basename:"libxul.so",requested_library_basename:"libpulse.so.0"}
    ]
  }
' >"$work/valid.json"
bash "$root/ci/m3-graphical-loader-reachability.sh" \
  "$work/valid.json" "$work/result.json"
jq -e '
  .reached_by_at_least_one_seed_count==58 and
  .not_reached_by_the_three_seed_count==0 and
  .ffmpeg_seed_reached_count==33 and
  .gbm_seed_reached_count==21 and
  .pulse_seed_reached_count==16 and
  .overlapped_names_not_exclusive_to_one_root==true
' "$work/result.json" >/dev/null
reject() {
  if bash "$root/ci/m3-graphical-loader-reachability.sh" \
    "$work/bad.json" "$work/wrong.json" >"$work/error.log" 2>&1; then
    echo 'FAIL: invalid reachability evidence was accepted' >&2
    exit 1
  fi
}
jq '.observed_unique_graphical_names+=["/secret/lib.so"]' "$work/valid.json" >"$work/bad.json"
reject
jq '.needed_by_graphical_only_edges[0].requester_basename="../unsafe"' \
  "$work/valid.json" >"$work/bad.json"
reject
jq '.needed_by_graphical_only_count=999' "$work/valid.json" >"$work/bad.json"
reject
jq '.m3_sixth_gate_closed=true' "$work/valid.json" >"$work/bad.json"
reject
jq '.source_commit="forged"' "$work/valid.json" >"$work/bad.json"
reject
jq '.dynamic_graphical_only_edges[1].requested_library_basename="not-observed.so"' \
  "$work/valid.json" >"$work/bad.json"
reject
echo 'PASS: bounded real-loader reachability fixtures, overlapping paths, provenance, graph mutation, privacy and gate safety'
