#!/usr/bin/env bash
# Read-only mixed-GPU display topology and bounded GPU telemetry for issue #7.
# No root, browser launch, user profile access, compositor config or setting edits.
set -Eeuo pipefail
repo="${1:-$HOME/Code/Apps/vulpra}"
cd "$repo" || { echo "ERROR: Vulpra checkout not found: $repo" >&2; exit 2; }
[[ -f mach ]] || { echo 'ERROR: Not the Vulpra source checkout.' >&2; exit 2; }
for name in jq hyprctl git; do
  command -v "$name" >/dev/null 2>&1 || { echo "ERROR: Missing $name; no software was installed." >&2; exit 2; }
done
samples="${VULPRA_GPU_SAMPLES:-8}"
[[ "$samples" =~ ^[1-9][0-9]?$ ]] && ((samples <= 30)) || {
  echo 'ERROR: VULPRA_GPU_SAMPLES must be 1..30.' >&2; exit 2;
}
source_commit="$(git rev-parse --verify --short=12 HEAD)" || { echo "ERROR: Checkout has no source commit." >&2; exit 2; }
logdir="$(git rev-parse --path-format=absolute --git-path vulpra-native-build)"
mkdir -p "$logdir"
stamp="$(date +%Y%m%d-%H%M%S-%N)"
report="$logdir/hyprland-gpu-baseline-$stamp.txt"
# Never record the full hyprctl JSON (it includes identifying display data).
# A command failure should be reported, not accepted as an empty topology.
monitors="$(hyprctl -j monitors | jq -ec '
  if type != "array" or length == 0 then error("no active monitors") else
  [.[] | {connector: .name, width: .width, height: .height,
         refresh_hz: .refreshRate, scale: .scale, transform: .transform,
         vrr: .vrr, focused: .focused, dpms: .dpmsStatus}]
  end
')" || { echo 'ERROR: Could not query active Hyprland monitors.' >&2; exit 3; }
{
  printf 'Vulpra mixed-GPU baseline (read-only; %s)\n' "$(date -Is)"
  printf 'Source commit: %s\n' "$source_commit"
  printf 'Active Hyprland monitors (identifying fields excluded):\n%s\n' "$monitors"
  # "all" includes Hyprland-known outputs which may be disabled and absent
  # from the normal active-monitor view. Never persist unfiltered JSON.
  if all_monitors="$(hyprctl -j monitors all 2>/dev/null | jq -ec '
    if type != "array" then error("not monitor array") else
    [.[] | {connector: .name, disabled: (.disabled // null),
           width: .width, height: .height, refresh_hz: .refreshRate,
           dpms: .dpmsStatus}]
    end
  ' 2>/dev/null)"; then
    printf 'All Hyprland-known monitors (including disabled, if supported):\n%s\n' "$all_monitors"
  else
    echo 'All-monitor view unavailable on this Hyprland version.'
  fi
  printf 'Connected DRM outputs (connector, parent card GPU PCI vendor, KMS enabled; no EDID):\n'
  found=0
  drm_root="${VULPRA_DRM_SYSFS_ROOT:-/sys/class/drm}"
  if [[ "$drm_root" != /sys/class/drm ]]; then
    echo 'NONSTANDARD DRM sysfs root: fixture/test override; not valid hardware evidence.'
  fi
  for connector in "$drm_root"/card[0-9]*-*; do
    [[ -r "$connector/status" ]] || continue
    IFS= read -r status < "$connector/status" || continue
    [[ "$status" == connected ]] || continue
    found=1
    connector_name="${connector##*/}"
    card="${connector_name%%-*}"
    vendor='unknown'
    # GPU PCI vendor is attached to cardN, not cardN-HDMI-A-N.
    if [[ -r "$drm_root/$card/device/vendor" ]]; then
      IFS= read -r vendor < "$drm_root/$card/device/vendor" || true
    fi
    case "${vendor,,}" in
      0x10de) gpu='NVIDIA' ;;
      0x1002) gpu='AMD' ;;
      0x8086) gpu='Intel' ;;
      *) gpu='unknown' ;;
    esac
    kms_enabled='unknown'
    if [[ -r "$connector/enabled" ]]; then
      IFS= read -r kms_enabled < "$connector/enabled" || true
    fi
    printf '  %s  card=%s  vendor=%s  gpu=%s  kms_enabled=%s\n' "$connector_name" "$card" "$vendor" "$gpu" "$kms_enabled"
  done
  ((found)) || printf '  unavailable (not a test failure)\n'
  if command -v nvidia-smi >/dev/null 2>&1; then
    printf 'NVIDIA readings (%ss, index, GPU%%, memory%%, power W, temperature C):\n' "$samples"
    for ((i=0; i<samples; ++i)); do
      if ! timeout 5 nvidia-smi --query-gpu=index,utilization.gpu,utilization.memory,power.draw,temperature.gpu --format=csv,noheader,nounits; then
        printf '  NVIDIA telemetry unavailable or timed out at sample %d\n' "$((i+1))"
        break
      fi
      if (( i+1 < samples )); then sleep 1; fi
    done
  else
    echo 'NVIDIA telemetry unavailable (nvidia-smi not installed on PATH).'
  fi
  echo 'LIMIT: This captures topology and utilization only; it does not measure typing-to-paint latency, frame pacing, renderer selection or causal GPU attribution.'
  echo 'LIMIT: No browser profile, compositor configuration, display settings, security controls or other services were changed.'
} | tee "$report"
printf 'Report: %s\n' "$report"
