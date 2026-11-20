#!/usr/bin/env bash
# Contract tests for the nom-first Vulpra launcher; no Nix evaluation or build.
set -euo pipefail
launcher="${1:-$(dirname -- "${BASH_SOURCE[0]}")/vulpra}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Run against a tiny fake checkout: works both in a Nix sandbox (where each
# flake input path is copied separately) and directly from Git.
repo="$tmp/checkout"
mkdir -p "$repo/nix"
cp "$launcher" "$repo/nix/vulpra"
: > "$repo/nix/flake.nix"
: > "$repo/nix/flake.lock"

printf '#!%s\n' "$(command -v bash)" > "$tmp/nix"
cat >> "$tmp/nix" <<'EOF'
printf '%s\n' "$PWD" > "$NIX_TEST_PWD"
printf '%s\n' "$@" > "$NIX_TEST_ARGS"
exit "${NIX_TEST_EXIT:-0}"
EOF
printf '#!%s\n' "$(command -v bash)" > "$tmp/nom"
cat >> "$tmp/nom" <<'EOF'
printf '%s\n' "$PWD" > "$NOM_TEST_PWD"
printf '%s\n' "$@" > "$NOM_TEST_ARGS"
exit "${NOM_TEST_EXIT:-0}"
EOF
chmod +x "$tmp/nix" "$tmp/nom"
export PATH="$tmp:$PATH"
export NOM_TEST_PWD="$tmp/pwd" NOM_TEST_ARGS="$tmp/args"
export NIX_TEST_PWD="$tmp/nix-pwd" NIX_TEST_ARGS="$tmp/nix-args"

bash "$repo/nix/vulpra" doctor
printf '%s\n' develop "path:$repo/nix" --no-write-lock-file --command vulpra-dev doctor > "$tmp/expected"
cmp "$tmp/expected" "$tmp/args"
[[ "$(cat "$tmp/pwd")" == "$repo" ]]

(cd / && bash "$repo/nix/vulpra" shell)
printf '%s\n' develop "path:$repo/nix" --no-write-lock-file --command fish > "$tmp/expected"
cmp "$tmp/expected" "$tmp/args"

bash "$repo/nix/vulpra" mach configure --verbose
printf '%s\n' develop "path:$repo/nix" --no-write-lock-file --command vulpra-dev mach configure --verbose > "$tmp/expected"
cmp "$tmp/expected" "$tmp/args"

if bash "$repo/nix/vulpra" shell extra > /dev/null 2>&1; then
  echo 'ERROR: shell unexpectedly accepted extra arguments' >&2
  exit 1
fi
if bash "$repo/nix/vulpra" bogus > /dev/null 2>&1; then
  echo 'ERROR: unknown launcher action was accepted' >&2
  exit 1
fi

export NOM_TEST_EXIT=19
set +e
bash "$repo/nix/vulpra" doctor
result=$?
set -e
[[ "$result" -eq 19 ]] || {
  echo "ERROR: nom exit status not propagated: $result" >&2
  exit 1
}
unset NOM_TEST_EXIT
rm "$tmp/nom"
bash "$repo/nix/vulpra" source
printf '%s\n' shell "path:$repo/nix#nom" --no-write-lock-file --command nom develop "path:$repo/nix" --no-write-lock-file --command vulpra-dev source > "$tmp/expected"
cmp "$tmp/expected" "$tmp/nix-args"
[[ "$(cat "$tmp/nix-pwd")" == "$repo" ]]
# Neither Nix nor nom may receive an implicit git+file source reference.
# The flake input must remain scoped to the tiny nix/ subdirectory.
if grep -Eq '^\\./nix(#|$)' "$tmp/nix-args" "$tmp/args"; then
  echo 'ERROR: launcher regressed to Git-root flake input' >&2
  exit 1
fi
grep -Fxq "path:$repo/nix" "$tmp/nix-args"
grep -Fxq "path:$repo/nix#nom" "$tmp/nix-args"

export NIX_TEST_EXIT=23
set +e
bash "$repo/nix/vulpra" source
result=$?
set -e
[[ "$result" -eq 23 ]] || {
  echo "ERROR: nix bootstrap exit status not propagated: $result" >&2
  exit 1
}

echo 'PASS: isolated path: flake, nom bootstrap, forwarding, cwd, guards and exit statuses'
