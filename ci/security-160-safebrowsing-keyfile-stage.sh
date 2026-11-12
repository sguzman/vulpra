#!/usr/bin/env bash
# Prepare an ephemeral Firefox Safe Browsing mozconfig from an authorized keyfile.
# Never invoke from a release build without separate provider/distribution approval.
set -euo pipefail
umask 077

reject() {
  printf '%s\n' 'FAIL: Safe Browsing keyfile staging contract rejected input' >&2
  exit 1
}

[[ $# -eq 2 ]] || reject
[[ -n "$RUNNER_TEMP" && -n "$GITHUB_WORKSPACE" && -n "$VULPRA_SAFEBROWSING_KEY_SOURCE" ]] || reject
[[ "$RUNNER_TEMP" = /* && "$GITHUB_WORKSPACE" = /* ]] || reject

temp_root=$(realpath -e -- "$RUNNER_TEMP") || reject
workspace=$(realpath -e -- "$GITHUB_WORKSPACE") || reject
base=$(realpath -e -- "$1") || reject
output=$(realpath -m -- "$2") || reject

[[ -f "$base" && ! -L "$1" ]] || reject
[[ -f "$VULPRA_SAFEBROWSING_KEY_SOURCE" && ! -L "$VULPRA_SAFEBROWSING_KEY_SOURCE" ]] || reject
source_file=$(realpath -e -- "$VULPRA_SAFEBROWSING_KEY_SOURCE") || reject

# One newly created, private directory directly under the ephemeral runner root.
# A key may not come from source control, another checkout, or the output.
[[ "$(dirname -- "$output")" == "$temp_root" ]] || reject
[[ ! -e "$output" && ! -L "$output" ]] || reject
[[ "$source_file" == "$temp_root/"* ]] || reject
[[ "$source_file" != "$workspace/"* ]] || reject
[[ "$source_file" != "$output/"* ]] || reject
[[ -r "$source_file" && -s "$source_file" ]] || reject

mode=$(stat -c '%a' -- "$source_file") || reject
(( (8#$mode & 077) == 0 )) || reject
bytes=$(wc -c < "$source_file") || reject
(( bytes >= 20 && bytes <= 256 )) || reject
[[ $(LC_ALL=C tr -cd '\n' < "$source_file" | wc -c) -eq 0 ]] || reject
LC_ALL=C grep -Eq '^[A-Za-z0-9_-]{20,256}$' "$source_file" || reject
! grep -Fq -- '--with-google-safebrowsing-api-keyfile' "$base" || reject
! grep -Fq -- '--without-google-safebrowsing-api-keyfile' "$base" || reject

mkdir -m 700 -- "$output" || reject
trap 'rm -rf -- "$output"' ERR
install -m 600 -- "$source_file" "$output/google-safebrowsing.key"
{
  cat -- "$base"
  printf '\nac_add_options --with-google-safebrowsing-api-keyfile=%s\n' "$output/google-safebrowsing.key"
} > "$output/mozconfig"
chmod 600 "$output/mozconfig"
trap - ERR
printf '%s\n' 'PASS: private Safe Browsing keyfile and mozconfig staged (no provider/network/build verification)'
