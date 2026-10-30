#!/usr/bin/env bash
# CI-only: invoke private Weston with NO outside network interfaces or routes.
# This helper MUST be launched under: sudo unshare --net -- bash SCRIPT ...
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-wayland-netns-launch.sh runner-user harness appdir enabled|unset' >&2
  exit 2
fi
user="$1"
harness="$(realpath -e -- "$2")"
appdir="$(realpath -e -- "$3")"
mode="$4"
[[ "$(id -u)" -eq 0 ]] || { echo 'Diagnostic netns launcher requires root namespace setup' >&2; exit 4; }
command -v ip >/dev/null || { echo 'Missing iproute2 inside namespace' >&2; exit 4; }
# A just-created Linux network namespace should expose only loopback,
# not merely lack a default route: reject bridges and direct routes too.
interfaces="$(ip -o link show | wc -l)"
[[ "$interfaces" -eq 1 ]] || {
  echo 'Unsafe network namespace: unexpected additional interfaces' >&2
  exit 4
}
ip -o link show | grep -Eq '^[0-9]+: lo:' || {
  echo 'Unsafe network namespace: loopback-only assertion failed' >&2
  exit 4
}
if ip -4 route show | grep -q . || ip -6 route show | grep -q .; then
  echo 'Unsafe network namespace: routing table is not empty' >&2
  exit 4
fi
case "$mode" in
  enabled)
    exec runuser -u "$user" -- env \
      MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 VULPRA_WAYLAND_TEST_SECONDS=10 \
      bash "$harness" "$appdir"
    ;;
  unset)
    exec runuser -u "$user" -- env -u MOZ_DISABLE_NONLOCAL_CONNECTIONS \
      VULPRA_WAYLAND_TEST_SECONDS=10 bash "$harness" "$appdir"
    ;;
  *)
    echo 'Invalid network flag mode' >&2
    exit 2
    ;;
esac
