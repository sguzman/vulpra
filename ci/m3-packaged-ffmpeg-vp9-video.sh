#!/usr/bin/env bash
# Real packaged Vulpra VP9/WebM video decoding under baseline and denied FFmpeg.
# WebDriver requires *decoded video frames + advancing currentTime*.
# Disposable private profiles, generated localhost clip, no system lib edits.
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
if test "$#" -eq 1 && test "$1" = "--self-test"; then
  tmp="$(mktemp -d)"; trap 'rm -rf -- "$tmp"' EXIT
  make_clip "$tmp/test.webm"
  echo "PASS: generated real bounded four-second local VP9/WebM clip"
  exit 0
fi
if test "$#" -ne 4; then
  echo "usage: $0 REPO DENIAL_SHIM_SO GECKODRIVER REPORT_JSON" >&2
  exit 2
fi
repo="$1"; shim="$2"; gecko="$3"; output="$4"
test "$repo" = "$GITHUB_WORKSPACE"
test "$(git -C "$repo" rev-parse HEAD)" = "$GITHUB_SHA"
test "$output" = "$RUNNER_TEMP/m3-packaged-ffmpeg-vp9-video.json"
test ! -e "$output"
test -s "$shim" && test ! -L "$shim"
test -x "$gecko"
archive="$repo/.git/vulpra-native-build/packages/vulpra-local-m3-native-link-ci.tar.xz"
test -s "$archive" && test -s "$archive.sha256"
(cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256") >/dev/null
archive_sha="$(sha256sum "$archive" | cut -d' ' -f1)"
tmp="$(mktemp -d "$RUNNER_TEMP/vulpra-vp9.XXXXXXXX")"
driver_pid=""; server_pid=""; session=""; port=""
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
  rm -rf -- "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/app" "$tmp/www"
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
cat > "$tmp/www/watch.html" <<'HTML'
<!doctype html><meta charset="utf-8"><title>Local VP9/WebM video</title>
<video id="v" muted autoplay playsinline preload="auto" src="/vp9.mp4"></video>
<script>
document.getElementById("v").play().catch(e=>{
document.documentElement.dataset.playRejected=e.name;
});
</script>
HTML
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
: > "$tmp/modes.jsonl"
run_mode() {
  local mode="$1" home="$tmp/$1-home"
  mkdir -p "$home/.mozilla/firefox"
  echo 'test sentinel: preserve profile' > "$home/.mozilla/firefox/profiles.ini"
  local sentinel="$(sha256sum "$home/.mozilla/firefox/profiles.ini" | cut -d' ' -f1)"
  local log="$tmp/$mode-denial.log"
  : > "$log"; chmod 0600 "$log"
  port="$(new_port)"
  if test "$mode" = denied; then
    env -u VULPRA_M3_DENY_FIXTURE_EXE \
      LD_PRELOAD="$shim" VULPRA_M3_DENY_GROUP=ffmpeg VULPRA_M3_DENY_LOG="$log" \
      HOME="$home" XDG_DATA_HOME="$home/.local/share" MOZ_HEADLESS=1 \
      NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost \
      "$gecko" --host 127.0.0.1 --port "$port" > "$tmp/$mode-geckodriver.log" 2>&1 &
  else
    env -u LD_PRELOAD -u VULPRA_M3_DENY_GROUP -u VULPRA_M3_DENY_LOG \
      HOME="$home" XDG_DATA_HOME="$home/.local/share" MOZ_HEADLESS=1 \
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
      "moz:firefoxOptions":{binary:$binary,args:["-headless","-no-remote"],
      prefs:{"browser.shell.checkDefaultBrowser":false,"app.update.enabled":false,
      "extensions.update.enabled":false,"media.autoplay.default":0}}}}
  }')"
  session="$(wd POST /session "$caps" |
    jq -er '.value.sessionId | select(type=="string" and length>0)')"
  local before after attached response state video_ok=false media_error=false alive=false preserved=false
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
    --argjson preserved "$preserved" --argjson state "$state" '{
    mode:$mode,actual_packaged_browser_session:true,
    browser_interposer_attached:($attached>0),
    ffmpeg_denials_before_video_navigation:$before,
    ffmpeg_denials_after_video_navigation:$after,
    new_denials_during_video_navigation:($after-$before),
    vp9_decoded_frames_and_time_verified:$decoded,
    media_error_observed:$error,
    webdriver_browser_responsive:$alive,
    isolated_profile_preserved:$preserved,
    observed_video_state:$state
  }' >> "$tmp/modes.jsonl"
  echo "AUDIT: $mode VP9_decoded=$video_ok media_error=$media_error FFmpeg_denied_before=$before denied_after=$after responsive=$alive"
  stop_driver
}
run_mode baseline
run_mode denied
jq -s --arg source "$GITHUB_SHA" --arg archive "$archive_sha" '{
  schema_version:1,status:"real_packaged_VP9_WebDriver_video_decode_with_FFmpeg_denial",
  source_commit:$source,normal_packaged_archive_sha256:$archive,
  fixture_VP9_codec_validated:true,
  real_browser_decoded_frames_and_time_measured:true,
  baseline_VP9_playback_passed:([.[]|select(.mode=="baseline")|.vp9_decoded_frames_and_time_verified][0]//false),
  denied_VP9_playback_passed:([.[]|select(.mode=="denied")|.vp9_decoded_frames_and_time_verified][0]//false),
  denied_VP9_media_error_observed:([.[]|select(.mode=="denied")|.media_error_observed][0]//false),
  denied_FFmpeg_loader_attempts:([.[]|select(.mode=="denied")|.ffmpeg_denials_after_video_navigation][0]//0),
  denial_attempts_after_video_navigation:([.[]|select(.mode=="denied")|.new_denials_during_video_navigation][0]//0),
  exact_source_private_webdriver_modes_safe:(
    length==2 and (map(.mode)|sort)==["baseline","denied"] and
    all(.[];.webdriver_browser_responsive and .isolated_profile_preserved)),
  VP9_playback_with_FFmpeg_denied_demonstrated:(
    [.[]|select(.mode=="denied")|.vp9_decoded_frames_and_time_verified][0]//false),
  real_denied_FFmpeg_attempt_observed:(
    [.[]|select(.mode=="denied")|(.browser_interposer_attached and .ffmpeg_denials_after_video_navigation>0)][0]//false),
  specific_VP9_decoder_implementation_identified:false,
  alternative_H264_software_decoder_fallback_proven:false,
  VAAPI_Wayland_DMABuf_runtime_fallback_proven:false,
  complete_indirect_dynamic_loader_graph_closed:false,
  tested_only_temporary_headless_localhost_playback:true,
  source_pruning_authorized:false,m3_sixth_gate_closed:false,release_ready:false,
  modes:.
}' "$tmp/modes.jsonl" > "$output"
jq -e '
  .schema_version==1 and .fixture_VP9_codec_validated==true and
  .baseline_VP9_playback_passed==true and
  .exact_source_private_webdriver_modes_safe==true and
  .real_denied_FFmpeg_attempt_observed==true and
  .specific_VP9_decoder_implementation_identified==false and
  .alternative_H264_software_decoder_fallback_proven==false and
  .m3_sixth_gate_closed==false and .source_pruning_authorized==false
' "$output" >/dev/null
echo "PASS: actual packaged browser VP9/WebM baseline decoded frames; FFmpeg-denied media outcome recorded"
echo "LIMIT: denial may cause VP9/WebM error; software decoder fallback, VAAPI, DMABuf and full closure unproven"
