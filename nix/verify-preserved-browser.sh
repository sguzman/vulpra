#!/usr/bin/env bash
# Actual original compiled Firefox160 browser, always ephemeral and never
# installed. Intended for the isolated archived-artifact CI replay.
set -euo pipefail

mode="${1:-}"
[[ "$mode" == headless || "$mode" == wayland ]] || {
  printf 'usage: verify-preserved-browser.sh headless|wayland\n' >&2
  exit 2
}
[[ "${VULPRA_NIX_DEV:-}" == 1 ]] || {
  printf 'Nix devShell required\n' >&2
  exit 2
}
[[ -n "${RUNNER_TEMP:-}" && -n "${GITHUB_WORKSPACE:-}" ]] || {
  printf 'Dedicated CI runner required, not an interactive user profile\n' >&2
  exit 2
}
app="$RUNNER_TEMP/compiled/vulpra"
[[ -x "$app/vulpra" && -x "$app/vulpra-launch" ]] || {
  printf 'Original packaged native Vulpra executable/launcher missing\n' >&2
  exit 2
}
grep -Fxq 'Name=Vulpra' "$app/application.ini"

case "$mode" in
  headless)
    work="$(mktemp -d "$RUNNER_TEMP/vulpra-nix-runtime.XXXXXXXX")"
    trap 'rm -rf -- "$work"' EXIT
    mkdir -p "$work/home/.mozilla/firefox"
    printf 'preserve Firefox profile\n' > "$work/home/.mozilla/firefox/profiles.ini"
    before="$(sha256sum "$work/home/.mozilla/firefox/profiles.ini" | cut -d' ' -f1)"
    printf '%s\n' \
      '<!doctype html><title>Vulpra Nix runtime test</title><h1>Firefox 160 preserved native package</h1>' \
      > "$work/test.html"
    env HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" \
      XRE_START_OFFLINE=1 MOZ_HEADLESS=1 MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
      timeout 120 "$app/vulpra-launch" --headless \
        --screenshot "$work/browser.png" "file://$work/test.html"
    [[ -s "$work/browser.png" ]]
    [[ "$(od -An -tx1 -N8 "$work/browser.png" | tr -d ' \n')" == 89504e470d0a1a0a ]]
    after="$(sha256sum "$work/home/.mozilla/firefox/profiles.ini" | cut -d' ' -f1)"
    [[ "$before" == "$after" ]]
    printf 'PASS: actual preserved Firefox160 headless screenshot in Nix devShell; existing Firefox sentinel unchanged\n'
    ;;
  wayland)
    # Original ELF compiled on Ubuntu 24.04, so use host GTK image-loaders.
    # Nix GDK_PIXBUF_MODULE_FILE and GIO/GTK module paths can inject
    # Nix-built plugins into a host-linked GTK binary, causing a crash.
    # This is scoped to this specific archived external binary in disposable
    # CI, not a fix for a native Nix-built Firefox or user's machine.
    # Reconstruct only documented CI inputs so Nix setup-hook GTK, GIO,
    # pixbuf and theme variables cannot enter the external host-built ELF.
    # Keep the Nix-provided developer PATH (Weston, wayland-info, tools).
    env -i HOME="$HOME" PATH="$PATH" LANG=C.UTF-8 \
      RUNNER_TEMP="$RUNNER_TEMP" GITHUB_WORKSPACE="$GITHUB_WORKSPACE" \
      VULPRA_WAYLAND_TEST_OFFLINE=1 MOZ_DISABLE_NONLOCAL_CONNECTIONS=1 \
      VULPRA_WAYLAND_TEST_SECONDS=6 \
      bash "$GITHUB_WORKSPACE/packaging/test-wayland.sh" "$app"
    printf 'PASS: private Weston graphical non-null surface buffer/commit in Nix devShell\n'
    ;;
esac
