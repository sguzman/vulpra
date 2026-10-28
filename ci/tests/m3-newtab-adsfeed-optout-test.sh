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

config = get("browser/moz.configure")
assert 'env="VULPRA_EXPERIMENT_NO_NEWTAB_ADSFEED"' in config
assert 'set_config("VULPRA_NO_NEWTAB_ADSFEED", vulpra_no_newtab_adsfeed)' in config
assert 'set_define("VULPRA_NO_NEWTAB_ADSFEED", vulpra_no_newtab_adsfeed)' in config
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
