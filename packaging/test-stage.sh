#!/usr/bin/env bash
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/in/firefox"
printf '[App]\nName=Vulpra\n' > "$work/in/firefox/application.ini"
cat > "$work/in/firefox/firefox" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$ARGS_CAPTURE"
MOCK
chmod +x "$work/in/firefox/firefox"
ln -s firefox "$work/in/firefox/browser-link"
original_binary_sha="$(sha256sum "$work/in/firefox/firefox" | cut -d' ' -f1)"
tar -cJf "$work/moz.tar.xz" -C "$work/in" .
bash "$here/stage.sh" "$work/moz.tar.xz" "$work/vulpra.tar.xz"
[[ -s "$work/vulpra.tar.xz" && -s "$work/vulpra.tar.xz.sha256" ]]
(cd "$work" && sha256sum --check vulpra.tar.xz.sha256)
# Downloading the archive into a different directory must not invalidate SHA-256.
mkdir -p "$work/download"
cp "$work/vulpra.tar.xz" "$work/vulpra.tar.xz.sha256" "$work/download/"
(cd "$work/download" && sha256sum --check vulpra.tar.xz.sha256)
if grep -Fq "$work/" "$work/download/vulpra.tar.xz.sha256"; then
  echo "Checksum leaks build-machine absolute path" >&2
  exit 1
fi
mkdir "$work/unpack"
tar -xf "$work/vulpra.tar.xz" -C "$work/unpack"
[[ -x "$work/unpack/firefox/vulpra" ]]
# Staging must add only Vulpra's launcher, not alter Firefox engine bits.
test "$(sha256sum "$work/unpack/firefox/firefox" | cut -d' ' -f1)" = "$original_binary_sha"
cmp -- "$work/in/firefox/application.ini" "$work/unpack/firefox/application.ini"
[[ -L "$work/unpack/firefox/browser-link" ]]
[[ "$(readlink "$work/unpack/firefox/browser-link")" == firefox ]]
export ARGS_CAPTURE="$work/args" HOME="$work/user"
mkdir "$HOME"
"$work/unpack/firefox/vulpra" https://example.org
mapfile -t args < "$ARGS_CAPTURE"
[[ "${args[0]}" == --no-remote && "${args[1]}" == --new-instance && "${args[2]}" == --profile ]]
[[ "${args[3]}" == "$HOME/.local/share/vulpra/default" && "${args[4]}" == https://example.org ]]
[[ ! -e "$HOME/.mozilla" ]]
# A branded native package contains an executable named vulpra.
# Keep that executable untouched; install a separate vulpra-launch wrapper.
mkdir -p "$work/branded/vulpra"
cp "$work/in/firefox/application.ini" "$work/branded/vulpra/application.ini"
cp "$work/in/firefox/firefox" "$work/branded/vulpra/vulpra"
branded_sha="$(sha256sum "$work/branded/vulpra/vulpra" | cut -d' ' -f1)"
tar -cJf "$work/branded-source.tar.xz" -C "$work/branded" .
bash "$here/stage.sh" "$work/branded-source.tar.xz" "$work/branded-staged.tar.xz"
(cd "$work" && sha256sum --check branded-staged.tar.xz.sha256)
mkdir -p "$work/branded-unpack"
tar -xf "$work/branded-staged.tar.xz" -C "$work/branded-unpack"
[[ -x "$work/branded-unpack/vulpra/vulpra-launch" ]]
[[ "$(sha256sum "$work/branded-unpack/vulpra/vulpra" | cut -d' ' -f1)" == "$branded_sha" ]]
cmp -- "$work/branded/vulpra/application.ini" "$work/branded-unpack/vulpra/application.ini"
"$work/branded-unpack/vulpra/vulpra-launch" https://example.org/branded
mapfile -t branded_args < "$ARGS_CAPTURE"
[[ "${branded_args[0]}" == --no-remote && "${branded_args[1]}" == --new-instance ]]
[[ "${branded_args[2]}" == --profile && "${branded_args[3]}" == "$HOME/.local/share/vulpra/default" ]]
[[ "${branded_args[4]}" == https://example.org/branded ]]
if bash "$here/stage.sh" "$work/branded-staged.tar.xz" "$work/branded-overwrite.tar.xz" >/dev/null 2>&1; then
  echo "Unexpected overwrite of native Vulpra launcher" >&2; exit 1
fi
# Refuse a package which already contains a Vulpra launch wrapper.
touch "$work/in/firefox/vulpra"
tar -cJf "$work/already-vulpra.tar.xz" -C "$work/in" .
if bash "$here/stage.sh" "$work/already-vulpra.tar.xz" "$work/repack.tar.xz" >/dev/null 2>&1; then
  echo "Unexpected overwrite of existing Vulpra executable" >&2; exit 1
fi
if bash "$here/stage.sh" "$work/moz.tar.xz" "$work/moz.tar.xz" >/dev/null 2>&1; then
  printf 'stage: incorrectly accepted same input and output\n' >&2; exit 1
fi
mkdir -p "$work/mock-dist/bin"
cp "$work/in/firefox/application.ini" "$work/mock-dist/bin/"
cp "$work/in/firefox/firefox" "$work/mock-dist/bin/"
bash "$here/measure-build.sh" "$work/mock-dist" "$work/vulpra.tar.xz" 123 "$work/baseline.json"
jq -e '.application == "Vulpra" and .native_build_seconds == 123 and .archive_bytes > 0 and .native_executable_bytes > 0' "$work/baseline.json" >/dev/null
test "$(jq -r '.archive_sha256' "$work/baseline.json")" = "$(sha256sum "$work/vulpra.tar.xz" | cut -d' ' -f1)"
if bash "$here/measure-build.sh" "$work/mock-dist" "$work/vulpra.tar.xz" arbitrary "$work/invalid.json" >/dev/null 2>&1; then
  echo 'Invalid build duration unexpectedly accepted' >&2; exit 1
fi
echo 'PASS: staged package has a private-profile Vulpra launcher and verified archive checksum.'
