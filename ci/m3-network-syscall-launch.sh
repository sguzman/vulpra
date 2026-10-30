#!/usr/bin/env bash
# Separate diagnostic: trace only network syscalls of unmodified Weston smoke.
# Called as runner for "host"; or as root INSIDE a newly empty network
# namespace for "netns". Raw strace files must be deleted by caller.
set -euo pipefail
if [[ $# -ne 5 ]]; then
  echo 'usage: m3-network-syscall-launch.sh host|netns runner harness appdir trace-prefix' >&2
  exit 2
fi
mode="$1"
runner="$2"
harness="$(realpath -e -- "$3")"
appdir="$(realpath -e -- "$4")"
prefix="$5"
[[ "$prefix" == /* ]] || { echo 'Trace prefix must be absolute' >&2; exit 2; }
[[ "$prefix" != *..* ]] || { echo 'Trace prefix may not traverse parent paths' >&2; exit 2; }
[[ -d "$(dirname -- "$prefix")" ]] || { echo 'Trace output directory missing' >&2; exit 2; }
case "$mode" in
  host)
    test "$(id -u)" -ne 0
    exec env MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 VULPRA_WAYLAND_TEST_SECONDS=10 \
      strace -qq -ff -e trace=network -o "$prefix" \
      bash "$harness" "$appdir"
    ;;
  netns)
    test "$(id -u)" -eq 0
    test "$(ip -o link show | wc -l)" -eq 1
    ip -o link show | grep -Eq '^[0-9]+: lo:'
    if ip -4 route show | grep -q . || ip -6 route show | grep -q .; then
      echo 'Refusing namespace with any existing routes' >&2
      exit 4
    fi
    # runuser relinquishes root before strace and Weston.
    exec runuser -u "$runner" -- env \
      MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 VULPRA_WAYLAND_TEST_SECONDS=10 \
      strace -qq -ff -e trace=network -o "$prefix" \
      bash "$harness" "$appdir"
    ;;
  *)
    echo 'Unknown syscall probe launch mode' >&2
    exit 2
    ;;
esac
