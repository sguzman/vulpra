#!/usr/bin/env bash
# Run exclusively under sudo unshare --net with isolated loopback-only networking.
# Avoids real decryption keys, DRM sessions, media or browser profile access.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-clearkey-no-egress.sh package-dir rust-probe static-report output' >&2
  exit 2
fi
[[ "$(id -u)" == 0 ]] || exit 2
package="$(realpath -e -- "$1")"
probe="$(realpath -e -- "$2")"
static="$(realpath -e -- "$3")"
out="$4"
plugin="$package/gmp-clearkey/0.1/libclearkey.so"
[[ -f "$plugin" && -x "$probe" && ! -e "$out" ]] || exit 2
ip link set lo up
[[ -z "$(ip -4 route show default)" && -z "$(ip -6 route show default)" ]] || exit 1
[[ "$(ip -o link show | wc -l)" == 1 ]] || exit 1
# Optional source-pinned native binding-only replay, distinct from the normal
# ABI version report. Its only output is a sanitized provider/count JSON.
debug_modes=versions
if [[ -n "${M3_NATIVE_BINDINGS_REPORT:-}" ]]; then
  [[ -x "${M3_NATIVE_BINDINGS_PARSER:-}" && ! -e "$M3_NATIVE_BINDINGS_REPORT" ]] || exit 2
  debug_modes=versions,bindings
fi
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -m 0700 "$work/home"
umask 077
timeout --signal=TERM --kill-after=3s 25s \
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
  HOME="$work/home" LD_LIBRARY_PATH="$package:$package/gmp-clearkey/0.1" \
  LD_DEBUG="$debug_modes" LD_DEBUG_OUTPUT="$work/clearkey-loader" \
  MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
  "$probe" "$plugin" >"$work/probe.out" 2>"$work/probe.err" || {
    echo 'Original ClearKey CDM C API negative-path execution failed' >&2
    sed -n '1,8p' "$work/probe.err" >&2
    exit 1
  }
grep -Fxq 'PASS: original packaged ClearKey CDM C API rejected invalid interface version' \
  "$work/probe.out" || exit 1
repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
if [[ -z "${M3_NATIVE_BINDINGS_REPORT:-}" ]]; then
  python3 "$repo/ci/m3-clearkey-version-checks.py" \
    --traces "$work" --static "$static" --output "$out"
  chmod 0644 "$out"
else
  "$M3_NATIVE_BINDINGS_PARSER" "$work" "$M3_NATIVE_BINDINGS_REPORT" "libclearkey.so"
  chmod 0644 "$M3_NATIVE_BINDINGS_REPORT"
fi
[[ ! -e "$work/home/.mozilla" ]] || exit 1
echo 'PASS: original ClearKey invalid-version C API and native ABI loader checks, no egress'
