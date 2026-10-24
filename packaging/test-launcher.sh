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
[[ ! -e "$HOME/.mozilla" ]]
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
echo 'PASS: Vulpra launcher isolates profiles, preserves URL args, and rejects profile escapes.'
