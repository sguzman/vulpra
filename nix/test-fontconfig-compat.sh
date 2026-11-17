#!/usr/bin/env bash
# The isolated Nix Fontconfig must use compatible bundled XML and still
# discover the workstation's fonts; no host config mutation is allowed.
set -euo pipefail
[[ "${VULPRA_NIX_DEV:-}" == 1 ]] || {
  echo 'ERROR: Vulpra Nix developer environment required' >&2; exit 1;
}
[[ -r "${FONTCONFIG_FILE:-}" ]] || {
  echo "ERROR: FONTCONFIG_FILE is not readable: ${FONTCONFIG_FILE:-<unset>}" >&2; exit 1;
}
case "$FONTCONFIG_FILE" in
  /nix/store/*/etc/fonts/fonts.conf) ;;
  *) echo "ERROR: unexpected Fontconfig configuration path: $FONTCONFIG_FILE" >&2; exit 1 ;;
esac
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
fc-match -f '%{family}\n' sans-serif > "$scratch/match.out" 2> "$scratch/match.err"
[[ -s "$scratch/match.out" ]] || {
  echo 'ERROR: no sans-serif font match in Nix environment' >&2; exit 1;
}
if grep -E 'invalid attribute|invalid constant used|cannot load' "$scratch/match.err" >&2; then
  echo 'ERROR: the pinned Fontconfig still cannot parse its configuration' >&2
  exit 1
fi
printf 'PASS: isolated pinned Fontconfig config resolves sans-serif: %s\n' "$(head -n1 "$scratch/match.out")"
