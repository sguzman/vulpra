#!/usr/bin/env bash
# Isolated, no-network original Vulpra WebAudio -> PulseAudio null sink.
set -euo pipefail
probe_stage='preflight'
trap 'printf "Original Pulse probe failed at stage=%s line=%s\n" "$probe_stage" "$LINENO" >&2' ERR
[[ $# -eq 3 ]] || exit 2
browser="$(realpath -e "$1")"; origin="$(realpath -e "$2")"; report="$3"
[[ -x "$browser" && -x "$origin" && "$(basename "$browser")" == vulpra ]] || exit 2
[[ "$MOZ_DISABLE_NONLOCAL_CONNECTIONS" == 1 && "$VULPRA_OFFLINE_CONTAINER_ONLY" == 1 && "$VULPRA_M3_NO_AUDIO_DEVICE" == 1 ]] || exit 2
[[ "$(awk '/^CapEff:/ {print $2}' /proc/self/status)" == 0000000000000000 ]] || exit 2
work="$(mktemp -d /tmp/vulpra-pulse.XXXXXX)"
export HOME="$work/home" XDG_DATA_HOME="$work/data" XDG_RUNTIME_DIR="$work/runtime"
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
export WAYLAND_DISPLAY=wayland-vulpra-pulse XDG_SESSION_TYPE=wayland GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1
export MOZ_CRASHREPORTER_DISABLE=1 XRE_START_OFFLINE=1
unset MOZ_HEADLESS DISPLAY
mkdir -m 0700 "$HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
weston_pid='' pulse_pid='' origin_pid='' driver_pid='' session=''
base=http://127.0.0.1:4444
api(){ curl --noproxy '*' -sS --max-time 20 -H 'Content-Type: application/json' -X "$1" -d "$3" "$base$2"; }
cleanup(){
  [[ -z "$session" ]] || api DELETE "/session/$session" '{}' >/dev/null 2>&1 || true
  for pid in "$driver_pid" "$origin_pid" "$pulse_pid" "$weston_pid"; do [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; done
  for pid in "$driver_pid" "$origin_pid" "$pulse_pid" "$weston_pid"; do [[ -z "$pid" ]] || wait "$pid" 2>/dev/null || true; done
  rm -rf -- "$work"
}
trap cleanup EXIT
probe_stage='private-weston'
weston --backend=headless-backend.so --renderer=pixman --idle-time=0 \
  --socket="$WAYLAND_DISPLAY" --log="$work/weston.log" >"$work/weston.out" 2>&1 &
weston_pid=$!
for _ in {1..40}; do [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break; kill -0 "$weston_pid"; sleep 0.25; done
[[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] || exit 1
wayland-info | grep -Fq xdg_wm_base
probe_stage='private-pulse'
pulseaudio -n --daemonize=no --exit-idle-time=-1 --log-level=error \
  --load=module-native-protocol-unix --load='module-null-sink sink_name=vulpra_m3_null' \
  >"$work/pulse.log" 2>&1 &
pulse_pid=$!
ready=false
for _ in {1..50}; do
 if pactl info >/dev/null 2>&1 && pactl list short sinks | grep -Fq vulpra_m3_null; then ready=true; break; fi
 kill -0 "$pulse_pid" || exit 1; sleep 0.2
done
[[ "$ready" == true && -z "$(pactl list short sink-inputs)" ]] || exit 1
probe_stage='browser-startup'
"$origin" vulpra-original-pulse-offline >"$work/origin.log" 2>&1 & origin_pid=$!
geckodriver --host 127.0.0.1 --port 4444 --log error >"$work/driver.log" 2>&1 & driver_pid=$!
ready=false
for _ in {1..45}; do
 if curl --noproxy '*' -s --max-time 1 "$base/status" | jq -e '.value.ready==true' >/dev/null 2>&1 &&
    curl --noproxy '*' -s --max-time 1 http://127.0.0.1:18889/ | grep -Fq 'Vulpra Pulse QA'; then ready=true; break; fi
 kill -0 "$driver_pid" || exit 1; sleep 0.4
done
[[ "$ready" == true ]] || exit 1
probe_stage='webdriver-session'
caps="$(jq -nc --arg bin "$browser" '{capabilities:{alwaysMatch:{browserName:"firefox","moz:firefoxOptions":{binary:$bin,args:[],prefs:{"media.autoplay.default":0}}}}}')"
reply="$(api POST /session "$caps")"
session="$(jq -er '.value.sessionId // .sessionId' <<<"$reply")" || exit 1
api POST "/session/$session/url" '{"url":"http://localhost:18889/"}' | jq -e '.value==null' >/dev/null
audio="$(api POST "/session/$session/execute/sync" '{"script":"return {origin:location.origin,secure:isSecureContext,audio:typeof AudioContext};","args":[]}')"
jq -e '.value.origin=="http://localhost:18889" and .value.secure==true and .value.audio=="function"' <<<"$audio" >/dev/null
pulse_mapped(){
 for proc in /proc/[0-9]*/comm; do
  [[ -r "$proc" ]] || continue
  name="$(cat "$proc" 2>/dev/null || true)"
  [[ "$name" == vulpra || "$name" == vulpra-bin ]] || continue
  [[ -r "$(dirname "$proc")/maps" ]] || continue
  grep -Fq libpulse.so.0 "$(dirname "$proc")/maps" && return 0
 done
 return 1
}
pre=false; pulse_mapped && pre=true
probe_stage='clicked-webaudio'
button="$(api POST "/session/$session/element" '{"using":"css selector","value":"#play"}')"
button_id="$(jq -er '.value."element-6066-11e4-a52e-4f735466cecf" // .value.ELEMENT' <<<"$button")"
api POST "/session/$session/element/$button_id/click" '{}' | jq -e '.value==null' >/dev/null
sink=false; mapped=false; running=false
for _ in {1..60}; do
 [[ -n "$(pactl list short sink-inputs)" ]] && sink=true
 pulse_mapped && mapped=true
 if [[ "$running" == false ]]; then
  audio="$(api POST "/session/$session/execute/sync" '{"script":"return window.__vulpraPulse;","args":[]}')"
  jq -e '.value.phase=="running" and .value.ok==true and .value.state=="running"' <<<"$audio" >/dev/null 2>&1 && running=true
  jq -e '.value.phase=="failed"' <<<"$audio" >/dev/null 2>&1 && { echo 'WebAudio failed' >&2; exit 1; }
 fi
 [[ "$sink" == true && "$mapped" == true && "$running" == true ]] && break
 sleep 0.15
done
[[ "$sink" == true && "$mapped" == true && "$running" == true ]] || { echo "Audio witness missing: $sink $mapped $running" >&2; exit 1; }
probe_stage='native-backend-about-support'
echo 'Pulse stream, mapping and browser WebAudio confirmed; querying native backend' >&2
# Read the native cubeb backend ID via the *original* about:support media
# diagnostics pipeline. This is actual browser state, not a source guess.
support_reply="$(api POST "/session/$session/url" '{"url":"about:support"}')"
if ! jq -e '.value==null' <<<"$support_reply" >/dev/null; then
  jq -r '.value.error // "unexpected about:support navigation response"' <<<"$support_reply" >&2
  exit 1
fi
probe_stage='native-backend-row'
backend=''
for _ in {1..60}; do
  result="$(api POST "/session/$session/execute/sync" '{"script":"const row=[...document.querySelectorAll(\"#media-info-tbody tr\")].find(r=>r.querySelector(\"th\")?.getAttribute(\"data-l10n-id\")===\"audio-backend\");return {uri:document.documentURI,backend:row?.querySelector(\"td\")?.textContent?.trim()||null};","args":[]}' )"
  if jq -e '.value.uri=="about:support"' <<<"$result" >/dev/null 2>&1; then
    backend="$(jq -er '.value.backend // empty' <<<"$result" 2>/dev/null || true)"
    [[ "$backend" =~ ^[a-z][a-z0-9-]{1,31}$ ]] && break
  fi
  sleep 0.25
done
[[ "$backend" =~ ^[a-z][a-z0-9-]{1,31}$ ]] || {
  echo 'Native about:support cubeb backend ID was not available' >&2
  exit 1
}
echo "Original browser native cubeb backend=$backend" >&2
is_rust=false
[[ "$backend" == pulse-rust ]] && is_rust=true
jq -n --argjson pre "$pre" --arg backend "$backend" --argjson rust "$is_rust" '{
schema_version:1,status:"original_browser_webaudio_pulse_null_sink_stream_verified",
source_commit:"b1482404dfb8b01342990ee99ea3df0f9756b5f7",
archive_sha256:"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a",
original_native_browser_executed:true,real_user_click_audio_context_running:true,
pulse_null_sink_created:true,pulse_sink_had_no_inputs_before_browser_audio:true,
pulse_sink_input_observed_during_browser_audio:true,libpulse_mapped_before_click:$pre,
libpulse_mapped_during_audio:true,reported_cubeb_backend:$backend,
reported_cubeb_backend_is_pulse_rust:$rust,
compiled_rust_pulse_callsite_proven:false,
physical_audio_or_microphone_used:false,network_egress_allowed:false,
target_endeavouros_verified:false,source_pruning_authorized:false,m3_sixth_gate_closed:false
}' >"$report"
echo 'PASS: original browser generated audio stream in disposable PulseAudio null sink'
