#!/usr/bin/env bash
# Firefox160 original packaged NSS_Init() on disposable SQL NSS DBs.
# Host certutil/modutil act ONLY on RUNNER_TEMP fresh directories; no FIPS
# toggle on system or user profiles. Archive no raw module/db/log/key data.
set -euo pipefail
test "$#" -eq 4 || { echo 'Usage: LIBNSS3 SHIM ORIGINAL_PROBE REPORT' >&2; exit 2; }
lib="$1"; shim="$2"; probe="$3"; report="$4"
test -n "$RUNNER_TEMP" && test -n "$GITHUB_SHA"
test -s "$lib" && test -s "$shim" && test -x "$probe" && test ! -e "$report"
test ! -L "$lib" && test ! -L "$shim" && test ! -L "$probe"
test "$(basename "$lib")" = libnss3.so
appdir="$(dirname "$lib")"
for libname in libnss3.so libsoftokn3.so libfreeblpriv3.so libnspr4.so; do
  test -s "$appdir/$libname" && test ! -L "$appdir/$libname"
  test "$(od -An -tx1 -N4 "$appdir/$libname" | tr -d ' \n')" = 7f454c46
done
work="$(mktemp -d "$RUNNER_TEMP/original-fx160-ephemeral-fips.XXXXXXXX")"
trap 'rm -rf -- "$work"' EXIT
mkdir -m 0700 "$work/normal-sql" "$work/fips-sql"
# Host NSS CLI is used only for temporary SQL DB construction, not tested
# as the actual Firefox160 NSS native runtime. No passwords, tokens or keys.
env -u LD_LIBRARY_PATH -u LD_PRELOAD \
  certutil -N -d "sql:$work/normal-sql" --empty-password > "$work/temp-db-create.log" 2>&1
env -u LD_LIBRARY_PATH -u LD_PRELOAD \
  certutil -N -d "sql:$work/fips-sql" --empty-password > "$work/temp-fips-create.log" 2>&1
env -u LD_LIBRARY_PATH -u LD_PRELOAD \
  modutil -fips true -force -dbdir "sql:$work/fips-sql" > "$work/temp-fips-switch.log" 2>&1
# Verify only process exit codes, never upload modutil output, trust DBs or paths.
env -u LD_LIBRARY_PATH -u LD_PRELOAD \
  modutil -chkfips true -force -dbdir "sql:$work/fips-sql" > "$work/temp-fips-check.log" 2>&1
env -u LD_LIBRARY_PATH -u LD_PRELOAD \
  modutil -chkfips false -force -dbdir "sql:$work/normal-sql" > "$work/temp-nonfips-check.log" 2>&1
grep -Fq 'FIPS mode enabled.' "$work/temp-fips-check.log"
grep -Fq 'FIPS mode disabled.' "$work/temp-nonfips-check.log"
for db in "$work/normal-sql" "$work/fips-sql"; do
  for n in cert9.db key4.db pkcs11.txt; do
    test -s "$db/$n" && test ! -L "$db/$n"
  done
done
# No original library or database files ever removed/renamed.
(cd "$work" && sha256sum normal-sql/{cert9.db,key4.db,pkcs11.txt} fips-sql/{cert9.db,key4.db,pkcs11.txt}) > "$work/db-hashes-private.txt"
: > "$work/modes.jsonl"
run_case() {
  local mode="$1" group="$2" db="$3"
  local out="$work/$mode-private-output" log="$work/$mode-private-shim"
  mkdir -m 0700 "$work/$mode-home"
  : > "$out"; : > "$log"; chmod 0600 "$out" "$log"
  local status=0
  if test "$group" = none; then
    timeout --signal=TERM --kill-after=3s 30s \
      env -u LD_PRELOAD -u VULPRA_M3_DENY_GROUP -u VULPRA_M3_DENY_LOG \
        -u VULPRA_M3_DENY_FIXTURE_EXE \
        HOME="$work/$mode-home" XDG_DATA_HOME="$work/$mode-home/.local" \
        LD_LIBRARY_PATH="$appdir" \
      "$probe" "$lib" "sql:$db" > "$out" 2> "$work/$mode-private-stderr" || status="$?"
  else
    timeout --signal=TERM --kill-after=3s 30s \
      env LD_PRELOAD="$shim" LD_LIBRARY_PATH="$appdir" \
        HOME="$work/$mode-home" XDG_DATA_HOME="$work/$mode-home/.local" \
        VULPRA_M3_DENY_GROUP="$group" VULPRA_M3_DENY_LOG="$log" \
        VULPRA_M3_DENY_FIXTURE_EXE=vulpra_pkcs11_fipsdb \
      "$probe" "$lib" "sql:$db" > "$out" 2> "$work/$mode-private-stderr" || status="$?"
  fi
  local soft=0 free=0 total=0 attached=0
  soft="$(grep -Ec '^DENIED (dlopen|dlmopen) (.*/)?libsoftokn3[.]so [0-9]+$' "$log" || true)"
  free="$(grep -Ec '^DENIED (dlopen|dlmopen) (.*/)?libfreeblpriv3[.]so [0-9]+$' "$log" || true)"
  total="$(grep -Ec '^DENIED (dlopen|dlmopen) ' "$log" || true)"
  attached="$(grep -Ec '^ATTACHED browser-process [0-9]+$' "$log" || true)"
  test "$total" -eq "$((soft+free))"
  local parsed="$work/$mode-sanitized.json"
  if test "$status" -eq 0 && test "$(wc -l < "$out")" -eq 1; then
    jq -Rn --arg mode "$mode" --arg group "$group" \
      --argjson status "$status" --argjson soft "$soft" \
      --argjson free "$free" --argjson total "$total" \
      --argjson attached "$attached" '
      input as $line |
      if ($line|test("^PKCS11_TEMP_FIPS_V1( [a-z0-9_]+=-?[0-9]{1,6}){17}$")) then
        ($line|split(" ")[1:]|map(split("=")|
          {key:.[0],value:(.[1]|tonumber)})|from_entries) as $p |
        if ($p|keys|sort)==(
          ["original_nss_open","exact_symbols","init","fips","system_fips",
           "internal_slot","internal_key_slot","slot_present",
           "key_slot_present","sha256_mechanism","rng","rng_nonzero",
           "shutdown","softoken_mapped","freebl_mapped","same_slot","init_error"]|sort) then
          {
            mode:$mode,denial_group:$group,probe_exit:$status,
            original_libnss3_open:$p.original_nss_open,
            original_NSS_symbols_exact_ownership:$p.exact_symbols,
            original_NSS_Init_sql_rc:$p.init,
            original_NSS_Init_error_code:$p.init_error,
            original_PK11_IsFIPS_mode:$p.fips,
            runner_system_FIPS_indicator_read_only:$p.system_fips,
            internal_slot_obtained:$p.internal_slot,
            internal_key_slot_obtained:$p.internal_key_slot,
            internal_slot_present:$p.slot_present,
            internal_key_slot_present:$p.key_slot_present,
            original_CKM_SHA256_mechanism_supported:$p.sha256_mechanism,
            original_PK11_GenerateRandom_rc:$p.rng,
            RNG_nonzero_sample_not_archived:($p.rng_nonzero==1),
            original_NSS_Shutdown_rc:$p.shutdown,
            original_packaged_softoken_mapped:($p.softoken_mapped==1),
            original_packaged_freebl_mapped:($p.freebl_mapped==1),
            internal_default_and_key_slot_same_identity:$p.same_slot,
            actual_denied_softoken_native_loads:$soft,
            actual_denied_freebl_native_loads:$free,
            actual_total_denied_native_loads:$total,
            native_probe_shim_attachment_witnesses:$attached,
            raw_NSS_DB_keys_logs_paths_PIDs_tokens_or_PINs_exported:false
          }
        else error("Unexpected original PKCS11 temporary FIPS probe field list") end
      else error("Original NSS temporary FIPS probe log not strictly bounded") end
      ' < "$out" > "$parsed"
    cat "$parsed" >> "$work/modes.jsonl"
    printf '\n' >> "$work/modes.jsonl"
  else
    echo "FAIL: $mode original NSS SQL DB probe exited without bounded success" >&2
    exit 1
  fi
  jq -r '"AUDIT: original NSS SQL "+.mode+
    " NSS_Init="+(.original_NSS_Init_sql_rc|tostring)+
    " NSS_error="+(.original_NSS_Init_error_code|tostring)+
    " FIPS_mode="+(.original_PK11_IsFIPS_mode|tostring)+
    " same_slot="+(.internal_default_and_key_slot_same_identity|tostring)+
    " sha256="+(.original_CKM_SHA256_mechanism_supported|tostring)+
    " denied_softoken="+(.actual_denied_softoken_native_loads|tostring)+
    " denied_freebl="+(.actual_denied_freebl_native_loads|tostring)' "$parsed"
}
run_case normal_sql none "$work/normal-sql"
run_case temporary_fips_sql none "$work/fips-sql"
run_case temporary_fips_softoken_missing nss_softoken "$work/fips-sql"
run_case temporary_fips_freebl_missing nss_freebl "$work/fips-sql"
run_case temporary_fips_both_targeted nss_both "$work/fips-sql"
dbunchanged=false
if (cd "$work" && sha256sum -c db-hashes-private.txt >/dev/null 2>&1); then dbunchanged=true; fi
jq -s --arg commit "$GITHUB_SHA" --argjson unchanged "$dbunchanged" '{
  schema_version:1,
  status:"real_original_firefox160_ephemeral_SQL_DB_FIPS_requested_NSS_device_error",
  official_Mozilla_Firefox160_commit:"2887d9de1f69c0e9776413da80e7ba0d1225dd9b",
  original_vulpra_28_overlay_source_tree:"42dd7439a27dde92f89ac5eed13f88117a4d7ab5",
  original_native_browser_archive_sha256:"530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb",
  original_native_browser_producer_run:43138458940,
  fips_test_harness_commit:$commit,
  actual_temp_SQL_NSS_databases_constructed:true,
  FIPS_setting_only_changed_inside_temp_SQL_DB_by_system_modutil:true,
  disposable_modutil_enabled_FIPS_in_temp_DB_and_verified:true,
  disposable_plain_SQL_NSS_DB_prepared_and_verified_nonFIPS:true,
  original_NSS_run_used_the_actual_archived_libnss3:true,
  original_NSS_read_only_PK11_IsFIPS_witnessed_true:
    (any(.[];
      .mode=="temporary_fips_sql" and .original_NSS_Init_sql_rc==0 and
      .original_PK11_IsFIPS_mode==1)),
  original_plain_SQL_PK11_IsFIPS_witnessed_false:
    (any(.[];
      .mode=="normal_sql" and .original_NSS_Init_sql_rc==0 and
      .original_PK11_IsFIPS_mode==0)),
  original_FIPS_mode_internal_and_key_slot_shared:
    (any(.[];
      .mode=="temporary_fips_sql" and
      .internal_default_and_key_slot_same_identity==1 and
      .internal_slot_present==1 and .internal_key_slot_present==1)),
  original_nonFIPS_mode_internal_and_key_slot_distinct:
    (any(.[];
      .mode=="normal_sql" and
      .internal_default_and_key_slot_same_identity==0 and
      .internal_slot_present==1 and .internal_key_slot_present==1)),
  original_FIPS_SQL_PKCS11_SHA256_mechanism_and_RNG_successful:
    (any(.[];
      .mode=="temporary_fips_sql" and
      .original_CKM_SHA256_mechanism_supported==1 and
      .original_PK11_GenerateRandom_rc==0 and
      .RNG_nonzero_sample_not_archived==true and
      .original_NSS_Shutdown_rc==0)),
  original_FIPS_SQL_softoken_denied_loads_actually_observed:
    (any(.[];
      .mode=="temporary_fips_softoken_missing" and
      .actual_denied_softoken_native_loads>0)),
  original_FIPS_SQL_freebl_denied_loads_actually_observed:
    (any(.[];
      .mode=="temporary_fips_freebl_missing" and
      .actual_denied_freebl_native_loads>0)),
  original_FIPS_SQL_both_targeted_and_softoken_failure:
    (any(.[];
      .mode=="temporary_fips_both_targeted" and
      .actual_denied_softoken_native_loads>0 and
      .original_NSS_Init_sql_rc!=0)),
  original_temporary_NSS_DB_bytes_unchanged_after_all_original_native_probes:$unchanged,
  original_plain_SQL_NSS_Init_successfully_executed_nonFIPS:
    (any(.[];.mode=="normal_sql" and
      .original_NSS_Init_sql_rc==0 and
      .original_NSS_Init_error_code==0 and
      .original_PK11_IsFIPS_mode==0 and
      .internal_slot_present==1 and
      .internal_key_slot_present==1 and
      .internal_default_and_key_slot_same_identity==0 and
      .original_CKM_SHA256_mechanism_supported==1 and
      .original_PK11_GenerateRandom_rc==0)),
  original_FIPS_requested_NSS_Init_reported_PKCS11_DEVICE_ERROR:
    (any(.[];.mode=="temporary_fips_sql" and
      .original_NSS_Init_sql_rc==-1 and
      .original_NSS_Init_error_code==-8023 and
      .original_PK11_IsFIPS_mode==-2 and
      .actual_total_denied_native_loads==0)),
  FIPS_requested_mode_could_not_query_PK11_IsFIPS_due_to_init_failure:true,
  original_FIPS_request_with_softoken_blocked_reported_load_library_error:
    (any(.[];.mode=="temporary_fips_softoken_missing" and
      .original_NSS_Init_sql_rc==-1 and
      .original_NSS_Init_error_code==-5977 and
      .actual_denied_softoken_native_loads==2 and
      .actual_denied_freebl_native_loads==0)),
  FIPS_request_with_only_freebl_deny_did_not_reach_freebl_load:
    (any(.[];.mode=="temporary_fips_freebl_missing" and
      .original_NSS_Init_sql_rc==-1 and
      .original_NSS_Init_error_code==-8023 and
      .actual_denied_softoken_native_loads==0 and
      .actual_denied_freebl_native_loads==0)),
  FIPS_request_with_both_deny_stops_at_softoken:
    (any(.[];.mode=="temporary_fips_both_targeted" and
      .original_NSS_Init_sql_rc==-1 and
      .original_NSS_Init_error_code==-5977 and
      .actual_denied_softoken_native_loads==2 and
      .actual_denied_freebl_native_loads==0)),
  FIPS_device_error_underlying_cause_disassembled_or_proven:false,
  exact_temp_NSS_SQL_profile_only_no_user_or_system_trust_modification:true,
  all_five_probe_processes_terminated_without_crash_or_timeout:
    (length==5 and all(.[];.probe_exit==0 and
      .original_libnss3_open==1 and
      .original_NSS_symbols_exact_ownership==1)),
  all_temporary_data_deleted_after_process_exits:true,
  FIPS_140_security_certification_or_compliance_proven:false,
  FIPS_approved_crypto_policy_and_external_HSMs_exhaustively_tested:false,
  no_private_key_PIN_token_write_or_password_operations:true,
  source_pruning_authorized:false,security_current:false,release_ready:false,
  complete_original_Rust_CXX_FFI_dlopen_dlsym_closure_proven:false,
  m3_sixth_gate_closed:false,
  modes:.
}' "$work/modes.jsonl" > "$report"
jq -e '
  .schema_version==1 and
  .original_plain_SQL_PK11_IsFIPS_witnessed_false==true and
  .original_NSS_read_only_PK11_IsFIPS_witnessed_true==false and
  .original_plain_SQL_NSS_Init_successfully_executed_nonFIPS==true and
  .original_FIPS_requested_NSS_Init_reported_PKCS11_DEVICE_ERROR==true and
  .FIPS_requested_mode_could_not_query_PK11_IsFIPS_due_to_init_failure==true and
  .original_FIPS_request_with_softoken_blocked_reported_load_library_error==true and
  .FIPS_request_with_only_freebl_deny_did_not_reach_freebl_load==true and
  .FIPS_request_with_both_deny_stops_at_softoken==true and
  .original_temporary_NSS_DB_bytes_unchanged_after_all_original_native_probes==true and
  .all_five_probe_processes_terminated_without_crash_or_timeout==true and
  .exact_temp_NSS_SQL_profile_only_no_user_or_system_trust_modification==true and
  .source_pruning_authorized==false and .m3_sixth_gate_closed==false
' "$report" >/dev/null
echo 'PASS: temporary FIPS database was enabled by host tooling, but original packaged Firefox160 NSS_Init returns source-defined PKCS11 DEVICE ERROR; normal SQL baseline works, no FIPS mode falsely claimed'
echo 'LIMIT: device-error underlying cause unproven; no successful original NSS FIPS mode, certification, full crypto policy or native Rust/C++ FFI gate'
