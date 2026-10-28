#!/usr/bin/env bash
# Full pinned-tree contract for the opt-in New Tab AdsFeed exclusion.
set -euo pipefail
repo="${1:-$PWD}"
python3 - "$repo" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

repo = Path(sys.argv[1])
def get(path):
    return subprocess.check_output(
        ["git", "-C", str(repo), "show", "HEAD:" + path], text=True
    )

src = "browser/extensions/newtab/"
inventory = subprocess.check_output(
    ["git", "-C", str(repo), "ls-tree", "HEAD:" + src + "lib"], text=True
).splitlines()
names = set()
directories = set()
for entry in inventory:
    meta, name = entry.split("\t", 1)
    names.add(name)
    if meta.split()[1] == "tree":
        directories.add(name)
assert "AdsFeed.sys.mjs" in names, "candidate must remain in source"
expected = names - {"AdsFeed.sys.mjs"}
assert len(expected) >= 40, "unexpected truncated New Tab source inventory"

# The builtin jar's (./lib/<directory>/*) entries are intentionally
# non-recursive, unlike the XPI's ../lib/<directory>/** entries. Confirm that
# source subdirectories have no deeper tracked descendants, or else future
# files could be missing from the opt-in builtin jar despite passing the
# top-level manifest name equality check.
recursive_files = subprocess.check_output(
    ["git", "-C", str(repo), "ls-tree", "-r", "--name-only",
     "HEAD:" + src + "lib"], text=True
).splitlines()
assert "AdsFeed.sys.mjs" in recursive_files
for name in recursive_files:
    parts = name.split("/")
    assert parts[0] in names, ("unlisted top-level library", name)
    if parts[0] in directories:
        assert len(parts) == 2, (
            "nested lib directory would be omitted by jar.mn one-level wildcard",
            name,
        )
    else:
        assert len(parts) == 1, (
            "unexpected directory without explicit jar/XPI recursive entry",
            name,
        )
print(
    f"PASS: {len(recursive_files)} tracked New Tab library leaf paths, "
    f"{len(directories)} one-level directories; no nested-JAR omissions"
)


config = get("browser/moz.configure")
assert 'env="VULPRA_EXPERIMENT_NO_NEWTAB_ADSFEED"' in config
assert 'set_config("VULPRA_NO_NEWTAB_ADSFEED", vulpra_no_newtab_adsfeed)' in config
assert 'set_define("VULPRA_NO_NEWTAB_ADSFEED", depends_if(vulpra_no_newtab_adsfeed)(lambda _: True))' in config
assert 'set_define("VULPRA_NO_NEWTAB_ADSFEED", vulpra_no_newtab_adsfeed)' not in config
assert "if disable and not linux:" in config
app = get("toolkit/modules/AppConstants.sys.mjs")
assert 'VULPRA_NO_NEWTAB_ADSFEED:' in app
assert "#ifdef VULPRA_NO_NEWTAB_ADSFEED\n  true,\n#else\n  false,\n#endif" in app
feed = get(src + "lib/ActivityStream.sys.mjs")
assert 'if (AppConstants.VULPRA_NO_NEWTAB_ADSFEED && config.name === "adsfeed")' in feed
assert feed.index("for (const config of FEEDS_DATA)") < feed.index(
    'if (AppConstants.VULPRA_NO_NEWTAB_ADSFEED && config.name === "adsfeed")'
)
assert 'factory: () => new lazy.DiscoveryStreamFeed()' in feed
# A remote Nimbus experiment can enable unifiedAds.adsFeed.enabled even in
# the opt-in build that physically omits the module. Both retained consumers
# must route the preference to their guarded direct-fetch/AdsClient fallbacks,
# including cleanup paths, instead of dereferencing missing state.Ads.
discovery = get(src + "lib/DiscoveryStreamFeed.sys.mjs")
topsites = get(src + "lib/TopSitesFeed.sys.mjs")
for name, text, required in (
    ("DiscoveryStreamFeed", discovery, 2),
    ("TopSitesFeed", topsites, 1),
):
    assert 'AppConstants: "resource://gre/modules/AppConstants.sys.mjs"' in text
    assert text.count("!lazy.AppConstants.VULPRA_NO_NEWTAB_ADSFEED &&") == required, (
        name,
        "all direct AdsFeed pref branches must be guarded",
    )
    assert "state.Ads" in text, (name, "expected upstream consumer")
    assert "PREF_UNIFIED_ADS_ADSFEED_ENABLED" in text
assert "if (unifiedAdsEnabled && !adsFeedEnabled)" in discovery
assert "if (adsFeedEnabled) {" in discovery
assert "if (!adsFeedEnabled) {" in topsites
print("PASS: forced remote AdsFeed pref cannot select missing-feed branches in opt-in code")
assert 'factory: () => new lazy.TopSitesFeed()' in feed
assert 'factory: () => new lazy.PrefsFeed(PREFS_CONFIG)' in feed

jar = get(src + "addon-jar.mn")
block = jar.split("#ifdef VULPRA_NO_NEWTAB_ADSFEED\n", 1)[1].split(
    "\n#else\n", 1)[0]
jar_files = set()
for line in block.splitlines():
    if not line.strip():
        continue
    match = re.fullmatch(
        r"  builtin-addons/newtab/lib/([^ (]+) \(./lib/([^ )]+)\)", line
    )
    assert match, "invalid candidate jar entry: " + repr(line)
    dest, source = match.groups()
    name = dest.split("/", 1)[0]
    if name in directories:
        assert dest == name + "/" and source == name + "/*", (dest, source)
    else:
        assert dest == source == name, (dest, source)
    jar_files.add(name)
assert jar_files == expected, {
    "missing": sorted(expected - jar_files),
    "unexpected": sorted(jar_files - expected)
}
assert '  builtin-addons/newtab/lib/ (./lib/*)' in jar.split(
    "\n#else\n", 1)[1].split("\n#endif", 1)[0]

webext = get(src + "webext-glue/moz.build")
block = webext.split('if CONFIG["VULPRA_NO_NEWTAB_ADSFEED"]:\n', 1)[1].split(
    "\nelse:\n", 1)[0]
xpi_files = set()
for entry in re.findall(r'"../lib/([^"]+)"', block):
    name = entry.split("/", 1)[0]
    if name in directories:
        assert entry == name + "/**"
    else:
        assert entry == name
    xpi_files.add(name)
assert xpi_files == expected
assert '        "../lib/**",' in webext.split(
    'if CONFIG["VULPRA_NO_NEWTAB_ADSFEED"]:\n', 1
)[1].split("\nelse:\n", 1)[1]

lean = get("ci/mozconfig-linux-m3-newtab-adsfeed-experiment")
base = get("ci/mozconfig-linux-m3-baseline")
normal = get("ci/mozconfig-linux")
assert "VULPRA_EXPERIMENT_NO_NEWTAB_ADSFEED" not in base + normal
assert "export VULPRA_EXPERIMENT_NO_NEWTAB_ADSFEED=1" in lean
assert "obj-vulpra-linux-m3-newtab-adsfeed-experiment" in lean
def opts(s):
    return [x.strip() for x in s.splitlines()
            if x.strip() and not x.lstrip().startswith("#")
            and not x.startswith("mk_add_options MOZ_OBJDIR=")
            and not x.startswith("export VULPRA_EXPERIMENT_NO_NEWTAB_ADSFEED=")]
assert opts(lean) == opts(base), (opts(lean), opts(base))
print("PASS: default New Tab wildcard untouched and candidate excludes only AdsFeed")
print(f"PASS: {len(expected)} retained New Tab library entries in built-in jar and train-hop XPI")
print("PASS: immutable factory guard, shared feed retention and matched configure options")
print("SOURCE CONTRACT ONLY; real native packaging/runtime and size remain unverified")
PY
