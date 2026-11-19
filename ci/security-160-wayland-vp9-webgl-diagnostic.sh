#!/usr/bin/env bash
# Firefox 160-specific reproducible WebGL availability diagnosis.
# Feature-triggered real packaged Vulpra VP9/video and canvas on private Weston
# (non-headless Wayland), with isolated baseline, GBM/DRM and VA-API load denial.
# A video or WebGL result does not identify hardware decode or DMA-BUF fallback.
# Uses source-verified test-only package; no user profiles or system lib edits.
set -euo pipefail
make_clip() {
  ffmpeg -nostdin -hide_banner -loglevel error -y \
    -f lavfi -i testsrc2=size=192x108:rate=15 -t 4 \
    -an -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -b:v 450k \
    -pix_fmt yuv420p -f webm "$1"
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=codec_name,width,height,pix_fmt -of json "$1" |
    jq -e '(.streams|length)==1 and
      .streams[0].codec_name=="vp9" and .streams[0].width==192 and
      .streams[0].height==108 and .streams[0].pix_fmt=="yuv420p"' >/dev/null
  test "$(stat -c %s "$1")" -gt 3000
  test "$(stat -c %s "$1")" -lt 800000
}
make_watch_page() {
  cat > "$1" <<'HTML'
<!doctype html><meta charset="utf-8"><title>Local VP9/WebM video</title>
<video id="v" muted autoplay playsinline preload="auto" src="/vp9.webm"></video>
<script>
document.getElementById("v").play().catch(e=>{
document.documentElement.dataset.playRejected=e.name;
});
</script>
HTML
}
# Check the actual page generated for the runtime and ensure its video
# points to the generated WebM fixture, not a nonexistent MP4.
check_watch_page() {
  local dir="$1" src
  test -s "$dir/watch.html" && test -s "$dir/vp9.webm"
  src="$(sed -n 's/.*<video id="v"[^>]*src="\([^"]*\)".*/\1/p' "$dir/watch.html")"
  test "$src" = /vp9.webm
  test -s "$dir/${src#/}"
}
if test "$#" -eq 1 && test "$1" = "--self-test"; then
  tmp="$(mktemp -d)"; trap 'rm -rf -- "$tmp"' EXIT
  mkdir -p "$tmp/www"
  make_clip "$tmp/www/vp9.webm"
  make_watch_page "$tmp/www/watch.html"
  check_watch_page "$tmp/www"
  echo "PASS: real bounded VP9/WebM fixture and matching playable HTML source"
  exit 0
fi
if test "$#" -ne 4; then
  echo "usage: $0 REPO DENIAL_SHIM_SO GECKODRIVER REPORT_JSON" >&2
  exit 2
fi
repo="$1"; shim="$2"; gecko="$3"; output="$4"
test "$repo" = "$GITHUB_WORKSPACE"
test "$(git -C "$repo" rev-parse HEAD)" = "$GITHUB_SHA"
# A replay may run a newer test harness against a previously compiled,
# source-pinned package. Keep both identities distinct in its evidence.
compiled_source="${VULPRA_M3_COMPILED_SOURCE_SHA:-$GITHUB_SHA}"
[[ "$compiled_source" =~ ^[0-9a-f]{40}$ ]]
test "$output" = "$RUNNER_TEMP/m3-packaged-wayland-vp9-providers.json"
test ! -e "$output"
test -s "$shim" && test ! -L "$shim"
test -x "$gecko"
archive="$repo/.git/vulpra-native-build/packages/vulpra-local-m3-native-link-ci.tar.xz"
test -s "$archive" && test -s "$archive.sha256"
(cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256") >/dev/null
archive_sha="$(sha256sum "$archive" | cut -d' ' -f1)"
tmp="$(mktemp -d "$RUNNER_TEMP/vulpra-wayland-vp9.XXXXXXXX")"
driver_pid=""; server_pid=""; weston_pid=""; session=""; port=""
stop_driver() {
  if test -n "$session"; then
    curl -sf --max-time 5 -X DELETE "http://127.0.0.1:$port/session/$session" >/dev/null || true
  fi
  if test -n "$driver_pid"; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  session=""; driver_pid=""; port=""
}
cleanup() {
  stop_driver
  if test -n "$server_pid"; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if test -n "$weston_pid"; then
    kill "$weston_pid" 2>/dev/null || true
    wait "$weston_pid" 2>/dev/null || true
  fi
  rm -rf -- "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/app" "$tmp/www" "$tmp/runtime"
chmod 0700 "$tmp/runtime"
tar -xf "$archive" -C "$tmp/app"
mapfile -t ini < <(find "$tmp/app" -type f -name application.ini -print)
test "${#ini[@]}" -eq 1
grep -Fxq 'Name=Vulpra' "${ini[0]}"
appdir="$(dirname "${ini[0]}")"
binary=""
for name in vulpra firefox; do
  if test -x "$appdir/$name" &&
    test "$(od -An -tx1 -N4 "$appdir/$name" | tr -d ' \n')" = 7f454c46; then
    binary="$appdir/$name"; break
  fi
done
test -n "$binary"
make_clip "$tmp/www/vp9.webm"
make_watch_page "$tmp/www/watch.html"
check_watch_page "$tmp/www"
new_port() {
  python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'
}
httpport="$(new_port)"
python3 -m http.server "$httpport" --bind 127.0.0.1 --directory "$tmp/www" > "$tmp/http.log" 2>&1 &
server_pid="$!"
ready=false
for _ in $(seq 1 65); do
  if curl -fsS --max-time 2 -o /dev/null "http://127.0.0.1:$httpport/watch.html" 2>/dev/null; then
    ready=true; break
  fi
  sleep 0.1
done
test "$ready" = true
# The server and its localhost requests run in the same disposable CI runner.
# Weston uses the software Pixman renderer; no GPU acceleration is assumed.
for cmd in weston wayland-info; do command -v "$cmd" >/dev/null; done
export XDG_RUNTIME_DIR="$tmp/runtime"
export WAYLAND_DISPLAY="wayland-vulpra-vp9"
unset DISPLAY MOZ_HEADLESS
weston --backend=headless-backend.so --renderer=pixman \
  --socket="$WAYLAND_DISPLAY" --idle-time=0 \
  --log="$tmp/weston.log" >"$tmp/weston-stdout.log" 2>&1 &
weston_pid="$!"
socket_ready=false
for _ in $(seq 1 80); do
  if test -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"; then socket_ready=true; break; fi
  kill -0 "$weston_pid" 2>/dev/null || break
  sleep 0.2
done
test "$socket_ready" = true
wayland-info >"$tmp/wayland-info.txt" 2>"$tmp/wayland-info.err"
grep -q 'wl_compositor' "$tmp/wayland-info.txt"
grep -q 'xdg_wm_base' "$tmp/wayland-info.txt"
wd() {
  local method="$1" route="$2" data=""
  if test "$#" -ge 3; then data="$3"; fi
  if test -n "$data"; then
    curl -fsS --max-time 45 -X "$method" -H 'Content-Type: application/json' \
      --data "$data" "http://127.0.0.1:$port$route"
  else
    curl -fsS --max-time 15 -X "$method" "http://127.0.0.1:$port$route"
  fi
}
js='const v=document.getElementById("v");if(!v)return {found:false};
const q=v.getVideoPlaybackQuality?.();
return {found:true,time:Number(v.currentTime.toFixed(3)),
frames:q?.totalVideoFrames??null,width:v.videoWidth,height:v.videoHeight,
error:v.error?.code??null,playRejected:document.documentElement.dataset.playRejected??null};'
js_body="$(jq -nc --arg script "$js" '{script:$script,args:[]}')"
graphics_js='const v=document.getElementById("v");
const c=document.createElement("canvas");c.width=8;c.height=8;
let canvas=false,webgl2=false,error=null;
try {const ctx=c.getContext("2d",{willReadFrequently:true});
  if(v&&v.readyState>=2){ctx.drawImage(v,0,0,8,8);
    const pixels=ctx.getImageData(0,0,8,8).data;canvas=pixels.length===256;}}
catch(e){error=e.name;}
let webglError=null;
try {
  const glCanvas=document.createElement("canvas");
  glCanvas.addEventListener("webglcontextcreationerror", e=>{
    webglError=String(e.statusMessage||"context-creation-error").slice(0,180);
  });
  const gl=glCanvas.getContext("webgl2");
  webgl2=!!gl;
  gl?.getExtension("WEBGL_lose_context")?.loseContext();
} catch(e) { webglError=String(e.name||"WebGL exception").slice(0,100); }
return {canvas_video_readback:canvas,webgl2_context_available:webgl2,
  webgl2_context_creation_error:webglError, graphics_error:error};'
graphics_body="$(jq -nc --arg script "$graphics_js" '{script:$script,args:[]}')"

: > "$tmp/modes.jsonl"
run_mode() {
  local mode="$1" home="$tmp/$1-home"
  mkdir -p "$home/.mozilla/firefox"
  echo 'test sentinel: preserve profile' > "$home/.mozilla/firefox/profiles.ini"
  local sentinel="$(sha256sum "$home/.mozilla/firefox/profiles.ini" | cut -d' ' -f1)"
  local log="$tmp/$mode-denial.log"
  : > "$log"; chmod 0600 "$log"
  port="$(new_port)"
  if test "$mode" != baseline; then
    env -u VULPRA_M3_DENY_FIXTURE_EXE \
      LD_PRELOAD="$shim" VULPRA_M3_DENY_GROUP="$mode" VULPRA_M3_DENY_LOG="$log" \
      HOME="$home" XDG_DATA_HOME="$home/.local/share" \
      GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1 XDG_SESSION_TYPE=wayland \
      MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
      NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost \
      "$gecko" --host 127.0.0.1 --port "$port" > "$tmp/$mode-geckodriver.log" 2>&1 &
  else
    env -u LD_PRELOAD -u VULPRA_M3_DENY_GROUP -u VULPRA_M3_DENY_LOG \
      HOME="$home" XDG_DATA_HOME="$home/.local/share" \
      GDK_BACKEND=wayland MOZ_ENABLE_WAYLAND=1 XDG_SESSION_TYPE=wayland \
      MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
      NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost \
      "$gecko" --host 127.0.0.1 --port "$port" > "$tmp/$mode-geckodriver.log" 2>&1 &
  fi
  driver_pid="$!"
  local driver_ready=false
  for _ in $(seq 1 150); do
    if curl -fsS --max-time 2 "http://127.0.0.1:$port/status" 2>/dev/null |
      jq -e '.value.ready==true' >/dev/null 2>&1; then
      driver_ready=true;break
    fi
    kill -0 "$driver_pid" 2>/dev/null || break
    sleep 0.2
  done
  test "$driver_ready" = true
  local caps
  caps="$(jq -nc --arg binary "$binary" '{
    capabilities:{alwaysMatch:{
      browserName:"firefox",acceptInsecureCerts:false,
      "moz:firefoxOptions":{binary:$binary,args:["-no-remote"],
      prefs:{"browser.shell.checkDefaultBrowser":false,"app.update.enabled":false,
      "extensions.update.enabled":false,"media.autoplay.default":0,
      "media.ffmpeg.vaapi.enabled":true,
      "media.hardware-video-decoding.enabled":true,
      "gfx.webrender.all":true}}}}
  }')"
  session="$(wd POST /session "$caps" |
    jq -er '.value.sessionId | select(type=="string" and length>0)')"
  local before after attached response state graphics screenshot_ok=false
  local video_ok=false media_error=false alive=false preserved=false
  graphics='{"canvas_video_readback":false,"webgl2_context_available":false,"graphics_error":"not_run"}'
  before="$(grep -Ec '^DENIED (dlopen|dlmopen) ' "$log" || true)"
  wd POST "/session/$session/url" \
    "$(jq -nc --arg url "http://127.0.0.1:$httpport/watch.html" '{url:$url}')" >/dev/null
  state='{"found":false}'
  for _ in $(seq 1 80); do
    if response="$(wd POST "/session/$session/execute/sync" "$js_body" 2>/dev/null)"; then
      state="$(jq -c '.value | select(type=="object")' <<< "$response" 2>/dev/null || echo '{"found":false}')"
      if jq -e '.found==true and .time>=0.35 and .width==192 and
        .height==108 and .frames!=null and .frames>=2' <<< "$state" >/dev/null 2>&1; then
        video_ok=true; break
      fi
      if jq -e '.found==true and .error!=null' <<< "$state" >/dev/null 2>&1; then
        media_error=true; break
      fi
    fi
    sleep 0.25
  done
  if response="$(wd POST "/session/$session/execute/sync" "$graphics_body" 2>/dev/null)"; then
    graphics="$(jq -c '.value | select(type=="object")' <<< "$response" 2>/dev/null || echo '{"canvas_video_readback":false,"webgl2_context_available":false,"graphics_error":"webdriver_error"}')"
  fi
  # One-shot WebGL2 failure is not conclusive. Record separate first result,
  # up to six delayed subsequent attempts, and the final context error.
  local webgl_first=false webgl_retries=0
  webgl_first="$(jq -r '.webgl2_context_available // false' <<< "$graphics")"
  if test "$webgl_first" != true; then
    for _ in $(seq 1 6); do
      sleep 0.7
      webgl_retries=$((webgl_retries+1))
      if response="$(wd POST "/session/$session/execute/sync" "$graphics_body" 2>/dev/null)"; then
        candidate="$(jq -c '.value | select(type=="object")' <<< "$response" 2>/dev/null || echo '{"canvas_video_readback":false,"webgl2_context_available":false,"graphics_error":"webdriver_error"}')"
        graphics="$candidate"
      fi
      if jq -e '.webgl2_context_available==true' <<< "$graphics" >/dev/null 2>&1; then
        break
      fi
    done
  fi
  if wd GET "/session/$session/screenshot" 2>/dev/null |
    jq -e '.value|type=="string" and startswith("iVBORw0KGgo") and length>256' >/dev/null 2>&1; then
    screenshot_ok=true
  fi
  after="$(grep -Ec '^DENIED (dlopen|dlmopen) ' "$log" || true)"
  attached="$(grep -c '^ATTACHED browser-process ' "$log" || true)"
  if wd GET /status >/dev/null 2>&1 &&
    wd GET "/session/$session/title" >/dev/null 2>&1; then alive=true; fi
  if test "$(sha256sum "$home/.mozilla/firefox/profiles.ini" | cut -d' ' -f1)" = "$sentinel"; then
    preserved=true
  fi
  jq -nc --arg mode "$mode" --argjson before "$before" --argjson after "$after" \
    --argjson attached "$attached" --argjson decoded "$video_ok" \
    --argjson error "$media_error" --argjson alive "$alive" \
    --argjson preserved "$preserved" --argjson state "$state" \
    --argjson graphics "$graphics" --argjson screenshot "$screenshot_ok" \
    --arg webgl_first "$webgl_first" --argjson webgl_retries "$webgl_retries" '{
    mode:$mode,actual_packaged_browser_session:true,
    browser_interposer_attached:($attached>0),
    ffmpeg_denials_before_video_navigation:$before,
    ffmpeg_denials_after_video_navigation:$after,
    new_denials_during_video_navigation:($after-$before),
    vp9_decoded_frames_and_time_verified:$decoded,
    actual_webdriver_png_screenshot:$screenshot,
    canvas_video_readback:($graphics.canvas_video_readback==true),
    webgl2_initial_context_available:($webgl_first=="true"),
    webgl2_context_available:($graphics.webgl2_context_available==true),
    webgl2_delayed_retry_attempts:$webgl_retries,
    observed_graphics_state:$graphics,
    media_error_observed:$error,
    webdriver_browser_responsive:$alive,
    isolated_profile_preserved:$preserved,
    observed_video_state:$state
  }' >> "$tmp/modes.jsonl"
  echo "AUDIT: $mode VP9_decoded=$video_ok media_error=$media_error provider_denied_before=$before after=$after screenshot=$screenshot_ok responsive=$alive webgl_initial=$webgl_first retries=$webgl_retries"
  stop_driver
}
run_mode baseline
run_mode gbm
run_mode vaapi
jq -s --arg source "$compiled_source" --arg harness "$GITHUB_SHA" \
  --arg archive "$archive_sha" '{
  schema_version:1,
  status:"real_packaged_non_headless_Wayland_VP9_video_canvas_provider_denial",
  native_source_commit:$source,
  test_harness_commit:$harness,
  verified_normal_packaged_archive_sha256:$archive,
  private_Weston_pixman_compositor_available:true,
  actual_GPU_or_DMABuf_provider_execution_proven:false,
  hardware_video_decoder_identified:false,
  complete_indirect_loader_graph_proven:false,
  restricted_to_disposable_localhost_media_probe:true,
  target_endeavouros_hyprland_verified:false,
  user_normal_profile_or_credentials_used:false,
  source_pruning_authorized:false,m3_sixth_gate_closed:false,release_ready:false,
  baseline_playback_verified:([.[]|select(.mode=="baseline")|.vp9_decoded_frames_and_time_verified][0]//false),
  all_real_browser_sessions_safe:(length==3 and
    ([.[].mode]|sort)==["baseline","gbm","vaapi"] and
    all(.[];.webdriver_browser_responsive and
      .isolated_profile_preserved and .actual_webdriver_png_screenshot)),
  gbm_video_playback_verified:([.[]|select(.mode=="gbm")|.vp9_decoded_frames_and_time_verified][0]//false),
  vaapi_video_playback_verified:([.[]|select(.mode=="vaapi")|.vp9_decoded_frames_and_time_verified][0]//false),
  modes:.
}' "$tmp/modes.jsonl" > "$output"
jq -e '
  .schema_version==1 and
  .baseline_playback_verified==true and
  .all_real_browser_sessions_safe==true and
  .hardware_video_decoder_identified==false and
  .actual_GPU_or_DMABuf_provider_execution_proven==false and
  .m3_sixth_gate_closed==false and .release_ready==false
' "$output" >/dev/null
echo "PASS: private Weston non-headless browser video, canvas, WebGL and selective provider observations recorded"
echo "LIMIT: no actual GPU/VA-API decoder fallback proven; absence of denied calls means selected path unexercised"
