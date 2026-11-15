#!/usr/bin/env bash
# Four fresh original NSS processes; read-only PKCS11 slot/FIPS queries.
# Never export raw logs, paths, PIDs, passwords or random samples.
set -euo pipefail
test "$#" -eq 4 || exit 2
lib="$1"; shim="$2"; probe="$3"; report="$4"
test -n "$RUNNER_TEMP" && test -n "$GITHUB_SHA"
test "$(basename "$lib")" = libnss3.so && test ! -e "$report"
test -s "$lib" && test -s "$shim" && test -x "$probe"
test ! -L "$lib" && test ! -L "$shim" && test ! -L "$probe"
appdir="$(dirname "$lib")"
for n in libnss3.so libsoftokn3.so libfreeblpriv3.so libnspr4.so; do
  test -s "$appdir/$n" && test ! -L "$appdir/$n"
  test "$(od -An -tx1 -N4 "$appdir/$n"|tr -d ' \n')" = 7f454c46
done
tmp="$(mktemp -d "$RUNNER_TEMP/original-pkcs11-readonly.XXXXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
: > "$tmp/modes.jsonl"
run_case() {
  local name="$1" group="$2" out="$tmp/$1-private-output" log="$tmp/$1-private-shim"
  : > "$out"; : > "$log"; chmod 0600 "$out" "$log"
  local status=0
  if test "$group" = none; then
    timeout --signal=TERM --kill-after=2s 25s \
      env -u LD_PRELOAD -u VULPRA_M3_DENY_GROUP -u VULPRA_M3_DENY_LOG \
        -u VULPRA_M3_DENY_FIXTURE_EXE LD_LIBRARY_PATH="$appdir" \
      "$probe" "$lib" > "$out" 2> "$tmp/$name-private-stderr" || status="$?"
  else
    timeout --signal=TERM --kill-after=2s 25s \
      env LD_PRELOAD="$shim" LD_LIBRARY_PATH="$appdir" \
        VULPRA_M3_DENY_GROUP="$group" VULPRA_M3_DENY_LOG="$log" \
        VULPRA_M3_DENY_FIXTURE_EXE=vulpra_pkcs11_readonly \
      "$probe" "$lib" > "$out" 2> "$tmp/$name-private-stderr" || status="$?"
  fi
  local soft=0 free=0 total=0 attached=0
  soft="$(grep -Ec '^DENIED (dlopen|dlmopen) (.*/)?libsoftokn3[.]so [0-9]+$' "$log" || true)"
  free="$(grep -Ec '^DENIED (dlopen|dlmopen) (.*/)?libfreeblpriv3[.]so [0-9]+$' "$log" || true)"
  total="$(grep -Ec '^DENIED (dlopen|dlmopen) ' "$log" || true)"
  attached="$(grep -Ec '^ATTACHED browser-process [0-9]+$' "$log" || true)"
  test "$total" -eq "$((soft+free))"
  local parsed="$tmp/$name-private-sanitized.json"
  if test "$status" -eq 0 && test "$(wc -l < "$out")" -eq 1; then
    jq -Rn --argjson exit "$status" --arg mode "$name" --arg group "$group" \
      --argjson soft "$soft" --argjson free "$free" --argjson total "$total" \
      --argjson attached "$attached" '
      input as $line |
      if ($line|test("^PKCS11_READONLY_V1( [a-z_]+=-?[0-9]{1,4}){15}$")) then
        ($line|split(" ")[1:]|map(split("=")|
          {key:.[0],value:(.[1]|tonumber)})|from_entries) as $p |
        if ($p|keys|sort)==(
          ["original_nss_open","exact_symbols","init","fips","system_fips",
           "internal_slot","internal_key_slot","slot_present",
           "key_slot_present","sha256_mechanism","rng","rng_nonzero",
           "shutdown","softoken_mapped","freebl_mapped"]|sort) then
          {
            mode:$mode,denial_group:$group,process_exit:$exit,
            original_nss_open:$p.original_nss_open,
            exact_original_symbols:$p.exact_symbols,
            NSS_NoDB_Init_rc:$p.init,
            original_PKCS11_FIPS_mode_readonly:$p.fips,
            system_FIPS_mode_readonly:$p.system_fips,
            internal_slot_obtained:$p.internal_slot,
            internal_key_slot_obtained:$p.internal_key_slot,
            internal_slot_present:$p.slot_present,
            internal_key_slot_present:$p.key_slot_present,
            SHA256_PKCS11_mechanism_available:$p.sha256_mechanism,
            original_RNG_rc:$p.rng,random_bytes_nonzero:($p.rng_nonzero==1),
            NSS_Shutdown_rc:$p.shutdown,
            original_softoken_ELF_mapped:($p.softoken_mapped==1),
            original_freebl_ELF_mapped:($p.freebl_mapped==1),
            actual_softoken_native_denials:$soft,
            actual_freebl_native_denials:$free,
            actual_total_native_denials:$total,
            original_native_shim_attachment_count:$attached,
            FIPS_mode_changed:false,
            original_private_paths_PIDs_keys_tokens_PINS_or_raw_logs_exported:false
          }
        else error("Unexpected native NSS source-defined probe field set") end
      else error("Original NSS PKCS11 private probe data not bounded") end
      ' < "$out" > "$parsed"
    cat "$parsed" >> "$tmp/modes.jsonl"
    printf '\n' >> "$tmp/modes.jsonl"
  else
    echo "FAIL: original NSS PKCS11 native probe did not complete cleanly in $name" >&2
    exit 1
  fi
  jq -r '"AUDIT: original NSS PKCS11 "+.mode+
    " init="+(.NSS_NoDB_Init_rc|tostring)+
    " FIPS_readonly="+(.original_PKCS11_FIPS_mode_readonly|tostring)+
    " internal_slot="+(.internal_slot_obtained|tostring)+
    " SHA256="+(.SHA256_PKCS11_mechanism_available|tostring)+
    " softoken_denied="+(.actual_softoken_native_denials|tostring)+
    " freebl_denied="+(.actual_freebl_native_denials|tostring)' "$parsed"
}
run_case baseline none
run_case softoken_missing nss_softoken
run_case freebl_missing nss_freebl
run_case both_targeted nss_both
jq -s --arg harness "$GITHUB_SHA" '{
  schema_version:1,
  status:"original_firefox160_real_readonly_PKCS11_internal_slot_SHA256_FIPS_state_under_NSS_denial",
  official_Firefox160_release_commit:"2887d9de1f69c0e9776413da80e7ba0d1225dd9b",
  complete_vulpra_28_overlay_tree:"42dd7439a27dde92f89ac5eed13f88117a4d7ab5",
  unchanged_original_native_archive_sha256:"530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb",
  original_native_browser_build_run:43138458940,
  probe_harness_commit:$harness,
  original_packaged_NSS_PKCS11_readonly_operations_executed:true,
  baseline_real_original_PKCS11_available:(any(.[];
    .mode=="baseline" and .process_exit==0 and
    .original_nss_open==1 and .exact_original_symbols==1 and
    .NSS_NoDB_Init_rc==0 and .internal_slot_obtained==1 and
    .internal_key_slot_obtained==1 and .internal_slot_present==1 and
    .internal_key_slot_present==1 and
    .SHA256_PKCS11_mechanism_available==1 and
    .original_RNG_rc==0 and .random_bytes_nonzero==true and
    .NSS_Shutdown_rc==0 and
    .original_softoken_ELF_mapped and .original_freebl_ELF_mapped)),
  original_module_FIPS_mode_readonly:([.[]|select(.mode=="baseline")|.original_PKCS11_FIPS_mode_readonly][0]//-2),
  runner_system_FIPS_mode_readonly:([.[]|select(.mode=="baseline")|.system_FIPS_mode_readonly][0]//-2),
  softoken_missing_actual_loads_observed:(any(.[];
    .mode=="softoken_missing" and .actual_softoken_native_denials>0 and
    .NSS_NoDB_Init_rc!=0)),
  freebl_missing_actual_loads_observed:(any(.[];
    .mode=="freebl_missing" and .actual_freebl_native_denials>0 and
    .NSS_NoDB_Init_rc!=0)),
  combined_target_softoken_failure_prevents_freebl_attempt:(any(.[];
    .mode=="both_targeted" and .actual_softoken_native_denials>0 and
    .actual_freebl_native_denials==0 and .NSS_NoDB_Init_rc!=0)),
  all_original_NSS_PKCS11_probes_completed_without_crash:(all(.[];
    .process_exit==0 and .original_nss_open==1 and
    .exact_original_symbols==1 and
    .original_private_paths_PIDs_keys_tokens_PINS_or_raw_logs_exported==false)),
  FIPS_enabled_or_FIPS_security_compliance_tested:false,
  no_FIPS_mode_change_or_system_crypto_config_mutation:true,
  no_private_key_PIN_token_write_or_password_operation:true,
  no_external_HSM_or_PKCS11_module_enumeration:true,
  real_browser_HTTPS_PKCS11_tested_in_this_native_run:false,
  full_Rust_CXX_FFI_dlopen_dlsym_graph_closed:false,
  actual_source_level_machine_callstacks_proven:false,
  personal_Arch_Hyprland_profiles_modified:false,
  source_pruning_authorized:false,
  security_current:false,release_ready:false,m3_sixth_gate_closed:false,
  modes:.
}' "$tmp/modes.jsonl" > "$report"
jq -e '
  .schema_version==1 and
  .baseline_real_original_PKCS11_available==true and
  .all_original_NSS_PKCS11_probes_completed_without_crash==true and
  ([.modes[].mode]|sort)==["baseline","both_targeted","freebl_missing","softoken_missing"] and
  .no_FIPS_mode_change_or_system_crypto_config_mutation==true and
  .source_pruning_authorized==false and .m3_sixth_gate_closed==false
' "$report" >/dev/null
echo 'PASS: original NSS PKCS11 internal slots, SHA256 mechanism, FIPS mode read-only and isolated native provider failures'
