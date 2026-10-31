#!/usr/bin/env bash
# Only synthetic/read-only/invalid-argument paths of the original compiled
# crashreporter, updater, crashhelper. Must be run in sudo unshare --net.
set -euo pipefail
[[ $# == 3 && "$(id -u)" == 0 ]] || exit 2
pkg="$(realpath -e -- "$1")"
static="$(realpath -e -- "$2")"
out="$3"
[[ ! -e "$out" && -x "$pkg/crashhelper" && -x "$pkg/crashreporter" && -x "$pkg/updater" ]] || exit 2
ip link set lo up
[[ -z "$(ip -4 route show default)" && -z "$(ip -6 route show default)" ]] || exit 1
[[ "$(ip -o link show | wc -l)" == 1 ]] || exit 1
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -m 0700 "$work/home"
repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
cd "$work"
umask 077
export HOME="$work/home" TMPDIR="$work/home" XDG_CONFIG_HOME="$work/home/config"
export XDG_CACHE_HOME="$work/home/cache" LD_LIBRARY_PATH="$pkg"
export MOZ_DISABLE_NONLOCAL_CONNECTIONS=1
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy || :
# Fewer than six arguments: source crashhelper.cpp returns before crash logic.
set +e
timeout --kill-after=3s 10s env LD_DEBUG=versions \
  LD_DEBUG_OUTPUT="$work/crashhelper-loader" \
  "$pkg/crashhelper" >"$work/crashhelper.out" 2>"$work/crashhelper.err"
rc=$?
set -e
[[ "$rc" == 1 && ! -s "$work/crashhelper.out" ]] || exit 1
# Source crashreporter Rust main routes --memtest directly to synthetic memory.
args='{"timeout":{"secs":5,"nanos":0},"mem_lock_mode":"Disabled","allow_working_set_resize":false,"allow_multithread":false,"allow_early_termination":true}'
timeout --kill-after=3s 35s env LD_DEBUG=versions \
  LD_DEBUG_OUTPUT="$work/crashreporter-loader" \
  "$pkg/crashreporter" --memtest 1 "$args" >"$work/crashreporter.out" \
  2>"$work/crashreporter.err" || {
    echo 'Original crashreporter synthetic memtest failed' >&2
    sed -n '1,8p' "$work/crashreporter.err" >&2
    exit 1
  }
jq -e '.memtest_failed==false and (.tested_mem_length>=512) and (.reports|length>0)' \
  "$work/crashreporter.out" >/dev/null || exit 1
# Source updater.cpp --channels-allowed reads channel configuration and exits
# before any MAR application; require this exact branch.
set +e
timeout --kill-after=3s 10s env LD_DEBUG=versions \
  LD_DEBUG_OUTPUT="$work/updater-loader" \
  "$pkg/updater" --channels-allowed >"$work/updater.out" 2>"$work/updater.err"
rc=$?
set -e
if [[ "$rc" == 0 ]]; then
  grep -Eq '^(Channels Allowed: |Not Applicable: )' "$work/updater.out" || exit 1
elif [[ "$rc" == 1 ]]; then
  grep -Eq '^Error: [0-9]+' "$work/updater.out" || exit 1
else
  echo 'Original read-only updater channel query took unexpected route' >&2
  exit 1
fi
python3 "$repo/ci/m3-auxiliary-guarded-cli-version-checks.py" \
  --traces "$work" --static "$static" --output "$out"
[[ ! -e "$work/home/.mozilla" ]] || exit 1
chmod 0644 "$out"
echo 'PASS: no-egress original protected auxiliary diagnostic-only ELF ABI'
