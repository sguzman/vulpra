#!/usr/bin/env bash
# Source-pinned, offline Cargo feature-resolution evidence for the actual
# Mozilla-emitted gkrust root. Never compiles Rust or modifies user profiles.
set -euo pipefail
export LC_ALL=C
if [ "$#" -ne 3 ]; then
  echo "usage: m3-compare-gkrust-resolve.sh FULL_EVALUATED_JSON LEAN_EVALUATED_JSON OUTPUT_JSON" >&2
  exit 2
fi
full_json=$1
lean_json=$2
out=$3
[ "$SOURCE_SHA" = "b1482404dfb8b01342990ee99ea3df0f9756b5f7" ]
test "$(git rev-parse HEAD)" = "$SOURCE_SHA"
test -f toolkit/library/rust/Cargo.toml
test -f Cargo.lock
test -f .cargo/config.toml.in
# Only in the ephemeral pinned-source CI checkout. Never overwrite an existing
# config; Mozilla's unexpanded vendor config is deliberately valid Cargo TOML.
test ! -e .cargo/config.toml
cp .cargo/config.toml.in .cargo/config.toml
trap 'rm -f .cargo/config.toml; rm -rf "$tmp"' EXIT
tmp=$(mktemp -d)
export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null

for side in full lean; do
  if [ "$side" = full ]; then json=$full_json; else json=$lean_json; fi
  jq -e --arg sha "$SOURCE_SHA" \
    '.original_source_commit == $sha and
     .status == "original_configure_evaluated_mozbuild_frontend" and
     .actual_evaluated_rust_library_target_count >= 4 and
     .cargo_resolved_dependency_graph_proven == false' "$json" >/dev/null
  jq -re '.actual_evaluated_rust_library_targets[] |
    select(.[0] == "toolkit/library/rust" and .[1] == "RustLibrary") |
    select(.[5] == "toolkit/library/rust/Cargo.toml") |
    .[3]' "$json" > "$tmp/$side-root-name"
  [ "$(wc -l < "$tmp/$side-root-name")" = 1 ]
  jq -r '.actual_evaluated_rust_library_features[] |
    select(.[0] == "toolkit/library/rust" and .[1] == "RustLibrary") |
    .[-1]' "$json" | sort -u > "$tmp/$side-features"
  [ "$(wc -l < "$tmp/$side-features")" -ge 10 ]
  [ "$(wc -l < "$tmp/$side-features")" -le 100 ]
  features=$(paste -sd, "$tmp/$side-features")
  # Resolve the actual staticlib root, not unrelated workspace default feature
  # activations. Fully offline and locked against the immutable Cargo.lock.
  cargo metadata --offline --locked --format-version 1 \
    --manifest-path toolkit/library/rust/Cargo.toml \
    --features "$features" > "$tmp/$side-metadata.json"
  jq -e '(.resolve.nodes | type) == "array" and
    (.resolve.nodes | length) > 100 and
    ([.packages[] | select(.name == "gkrust")] | length) == 1' \
    "$tmp/$side-metadata.json" >/dev/null
  jq -r '.packages[] | select(.name == "gkrust") | .id' "$tmp/$side-metadata.json" \
    > "$tmp/$side-gkrust-id"
  jq -c '.resolve.nodes[] |
    [.id, (.features|sort), ([.deps[] |
      [.pkg, ([.dep_kinds[]? | [.kind, (.target//"")] | @json] | sort)]
      | @json] | sort)] | @json' \
    "$tmp/$side-metadata.json" | sort -u > "$tmp/$side-resolved"
  jq -c '.packages[] | [.id,.name,.version,(.source//"")] | @json' \
    "$tmp/$side-metadata.json" | sort -u > "$tmp/$side-packages"
done
comm -12 "$tmp/full-resolved" "$tmp/lean-resolved" > "$tmp/shared-resolved"
comm -23 "$tmp/full-resolved" "$tmp/lean-resolved" > "$tmp/full-only-resolved"
comm -13 "$tmp/full-resolved" "$tmp/lean-resolved" > "$tmp/lean-only-resolved"
comm -23 "$tmp/full-packages" "$tmp/lean-packages" > "$tmp/full-only-packages"
comm -13 "$tmp/full-packages" "$tmp/lean-packages" > "$tmp/lean-only-packages"
comm -23 "$tmp/full-features" "$tmp/lean-features" > "$tmp/full-only-features"
comm -13 "$tmp/full-features" "$tmp/lean-features" > "$tmp/lean-only-features"

full_resolved=$(wc -l < "$tmp/full-resolved")
lean_resolved=$(wc -l < "$tmp/lean-resolved")
shared=$(wc -l < "$tmp/shared-resolved")
full_only=$(wc -l < "$tmp/full-only-resolved")
lean_only=$(wc -l < "$tmp/lean-only-resolved")
[ "$full_resolved" -eq "$((shared+full_only))" ]
[ "$lean_resolved" -eq "$((shared+lean_only))" ]
full_packages=$(wc -l < "$tmp/full-packages")
lean_packages=$(wc -l < "$tmp/lean-packages")

# Do not archive the full Cargo metadata or raw host filesystem paths.
jq -n --arg sha "$SOURCE_SHA" \
  --argjson full_nodes "$full_resolved" --argjson lean_nodes "$lean_resolved" \
  --argjson shared "$shared" --argjson full_only "$full_only" \
  --argjson lean_only "$lean_only" --argjson full_packages "$full_packages" \
  --argjson lean_packages "$lean_packages" \
  --argjson full_features "$(wc -l < "$tmp/full-features")" \
  --argjson lean_features "$(wc -l < "$tmp/lean-features")" \
  --argjson full_only_features "$(wc -l < "$tmp/full-only-features")" \
  --argjson lean_only_features "$(wc -l < "$tmp/lean-only-features")" \
  --argjson full_only_packages "$(wc -l < "$tmp/full-only-packages")" \
  --argjson lean_only_packages "$(wc -l < "$tmp/lean-only-packages")" '
  {
    schema_version:1,
    status:"pinned_offline_gkrust_cargo_metadata_resolved",
    original_source_commit:$sha,
    cargo_invocation_locked:true,
    cargo_invocation_offline:true,
    source_root:"toolkit/library/rust/Cargo.toml",
    normal_requested_gkrust_features:$full_features,
    lean_requested_gkrust_features:$lean_features,
    normal_only_requested_feature_count:$full_only_features,
    lean_only_requested_feature_count:$lean_only_features,
    normal_metadata_package_records:$full_packages,
    lean_metadata_package_records:$lean_packages,
    normal_only_metadata_package_records:$full_only_packages,
    lean_only_metadata_package_records:$lean_only_packages,
    normal_resolve_node_records:$full_nodes,
    lean_resolve_node_records:$lean_nodes,
    identical_resolve_nodes_features_and_dependency_edges:$shared,
    normal_only_resolve_node_feature_edge_records:$full_only,
    lean_only_resolve_node_feature_edge_records:$lean_only,
    metadata_includes_workspace_not_just_gkrust_closure:true,
    commands_resolved_not_executed:true,
    rustc_invoked:false,
    native_linker_invoked:false,
    resolved_other_rust_roots_with_specific_features:false,
    ffi_or_runtime_dlopen_closure_proven:false,
    source_pruning_authorized:false,
    m3_sixth_gate_closed:false
  }' > "$out"
jq -e '
  .normal_requested_gkrust_features > 10 and
  .lean_requested_gkrust_features > 10 and
  .normal_resolve_node_records > 100 and
  .lean_resolve_node_records > 100 and
  (.identical_resolve_nodes_features_and_dependency_edges+
   .normal_only_resolve_node_feature_edge_records)==.normal_resolve_node_records and
  (.identical_resolve_nodes_features_and_dependency_edges+
   .lean_only_resolve_node_feature_edge_records)==.lean_resolve_node_records and
  .cargo_invocation_locked == true and
  .cargo_invocation_offline == true and
  .rustc_invoked == false and
  .m3_sixth_gate_closed == false' "$out" >/dev/null
jq -c '{
  gkrust_features:[.normal_requested_gkrust_features,.lean_requested_gkrust_features],
  resolved_packages:[.normal_metadata_package_records,.lean_metadata_package_records],
  resolved_node_records:[.normal_resolve_node_records,.lean_resolve_node_records],
  identical_nodes:.identical_resolve_nodes_features_and_dependency_edges,
  one_sided_nodes:[.normal_only_resolve_node_feature_edge_records,.lean_only_resolve_node_feature_edge_records],
  one_sided_package_records:[.normal_only_metadata_package_records,.lean_only_metadata_package_records]
}' "$out"
