#!/usr/bin/env bash
# Build the pinned Firefox 160.0.1 Vulpra BYOB candidate locally.
# No CI binary download, Git network operation, privilege escalation, or system install.
set -euo pipefail
umask 077

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
old_sha=2887d9de1f69c0e9776413da80e7ba0d1225dd9b
hotfix_sha=58fed86b1b6864ad71b83c910a879d6f1a6b678b
candidate_tree=d6f7faf6583831a58d127480db54b5bcd5ab5949
branding_sha=ca4ef5eea3e63b75cc0db0ce8e036dccce1b8511
brand_path=browser/branding/unofficial/pref/firefox-branding.js
brand_blob=ae3fd50a6aee0ad58933dca09db39b7b87c0eb5e

usage() {
  cat <<'HELP'
Usage:
  bash scripts/build-firefox160-local.sh prepare --old-source PATH --hotfix-source PATH --work-dir PATH
  bash scripts/build-firefox160-local.sh build --work-dir PATH [--jobs N]
  bash scripts/build-firefox160-local.sh run --work-dir PATH [-- browser flags]

prepare: uses EXISTING authenticated official Mozilla Git checkouts, copies
         verified Vulpra overlays into an independent local clone, no downloads.
build:   uses the prepared source and local Mozilla toolchain; incremental on
         subsequent invocations. Build tools may need dependencies installed.
run:     starts locally compiled Vulpra with a private profile under work-dir.

No network checkout, CI artifact download, sudo/doas, Nix mutation, system
installation, or profile modification occurs in this script. On first use you
must already have official Firefox 160.0 and 160.0.1 Git source checkouts.
HELP
}
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
mode="${1:-}"
case "$mode" in help|-h|--help) usage; exit 0;; prepare|build|run) shift;; *) usage >&2; exit 2;; esac
old='' hotfix='' work='' jobs=4
while (($#)); do
  case "$1" in
    --old-source) (($# >= 2)) || fail 'missing --old-source value'; old="$2"; shift 2;;
    --hotfix-source) (($# >= 2)) || fail 'missing --hotfix-source value'; hotfix="$2"; shift 2;;
    --work-dir) (($# >= 2)) || fail 'missing --work-dir value'; work="$2"; shift 2;;
    --jobs) (($# >= 2)) || fail 'missing --jobs value'; jobs="$2"; shift 2;;
    --) shift; break;;
    *) fail "unknown argument: $1";;
  esac
done
[[ -n "$work" ]] || fail 'specify --work-dir explicitly'
[[ "$work" == /* ]] || fail '--work-dir must be an absolute path'
[[ ! -L "$work" ]] || fail '--work-dir may not be a symlink'
work="$(realpath -m -- "$work")"
[[ "$jobs" =~ ^[1-9][0-9]?$ ]] || fail '--jobs must be between 1 and 99'
for cmd in git realpath find cp sort cmp sha256sum; do command -v "$cmd" >/dev/null || fail "missing dependency: $cmd"; done
[[ -d "$repo/.git" || -f "$repo/.git" ]] || fail "Vulpra repository checkout not found at $repo"
source_dir="$work/source"
index="$work/candidate.index"

if [[ "$mode" == prepare ]]; then
  [[ -n "$old" && -n "$hotfix" ]] || fail 'prepare needs both --old-source and --hotfix-source'
  [[ -d "$old" && -d "$hotfix" ]] || fail 'official source checkouts must already exist; refusing network fetch'
  old="$(realpath -e -- "$old")"
  hotfix="$(realpath -e -- "$hotfix")"
  [[ "$old" != "$hotfix" ]] || fail 'old and hotfix source roots must differ'
  for root in "$repo" "$old" "$hotfix"; do
    [[ "$work" != "$root" && "$work/" != "$root/"* && "$root/" != "$work/"* ]] || fail "work-dir overlaps source checkout: $root"
  done
  [[ ! -e "$work" ]] || fail 'work-dir already exists; choose a fresh path, or use build/run to reuse a prepared tree'
  [[ "$(git -C "$old" rev-parse HEAD)" == "$old_sha" ]] || fail 'old checkout is not official Firefox 160.0'
  [[ "$(git -C "$hotfix" rev-parse HEAD)" == "$hotfix_sha" ]] || fail 'hotfix checkout is not official Firefox 160.0.1'
  [[ -z "$(git -C "$old" status --porcelain)" && -z "$(git -C "$hotfix" status --porcelain)" ]] || fail 'official source checkout has uncommitted changes'
  [[ -f "$repo/ci/security-160-stage-overlay.sh" && -f "$repo/ci/security-160-stage-byob-branding.sh" && -f "$repo/ci/security-160-hotfix-assemble-tree.sh" ]] || fail 'required Vulpra source-staging scripts missing; select the Firefox 160 upgrade branch'
  git -C "$repo" cat-file -e "$branding_sha:$brand_path" || fail 'pinned BYOB branding commit not in local Vulpra Git; fetch repository history first'
  mkdir -m 700 -p -- "$work"
  git -C "$repo" show "$branding_sha:$brand_path" > "$work/branding.js"
  [[ "$(git hash-object "$work/branding.js")" == "$brand_blob" ]] || fail 'BYOB branding identity mismatch'
  bash "$repo/ci/security-160-stage-overlay.sh" --stage "$old" "$work/stage-original"
  bash "$repo/ci/security-160-stage-byob-branding.sh" --derive "$work/stage-original" "$work/branding.js" "$work/stage-byob"
  bash "$repo/ci/security-160-hotfix-assemble-tree.sh" --assemble "$old" "$hotfix" "$work/stage-byob" "$work/proof"
  proof="$work/proof/hotfix-candidate-tree-proof.json"
  [[ -s "$proof" ]] || fail 'source assembly proof missing'
  command -v jq >/dev/null || fail 'jq is required to inspect the proof'
  [[ "$(jq -r .candidate_git_tree "$proof")" == "$candidate_tree" ]] || fail 'source candidate is not the independently verified 160.0.1 tree'
  # Local clone: reuses local Git objects; never consults GitHub or pulls an artifact.
  GIT_NO_LAZY_FETCH=1 git clone --local --no-checkout -- "$hotfix" "$source_dir"
  GIT_NO_LAZY_FETCH=1 git -C "$source_dir" checkout --detach "$hotfix_sha"
  list="$work/proof/overlay-paths.txt"
  [[ -s "$list" && "$(wc -l < "$list")" -eq 28 ]] || fail 'expected exactly 28 authenticated source changes'
  (cd "$work/stage-byob" && find . -type f -printf '%P\n' | LC_ALL=C sort) > "$work/actual-paths.txt"
  cmp -s "$list" "$work/actual-paths.txt" || fail 'source overlays and proof have different file inventories'
  while IFS= read -r path; do
    case "$path" in ''|/*|../*|*/../*|*/..|./*) fail "unsafe overlay path: $path";; esac
    src="$work/stage-byob/$path" dst="$source_dir/$path"
    [[ -f "$src" && ! -L "$src" && ! -L "$dst" ]] || fail "unsafe source overlay: $path"
    [[ -d "$(dirname -- "$dst")" ]] || fail "unexpected missing Mozilla destination: $path"
    cp -p -- "$src" "$dst"
    [[ "$(git hash-object -- "$src")" == "$(git hash-object -- "$dst")" ]] || fail "copy changed overlay contents: $path"
  done < "$list"
  GIT_INDEX_FILE="$index" git -C "$source_dir" read-tree HEAD
  GIT_INDEX_FILE="$index" git -C "$source_dir" add -f --pathspec-from-file="$list"
  [[ "$(GIT_INDEX_FILE="$index" git -C "$source_dir" write-tree)" == "$candidate_tree" ]] || fail 'complete Vulpra Git tree does not match CI-authenticated exact source'
  [[ "$(git -C "$source_dir" rev-parse "$candidate_tree:dom/media/ChannelMediaDecoder.cpp")" == d688d7ec968395490c84c308eb0ddc241a7ba2ea ]] || fail 'official media hotfix missing'
  [[ "$(git -C "$source_dir" rev-parse "$candidate_tree:gfx/gl/GLBlitHelper.cpp")" == 0fb43a1429ef359313ebae7873ac3b2cd20fea64 ]] || fail 'official Linux graphics hotfix missing'
  [[ "$(cat "$source_dir/browser/config/version.txt")" == 160.0.1 ]] || fail 'not Firefox 160.0.1'
  printf '%s\n' "$candidate_tree" > "$work/prepared-source-tree.sha"
  echo 'PASS: isolated local Firefox 160.0.1 Vulpra source prepared; no network fetch or existing profile touched'
  echo "NEXT: bash scripts/build-firefox160-local.sh build --work-dir '$work'"
  exit 0
fi

[[ -d "$source_dir" && -s "$index" && -s "$work/prepared-source-tree.sha" ]] || fail 'work-dir has no verified prepared source; run prepare first'
[[ "$(cat "$work/prepared-source-tree.sha")" == "$candidate_tree" ]] || fail 'source provenance stamp changed'
[[ "$(git -C "$source_dir" rev-parse HEAD)" == "$hotfix_sha" ]] || fail 'local build source HEAD changed'
[[ "$(GIT_INDEX_FILE="$index" git -C "$source_dir" write-tree)" == "$candidate_tree" ]] || fail 'prepared source index was changed'
GIT_INDEX_FILE="$index" git -C "$source_dir" diff --exit-code -- >/dev/null || fail 'local source files differ from the verified Vulpra candidate; refusing silent overwrite'

if [[ "$mode" == build ]]; then
  [[ "${VULPRA_NIX_DEV:-}" == 1 ]] ||
    fail 'the original Nix developer shell is required: use ./nix/vulpra build'
  [[ -n "${VULPRA_NIX_LIBCLANG_PATH:-}" && -d "$VULPRA_NIX_LIBCLANG_PATH" ]] ||
    fail 'Nix libclang path missing; use ./nix/vulpra build'
  command -v python3 >/dev/null || fail 'Mozilla mach needs Python 3'
  mkdir -m 700 -p -- "$work/config"
  # The GitHub runner's mozconfig is also used locally, except the optional
  # sccache path and CI-only memory constraint are parameterized.
  sed -e '/^ac_add_options --with-ccache=sccache$/d' \
      -e '/^mk_add_options MOZ_PARALLEL_BUILD=/d' \
      "$repo/ci/mozconfig-linux" > "$work/config/mozconfig"
  if command -v sccache >/dev/null; then
    printf '%s\n' 'ac_add_options --with-ccache=sccache' >> "$work/config/mozconfig"
  fi
  printf 'mk_add_options MOZ_PARALLEL_BUILD=%s\n' "$jobs" >> "$work/config/mozconfig"
  printf 'ac_add_options --with-libclang-path=%s\n' "$VULPRA_NIX_LIBCLANG_PATH" >> "$work/config/mozconfig"
  echo 'Local source build (no CI binary): running Mozilla mach configure/build.'
  echo 'NOTE: Mozilla tooling may still fetch toolchain dependencies if not present locally.'
  (cd "$source_dir" && MOZCONFIG="$work/config/mozconfig" ./mach configure && MOZCONFIG="$work/config/mozconfig" ./mach build)
  [[ -x "$source_dir/obj-vulpra-linux/dist/bin/vulpra" ]] || fail 'build exited without a Vulpra native executable'
  echo "PASS: local native Vulpra compiled at $source_dir/obj-vulpra-linux/dist/bin/vulpra"
  echo "NEXT: bash scripts/build-firefox160-local.sh run --work-dir '$work'"
  exit 0
fi

binary_dir="$source_dir/obj-vulpra-linux/dist/bin"
[[ -x "$binary_dir/vulpra" ]] || fail 'local binary absent: run build first'
[[ -f "$repo/packaging/vulpra" ]] || fail 'isolated launcher template missing'
[[ ! -L "$binary_dir/vulpra-launch" ]] || fail 'refusing symlink launcher'
install -m 0755 -- "$repo/packaging/vulpra" "$binary_dir/vulpra-launch"
mkdir -m 700 -p -- "$work/profile-data"
exec env XDG_DATA_HOME="$work/profile-data" "$binary_dir/vulpra-launch" "$@"
