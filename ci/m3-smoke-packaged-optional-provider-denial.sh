#!/usr/bin/env bash
# Re-run the existing source-linked *actual packaged* browser screenshot smoke
# with optional library groups deliberately unavailable via a tightly scoped
# LD_PRELOAD interposer. This never edits host libraries or any real profile.
# No provider-denial log entries => target path NOT exercised, not a fallback.
set -euo pipefail
if test "$#" -ne 3; then
  echo "usage: $0 REPOSITORY_ROOT VERIFIED_INTERPOSER_SO OUTPUT_JSON" >&2
  exit 2
fi
repo="$1"
shim="$2"
output="$3"
test "$repo" = "$GITHUB_WORKSPACE"
test "$(git -C "$repo" rev-parse HEAD)" = "$GITHUB_SHA"
test -s "$shim" && test ! -L "$shim"
test "$output" = "$RUNNER_TEMP/m3-packaged-provider-denial-runtime.json"
test ! -e "$output"
pkg="$repo/.git/vulpra-native-build/packages/vulpra-local-m3-native-link-ci.tar.xz"
baseline="$repo/.git/vulpra-native-build/m3-localhost-acceptance.json"
test -s "$pkg"
test -s "$baseline"
test "$(find "$repo/.git/vulpra-native-build/packages" -maxdepth 1 -name 'vulpra-local-m3-native-link-ci.tar.xz' -type f | wc -l)" -eq 1
package_sha="$(sha256sum "$pkg" | cut -d' ' -f1)"
jq -e --arg digest "$package_sha" '
  .schema_version == 1 and .result == "pass" and
  .sha256 == $digest and .profile_isolation == true and
  .screenshot_png_complete_and_crc_valid == true
' "$baseline" >/dev/null

tmp="$(mktemp -d "$RUNNER_TEMP/vulpra-provider-denial.XXXXXXXX")"
cp "$baseline" "$tmp/verified-normal-screenshot-baseline.json"
restore() {
  cp -f "$tmp/verified-normal-screenshot-baseline.json" "$baseline"
  rm -rf -- "$tmp"
}
trap restore EXIT
rows="$tmp/results.jsonl"
: > "$rows"
for group in gbm vaapi ffmpeg; do
  log="$tmp/denials-$group.log"
  touch "$log"
  chmod 0600 "$log"
  passed=false
  # Existing browser test controls its own temp HOME, launcher, checksum,
  # localhost web server and fully parsed PNG. The shim checks /proc/self/exe
  # before intercepting any dlopen; Python, timeout and shell remain unaffected.
  if env -u VULPRA_M3_DENY_FIXTURE_EXE \
    LD_PRELOAD="$shim" \
    VULPRA_M3_DENY_GROUP="$group" \
    VULPRA_M3_DENY_LOG="$log" \
    python3 ci/smoke-m3-localhost-package.py "$repo" \
    > "$tmp/runtime-$group.log" 2>&1; then
    if jq -e --arg digest "$package_sha" '
      .schema_version == 1 and .result == "pass" and
      .sha256 == $digest and .profile_isolation == true and
      .screenshot_png_complete_and_crc_valid == true
    ' "$baseline" >/dev/null; then
      passed=true
    fi
  fi
  test "$(stat -c '%s' "$log")" -lt 16777216
  attached="$(grep -c '^ATTACHED browser-process ' "$log" || true)"
  denied="$(grep -Ec '^DENIED (dlopen|dlmopen) ' "$log" || true)"
  # Record all findings, including negative control / no-load cases. Do not
  # claim missing-provider execution just because the screenshot succeeded.
  jq -nc \
    --arg group "$group" \
    --argjson attached "$attached" \
    --argjson denied "$denied" \
    --argjson screenshot "$passed" '{
      provider_group:$group,
      actual_packaged_browser_instrumentation_attached:($attached>0),
      actual_browser_process_attachment_records:$attached,
      actual_matching_optional_provider_load_denials:$denied,
      provider_missing_path_observed:($denied>0),
      screenshot_passed:$screenshot,
      screenshot_passed_after_observed_denial:($screenshot and $denied>0),
      all_conditional_feature_routes_tested:false,
      software_video_decoding_fallback_proven:false,
      Wayland_dmabuf_rendering_fallback_proven:false
    }' >> "$rows"
  echo "AUDIT: packaged Vulpra $group attached=$attached denied=$denied screenshot_passed=$passed"
  if test "$passed" != true || test "$attached" -eq 0; then
    # Preserve the partial outcome as a bounded report below, then fail.
    break
  fi
done

jq -s \
  --arg source "$GITHUB_SHA" \
  --arg archive "$package_sha" '{
    schema_version:1,
    status:"real_packaged_native_browser_optional_provider_denial_probe",
    native_source_commit:$source,
    verified_packaged_archive_sha256:$archive,
    actual_normal_packaged_browser_relaunched:true,
    environment:"disposable headless Vulpra localhost screenshot smoke",
    original_private_home_and_profiles_untouched:true,
    system_libraries_modified:false,
    used_compiled_LD_PRELOAD_interposer:true,
    attempted_provider_groups:(map(.provider_group)),
    observed_denied_library_loads:(map(.actual_matching_optional_provider_load_denials)|add),
    every_scenario_attached_and_screenshot_passed:(length==3 and all(.[]; .actual_packaged_browser_instrumentation_attached and .screenshot_passed)),
    at_least_one_matching_provider_denial_observed:any(.[]; .provider_missing_path_observed),
    runtime_modes:.,
    all_requested_library_arguments_and_indirect_edges_proven:false,
    hardware_video_or_Wayland_gpu_fallback_complete:false,
    target_endeavouros_hyprland_verified:false,
    source_pruning_authorized:false,
    m3_sixth_gate_closed:false,
    release_ready:false
  }' "$rows" > "$output"

jq -e '
  .schema_version==1 and
  .actual_normal_packaged_browser_relaunched==true and
  .every_scenario_attached_and_screenshot_passed==true and
  .source_pruning_authorized==false and .m3_sixth_gate_closed==false and
  .hardware_video_or_Wayland_gpu_fallback_complete==false
' "$output" >/dev/null
echo "PASS: actual source-pinned packaged Vulpra rendered three isolated optional-provider-denial-mode screenshots"
echo "LIMIT: if requested library was never loaded, no missing-provider runtime branch exercised; no full software-video/Wayland GPU fallback"
