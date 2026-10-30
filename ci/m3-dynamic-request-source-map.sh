#!/usr/bin/env bash
# Independent source pin and observed glibc dynamic-request boundary contract.
# This is source-candidate matching, NOT stack-trace-level call attribution.
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo 'usage: m3-dynamic-request-source-map.sh edge-contrast.json pinned-source-root output.json' >&2
  exit 2
fi
report="$(realpath -e -- "$1")"
src="$(realpath -e -- "$2")"
out="$3"
source='b1482404dfb8b01342990ee99ea3df0f9756b5f7'
archive='7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a'
[[ "$(stat -c %s -- "$report")" -gt 0 && "$(stat -c %s -- "$report")" -le 131072 ]]
test -f "$src/widget/gtk/DMABufDevice.cpp"
test -f "$src/widget/gtk/moz.build"
test -f "$src/dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp"
test -f "$src/dom/media/platforms/ffmpeg/moz.build"
test -f "$src/media/libcubeb/src/moz.build"
test -f "$src/media/libcubeb/src/cubeb.c"
test -f "$src/toolkit/library/rust/shared/Cargo.toml"
test -f "$src/toolkit/library/rust/gkrust-features.mozbuild"
test "$(git -C "$src" rev-parse HEAD)" = "$source"
# EXACTLY three observed requests; never substitute source guesses for actual
# authenticated glibc reports or silently allow an absent/extra request.
jq -e --arg src "$source" --arg sha "$archive" '
  .schema_version==1 and .source_commit==$src and
  .compiled_archive_sha256==$sha and
  .headless_dynamic_request_count==18 and
  .graphical_dynamic_request_count==21 and
  .dynamic_both_count==18 and
  .dynamic_headless_only_count==0 and
  .dynamic_graphical_only_count==3 and
  .request_target_had_glibc_init_event==true and
  .file_paths_and_raw_pids_retained==false and
  .full_source_feature_graph_proven==false and
  .full_dlopen_graph_proven==false and
  .dynamic_symbol_abi_closure_proven==false and
  .further_source_removal_authorized==false and
  .m3_sixth_gate_closed==false and
  (
    (.dynamic_graphical_only_edges | sort_by(.requester_basename,.requested_library_basename)) ==
    [
      {requester_basename:"libnspr4.so",requested_library_basename:"libavcodec.so.60"},
      {requester_basename:"libxul.so",requested_library_basename:"libgbm.so.1"},
      {requester_basename:"libxul.so",requested_library_basename:"libpulse.so.0"}
    ]
  )
' "$report" >/dev/null
# Source citations are explicit and preserved from the authentic pinned
# browser SOURCE, not from the commit containing this test.
has() { grep -Fq -- "$2" "$src/$1"; }
has widget/gtk/DMABufDevice.cpp '#define GBMLIB_NAME "libgbm.so.1"'
has widget/gtk/DMABufDevice.cpp 'dlopen(GBMLIB_NAME, RTLD_LAZY | RTLD_LOCAL)'
has widget/gtk/moz.build '"DMABufDevice.cpp"'
has dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp '"libavcodec.so.60"'
has dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp 'PR_LoadLibraryWithFlags(lspec, PR_LD_NOW | PR_LD_LOCAL)'
has dom/media/platforms/ffmpeg/moz.build 'FFmpegRuntimeLinker.cpp'
has media/libcubeb/src/moz.build "if CONFIG['MOZ_PULSEAUDIO']:"
has media/libcubeb/src/moz.build "DEFINES['USE_PULSE_RUST'] = True"
has media/libcubeb/src/cubeb.c 'pulse_rust_init,'
has toolkit/library/rust/gkrust-features.mozbuild 'gkrust_features += ["cubeb_pulse_rust"]'
has toolkit/library/rust/shared/Cargo.toml 'cubeb-pulse = { git = "https://github.com/mozilla/cubeb-pulse-rs"'
has toolkit/library/rust/shared/Cargo.toml 'features=["pulse-dlopen"]'
has toolkit/library/rust/shared/Cargo.toml 'cubeb_pulse_rust = ["cubeb-sys", "cubeb-pulse"]'
jq -n --arg source "$source" --arg archive "$archive" '
  {
    schema_version:1,
    historical_compiled_source:$source,
    original_native_package_sha256:$archive,
    trace_run_ids:[41137841775,41137841911],
    observed_three_dynamic_library_requests:[
      {
        requester_basename:"libnspr4.so",
        requested_library_basename:"libavcodec.so.60",
        source_candidate:"dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp",
        source_build_manifest:"dom/media/platforms/ffmpeg/moz.build",
        mechanism:"NSPR PR_LoadLibraryWithFlags chooses runtime libavcodec candidate",
        linker_source_requester_matches_function_owner:false
      },
      {
        requester_basename:"libxul.so",
        requested_library_basename:"libgbm.so.1",
        source_candidate:"widget/gtk/DMABufDevice.cpp",
        source_build_manifest:"widget/gtk/moz.build",
        mechanism:"GbmLib::Load uses dlopen(GBMLIB_NAME) and runtime dlsym",
        linker_source_requester_matches_function_owner_not_proven:true
      },
      {
        requester_basename:"libxul.so",
        requested_library_basename:"libpulse.so.0",
        source_candidate:"media/libcubeb/src/cubeb.c",
        source_build_manifest:"toolkit/library/rust/shared/Cargo.toml",
        mechanism:"MOZ_PULSEAUDIO selects USE_PULSE_RUST / cubeb_pulse_rust with pulse-dlopen from pinned external Rust crate",
        linked_pinned_external_crate_bytes_audited:false
      }
    ],
    source_candidates_confirmed_with_exact_original_tree:true,
    actual_call_stacks_captured:false,
    runtime_source_caller_uniquely_attributed:false,
    pulse_external_crate_source_line_proven:false,
    actual_generated_build_feature_values_verified_by_this_subtask:false,
    full_dynamic_load_graph_covered:false,
    full_abi_symbol_resolution_verified:false,
    any_new_removal_authorized:false,
    new_compressed_byte_savings:null,
    m3_sixth_gate_closed:false
  }
' > "$out"
jq -e '.observed_three_dynamic_library_requests|length==3' "$out" >/dev/null
echo 'PASS: three actual loader-observed dynamic requests are backed by pinned build/source candidate paths; no causal call-stack, ABI or deletion credit'
