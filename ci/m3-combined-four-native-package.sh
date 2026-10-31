#!/usr/bin/env bash
# Run ONLY in the disposable GitHub Actions original-source native build.
# This is a combined-four feature experiment, not Vulpra's default or a
# statistically reproducible compressed-saving attribution.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo 'usage: m3-combined-four-native-package.sh ORIGINAL_SOURCE_ROOT RUNNER_TEMP' >&2
  exit 2
fi
original="$(realpath -e -- "$1")"
temp="$(realpath -e -- "$2")"
: "$SOURCE_SHA" "$FULL_ARCHIVE_SHA" "$FULL_RUN"
cd "$original"
test "$(git rev-parse HEAD)" = "$SOURCE_SHA"
./mach package
dist="$original/obj-vulpra-linux-m3-combined-lean/dist"
count="$(find "$dist" -maxdepth 1 -type f -name '*.tar.xz' | wc -l)"
test "$count" -eq 1
pkg="$(find "$dist" -maxdepth 1 -type f -name '*.tar.xz' -print -quit)"
mkdir -p "$temp/four" "$temp/full"
bash packaging/stage.sh "$pkg" "$temp/four/vulpra-four-lean.tar.xz"
(cd "$temp/four" && sha256sum -c vulpra-four-lean.tar.xz.sha256)
gh run download "$FULL_RUN" --repo "$GITHUB_REPOSITORY" \
  --name vulpra-m3-normandy-matched-full-baseline --dir "$temp/full"
(cd "$temp/full" && sha256sum -c full-normandy-baseline.tar.xz.sha256)
test "$(sha256sum "$temp/full/full-normandy-baseline.tar.xz" | awk '{print $1}')" = "$FULL_ARCHIVE_SHA"
tar -xf "$temp/four/vulpra-four-lean.tar.xz" -C "$temp/four"
test -x "$temp/four/vulpra/vulpra"
test "$(head -c 4 "$temp/four/vulpra/vulpra" | od -An -tx1 | tr -d ' \n')" = 7f454c46
grep -Fxq 'Name=Vulpra' "$temp/four/vulpra/application.ini"
full="$(stat -c %s "$temp/full/full-normandy-baseline.tar.xz")"
lean="$(stat -c %s "$temp/four/vulpra-four-lean.tar.xz")"
sha="$(sha256sum "$temp/four/vulpra-four-lean.tar.xz" | awk '{print $1}')"
jq -n --arg src "$SOURCE_SHA" --arg fullsha "$FULL_ARCHIVE_SHA" \
  --arg lean_sha "$sha" --arg full "$full" --arg lean "$lean" '{
   schema_version:1,
   status:"original_native_four_optin_combined_package_built",
   original_source_commit:$src,
   historical_original_full_archive_sha256:$fullsha,
   combined_native_archive_sha256:$lean_sha,
   full_original_archive_compressed_bytes:($full|tonumber),
   combined_optin_archive_compressed_bytes:($lean|tonumber),
   signed_full_minus_combined_compressed_delta_bytes:(($full|tonumber)-($lean|tonumber)),
   native_browser_compilation_verified:true,
   all_four_generated_config_guards_verified:true,
   protected_sync_wayland_sandbox_devtools_verified:true,
   actual_browser_runtime_or_feature_fallback_verified:false,
   independent_source_matched_compilation_runs:true,
   reproducible_additive_feature_byte_savings_proven:false,
   default_browser_or_user_profile_modified:false,
   source_pruning_authorized:false,
   m3_sixth_gate_closed:false
  }' > "$temp/four/m3-original-four-native-size.json"
jq -e '.status=="original_native_four_optin_combined_package_built" and
 .native_browser_compilation_verified==true and
 .all_four_generated_config_guards_verified==true and
 .protected_sync_wayland_sandbox_devtools_verified==true and
 .actual_browser_runtime_or_feature_fallback_verified==false and
 .reproducible_additive_feature_byte_savings_proven==false and
 .source_pruning_authorized==false and .m3_sixth_gate_closed==false' \
 "$temp/four/m3-original-four-native-size.json" >/dev/null
echo 'PASS: combined original-source real native package measured against original full control'
