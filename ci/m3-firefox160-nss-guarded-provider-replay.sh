#!/usr/bin/env bash
# Real original Firefox160 packaged NSS API in isolated subprocesses, never
# user profiles or host system NSS libraries; only bounded JSON archived.
set -euo pipefail
test "$#" -eq 4 || { echo 'Need original libnss3, shim, native probe and report' >&2; exit 2; }
original="$1"; shim="$2"; probe="$3"; report="$4"
test -n "$RUNNER_TEMP" && test -n "$GITHUB_SHA"
test -f "$original" && test -s "$shim" && test -x "$probe" && test ! -e "$report"
test ! -L "$original" && test ! -L "$shim" && test ! -L "$probe"
test "$(basename "$original")" = libnss3.so
appdir="$(dirname "$original")"
for n in libnss3.so libsoftokn3.so libfreeblpriv3.so libnspr4.so; do
  test -s "$appdir/$n" && test ! -L "$appdir/$n"
  test "$(od -An -tx1 -N4 "$appdir/$n" | tr -d ' \n')" = 7f454c46
done
tmp="$(mktemp -d "$RUNNER_TEMP/vulpra-nss-original.XXXXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
: > "$tmp/modes.jsonl"
mode() {
  local mode="$1" group="$2" out="$tmp/$1-output" log="$tmp/$1-private-denials"
  : > "$out"; : > "$log"; chmod 0600 "$out" "$log"
  local status=0
  if test "$group" = none; then
    timeout --signal=TERM --kill-after=3s 25s \
      env -u LD_PRELOAD -u VULPRA_M3_DENY_GROUP -u VULPRA_M3_DENY_LOG \
        -u VULPRA_M3_DENY_FIXTURE_EXE LD_LIBRARY_PATH="$appdir" \
      "$probe" "$original" > "$out" 2> "$tmp/$mode-stderr" || status="$?"
  else
    timeout --signal=TERM --kill-after=3s 25s \
      env LD_PRELOAD="$shim" LD_LIBRARY_PATH="$appdir" \
      VULPRA_M3_DENY_GROUP="$group" VULPRA_M3_DENY_LOG="$log" \
      VULPRA_M3_DENY_FIXTURE_EXE=vulpra_nss_probe \
      "$probe" "$original" > "$out" 2> "$tmp/$mode-stderr" || status="$?"
  fi
  local soft=0 free=0 total=0 attached=0
  soft="$(grep -Ec '^DENIED (dlopen|dlmopen) (.*/)?libsoftokn3[.]so [0-9]+$' "$log" || true)"
  free="$(grep -Ec '^DENIED (dlopen|dlmopen) (.*/)?libfreeblpriv3[.]so [0-9]+$' "$log" || true)"
  total="$(grep -Ec '^DENIED (dlopen|dlmopen) ' "$log" || true)"
  attached="$(grep -Ec '^ATTACHED browser-process [0-9]+$' "$log" || true)"
  test "$total" -eq "$((soft+free))"
  local parsed=false opened=0 source=0 init=-2 random=-2 nonzero=0 shutdown=-2 mappedsoft=0 mappedfree=0 line
  if test "$status" -eq 0 && test "$(wc -l < "$out")" -eq 1; then
    line="$(cat "$out")"
    if [[ "$line" =~ ^NSS_PROBE_V1[[:space:]]native_nss_open=([01])[[:space:]]original_nss_symbols=([01])[[:space:]]init=(-?[0-9]{1,4})[[:space:]]random=(-?[0-9]{1,4})[[:space:]]nonzero=([01])[[:space:]]shutdown=(-?[0-9]{1,4})[[:space:]]original_softoken_mapped=([01])[[:space:]]original_freebl_mapped=([01])$ ]]; then
      parsed=true
      opened="${BASH_REMATCH[1]}"; source="${BASH_REMATCH[2]}"
      init="${BASH_REMATCH[3]}"; random="${BASH_REMATCH[4]}"
      nonzero="${BASH_REMATCH[5]}"; shutdown="${BASH_REMATCH[6]}"
      mappedsoft="${BASH_REMATCH[7]}"; mappedfree="${BASH_REMATCH[8]}"
    fi
  fi
  jq -nc --arg mode "$mode" --arg group "$group" --argjson exit "$status" \
    --argjson parsed "$parsed" --argjson opened "$opened" --argjson source "$source" \
    --argjson init "$init" --argjson rng "$random" --argjson nz "$nonzero" \
    --argjson shutdown "$shutdown" --argjson soft "$soft" --argjson free "$free" \
    --argjson total "$total" --argjson attached "$attached" \
    --argjson mappedsoft "$mappedsoft" --argjson mappedfree "$mappedfree" '{
      mode:$mode,denial_group:$group,disposable_probe_exit_status:$exit,
      exact_original_NSS_API_probe_output_parsed:$parsed,
      original_libnss3_dlopen_succeeded:($opened==1),
      original_NSS_three_symbols_resolved_from_exact_package:($source==1),
      NSS_NoDB_Init_rc:$init,PK11_GenerateRandom_rc:$rng,
      generated_random_bytes_nonzero:($nz==1),NSS_Shutdown_rc:$shutdown,
      original_packaged_libsoftokn3_ELF_mapped:($mappedsoft==1),
      original_packaged_libfreeblpriv3_ELF_mapped:($mappedfree==1),
      actual_denied_libsoftokn3_loader_requests:$soft,
      actual_denied_libfreeblpriv3_loader_requests:$free,
      actual_denied_requests_total:$total,
      shim_attachment_fixture_witness_count:$attached,
      raw_library_paths_dlopen_PIDs_or_random_bytes_archived:false
    }' >> "$tmp/modes.jsonl"
  echo "AUDIT: original NSS $mode exit=$status probe_parsed=$parsed init=$init random=$random softoken_denied=$soft freebl_denied=$free"
}
mode baseline none
mode softoken_missing nss_softoken
mode freebl_missing nss_freebl
mode both_missing nss_both
jq -s --arg original '2887d9de1f69c0e9776413da80e7ba0d1225dd9b' \
  --arg tree '42dd7439a27dde92f89ac5eed13f88117a4d7ab5' \
  --arg package '530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb' \
  --arg harness "$GITHUB_SHA" '{
    schema_version:1,
    status:"original_firefox160_real_NSS_NoDB_Init_PK11_random_missing_softoken_freebl",
    original_mozilla_firefox160_commit:$original,
    original_vulpra_28_overlay_tree:$tree,
    original_compiled_archive_sha256:$package,
    original_native_producer_run:43138458940,
    current_probe_harness_git_commit:$harness,
    genuine_original_packaged_nss3_API_invoked:true,
    original_random_bytes_never_recorded:true,
    baseline_original_NSS_initialized_and_generated_random:
      (any(.[];.mode=="baseline" and .disposable_probe_exit_status==0 and
        .exact_original_NSS_API_probe_output_parsed and
        .original_libnss3_dlopen_succeeded and
        .original_NSS_three_symbols_resolved_from_exact_package and
        .NSS_NoDB_Init_rc==0 and .PK11_GenerateRandom_rc==0 and
        .generated_random_bytes_nonzero and .NSS_Shutdown_rc==0)),
    original_softoken_denial_actually_observed:
      (any(.[];.mode=="softoken_missing" and
        .actual_denied_libsoftokn3_loader_requests>0)),
    original_freebl_denial_actually_observed:
      (any(.[];.mode=="freebl_missing" and
        .actual_denied_libfreeblpriv3_loader_requests>0)),
    combined_mode_both_named_denials_actually_observed:
      (any(.[];.mode=="both_missing" and
        .actual_denied_libsoftokn3_loader_requests>0 and
        .actual_denied_libfreeblpriv3_loader_requests>0)),
    all_missing_provider_tests_completed_without_process_crash_or_timeout:
      (all(.[]|select(.mode!="baseline");
        .disposable_probe_exit_status==0 and
        .exact_original_NSS_API_probe_output_parsed)),
    actual_real_firefox_browser_or_TLS_flow_tested:false,
    all_NSS_PKCS11_FIPS_crypto_security_paths_tested:false,
    original_NSS_direct_dlopen_machine_callstacks_proven:false,
    complete_Rust_CXX_FFI_dlopen_dlsym_graph_closed:false,
    workstation_browser_profile_or_arch_hyprland_touched:false,
    source_pruning_authorized:false,
    security_current:false,release_ready:false,m3_sixth_gate_closed:false,
    modes:.
  }' "$tmp/modes.jsonl" > "$report"
jq -e '.schema_version==1 and
  .baseline_original_NSS_initialized_and_generated_random==true and
  (.modes|length)==4 and
  ([.modes[].mode]|sort)==["baseline","both_missing","freebl_missing","softoken_missing"] and
  all(.modes[];.raw_library_paths_dlopen_PIDs_or_random_bytes_archived==false) and
  .source_pruning_authorized==false and .m3_sixth_gate_closed==false' "$report" >/dev/null
echo 'PASS: source-packaged NSS baseline init and RNG, actual isolated provider-denial outcomes recorded'
echo 'LIMIT: only observed blocked native requests count as evidence; no real browser/TLS/FIPS or complete FFI acceptance'
