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
[[ "$*" == '-j monitors' ]] || exit 5
printf '%s\n' '[{"name":"HDMI-A-1","description":"IDENTIFY-SECRET-DESCRIPTION","serial":"SECRET-SERIAL","width":1920,"height":1080,"refreshRate":60.0,"scale":1,"transform":0,"vrr":false,"focused":true,"dpmsStatus":true,"activeWorkspace":{"name":"SECRET-WORKSPACE"}}]'
EOF
cat > "$work/bin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == '--query-gpu=index,utilization.gpu,utilization.memory,power.draw,temperature.gpu' ]] || exit 5
printf '0, 12, 4, 55.0, 50\n'
EOF
chmod +x "$work/bin/hyprctl" "$work/bin/nvidia-smi"
PATH="$work/bin:$PATH" VULPRA_GPU_SAMPLES=1 bash "$script" "$work/repo" > "$work/out"
grep -Fq 'HDMI-A-1' "$work/out"
grep -Fq '0, 12, 4, 55.0, 50' "$work/out"
if grep -Eq 'SECRET-SERIAL|SECRET-WORKSPACE|IDENTIFY-SECRET' "$work/out"; then
  echo 'FAIL: monitor-identifying data leaked' >&2
  exit 1
fi
if PATH="$work/bin:$PATH" VULPRA_GPU_SAMPLES=0 bash "$script" "$work/repo" > "$work/bad" 2>&1; then
  echo 'FAIL: zero telemetry samples unexpectedly accepted' >&2; exit 1
fi
if PATH="$work/bin:$PATH" VULPRA_GPU_SAMPLES=31 bash "$script" "$work/repo" > "$work/bad" 2>&1; then
  echo 'FAIL: unbounded telemetry samples unexpectedly accepted' >&2; exit 1
fi
printf 'PASS: bounded Hyprland GPU baseline, profile safety and serial filtering fixtures.\n'
