#!/usr/bin/env bash
# CI-only source-pinned Vulpra libxul dlsym provider crosswalk.
# Runs inside the already unprivileged original-browser WebDriver process.
# All raw process IDs and loader traces remain in the disposable /tmp.
set -euo pipefail
[[ $# -eq 1 && "$1" == /reports/m3-original-browser-libudev-dlopen-callsite.json ]] || exit 2
[[ "$SOURCE_SHA" == b1482404dfb8b01342990ee99ea3df0f9756b5f7 ]] || exit 2
[[ "$ARCHIVE_SHA" == 7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a ]] || exit 2
[[ "$VULPRA_M3_LIBUDEV_DLSYM_TRACE" == /tmp/vulpra-m3-libudev-dlsym.trace ]] || exit 2
[[ "$VULPRA_M3_LIBUDEV_DLOPEN_TRACE" == /tmp/vulpra-m3-libudev-dlopen.trace ]] || exit 2
[[ -f /audit/udev-original-abi.json && -f /audit/dlsym-crosswalk.jq ]] || exit 2
sym="$VULPRA_M3_LIBUDEV_DLSYM_TRACE"
open="$VULPRA_M3_LIBUDEV_DLOPEN_TRACE"
feature="$1"
out=/reports/m3-original-browser-libudev-dlsym-provider.json
[[ -s "$sym" && -s "$open" && -s "$feature" ]] || {
  echo 'No actual original libxul dlsym provider record alongside dlopen' >&2
  exit 1
}
[[ "$(stat -c %s "$sym")" -le 65536 ]] || exit 1
audit() {
  jq -n --arg src "$SOURCE_SHA" --arg archive "$ARCHIVE_SHA" \
    --slurpfile abi /audit/udev-original-abi.json \
    --slurpfile feature "$2" \
    --rawfile dlsym "$1" --rawfile dlopen "$3" \
    -f /audit/dlsym-crosswalk.jq
}
audit "$sym" "$feature" "$open" >"$out"
jq -e '
  .schema_version==1 and
  .status=="original_instrumented_browser_libxul_udev_symbol_real_provider_resolution_observed" and
  .original_rust_source_declared_symbol_count==49 and
  .source_declared_udev_new_resolved_by_actual_original_browser==true and
  .unique_original_browser_udev_symbols_resolved>=1 and
  .libxul_dlopen_and_libudev_dlsym_success_same_original_browser_pid_verified==true and
  .ld_preload_instrumentation_changes_original_symbol_resolution==true and
  .uninstrumented_original_browser_dlsym_provider_verified==false and
  .source_pruning_authorized==false and .native_bytes_saved==0 and
  .m3_sixth_gate_closed==false
' "$out" >/dev/null
# Mutate real records only in /tmp, never upload them.
cp "$sym" /tmp/m3-udev-mutant
printf '1\t0x123\tudev_nonexistent\thit\tlibudev.so.1.7.15\n' >>/tmp/m3-udev-mutant
if audit /tmp/m3-udev-mutant "$feature" "$open" >/dev/null 2>&1; then
  echo 'FAIL: undeclared original Rust libudev symbol accepted' >&2; exit 1
fi
awk -F '\t' 'BEGIN{OFS="\t"} $4=="hit"{$5="libxul.so"} {print}' "$sym" >/tmp/m3-udev-mutant
if audit /tmp/m3-udev-mutant "$feature" "$open" >/dev/null 2>&1; then
  echo 'FAIL: symbol supplied by incorrect provider accepted' >&2; exit 1
fi
awk -F '\t' 'BEGIN{OFS="\t"} {$1="9999999999"; print}' "$sym" >/tmp/m3-udev-mutant
if audit /tmp/m3-udev-mutant "$feature" "$open" >/dev/null 2>&1; then
  echo 'FAIL: nonmatching browser process accepted' >&2; exit 1
fi
jq '.source_pinned_libxul_normal_load_hit_at_return_pc_0x9936667=false' \
  "$feature" >/tmp/m3-udev-feature-mutant.json
if audit "$sym" /tmp/m3-udev-feature-mutant.json "$open" >/dev/null 2>&1; then
  echo 'FAIL: original native loader callsite mutation accepted' >&2; exit 1
fi
echo 'M3_UDEV_DLSYM=actual_original_browser_provider_and_four_negative_mutants_passed'
