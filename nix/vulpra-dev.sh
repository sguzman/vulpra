#!/usr/bin/env bash
# Vulpra developer CLI: dispatches existing guarded native workflows.
# Does not install a browser, select user profiles, or modify host settings.
set -euo pipefail

usage() {
  cat <<'HELP'
Vulpra Nix developer commands

  vulpra-dev doctor       Read-only toolchain/checkout/mozconfig inspection
  vulpra-dev source       Read-only tracked-source completeness check
  vulpra-dev check        Syntax-check existing guarded shell workflows
  vulpra-dev configure    Run ./mach configure (requires Nix devShell)
  vulpra-dev build        Build verified Firefox 160.0.1 in separate source tree
  vulpra-dev build --fetch-source  Explicitly permit first Mozilla source download
  vulpra-dev run          Launch local Firefox 160.0.1 with private profile
  vulpra-dev package      Package and smoke the same compiled Firefox 160.0.1 tree
    vulpra-dev smoke        Private headless native executable smoke
  vulpra-dev wayland      Private Weston/Wayland packaged smoke
  vulpra-dev accept       Offline localhost JS/redirect/package test
  vulpra-dev webext       Private packaged WebExtension lifecycle test
  vulpra-dev input        Headless synthetic typing-to-rAF timing; isolated package
  vulpra-dev mach ARGS    Pass arguments to this checkout's ./mach
  vulpra-dev help         Show this help

Use from the repository root:
  nix develop ./nix --command vulpra-dev doctor
  nix develop ./nix --command fish

The native build sources your original MOZCONFIG (or your already-existing
~/.mozbuild/vulpra-local.mozconfig) through the versioned Nix libclang shim.
The original file is never changed. Nothing here installs Firefox.
HELP
}

error() { printf 'Vulpra: %s\n' "$*" >&2; exit 2; }

has_shared_libclang() {
  local candidate
  for candidate in "$1"/libclang.so*; do
    [[ -f "$candidate" ]] && return 0
  done
  return 1
}

command_name="${1:-help}"
if (($#)); then shift; fi

case "$command_name" in
  help|-h|--help) usage; exit 0 ;;
  doctor|source|check|configure|build|run|package|smoke|wayland|accept|webext|input|mach) ;;
  *) error "unknown command '$command_name'; run vulpra-dev help" ;;
esac

# The CLI can be run from any subdirectory or with an explicit VULPRA_REPO.
candidate="${VULPRA_REPO:-$PWD}"
root="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)" ||
  error "not inside a Vulpra Git checkout: $candidate"
root="$(cd "$root" && pwd -P)"
[[ -f "$root/AGENTS.md" && -f "$root/mach" && -d "$root/ci" ]] ||
  error "not a Vulpra source checkout: $root"
[[ -f "$root/ci/mozconfig-linux" ]] ||
  error "missing CI native mozconfig (incomplete checkout): $root"

local_mozconfig="${MOZCONFIG:-$HOME/.mozbuild/vulpra-local.mozconfig}"

# Default local build now targets the exact Firefox 160.0.1 Vulpra candidate,
# not the tracked historical Firefox 159 files in repository main. Preserve
# their source and objdir: prepare/build the 160 tree independently.
if [[ "$command_name" == build || "$command_name" == run || "$command_name" == package ]]; then
  [[ "${VULPRA_NIX_DEV:-}" == 1 ]] ||
    error "use ./nix/vulpra $command_name; requires pinned Nix devShell"
  [[ -f "$root/scripts/vulpra-build-160.sh" ]] ||
    error "missing main-branch source-first 160 local build entrypoint"
  if [[ "$command_name" == run ]]; then
    exec bash "$root/scripts/vulpra-build-160.sh" --run "$@"
  elif [[ "$command_name" == package ]]; then
    (($# == 0)) || error "package takes no arguments"
    exec bash "$root/scripts/vulpra-package-160.sh"
  fi
  exec bash "$root/scripts/vulpra-build-160.sh" "$@"
fi


case "$command_name" in
  configure)
    error "standalone configure targets the historical Firefox 159 checkout; use './nix/vulpra build' to configure and compile the verified Firefox 160 source"
    ;;
  doctor)
    printf 'Vulpra root: %s\n' "$root"
    printf 'Commit: %s\n' "$(git -C "$root" rev-parse --short=12 HEAD)"
    printf 'Nix developer environment: %s\n' "${VULPRA_NIX_DEV:-not active}"
    printf 'MOZCONFIG: %s\n' "$local_mozconfig"
    if [[ -f "$local_mozconfig" ]]; then
      printf 'MOZCONFIG exists (contents not printed)\n'
    else
      printf 'NOTE: no local MOZCONFIG at this path; native configure/build is not ready\n'
    fi
    missing=0
    for tool in bash git clang rustc cargo cbindgen nasm node python3 pkg-config jq xz sccache; do
      if command -v "$tool" >/dev/null 2>&1; then
        printf 'OK: %-13s %s\n' "$tool" "$(command -v "$tool")"
      else
        printf 'MISSING: %s\n' "$tool" >&2
        missing=1
      fi
    done
    if ((missing)); then error "required developer tools missing"; fi
    if [[ "${VULPRA_NIX_DEV:-}" == 1 ]]; then
      libclang_dir="${VULPRA_NIX_LIBCLANG_PATH:-}"
      [[ -n "$libclang_dir" && -d "$libclang_dir" ]] ||
        error "Nix devShell did not provide a usable libclang directory"
      has_shared_libclang "$libclang_dir" ||
        error "Nix libclang directory lacks a shared libclang.so: $libclang_dir"
      printf 'OK: libclang       %s\n' "$libclang_dir"
    fi
    printf 'PASS: required tool commands are available (not native build verification)\n'
    ;;
  source)
    if [[ "$(git -C "$root" config --bool core.sparseCheckout || true)" == true ]]; then
      error "sparse checkout active; no full native build accepted"
    fi
    missing="$(git -C "$root" ls-files -d | sed -n '1p')" ||
      error "failed reading tracked source"
    [[ -z "$missing" ]] ||
      error "missing tracked source: $missing"
    printf 'PASS: tracked files present and sparse checkout disabled\n'
    printf 'LIMIT: upstream gitignored Breakpad source is checked by ci/build-local.sh\n'
    ;;
  check)
    for relative in \
      scripts/build-firefox160-local.sh \
      scripts/vulpra-build-160.sh \
      scripts/vulpra-package-160.sh \
      ci/build-local.sh \
      ci/smoke-native-local.sh \
      ci/package-smoke-local.sh \
      ci/smoke-wayland-package-local.sh \
      packaging/stage.sh; do
      [[ -f "$root/$relative" ]] || error "missing native workflow $relative"
      bash -n "$root/$relative"
    done
    bash -n "$root/nix/vulpra-dev.sh"
    printf 'PASS: existing native shell workflows syntax-checked (no browser execution)\n'
    ;;
  *)
    [[ "${VULPRA_NIX_DEV:-}" == 1 ]] ||
      error "enter 'nix develop ./nix' before running '$command_name'; refusing host-toolchain fallback"
    case "$command_name" in
      configure|package|mach)
        [[ -f "$local_mozconfig" ]] ||
          error "local MOZCONFIG missing: $local_mozconfig; existing workstation configuration is never overwritten"
        ;;
    esac
    # Gecko's bindgen.configure recognizes --with-libclang-path in a mozconfig.
    # It does NOT automatically search Nix's split libclang output. Point
    # native configure/build/mach at a versioned, additive shim that first
    # sources the untouched original workstation MOZCONFIG.
    case "$command_name" in
      configure|mach)
        libclang_dir="${VULPRA_NIX_LIBCLANG_PATH:-}"
        [[ -n "$libclang_dir" && -d "$libclang_dir" ]] ||
          error "no Nix-provided libclang directory; refusing host-toolchain fallback"
        has_shared_libclang "$libclang_dir" ||
          error "missing libclang.so in Nix directory: $libclang_dir"
        [[ -f "$root/nix/mozconfig-overlay.sh" ]] ||
          error "missing tracked Nix mozconfig shim"
        export VULPRA_MOZCONFIG_SOURCE="$local_mozconfig"
        export MOZCONFIG="$root/nix/mozconfig-overlay.sh"
        printf 'Nix libclang: %s\n' "$libclang_dir"
        printf 'Original workstation MOZCONFIG preserved: %s\n' "$VULPRA_MOZCONFIG_SOURCE"
        ;;
    esac
    cd "$root"
    case "$command_name" in
      configure) exec ./mach configure "$@" ;;
      package) exec bash "$root/ci/package-smoke-local.sh" "$@" ;;
      smoke) exec bash "$root/ci/smoke-native-local.sh" "$@" ;;
      wayland) exec bash "$root/ci/smoke-wayland-package-local.sh" "$@" ;;
      accept) exec python3 "$root/ci/accept-native-package-local.py" "$@" ;;
      webext) exec python3 "$root/ci/smoke-webextension-package-local.py" "$@" ;;
      input) exec bash "$root/ci/measure-input-frame-local.sh" "$root" ;;
      mach) exec ./mach "$@" ;;
    esac
    ;;
esac
