#!/usr/bin/env bash
# Synthetic input only. No actual provider credentials, native build or release.
set -euo pipefail
script=ci/security-160-safebrowsing-keyfile-stage.sh
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
export RUNNER_TEMP="$root/runner"
export GITHUB_WORKSPACE="$root/checkout"
mkdir -p "$RUNNER_TEMP" "$GITHUB_WORKSPACE"
cp ci/mozconfig-linux "$GITHUB_WORKSPACE/mozconfig"
base="$GITHUB_WORKSPACE/mozconfig"
secret='synthetic_fixture_only_no_provider_12345'
source_file="$RUNNER_TEMP/input"
printf '%s' "$secret" > "$source_file"
chmod 600 "$source_file"
export VULPRA_SAFEBROWSING_KEY_SOURCE="$source_file"

bash "$script" "$base" "$RUNNER_TEMP/prepared" > "$root/positive.log" 2>&1
test -d "$RUNNER_TEMP/prepared"
test "$(stat -c '%a' "$RUNNER_TEMP/prepared")" = 700
test "$(stat -c '%a' "$RUNNER_TEMP/prepared/google-safebrowsing.key")" = 600
test "$(stat -c '%a' "$RUNNER_TEMP/prepared/mozconfig")" = 600
cmp -s "$source_file" "$RUNNER_TEMP/prepared/google-safebrowsing.key"
grep -Fxq "ac_add_options --with-google-safebrowsing-api-keyfile=$RUNNER_TEMP/prepared/google-safebrowsing.key" "$RUNNER_TEMP/prepared/mozconfig"
! grep -Fq "$secret" "$root/positive.log"
! grep -Fq "$secret" "$RUNNER_TEMP/prepared/mozconfig"

count=0
reject_case() {
  if "$@" > "$root/negative.log" 2>&1; then
    echo 'FAIL: rejected staging case was accepted' >&2
    exit 1
  fi
  if grep -Fq "$secret" "$root/negative.log"; then
    echo 'FAIL: fixture secret leaked to diagnostic output' >&2
    exit 1
  fi
  count=$((count+1))
}
reject_case env -u VULPRA_SAFEBROWSING_KEY_SOURCE bash "$script" "$base" "$RUNNER_TEMP/no-source"
reject_case bash "$script" "$base" "$RUNNER_TEMP/prepared"
reject_case bash "$script" "$base" "$GITHUB_WORKSPACE/outside"
ln -s "$source_file" "$RUNNER_TEMP/symlink"
reject_case env VULPRA_SAFEBROWSING_KEY_SOURCE="$RUNNER_TEMP/symlink" bash "$script" "$base" "$RUNNER_TEMP/symlink-dest"
cp "$source_file" "$GITHUB_WORKSPACE/checked-in-like-key"
chmod 600 "$GITHUB_WORKSPACE/checked-in-like-key"
reject_case env VULPRA_SAFEBROWSING_KEY_SOURCE="$GITHUB_WORKSPACE/checked-in-like-key" bash "$script" "$base" "$RUNNER_TEMP/checkout-key"
chmod 644 "$source_file"
reject_case bash "$script" "$base" "$RUNNER_TEMP/group-readable"
chmod 600 "$source_file"
printf '%s' 'short' > "$source_file"
reject_case bash "$script" "$base" "$RUNNER_TEMP/short-key"
printf '%s\n%s\n' "$secret" 'second-line' > "$source_file"
reject_case bash "$script" "$base" "$RUNNER_TEMP/multiline"
printf '%s' "$secret" > "$source_file"
printf '\nac_add_options --with-google-safebrowsing-api-keyfile=/bad/in-source\n' >> "$base"
reject_case bash "$script" "$base" "$RUNNER_TEMP/duplicate-key"
test "$count" -eq 9
echo 'PASS: synthetic private staging, no key in log/config, nine rejected fixtures'
