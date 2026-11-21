#!/usr/bin/env bash
# Offline safety fixtures; synthetic browser only, never reads real profiles.
set -Eeuo pipefail
umask 077
die() { echo "FAIL: $*" >&2; exit 1; }
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash -n "$root/scripts/vulpra-security-qa.sh"
bash -n "$root/scripts/vulpra-security-qa-build.sh"
bash -n "$root/nix/vulpra"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
repo="$work/vulpra"
qa="$work/vulpra-security-qa"
mkdir -p "$repo/scripts" "$repo/nix" "$repo/browser/config" \
  "$repo/obj-vulpra-main-160/dist/bin" "$work/home/.mozilla/firefox" \
  "$work/home/.local/share/vulpra/default" "$work/bin"
cp -- "$root/scripts/vulpra-security-qa.sh" "$repo/scripts/vulpra-security-qa.sh"
cp -- "$root/scripts/vulpra-security-qa-build.sh" "$repo/scripts/vulpra-security-qa-build.sh"
mkdir -p "$repo/ci"
cp -- "$root/nix/vulpra" "$repo/nix/vulpra"
printf '# Vulpra synthetic fixture\n' > "$repo/AGENTS.md"
cat > "$repo/mach" <<'MACH'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$MOZCONFIG" == "$PWD/obj-vulpra-security-qa/native.mozconfig" ]] || exit 91
grep -Fq 'obj-vulpra-security-qa-build' "$MOZCONFIG" || exit 92
case "$1" in
  configure) : ;;
  build)
    out="$PWD/obj-vulpra-security-qa-build/dist/bin"
    mkdir -p "$out"
    cp -- "$PWD/../vulpra/obj-vulpra-main-160/dist/bin/vulpra" "$out/vulpra"
    cp -- "$PWD/../vulpra/obj-vulpra-main-160/dist/bin/application.ini" "$out/application.ini"
    ;;
  *) exit 93 ;;
esac
MACH
chmod 0755 "$repo/mach"
printf 'mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-linux\n' > "$repo/ci/mozconfig-linux"

printf '160.0.1\n' > "$repo/browser/config/version.txt"
printf '/obj*/\n' > "$repo/.gitignore"
printf 'Firefox sentinel\n' > "$work/home/.mozilla/firefox/sentinel"
printf 'Dogfood sentinel\n' > "$work/home/.local/share/vulpra/default/sentinel"
cat > "$repo/obj-vulpra-main-160/dist/bin/application.ini" <<'INI'
[App]
Name=Vulpra
Version=160.0.1
INI
# Gecko's real dist/bin/application.ini is an absolute link to obj*/build.
# Exercise that real layout instead of incorrectly testing only regular files.
mkdir -p "$repo/obj-vulpra-main-160/build"
mv -- "$repo/obj-vulpra-main-160/dist/bin/application.ini" \
  "$repo/obj-vulpra-main-160/build/application.ini"
ln -s "$repo/obj-vulpra-main-160/build/application.ini" \
  "$repo/obj-vulpra-main-160/dist/bin/application.ini"
cat > "$repo/obj-vulpra-main-160/dist/bin/vulpra" <<'BROWSER'
#!/usr/bin/env bash
# Test-only browser substitute, producing a valid PNG header.
set -Eeuo pipefail
[[ "$MOZ_HEADLESS" == 1 ]] || exit 90
screen=""
profile=""
while (($#)); do
  case "$1" in
    --screenshot) screen="$2"; shift 2 ;;
    --profile) profile="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$screen" && -d "$profile" ]] || exit 91
printf '%s\n' "$HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" \
  "$XDG_CONFIG_HOME" "$profile" > "$HOME/env-proof"
printf '\211PNG\r\n\032\n' > "$screen"
BROWSER
chmod 0755 "$repo/obj-vulpra-main-160/dist/bin/vulpra"
# Ensure no Nix/nom use in any QA command.
for name in nix nom; do
  cat > "$work/bin/$name" <<'NO_NIX'
#!/usr/bin/env bash
echo 'ERROR: security QA unexpectedly entered Nix/nom' >&2
exit 99
NO_NIX
  chmod 0755 "$work/bin/$name"
done
git -C "$repo" init -q -b main
git -C "$repo" add .
git -C "$repo" -c user.name='QA Fixture' \
  -c user.email='qa-fixture@example.invalid' commit -qm 'synthetic source'
original="$(git -C "$repo" rev-parse HEAD)"
export HOME="$work/home" PATH="$work/bin:$PATH"
bash "$repo/nix/vulpra" security-qa status > "$work/status"
grep -Fq 'QA worktree: not set up' "$work/status"
if bash "$repo/nix/vulpra" security-qa headless >/dev/null 2>&1; then
  die 'headless ran before setup'
fi
if bash "$repo/nix/vulpra" security-qa verify >/dev/null 2>&1; then
  die 'verify accepted missing snapshot'
fi
bash "$repo/nix/vulpra" security-qa setup > "$work/setup"
[[ -f "$qa/.git" ]] || die 'registered QA Git worktree missing'
[[ "$(git -C "$qa" rev-parse HEAD)" == "$original" ]] ||
  die 'QA pinned to wrong commit'
[[ -z "$(git -C "$qa" symbolic-ref --short -q HEAD || :)" ]] ||
  die 'QA should be detached, not main'
if bash "$repo/nix/vulpra" security-qa setup >/dev/null 2>&1; then
  die 'duplicate setup unexpectedly overwrote a worktree'
fi
# A plausible application.ini outside the native object directory must fail
# even when it claims to be Vulpra 160.0.1.
cp -- "$repo/obj-vulpra-main-160/build/application.ini" "$work/outside.ini"
ln -sfn "$work/outside.ini" "$repo/obj-vulpra-main-160/dist/bin/application.ini"
if bash "$repo/nix/vulpra" security-qa snapshot >/dev/null 2>&1; then
  die 'snapshot accepted application.ini escaping the native object directory'
fi
ln -sfn "$repo/obj-vulpra-main-160/build/application.ini" \
  "$repo/obj-vulpra-main-160/dist/bin/application.ini"
# A live Gecko browser may leave a hostname:PID 'lock' symlink with no
# readable target. A naïve cp -aL fails while copying the executable tree.
ln -s 'host.example.invalid:+12345' "$repo/obj-vulpra-main-160/dist/bin/lock"
printf 'runtime lock fixture\n' > "$repo/obj-vulpra-main-160/dist/bin/.parentlock"
bash "$repo/nix/vulpra" security-qa snapshot > "$work/snapshot"

name="$(cat "$qa/obj-vulpra-security-qa/active-snapshot")"
[[ "$name" =~ ^[0-9a-f]{12}-[0-9a-f]{12}$ ]] || die 'invalid snapshot identifier'
app="$qa/obj-vulpra-security-qa/snapshots/$name/app/vulpra"
[[ -x "$app" ]] || die 'snapshot executable missing'
[[ ! -e "$qa/obj-vulpra-security-qa/snapshots/$name/app/lock" &&
   ! -L "$qa/obj-vulpra-security-qa/snapshots/$name/app/lock" &&
   ! -e "$qa/obj-vulpra-security-qa/snapshots/$name/app/.parentlock" ]] ||
  die 'snapshot included live browser runtime lock state'
[[ -L "$repo/obj-vulpra-main-160/dist/bin/lock" &&
   -f "$repo/obj-vulpra-main-160/dist/bin/.parentlock" ]] ||
  die 'snapshot mutated the running browser lock entries'
[[ -f "$qa/obj-vulpra-security-qa/snapshots/$name/app/application.ini" &&
   ! -L "$qa/obj-vulpra-security-qa/snapshots/$name/app/application.ini" ]] ||
  die 'snapshot did not dereference the internal Gecko application.ini symlink'
cmp "$app" "$repo/obj-vulpra-main-160/dist/bin/vulpra"
manifest="$qa/obj-vulpra-security-qa/snapshots/$name/manifest.txt"
grep -Eq '^application_ini_sha256=[0-9a-f]{64}$' "$manifest" ||
  die 'snapshot did not record application.ini digest'
bash "$repo/nix/vulpra" security-qa verify > "$work/verify"
grep -Fq 'PASS: independent QA executable' "$work/verify"
# Tampered copied ELF must fail closed without launching.
printf '\n# corrupt only the copied QA executable\n' >> "$app"
if bash "$repo/nix/vulpra" security-qa verify >/dev/null 2>&1; then
  die 'verify accepted modified QA executable'
fi
if bash "$repo/nix/vulpra" security-qa headless >/dev/null 2>&1; then
  die 'headless started a modified QA executable'
fi
cp -- "$repo/obj-vulpra-main-160/dist/bin/vulpra" "$app"
bash "$repo/nix/vulpra" security-qa verify > "$work/verify-restored"
# Tampered copied application.ini must fail closed even if still Version=160.0.1.
printf '\n# invalid added ini line\n' >> "$qa/obj-vulpra-security-qa/snapshots/$name/app/application.ini"
if bash "$repo/nix/vulpra" security-qa verify >/dev/null 2>&1; then
  die 'verify accepted modified QA application.ini'
fi
cp -- "$repo/obj-vulpra-main-160/dist/bin/application.ini" \
  "$qa/obj-vulpra-security-qa/snapshots/$name/app/application.ini"
bash "$repo/nix/vulpra" security-qa verify > "$work/verify-ini-restored"
# Legacy snapshots created before INI digest support remain usable.
sed -i '/^application_ini_sha256=/d' "$manifest"
bash "$repo/nix/vulpra" security-qa verify > "$work/verify-legacy"
grep -Fq 'LIMIT: legacy snapshot' "$work/verify-legacy"

if bash "$repo/nix/vulpra" security-qa snapshot >/dev/null 2>&1; then
  die 'duplicate snapshot unexpectedly overwrote files'
fi
bash "$repo/nix/vulpra" security-qa headless > "$work/out"
grep -Fq 'PASS: isolated Vulpra QA headless screenshot' "$work/out"
shopt -s nullglob
runs=("$qa/obj-vulpra-security-qa/runtime"/run.*)
[[ "${#runs[@]}" -eq 1 ]] || die 'unexpected QA run count'
run="${runs[0]}"
mapfile -t proof < "$run/home/env-proof"
[[ "${proof[0]}" == "$run/home" && "${proof[1]}" == "$run/data" &&
   "${proof[2]}" == "$run/cache" && "${proof[3]}" == "$run/config" &&
   "${proof[4]}" == "$run/profile" ]] ||
  die 'browser environment escaped disposable QA paths'
[[ "$(git -C "$repo" rev-parse HEAD)" == "$original" &&
   "$(git -C "$repo" symbolic-ref --short HEAD)" == main ]] ||
  die 'daily main source branch altered'
# A dirty QA checkout must not be reset/silently discarded.
printf '\n# temporary QA source change\n' >> "$qa/AGENTS.md"
if bash "$repo/nix/vulpra" security-qa sync >/dev/null 2>&1; then
  die 'sync unexpectedly discarded changes from QA worktree'
fi
git -C "$qa" checkout -- AGENTS.md
# A new main commit must not silently combine old QA source with a new binary.
printf '\n# revised synthetic source\n' >> "$repo/AGENTS.md"
git -C "$repo" add AGENTS.md
git -C "$repo" -c user.name='QA Fixture' -c user.email='qa-fixture@example.invalid' \
  commit -qm 'next synthetic main source'
latest="$(git -C "$repo" rev-parse HEAD)"
if bash "$repo/nix/vulpra" security-qa snapshot >/dev/null 2>&1; then
  die 'snapshot accepted source commit mismatch'
fi
bash "$repo/nix/vulpra" security-qa sync > "$work/sync"
[[ "$(git -C "$qa" rev-parse HEAD)" == "$latest" &&
   "$(git -C "$repo" symbolic-ref --short HEAD)" == main ]] ||
  die 'safe detached QA source sync did not preserve main'
[[ -x "$app" ]] || die 'sync removed existing QA binary snapshot'
grep -Fxq 'Firefox sentinel' "$work/home/.mozilla/firefox/sentinel"
grep -Fxq 'Dogfood sentinel' "$work/home/.local/share/vulpra/default/sentinel"
# Source can be rebuilt in the detached worktree only, in a separate object
# directory. These fake mach invocations validate paths, not Firefox compile.
builder="$qa/scripts/vulpra-security-qa-build.sh"
[[ -f "$builder" ]] || die 'native QA build script missing from detached worktree'
bash "$builder" --preflight > "$work/build-preflight"
[[ ! -e "$qa/obj-vulpra-security-qa/native.mozconfig" ]] ||
  die 'QA preflight unexpectedly generated a mozconfig'
mkdir -p "$work/mock-libclang"
mkdir -p "$repo/toolkit/crashreporter/google-breakpad/src/third_party/lss"
printf '/* synthetic Breakpad header */\n' > "$repo/toolkit/crashreporter/google-breakpad/src/third_party/lss/linux_syscall_support.h"
export VULPRA_NIX_DEV=1 VULPRA_NIX_LIBCLANG_PATH="$work/mock-libclang"
bash "$builder" --build --jobs 2 > "$work/build"
native="$qa/obj-vulpra-security-qa-build/dist/bin"
[[ -x "$native/vulpra" && -f "$native/application.ini" ]] ||
  die 'mock native output was not built in detached QA tree'
grep -Fq 'obj-vulpra-security-qa-build' "$qa/obj-vulpra-security-qa/native.mozconfig"
[[ ! -d "$repo/obj-vulpra-security-qa-build" ]] ||
  die 'QA build created output inside daily source'
bash "$repo/nix/vulpra" security-qa headless-build > "$work/headless-build"
grep -Fq 'PASS: isolated Vulpra QA headless screenshot' "$work/headless-build"
if bash "$repo/nix/vulpra" security-qa headless --profile \
  "$work/home/.mozilla/firefox" >/dev/null 2>&1; then
  die 'QA accepted profile override'
fi
echo 'PASS: detached QA source, checksum copied browser, private HOME/XDG/profile and test screenshot'
echo 'PASS: copied snapshot verification rejects tampered ELF/INI, blocks headless, accepts legacy snapshots'
echo 'PASS: dirty worktree sync rejected, clean detached sync to newer main accepted; daily sentinels preserved'
echo 'LIMIT: synthetic executable, not an actual Gecko browser security result'
