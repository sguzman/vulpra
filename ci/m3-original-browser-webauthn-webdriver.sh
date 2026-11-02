#!/usr/bin/env bash
# CI-only original browser WebAuthn virtual CTAP2 USB create+get, offline.
set -euo pipefail
[[ $# -eq 3 ]] || exit 2
browser="$(realpath -e -- "$1")"
origin="$(realpath -e -- "$2")"
report="$3"
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
caps="$(jq -nc --arg bin "$browser" '{capabilities:{alwaysMatch:{browserName:"firefox",
 "moz:firefoxOptions":{binary:$bin,args:[],
 prefs:{"security.webauth.webauthn":true,"security.webauth.webauthn_enable_softtoken":true,
 "security.webauth.webauthn_enable_usbtoken":false,"security.webauthn.ctap2":true}}}}}')"
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
auth="$(api POST "/session/$session/webauthn/authenticator" '{"protocol":"ctap2_1","transport":"internal","hasResidentKey":true,"hasUserVerification":true,"isUserConsenting":true,"isUserVerified":true}')"
authid="$(jq -er '.value|select(type=="string" and length>0)' <<<"$auth")" || {
 echo 'Virtual authenticator was not accepted' >&2
 jq -c '{error:.value.error,message:(.value.message|tostring|.[0:150])}' <<<"$auth" >&2; exit 1
}
create_js='
const done=arguments[arguments.length-1];
navigator.credentials.create({publicKey:{
challenge:new Uint8Array(32).fill(7),rp:{id:"localhost",name:"Private QA"},
user:{id:new Uint8Array([1,2,3]),name:"disposable",displayName:"Disposable"},
pubKeyCredParams:[{type:"public-key",alg:-7}],timeout:10000,
authenticatorSelection:{authenticatorAttachment:"platform",userVerification:"discouraged"}
}}).then(c=>{window.__vulpraM3Cred=new Uint8Array(c.rawId);
done({ok:true,type:c.type,size:c.rawId.byteLength})})
.catch(e=>done({ok:false,error:e.name}));
'
created="$(api POST "/session/$session/execute/async" "$(jq -nc --arg script "$create_js" '{script:$script,args:[]}')")"
jq -e '.value.ok==true and .value.type=="public-key" and .value.size>0' <<<"$created" >/dev/null || {
 echo 'Actual browser WebAuthn create failed' >&2; jq -c '.value' <<<"$created" | head -c 300 >&2; exit 1
}
# Verify the created key lives in the WebDriver virtual authenticator,
# not merely a separate softtoken; never disclose credential or private bytes.
credentials="$(curl --noproxy '*' -sS --max-time 20 "$base/session/$session/webauthn/authenticator/$authid/credentials")"
jq -e '.value|type=="array" and length>=1' <<<"$credentials" >/dev/null || {
 echo 'Virtual authenticator did not contain the created browser credential' >&2; exit 1;
}
get_js='
const done=arguments[arguments.length-1],id=window.__vulpraM3Cred;
if(!(id instanceof Uint8Array)){done({ok:false,error:"NoCreatedCredential"});return;}
navigator.credentials.get({publicKey:{
challenge:new Uint8Array(32).fill(13),rpId:"localhost",timeout:10000,
allowCredentials:[{type:"public-key",id:id,transports:["internal"]}],userVerification:"discouraged"
}}).then(c=>done({ok:true,type:c.type,data:c.response.authenticatorData.byteLength,
sig:c.response.signature.byteLength}))
.catch(e=>done({ok:false,error:e.name}));
'
assertion="$(api POST "/session/$session/execute/async" "$(jq -nc --arg script "$get_js" '{script:$script,args:[]}')")"
jq -e '.value.ok==true and .value.type=="public-key" and .value.data>0 and .value.sig>0' <<<"$assertion" >/dev/null || {
 echo 'Actual browser WebAuthn get assertion failed' >&2; jq -c '.value' <<<"$assertion" | head -c 300 >&2; exit 1
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
schema_version:1,status:"original_browser_real_webauthn_virtual_usb_create_get",
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
