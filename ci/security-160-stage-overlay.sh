#!/usr/bin/env bash
# Stage a BOUNDED Vulpra overlay over an authenticated Firefox 160 checkout.
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

# Resolve and reject dangerous destinations BEFORE mkdir. Otherwise a
# rejected nested path would leave even an empty directory in a source tree.
dest="$(realpath -m -- "$3")" || fail 'unable to canonicalize output'
case "$dest/" in
  "$upstream/"*|"$repo/"*) fail 'output must be outside BOTH source checkouts' ;;
esac
test "$dest" != "$upstream" && test "$dest" != "$repo" ||
  fail 'output cannot replace a source checkout'
mkdir -p -- "$dest"
dest="$(cd -- "$dest" && pwd -P)"
case "$dest/" in
  "$upstream/"*|"$repo/"*) fail 'resolved output entered a source checkout' ;;
esac
test "$dest" != "$upstream" && test "$dest" != "$repo" ||
  fail 'resolved output is a source checkout'
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

# For these four selected files, Vulpra's 159 beta upstream base
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

# Ten further modifications have identical Firefox 159 beta / 160 release
# upstream source bases. Pinned preimages and Vulpra postimages only.
# Entire engine and component integration still need native QA.
count=0
while read -r path upstream_sha vulpra_sha; do
  test -n "$path" && test -n "$upstream_sha" && test -n "$vulpra_sha" ||
    fail 'invalid stable-base overlay record'
  hash_is "$upstream/$path" "$upstream_sha"
  hash_is "$repo/$path" "$vulpra_sha"
  mkdir -p -- "$dest/$(dirname -- "$path")"
  cp -- "$repo/$path" "$dest/$path"
  hash_is "$dest/$path" "$vulpra_sha"
  count=$((count+1))
done <<'PINNED_STABLE_BASE_OVERLAYS'
browser/components/asrouter/moz.build 4ba87e39bdf56c986acc8b227b34b70536c070e1 2bfad6b6bf4a1628a5c08d138ca5f6a5966c189b
browser/extensions/newtab/addon-jar.mn 0410678376ca1babfa9db91ca4860020fd5c9c51 6b3cce522bbff4ae6b3df3b1c44a771e64392c67
browser/extensions/newtab/build-newtab-bundles.py a4cb551e77005df379305ac75fdb1102eef361bf a04a3f30ff47109f206311e2f1dad687fa1f1430
browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/AdBanner/AdBanner.jsx 96b29e32c41b7704f03d54621715e30ee00663e2 e1c3614ad411e764748edea5291d4dc92978dbf9
browser/extensions/newtab/webpack.system-addon.config.js 537d63d154d067ffa349f5a791678d574379e8d5 0d67a72d2e000d7ba01f4d0f59b640578975559c
dom/webgpu/tests/cts/checkout/node.tsconfig.json 74707d408d492c0957b059aea4e415052d1fa809 deefd7eda5dd2fe9bc4304fdac42b608dc330943
python/mozbuild/mozbuild/testing.py f324f16cacd9303dd47bc4ffef8c46cbc58aadf0 cb73fff42ce304134bc71fa9196efbb87fd6d8a1
toolkit/components/nimbus/moz.build b131bc08916f62944fc881a4f3134cbe1cfd90ed 263de482d19bf6afa5ad0ae2e986ffad6d007456
toolkit/components/normandy/moz.build 107d857760c8343fc32294e06353f3bf51aada2e 42a6649255080bda8d1d5cfd787d2c52b7e1103e
toolkit/modules/AppConstants.sys.mjs 9dc427fd61aea11b6839d542af39c4b887b52b6f b68feb206bf9e02ff159b4105181ed3129360b47
PINNED_STABLE_BASE_OVERLAYS
test "$count" -eq 10 || fail 'expected ten additional stable-base overlays'

# Two upstream-modified 160 source files need context-specific ports.
# Independently proved that removing exactly these Vulpra 159 edits
# reproduces the original 159 beta file. The 160 source is NOT overwritten
# with the beta file. Reapply the exact small patches at unique 160 anchors.
hash_is "$repo/browser/components/BrowserComponents.manifest" d8f8952b290ff81f6a78a05c66f747f9bc1156d3
hash_is "$upstream/browser/components/BrowserComponents.manifest" a5b11f0ab58827a6599ddf6b2c195657a048c1f9
hash_is "$repo/browser/components/DesktopActorRegistry.sys.mjs" 341bb4fd07c8e43c3f16d8f256608730df272d39
hash_is "$upstream/browser/components/DesktopActorRegistry.sys.mjs" 52cfb1668493ef557419ceb2aff36967de1d8712

mkdir -p -- "$dest/browser/components"
awk '
  {
    if ($0 == "category browser-quit-application-granted resource://normandy/Normandy.sys.mjs Normandy.uninit") {
      print "#ifdef MOZ_NORMANDY"
      print
      print "#endif"
      count_quit++
    } else {
      print
    }
    if ($0 == "category browser-before-ui-startup resource://normandy/Normandy.sys.mjs Normandy.init") {
      inside_init=1
    } else if (inside_init && $0 == "#endif") {
      print "#ifdef XP_LINUX"
      print "#ifndef MOZ_NORMANDY"
      print "# The opt-in Linux build initializes Nimbus after the UI without the"
      print "# missing Normandy recipe runner. Keep the normal startup untouched."
      print "category browser-before-ui-startup moz-src:///toolkit/components/nimbus/NimbusBootstrap.sys.mjs NimbusBootstrap.init"
      print "#endif"
      print "#endif"
      count_init++
      inside_init=0
    }
  }
  END {
    if (count_init != 1 || count_quit != 1) exit 1
  }
' "$upstream/browser/components/BrowserComponents.manifest" > "$dest/browser/components/BrowserComponents.manifest"
hash_is "$dest/browser/components/BrowserComponents.manifest" 35571da687bec3207d3d28f03c959d6cd6bc2b9e

awk '
  {
    if ($0 == "    ActorManagerParent.addJSProcessActors(JSPROCESSACTORS);") {
      print "    // about:studies is omitted from no-Normandy builds; avoid registering"
      print "    // an actor whose parent and child are absent from the lean package."
      print "    if (!AppConstants.MOZ_NORMANDY) {"
      print "      delete JSWINDOWACTORS.ShieldFrame;"
      print "    }"
      count_init++
    }
    print
    if ($0 == "import { ActorManagerParent } from \"resource://gre/modules/ActorManagerParent.sys.mjs\";") {
      print "import { AppConstants } from \"resource://gre/modules/AppConstants.sys.mjs\";"
      count_import++
    }
  }
  END {
    if (count_init != 1 || count_import != 1) exit 1
  }
' "$upstream/browser/components/DesktopActorRegistry.sys.mjs" > "$dest/browser/components/DesktopActorRegistry.sys.mjs"
hash_is "$dest/browser/components/DesktopActorRegistry.sys.mjs" e6c50e85908a4c870185390d61e396e7004414cc

# The Firefox 160 toolkit-components registry gained a "widgets" directory.
# Reapply the exact Vulpra 159 Normandy comment/split to the 160 file, without
# overwriting the new widgets registration or any other 160 component.
hash_is "$repo/toolkit/components/moz.build" 0812acb2ebb454eacba5408c7e08b8cdf99ec755
hash_is "$upstream/toolkit/components/moz.build" 397419b65bcbcb54508c3515b5bfd45429d6da96
mkdir -p -- "$dest/toolkit/components"
awk '
  {
    if ($0 == "    DIRS += [\"messaging-system\", \"normandy\"]") {
      print "    DIRS += [\"messaging-system\"]"
      print "    # The opt-in variant still traverses Normandy to ship only the small"
      print "    # shared helper jar required by Nimbus and browser targeting. Its own"
      print "    # moz.build selects that jar when MOZ_NORMANDY is disabled."
      print "    DIRS += [\"normandy\"]"
      count++
    } else {
      print
    }
  }
  END {
    if (count != 1) exit 1
  }
' "$upstream/toolkit/components/moz.build" > "$dest/toolkit/components/moz.build"
hash_is "$dest/toolkit/components/moz.build" 4c22a26aee7a8b163e7b315864f5e4dd11946f52
grep -Fqx '    "widgets",' "$dest/toolkit/components/moz.build" ||
  fail 'Firefox 160 new widgets component registry was lost'

echo 'PASS: eighteen exact-source Firefox 160 Vulpra overlay files staged OUTSIDE both source trees'
echo 'PASS: modern Firefox 160 preference file retained + Firefox compatibility and Vulpra branding'
echo 'LIMIT: no actual Firefox 160 tree modified, no complete Vulpra port, native build or security-current claim'
