#!/usr/bin/env bash
# Guarded fast-forward of the pinned Vulpra workstation checkout.
# Never discards unverified local build-system patches.
set -Eeuo pipefail
REPO="${1:-$HOME/Code/Apps/vulpra}"
cd -- "$REPO"
REPO=$(pwd -P)
for cmd in git cmp mktemp cp sha256sum date; do
  command -v "$cmd" >/dev/null || { echo "ERROR: Missing $cmd" >&2; exit 2; }
done
[[ "$(git branch --show-current)" == main ]] || {
  echo 'STOP: Local branch is not main. No source changes made.' >&2; exit 3;
}
[[ "$(git config --bool core.sparseCheckout || true)" != true ]] || {
  echo 'STOP: Sparse checkout enabled; do not fast-forward incomplete sources.' >&2; exit 3;
}
origin=$(git remote get-url origin)
if [[ "${VULPRA_SYNC_ALLOW_TEST_REMOTE:-0}" != 1 ]]; then
  case "$origin" in
    https://github.com/sguzman/vulpra|https://github.com/sguzman/vulpra.git|git@github.com:sguzman/vulpra|git@github.com:sguzman/vulpra.git) ;;
    *) echo "STOP: Unexpected origin URL: $origin" >&2; exit 3 ;;
  esac
fi
if ! git diff --cached --quiet; then
  echo 'STOP: Staged changes exist. Nothing modified.' >&2; exit 4;
fi
files=(python/mozbuild/mozbuild/frontend/emitter.py python/mozbuild/mozbuild/testing.py)
mapfile -t changed < <(git status --porcelain=v1 --untracked-files=normal)
for item in "${changed[@]}"; do
  permitted=false
  for p in "${files[@]}"; do
    [[ "$item" == " M $p" ]] && permitted=true
  done
  if [[ "$permitted" != true ]]; then
    echo "STOP: Unexpected working-tree change: $item" >&2
    echo 'No files altered. Review the worktree before syncing.' >&2
    exit 4
  fi
done
local_commit=$(git rev-parse HEAD)
printf 'Local commit: %s\n' "$local_commit"
echo 'Fetching remote main (Git metadata only, not source files)...'
git fetch --no-tags origin main
remote_commit=$(git rev-parse FETCH_HEAD)
printf 'Remote commit: %s\n' "$remote_commit"
git merge-base --is-ancestor "$local_commit" "$remote_commit" || {
  echo 'STOP: Histories diverged, so no merge was attempted.' >&2; exit 5;
}
if [[ "$local_commit" == "$remote_commit" ]]; then
  echo 'Already at remote commit; working tree unchanged.'
  exit 0
fi

# The only accepted dirty files are the two proven build patches; compare
# against the *actual fetched remote contents* before any source modification.
for p in "${files[@]}"; do
  [[ -f "$p" && ! -L "$p" ]] || {
    echo "STOP: Missing or nonregular source: $p" >&2; exit 5;
  }
  target=$(mktemp)
  git show "FETCH_HEAD:$p" > "$target" || { rm -f "$target"; exit 5; }
  if ! cmp -s -- "$p" "$target"; then
    rm -f "$target"
    echo "STOP: $p differs from remote main; source preserved." >&2
    echo "Inspect differences: git diff -- $p" >&2
    exit 6
  fi
  rm -f "$target"
done
if [[ -n "$(git diff --summary -- "${files[@]}")" ]]; then
  echo 'STOP: Build patch has a file-mode change, not just matching contents.' >&2
  exit 6
fi
gitdir=$(git rev-parse --absolute-git-dir)
stamp=$(date -u +%Y%m%d-%H%M%S)-$$
backup="$gitdir/vulpra-native-build/sync-backups/$stamp"
mkdir -p "$backup/files"
printf 'local=%s\nremote=%s\norigin=%s\n' "$local_commit" "$remote_commit" "$origin" > "$backup/commits.txt"
git diff --binary -- "${files[@]}" > "$backup/local-changes.patch"
for p in "${files[@]}"; do
  mkdir -p "$backup/files/$(dirname "$p")"
  cp -p -- "$p" "$backup/files/$p"
  (cd "$backup/files" && sha256sum "$p") >> "$backup/local-file-hashes.sha256"
done
echo "Original local source files backed up at $backup"

# Source only: the existing working native binary/package remain untouched.
# Temporarily remove these exact matched local modifications, fast-forward,
# and verify restored remote content byte for byte. Restore copies on failure.
success=false
recover() {
  status=$?
  if [[ "$success" != true ]]; then
    echo 'Sync incomplete; restoring saved workstation build patches.' >&2
    for p in "${files[@]}"; do
      cp -p -- "$backup/files/$p" "$p" || true
    done
    echo "Backups: $backup" >&2
  fi
  exit "$status"
}
trap recover EXIT
git restore --worktree --source=HEAD -- "${files[@]}"
git merge --ff-only "$remote_commit"
for p in "${files[@]}"; do
  cmp -s "$p" "$backup/files/$p" || {
    echo "ERROR: Source contents changed unexpectedly: $p" >&2
    exit 7
  }
done
if [[ -n "$(git status --porcelain=v1 --untracked-files=normal)" ]]; then
  echo 'ERROR: Worktree not clean after fast-forward.' >&2
  exit 7
fi
success=true
trap - EXIT
echo "PASS: Local main fast-forwarded to $(git rev-parse HEAD)."
echo 'PASS: Both local build patch files match remote bytes exactly.'
echo 'PASS: Working tree clean; future git pull --ff-only works while it remains clean.'
echo "Patch backup and original file copies: $backup"
