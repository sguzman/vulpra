#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
cat >"$work/sample" <<'RAW'
socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE) = 4
connect(4, {sa_family=AF_NETLINK, nl_pid=0}, 12) = 0
socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP) = 6
connect(6, {sa_family=AF_INET6, ipv6_addr="personal"}, 16) = -1 ENETUNREACH (Network unreachable)
recvmsg(4, {PRIVATE_PATH="/tmp/secret123"}, 0) = 0
socket(AF_UNIX, SOCK_STREAM, 0) = 8
RAW
awk -f "$root/ci/m3-network-syscall-counts.awk" "$work/sample" >"$work/summary"
grep -Fxq 'aggregate network syscall lines: 6' "$work/summary"
grep -Fxq 'socket() calls: 3' "$work/summary"
grep -Fxq 'connect() calls: 2' "$work/summary"
grep -Fxq 'AF_NETLINK occurrences: 2' "$work/summary"
grep -Fxq 'AF_INET6 occurrences: 2' "$work/summary"
grep -Fxq 'ENETUNREACH occurrences: 1' "$work/summary"
if grep -Eq 'personal|secret123|/tmp/|nl_pid|ipv6_addr|\\b[0-9]{2,}\\b' "$work/summary"; then
  # Numeric counters >99 are valid; reject actual fixture raw markers only.
  if grep -Eq 'personal|secret123|/tmp/|nl_pid|ipv6_addr' "$work/summary"; then
    echo 'FAIL: raw network syscall detail escaped sanitizer' >&2
    exit 1
  fi
fi
echo 'PASS: aggregate network syscall categories without raw endpoint/trace leakage'
