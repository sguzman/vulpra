#!/usr/bin/env bash
# Explicit QA-only native build from a DETACHED security worktree.
# Never changes main, live native objdir, profiles, or installed browser.
set -Eeuo pipefail
umask 077
die() { printf 'Vulpra QA build: %s\n' "$*" >&2; exit 2; }

action="${1:-}"
[[ "$#" -ge 1 ]] || die 'usage: --preflight | --build [--jobs N]'
shift
jobs=2
while (($#)); do
  case "$1" in
    --jobs)
      (($# >= 2)) || die 'missing --jobs count'
      jobs="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ "$action" == --preflight || "$action" == --build ]] ||
  die 'only --preflight and --build are supported'
[[ "$jobs" =~ ^[1-9][0-9]?$ ]] ||
  die 'jobs must be between 1 and 99'

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
main="$(dirname -- "$repo")/vulpra"
[[ "$(basename -- "$repo")" == vulpra-security-qa && -f "$repo/.git" &&
   -d "$main/.git" && ! -L "$repo" ]] ||
  die 'refusing native QA build outside registered sibling worktree'
[[ "$(git -C "$repo" rev-parse --show-toplevel)" == "$repo" &&
   "$(git -C "$main" rev-parse --show-toplevel)" == "$main" ]] ||
  die 'expected two independent Git worktree roots'
[[ -z "$(git -C "$repo" symbolic-ref -q --short HEAD || :)" &&
   "$(git -C "$main" symbolic-ref -q --short HEAD || :)" == main ]] ||
  die 'QA must be detached and daily source must stay on main'
git -C "$main" worktree list --porcelain |
  grep -Fxq "worktree $repo" ||
  die 'QA worktree not registered with daily repository'
[[ "$(cat "$repo/browser/config/version.txt")" == 160.0.1 &&
   "$(git -C "$repo" show HEAD:browser/config/version.txt)" == 160.0.1 ]] ||
  die 'expected Firefox 160.0.1 QA source'
[[ "$(git -C "$repo" config --bool core.sparseCheckout || :)" != true ]] ||
  die 'sparse source worktree is not buildable'
[[ -f "$repo/mach" && -f "$repo/ci/mozconfig-linux" ]] ||
  die 'missing full source build entrypoint/mozconfig'
missing="$(git -C "$repo" ls-files -d | sed -n '1p')"
[[ -z "$missing" ]] || die "missing tracked QA source file: $missing"
obj="$repo/obj-vulpra-security-qa-build"
state="$repo/obj-vulpra-security-qa"
config="$state/native.mozconfig"
[[ ! -L "$obj" && ! -L "$state" && ! -L "$config" ]] ||
  die 'QA build and configuration paths must never be symlinks'
[[ "$obj" != "$main/obj-vulpra-main-160" ]] ||
  die 'refusing main object directory'
if [[ "$action" == --preflight ]]; then
  printf 'PASS: detached full-source Firefox 160.0.1 QA worktree (%s)\n' \
    "$(git -C "$repo" rev-parse --short=12 HEAD)"
  printf 'QA object directory: %s (isolated from main)\n' "$obj"
  echo 'No Nix realization, compilation, system/browser/profile changes.'
  exit 0
fi
[[ "${VULPRA_NIX_DEV:-}" == 1 &&
   -n "${VULPRA_NIX_LIBCLANG_PATH:-}" &&
   -d "$VULPRA_NIX_LIBCLANG_PATH" ]] ||
  die 'QA build requires pinned Vulpra Nix developer environment'
for tool in flock git bash sed python3; do
  command -v "$tool" >/dev/null || die "required tool missing: $tool"
done
# Main's existing local build may contain a generated/untracked Breakpad
# header. Never mutate main; copy this single build input only into QA if
# a newly created worktree legitimately lacks it.
header="toolkit/crashreporter/google-breakpad/src/third_party/lss/linux_syscall_support.h"
if [[ ! -s "$repo/$header" ]]; then
  [[ ! -e "$repo/$header" && ! -L "$repo/$header" &&
     -s "$main/$header" && ! -L "$main/$header" ]] ||
    die 'missing QA Breakpad header and no safe local source for it'
  [[ "$(realpath -m -- "$repo/$header")" == "$repo/$header" ]] ||
    die 'Breakpad header destination escapes QA source tree through a symlink'
  mkdir -p -- "$(dirname -- "$repo/$header")"
  install -m 0644 -- "$main/$header" "$repo/$header"
fi
mkdir -p -m 0700 -- "$state"
exec 9>"$state/build.lock"
flock -n 9 || die 'another QA native build is active'
temp="$state/native.mozconfig.new"
[[ ! -e "$temp" && ! -L "$temp" ]] ||
  die 'stale QA configuration temporary file; do not overwrite'
sed -e 's|^mk_add_options MOZ_OBJDIR=.*|mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-security-qa-build|' \
    -e '/^ac_add_options --with-ccache=sccache$/d' \
    -e '/^mk_add_options MOZ_PARALLEL_BUILD=/d' \
    "$repo/ci/mozconfig-linux" > "$temp"
printf 'mk_add_options MOZ_PARALLEL_BUILD=%s\n' "$jobs" >> "$temp"
printf 'ac_add_options --with-libclang-path=%s\n' "$VULPRA_NIX_LIBCLANG_PATH" >> "$temp"
if command -v sccache >/dev/null; then
  printf '%s\n' 'ac_add_options --with-ccache=sccache' >> "$temp"
fi
mv -- "$temp" "$config"
export MOZCONFIG="$config"
cd "$repo"
printf 'QA source: %s\nQA object: %s\n' "$repo" "$obj"
echo 'The running main Vulpra executable and profile are not being modified.'
./mach configure 9>&-
./mach build 9>&-
[[ -x "$obj/dist/bin/vulpra" &&
   -f "$obj/dist/bin/application.ini" ]] ||
  die 'native QA build returned without a browser executable'
grep -Fxq 'Name=Vulpra' "$obj/dist/bin/application.ini" &&
  grep -Fxq 'Version=160.0.1' "$obj/dist/bin/application.ini" ||
  die 'native QA build has incorrect application identity/version'
printf 'PASS: independently compiled Vulpra security QA executable: %s\n' "$obj/dist/bin/vulpra"
echo 'LIMIT: compilation does not prove security acceptance or package integrity'
