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
  # The # form is the actual libwayland trace observed on EndeavourOS.
  sep="#"
  [[ "${MOCK_GUI_OBJECT_STYLE:-hash}" != at ]] || sep="@"
  if [[ "${MOCK_GUI_NO_ATTACH:-0}" != 1 ]]; then
    echo "[15:54:18.662104] -> wl_surface${sep}13.attach(wl_buffer${sep}45, 0, 0)" >&2
  fi
  if [[ "${MOCK_GUI_NO_COMMIT:-0}" != 1 ]]; then
    echo "[15:54:18.662106] -> wl_surface${sep}13.commit()" >&2
  fi
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
grep -Fq 'PASS: Packaged Vulpra connected to private Weston, attached and committed Wayland buffers' "$R/pass.log"
test "$(find "$R/repo/.git/vulpra-native-build" -name 'wayland-browser-*.log' | wc -l)" -eq 1
echo 'PASS: actual libwayland hash-ID buffer attach and commit, isolated profile gate passed'
set +e
PATH="$R/bin:$PATH" VULPRA_WAYLAND_TEST_SECONDS=1 MOCK_GUI_NO_SURFACE=1 bash "$RUNNER" "$R/repo" > "$R/nosurface.log" 2>&1
result=$?
set -e
[[ "$result" == 5 ]] || { cat "$R/nosurface.log"; echo "FAIL: no-surface expected exit 5, received $result"; exit 2; }
grep -Fq 'No Wayland surface buffer attachment and frame commit' "$R/nosurface.log"
echo 'PASS: rejects process that stays alive without creating a Wayland surface'
# Alternate older Wayland debug object formatting must also be supported.
PATH="$R/bin:$PATH" VULPRA_WAYLAND_TEST_SECONDS=1 MOCK_GUI_OBJECT_STYLE=at bash "$RUNNER" "$R/repo" > "$R/at-style.log" 2>&1 || {
  cat "$R/at-style.log"; exit 5;
}
grep -Fq 'PASS: Packaged Vulpra connected to private Weston' "$R/at-style.log"
echo 'PASS: old libwayland at-ID object formatting'
# Surface creation alone is insufficient: require a non-null buffer attachment
# and a committed frame. A browser can remain alive without drawing.
set +e
PATH="$R/bin:$PATH" VULPRA_WAYLAND_TEST_SECONDS=1 MOCK_GUI_NO_ATTACH=1 bash "$RUNNER" "$R/repo" > "$R/noattach.log" 2>&1
result=$?
set -e
[[ "$result" == 5 ]] || { cat "$R/noattach.log"; echo "FAIL: no-attach expected 5, got $result"; exit 6; }
echo 'PASS: alive process with only surface commits is rejected'
set +e
PATH="$R/bin:$PATH" VULPRA_WAYLAND_TEST_SECONDS=1 MOCK_GUI_NO_COMMIT=1 bash "$RUNNER" "$R/repo" > "$R/nocommit.log" 2>&1
result=$?
set -e
[[ "$result" == 5 ]] || { cat "$R/nocommit.log"; echo "FAIL: no-commit expected 5, got $result"; exit 7; }
echo 'PASS: attached but uncommitted buffer is rejected'
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
