#!/usr/bin/env bash
# Add Vulpra's isolated launcher to a trusted Firefox Linux package.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  printf 'usage: stage.sh firefox-source-package.tar.{xz,bz2,gz} output-vulpra.tar.xz\n' >&2
  exit 2
fi
archive="$(realpath -e -- "$1")"
output="$(realpath -m -- "$2")"
if [[ "$archive" == "$output" ]]; then
  printf 'stage: input and output archives must differ\n' >&2; exit 2
fi
[[ "$output" == *.tar.xz ]] || {
  printf 'stage: output must be .tar.xz\n' >&2; exit 2
}
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
# Trusted CI-generated artifact; no untrusted archive handling is claimed.
tar -xf "$archive" -C "$work"
mapfile -d '' -t candidates < <(find "$work" -mindepth 1 -maxdepth 4 -type f -name application.ini -print0)
if [[ "${#candidates[@]}" -ne 1 ]]; then
  printf 'stage: expected exactly one packaged application.ini, found %s\n' "${#candidates[@]}" >&2
  exit 1
fi
app_dir="$(dirname -- "${candidates[0]}")"
# Preserve the native browser binary byte-for-byte.
# M2 packages use firefox + vulpra (launcher).
# Independently branded native packages use vulpra (ELF) + vulpra-launch.
if [[ -x "$app_dir/vulpra" ]]; then
  launcher="$app_dir/vulpra-launch"
elif [[ -x "$app_dir/firefox" ]]; then
  launcher="$app_dir/vulpra"
else
  printf 'stage: no native Firefox/Vulpra executable beside application.ini\n' >&2
  exit 1
fi
if [[ -e "$launcher" || -L "$launcher" ]]; then
  printf 'stage: isolated launcher already exists; refusing overwrite\n' >&2
  exit 1
fi
install -m 0755 "$script_dir/vulpra" "$launcher"
tar -cJf "$output" -C "$work" .
# Store relative filename so the checksum survives artifact downloads/moves.
(
  cd -- "$(dirname -- "$output")"
  sha256sum -- "$(basename -- "$output")" > "$(basename -- "$output").sha256"
)
printf 'stage: packaged isolated Vulpra launcher in %s\n' "$output"
