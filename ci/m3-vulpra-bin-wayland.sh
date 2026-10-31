#!/usr/bin/env bash
# Run the exact original archived vulpra-bin through a disposable compatibility
# shim that uses the *same* real 10-second Wayland renderer/frame harness.
# Never replace the real packaged browser launcher or touch a user profile.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'usage: m3-vulpra-bin-wayland.sh original-app-dir static.json output.json repo-dir' >&2
  exit 2
fi
app="$(realpath -e -- "$1")"
static="$(realpath -e -- "$2")"
report="$3"
repo="$(realpath -e -- "$4")"
[[ -x "$app/vulpra-bin" && -x "$app/vulpra" ]] || {
  echo 'Original packaged alternate/native ELF executables missing' >&2
  exit 2
}
[[ ! -e "$report" ]] || { echo 'Refusing to overwrite native alternate-browser report' >&2; exit 2; }
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -m 0700 "$work/shim" "$work/traces"
{
  printf '#!/usr/bin/env bash\n'
  printf 'set -euo pipefail\n'
  printf 'umask 077\n'
  printf 'mkdir -p -m 0700 -- "$XDG_DATA_HOME/vulpra/default"\n'
  printf 'exec %q --no-remote --new-instance --profile "$XDG_DATA_HOME/vulpra/default" "$@"\n' "$app/vulpra-bin"
} > "$work/shim/vulpra-launch"
chmod 0700 "$work/shim/vulpra-launch"
# A shim is intentionally required because the normal launcher chooses the
# packaged canonical executable; this command isolates a distinct compiled
# executable's already-built graphical path, not a user configuration.
env MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 VULPRA_WAYLAND_TEST_OFFLINE=1 \
  VULPRA_WAYLAND_TEST_SECONDS=10 \
  bash "$repo/packaging/test-wayland.sh" "$work/shim"
echo 'PASS: real original alternate Vulpra binary 10s graphical frame/liveness uninstrumented'
# Binding replay is opt-in only; normal source-pinned version ABI test is
# unchanged and uses the same real temporary graphical browser launch.
trace_mode=versions
if [[ -n "${M3_ALT_BINDINGS_REPORT:-}" ]]; then
  [[ -x "${M3_NATIVE_BINDINGS_PARSER:-}" && ! -e "$M3_ALT_BINDINGS_REPORT" ]] || exit 2
  trace_mode=versions,bindings
fi
env MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 VULPRA_WAYLAND_TEST_OFFLINE=1 \
  VULPRA_WAYLAND_TEST_SECONDS=10 \
  VULPRA_M3_LOADER_TRACE_KIND="$trace_mode" \
  VULPRA_M3_LOADER_TRACE_PREFIX="$work/traces/vulpra-bin-loader" \
  bash "$repo/packaging/test-wayland.sh" "$work/shim"
if [[ -n "${M3_ALT_BINDINGS_REPORT:-}" ]]; then
  "$M3_NATIVE_BINDINGS_PARSER" "$work/traces" "$M3_ALT_BINDINGS_REPORT" "vulpra-bin"
  echo 'PASS: original graphical alternate Vulpra executable runtime bindings observed'
else
  python3 "$repo/ci/m3-vulpra-bin-version-reconcile.py" \
    --traces "$work/traces" --static "$static" --output "$report"
  echo 'PASS: alternate exact-source compiled Vulpra ELF graphical startup version checks verified'
fi
