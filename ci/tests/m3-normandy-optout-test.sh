#!/usr/bin/env bash
# Verify isolated M3 experiment guards without compiling Firefox.
set -Eeuo pipefail
repo="${1:-$PWD}"
python3 - "$repo" <<'PY'
from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1])
def source(path):
    return subprocess.run(
        ["git", "-C", str(repo), "show", "HEAD:" + path],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    ).stdout.decode()

normal = source("ci/mozconfig-linux")
lean = source("ci/mozconfig-linux-normandy-experiment")
assert "VULPRA_EXPERIMENT_NO_NORMANDY" not in normal
assert "obj-vulpra-linux-normandy-experiment" not in normal
assert "export VULPRA_EXPERIMENT_NO_NORMANDY=1" in lean
assert "obj-vulpra-linux-normandy-experiment" in lean
assert "mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-linux" in normal
assert "ac_add_options --with-app-basename=Vulpra" in normal and "ac_add_options --with-app-basename=Vulpra" in lean

configure = source("browser/moz.configure")
assert 'env="VULPRA_EXPERIMENT_NO_NORMANDY"' in configure
assert 'def vulpra_include_normandy(experimental_disable):' in configure
assert 'return not experimental_disable' in configure
assert 'imply_option("MOZ_NORMANDY", True, when=vulpra_include_normandy)' in configure
assert 'imply_option("MOZ_SERVICES_SYNC", True)' in configure

build = source("toolkit/components/moz.build")
assert 'DIRS += ["messaging-system"]' in build
assert 'if CONFIG["MOZ_NORMANDY"]:' in build
assert '    if CONFIG["MOZ_NORMANDY"]:\n        DIRS += ["normandy"]' in build
assert 'DIRS += ["messaging-system", "normandy"]' not in build

manifest = source("browser/components/BrowserComponents.manifest").splitlines()
init = "category browser-before-ui-startup resource://normandy/Normandy.sys.mjs Normandy.init"
uninit = "category browser-quit-application-granted resource://normandy/Normandy.sys.mjs Normandy.uninit"
for item in (init, uninit):
    assert manifest.count(item) == 1
    index = manifest.index(item)
    assert manifest[index - 1] == "#ifdef MOZ_NORMANDY"
    assert manifest[index + 1] == "#endif"

print("PASS: standard Vulpra build defaults unchanged")
print("PASS: opt-in Normandy experiment uses a distinct object directory")
print("PASS: alternate configure gates optional resource inclusion")
print("PASS: Normandy startup and shutdown registrations both gated")
print("PASS: no source deletion, native build or runtime tests claimed")
PY
