#!/usr/bin/env bash
set -euo pipefail

# Vulpra's technical upstream-license/branding guard. This is NOT a legal
# opinion or permission to distribute Mozilla-branded binaries.
[[ -f LICENSE && -f mach && -f Cargo.toml ]] || {
  echo "Not a Firefox source checkout" >&2; exit 1;
}
git rev-parse --verify refs/remotes/origin/upstream-base >/dev/null || {
  echo "Fetch origin/upstream-base before auditing" >&2; exit 1;
}

if ! cmp -s LICENSE <(git show refs/remotes/origin/upstream-base:LICENSE); then
  echo "Root upstream license notice differs from upstream-base" >&2
  exit 1
fi
echo "PASS: original Firefox source-tree LICENSE preserved"

license_template="toolkit/content/license.html.mako"
test -s "$license_template"
grep -Fq 'licenses.json' "$license_template"
grep -Fq 'LICENSES' "$license_template"
test -d toolkit/content/licenses
test -s toolkit/content/licenses/mpl.html
test -s toolkit/content/licenses/mit.txt
test -d other-licenses
test -s other-licenses/README
test -d third_party
echo "PASS: generated about:license source, declarations and third-party license inventories remain present"

for path in mach browser/branding/unofficial/configure.sh \
  browser/branding/unofficial/locales/en-US/brand.ftl; do
  grep -q 'Mozilla Public' "$path" || {
    echo "Missing upstream MPL header: $path" >&2
    exit 1
  }
done
echo "PASS: sampled per-file Mozilla license headers intact"

# Ensure CI is using a nonofficial upstream branding configuration.
# This does NOT mean that the result is branded as Vulpra or safe to ship.
grep -Fxq 'ac_add_options --with-branding=browser/branding/unofficial' ci/mozconfig-linux
if grep -Eq -- '--enable-official-branding|--with-branding=browser/branding/official' ci/mozconfig-linux; then
  echo "Refusing Mozilla official trademarked branding in Vulpra CI" >&2
  exit 1
fi
test -s browser/branding/unofficial/configure.sh
test -s browser/branding/unofficial/locales/en-US/brand.ftl
echo "PASS: native CI explicitly selects unofficial upstream branding"

# This is expected for the imported release and remains a release blocker:
# unofficial ≠ independently branded. Verify rather than silently ignore it.
grep -Fxq 'MOZ_APP_DISPLAYNAME=Vulpra' browser/branding/unofficial/configure.sh
grep -Fxq 'ac_add_options --with-app-basename=Vulpra' ci/mozconfig-linux
for key in shorter-name short-name shortcut-name full-name product-name; do
  grep -Fxq -- "-brand-$key = Vulpra" browser/branding/unofficial/locales/en-US/brand.ftl
done
grep -Fxq -- '-vendor-short-name = Vulpra' browser/branding/unofficial/locales/en-US/brand.ftl
echo "PASS: Vulpra app basename and displayed strings are independent of Nightly/Firefox"

echo "PASS: technical license and branding inventory checks. Unreviewed image assets, binary app ID and real-browser QA remain distribution blockers."
