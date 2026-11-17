#!/usr/bin/env bash
# Offline fixture: validate selected fields and that monitor serials stay private.
set -Eeuo pipefail
script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/capture-hyprland-gpu-baseline.sh"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/repo" "$work/bin"
cd "$work/repo"
git init -q
printf '#! /bin/sh\n' > mach
git add mach
git -c user.name=QA -c user.email=qa@example.invalid commit -qm 'fixture source'
cat > "$work/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-j monitors')
    printf '%s\n' '[{"name":"HDMI-A-1","description":"IDENTIFY-SECRET-DESCRIPTION","serial":"SECRET-SERIAL","width":1920,"height":1080,"refreshRate":60.0,"scale":1,"transform":0,"vrr":false,"focused":true,"dpmsStatus":true,"activeWorkspace":{"name":"SECRET-WORKSPACE"}}]'
    ;;
  '-j monitors all')
    printf '%s\n' '[{"name":"HDMI-A-1","description":"IDENTIFY-SECRET-DESCRIPTION","serial":"SECRET-SERIAL","width":1920,"height":1080,"refreshRate":60.0,"disabled":false,"dpmsStatus":true,"activeWorkspace":{"name":"SECRET-WORKSPACE"}},{"name":"HDMI-A-3","description":"IDENTIFY-SECRET-DISABLED","serial":"SECRET-SERIAL-2","width":0,"height":0,"refreshRate":0,"disabled":true,"dpmsStatus":false}]'
    ;;
  *) exit 5 ;;
esac
EOF
cat > "$work/bin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == '--query-gpu=index,utilization.gpu,utilization.memory,power.draw,temperature.gpu' ]] || exit 5
printf '0, 12, 4, 55.0, 50\n'
EOF
chmod +x "$work/bin/hyprctl" "$work/bin/nvidia-smi"
# Linux exposes PCI vendor on the parent DRM card, not the connector.
mkdir -p "$work/sysfs/card1-HDMI-A-1" "$work/sysfs/card2-HDMI-A-3" \
  "$work/sysfs/card1/device" "$work/sysfs/card2/device"
printf 'connected\n' > "$work/sysfs/card1-HDMI-A-1/status"
printf 'enabled\n' > "$work/sysfs/card1-HDMI-A-1/enabled"
printf '0x1002\n' > "$work/sysfs/card1/device/vendor"
printf 'connected\n' > "$work/sysfs/card2-HDMI-A-3/status"
printf 'disabled\n' > "$work/sysfs/card2-HDMI-A-3/enabled"
printf '0x10de\n' > "$work/sysfs/card2/device/vendor"
PATH="$work/bin:$PATH" VULPRA_DRM_SYSFS_ROOT="$work/sysfs" \
  VULPRA_GPU_SAMPLES=1 bash "$script" "$work/repo" > "$work/out"
grep -Fq 'HDMI-A-1' "$work/out"
grep -Fq '"disabled":false' "$work/out"
grep -Fq '"disabled":true' "$work/out"
grep -Fq 'card1-HDMI-A-1  card=card1  vendor=0x1002  gpu=AMD  kms_enabled=enabled' "$work/out"
grep -Fq 'card2-HDMI-A-3  card=card2  vendor=0x10de  gpu=NVIDIA  kms_enabled=disabled' "$work/out"
grep -Fq 'NONSTANDARD DRM sysfs root: fixture/test override' "$work/out"
grep -Fq '0, 12, 4, 55.0, 50' "$work/out"
if grep -Eq 'SECRET-SERIAL|SECRET-WORKSPACE|IDENTIFY-SECRET' "$work/out"; then
  echo 'FAIL: monitor-identifying data leaked' >&2
  exit 1
fi
if PATH="$work/bin:$PATH" VULPRA_DRM_SYSFS_ROOT="$work/sysfs" VULPRA_GPU_SAMPLES=0 bash "$script" "$work/repo" > "$work/bad" 2>&1; then
  echo 'FAIL: zero telemetry samples unexpectedly accepted' >&2; exit 1
fi
if PATH="$work/bin:$PATH" VULPRA_DRM_SYSFS_ROOT="$work/sysfs" VULPRA_GPU_SAMPLES=31 bash "$script" "$work/repo" > "$work/bad" 2>&1; then
  echo 'FAIL: unbounded telemetry samples unexpectedly accepted' >&2; exit 1
fi
printf 'PASS: mixed-GPU parent PCI vendor mapping, disabled monitor state, serial filtering and bounded samples.\n'
