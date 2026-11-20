#!/usr/bin/env bash
# Build committed Firefox 160.0.1 Vulpra FROM MAIN, not a second source clone.
# All source remains under this checkout. No Mozilla Git fetch or CI browser.
set -Eeuo pipefail
umask 077
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
obj="$repo/obj-vulpra-main-160"
config="$HOME/.cache/vulpra/main160/mozconfig"
version=160.0.1
action=build
jobs=8
die() { printf 'Vulpra main build: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'HELP'
Vulpra native build: Firefox 160.0.1 committed directly on main.

  ./nix/vulpra status            Read-only source and native build status
  ./nix/vulpra build             Compile source in the CURRENT main checkout
  ./nix/vulpra build --jobs 8    Set native build parallelism
  ./nix/vulpra run               Launch locally compiled Vulpra, isolated
  ./nix/vulpra package           Package and smoke the native main build

The Firefox source is ALREADY ON MAIN. No Mozilla source checkout, downloader,
alternate development branch, or precompiled CI browser is used. Nix and mach
may still acquire missing build TOOLCHAIN dependencies during compilation.
The historical Firefox159 obj-vulpra-linux and installed Firefox are untouched.
HELP
}
while (($#)); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --status) action=status; shift ;;
    --preflight) action=preflight; shift ;;
    --run) action=run; shift ;;
    --configure) action=configure; shift ;;
    --jobs)
      (($# >= 2)) || die 'missing --jobs value'
      jobs="$2"; shift 2 ;;
    --fetch-source)
      die 'Firefox 160.0.1 is already committed on main; --fetch-source is obsolete and disabled' ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ "$jobs" =~ ^[1-9][0-9]?$ ]] || die '--jobs must be between 1 and 99'
[[ -f "$repo/browser/config/version.txt" ]] ||
  die 'source version file missing from this checkout'
is_native() {
  [[ -x "$obj/dist/bin/vulpra" &&
     -f "$obj/dist/bin/application.ini" ]] &&
  grep -Fxq 'Name=Vulpra' "$obj/dist/bin/application.ini" &&
  grep -Fxq "Version=$version" "$obj/dist/bin/application.ini"
}
if [[ "$action" == status ]]; then
  printf 'Vulpra source: %s\n' "$repo"
  printf 'Branch: %s\n' "$(git -C "$repo" symbolic-ref -q --short HEAD || echo detached)"
  printf 'Tracked source version: %s\n' "$(git -C "$repo" show HEAD:browser/config/version.txt 2>/dev/null || echo unknown)"
  printf 'Working source version: %s\n' "$(cat "$repo/browser/config/version.txt")"
  printf 'Native object directory: %s\n' "$obj"
  printf 'Native Firefox 160.0.1 Vulpra: %s\n' \
    "$(if is_native; then echo compiled; else echo missing; fi)"
  echo 'No source download, Nix evaluation, compilation or profile changes.'
  exit 0
fi
# This validator is also invoked *before* nom/Nix can download build tools.
[[ "$(git -C "$repo" symbolic-ref -q --short HEAD || true)" == main ]] ||
  die 'expected main branch; refusing to build from any alternate branch'
[[ "$(git -C "$repo" show HEAD:browser/config/version.txt 2>/dev/null)" == "$version" &&
   "$(cat "$repo/browser/config/version.txt")" == "$version" ]] ||
  die 'main checkout does not contain committed Firefox 160.0.1 source'
[[ "$(git -C "$repo" config --bool core.sparseCheckout || true)" != true ]] ||
  die 'sparse source checkout refused; main must contain complete source'
[[ -f "$repo/mach" && -f "$repo/ci/mozconfig-linux" ]] ||
  die 'missing committed Mozilla build entrypoint or mozconfig'
missing="$(git -C "$repo" ls-files -d | sed -n '1p')" ||
  die 'unable to verify tracked source checkout'
[[ -z "$missing" ]] || die "tracked source missing: $missing"
[[ -s "$repo/toolkit/crashreporter/google-breakpad/src/third_party/lss/linux_syscall_support.h" ]] ||
  die 'required committed Mozilla Breakpad header is absent'
if [[ "$action" == preflight ]]; then
  echo 'PASS: Firefox 160.0.1 source is committed and materialized on main; no download needed'
  exit 0
fi
if [[ "$action" == run ]]; then
  is_native || die 'native Vulpra 160.0.1 not built yet; ./nix/vulpra build'
  [[ -f "$repo/packaging/vulpra" ]] || die 'private profile launcher missing'
  [[ ! -L "$obj/dist/bin/vulpra-launch" ]] || die 'refusing linked launcher'
  install -m 0755 -- "$repo/packaging/vulpra" "$obj/dist/bin/vulpra-launch"
  mkdir -p -m 0700 -- "$obj/profile-data"
  exec env XDG_DATA_HOME="$obj/profile-data" "$obj/dist/bin/vulpra-launch"
fi
[[ "$action" == configure || "$action" == build ]] ||
  die 'unknown build operation'
[[ "${VULPRA_NIX_DEV:-}" == 1 ]] ||
  die 'build/configure requires the pinned shell: ./nix/vulpra build'
[[ -n "${VULPRA_NIX_LIBCLANG_PATH:-}" &&
   -d "$VULPRA_NIX_LIBCLANG_PATH" ]] ||
  die 'Nix libclang path missing'
for command_name in git flock sed bash python3; do
  command -v "$command_name" >/dev/null || die "required tool unavailable: $command_name"
done
logdir="$(git -C "$repo" rev-parse --path-format=absolute --git-path vulpra-native-build)"
mkdir -p -- "$logdir"
exec 8>"$logdir/build.lock"
flock -n 8 || die 'another native Vulpra build or package is active'
[[ ! -L "$obj" && ! -L "$(dirname -- "$config")" ]] ||
  die 'refusing linked object directory or mozconfig cache'
mkdir -p -m 0700 -- "$(dirname -- "$config")"
# Derive from existing Firefox build settings; only the NEW objdir,
# job count, optional sccache and Nix libclang path are overridden.
sed -e 's|^mk_add_options MOZ_OBJDIR=.*|mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-main-160|' \
    -e '/^ac_add_options --with-ccache=sccache$/d' \
    -e '/^mk_add_options MOZ_PARALLEL_BUILD=/d' \
    "$repo/ci/mozconfig-linux" > "$config"
printf 'mk_add_options MOZ_PARALLEL_BUILD=%s\n' "$jobs" >> "$config"
printf 'ac_add_options --with-libclang-path=%s\n' "$VULPRA_NIX_LIBCLANG_PATH" >> "$config"
if command -v sccache >/dev/null; then
  printf '%s\n' 'ac_add_options --with-ccache=sccache' >> "$config"
fi
export MOZCONFIG="$config"
echo "Source: $repo (main, Firefox $version)"
echo "Object directory: $obj (old Firefox159 object directory remains untouched)"
echo "No separate upstream checkout, no binary/artifact download."
cd "$repo"
if [[ "$action" == configure ]]; then
  exec ./mach configure 8>&-
fi
./mach configure 8>&-
./mach build 8>&-
is_native || die 'mach build returned success without a Firefox160.0.1 Vulpra native executable'
echo "PASS: compiled committed main at $obj/dist/bin/vulpra"
