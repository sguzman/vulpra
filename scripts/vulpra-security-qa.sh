#!/usr/bin/env bash
# Disposable, no-Nix Vulpra security-QA worktree and copied runtime.
# NEVER builds, launches, or selects the persistent dogfooding profile.
set -Eeuo pipefail
umask 077

die() { printf 'Vulpra security QA: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'HELP'
Vulpra security QA, separate from the everyday Vulpra profile and executable
QA-only tests: run ~/Code/Apps/vulpra-security-qa/nix/vulpra security-qa accept

  ./nix/vulpra security-qa status    Read-only QA worktree/snapshot status
  ./nix/vulpra security-qa setup     Create detached sibling source worktree
  ./nix/vulpra security-qa sync      From QA: fetch+pin latest origin/main without changing daily checkout
  ./nix/vulpra security-qa snapshot  Copy built Vulpra binary into QA worktree
  ./nix/vulpra security-qa verify    Verify active copied QA runtime without launching
  ./nix/vulpra security-qa headless  Offline temporary-profile screenshot smoke
  ./nix/vulpra security-qa accept    Real copied-browser localhost TLS/WebExtension test
  ./nix/vulpra security-qa build [--jobs N]  Explicit separate native QA build
  ./nix/vulpra security-qa headless-build  Test compiled QA executable privately
  ./nix/vulpra security-qa style     Inspect collapsed/expanded tab group geometry in QA build

Setup does NOT compile, download, install, stop, restart or launch a browser.
Only the explicit 'build' operation enters Nix and compiles; default jobs=2.
Only QA's explicit 'sync' fetches Git data; test commands do not download source.
Snapshot can use substantial disk space, but never writes into the live
obj-vulpra-main-160 directory. Headless is opt-in and never opens a GUI window.
QA snapshots have independent HOME, XDG data/cache/config and Firefox profile.
No automatic switching/promotion to the daily browser is performed.
HELP
}

action="${1:-status}"
if (($#)); then shift; fi
case "$action" in
  help|-h|--help) usage; exit 0 ;;
  status|setup|sync|snapshot|verify|headless|headless-build|accept|style)
    (($# == 0)) || die "$action takes no extra arguments" ;;
  build)
    jobs=2
    if (($#)); then
      [[ "$#" -eq 2 && "$1" == --jobs && "$2" =~ ^[1-9][0-9]?$ ]] ||
        die 'usage: security-qa build [--jobs 1..99]'
      jobs="$2"
    fi ;;
  *) die "unknown action: $action" ;;
esac

# The QA worktree is a first-class execution root. Its test commands resolve
# scripts, binary snapshots, and outputs under QA -- not under daily main.
# Only source bootstrap/sync/snapshot ever require the main checkout's runner.
checkout="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
case "$(basename -- "$checkout")" in
  vulpra)
    source_repo="$checkout"
    worktree="$(dirname -- "$source_repo")/vulpra-security-qa"
    launcher_mode=main
    [[ -d "$source_repo/.git" && ! -L "$source_repo/.git" &&
       -f "$source_repo/AGENTS.md" &&
       -f "$source_repo/browser/config/version.txt" ]] ||
      die 'missing ordinary Vulpra main source checkout'
    [[ "$(git -C "$source_repo" symbolic-ref -q --short HEAD || :)" == main ]] ||
      die 'source checkout must remain on main; no branch switching allowed'
    ;;
  vulpra-security-qa)
    worktree="$checkout"
    source_repo="$(dirname -- "$worktree")/vulpra"
    launcher_mode=qa
    [[ -f "$worktree/.git" && ! -L "$worktree/.git" &&
       -d "$source_repo/.git" ]] ||
      die 'expected a registered detached QA worktree and sibling main Git metadata'
    [[ -z "$(git -C "$worktree" symbolic-ref -q --short HEAD || :)" ]] ||
      die 'QA source must stay detached; do not use the daily main branch here'
    ;;
  *)
    die 'security QA must be run from the Vulpra main or its detached sibling QA worktree'
    ;;
esac
[[ "$(git -C "$checkout" rev-parse --show-toplevel)" == "$checkout" ]] ||
  die 'source directory is not the expected Git checkout root'
state="$worktree/obj-vulpra-security-qa"
compiled="$source_repo/obj-vulpra-main-160/dist/bin"

valid_worktree() {
  [[ -d "$worktree" && ! -L "$worktree" &&
     -f "$worktree/.git" && ! -L "$worktree/.git" ]] || return 1
  [[ "$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null || :)" == "$worktree" ]] || return 1
  # The detached worktree shares Git objects, but no source checkout,
  # profile, executable or command entrypoint with daily main.
  [[ -z "$(git -C "$worktree" symbolic-ref -q --short HEAD 2>/dev/null || :)" ]] || return 1
  local shared_git main_git
  shared_git="$(realpath -e -- "$(git -C "$worktree" rev-parse --git-common-dir)")" || return 1
  main_git="$(realpath -e -- "$source_repo/.git")" || return 1
  [[ "$shared_git" == "$main_git" ]] || return 1
  git -C "$worktree" worktree list --porcelain |
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
verify_snapshot() {
  # Existing copies remain useful even after main/worktree move forward.
  # Check actual bytes and the identity recorded WHEN that copy was taken.
  valid_worktree || die 'registered security QA worktree not available'
  [[ ! -L "$state" && ! -L "$state/snapshots" ]] ||
    die 'linked QA state is not accepted'
  local app manifest ident commit binary_sha observed_sha ini_sha observed_ini
  app="$(snapshot_path)"
  valid_app "$app" || die 'QA copied Vulpra runtime missing or invalid'
  [[ ! -L "$app" && ! -L "$app/vulpra" ]] ||
    die 'linked QA executable or snapshot is not accepted'
  manifest="${app%/app}/manifest.txt"
  [[ -f "$manifest" && ! -L "$manifest" ]] ||
    die 'QA snapshot lacks its regular manifest'
  ident="$(cat -- "$state/active-snapshot")"
  commit="$(sed -n 's/^source_commit=//p' "$manifest")"
  binary_sha="$(sed -n 's/^binary_sha256=//p' "$manifest")"
  [[ "$commit" =~ ^[0-9a-f]{40}$ && "$binary_sha" =~ ^[0-9a-f]{64}$ ]] ||
    die 'malformed QA snapshot source or executable digest'
  [[ "$ident" == "${commit:0:12}-${binary_sha:0:12}" ]] ||
    die 'QA snapshot directory does not match recorded source and binary'
  observed_sha="$(sha256sum -- "$app/vulpra" | cut -d' ' -f1)"
  [[ "$observed_sha" == "$binary_sha" ]] ||
    die 'QA executable changed since its checksum-verified copy'
  ini_sha="$(sed -n 's/^application_ini_sha256=//p' "$manifest")"
  # Snapshots made before this check recorded only the ELF hash. Accept
  # their version-checked regular INI, but require the INI hash for new ones.
  if [[ -n "$ini_sha" ]]; then
    [[ "$ini_sha" =~ ^[0-9a-f]{64}$ ]] ||
      die 'malformed QA application.ini digest'
    observed_ini="$(sha256sum -- "$app/application.ini" | cut -d' ' -f1)"
    [[ "$observed_ini" == "$ini_sha" ]] ||
      die 'QA application.ini changed since snapshot'
  fi
  echo 'PASS: independent QA executable and manifest identity checksum verified'
  if [[ -z "$ini_sha" ]]; then
    echo 'LIMIT: legacy snapshot records only ELF checksum; application.ini validated by name/version'
  fi
  echo 'LIMIT: copy integrity is not build-to-source reproducibility or security acceptance'
}
valid_qa_build_app() {
  # Native Gecko dist/bin/application.ini is usually a symlink back into the
  # same QA objdir. The copied snapshot still requires a regular file.
  local dir="$1" obj_root="$worktree/obj-vulpra-security-qa-build" resolved_ini
  [[ "$dir" == "$obj_root/dist/bin" &&
     -d "$dir" && ! -L "$dir" && -x "$dir/vulpra" &&
     ! -L "$dir/vulpra" && -f "$dir/application.ini" ]] || return 1
  resolved_ini="$(realpath -e -- "$dir/application.ini")" || return 1
  case "$resolved_ini" in
    "$obj_root/"*) ;;
    *) return 1 ;;
  esac
  grep -Fxq 'Name=Vulpra' "$resolved_ini" &&
    grep -Fxq 'Version=160.0.1' "$resolved_ini"
}
valid_compiled_app() {
  # Gecko normally symlinks dist/bin/application.ini to obj*/build/application.ini.
  # Accept that source build link only when its canonical target remains inside
  # our main native object directory; QA copies must have their own regular ini.
  local dir="$1" obj_root="$source_repo/obj-vulpra-main-160" resolved_ini
  [[ "$dir" == "$obj_root/dist/bin" &&
     -d "$dir" && ! -L "$dir" && -x "$dir/vulpra" &&
     ! -L "$dir/vulpra" && -f "$dir/application.ini" ]] || return 1
  resolved_ini="$(realpath -e -- "$dir/application.ini")" || return 1
  case "$resolved_ini" in
    "$obj_root/"*) ;;
    *) return 1 ;;
  esac
  [[ -f "$resolved_ini" ]] || return 1
  grep -Fxq 'Name=Vulpra' "$resolved_ini" &&
    grep -Fxq 'Version=160.0.1' "$resolved_ini"
}
case "$action" in
  setup|snapshot)
    [[ "$launcher_mode" == main ]] ||
      die "$action copies from or creates the main checkout; use main once for bootstrap/snapshots, QA for testing"
    ;;
esac

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
    if valid_app "$worktree/obj-vulpra-security-qa-build/dist/bin"; then
      echo 'QA native build: available (separate object directory)'
    else
      echo 'QA native build: not compiled'
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
  sync)
    valid_worktree || die 'QA worktree missing or invalid; run security-qa setup'
    # Never discard any source edits or untracked files in the QA worktree.
    git -C "$worktree" diff --quiet &&
      git -C "$worktree" diff --cached --quiet &&
      [[ -z "$(git -C "$worktree" ls-files --others --exclude-standard)" ]] ||
      die 'QA source is modified; refusing to change its checked-out commit'
    if [[ "$launcher_mode" == qa ]]; then
      # Network access is explicit and scoped to source updates. Fetch into
      # shared Git objects/refs without modifying the daily main worktree,
      # installed browser, current QA snapshots or user profile.
      git -C "$worktree" -c http.version=HTTP/1.1 fetch --no-tags \
        --filter=blob:none origin main ||
        die 'QA source fetch failed; no source checkout changed'
      commit="$(git -C "$worktree" rev-parse 'FETCH_HEAD^{commit}')"
      [[ "$(git -C "$worktree" show "$commit:browser/config/version.txt")" == 160.0.1 ]] ||
        die 'fetched QA source is not Firefox 160.0.1'
    else
      commit="$(git -C "$source_repo" rev-parse HEAD)"
      [[ "$(cat "$source_repo/browser/config/version.txt")" == 160.0.1 ]] ||
        die 'main working source version is not Firefox 160.0.1'
    fi
    if [[ "$(git -C "$worktree" rev-parse HEAD)" == "$commit" ]]; then
      printf 'PASS: QA source already matches current main commit %s\n' "${commit:0:12}"
      exit 0
    fi
    git -C "$worktree" checkout --detach "$commit"
    printf 'PASS: QA source advanced to main commit %s without touching daily checkout\n' "${commit:0:12}"
    echo 'LIMIT: existing independent QA binary snapshots are not rebuilt or replaced'
    exit 0
    ;;
  snapshot)
    valid_worktree || die 'QA worktree missing or invalid; run security-qa setup'
    [[ ! -L "$state" && ! -L "$state/snapshots" &&
       ! -L "$state/active-snapshot" ]] ||
      die 'QA state must not contain symbolic-link entrypoints'
    valid_compiled_app "$compiled" ||
      die 'main Vulpra binary or application.ini is invalid, or application.ini resolves outside its object directory'
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
    # Firefox/Gecko can create a transient dist/bin/lock symlink while the
    # daily browser is running; it is normally dangling as a filesystem path.
    # Do not follow or copy process-lock entries into an independent runtime.
    # GNU tar dereferences legitimate build symlinks (including application.ini)
    # without requiring rsync, and pipefail rejects incomplete snapshots.
    mkdir -p -m 0700 -- "$tmp/app"
    tar -C "$compiled" --dereference \
      --exclude='./lock' --exclude='./.parentlock' --exclude='./parent.lock' \
      -cf - . | tar -C "$tmp/app" -xf -
    [[ ! -e "$tmp/app/lock" && ! -L "$tmp/app/lock" &&
       ! -e "$tmp/app/.parentlock" && ! -L "$tmp/app/.parentlock" ]] ||
      die 'QA copy unexpectedly included daily browser runtime lock state'
    valid_app "$tmp/app" || die 'copied QA binary was incomplete'
    [[ "$(sha256sum "$tmp/app/vulpra" | cut -d' ' -f1)" == "$binary_sha" ]] ||
      die 'copied QA executable checksum changed during snapshot'
    [[ "$(sha256sum "$tmp/app/application.ini" | cut -d' ' -f1)" == "$(sha256sum "$compiled/application.ini" | cut -d' ' -f1)" ]] ||
      die 'QA application identity changed during snapshot'
    ini_sha="$(sha256sum -- "$tmp/app/application.ini" | cut -d' ' -f1)"
    printf 'source_commit=%s\nbinary_sha256=%s\napplication_ini_sha256=%s\n' \
      "$source_commit" "$binary_sha" "$ini_sha" > "$tmp/manifest.txt"
    mv -- "$tmp" "$target"
    tmp=""
    printf '%s\n' "$identifier" > "$state/active-snapshot.new"
    mv -- "$state/active-snapshot.new" "$state/active-snapshot"
    printf 'PASS: independent, checksum-verified QA runtime snapshot %s\n' "$identifier"
    echo 'LIMIT: copied native binary is NOT proof of build-to-source reproducibility'
    exit 0
    ;;
  verify)
    verify_snapshot
    exit 0
    ;;
  build)
    valid_worktree || die 'QA worktree missing or invalid; run security-qa setup'
    builder="$worktree/scripts/vulpra-security-qa-build.sh"
    [[ -f "$builder" ]] ||
      die 'QA worktree does not yet contain the guarded native QA builder; sync a clean QA worktree'
    # Run all source/path checks BEFORE Nix can evaluate or download tools.
    bash "$builder" --preflight --jobs "$jobs"
    command -v nix >/dev/null ||
      die 'Nix/Lix unavailable; no unpinned host compiler fallback'
    [[ -f "$worktree/nix/flake.nix" && -f "$worktree/nix/flake.lock" ]] ||
      die 'QA worktree has no pinned Nix toolchain'
    qa_flake="path:$worktree/nix"
    if command -v nom >/dev/null; then
      exec nom develop "$qa_flake" --no-write-lock-file --command \
        bash "$builder" --build --jobs "$jobs"
    fi
    exec nix shell "$qa_flake#nom" --no-write-lock-file --command \
      nom develop "$qa_flake" --no-write-lock-file --command \
      bash "$builder" --build --jobs "$jobs"
    ;;
  accept)
    # Explicit local-only acceptance run; never touch the user's browser,
    # personal profiles, hosted credentials, installed extensions, or CA store.
    verify_snapshot
    app="$(snapshot_path)"
    probe="$worktree/ci/smoke-webextension-package-local.py"
    [[ -f "$probe" && ! -L "$probe" ]] ||
      die 'QA worktree WebDriver security probe missing; sync the detached QA source (never use daily main tests)'
    for tool in python3 geckodriver openssl jq timeout; do
      command -v "$tool" >/dev/null ||
        die "security QA acceptance requires $tool; no automatic installation"
    done
    runtime="$state/runtime"
    [[ ! -L "$runtime" ]] || die 'QA runtime must not be a symlink'
    mkdir -p -m 0700 -- "$runtime"
    run="$(mktemp -d "$runtime/accept.XXXXXXXX")"
    mkdir -p -m 0700 -- "$run/home" "$run/data" "$run/cache" "$run/config"
    # Retain only safe command/environment inputs. No Firefox/Gecko profile
    # variables from the interactive desktop are inherited by the subprocess.
    set +e
    timeout 240 env -i PATH="$PATH" HOME="$run/home" LANG=C.UTF-8 \
      XDG_DATA_HOME="$run/data" XDG_CACHE_HOME="$run/cache" \
      XDG_CONFIG_HOME="$run/config" \
      MOZ_HEADLESS=1 NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost \
      VULPRA_VERIFY_BYOB_DEFAULTS=1 VULPRA_VERIFY_UA_COMPAT=1 \
      python3 "$probe" --qa-appdir "$app" --qa-output-dir "$run" \
      > "$run/accept.log" 2>&1
    result=$?
    set -e
    [[ "$result" -eq 0 ]] ||
      die "isolated WebDriver acceptance failed (exit $result); QA-only log: $run/accept.log"
    shopt -s nullglob
    reports=("$run"/webextension-smoke-*.json)
    [[ "${#reports[@]}" -eq 1 && -f "${reports[0]}" && ! -L "${reports[0]}" ]] ||
      die "WebDriver acceptance returned without exactly one QA report: $run"
    jq -e '
      .schema_version == 1 and .status == "pass" and
      .runtime_source == "copied_qa_snapshot" and
      .security.temporary_home == true and
      .security.local_untrusted_tls_denial.verified == true and
      .security.local_untrusted_tls_denial.webdriver_accept_insecure_certs == false and
      .webextension.temporary_unsigned_install == true and
      .webextension.content_scripts == true and
      .webextension.background_messaging == true and
      .webextension.storage_local == true and
      .webextension.uninstall == true and
      .byob_default_preferences.verified == true
    ' "${reports[0]}" > /dev/null ||
      die "QA acceptance report lacks required real-browser security assertions: ${reports[0]}"
    echo 'PASS: copied QA Gecko real-browser localhost TLS + extension + BYOB checks'
    printf 'QA evidence: %s\n' "${reports[0]}"
    echo 'LIMIT: no target sandbox syscalls, live Safe Browsing provider or external egress audit'
    ;;
  style)
    [[ "$launcher_mode" == qa ]] ||
      die 'style must be launched from the detached QA checkout, not from daily main'
    valid_worktree || die 'detached QA source worktree missing or invalid'
    app="$worktree/obj-vulpra-security-qa-build/dist/bin"
    valid_qa_build_app "$app" ||
      die 'no independently compiled QA Vulpra; use QA security-qa build first'
    probe="$worktree/ci/smoke-webextension-package-local.py"
    [[ -f "$probe" && ! -L "$probe" ]] ||
      die 'QA-local browser geometry probe missing'
    for tool in python3 geckodriver timeout jq; do
      command -v "$tool" >/dev/null ||
        die "QA sidebar geometry check needs $tool; no automatic installation"
    done
    runtime="$state/runtime"
    [[ ! -L "$runtime" ]] || die 'QA runtime must not be linked'
    mkdir -p -m 0700 -- "$runtime"
    run="$(mktemp -d "$runtime/style.XXXXXXXX")"
    mkdir -p -m 0700 -- "$run/home" "$run/data" "$run/cache" "$run/config"
    set +e
    timeout 180 env -i PATH="$PATH" HOME="$run/home" LANG=C.UTF-8 \
      XDG_DATA_HOME="$run/data" XDG_CACHE_HOME="$run/cache" \
      XDG_CONFIG_HOME="$run/config" MOZ_HEADLESS=1 \
      NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost \
      python3 "$probe" --qa-vertical-style "$app" "$run" \
      > "$run/style.log" 2>&1
    result=$?
    set -e
    [[ "$result" == 0 ]] ||
      die "QA CSS geometry test failed (exit $result); QA-only log: $run/style.log"
    [[ -f "$run/style-result.json" && ! -L "$run/style-result.json" ]] ||
      die "QA CSS geometry test returned no report: $run/style.log"
    jq -e '.status == "pass" and .source == "qa_native_compiled" and
      .expanded.vertical == true and .collapsed.vertical == true and
      .expanded.group_label_square == true and
      .collapsed.group_label_square == true and
      .collapsed.group_alignment_within_px == true and
      .expanded.compact_27px_tabs == true and
      .collapsed.compact_27px_tabs == true' "$run/style-result.json" > /dev/null ||
      die "QA geometry report lacks required live layout evidence: $run/style-result.json"
    printf 'PASS: independent QA-native Vulpra vertical tab compact geometry: %s\n' "$run/style-result.json"
    echo 'LIMIT: headless measured chrome geometry, not a visual human review on Hyprland'
    ;;
  headless|headless-build)
    valid_worktree || die 'QA worktree missing or invalid'
    if [[ "$action" == headless-build ]]; then
      app="$worktree/obj-vulpra-security-qa-build/dist/bin"
    else
      verify_snapshot
      app="$(snapshot_path)"
    fi
    if [[ "$action" == headless-build ]]; then
      valid_qa_build_app "$app" ||
        die 'QA-native built Vulpra executable or application.ini missing or invalid'
    else
      valid_app "$app" || die 'selected QA executable missing or invalid'
    fi
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
