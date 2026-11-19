#!/usr/bin/env bash
# Source-first Firefox 160.0.1 BYOB Vulpra build using main's existing Nix shell.
# No CI binary, system install, local git branch switch, or profile mutation.
set -Eeuo pipefail
umask 077
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
old_sha=2887d9de1f69c0e9776413da80e7ba0d1225dd9b
new_sha=58fed86b1b6864ad71b83c910a879d6f1a6b678b
cache="${VULPRA_SOURCE_CACHE:-$HOME/.cache/vulpra/mozilla}"
work="${VULPRA_BUILD_DIR:-$HOME/Code/Builds/vulpra-160.0.1}"
old="${VULPRA_160_BASE_SOURCE:-$cache/firefox-160.0}"
new="${VULPRA_160_HOTFIX_SOURCE:-$cache/firefox-160.0.1}"
fetch=0; action=build; jobs=8

usage() {
  cat <<'HELP'
Vulpra local Nix build, from the repository's main branch:

  ./nix/vulpra build                 Build locally, reuse cached Mozilla source.
  ./nix/vulpra build --fetch-source  Authorize first-time official source fetch.
  ./nix/vulpra build --jobs 8        Set local native parallelism.
  ./nix/vulpra run                   Launch the locally built isolated Vulpra.
  bash scripts/vulpra-build-160.sh --status
                                    Read-only source/build availability.

No CI precompiled browser is downloaded. Mozilla source must be present or
--fetch-source must be explicitly given; first source acquisition can be large.
The existing Firefox Developer Edition and current Vulpra profile are untouched.
HELP
}
die() { printf 'Vulpra 160 local build: %s\n' "$*" >&2; exit 2; }
while (( $# )); do
  case "$1" in
    --help|-h) usage; exit 0;;
    --status) action=status; shift;;
    --preflight) action=preflight; shift;;
    --run) action=run; shift;;
    --fetch-source) fetch=1; shift;;
    --jobs) (( $# >= 2 )) || die 'missing --jobs value'; jobs="$2"; shift 2;;
    *) die "unknown argument: $1";;
  esac
done
[[ "$jobs" =~ ^[1-9][0-9]?$ ]] || die '--jobs must be between 1 and 99'
[[ "$cache" == /* && "$work" == /* && "$old" == /* && "$new" == /* ]] ||
  die 'cache, source and build directories must use absolute paths'
for p in "$cache" "$work" "$old" "$new"; do
  [[ ! -L "$p" ]] || die "refusing symlinked directory: $p"
done
[[ "$work" != "$repo" && "$work/" != "$repo/"* && "$repo/" != "$work/"* ]] ||
  die 'refusing to build within or above the repository checkout'
[[ "$old" != "$new" && "$old" != "$work" && "$new" != "$work" ]] ||
  die 'source caches and build directory must be separate'
[[ -f "$repo/ci/security-160-stage-overlay.sh" &&
   -f "$repo/ci/security-160-hotfix-assemble-tree.sh" &&
   -f "$repo/scripts/build-firefox160-local.sh" ]] ||
  die 'missing authenticated source assembly tools on main'

is_source() {
  [[ -d "$1/.git" || -f "$1/.git" ]] &&
    [[ "$(git -C "$1" rev-parse HEAD 2>/dev/null || true)" == "$2" ]] &&
    [[ -z "$(git -C "$1" status --porcelain 2>/dev/null)" ]]
}
if [[ "$action" == status ]]; then
  printf 'Vulpra root: %s\n' "$repo"
  printf 'Official Firefox 160.0 source: %s\n' \
    "$(if is_source "$old" "$old_sha"; then echo available; else echo missing; fi)"
  printf 'Official Firefox 160.0.1 source: %s\n' \
    "$(if is_source "$new" "$new_sha"; then echo available; else echo missing; fi)"
  printf 'Prepared Vulpra 160.0.1 source: %s\n' \
    "$(if [[ -s "$work/prepared-source-tree.sha" ]]; then echo present; else echo missing; fi)"
  printf 'Local Vulpra binary: %s\n' \
    "$(if [[ -x "$work/source/obj-vulpra-linux/dist/bin/vulpra" ]]; then echo present; else echo missing; fi)"
  echo 'No source downloads, compilation, or browser profile changes.'
  exit 0
fi

# This guard runs BEFORE entering Nix. Missing upstream source must not
# unexpectedly trigger a Nix/nom toolchain realization or any network fetch.
if [[ "$action" == preflight ]]; then
  if [[ -s "$work/prepared-source-tree.sha" ]]; then
    [[ "$(cat "$work/prepared-source-tree.sha")" ==
       d6f7faf6583831a58d127480db54b5bcd5ab5949 &&
       -d "$work/source" ]] ||
      die 'prepared source identity is incomplete or changed; refusing to start Nix'
    echo 'PASS: verified Vulpra source already prepared; no source download needed'
    exit 0
  fi
  if [[ -e "$work" ]]; then
    die "incomplete or unverified local build directory: $work; refusing overwrite"
  fi
  if is_source "$old" "$old_sha" && is_source "$new" "$new_sha"; then
    echo 'PASS: official Mozilla source caches present; no source download needed'
    exit 0
  fi
  cat >&2 <<HELP
Official Mozilla source is not cached for local Vulpra 160.0.1.
No Nix evaluation, source fetch, binary download or compilation was started.

To explicitly authorize the one-time Mozilla SOURCE download:
  ./nix/vulpra build --fetch-source

That source download can be large. Your existing browser is unaffected.
HELP
  exit 3
fi

if [[ "$action" == run ]]; then
  exec bash "$repo/scripts/build-firefox160-local.sh" run --work-dir "$work"
fi

[[ "${VULPRA_NIX_DEV:-}" == 1 ]] ||
  die 'use ./nix/vulpra build; the pinned Nix developer shell is required'
for command_name in git bash flock; do
  command -v "$command_name" >/dev/null || die "missing $command_name"
done
# Hold a separate lock; the checkout's historical obj-vulpra-linux is never built.
mkdir -p -- "$cache"
exec 9>"$cache/vulpra160-build.lock"
flock -n 9 || die 'another Vulpra 160 source/build job is in progress'
if [[ -s "$work/prepared-source-tree.sha" ]]; then
  echo 'Reusing already prepared Firefox 160.0.1 Vulpra source; no source fetch.'
else
  if ! is_source "$old" "$old_sha" || ! is_source "$new" "$new_sha"; then
    if [[ "$fetch" != 1 ]]; then
      cat >&2 <<HELP
Official Mozilla Firefox 160.0 / 160.0.1 source is not cached.
The repository intentionally does not silently download large source trees.
To approve the ONE-TIME upstream SOURCE fetch (not a CI binary), run:

  ./nix/vulpra build --fetch-source

Then future incremental builds use simply ./nix/vulpra build.
Existing profiles and source/build outputs are untouched.
HELP
      exit 3
    fi
  fi

  # Only fetching source with explicit permission. Reuse verified checkouts.
  if ! is_source "$old" "$old_sha"; then
    [[ ! -e "$old" ]] ||
      die "source cache exists but is unverified: $old; no automatic deletion or overwrite"
    mkdir -p -- "$(dirname -- "$old")"
    echo 'Fetching official Mozilla 160.0 source metadata and required overlay files.'
    git clone --quiet --depth=1 --filter=blob:none --no-checkout \
      --branch FIREFOX_160_0_RELEASE \
      https://github.com/mozilla-firefox/firefox.git "$old"
    [[ "$(git -C "$old" rev-parse HEAD)" == "$old_sha" ]] ||
      die 'official Firefox 160.0 release commit mismatch'
    git -C "$old" sparse-checkout set --no-cone \
      browser/branding/unofficial/configure.sh \
      browser/branding/unofficial/locales/en-US/brand.ftl \
      browser/branding/unofficial/pref/firefox-branding.js \
      browser/moz.configure \
      browser/app/profile/firefox.js \
      toolkit/components/normandy/jar.mn \
      toolkit/components/normandy/lib/NormandyApi.sys.mjs \
      toolkit/components/normandy/lib/NormandyUtils.sys.mjs \
      toolkit/components/normandy/schemas/LegacyHeartbeat.schema.json \
      browser/extensions/newtab/webext-glue/moz.build \
      browser/extensions/newtab/lib/ActivityStream.sys.mjs \
      browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs \
      browser/extensions/newtab/lib/TopSitesFeed.sys.mjs \
      taskcluster/kinds/toolchain/android.yml \
      python/mozbuild/mozbuild/frontend/emitter.py \
      browser/components/asrouter/modules/ASRouter.sys.mjs \
      toolkit/components/moz.build \
      browser/components/BrowserComponents.manifest \
      browser/components/DesktopActorRegistry.sys.mjs \
      browser/components/asrouter/moz.build \
      browser/extensions/newtab/addon-jar.mn \
      browser/extensions/newtab/build-newtab-bundles.py \
      browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/AdBanner/AdBanner.jsx \
      browser/extensions/newtab/webpack.system-addon.config.js \
      dom/webgpu/tests/cts/checkout/node.tsconfig.json \
      python/mozbuild/mozbuild/testing.py \
      toolkit/components/nimbus/moz.build \
      toolkit/components/normandy/moz.build \
      toolkit/modules/AppConstants.sys.mjs
    git -C "$old" checkout --detach "$old_sha"
  fi

  if ! is_source "$new" "$new_sha"; then
    [[ ! -e "$new" ]] ||
      die "hotfix source cache exists but is unverified: $new; no automatic deletion or overwrite"
    mkdir -p -- "$(dirname -- "$new")"
    echo 'Fetching official Mozilla Firefox 160.0.1 source (large one-time source acquisition).'
    git clone --quiet --depth=1 --filter=blob:none \
      --branch FIREFOX_160_0_1_RELEASE \
      https://github.com/mozilla-firefox/firefox.git "$new"
    [[ "$(git -C "$new" rev-parse HEAD)" == "$new_sha" ]] ||
      die 'official Firefox 160.0.1 commit mismatch'
  fi
  is_source "$old" "$old_sha" || die 'Firefox 160.0 authenticated source missing or dirty'
  is_source "$new" "$new_sha" || die 'Firefox 160.0.1 authenticated source missing or dirty'

  # The source assembly script refuses to overwrite a work directory. This
  # permits safe retries after source downloads, but not silent destructive repair.
  [[ ! -e "$work" ]] ||
    die "prepared build directory incomplete: $work; inspect manually, no automatic deletion"
  bash "$repo/scripts/build-firefox160-local.sh" prepare \
    --old-source "$old" --hotfix-source "$new" --work-dir "$work"
fi

# The existing Nix shell supplies bindgen/WASI toolchain and sccache.
# Its package realizations may use configured Nix caches; this does not
# download any precompiled Vulpra browser.
bash "$repo/scripts/build-firefox160-local.sh" build \
  --work-dir "$work" --jobs "$jobs"
