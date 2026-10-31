#!/usr/bin/env bash
# This test must be invoked via sudo unshare --net, with only loopback.
# Inference/model download is intentionally NEVER activated in this fixture.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-onnxruntime-no-egress.sh package-dir compiled-prober static.json output.json' >&2
  exit 2
fi
[[ "$(id -u)" == 0 ]] || exit 2
pkg="$(realpath -e -- "$1")"
probe="$(realpath -e -- "$2")"
static="$(realpath -e -- "$3")"
out="$4"
[[ -f "$pkg/libonnxruntime.so" && -x "$probe" && ! -e "$out" ]] || exit 2
ip link set lo up
[[ -z "$(ip -4 route show default)" && -z "$(ip -6 route show default)" ]] || exit 1
[[ "$(ip -o link show | wc -l)" == 1 ]] || exit 1
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -m 0700 "$work/home"
umask 077
timeout --signal=TERM --kill-after=3s 25s \
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
    HOME="$work/home" LD_LIBRARY_PATH="$pkg" \
    LD_DEBUG=versions LD_DEBUG_OUTPUT="$work/onnx-loader" \
    MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
    "$probe" "$pkg/libonnxruntime.so" >"$work/probe.out" 2>"$work/probe.err" || {
      echo 'Original packaged ONNX Runtime C ABI activation failed' >&2
      exit 1
    }
grep -Fxq 'PASS: original packaged ONNX Runtime C API base and nonempty version string invoked' "$work/probe.out" || {
  echo 'Original ONNX API version function not confirmed' >&2
  exit 1
}
python3 "$GITHUB_WORKSPACE/ci/m3-onnxruntime-version-checks.py" \
  --traces "$work" --static "$static" --output "$out"
[[ ! -e "$work/home/.mozilla" ]] || {
  echo 'No-egress ONNX library probe created browser user profile' >&2
  exit 1
}
chmod 0644 "$out"
echo 'PASS: original native ONNX API entrypoint reached under no-egress namespace'
