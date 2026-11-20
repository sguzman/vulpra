#!/usr/bin/env bash
# Regression: direct-main run uses the local binary and an isolated profile,
# without Nix evaluation, browser builds, or the user's Firefox profile.
set -Eeuo pipefail

source_repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
for source in nix/vulpra scripts/vulpra-build-160.sh packaging/vulpra; do
  [[ -f "$source_repo/$source" ]] || {
    printf 'Missing launcher fixture source: %s\n' "$source" >&2
    exit 2
  }
done

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
repo="$work/checkout"
mkdir -p "$repo/nix" "$repo/scripts" "$repo/packaging" \
  "$repo/browser/config" "$repo/ci" \
  "$repo/toolkit/crashreporter/google-breakpad/src/third_party/lss" \
  "$work/home/.mozilla/firefox" "$work/bin"
cp "$source_repo/nix/vulpra" "$repo/nix/vulpra"
cp "$source_repo/scripts/vulpra-build-160.sh" "$repo/scripts/vulpra-build-160.sh"
cp "$source_repo/packaging/vulpra" "$repo/packaging/vulpra"
printf '%s\n' '160.0.1' > "$repo/browser/config/version.txt"
printf '%s\n' '#! /bin/sh' > "$repo/mach"
printf '%s\n' 'mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-fixture' > "$repo/ci/mozconfig-linux"
printf '%s\n' '# synthetic complete source marker' > \
  "$repo/toolkit/crashreporter/google-breakpad/src/third_party/lss/linux_syscall_support.h"
printf '%s\n' 'unchanged Firefox profile' > "$work/home/.mozilla/firefox/sentinel"

git -C "$repo" init -q -b main
git -C "$repo" add .
git -C "$repo" -c user.name='Vulpra fixture' \
  -c user.email='vulpra-fixture@example.invalid' commit -qm 'Synthetic main source'

# A harmless fake executable stands in for the compiled ELF. This validates
# the real launch path and argument forwarding, not Gecko runtime behavior.
bin="$repo/obj-vulpra-main-160/dist/bin"
mkdir -p "$bin"
cat > "$bin/application.ini" <<'INI'
[App]
Name=Vulpra
Version=160.0.1
INI
cat > "$bin/vulpra" <<'BROWSER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$VULPRA_TEST_ARGS"
printf '%s\n' "$HOME" "$XDG_DATA_HOME" > "$VULPRA_TEST_ENV"
BROWSER
chmod 0755 "$bin/vulpra"

# These tools must never be invoked by the run path.
for tool in nix nom; do
  cat > "$work/bin/$tool" <<'NO_NIX'
#!/usr/bin/env bash
echo 'ERROR: direct run unexpectedly entered Nix/nom' >&2
exit 99
NO_NIX
  chmod 0755 "$work/bin/$tool"
done

export HOME="$work/home" PATH="$work/bin:$PATH"
export VULPRA_TEST_ARGS="$work/args" VULPRA_TEST_ENV="$work/env"
# Default mode: persistent dogfooding, never tied to a disposable objdir.
bash "$repo/nix/vulpra" run
printf '%s\n' --no-remote --new-instance --profile \
  "$HOME/.local/share/vulpra/default" > "$work/expected-args"
printf '%s\n' "$HOME" "$HOME/.local/share" > "$work/expected-env"
cmp "$work/expected-args" "$work/args"
cmp "$work/expected-env" "$work/env"
[[ -x "$bin/vulpra-launch" ]]
[[ -d "$HOME/.local/share/vulpra/default" ]]
grep -Fxq 'unchanged Firefox profile' "$HOME/.mozilla/firefox/sentinel"
printf 'dogfooding marker\n' > "$HOME/.local/share/vulpra/default/sentinel"

# QA mode: existing build-local profile stays separate from dogfooding data.
bash "$repo/nix/vulpra" qa
printf '%s\n' --no-remote --new-instance --profile \
  "$repo/obj-vulpra-main-160/profile-data/vulpra/default" > "$work/expected-args"
printf '%s\n' "$HOME" "$repo/obj-vulpra-main-160/profile-data" > "$work/expected-env"
cmp "$work/expected-args" "$work/args"
cmp "$work/expected-env" "$work/env"
[[ -d "$repo/obj-vulpra-main-160/profile-data/vulpra/default" ]]
grep -Fxq 'dogfooding marker' "$HOME/.local/share/vulpra/default/sentinel"

# No caller can override the mode-specific profile selection.
for mode in run qa; do
  if bash "$repo/nix/vulpra" "$mode" --profile "$HOME/.mozilla/firefox" >/dev/null 2>&1; then
    echo "ERROR: $mode accepted a profile-selection override" >&2
    exit 1
  fi
done
grep -Fxq 'unchanged Firefox profile' "$HOME/.mozilla/firefox/sentinel"
grep -Fxq 'dogfooding marker' "$HOME/.local/share/vulpra/default/sentinel"

# No local binary means fail closed; do not fetch or build a replacement.
rm -- "$bin/vulpra"
for mode in run qa; do
  if bash "$repo/nix/vulpra" "$mode" >/dev/null 2>&1; then
    echo "ERROR: $mode ran without a compiled executable" >&2
    exit 1
  fi
done
echo 'PASS: dogfooding and QA profiles isolated; local launcher bypasses Nix and fails closed'
