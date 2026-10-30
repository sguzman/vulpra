#!/usr/bin/env bash
# CI only, called inside sudo unshare --net: no outward network topology.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-wayland-private-topology.sh lo_down|lo_up|dummy_up|dummy_default|veth_down|veth_up|veth_default user harness appdir' >&2
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
  dummy_up|dummy_default)
    # A standalone synthetic device entirely inside this network namespace.
    # An optional default route is a local sink, NOT host network access.
    ip link add dummy0 type dummy
    ip addr add 192.0.2.1/32 dev dummy0
    ip link set dummy0 up
    if [[ "$mode" = dummy_default ]]; then
      ip -4 route add default dev dummy0
    fi
    ;;
  veth_down|veth_up|veth_default)
    # Both endpoints are created INSIDE the new network namespace; no peer
    # is moved to the host, no bridge is created and no outside egress exists.
    ip link add eth0 type veth peer name peer0
    if [[ "$mode" != veth_down ]]; then
      ip addr add 198.51.100.2/30 dev eth0
      ip addr add 198.51.100.1/30 dev peer0
      ip link set eth0 up
      ip link set peer0 up
      if [[ "$mode" = veth_default ]]; then
        ip -4 route add default dev eth0
      fi
    fi
    ;;
  *)
    echo 'Invalid isolated network topology' >&2
    exit 2
    ;;
esac
for name in $(ip -o link show | awk -F': ' '{print $2}'); do
  case "$name" in
    lo|dummy0|eth0|peer0) ;;
    *) echo 'Unsafe interface in diagnostic namespace' >&2; exit 4 ;;
  esac
done
if ip -6 route show default | grep -q .; then
  echo 'Unsafe namespace: unexpected IPv6 default route' >&2
  exit 4
fi
if [[ "$mode" = dummy_default || "$mode" = veth_default ]]; then
  # Only the synthetic interface in this disposable namespace is allowed.
  test "$(ip -4 route show default | wc -l)" -eq 1
  if [[ "$mode" = dummy_default ]]; then
    ip -4 route show default | grep -Eq '^default dev dummy0( |$)'
  else
    ip -4 route show default | grep -Eq '^default dev eth0( |$)'
  fi
else
  if ip -4 route show default | grep -q .; then
    echo 'Unsafe namespace: unexpected IPv4 default route' >&2
    exit 4
  fi
fi
# No public/global address on any interface in this disposable namespace.
if ip -o -4 addr show | grep -Ev 'inet (127[.]|192[.]0[.]2[.]1/32|198[.]51[.]100[.][12]/30)' | grep -q 'inet '; then
  echo 'Unsafe namespace: unexpected IPv4 address' >&2
  exit 4
fi
exec runuser -u "$user" -- env \
  MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 VULPRA_WAYLAND_TEST_SECONDS=10 \
  bash "$harness" "$appdir"
