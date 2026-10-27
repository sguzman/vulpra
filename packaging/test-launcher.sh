#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT
mkdir -p "$temp/package" "$temp/home"
cp "$project_root/vulpra" "$temp/package/vulpra"
chmod +x "$temp/package/vulpra"
cat > "$temp/package/firefox" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$MOCK_ARGS_FILE"
MOCK
chmod +x "$temp/package/firefox"
export HOME="$temp/home" XDG_DATA_HOME="$temp/data" MOCK_ARGS_FILE="$temp/args"
mkdir -p "$HOME/.mozilla/firefox"
printf '[Profile0]\nName=existing-firefox\nPath=existing-profile\n' > "$HOME/.mozilla/firefox/profiles.ini"
original_hash="$(sha256sum "$HOME/.mozilla/firefox/profiles.ini")"
"$temp/package/vulpra" "https://example.org/page" --headless
mapfile -t args < "$MOCK_ARGS_FILE"
[[ "${#args[@]}" -eq 6 ]]
[[ "${args[0]}" == '--no-remote' ]]
[[ "${args[1]}" == '--new-instance' ]]
[[ "${args[2]}" == '--profile' ]]
[[ "${args[3]}" == "$temp/data/vulpra/default" ]]
[[ "${args[4]}" == 'https://example.org/page' ]]
[[ "${args[5]}" == '--headless' ]]
[[ -d "${args[3]}" && "$(stat -c '%a' "${args[3]}")" == 700 ]]
[[ "$(sha256sum "$HOME/.mozilla/firefox/profiles.ini")" == "$original_hash" ]]
for banned in -P --profile -profile=other --profile=/tmp/foo -ProfileManager; do
  if "$temp/package/vulpra" "$banned" > "$temp/stdout" 2> "$temp/stderr"; then
    echo "Unexpected profile escape acceptance: $banned" >&2
    exit 1
  fi
  grep -q 'profile-selection arguments' "$temp/stderr"
done
export XDG_DATA_HOME='relative-path'
if "$temp/package/vulpra" > "$temp/stdout" 2> "$temp/stderr"; then
  echo 'Relative XDG_DATA_HOME unexpectedly accepted' >&2
  exit 1
fi
grep -q 'must be an absolute path' "$temp/stderr"
export XDG_DATA_HOME="$temp/data"
rm -rf "$temp/data/vulpra/default"
ln -s "$temp/home/.mozilla" "$temp/data/vulpra/default"
if "$temp/package/vulpra" > "$temp/stdout" 2> "$temp/stderr"; then
  echo 'Symlinked profile unexpectedly accepted' >&2
  exit 1
fi
grep -q 'symbolic link' "$temp/stderr"
# New native Vulpra builds already have an ELF named vulpra. Verify that
# the wrapper can coexist as vulpra-launch without replacing that binary.
# Restore a safe private profile after the intentional symlink-refusal test.
rm -f "$temp/data/vulpra/default"
mkdir -m 0700 "$temp/data/vulpra/default"
rm -f "$temp/package/vulpra"
mv "$temp/package/firefox" "$temp/package/vulpra"
cp "$project_root/vulpra" "$temp/package/vulpra-launch"
chmod +x "$temp/package/vulpra-launch"
"$temp/package/vulpra-launch" https://example.org/branded
mapfile -t branded_args < "$MOCK_ARGS_FILE"
[[ "${branded_args[0]}" == --no-remote && "${branded_args[1]}" == --new-instance ]]
[[ "${branded_args[2]}" == --profile && "${branded_args[3]}" == "$temp/data/vulpra/default" ]]
[[ "${branded_args[4]}" == https://example.org/branded ]]
[[ "$(sha256sum "$HOME/.mozilla/firefox/profiles.ini")" == "$original_hash" ]]
echo 'PASS: legacy and native-branded Vulpra launchers isolate profiles, preserve URL args, and reject profile escapes.'
