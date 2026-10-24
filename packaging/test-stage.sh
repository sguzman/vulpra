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
tar -cJf "$work/moz.tar.xz" -C "$work/in" .
bash "$here/stage.sh" "$work/moz.tar.xz" "$work/vulpra.tar.xz"
[[ -s "$work/vulpra.tar.xz" && -s "$work/vulpra.tar.xz.sha256" ]]
(cd "$work" && sha256sum --check vulpra.tar.xz.sha256)
mkdir "$work/unpack"
tar -xf "$work/vulpra.tar.xz" -C "$work/unpack"
[[ -x "$work/unpack/firefox/vulpra" ]]
export ARGS_CAPTURE="$work/args" HOME="$work/user"
mkdir "$HOME"
"$work/unpack/firefox/vulpra" https://example.org
mapfile -t args < "$ARGS_CAPTURE"
[[ "${args[0]}" == --no-remote && "${args[1]}" == --new-instance && "${args[2]}" == --profile ]]
[[ "${args[3]}" == "$HOME/.local/share/vulpra/default" && "${args[4]}" == https://example.org ]]
[[ ! -e "$HOME/.mozilla" ]]
if bash "$here/stage.sh" "$work/moz.tar.xz" "$work/moz.tar.xz" >/dev/null 2>&1; then
  printf 'stage: incorrectly accepted same input and output\n' >&2; exit 1
fi
echo 'PASS: staged package has a private-profile Vulpra launcher and verified archive checksum.'
