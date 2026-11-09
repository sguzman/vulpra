#!/usr/bin/env bash
# Passive prerequisites for target EndeavourOS/Hyprland GPU acceptance.
# Never open render devices, invoke GPU APIs, install, elevate or change files.
set -euo pipefail
if [[ $# -ne 1 || ( "$1" != "--inspect" && "$1" != "--self-test" ) ]]; then
  echo "usage: bash ci/m3-arch-wayland-gpu-readiness.sh --inspect|--self-test" >&2
  exit 2
fi
command -v jq >/dev/null || { echo "jq is required to emit bounded JSON" >&2; exit 2; }

has_command() {
  if command -v "$1" >/dev/null 2>&1; then printf true; else printf false; fi
}
has_package() {
  if command -v pacman >/dev/null 2>&1 && pacman -Qq "$1" >/dev/null 2>&1; then
    printf true
  else
    printf false
  fi
}

inspect() {
  local linux=false x86_64=false session="other"
  [[ "$(uname -s)" == Linux ]] && linux=true
  [[ "$(uname -m)" == x86_64 ]] && x86_64=true
  case "$(printenv XDG_SESSION_TYPE 2>/dev/null || true)" in
    wayland|x11) session="$(printenv XDG_SESSION_TYPE)" ;;
    "") session="unset" ;;
    *) session="other" ;;
  esac
  local wayland_env=false hyprland_env=false
  [[ -n "$(printenv WAYLAND_DISPLAY 2>/dev/null || true)" ]] && wayland_env=true
  [[ -n "$(printenv HYPRLAND_INSTANCE_SIGNATURE 2>/dev/null || true)" ]] && hyprland_env=true

  local render_count=0 readable_count=0 writable_count=0
  local nvidia_count=0 other_count=0
  local node base vendor
  shopt -s nullglob
  for node in /dev/dri/renderD*; do
    [[ -c "$node" ]] || continue
    render_count=$((render_count+1))
    [[ -r "$node" ]] && readable_count=$((readable_count+1))
    [[ -w "$node" ]] && writable_count=$((writable_count+1))
    base="$(basename "$node")"
    vendor=""
    if [[ -r "/sys/class/drm/$base/device/vendor" ]]; then
      IFS= read -r vendor < "/sys/class/drm/$base/device/vendor" || true
    fi
    if [[ "$vendor" == "0x10de" ]]; then
      nvidia_count=$((nvidia_count+1))
    else
      other_count=$((other_count+1))
    fi
  done

  jq -n \
    --arg session "$session" \
    --argjson linux "$linux" \
    --argjson x86_64 "$x86_64" \
    --argjson wayland "$wayland_env" \
    --argjson hyprland "$hyprland_env" \
    --argjson render "$render_count" \
    --argjson readable "$readable_count" \
    --argjson writable "$writable_count" \
    --argjson nvidia "$nvidia_count" \
    --argjson other "$other_count" \
    --argjson pacman "$(has_command pacman)" \
    --argjson nvidia_smi "$(has_command nvidia-smi)" \
    --argjson vainfo "$(has_command vainfo)" \
    --argjson vulkaninfo "$(has_command vulkaninfo)" \
    --argjson ffmpeg "$(has_command ffmpeg)" \
    --argjson wayland_info "$(has_command wayland-info)" \
    --argjson nvidia_utils "$(has_package nvidia-utils)" \
    --argjson vaapi_driver "$(has_package libva-nvidia-driver)" \
    --argjson libva "$(has_package libva)" \
    --argjson libdrm "$(has_package libdrm)" \
    --argjson egl_wayland "$(has_package egl-wayland)" '{
      schema_version:1,
      status:"passive_target_wayland_gpu_prerequisites_only",
      linux_x86_64:($linux and $x86_64),
      current_session_type:$session,
      wayland_environment_present:$wayland,
      hyprland_environment_present:$hyprland,
      render_nodes_present:$render,
      render_nodes_mode_readable:$readable,
      render_nodes_mode_writable:$writable,
      nvidia_vendor_render_nodes:$nvidia,
      other_or_unknown_vendor_render_nodes:$other,
      command_presence:{
        pacman:$pacman,nvidia_smi:$nvidia_smi,vainfo:$vainfo,
        vulkaninfo:$vulkaninfo,ffmpeg:$ffmpeg,wayland_info:$wayland_info
      },
      pacman_package_db_presence:{
        nvidia_utils:$nvidia_utils,libva_nvidia_driver:$vaapi_driver,
        libva:$libva,libdrm:$libdrm,egl_wayland:$egl_wayland
      },
      real_GPU_or_video_decoder_initialized:false,
      actual_render_node_opened:false,
      VAAPI_native_provider_loaded_or_denied:false,
      DMA_BUF_buffer_allocated_and_compositor_imported:false,
      accelerated_WebGL2_draw_presented:false,
      compiled_Vulpra_executed:false,
      complete_native_dependency_and_FFI_closure_proven:false,
      source_pruning_authorized:false,
      m3_sixth_gate_closed:false,
      release_ready:false,
      identifying_host_paths_credentials_or_GPU_UUIDs_collected:false,
      packages_or_host_configuration_modified:false
    }'
}
if [[ "$1" == "--inspect" ]]; then
  inspect
  exit 0
fi
report="$(inspect)"
jq -e '
  .schema_version==1 and .status=="passive_target_wayland_gpu_prerequisites_only" and
  (.linux_x86_64|type)=="boolean" and
  (.current_session_type|IN("wayland","x11","other","unset")) and
  .render_nodes_present>=0 and
  .render_nodes_mode_readable<=.render_nodes_present and
  .render_nodes_mode_writable<=.render_nodes_present and
  .nvidia_vendor_render_nodes+.other_or_unknown_vendor_render_nodes==.render_nodes_present and
  all(.command_presence[];type=="boolean") and
  all(.pacman_package_db_presence[];type=="boolean") and
  .real_GPU_or_video_decoder_initialized==false and
  .actual_render_node_opened==false and
  .VAAPI_native_provider_loaded_or_denied==false and
  .DMA_BUF_buffer_allocated_and_compositor_imported==false and
  .accelerated_WebGL2_draw_presented==false and
  .compiled_Vulpra_executed==false and
  .complete_native_dependency_and_FFI_closure_proven==false and
  .source_pruning_authorized==false and
  .m3_sixth_gate_closed==false and .release_ready==false and
  .identifying_host_paths_credentials_or_GPU_UUIDs_collected==false and
  .packages_or_host_configuration_modified==false
' <<< "$report" >/dev/null
echo "PASS: passive machine-agnostic graphics prerequisites and fail-closed JSON self-test"
echo "LIMIT: real target RTX / VA-API / DMA-BUF runtime compatibility not established"
