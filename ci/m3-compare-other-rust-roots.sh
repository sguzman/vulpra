#!/usr/bin/env bash
# Compare Cargo-resolved dependency and feature graph for five non-gkrust
# Mozilla-emitted Rust library/program roots. Offline, locked, no compilation.
set -euo pipefail
export LC_ALL=C
if [ "$#" -ne 3 ]; then
  echo 'usage: m3-compare-other-rust-roots.sh FULL_FRONTEND LEAN_FRONTEND OUTPUT_JSON' >&2
  exit 2
fi
full=$1
lean=$2
output=$3
[ "$SOURCE_SHA" = "b1482404dfb8b01342990ee99ea3df0f9756b5f7" ]
[ "$(git rev-parse HEAD)" = "$SOURCE_SHA" ]
[ -s .cargo/config.toml.in ] && [ ! -e .cargo/config.toml ]
tmp=$(mktemp -d)
trap 'rm -f .cargo/config.toml; rm -rf "$tmp"' EXIT
cp .cargo/config.toml.in .cargo/config.toml
export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null

for side in full lean; do
  if [ "$side" = full ]; then file=$full; else file=$lean; fi
  jq -e --arg sha "$SOURCE_SHA" '
    .original_source_commit==$sha and
    .status=="original_configure_evaluated_mozbuild_frontend" and
    .actual_evaluated_rust_library_target_count==4 and
    .actual_evaluated_rust_program_target_count==2' "$file" >/dev/null
  jq -r '
    ([.actual_evaluated_rust_library_targets[] |
        select(.[0]!="toolkit/library/rust") |
        [.[0],"library",.[4],.[5]]] +
     [.actual_evaluated_rust_program_targets[] |
        [.[0],"program",.[4],.[5]]]) |
    sort | .[] | @tsv' "$file" > "$tmp/$side-roots"
  [ "$(wc -l < "$tmp/$side-roots")" -eq 5 ]
done
cmp -s "$tmp/full-roots" "$tmp/lean-roots"
: > "$tmp/results.jsonl"

while IFS=$'\t' read -r owner kind origin manifest; do
  [ "$origin" = src ] && [ -f "$manifest" ]
  [[ "$manifest" =~ ^[a-z0-9_./+-]+/Cargo\.toml$ ]]
  [[ "$manifest" != *../* ]]
  [ "$kind" = library ] || [ "$kind" = program ]
  for side in full lean; do
    if [ "$side" = full ]; then file=$full; else file=$lean; fi
    if [ "$kind" = library ]; then key=actual_evaluated_rust_library_features
    else key=actual_evaluated_rust_program_features; fi
    jq -r --arg key "$key" --arg owner "$owner" \
      '.[$key][] | select(.[0]==$owner) | .[-1]' "$file" |
      sort -u > "$tmp/$side-features"
    features=$(paste -sd, "$tmp/$side-features")
    if [ -n "$features" ]; then
      cargo metadata --offline --locked --format-version 1 \
        --manifest-path "$manifest" --features "$features" \
        > "$tmp/$side-metadata.json"
    else
      cargo metadata --offline --locked --format-version 1 \
        --manifest-path "$manifest" > "$tmp/$side-metadata.json"
    fi
    jq -e '(.resolve.nodes|length)>100' "$tmp/$side-metadata.json" >/dev/null
    jq -r --arg manifest "$PWD/$manifest" \
      '.packages[]|select(.manifest_path==$manifest)|.id' \
      "$tmp/$side-metadata.json" > "$tmp/$side-root-id"
    [ "$(wc -l < "$tmp/$side-root-id")" -eq 1 ]
    jq -rc --arg root "$(cat "$tmp/$side-root-id")" '
      def closure($adj; $r):
        {todo:[$r],visited:{}} |
        until((.todo|length)==0;
          .todo[0] as $next |
          .todo |= .[1:] |
          if .visited[$next] then .
          else .visited[$next]=true | .todo += ($adj[$next]//[])
          end) | .visited | keys;
      (.resolve.nodes|map({key:.id,value:[.deps[].pkg]})|from_entries) as $adj |
      (closure($adj;$root)|reduce .[] as $key ({}; .[$key]=true)) as $reachable |
      .resolve.nodes[] | select($reachable[.id]) |
      [.id, (.features|sort),
       ([.deps[]|[.pkg,([.dep_kinds[]?|[.kind,(.target//"")]|@json]|sort)]|@json]|sort)] |
      @json
    ' "$tmp/$side-metadata.json" | sort -u > "$tmp/$side-reachable"
    [ "$(wc -l < "$tmp/$side-reachable")" -gt 0 ]
  done
  comm -12 "$tmp/full-reachable" "$tmp/lean-reachable" > "$tmp/shared"
  comm -23 "$tmp/full-reachable" "$tmp/lean-reachable" > "$tmp/full-only"
  comm -13 "$tmp/full-reachable" "$tmp/lean-reachable" > "$tmp/lean-only"
  full_count=$(wc -l < "$tmp/full-reachable")
  lean_count=$(wc -l < "$tmp/lean-reachable")
  shared=$(wc -l < "$tmp/shared")
  full_only=$(wc -l < "$tmp/full-only")
  lean_only=$(wc -l < "$tmp/lean-only")
  [ "$full_count" -eq "$((shared+full_only))" ]
  [ "$lean_count" -eq "$((shared+lean_only))" ]
  jq -nc --arg owner "$owner" --arg kind "$kind" --arg manifest "$manifest" \
    --argjson normal_features "$(wc -l < "$tmp/full-features")" \
    --argjson lean_features "$(wc -l < "$tmp/lean-features")" \
    --argjson normal "$full_count" --argjson lean "$lean_count" \
    --argjson shared "$shared" --argjson normal_only "$full_only" \
    --argjson lean_only "$lean_only" '
    {
      source_owner:$owner,root_kind:$kind,cargo_manifest:$manifest,
      normal_requested_features:$normal_features,
      lean_requested_features:$lean_features,
      normal_reachable_resolved_nodes:$normal,
      lean_reachable_resolved_nodes:$lean,
      identical_reachable_node_feature_edge_records:$shared,
      normal_only_node_feature_edge_records:$normal_only,
      lean_only_node_feature_edge_records:$lean_only
    }' >> "$tmp/results.jsonl"
done < "$tmp/full-roots"

jq -s --arg sha "$SOURCE_SHA" '
  {
    schema_version:1,
    status:"pinned_offline_other_five_rust_roots_resolved",
    original_source_commit:$sha,
    distinct_emitted_other_rust_root_count:length,
    root_results:.,
    offline_locked_cargo_metadata:true,
    root_reachability_and_enabled_feature_edges_compared:true,
    metadata_uses_whole_workspace_activation_context:true,
    raw_cargo_metadata_archived:false,
    crates_compiled:false,
    linker_executed:false,
    feature_unification_of_actual_native_build_proven:false,
    ffi_and_runtime_dlopen_graph_proven:false,
    source_pruning_authorized:false,
    m3_sixth_gate_closed:false
  }' "$tmp/results.jsonl" > "$output"
jq -e '
  .status=="pinned_offline_other_five_rust_roots_resolved" and
  .distinct_emitted_other_rust_root_count==5 and
  (.root_results|all(.[]; .normal_reachable_resolved_nodes>0 and
    .lean_reachable_resolved_nodes>0 and
    .normal_reachable_resolved_nodes ==
      .identical_reachable_node_feature_edge_records + .normal_only_node_feature_edge_records and
    .lean_reachable_resolved_nodes ==
      .identical_reachable_node_feature_edge_records + .lean_only_node_feature_edge_records)) and
  .raw_cargo_metadata_archived==false and
  .crates_compiled==false and
  .m3_sixth_gate_closed==false' "$output" >/dev/null
jq -c '{roots:[.root_results[] |
  {manifest:.cargo_manifest,
   features:[.normal_requested_features,.lean_requested_features],
   reachable:[.normal_reachable_resolved_nodes,.lean_reachable_resolved_nodes],
   differences:[.normal_only_node_feature_edge_records,.lean_only_node_feature_edge_records]}]}' "$output"
