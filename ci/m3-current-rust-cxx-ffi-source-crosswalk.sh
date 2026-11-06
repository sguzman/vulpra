#!/usr/bin/env bash
# Verify pinned original/current Rust-C++ FFI source ownership.
# Not a proof of compiled archive members, indirect FFI, or release readiness.
set -euo pipefail
repo=sguzman/vulpra
manifest=docs/vulpra/M3-CURRENT-RUST-CXX-FFI-SOURCE-ANCHORS-20261106.json
original=b1482404dfb8b01342990ee99ea3df0f9756b5f7
compiled=96454f7a1fbe6b505af440c6c2c5fc91e798756d
native_run=41762298450
expected_rows() {
  cat <<'ROWS'
xpcom/build/XPCOMInit.cpp 8d89afd0239b9a47da1dcb86e001aff137355f7d
toolkit/library/rust/shared/lib.rs 078e80a439de35757cf648a52062ff3d3122f8ce
toolkit/library/rust/lib.rs 815413a5da15df4f0031572734bc406c2628585f
toolkit/library/rust/Cargo.toml d110b667b08b60af7b539103d5ce3d8cbd71ee5e
toolkit/library/rust/moz.build b0c5c51031ce1cc916f9d6668c99c7a677883a83
toolkit/library/build/moz.build 72b02071e56d1c93b6bd8a58b6b0ece29837026b
toolkit/crashreporter/crash_helper/crashhelper.cpp e391fe314bbdfc81aebb894d7d5c5c5de8cceaa8
toolkit/crashreporter/crash_helper_server/src/lib.rs 6dc2c97db7e69986e66a43ad1fa4cdb8a617c5f1
toolkit/crashreporter/crash_helper_server/Cargo.toml b7455f095fd3cec6ca6c5b03135ee8570981f51e
toolkit/crashreporter/crash_helper_server/moz.build 266a7207e7f18128c2c3085e3ef0d1779691d597
toolkit/crashreporter/crash_helper/moz.build 78307c3d5f55f5802a75ca18976643195a6c1c95
ROWS
}
verify_manifest() {
  local source="$1" path sha count=0
  jq -e --arg original "$original" --arg compiled "$compiled" --argjson run "$native_run" '
    .schema_version == 1 and
    .kind == "m3_original_current_compiled_rust_cpp_ffi_source_anchor_parity" and
    .original_source_commit == $original and
    .current_compiled_source_commit == $compiled and
    .current_native_workflow_run_id == $run and
    .verified_date_utc == "2026-11-06" and
    .recorded_source_paths == 11 and
    (.source_file_blobs | type == "array" and length == 11) and
    ([.source_file_blobs[].path] | unique | length) == 11 and
    ([.observed_ffi_links[].source_export] | sort) ==
      ["GkRust_Init","GkRust_Shutdown","crash_generator_logic_desktop"] and
    ( [.observed_ffi_links[] |
       select(.source_export == "GkRust_Init" or .source_export == "GkRust_Shutdown")] |
       all(.rust_staticlib == "libgkrust.a" and .cpp_consumer == "libxul.so" and
           .cpp_source == "xpcom/build/XPCOMInit.cpp")) and
    ( [.observed_ffi_links[] |
       select(.source_export == "crash_generator_logic_desktop")] |
       all(.rust_staticlib == "libcrash_helper_server.a" and
           .cpp_consumer == "crashhelper" and
           .cpp_source == "toolkit/crashreporter/crash_helper/crashhelper.cpp")) and
    .all_original_and_compiled_current_source_blobs_identical == true and
    .all_current_main_source_blobs_identical_at_audit == true and
    .current_normal_native_success_source_authenticated_from_workflow == true and
    .current_compiled_ffi_archive_members_verified == false and
    .current_final_elf_ffi_machine_branches_verified == false and
    .all_rust_cpp_ffi_edges_identified == false and
    .conditional_dlopen_ffi_closure_proven == false and
    .all_protected_feature_fallbacks_proven == false and
    .real_target_endeavouros_hyprland_tested == false and
    .additional_source_pruning_authorized == false and
    .m3_sixth_gate_closed == false and
    (.note | type == "string" and length > 100)
  ' "$source" >/dev/null
  while read -r path sha; do
    jq -e --arg path "$path" --arg sha "$sha" '
      [.source_file_blobs[] | select(.path == $path)] as $match |
      ($match | length) == 1 and
      $match[0].original_git_blob_sha == $sha and
      $match[0].compiled_current_git_blob_sha == $sha and
      $match[0].main_git_blob_sha_at_audit == $sha
    ' "$source" >/dev/null
    count=$((count + 1))
  done < <(expected_rows)
  test "$count" -eq 11
}
verify_run_json() {
  jq -e --arg repo "$repo" --arg sha "$compiled" --argjson run "$native_run" '
    .id == $run and .head_sha == $sha and
    .head_branch == "main" and .head_repository.full_name == $repo and
    .name == "M3 Source Matched Native Link Inputs and Runtime" and
    .path == ".github/workflows/m3-source-matched-native-link.yml" and
    .event == "push" and .run_attempt == 1 and
    .status == "completed" and .conclusion == "success"
  ' "$1" >/dev/null
}
self_test() {
  verify_manifest "$manifest"
  local tmp mutation failures=0
  tmp="$(mktemp -d)"
  trap "rm -rf -- '$tmp'" EXIT
  while IFS= read -r mutation; do
    jq "$mutation" "$manifest" > "$tmp/forged.json"
    if verify_manifest "$tmp/forged.json" >/dev/null 2>&1; then
      echo "FAIL: forged source evidence accepted: $mutation" >&2; return 1
    fi
    failures=$((failures + 1))
  done <<'MUTATIONS'
.source_file_blobs[0].original_git_blob_sha = ("0" * 40)
.source_file_blobs[0].compiled_current_git_blob_sha = ("0" * 40)
.source_file_blobs[0].main_git_blob_sha_at_audit = ("0" * 40)
.source_file_blobs[1].path = .source_file_blobs[0].path
.source_file_blobs |= .[:-1]
.current_compiled_source_commit = ("0" * 40)
.original_source_commit = ("0" * 40)
.current_native_workflow_run_id = 1
.current_compiled_ffi_archive_members_verified = true
.current_final_elf_ffi_machine_branches_verified = true
.all_rust_cpp_ffi_edges_identified = true
.conditional_dlopen_ffi_closure_proven = true
.real_target_endeavouros_hyprland_tested = true
.m3_sixth_gate_closed = true
.observed_ffi_links[0].cpp_consumer = "not-libxul.so"
MUTATIONS
  test "$failures" -eq 15
  echo "PASS: 15/15 forged source, identity, FFI and M3 acceptance claims rejected"
}
check_live() {
  verify_manifest "$manifest"
  command -v jq >/dev/null
  command -v git >/dev/null
  command -v gh >/dev/null
  test -n "${GH_TOKEN:-}"
  test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?Exact checked source SHA required}"
  local tmp path sha ref inspected=0
  tmp="$(mktemp -d)"
  trap "rm -rf -- '$tmp'" EXIT
  gh api "repos/$repo/actions/runs/$native_run" > "$tmp/run.json"
  verify_run_json "$tmp/run.json"
  while read -r path sha; do
    test "$(git rev-parse --verify "HEAD:$path")" = "$sha"
    for ref in "$original" "$compiled"; do
      gh api "repos/$repo/contents/$path?ref=$ref" > "$tmp/blob.json"
      jq -e --arg sha "$sha" --arg path "$path" '
        .type == "file" and .path == $path and .sha == $sha
      ' "$tmp/blob.json" >/dev/null
      inspected=$((inspected + 1))
    done
  done < <(expected_rows)
  test "$inspected" -eq 22
  echo "PASS: 11/11 HEAD source Git objects and 22/22 exact original/current GitHub source refs"
  echo "PASS: source-matched current native workflow identity and outcome authenticated"
  echo "LIMIT: source anchors only, not current ELF Rust archive-member or complete indirect FFI closure"
}
case "${1:-}" in
  --self-test) self_test ;;
  --check-live) check_live ;;
  *) echo "Usage: $0 --self-test | --check-live" >&2; exit 2 ;;
esac
