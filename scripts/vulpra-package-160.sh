#!/usr/bin/env bash
# Package the actual Firefox 160.0.1 Vulpra compiled from committed main.
# No second Firefox source tree, CI browser archive, or system installation.
set -Eeuo pipefail
umask 077
die() { printf 'Vulpra main package: %s\n' "$*" >&2; exit 2; }
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
obj="$repo/obj-vulpra-main-160"
config="$HOME/.cache/vulpra/main160/mozconfig"
if [[ "$#" == 1 && "$1" == --preflight ]]; then
  preflight=1
elif [[ "$#" == 0 ]]; then
  preflight=0
else
  die 'package takes no arguments: ./nix/vulpra package'
fi
[[ "$(git -C "$repo" symbolic-ref -q --short HEAD || true)" == main ]] ||
  die 'package must use main, not an alternate branch'
[[ "$(git -C "$repo" show HEAD:browser/config/version.txt 2>/dev/null)" == 160.0.1 &&
   "$(cat "$repo/browser/config/version.txt")" == 160.0.1 ]] ||
  die 'main is not committed Firefox 160.0.1'
[[ -f "$config" && ! -L "$obj" ]] || die 'local main build config missing or unsafe; build main first'
[[ -x "$obj/dist/bin/vulpra" && -f "$obj/dist/bin/application.ini" ]] ||
  die 'native main Vulpra executable not built yet'
grep -Fxq 'Name=Vulpra' "$obj/dist/bin/application.ini" ||
  die 'compiled application identity is not Vulpra'
grep -Fxq 'Version=160.0.1' "$obj/dist/bin/application.ini" ||
  die 'compiled browser is not Firefox 160.0.1'
if (( preflight )); then
  echo 'PASS: locally compiled Firefox160.0.1 from main is available for packaging'
  exit 0
fi
[[ "${VULPRA_NIX_DEV:-}" == 1 ]] ||
  die 'package requires pinned Nix developer shell: ./nix/vulpra package'
# ci/package-smoke-local.sh owns and holds the SAME Git build.lock used by
# the main builder. Never take an outer lock then deadlock the smoke script.
export MOZCONFIG="$config"
export VULPRA_OBJDIR="$obj"
exec bash "$repo/ci/package-smoke-local.sh" "$repo"
