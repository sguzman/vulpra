#!/usr/bin/env bash
# Execute the actual source-owned FFmpegRuntimeLinker::Init + Linux sLibs
# array with controlled NSPR/FFmpeg mock providers. Source Git blob is pinned
# to an independently successful normal native browser run. No new build.
set -euo pipefail
root="${GITHUB_WORKSPACE:?}"
test "$(git -C "$root" rev-parse HEAD)" = "${GITHUB_SHA:?}"
test -d "${RUNNER_TEMP:?}"
src="$root/dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp"
test -s "$src" && test ! -L "$src"
blob="c854f34aa71f6fd4146e04ab332d3e0f8a60fb11"
native_sha="d7bf1cb73b384df047871d6b8c608312eb6cb5b4"
test "$(git -C "$root" rev-parse HEAD:dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp)" = "$blob"
test "$(git -C "$root" hash-object -- dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp)" = "$blob"
gh api "repos/$GITHUB_REPOSITORY/actions/runs/42546880350" > "$RUNNER_TEMP/native-ffmpeg-source-run.json"
jq -e --arg sha "$native_sha" '
 .head_sha==$sha and .status=="completed" and .conclusion=="success" and
 .name=="M3 Source Matched Native Link Inputs and Runtime" and
 .event=="push" and .run_attempt==1
' "$RUNNER_TEMP/native-ffmpeg-source-run.json" >/dev/null
gh api "repos/$GITHUB_REPOSITORY/contents/dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp?ref=$native_sha" \
  > "$RUNNER_TEMP/native-ffmpeg-source-object.json"
jq -e --arg expected "$blob" '.type=="file" and .sha==$expected' \
  "$RUNNER_TEMP/native-ffmpeg-source-object.json" >/dev/null
work="$(mktemp -d "$RUNNER_TEMP/vulpra-ffmpeg-init.XXXXXXXX")"
trap 'rm -rf -- "$work"' EXIT
sed -n '/^static const char\* sLibs\[\] = {/,/^};/p' "$src" > "$work/real-ffmpeg-loader-candidates.inc"
sed -n '/^bool FFmpegRuntimeLinker::Init() {/,/^}/p' "$src" > "$work/real-ffmpeg-runtime-init.inc"
test "$(grep -Fc 'static const char* sLibs[] = {' "$work/real-ffmpeg-loader-candidates.inc")" -eq 1
test "$(grep -Fc 'bool FFmpegRuntimeLinker::Init() {' "$work/real-ffmpeg-runtime-init.inc")" -eq 1
test "$(tail -1 "$work/real-ffmpeg-loader-candidates.inc")" = '};'
test "$(tail -1 "$work/real-ffmpeg-runtime-init.inc")" = '}'
test "$(wc -l < "$work/real-ffmpeg-loader-candidates.inc")" -gt 30
test "$(wc -l < "$work/real-ffmpeg-runtime-init.inc")" -gt 100
test "$(wc -l < "$work/real-ffmpeg-runtime-init.inc")" -lt 200
c++ -std=c++17 -O0 -g0 -Wall -Wextra -Werror \
 -I "$work" "$root/ci/tests/m3-real-ffmpeg-linker-candidates-fixture.cpp" \
 -o "$work/original-ffmpeg-init"
: > "$work/results.jsonl"
for case in missing-all first-success last-success bad-then-success invalid-priority; do
 "$work/original-ffmpeg-init" "$case" >> "$work/results.jsonl"
done
if "$work/original-ffmpeg-init" invalid-mode > /dev/null 2>&1; then
 echo "FAIL: accepted forged source method scenario" >&2;exit 1
fi
out="$RUNNER_TEMP/m3-original-ffmpeg-runtime-linker-mocks.json"
test ! -e "$out"
jq -s --arg sha "$native_sha" --arg blob "$blob" '
 if (
  length==5 and
  ([.[].scenario]|sort)==["bad-then-success","first-success","invalid-priority","last-success","missing-all"] and
  all(.[]; .exact_original_FFmpeg_Init_executed==true and
   .provider_loader_and_link_ABIs_mocked==true and
   .original_linux_candidate_count==14 and
   .cached_second_Init_avoided_loads==true and
   .decoded_actual_video_frames==false and
   .real_FFmpeg_shared_library_loaded==false and
   .normal_packaged_browser_executed==false and
   .software_video_fallback_proven==false) and
  any(.[]; .scenario=="missing-all" and .observed_ns_failed_or_loaded_attempts==14 and .observed_success==false) and
  any(.[]; .scenario=="first-success" and .observed_ns_failed_or_loaded_attempts==1 and .observed_success==true) and
  any(.[]; .scenario=="last-success" and .observed_ns_failed_or_loaded_attempts==14 and .observed_success==true) and
  any(.[]; .scenario=="bad-then-success" and .observed_ns_failed_or_loaded_attempts==2 and .observed_success==true) and
  any(.[]; .scenario=="invalid-priority" and .observed_ns_failed_or_loaded_attempts==14 and .observed_success==false)
 ) then {
  schema_version:1,
  status:"real_source_FFmpeg_Init_and_linux_candidates_executed_with_mocked_loaders",
  authenticated_successful_normal_native_source_commit:$sha,
  exact_source_git_blob:$blob,
  original_source_candidate_array_extracted_verbatim:true,
  original_source_cpp_Init_method_extracted_verbatim:true,
  actual_original_source_cpp_method_compiled_and_executed:true,
  original_linux_candidate_count:14,
  simulated_provider_scenarios:5,
  original_failed_candidates_exhausted:true,
  original_first_and_last_usable_candidate_traversal_tested:true,
  original_candidate_priority_and_memoization_tested:true,
  actual_packaged_browser_h264_playback_tested:false,
  actual_system_FFmpeg_ABI_loaded:false,
  real_video_decode_or_software_fallback_proven:false,
  complete_indirect_dynamic_dependency_closure_proven:false,
  m3_sixth_gate_closed:false,source_pruning_authorized:false,release_ready:false,
  scenarios:.
 } else error("Exact-source FFmpeg Init/NSPR mock candidate mismatch") end
' "$work/results.jsonl" > "$out"
echo "PASS: five original FFmpeg linker C++ source Init candidate/error/cache modes with real source and fake ABI providers"
echo "LIMIT: no actual libavcodec ABI, packaged H264 playback, codec fallback or full dependency closure"
