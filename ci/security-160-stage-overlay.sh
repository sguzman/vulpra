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

# ASRouter: exactly two old Vulpra opt-in promo guards cleanly revert to
# original Mozilla 159 beta source; 160 retained both corresponding callsites.
# Preserve the full modern 160 file and port ONLY these exact conditionals.
hash_is "$repo/browser/components/asrouter/modules/ASRouter.sys.mjs" 2fac89b4c02444fed4ee79d24d19fce445596e06
hash_is "$upstream/browser/components/asrouter/modules/ASRouter.sys.mjs" ed2ff82a6965fe039d02f1517a6c1358c13e75dd
mkdir -p -- "$dest/browser/components/asrouter/modules"
awk '
  {
    if ($0 == "        lazy.SidebarChatBotPromo.showPromo(browser, message, force);") {
      print "        // The isolated Linux candidate physically omits this lazy module."
      print "        // This immutable build flag prevents loading a missing resource,"
      print "        // including when a remote message supplies this template."
      print "        if (!AppConstants.VULPRA_NO_ASROUTER_PROMOS) {"
      print "          lazy.SidebarChatBotPromo.showPromo(browser, message, force);"
      print "        }"
      sidebar++
    } else if ($0 == "        lazy.SmartWindowNewTabPromo.showPromo(browser, message, trigger, force);") {
      print "        if (!AppConstants.VULPRA_NO_ASROUTER_PROMOS) {"
      print "          lazy.SmartWindowNewTabPromo.showPromo("
      print "            browser,"
      print "            message,"
      print "            trigger,"
      print "            force"
      print "          );"
      print "        }"
      smart++
    } else {
      print
    }
  }
  END {
    if (sidebar != 1 || smart != 1) exit 1
  }
' "$upstream/browser/components/asrouter/modules/ASRouter.sys.mjs" > "$dest/browser/components/asrouter/modules/ASRouter.sys.mjs"
hash_is "$dest/browser/components/asrouter/modules/ASRouter.sys.mjs" d02c8563be6db6d65f6dbbc2ddb12b4bdfc9fe4b

# The optional --disable-tests emitter guard was exactly the only delta in
# Vulpra's 159 emitter; keep all updated upstream Firefox 160 emitter internals.
hash_is "$repo/python/mozbuild/mozbuild/frontend/emitter.py" 3d591dee5d98302d87d972e4118ca77f591eb594
hash_is "$upstream/python/mozbuild/mozbuild/frontend/emitter.py" 0a8aa0b508003401adb70772860fa147809d2d97
mkdir -p -- "$dest/python/mozbuild/mozbuild/frontend"
awk '
  {
    print
    if ($0 == "    def _process_test_manifests(self, context):") {
      print "        # Nothing to install or validate for a --disable-tests build."
      print "        if not context.config.substs.get(\"ENABLE_TESTS\"):"
      print "            return"
      print ""
      found++
    }
  }
  END {
    if (found != 1) exit 1
  }
' "$upstream/python/mozbuild/mozbuild/frontend/emitter.py" > "$dest/python/mozbuild/mozbuild/frontend/emitter.py"
hash_is "$dest/python/mozbuild/mozbuild/frontend/emitter.py" 564e247580cba4b9e34a2c72be0f2ed64cacac47

# Android toolchain hash list: two references to absent Android Gradle-plugin
# files were removed by Vulpra. Original 159 delta is exactly two identical
# substitutions, and 160 still has the same references. Preserve Firefox
# 160's NEW Robolectric job and all other Android CI improvements in source.
hash_is "$repo/taskcluster/kinds/toolchain/android.yml" b1de1ef5ccbd441544029a544dc3662c9458ff70
hash_is "$upstream/taskcluster/kinds/toolchain/android.yml" 2372d61733194333175d911d28be6be14f7d7683
mkdir -p -- "$dest/taskcluster/kinds/toolchain"
awk '
  $0 == "            - \x27mobile/android/android-components/plugins/dependencies/src/main/java/ApplicationServices.kt\x27" {
    if ((getline next_line) <= 0 ||
        next_line != "            - \x27mobile/android/android-components/plugins/dependencies/src/main/java/DependenciesPlugin.kt\x27") {
      exit 2
    }
    print "            # Vulpra Linux-only source pruning removed Android Components\x27 Gradle plugin."
    print "            # The Android Gradle dependency tasks are unsupported in this fork."
    print "            # Do not hash paths absent from the source tree while resolving Linux toolchains."
    count++
    next
  }
  { print }
  END { if (count != 2) exit 1 }
' "$upstream/taskcluster/kinds/toolchain/android.yml" > "$dest/taskcluster/kinds/toolchain/android.yml"
hash_is "$dest/taskcluster/kinds/toolchain/android.yml" 2b2f399363ffdb14c5c96e5f16ef2def162f02ba
grep -Fq 'linux64-android-robolectric-jars:' "$dest/taskcluster/kinds/toolchain/android.yml" ||
  fail 'Firefox 160 Robolectric build job missing from adapted source'

# New Tab: exact Vulpra 159 beta delta is an optional AdsFeed factory
# suppression in FEEDS_CONFIG. Keep all Firefox 160 feed lifecycle changes.
hash_is "$repo/browser/extensions/newtab/lib/ActivityStream.sys.mjs" e0b0eef5a3f4a9814888b60f5617d105db739454
hash_is "$upstream/browser/extensions/newtab/lib/ActivityStream.sys.mjs" 6fd9e6c62769bc435577280d468eba1f387ff0f8
mkdir -p -- "$dest/browser/extensions/newtab/lib"
awk '
  {
    print
    if ($0 == "for (const config of FEEDS_DATA) {") {
      print "  // Preserve all other New Tab feeds; this opt-in Linux variant does not"
      print "  // register or instantiate the independently packaged sponsored AdsFeed."
      print "  if (AppConstants.VULPRA_NO_NEWTAB_ADSFEED && config.name === \"adsfeed\") {"
      print "    continue;"
      print "  }"
      count++
    }
  }
  END { if (count != 1) exit 1 }
' "$upstream/browser/extensions/newtab/lib/ActivityStream.sys.mjs" > "$dest/browser/extensions/newtab/lib/ActivityStream.sys.mjs"
hash_is "$dest/browser/extensions/newtab/lib/ActivityStream.sys.mjs" 96c542d338f72c22f448a799e6b1b2a569c8c6f3

# Discovery Stream: original Vulpra beta delta was one lazy AppConstants getter
# and two AdsFeed-enabled checks. Never replace 160 story/personalization logic.
hash_is "$repo/browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs" aa6239b92899d0ee3a0a57a6023d89109eb8829f
hash_is "$upstream/browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs" 802fd3265b77c55597a7e0d9f5f8cc35a3a21130
awk '
  {
    if ($0 == "  AdsClient: \"resource://newtab/lib/AdsClient.sys.mjs\",") {
      print "  AppConstants: \"resource://gre/modules/AppConstants.sys.mjs\","
      count_import++
    }
    if ($0 == "    const adsFeedEnabled =") {
      print "    // No AdsFeed factory exists in the opt-in package even if Nimbus/remote"
      print "    // prefs enable this upstream pref. Use the retained direct-fetch/AdsClient"
      print "    // path instead of reading a nonexistent state.Ads payload."
      print
      print "      !lazy.AppConstants.VULPRA_NO_NEWTAB_ADSFEED &&"
      count_cached++
    } else if ($0 == "    const adsFeedEnabled = state.Prefs.values[PREF_UNIFIED_ADS_ADSFEED_ENABLED];") {
      print "    const adsFeedEnabled ="
      print "      !lazy.AppConstants.VULPRA_NO_NEWTAB_ADSFEED &&"
      print "      state.Prefs.values[PREF_UNIFIED_ADS_ADSFEED_ENABLED];"
      count_delete++
    } else {
      print
    }
  }
  END { if (count_import != 1 || count_cached != 1 || count_delete != 1) exit 1 }
' "$upstream/browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs" > "$dest/browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs"
hash_is "$dest/browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs" 2f4046cdf9d02cef0260da14acd4fd7c859cf854

# TopSites: original Vulpra beta delta was one lazy AppConstants getter and
# one optional AdsFeed check. Preserve new 160 Top Sites application logic.
hash_is "$repo/browser/extensions/newtab/lib/TopSitesFeed.sys.mjs" 25ece297c5c5e3a4495d1d89c1103c3c52c8ec13
hash_is "$upstream/browser/extensions/newtab/lib/TopSitesFeed.sys.mjs" 3510f65e71cd4f250f5fc6b591e0096ee5276015
awk '
  {
    if ($0 == "  AdsClient: \"resource://newtab/lib/AdsClient.sys.mjs\",") {
      print "  AppConstants: \"resource://gre/modules/AppConstants.sys.mjs\","
      count_import++
    }
    if ($0 == "    const adsFeedEnabled = state.Prefs.values[PREF_UNIFIED_ADS_ADSFEED_ENABLED];") {
      print "    // Even when a remote pref enables AdsFeed, the opt-in build never"
      print "    // registers its factory. Fall back to existing direct/AdsClient tiles."
      print "    const adsFeedEnabled ="
      print "      !lazy.AppConstants.VULPRA_NO_NEWTAB_ADSFEED &&"
      print "      state.Prefs.values[PREF_UNIFIED_ADS_ADSFEED_ENABLED];"
      count_ads++
    } else {
      print
    }
  }
  END { if (count_import != 1 || count_ads != 1) exit 1 }
' "$upstream/browser/extensions/newtab/lib/TopSitesFeed.sys.mjs" > "$dest/browser/extensions/newtab/lib/TopSitesFeed.sys.mjs"
hash_is "$dest/browser/extensions/newtab/lib/TopSitesFeed.sys.mjs" c68ac1440fe93656a563210ecb9d55d79760a573

# New Tab train-hop XPI: Vulpra 159 beta changed only the wildcard
# library manifest to an optional AdsFeed-less allowlist. Firefox 160 has
# exactly the same old wildcard anchor; its new per-locale preview Fluent
# packaging is elsewhere and MUST be retained. The exact 160 root library
# inventory has 47 entries; the opt-in list covers the other 46, excludes
# AdsFeed.sys.mjs, and leaves normal builds on the original wildcard path.
hash_is "$repo/browser/extensions/newtab/webext-glue/moz.build" 2637aaf669255aa633ce1ccd50e7ae5f50d102ba
hash_is "$upstream/browser/extensions/newtab/webext-glue/moz.build" 60f1e353ae2ac38f8f223b4e48581468782f143c
mkdir -p -- "$dest/browser/extensions/newtab/webext-glue"
awk '
  FNR == NR {
    if ($0 == "# Maintain the train-hop XPI\x27s library contents in sync with addon-jar.mn.") {
      grab=1
      starts++
    }
    if ($0 == "FINAL_TARGET_FILES.common += [") {
      if (grab) {
        grab=0
        ends++
      }
    }
    if (grab) patch=patch $0 "\n"
    next
  }
  $0 == "FINAL_TARGET_FILES.lib += [" {
    printf "%s", patch
    if ((getline line) <= 0 || line != "    \"../lib/**\",") exit 2
    if ((getline line) <= 0 || line != "]") exit 2
    replacement_count++
    next
  }
  { print }
  END {
    if (starts != 1 || ends != 1 || replacement_count != 1) exit 1
  }
' "$repo/browser/extensions/newtab/webext-glue/moz.build" "$upstream/browser/extensions/newtab/webext-glue/moz.build" > "$dest/browser/extensions/newtab/webext-glue/moz.build"
hash_is "$dest/browser/extensions/newtab/webext-glue/moz.build" 6301413e4e5a0f7caf6d2b8195bfc222d3646b7c
grep -Fq 'newtabPreview.ftl' "$dest/browser/extensions/newtab/webext-glue/moz.build" ||
  fail 'Firefox 160 newtab preview localization was dropped'
grep -Fq 'if CONFIG["VULPRA_NO_NEWTAB_ADSFEED"]:' "$dest/browser/extensions/newtab/webext-glue/moz.build" ||
  fail 'optional AdsFeed-less allowlist missing'
if grep -Fq '    "../lib/AdsFeed.sys.mjs",' "$dest/browser/extensions/newtab/webext-glue/moz.build"; then
  fail 'AdsFeed inadvertently enabled in opt-in allowlist'
fi

# Normandy: Firefox 160 deleted ClientEnvironment.sys.mjs, and removed the
# old normandy-content stanza. Keeping the old Vulpra 159 manifest would
# reference a missing file and overwrite the new upstream resource policy.
# Keep the entire standard Firefox 160 Normandy manifest intact beneath
# MOZ_NORMANDY. In the opt-in experimental branch, only list three still-
# existing helpers. This is a *new adaptation*, not a byte-for-byte Vulpra
# 159 resource contract; native verification is still required.
hash_is "$repo/toolkit/components/normandy/jar.mn" 4fd6e7e67d1677030c7997a6641d176cb0dfdab6
hash_is "$upstream/toolkit/components/normandy/jar.mn" aba68ea151c317ef8328baa7ff78fbac1fc2767a
hash_is "$upstream/toolkit/components/normandy/lib/NormandyApi.sys.mjs" cce2b00d6febc9f8c73503e2adce217f4ee73c2f
hash_is "$upstream/toolkit/components/normandy/lib/NormandyUtils.sys.mjs" 7db12c59b7324fe84868b6fb8bf8b6e492a967d5
hash_is "$upstream/toolkit/components/normandy/schemas/LegacyHeartbeat.schema.json" 3bb1f18fc4555b45ce60f98235f31282fdc71776
mkdir -p -- "$dest/toolkit/components/normandy"
awk '
  {
    print
    if ($0 == "% resource normandy %res/normandy/") {
      print ""
      print "#ifdef MOZ_NORMANDY"
      count++
    }
  }
  END { if (count != 1) exit 1 }
' "$upstream/toolkit/components/normandy/jar.mn" > "$dest/toolkit/components/normandy/jar.mn"
cat >> "$dest/toolkit/components/normandy/jar.mn" <<'NO_NORMANDY_HELPERS'
#else
  res/normandy/lib/NormandyApi.sys.mjs (./lib/NormandyApi.sys.mjs)
  res/normandy/lib/NormandyUtils.sys.mjs (./lib/NormandyUtils.sys.mjs)
  res/normandy/schemas/LegacyHeartbeat.schema.json (./schemas/LegacyHeartbeat.schema.json)
#endif
NO_NORMANDY_HELPERS
hash_is "$dest/toolkit/components/normandy/jar.mn" 06317cdd540b6e32eeb195b555923795894f5b0e
if grep -Fq 'ClientEnvironment.sys.mjs' "$dest/toolkit/components/normandy/jar.mn"; then
  fail 'deleted Firefox 160 Normandy ClientEnvironment was reintroduced'
fi
if grep -Fq 'normandy-content' "$dest/toolkit/components/normandy/jar.mn"; then
  fail 'removed upstream Normandy content package was reintroduced'
fi

echo 'PASS: twenty-six exact-source Firefox 160 Vulpra overlay files staged OUTSIDE both source trees'
echo 'PASS: modern Firefox 160 preference file retained + Firefox compatibility and Vulpra branding'
echo 'LIMIT: no actual Firefox 160 tree modified, no complete Vulpra port, native build or security-current claim'
