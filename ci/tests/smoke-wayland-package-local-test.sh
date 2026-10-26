#!/usr/bin/env bash
# CI-only Weston and browser stand-ins; no real Firefox compile required.
set -Eeuo pipefail
RUNNER="${1:?Wayland package runner required}"
R=$(mktemp -d)
trap 'rm -rf -- "$R"' EXIT
mkdir -p "$R/repo" "$R/bin" "$R/package/vulpra" "$R/repo/.git"
cd "$R/repo"
git init -q
git config user.email test@example.invalid
git config user.name Test
printf 'fixture\n' > README
git add README
git commit -qm 'mock checkout'
mkdir -p "$R/repo/.git/vulpra-native-build/packages"
cat > "$R/package/vulpra/application.ini" <<'INI'
[App]
Name=Vulpra
INI
cat > "$R/package/vulpra/vulpra-launch" <<'BROWSER'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${WAYLAND_DISPLAY:-}" == wayland-vulpra-* ]] || exit 83
[[ "${GDK_BACKEND:-}" == wayland && "${MOZ_ENABLE_WAYLAND:-}" == 1 ]] || exit 84
[[ "${WAYLAND_DEBUG:-}" == client ]] || exit 85
[[ "${HOME:-}" == */home ]] || exit 86
mkdir -p "$XDG_DATA_HOME/vulpra/default"
if [[ "${MOCK_GUI_EARLY_EXIT:-0}" == 1 ]]; then exit 9; fi
if [[ "${MOCK_GUI_NO_SURFACE:-0}" != 1 ]]; then
  echo '[00000] -> xdg_surface@19.get_toplevel(new id xdg_toplevel@22)' >&2
fi
sleep 15
BROWSER
chmod +x "$R/package/vulpra/vulpra-launch"
archive="$R/repo/.git/vulpra-native-build/packages/vulpra-local-mock.tar.xz"
tar -cJf "$archive" -C "$R/package" .
(cd "$(dirname "$archive")" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")
cat > "$R/bin/weston" <<'WESTON'
#!/usr/bin/env bash
exec python3 - "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" <<'PY'
import signal, socket, sys, time
sock = socket.socket(socket.AF_UNIX)
sock.bind(sys.argv[1])
sock.listen(1)
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
while True: time.sleep(0.2)
PY
WESTON
chmod +x "$R/bin/weston"
cat > "$R/bin/wayland-info" <<'INFO'
#!/usr/bin/env bash
echo 'interface: wl_compositor'
echo 'interface: xdg_wm_base'
INFO
chmod +x "$R/bin/wayland-info"
PATH="$R/bin:$PATH" VULPRA_WAYLAND_TEST_SECONDS=1 bash "$RUNNER" "$R/repo" > "$R/pass.log" 2>&1 || {
  cat "$R/pass.log"
  exit 1
}
grep -Fq 'PASS: Packaged Vulpra connected to private Weston' "$R/pass.log"
test "$(find "$R/repo/.git/vulpra-native-build" -name 'wayland-browser-*.log' | wc -l)" -eq 1
echo 'PASS: graphical protocol surface and isolated profile gate passed'
set +e
PATH="$R/bin:$PATH" VULPRA_WAYLAND_TEST_SECONDS=1 MOCK_GUI_NO_SURFACE=1 bash "$RUNNER" "$R/repo" > "$R/nosurface.log" 2>&1
result=$?
set -e
[[ "$result" == 5 ]] || { cat "$R/nosurface.log"; echo "FAIL: no-surface expected exit 5, received $result"; exit 2; }
grep -Fq 'No graphical xdg_surface/toplevel' "$R/nosurface.log"
echo 'PASS: rejects process that stays alive without creating a Wayland surface'
set +e
PATH="$R/bin:$PATH" VULPRA_WAYLAND_TEST_SECONDS=1 MOCK_GUI_EARLY_EXIT=1 bash "$RUNNER" "$R/repo" > "$R/earlyexit.log" 2>&1
result=$?
set -e
[[ "$result" == 5 ]] || { cat "$R/earlyexit.log"; echo "FAIL: premature exit expected 5, received $result"; exit 3; }
grep -Fq 'exited prematurely' "$R/earlyexit.log"
echo 'PASS: rejects premature browser exit'
printf 'wrong checksum\n' > "$archive.sha256"
set +e
PATH="$R/bin:$PATH" VULPRA_WAYLAND_TEST_SECONDS=1 bash "$RUNNER" "$R/repo" > "$R/checksum.log" 2>&1
result=$?
set -e
[[ "$result" == 4 ]] || { cat "$R/checksum.log"; echo "FAIL: corrupt checksum expected 4, received $result"; exit 4; }
echo 'PASS: rejects package with invalid checksum'
echo 'PASS: Wayland package smoke offline regressions'
