#!/usr/bin/env python3
"""Source-pinned contract for optional New Tab PromoCard bundle substitution."""
from __future__ import annotations
from copy import deepcopy
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
FILES = {
    "configure": "browser/moz.configure",
    "generator": "browser/extensions/newtab/build-newtab-bundles.py",
    "webpack": "browser/extensions/newtab/webpack.system-addon.config.js",
    "banner": "browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/AdBanner/AdBanner.jsx",
    "real": "browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCard.jsx",
    "stub": "browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCardOptOut.jsx",
    "mozconfig": "ci/mozconfig-linux-m3-promocard-experiment",
    "newtab": "browser/extensions/newtab/lib/ActivityStream.sys.mjs",
}

def tracked(name: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), "show",
                                   "HEAD:" + FILES[name]], text=True)

def verify(f: dict[str, str]) -> None:
    checks = {
        "configure": ('env="VULPRA_EXPERIMENT_NO_NEWTAB_PROMOCARD"',
                      '@depends("VULPRA_EXPERIMENT_NO_NEWTAB_PROMOCARD", target_has_linux_kernel)',
                      'set_config("VULPRA_NO_NEWTAB_PROMOCARD", vulpra_no_newtab_promocard)',
                      'if disable and not linux:'),
        "generator": ('buildconfig.substs.get("VULPRA_NO_NEWTAB_PROMOCARD")',
                      '"VULPRA_NO_NEWTAB_PROMOCARD": (', '"MOZ_WEBPACK_DEPS": deps_file'),
        "webpack": ('process.env.VULPRA_NO_NEWTAB_PROMOCARD === "1"',
                    "new webpack.NormalModuleReplacementPlugin(",
                    "PromoCardOptOut.jsx",
                    '__VULPRA_NO_NEWTAB_PROMOCARD__: JSON.stringify(withoutPromoCard)',
                    "...promoCardPlugins(),", "withoutPromoCard\n    ? [", "    : [];"),
        "banner": ('import { PromoCard } from "../PromoCard/PromoCard.jsx";',
                   'typeof __VULPRA_NO_NEWTAB_PROMOCARD__ === "undefined" ||',
                   '!__VULPRA_NO_NEWTAB_PROMOCARD__;',
                   "promoCardAvailable &&",
                   'spoc.format === "billboard" &&',
                   "prefs[PREF_PROMOCARD_ENABLED] &&",
                   "prefs[PREF_PROMOCARD_VISIBLE];",
                   "{promoCardEnabled && <PromoCard />}",
                   "<SafeAnchor", "<ImpressionStats", "<AdBannerContextMenu"),
        "real": ("PROMO_CARD_CLICK", "PROMO_CARD_DISMISS",
                 "PROMO_CARD_IMPRESSION", "export { PromoCard };"),
        "stub": ("export const PromoCard = () => null;",),
        "mozconfig": ("export VULPRA_EXPERIMENT_NO_NEWTAB_PROMOCARD=1",
                      "obj-vulpra-linux-m3-promocard-experiment",
                      "MOZ_PARALLEL_BUILD=1"),
        "newtab": ("new lazy.TopStoriesFeed(", "new lazy.DiscoveryStreamFeed()",
                   "new lazy.TopSitesFeed()", "new lazy.PrefsFeed("),
    }
    for name, tokens in checks.items():
        for token in tokens:
            assert token in f[name], f"lost {name} dependency: {token}"
    for token in checks["real"]:
        assert token not in f["stub"], "original promo handler leaked into stub"

def self_test(f: dict[str, str]) -> None:
    changes = (
        ("configure", 'set_config("VULPRA_NO_NEWTAB_PROMOCARD", vulpra_no_newtab_promocard)'),
        ("generator", 'buildconfig.substs.get("VULPRA_NO_NEWTAB_PROMOCARD")'),
        ("webpack", "new webpack.NormalModuleReplacementPlugin("),
        ("webpack", "PromoCardOptOut.jsx"),
        ("webpack", "withoutPromoCard\n    ? ["),
        ("banner", 'typeof __VULPRA_NO_NEWTAB_PROMOCARD__ === "undefined" ||'),
        ("banner", "<AdBannerContextMenu"),
        ("stub", "export const PromoCard = () => null;"),
        ("mozconfig", "export VULPRA_EXPERIMENT_NO_NEWTAB_PROMOCARD=1"),
    )
    for name, token in changes:
        altered = deepcopy(f)
        altered[name] = altered[name].replace(token, "BROKEN_CASE", 1)
        try:
            verify(altered)
        except AssertionError:
            continue
        raise AssertionError("Mutation wrongly accepted: " + token)
    print(f"PASS: {len(changes)} deliberately broken source contracts rejected")

def main() -> None:
    files = {name: tracked(name) for name in FILES}
    verify(files)
    self_test(files)
    sha = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                                  text=True).strip()
    print("PASS: pinned PromoCard option, renderer and dependency contract", sha)
    print("SOURCE CONTRACT ONLY: no real Webpack/native/packaging acceptance")

if __name__ == "__main__":
    try:
        main()
    except (OSError, AssertionError, subprocess.CalledProcessError) as e:
        print("FAIL: PromoCard source contract:", e, file=sys.stderr)
        raise SystemExit(1)
