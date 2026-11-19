#!/usr/bin/env bash
# Package and privately smoke the locally compiled Firefox 160.0.1 Vulpra.
# Preserve the old source/objdir and every installed Firefox profile.
set -Eeuo pipefail
umask 077
die() { printf 'Vulpra local package: %s\n' "$*" >&2; exit 2; }
preflight=0
if [[ "$#" == 1 && "$1" == --preflight ]]; then
  preflight=1
elif [[ "$#" != 0 ]]; then
  die 'package takes no arguments: ./nix/vulpra package'
fi
# A read-only readiness check is performed by the launcher before Nix is
# entered. Packaging itself still requires the exact pinned Nix toolchain.
if (( preflight == 0 )); then
  [[ "${VULPRA_NIX_DEV:-}" == 1 ]] ||
    die 'requires pinned Nix developer shell: ./nix/vulpra package'
fi
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="${VULPRA_BUILD_DIR:-$HOME/Code/Builds/vulpra-160.0.1}"
cache="${VULPRA_SOURCE_CACHE:-$HOME/.cache/vulpra/mozilla}"
expected_tree=d6f7faf6583831a58d127480db54b5bcd5ab5949
expected_commit=58fed86b1b6864ad71b83c910a879d6f1a6b678b
[[ "$work" == /* && "$cache" == /* ]] ||
  die 'build and cache directories must be absolute'
[[ ! -L "$work" && ! -L "$cache" ]] ||
  die 'symlinked build/cache root refused'
source="$work/source"
obj="$source/obj-vulpra-linux"
config="$work/config/mozconfig"
index="$work/candidate.index"
[[ ( -d "$source/.git" || -f "$source/.git" ) && -f "$source/mach" && -s "$index" &&
   -s "$work/prepared-source-tree.sha" && -s "$config" ]] ||
  die 'verified source/config absent; first run ./nix/vulpra build'
[[ "$(cat "$work/prepared-source-tree.sha")" == "$expected_tree" ]] ||
  die 'prepared source identity changed'
[[ "$(git -C "$source" rev-parse HEAD)" == "$expected_commit" ]] ||
  die 'prepared source is not official Firefox 160.0.1'
[[ "$(GIT_INDEX_FILE="$index" git -C "$source" write-tree)" == "$expected_tree" ]] ||
  die 'candidate Git tree no longer matches compiled source'
GIT_INDEX_FILE="$index" git -C "$source" diff --quiet -- ||
  die 'on-disk source differs from verified candidate index'
[[ -x "$obj/dist/bin/vulpra" && -s "$obj/dist/bin/application.ini" ]] ||
  die 'local native Vulpra is not compiled; first run ./nix/vulpra build'
grep -Fxq 'Name=Vulpra' "$obj/dist/bin/application.ini" ||
  die 'compiled binary identity is not Vulpra'
grep -Fxq 'Version=160.0.1' "$obj/dist/bin/application.ini" ||
  die 'compiled binary is not Firefox 160.0.1'
[[ -f "$repo/ci/package-smoke-local.sh" ]] ||
  die 'existing local package+smoke workflow missing'
if (( preflight == 1 )); then
  echo 'PASS: authenticated native Vulpra 160.0.1 exists; package may enter Nix'
  exit 0
fi
command -v flock >/dev/null || die 'missing flock'
mkdir -p -- "$cache"
# Hold the same exclusive lock as the source build for the ENTIRE package
# smoke. Use FD 8: the downstream package-smoke script opens FD 9 for its
# own lock, and would otherwise silently release the outer build lock.
exec 8>"$cache/vulpra160-build.lock"
flock -n 8 ||
  die 'another Firefox160 source/build/package task is running'
echo 'Packaging and headless-testing LOCAL Firefox 160.0.1 Vulpra.'
echo 'No CI binary download; running existing package-smoke with private HOME.'
export MOZCONFIG="$config"
exec bash "$repo/ci/package-smoke-local.sh" "$source"
