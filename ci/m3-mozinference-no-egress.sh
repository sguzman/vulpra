#!/usr/bin/env bash
# Invoked only under sudo unshare --net with one loopback interface.
# Test data is synthetic; no model or browser profile is opened.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-mozinference-no-egress.sh package-dir rust-probe static-report output' >&2
  exit 2
fi
[[ "$(id -u)" == 0 ]] || exit 2
package="$(realpath -e -- "$1")"
probe="$(realpath -e -- "$2")"
static="$(realpath -e -- "$3")"
out="$4"
[[ -f "$package/libmozinference.so" && -x "$probe" && ! -e "$out" ]] || exit 2
ip link set lo up
[[ -z "$(ip -4 route show default)" && -z "$(ip -6 route show default)" ]] || exit 1
[[ "$(ip -o link show | wc -l)" == 1 ]] || exit 1
grep -qw avx2 /proc/cpuinfo || {
  echo 'Original mozinference x86-64 build requires AVX2 on the test host' >&2
  exit 1
}
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -m 0700 "$work/home"
umask 077
timeout --signal=TERM --kill-after=3s 25s \
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
  HOME="$work/home" LD_LIBRARY_PATH="$package" \
  LD_DEBUG=versions LD_DEBUG_OUTPUT="$work/mozinference-loader" \
  MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
  "$probe" "$package/libmozinference.so" >"$work/probe.out" 2>"$work/probe.err" || {
    echo 'Original packaged mozinference C API activation failed' >&2
    sed -n '1,8p' "$work/probe.err" >&2
    exit 1
  }
grep -Fxq 'PASS: original packaged mozinference production-linked llama C API invoked' \
  "$work/probe.out" || exit 1
repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
python3 "$repo/ci/m3-mozinference-version-checks.py" \
  --traces "$work" --static "$static" --output "$out"
[[ ! -e "$work/home/.mozilla" ]] || exit 1
chmod 0644 "$out"
echo 'PASS: pinned native mozinference API and ABI version checks in isolated network namespace'
