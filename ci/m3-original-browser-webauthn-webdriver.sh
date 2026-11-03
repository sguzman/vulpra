#!/usr/bin/env bash
# CI-only real original browser virtual WebAuthn and physical-USB-backend no-device probes, offline.
set -euo pipefail
[[ $# -eq 3 ]] || exit 2
browser="$(realpath -e -- "$1")"
origin="$(realpath -e -- "$2")"
report="$3"
mode="${VULPRA_M3_ORIGINAL_WEBAUTHN_MODE:-virtual}"
[[ "$mode" == virtual || "$mode" == usb-no-device || "$mode" == usb-dlopen-trace ]] || { echo 'Unsupported WebAuthn CI mode' >&2; exit 2; }
if [[ "$mode" == usb-no-device || "$mode" == usb-dlopen-trace ]]; then
  [[ "${VULPRA_M3_NO_USB_PASSTHROUGH:-}" == 1 ]] || { echo 'USB probe must explicitly disallow device passthrough' >&2; exit 2; }
  for dev in /dev/hidraw*; do [[ ! -e "$dev" ]] || { echo 'USB probe unexpectedly has physical hidraw device' >&2; exit 2; }; done
fi
# CI-only diagnostic LD_PRELOAD changes the target's dynamic resolution.
# Require exact tracer path and a real ELF binary for the dedicated trace
# mode. The previous uninstrumented run 41371647131 is the control.
if [[ "$mode" == usb-dlopen-trace ]]; then
  [[ "${LD_PRELOAD:-}" == /audit/libudev-trace.so ]] || { echo 'Unexpected tracer location' >&2; exit 2; }
  [[ "${VULPRA_M3_LIBUDEV_DLOPEN_TRACE:-}" == /tmp/vulpra-m3-libudev-dlopen.trace ]] || {
    echo 'Missing bounded libudev callsite trace output' >&2; exit 2;
  }
  [[ -r "$LD_PRELOAD" ]] || { echo 'Missing tracing shared object' >&2; exit 2; }
fi
[[ -x "$browser" && -x "$origin" && "$(basename "$browser")" == vulpra ]] || exit 2
[[ "$MOZ_DISABLE_NONLOCAL_CONNECTIONS" == 1 && "$VULPRA_OFFLINE_CONTAINER_ONLY" == 1 ]] || exit 2
for cmd in geckodriver curl jq grep; do command -v "$cmd" >/dev/null || exit 2; done
# setup capabilities must be gone before any driver/browser/HTTP service.
cap_eff="$(awk '/^CapEff:/ {print $2}' /proc/self/status)"
cap_prm="$(awk '/^CapPrm:/ {print $2}' /proc/self/status)"
[[ "$cap_eff" == 0000000000000000 && "$cap_prm" == 0000000000000000 ]] || {
  echo 'Offline browser user retained Linux capabilities' >&2; exit 2;
}

work="$(mktemp -d /tmp/vulpra-m3-webauthn.XXXXXX)"
export HOME="$work/home" XDG_DATA_HOME="$work/data" XDG_RUNTIME_DIR="$work/runtime" MOZ_CRASHREPORTER_DISABLE=1 XRE_START_OFFLINE=1
# Exact Vulpra/Firefox Marionette requirement for chrome context; ONLY this
# disposable, no-network, unprivileged WebDriver test, never an installed profile.
export MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1
export WAYLAND_DISPLAY=wayland-vulpra-m3 XDG_SESSION_TYPE=wayland GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1
unset MOZ_HEADLESS DISPLAY
mkdir -m 0700 "$HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
server_pid='' driver_pid='' weston_pid='' session=''
base='http://127.0.0.1:4444'
api(){
 local method="$1" path="$2" data="$3"
 curl --noproxy '*' -sS --max-time 25 -X "$method" \
  -H 'Content-Type: application/json' -d "$data" "$base$path"
}
cleanup(){
 [[ -z "$session" ]] || api DELETE "/session/$session" '{}' >/dev/null 2>&1 || true
 if [[ -n "$driver_pid" ]]; then kill "$driver_pid" 2>/dev/null || true; wait "$driver_pid" 2>/dev/null || true; fi
 if [[ -n "$server_pid" ]]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi
 if [[ -n "$weston_pid" ]]; then kill "$weston_pid" 2>/dev/null || true; wait "$weston_pid" 2>/dev/null || true; fi
 rm -rf -- "$work"
}
trap cleanup EXIT
# Identical private Weston backend/renderer as the already proven original
# browser Wayland frame harness; no host display or X11 fallback.
weston --backend=headless-backend.so --renderer=pixman --idle-time=0 \
 --socket="$WAYLAND_DISPLAY" --log="$work/weston.log" >"$work/weston.stdout" 2>&1 &
weston_pid=$!
weston_ready=false
for _ in {1..40}; do
 if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then weston_ready=true; break; fi
 kill -0 "$weston_pid" 2>/dev/null || { echo 'Private Weston exited early' >&2; exit 1; }
 sleep 0.25
done
[[ "$weston_ready" == true ]] || { echo 'Private Weston socket unavailable' >&2; exit 1; }
wayland-info >"$work/wayland-info.log" 2>&1
grep -Fq xdg_wm_base "$work/wayland-info.log" || { echo 'Private Weston lacks xdg_wm_base' >&2; exit 1; }
"$origin" vulpra-original-offline-webauthn >"$work/origin.log" 2>&1 &
server_pid=$!
geckodriver --host 127.0.0.1 --port 4444 --log error >"$work/driver.log" 2>&1 &
driver_pid=$!
ready=false
for _ in {1..45}; do
 if curl --noproxy '*' -s --max-time 1 "$base/status" | jq -e '.value.ready==true' >/dev/null 2>&1 &&
    curl --noproxy '*' -s --max-time 1 http://127.0.0.1:18888/ | grep -Fq 'Vulpra Offline WebAuthn QA'; then
   ready=true; break
 fi
 kill -0 "$driver_pid" 2>/dev/null || { echo 'Driver stopped' >&2; exit 1; }
 sleep 0.4
done
[[ "$ready" == true ]] || { echo 'Offline driver/origin not ready' >&2; tail -n 30 "$work/driver.log" >&2; exit 1; }
caps="$(jq -nc --arg bin "$browser" --argjson usb "$([[ "$mode" != virtual ]] && echo true || echo false)" '{capabilities:{alwaysMatch:{browserName:"firefox","webauthn:virtualAuthenticators":true,
 "moz:firefoxOptions":{binary:$bin,args:[],
 prefs:{"security.webauth.webauthn":true,"security.webauth.webauthn_enable_softtoken":($usb|not),
 "security.webauth.webauthn_enable_usbtoken":$usb,"security.webauthn.ctap2":true}}}}}')"
resp="$(api POST /session "$caps")"
session="$(jq -er '.value.sessionId // .sessionId' <<<"$resp")" || {
 echo 'Original browser WebDriver session failed' >&2
 # Only transient, sanitized diagnostic lines: no browser/user profile paths,
 # PIDs, full startup traces or virtual credential bytes in public CI logs.
 grep -Ei 'marionette|sandbox|fatal|error|abort|crash|exited|failed|gtk' "$work/driver.log" \
   | sed -E 's@/[^[:space:]":]+@<path>@g' | cut -c 1-220 | tail -n 14 >&2 || true
 jq -c '{error:.value.error,message:(.value.message|tostring|.[0:150])}' <<<"$resp" >&2
 exit 1
}
api POST "/session/$session/timeouts" '{"script":18000,"pageLoad":30000}' | jq -e '.value==null' >/dev/null
api POST "/session/$session/url" '{"url":"http://localhost:18888/"}' | jq -e '.value==null' >/dev/null
js='return {origin:location.origin,secure:isSecureContext,create:typeof navigator.credentials?.create,get:typeof navigator.credentials?.get};'
state="$(api POST "/session/$session/execute/sync" "$(jq -nc --arg script "$js" '{script:$script,args:[]}')")"
jq -e '.value.origin=="http://localhost:18888" and .value.secure==true and .value.create=="function" and .value.get=="function"' <<<"$state" >/dev/null || {
 echo 'Original browser secure-origin WebAuthn API unavailable' >&2; jq -c '.value' <<<"$state" >&2; exit 1
}
# Source-matched physical USB transport diagnostic without a real device.
# Independently assert browser prefs in the original Chrome service, then
# click real WebAuthn registration. No virtual authenticator may be created.
if [[ "$mode" == usb-no-device || "$mode" == usb-dlopen-trace ]]; then
  # The normal / route is source-matched cross-platform WebAuthn registration;
  # with these original runtime prefs authrs_bridge takes usb_token_manager.
  chrome_reply="$(api POST "/session/$session/moz/context" '{"context":"chrome"}')"
  jq -e '.value==null or .value=="chrome"' <<<"$chrome_reply" >/dev/null || {
    echo 'No privileged original browser pref verification' >&2; exit 1;
  }
  pref_js='const s=Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefBranch);return {usb:s.getBoolPref("security.webauth.webauthn_enable_usbtoken"),soft:s.getBoolPref("security.webauth.webauthn_enable_softtoken")};'
  prefs="$(api POST "/session/$session/execute/sync" "$(jq -nc --arg script "$pref_js" '{script:$script,args:[]}')")"
  restored="$(api POST "/session/$session/moz/context" '{"context":"content"}')"
  jq -e '.value==null or .value=="content"' <<<"$restored" >/dev/null
  jq -e '.value.usb==true and .value.soft==false' <<<"$prefs" >/dev/null || {
    echo 'Original browser USB backend not enabled as intended' >&2; exit 1;
  }
  browser_maps_udev(){
    local proc name maps
    for proc in /proc/[0-9]*/comm; do
      [[ -r "$proc" ]] || continue
      name="$(cat "$proc" 2>/dev/null || true)"
      [[ "$name" == vulpra || "$name" == vulpra-bin ]] || continue
      maps="${proc%/comm}/maps"
      [[ -r "$maps" ]] || continue
      grep -Fq 'libudev.so.1' "$maps" && return 0
    done
    return 1
  }
  preloaded=false
  if browser_maps_udev; then preloaded=true; fi
  # Opt-in independent Rust ELF residency witness for this no-device
  # original-browser workload. No effect on virtual or interposed modes.
  phase_maps=false
  if [[ "${VULPRA_M3_WEBAUTHN_MAP_PHASES:-0}" == 1 ]]; then
    [[ "$mode" == usb-no-device && -x /audit/on-demand-maps ]] || exit 2
    /audit/on-demand-maps usb-before /original /reports/m3-original-webauthn-usb-before-maps.json
    phase_maps=true
  fi
  found="$(api POST "/session/$session/element" '{"using":"css selector","value":"#create"}')"
  button_id="$(jq -er '.value."element-6066-11e4-a52e-4f735466cecf" // .value.ELEMENT' <<<"$found")"
  api POST "/session/$session/element/$button_id/click" '{}' | jq -e '.value==null' >/dev/null
  mapped_during=false
  phase_during_saved=false
  completed=false
  create_state=''
  # Source-pinned page requests a 10s WebAuthn timeout; the original short
  # poll budget can race its asynchronous NotAllowedError under LD_PRELOAD.
  # Expand only the opt-in provider-instrumented diagnostic, not other modes.
  request_poll_limit=65
  if [[ "$mode" == usb-dlopen-trace && -n "${VULPRA_M3_LIBUDEV_DLSYM_TRACE:-}" ]]; then
    request_poll_limit=150
  fi
  for ((poll_attempt=0; poll_attempt<request_poll_limit; poll_attempt++)); do
    if browser_maps_udev; then
      mapped_during=true
      if [[ "$phase_maps" == true && "$phase_during_saved" == false ]]; then
        # Never infer a transient mapping from a retrospective flag:
        # capture the backing filename while /proc/maps still shows libudev.
        if /audit/on-demand-maps usb-during /original /reports/m3-original-webauthn-usb-during-maps.json; then
          phase_during_saved=true
        fi
      fi
    fi
    create_state="$(api POST "/session/$session/execute/sync" '{"script":"return window.__vulpraResult.create;","args":[]}')"
    if jq -e '.value.state=="complete"' <<<"$create_state" >/dev/null 2>&1; then
      completed=true; break
    fi
    sleep 0.18
  done
  # Do not turn an absent key into a successful WebAuthn credential assertion;
  # a no-device NotAllowedError is the expected bounded negative result.
  if [[ "$completed" != true ]] || ! jq -e '.value.ok==false and .value.error=="NotAllowedError"' <<<"$create_state" >/dev/null; then
    echo 'Original USB no-device request did not terminate with expected NotAllowedError' >&2
    jq -c '.value|{state,ok,error}' <<<"$create_state" >&2 || true
    exit 1
  fi
  if browser_maps_udev; then mapped_during=true; fi
  if [[ "$phase_maps" == true ]]; then
    [[ "$phase_during_saved" == true ]] || {
      echo 'No independent original libudev mapping during USB attempt' >&2
      exit 1
    }
    /audit/on-demand-maps usb-after /original /reports/m3-original-webauthn-usb-after-maps.json
  fi
  callsites_verified=false
  stack_verified=false
  if [[ "$mode" == usb-dlopen-trace ]]; then
    trace_path="$VULPRA_M3_LIBUDEV_DLOPEN_TRACE"
    [[ -f "$trace_path" ]] || { echo 'Original libxul produced no interposed dlopen trace' >&2; exit 1; }
    # The interposer has already filtered to libudev.so.1, caller ELF libxul.so,
    # and moved the return PCs relative to that original ELF's ASLR base.
    # Require one PID to have both exact source-pinned machine callsites:
    # 0x993664f -> return PC 0x9936652, NOLOAD miss with 0x105;
    # 0x9936664 -> return PC 0x9936667, normal dlopen hit with 0x101.
    if ! awk -F '\t' '
      NF!=4 {exit 4}
      $1!~/^[0-9]+$/ {exit 5}
      $2=="0x9936652" && $3=="0x105" && $4=="miss" {first[$1]=1}
      $2=="0x9936667" && $3=="0x101" && $4=="hit" {second[$1]=1}
      END {for (pid in first) if (second[pid]) found=1; if(!found) exit 6}
    ' "$trace_path"; then
      echo 'Original pinned libxul callsite/flags/outcome did not reconcile' >&2
      # Never print the unsanitized trace; it contains transient PIDs.
      exit 1
    fi
    [[ "$mapped_during" == true && "$preloaded" == false ]] || {
      echo 'Instrumentation did not reproduce the uninstrumented libudev mapping transition' >&2; exit 1;
    }
    callsites_verified=true
  fi

  # Optional independent bounded unwind. Keep old 4-column trace unchanged;
  # never upload transient-PID traces or claim a full uninstrumented stack.
  if [[ -n "${VULPRA_M3_LIBUDEV_DLOPEN_STACK:-}" ]]; then
    [[ "$mode" == usb-dlopen-trace && "$VULPRA_M3_LIBUDEV_DLOPEN_STACK" == /tmp/vulpra-m3-libudev-dlopen.stack ]] || exit 2
    [[ -f "$VULPRA_M3_LIBUDEV_DLOPEN_STACK" ]] || { echo 'No bounded original libxul stack evidence' >&2; exit 1; }
    if ! awk -F '\t' '
      {
        if (NF<5 || $1!~/^[0-9]+$/ || $2!~/^0x[0-9a-f]+$/ ||
            $3!~/^[0-9]+$/ || $3<2 || $3>12 || NF!=3+$3 || $4!=$2) {bad=1;exit}
        for (i=4;i<=NF;i++) if ($i!~/^0x[0-9a-f]+$/) {bad=1;exit}
        if ($2=="0x9936652") first[$1]=1
        if ($2=="0x9936667") second[$1]=1
      }
      END {if (bad) exit 6; for (pid in first) if (second[pid]) found=1; if (!found) exit 7}
    ' "$VULPRA_M3_LIBUDEV_DLOPEN_STACK"; then
      echo 'Original source-pinned libxul unwind is absent, truncated or mismatched' >&2
      exit 1
    fi
    stack_verified=true
  fi
  status="original_browser_usb_backend_no_device_negative_probe"
  if [[ "$mode" == usb-dlopen-trace ]]; then status="original_browser_usb_libudev_interposed_callsite_verified"; fi
  jq -n --argjson initial "$preloaded" --argjson mapped "$mapped_during" \
    --argjson verified "$callsites_verified" --argjson stack "$stack_verified" --arg status "$status" '{

    schema_version:1,
    status:$status,
    original_source_commit:"b1482404dfb8b01342990ee99ea3df0f9756b5f7",
    original_archive_sha256:"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a",
    original_native_browser_executed:true,
    real_browser_usbtoken_pref:true,
    real_browser_softtoken_pref:false,
    real_original_web_authn_create_called_from_user_click:true,
    virtual_authenticator_registered:false,
    physical_usb_device_passthrough:false,
    credential_create_result:"NotAllowedError",
    libudev_mapped_before_attempt:$initial,
    libudev_mapped_during_or_after_attempt:$mapped,
    instrumented_dlopen_symbol_interposition:$verified,
    source_pinned_libxul_noload_miss_at_return_pc_0x9936652:$verified,
    source_pinned_libxul_normal_load_hit_at_return_pc_0x9936667:$verified,
    exact_two_machine_callsite_and_flags_outcomes_reconciled:$verified,
    bounded_instrumented_libxul_unwind_two_or_more_frames:$stack,
    full_uninstrumented_browser_stack_observed:false,
    original_browser_uninstrumented_control_ci:41371647131,
    actual_original_dlopen_call_stack_observed:false,
    original_browser_libudev_runtime_dependency_proven:false,
    source_pruning_authorized:false,
    whole_dynamic_loader_graph_proven:false,
    physical_security_key_authentication_verified:false,
    real_user_profile_or_browser_accessed:false,
    network_egress_allowed:false,
    m3_sixth_gate_closed:false
  }' >"$report"
  # Run the optional dlsym provider check inside THIS already-unprivileged
  # process, before cleanup removes temporary PID-bearing raw traces. The
  # outer Docker launcher uses exec setpriv and cannot do postprocess work.
  if [[ "$mode" == usb-dlopen-trace && -n "${VULPRA_M3_LIBUDEV_DLSYM_TRACE:-}" ]]; then
    [[ -r /audit/dlsym-verify.sh ]] || { echo 'Missing bounded provider verifier' >&2; exit 2; }
    /bin/bash /audit/dlsym-verify.sh "$report"
  fi
  echo "PASS: original browser USB backend no-device attempt recorded; libudev mapping observed=$mapped_during (not a completed USB authenticator)"
  exit 0
fi
auth="$(api POST "/session/$session/webauthn/authenticator" '{"protocol":"ctap2_1","transport":"internal","hasResidentKey":true,"hasUserVerification":true,"isUserConsenting":true,"isUserVerified":true}')"
authid="$(jq -er '.value|select(type=="string" and length>0)' <<<"$auth")" || {
 echo 'Virtual authenticator was not accepted' >&2
 jq -c '{error:.value.error,message:(.value.message|tostring|.[0:150])}' <<<"$auth" >&2; exit 1
}
# Probe the ACTUAL original browser's internal virtual-authenticator DB.
# A driver HTTP 200 alone does not prove its Gecko service registered a key.
chrome_reply="$(api POST "/session/$session/moz/context" '{"context":"chrome"}')"
jq -e '.value==null or .value=="chrome"' <<<"$chrome_reply" >/dev/null || {
 echo 'Marionette privileged WebAuthn context unavailable' >&2
 jq -c '{error:.value.error,message:(.value.message|tostring|.[0:150]),context:.value}' <<<"$chrome_reply" >&2
 exit 1
}
auth_js='const s=Components.classes["@mozilla.org/webauthn/service;1"].getService(Components.interfaces.nsIWebAuthnService);return s.hasVirtualAuthenticator(arguments[0]);'
registered="$(api POST "/session/$session/execute/sync" \
 "$(jq -nc --arg script "$auth_js" --arg authid "$authid" '{script:$script,args:[$authid]}')")"
content_reply="$(api POST "/session/$session/moz/context" '{"context":"content"}')"
jq -e '.value==null or .value=="content"' <<<"$content_reply" >/dev/null || {
 echo 'Marionette original browser content context restore failed' >&2; exit 1;
}
jq -e '.value==true' <<<"$registered" >/dev/null || {
 echo 'Virtual authenticator absent from original Gecko nsIWebAuthnService' >&2
 jq -c '{error:.value.error,message:(.value.message|tostring|.[0:140]),result:.value}' <<<"$registered" >&2; exit 1;
}
# WebDriver element click is a genuine browser input event and carries user
# activation, unlike a bare execute/async WebAuthn call in a script context.
click_button(){
 local selector="$1" found element_id
 found="$(api POST "/session/$session/element" "$(jq -nc --arg css "$selector" '{using:"css selector",value:$css}')")"
 element_id="$(jq -er '.value."element-6066-11e4-a52e-4f735466cecf" // .value.ELEMENT' <<<"$found")" || {
   echo 'Original browser clickable WebAuthn element missing' >&2; exit 1;
 }
 api POST "/session/$session/element/$element_id/click" '{}' | jq -e '.value==null' >/dev/null
}
poll_result(){
 local which="$1" response
 for _ in {1..55}; do
   response="$(api POST "/session/$session/execute/sync" \
     "$(jq -nc --arg script "return window.__vulpraResult.$which;" '{script:$script,args:[]}')")"
   if jq -e '.value.state=="complete"' <<<"$response" >/dev/null 2>&1; then
     printf '%s\n' "$response"; return 0
   fi
   sleep 0.35
 done
 echo 'Original browser WebAuthn click result timed out' >&2; return 1
}
click_button '#create'
created="$(poll_result create)"
jq -e '.value.state=="complete" and .value.ok==true and .value.type=="public-key" and .value.size>0' <<<"$created" >/dev/null || {
 echo 'Original browser click WebAuthn registration failed' >&2
 jq -c '.value|{ok,error}' <<<"$created" >&2; exit 1
}
# Require a real virtual device credential. Never log the credential/private bytes.
credentials="$(curl --noproxy '*' -sS --max-time 20 "$base/session/$session/webauthn/authenticator/$authid/credentials")"
jq -e '.value|type=="array" and length>=1' <<<"$credentials" >/dev/null || {
 echo 'Browser-created key not stored on WebDriver virtual authenticator' >&2; exit 1
}
click_button '#get'
assertion="$(poll_result get)"
jq -e '.value.state=="complete" and .value.ok==true and .value.type=="public-key" and .value.data>0 and .value.sig>0' <<<"$assertion" >/dev/null || {
 echo 'Original browser click WebAuthn assertion failed' >&2
 jq -c '.value|{ok,error}' <<<"$assertion" >&2; exit 1
}
libudev=false; browser_count=0
for proc in /proc/[0-9]*/comm; do
 [[ -r "$proc" ]] || continue
 name="$(cat "$proc" 2>/dev/null || true)"
 [[ "$name" == vulpra || "$name" == vulpra-bin ]] || continue
 maps="$(dirname "$proc")/maps"
 [[ -r "$maps" ]] || continue
 browser_count=$((browser_count+1))
 if grep -Fq libudev.so.1 "$maps"; then libudev=true; fi
done
[[ "$browser_count" -gt 0 ]] || { echo 'Original browser native process not observed' >&2; exit 1; }
jq -n --argjson libudev "$libudev" '{
schema_version:1,status:"original_browser_real_webauthn_virtual_internal_create_get",
original_source_commit:"b1482404dfb8b01342990ee99ea3df0f9756b5f7",
original_archive_sha256:"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a",
original_native_browser_executed:true,localhost_secure_origin:true,
actual_browser_navigator_credentials_create_succeeded:true,
actual_browser_navigator_credentials_get_succeeded:true,
virtual_ctap2_internal_authenticator_used:true,virtual_credential_is_ephemeral:true,
user_usb_hardware_or_authenticator_accessed:false,
original_browser_libudev_mapped_at_end:$libudev,
original_browser_dynamic_libudev_load_proven:false,
actual_physical_usb_webauthn_path_verified:false,no_network_egress:true,
real_user_profile_or_browser_accessed:false,user_endeavouros_hyprland_verified:false,
full_dynamic_loader_graph_proven:false,source_pruning_authorized:false,
m3_sixth_gate_closed:false
}' >"$report"
echo 'PASS: original native browser virtual internal WebAuthn create/get offline'
