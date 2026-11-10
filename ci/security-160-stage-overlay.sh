#!/usr/bin/env bash
# Stage a MINIMAL Vulpra overlay over an authenticated Firefox 160 checkout.
# This does not port the whole browser, compile Gecko, touch main or alter the
# user's local checkout. FAIL CLOSED if any pinned upstream/source blob differs.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if [[ "$#" != 3 || "$1" != "--stage" ]]; then
  echo 'Usage: security-160-stage-overlay.sh --stage <mozilla-firefox-160-checkout> <empty-output-dir>' >&2
  exit 2
fi

repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
upstream="$(cd -- "$2" && pwd -P)" || fail 'upstream directory missing'
test -d "$upstream/.git" || test -f "$upstream/.git" || fail 'upstream Git checkout missing'
expected_upstream="2887d9de1f69c0e9776413da80e7ba0d1225dd9b"
test "$(git -C "$upstream" rev-parse HEAD)" = "$expected_upstream" ||
  fail 'refusing to stage against anything but authenticated Firefox 160 release commit'

mkdir -p -- "$3"
dest="$(cd -- "$3" && pwd -P)"
case "$dest/" in
  "$upstream/"*|"$repo/"*) fail 'output must be outside BOTH source checkouts' ;;
esac
test "$dest" != "$upstream" && test "$dest" != "$repo" ||
  fail 'output cannot replace a source checkout'
test -z "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit)" ||
  fail 'output directory must initially be empty'

hash_is() {
  local path="$1" sha="$2"
  test -f "$path" && test ! -L "$path" ||
    fail "missing or symlinked source: $path"
  local actual
  actual="$(git hash-object -- "$path")" || fail "cannot hash: $path"
  test "$actual" = "$sha" || fail "source drift $path: expected $sha, got $actual"
}

# Upstream release files must match exact Mozilla tag contents.
hash_is "$upstream/browser/branding/unofficial/configure.sh" f42e11ddad27285de8c58e4e48fa979119c37a72
hash_is "$upstream/browser/branding/unofficial/locales/en-US/brand.ftl" 5eaea9a7c4e874640464aff1c123ae3058d98302
hash_is "$upstream/browser/branding/unofficial/pref/firefox-branding.js" f22dd0a51ccb367bbbb418d90aba6c8b6dbd7308
hash_is "$upstream/browser/moz.configure" 8979a2e4e8d92e9aa4478c397cf4891211608f24
hash_is "$upstream/browser/app/profile/firefox.js" 15a12b67bde1501b2070a19c77a6676943bc1df9

# For these four selected files only, Vulpra's 159 beta upstream base
# is byte-identical to the complete 160 release base. Their current Vulpra
# content therefore survives without dropping any upstream 160 edits.
hash_is "$repo/browser/branding/unofficial/configure.sh" 659250d7a9606c5a583b4d8f14a104a6cd390e19
hash_is "$repo/browser/branding/unofficial/locales/en-US/brand.ftl" 36b392d5fae6ba5ef1cb1a5a7cca823b6e74ec0b
hash_is "$repo/browser/branding/unofficial/pref/firefox-branding.js" 9308a1b26f339e0e89d959f0c4559eb7596a0fe6
hash_is "$repo/browser/moz.configure" 1d7a9bd2af8eb419e7f59d3f737c2fcf9c57995a

for path in \
  browser/branding/unofficial/configure.sh \
  browser/branding/unofficial/locales/en-US/brand.ftl \
  browser/branding/unofficial/pref/firefox-branding.js \
  browser/moz.configure; do
  mkdir -p -- "$dest/$(dirname -- "$path")"
  cp -- "$repo/$path" "$dest/$path"
done

# Firefox 160 modified its 192 KiB profile preference file since beta:
# NEVER copy Vulpra's outdated 159 firefox.js wholesale. Inject one already
# real-world tested preference into the exact 160 upstream file instead.
src="$upstream/browser/app/profile/firefox.js"
test "$(grep -Fxc '// screen.' "$src")" -eq 1 ||
  fail 'upstream pref insertion anchor changed'
if grep -Fq 'general.useragent.compatMode.firefox' "$src" ||
   grep -Fq 'general.useragent.override' "$src"; then
  fail 'upstream now owns a relevant UA pref: manual review required'
fi
mkdir -p -- "$dest/browser/app/profile"
awk '
  {
    print
    if ($0 == "// screen.") {
      print ""
      print "// Vulpra: keep a Firefox compatibility token for sites that otherwise"
      print "// deliver degraded layouts. Do not override the entire user agent or"
      print "// remove Vulpra\x27s app token. Verified with Google Search under Wayland."
      print "pref(\"general.useragent.compatMode.firefox\", true);"
    }
  }
' "$src" > "$dest/browser/app/profile/firefox.js"

# Independent, deterministic postimage checks. Does not need any changed
# output written into an actual Mozilla or Vulpra source tree.
hash_is "$dest/browser/branding/unofficial/configure.sh" 659250d7a9606c5a583b4d8f14a104a6cd390e19
hash_is "$dest/browser/branding/unofficial/locales/en-US/brand.ftl" 36b392d5fae6ba5ef1cb1a5a7cca823b6e74ec0b
hash_is "$dest/browser/branding/unofficial/pref/firefox-branding.js" 9308a1b26f339e0e89d959f0c4559eb7596a0fe6
hash_is "$dest/browser/moz.configure" 1d7a9bd2af8eb419e7f59d3f737c2fcf9c57995a
hash_is "$dest/browser/app/profile/firefox.js" 78f017eeca1cac668aaae4075713a5d648e947b2
test "$(grep -Fxc 'pref("general.useragent.compatMode.firefox", true);' \
  "$dest/browser/app/profile/firefox.js")" -eq 1 ||
  fail 'no unique Firefox-compatibility pref'
if grep -Fq 'general.useragent.override' "$dest/browser/app/profile/firefox.js"; then
  fail 'full UA override accidentally introduced'
fi

echo 'PASS: five exact-source Firefox 160 Vulpra overlay files staged OUTSIDE both source trees'
echo 'PASS: modern Firefox 160 preference file retained + Firefox compatibility and Vulpra branding'
echo 'LIMIT: no actual Firefox 160 tree modified, no complete Vulpra port, native build or security-current claim'
