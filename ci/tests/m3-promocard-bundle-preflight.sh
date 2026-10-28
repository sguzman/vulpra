#!/usr/bin/env bash
# Compile BOTH real vendored Webpack New Tab bundles; never npm-install.
set -Eeuo pipefail
src="$1"
out="$2"
test -d "$src"
mkdir -p "$out/normal" "$out/optin"
cd "$src"
node --check browser/extensions/newtab/webpack.system-addon.config.js
python3 -m py_compile browser/extensions/newtab/build-newtab-bundles.py
python3 ci/tests/m3-promocard-bundle-contract.py
test -f third_party/node/node_modules/webpack/bin/webpack.js
test -d third_party/node/node_modules/@babel/preset-react
runner="$src/third_party/node/node_modules/webpack/bin/webpack.js"
config="$src/browser/extensions/newtab/webpack.system-addon.config.js"
cd browser/extensions/newtab
env MOZ_NODE_MODULES="$src/third_party/node/node_modules" \
  MOZ_WEBPACK_DEPS="$out/normal/deps.txt" \
  WEBPACK_CLI_SKIP_IMPORT_LOCAL=1 VULPRA_NO_NEWTAB_PROMOCARD=0 \
  node "$runner" --config "$config" --env "outputPath=$out/normal"
env MOZ_NODE_MODULES="$src/third_party/node/node_modules" \
  MOZ_WEBPACK_DEPS="$out/optin/deps.txt" \
  WEBPACK_CLI_SKIP_IMPORT_LOCAL=1 VULPRA_NO_NEWTAB_PROMOCARD=1 \
  node "$runner" --config "$config" --env "outputPath=$out/optin"
normal="$out/normal/activity-stream.bundle.js"
lean="$out/optin/activity-stream.bundle.js"
for pkg in "$normal" "$lean"; do
  test -s "$pkg"
  grep -Fq "newtab-label-sponsored-fixed" "$pkg"
  grep -Fq "NewtabRenderUtils" "$pkg"
done
grep -Fq "newtab-promo-card-title-addons" "$normal"
grep -Fq "firefox-mascot-prop-paintbucket-rgb.svg" "$normal"
if grep -Fq "newtab-promo-card-title-addons" "$lean"; then
  echo 'FAIL: original PromoCard title remains in opt-in bundle' >&2
  exit 1
fi
# The mascot asset is referenced by other New Tab renderers; its URL may
# remain even when this one PromoCard component has been omitted.
if grep -Fq "firefox-mascot-prop-paintbucket-rgb.svg" "$lean"; then
  echo 'NOTE: shared mascot URL remains elsewhere in New Tab; not omission evidence'
fi
echo "Baseline New Tab JS bytes: $(wc -c < "$normal")"
echo "Experimental New Tab JS bytes: $(wc -c < "$lean")"
cmp "$out/normal/vendor.bundle.js" "$out/optin/vendor.bundle.js"
# The real Webpack dependency graph is stronger than text-marker absence.
# It proves that the opt-in graph did not load the original PromoCard module.
python3 - "$src" "$out" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]).resolve()
out=Path(sys.argv[2]).resolve()
relative="browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/"
real=(root/relative/"PromoCard.jsx").resolve()
stub=(root/relative/"PromoCardOptOut.jsx").resolve()
def dependencies(variant):
    path=out/variant/"deps.txt"
    if not path.is_file() or not path.stat().st_size:
        raise AssertionError(f"Missing Webpack dependency evidence for {variant}")
    # Webpack fileDependencies can include paths from vendor and application.
    return {Path(x).resolve() for x in path.read_text().splitlines() if x.strip()}
normal=dependencies("normal")
optin=dependencies("optin")
assert real in normal, "Normal bundle did not compile the real PromoCard"
assert stub not in normal, "Null PromoCard substituted in normal browser"
assert stub in optin, "Experimental bundle did not compile the null PromoCard"
assert real not in optin, "Real PromoCard still a dependency of opt-in bundle"
print("PASS: independent Webpack dependency graphs prove real module vs null substitute")
PY
python3 - "$normal" "$lean" "$out/report.json" <<'PY'
import hashlib, json, pathlib, sys
normal, lean, out = map(pathlib.Path, sys.argv[1:])
full = normal.read_bytes()
small = lean.read_bytes()
report = {
    "schema_version":1,
    "test":"real_vendored_webpack_bundle_no_full_browser_compile",
    "normal_bundle_bytes":len(full), "optin_bundle_bytes":len(small),
    "observed_uncompressed_js_byte_delta":len(full)-len(small),
    "normal_sha256":hashlib.sha256(full).hexdigest(),
    "optin_sha256":hashlib.sha256(small).hexdigest(),
    "normal_promocard_present":True, "optin_real_promocard_absent":True,
    "protected_main_adbanner_label_present_in_both":True,
    "vendor_bundle_identical":True,
    "normal_real_module_resolved":True,
    "optin_null_module_resolved":True,
    "optin_real_module_not_a_dependency":True,
    "limitations":[
        "Uncompressed JS bundle bytes are not marginal compressed tar.xz bytes.",
        "Not native Firefox packaging, graphics or profile runtime.",
        "Native opt-in and normal builds remain untested."
    ]
}
out.write_text(json.dumps(report, indent=2)+"\n")
print(json.dumps(report,indent=2))
print("PASS: default retains real PromoCard; opt-in excludes original handlers")
PY
