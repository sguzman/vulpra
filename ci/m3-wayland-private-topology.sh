#!/usr/bin/env bash
# CI only, called inside sudo unshare --net: no outward network topology.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-wayland-private-topology.sh lo_down|lo_up|dummy_up user harness appdir' >&2
  exit 2
fi
mode="$1"
user="$2"
harness="$(realpath -e -- "$3")"
appdir="$(realpath -e -- "$4")"
[[ "$(id -u)" -eq 0 ]] || { echo 'Requires isolated namespace root' >&2; exit 4; }
test "$(ip -o link show | wc -l)" -eq 1
ip -o link show | grep -Eq '^[0-9]+: lo:'
# No host device may be imported. Start from a newly empty namespace.
case "$mode" in
  lo_down)
    ;;
  lo_up)
    ip link set lo up
    ;;
  dummy_up)
    # Only a locally scoped synthetic interface; documentation address,
    # no default route, no link to the real network.
    ip link add dummy0 type dummy
    ip addr add 192.0.2.1/32 dev dummy0
    ip link set dummy0 up
    ;;
  *)
    echo 'Invalid isolated network topology' >&2
    exit 2
    ;;
esac
for name in $(ip -o link show | awk -F': ' '{print $2}'); do
  case "$name" in
    lo|dummy0) ;;
    *) echo 'Unsafe interface in diagnostic namespace' >&2; exit 4 ;;
  esac
done
if ip -4 route show default | grep -q . || ip -6 route show default | grep -q .; then
  echo 'Unsafe namespace: default outside route present' >&2
  exit 4
fi
# No public/global address on any interface in this disposable namespace.
if ip -o -4 addr show | grep -Ev 'inet (127[.]|192[.]0[.]2[.]1/32)' | grep -q 'inet '; then
  echo 'Unsafe namespace: unexpected IPv4 address' >&2
  exit 4
fi
exec runuser -u "$user" -- env \
  MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 VULPRA_WAYLAND_TEST_SECONDS=10 \
  bash "$harness" "$appdir"
