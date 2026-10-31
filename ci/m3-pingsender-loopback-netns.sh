#!/usr/bin/env bash
# Run ONLY inside sudo unshare --net. Synthetic localhost HTTP POST using
# original packaged pingsender with glibc version evidence. No external egress.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-pingsender-loopback-netns.sh package-dir static-report json-report repo-root' >&2
  exit 2
fi
[[ "$(id -u)" == 0 ]] || { echo 'Private network namespace needs root namespace setup' >&2; exit 2; }
package="$(realpath -e -- "$1")"
static="$(realpath -e -- "$2")"
output="$3"
repository="$(realpath -e -- "$4")"
[[ -x "$package/pingsender" ]] || { echo 'Source-pinned package pingsender missing' >&2; exit 2; }
[[ ! -e "$output" ]] || { echo 'Refusing to replace prior scoped report' >&2; exit 2; }
command -v ip >/dev/null
command -v timeout >/dev/null
# This namespace was created specifically using unshare --net. A default route
# would mean a dangerous caller mistake; reject BEFORE any program network use.
ip link set lo up
[[ -z "$(ip -4 route show default)" ]] || exit 1
[[ -z "$(ip -6 route show default)" ]] || exit 1
[[ "$(ip -o link show | wc -l)" == 1 ]] || {
  echo 'Network namespace unexpectedly has a non-loopback interface' >&2; exit 1;
}
# The independent actual-binding replay opts in, retaining the same synthetic
# loopback request and forbidden-host negative test as the ABI-only path.
debug_modes=versions
if [[ -n "${M3_NATIVE_BINDINGS_REPORT:-}" ]]; then
  [[ -x "${M3_NATIVE_BINDINGS_PARSER:-}" && ! -e "$M3_NATIVE_BINDINGS_REPORT" ]] || exit 2
  debug_modes=versions,bindings
fi
work="$(mktemp -d)"
server=''
cleanup() {
  if [[ -n "$server" ]]; then
    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
  fi
  rm -rf -- "$work"
}
trap cleanup EXIT
umask 077
mkdir -m 0700 "$work/home"
printf '%s' '{"probe":"vulpra-source-pinned-only","count":1}' > "$work/ping.json"
env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
  HOME="$work/home" \
  python3 "$repository/ci/m3-pingsender-local-http-server.py" \
  --ready "$work/port" --result "$work/response.json" >"$work/server.out" 2>&1 &
server="$!"
for attempt in {1..50}; do
  [[ -s "$work/port" ]] && break
  kill -0 "$server" 2>/dev/null || break
  sleep 0.1
done
[[ -s "$work/port" ]] || { echo 'Synthetic localhost server did not start' >&2; exit 1; }
port="$(cat "$work/port")"
[[ "$port" =~ ^[0-9]{1,5}$ ]] || exit 1
((port>=1024 && port<=65535)) || exit 1
# Source accepts literal hostname "localhost" but does not accept
# numeric 127.0.0.1. Negative-route check happens WHILE the one-request
# server listens: if numeric-host validation accidentally allowed the request,
# the rejected payload would be transmitted and deleted; fail closed.
printf '%s' '{"probe":"vulpra-source-pinned-only","count":1}' > "$work/rejected.json"
if timeout --signal=TERM --kill-after=3s 10s \
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
    HOME="$work/home" NO_PROXY="localhost,127.0.0.1" \
    MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
    "$package/pingsender" "http://127.0.0.1:$port/pingsender-fixture" "$work/rejected.json" \
    >"$work/rejected.out" 2>"$work/rejected.err"; then
  echo 'pingsender incorrectly accepted forbidden numeric host' >&2
  exit 1
fi
[[ -s "$work/rejected.json" ]] || {
  echo 'Rejected destination unexpectedly deleted its synthetic ping' >&2
  exit 1
}
kill -0 "$server" 2>/dev/null || {
  echo 'Rejected destination unexpectedly contacted the synthetic server' >&2
  exit 1
}
# Now the single permitted literal-host request must reach the same
# original listener and delete only its own successful synthetic payload.
timeout --signal=TERM --kill-after=3s 25s \
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
    HOME="$work/home" NO_PROXY="localhost,127.0.0.1" \
    LD_DEBUG="$debug_modes" LD_DEBUG_OUTPUT="$work/pingsender-loader" \
    MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
    "$package/pingsender" "http://localhost:$port/pingsender-fixture" "$work/ping.json" \
    >"$work/sender.out" 2>"$work/sender.err" || {
      echo 'Original packaged pingsender failed synthetic localhost POST' >&2; exit 1;
    }
[[ ! -e "$work/ping.json" ]] || {
  echo 'Successful local ping did not remove only its isolated payload' >&2; exit 1;
}
wait "$server" || { echo 'Synthetic HTTP server did not accept valid gzip POST' >&2; exit 1; }
server=''
jq -e '.schema_version==1 and .synthetic_loopback_request_received==true and
       .synthetic_gzip_payload_and_fixed_headers_verified==true and
       .network_namespace_has_no_external_interface==true and
       .real_user_ping_payloads_sent==false' "$work/response.json" >/dev/null
if [[ -z "${M3_NATIVE_BINDINGS_REPORT:-}" ]]; then
  python3 "$repository/ci/m3-pingsender-version-reconcile.py" \
    --traces "$work" --static "$static" --output "$output"
  chmod 0644 -- "$output"
else
  "$M3_NATIVE_BINDINGS_PARSER" "$work" "$M3_NATIVE_BINDINGS_REPORT" "pingsender"
  chmod 0644 "$M3_NATIVE_BINDINGS_REPORT"
fi
[[ ! -e "$work/home/.mozilla" ]] || {
  echo 'Local-only helper created a browser/user profile' >&2; exit 1;
}
echo 'PASS: original pingsender posted only synthetic gzip to no-egress loopback and removed temporary input'
