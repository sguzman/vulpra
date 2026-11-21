#!/usr/bin/env bash
# Disposable, no-Nix Vulpra security-QA worktree and copied runtime.
# NEVER builds, launches, or selects the persistent dogfooding profile.
set -Eeuo pipefail
umask 077

die() { printf 'Vulpra security QA: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'HELP'
Vulpra security QA, separate from the everyday Vulpra profile and executable

  ./nix/vulpra security-qa status    Read-only QA worktree/snapshot status
  ./nix/vulpra security-qa setup     Create detached sibling source worktree
  ./nix/vulpra security-qa snapshot  Copy built Vulpra binary into QA worktree
  ./nix/vulpra security-qa headless  Offline temporary-profile screenshot smoke

Setup does NOT compile, download, install, stop, restart or launch a browser.
Snapshot can use substantial disk space, but never writes into the live
obj-vulpra-main-160 directory. Headless is opt-in and never opens a GUI window.
QA snapshots have independent HOME, XDG data/cache/config and Firefox profile.
No automatic switching/promotion to the daily browser is performed.
HELP
}

[[ "$#" -le 1 ]] || die 'expected one subcommand: status|setup|snapshot|headless'
action="${1:-status}"
case "$action" in
  help|-h|--help) usage; exit 0 ;;
  status|setup|snapshot|headless) ;;
  *) die "unknown action: $action" ;;
esac

source_repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ -d "$source_repo/.git" && -f "$source_repo/AGENTS.md" &&
   -f "$source_repo/browser/config/version.txt" ]] ||
  die 'must start from the regular Vulpra source checkout, not a QA worktree'
[[ "$(git -C "$source_repo" rev-parse --show-toplevel)" == "$source_repo" ]] ||
  die 'source directory is not the expected Git checkout'
[[ "$(git -C "$source_repo" symbolic-ref -q --short HEAD || :)" == main ]] ||
  die 'source checkout must remain on main; no branch switching allowed'
worktree="$(dirname -- "$source_repo")/vulpra-security-qa"
state="$worktree/obj-vulpra-security-qa"
compiled="$source_repo/obj-vulpra-main-160/dist/bin"

valid_worktree() {
  [[ -d "$worktree" && ! -L "$worktree" ]] || return 1
  [[ "$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null || :)" == "$worktree" ]] || return 1
  # Detached QA worktree is registered in the SAME repo but cannot alter main's index.
  [[ -z "$(git -C "$worktree" symbolic-ref -q --short HEAD 2>/dev/null || :)" ]] || return 1
  git -C "$source_repo" worktree list --porcelain |
    grep -Fxq "worktree $worktree" || return 1
}
snapshot_path() {
  [[ -f "$state/active-snapshot" && ! -L "$state/active-snapshot" ]] ||
    die 'no QA snapshot selected; use security-qa snapshot first'
  local name
  IFS= read -r name < "$state/active-snapshot"
  [[ "$name" =~ ^[0-9a-f]{12}-[0-9a-f]{12}$ ]] ||
    die 'invalid QA snapshot selector'
  printf '%s/snapshots/%s/app\n' "$state" "$name"
}
valid_app() {
  local dir="$1"
  [[ -d "$dir" && ! -L "$dir" && -x "$dir/vulpra" &&
     -f "$dir/application.ini" && ! -L "$dir/application.ini" ]] || return 1
  grep -Fxq 'Name=Vulpra' "$dir/application.ini" &&
    grep -Fxq 'Version=160.0.1' "$dir/application.ini"
}
case "$action" in
  status)
    printf 'Daily Vulpra checkout: %s\n' "$source_repo"
    printf 'Daily browser untouched: yes (status is read-only)\n'
    if valid_worktree; then
      printf 'QA worktree: ready (%s)\n' "$worktree"
      printf 'QA source commit: %s\n' "$(git -C "$worktree" rev-parse --short=12 HEAD)"
    else
      printf 'QA worktree: not set up\n'
    fi
    if [[ -f "$state/active-snapshot" ]]; then
      printf 'QA snapshot: %s\n' "$(cat -- "$state/active-snapshot")"
    else
      printf 'QA snapshot: none\n'
    fi
    exit 0
    ;;
  setup)
    [[ ! -e "$worktree" && ! -L "$worktree" ]] ||
      die "refusing to overwrite existing destination: $worktree"
    [[ "$(cat "$source_repo/browser/config/version.txt")" == 160.0.1 ]] ||
      die 'main working source is not Firefox 160.0.1'
    # The pinned source is a detached commit, never an alternative main branch.
    commit="$(git -C "$source_repo" rev-parse HEAD)"
    git -C "$source_repo" worktree add --detach -- "$worktree" "$commit"
    valid_worktree || die 'worktree registry verification failed'
    printf 'PASS: detached QA source worktree created at %s\n' "$worktree"
    echo 'LIMIT: no QA executable, separate build or browser runtime was created'
    exit 0
    ;;
  snapshot)
    valid_worktree || die 'QA worktree missing or invalid; run security-qa setup'
    [[ ! -L "$state" && ! -L "$state/snapshots" &&
       ! -L "$state/active-snapshot" ]] ||
      die 'QA state must not contain symbolic-link entrypoints'
    valid_app "$compiled" || die 'current native compiled Vulpra 160.0.1 is missing'
    [[ ! -L "$compiled" && ! -L "$compiled/vulpra" ]] ||
      die 'refusing linked source executable or binary directory'
    # Require exact committed code/QA baseline alignment. This proves source
    # pinning only, NOT which source compiled the source binary.
    source_commit="$(git -C "$source_repo" rev-parse HEAD)"
    qa_commit="$(git -C "$worktree" rev-parse HEAD)"
    [[ "$qa_commit" == "$source_commit" ]] ||
      die 'QA source is at an older commit; do not silently snapshot a different source'
    binary_sha="$(sha256sum "$compiled/vulpra" | cut -d' ' -f1)"
    identifier="${source_commit:0:12}-${binary_sha:0:12}"
    target="$state/snapshots/$identifier"
    [[ ! -e "$target" && ! -L "$target" ]] ||
      die "QA snapshot already exists; no files overwritten: $identifier"
    mkdir -p -m 0700 -- "$state/snapshots"
    tmp="$(mktemp -d "$state/snapshots/.staging.XXXXXXXX")"
    # The trap is limited to a fresh QA-only staging directory.
    cleanup() { if [[ -n "${tmp:-}" && -d "$tmp" ]]; then rm -rf -- "$tmp"; fi; }
    trap cleanup EXIT
    cp -aL -- "$compiled" "$tmp/app"
    valid_app "$tmp/app" || die 'copied QA binary was incomplete'
    [[ "$(sha256sum "$tmp/app/vulpra" | cut -d' ' -f1)" == "$binary_sha" ]] ||
      die 'copied QA executable checksum changed during snapshot'
    [[ "$(sha256sum "$tmp/app/application.ini" | cut -d' ' -f1)" == "$(sha256sum "$compiled/application.ini" | cut -d' ' -f1)" ]] ||
      die 'QA application identity changed during snapshot'
    printf 'source_commit=%s\nbinary_sha256=%s\n' \
      "$source_commit" "$binary_sha" > "$tmp/manifest.txt"
    mv -- "$tmp" "$target"
    tmp=""
    printf '%s\n' "$identifier" > "$state/active-snapshot.new"
    mv -- "$state/active-snapshot.new" "$state/active-snapshot"
    printf 'PASS: independent, checksum-verified QA runtime snapshot %s\n' "$identifier"
    echo 'LIMIT: copied native binary is NOT proof of build-to-source reproducibility'
    exit 0
    ;;
  headless)
    valid_worktree || die 'QA worktree missing or invalid'
    app="$(snapshot_path)"
    valid_app "$app" || die 'QA runtime missing or invalid'
    [[ -L "$state" || -L "$state/snapshots" || -L "$app/vulpra" ]] &&
      die 'symbolic-link path in QA executable selection'
    runtime="$state/runtime"
    [[ ! -L "$runtime" ]] || die 'QA runtime must not be linked'
    mkdir -p -m 0700 -- "$runtime"
    run="$(mktemp -d "$runtime/run.XXXXXXXX")"
    mkdir -p -m 0700 -- "$run/home" "$run/data" "$run/cache" \
      "$run/config" "$run/profile"
    cat > "$run/smoke.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>Vulpra private QA</title></head>
<body><h1>Offline local security-QA fixture</h1></body></html>
HTML
    set +e
    timeout 90 env -i PATH="$PATH" HOME="$run/home" LANG=C.UTF-8 \
      XDG_DATA_HOME="$run/data" XDG_CACHE_HOME="$run/cache" \
      XDG_CONFIG_HOME="$run/config" MOZ_HEADLESS=1 \
      "$app/vulpra" --no-remote --new-instance --profile "$run/profile" \
      --headless --screenshot "$run/result.png" \
      "file://$run/smoke.html" > "$run/browser.log" 2>&1
    result=$?
    set -e
    [[ "$result" -eq 0 ]] || die "QA browser exited $result; private log: $run/browser.log"
    [[ -s "$run/result.png" ]] ||
      die 'QA browser did not generate a screenshot'
    [[ "$(head -c 8 "$run/result.png" | od -An -tx1 | tr -d ' \n')" == 89504e470d0a1a0a ]] ||
      die 'QA screenshot is not PNG'
    printf 'PASS: isolated Vulpra QA headless screenshot (%s)\n' "$run/result.png"
    echo 'LIMIT: smoke is not a sandbox, TLS or Safe Browsing security acceptance'
    ;;
esac
