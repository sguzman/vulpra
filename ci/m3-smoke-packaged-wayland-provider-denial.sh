#!/usr/bin/env bash
# Future source-pinned native CI test. Uses the *actual packaged* Vulpra
# graphical browser on private Weston with an opt-in optional-provider
# denial interposer; never changes host system libraries or user profiles.
# Not integrated into the already-running full native job.
set -euo pipefail
if test "$#" -ne 3; then
  echo "usage: $0 REPO INTERPOSER_SO OUTPUT_JSON" >&2
  exit 2
fi
repo="$1"; shim="$2"; output="$3"
test "$repo" = "$GITHUB_WORKSPACE"
test "$(git -C "$repo" rev-parse HEAD)" = "$GITHUB_SHA"
# A source-pinned already-compiled package may be replayed with a newer
# verification harness. Preserve the original ELF source identity separately.
compiled_source="${VULPRA_M3_COMPILED_SOURCE_SHA:-$GITHUB_SHA}"
[[ "$compiled_source" =~ ^[0-9a-f]{40}$ ]]
test -s "$shim" && test ! -L "$shim"
test "$output" = "$RUNNER_TEMP/m3-packaged-wayland-provider-denial-runtime.json"
test ! -e "$output"
pkg="$repo/.git/vulpra-native-build/packages/vulpra-local-m3-native-link-ci.tar.xz"
test -s "$pkg" && test ! -L "$pkg"
test -s "$pkg.sha256" && test ! -L "$pkg.sha256"
(cd "$(dirname "$pkg")" && sha256sum -c "$(basename "$pkg").sha256") >/dev/null
archive="$(sha256sum "$pkg" | cut -d' ' -f1)"
work="$(mktemp -d "$RUNNER_TEMP/vulpra-real-wayland-denial.XXXXXXXX")"
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/app"
tar -xf "$pkg" -C "$work/app"
mapfile -t inis < <(find "$work/app" -mindepth 1 -maxdepth 5 -type f -name application.ini -print)
test "${#inis[@]}" -eq 1
grep -Fxq 'Name=Vulpra' "${inis[0]}"
appdir="$(dirname "${inis[0]}")"
if test -x "$appdir/vulpra-launch"; then
  test -s "$appdir/vulpra"
elif test -x "$appdir/vulpra"; then
  test -x "$appdir/firefox"
else
  echo "FAIL: packaged Vulpra private launcher absent" >&2
  exit 1
fi
rows="$work/modes.jsonl"
: > "$rows"
for group in gbm vaapi ffmpeg; do
  log="$work/$group-loader.log"
  : > "$log"
  chmod 0600 "$log"
  passed=false
  # test-wayland.sh starts private Weston headless-backend/pixman; it launches
  # a NON-MOZ_HEADLESS GTK Wayland browser with a disposable HOME, then proves
  # attach+commit of a nonnull wl_buffer on one surface.
  # LD_PRELOAD may enter Weston too but the shim only denies in /proc/self/exe
  # matching the actual browser executable.
  if env -u VULPRA_M3_DENY_FIXTURE_EXE \
    LD_PRELOAD="$shim" \
    VULPRA_M3_DENY_GROUP="$group" \
    VULPRA_M3_DENY_LOG="$log" \
    VULPRA_WAYLAND_TEST_OFFLINE=1 \
    MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
    VULPRA_WAYLAND_TEST_SECONDS=10 \
    bash "$repo/packaging/test-wayland.sh" "$appdir" \
    > "$work/$group-wayland.log" 2>&1; then
    if grep -Fq 'PASS: private Weston compositor, Wayland surface buffer attachment and commit' \
      "$work/$group-wayland.log"; then
      passed=true
    fi
  fi
  test "$(stat -c '%s' "$log")" -lt 16777216
  attached="$(grep -c '^ATTACHED browser-process ' "$log" || true)"
  denied="$(grep -Ec '^DENIED (dlopen|dlmopen) ' "$log" || true)"
  jq -nc --arg group "$group" --argjson attached "$attached" \
    --argjson denied "$denied" --argjson frame "$passed" '{
      provider_group:$group,
      browser_process_instrumentation_attached:($attached>0),
      browser_attachment_records:$attached,
      targeted_optional_library_denial_events:$denied,
      targeted_missing_provider_path_actually_seen:($denied>0),
      actual_graphical_Wayland_frame_committed:$frame,
      frame_after_observed_targeted_denial:($frame and $denied>0),
      actual_GPU_acceleration_or_DMABuf_fallback_verified:false,
      media_decoding_fallback_verified:false,
      complete_native_dynamic_dependency_graph:false
    }' >> "$rows"
  echo "AUDIT: graphical Vulpra group=$group attached=$attached denied=$denied real_Wayland_frame=$passed"
  if test "$passed" != true || test "$attached" -eq 0; then break; fi
done
jq -s --arg source "$compiled_source" --arg harness "$GITHUB_SHA" --arg archive "$archive" '{
  schema_version:1,
  status:"actual_packaged_graphical_Weston_Wayland_optional_provider_denial_probe",
  native_source_commit:$source,
  test_harness_commit:$harness,
  verified_normal_packaged_archive_sha256:$archive,
  actual_graphical_packaged_Vulpra_executed:true,
  private_Weston_pixman_renderer_used:true,
  non_MOZ_HEADLESS_Wayland_browser_verified:true,
  scenarios:., 
  targeted_provider_calls_intercepted:(map(.targeted_optional_library_denial_events)|add),
  any_targeted_optional_provider_load_seen:any(.[]; .targeted_missing_provider_path_actually_seen),
  three_graphical_frames_and_attach_witnesses_passed:(
    length==3 and all(.[]; .browser_process_instrumentation_attached and .actual_graphical_Wayland_frame_committed)),
  GPU_DMABuf_or_software_video_fallback_complete:false,
  all_direct_indirect_dynamic_loader_routes_covered:false,
  user_endeavouros_hyprland_qa_done:false,
  host_system_libraries_modified:false,
  user_normal_profile_or_credentials_used:false,
  source_pruning_authorized:false,
  m3_sixth_gate_closed:false,
  release_ready:false
}' "$rows" > "$output"
jq -e '
  .schema_version == 1 and
  .three_graphical_frames_and_attach_witnesses_passed == true and
  .GPU_DMABuf_or_software_video_fallback_complete == false and
  .source_pruning_authorized == false and
  .m3_sixth_gate_closed == false and .release_ready == false
' "$output" >/dev/null
echo "PASS: actual packaged Vulpra submitted graphical Wayland frames under 3 isolated provider-denial modes"
echo "LIMIT: no attempted provider loads means no actual missing-provider branch observed; pixman does not prove hardware GPU/DMABuf fallback"
